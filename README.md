# DSMC
DSMC - github repository

Dynamic Sequential Mission Campaign (DSMC) is a tool for mission designers, supporting versions of DCS World 2.5.6 and above. This tool adds persistence to any DCS World mission, done by allowing the user to save the scenario at any moment and generate a new mission file based on the situation at the time of saving, that can be loaded, or edited, using the DCS mission editor. DSMC is required to be installed on the host/server only, and has configuration settings available for both Dedicated server, or Player as Host, via the special options GUI in DCS World.
DSMC creates a new .miz file that includes:
•	All original triggers, scripts and embedded files as the original 
•	Updated unit positions and states (alive, dead)
•	Scenery object states, like bridges, houses and structures
•	Updated airbases, Oil/Gas facilities & FARP ownership
•	Updated warehouse contents of fuel, aircraft & ammo

DSMC also includes improved features and functions for dedicated server mode, and for servers with desanitized missionscripting.lua settings.
DSMC does not support capturing aircraft or missiles in flight.
 
 
 
INSTALLATION

DSMC needs to be installed on the server or mission hosts computer only. It works with both DCS stable & openbeta versions. The following example references the DCS World Open Beta version.
The installation package is a zipped file to be copied “as is”. Installation is performed by copying “DSMC_main” folder content inside your Saved Games\DCS.openbeta\ folder. The mod files are:
•	DSMC folder
•	Script\Hooks\DSMC_hooks.lua file
•	Mods\tech\DSMC\ folder
•	DSMC_Dedicated_Server_options.lua file.
To allow faster install/uninstall procedures you may want to use JGSME or OvGME mod managers, which are fully compatible with DSMC.



COMPATIBILITY

DSMC is designed to be fully compatible with; 
•	Mist
•	MOOSE
•	LoATC
Special consideration was given to the CTLD script by Ciribob. To add additional features and automation, CTLD is already included in DSMC with some small additional features:
•	Automated helicopter, infantry group and APC/IFV recognition (no need to edit lua files)
•	Feel the weight! When you load troops into the helicopter, the helicopter weight is now dynamically added
•	All CTLD spawned items are retained in the saved mission and will continue to work in subsequent missions (FOBs cargo zones etc) 
SINGLE PLAYER / HOST MULTIPLAYER
This is the “basic” DSMC mode. It will require no additional modification and allows DSMC to be customized and configured using the special options menu, in the DCS World user interface.
This mode should be used for single players and multiplayer hosts who run the simulation without using a dedicated server. It relies on the 3D interface for configuration. If you want to run a dedicated server version or with graphics disabled, please skip to the “SERVER / DEDICATED SERVER” instructions.

To do a quick test, follow those steps:
1.	Go into the DCS mission editor
2.	Open a mission
3.	Save the mission renaming with “DSMC_missionname.miz”. DSMC will only work if the first letters of the mission name are “DSMC”, case sensitive
4.	Load the mission, from the editor or from the main menu
5.	Enter a client unit or, with Combined Arms, into a tactical commander or game master slot
6.	You will see an additional option using F10 radio menu. If you choose “DSMC - save progress” it will start a sequence of trigger messages and it will print “scenery saved!” in some seconds.
You can now exit the mission, go to the default DCS mission folder (\Saved Games\DCS.whateverversion\Missions) and open the and you will see a new mission named “DSMC_missionname_001.miz”.
Done!
Additionally, DSMC monitors the connected player counts. DSMC will perform an automatic save procedure by itself when the server is empty or only the host is online!
BEWARE: the save process is complex and heavy, it might takes minutes for complex missions. Do not run it continuously, or while clients are connected, in order to avoid momentary server disruption! 



SERVER / DEDICATED SERVER

This mode is made with server administrators in mind, and allows some additional features such as:
•	Auto-save process every “n” minutes (1 to 480)
•	No screen information messages during the save process
•	Extremely light save process (unless F10 menu is used)
•	Automatically modify the ServerSettings.lua  next mission
By design, the configuration of this mode is done using the “DSMC_Dedicated_Server_options.lua” file instead of the GUI special options menu. Here you will find the DSMC settings you can change.
Dedicated Server mode requires the server administrator to desanitize the missionscripting.lua file. By default, DCS forbids the interaction with files and folders outside itself when run from within the mission. This process lowers the security level of DCS which, by default, prevents malicious code from being executed onto the Local File System. Therefore we advise researching the impact by searching for the key terms "desanitize" and "missionscripting.lua". 
This mode is the only way DSMC will work when using the dedicated server version, headless mode.
In ‘dedicated server mode’ you will continue to have the radio menu options to begin the “heavy” save process, but you will also have a “light save” process every “n” minutes (frequency defined in the DSMC_Dedicated_Server_options.lua) which will create the saved files only when the mission is halted or stopped. This save won’t immediately produce the new miz file, so don’t look for it before the simulation is closed/stopped.
In addition, DSMC will perform an automatic full save every time the last client leaves the server. DSMC also attempts to save when the dedicated server is closed from Windows, however this method is not supported and requires a ‘graceful’ process exit.

To help server admin that want to run 24h servers, given that DCS and DSMC don’t like that much the windows process killing procedure, DSMC provide an automatic close to desktop command that can be set every “n” hours, from 1 to 24: i.e., If set with 6 hours, after 6 hours of simulation DCS will try to close it to desktop. Try… why? Cause if there are clients connected, it will wait till the last one is out, checking every 5 minutes.
BEWARE: DSMC does not provide the " restart" DCS automation: that can be easily done with software like “RestartOnCrash”, using a gracetime settings of at least 120 seconds. As said, the new miz file building is a very heavy process and on complex mission where lot of things has been done it could takes minutes! 
DSMC will continuously increment the next mission to run in Dedicated Server mode. DSMC will create an additional duplicate of the saved file named DSMC_ServerReload_nnn.miz, where “nnn” is a progressive number beginning with 001. This file will be automatically set as “first mission to run” when the dedicated server is launched. Server Administrators can leverage this mode to have ‘hands-off’ continuous persistence.
