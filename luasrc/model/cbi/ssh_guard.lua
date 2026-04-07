local m, s, o

m = Map("ssh_guard", translate("SSH 防火墙"),
	translate("自动封禁在设定时间内SSH认证失败次数过多的IP"))

s = m:section(TypedSection, "ssh_guard", translate("基本设置"))
s.anonymous = true

o = s:option(Flag, "enabled", translate("启用"))
o.rmempty = false

o = s:option(Value, "time_window", translate("时间窗口（秒）"))
o.datatype = "uinteger"
o.default = 10
o.rmempty = false

o = s:option(Value, "max_attempts", translate("最大尝试次数"))
o.datatype = "uinteger"
o.default = 3
o.rmempty = false

o = s:option(Value, "ban_duration", translate("封禁时长（秒）"))
o.datatype = "uinteger"
o.default = 3600
o.rmempty = false

return m
