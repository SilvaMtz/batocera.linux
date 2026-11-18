# Minecraft system (Prism Launcher)

Adds a root-level **Minecraft** system to EmulationStation. Prism Launcher is
the backend; `batocera-minecraft` launches each menu entry and places the
windows. Design doc: https://claude.ai/artifact/B9PkUHMB61vRypjDCRRFQw

## Pieces

| Piece | Path |
|---|---|
| Prism AppImage 11.1.1 (pinned, sha256 in `prismlauncher.hash`) | this package, installed to `/usr/share/prismlauncher/` |
| Launcher script | `batocera-minecraft`, installed to `/usr/bin/` |
| Instance templates P1/P2, Prism defaults | `minecraft/`, installed to `/usr/share/prismlauncher/minecraft/` |
| configgen generator | `package/batocera/core/batocera-configgen/configgen/configgen/generators/prismlauncher/` |
| System entry | `minecraft` in `batocera-es-system/es_systems.yml` |
| Menu entries | `batocera-es-system/roms/minecraft/` (copied to `/userdata/roms/minecraft/` on first boot only) |
| Openbox rule and borderless theme | `board/batocera/fsoverlay/etc/openbox/rc.xml`, `board/batocera/fsoverlay/usr/share/themes/BatoceraNoBorder/` |
| Kconfig | `BR2_PACKAGE_PRISMLAUNCHER`, selected by `BR2_PACKAGE_BATOCERA_MINECRAFT_SYSTEMS` on x86_64 |
| NVIDIA driver on by default | `nvidia-driver=true` in `batocera-boot.conf` |

## Menu entries

Each `.minecraft` file holds one word, the mode passed to `batocera-minecraft`:

- `singleplayer`: P1 with Prism's default account, full screen.
- `splitscreen`: P1 (Microsoft account) on the left. When P1 opens its world
  to LAN, P2 joins with the offline account `Player2` through
  `--profile Player2 --server 127.0.0.1:<port>` and goes on the right. When one
  player quits, the other window takes the whole screen. With no Microsoft
  account yet, Prism's window opens instead.
- `prism`: Prism's own window, for Microsoft sign-in and management.

`batocera-minecraft stop` is the hotkey exit.

## Data

Prism uses `/userdata/system/configs/prismlauncher`. On first use the script
copies the P1/P2 templates, merges `prismlauncher.cfg` defaults, adds the
offline account to `accounts.json` (only while Prism is closed) and downloads
missing mods listed in `mods/.index/*.pw.toml` (sha512 checked). Mod jars,
resource packs and accounts are never stored in the image.

Instances: Minecraft 26.3, Fabric 0.20.1, Fabric API, Controlify, Sodium,
Iris, Cull Leaves, YACL, FerriteCore; P1 also has LAN World Plug-n-Play
(online mode off, UPnP off, port 25565). Options: GUI scale 2, render distance
12, F11 unbound, no pause on lost focus. 3 GB heap each.

## Tested on the target PC (2026-11-17, stock 43.1 + this script over SSH)

- Single Player: full screen 1920x1080, focus returned to EmulationStation on exit.
- Split Screen: P2 joined P1's world automatically once LAN opened; P1 expanded
  and rendered full screen when P2 quit; the script exited when P1 quit.
- No GPU errors with the riser's slot set to **PCIe x16 Link Speed = Gen4** in
  the BIOS. Gen5 over the riser caused GPU hangs (Xid 31/119).

## Iterating without building an image

Edit in this repo only; the PC just receives copies.

1. **Script only** (seconds): copy `batocera-minecraft` and `minecraft/` to the
   PC and run a mode over SSH:

   ```
   MINECRAFT_APPIMAGE=/path/PrismLauncher.AppImage MINECRAFT_TEMPLATE=/path/minecraft \
   DISPLAY=:0 python3 batocera-minecraft splitscreen
   ```

2. **Through EmulationStation** (a minute): from the Mac, run

   ```
   package/batocera/emulators/prismlauncher/dev-deploy.sh [--host root@batocera.local] [--save] [--no-restart]
   ```

   It copies the script, templates, AppImage (pinned hash), generator,
   configgen default, Openbox rule and theme to where a build installs them,
   writes `es_systems_minecraft.cfg` from the `es_systems.yml` entry, copies the
   menu entries to `/userdata/roms/minecraft` and restarts EmulationStation.
   Copies to `/usr` and `/etc` are RAM-only unless `--save` runs
   `batocera-save-overlay`; delete that overlay before installing a real build.
   Launch from the menu, or over SSH with
   `curl -d "/userdata/roms/minecraft/Single Player.minecraft" http://127.0.0.1:1234/launch`.

3. **Image build** (hours): at milestones, build the fork and install it on
   the PC by replacing the boot files; `/userdata` is kept.

Logs: `/userdata/system/logs/minecraft.log`, `es_launch_stdout.log` /
`es_launch_stderr.log` in the same folder, each instance's
`minecraft/logs/latest.log`, and `dmesg | grep Xid` for GPU errors.

## Not done yet

- The world does not open to LAN by itself; P1 uses World Options and
  Apply Changes (that screen is cut off at half width). Planned: a small
  auto-LAN client mod for P1.
- Controllers: Controlify binds a profile to `md5(vendor id + product id + serial)`;
  P2 falls back to the first controller if its own is missing. Set up by hand for now.
- Manage Minecraft UI, Minecraft Launcher entry and the account pickers.
- Prism's main window and a progress dialog show briefly while a game starts.
- The image has not been built yet (no build machine set up).
