-- Dynamic Sequential Mission Campaign -- Dedicated server option file

-- ##################################################################
-- OPTIONS CUSTOMIZATION   ##########################################
-- ##################################################################

-- those variables are the same you find in options menù. They are checked by the loader.lua only
-- after options menù! So if you're running with graphics, those options will be used. If you're
-- running dedicated server, it will use the variables below.
-- Save scenery enhancement

DSMC_MapPersistence 			= true		-- true / false
DSMC_StaticDeadUnits 			= true		-- true / false
DSMC_WeatherUpdate          	= true      -- true / false
DSMC_TrackSpawnedUnits			= true	 	-- true / false

DSMC_CreateSlotHeliports    	= true      -- true / false. If true, helicopters slots will be automatically created on heliports. Check manual for details on how it works.
DSMC_CreateSlotAirbases     	= true      -- true / false. If true, slots will be created in airbase also and with fixed wing type. BEWARE: REQUIRE CONSISTENT SCENERY DESIGN! CHECK MANUAL

DSMC_UpdateStartTime			= true 		-- true / false. Works only for mission with timeframe 1970-today, due to function limitation. For mission before 1970, i.e. WWII or Korea, it will be skipped.
DSMC_UpdateStartTime_mode		= 2 		-- 1,2 or 3. Ignored if UpdateStartTime is false. 1 = keep continous scenery. 2 = start the next day, random hour. 3 = use current date, default mission time.

DSMC_TrackWarehouses			= true	 	-- true / false

--> Choosing Auto-Save will make DSMC automatically desanitizatize MissionScripting.lua
DSMC_AutosaveProcess			= true		-- true / false. 
DSMC_AutosaveProcess_min		= 2			-- minutes, number, from 2 to 480

-- CTLD & CSAR setup stuff
DSMC_automated_CTLD				= true	 	-- true / false
DSMC_automated_CSAR         	= true      -- true / false

-- Debug. Leave on only for bugtracking!!!
DSMC_DebugMode					= false		-- true / false


-- ##################################################################
-- SERVER CUSTOMIZATION   ###########################################
-- ##################################################################

-- these additional configuration has effect ONLY when DSMC_UpdateStartTime = true and DSMC_UpdateStartTime_mode = 2
-- min & max is used to define the minimum and maximum hours used to randomize mission start time.
DSMC_StarTimeHourMin        	= 5         -- 1-> 14. hour 0-24 that will be used as minimum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "4"
DSMC_StarTimeHourMax        	= 16        -- 15-> 23. hour 0-24 that will be used as maximum in the start mission time randomization, valid only with DSMC_UpdateStartTime set to true and DSMC_UpdateStartTime_mode set to "2". Out of the defined range, the value will be set as "16"


DSMC_WarehouseAutoSetup     	= true      -- true / false. If true, at each mission end the supply net will be automatically rebuilt. Check manual!

DSMC_DisableF10save				= true      -- true / false. F10 menù save option disable switch

DSMC_AutosaveExit_hours			= 25        -- value, 1->24 or 25. hours of simulation after with DCS closes, from 0 to 24 (higher values won't be accepted). If clients are online, it will delay 5 minutes and so on till nobody is online.
DSMC_AutosaveExit_time      	= 0         -- value, 1->23. hour at witch DCS will automatically close regardless of clients or other settings. works only if DSMC_AutosaveExit_hours is set to >24. Values out of the 1-23 range will be ignored.
DSMC_AutosaveExit_safe      	= true      -- true / false. If false, the autosaveExit will kill DCS even if there are clients online, for those server admin who prefer to have a specific kill time.
DSMC_AutoRestart_active     	= false     -- true / false If true, DSMC will load a dynamically created .bat file (base version in DSMC\files, kindly provided by Maverick87Shaka) that will monitor DCS process. Once it close, it will try to load up automatically. BEWARE: no stop on that process is provided, you must do it on your own.

DSMC_CreateSlotCoalition    	= "all"     -- "all", "blue", "red". Case sensitive. If wrong, it reverts to "all". If blue or red, slots will be created only for that coalition

DSMC_DCSR_useCoalitionMessages  = true	 	-- true / false
DSMC_DCSR_clientPilotOnly       = false     -- true / false. If True, only client downed pilots will generate CSAR mission.
DSMC_CTLD_RealSlingload			= true	 	-- true / false

-- ##################################################################
-- ADVANCED SERVER CUSTOMIZATION  ## TOUCH THIS AT YOUR OWN RISKS! ##
-- ##################################################################

-- warehouse fix base quantity
DSMC_baseQuantity               = 0         -- number, from 0 to 1000, which is the quantity used when fixing warehouses // NOT WORKING YET

-- CTLD advanced setup
DSMC_CTLD_JTACenable            = true      -- true / false. If set false, you won't be able to spawn JTACs
DSMC_CTLD_AllowCrates           = true      -- true / false
DSMC_CTLD_AllowPlatoon		    = true	 	-- true / false     BEWARE: using platoons mode will require you to set up some factories around. Check manual!
DSMC_CTLD_crateReductionFactor  = 1.5       -- number, from 1 to 4 with fraction allowed. This is the required crate reduction factor number for platoons. 1 means about 8-12 crates/platoon, 1.5 means 5-8 crates/platoon, 2 means 2-6 crates/platoon, and so on.
DSMC_CTLD_longRangeSamCrates    = true      -- true / false  
DSMC_CTLD_UnitNumLimits         = false      -- true / false
DSMC_CTLD_Limit_APC             = 200       -- number
DSMC_CTLD_Limit_IFV             = 150       -- number
DSMC_CTLD_Limit_Tanks           = 80        -- number
DSMC_CTLD_Limit_ads             = 50        -- number
DSMC_CTLD_Limit_Arty            = 60        -- number

-- Save scenery enhancement
DSMC_BuilderToolsBeta 		    = false		-- true / false -- // NOT WORKING YET Leave FALSE ALWAYS

-- additional feature (not working leave as it is)
DSMC_ExportDocuments        	= false      -- true / false