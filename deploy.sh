#!/bin/bash
# deploy.sh - 直接部署到 OpenWrt 路由器，无需 opkg

ROUTER="${1:-192.168.1.1}"
USER="${2:-root}"

echo "================================================"
echo "  SSH Guard Deploy to OpenWrt"
echo "  Router: $USER@$ROUTER"
echo "================================================"

echo "📁 上传文件..."
scp -r root/etc/init.d/ssh_guard ${USER}@${ROUTER}:/etc/init.d/ssh_guard
scp -r root/usr/lib/ssh_guard ${USER}@${ROUTER}:/usr/lib/ssh_guard
scp -r root/usr/share/rpcd/acl.d/luci-ssh-guard.json ${USER}@${ROUTER}:/usr/share/rpcd/acl.d/
scp -r luasrc/controller/ssh_guard.lua ${USER}@${ROUTER}:/usr/lib/lua/luci/controller/ssh_guard.lua
scp -r luasrc/model/cbi/ssh_guard.lua ${USER}@${ROUTER}:/usr/lib/lua/luci/model/cbi/ssh_guard.lua
scp -r luasrc/model/ssh_guard.lua ${USER}@${ROUTER}:/usr/lib/lua/luci/model/ssh_guard.lua
scp -r luasrc/view/ssh_guard ${USER}@${ROUTER}:/usr/lib/lua/luci/view/ssh_guard/
ssh ${USER}@${ROUTER} "mkdir -p /etc/config && cat > /etc/config/ssh_guard" < files/ssh_guard

echo ""
echo "⚙️ 配置权限..."
ssh ${USER}@${ROUTER} 'chmod +x /etc/init.d/ssh_guard /usr/lib/ssh_guard/ssh_guard.sh'

echo ""
echo "🚀 启动服务..."
ssh ${USER}@${ROUTER} '/etc/init.d/ssh_guard enable && /etc/init.d/ssh_guard start'

echo ""
echo "================================================"
echo "✅ 部署完成!"
echo "================================================"
echo ""
echo "💡 访问 LuCI: Services → SSH Guard"
echo "💡 查看状态: /etc/init.d/ssh_guard status"
