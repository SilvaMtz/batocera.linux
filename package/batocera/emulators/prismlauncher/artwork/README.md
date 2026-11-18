# Your own Minecraft artwork

Put your pictures for the Minecraft system in this folder. Git ignores
everything here except this file, so pictures you don't own the rights to
(Mojang's logo and artwork, for example) never reach a public repository.
The image build and `dev-deploy.sh` both read this folder. Any picture that
is missing keeps the drawn default from `theme/` and `roms/images/`.

## File names

All files go directly in this folder. The names must match exactly,
including upper and lower case:

| File | Shown as | Suggested size |
|---|---|---|
| `minecraft_Logo.png` | System logo in the carousel and above the menu | about 1200 px wide, transparent PNG trimmed to the letters |
| `minecraft_Wallpaper.jpg` | Wallpaper behind the Minecraft carousel entry | 1920x1080 |
| `minecraft_SinglePlayer.jpg` | Single Player entry | about 1000 px wide |
| `minecraft_SplitScreen.jpg` | Split Screen entry | about 1000 px wide |
| `minecraft_ManageMinecraft.jpg` | Manage Minecraft entry | about 1000 px wide |
| `minecraft_PrismLauncher.jpg` | Prism Launcher entry | about 1000 px wide |

Each menu entry's picture is `minecraft_<Title>.jpg`, where `<Title>` is the
entry's name in `../roms/gamelist.xml` without spaces. A new entry named
"Minecraft Launcher" would use `minecraft_MinecraftLauncher.jpg`.

The logo is the one PNG: it needs a transparent background. Trim the empty
margin around the letters, or the logo shows up small.

Converting on a Mac, for example:

```bash
sips -s format jpeg -s formatOptions 85 -Z 1000 picture.webp --out minecraft_SplitScreen.jpg
```

## After changing a picture

- On the running PC: `../dev-deploy.sh --save`
- In the image: `scripts/minecraft-fork/build-on-mac.sh prismlauncher`, then
  `scripts/minecraft-fork/install-image.sh`

Both print which pictures were used and warn about files whose names don't
match.
