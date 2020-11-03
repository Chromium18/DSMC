-- Dynamic Sequential Mission Campaign -- HOOKS module

local ModuleName  	= "Hooks"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0100"
local Date			= "17/10/2020"

-- ## LIBS	
module('HOOK', package.seeall)	-- module name. All function in this file, if used outside, should be called "HOOK.functionname"
base 						= _G	
require 					= base.require		
io 							= require('io')
lfs 						= require('lfs')
os 							= require('os')
minizip 					= require('minizip')
DSMCdir						= lfs.writedir() .. "DSMC/"
DSOdir						= lfs.writedir()

guiBindPath = './dxgui/bind/?.lua;' .. 
              './dxgui/loader/?.lua;' .. 
              './dxgui/skins/skinME/?.lua;' .. 
              './dxgui/skins/common/?.lua;'

package.path = 
	''
	..  DSMCdir..'?.lua;'
    .. guiBindPath
	.. './MissionEditor/?.lua;'
    .. './MissionEditor/modules/?.lua;'	
    .. './Scripts/?.lua;'
    .. './LuaSocket/?.lua;'
	.. './Scripts/UI/?.lua;'
	.. './Scripts/UI/Multiplayer/?.lua;'
	.. './Scripts/DemoScenes/?.lua;'
	.. './MAC_Gui/?.lua;'	
	..package.path

-- ## DEBUG TO TEXT FUNCTION
debugProcess	= true -- this should be left on for testers normal ops and test missions

-- keep old DSMC.log file as "old"
local cur_debuglogfile  = io.open(lfs.writedir() .. "Logs/" .. "DSMC.log", "r")
local old_debuglogfile  = io.open(lfs.writedir() .. "Logs/" .. "DSMC_old.log", "w")
if cur_debuglogfile then
	old_debuglogfile:write(cur_debuglogfile:read("*a"))
	old_debuglogfile:close()
	cur_debuglogfile:close()
end	

-- set new DSMC.log file
debuglogfile 	= io.open(lfs.writedir() .. "Logs/" .. "DSMC.log", "w")
debuglogfile:close()
function writeDebugBase(debuglog, othervar)
	if debuglog and debugProcess then
		f = io.open(lfs.writedir() .. "Logs/" .. "DSMC.log", "r")		
		oldDebug = f:read("*all")
		f:close()
		newDebug = oldDebug .. "\n" .. os.date("%H:%M:%S") .. " - " .. debuglog
		n = io.open(lfs.writedir() .. "Logs/" .. "DSMC.log", "w")		
		n:write(newDebug)
		if othervar then n:write("othervar exist\n") end
		n:close()
	end
end
function writeDebugDetail(debuglog, othervar)
	if debuglog and debugProcessDetail then
		f = io.open(lfs.writedir() .. "Logs/" .. "DSMC.log", "r")		
		oldDebug = f:read("*all")
		f:close()
		newDebug = oldDebug .. "\n" .. os.date("%H:%M:%S") .. " - " .. debuglog
		n = io.open(lfs.writedir() .. "Logs/" .. "DSMC.log", "w")		
		n:write(newDebug)
		if othervar then n:write("othervar exist\n") end
		n:close()
	end
end
writeDebugDetail(ModuleName .. ": local required and debug functions loaded")

--## MAIN VARIABLES
DSMC 						= {} -- main plugin table. Sim callback are here, while function is int the module (HOOK) 
tempEnv 					= {} -- 
StartFilterCode				= "DSMC"
writeDebugBase(ModuleName .. ": main variables loaded")

-- ## LOCAL VARIABLES
DSMCloader 					= false
DCSshouldCloseNow			= false
StartFilterCode				= "DSMC"
mapObj_deathcounter 		= 0
baseGcounter 				= 100000
saveCounter					= 0 
StaticStartNumber 			= 0
NEWstartTime 				= nil
NEWstartDateYear			= nil
NEWstartDateMonth			= nil
NEWstartDateDay				= nil
NEWstartTime				= nil			
NEWstartDateDay				= nil
NEWstartDateYear			= nil
NEWstartDateMonth			= nil
NEWweather 					= nil 
strDeadUnits				= nil
strScenObj					= nil
strUnitsUpdate				= nil
strAirbases					= nil
strWeather					= nil
strSpawned					= nil
hits_max_count				= 10000  -- more that this number and the aircraft is considerered grounded!. Set 10000 to "disable" that function
tempWeatherTable			= nil
randomizeDynWeather			= false
trackspawnedinfantry		= true
--ATRLloaded				= false
autosavefrequency			= nil -- minutes
DCS_Multy					= nil
DCS_Server					= nil
DSMC_isRecovering			= false
writeDebugDetail(ModuleName .. ": local variables loaded")

-- ## PATHS VARIABLES
DSMCdirectory				= lfs.writedir() .. "DSMC/"
missionfilesdirectory 		= lfs.writedir() .. "Missions/"
DSMCtemp					= missionfilesdirectory .. "Temp/"
DSMCfiles					= missionfilesdirectory .. "Temp/Files/"  
tempmissionfilesdirectory	= lfs.tempdir() .. "DSMCunpack/"
configfilesdirectory		= lfs.writedir() .. "Config/"
NewMizTempDir 				= "SAVE_TempMix/"	
OldMissionPath 				= missionfilesdirectory .. "Temp/" .. "mission"
NewMissionPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .. "mission"
OldDictPath 				= missionfilesdirectory .. "Temp/" .. "dictionary"
NewDictPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/" .. "dictionary"	
OldMResPath 				= missionfilesdirectory .. "Temp/" .. "mapResource"
NewMResPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/" .. "mapResource"	
OldWrhsPath 				= missionfilesdirectory .. "Temp/" .. "warehouses"
NewWrhsPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."warehouses"
logpath 					= lfs.writedir() .. "Logs/mixpath.txt"
tempPath 					= missionfilesdirectory .. "DSMC_tempFile.miz"
missionscriptingluaPath		= lfs.currentdir() .. "Scripts/" .. "MissionScripting.lua"
writeDebugDetail(ModuleName .. ": paths variable loaded")
-- REMEMBER!!!!! for temp save into the SSE, EMBD.saveTable has DSMCfiles path hardcoded into the function!!!!

