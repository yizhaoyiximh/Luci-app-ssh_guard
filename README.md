# luci-app-ssh-guard

OpenWrt LuCI 插件 - SSH 防火墙

## 功能特性

- **自动封禁**: 当某个 IP 在设定时间内 SSH 连接失败次数超过阈值时，自动封禁该 IP
- **实时监控**: 监控 dropbear/sshd 认证日志
- **nftables/iptables**: 支持 nftables 和 iptables 防火墙
- **中文界面**: 完全中文化的 LuCI Web 界面
- **临时解封**: 可手动解封被封禁的 IP，解封后该 IP 再次失败仍会被封禁
- **自动解封**: 封禁时长到期后自动解封

## 默认配置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 时间窗口 | 10 秒 | 统计失败次数的时间窗口 |
| 最大尝试次数 | 3 次 | 超过此次数将被封禁 |
| 封禁时长 | 3600 秒 | IP 被封禁的时长（1小时） |

## 安装方法

### 方法一：从 GitHub Actions 下载（推荐）

1. 在 GitHub 仓库的 Actions 页面下载构建好的 ipk 文件
2. 上传到路由器：
   ```bash
   scp luci-app-ssh_guard_*.ipk root@192.168.1.1:/tmp/
   ```
3. SSH 登录路由器安装：
   ```bash
   ssh root@192.168.1.1
   opkg install /tmp/luci-app-ssh_guard_*.ipk
   ```

### 方法二：手动部署

```bash
# 上传文件到路由器
scp root/usr/lib/ssh_guard/ssh_guard.sh root@192.168.1.1:/usr/lib/ssh_guard/
scp root/etc/init.d/ssh_guard root@192.168.1.1:/etc/init.d/
scp luasrc/controller/ssh_guard.lua root@192.168.1.1:/usr/lib/lua/luci/controller/
scp luasrc/model/cbi/ssh_guard.lua root@192.168.1.1:/usr/lib/lua/luci/model/cbi/
scp luasrc/model/ssh_guard.lua root@192.168.1.1:/usr/lib/lua/luci/model/
scp -r luasrc/view/ssh_guard/* root@192.168.1.1:/usr/lib/lua/luci/view/ssh_guard/
scp files/ssh_guard root@192.168.1.1:/etc/config/ssh_guard

# SSH 登录路由器配置
ssh root@192.168.1.1
chmod +x /usr/lib/ssh_guard/ssh_guard.sh /etc/init.d/ssh_guard
/etc/init.d/ssh_guard enable
/etc/init.d/ssh_guard start
rm -rf /tmp/luci-*
/etc/init.d/uhttpd restart
```

## 使用方法

### LuCI 界面

1. 访问路由器 LuCI 界面
2. 进入 **服务** → **SSH 防火墙**
3. 启用插件并设置参数
4. 点击 **状态** 查看已封禁 IP 列表

### 命令行

```bash
# 启动服务
/etc/init.d/ssh_guard start

# 停止服务
/etc/init.d/ssh_guard stop

# 重启服务
/etc/init.d/ssh_guard restart

# 查看状态
/etc/init.d/ssh_guard status

# 查看日志
logread | grep ssh_guard

# 查看被封禁的 IP
cat /tmp/ssh_guard/blacklist

# 查看尝试失败记录
cat /tmp/ssh_guard/attempts

# 临时解封某个 IP（解封后该 IP 再次失败仍会被封禁）
/usr/lib/ssh_guard/ssh_guard.sh temp-unban <IP>

# 永久解封某个 IP
/usr/lib/ssh_guard/ssh_guard.sh unban <IP>
```

## 构建方法

### 使用 GitHub Actions（推荐）

项目已配置 GitHub Actions，push 到 main 分支后会自动构建。

### 本地构建（需要 OpenWrt SDK）

```bash
# 下载对应架构的 SDK
wget https://downloads.openwrt.org/releases/23.05.5/targets/ramips/mt7621/openwrt-sdk-23.05.5-ramips-mt7621_gcc-12.3.0_musl.Linux-x86_64.tar.xz
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*/

# 复制插件并构建
cp Makefile package/luci-app-ssh_guard/
mkdir -p package/luci-app-ssh_guard/files
cp -r ../ipfilter/files/* package/luci-app-ssh_guard/files/
cp -r ../ipfilter/luasrc package/luci-app-ssh_guard/
cp -r ../ipfilter/root/* package/luci-app-ssh_guard/
make package/luci-app-ssh_guard/compile V=sc
```

## 文件结构

```
luci-app-ssh-guard/
├── Makefile                      # OpenWrt 包构建文件
├── files/ssh_guard               # UCI 默认配置
├── luasrc/
│   ├── controller/ssh_guard.lua  # LuCI 控制器
│   ├── model/
│   │   ├── cbi/ssh_guard.lua    # CBI 配置模型
│   │   └── ssh_guard.lua        # 后端模型
│   └── view/ssh_guard/          # 视图模板
│       ├── status.htm           # 状态页面
│       └── actions.htm          # 操作按钮
├── root/
│   ├── etc/init.d/ssh_guard     # 初始化脚本
│   └── usr/lib/ssh_guard/       # 核心脚本
│       └── ssh_guard.sh
└── package_ipk.py              # Python 打包脚本
```

## 兼容性

- OpenWrt 21.02+
- ImmortalWrt
- nftables 防火墙
- iptables 防火墙
- dropbear SSH
- OpenSSH

## 许可证

Apache-2.0
