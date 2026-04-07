module("luci.controller.ssh_guard", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ssh_guard") then
		return
	end

	entry({"admin", "services", "ssh_guard"}, cbi("ssh_guard"), _("SSH Guard"), 90).dependent = true
end