DSMC_ServerMode = true
if _G.panel_aircraft then
	DSMC_ServerMode = false
end

-- loading proper options from custom file (if dedicated server) or options menù (if standard)
function loadDSMCHooks()
	if DSMC_ServerMode == true then
		writeDebugBase(ModuleName .. ": Server mode active")
		local dso_fcn, dso_err = dofile(DSOdir .. "DSMC_Dedicated_Server_options.lua")
		if dso_err then
			writeDebugBase(ModuleName .. ": dso_fcn error = " .. tostring(dso_fcn))
			writeDebugBase(ModuleName .. ": dso_err error = " .. tostring(dso_err))
		end
	else
		writeDebugBase(ModuleName .. ": Standard mode active")	
		local opt_fcn, opt_err = dofile(lfs.writedir() .. "Config/options.lua")
		if opt_err then
			writeDebugBase(ModuleName .. ": opt_fcn error = " .. tostring(opt_fcn))
			writeDebugBase(ModuleName .. ": opt_err error = " .. tostring(opt_err))
		end
		if options then
			for opt_id, opt_data in pairs(options) do
				if opt_id == "plugins" then
					for pl_id, pl_data in pairs (opt_data) do
						if pl_id == "DSMC" then						
							opt_MOBJ_var 		= pl_data.MOBJ
							opt_CRST_var 		= pl_data.CRST	
							opt_WTHR_var 		= pl_data.WTHR		
							opt_TMUP_var		= pl_data.TMUP
							opt_TMUP_cont_var	= pl_data.timer_options	or 2
							opt_WRHS_var		= pl_data.WRHS
							opt_SPWN_var		= pl_data.SPWN
							opt_TRPS_var		= pl_data.TRPS
							opt_TRPS_setup_var	= pl_data.TRPS_setup
							opt_DEBUG_var		= pl_data.DEBUG
							opt_ATRL_var		= pl_data.ATRL
							opt_ATRL_time_var	= pl_data.ATRL_time
							--opt_UPAP_var		= pl_data.UPAP			
							opt_SLOT_var		= pl_data.SLOT
							opt_GOAP_var		= pl_data.GOAP
							--opt_SBEO			= pl_data.SBEO

							--opt_SLOT			= pl_data.SLOT
						end
					end
				end
			end
		end		
	end

	-- assign variables
	MOBJ_var 							= opt_MOBJ_var or DSMC_MapPersistence
	CRST_var 							= opt_CRST_var or DSMC_StaticDeadUnits		
	WTHR_var 							= opt_WTHR_var or DSMC_WeatherUpdate		
	TMUP_var							= opt_TMUP_var or DSMC_UpdateStartTime		
	TMUP_cont_var						= opt_TMUP_cont_var or DSMC_UpdateStartTime_mode	
	WRHS_var							= opt_WRHS_var or DSMC_TrackWarehouses
	SPWN_var							= opt_SPWN_var or DSMC_TrackSpawnedUnits
	DEBUG_var							= opt_DEBUG_var or DSMC_DebugMode
	ATRL_var							= opt_ATRL_var or DSMC_AutosaveProcess 
	ATRL_time_var						= opt_ATRL_time_var or DSMC_AutosaveProcess_min 
	UPAP_var							= DSMC_ExportDocuments or false -- opt_UPAP_var or    NOT USED NOW if true mission briefings will be updated from a mission to another
	--TAIR_var							= opt_TAIR_var or DSMC_SaveLastPlanePosition
	SLOT_var							= opt_SLOT_var or DSMC_CreateClientSlot
	STOP_var							= DSMC_AutosaveExit_hours
	SBEO_var							= DSMC_BuilderToolsBeta or false -- opt_SBEO or    NOT USED NOW if true mission briefings will be updated from a mission to another
	TRPS_var							= opt_TRPS_var or DSMC_automated_CTLD
	TRPS_setup_var						= opt_TRPS_setup_var or DSMC_CTLD_RealSlingload
	TRPS_setup2_var						= DSMC_CTLD_AllowPlatoon or true
	TRPS_setup3_var						= DSMC_CTLD_AllowCrates or true	
	TRPS_setup4_var						= DSMC_CTLD_UnitNumLimits or true
	TRPS_setup5_var						= DSMC_CTLD_Limit_APC or 10000
	TRPS_setup6_var						= DSMC_CTLD_Limit_IFV or 10000
	TRPS_setup7_var						= DSMC_CTLD_Limit_Tanks or 10000
	TRPS_setup8_var						= DSMC_CTLD_Limit_ads or 10000
	TRPS_setup9_var						= DSMC_CTLD_Limit_Arty or 10000	
	TRPS_setup10_var					= DSMC_CTLD_UseYearFilter or true
	GOAP_var							= false -- opt_GOAP_var or DSMC_AutomaticAI

	-- debug call
	debugProcessDetail = DEBUG_var

	-- debug call
	writeDebugBase(ModuleName .. ": MOBJ_var = " ..tostring(MOBJ_var))
	writeDebugBase(ModuleName .. ": CRST_var = " ..tostring(CRST_var))
	writeDebugBase(ModuleName .. ": WTHR_var = " ..tostring(WTHR_var))
	writeDebugBase(ModuleName .. ": TMUP_var = " ..tostring(TMUP_var))
	writeDebugBase(ModuleName .. ": TMUP_cont_var = " ..tostring(TMUP_cont_var))
	writeDebugBase(ModuleName .. ": WRHS_var = " ..tostring(WRHS_var))
	writeDebugBase(ModuleName .. ": SPWN_var = " ..tostring(SPWN_var))
	writeDebugBase(ModuleName .. ": TRPS_var = " ..tostring(TRPS_var))
	writeDebugBase(ModuleName .. ": DEBUG_var = " ..tostring(DEBUG_var))
	writeDebugBase(ModuleName .. ": ATRL_var = " ..tostring(ATRL_var))
	writeDebugBase(ModuleName .. ": ATRL_time_var = " ..tostring(ATRL_time_var))
	--writeDebugBase(ModuleName .. ": TAIR_var = " ..tostring(TAIR_var))
	writeDebugBase(ModuleName .. ": SLOT_var = " ..tostring(SLOT_var))
	writeDebugBase(ModuleName .. ": UPAP_var = " ..tostring(UPAP_var))
	writeDebugBase(ModuleName .. ": STOP_var = " ..tostring(STOP_var))
	writeDebugBase(ModuleName .. ": SBEO_var = " ..tostring(SBEO_var))
	writeDebugBase(ModuleName .. ": TRPS_setup_var realslingload = " ..tostring(TRPS_setup_var))
	writeDebugBase(ModuleName .. ": TRPS_setup2_var platoons = " ..tostring(TRPS_setup2_var))
	writeDebugBase(ModuleName .. ": TRPS_setup3_var crates use = " ..tostring(TRPS_setup3_var))
	writeDebugBase(ModuleName .. ": TRPS_setup4_UnitNumLimits = " ..tostring(TRPS_setup4_var))	
	writeDebugBase(ModuleName .. ": TRPS_setup5_Limit_APC = " ..tostring(TRPS_setup5_var))	
	writeDebugBase(ModuleName .. ": TRPS_setup6_Limit_IFV = " ..tostring(TRPS_setup6_var))
	writeDebugBase(ModuleName .. ": TRPS_setup7_Limit_Tanks = " ..tostring(TRPS_setup7_var))
	writeDebugBase(ModuleName .. ": TRPS_setup8_Limit_ads = " ..tostring(TRPS_setup8_var))
	writeDebugBase(ModuleName .. ": TRPS_setup9_Limit_Arty = " ..tostring(TRPS_setup9_var))
	writeDebugBase(ModuleName .. ": TRPS_setup10_Year_Filter = " ..tostring(TRPS_setup10_var))
	writeDebugBase(ModuleName .. ": GOAP_var = " ..tostring(GOAP_var))

	-- debug call check (doesn't print if debugProcessDetail is false!)
	writeDebugDetail(ModuleName .. ": debugProcessDetail = " .. tostring(debugProcessDetail))

	-- assign auto save frequency in minutes
	if ATRL_var then
		autosavefrequency = tonumber(ATRL_time_var) * 60
	end
	
	-- check STO_var
	if STOP_var then
		if type(STOP_var) == 'number' then
			if STOP_var > 24 then
				STOP_var = nil
			end
		else
			STOP_var = nil
		end
	end

	-- ## DSMC LOCAL MODULES

	function cleanTemp()
		local dirToDel = DSMCtemp

		local deletedir
		deletedir = function(dir)
			for file in lfs.dir(dir) do
				if file then
					local file_path = dir..'/'..file
					if file ~= "." and file ~= ".." then
						if lfs.attributes(file_path, 'mode') == 'file' then
							os.remove(file_path)
							--print('remove file',file_path)
						elseif lfs.attributes(file_path, 'mode') == 'directory' then
							--print('dir', file_path)
							deletedir(file_path)
						end
					end
				end
			end
			lfs.rmdir(dir)
			--print('remove dir',dir)
		end


		deletedir(DSMCtemp)
	end

	-- this will decide the saved name in case of server mode and autosave on.
	function getNewMizFile(curPath)
		if curPath then
			if string.find(curPath, "DSMC_ServerReload_") then
				local start, stop = string.find(curPath, "DSMC_ServerReload_")
				local start2, stop2 = string.find(curPath, ".miz")
				local progNum = string.sub(curPath, stop+1, start2-1)
				writeDebugDetail(ModuleName .. ": progNum = " .. tostring(progNum))
				local numVal = tonumber(progNum)
				local numVal2 = string.format("%03d", progNum+1)
				local path = missionfilesdirectory .. "DSMC_ServerReload_" .. numVal2 .. ".miz"
				writeDebugDetail(ModuleName .. ": path = " .. tostring(path))
			
				return path
			else
				writeDebugDetail(ModuleName .. ": returning, DSMC_ServerReload_001.miz")
				return missionfilesdirectory .. "DSMC_ServerReload_001.miz"
			end
		else
			writeDebugDetail(ModuleName .. ": getNewMizFile, curPath non available")
		end
	end

	-- ## DSMC CORE MODULES
	UTIL						= require("UTIL")
	writeDebugBase(ModuleName .. ": loaded UTIL module")
	SAVE 						= require("SAVE")
	writeDebugBase(ModuleName .. ": loaded SAVE module")

	-- ## DSMC ADDITIONAL MODULES
	if UTIL.fileExist(DSMCdirectory .. "MOBJ" .. ".lua") == true and MOBJ_var == true then
		MOBJ 						= require("MOBJ")
		writeDebugBase(ModuleName .. ": loaded MOBJ module")
	end
	if UTIL.fileExist(DSMCdirectory .. "CRST" .. ".lua") == true and CRST_var == true then
		CRST 						= require("CRST")
		writeDebugBase(ModuleName .. ": loaded in CRST module")
	end
	if UTIL.fileExist(DSMCdirectory .. "WTHR" .. ".lua") == true and WTHR_var == true then
		WTHR 						= require("WTHR")
		writeDebugBase(ModuleName .. ": loaded in WTHR module")
	end
	if UTIL.fileExist(DSMCdirectory .. "WRHS" .. ".lua") == true and WRHS_var == true then
		WRHS 						= require("WRHS")
		writeDebugBase(ModuleName .. ": loaded in WRHS module")
	end
	if UTIL.fileExist(DSMCdirectory .. "TMUP" .. ".lua") == true and TMUP_var == true then
		TMUP 						= require("TMUP")
		writeDebugBase(ModuleName .. ": loaded in TMUP module")
	end
	if UTIL.fileExist(DSMCdirectory .. "SPWN" .. ".lua") == true and SPWN_var == true then
		SPWN 						= require("SPWN")
		writeDebugBase(ModuleName .. ": loaded in SPWN module")
	end
	if UTIL.fileExist(DSMCdirectory .. "UPAP" .. ".lua") == true and UPAP_var == true then
		UPAP 						= require("UPAP")
		writeDebugBase(ModuleName .. ": loaded in UPAP module")
	end
	if UTIL.fileExist(DSMCdirectory .. "SLOT" .. ".lua") == true and SLOT_var == true then
		SLOT 						= require("SLOT")
		writeDebugBase(ModuleName .. ": loaded in SLOT module")
	end
	if UTIL.fileExist(DSMCdirectory .. "GOAP" .. ".lua") == true and GOAP_var == true then
		GOAP 						= require("GOAP")
		writeDebugBase(ModuleName .. ": loaded in GOAP module")
	end

	-- check minimum settings to create callbacks
	if UTIL and SAVE then
		DSMCloader = true
	else
		writeDebugBase(ModuleName .. ": SAVER or UTIL failed loading, stop process")
		return
	end

end
loadDSMCHooks()

--## PROCESS FUNCTIONS

-- on load mod,try to recover server crash
function recoverAutosave()
	if 	UTIL.fileExist(DSMCfiles .. "tblDeadUnits.lua") and 
		UTIL.fileExist(DSMCfiles .. "tblDeadScenObj.lua") and
		UTIL.fileExist(DSMCfiles .. "tblUnitsUpdate.lua") and
		UTIL.fileExist(DSMCfiles .. "tblAirbases.lua") and
		UTIL.fileExist(DSMCfiles .. "tblLogistic.lua") and
		UTIL.fileExist(DSMCfiles .. "tblSpawned.lua") and
		UTIL.fileExist(DSMCfiles .. "tblConquer.lua") then
		
		--old_TAIR_var = TAIR_var
		--TAIR_var = false
		writeDebugBase(ModuleName .. ": there are recoverable files, recovering mission")
		loadedMissionPath = DSMCfiles .. "tempFile.miz"
		DSMC_isRecovering = true
		SAVE.getMizFiles(loadedMissionPath)
		batchSaveProcess()	
		os.remove(DSMCfiles .. "tempFile.miz")
		lfs.rmdir(DSMCfiles)
		lfs.rmdir(DSMCtemp)	

		writeDebugBase(ModuleName .. ": mission recovered")
		--TAIR_var = old_TAIR_var

		if UTIL.fileExist(lfs.writedir() .. "Logs/" .. "dcs.log.old") then
			UTIL.copyFile(lfs.writedir() .. "Logs/" .. "dcs.log.old", lfs.writedir() .. "Logs/" .. "dcs.log.old.crashed")
		end
		cleanTemp()

	else
		writeDebugBase(ModuleName .. ": no mission to recover")
		cleanTemp()
	end
end

-- callback on start
function startDSMCprocess()
	if UTIL and SAVE then
		
		--## CHECKING MIZ FILENAME, IF NOT DMSCyourfilename THEN STOP
		loadedMizFileName = DCS.getMissionName()
		loadedMissionPath = DCS.getMissionFilename()		
		writeDebugDetail(ModuleName .. ": loadedMissionPath: " .. tostring(loadedMissionPath))			
		writeDebugDetail(ModuleName .. ": loadedMizFileName: " .. tostring(loadedMizFileName))
		
		DCS_Multy	= DCS.isMultiplayer()
		DCS_Server 	= DCS.isServer()
		
		
		if loadedMizFileName and loadedMissionPath then				
			if string.sub(loadedMizFileName,1,4) == StartFilterCode then
			
				SAVE.getMizFiles(loadedMissionPath)
				if SAVE.tempEnv.mission and SAVE.tempEnv.warehouses and SAVE.tempEnv.dictionary and SAVE.tempEnv.mapResource then
					writeDebugDetail(ModuleName .. ": tempEnv.files available")

					--## FILTER PASSED, NOW LOADING EXTERNAL CODE INTO MISSION ENV (INJECTING)
					
					-- check group & unit max ID
					function setMaxId(mixfile)
						local curvalG = 0
						local curvalU = 0
						for coalitionID,coalition in pairs(mixfile["coalition"]) do
							for countryID,country in pairs(coalition["country"]) do
								for attrID,attr in pairs(country) do
									if (type(attr)=="table") then		
										for groupID,group in pairs(attr["group"]) do
											if (group) then
												if group.groupId then
													if curvalG < group.groupId then
														curvalG = group.groupId
													end
												end

												for unitID,unit in pairs(group["units"]) do
													if unit.unitId then
														if curvalU < unit.unitId then
															curvalU = unit.unitId
														end
													end
												end
											end
										end
									end
								end
							end
						end

						if curvalG > 0 and curvalU > 0 then
							writeDebugDetail(ModuleName .. ": setMaxId baseGcounter= " .. tostring(curvalG) .. ", baseUcounter= " .. tostring(curvalU))
							return curvalG, curvalU
						else
							writeDebugDetail(ModuleName .. ": setMaxId failed to get id results")
							return nil
						end
					end
					local baseGcounter, baseUcounter = setMaxId(SAVE.tempEnv.mission)

					if baseUcounter and baseGcounter then
						baseGcounter = baseGcounter + 1
						baseUcounter = baseUcounter + 1
					else
						writeDebugDetail(ModuleName .. ": setMaxId failed to get base counters! HALT ALL")
						return false
					end

					-- inject variables
					UTIL.inJectCode("DSMC_F10save", "DSMC_DisableF10save = " .. tostring(DSMC_DisableF10save)) -- DSMC_disableF10  menu option
					UTIL.inJectCode("DSMC_ServerMode", "DSMC_ServerMode = " .. tostring(DSMC_ServerMode)) -- DSMC_dediserv
					UTIL.inJectCode("DCSmulty", "DSMC_multy = " .. tostring(DCS.isMultiplayer()))
					UTIL.inJectCode("DCSserver", "DSMC_server = " .. tostring(DCS.isServer()))
					UTIL.inJectCode("DCSsamcleading", "DSMC_cleanSAMs = " .. tostring(DSMC_cleanDamagedSAMsites))	
					UTIL.inJectCode("debugProcessDetail", "DSMC_debugProcessDetail = " .. tostring(debugProcessDetail))
					UTIL.inJectCode("autosavefrequency", "DSMC_autosavefrequency = " .. tostring(autosavefrequency))
					UTIL.inJectCode("baseGcounter", "DSMC_baseGcounter = " .. tostring(baseGcounter))
					UTIL.inJectCode("baseUcounter", "DSMC_baseUcounter = " .. tostring(baseUcounter))
					
					--## EXPORT IN SSE ENVIRONMENT THE SAVE MODULE
					if STOP_var then
						UTIL.inJectCode("autoexitvar", "DSMC_AutosaveExit_hours = " .. tostring(STOP_var))
					end
					
					--if TAIR_var then
					--	UTIL.inJectCode("checkLandvar", "DSMC_LandPosUpdate = " .. tostring(TAIR_var))
					--end


					-- code from WRHS module
					if WRHS_var then
						local wrhStr, wrhStrErr = WRHS.createdbWeapon()	
						if not wrhStrErr then
							writeDebugDetail(ModuleName .. ": createdbWeapon, errors: " .. tostring(wrhStr))
						end					
						if WRHS.dbWeapon then
							if #WRHS.dbWeapon > 0 then					
								UTIL.inJectTable("dbWeapon", WRHS.dbWeapon)		
							else
								writeDebugDetail(ModuleName .. ": createdbWeapon, dbWeapon not injected cause table has 0 entry. probable all airbase are unlimited weapons")
							end
						else
							writeDebugDetail(ModuleName .. ": WRHS.dbWeapon void")
						end
					else
						writeDebugBase(ModuleName .. ": Embedded warehouses files not loaded: WRHS_var false")
					end
					
					-- code from TRPS module
					if TRPS_var then
						
						if TRPS_setup_var == true then
							UTIL.inJectCode("TRPS_Setup", "TRPSslingLoad_main = true")
						end

						if TRPS_setup3_var == true then
							UTIL.inJectCode("TRPS_Setup3", "TRPSallowCrates_main = true")
							if TRPS_setup2_var == true then
								UTIL.inJectCode("TRPS_Setup2", "TRPSallowPlatoons_main = true")
							end
							
							if TRPS_setup4_var == true then
								UTIL.inJectCode("TRPS_setup4_var", "TRPSUnitNumLimits = true")
							end							

							if TRPS_setup5_var then
								UTIL.inJectCode("TRPS_Setup5", "TRPSLimit_APC = " .. tostring(TRPS_setup5_var))
							end

							if TRPS_setup6_var then
								UTIL.inJectCode("TRPS_Setup6", "TRPSLimit_IFV = " .. tostring(TRPS_setup6_var))
							end

							if TRPS_setup7_var then
								UTIL.inJectCode("TRPS_Setup7", "TRPSLimit_Tanks = " .. tostring(TRPS_setup7_var))
							end

							if TRPS_setup8_var then
								UTIL.inJectCode("TRPS_Setup8", "TRPSLimit_ads = " .. tostring(TRPS_setup8_var))
							end

							if TRPS_setup9_var then
								UTIL.inJectCode("TRPS_Setup9", "TRPSLimit_Arty = " .. tostring(TRPS_setup9_var))
							end

							if TRPS_setup10_var == true then
								UTIL.inJectCode("TRPS_Setup10", "TRPSuseYearFilter = true")
								UTIL.inJectTable("TRPSdbYears", _G.dbYears)

							end
						end

						local t = io.open(DSMCdir .. "TRPS_inj.lua", "r")
						if t then
							local TRPS_Embeddedcode = tostring(t:read("*all"))
							t:close()
							UTIL.inJectCode("TRPS_Embeddedcode", TRPS_Embeddedcode)					
						else
							writeDebugDetail(ModuleName .. ": TRPS_inj.lua not found")	
						end

					else
						writeDebugBase(ModuleName .. ": TRPS not required")	
					end
					
					-- code from SPWN module
					if SPWN_var then
						writeDebugDetail(ModuleName .. ": configuring inside mission trackspawnedinfantry = " .. tostring(trackspawnedinfantry))
						UTIL.inJectCode("DSMC_trackspawnedinfantry", "DSMC_trackspawnedinfantry = true")
					else
						writeDebugBase(ModuleName .. ": SPWN not required")	
					end
					
					-- main loop code: EMDB file
					local e = io.open(DSMCdir .. "EMBD_inj.lua", "r")
					local Embeddedcode = nil
					if e then
						Embeddedcode = tostring(e:read("*all"))
						e:close()
					else
						writeDebugBase(ModuleName .. ": EMBD_inj.lua not found")
					end			
					UTIL.inJectCode("Embeddedcode", Embeddedcode)

					-- code from GOAP module
					if GOAP_var then
						writeDebugDetail(ModuleName .. ": activating automated AI")
						GOAP.loadTownTables(SAVE.tempEnv.mission.theatre)
						GOAP.loadCode()
					else
						writeDebugBase(ModuleName .. ": GOAP not required")	
					end					

					lfs.mkdir(DSMCtemp)
					lfs.mkdir(DSMCfiles)
					writeDebugDetail(ModuleName .. ": created dir = " .. tostring(missionfilesdirectory .. "Temp/"))
					UTIL.copyFile(loadedMissionPath, DSMCfiles .. "tempFile.miz")					
					
					writeDebugBase(ModuleName .. ": Initial loop done, mission is started now!")
					
				else
					writeDebugBase(ModuleName .. ": SAVE.getMizFiles failed. Stop process")
				end	
			else
				writeDebugBase(ModuleName .. ": Filename is not -DSMC(something)- format. Stop process")			
			end
		else
			writeDebugBase(ModuleName .. ": Failed to retrieve mission name information. Stop process")
		end

	else
		writeDebugBase(ModuleName .. ": ERROR: SAVE or UTIL module not available")
	end
end

-- callback on start
function desanitizer()
	if ATRL_var or DSMC_ServerMode then
		local f=io.open(missionscriptingluaPath,"r")
		if f~=nil then 
		
			local newText = ""
			for line in f:lines() do				
				if string.find(line, "sanitizeModule%('os'%)") and not string.find(line, "%-%-sanitizeModule%('os'%)") then
					local newline = string.gsub(line, "sanitizeModule%('os'%)", "%-%-sanitizeModule%('os'%), commented by DSMC: if you won't desanitized environment, please disable the autosave option!")	
					newText = newText .. tostring(newline) .. "\n"
				elseif string.find(line, "sanitizeModule%('io'%)") and not string.find(line, "%-%-sanitizeModule%('io'%)")  then
					local newline = string.gsub(line, "sanitizeModule%('io'%)", "%-%-sanitizeModule%('io'%), commented by DSMC: if you won't desanitized environment, please disable the autosave option!")	
					newText = newText .. tostring(newline) .. "\n"				
				elseif string.find(line, "sanitizeModule%('lfs'%)") and not string.find(line, "%-%-sanitizeModule%('lfs'%)")  then
					local newline = string.gsub(line, "sanitizeModule%('lfs'%)", "%-%-sanitizeModule%('lfs'%), commented by DSMC: if you won't desanitized environment, please disable the autosave option!")	
					newText = newText .. tostring(newline) .. "\n"					
				else
					newText = newText .. line .. "\n"
				end
			end
			
			io.close(f)
			
			--
			local o = io.open(missionscriptingluaPath, "w")
			o:write(newText)
			o:close()
			return true
			
		else 
			io.close(f) 
			return false 
		end		
	else
		writeDebugBase(ModuleName .. ": desanitizer, ATRL_var set false")
	end
end

-- function to load tables
function loadtables()
	writeDebugBase(ModuleName .. ": loadtables started")
	for entry in lfs.dir(DSMCfiles) do
		if entry ~= "." and entry ~= ".." then
			local attr = lfs.attributes(DSMCfiles .. entry)
			if attr.mode == "file" then
				writeDebugDetail(ModuleName .. ".loadtables : checking file = " .. tostring(entry))
				if string.find(entry, ".lua") and string.sub(entry, 1, 3) == "tbl" then
					local path = DSMCfiles .. entry
					writeDebugDetail(ModuleName .. ".loadtables : check 1")
					local tbl_fcn, tbl_err = dofile(path)
					if tbl_err then
						writeDebugDetail(ModuleName .. " loadtables : tbl_fcn = " .. tostring(tbl_fcn))
						writeDebugDetail(ModuleName .. " loadtables : tbl_err = " .. tostring(tbl_err))
					else
						writeDebugDetail(ModuleName .. " loadtables : imported table = " .. tostring(entry))
						os.remove(path)
					end
					
				end
			end
		end
	end

	-- debug utility
	if debugProcessDetail == true then
		writeDebugDetail(ModuleName .. ": dumping tables..")
		UTIL.dumpTable("tblDeadUnits.lua", tblDeadUnits)
		UTIL.dumpTable("tblDeadScenObj.lua", tblDeadScenObj)
		UTIL.dumpTable("tblUnitsUpdate.lua", tblUnitsUpdate)
		UTIL.dumpTable("tblAirbases.lua", tblAirbases)
		UTIL.dumpTable("tblLogistic.lua", tblLogistic)
		UTIL.dumpTable("tblSpawned.lua", tblSpawned)
		UTIL.dumpTable("tblConquer.lua", tblConquer)
		UTIL.dumpTable("tblLandPosition.lua", tblLandPosition)		
	end
	--]]--
