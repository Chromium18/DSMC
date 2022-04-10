-- Dynamic Sequential Mission Campaign -- HOOKS module


-- ## LIBS	
module('HOOK', package.seeall)	-- module name. All function in this file, if used outside, should be called "HOOK.functionname"
base 						= _G	
require 					= base.require		
io 							= require('io')
lfs 						= require('lfs')
os 							= require('os')
minizip 					= require('minizip')
local lang					= require('i18n')
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


DSMC_ModuleName  	= "HOOKS"
DSMC_MainVersion 	= "1"
DSMC_SubVersion 	= "2"
DSMC_SubSubVersion 	= "5"
DSMC_Build 			= "2082"
DSMC_Date			= "10/04/2021"

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
writeDebugDetail(DSMC_ModuleName .. ": local required and debug functions loaded")

--## MAIN VARIABLES
DSMC 						= {} -- main plugin table. Sim callback are here, while function is int the module (HOOK) 
tempEnv 					= {} -- 
StartFilterCode				= "DSMC"
writeDebugBase(DSMC_ModuleName .. ": main variables loaded")

-- ## LOCAL VARIABLES
DSMCloader 					= false
DCSshouldCloseNow			= false
mapObj_deathcounter 		= 0
baseGcounter 				= 100000 -- placeholder
baseUcounter		 		= 110000 -- placeholder
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
trackspawnedinfantry		= true
--ATRLloaded				= false
autosavefrequency			= nil -- minutes
DCS_Multy					= nil
DCS_Server					= nil
DSMC_isRecovering			= false
local alreadyStarted		= false
writeDebugDetail(DSMC_ModuleName .. ": local variables loaded")

-- ## PATHS VARIABLES
DSMCdirectory				= lfs.writedir() .. "DSMC/"
missionfilesdirectory 		= lfs.writedir() .. "Missions/"
DSMCtemp					= missionfilesdirectory .. "Temp/"
DSMCfiles					= missionfilesdirectory .. "Temp/Files/"  
tempmissionfilesdirectory	= lfs.tempdir() .. "DSMCunpack/"
--tempmissionfilesdirectory	= lfs.writedir() .. "DSMCunpack/"
configfilesdirectory		= lfs.writedir() .. "Config/"
NewMizTempDir 				= "SAVE_TempMix/"	
OldMissionPath 				= missionfilesdirectory .. "Temp/" .. "mission"
NewMissionPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .. "mission"
OldDictPath 				= missionfilesdirectory .. "Temp/" .. "dictionary"
NewDictPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/" .. "dictionary"	
OldMResPath 				= missionfilesdirectory .. "Temp/" .. "mapResource"
NewMResPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/" .. "mapResource"
NewFilesDir					= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."l10n/" .. "DEFAULT/"
OldWrhsPath 				= missionfilesdirectory .. "Temp/" .. "warehouses"
NewWrhsPath 				= missionfilesdirectory .. "Temp/" .. NewMizTempDir .."warehouses"
logpath 					= lfs.writedir() .. "Logs/mixpath.txt"
tempPath 					= missionfilesdirectory .. "DSMC_tempFile.miz"
missionscriptingluaPath		= lfs.currentdir() .. "Scripts/" .. "MissionScripting.lua"
writeDebugDetail(DSMC_ModuleName .. ": paths variable loaded")
-- REMEMBER!!!!! for temp save into the SSE, EMBD.saveTable has DSMCfiles path hardcoded into the function!!!!

DSMC_ServerMode = true
if _G.panel_aircraft then
	DSMC_ServerMode = false
end

