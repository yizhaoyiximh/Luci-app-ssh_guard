#!/bin/sh

LOG_FILE="/tmp/ssh_guard.log"
STATE_DIR="/tmp/ssh_guard"
BLACKLIST_FILE="$STATE_DIR/blacklist"
WHITELIST_FILE="$STATE_DIR/whitelist"
LOCK_FILE="$STATE_DIR/lock"
LAST_LINE_FILE="$STATE_DIR/last_line"

mkdir -p "$STATE_DIR"
touch "$BLACKLIST_FILE"
touch "$LAST_LINE_FILE"

load_config() {
	ENABLED=$(uci get ssh_guard.config.enabled 2>/dev/null || echo "0")
	TIME_WINDOW=$(uci get ssh_guard.config.time_window 2>/dev/null || echo "10")
	MAX_ATTEMPTS=$(uci get ssh_guard.config.max_attempts 2>/dev/null || echo "3")
	BAN_DURATION=$(uci get ssh_guard.config.ban_duration 2>/dev/null || echo "3600")
	SSH_PORT=$(uci get ssh_guard.config.ssh_port 2>/dev/null || echo "22")
}

is_whitelisted() {
	local ip="$1"
	[ -f "$WHITELIST_FILE" ] && grep -q "^${ip}$" "$WHITELIST_FILE"
}

acquire_lock() {
	local retries=10
	while [ $retries -gt 0 ]; do
		if (set -o noclobber; echo $$ > "$LOCK_FILE") 2>/dev/null; then
			return 0
		fi
		retries=$((retries - 1))
		sleep 0.1
	done
	return 1
}

release_lock() {
	rm -f "$LOCK_FILE"
}

ban_ip() {
	local ip="$1"
	local now=$(date +%s)

	local existing=$(grep "^${ip}:" "$BLACKLIST_FILE" 2>/dev/null)
	if [ -n "$existing" ]; then
		sed -i "s/^${ip}:.*$/${ip}:${now}/" "$BLACKLIST_FILE"
		logger -t ssh_guard "Reset ban time for IP: $ip"
		return 0
	fi

	echo "Banning IP: $ip" >> "$LOG_FILE"
	if command -v iptables >/dev/null 2>&1; then
		iptables -C INPUT -s "$ip" -j DROP 2>/dev/null || \
		iptables -I INPUT -s "$ip" -j DROP
		iptables -C INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j DROP 2>/dev/null || \
		iptables -I INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j DROP
	elif command -v nft >/dev/null 2>&1; then
		nft add rule inet fw4 input ip saddr "$ip" drop 2>/dev/null
	fi

	echo "${ip}:${now}" >> "$BLACKLIST_FILE"
	logger -t ssh_guard "Banned IP: $ip for $BAN_DURATION seconds"
}

temp_unban() {
	local ip="$1"
	
	if ! grep -q "^${ip}:" "$BLACKLIST_FILE" 2>/dev/null; then
		return 1
	fi
	
	sed -i "/^${ip}:/d" "$BLACKLIST_FILE"
	
	if command -v iptables >/dev/null 2>&1; then
		iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
		iptables -D INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j DROP 2>/dev/null
	elif command -v nft >/dev/null 2>&1; then
		nft delete rule inet fw4 input ip saddr "$ip" drop 2>/dev/null
	fi
	
	echo "$ip" >> "$WHITELIST_FILE"
	logger -t ssh_guard "Temp unbanned IP: $ip"
	return 0
}

unban_ip() {
	local ip="$1"
	
	if ! grep -q "^${ip}:" "$BLACKLIST_FILE" 2>/dev/null; then
		return 1
	fi
	
	sed -i "/^${ip}:/d" "$BLACKLIST_FILE"
	
	if command -v iptables >/dev/null 2>&1; then
		iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
		iptables -D INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j DROP 2>/dev/null
	elif command -v nft >/dev/null 2>&1; then
		nft delete rule inet fw4 input ip saddr "$ip" drop 2>/dev/null
	fi
	
	logger -t ssh_guard "Unbanned IP: $ip"
	return 0
}

unban_expired() {
	local now=$(date +%s)
	local temp_file="${BLACKLIST_FILE}.tmp"

	> "$temp_file"

	while IFS=: read -r ip ban_time; do
		[ -z "$ip" ] && continue
		local expiry=$((ban_time + BAN_DURATION))
		if [ "$now" -lt "$expiry" ]; then
			echo "${ip}:${ban_time}" >> "$temp_file"
		else
			echo "Unbanning IP: $ip" >> "$LOG_FILE"
			if command -v iptables >/dev/null 2>&1; then
				iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
				iptables -D INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j DROP 2>/dev/null
			elif command -v nft >/dev/null 2>&1; then
				nft delete rule inet fw4 input ip saddr "$ip" drop 2>/dev/null
			fi
			logger -t ssh_guard "Unbanned IP: $ip"
		fi
	done < "$BLACKLIST_FILE"

	mv "$temp_file" "$BLACKLIST_FILE"
}