end

--[[ function update serversettings.lua to enter saved mission as 1st
function makefirstmission(missionPath)
	if (DCS_Multy and DCS_Server) or DSMC_isRecovering == true then -- only server mode
		local future_file_path = getNewMizFile(loadedMissionPath)
		if future_file_path then -- a mission file was found
			writeDebugDetail(ModuleName .. ": makefirstmission future_file_path = " .. tostring(future_file_path))
			UTIL.copyFile(SAVE.NewMizPath, future_file_path)			
			local serSettingPath = configfilesdirectory .. "serverSettings.lua"
			if UTIL.fileExist(serSettingPath) then
				local serSettingString = nil
				if serSettingPath then
					local f = io.open(serSettingPath, 'r')
					if f then
						serSettingString = f:read('*all')
						f:close()
					end
				end		
				
				local changed = false
				local serEnv = {}
				if serSettingString then
					local sResFun, sErrStr 	= loadstring(serSettingString);
					
					if sResFun then
						setfenv(sResFun, serEnv)
						sResFun()								
						UTIL.dumpTable("serEnv.cfg.lua", serEnv.cfg)
						if serEnv.cfg then
							serEnv.cfg["missionList"][1] = future_file_path
							serEnv.cfg["current"] = 1
							writeDebugDetail(ModuleName .. ": makefirstmission serSetting modified")
						end
					end
				end
				local outFile = io.open(serSettingPath, "w");
				local newSrvConfigStr = UTIL.IntegratedserializeWithCycles('cfg', serEnv.cfg);
				outFile:write(newSrvConfigStr);
				io.close(outFile);
			end			
		end
		local stringOK = "trigger.action.outText('setup done!', 5)"
		if DSMC_isRecovering == false then
			UTIL.inJectCode("stringOK", stringOK)
		end
		DSMC_isRecovering = false
	else	
		writeDebugDetail(ModuleName .. ": makefirstmission stopped, no multy or no server")
	end
end
--]]--

