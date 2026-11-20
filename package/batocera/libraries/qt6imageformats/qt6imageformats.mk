################################################################################
#
# qt6imageformats
#
################################################################################

# Not in Batocera's Buildroot (43.1); written like its qt6svg package. Only
# the WebP plugin, against the system libwebp: Manage Minecraft shows
# Modrinth's icons, most of which are WebP.
QT6IMAGEFORMATS_VERSION = $(QT6_VERSION)
QT6IMAGEFORMATS_SITE = $(QT6_SITE)
QT6IMAGEFORMATS_SOURCE = qtimageformats-$(QT6_SOURCE_TARBALL_PREFIX)-$(QT6IMAGEFORMATS_VERSION).tar.xz
QT6IMAGEFORMATS_INSTALL_STAGING = YES
QT6IMAGEFORMATS_SUPPORTS_IN_SOURCE_BUILD = NO

QT6IMAGEFORMATS_CMAKE_BACKEND = ninja

QT6IMAGEFORMATS_LICENSE = GPL-2.0+ or LGPL-3.0, GFDL-1.3 (docs), BSD-3-Clause
QT6IMAGEFORMATS_LICENSE_FILES = \
	LICENSES/BSD-3-Clause.txt \
	LICENSES/GFDL-1.3-no-invariants-only.txt \
	LICENSES/GPL-2.0-only.txt \
	LICENSES/GPL-3.0-only.txt \
	LICENSES/LGPL-3.0-only.txt

QT6IMAGEFORMATS_CONF_OPTS = \
	-DQT_HOST_PATH=$(HOST_DIR) \
	-DBUILD_WITH_PCH=OFF \
	-DQT_BUILD_EXAMPLES=OFF \
	-DQT_BUILD_TESTS=OFF \
	-DFEATURE_webp=ON \
	-DFEATURE_system_webp=ON \
	-DFEATURE_tiff=OFF \
	-DFEATURE_mng=OFF \
	-DFEATURE_jasper=OFF
# (The ICNS, TGA and WBMP plugins have no switch and no dependencies: they
# are built too, about 130 KB.)

QT6IMAGEFORMATS_DEPENDENCIES = \
	host-pkgconf \
	qt6base \
	webp

$(eval $(cmake-package))
