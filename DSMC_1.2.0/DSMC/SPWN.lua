-- Dynamic Sequential Mission Campaign -- TRACK SPAWNED module

local ModuleName  	= "SPWN"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('SPWN', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
SPWNloaded						= false
KeepGroupName					= true -- if true a spawned group will retain it's name in the saved files... but it means that CTLD can overwrite it! if overwritten (by spawning another group) the original one will instantly disappear from the mission

-- ## MANUAL TABLES
local tblShapes = {
	["Invisible FARP"] = "invisiblefarp",
	["FARP"] = "FARPS",
	["SINGLE_HELIPAD"] = "FARP",
}

-- ## ELAB FUNCTION
function doSpawned(missionEnv, tblSpawned, dictEnv, whEnv)
	HOOK.writeDebugDetail(ModuleName .. ": starting doSpawned")
	
	--if HOOK.debugProcessDetail then
		--UTIL.dumpTable("tblSpawned.lua", tblSpawned)
		--UTIL.dumpTable("dictEnv.lua", dictEnv)
	--end	

	if missionEnv.maxDictId then
		HOOK.writeDebugDetail(ModuleName .. ": found maxDictId")
		if tblSpawned then
			HOOK.writeDebugDetail(ModuleName .. ": found tblSpawned")
			--DICTPROBLEM -- added newMaxId
			local MaxDict = missionEnv.maxDictId
			local newMaxId = 1
			HOOK.writeDebugDetail(ModuleName .. ": MaxDict = " .. tostring(MaxDict))
			HOOK.writeDebugDetail(ModuleName .. ": newMaxId = " .. tostring(newMaxId))

			for _id, sgData in pairs(tblSpawned) do
				local oneAlive = false
				if sgData.gUnits then
					for u, uD in pairs(sgData.gUnits) do
						if uD.uAlive == true then
							oneAlive = true
						end
					end
				end
				
				if oneAlive == true then
				
					local correctCoalition = nil
					local correctCountry = nil				
					
					if tonumber(sgData.gCoalition) == 0 then
						correctCoalition = "neutral"
					elseif tonumber(sgData.gCoalition) == 1 then
						correctCoalition = "red"				
					elseif tonumber(sgData.gCoalition) == 2 then
						correctCoalition = "blue"				
					end					
					HOOK.writeDebugDetail(ModuleName .. ": Coalition set")
					
					for ctryID, ctryData in pairs (missionEnv.coalition[correctCoalition]["country"]) do
						if tonumber(sgData.gCountry) == tonumber(ctryData.id) then
							correctCountry = ctryID
						end
					end
					HOOK.writeDebugDetail(ModuleName .. ": Country set")
					
					local groupTable = {}
					-- SET mother groupTable
					if sgData.gType == "static" then				
						if not missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"] then
							missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"] = {}				
						end											
						if not missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"]["group"] then
							missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"]["group"] = {}						
						end
						groupTable = missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"]["group"]
						
					elseif sgData.gType == "vehicle" then					
						if not missionEnv.coalition[correctCoalition]["country"][correctCountry]["vehicle"] then
							missionEnv.coalition[correctCoalition]["country"][correctCountry]["vehicle"] = {}				
						end

						if not missionEnv.coalition[correctCoalition]["country"][correctCountry]["vehicle"]["group"] then
							missionEnv.coalition[correctCoalition]["country"][correctCountry]["vehicle"]["group"] = {}						
						end	
						groupTable = missionEnv.coalition[correctCoalition]["country"][correctCountry]["vehicle"]["group"]
						
					end
					HOOK.writeDebugDetail(ModuleName .. ": groupTable set")
					
					local tblDictEntries = dictEnv
					HOOK.writeDebugDetail(ModuleName .. ": tblDictEntries set")
					
					if groupTable and correctCoalition and correctCountry then
						local GrpNameAssigned = ""
						local sgUnits = {}
						local minU = 1000000000000000
						local isFARP = false

						for uId, uData in pairs(sgData.gUnits) do
							if uData.uAlive == true then
								--DICTPROBLEM
								--MaxDict = MaxDict+1									
								--local UnitDictEntry = "DictKey_UnitName_" .. MaxDict
								--local name = nil
								newMaxId = newMaxId + 1
								if uData.uName then
									name = uData.uName
								else
									--DICTPROBLEM
									--name = tostring(uData.uType) .. "_" .. tostring(MaxDict)
									name = tostring(uData.uType) .. "_" .. tostring(newMaxId)
								end
								
								--tblDictEntries[UnitDictEntry] = name -- tostring(uData.uType) .. "_" .. tostring(MaxDict)
								
								local shape = nil
								if not uData.shape_name then
									local found = false
									for t, s in pairs(tblShapes) do
										if t == uData.uType then
											shape = s
											found = true
										end
									end

									if found == false then
										shape = uData["uDesc"]["typeName"]
									end

								else
									shape = uData.shape_name
								end


								if tonumber(sgData.gCat) == 3 then -- maybe add category 4 for FARPs and similar?
									sgUnits[#sgUnits + 1] =
													{
														["type"] = uData.uType,
														--["category"] = uData.uStaticCategory,
														["shape_name"] = shape,
														["unitId"] = uData.uID,
														["y"] = uData.uPos.z,
														["x"] = uData.uPos.x,
														--DICTPROBLEM
														["name"] = name, --UnitDictEntry,
														["heading"] = 0, -- do it better next time
														["category"] = "Fortifications",
													}
								elseif tonumber(sgData.gCat) == 4 then -- FARP
									sgUnits[#sgUnits + 1] =
													{
														["type"] = uData.uType,
														--["category"] = uData.uStaticCategory,
														["shape_name"] = shape,
														["unitId"] = uData.uID,
														["y"] = uData.uPos.z,
														["x"] = uData.uPos.x,
														--DICTPROBLEM
														["name"] = name, -- UnitDictEntry,
														["heading"] = 0, -- do it better next time
														["category"] = "Heliports",
														["heliport_modulation"] = 0,
														["heliport_frequency"] = 127.5,
														["heliport_callsign_id"] = 1,
													}
									local v = nil
									if WRHS then
										v = true
									end					
									UTIL.addFARPwhBase(uData.uID, correctCoalition, whEnv, v)
									isFARP = true

								elseif tonumber(sgData.gCat) == 6 then -- cargo
									sgUnits[#sgUnits + 1] =
													{
														["type"] = uData.uType,
														--["category"] = uData.uStaticCategory,
														["shape_name"] = shape,
														["unitId"] = uData.uID,
														["y"] = uData.uPos.z,
														["x"] = uData.uPos.x,
														--DICTPROBLEM
														["name"] = name, -- UnitDictEntry,
														["heading"] = 0, -- do it better next time
														["mass"] = uData.uWeight,
														["canCargo"] = true,
													}
								elseif tonumber(sgData.gCat) == 1 then
									sgUnits[#sgUnits + 1] =
													{
														["type"] = uData.uType,
														["transportable"] = 
														{
															["randomTransportable"] = false,
														}, -- end of ["transportable"]
														["unitId"] = uData.uID,
														["skill"] = "Random",
														["y"] = uData.uPos.z,
														["x"] = uData.uPos.x,
														--DICTPROBLEM
														["name"] = name, -- UnitDictEntry,
														["playerCanDrive"] = true,
														["heading"] = 0, -- do it better next time
													}
								end
								HOOK.writeDebugDetail(ModuleName .. ": added unit " .. tostring(uData.uName))
								
								if uId < minU then
									minU = uId
									--DICTPROBLEM
									--GrpNameAssigned = tostring(uData.uType) .. "_".. tostring(MaxDict)
									GrpNameAssigned = tostring(uData.uType) .. "_".. tostring(MaxDict)
									HOOK.writeDebugDetail(ModuleName .. ": GrpNameAssigned " .. tostring(GrpNameAssigned))
								end
							end
						end
						HOOK.writeDebugDetail(ModuleName .. ": units table set")				
						
						if table.getn(sgUnits) > 0 then
							--DICTPROBLEM
							--MaxDict = MaxDict+1
							--local GrpDictEntry = "DictKey_GroupName_" .. MaxDict
							if KeepGroupName then
								GrpNameAssigned = sgData.gName
							end							
							--tblDictEntries[GrpDictEntry] = GrpNameAssigned -- this cause CTLD to overwrite the group if created again
							--MaxDict = MaxDict+1
							--local WptDictEntry = "DictKey_WptName_" .. MaxDict
							--tblDictEntries[WptDictEntry] = ""										
				
							local gPosX = sgUnits[1]["x"]
							local gPosY = sgUnits[1]["y"]
							
							local NewGroupTable = 
							{
								["visible"] = false,
								["tasks"] = 
								{
								}, -- end of ["tasks"]
								["uncontrollable"] = false,
								["task"] = "Ground Nothing",
								["taskSelected"] = true,
								["route"] = 							
								{
									["spans"] = 
									{
									}, -- end of ["spans"]
									["points"] = 
									{
										[1] = 
										{
											["alt"] = sgData.gAlt,
											["type"] = "Turning Point",
											["ETA"] = 0,
											["alt_type"] = "BARO",
											["formation_template"] = "",
											["y"] = gPosY,
											["x"] = gPosX,
											--DICTPROBLEM
											["name"] = "", --WptDictEntry,
											["ETA_locked"] = true,
											["speed"] = 0,
											["action"] = "Off Road",
											["task"] = 
											{
												["id"] = "ComboTask",
												["params"] = 
												{
													["tasks"] = 
													{
													}, -- end of ["tasks"]
												}, -- end of ["params"]
											}, -- end of ["task"]
											["speed_locked"] = true,
										}, -- end of [1]
									}, -- end of ["points"]
								}, -- end of ["route"]								
								["groupId"] = sgData.gID,
								["hidden"] = false,
								["units"] = sgUnits,
								["y"] = gPosY,
								["x"] = gPosX,
								--DICTPROBLEM
								["name"] = GrpNameAssigned, -- GrpDictEntry,
								["heading"] = 0, -- this also in new structure!
								["start_time"] = 0,
							}	

							if sgData.gType == "static" then
								NewGroupTable["route"]["spans"] = nil
								NewGroupTable["route"]["points"][1]["ETA"] = nil
								NewGroupTable["route"]["points"][1]["alt_type"] = nil
								NewGroupTable["route"]["points"][1]["name"] = nil
								NewGroupTable["route"]["points"][1]["ETA_locked"] = nil
								NewGroupTable["route"]["points"][1]["task"] = nil
								NewGroupTable["route"]["points"][1]["speed_locked"] = nil						
								
								if sgData.gStaticAlive == false then
									NewGroupTable["dead"] = true
									NewGroupTable["linkOffset"] = false
								else
									NewGroupTable["dead"] = false
									NewGroupTable["linkOffset"] = false																		
								end
							end

							if isFARP then
								NewGroupTable["linkOffset"] = nil
								NewGroupTable["hidden"] = nil
							end
							
							groupTable[#groupTable + 1] = NewGroupTable
							HOOK.writeDebugDetail(ModuleName .. ": group table inserted")
						end

					end				
				end
			end
			missionEnv.maxDictId = MaxDict
			HOOK.writeDebugDetail(ModuleName .. ": tblSpawned cycle complete, MaxDict: " ..tostring(MaxDict))
		else
			HOOK.writeDebugDetail(ModuleName .. ": tblSpawned missing")
		end 
	else
		HOOK.writeDebugDetail(ModuleName .. ": maxDictId missing")
	end
	
	return whEnv

end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
SPWNloaded = true
