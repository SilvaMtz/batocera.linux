################################################################################
#
# prismlauncher
#
################################################################################

PRISMLAUNCHER_VERSION = 11.1.1
PRISMLAUNCHER_SITE = https://github.com/PrismLauncher/PrismLauncher/releases/download/$(PRISMLAUNCHER_VERSION)
PRISMLAUNCHER_SOURCE = PrismLauncher-Linux-x86_64.AppImage
PRISMLAUNCHER_LICENSE = GPL-3.0
PRISMLAUNCHER_EMULATOR_INFO = prismlauncher.emulator.yml

define PRISMLAUNCHER_EXTRACT_CMDS
	cp $(PRISMLAUNCHER_DL_DIR)/$(PRISMLAUNCHER_SOURCE) $(@D)/
endef

define PRISMLAUNCHER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/prismlauncher
	$(INSTALL) -m 0755 $(@D)/$(PRISMLAUNCHER_SOURCE) \
	    $(TARGET_DIR)/usr/share/prismlauncher/PrismLauncher.AppImage
	cp -pr $(PRISMLAUNCHER_PKGDIR)/minecraft $(TARGET_DIR)/usr/share/prismlauncher/
	$(INSTALL) -D -m 0755 $(PRISMLAUNCHER_PKGDIR)/batocera-minecraft \
	    $(TARGET_DIR)/usr/bin/batocera-minecraft
	# system art for the default theme (logos, carousel block, background)
	mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art
	cp -pr $(PRISMLAUNCHER_PKGDIR)/theme/art/* \
	    $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art/
endef

$(eval $(generic-package))
$(eval $(emulator-info-package))
