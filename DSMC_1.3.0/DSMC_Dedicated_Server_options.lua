-- Dynamic Sequential Mission Campaign -- Dedicated server & server without graphics option file
-- please check mission designer manual before changing any paramterer. If you have issues, log in the DSMC discord and report as described in chapter 5 of the manual.

-- Debug. Leave this true only for bugtracking!!!
DSMC_DebugMode					= false		-- true / false

-- ##################################################################
-- SAVED SCENERY FILE (.miz) CUSTOMIZATION & PREFERENCES ############
-- ##################################################################

DSMC_StaticDeadUnits 			= true		-- true / false
DSMC_UpdateStartTime_mode		= 2 		-- 1,2 or 3. Ignored if UpdateStartTime is false. 1 = keep continous scenery. 2 = start the next day, random hour. 3 = use current date, default mission time.
DSMC_StarTimeHourMin        	= 5         -- 1-> 14. hour 0-24 that will be used as minimum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "4"
DSMC_StarTimeHourMax        	= 16        -- 15-> 23. hour 0-24 that will be used as maximum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "16"
DSMC_CreateSlotHeliports    	= true      -- true / false. If true, helicopters slots will be automatically created on heliports. Check manual for details on how it works.
DSMC_CreateSlotAirbases     	= true      -- true / false. If true, slots will be created in airbase also and with fixed wing type. BEWARE: REQUIRE CONSISTENT SCENERY DESIGN! CHECK MANUAL
DSMC_CreateSlotCoalition    	= "all"     -- "all", "blue", "red". Case sensitive. If wrong, it reverts to "all". If blue or red, slots will be created only for that coalition
DSMC_WarehouseAutoSetup     	= true      -- true / false. If true, at each mission end the supply net will be automatically rebuilt. Check manual!
DSMC_DisableFog     	        = false     -- true / false. If false, DSMC weather system will create fog when could be expected due to moisture levels. If true, it will prevent fog formation in any conditions.

-- ##################################################################
-- DEDICATED SERVER / SERVER WITHOUT GRAPHICS CUSTOMIZATION #########
-- ##################################################################

DSMC_DisableF10save				= false      -- true / false. F10 menù save option disable switch
DSMC_AutosaveProcess			= false		-- true / false. --> Choosing Auto-Save will make DSMC automatically desanitizatize MissionScripting.lua
DSMC_AutosaveProcess_min		= 2			-- minutes, number, from 2 to 480. DSMC_AutosaveProcess must be true.
DSMC_24_7_serverStandardSetup   = 1         -- value, 0->24. 0 means disabled. Any values above 24 are read as 0. If a valid number between 1 and 24, it will automatically save the scenery & close DCS after that period in hours, and set the saved mission as first upon restart of DCS.
-- This option is a simplified setup for the specific server autosave layout, where:
---- variable DSMC_AutosaveExit_hours is equal to the specified values
---- variable DSMC_AutosaveExit_time is 0
---- variable DSMC_AutosaveExit_safe is true
---- variable DSMC_AutoRestart_active is true
---- variable DSMC_updateMissionList is true
-- Server admin with a auto-restart 24/7 setting should consider to use this instead of the single variables unless needed.

-- Specific server autosave and restart setting 
-- THESE VARIABLES WORKS ONLY IF DSMC_24_7_serverStandardSetup IS SET AS 0 (false)
DSMC_updateMissionList          = false     -- true / false. If true, once the server closes, DSMC will automatically update the mission list by setting only the saved mission as first one, and removing the others
DSMC_AutosaveExit_hours			= 25        -- value, 1->24 or 25. hours of simulation after with DCS will close the mission, from 0 to 24 (higher values won't be accepted). If clients are online, it will delay 5 minutes and so on till nobody is online.
DSMC_AutosaveExit_time      	= 0         -- value, 1->23. hour at witch DCS will automatically close the mission regardless of clients or other settings. works only if DSMC_AutosaveExit_hours is set to >24. Values out of the 1-23 range will be ignored.
DSMC_AutosaveExit_safe      	= true      -- true / false. If false, the autosaveExit will close the mission regardless of clients online, for those server admin who prefer to have a specific kill time.
DSMC_AutoRestart_active     	= true      -- true / false. If true, the server won't close and will be automatically loaded the saved mission. If false, the DCS server will be closed completely and will require a fresh start with an external solution (not included)

-- ##################################################################
-- EXTERNAL SCRIPT SUPPORT   ##  CTLD PERSISTENCY OPTIONS  ##########
-- ##################################################################

-- these parameters will work with any ctld versions, with exception for the DSMC's customized CTLD script (non included)
DSMC_ctld_recognizeHelos        = true     -- true / false. If true, any helicopter that spawns in the scenery will be added to ctld.transportPilotNames
DSMC_ctld_recognizeVehicles     = true     -- true / false. If true, any Truck, IFV or APC vehicle from mission editor objects will be added to ctld.transportPilotNames (spawned won't be available)