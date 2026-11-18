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
cp "$PKG_DIR/batocera-minecraft" "$PKG_DIR/batocera-minecraft-mods" "$STAGE/"
cp -R "$PKG_DIR/minecraft" "$STAGE/"
cp "$OVERLAY/etc/openbox/rc.xml" "$STAGE/"
cp -R "$OVERLAY/usr/share/themes/BatoceraNoBorder/." "$STAGE/theme/"
cp "$GEN_DIR"/*.py "$STAGE/generator/"
cp -R "$PKG_DIR/roms/." "$STAGE/roms/"
cp -R "$PKG_DIR/theme/art" "$STAGE/esart"
# The builder's own pictures over the drawn defaults, as the image build does
python3 "$PKG_DIR/apply-artwork.py" "$PKG_DIR/artwork" "$STAGE/esart" "$STAGE/roms"
# Manage Minecraft: its screens (QML, no compiling) and, once an image build
# has compiled it, the program from the build's Docker volume
MANAGER_DIR="$REPO/package/batocera/emulators/minecraft-manager"
cp -R "$MANAGER_DIR/src/qml" "$STAGE/manager-qml"
if docker info >/dev/null 2>&1 && docker run --rm -v batocera-x86_64:/x86_64:ro alpine:3.20 \
        cat /x86_64/target/usr/bin/minecraft-manager > "$STAGE/minecraft-manager" 2>/dev/null; then
    echo "Manage Minecraft: program from the image build's output"
else
    rm -f "$STAGE/minecraft-manager"
    echo "Manage Minecraft: program not built yet (scripts/minecraft-fork/build-on-mac.sh minecraft-manager);"
    echo "  the PC keeps the one it has, or opens Prism Launcher for that entry if it has none"
fi
# The fork's update guard (official updates would replace this build)
mkdir -p "$STAGE/scripts"
cp "$REPO/package/batocera/core/batocera-scripts/scripts/batocera-config" \
   "$REPO/package/batocera/core/batocera-scripts/scripts/batocera-upgrade" "$STAGE/scripts/"
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
install -m 0755 "$D/batocera-minecraft-mods" /usr/bin/batocera-minecraft-mods
rm -rf /usr/share/minecraft-manager/qml
mkdir -p /usr/share/minecraft-manager
cp -R "$D/manager-qml" /usr/share/minecraft-manager/qml
if [ -s "$D/minecraft-manager" ]; then
    install -m 0755 "$D/minecraft-manager" /usr/bin/minecraft-manager
fi
install -m 0755 "$D/scripts/batocera-config" /usr/bin/batocera-config
install -m 0755 "$D/scripts/batocera-upgrade" /usr/bin/batocera-upgrade
# The image's default is off; existing installs keep their own setting, so set it
batocera-settings-set updates.enabled 0
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
cp /userdata/roms/minecraft/gamelist.xml "$D/old-gamelist.xml" 2>/dev/null || true
# Replace the entry images: a renamed or reformatted one must not leave the old file
rm -rf /userdata/roms/minecraft/images
cp -R "$D/roms/." /userdata/roms/minecraft/

# Keep what ES recorded about each entry (play count and time, favorite...):
# from the old gamelist.xml, and from ES's recovery copies of played entries.
# ES only uses a recovery copy while gamelist.xml keeps the size it was made
# against (its parentHash), so a new gamelist.xml would orphan them: merge
# them in and remove them. The repo's own fields (name, image...) win.
python3 - <<'PY'
import glob
import os
import xml.etree.ElementTree as ET

GAMELIST = "/userdata/roms/minecraft/gamelist.xml"
OURS = {"path", "name", "sortname", "desc", "image", "players"}

tree = ET.parse(GAMELIST)
games = {g.findtext("path"): g for g in tree.getroot().iter("game")}
sources = ["/tmp/minecraft-deploy/old-gamelist.xml"]
recovery = sorted(glob.glob("/userdata/system/configs/emulationstation/recovery/minecraft/*.xml"))
kept = 0
for f in sources + recovery:  # recovery last: newer than what ES saved
    if not os.path.exists(f):
        continue
    for old in ET.parse(f).getroot().iter("game"):
        game = games.get(old.findtext("path"))
        if game is None:
            continue
        for el in old:
            if el.tag in OURS:
                continue
            current = game.find(el.tag)
            if current is not None:
                game.remove(current)
            game.append(el)
            kept += 1
ET.indent(tree, space="\t")
tree.write(GAMELIST, encoding="utf-8", xml_declaration=True)
for f in recovery:
    os.remove(f)
if kept or recovery:
    print(f"Kept {kept} recorded values (play stats etc.); merged and removed {len(recovery)} ES recovery file(s)")
PY

# System art for the default theme, where the package installs it. Earlier
# deploys' files go first: the theme picks an .svg logo over a .png one, so a
# stale minecraft.svg would hide a new minecraft.png. (Carbon's own
# collections/Minecraft.* art is in subfolders and stays.)
THEME_ART=/usr/share/emulationstation/themes/es-theme-carbon/art
if [ -d "$THEME_ART" ]; then
    find "$THEME_ART/logos" "$THEME_ART/consoles" "$THEME_ART/background" \
        -maxdepth 1 -type f -name 'minecraft*' -delete 2>/dev/null || true
    cp -R "$D/esart/." "$THEME_ART/"
fi

if [ "$SAVE" = 1 ]; then
    batocera-save-overlay
fi
if [ "$RESTART" = 1 ]; then
    batocera-es-swissknife --restart >/dev/null 2>&1 &
fi

echo "Installed: /usr/bin/batocera-minecraft(-mods), Manage Minecraft, /usr/share/prismlauncher, $CONFIGGEN/generators/prismlauncher, configgen defaults,"
echo "           /etc/openbox/rc.xml, BatoceraNoBorder theme, carbon theme art, update guard, /userdata/roms/minecraft, es_systems_minecraft.cfg"
[ "$SAVE" = 1 ] && echo "Saved to the overlay (survives reboot)." || echo "RAM only: lost on reboot (use --save to keep)."
[ "$RESTART" = 1 ] && echo "Restarting EmulationStation."
rm -rf "$D"
REMOTE
