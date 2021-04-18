-- Dynamic Sequential Mission Campaign -- ADDING FILES module

local ModuleName  	= "ADTR"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('ADTR', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
ADTRloaded						= false

-- ## MANUAL TABLES
local bDir_1 = HOOK.DSMCdirectory .. "Files/beacon.ogg"
local bDir_2 = HOOK.DSMCdirectory .. "Files/beaconsilent.ogg"

tblAddResources = {
    [1] = {path = bDir_1, cat = "sound", file = "beacon.ogg"},
    [2] = {path = bDir_2, cat = "sound", file = "beaconsilent.ogg"},


}

--UTIL.dumpTable("tblAddResources.lua", tblAddResources)

-- ## ELAB FUNCTION
function updateMapResources(missionEnv, mapEnv, tblAddResources)	
	if table.getn(tblAddResources) > 0 then

		local maxId = missionEnv.maxDictId
		if maxId and SAVE.DSMC_NewSaveresourceFiles then

			-- ## RESOURCE ADDITION
			for _, ds_data in pairs(tblAddResources) do
				--check if already there
				local found = false
				for _, kData in pairs(mapEnv) do
					if ds_data.file == kData then

						found = true
					end
				end

				-- if not there, add
				if found == false then
					maxId = maxId + 1
					local resKeynew = "ResKey_Action_" .. tostring(maxId)
					mapEnv[resKeynew] = ds_data.file
					HOOK.writeDebugDetail(ModuleName .. ": added " .. tostring(resKeynew) .. ", file " .. tostring(ds_data.file) .. " to mapResource.lua")
				end
			end

			missionEnv.maxDictId = maxId

			-- ## MOVE FILES
			for _, ds_data in pairs(tblAddResources) do
				local newPath = HOOK.NewFilesDir .. tostring(ds_data.file)
				HOOK.writeDebugDetail(ModuleName .. ": newPath: " .. tostring(newPath))
				UTIL.copyFile(ds_data.path, newPath)
				SAVE.DSMC_NewSaveresourceFiles["l10n/DEFAULT/" .. ds_data.file] = newPath
				HOOK.writeDebugDetail(ModuleName .. ": copied file: " .. tostring(ds_data.file))

				local fileIsThere = UTIL.fileExist(newPath)
				HOOK.writeDebugDetail(ModuleName .. ": fileIsThere: " .. tostring(fileIsThere))
			end

			-- ## TRIGGER ADDITION

			local currentTrigNum = nil
			local actionStr = ""
			--local actionsId = 20000

			for tgId, tgData in pairs (missionEnv.trigrules) do
				if tgData.comment == "DSMC_adding_files" then
					currentTrigNum = tgId
					HOOK.writeDebugDetail(ModuleName .. ": additional resource trigger already existant. id: " .. tostring(currentTrigNum))
					--actionsId = table.getn(missionEnv.trigrules[currentTrigNum].actions) + 1
					actionsStr = missionEnv.trig.actions[currentTrigNum]
				end
			end
			
			if not currentTrigNum then 
				currentTrigNum	= table.getn(missionEnv.trig.flag) + 1 
				missionEnv.trigrules[currentTrigNum] = {
					["rules"] = {},
					["eventlist"] = "",
					["comment"] = "DSMC_adding_files",
					["actions"] = {},			
					["predicate"] = "triggerStart",
				}
			end
			
			-- trigrules + actions + conditions + funcStartup
			missionEnv.trig.flag[currentTrigNum] = true
			missionEnv.trig.conditions[currentTrigNum] = "return(c_random_less(0) )"
			missionEnv.trig.actions[currentTrigNum] = actionStr  -- void cause it will be changed after
			missionEnv.trig.funcStartup[currentTrigNum] = "if mission.trig.conditions[" .. currentTrigNum .. "]() then mission.trig.actions[" .. currentTrigNum .. "]() end"

			-- add files
			for ds_id, ds_data in pairs(tblAddResources) do
				local key = nil
				for mId, mData in pairs(mapEnv) do
					if mData == ds_data.file then
						key = mId
					end
				end
				
				if key then

					if ds_data.cat == "sound" then
						missionEnv.trig.actions[currentTrigNum] = missionEnv.trig.actions[currentTrigNum] ..  '"a_out_sound_c(21, getValueResourceByKey(\"' .. tostring(key) .. '\"), 0);'
						HOOK.writeDebugDetail(ModuleName .. ": added sound, complete string: " .. tostring(missionEnv.trig.actions[currentTrigNum]))
					elseif ds_data.cat == "lua" then
						missionEnv.trig.actions[currentTrigNum] = missionEnv.trig.actions[currentTrigNum] ..  '"a_do_script_file(getValueResourceByKey(\"' .. tostring(key) .. '\"));'
						HOOK.writeDebugDetail(ModuleName .. ": added file, complete string: " .. tostring(missionEnv.trig.actions[currentTrigNum]))
					-- OTHER THINGS!?
					
					end
				else
					HOOK.writeDebugDetail(ModuleName .. ": key for ds_id: " .. tostring(ds_id) .. " not found")

				end
				
			end

			local tblTrigRules = {}
			-- add rules
			tblTrigRules["rules"] = {
				[1] = 
				{
					["percent"] = 0,
					["predicate"] = "c_random_less",
					["zone"] = "",
				}, -- end of [1]
			} -- end of ["rules"]
			-- add
			tblTrigRules["comment"] = "DSMC_adding_files"
			tblTrigRules["eventlist"] = ""
			tblTrigRules["predicate"] = "triggerStart"
			local actList = {}
			for ds_id, ds_data in pairs(tblAddResources) do
				local key = nil
				for mId, mData in pairs(mapEnv) do
					if mData == ds_data.file then
						key = mId
					end
				end
				
				if key then
					if ds_data.cat == "sound" then
						actList[#actList+1] = {
							["countrylist"] = 21,
							["start_delay"] = 0,
							["zone"] = "",
							["meters"] = 1000,
							["predicate"] = "a_out_sound_c",
							["file"] = key,
						} 
						HOOK.writeDebugDetail(ModuleName .. ": added trigRules action: sound - " .. tostring(key))
					elseif ds_data.cat == "lua" then
						actList[#actList+1] = {
							["meters"] = 1000,
							["file"] = key,
							["predicate"] = "a_do_script_file",
							["zone"] = "",
						}
						HOOK.writeDebugDetail(ModuleName .. ": added trigRules action: file - " .. tostring(key))
					end
				end
			end
			tblTrigRules["actions"] = actList
			
			missionEnv.trigrules[currentTrigNum] = tblTrigRules -- reset all files loaded before. Every mission have to re-load its file!!!

			HOOK.writeDebugDetail(ModuleName .. ": added code for custom files")
		else
			HOOK.writeDebugDetail(ModuleName .. ": missing SAVE.DSMC_NewSaveresourceFiles: " ..tostring(SAVE.DSMC_NewSaveresourceFiles) ..", or maxId: " .. tostring(maxId))
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": no files to be added")
	end
end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
ADTRloaded = true