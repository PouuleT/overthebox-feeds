include $(TOPDIR)/rules.mk

PKG_NAME:=otb-debug
PKG_VERSION:=0.6
PKG_RELEASE:=0

include $(INCLUDE_DIR)/package.mk

MY_DEPENDS := overthebox TARGET_x86:python-swconfig-otb \
	kmod-fs-ext4 kmod-fs-hfsplus kmod-fs-vfat \
	fuse-utils luci-app-samba samba36-server \
	luci-app-statistics \
	htop bmon rsync netcat svfs screen

define Package/$(PKG_NAME)
SECTION:=OVH
CATEGORY:=OverTheBox
DEPENDS:=$(foreach p,$(MY_DEPENDS),+$(p))
TITLE:=$(PKG_NAME)
PKGARCH:=all
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc
	echo "$(PKG_VERSION)-$(PKG_RELEASE)+$(PKG_NAME)" > $(1)/etc/otb-version
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
