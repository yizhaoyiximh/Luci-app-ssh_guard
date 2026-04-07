local m, s, o

m = Map("ssh_guard", translate("SSH Guard"),
	translate("Automatically ban IPs that fail SSH authentication too many times within a specified time window."))

s = m:section(TypedSection, "ssh_guard", translate("Settings"))
s.anonymous = true

o = s:option(Flag, "enabled", translate("Enable"))
o.rmempty = false

o = s:option(Value, "time_window", translate("Time Window (seconds)"),
	translate("Time window to count failed attempts (default: 10s)"))
o.datatype = "uinteger"
o.default = 10
o.rmempty = false

o = s:option(Value, "max_attempts", translate("Max Attempts"),
	translate("Maximum failed attempts before ban (default: 3)"))
o.datatype = "uinteger"
o.default = 3
o.rmempty = false

o = s:option(Value, "ban_duration", translate("Ban Duration (seconds)"),
	translate("How long to ban an IP (default: 3600s = 1 hour)"))
o.datatype = "uinteger"
o.default = 3600
o.rmempty = false

o = s:option(Value, "ssh_port", translate("SSH Port"),
	translate("SSH port to monitor (default: 22)"))
o.datatype = "port"
o.default = 22
o.rmempty = false

return m
