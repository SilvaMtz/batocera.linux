from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext

class PrismlauncherGenerator(Generator):
    """Minecraft system: each menu entry is a small file naming its mode.

    batocera-minecraft does the work (instances, accounts, window placement)
    and decides what each entry's word means, so a new menu entry only
    touches the prismlauncher package. It can also be run and tested over
    SSH without EmulationStation.
    """

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        words = rom.read_text().split() if rom.is_file() else []
        return Command.Command(array=["/usr/bin/batocera-minecraft", "menu", *words[:1]])

    def getMouseMode(self, config, rom):
        # Prism's own window (Microsoft sign-in) needs a pointer
        return True

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "prismlauncher",
            "keys": {"exit": "/usr/bin/batocera-minecraft stop"},
        }
