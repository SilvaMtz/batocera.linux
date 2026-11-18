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
# apply-artwork.py
PRISMLAUNCHER_DEPENDENCIES = host-python3

PRISMLAUNCHER_THEME_ART = $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-carbon/art
PRISMLAUNCHER_ROMS = $(TARGET_DIR)/usr/share/batocera/datainit/roms/minecraft

define PRISMLAUNCHER_EXTRACT_CMDS
	cp $(PRISMLAUNCHER_DL_DIR)/$(PRISMLAUNCHER_SOURCE) $(@D)/
endef

# Menu entries and system art: the drawn defaults, with the builder's own
# pictures from artwork/ (kept out of Git) put over them.
define PRISMLAUNCHER_BUILD_CMDS
	rm -rf $(@D)/art $(@D)/roms
	cp -pr $(PRISMLAUNCHER_PKGDIR)/theme/art $(@D)/art
	cp -pr $(PRISMLAUNCHER_PKGDIR)/roms $(@D)/roms
	$(HOST_DIR)/bin/python3 $(PRISMLAUNCHER_PKGDIR)/apply-artwork.py \
	    $(PRISMLAUNCHER_PKGDIR)/artwork $(@D)/art $(@D)/roms
endef

define PRISMLAUNCHER_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/prismlauncher
	$(INSTALL) -m 0755 $(@D)/$(PRISMLAUNCHER_SOURCE) \
	    $(TARGET_DIR)/usr/share/prismlauncher/PrismLauncher.AppImage
	cp -pr $(PRISMLAUNCHER_PKGDIR)/minecraft $(TARGET_DIR)/usr/share/prismlauncher/
	$(INSTALL) -D -m 0755 $(PRISMLAUNCHER_PKGDIR)/batocera-minecraft \
	    $(TARGET_DIR)/usr/bin/batocera-minecraft
	# System art for the default theme (logo, carousel block, wallpaper).
	# Earlier installs' files go first: the theme shows an .svg logo over a
	# .png one. (Carbon's own collections/Minecraft.* art is in subfolders.)
	for d in logos consoles background; do \
	    mkdir -p $(PRISMLAUNCHER_THEME_ART)/$$d; \
	    find $(PRISMLAUNCHER_THEME_ART)/$$d -maxdepth 1 -type f -name 'minecraft*' -delete; \
	done
	cp -pr $(@D)/art/. $(PRISMLAUNCHER_THEME_ART)/
	# Menu entries, copied to /userdata/roms/minecraft on first boot.
	# batocera-es-system only adds _info.txt to this folder.
	mkdir -p $(PRISMLAUNCHER_ROMS)
	rm -rf $(PRISMLAUNCHER_ROMS)/images
	cp -pr $(@D)/roms/. $(PRISMLAUNCHER_ROMS)/
endef

$(eval $(generic-package))
$(eval $(emulator-info-package))