function makefirstmission(missionPath)
	if missionPath then -- only server mode
		local future_file_path = missionPath
		if future_file_path then -- a mission file was found
			writeDebugDetail(ModuleName .. ": makefirstmission future_file_path = " .. tostring(future_file_path))
			--UTIL.copyFile(SAVE.NewMizPath, future_file_path)			
			local serSettingPath = configfilesdirectory .. "serverSettings.lua"
			if UTIL.fileExist(serSettingPath) then
				local serSettingString = nil
				if serSettingPath then
					local f = io.open(serSettingPath, 'r')
					if f then
						serSettingString = f:read('*all')
						f:close()
					end
				end		
				
				local serEnv = {}
				if serSettingString then
					local sResFun, sErrStr 	= loadstring(serSettingString);
					
					if sResFun then
						setfenv(sResFun, serEnv)
						sResFun()								
						UTIL.dumpTable("serEnv.cfg.lua", serEnv.cfg)
						if serEnv.cfg then
							serEnv.cfg["missionList"][1] = future_file_path
							serEnv.cfg["current"] = 1
							writeDebugDetail(ModuleName .. ": makefirstmission serSetting modified")
						end
					end
				end
				local outFile = io.open(serSettingPath, "w");
				local newSrvConfigStr = UTIL.IntegratedserializeWithCycles('cfg', serEnv.cfg);
				outFile:write(newSrvConfigStr);
				io.close(outFile);
			end			
		end
		local stringOK = "trigger.action.outText('setup done!', 5)"
		if DSMC_isRecovering == false then
			UTIL.inJectCode("stringOK", stringOK)
		end
		DSMC_isRecovering = false
	else	
		writeDebugBase(ModuleName .. ": makefirstmission stopped, no multy or no server")
	end

