#!/usr/bin/env bash
# Build this fork's x86_64 image on an Apple Silicon Mac with Docker Desktop.
#
# Usage: build-on-mac.sh [--clean] [--log PATH] [PKG...]
#   (no PKG)  full build: defconfig, then everything
#   PKG...    rebuild only these packages, then the image, e.g.
#             build-on-mac.sh prismlauncher   (after changing the Minecraft package)
#   --clean   wipe the build output volume first (downloads and ccache are kept)
#   --log     log file (default /Volumes/batocera-build/build.log if that
#             volume is mounted, otherwise ./build.log)
#
# Why it looks like this (each one failed first):
#   * Batocera's published build image is for its development branch (Ubuntu
#     26.04, GCC 15). This 43.1-based fork needs its own Dockerfile (Ubuntu
#     22.04, GCC 11), built as batocera-local/build-43.
#   * That image is x86_64 (gcc-multilib), so it runs through Rosetta.
#     Docker Desktop's "Use Rosetta for x86_64/amd64 emulation" must be on.
#   * Output, downloads and ccache live on Docker volumes. Folders shared from
#     macOS have unstable inode numbers and GNU tar aborts ("Directory renamed
#     before its status could be extracted").
#   * The volumes belong to the Mac user's uid/gid and keep a .keep file:
#     Docker resets an empty volume's owner to root on every mount.
#   * Rust packages resolve crates at download time when they have no
#     Cargo.lock; CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS=fallback keeps
#     them compatible with 43.1's rustc (newest crates need a newer one).
#   * Under Rosetta, a make started by something other than make (fluidsynth's
#     and Kodi's nested builds) stopped with "write jobserver: Bad file
#     descriptor". build-image/ adds a make wrapper on top of
#     batocera-local/build-43 (as batocera-local/build-43-mac); see
#     build-image/make-wrapper.
#   * Rosetta ignores mmap's MAP_32BIT. The build's own Mono (host-mono)
#     counts on it for short jumps on x86_64 Linux and aborted with "should
#     not be reached at tramp-amd64.c". It is built like Mono on every other
#     system, with MONO_ARCH_NOMAP32BIT. The PC's Mono is unchanged.
#
# The images end up in the batocera-x86_64 volume under
# /x86_64/images/batocera/images/x86_64/; install-image.sh sends them to the PC.
set -euo pipefail

REPO="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
IMAGE="batocera-local/build-43:latest"
MAC_IMAGE="batocera-local/build-43-mac:latest"
OUT_VOL="batocera-x86_64"
DL_VOL="batocera-dl"
CCACHE_VOL="batocera-ccache"
CLEAN=0
LOG=""
PKGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --clean) CLEAN=1; shift ;;
        --log) LOG="$2"; shift 2 ;;
        -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "unknown option $1" >&2; exit 2 ;;
        *) PKGS+=("$1"); shift ;;
    esac
done

if [ -z "$LOG" ]; then
    if [ -d /Volumes/batocera-build ]; then LOG=/Volumes/batocera-build/build.log; else LOG="$PWD/build.log"; fi
fi

docker info >/dev/null 2>&1 || { echo "Docker Desktop is not running" >&2; exit 1; }

# 1. The 43.1 build environment
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Building $IMAGE from the fork's Dockerfile (a few minutes)..."
    docker build --platform linux/amd64 -t "$IMAGE" "$REPO"
fi
# ...plus the make wrapper for Rosetta (Docker's cache makes this instant)
docker build -q --platform linux/amd64 --build-arg BASE="$IMAGE" \
    -t "$MAC_IMAGE" "$REPO/scripts/minecraft-fork/build-image" >/dev/null

# 2. Volumes owned by this user, never left empty
U="$(id -u)"; G="$(id -g)"
if [ "$CLEAN" = 1 ]; then
    echo "Wiping $OUT_VOL ..."
    docker volume rm "$OUT_VOL" >/dev/null 2>&1 || true
fi
for v in "$OUT_VOL" "$DL_VOL" "$CCACHE_VOL"; do
    docker volume create "$v" >/dev/null
    docker run --rm --platform linux/amd64 -v "$v:/v" "$IMAGE" \
        sh -c "touch /v/.keep && chown $U:$G /v /v/.keep"
done

# 3. The defconfig is generated from configs/batocera-x86_64.board (+ common)
touch "$REPO/configs/.user_defconfig"
"$REPO/configs/createDefconfig.sh" "$REPO/configs/batocera-x86_64.board" \
    "$REPO/configs/.user_defconfig" "$REPO/configs/batocera-x86_64_defconfig"

RUN=(docker run -t --init --rm --platform linux/amd64
     -e HOME="$HOME"
     # Rust packages without a Cargo.lock get their crates resolved at
     # download time; today's newest crates need a newer rustc than 43.1's
     # 1.92. "fallback" picks the newest versions that still work with it.
     -e CARGO_RESOLVER_INCOMPATIBLE_RUST_VERSIONS=fallback
     -v "$REPO:/build"
     -v "$DL_VOL:/build/buildroot/dl"
     -v "$OUT_VOL:/x86_64"
     -v "$CCACHE_VOL:$HOME/.buildroot-ccache"
     -w /x86_64
     -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro
     -u "$U:$G" "$MAC_IMAGE")
BR=(make O=/x86_64 BR2_EXTERNAL=/build -C /build/buildroot
    # host-mono without MAP_32BIT (see above); make expands $(HOST_CPPFLAGS)
    'HOST_MONO_CONF_ENV=CPPFLAGS="$(HOST_CPPFLAGS) -DMONO_ARCH_NOMAP32BIT=1"')

echo "build started $(date '+%Y-%m-%d %H:%M') at $(git -C "$REPO" rev-parse --short HEAD) ${PKGS[*]:-(full)}" > "$LOG"
echo "Logging to $LOG"

status=0
{
    "${RUN[@]}" "${BR[@]}" batocera-x86_64_defconfig
    if [ ${#PKGS[@]} -gt 0 ]; then
        for p in "${PKGS[@]}"; do "${RUN[@]}" "${BR[@]}" "$p-dirclean" "$p"; done
    fi
    "${RUN[@]}" "${BR[@]}"
} >> "$LOG" 2>&1 || status=$?

echo "BUILD EXIT CODE: $status at $(date '+%H:%M')" >> "$LOG"
if [ "$status" = 0 ]; then
    docker run --rm -v "$OUT_VOL:/x86_64:ro" alpine:3.20 ls -lh /x86_64/images/batocera/images/x86_64/
fi
exit "$status"
