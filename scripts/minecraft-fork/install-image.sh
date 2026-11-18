#!/usr/bin/env bash
# Install a build of this fork on the Batocera PC, with a rollback backup.
# Run from the Mac. /userdata (worlds, accounts, settings) is kept.
#
# Usage:
#   install-image.sh [--host root@batocera.local] [--boot-tar PATH] [--reboot]
#   install-image.sh [--host ...] --rollback BACKUP.tar [--reboot]
#   install-image.sh [--host ...] --list-backups
#
# Install:
#   1. Takes boot.tar.xz (and its .md5) from the build's Docker volume
#      (batocera-x86_64, see build-on-mac.sh), or from --boot-tar.
#   2. Saves the PC's whole boot partition to
#      /userdata/system/boot-backups/boot-<date>.tar, including the saved
#      dev-deploy overlay, then removes that overlay (it would sit on top of
#      the new image).
#   3. Runs Batocera's own installer: batocera-upgrade manual (keeps
#      batocera-boot.conf, cleans stale files on the next boot).
# Rollback:
#   Restores a boot backup over /boot. Needs the PC to boot and answer SSH;
#   if the new image does not boot at all, boot a stock Batocera USB stick
#   and extract the backup over the NVMe's first partition by hand.
set -euo pipefail

HOST="root@batocera.local"
BOOT_TAR=""
ROLLBACK=""
LIST=0
REBOOT=0
VOLUME="batocera-x86_64"
IMAGE_DIR="/x86_64/images/batocera/images/x86_64"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --host) HOST="$2"; shift 2 ;;
        --boot-tar) BOOT_TAR="$2"; shift 2 ;;
        --rollback) ROLLBACK="$2"; shift 2 ;;
        --list-backups) LIST=1; shift ;;
        --reboot) REBOOT=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=10 -o LogLevel=ERROR "$HOST")

if [ "$LIST" = 1 ]; then
    "${SSH[@]}" 'ls -lh /userdata/system/boot-backups/ 2>/dev/null || echo "no backups yet"'
    exit 0
fi

reboot_if_asked() {
    if [ "$REBOOT" = 1 ]; then
        echo "Rebooting the PC..."
        "${SSH[@]}" 'sync; (sleep 1; reboot) >/dev/null 2>&1 &'
    else
        echo "Reboot the PC to start it (or rerun with --reboot)."
    fi
}

if [ -n "$ROLLBACK" ]; then
    echo "Restoring $ROLLBACK over /boot on $HOST"
    "${SSH[@]}" "BACKUP='$ROLLBACK' bash -s" <<'REMOTE'
set -eu
test -f "$BACKUP" || { echo "No such backup: $BACKUP" >&2; exit 1; }
# Never clear /boot unless the backup reads cleanly and has a system in it
tar -tf "$BACKUP" > /tmp/boot-backup.list || { echo "Backup is unreadable" >&2; exit 1; }
grep -qx "./boot/batocera" /tmp/boot-backup.list || { echo "Backup has no boot/batocera" >&2; exit 1; }
mount -o remount,rw /boot
# Remove what the newer install added, then put the old partition back
find /boot -mindepth 1 -maxdepth 1 -exec rm -rf {} +
tar -xf "$BACKUP" -C /boot --no-same-owner
sync
mount -o remount,ro /boot
echo "Boot partition restored from $BACKUP"
REMOTE
    reboot_if_asked
    exit 0
fi

# ------------------------------------------------------------------ install

echo "Checking the PC..."
"${SSH[@]}" 'mkdir -p /userdata/system/upgrade /userdata/system/boot-backups; df -m /userdata | tail -1 | awk "{print \"userdata free: \" \$4 \" MB\"}"'

echo "Sending boot.tar.xz to the PC..."
if [ -n "$BOOT_TAR" ]; then
    "${SSH[@]}" 'cat > /userdata/system/upgrade/boot.tar.xz' < "$BOOT_TAR"
    if [ -f "$BOOT_TAR.md5" ]; then
        "${SSH[@]}" 'cat > /userdata/system/upgrade/boot.tar.xz.md5' < "$BOOT_TAR.md5"
    fi
else
    docker run --rm -v "$VOLUME:/x86_64:ro" alpine:3.20 cat "$IMAGE_DIR/boot.tar.xz" \
        | "${SSH[@]}" 'cat > /userdata/system/upgrade/boot.tar.xz'
    docker run --rm -v "$VOLUME:/x86_64:ro" alpine:3.20 cat "$IMAGE_DIR/boot.tar.xz.md5" \
        | "${SSH[@]}" 'cat > /userdata/system/upgrade/boot.tar.xz.md5'
fi

"${SSH[@]}" 'bash -s' <<'REMOTE'
set -eu
U=/userdata/system/upgrade
if [ -f "$U/boot.tar.xz.md5" ]; then
    [ "$(md5sum "$U/boot.tar.xz" | cut -d" " -f1)" = "$(cat "$U/boot.tar.xz.md5")" ] \
        || { echo "Checksum mismatch: transfer failed" >&2; exit 1; }
    echo "Checksum OK"
fi

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP=/userdata/system/boot-backups/boot-$STAMP.tar
echo "Backing up the boot partition to $BACKUP ..."
tar -cf "$BACKUP" -C /boot .
echo "Backup size: $(du -h "$BACKUP" | cut -f1)"

mount -o remount,rw /boot
if [ -e /boot/boot/overlay ]; then
    # Already inside the backup; the new image must not start with it
    rm -f /boot/boot/overlay
    echo "Removed the saved dev-deploy overlay (kept in the backup)"
fi
mount -o remount,ro /boot

echo "Installing with batocera-upgrade manual ..."
batocera-upgrade manual
echo "Rollback, if needed: install-image.sh --rollback $BACKUP"
REMOTE

reboot_if_asked