-- loading proper options from custom file (if dedicated server) or options menù (if standard)
function loadDSMCHooks()

	local forceServerMode = false -- debug purpose

	if DSMC_ServerMode == true or forceServerMode == true then
		writeDebugBase(DSMC_ModuleName .. ": Server mode active")
		local dso_fcn, dso_err = dofile(DSOdir .. "DSMC_Dedicated_Server_options.lua")
		if dso_err then
			writeDebugBase(DSMC_ModuleName .. ": dso_fcn error = " .. tostring(dso_fcn))
			writeDebugBase(DSMC_ModuleName .. ": dso_err error = " .. tostring(dso_err))
		end
	else
		writeDebugBase(DSMC_ModuleName .. ": Standard mode active")	
		local opt_fcn, opt_err = dofile(lfs.writedir() .. "Config/options.lua")
		if opt_err then
			writeDebugBase(DSMC_ModuleName .. ": opt_fcn error = " .. tostring(opt_fcn))
			writeDebugBase(DSMC_ModuleName .. ": opt_err error = " .. tostring(opt_err))
		end
		if options then
			for opt_id, opt_data in pairs(options) do
				if opt_id == "plugins" then
					for pl_id, pl_data in pairs (opt_data) do
						if pl_id == "DSMC" then						
							opt_MOBJ_var 		= true -- pl_data.MOBJ
							opt_CRST_var 		= pl_data.CRST	
							opt_WTHR_var 		= true -- pl_data.WTHR		
							opt_TMUP_var		= true -- pl_data.TMUP
							opt_TMUP_cont_var	= pl_data.timer_options	or 2
							opt_WRHS_var		= true -- pl_data.WRHS
							opt_SPWN_var		= true -- pl_data.SPWN
							opt_DEBUG_var		= pl_data.DEBUG
							opt_ATRL_var		= pl_data.ATRL
							opt_ATRL_time_var	= pl_data.ATRL_time
							--opt_UPAP_var		= pl_data.UPAP			
							opt_SLOT_var		= pl_data.SLOT
							opt_SLOT_ab_var		= pl_data.SLOT_ab
							opt_PLAN_var		= pl_data.PLAN
							--opt_SBEO			= pl_data.SBEO

							--opt_SLOT			= pl_data.SLOT
						end
					end
				end
			end
		end		
	end

	-- assign variables
	MOBJ_var 							= true -- opt_MOBJ_var or DSMC_MapPersistence
	CRST_var 							= opt_CRST_var or DSMC_StaticDeadUnits		
	WTHR_var 							= true -- opt_WTHR_var or DSMC_WeatherUpdate	
	WTHR_fog							= DSMC_DisableFog or false	
	TMUP_var							= true -- opt_TMUP_var or DSMC_UpdateStartTime		
	TMUP_cont_var						= opt_TMUP_cont_var or DSMC_UpdateStartTime_mode	
	WRHS_var							= true -- opt_WRHS_var or DSMC_TrackWarehouses
	WRHS_rblt							= DSMC_WarehouseAutoSetup or false
	SPWN_var							= true -- opt_SPWN_var or DSMC_TrackSpawnedUnits
	DEBUG_var							= opt_DEBUG_var or DSMC_DebugMode
	ATRL_var							= opt_ATRL_var or DSMC_AutosaveProcess 
	ATRL_time_var						= opt_ATRL_time_var or DSMC_AutosaveProcess_min 
	UPAP_var							= DSMC_ExportDocuments or false -- opt_UPAP_var or    NOT USED NOW if true mission briefings will be updated from a mission to another
	--TAIR_var							= opt_TAIR_var or DSMC_SaveLastPlanePosition
	SLOT_var							= opt_SLOT_var or DSMC_CreateSlotHeliports
	SLOT_coa_var						= DSMC_CreateSlotCoalition or "all" -- to test, set this "blue" or "red"
	SLOT_add_ab							= opt_SLOT_ab_var or DSMC_CreateSlotAirbases -- to test, set this "blue" or "red"
	STOP_var							= DSMC_AutosaveExit_hours
	STOP_var_time						= DSMC_AutosaveExit_time
	STOP_var_safe						= DSMC_AutosaveExit_safe
	RSTS_var							= DSMC_AutoRestart_active
	UMLS_var							= DSMC_updateMissionList
	S247_var							= DSMC_24_7_serverStandardSetup
	SBEO_var							= DSMC_BuilderToolsBeta or false -- opt_SBEO or    NOT USED NOW if true some mess may happen
	PLAN_var							= false -- opt_PLAN_var or DSMC_AutomaticAI
	RTAI_var							= false -- opt_PLAN_var or DSMC_AutomaticAI
	CTLD1_var							= DSMC_ctld_recognizeHelos or false
	CTLD2_var							= DSMC_ctld_recognizeVehicles or false

	-- debug call
	debugProcessDetail = DEBUG_var

	-- reset variable depending from DSMC_24_7_serverStandardSetup
	if S247_var and S247_var > 0 then
		writeDebugBase(DSMC_ModuleName .. ": S247_var is a valid setting: " ..tostring(S247_var))
		if S247_var > 24 then S247_var = 0 end
		writeDebugBase(DSMC_ModuleName .. ": S247_var filtered: " ..tostring(S247_var))
		
		if S247_var > 0 then
			writeDebugBase(DSMC_ModuleName .. ": S247_var filtered child variables")
			UMLS_var = true
			STOP_var = S247_var
			STOP_var_time = 0
			STOP_var_safe = true
			RSTS_var = false
		end
	end

	-- debug call
	writeDebugBase(DSMC_ModuleName .. ": S247_var = " ..tostring(S247_var))
	writeDebugBase(DSMC_ModuleName .. ": MOBJ_var = " ..tostring(MOBJ_var))
	writeDebugBase(DSMC_ModuleName .. ": CRST_var = " ..tostring(CRST_var))
	writeDebugBase(DSMC_ModuleName .. ": WTHR_var = " ..tostring(WTHR_var))
	writeDebugBase(DSMC_ModuleName .. ": WTHR_fog = " ..tostring(WTHR_fog))
	writeDebugBase(DSMC_ModuleName .. ": TMUP_var = " ..tostring(TMUP_var))
	writeDebugBase(DSMC_ModuleName .. ": TMUP_cont_var = " ..tostring(TMUP_cont_var))
	writeDebugBase(DSMC_ModuleName .. ": WRHS_var = " ..tostring(WRHS_var))
	writeDebugBase(DSMC_ModuleName .. ": SPWN_var = " ..tostring(SPWN_var))
	writeDebugBase(DSMC_ModuleName .. ": DEBUG_var = " ..tostring(DEBUG_var))
	writeDebugBase(DSMC_ModuleName .. ": ATRL_var = " ..tostring(ATRL_var))
	writeDebugBase(DSMC_ModuleName .. ": ATRL_time_var = " ..tostring(ATRL_time_var))
	--writeDebugBase(DSMC_ModuleName .. ": TAIR_var = " ..tostring(TAIR_var))
	writeDebugBase(DSMC_ModuleName .. ": SLOT_var = " ..tostring(SLOT_var))
	writeDebugBase(DSMC_ModuleName .. ": SLOT_coa_var = " ..tostring(SLOT_coa_var))
	writeDebugBase(DSMC_ModuleName .. ": SLOT_add_ab = " ..tostring(SLOT_add_ab))	
	writeDebugBase(DSMC_ModuleName .. ": UPAP_var = " ..tostring(UPAP_var))
	writeDebugBase(DSMC_ModuleName .. ": STOP_var = " ..tostring(STOP_var))
	writeDebugBase(DSMC_ModuleName .. ": STOP_var_time = " ..tostring(STOP_var_time))
	writeDebugBase(DSMC_ModuleName .. ": STOP_var_safe = " ..tostring(STOP_var_safe))
	writeDebugBase(DSMC_ModuleName .. ": RSTS_var = " ..tostring(RSTS_var))
	writeDebugBase(DSMC_ModuleName .. ": UMLS_var = " ..tostring(UMLS_var))
	writeDebugBase(DSMC_ModuleName .. ": SBEO_var = " ..tostring(SBEO_var))
	writeDebugBase(DSMC_ModuleName .. ": CTLD1_var = " ..tostring(CTLD1_var))
	writeDebugBase(DSMC_ModuleName .. ": CTLD2_var = " ..tostring(CTLD2_var))

	writeDebugBase(DSMC_ModuleName .. ": PLAN_var = " ..tostring(PLAN_var))

	-- debug call check (doesn't print if debugProcessDetail is false!)
	writeDebugDetail(DSMC_ModuleName .. ": debugProcessDetail = " .. tostring(debugProcessDetail))

	-- assign auto save frequency in minutes
	if ATRL_var then
		autosavefrequency = tonumber(ATRL_time_var) * 60
	end
	
	-- check STOP_var
	if STOP_var then
		if type(STOP_var) == 'number' then
			if STOP_var > 24 then
				STOP_var = nil
			end
		else
			STOP_var = nil
		end
	end

	-- check STOP_var_time
	if STOP_var_time then
		if not STOP_var then
			if type(STOP_var_time) == 'number' then
				if STOP_var_time > 23 or STOP_var_time < 1 then
					STOP_var_time = nil
				end
			else
				STOP_var_time = nil
			end
		else
			STOP_var_time = nil
		end
	end

	-- ## DSMC LOCAL MODULES

	function cleanTemp()

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
				writeDebugDetail(DSMC_ModuleName .. ": progNum = " .. tostring(progNum))
				local numVal = tonumber(progNum)
				local numVal2 = string.format("%03d", progNum+1)
				local path = missionfilesdirectory .. "DSMC_ServerReload_" .. numVal2 .. ".miz"
				writeDebugDetail(DSMC_ModuleName .. ": path = " .. tostring(path))
			
				return path
			else
				writeDebugDetail(DSMC_ModuleName .. ": returning, DSMC_ServerReload_001.miz")
				return missionfilesdirectory .. "DSMC_ServerReload_001.miz"
			end
		else
			writeDebugDetail(DSMC_ModuleName .. ": getNewMizFile, curPath non available")
		end
	end

	-- ## DSMC CORE MODULES
	UTIL						= require("UTIL")
	writeDebugBase(DSMC_ModuleName .. ": loaded UTIL module")
	SAVE 						= require("SAVE")
	writeDebugBase(DSMC_ModuleName .. ": loaded SAVE module")

	-- ## DSMC ADDITIONAL MODULES
	if UTIL.fileExist(DSMCdirectory .. "MOBJ" .. ".lua") == true and MOBJ_var == true then
		MOBJ 						= require("MOBJ")
		writeDebugBase(DSMC_ModuleName .. ": loaded MOBJ module")
	end
	if UTIL.fileExist(DSMCdirectory .. "CRST" .. ".lua") == true and CRST_var == true then
		CRST 						= require("CRST")
		writeDebugBase(DSMC_ModuleName .. ": loaded in CRST module")
	end
	if UTIL.fileExist(DSMCdirectory .. "WTHR" .. ".lua") == true and WTHR_var == true then
		WTHR 						= require("WTHR")
		writeDebugBase(DSMC_ModuleName .. ": loaded in WTHR module")
	end
	if UTIL.fileExist(DSMCdirectory .. "WRHS" .. ".lua") == true and WRHS_var == true then
		WRHS 						= require("WRHS")
		writeDebugBase(DSMC_ModuleName .. ": loaded in WRHS module")
	end
	if UTIL.fileExist(DSMCdirectory .. "TMUP" .. ".lua") == true and TMUP_var == true then
		TMUP 						= require("TMUP")
		writeDebugBase(DSMC_ModuleName .. ": loaded in TMUP module")
	end
	if UTIL.fileExist(DSMCdirectory .. "SPWN" .. ".lua") == true and SPWN_var == true then
		SPWN 						= require("SPWN")
		writeDebugBase(DSMC_ModuleName .. ": loaded in SPWN module")
	end
	if UTIL.fileExist(DSMCdirectory .. "UPAP" .. ".lua") == true and UPAP_var == true then
		UPAP 						= require("UPAP")
		writeDebugBase(DSMC_ModuleName .. ": loaded in UPAP module")
	end
	if UTIL.fileExist(DSMCdirectory .. "SLOT" .. ".lua") == true then
		if SLOT_var == true or SLOT_ab_var == true then
			SLOT 						= require("SLOT")
			writeDebugBase(DSMC_ModuleName .. ": loaded in SLOT module")
		end
	end
	if UTIL.fileExist(DSMCdirectory .. "PLAN" .. ".lua") == true and UTIL.fileExist(DSMCdirectory .. "GOAP" .. ".lua") == true and UTIL.fileExist(DSMCdirectory .. "DLNY" .. ".lua") == true and PLAN_var == true then
		DLNY 						= require("DLNY")
		GOAP 						= require("GOAP")
		PLAN 						= require("PLAN")	
		writeDebugBase(DSMC_ModuleName .. ": loaded in PLAN module")
	end
	if UTIL.fileExist(DSMCdirectory .. "ADTR" .. ".lua") == true then
		ADTR 						= require("ADTR")
		writeDebugBase(DSMC_ModuleName .. ": loaded in ADTR module")
	end

	-- check minimum settings to create callbacks
	if UTIL and SAVE then
		DSMCloader = true
	else
		writeDebugBase(DSMC_ModuleName .. ": SAVER or UTIL failed loading, stop process")
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
		writeDebugBase(DSMC_ModuleName .. ": there are recoverable files, recovering mission")
		loadedMissionPath = DSMCfiles .. "tempFile.miz"
		DSMC_isRecovering = true
		SAVE.getMizFiles(loadedMissionPath)
		batchSaveProcess()	
		os.remove(DSMCfiles .. "tempFile.miz")
		lfs.rmdir(DSMCfiles)
		lfs.rmdir(DSMCtemp)	

		writeDebugBase(DSMC_ModuleName .. ": mission recovered")
		--TAIR_var = old_TAIR_var

		if UTIL.fileExist(lfs.writedir() .. "Logs/" .. "dcs.log.old") then
			UTIL.copyFile(lfs.writedir() .. "Logs/" .. "dcs.log.old", lfs.writedir() .. "Logs/" .. "dcs.log.old.crashed")
		end
		cleanTemp()

	else
		writeDebugBase(DSMC_ModuleName .. ": no mission to recover")
		cleanTemp()
	end
end

writeDebugDetail(DSMC_ModuleName .. ": loading loadrestart function..")

function loadRestart()


	writeDebugDetail(DSMC_ModuleName .. ": loadRestart, started")

	-- WARNING: DO NOT INDENT LINES BELOW OR THE BATCH FILE WON'T WORK ANYMORE PROPERLY!!!!

local code = [[echo Checking DCS process...
@echo off
REM this script is done to provide restart automation
set "titleWhileRunning=DSMC_DCS_Server_Monitor"
]] .. "\n"
code = code .. 'set DCS_PATH=' .. '"' .. lfs.currentdir() .. [[bin\]] .. '"' .. "\n"
code = code .. [[for /f "tokens=2 delims=," %%a in ('
tasklist /fi "imagename eq cmd.exe" /v /fo:csv /nh 
^| findstr /r /c:".DSMC_DCS[^,]$" ') do echo Powershell script already running, wait for it to finish. >&2 & exit /b 1

title %titleWhileRunning%
taskkill /F /IM DCS.exe
Color 9A
echo LAUNCHING DCS...

:Serverrestart
cd /D %DCS_PATH%
start "" /wait /min DCS.exe --server --norender
timeout 40
echo ============
goto Serverrestart]]

	writeDebugDetail(DSMC_ModuleName .. ": loadRestart, code created")

	local o = io.open(DSMCdirectory .. 'Files/' .. "DSMC_Restart_DCS.bat", "w")
	o:write(code)
	o:close()

	writeDebugDetail(DSMC_ModuleName .. ": loadRestart, .bat file created")

	local revString = DSMCdirectory .. 'Files/' .. 'DSMC_Restart_DCS.bat'
	local startString = string.gsub(revString, "\\", "/")

	--[[""C:\Program Files\National Instruments\LabVIEW 2009\LabVIEW.exe" "C:\Program Files\National Instruments\LabVIEW 2009\examples\viserver\cmdline.llb\CommandLine.vi" -- 4.0"]]
	local strCmd = tostring(startString)
	writeDebugDetail(DSMC_ModuleName .. ": loadRestart, " .. strCmd)

	local function Execute(cmd)
		local exitCode = os.execute(cmd)
		if exitCode ~= 0 then
		   -- If the exit status isn't 0 this should indicate the execution
		   -- wasn't a complete success. We'll return the pre-defined error
		   -- message for this exit status or a generic one.
		   return "Done with possible errors exit code "..exitCode..":\r\n"..cmd
		else
		   return "Done"
		end
	end

	local loading, errors = Execute(tostring('"' .. strCmd ..  '"'))
	writeDebugDetail(DSMC_ModuleName .. ": loadRestart, .bat file executed: " .. tostring(loading))
	writeDebugDetail(DSMC_ModuleName .. ": loadRestart, .bat file errors: " .. tostring(errors))

	--local retry, reErrors = Execute([["C:/Users/Admin/Saved Games/DCS.openbeta_server/DSMC/Files/DSMC_Restart_DCS.bat"]])
	--writeDebugDetail(DSMC_ModuleName .. ": loadRestart, .bat file retry: " .. tostring(retry))
	--writeDebugDetail(DSMC_ModuleName .. ": loadRestart, .bat file reErrors: " .. tostring(reErrors))

end

writeDebugDetail(DSMC_ModuleName .. ": loadrestart function done")

-- callback on start
function startDSMCprocess()
	if UTIL and SAVE then

		--UTIL.dumpTable("nightlyGa.lua", _G)

		--## CHECKING MIZ FILENAME, IF NOT DMSCyourfilename THEN STOP
		loadedMizFileName = DCS.getMissionName()
		loadedMissionPath = DCS.getMissionFilename()		
		writeDebugDetail(DSMC_ModuleName .. ": loadedMissionPath: " .. tostring(loadedMissionPath))			
		writeDebugDetail(DSMC_ModuleName .. ": loadedMizFileName: " .. tostring(loadedMizFileName))
		
		DCS_Multy	= DCS.isMultiplayer()
		DCS_Server 	= DCS.isServer()
		
		if not DCS_Multy then
			WRHS_rblt = true
		end
		
		if loadedMizFileName and loadedMissionPath then				
			if string.sub(loadedMizFileName,1,4) == StartFilterCode then
				alreadyStarted = true

				SAVE.getMizFiles(loadedMissionPath)
				if SAVE.tempEnv.mission and SAVE.tempEnv.warehouses and SAVE.tempEnv.dictionary and SAVE.tempEnv.mapResource then
					writeDebugDetail(DSMC_ModuleName .. ": tempEnv.files available")

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
							writeDebugDetail(DSMC_ModuleName .. ": setMaxId baseGcounter= " .. tostring(curvalG) .. ", baseUcounter= " .. tostring(curvalU))
							return curvalG, curvalU
						else
							writeDebugDetail(DSMC_ModuleName .. ": setMaxId failed to get id results")
							return nil
						end
					end
					local baseGcounter, baseUcounter = setMaxId(SAVE.tempEnv.mission)

					if baseUcounter and baseGcounter then
						baseGcounter = baseGcounter + 1
						baseUcounter = baseUcounter + 1

						writeDebugDetail(DSMC_ModuleName .. ": creating temp folders...")
						lfs.mkdir(DSMCtemp)
						lfs.mkdir(DSMCfiles)
						writeDebugDetail(DSMC_ModuleName .. ": created dir = " .. tostring(missionfilesdirectory .. "Temp/"))

						-- filter units table
						
						UTIL.filterNamingTables(SAVE.tempEnv.mission) --SAVE.tempEnv.dictionary

						-- inject version
						UTIL.inJectCode("DSMC_MainVersion", "DSMC_MainVersion = " .. tostring(DSMC_MainVersion))
						UTIL.inJectCode("DSMC_SubVersion", "DSMC_SubVersion = " .. tostring(DSMC_SubVersion))
						UTIL.inJectCode("DSMC_Build", "DSMC_Build = " .. tostring(DSMC_Build))
						UTIL.inJectCode("DSMC_Date", "DSMC_Date = " .. tostring(DSMC_Date))

						-- inject variables
						UTIL.inJectCode("DSMC_F10save", "DSMC_DisableF10save = " .. tostring(DSMC_DisableF10save)) -- DSMC_disableF10  menu option
						UTIL.inJectCode("DSMC_ServerMode", "DSMC_ServerMode = " .. tostring(DSMC_ServerMode)) -- DSMC_dediserv
						UTIL.inJectCode("DCSmulty", "DSMC_multy = " .. tostring(DCS.isMultiplayer()))
						UTIL.inJectCode("DCSserver", "DSMC_server = " .. tostring(DCS.isServer()))
						UTIL.inJectCode("debugProcessDetail", "DSMC_debugProcessDetail = " .. tostring(debugProcessDetail))
						UTIL.inJectCode("autosavefrequency", "DSMC_autosavefrequency = " .. tostring(autosavefrequency))
						UTIL.inJectCode("baseGcounter", "DSMC_baseGcounter = " .. tostring(baseGcounter))
						UTIL.inJectCode("baseUcounter", "DSMC_baseUcounter = " .. tostring(baseUcounter))
						
						-- inject tables
						if UTIL.ctryList then
							writeDebugBase(DSMC_ModuleName .. ": injecting ctryList")
							UTIL.inJectTable("ctryList", UTIL.ctryList)
						end

						--## EXPORT IN SSE ENVIRONMENT THE SAVE MODULE
						if STOP_var then
							UTIL.inJectCode("autoexitvar", "DSMC_AutosaveExit_timer = " .. tostring(STOP_var*3600))
						elseif STOP_var_time then
							
							local date_table = os.date("*t")
							local hour, minute, second = date_table.hour, date_table.min, date_table.sec
							local hour_s = hour*3600
							local min_s = minute*60
							local curSec = second+min_s+hour_s
							writeDebugDetail(DSMC_ModuleName .. ": curSec = " .. tostring(curSec))
							local deltaSeconds = nil
							if STOP_var_time*3600 > curSec then
								deltaSeconds = (STOP_var_time*3600) - curSec 
							else
								deltaSeconds = (24*3600) - curSec + (STOP_var_time*3600)
							end

							writeDebugDetail(DSMC_ModuleName .. ": deltaSeconds = " .. tostring(deltaSeconds))
							if deltaSeconds then
								
								UTIL.inJectCode("autoexitvar", "DSMC_AutosaveExit_timer = " .. tostring(deltaSeconds))
							end
						end

						-- code from WRHS module
						if WRHS_var then
							local wrhStr, wrhStrErr = WRHS.createdbWeapon()	
							if not wrhStrErr then
								writeDebugDetail(DSMC_ModuleName .. ": createdbWeapon, errors: " .. tostring(wrhStr))
							end					
							if WRHS.dbWeapon then
								if #WRHS.dbWeapon > 0 then					
									UTIL.inJectTable("dbWeapon", WRHS.dbWeapon)
									UTIL.inJectCode("WRHS_active", "WRHS_module_active = true")
									UTIL.inJectTable("dbWarehouse", SAVE.tempEnv.warehouses)
									if HOOK.debugProcessDetail then
										--UTIL.dumpTable("dbWarehouse.lua", SAVE.tempEnv.warehouses)
									end
								else
									writeDebugDetail(DSMC_ModuleName .. ": createdbWeapon, dbWeapon not injected cause table has 0 entry. probable all airbase are unlimited weapons")
								end
							else
								writeDebugDetail(DSMC_ModuleName .. ": WRHS.dbWeapon void")
							end
						else
							writeDebugBase(DSMC_ModuleName .. ": Embedded warehouses files not loaded: WRHS_var false")
						end

						-- code from SPWN module
						if SPWN_var then
							writeDebugDetail(DSMC_ModuleName .. ": configuring inside mission trackspawnedinfantry = " .. tostring(trackspawnedinfantry))
							UTIL.inJectCode("DSMC_trackspawnedinfantry", "DSMC_trackspawnedinfantry = true")
						else
							writeDebugBase(DSMC_ModuleName .. ": SPWN not required")	
						end
						
						-- CTLD Supports
						if CTLD1_var == true then
							UTIL.inJectCode("CTLD1_var_code", "DSMC_ctld_var1 = true")
						end
						if CTLD2_var == true then
							UTIL.inJectCode("CTLD2_var_code", "DSMC_ctld_var2 = true")
						end

						-- main loop code: EMDB file
						local e = io.open(DSMCdir .. "EMBD_inj.lua", "r")
						local Embeddedcode = nil
						if e then
							Embeddedcode = tostring(e:read("*all"))
							e:close()
						else
							writeDebugBase(DSMC_ModuleName .. ": EMBD_inj.lua not found")
						end			
						UTIL.inJectCode("Embeddedcode", Embeddedcode)
						writeDebugDetail(DSMC_ModuleName .. ": EMBD injected")

						local tblThreats = UTIL.getThreatRanges()
						if tblThreats then
							UTIL.inJectTable("EMBD.tblThreatsRange", tblThreats)
							writeDebugDetail(DSMC_ModuleName .. ": tblThreats injected")
						else
							writeDebugDetail(DSMC_ModuleName .. ": can't inject tblThreats")
						end

						-- code from PLAN module
						if PLAN_var then
							writeDebugDetail(DSMC_ModuleName .. ": activating tactical AI planning (PLAN)")
							PLAN.initProcess()
							writeDebugDetail(DSMC_ModuleName .. ": tactical AI planning activated")
						else
							writeDebugBase(DSMC_ModuleName .. ": PLAN not required")	
						end		
						
						if RTAI_var then
							writeDebugDetail(DSMC_ModuleName .. ": activating real time AI enhancement")
							local e = io.open(DSMCdir .. "RTAI_inj.lua", "r")
							local Embeddedcode = nil
							if e then
								Embeddedcode = tostring(e:read("*all"))
								e:close()
							else
								writeDebugBase(DSMC_ModuleName .. ": RTAI_inj.lua not found")
							end			
							UTIL.inJectCode("Embeddedcode", Embeddedcode)
						else
							writeDebugBase(DSMC_ModuleName .. ": RTAI not required")	
						end		

						writeDebugDetail(DSMC_ModuleName .. ": loaded all variables")

						--lfs.mkdir(DSMCtemp)
						--lfs.mkdir(DSMCfiles)
						--writeDebugDetail(DSMC_ModuleName .. ": created dir = " .. tostring(missionfilesdirectory .. "Temp/"))
						
						UTIL.copyFile(loadedMissionPath, DSMCfiles .. "tempFile.miz")		
						writeDebugDetail(DSMC_ModuleName .. ": base file copied")

						--local tmpSlots = DCS.getAvailableSlots("blue")
						--UTIL.dumpTable("slotsData.lua", tmpSlots)


						
						if STOP_var or STOP_var then
							if RSTS_var then
								writeDebugBase(DSMC_ModuleName .. ": STOP_var is true, activating autorestart .bat file")
								loadRestart()
								writeDebugBase(DSMC_ModuleName .. ": STOP_var is true, .bat file activated")
							end
						else
							writeDebugBase(DSMC_ModuleName .. ": STOP_var is false, no autorestart required")
						end

						writeDebugBase(DSMC_ModuleName .. ": Initial loop done, mission is started now!")
					else
						writeDebugDetail(DSMC_ModuleName .. ": setMaxId failed to get base counters! HALT ALL")
						return false
					end					

				else
					writeDebugBase(DSMC_ModuleName .. ": SAVE.getMizFiles failed. Stop process")
				end	
			else
				writeDebugBase(DSMC_ModuleName .. ": Filename is not -DSMC(something)- format. Stop process")			
			end
		else
			writeDebugBase(DSMC_ModuleName .. ": Failed to retrieve mission name information. Stop process")
		end

	else
		writeDebugBase(DSMC_ModuleName .. ": ERROR: SAVE or UTIL module not available")
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
				elseif string.find(line, "%_G%['require'%] = nil") and not string.find(line, "%-%-%_G%['require'%] = nil")  then
					local newline = string.gsub(line, "%_G%['require'%] = nil", "%-%-%_G%['require'%] = nil, commented by DSMC: if you won't desanitized environment, please disable the autosave option!")	
					newText = newText .. tostring(newline) .. "\n"
				elseif string.find(line, "%_G%['loadlib'%] = nil") and not string.find(line, "%-%-%_G%['loadlib'%] = nil")  then
					local newline = string.gsub(line, "%_G%['loadlib'%] = nil", "%-%-%_G%['loadlib'%] = nil, commented by DSMC: if you won't desanitized environment, please disable the autosave option!")	
					newText = newText .. tostring(newline) .. "\n"	
				elseif string.find(line, "%_G%['package'%] = nil") and not string.find(line, "%-%-%_G%['package'%] = nil")  then
					local newline = string.gsub(line, "%_G%['package'%] = nil", "%-%-%_G%['package'%] = nil, commented by DSMC: if you won't desanitized environment, please disable the autosave option!")	
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
		writeDebugBase(DSMC_ModuleName .. ": desanitizer, ATRL_var set false")
	end
end

-- function to load tables
function loadtables()
	writeDebugBase(DSMC_ModuleName .. ": loadtables started")
	for entry in lfs.dir(DSMCfiles) do
		if entry ~= "." and entry ~= ".." then
			local attr = lfs.attributes(DSMCfiles .. entry)
			if attr.mode == "file" then
				writeDebugDetail(DSMC_ModuleName .. ": loadtables : checking file = " .. tostring(entry))
				if string.find(entry, ".lua") and string.sub(entry, 1, 3) == "tbl" then
					local path = DSMCfiles .. entry
					local tbl_fcn, tbl_err = dofile(path)
					if tbl_err then
						writeDebugDetail(DSMC_ModuleName .. ": loadtables : tbl_fcn = " .. tostring(tbl_fcn))
						writeDebugDetail(DSMC_ModuleName .. ": loadtables : tbl_err = " .. tostring(tbl_err))
					else
						writeDebugDetail(DSMC_ModuleName .. ": loadtables : imported table = " .. tostring(entry))
						os.remove(path)
					end
					
				end
			end
		end
	end

	-- debug utility
	if debugProcessDetail == true then
		writeDebugDetail(DSMC_ModuleName .. ": dumping tables..")
		UTIL.dumpTable("tblDeadUnits.lua", tblDeadUnits)
		UTIL.dumpTable("tblDeadScenObj.lua", tblDeadScenObj)
		UTIL.dumpTable("tblUnitsUpdate.lua", tblUnitsUpdate)
		UTIL.dumpTable("tblAirbases.lua", tblAirbases)
		UTIL.dumpTable("tblLogistic.lua", tblLogistic)
		UTIL.dumpTable("tblSpawned.lua", tblSpawned)
		UTIL.dumpTable("tblConquer.lua", tblConquer)
		UTIL.dumpTable("tblWarehouseChangeCoa.lua", tblWarehouseChangeCoa)
		UTIL.dumpTable("tblIntelDb.lua", tblIntelDb)
		UTIL.dumpTable("tblORBATDb.lua", tblORBATDb)
		UTIL.dumpTable("tblTerrainDb.lua", tblTerrainDb)
	end
	--]]--
