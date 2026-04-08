require("luci.sys")
require("luci.http")
require("luci.dispatcher")
require("luci.model.uci")
local fs = require "nixio.fs"

module("luci.model.ssh_guard", package.seeall)

function get_status()
	local pidfile = "/var/run/ssh_guard.pid"
	if fs.access(pidfile) then
		local pid = fs.readfile(pidfile)
		if pid and luci.sys.process.info(tonumber(pid)) then
			return true
		end
	end
	return false
end

function get_banned_ips()
	local blacklist = "/tmp/ssh_guard/blacklist"
	local ips = {}
	
	if not fs.access(blacklist) then
		return ips
	end
	
	local f = io.open(blacklist, "r")
	if not f then
		return ips
	end
	
	local now = os.time()
	local uci = luci.model.uci.cursor()
	local ban_duration = tonumber(uci:get("ssh_guard", "config", "ban_duration")) or 3600
	
	for line in f:lines() do
		local ip, ban_time = line:match("^([^:]+):([^:]+)$")
		if ip and ban_time then
			local expiry = tonumber(ban_time) + ban_duration
			local remaining = expiry - now
			
			if remaining > 0 then
				table.insert(ips, {
					ip = ip,
					remaining = remaining,
					ban_time = tonumber(ban_time)
				})
			end
		end
	end
	
	f:close()
	return ips
end

function temp_unban(ip)
	local blacklist = "/tmp/ssh_guard/blacklist"
	local whitelist = "/tmp/ssh_guard/whitelist"
	
	if not fs.access(blacklist) then
		return false
	end
	
	local temp_file = blacklist .. ".tmp"
	local found = false
	
	local f = io.open(blacklist, "r")
	if not f then
		return false
	end
	
	local out = io.open(temp_file, "w")
	for line in f:lines() do
		local line_ip = line:match("^([^:]+):")
		if line_ip == ip then
			found = true
		else
			out:write(line .. "\n")
		end
	end
	
	f:close()
	out:close()
	
	if found then
		os.execute("mv " .. temp_file .. " " .. blacklist)
		os.execute("iptables -D INPUT -s " .. ip .. " -j DROP 2>/dev/null")
		os.execute("iptables -D INPUT -s " .. ip .. " -p tcp --dport 22 -j DROP 2>/dev/null")
		
		local wf = io.open(whitelist, "a")
		if wf then
			wf:write(ip .. "\n")
			wf:close()
		end
		
		luci.sys.call("logger -t ssh_guard 'temp unbanned IP: " .. ip .. "'")
		return true
	else
		os.remove(temp_file)
		return false
	end
end

function unban_ip(ip)
	local blacklist = "/tmp/ssh_guard/blacklist"
	
	if not fs.access(blacklist) then
		return false
	end
	
	local temp_file = blacklist .. ".tmp"
	local found = false
	
	local f = io.open(blacklist, "r")
	if not f then
		return false
	end
	
	local out = io.open(temp_file, "w")
	for line in f:lines() do
		local line_ip = line:match("^([^:]+):")
		if line_ip == ip then
			found = true
		else
			out:write(line .. "\n")
		end
	end
	
	f:close()
	out:close()
	
	if found then
		os.execute("mv " .. temp_file .. " " .. blacklist)
		os.execute("iptables -D INPUT -s " .. ip .. " -j DROP 2>/dev/null")
		os.execute("iptables -D INPUT -s " .. ip .. " -p tcp --dport 22 -j DROP 2>/dev/null")
		return true
	else
		os.remove(temp_file)
		return false
	end
end

function is_whitelisted(ip)
	local whitelist = "/tmp/ssh_guard/whitelist"
	
	if not fs.access(whitelist) then
		return false
	end
	
	local f = io.open(whitelist, "r")
	if not f then
		return false
	end
	
	for line in f:lines() do
		if line == ip then
			f:close()
			return true
		end
	end
	
	f:close()
	return false
end

function clear_whitelist()
	local whitelist = "/tmp/ssh_guard/whitelist"
	if fs.access(whitelist) then
		os.execute("rm " .. whitelist)
	end
end

function start_service()
	luci.sys.call("/etc/init.d/ssh_guard start")
end

function stop_service()
	luci.sys.call("/etc/init.d/ssh_guard stop")
end

function restart_service()
	luci.sys.call("/etc/init.d/ssh_guard restart")
end
