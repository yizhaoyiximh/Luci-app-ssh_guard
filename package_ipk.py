#!/usr/bin/env python3
"""
OpenWrt IPK Packer - 精确构建 ar 格式
"""

import os
import tarfile
import shutil
import tempfile

PKG_NAME = "luci-app-ssh-guard"
PKG_VERSION = "1.0.0-1"
PKG_ARCH = "all"

def clean_dir(path):
    for root, dirs, files in os.walk(path):
        for f in files:
            if f.startswith('.DS_Store') or f.startswith('._'):
                os.remove(os.path.join(root, f))

def create_tar_gz(source_dir, output_file):
    with tarfile.open(output_file, 'w:gz', format=tarfile.GNU_FORMAT) as tar:
        for root, dirs, files in os.walk(source_dir):
            for name in files:
                filepath = os.path.join(root, name)
                arcname = os.path.relpath(filepath, source_dir)
                tar.add(filepath, arcname=arcname)

def build_ar_header(name, size):
    # ar header: name(16) + mtime(12) + uid(6) + gid(6) + mode(8) + size(10) + magic(2)
    name_bytes = name.encode('ascii')[:15] + b' ' * max(0, 16 - len(name) - 1) + b' '
    mtime = b'0           '
    uid = b'0     '
    gid = b'0     '
    mode = b'100644  '
    size_bytes = str(size).encode().rjust(10)
    magic = b'`\n'
    return name_bytes + mtime + uid + gid + mode + size_bytes + magic

def create_ipk():
    print("=" * 50)
    print("  OpenWrt IPK Packer")
    print("=" * 50)

    tmpdir = tempfile.mkdtemp()
    pkg_root = os.path.join(tmpdir, "root")
    pkg_ctrl = os.path.join(tmpdir, "control")
    os.makedirs(pkg_root)
    os.makedirs(pkg_ctrl)

    # 复制文件
    for src, dst in [
        ("root", pkg_root),
        ("files", os.path.join(pkg_root, "etc/config")),
        ("luasrc", os.path.join(pkg_root, "usr/lib/lua/luci"))
    ]:
        if os.path.exists(src):
            if src == "files":
                os.makedirs(dst, exist_ok=True)
                for f in os.listdir(src):
                    shutil.copy2(os.path.join(src, f), dst)
            else:
                for item in os.listdir(src):
                    s = os.path.join(src, item)
                    d = os.path.join(dst, item)
                    if os.path.isdir(s):
                        shutil.copytree(s, d, dirs_exist_ok=True)
                    else:
                        shutil.copy2(s, d)

    clean_dir(tmpdir)

    # 设置权限
    for f in ["etc/init.d/ssh_guard", "usr/lib/ssh_guard/ssh_guard.sh"]:
        fp = os.path.join(pkg_root, f)
        if os.path.exists(fp):
            os.chmod(fp, 0o755)

    # 生成 control 文件
    with open(os.path.join(pkg_ctrl, "control"), 'w') as f:
        f.write(f"""Package: {PKG_NAME}
Version: {PKG_VERSION}
Depends: libc, iptables, logread
Source: local
SourceName: luci-app-ssh-guard
Section: luci
Priority: optional
Maintainer: OpenWrt
Architecture: {PKG_ARCH}
Installed-Size: 10240
Description: SSH Guard - Auto-ban SSH attackers
 A LuCI plugin to monitor SSH authentication failures and ban IPs.
""")

    with open(os.path.join(pkg_ctrl, "conffiles"), 'w') as f:
        f.write("/etc/config/ssh_guard\n")

    print("📦 正在打包...")

    ipk_file = f"{PKG_NAME}_{PKG_VERSION}_{PKG_ARCH}.ipk"

    # 创建 tar.gz
    data_tar = os.path.join(tmpdir, "data.tar.gz")
    control_tar = os.path.join(tmpdir, "control.tar.gz")
    
    create_tar_gz(pkg_root, data_tar)
    create_tar_gz(pkg_ctrl, control_tar)

    # 读取 tar.gz 数据
    with open(control_tar, 'rb') as f:
        control_data = f.read()
    with open(data_tar, 'rb') as f:
        data_gz_data = f.read()
    debian_binary = b"2.0\n"

    # 构建 ar 文件
    with open(ipk_file, 'wb') as out:
        out.write(b"!<arch>\n")
        
        # debian-binary
        out.write(build_ar_header("debian-binary/", len(debian_binary)))
        out.write(debian_binary)
        if len(debian_binary) % 2:
            out.write(b'\n')
        
        # control.tar.gz
        out.write(build_ar_header("control.tar.gz/", len(control_data)))
        out.write(control_data)
        if len(control_data) % 2:
            out.write(b'\n')
        
        # data.tar.gz
        out.write(build_ar_header("data.tar.gz/", len(data_gz_data)))
        out.write(data_gz_data)
        if len(data_gz_data) % 2:
            out.write(b'\n')

    shutil.rmtree(tmpdir)

    size = os.path.getsize(ipk_file)
    print()
    print("=" * 50)
    print("✅ 打包成功!")
    print("=" * 50)
    print(f"  {ipk_file} ({size/1024:.1f} KB)")
    print()
    print("💡 安装方法:")
    print(f"   scp {ipk_file} root@192.168.1.1:/tmp/")
    print(f"   ssh root@192.168.1.1 'opkg install /tmp/{ipk_file}'")

if __name__ == "__main__":
    create_ipk()
