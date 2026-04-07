module("luci.controller.ssh_guard", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ssh_guard") then
		return
	end

	entry({"admin", "services", "ssh_guard"}, alias("admin", "services", "ssh_guard", "config"), _("SSH 防火墙"), 90)
	entry({"admin", "services", "ssh_guard", "config"}, cbi("ssh_guard"), _("配置"))
	entry({"admin", "services", "ssh_guard", "status"}, template("ssh_guard/status"), _("状态"))
	entry({"admin", "services", "ssh_guard", "unban"}, call("action_unban"))
end

function action_unban()
	local ip = luci.http.formvalue("ip")
	if ip and #ip > 0 then
		local guard = require "luci.model.ssh_guard"
		guard.temp_unban(ip)
	end
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "ssh_guard", "status"))
end
