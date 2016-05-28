Denaid Mod for Minetest 0.4.12

Dependencies: none.
License: see below.

This mod is an advanced area management tool. it allows areas to be created, and the owner or an administrator can add and edit rulesets for players. this includes restrictions for entering an area, building on an area, interacting with nodes and hit other players inside an area
only administrators are permitted to edit the bounds or the priority of an area.

Data an area can save
---------------------
Every area consists of some properties:

id: this is used to identifiy the area. should be unique and capable of being a lua table index.
name: the name displayed to people seeing this area.
coord1/coord2: the area borders
priority: which priority this area has over other areas. if more than one areas have the same priority, they are evaluated together, areas with lower priorities overlapping areas with higher ones are ignored in these places.
Example:
Areas:        [Area 1: priority 0   [Area 2:priority 2 [Area 3:priority 2  ]  ]   ]
What is here?:|Area 1 only          |Area 2 only       |Area 2 and Area 3  |  |   |
(I think a parent-child-system is not useful in a mod like this where areas are mostly admin-controlled)

These options are only accessible for admins (persons who have the denaid_admin privilege).

PvP: If players should be able to hit other players inside the area.
Allow Mob spawning: If Mobs should spawn inside this area. Mods that add mobs should depend on denaid? and call denaid.check_can_mob_spawn_here(pos) (returns a boolean) when spawning mobs in the world.
Currently there is no mod that does this.

Rulesets: Allow/Disallow specific or all players to do different actions. They are parsed from first to last, the first one that applies to the player is used to allow/deny the action.

Per-Ruleset options:
Players: can be player names separated by comma or the string @a which means all players. The owner and players with the denaid_admin privilege are always allowed to do everything in their area.
allow entering: grant players access to your area
allow interaction: players can rightclick nodes and modify inventories.
allow building: players may change nodes, as checked with is_protected() (editing signs and other things checking is_protected apply here too).

These are accessible in the info form, and the owner as well as admins can edit them.

Rule interpretation
-------------------
Rulesets are applied to players as follows:
For every area with the same, highest priority the player is inside (usually 1 area, but can be more):
  Find the first ruleset that applies to the player
  Check if he is allowed to do this action corresponding to the ruleset
If any area prohibits the action: disallow and show message.
If no area forbids the action: allow.

Every area can be thought of having an invisible ruleset [- - -  @a] as last ruleset. So, if there's no ruleset applying to a player, the action will be denied.

E I B
-----
stand for Enter Interact Build and are used everywhere to describe your (or other player's) privileges inside areas.

Chat Commands
-------------
/all_areas: lists all areas registered. info form can be visited, but only owners or admins can edit options
/areas_here: lists all areas at your position (of course only the ones with highest priority here)

admin-only:
/denaid_coord_a-d to set the coordinate pairs that can be inserted into coord1/2 of the area edit form. The stand-position of the player is saved.
/denaid_editform to open the denaid_editform(see below)

Understanding the /denaid_editform
----------------------------------

The denaid_editform is THE non-user-friendly tool to manage all kind of area data.
I'll just explain what the buttons do:
write: saves all data to the area-id given in the id field. if it does not exist, it is created.
delete: removes the area with the id written in the id field.
get areaid/new area: discards all unsaved data and shows the ones of the area specified in the id field. if it is not existing, you'll be warned and everything is zero. the area is actually created when you click write.
setup: takes you to the ordinary area info dialog where you can edit rulesets.
<a...<d write the saved coordinates a-d into the corresponding fields. they are sorted when you click write.

Example: Creating areas (admin-only)
------------------------------------
1. fly to the two corners (3D!) of the area and execute one of /denaid_coord_x (where x is a, b, c or d) to save the corner points. (the stand position of the player is saved!)
2. invoke /denaid_editform (this is the universal form for adding, deleting or editing areas)
3. click the <a/<b/<whatever buttons to import the saved corner points
4. fill out all other area data, including the new id
5. click write
the area is then saved under this name.

API for other mods
------------------
Yes, there is an API. It is documented inside init.lua

Self-protection
---------------
normal players can create a private area that they own (so they can edit rulesets).

/protect command gives them a marker tool to set X/Z corners:
- Punch a node with that tool, this will be the first corner of the area
- Punch a second node at the opposite corner
- a dialog asks for remaining info.

Self-protected areas are restricted in size to 100x100x100, this can be changed in init.lua

/myarea shows the administration formspec for the private area

The marker tool can be used to redefine the private area.

Note for admins: self-protected areas have priority 2, they can't intersect with areas of priority 2 or higher. Configuration: inside init.lua (on top of file)

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
Have fun with this mod. I hope it will become more popular.
