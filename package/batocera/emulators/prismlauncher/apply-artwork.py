#!/usr/bin/env python3
"""Put the builder's own pictures over the Minecraft system's drawn defaults.

Usage: apply-artwork.py ARTWORK_DIR THEME_ART_DIR ROMS_DIR

THEME_ART_DIR and ROMS_DIR are copies of theme/art and roms/ (the drawn
defaults); they are changed in place. ARTWORK_DIR holds the pictures, all in
one folder, with fixed names (artwork/README.md explains them):

  minecraft_Logo.png        system logo (transparent PNG)
  minecraft_Wallpaper.jpg   wallpaper behind the Minecraft carousel entry
  minecraft_<Title>.jpg     one per menu entry: <Title> is the entry's name in
                            roms/gamelist.xml without spaces, e.g.
                            minecraft_SinglePlayer.jpg for "Single Player"

A missing picture keeps the drawn default. Used by prismlauncher.mk (image
build) and dev-deploy.sh. Standard library only.
"""
from __future__ import annotations

import re
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PREFIX = "minecraft_"
NOT_PICTURES = {".gitignore", "README.md", ".DS_Store"}


def title_key(name: str) -> str:
    """'Single Player' -> 'SinglePlayer'"""
    return re.sub(r"[^A-Za-z0-9]", "", name)


def main(artwork: Path, theme_art: Path, roms: Path) -> None:
    present = {p.name for p in artwork.iterdir() if p.is_file()} if artwork.is_dir() else set()
    used: set[str] = set()

    def take(name: str) -> Path | None:
        if name in present:
            used.add(name)
            return artwork / name
        return None

    expected = [PREFIX + "Logo.png", PREFIX + "Wallpaper.jpg"]

    # The theme shows an .svg logo over a .png of the same name, so the drawn
    # SVGs go. "-w" is the version for dark views (Carbon's default uses it).
    logo = take(PREFIX + "Logo.png")
    if logo:
        for stem in ("minecraft", "minecraft-w"):
            (theme_art / "logos" / f"{stem}.svg").unlink(missing_ok=True)
            shutil.copyfile(logo, theme_art / "logos" / f"{stem}.png")

    wallpaper = take(PREFIX + "Wallpaper.jpg")
    if wallpaper:
        shutil.copyfile(wallpaper, theme_art / "background" / "minecraft.jpg")

    # Menu entry pictures
    gamelist = roms / "gamelist.xml"
    tree = ET.parse(gamelist)
    games = list(tree.getroot().iter("game"))
    for game in games:
        name = PREFIX + title_key(game.findtext("name", "")) + ".jpg"
        expected.append(name)
        picture = take(name)
        if picture:
            shutil.copyfile(picture, roms / "images" / name)
            image = game.find("image")
            if image is None:
                image = ET.SubElement(game, "image")
            image.text = f"./images/{name}"
    tree.write(gamelist, encoding="utf-8", xml_declaration=True)

    # Drawn defaults that no entry shows any more
    shown = {Path(g.findtext("image", "")).name for g in games}
    for f in (roms / "images").iterdir():
        if f.name not in shown:
            f.unlink()

    print(f"Minecraft artwork from {artwork}:")
    for name in expected:
        print(f"  {name:34} {'yours' if name in used else 'drawn default'}")
    for name in sorted(present - used - NOT_PICTURES):
        stem = name.rsplit(".", 1)[0].lower()
        close = [e for e in expected if e.rsplit(".", 1)[0].lower() == stem]
        hint = f" (did you mean {close[0]}?)" if close else ""
        print(f"  WARNING: {name} is not used{hint}; names must match exactly")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*(Path(a) for a in sys.argv[1:]))
