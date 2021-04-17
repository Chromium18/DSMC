-- Dynamic Sequential Mission Campaign -- MAP OBJECT PERSISTENCE module

local ModuleName  	= "MOBJ"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('MOBJ', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
MOBJloaded						= false
local BugFixed					= true -- TILL ED DOESN'T SOLVE THE SCENERY DESTRUCTION BUG, MP SIDE
local BaseExplosionPower		= 1000

-- ## MANUAL TABLES


-- ## ELAB FUNCTION
function updateMapObject(missionEnv, tblDeadScenObj)	
	if table.getn(tblDeadScenObj) > 0 then

		local currentZoneNum 	= table.getn(missionEnv.triggers.zones) + 1
		local currentZoneId		= 1000
		local actionsId			= 1000		

		local currentTrigNum = nil
		local actionStr = ""
		-- check Sdes trigger existence?
		for tgId, tgData in pairs (missionEnv.trigrules) do
			if tgData.comment == "DSMC_Scenery_Persistence" then
				currentTrigNum = tgId
				HOOK.writeDebugDetail(ModuleName .. ": scenery base trigger already existant. id: " .. tostring(currentTrigNum))
				actionsId = table.getn(missionEnv.trigrules[currentTrigNum].actions) + 1
				actionsStr = missionEnv.trig.actions[currentTrigNum]
			end
		end
		
		if not currentTrigNum then 
			currentTrigNum	= table.getn(missionEnv.trig.flag) + 1 
			missionEnv.trigrules[currentTrigNum] = {
				["rules"] = {},
				["eventlist"] = "",
				["comment"] = "DSMC_Scenery_Persistence",
				["actions"] = {},			
				["predicate"] = "triggerStart",
			}
		end
		
		-- trigrules + actions + conditions
		missionEnv.trig.flag[currentTrigNum] = true
		missionEnv.trig.conditions[currentTrigNum] = "return(true)"
		missionEnv.trig.actions[currentTrigNum] = actionStr  -- NEEDS TO BE CHANGED?!?!  was ""
		
		missionEnv.trig.funcStartup[currentTrigNum] = "if mission.trig.conditions[" .. currentTrigNum .. "]() then mission.trig.actions[" .. currentTrigNum .. "]() end"

		HOOK.writeDebugDetail(ModuleName .. ": c1")

		-- add zones & trigger
		for ds_id, ds_data in pairs(tblDeadScenObj) do			
			if ds_data.objId then
				-- local currentZoneId = ds_data.objId
				local ExplosionPower = BaseExplosionPower 

				if ds_data.SOdesc.life < 5 then
					ExplosionPower = 10
				elseif ds_data.SOdesc.life < 50 then
					ExplosionPower = 50								
				elseif ds_data.SOdesc.life < 100 then
					ExplosionPower = 300
				elseif ds_data.SOdesc.life < 500 then
					ExplosionPower = 800
				else
					ExplosionPower = 5000 -- ds_data.SOdesc.life * 15
				end

				--check already there
				local okDoDestZone = true
				for zoneNum, zoneData in pairs(missionEnv.triggers.zones) do
					if zoneData.name == tostring("DSMC_ScenDest_" .. tostring(currentZoneId)) then
						HOOK.writeDebugDetail(ModuleName .. ": trigger is already there! : " .. tostring(currentZoneId))
						okDoDestZone = false
					end
				end

				-- create zone
				if okDoDestZone then
					if not missionEnv.triggers.zones[currentZoneNum] then
						missionEnv.triggers.zones[currentZoneNum] = {
							["x"] = ds_data.x,
							["y"] = ds_data.y,
							["radius"] = 5,
							["type"] = 0,
							["zoneId"] = currentZoneId,
							["color"] = 
							{
								[1] = 1,
								[2] = 1,
								[3] = 1,
								[4] = 0.15,
							},
							["hidden"] = true,
							["name"] = "DSMC_ScenDest_" .. ds_data.objId,
							["properties"] = 
							{
							},
						}
						
						--create trig.actions addon
						if BugFixed == true then
							--HOOK.writeDebugDetail(ModuleName .. ": c3a")
							missionEnv.trig.actions[currentTrigNum] = missionEnv.trig.actions[currentTrigNum] ..  "a_scenery_destruction_zone(" .. tostring(currentZoneId) .. ", 100);" -- currentZoneNum
						else
							--HOOK.writeDebugDetail(ModuleName .. ": c3b")
							missionEnv.trig.actions[currentTrigNum] = missionEnv.trig.actions[currentTrigNum] ..  "a_explosion(" .. tostring(currentZoneId) .. ", 1, " .. tostring(ExplosionPower) .. ");"
						end

						--populate trigger rules
						if BugFixed == true then
							--HOOK.writeDebugDetail(ModuleName .. ": c4a")
							local tblRules = missionEnv.trigrules[currentTrigNum].actions
							local currentNum = table.getn(tblRules)
							--HOOK.writeDebugDetail(ModuleName .. ": c5a")
							local nextNum = currentNum + 1
							--HOOK.writeDebugDetail(ModuleName .. ": c6a")
							missionEnv.trigrules[currentTrigNum].actions[nextNum] = {
								["meters"] = 1000,
								["predicate"] = "a_scenery_destruction_zone",
								["destruction_level"] = 100,
								["zone"] = currentZoneId,
							}	
						else

							local tblRules = missionEnv.trigrules[currentTrigNum].actions
							local currentNum = table.getn(tblRules)
							local nextNum = currentNum + 1

							missionEnv.trigrules[currentTrigNum].actions[nextNum] = {
								["altitude"] = 1,
								["zone"] = currentZoneId,
								["meters"] = 1000,
								["predicate"] = "a_explosion",
								["volume"] = ExplosionPower,
							}
						end	
						
						currentZoneNum 	= currentZoneNum +1
						currentZoneId	= currentZoneId +1
						actionsId 		= actionsId +1
						HOOK.writeDebugDetail(ModuleName .. ": created zone name " .. tostring("DSMC_ScenDest_" .. tostring(currentZoneId)))
					end
				else
					HOOK.writeDebugDetail(ModuleName .. ": zone skipped, already there!")
				end
			end
		end
		HOOK.writeDebugDetail(ModuleName .. ": c2")
		HOOK.writeDebugDetail(ModuleName .. ": added code for scenojb dead")
	else
		HOOK.writeDebugDetail(ModuleName .. ": no objects to be destroyed")
	end
end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
MOBJloaded = true