end

-- callback to create the new miz file
function batchSaveProcess()	
	writeDebugDetail(ModuleName .. ": batchSaveProcess started")
	if SAVE and UTIL then
		writeDebugDetail(ModuleName .. ": batchSaveProcess SAVE and UTIL are there")
		SAVE.NewMizPath = nil
		
		-- load tables
		loadtables()
		
		-- save updated mission file
		if tblAirbases and tblDeadUnits and tblDeadScenObj and tblUnitsUpdate and tblLogistic and tblSpawned and tblConquer then
			writeDebugBase(ModuleName .. ": batchSaveProcess loading SAVE.buildNewMizFile..")
			local saveComplete = SAVE.buildNewMizFile(loadedMissionPath, loadedMizFileName)
			writeDebugBase(ModuleName .. ": batchSaveProcess SAVE.buildNewMizFile done, valid save: " .. tostring(saveComplete))
		else
			writeDebugBase(ModuleName .. ": batchSaveProcess SAVE.buildNewMizFile failed, missing one or more table files")
			return
		end

		-- update serverSettings.lua
		if ATRL_var then
			if SAVE.NewMizPath then
				makefirstmission(SAVE.NewMizPath)
			else
				writeDebugDetail(ModuleName .. ": onPlayerDisconnect SAVE.NewMizPath not found!")
			end
		end
		
		-- clean old shared data
		tblAirbases = nil
		tblDeadUnits = nil 
		tblDeadScenObj = nil 
		tblUnitsUpdate = nil 
		tblLogistic = nil 
		tblSpawned = nil 
		tblConquer = nil

	end