check_failed_attempts() {
	local now=$(date +%s)
	local window_start=$((now - TIME_WINDOW))
	local attempts_file="$STATE_DIR/attempts"

	touch "$attempts_file"
	local temp_file="${attempts_file}.tmp"
	> "$temp_file"

	while IFS=: read -r ip timestamp; do
		[ -z "$ip" ] && continue
		if is_whitelisted "$ip"; then
			continue
		fi
		if [ "$timestamp" -ge "$window_start" ]; then
			echo "${ip}:${timestamp}" >> "$temp_file"
		fi
	done < "$attempts_file"

	mv "$temp_file" "$attempts_file"

	local ips=$(cut -d: -f1 "$attempts_file" | sort -u)
	for ip in $ips; do
		if is_whitelisted "$ip"; then
			sed -i "/^${ip}:/d" "$attempts_file"
			continue
		fi
		local count=$(grep -c "^${ip}:" "$attempts_file")
		if [ "$count" -ge "$MAX_ATTEMPTS" ]; then
			ban_ip "$ip"
			sed -i "/^${ip}:/d" "$attempts_file"
		fi
	done
}

record_failed_attempt() {
	local ip="$1"
	local now=$(date +%s)
	local attempts_file="$STATE_DIR/attempts"

	if is_whitelisted "$ip"; then
		return
	fi

	if acquire_lock; then
		echo "${ip}:${now}" >> "$attempts_file"
		check_failed_attempts
		release_lock
	fi
}

parse_auth_log() {
	local current_line_count=$(logread 2>/dev/null | wc -l)
	local last_line=$(cat "$LAST_LINE_FILE" 2>/dev/null || echo "0")

	if [ "$current_line_count" -le "$last_line" ]; then
		return
	fi

	local new_lines=$((current_line_count - last_line))

	logread 2>/dev/null | tail -n "$new_lines" | grep -E "dropbear|sshd" | while read -r line; do
		if echo "$line" | grep -qiE "bad password|failed password|invalid user|authentication failure|login attempt.*nonexistent|1 fails"; then
			local ip=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1)
			if [ -n "$ip" ]; then
				record_failed_attempt "$ip"
			fi
		fi
	done

	echo "$current_line_count" > "$LAST_LINE_FILE"
}

monitor_loop() {
	while true; do
		parse_auth_log
		unban_expired
		sleep 2
	done
}

start() {
	load_config

	if [ "$ENABLED" != "1" ]; then
		echo "SSH Guard is disabled. Enable it in UCI config."
		return 1
	fi

	echo "0" > "$LAST_LINE_FILE"
	echo "Starting SSH Guard..." >> "$LOG_FILE"
	logger -t ssh_guard "Starting SSH Guard (window=${TIME_WINDOW}s, max=${MAX_ATTEMPTS}, ban=${BAN_DURATION}s)"

	monitor_loop &
	echo $! > /var/run/ssh_guard.pid
}

stop() {
	if [ -f /var/run/ssh_guard.pid ]; then
		kill $(cat /var/run/ssh_guard.pid) 2>/dev/null
		rm -f /var/run/ssh_guard.pid
	fi

	echo "Stopping SSH Guard..." >> "$LOG_FILE"
	logger -t ssh_guard "Stopping SSH Guard"

	if command -v iptables >/dev/null 2>&1; then
		while IFS=: read -r ip ban_time; do
			[ -z "$ip" ] && continue
			iptables -D INPUT -s "$ip" -j DROP 2>/dev/null
			iptables -D INPUT -s "$ip" -p tcp --dport "$SSH_PORT" -j DROP 2>/dev/null
		done < "$BLACKLIST_FILE"
	elif command -v nft >/dev/null 2>&1; then
		while IFS=: read -r ip ban_time; do
			[ -z "$ip" ] && continue
			nft delete rule inet fw4 input ip saddr "$ip" drop 2>/dev/null
		done < "$BLACKLIST_FILE"
	fi

	> "$BLACKLIST_FILE"
}

status() {
	if [ -f /var/run/ssh_guard.pid ] && kill -0 $(cat /var/run/ssh_guard.pid) 2>/dev/null; then
		echo "SSH Guard is running (PID: $(cat /var/run/ssh_guard.pid))"
		echo "Configuration:"
		echo "  Time Window: ${TIME_WINDOW}s"
		echo "  Max Attempts: ${MAX_ATTEMPTS}"
		echo "  Ban Duration: ${BAN_DURATION}s"
		echo "  SSH Port: ${SSH_PORT}"
		echo ""
		echo "Currently banned IPs:"
		if [ -s "$BLACKLIST_FILE" ]; then
			local now=$(date +%s)
			while IFS=: read -r ip ban_time; do
				[ -z "$ip" ] && continue
				local expiry=$((ban_time + BAN_DURATION))
				local remaining=$((expiry - now))
				echo "  $ip (expires in ${remaining}s)"
			done < "$BLACKLIST_FILE"
		else
			echo "  (none)"
		fi
		echo ""
		echo "Whitelisted IPs (temp unbanned):"
		if [ -s "$WHITELIST_FILE" ]; then
			cat "$WHITELIST_FILE" | sed 's/^/  /'
		else
			echo "  (none)"
		fi
	else
		echo "SSH Guard is not running"
	fi
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		start
		;;
	status)
		load_config
		status
		;;
	temp-unban)
		temp_unban "$2"
		;;
	unban)
		unban_ip "$2"
		;;
	*)
		echo "Usage: $0 {start|stop|restart|status|temp-unban <ip>|unban <ip>}"
		exit 1
		;;
esac
