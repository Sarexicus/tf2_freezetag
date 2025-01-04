# So you want to make a map for Freeze Tag

Great! This document will guide you though the process of adding the gamemode to your map, as well as cover some design principles for your map to best work with the gamemode.

## BEFORE GOING ANY FURTHER

It is highly recommended you check the license document in this pack, and understand every point in it. This is very important for us, the team that made this gamemode.

Also, in order to use this gamemode, you will be needing CompilePal in order to pack the necessary files once you are done with compilation. Make sure you have it on your computer before continuing. This guide also assumes you know how to use the Hammer editor, as well as how to compile maps.



# I. Pack installation

The first step with this pack is to put it inside your tf/custom folder. If you do not know where that is, go into your Steam installation folder, then go into steamapps, common, Team Fortress 2, then finally tf. If the custom folder doesn't exist, create it.

This will make the content of this pack available to both your game and Hammer, as well as later down the line CompilePal.



# II. Gamemode installation

In this pack you will find a prefab VMF file that contains the required elements for you to add Freeze Tag to your map. In it you will find:
- Spawnpoints for both teams
- A central control point (with associated prop and trigger)
- A func_regenerate and func_respawnrooms used during setup
- A logic_script that loads the script files, and a few other entities, necessary for the gamemode
- A func_door used as an example setup door

In addition to those necessary elements, you will also find a separate trigger on top of an orange pad, as well as an overlay on the ground. These will be detailed later down this guide.

## To add Freeze Tag to your map, follow these steps:
1. Take the central control point, its control point base model, and its associated trigger, and place them where you want the CP to be placed in your map.
    - The control point, trigger, and prop all have special names and outputs to make the gamemode work.
    - You may notice that it has a fairly long cap time. This is from our testing, we saw that a long cap time allowed for more interesting games. We recommend keeping it as is.
    - **DO NOT** recreate the control point from scratch. Use the one in the prefab.
2. Take all the floating entities off to the side of the control point, and put them anywhere in your map.
    - Those entities are what powers the gamemode. All of them are necessary.
    - This includes a default light_environment. **YOU MAY** delete it to avoid issues.
