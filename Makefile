#
# Copyright (C) 2024 OpenWrt
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-ssh_guard
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=OpenWrt

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-ssh_guard
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=SSH Guard - Auto-ban SSH attackers
  PKGARCH:=all
  DEPENDS:=+iptables +logread
endef

define Package/luci-app-ssh_guard/description
  A LuCI application that monitors SSH authentication failures and automatically bans IPs
  that exceed a configurable threshold within a specified time window.
  Default: 10 seconds window, 3 max attempts.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-ssh_guard/conffiles
/etc/config/ssh_guard
endef

define Package/luci-app-ssh_guard/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/ssh_guard $(1)/etc/config/ssh_guard

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./root/etc/init.d/ssh_guard $(1)/etc/init.d/ssh_guard

	$(INSTALL_DIR) $(1)/usr/lib/ssh_guard
	$(INSTALL_BIN) ./root/usr/lib/ssh_guard/ssh_guard.sh $(1)/usr/lib/ssh_guard/ssh_guard.sh

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-ssh-guard.json $(1)/usr/share/rpcd/acl.d/luci-ssh-guard.json

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/ssh_guard.lua $(1)/usr/lib/lua/luci/controller/ssh_guard.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/ssh_guard.lua $(1)/usr/lib/lua/luci/model/cbi/ssh_guard.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model
	$(INSTALL_DATA) ./luasrc/model/ssh_guard.lua $(1)/usr/lib/lua/luci/model/ssh_guard.lua

	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/ssh_guard
	$(INSTALL_DATA) ./luasrc/view/ssh_guard/status.htm $(1)/usr/lib/lua/luci/view/ssh_guard/status.htm
	$(INSTALL_DATA) ./luasrc/view/ssh_guard/actions.htm $(1)/usr/lib/lua/luci/view/ssh_guard/actions.htm
endef

$(eval $(call BuildPackage,luci-app-ssh_guard))