end

-- callback to save on disconnect of last client
function saveOnDisconnect()
	local multy = DCS.isMultiplayer()
	if multy == true then
		writeDebugDetail(ModuleName .. ": onPlayerDisconnect checking for autosave")
		local num_clients = false
		local player_tbl = net.get_player_list()
		if player_tbl then
			num_clients = tonumber(#player_tbl) - 1
			writeDebugDetail(ModuleName .. ": there are " .. tostring(num_clients) .. " clients connected")
			if num_clients == 0 then
				if UPAP then
					HOOK.writeDebugDetail(ModuleName .. ": saveOnDisconnect disabled weather export")
					UPAP.weatherExport = false
				end	
				UTIL.inJectCode("DSCMsave", "EMBD.executeSAVE('recall')")
				writeDebugDetail(ModuleName .. ": autosave scheduled!")
			end			
		end	
	end
end

--## CALLBACKS
function DSMC.onSimulationStart()
	startDSMCprocess()
end

--## ALL EXTERNAL FUNCTIONS AND PROCESSES ARE ALWAYS ACTIVATED BY TRIGGER MESSAGE. ALSO MAIN INFORMATION ARE PASSED BY WITH TRIGGER MESSAGES
function DSMC.onTriggerMessage(message)	
	
	if string.sub(message, 1, 3) == "tbl" then	-- this will import & save any table that starts with "tbl"					
		local tableName = string.sub(message, 1, string.find(message, "=")-2)
		writeDebugDetail(ModuleName .. ": tableName = " .. tostring(tableName))
		local str, str_err = loadstring(tostring(message))
		if not str_err then -- check errors  -- == true 
			str()
			
			if tableName == "tblAirbases" then
				UTIL.saveTable(tableName, tblAirbases, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))
			elseif tableName == "tblDeadUnits" then
				UTIL.saveTable(tableName, tblDeadUnits, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))						
			elseif tableName == "tblDeadScenObj" then
				UTIL.saveTable(tableName, tblDeadScenObj, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))						
			elseif tableName == "tblUnitsUpdate" then
				UTIL.saveTable(tableName, tblUnitsUpdate, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))	
			elseif tableName == "tblLogistic" then
				UTIL.saveTable(tableName, tblLogistic, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))					
			elseif tableName == "tblSpawned" then
				UTIL.saveTable(tableName, tblSpawned, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))						
			elseif tableName == "tblConquer" then
				UTIL.saveTable(tableName, tblConquer, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))		
			elseif tableName == "tblLandPosition" then
				UTIL.saveTable(tableName, tblLandPosition, DSMCfiles)
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))
			elseif tableName == "tblLogCollect" then
				UTIL.dumpTable("tblLogCollect.lua", tblLogCollect)	
				writeDebugDetail(ModuleName .. ": recognized & saved " .. tostring(tableName))									
			end			
			writeDebugDetail(ModuleName .. ": table loaded")			
		else
			writeDebugBase(ModuleName .. ": error loading table")
			writeDebugBase(ModuleName .. ": table:\n" .. tostring(message) .. "\nError: " .. tostring(str))	
		end

	elseif message == "DSMC save..." then			
		--command save actions
		batchSaveProcess()

	elseif message == "DSMC is trying to restart the server! land or disconnect as soon as you can: DSMC will try again in 10 minutes" then			
		--command server closeup
		local num_clients = false
		local player_tbl = net.get_player_list()
		if player_tbl then
			num_clients = tonumber(#player_tbl) - 1
			writeDebugDetail(ModuleName .. ": there are " .. tostring(num_clients) .. " clients connected")
			if num_clients == 0 then
				writeDebugBase(ModuleName .. ": Closing DCS!")
				DCS.stopMission()
				DCSshouldCloseNow = true
			else
				writeDebugBase(ModuleName .. ": there are " .. tostring(num_clients) .. " clients connected, can't close DCS: delayed 10 mins")	
			end			
		end	
	end	
	
end

function DSMC.onPlayerDisconnect()
	saveOnDisconnect()
end

function DSMC.onRadioMessage(message, duration)
	writeDebugDetail(ModuleName .. ": test onRadioMessage = " .. tostring(message))

end

function DSMC.onShowGameMenu()
	writeDebugDetail(ModuleName .. ": test onShowGameMenu")

end

function DSMC.onSimulationStop()
	writeDebugBase(ModuleName .. ": starting DSMC.onSimulationStop() call..")
	if ATRL_var then
		batchSaveProcess()
		writeDebugBase(ModuleName .. ": DSMC.onSimulationStop() autosave file built process done - check if ok!")
	end
	
	-- do an educated clean
	if UTIL.fileExist(DSMCfiles .. "tempFile.miz") then
		os.remove(DSMCfiles .. "tempFile.miz")
	end
	lfs.rmdir(DSMCfiles)
	lfs.rmdir(DSMCtemp)	
	DCS_Multy = nil
	DCS_Server = nil
	
	if DCSshouldCloseNow == true then
		writeDebugBase(ModuleName .. ": DSMC.onSimulationStop() is calling the exitProcess, DCS is closing")
		DCS.exitProcess()
	end

end
	
writeDebugDetail(ModuleName .. ": callbacks loaded")
DCS.setUserCallbacks(DSMC)

desanitizer()
recoverAutosave()

if UTIL then
	--UTIL.whZeroer(lfs.writedir() .. "DSMC/zerowh.lua")
	--UTIL.whFixer(lfs.writedir() .. "DSMC/from.lua", lfs.writedir() .. "DSMC/to.lua")
	--UTIL.whCleaner(lfs.writedir() .. "DSMC/from.lua", lfs.writedir() .. "DSMC/zerowh.lua")
	--UTIL.whUnlimitedRemover(lfs.writedir() .. "DSMC/zerowh.lua")

	--UTIL.dumpTable("DB.db.Units.Helicopters.Helicopter.lua", DB.db.Units.Helicopters.Helicopter) 

end

writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)

--~=
