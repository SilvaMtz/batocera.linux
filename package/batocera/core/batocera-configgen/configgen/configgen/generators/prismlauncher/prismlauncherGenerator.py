from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_MODES = ("singleplayer", "splitscreen", "prism")


class PrismlauncherGenerator(Generator):
    """Minecraft system: each menu entry is a small file naming its mode.

    batocera-minecraft does the work (instances, accounts, window placement)
    so it can be run and tested over SSH without EmulationStation.
    """

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        mode = "prism"
        if rom.is_file():
            words = rom.read_text().split()
            if words and words[0] in _MODES:
                mode = words[0]

        return Command.Command(array=["/usr/bin/batocera-minecraft", mode])

    def getMouseMode(self, config, rom):
        # Prism's own window (Microsoft sign-in) needs a pointer
        return True

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "prismlauncher",
            "keys": {"exit": "/usr/bin/batocera-minecraft stop"},
        }
