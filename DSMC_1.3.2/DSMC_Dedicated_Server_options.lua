-- Dynamic Sequential Mission Campaign -- Dedicated server & server without graphics option file
-- please check mission designer manual before changing any paramterer. If you have issues, log in the DSMC discord and report as described in chapter 5 of the manual.

-- Debug. Leave this true only for bugtracking!!!
DSMC_DebugMode					= false		-- true / false

-- ##################################################################
-- SAVED SCENERY FILE (.miz) CUSTOMIZATION & PREFERENCES ############
-- ##################################################################

DSMC_StaticDeadUnits 			= true		-- true / false
DSMC_UpdateStartTime_mode		= 1 		-- 1,2 or 3. Ignored if UpdateStartTime is false. 1 = keep continous scenery. 2 = start the next day, random hour. 3 = use current date, default mission time.
DSMC_StarTimeHourMin        	= 5         -- 1-> 14. hour 0-24 that will be used as minimum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "4"
DSMC_StarTimeHourMax        	= 16        -- 15-> 23. hour 0-24 that will be used as maximum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "16"
DSMC_CreateSlotHeliports    	= true      -- true / false. If true, helicopters slots will be automatically created on heliports. Check manual for details on how it works.
DSMC_CreateSlotAirbases     	= true      -- true / false. If true, slots will be created in airbase also and with fixed wing type. BEWARE: REQUIRE CONSISTENT SCENERY DESIGN! CHECK MANUAL
DSMC_CreateSlotCoalition    	= "all"     -- "all", "blue", "red". Case sensitive. If wrong, it reverts to "all". If blue or red, slots will be created only for that coalition
DSMC_WarehouseAutoSetup     	= true      -- true / false. If true, at each mission end the supply net will be automatically rebuilt. Check manual!
DSMC_WeatherUpdate              = true      -- true / false. If false, DSMC weather system won't run and update the mission
DSMC_DisableFog     	        = false     -- true / false. If false, DSMC weather system will create fog when could be expected due to moisture levels. If true, it will prevent fog formation in any conditions.

-- ##################################################################
-- DEDICATED SERVER / SERVER WITHOUT GRAPHICS CUSTOMIZATION #########
-- ##################################################################

DSMC_DisableF10save				= false     -- true / false. F10 menù save option disable switch
DSMC_AutosaveProcess			= true		-- true / false. --> Choosing Auto-Save will activate the light auto-save process. BEWARE: if this option is active, it will make DSMC automatically desanitizatize MissionScripting.lua
DSMC_AutosaveProcess_min		= 6			-- minutes, number, from 2 to 480. DSMC_AutosaveProcess must be true.

DSMC_24_7_serverStandardSetup   = 0.10         -- multiple valid values. This option is a simplified setup for the specific server autosave layout. You can input:
--  false 							: boolean, this will disable the option
-- 	0-> 23 (number) 				: number, this will set the automatic restart every "n" hours. Values as 0 or > 24 will be read as false
--  "19:00" (text, hh:mm format) 	: text, this will set the automatic save & restart exactly at 19:00, or any other hour you set in "hh:mm". This MUST be a text value. Any non valid "hh:mm" format will be read as false

-- DSMC will work in different way depending on how you set DSMC_24_7_serverStandardSetup option:
-- * if you set this false, the 24_7 standard setup will be ignored and you will have to set any single option accordingly, please read the manual CAREFULLY cause many of them are "child" option that can be read only if other options are set properly.
-- * if you set the number value, DSMC will save the scenery & restart the newly saved mission every "n" hours if no clients are connected (without closing the server). If clients are connected, it will retry every 10 min until all the clients are gone (a message will be prompted to anyone online every 10 mins calling for RTB and disconnect).
-- * if you set specific time value in text format, DSMC will save and close & restart the newly saved mission once a day, right at the specified hour, and will kick out any client online (and resources of non landed aircraft will be lost!). No warning is provided: you should set some specific trigger if you want to warn the clients

-- Specific server autosave and restart setting 
-- THESE VARIABLES WORKS ONLY IF DSMC_24_7_serverStandardSetup IS SET AS FALSE
DSMC_AutosaveExit_hours			= 25       -- value, 1->24 or 25. hours of simulation after with DCS will close the mission, from 0 to 24 (higher values won't be accepted). If clients are online, it will delay 5 minutes and so on till nobody is online.
DSMC_AutosaveExit_time      	= "04:00"  -- text in time hh:mm format "00:00"->"23:00". hour at witch DCS will automatically close the mission regardless of clients or other settings. works only if DSMC_AutosaveExit_hours is set to >24.
DSMC_AutosaveExit_safe      	= true     -- true / false. If false, the autosaveExit will close the mission regardless of clients online, for those server admin who prefer to have a specific kill time.
DSMC_AutoRestart_active     	= false    -- true / false. If true, the server won't close and will be automatically loaded the saved mission. If false, the DCS server will be closed completely and will require a fresh start with an external solution (not included)
DSMC_updateMissionList          = true     -- true / false. If true, once the server closes, DSMC will automatically update the mission list by setting only the saved mission as first one, and removing the others. If false, the mission list won't be updated and therefore at restart the same mission (not the saved one) will be loaded. Works only if DSMC_AutoRestart_active is set to false
DSMC_restartCampaign            = true     -- true / false. If true, DSMC will check DCS "mission goals" and when reached, instead of restarting the saved mission, will specifically look for the "_000" miz file and load that one, to restart the campaign
 
-- ##################################################################
-- EXTERNAL SCRIPT SUPPORT   ##  CTLD PERSISTENCY OPTIONS  ##########
-- ##################################################################

-- these parameters will work with any ctld versions, with exception for the DSMC's customized CTLD script (non included)
DSMC_ctld_recognizeHelos        = true     -- true / false. If true, any helicopter that spawns in the scenery will be added to ctld.transportPilotNames
DSMC_ctld_recognizeVehicles     = true     -- true / false. If true, any Truck, IFV or APC vehicle from mission editor objects will be added to ctld.transportPilotNames (spawned won't be available)

DSMC_Excl_Tag                   = "DSMC_noUP"     -- text. Any not flying group name (NOT UNIT) with this tag won't be saved/tracked/removed/added, it will be simply ignored by the save code.