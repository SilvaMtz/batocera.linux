#!/usr/bin/env bash
# Copy the Minecraft system from this repo onto a running Batocera over SSH,
# to the places an image build would install it, so changes can be tried from
# EmulationStation without building. Not part of the image.
#
# Usage: dev-deploy.sh [--host root@batocera.local] [--save] [--no-restart]
#   --save        keep the copies across reboots (batocera-save-overlay).
#                 This saves everything in the RAM overlay, including the
#                 NVIDIA driver links Batocera makes at boot. Delete the saved
#                 overlay (/boot/boot/overlay) before installing a real build.
#   --no-restart  don't restart EmulationStation afterwards
#
# Copies to /usr and /etc land in Batocera's RAM overlay and are lost on
# reboot unless --save is used. The menu entries go to /userdata/roms/minecraft
# and the system definition to
# /userdata/system/configs/emulationstation/es_systems_minecraft.cfg.
set -euo pipefail

HOST="root@batocera.local"
SAVE=0
RESTART=1

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --host) HOST="$2"; shift 2 ;;
        --save) SAVE=1; shift ;;
        --no-restart) RESTART=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

PKG_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$PKG_DIR" rev-parse --show-toplevel)"
GEN_DIR="$REPO/package/batocera/core/batocera-configgen/configgen/configgen/generators/prismlauncher"
ES_DIR="$REPO/package/batocera/emulationstation/batocera-es-system"
OVERLAY="$REPO/board/batocera/fsoverlay"

VERSION="$(sed -n 's/^PRISMLAUNCHER_VERSION = //p' "$PKG_DIR/prismlauncher.mk")"
SOURCE="$(sed -n 's/^PRISMLAUNCHER_SOURCE = //p' "$PKG_DIR/prismlauncher.mk")"
SHA256="$(awk '$1 == "sha256" {print $2}' "$PKG_DIR/prismlauncher.hash")"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR)

