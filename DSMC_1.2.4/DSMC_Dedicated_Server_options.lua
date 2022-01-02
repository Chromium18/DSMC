-- Dynamic Sequential Mission Campaign -- Dedicated server & server without graphics option file
-- please check mission designer manual before changing any paramterer. If you have issues, log in the DSMC discord and report as described in chapter 5 of the manual.

-- ##################################################################
-- OPTIONS CUSTOMIZATION   ## THE ONLY NEEDED FOR SINGLE PLAYER #####
-- ##################################################################

DSMC_StaticDeadUnits 			= true		-- true / false

DSMC_UpdateStartTime_mode		= 2 		-- 1,2 or 3. Ignored if UpdateStartTime is false. 1 = keep continous scenery. 2 = start the next day, random hour. 3 = use current date, default mission time.

--> Choosing Auto-Save will make DSMC automatically desanitizatize MissionScripting.lua
DSMC_AutosaveProcess			= false		-- true / false. 
DSMC_AutosaveProcess_min		= 2			-- minutes, number, from 2 to 480. DSMC_AutosaveProcess must be true.

DSMC_automated_CTLD				= true	 	-- true / false. If true enable the inbuilt CTLD.
DSMC_automated_CSAR         	= true      -- true / false. If true enable the inbuilt CSAR scritp. Works only if DSMC_automated_CTLD is true

DSMC_CreateSlotHeliports    	= false     -- true / false. If true, helicopters slots will be automatically created on heliports. Check manual for details on how it works.
DSMC_CreateSlotAirbases     	= false     -- true / false. If true, slots will be created in airbase also and with fixed wing type. BEWARE: REQUIRE CONSISTENT SCENERY DESIGN! CHECK MANUAL

-- Debug. Leave this true only for bugtracking!!!
DSMC_DebugMode					= false		-- true / false


-- ##################################################################
-- SERVER CUSTOMIZATION   ###########################################
-- ##################################################################

-- these additional configuration has effect ONLY when DSMC_UpdateStartTime = true and DSMC_UpdateStartTime_mode = 2
-- min & max is used to define the minimum and maximum hours used to randomize mission start time.

DSMC_DisableF10save				= true      -- true / false. F10 menù save option disable switch

DSMC_StarTimeHourMin        	= 5         -- 1-> 14. hour 0-24 that will be used as minimum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "4"
DSMC_StarTimeHourMax        	= 16        -- 15-> 23. hour 0-24 that will be used as maximum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "16"

DSMC_WarehouseAutoSetup     	= true      -- true / false. If true, at each mission end the supply net will be automatically rebuilt. Check manual!

DSMC_DisableFog     	        = false     -- true / false. If false, DSMC weather system will create fog when could be expected due to moisture levels. If true, it will prevent fog formation in any conditions.

DSMC_CreateSlotCoalition    	= "all"     -- "all", "blue", "red". Case sensitive. If wrong, it reverts to "all". If blue or red, slots will be created only for that coalition

