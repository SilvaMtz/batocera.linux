################################################################################
#
# minecraft-manager
#
################################################################################

# Manage Minecraft: a small Qt 6 program (src/) whose screens are QML files
# read at startup, installed to /usr/share/minecraft-manager/qml.
MINECRAFT_MANAGER_VERSION = 1.0
MINECRAFT_MANAGER_SITE = $(BR2_EXTERNAL_BATOCERA_PATH)/package/batocera/emulators/minecraft-manager/src
MINECRAFT_MANAGER_SITE_METHOD = local
MINECRAFT_MANAGER_DEPENDENCIES = qt6base qt6declarative sdl2
# Qt's host tools (moc) come from the host directory, as Buildroot's Qt modules do it
MINECRAFT_MANAGER_CONF_OPTS = -DQT_HOST_PATH=$(HOST_DIR) -DCMAKE_BUILD_TYPE=Release

$(eval $(cmake-package))