# Stage everything locally, then send it in one archive.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/generator" "$STAGE/roms" "$STAGE/theme"
cp "$PKG_DIR/batocera-minecraft" "$STAGE/"
cp -R "$PKG_DIR/minecraft" "$STAGE/"
cp "$OVERLAY/etc/openbox/rc.xml" "$STAGE/"
cp -R "$OVERLAY/usr/share/themes/BatoceraNoBorder/." "$STAGE/theme/"
cp "$GEN_DIR"/*.py "$STAGE/generator/"
cp -R "$ES_DIR/roms/minecraft/." "$STAGE/roms/"
cp -R "$PKG_DIR/theme/art" "$STAGE/esart"
# The minecraft entries of es_systems.yml and configgen-defaults.yml
# (each up to the next top-level key)
yaml_block() { awk '/^minecraft:$/ {f = 1; print; next} f && /^[A-Za-z0-9_-]+:/ {exit} f' "$1"; }
yaml_block "$ES_DIR/es_systems.yml" > "$STAGE/system.yml"
yaml_block "$REPO/package/batocera/core/batocera-configgen/configs/configgen-defaults.yml" > "$STAGE/defaults.yml"
find "$STAGE" -name '.DS_Store' -delete

echo "Deploying $(git -C "$REPO" rev-parse --short HEAD) ($(git -C "$REPO" status --porcelain | wc -l | tr -d ' ') uncommitted changes) to $HOST"

COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C "$STAGE" -czf - . \
    | ssh "${SSH_OPTS[@]}" "$HOST" \
        'rm -rf /tmp/minecraft-deploy && mkdir -p /tmp/minecraft-deploy && tar -xzf - -C /tmp/minecraft-deploy --no-same-owner'

ssh "${SSH_OPTS[@]}" "$HOST" \
    "VERSION='$VERSION' SOURCE='$SOURCE' SHA256='$SHA256' SAVE='$SAVE' RESTART='$RESTART' bash -s" <<'REMOTE'
set -eu
D=/tmp/minecraft-deploy
export DISPLAY=:0

# End a running session first
if [ -x /usr/bin/batocera-minecraft ]; then /usr/bin/batocera-minecraft stop || true; fi

install -m 0755 "$D/batocera-minecraft" /usr/bin/batocera-minecraft
mkdir -p /usr/share/prismlauncher
rm -rf /usr/share/prismlauncher/minecraft
cp -R "$D/minecraft" /usr/share/prismlauncher/minecraft

CONFIGGEN="$(python3 -c 'import configgen, os; print(os.path.dirname(configgen.__file__))')"
mkdir -p "$CONFIGGEN/generators/prismlauncher"
cp "$D"/generator/*.py "$CONFIGGEN/generators/prismlauncher/"

# Default emulator for the system: replace or add the minecraft block
python3 - <<'PY'
import re
path = "/usr/share/batocera/configgen/configgen-defaults.yml"
text = open(path).read()
block = open("/tmp/minecraft-deploy/defaults.yml").read().rstrip("\n") + "\n"
pattern = re.compile(r"^minecraft:\n(?:[ \t].*\n|\n)*", re.M)
text = pattern.sub(block, text) if pattern.search(text) else text.rstrip("\n") + "\n" + block
open(path, "w").write(text)
PY

install -m 0644 "$D/rc.xml" /etc/openbox/rc.xml
mkdir -p /usr/share/themes/BatoceraNoBorder
cp -R "$D/theme/." /usr/share/themes/BatoceraNoBorder/
openbox --reconfigure 2>/dev/null || true

# Prism AppImage, pinned like the package. It is ~100 MB, so it is kept on
# /userdata and linked into place: the RAM overlay (and a saved overlay,
# 100 MB by default) only gets the small files.
APP=/usr/share/prismlauncher/PrismLauncher.AppImage
STORE=/userdata/system/prism-dev
STORED="$STORE/PrismLauncher-$VERSION.AppImage"
hash_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
mkdir -p "$STORE"
if [ "$(hash_of "$STORED")" != "$SHA256" ]; then
    PROTO=/userdata/system/prism-proto/PrismLauncher.AppImage
    if [ "$(hash_of "$PROTO")" = "$SHA256" ]; then
        cp "$PROTO" "$STORED.part"
    else
        curl -fsSL -o "$STORED.part" "https://github.com/PrismLauncher/PrismLauncher/releases/download/$VERSION/$SOURCE"
        [ "$(hash_of "$STORED.part")" = "$SHA256" ] || { echo "AppImage hash mismatch" >&2; rm -f "$STORED.part"; exit 1; }
    fi
    chmod 0755 "$STORED.part"
    mv "$STORED.part" "$STORED"
fi
rm -f "$APP"
ln -s "$STORED" "$APP"
chmod -R go+rX /usr/share/prismlauncher /usr/share/themes/BatoceraNoBorder

# EmulationStation system definition, generated from the es_systems.yml entry
python3 - <<'PY'
from xml.sax.saxutils import escape
import yaml

d = yaml.safe_load(open("/tmp/minecraft-deploy/system.yml"))["minecraft"]
emulator, cores = next(iter(d["emulators"].items()))
core = next(iter(cores))
ext = " ".join("." + e for e in d["extensions"])
text = lambda k: escape(str(d.get(k) or ""))
xml = f"""<?xml version="1.0"?>
<!-- Written by dev-deploy.sh from es_systems.yml; a real build generates this into es_systems.cfg -->
<systemList>
  <system>
    <fullname>{text("name")}</fullname>
    <name>minecraft</name>
    <manufacturer>{text("manufacturer")}</manufacturer>
    <release>{text("release")}</release>
    <hardware>{text("hardware")}</hardware>
    <path>/userdata/roms/minecraft</path>
    <extension>{ext}</extension>
    <command>emulatorlauncher %CONTROLLERSCONFIG% -system %SYSTEM% -rom %ROM% -gameinfoxml %GAMEINFOXML% -systemname %SYSTEMNAME%</command>
    <platform>{text("platform")}</platform>
    <theme>minecraft</theme>
    <emulators>
      <emulator name="{emulator}">
        <cores>
          <core default="true">{core}</core>
        </cores>
      </emulator>
    </emulators>
  </system>
</systemList>
"""
open("/userdata/system/configs/emulationstation/es_systems_minecraft.cfg", "w").write(xml)
PY

mkdir -p /userdata/roms/minecraft
cp -R "$D/roms/." /userdata/roms/minecraft/

# System art for the default theme, where the package installs it
THEME_ART=/usr/share/emulationstation/themes/es-theme-carbon/art
if [ -d "$THEME_ART" ]; then
    cp -R "$D/esart/." "$THEME_ART/"
fi

if [ "$SAVE" = 1 ]; then
    batocera-save-overlay
fi
if [ "$RESTART" = 1 ]; then
    batocera-es-swissknife --restart >/dev/null 2>&1 &
fi

echo "Installed: /usr/bin/batocera-minecraft, /usr/share/prismlauncher, $CONFIGGEN/generators/prismlauncher, configgen defaults,"
echo "           /etc/openbox/rc.xml, BatoceraNoBorder theme, carbon theme art, /userdata/roms/minecraft, es_systems_minecraft.cfg"
[ "$SAVE" = 1 ] && echo "Saved to the overlay (survives reboot)." || echo "RAM only: lost on reboot (use --save to keep)."
[ "$RESTART" = 1 ] && echo "Restarting EmulationStation."
rm -rf "$D"
REMOTE