DSMC_24_7_serverStandardSetup   = 0         -- value, 0->24. 0 means disabled. Any values above 24 are read as 0. If a valid number between 1 and 24, it will automatically save the scenery & close DCS after that period in hours, and set the saved mission as first upon restart of DCS.
-- This option is a simplified setup for the specific server autosave layout, where:
---- variable DSMC_AutosaveExit_hours is equal to the specified values
---- variable DSMC_AutosaveExit_time is 0
---- variable DSMC_AutosaveExit_safe is true
---- variable DSMC_AutoRestart_active is false (since it's beta and not working currently)
---- variable DSMC_updateMissionList is true
-- Server admin with a auto-restart 24/7 setting should consider to use this instead of the single variables unless needed.

-- Specific server autosave and restart setting 
-- THESE VARIABLES WORKS ONLY IF DSMC_24_7_serverStandardSetup IS SET AS 0 (false)
DSMC_updateMissionList          = false     -- true / false. If true, once the server closes, DSMC will automatically update the mission list by setting only the saved mission as first one, and removing the others
DSMC_AutosaveExit_hours			= 25        -- value, 1->24 or 25. hours of simulation after with DCS closes, from 0 to 24 (higher values won't be accepted). If clients are online, it will delay 5 minutes and so on till nobody is online.
DSMC_AutosaveExit_time      	= 0         -- value, 1->23. hour at witch DCS will automatically close regardless of clients or other settings. works only if DSMC_AutosaveExit_hours is set to >24. Values out of the 1-23 range will be ignored.
DSMC_AutosaveExit_safe      	= true      -- true / false. If false, the autosaveExit will kill DCS even if there are clients online, for those server admin who prefer to have a specific kill time.


-- ##################################################################
-- INBUILT CTLD/ CSAR CUSTOMIZATION #################################
-- ##################################################################

-- main CTLD on/off options
DSMC_CTLD_MessageDuration		= 20	 	-- number, from 10 to 120. Seconds of duration of the "standard" CTLD message. BEWARE: some message will be kept shorter and some other longer (as JTAC ones) depending on situation

-- crate operations options
DSMC_CTLD_RealSlingload			= true	 	-- true / false
DSMC_CTLD_ForceCrateToBeMoved   = false     -- true / false. a crate must be picked up at least once and moved before it can be unpacked. Helps to reduce crate spam
DSMC_CTLD_buildTimeFOB          = 240       -- number, from 10 to 1200. Time needed for a FOB to be built once requested

DSMC_CTLD_AllowCrates           = true      -- true / false. If set false, all subsequent crates ops will be disabled
DSMC_CTLD_Allow_JTAC_Crates     = true      -- true / false. If set false, you won't be able to spawn JTAC crates
DSMC_CTLD_Allow_SAM_Crates      = true      -- true / false. If set false, you won't be able to spawn SAM crates
DSMC_CTLD_Allow_Supply_Crates   = true      -- true / false. If set false, you won't be able to spawn Airlift supplies crates
DSMC_CTLD_longRangeSamCrates    = true      -- true / false. If set true, SA-10 and Patriots SAM system will be available. Beware: these sams require many crates! at least 6 launcher crates are required!
DSMC_CTLD_crateLargeToSmallRto  = 3         -- number, from 1 to 10. this variable define how many small crates equals to large crates. "3" means that 3 small crates equals to 1 large crates.
DSMC_CTLD_spawnCrateDistance    = 30        -- meters of distance at 12 o'clock where the crate is spawned. 30 is CTLD default. Shorter distance may help for frequent spawning on carrier

-- constructible crates custom parameters
DSMC_CTLD_AllowPlatoon		    = true	 	-- true / false. BEWARE: using platoons mode will require you to set up some factories around. Check manual!
DSMC_CTLD_crateReductionFactor  = 1.5       -- number, from 1 to 4 with fraction allowed. This is the required crate reduction factor number for platoons. 1 means about 8-12 crates/platoon, 1.5 means 5-8 crates/platoon, 2 means 2-6 crates/platoon, and so on.

-- tags to force an objects to a specific category
DSMC_CTLD_forcePilot		    = "dsmc_helicargo_" -- text. Any unit with this specific tag inside its name, case sensitive, will be recognized as a CTLD pilot.
DSMC_CTLD_forceLogistic		    = "dsmc_logistic_" -- text. Any unit with this specific tag inside its name, case sensitive, will be recognized as a logistic site.
DSMC_CTLD_forcePickzone		    = "dsmc_pickZone_" -- text. Any unit with this specific tag inside its name, case sensitive, will be recognized as a pickup zone.
DSMC_CTLD_forceDropzone		    = "dsmc_dropZone_" -- text. Any unit with this specific tag inside its name, case sensitive, will be recognized as a drop zone.
DSMC_CTLD_forceWpzone		    = "dsmc_WpZone_" -- text. Any unit with this specific tag inside its name, case sensitive, will be recognized as a waypoint zone.

-- smoke option
DSMC_CTLD_disableJTACSmoke      = false -- true / false. If True, only client 

-- CSAR script available options. BEWARE: lives and scoring system is disabled by design choice to avoid conflict with warehouse tracking
DSMC_CSAR_useCoalitionMessages  = true	 	-- true / false
DSMC_CSAR_clientPilotOnly       = false     -- true / false. If True, only client downed pilots will generate CSAR mission.



-- ##################################################################
-- BETA NOT TESTED FEATURE ## THESE VARIABLES ARE NOT WORKING #######
-- ##################################################################

-- currently not working feature below:
DSMC_AutoRestart_active     	= false     -- true / false. If true, DSMC will load a dynamically created .bat file (base version in DSMC\files, kindly provided by Maverick87Shaka) that will monitor DCS process. Once it close, it will try to load up automatically. BEWARE: no stop on that process is provided, you must do it on your own.

-- warehouse fix base quantity
DSMC_baseQuantity               = 0         -- number, from 0 to 1000, which is the quantity used when fixing warehouses // NOT WORKING YET

-- Save scenery enhancement
DSMC_BuilderToolsBeta 		    = false		-- true / false -- // NOT WORKING YET Leave FALSE ALWAYS

-- additional feature (not working leave as it is)
DSMC_ExportDocuments        	= false      -- true / false

-- CTLD custom limit for adding platoons crates
DSMC_CTLD_UnitNumLimits         = false     -- true / false. If False, the subsequent limit variable does not apply
DSMC_CTLD_Limit_APC             = 200       -- number. if the limit is reached, you won't be able to unpack any crates in this category (also consider existing units)
DSMC_CTLD_Limit_IFV             = 150       -- number. if the limit is reached, you won't be able to unpack any crates in this category (also consider existing units)
DSMC_CTLD_Limit_Tanks           = 80        -- number. if the limit is reached, you won't be able to unpack any crates in this category (also consider existing units)
DSMC_CTLD_Limit_ads             = 50        -- number. if the limit is reached, you won't be able to unpack any crates in this category (also consider existing units)
DSMC_CTLD_Limit_Arty            = 60        -- number. if the limit is reached, you won't be able to unpack any crates in this category (also consider existing units)
DSMC_CTLD_Limit_Trucks          = 100       -- number. if the limit is reached, you won't be able to unpack any crates in this category (also consider existing units)