end

function makefirstmission(missionPath)
	if missionPath then -- only server mode
		local future_file_path = missionPath
		if future_file_path then -- a mission file was found
			writeDebugDetail(DSMC_ModuleName .. ": makefirstmission future_file_path = " .. tostring(future_file_path))
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
					writeDebugDetail(DSMC_ModuleName .. ": makefirstmission serSettingString table exist")
					local sResFun, sErrStr 	= loadstring(serSettingString);
					
					if sResFun then
						writeDebugDetail(DSMC_ModuleName .. ": makefirstmission sResFun table exist")
						setfenv(sResFun, serEnv)
						sResFun()								
						--UTIL.dumpTable("serEnv.cfg.lua", serEnv.cfg)
						if serEnv.cfg then
							writeDebugDetail(DSMC_ModuleName .. ": makefirstmission serEnv is readable")
							local mizList = serEnv.cfg["missionList"]
							if #mizList < 2 then
								writeDebugDetail(DSMC_ModuleName .. ": makefirstmission mizList is one mission only, replacing")
								serEnv.cfg["missionList"][1] = future_file_path
								serEnv.cfg["current"] = 1
								writeDebugDetail(DSMC_ModuleName .. ": makefirstmission serSetting modified")
							else
								writeDebugBase(DSMC_ModuleName .. ": WARNING: mission list is made by more than 1 mission: DSMC will remove all the other entries")
								for mId, mData in pairs(serEnv.cfg["missionList"]) do
									if mId > 1 then
										serEnv.cfg["missionList"][mId] = nil
									end
								end
								serEnv.cfg["missionList"][1] = future_file_path
								serEnv.cfg["current"] = 1
								writeDebugDetail(DSMC_ModuleName .. ": makefirstmission serSetting modified")
							end
						end
					end
				end
				local outFile = io.open(serSettingPath, "w");
				local newSrvConfigStr = UTIL.IntegratedserializeWithCycles('cfg', serEnv.cfg);
				outFile:write(newSrvConfigStr);
				io.close(outFile);
			else
				writeDebugDetail(DSMC_ModuleName .. ": makefirstmission can't find serversettings")
			end			
		end
		local stringOK = "trigger.action.outText('setup done!', 5)"
		if DSMC_isRecovering == false then
			UTIL.inJectCode("makefirstmission", stringOK)
		end
		DSMC_isRecovering = false
	else	
		writeDebugBase(DSMC_ModuleName .. ": makefirstmission stopped, no multy or no server")
	end

