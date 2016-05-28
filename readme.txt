### Tyrant - an attempt to standartize many area protection mods out there

This mod provides a library for area protection mods. It tries to exterminate conflicts caused by different area protection mods each behaving like the only one.
It does this by letting mods register a so-called integration.
- All areas you are in are displayed inside one HUD.
- tyrant automatically handles protection for entering, pvp, building, activating and modifying inventories and just asks integrations if this action can be performed by the player
- Area protection mods that allow players to self-protect areas can check if any other mod registered an area here, not just its own.
To see what can be done with integrations and how easy it should be to rewrite your mod into a tyrant integration, see the top of init.lua or one of my integrations.


License
-------
            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.

-------

