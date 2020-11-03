-- Dynamic Sequential Mission Campaign -- Dedicated server option file

-- Server auto-save options
-- Choosing this option require desanitization of MissionScripting.lua. 
-- If you didn't already done that, DSMC will do that for you!
DSMC_AutosaveProcess		= true		-- true / false. 
DSMC_AutosaveProcess_min	= 1			-- minutes, number, from 2 to 480

-- Server auto-close option
DSMC_AutosaveExit_hours		= 25 		-- hours of simulation after with DCS closes, from 0 to 24 (higher values won't be accepted). If clients are online, it will delay 5 minutes and so on till nobody is online.

-- Server F10 menù save option disable switch
DSMC_DisableF10save			= true

-- those variables are the same you find in options menù. They are checked by the loader.lua only
-- after options menù! So if you're running with graphics, those options will be used. If you're
-- running dedicated server, it will use the variables below.

-- Save scenery enhancement
DSMC_MapPersistence 		= true		-- true / false
DSMC_StaticDeadUnits 		= true		-- true / false
DSMC_UpdateStartTime		= true 		-- true / false
DSMC_UpdateStartTime_mode	= 1 		-- Ignored if UpdateStartTime is false. 1 = keep continous scenery. 2 = start the next day, random hour
DSMC_TrackWarehouses		= true	 	-- true / false
DSMC_TrackSpawnedUnits		= true	 	-- true / false
DSMC_WeatherUpdate          = true      -- true / false
DSMC_ExportDocuments        = true      -- true / false
DSMC_CreateClientSlot       = true      -- true / false

-- CTLD setup stuff
DSMC_automated_CTLD			= true	 	-- true / false
DSMC_CTLD_RealSlingload		= true	 	-- true / false


-- Debug. Leave on only for bugtracking!!!
DSMC_DebugMode				= false		-- true / false




-- ##################################################################
-- ADVANCED SERVER CUSTOMIZATION  ## TOUCH THIS AT YOUR OWN RISKS! ##
-- ##################################################################

-- support scripts setup
DSMC_cleanDamagedSAMsites   = false     -- true / false

-- CTLD advanced setup
DSMC_CTLD_AllowCrates       = true      -- true / false
DSMC_CTLD_AllowPlatoon		= true	 	-- true / false     BEWARE: using platoons mode will require you to set up some factories around. Check manual!
DSMC_CTLD_UseYearFilter     = true      -- true / false  
DSMC_CTLD_UnitNumLimits     = false      -- true / false
DSMC_CTLD_Limit_APC         = 200       -- number
DSMC_CTLD_Limit_IFV         = 150       -- number
DSMC_CTLD_Limit_Tanks       = 80        -- number
DSMC_CTLD_Limit_ads         = 50        -- number
DSMC_CTLD_Limit_Arty        = 60        -- number

-- Save scenery enhancement
DSMC_BuilderToolsBeta 		= false		-- true / false -- Leave FALSE ALWAYS