end

-- callback to create the new miz file
function batchSaveProcess()	
	writeDebugDetail(DSMC_ModuleName .. ": batchSaveProcess started")
	if SAVE and UTIL then
		writeDebugDetail(DSMC_ModuleName .. ": batchSaveProcess SAVE and UTIL are there")
		SAVE.NewMizPath = nil
		
		-- load tables
		loadtables()
		
		-- save updated mission file
		if tblAirbases and tblDeadUnits and tblDeadScenObj and tblUnitsUpdate and tblLogistic and tblSpawned and tblConquer then
			writeDebugBase(DSMC_ModuleName .. ": batchSaveProcess loading SAVE.buildNewMizFile..")
			local saveComplete = SAVE.buildNewMizFile(loadedMissionPath, loadedMizFileName)
			writeDebugBase(DSMC_ModuleName .. ": batchSaveProcess SAVE.buildNewMizFile done, valid save: " .. tostring(saveComplete))
		else
			writeDebugBase(DSMC_ModuleName .. ": batchSaveProcess SAVE.buildNewMizFile failed, missing one or more table files")
			return
		end

		-- update serverSettings.lua
		if ATRL_var then
			if SAVE.NewMizPath then
				makefirstmission(SAVE.NewMizPath)
			else
				writeDebugDetail(DSMC_ModuleName .. ": onPlayerDisconnect SAVE.NewMizPath not found!")
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
	local isServer 	= DCS.isServer()
	if multy == true and isServer == true then
		writeDebugDetail(DSMC_ModuleName .. ": onPlayerDisconnect checking for autosave")
		local num_clients = false
		local player_tbl = net.get_player_list()
		if player_tbl then
			num_clients = tonumber(#player_tbl) - 1
			writeDebugDetail(DSMC_ModuleName .. ": there are " .. tostring(num_clients) .. " clients connected")
			if num_clients == 0 then
				if UPAP then
					HOOK.writeDebugDetail(DSMC_ModuleName .. ": saveOnDisconnect disabled weather export")
					UPAP.weatherExport = false
				end	
				UTIL.inJectCode("DSCMsave", "if EMBD then EMBD.executeSAVE('recall') end")
				writeDebugDetail(DSMC_ModuleName .. ": autosave scheduled!")
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
	local isServer 	= DCS.isServer()
	writeDebugDetail(DSMC_ModuleName .. ": onTriggerMessage: isServer = " .. tostring(isServer))
	if isServer == true then
		local lmz = DCS.getMissionName()
		if lmz then
			if string.sub(lmz,1,4) == StartFilterCode then
				if string.sub(message, 1, 3) == "tbl" then	-- this will import & save any table that starts with "tbl"					
					local tableName = string.sub(message, 1, string.find(message, "=")-2)
					writeDebugDetail(DSMC_ModuleName .. ": tableName = " .. tostring(tableName))
					local str, str_err = loadstring(tostring(message))
					if not str_err then -- check errors  -- == true 
						str()
						
						if tableName == "tblAirbases" then
							UTIL.saveTable(tableName, tblAirbases, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))
						elseif tableName == "tblDeadUnits" then
							UTIL.saveTable(tableName, tblDeadUnits, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))						
						elseif tableName == "tblDeadScenObj" then
							UTIL.saveTable(tableName, tblDeadScenObj, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))						
						elseif tableName == "tblUnitsUpdate" then
							UTIL.saveTable(tableName, tblUnitsUpdate, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))	
						elseif tableName == "tblLogistic" then
							UTIL.saveTable(tableName, tblLogistic, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))					
						elseif tableName == "tblSpawned" then
							UTIL.saveTable(tableName, tblSpawned, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))						
						elseif tableName == "tblConquer" then
							UTIL.saveTable(tableName, tblConquer, DSMCfiles)
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))		
						elseif tableName == "tblLogCollect" then
							--UTIL.dumpTable("tblLogCollect.lua", tblLogCollect)	
							writeDebugDetail(DSMC_ModuleName .. ": recognized & saved " .. tostring(tableName))									
						end			
						writeDebugDetail(DSMC_ModuleName .. ": table loaded")			
					else
						writeDebugBase(DSMC_ModuleName .. ": error loading table")
						writeDebugBase(DSMC_ModuleName .. ": table:\n" .. tostring(message) .. "\nError: " .. tostring(str))	
					end

				elseif message == "DSMC save..." then			
					--command save actions
					batchSaveProcess()

				elseif message == "DSMC close..." then			
					writeDebugBase(DSMC_ModuleName .. ": DCS is closing due to trigger message DSMC close")
					DCS.exitProcess()

				elseif message == "DSMC is trying to restart the server! land or disconnect as soon as you can: DSMC will try again in 10 minutes" then			
					--command server closeup

					if STOP_var_safe == true then

						local num_clients = false
						local player_tbl = net.get_player_list()
						if player_tbl then
							num_clients = tonumber(#player_tbl) - 1
							writeDebugDetail(DSMC_ModuleName .. ": there are " .. tostring(num_clients) .. " clients connected")
							if num_clients == 0 then
								writeDebugBase(DSMC_ModuleName .. ": Closing DCS!")

								DCS.stopMission()
								DCSshouldCloseNow = true
							else
								writeDebugBase(DSMC_ModuleName .. ": there are " .. tostring(num_clients) .. " clients connected, can't close DCS: delayed 10 mins")	
							end			
						end	
					else
						writeDebugBase(DSMC_ModuleName .. ": Closing DCS without checking clients!")

						DCS.stopMission()
						DCSshouldCloseNow = true

					end
				end
			end
		end
	end
end

function DSMC.onPlayerStart()
	if alreadyStarted == true then
		local lmz = DCS.getMissionName()
		local isServer 	= DCS.isServer()
		if lmz and isServer == true then
			if string.sub(lmz,1,4) == StartFilterCode then
				writeDebugDetail(DSMC_ModuleName .. ": client starting, DSMC_resetSceneryDestruction is resetting")
				UTIL.inJectCode("DSMC_resetSceneryDestruction", "EMBD.sceneryDestroyRefreshRemote()")
			end
		end
	else
		writeDebugDetail(DSMC_ModuleName .. ": client connecting before simulation start, DSMC_resetSceneryDestruction is skipped")
	end
end

function DSMC.onPlayerDisconnect()
	saveOnDisconnect()
end

--[[
function DSMC.onRadioMessage(message, duration)
	local lmz = DCS.getMissionName()
	if lmz then
		if string.sub(lmz,1,4) == StartFilterCode then
			writeDebugDetail(DSMC_ModuleName .. ": test onRadioMessage = " .. tostring(message))
		end
	end
end

function DSMC.onShowGameMenu()
	local lmz = DCS.getMissionName()
	if lmz then
		if string.sub(lmz,1,4) == StartFilterCode then	
			writeDebugDetail(DSMC_ModuleName .. ": test onShowGameMenu")
		end
	end
end
--]]--

function DSMC.onSimulationStop()
	alreadyStarted = false
	local lmz = DCS.getMissionName()
	if lmz then
		if string.sub(lmz,1,4) == StartFilterCode then

			writeDebugBase(DSMC_ModuleName .. ": starting DSMC.onSimulationStop() call..")
			if ATRL_var then
				batchSaveProcess()
				writeDebugBase(DSMC_ModuleName .. ": DSMC.onSimulationStop() autosave file built process done - check if ok!")
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
				writeDebugBase(DSMC_ModuleName .. ": DSMC.onSimulationStop() is calling the exitProcess, DCS is closing")
				DCS.exitProcess()
			end
		end
	end

end
	
writeDebugDetail(DSMC_ModuleName .. ": callbacks loaded")
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


local language, langCountry = lang.getLocale()
writeDebugDetail(DSMC_ModuleName .. ": language = " .. tostring(language) .. ", langCountry = " .. tostring(langCountry))

writeDebugBase(DSMC_ModuleName .. ": Loaded " .. DSMC_MainVersion .. "." .. DSMC_SubVersion .. "." .. DSMC_SubSubVersion .. "." .. DSMC_Build .. ", released " .. DSMC_Date)

--~=
