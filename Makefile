include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-netlock
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=haizi

LUCI_TITLE:=LuCI NetLock - Presence-based Network Control
LUCI_DESCRIPTION:=Intelligent network lock that blocks internet for all LAN clients when designated anchor device is absent from WiFi
LUCI_DEPENDS:=+nftables +iwinfo
LUCI_PKGARCH:=all

PKG_PO_VERSION:=$(PKG_VERSION)-$(PKG_RELEASE)

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-netlock/conffiles
/etc/config/netlock
endef

define Package/luci-app-netlock/install
	# LuCI JS views
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/netlock
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/view/*.js \
		$(1)/www/luci-static/resources/view/netlock/

	# UCI default config
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/src/config/netlock $(1)/etc/config/

	# procd init script
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/init/netlock $(1)/etc/init.d/

	# UCI defaults (first-boot)
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/uci-defaults/50-luci-netlock $(1)/etc/uci-defaults/

	# Main daemon
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/bin/netlock $(1)/usr/sbin/

	# rpcd backend
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/rpcd/netlock $(1)/usr/libexec/rpcd/

	# LuCI menu registration
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/share/menu.d/luci-app-netlock.json \
		$(1)/usr/share/luci/menu.d/

	# rpcd ACL
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/src/share/acl.d/luci-app-netlock.json \
		$(1)/usr/share/rpcd/acl.d/
endef

define Package/luci-app-netlock/poinstall
	# Install PO-compiled .lmo translation files
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	for lang in $$(ls $(PKG_BUILD_DIR)/src/i18n/ 2>/dev/null | grep -v templates); do \
		if [ -f "$(PKG_BUILD_DIR)/src/i18n/$$lang/netlock.po" ]; then \
			po2lmo $(PKG_BUILD_DIR)/src/i18n/$$lang/netlock.po \
				$(1)/usr/lib/lua/luci/i18n/netlock.$$lang.lmo 2>/dev/null || true; \
		fi; \
	done
endef

$(eval $(call BuildPackage,luci-app-netlock))