3. Take the overlay of the cup on the ground, and put it somewhere out of bounds on your map (where players won't see it).
    - This will ensure that the custom HUD loads its images correctly, and avoids issues with reloading maps under sv_pure.
    - If the overlay shows up as a pink and black checkerboard, this means you didn't put the pack folder in tf/custom (or need to reload Hammer).
4. Take the func_regenerate and func_respawnrooms and put them around your spawns.
    - Later, you will be including a soundscript file that will mute the func_regenerate sounds, so don't worry about putting them around the entire spawnrooms.
    - Those elements only exist during setup time, and allow players to freely change classes/loadouts.
    - **YOU MAY** put the func_regenerate around your entire map if you want.
    - **DO NOT** mix the func_respawnrooms, as they are associated with specific teams.
    - **DO NOT** recreate those elements from scratch, as they have special names that are required for the logic to work.
    - **DO NOT** include regular resupply cabinets in your spawns.
5. Use the spawnpoints in the prefab, or create them from scratch in your spawns.
6. When setting up the doors for your spawns, make sure their targetname starts with "setupgate" (without the quotes).
    - This should be the case with the setup door prefabs included in the ABS/BAMF pack.
    - **YOU MAY** put anything after "setupgate" in the name for your doors.

For now, leave the trigger on the orange pad where it is. It's a special tool that will help use later.

## Once you have done all these steps, you should be able to load into the map and see the gamemode in action.

This should mean:
- Loading into a waiting for players period, where the setup doors automatically opens and players respawn instantly.
    - It's recommended to add a few bots for testing. You can do this with the "bot" command (again, without the quotes).
    - It's also recommended you enable "developer 1" (you get the idea) to get console feedback.
    - **DO NOT** use "waitingforplayers_cancel". It will brick the gamemode. **DO** use "restartround" or "restartround_immediate".
- Starting a round with a setup period where you respawn instantly
- Once the setup period is over, the setup gates open and dying means becoming an ice statue.
- After 75 seconds, the point unlocks.
- All players dying or the point being capped causes the round to end and a new one to start.

If this doesn't happen, check that the pack folder is in tf/custom. If that's the case, verify each step of the installation process, redoing it if necessary.

## Now, you may have seen a message when loading into your map (and whenever a game starts) that says that "The map contains no nav mesh!"

This is because the gamemode requires the navigation mesh in order to determine what is and isn't a valid spot for a statue to be put at.

You can generate a navmesh using the "nav_generate" command. It will take a few minutes and will be quite demanding, and once done will reload the map.

You can see the navmesh with "nav_edit 1" once generated. **YOU SHOULD** check for spots that might look unfitting for a statue, namely high/unreachable places, or death pits.

This is were our special tool comes into play! Wherever those spot might appear, you can copy and paste this special trigger to prevent status from being placed there.
- The trigger is simply a trigger_multiple named "ft_func_nofreeze". It prevents statues appearing within its bounds. It still works correctly if rotated or cut.
- You do not need the orange pad under it for it to work.
- **DO** be diligent with this tool, like you would with a func_nobuild. **YOU MUST** use it wherever necessary, but don't abuse it.



# III. Design principles

You should now have a working example of a Freeze Tag map. Here are a few elements to keep in mind when designing your map:
- As you may have guessed, the gamemode requires closed spawn rooms. Be sure to have a space for them in your map.
- The gamemode handles death pits, either through them not having nav meshes, or having a ft_func_nofreeze in them. Statues will be placed at the last valid position the player was in.
- Players thaw at half health, then slowly regenerate to full. Unlike regular Arena, **YOU SHOULD** put more health kits around to help players get back in the fight faster.
- The capture point has a fairly long capture time by default. It's recommended to keep it as is, as through testing, we realized that a logner cap time lead to more interesting games.


# IV. Compiling for launch

You now have your very own Freeze Tag map, ready for testing. This is where CompilePal comes into play, and where it is **IMPERATIVE** that you follow these steps.
1. Copy the files named "mapname_english.txt", "mapname_level_sounds.txt", and "mapname_particles.txt" into your tf/maps folder. Then, rename them by replacing "mapname" with the **FULL NAME** of your map.
    - Full name means **IT MUST** include the gamemode prefix, and the version suffix.
1. In CompilePal, create a new compilation profile. **YOU MAY** copy it from an existing one.
2. Add or enable the Pack option. In it, add the following parameters:
    - Include Directory, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag"
    - Exclude, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag/prefab_freezetag.vmf"
    - Exclude, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag/README.md"
    - Exclude, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag/GUIDE.md"
    - Exclude, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag/mapname_english.txt"
    - Exclude, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag/mapname_level_sounds.txt"
    - Exclude, "[Steam installation folder]/steamapps/common/Team Fortress 2/tf/custom/freezetag/mapname_particles.txt"
        - **IF YOU ARE USING COMPILE PAL v028.3 OR LATER**, you may skip those, as the script contains hints for CompilePal
    - Verbose
        - **DO** include this parameter even on Compile Pal v028.3 or later.
3. Launch the compilation of your map. In the logs, you should see that it has packed scripts, materials, models, resource files, soundscript, navmesh, and particle manifest.
    - In addition, you can check that it has added the individual files of the gamemode using the verbose output.

## If everything went correctly, you should be able to launch your map with "sv_pure 2" and have everything work.

When doing so, **YOU MUST** also move or rename the scripts folder of this pack, as it will be used by the game in case the scripts weren't packed in properly. **REMEMBER** to undo this once you're done testing.

## If you want a thorough testing of your map before release, here is a testing routine you could use

- Start map with "developer 1", "sv_cheats 1", "sv_pure 2", "nav_edit 1" (use the "map" command afterwards)
- Check navmesh for weird spots not covered by ft_func_nofreeze
- Test winning with everyone dead and with the central point
- Test freezing from damage and hazards (death pit)
- Test statue placement
- Test thawing (you can use "tf_bot_warp_team_to_me" to have bots teleport to your statue)



# V. Troubleshooting

- Nothing happens when I run the map
  - Check you have installed the pack correctly (in the correct folder). If this is a compile, check that it's packed correctly.
- When I die in a death pit, my statue ends up in that death pit
  - Delete the nav mesh in the death pit with "nav_edit 1" and "nav_delete" (don't forget to use "nav_save" afterwards), or put a ft_func_nofreeze down there.
- The gamemode seems to work partially
  - Make sure you have included ALL of the core entities into your map, as per the installation instructions
- The point never unlocks
  - Use the point in the prefab (control point, trigger, and prop). Do not recreate them from scratch
- I crashed (when killing someone or when someone else dies)
  - This is a known bug that we have been unable to fix. We kill ragdolls to sell the effect better, but this sometimes causes clients to crash. Alternatives have been explored but none were good enough
- The gamemode loads correctly, but nothing happens
  - Check if you have other scripts in your map, and if they clear event callbacks. If so, remove those scripts, or rework them to use event namespaces to avoid interference with other scripts.
- Players drop flags and round score isn't reported on the HUD
  - You might have accidentally duplicated part of the central logic. Check for it in your map, and redo the installation if needed.
- I have some other issue! / I have a suggestion!
  - Leave a message on the prefab's thread. We'll look into solving bugs, and potentially integrating suggestions if we deem them fitting and possible to do.
