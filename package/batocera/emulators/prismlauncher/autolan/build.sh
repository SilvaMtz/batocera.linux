#!/usr/bin/env bash
# Build batocera-autolan.jar. Minecraft 26.x is not obfuscated, so plain
# javac against the game jar works; no Gradle or Loom needed.
#
# Usage: build.sh <prism data dir> [java home]
#   <prism data dir>  a Prism folder that has run the P1 instance (it holds the
#                     26.3 client jar, its libraries and Fabric API), e.g.
#                     /userdata/system/configs/prismlauncher on the PC
#   [java home]       a JDK 25; defaults to Prism's own runtime there
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PRISM="${1:?prism data dir}"
JAVA_HOME="${2:-$PRISM/java/java-runtime-epsilon}"
OUT="$HERE/../minecraft/instances/P1/minecraft/mods/batocera-autolan.jar"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Fabric API keeps its modules as nested jars
FAPI="$(ls "$PRISM"/instances/P1/minecraft/mods/fabric-api-*.jar | head -1)"
(cd "$WORK" && "$JAVA_HOME/bin/jar" xf "$FAPI" META-INF/jars)

CP="$(find "$PRISM/libraries" "$WORK/META-INF/jars" -name '*.jar' | tr '\n' ':')"
mkdir -p "$WORK/classes"
"$JAVA_HOME/bin/javac" --release 25 -nowarn -cp "$CP" -d "$WORK/classes" \
    $(find "$HERE/src" -name '*.java')
cp "$HERE/resources/fabric.mod.json" "$WORK/classes/"
"$JAVA_HOME/bin/jar" --create --file "$OUT" --date 2026-01-01T00:00:00Z -C "$WORK/classes" .
echo "built $OUT"
