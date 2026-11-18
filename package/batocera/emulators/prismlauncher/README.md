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
| Auto-LAN mod (source, build script; jar in P1's template) | `autolan/` |
| System art (logos, carousel block, background) for es-theme-carbon, and its generator | `theme/`, installed to `/usr/share/emulationstation/themes/es-theme-carbon/art/` |
| Your own logo, wallpaper and entry pictures (not in Git) | `artwork/`, applied by `apply-artwork.py` |
| configgen generator | `package/batocera/core/batocera-configgen/configgen/configgen/generators/prismlauncher/` |
| System entry | `minecraft` in `batocera-es-system/es_systems.yml` |
| Menu entries and their default images | `roms/`, installed to `/usr/share/batocera/datainit/roms/minecraft/` (copied to `/userdata/roms/minecraft/` on first boot only). Kept in this package rather than `batocera-es-system/roms/` so the pictures can be applied in one place: the two packages install in no fixed order. |
| Openbox rule and borderless theme | `board/batocera/fsoverlay/etc/openbox/rc.xml`, `board/batocera/fsoverlay/usr/share/themes/BatoceraNoBorder/` |
| Kconfig | `BR2_PACKAGE_PRISMLAUNCHER`, selected by `BR2_PACKAGE_BATOCERA_MINECRAFT_SYSTEMS` on x86_64 |
| NVIDIA driver on by default | `nvidia-driver=true` in `batocera-boot.conf` |

## Menu entries

Each `.minecraft` file holds one word, the mode passed to `batocera-minecraft`:

- `singleplayer`: P1 with Prism's default account, full screen.
- `splitscreen`: P1 (Microsoft account) on the left picks or creates a world.
  The auto-LAN mod opens it to LAN on port 25565 with online mode off as soon
  as P1 joins, and P2 joins with the offline account `Player2` through
  `--profile Player2 --server 127.0.0.1:25565` on the right. When one player
  quits, the other window takes the whole screen. With no Microsoft account
  yet, Prism's window opens instead.
- `prism`: Prism's own window, for Microsoft sign-in and management.

`batocera-minecraft stop` is the hotkey exit.

For Single Player and Split Screen, Prism runs with `QT_QPA_PLATFORM=offscreen`:
it works but draws no window, so nothing flashes before the game. If a game
does not appear within 4 minutes (Prism stuck on a hidden dialog, such as an
expired sign-in), the script closes it and opens Prism visibly instead. The
Prism Launcher entry always shows Prism.

## Data

Prism uses `/userdata/system/configs/prismlauncher`. On each launch the script
copies missing P1/P2 templates, merges `prismlauncher.cfg` defaults, forces
`auto_check=false` in `prismlauncher_update.cfg` (the AppImage is pinned, so
Prism must never update itself), adds the
offline account to `accounts.json` (only while Prism is closed) and downloads
missing mods listed in `mods/.index/*.pw.toml` (sha512 checked). Third-party
mod jars, resource packs and accounts are never stored in the image; only our
own auto-LAN jar is, and the script copies it into P1 when missing or changed.

Instances: Minecraft 26.3, Fabric 0.20.1, Fabric API, Controlify, Sodium,
Iris, Cull Leaves, YACL, FerriteCore; P1 also has the auto-LAN mod. Options:
GUI scale 2, render distance 12, F11 unbound, no pause on lost focus. 3 GB
heap each.

## Auto-LAN mod

`autolan/` is a small Fabric client mod for P1. When the player joins a
single-player world it turns online mode off and opens the world to LAN, but
only if `config/batocera-autolan.json` says `"enabled": true`. The script
writes that file before each launch: enabled for Split Screen, disabled for
Single Player and the Prism window, so a normal Single Player world is never
reachable from the network.

Minecraft 26.x is not obfuscated, so it builds with plain `javac` against the
game jar (no Gradle/Loom):

```
autolan/build.sh /userdata/system/configs/prismlauncher   # on the PC, after P1 has run once
```

The jar lands in `minecraft/instances/P1/minecraft/mods/batocera-autolan.jar`;
commit it with the source.

## Tested on the target PC (2026-11-17, stock 43.1 + this script over SSH)

- Single Player: full screen 1920x1080, focus returned to EmulationStation on exit.
- Split Screen, launched from EmulationStation: the auto-LAN mod opened P1's
  world in the second it loaded, P2 joined about 11 seconds later with no menus
  touched; P1 expanded and rendered full screen when P2 quit; the session
  returned to EmulationStation when P1 quit.
- Single Player with the mod installed: the world loaded and nothing listened
  on port 25565.
- No GPU errors with the riser's slot set to **PCIe x16 Link Speed = Gen4** in
  the BIOS. Gen5 over the riser caused GPU hangs (Xid 31/119).

## Artwork

Two layers:

- **Drawn defaults**, in Git: `theme/make-art.py` draws the logo, carousel
  block, background and entry images from code (original pixel art, no
  Mojang assets) into `theme/art/` and `roms/images/`. Regenerate with
  `python3 theme/make-art.py`.
- **Your own pictures**, not in Git: `artwork/` holds pictures with fixed
  names (`minecraft_Logo.png`, `minecraft_Wallpaper.jpg`,
  `minecraft_<Title>.jpg` per menu entry; `artwork/README.md` has the list).
  `apply-artwork.py` puts them over the defaults. The image build runs it in
  the package's build step and `dev-deploy.sh` before copying; both print
  which pictures were used. The folder's `.gitignore` keeps everything but
  its README out of Git, so third-party artwork stays on the build machine.

Carbon's default wallpaper style ("consoles") fills the screen with
`art/background/<system>.jpg` and puts its own fade overlay (`art/backfade.png`) on top.
For logos it tries `<system>.png`, `<system>.svg` and then the `-w` (for dark
backgrounds) versions; the last one that exists wins, so a PNG logo only shows
when there is no SVG of the same name. The default system view
("darkened") uses only the `-w` files.

## Checked against the build's own tools (2026-11-17)

- `python-src/batocera-es-system` (the build's ES config generator), run on
  the Mac with every emulator info file and x86_64's configgen defaults,
  produces the expected `minecraft` system, default emulator/core and menu
  entries.
- The Kconfig tree parses, and on x86_64 the chain all systems → Minecraft
  systems → `prismlauncher` → `xdotool` resolves to `y`.

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

- Player 1 still picks the world in a half-width window; some vanilla screens
  (World Options) are cut off at that width.
- Controllers: Controlify binds a profile to `md5(vendor id + product id + serial)`;
  P2 falls back to the first controller if its own is missing. Set up by hand for now.
- Manage Minecraft UI, Minecraft Launcher entry and the account pickers.
- The image has not been built yet (no build machine set up).
