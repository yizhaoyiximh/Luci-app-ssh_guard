#!/bin/bash
# package_ipk.sh
# 修复版：兼容 OpenWrt opkg，自动清理 macOS 特有文件

set -e

PKG_NAME="luci-app-ssh-guard"
PKG_VERSION="1.0.0-1"
PKG_ARCH="all"

echo "================================================"
echo "  OpenWrt IPK Packer (Fixed for macOS)"
echo "================================================"

# 清理旧构建
rm -rf build_pkg
mkdir -p build_pkg/{root,CONTROL}

export COPYFILE_DISABLE=1
export TAR_OPTIONS="--no-mac-metadata"

echo "📂 正在整理文件结构..."

# 1. 复制 root 目录
if [ -d "root" ]; then
    cp -r root/* build_pkg/root/
fi

# 2. 处理 files 目录
if [ -d "files" ]; then
    mkdir -p build_pkg/root/etc/config
    cp -r files/* build_pkg/root/etc/config/
fi

# 3. 处理 luasrc 目录
if [ -d "luasrc" ]; then
    mkdir -p build_pkg/root/usr/lib/lua/luci
    cp -r luasrc/* build_pkg/root/usr/lib/lua/luci/
fi

# 4. 清理 macOS 隐藏文件
find build_pkg -name '.DS_Store' -delete
find build_pkg -name '._*' -delete
find build_pkg -name '.AppleDouble' -exec rm -rf {} + 2>/dev/null || true

# 5. 设置可执行权限
chmod +x build_pkg/root/etc/init.d/ssh_guard 2>/dev/null || true
chmod +x build_pkg/root/usr/lib/ssh_guard/ssh_guard.sh 2>/dev/null || true

echo "📝 生成控制文件..."

# 6. 生成 CONTROL/control
cat > build_pkg/CONTROL/control << EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Depends: libc, iptables, logread
Source: local
SourceName: luci-app-ssh-guard
Section: luci
Priority: optional
Maintainer: OpenWrt
Architecture: $PKG_ARCH
Installed-Size: 10240
Description: SSH Guard - Auto-ban SSH attackers
 A LuCI plugin to monitor SSH authentication failures and ban IPs.
EOF

# 7. 生成 conffiles (opkg 需要)
cat > build_pkg/CONTROL/conffiles << EOF
/etc/config/ssh_guard
EOF

echo "📦 正在打包..."

# 8. 打包 data.tar.gz
(cd build_pkg/root && tar czf ../data.tar.gz .)

# 9. 打包 control.tar.gz
(cd build_pkg/CONTROL && tar czf ../control.tar.gz .)

# 10. 生成 debian-binary
echo "2.0" > build_pkg/debian-binary

# 11. 合并为 ipk (使用 ar rc 避免生成符号表)
(cd build_pkg && ar rc ../${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.ipk debian-binary control.tar.gz data.tar.gz)

# 清理
rm -rf build_pkg

echo ""
echo "================================================"
echo "✅ 打包成功!"
echo "================================================"
ls -lh ${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.ipk
echo ""
echo "💡 安装方法:"
echo "   scp ${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.ipk root@192.168.1.1:/tmp/"
echo "   ssh root@192.168.1.1 'opkg install /tmp/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.ipk'"
