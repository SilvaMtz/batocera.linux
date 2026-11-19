################################################################################
#
# rclone
#
################################################################################

RCLONE_VERSION = v1.72.1
RCLONE_SITE = $(call github,rclone,rclone,$(RCLONE_VERSION))
RCLONE_LICENSE = GPLv2
RCLONE_DEPENDENCIES =

define RCLONE_BUILD_CMDS
	cd $(@D) && $(HOST_GO_TARGET_ENV) $(GO_BIN) build
endef

define RCLONE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	$(INSTALL) -D $(@D)/rclone $(TARGET_DIR)/usr/bin/rclone
endef

$(eval $(golang-package))
# One of rclone's modules, goftp.io/server/v2, is no longer served from
# goftp.io; Go's module proxy still has it. (After the eval, so it wins over
# the golang-package's GOPROXY=direct.)
RCLONE_DL_ENV += GOPROXY=https://proxy.golang.org,direct
