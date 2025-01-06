-- Dynamic Sequential Mission Campaign -- SAVE module

local ModuleName  	= "SAVE"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
module('SAVE', package.seeall)
local require 		= _G.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')
local minizip 		= require('minizip')
local ME_DB   		= require('me_db_api')
local Terrain		= require('terrain')
HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

--## VARS
tblToBeKilled 			= {}
tblContryCoaChange 		= {}
HOOK.writeDebugDetail(ModuleName .. ": vars required loaded")
local wreckagePersistence_units = 2 -- days after destruction
local wreckagePersistence_mapObj = 30 -- days after destruction (not implemented yet)
local wreckagePersistence_statics = 30 -- days after destruction (not implemented yet)


--## LOGIC FIXING TEMP THINGS
local fixSkillsDSMC2 = true

--find nearest airdrome
function getNearestAirdrome(atbl, cx, cy)
    local result = nil
	local dMin = 100000000
    local sx, sy, ID, roadnet

    for airdromeID, airdrome in pairs(atbl) do
        if airdrome.abandoned ~= true then
            --local d = DB.getDist(x, y, airdrome.reference_point.x, airdrome.reference_point.y)
            local p1 	= {x = cx, y = 0, z = cy}
			local p2 	= {x = airdrome.reference_point.x, y = 0, z = airdrome.reference_point.y} 
			local d 	= UTIL.get2Ddistance(p1, p2)
            local air_item =
            {
                dist    = d,
                sx 		= airdrome.reference_point.x,
                sy 		= airdrome.reference_point.y,
                ID 		= airdromeID,
                roadnet = airdrome.roadnet,
            }
            
            if 	result == nil or
                d < dMin then
                result = air_item
                dMin = d
            end		
        end
    end
	return result
end

--## FUNCTIONS

function IncludeSpawned(missionEnv, tbl, whEnv) -- , dictEnv
	if SPWN and missionEnv and tbl and whEnv then -- and dictEnv
		local lthStr, lthStrErr = SPWN.doSpawned(missionEnv, tbl, whEnv) -- , dictEnv
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": SPWN.doSpawned, errors: " .. tostring(lthStr))
		end	
		
		HOOK.writeDebugDetail(ModuleName .. ": doSpawned ok")
	else
		HOOK.writeDebugDetail(ModuleName .. ": doSpawned, missing missionEnv or tbl or dictEnv")
	end
end
HOOK.writeDebugDetail(ModuleName .. ": SPWN loaded")

function createStatics(missionEnv, tbl)
	if CRST and missionEnv and tbl then
		local lthStr, lthStrErr = CRST.doStatics(missionEnv, tbl)		
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": CRST.doStatics, errors: " .. tostring(lthStr))
		end	
		
		HOOK.writeDebugDetail(ModuleName .. ": doStatics ok")
	else
		HOOK.writeDebugDetail(ModuleName .. ": doStatics, missing missionEnv or tbl")
	end

end
HOOK.writeDebugDetail(ModuleName .. ": CRST loaded")

function mapObjUpdate(missionEnv, tbl)
	if MOBJ and missionEnv and tbl then
		local lthStr, lthStrErr = MOBJ.updateMapObject(missionEnv, tbl)		
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": MOBJ.updateMapObject, errors: " .. tostring(lthStr))
		end	
		
		HOOK.writeDebugDetail(ModuleName .. ": mapObjUpdate ok")
	else
		HOOK.writeDebugDetail(ModuleName .. ": mapObjUpdate, missing missionEnv or tbl")
	end
end
HOOK.writeDebugDetail(ModuleName .. ": MOBJ loaded")

function killUnits(missionEnv)

	-- check related units
	for _, kData in pairs(tblToBeKilled) do	
		for coalitionID,coalition in pairs(missionEnv["coalition"]) do
			for countryID,country in pairs(coalition["country"]) do
				for attrID,attr in pairs(country) do
					if (type(attr)=="table") then
						for groupID,group in pairs(attr["group"]) do
							if (group) then
							
								local isKill = false
								for rID,rData in pairs (group.route.points) do
									if rData.linkUnit == kData.uId then
										isKill = true
										HOOK.writeDebugDetail(ModuleName .. ": killUnits found related groups of unit, base object: " .. tostring(kData.uId))
									end
								end
								
								if isKill == true then
									for unitID,unit in pairs(group["units"]) do	
										HOOK.writeDebugDetail(ModuleName .. ": killUnits found added to be killed, unit id: " .. tostring(unit.unitId))
										tblToBeKilled[#tblToBeKilled+1] = {uId = unit.unitId, gId = group.groupId}
									end
								end
								
							end
						end
					end
				end
			end	
		end
	end
	
	-- kill units
	--UTIL.dumpTable("tblToBeKilled.lua", tblToBeKilled)
	for _, kData in pairs(tblToBeKilled) do	
		for coalitionID,coalition in pairs(missionEnv["coalition"]) do
			for countryID,country in pairs(coalition["country"]) do
				for attrID,attr in pairs(country) do
					if (type(attr)=="table") then
						for groupID,group in pairs(attr["group"]) do
							if (group) then
								if group.groupId == kData.gId then
									for unitID,unit in pairs(group["units"]) do
										if unit.unitId == kData.uId then
											if (attrID == "static") then
												if unit.category == "Cargos" or unit.canCargo == true then 				-- cargo object removed from mission
													HOOK.writeDebugDetail(ModuleName .. ": killUnits killing cargo object")
													table.remove(attr.group, groupID)
													--table.remove(group.units, unitID);				
													if table.getn(attr.group) < 1 then 				
														country[attrID] = nil;
													end		
												else											-- any other static set "dead"
													HOOK.writeDebugDetail(ModuleName .. ": killUnits killing static object")
													group["dead"] = true;
													--isVehicle = false
												end
												HOOK.writeDebugDetail(ModuleName .. ": killUnits killed static")
											else										
												HOOK.writeDebugDetail(ModuleName .. ": killUnits unit " .. tostring(unitID) .. " is not alive, removing unit table")									

												-- fix group position
												if unitID == 1 then
													for uID, u in pairs(group["units"]) do
														if uID == 2 then
															group["x"] = u["x"];
															group["y"] = u["y"];
															HOOK.writeDebugDetail(ModuleName .. ": killUnits updated group position")

															group.route.points[1]["x"] = u["x"];
															group.route.points[1]["y"] = u["y"];

															HOOK.writeDebugDetail(ModuleName .. ": killUnits updated group route")
															group.route.spans = {
																					[1] = 
																					{
																						[1] = 
																						{
																							["y"] = u["y"],
																							["x"] = u["x"],
																						}, -- end of [1]
																						[2] = 
																						{
																							["y"] = u["y"]+0.0001,
																							["x"] = u["x"]+0.0001,
																						}, -- end of [2]
																					}, -- end of [1]													
																				} -- end of ["spans"]
															HOOK.writeDebugDetail(ModuleName .. ": killUnits updated group spans")
														end
													end
												end

												table.remove(group.units, unitID);
												--group.units[unitID] = nil

												HOOK.writeDebugDetail(ModuleName .. ": killUnits killed unit. table.getn(group.units): " .. tostring(table.getn(group.units)))
												if table.getn(group.units) < 1 then -- next(group.units) == nil
													table.remove(attr.group, groupID)
													--attr.group[groupID] = nil;
													HOOK.writeDebugDetail(ModuleName .. ": killUnits killed group (no more units)")		
													
													HOOK.writeDebugDetail(ModuleName .. ": killUnits table.getn(attr.group): " .. tostring(table.getn(attr.group)))
													if table.getn(attr.group) < 1 then -- next(attr.group) == nil													
														country[attrID] = nil;
														HOOK.writeDebugDetail(ModuleName .. ": killUnits killed country (no more groups)")												
													end
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end	
	end

	HOOK.writeDebugDetail(ModuleName .. ": killUnits ok")
end	
HOOK.writeDebugDetail(ModuleName .. ": killUnits loaded")

function killStatics(missionEnv) -- remove static units wreckages created by DSCM CRST module

	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			HOOK.writeDebugDetail(ModuleName .. ": killStatics, country: " .. tostring(country.name))
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") and (attrID == "static") then
					
					for i = #attr.group, 1, -1 do
						--HOOK.writeDebugDetail(ModuleName .. ": killStatics, i: " .. tostring(i))
						

						if string.find(attr.group[i].name, "_dsmc_dd_") then
							
							local code = nil
							local code2 = string.sub(attr.group[i].name, string.find(attr.group[i].name, "_dsmc_dd_")+9)
							HOOK.writeDebugDetail(ModuleName .. ": killStatics, code2: " .. tostring(code2))

							if string.find(code2, "%-") then
								--HOOK.writeDebugDetail(ModuleName .. ": killStatics, code check a")
								code = string.sub(code2, 1, string.find(code2, "%-")-1)
							else
								--HOOK.writeDebugDetail(ModuleName .. ": killStatics, code check b")
								code = code2
							end

							HOOK.writeDebugDetail(ModuleName .. ": killStatics, code: " .. tostring(code))

							local subDateFilter = tonumber(code)+wreckagePersistence_units

							local y = missionEnv.date.Year
							local m = missionEnv.date.Month
							local d = missionEnv.date.Day
	
							local dayValue = nil
	
							if y and m and d then
								if type(y) == "number" and type(m) == "number" and type(d) == "number" then 
									dayValue = y*365+m*30+d -- (can't use os.time and os.date cause I can't be sure to have os available!)
								end
							end

							--HOOK.writeDebugDetail(ModuleName .. ": killStatics, subDateFilter: " .. tostring(subDateFilter) .. ", dayValue:" .. tostring(dayValue))

							if dayValue > subDateFilter then
								HOOK.writeDebugDetail(ModuleName .. ": killStatics filter is passed, attr.group[i] removed")
								table.remove(attr.group, i)
							end
						end
					end

					HOOK.writeDebugDetail(ModuleName .. ": killStatics table.getn(attr.group): " .. tostring(table.getn(attr.group)))
					if table.getn(attr.group) < 1 then -- next(attr.group) == nil													
						country[attrID] = nil;
						HOOK.writeDebugDetail(ModuleName .. ": killStatics killed static table for country (no more groups)")												
					end

				end
			end
		end
	end	

	HOOK.writeDebugDetail(ModuleName .. ": killStatics ok")
end	
HOOK.writeDebugDetail(ModuleName .. ": killStatics loaded")

function updateUnits(missionEnv)
	local unitsUpdatePreview = table.getn(tblUnitsUpdate)
	local unitsUpdateNumber = 0 

	tblToBeKilled = {}

	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					if attrID == "plane" or attrID == "helicopter" then
						HOOK.writeDebugDetail(ModuleName .. ": plane or helo found, skip")
					elseif attrID == "ship" then
						for groupID,group in pairs(attr["group"]) do
							if (group) then
								
								HOOK.writeDebugDetail(ModuleName .. ": updateUnits, checking group " .. tostring(group.name))
								local excluded = false
								if string.find(group.name, HOOK.EMBD_var) then
									HOOK.writeDebugDetail(ModuleName .. ": updateUnits, group " .. tostring(group.name) .. " is excluded")
									excluded = true
								end

								if excluded == false then
									local isCarrierGroup = false
									HOOK.writeDebugDetail(ModuleName .. ": updateUnits checking carrier group")
									for unitID,unit in pairs(group["units"]) do		
										for id, updatedData in pairs (tblUnitsUpdate) do
											if tonumber(updatedData.unitId) == tonumber(unit.unitId) then
												if updatedData.carrier == true then
													isCarrierGroup = true
													--HOOK.writeDebugDetail(ModuleName .. ": updateUnits, unit " .. tonumber(unit.unitId) .. " is a carrier")
												end
											end
										end
									end
									
									if isCarrierGroup == false then
										for unitID,unit in pairs(group["units"]) do
											--HOOK.writeDebugDetail(ModuleName .. ": updateUnits looking for unit number " .. tostring(unitID) .. ", unitId: " .. tostring(unit.unitId))
											local isAlive = true
											for id, deadData in pairs (tblDeadUnits) do -- check if this unit is dead
												if tonumber(deadData.unitId) == tonumber(unit.unitId) then
													isAlive = false
												end
											end
											--HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive))
											if isAlive == false then
												tblToBeKilled[#tblToBeKilled+1] = {uId = unit.unitId, gId = group.groupId}
												--HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive) .. ", unit added to tblToBeKilled")
											else
												--update the unit
												if group and unit then
													--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updating unit")
													for id, updatedData in pairs (tblUnitsUpdate) do
														if tonumber(updatedData.unitId) == tonumber(unit.unitId) then
															
															local posChanged = false
															if math.floor(unit["x"]) ~= math.floor(updatedData.x) and math.floor(unit["y"]) ~= math.floor(updatedData.z) then
																--HOOK.writeDebugDetail(ModuleName .. ": updateUnits position is changed: x = " .. tostring(unit["x"]) .. ", new x = " .. tostring(updatedData.x))
																--HOOK.writeDebugDetail(ModuleName .. ": updateUnits position is changed: y = " .. tostring(unit["y"]) .. ", new y = " .. tostring(updatedData.z))
																posChanged = true
															end
															if posChanged == true then
																if group["lateActivation"] == true then
																	HOOK.writeDebugDetail(ModuleName .. ": updateUnits unit was late activation, removing the option")
																	group["lateActivation"] = nil
																end
															
																unit["x"] = updatedData.x;
																unit["y"] = updatedData.z;

																if unitID == 1 then  -- try to fix ME stuff
																	group["x"] = unit["x"];
																	group["y"] = unit["y"];
																	HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 position")

																	group.route.points[1]["x"] = unit["x"];
																	group.route.points[1]["y"] = unit["y"];

																	HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 route")
																	group.route.spans = {
																							[1] = 
																							{
																								[1] = 
																								{
																									["y"] = unit["y"],
																									["x"] = unit["x"],
																								}, -- end of [1]
																								[2] = 
																								{
																									["y"] = unit["y"]+0.0001,
																									["x"] = unit["x"]+0.0001,
																								}, -- end of [2]
																							}, -- end of [1]													
																						} -- end of ["spans"]
																	HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 spans")												
																end
																
																for id, pointData in pairs (group.route.points) do
																	if id > 1 then
																		--table.remove(group.route.points, id);
																		group.route.points[id] = nil
																	end
																end

																if unit.skill == "Random" and fixSkillsDSMC2 == true then
																	local rnd = math.random(1,10)
																	if unitID == 1 or unitID == 2 then
																		if rnd >= 8 then
																			unit.skill = "Excellent"
																		elseif rnd >= 5 then
																			unit.skill = "High"
																		elseif rnd >= 3 then
																			unit.skill = "Good"
																		else
																			unit.skill = "Average"
																		end
																	else
																		if rnd >= 9 then
																			unit.skill = "Excellent"
																		elseif rnd >= 7 then
																			unit.skill = "High"
																		elseif rnd >= 4 then
																			unit.skill = "Good"
																		else
																			unit.skill = "Average"
																		end
																	end
																end															
																--if group.route.spans then
																--	group.route.spans = nil 
																--end
																HOOK.writeDebugDetail(ModuleName .. ": updateUnits unit updated")
																unitsUpdateNumber = unitsUpdateNumber + 1
															end
														end
													end												
												end
											end
										end
									else
										for unitID,unit in pairs(group["units"]) do
											--HOOK.writeDebugDetail(ModuleName .. ": updateUnits looking for carrier group unit number " .. tostring(unitID) .. ", unitId: " .. tostring(unit.unitId))
											local isAlive = true
											for id, deadData in pairs (tblDeadUnits) do -- check if this unit is dead
												if tonumber(deadData.unitId) == tonumber(unit.unitId) then
													isAlive = false
												end
											end
											--HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive))
											if isAlive == false then
												tblToBeKilled[#tblToBeKilled+1] = {uId = unit.unitId, gId = group.groupId}
												HOOK.writeDebugDetail(ModuleName .. ": updateUnits  carrier group unit isAlive: " .. tostring(isAlive) .. ", unit added to tblToBeKilled")
											end
										end
									end
								end
							end
						end					
					else
						for groupID,group in pairs(attr["group"]) do
							if (group) then				
																
								HOOK.writeDebugDetail(ModuleName .. ": updateUnits, checking group " .. tostring(group.name))
								local excluded = false
								if string.find(group.name, HOOK.EMBD_var) then
									HOOK.writeDebugDetail(ModuleName .. ": updateUnits, group " .. tostring(group.name) .. " is excluded")
									excluded = true
								end

								if excluded == false then		
									for unitID,unit in pairs(group["units"]) do
										--HOOK.writeDebugDetail(ModuleName .. ": updateUnits looking for unit number " .. tostring(unitID) .. ", unitId: " .. tostring(unit.unitId))
										local isAlive = true
										for id, deadData in pairs (tblDeadUnits) do -- check if this unit is dead
											if tonumber(deadData.unitId) == tonumber(unit.unitId) then
												isAlive = false
											end
										end
										--HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive))
										if isAlive == false then
											tblToBeKilled[#tblToBeKilled+1] = {uId = unit.unitId, gId = group.groupId}
											--HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive) .. ", unit added to tblToBeKilled")
										else
											--update the unit
											if group and unit then
												--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updating unit")
												for id, updatedData in pairs (tblUnitsUpdate) do
													if tonumber(updatedData.unitId) == tonumber(unit.unitId) then	
														--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updating unit: found update data ")							
														if updatedData.aircraft == false then
														
															local posChanged = false
															if math.floor(unit["x"]) ~= math.floor(updatedData.x) and math.floor(unit["y"]) ~= math.floor(updatedData.z) then
																HOOK.writeDebugDetail(ModuleName .. ": updateUnits position is changed: x = " .. tostring(unit["x"]) .. ", new x = " .. tostring(updatedData.x))
																HOOK.writeDebugDetail(ModuleName .. ": updateUnits position is changed: y = " .. tostring(unit["y"]) .. ", new y = " .. tostring(updatedData.z))
																posChanged = true
															end
															
															if unit.skill == "Random" and fixSkillsDSMC2 == true then
																local rnd = math.random(1,10)
																if unitID == 1 or unitID == 2 then
																	if rnd >= 8 then
																		unit.skill = "Excellent"
																	elseif rnd >= 5 then
																		unit.skill = "High"
																	elseif rnd >= 3 then
																		unit.skill = "Good"
																	else
																		unit.skill = "Average"
																	end
																else
																	if rnd >= 9 then
																		unit.skill = "Excellent"
																	elseif rnd >= 7 then
																		unit.skill = "High"
																	elseif rnd >= 4 then
																		unit.skill = "Good"
																	else
																		unit.skill = "Average"
																	end
																end
															end	

															if posChanged == true then
																if group["lateActivation"] == true then
																	HOOK.writeDebugDetail(ModuleName .. ": updateUnits unit was late activation, removing the option")
																	group["lateActivation"] = nil
																end

															
																unit["x"] = updatedData.x;
																unit["y"] = updatedData.z;

																if unitID == 1 then  -- try to fix ME stuff -- QUESTO VA AGGIORNATO!!!!

																	group["x"] = unit["x"];
																	group["y"] = unit["y"];
																	--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 position")

																	group.route.points[1]["x"] = unit["x"];
																	group.route.points[1]["y"] = unit["y"];

																	--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 route")
																	group.route.spans = {
																							[1] = 
																							{
																								[1] = 
																								{
																									["y"] = unit["y"],
																									["x"] = unit["x"],
																								}, -- end of [1]
																								[2] = 
																								{
																									["y"] = unit["y"]+0.0001,
																									["x"] = unit["x"]+0.0001,
																								}, -- end of [2]
																							}, -- end of [1]													
																						} -- end of ["spans"]
																	--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 spans")													
																end
																
																for id, pointData in pairs (group.route.points) do
																	if id > 1 then
																		table.remove(group.route.points, id);
																	end
																end
																
																--if group.route.spans then 
																--	group.route.spans = nil 
																--end
																HOOK.writeDebugDetail(ModuleName .. ": updateUnits unit updated")
																unitsUpdateNumber = unitsUpdateNumber + 1
															end
														end
													end
												end												
											end
										end
									end
								end
							end
						end				
					end
				end
			end
		end
	end
	if unitsUpdateNumber == unitsUpdatePreview then
		HOOK.writeDebugDetail(ModuleName .. ": updateUnits ok")
	elseif debugProcess == true and unitsUpdateNumber ~= unitsUpdatePreview then
		HOOK.writeDebugDetail(ModuleName .. ": updateUnits, errors: unitsUpdateNumber = " .. tostring(unitsUpdateNumber) .. ", unitsUpdatePreview = " .. tostring(unitsUpdatePreview))
	end		
end	
HOOK.writeDebugDetail(ModuleName .. ": updateUnits loaded")

function updateBases(missionEnv, wrhsEnv)
	if table.getn(tblConquer) > 0 then
		HOOK.writeDebugDetail(ModuleName .. ": updateBases found some changes")
		for _b, bData in pairs(tblConquer) do		
			HOOK.writeDebugDetail(ModuleName .. ": updateBases base name: " .. tostring(bData.name))
			
			for wType, wTable in pairs(wrhsEnv) do				
				if bData.baseType == wType then
					if wType == "airports" then
						HOOK.writeDebugDetail(ModuleName .. ": updateBases base is an airport")
						
						--update warehouses file
						for wId, wData in pairs(wTable) do
							if wId == bData.id then
								HOOK.writeDebugDetail(ModuleName .. ": updateBases base storage found in wrhsEnv")
								local correctCoalition = nil
								if tonumber(bData.coa) == 0 then
									correctCoalition = "NEUTRAL"
								elseif tonumber(bData.coa) == 1 then
									correctCoalition = "RED"				
								elseif tonumber(bData.coa) == 2 then
									correctCoalition = "BLUE"				
								end							
								HOOK.writeDebugDetail(ModuleName .. ": updateBases coalition corrected")									
								
								HOOK.writeDebugDetail(ModuleName .. ": updateBases current coalition: " .. tostring(wData.coalition))	
								wData.coalition = correctCoalition
								HOOK.writeDebugDetail(ModuleName .. ": updateBases new coalition: " .. tostring(wData.coalition))								
							end
						end
					
					elseif wType == "warehouses" then
						HOOK.writeDebugDetail(ModuleName .. ": updateBases base is a unit (FARP or Ship)")
						
						--update warehouses file
						for wId, wData in pairs(wTable) do
							if tonumber(wId) == tonumber(bData.id) then
								HOOK.writeDebugDetail(ModuleName .. ": updateBases base storage found in wrhsEnv")
								local correctCoalition = nil
								if tonumber(bData.coa) == 0 then
									correctCoalition = "neutral"
								elseif tonumber(bData.coa) == 1 then
									correctCoalition = "red"				
								elseif tonumber(bData.coa) == 2 then
									correctCoalition = "blue"				
								end							
								HOOK.writeDebugDetail(ModuleName .. ": updateBases coalition corrected for airbases")									
								
								HOOK.writeDebugDetail(ModuleName .. ": updateBases current coalition: " .. tostring(wData.coalition))	
								wData.coalition = correctCoalition
								HOOK.writeDebugDetail(ModuleName .. ": updateBases new coalition: " .. tostring(wData.coalition))								
							end
						end							
						
						-- update mission table file
						local StaticTable = nil
						local correctCoalition = nil
						if tonumber(bData.coa) == 0 then
							correctCoalition = "neutral"
						elseif tonumber(bData.coa) == 1 then
							correctCoalition = "red"				
						elseif tonumber(bData.coa) == 2 then
							correctCoalition = "blue"				
						end							
						HOOK.writeDebugDetail(ModuleName .. ": updateBases coalition corrected for unit")										
						--copy existing
						for coalitionID,coalition in pairs(missionEnv["coalition"]) do
							for countryID,country in pairs(coalition["country"]) do
								for attrID,attr in pairs(country) do
									if (type(attr)=="table") then
										if attrID == "static" then
											for groupID,group in pairs(attr["group"]) do
												if (group) then
													local isIt = false
													for unitID,unit in pairs(group["units"]) do							
														if tonumber(unit.unitId) == tonumber(bData.id) then
															HOOK.writeDebugDetail(ModuleName .. ": updateBases found base static object")	
															isIt = true
														end
													end
													
													if isIt == true then
														StaticTable = group
														table.remove(attr["group"], groupID) 
													end
												end
											end
										end	
									end
								end
							end
						end
						
						--paste in new coalition
						for coalitionID,coalition in pairs(missionEnv["coalition"]) do
							if coalitionID == correctCoalition then
								HOOK.writeDebugDetail(ModuleName .. ": updateBases coalition found in env.mission")	
								for countryID,country in pairs(coalition["country"]) do
									if tonumber(country.id) == tonumber(bData.country) then
										HOOK.writeDebugDetail(ModuleName .. ": updateBases country found in env.mission")	
										if not country["static"] then
											country["static"] = {}
										end
										
										for attrID,attr in pairs(country) do
											if (type(attr)=="table") then
												if attrID == "static" then
													if not attr["group"] then
														attr["group"] = {}											
													end
	
													HOOK.writeDebugDetail(ModuleName .. ": updateBases created static group table")
													local curTbl = attr["group"]
													curTbl[#curTbl+1] = StaticTable
													attr["group"] = curTbl
													HOOK.writeDebugDetail(ModuleName .. ": updateBases added base to table")
												end	
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": updateBases no changes, skip")
	end
end	
HOOK.writeDebugDetail(ModuleName .. ": updateBases loaded")

function updateStaticCoa(missionEnv)
	if table.getn(tblWarehouseChangeCoa) > 0 then
		HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa found some changes")
		for _b, bData in pairs(tblWarehouseChangeCoa) do		
			HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa static name: " .. tostring(bData.name))

			-- update mission table file
			local StaticTable = nil
			local correctCoalition = nil
			if tonumber(bData.coa) == 0 then
				correctCoalition = "neutral"
			elseif tonumber(bData.coa) == 1 then
				correctCoalition = "red"				
			elseif tonumber(bData.coa) == 2 then
				correctCoalition = "blue"				
			end							
			HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa coalition corrected for unit")										
			--copy existing
			for coalitionID,coalition in pairs(missionEnv["coalition"]) do
				for countryID,country in pairs(coalition["country"]) do
					for attrID,attr in pairs(country) do
						if (type(attr)=="table") then
							if attrID == "static" then
								for groupID,group in pairs(attr["group"]) do
									if (group) then
										local isIt = false
										for unitID,unit in pairs(group["units"]) do							
											if tonumber(unit.unitId) == tonumber(bData.id) then
												HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa found static object")	
												isIt = true
											end
										end
										
										if isIt == true then
											StaticTable = group
											table.remove(attr["group"], groupID) 
										end
									end
								end
							end	
						end
					end
				end
			end
			
			--paste in new coalition
			for coalitionID,coalition in pairs(missionEnv["coalition"]) do
				if coalitionID == correctCoalition then
					HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa coalition found in env.mission")	
					for countryID,country in pairs(coalition["country"]) do
						if tonumber(country.id) == tonumber(bData.country) then
							HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa country found in env.mission")	
							if not country["static"] then
								country["static"] = {}
							end
							
							for attrID,attr in pairs(country) do
								if (type(attr)=="table") then
									if attrID == "static" then
										if not attr["group"] then
											attr["group"] = {}											
										end

										HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa created static group table")
										local curTbl = attr["group"]
										curTbl[#curTbl+1] = StaticTable
										attr["group"] = curTbl
										HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa added static to table")
									end	
								end
							end
						end
					end
				end
			end

		end
	end
end	
HOOK.writeDebugDetail(ModuleName .. ": updateStaticCoa loaded")

function updateCountryCoa(missionEnv)
	if tblCoaChanges and missionEnv and tblCoaChanges ~= {} then
		for crId, coaId in pairs(tblCoaChanges) do
			local coaNewName = nil
			if coaId == 1 then
				coaNewName = "red"
			elseif coaId == 2 then
				coaNewName = "blue"
			end

			-- coalitions table
			if missionEnv["coalitions"] and coaNewName then
				for coaName, coaData in pairs(missionEnv["coalitions"]) do
					if coaName == "neutrals" then
						for index, ctrId in pairs(coaData) do
							if ctrId == crId then
								table.remove(coaData, index)
							end
						end
					elseif coaName == coaNewName then
						coaData[#coaData+1]	 = crId
					end
				end
			end

			-- coalition table, find data
			local cTbl = nil
			for coalitionID,coalition in pairs(missionEnv["coalition"]) do
				if coalitionID == "neutrals" then
					for countryID,country in pairs(coalition["country"]) do
						if tonumber(country.id) == crId then
							cTbl = UTIL.deepCopy(country)
							table.remove(coalition["country"], countryID)
						end
					end
				end
			end

			-- coalition table, insert data
			if cTbl then
				for coalitionID, coalition in pairs(missionEnv["coalition"]) do
					if coalitionID == coaNewName then
						if coalition.country then
							coalition.country[#coalition.country+1] = cTbl
							HOOK.writeDebugDetail(ModuleName .. ": updateCountryCoa country " .. tostring(cTbl.name) .. " moved to " .. tostring(coalitionID))
						end
					end
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": updateCountryCoa cTbl not found")
			end

		end
	end
end
HOOK.writeDebugDetail(ModuleName .. ": updateCountryCoa loaded")

function updateMissionStartTime(missionEnv)
	if TMUP and missionEnv then
		local lthStr, lthStrErr = TMUP.updateStTime(missionEnv)		
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": TMUP.updateStTime, errors: " .. tostring(lthStr))
		end	
		
		HOOK.writeDebugDetail(ModuleName .. ": updateStTime ok")
	else
		HOOK.writeDebugDetail(ModuleName .. ": updateStTime, missing missionEnv")
	end
end
HOOK.writeDebugDetail(ModuleName .. ": updateMissionStartTime loaded")

function updateWarehouse(tblWarehousesContent, tbl)
	if WRHS and tblWarehousesContent and tbl and WRHS.WRHSloaded == true then
		 
		local lthStr, lthStrErr = WRHS.warehouseUpdateCycle(tblWarehousesContent, tbl)
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse, warehouseUpdateCycle errors: " .. tostring(lthStr))
		end
		
		if WRHS.tblWarehouses then
			tbl = WRHS.tblWarehouses
			WRHS.tblWarehouses = nil
			HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse ok")
		else
			HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse: tblWarehousesContent not found")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse: WRHS not found")
	end
end	
HOOK.writeDebugDetail(ModuleName .. ": WRHS loaded")

function updateWeather(missionEnv)
	if WTHR and WTHR.WTHRloaded == true then
		local lthStr, lthStrErr = WTHR.elabWeather(missionEnv)		
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": updateWeather, elabWeather errors: " .. tostring(lthStr))
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": updateWeather: WTHR not found")
	end
end
HOOK.writeDebugDetail(ModuleName .. ": WTHR loaded")

function updateFlags(tblFlags)
	if ADTR and ADTR.ADTRloaded == true then
		if tblFlags then
			local stringFile = "do\n"
			for flag, value in pairs(tblFlags) do
				local s = "trigger.action.setUserFlag('" .. tostring(flag) .. "', " .. tostring(value) .. ")"
				stringFile = stringFile .. s .. "\n"
			end

			stringFile = stringFile .. "trigger.action.outText('DSMC: trigger flags updated', 10)\n"
			stringFile = stringFile .. "end"
			UTIL.saveFile("tblFlagsSetter.lua", stringFile, HOOK.DSMCdirectory .. "Files/")
			
			local bDir_3 = HOOK.DSMCdirectory .. "Files/tblFlagsSetter.lua"
			local check = "tblFlagsSetter.lua"

			-- remove previously created states
			for fId, fData in pairs(ADTR.tblAddResources) do
				if fData.file == check then
					ADTR.tblAddResources[fId] = nil
				end
			end

			-- add updated conditions
			ADTR.tblAddResources[#ADTR.tblAddResources+1] = {path = bDir_3, cat = "lua", file = "tblFlagsSetter.lua"}
		end
	end
end
HOOK.writeDebugDetail(ModuleName .. ": updateFlags loaded")

function updateResources(missionEnv, mapEnv, tblRes)
	if ADTR and ADTR.ADTRloaded == true then
		ADTR.updateMapResources(missionEnv, mapEnv, tblRes)
	end	
end
HOOK.writeDebugDetail(ModuleName .. ": updateResources loaded")

function save() 
	HOOK.writeDebugDetail(ModuleName .. ": save starting... ")
	local processDone = false

	if not current_miz_file then
		HOOK.writeDebugDetail(ModuleName .. ": save, errore: current_miz_file non disponibile")
		return false
	end	
	if not current_wrhs_file then
		HOOK.writeDebugDetail(ModuleName .. ": save, errore: current_wrhs_file non disponibile")
		return false
	end
	if not current_dict_file then
		HOOK.writeDebugDetail(ModuleName .. ": save, errore: current_dict_file non disponibile")
		return false
	end
	if not current_mRes_file then
		HOOK.writeDebugDetail(ModuleName .. ": save, errore: current_mRes_file non disponibile")
		return false
	end	
	local mixFun, mErrStr 	= loadstring(current_miz_file);
	local wrhsFun, wErrStr 	= loadstring(current_wrhs_file);
	local dictFun, dErrStr 	= loadstring(current_dict_file);
	local mResFun, mErrStr 	= loadstring(current_mRes_file);
	HOOK.writeDebugDetail(ModuleName .. ": save fun's loaded")
	
	if mixFun and wrhsFun and dictFun and mResFun then
	
		local env = {}
		local wrhs_env = {}
		local dict_env = {}			
		local mRes_env = {}
		
		setfenv(mixFun, env)
		mixFun()		
		setfenv(wrhsFun, wrhs_env)
		wrhsFun()
		setfenv(dictFun, dict_env)
		dictFun()
		setfenv(mResFun, mRes_env)
		mResFun()	
		HOOK.writeDebugDetail(ModuleName .. ": save mixFun, dictFun, wrhsFun & mResFun available")
		
		--updateAirbaseTable(env.mission)
		
		updateUnits(env.mission)	
		updateStaticCoa(env.mission)
		killUnits(env.mission)		
		killStatics(env.mission)

		if HOOK.SPWN_var == true then
			IncludeSpawned(env.mission, tblSpawned, wrhs_env.warehouses) -- , dict_env.dictionary
			HOOK.writeDebugDetail(ModuleName .. ": env.mission maxDictId: " .. tostring(env.mission.maxDictId))
			local tempWh = wrhs_env.warehouses
			wrhs_env.warehouses = UTIL.addFARPwh(tempWh)
		end		
		if HOOK.CRST_var == true then
			createStatics(env.mission, tblDeadUnits)
		end		
		if HOOK.MOBJ_var == true then
			mapObjUpdate(env.mission, tblDeadScenObj)					
		end		
		if HOOK.TMUP_var == true then
			updateMissionStartTime(env.mission)
		end		
		if HOOK.WTHR_var == true then
			updateWeather(env.mission)
		end				

		updateCountryCoa(env.mission)
		updateBases(env.mission, wrhs_env.warehouses) 
		
		local doPlans = false -- till DGWS active
		if HOOK.WRHS_var == true then

			-- reset warehouse if mission is 000
			local lenght 		= string.len(HOOK.loadedMizFileName)
			local initLenght 	= lenght - 2
			local endLenght 	= lenght
			local strSub		= string.sub(HOOK.loadedMizFileName, initLenght, endLenght)
			
			if strSub == "000" then
				HOOK.writeDebugDetail(ModuleName .. ": mission is 000, resetting warehouse content")
				UTIL.whAutoReset(wrhs_env.warehouses, env.mission)
				UTIL.whAutoPopulateDepotsAndProduction(wrhs_env.warehouses, env.mission)
				doPlans = false
			elseif strSub == "998" then
				HOOK.writeDebugDetail(ModuleName .. ": mission is 998, setting all wh to void")
				UTIL.whAutoZero(wrhs_env.warehouses)
				doPlans = false
			else
				updateWarehouse(tblWarehousesContent, wrhs_env.warehouses) -- also update airbaseTbl
			end

			-- fix wh if necessary
			local wh = UTIL.fixWarehouse(wrhs_env.warehouses) 
			if wh then
				wrhs_env.warehouses = UTIL.deepCopy(wh)
				wh = nil
				HOOK.writeDebugDetail(ModuleName .. ": warehouse fix ended")
			end

		end		

		-- merge wh info in tblAirbases
		for aId, aData in pairs(tblAirbases) do
			if aData.wh then
				for wId, wData in pairs(tblWarehousesContent) do
					if aData.name == wData.name then
						aData.wh = wData.wh
					end
				end
			end
		end
				
		-- plan module for DSMC 2.0
		if UTIL.fileExist(HOOK.DSMCdirectory .. "DGWS" .. ".lua") == true and HOOK.DGWS_var == true and doPlans == true then
			HOOK.writeDebugDetail(ModuleName .. " starting DGWS...")
			local m = UTIL.deepCopy(env.mission)
			local d = UTIL.deepCopy(dict_env.dictionary)
			local w = UTIL.deepCopy(wrhs_env.warehouses)
			local r = UTIL.deepCopy(mRes_env.mapResource)
			
			env.mission, dict_env.dictionary = DGWS.executePlanning(m, d, w)
			HOOK.writeDebugDetail(ModuleName .. " DGWS done")

		end	

		-- update flags
		if HOOK.FLAG_var == true then
			updateFlags(tblFlags)
		end

		if ADTR.tblAddResources then
			HOOK.writeDebugDetail(ModuleName .. " adding external files")
			updateResources(env.mission, mRes_env.mapResource, ADTR.tblAddResources)
			HOOK.writeDebugDetail(ModuleName .. " external files added")
		else
			HOOK.writeDebugDetail(ModuleName .. " no external files available")
		end			

		lfs.mkdir(HOOK.missionfilesdirectory .. "Temp/")
		--mission
		local fName = "mission"
		local missName = HOOK.missionfilesdirectory .. "Temp/" .. fName
		local outFile = io.open(missName, "w");
		local newMissionStr = UTIL.Integratedserialize('mission', env.mission);
		outFile:write(newMissionStr);
		io.close(outFile);
		--HOOK.writeDebugDetail(ModuleName .. " d3")

		--warehouses
		local w_fName = "warehouses"
		local wrhsName = HOOK.missionfilesdirectory .. "Temp/" .. w_fName
		local w_outFile = io.open(wrhsName, "w");
		local newWrhsStr = UTIL.Integratedserialize('warehouses', wrhs_env.warehouses);
		w_outFile:write(newWrhsStr);
		io.close(w_outFile);

		--HOOK.writeDebugDetail(ModuleName .. " d3")

		--dictionary
		local d_fName = "dictionary"
		local dictName = HOOK.missionfilesdirectory .. "Temp/" .. d_fName
		local d_outFile = io.open(dictName, "w");
		local newDictStr = UTIL.Integratedserialize('dictionary', dict_env.dictionary);
		d_outFile:write(newDictStr);
		io.close(d_outFile);

		--mapResource
		local m_fName = "mapResource"
		local mResName = HOOK.missionfilesdirectory .. "Temp/" .. m_fName
		local m_outFile = io.open(mResName, "w");
		local newMResStr = UTIL.Integratedserialize('mapResource', mRes_env.mapResource);
		m_outFile:write(newMResStr);
		io.close(m_outFile);
		
		processDone = true
	end
	
	if processDone == true then
		HOOK.writeDebugDetail(ModuleName .. ": save ok")
	elseif processDone == false then
		HOOK.writeDebugDetail(ModuleName .. ": save, error")				
	end		
end
HOOK.writeDebugDetail(ModuleName .. ": save loaded")

function getMizFiles(loadedMissionPath)
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles starting ")
	TempMizPath = HOOK.tempmissionfilesdirectory .. HOOK.StartFilterCode .. "-tempfile.miz"
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles TempMizPath: " .. tostring(TempMizPath))
	lfs.mkdir(HOOK.tempmissionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir)	
	
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles, minizip.unzOpen opening=" .. tostring(loadedMissionPath))
	local zipFile, err = minizip.unzOpen(loadedMissionPath, 'rb')
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles, minizip.unzOpen loaded")
	zipFile:unzGoToFirstFile() --vai al primo file dello zip		
	local NewSaveresourceFiles = {}
	local CreatedDirectories = {}
	local function Unpack()
		while true do --scompattalo e passa al prossimo
			local filename = zipFile:unzGetCurrentFileName()
			HOOK.writeDebugDetail(ModuleName .. ": getMizFiles, unzipping " .. tostring(filename))
			local BaseTempDir = HOOK.tempmissionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir
			local fullPath = BaseTempDir .. filename
			
			--create subdirectories
			local subdir1_string = nil
			local subdir2_string = nil
			local subdir3_string = nil
			local subdir4_string = nil
			local subdir5_string = nil
			local subdir6_string = nil
			local subdir7_string = nil
			local subdir8_string = nil
			local subdir9_string = nil
			local subdir1_end = nil
			local subdir2_end = nil
			local subdir3_end = nil
			local subdir4_end = nil
			local subdir5_end = nil
			local subdir6_end = nil
			local subdir7_end = nil
			local subdir8_end = nil
			local subdir9_end = nil
			local subdir1 = nil
			local subdir2 = nil
			local subdir3 = nil
			local subdir4 = nil
			local subdir5 = nil
			local subdir6 = nil
			local subdir7 = nil
			local subdir8 = nil
			local subdir9 = nil				
				
			-- check if a subdir exist
			local subdirTrue = false
			subdir1_string = string.sub(filename, 1)
			
			-- identify first subdir string -- PROVA AD AGGIUNGERE WORKAROUND
			if subdir1_string then
				subdir1_end = string.find(subdir1_string, "/")
				if subdir1_end then
					subdir1 = string.sub(subdir1_string, 1, subdir1_end-1)					
					lfs.mkdir(BaseTempDir .. subdir1 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir1 .. "/"
					BaseTempDir = BaseTempDir .. subdir1 .. "/"							
					subdir2_string = string.sub(subdir1_string, subdir1_end+1)
					subdirTrue = true
				end	
			end
			
			-- identify second subdir string
			if subdir2_string then
				subdir2_end = string.find(subdir2_string, "/")
				if subdir2_end then
					subdir2 = string.sub(subdir2_string, 1, subdir2_end-1)						
					lfs.mkdir(BaseTempDir .. subdir2 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir2 .. "/"
					BaseTempDir = BaseTempDir .. subdir2 .. "/"							
					subdir3_string = string.sub(subdir2_string, subdir2_end+1)
					subdirTrue = true					
				end	
			end				
			
			-- identify third subdir string
			if subdir3_string then
				subdir3_end = string.find(subdir3_string, "/")
				if subdir3_end then
					subdir3 = string.sub(subdir3_string, 1, subdir3_end-1)						
					lfs.mkdir(BaseTempDir .. subdir3 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir3 .. "/"
					BaseTempDir = BaseTempDir .. subdir3 .. "/"							
					subdir4_string = string.sub(subdir3_string, subdir3_end+1)
					subdirTrue = true
				end	
			end							

			-- identify fourth and last subdir string
			if subdir4_string then
				subdir4_end = string.find(subdir4_string, "/")
				if subdir4_end then
					subdir4 = string.sub(subdir4_string, 1, subdir4_end-1)						
					lfs.mkdir(BaseTempDir .. subdir4 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir4 .. "/"
					BaseTempDir = BaseTempDir .. subdir4 .. "/"	
					subdir5_string = string.sub(subdir4_string, subdir4_end+1)
					subdirTrue = true
				end	
			end

			-- identify fifth subdir string
			if subdir5_string then
				subdir5_end = string.find(subdir5_string, "/")
				if subdir5_end then
					subdir5 = string.sub(subdir5_string, 1, subdir5_end-1)						
					lfs.mkdir(BaseTempDir .. subdir5 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir5 .. "/"
					BaseTempDir = BaseTempDir .. subdir5 .. "/"		
					subdir6_string = string.sub(subdir5_string, subdir5_end+1)
					subdirTrue = true
				end	
			end

			-- identify sixth subdir string
			if subdir6_string then
				subdir6_end = string.find(subdir6_string, "/")
				if subdir6_end then
					subdir6 = string.sub(subdir6_string, 1, subdir6_end-1)						
					lfs.mkdir(BaseTempDir .. subdir6 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir6 .. "/"
					BaseTempDir = BaseTempDir .. subdir6 .. "/"	
					subdir7_string = string.sub(subdir6_string, subdir6_end+1)
					subdirTrue = true
				end	
			end

			-- identify seventh subdir string
			if subdir7_string then
				subdir7_end = string.find(subdir7_string, "/")
				if subdir7_end then
					subdir7 = string.sub(subdir7_string, 1, subdir7_end-1)						
					lfs.mkdir(BaseTempDir .. subdir7 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir7 .. "/"
					BaseTempDir = BaseTempDir .. subdir7 .. "/"	
					subdir8_string = string.sub(subdir7_string, subdir7_end+1)
					subdirTrue = true
				end	
			end			


			-- identify eight subdir string
			if subdir8_string then
				subdir8_end = string.find(subdir8_string, "/")
				if subdir8_end then
					subdir8 = string.sub(subdir8_string, 1, subdir8_end-1)						
					lfs.mkdir(BaseTempDir .. subdir8 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir8 .. "/"
					BaseTempDir = BaseTempDir .. subdir8 .. "/"
					subdir9_string = string.sub(subdir8_string, subdir8_end+1)
					subdirTrue = true
				end	
			end	
			

			-- identify nineth subdir string
			if subdir9_string then
				subdir9_end = string.find(subdir9_string, "/")
				if subdir9_end then
					subdir9 = string.sub(subdir9_string, 1, subdir9_end-1)						
					lfs.mkdir(BaseTempDir .. subdir9 .. "/")
					CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir9 .. "/"
					BaseTempDir = BaseTempDir .. subdir9 .. "/"		
					subdirTrue = true						
				end	
			end	
			
			--if not string.find(fullPath, "/") then -- subdirTrue
				zipFile:unzUnpackCurrentFile(fullPath)
			--end 
			NewSaveresourceFiles[filename] = fullPath
			

			if (fullPath:sub(-7) == "mission") then
				local f = io.open(fullPath, 'r')
				local mis_path = nil
				if f then
					local fline = f:read()
					if fline and fline:sub(1,7) == 'mission' then
						mis_path = fullPath
					end
					f:close()
				end										
				if mis_path then
					local f = io.open(mis_path, 'r')
					if f then
						current_miz_file = f:read('*all')
						f:close()								
					end
				end
			elseif (fullPath:sub(-10) == "warehouses") then
				local f = io.open(fullPath, 'r')
				local wrhs_path = nil
				if f then
					local fline = f:read()
					if fline and fline:sub(1,10) == 'warehouses' then
						wrhs_path = fullPath
					end
					f:close()
				end										
				if wrhs_path then 
					local f = io.open(wrhs_path, 'r')
					if f then
						current_wrhs_file = f:read('*all')
						f:close()						
					end
				end				
			elseif (fullPath:sub(-10) == "dictionary") then
				local f = io.open(fullPath, 'r')
				local dict_path = nil
				if f then
					local fline = f:read()
					if fline and fline:sub(1,10) == 'dictionary' then
						dict_path = fullPath
					end
					f:close()
				end										
				if dict_path then
					local f = io.open(dict_path, 'r')
					if f then
						current_dict_file = f:read('*all')
						f:close()							
					end
				end	
			elseif (fullPath:sub(-11) == "mapResource") then
				local f = io.open(fullPath, 'r')
				local mRes_path = nil
				if f then
					local fline = f:read()
					if fline and fline:sub(1,11) == 'mapResource' then
						mRes_path = fullPath
					end
					f:close()
				end										
				if mRes_path then
					local f = io.open(mRes_path, 'r')
					if f then
						current_mRes_file = f:read('*all')
						f:close()						
					end
				end							
			end

			
			if not zipFile:unzGoToNextFile() then 
				break
			end
		end
		--zipFile:unzClose()
		return NewSaveresourceFiles
	end
	Unpack() -- execute the unpacking	
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles - unpack ok")
	
	local function deleteFiles()
		for file, fullPath in pairs(NewSaveresourceFiles) do
			local fileIsThere = UTIL.fileExist(fullPath)
			if fileIsThere == true then
				os.remove(fullPath)				
			end
		end
	end
	zipFile:unzClose()
	deleteFiles()	
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles - files deleted")
	
	-- remove directories
	for id, path in pairs(CreatedDirectories) do		
		lfs.rmdir(path)
	end
	lfs.rmdir(HOOK.tempmissionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir  .. "Scripts/")
	lfs.rmdir(HOOK.tempmissionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir)
	--lfs.rmdir(HOOK.tempmissionfilesdirectory .. "Temp/")
	HOOK.writeDebugDetail(ModuleName .. ": getMizFiles - dir removed ok")
	
	if current_mRes_file and current_dict_file and current_wrhs_file and current_miz_file then
		local mixFun, mErrStr 	= loadstring(current_miz_file);
		local wrhsFun, wErrStr 	= loadstring(current_wrhs_file);
		local dictFun, dErrStr 	= loadstring(current_dict_file);
		local mResFun, mErrStr 	= loadstring(current_mRes_file);
		HOOK.writeDebugDetail(ModuleName .. ": getMizFiles fun's loaded")
		
		if mixFun and wrhsFun and dictFun and mResFun then
		
			tempEnv = {}
			
			setfenv(mixFun, tempEnv)
			mixFun()		
			setfenv(wrhsFun, tempEnv)
			wrhsFun()
			setfenv(dictFun, tempEnv)
			dictFun()
			setfenv(mResFun, tempEnv)
			mResFun()
			HOOK.writeDebugDetail(ModuleName .. ": getMizFiles fun's executed")	
		else
			HOOK.writeDebugDetail(ModuleName .. ": getMizFiles fun's missing")			
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getMizFiles - current_xxxx_file not available!")
	end
end
HOOK.writeDebugDetail(ModuleName .. ": getMizFiles loaded")

function getNewMissionName(currentName)
	if currentName then
		local lenght 		= string.len(currentName)
		local initLenght 	= lenght - 2
		local endLenght 	= lenght
		local strSub		= string.sub(currentName, initLenght, endLenght)

		local val			= tonumber(strSub)
		if type(val) == "number" then
			HOOK.writeDebugDetail(ModuleName .. ": getNewMissionName - val is a number")
			local strSub	= string.sub(currentName, 1, lenght-3) .. string.format("%03d", val + 1) .. ".miz"
			HOOK.writeDebugDetail(ModuleName .. ": getNewMissionName : " .. strSub)
			return strSub
		else
			HOOK.writeDebugDetail(ModuleName .. ": getNewMissionName - val is not a number")
			HOOK.writeDebugDetail(ModuleName .. ": getNewMissionName : " .. currentName .. "_001.miz")
			return currentName .. "_001.miz"

		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getNewMissionName - no currentName")
	end

end

function buildNewMizFile(loadedMissionPath, loadedMizFileName, cpm_path)
	HOOK.writeDebugBase(ModuleName .. ": buildNewMizFile - starting with path: " .. tostring(loadedMissionPath) .. ", saving path: " .. tostring(cpm_path))
	
	--check new name
	local missionName = nil
	if loadedMizFileName == nil then
		missionName = "DSMC_recoveredFile_000.miz"
	else
		missionName = getNewMissionName(loadedMizFileName)
	end
	
	-- local curHour = tostring(os.date('%Y-%m-%d_%H_%M_%S'))
	NewMizPath = HOOK.missionfilesdirectory .. missionName
	
	HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - NewMizPath path: " .. tostring(NewMizPath))
	
	if tblAirbases and tblUnitsUpdate and NewMizPath then

		lfs.mkdir(HOOK.missionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir)	
		
		local zipFile, err = minizip.unzOpen(loadedMissionPath, 'rb')
		zipFile:unzGoToFirstFile() --vai al primo file dello zip		
		DSMC_NewSaveresourceFiles = {}
		local CreatedDirectories = {}
		local function Unpack()
			local SaveresourceFiles = {}
			while true do --scompattalo e passa al prossimo
				local filename = zipFile:unzGetCurrentFileName()
				local BaseTempDir = HOOK.missionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir
				local fullPath = BaseTempDir .. filename

				--create subdirectories
				local subdir1_string = nil
				local subdir2_string = nil
				local subdir3_string = nil
				local subdir4_string = nil
				local subdir5_string = nil
				local subdir6_string = nil
				local subdir7_string = nil
				local subdir8_string = nil
				local subdir9_string = nil
				local subdir1_end = nil
				local subdir2_end = nil
				local subdir3_end = nil
				local subdir4_end = nil
				local subdir5_end = nil
				local subdir6_end = nil
				local subdir7_end = nil
				local subdir8_end = nil
				local subdir9_end = nil
				local subdir1 = nil
				local subdir2 = nil
				local subdir3 = nil
				local subdir4 = nil
				local subdir5 = nil
				local subdir6 = nil
				local subdir7 = nil
				local subdir8 = nil
				local subdir9 = nil				
					
				-- check if a subdir exist
				subdir1_string = string.sub(filename, 1)
				
				-- identify first subdir string
				if subdir1_string then
					subdir1_end = string.find(subdir1_string, "/")
					if subdir1_end then
						subdir1 = string.sub(subdir1_string, 1, subdir1_end-1)					
						lfs.mkdir(BaseTempDir .. subdir1 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir1 .. "/"
						BaseTempDir = BaseTempDir .. subdir1 .. "/"							
						subdir2_string = string.sub(subdir1_string, subdir1_end+1)
					end	
				end
				
				-- identify second subdir string
				if subdir2_string then
					subdir2_end = string.find(subdir2_string, "/")
					if subdir2_end then
						subdir2 = string.sub(subdir2_string, 1, subdir2_end-1)						
						lfs.mkdir(BaseTempDir .. subdir2 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir2 .. "/"
						BaseTempDir = BaseTempDir .. subdir2 .. "/"							
						subdir3_string = string.sub(subdir2_string, subdir2_end+1)
					end	
				end				
				
				-- identify third subdir string
				if subdir3_string then
					subdir3_end = string.find(subdir3_string, "/")
					if subdir3_end then
						subdir3 = string.sub(subdir3_string, 1, subdir3_end-1)						
						lfs.mkdir(BaseTempDir .. subdir3 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir3 .. "/"
						BaseTempDir = BaseTempDir .. subdir3 .. "/"							
						subdir4_string = string.sub(subdir3_string, subdir3_end+1)
					end	
				end							

				-- identify fourth and last subdir string
				if subdir4_string then
					subdir4_end = string.find(subdir4_string, "/")
					if subdir4_end then
						subdir4 = string.sub(subdir4_string, 1, subdir4_end-1)						
						lfs.mkdir(BaseTempDir .. subdir4 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir4 .. "/"
						BaseTempDir = BaseTempDir .. subdir4 .. "/"	
						subdir5_string = string.sub(subdir4_string, subdir4_end+1)
					end	
				end

				-- identify fifth subdir string
				if subdir5_string then
					subdir5_end = string.find(subdir5_string, "/")
					if subdir5_end then
						subdir5 = string.sub(subdir5_string, 1, subdir5_end-1)						
						lfs.mkdir(BaseTempDir .. subdir5 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir5 .. "/"
						BaseTempDir = BaseTempDir .. subdir5 .. "/"		
						subdir6_string = string.sub(subdir5_string, subdir5_end+1)
					end	
				end

				-- identify sixth subdir string
				if subdir6_string then
					subdir6_end = string.find(subdir6_string, "/")
					if subdir6_end then
						subdir6 = string.sub(subdir6_string, 1, subdir6_end-1)						
						lfs.mkdir(BaseTempDir .. subdir6 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir6 .. "/"
						BaseTempDir = BaseTempDir .. subdir6 .. "/"	
						subdir7_string = string.sub(subdir6_string, subdir6_end+1)
					end	
				end

				-- identify seventh subdir string
				if subdir7_string then
					subdir7_end = string.find(subdir7_string, "/")
					if subdir7_end then
						subdir7 = string.sub(subdir7_string, 1, subdir7_end-1)						
						lfs.mkdir(BaseTempDir .. subdir7 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir7 .. "/"
						BaseTempDir = BaseTempDir .. subdir7 .. "/"	
						subdir8_string = string.sub(subdir7_string, subdir7_end+1)
					end	
				end			


				-- identify eight subdir string
				if subdir8_string then
					subdir8_end = string.find(subdir8_string, "/")
					if subdir8_end then
						subdir8 = string.sub(subdir8_string, 1, subdir8_end-1)						
						lfs.mkdir(BaseTempDir .. subdir8 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir8 .. "/"
						BaseTempDir = BaseTempDir .. subdir8 .. "/"
						subdir9_string = string.sub(subdir8_string, subdir8_end+1)
					end	
				end	
				

				-- identify nineth subdir string
				if subdir9_string then
					subdir9_end = string.find(subdir9_string, "/")
					if subdir9_end then
						subdir9 = string.sub(subdir9_string, 1, subdir9_end-1)						
						lfs.mkdir(BaseTempDir .. subdir9 .. "/")
						CreatedDirectories[#CreatedDirectories + 1] = BaseTempDir .. subdir9 .. "/"
						BaseTempDir = BaseTempDir .. subdir9 .. "/"								
					end	
				end	
				
				zipFile:unzUnpackCurrentFile(fullPath) 
				SaveresourceFiles[filename] = fullPath
				if not zipFile:unzGoToNextFile() then 
					break
				end
			end
			zipFile:unzClose()
			return SaveresourceFiles
		end
		DSMC_NewSaveresourceFiles = Unpack() -- execute the unpacking
		HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - unpack ok")

		save()
		UTIL.moveFile(HOOK.OldMissionPath, HOOK.NewMissionPath)
		HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - mission file moved")
		UTIL.moveFile(HOOK.OldDictPath, HOOK.NewDictPath)			
		HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - dictionary file moved")
		UTIL.moveFile(HOOK.OldWrhsPath, HOOK.NewWrhsPath)
		HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - warehouses file moved")
		UTIL.moveFile(HOOK.OldMResPath, HOOK.NewMResPath)
		HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - mapResource file moved")

		--[=[
		net.dostring_in("server", "log.info(\" f it\")")

		local provatesto = [[
			local testo = "provatestodila"
			return testo
		  ]]
	  
		  local result = net.dostring_in("server", provatesto)
		  HOOK.writeDebugDetail(ModuleName .. ": PROVATESTO: " .. tostring(result))
	  
		  local provatesto2 = [[
			local newText = uString
			return newText
		  ]]
	  
		  local dsmcUtbl, derr2 = net.dostring_in("server", provatesto2)
		  HOOK.writeDebugDetail(ModuleName .. ": PROVATESTO2: " .. tostring(dsmcUtbl))
		  HOOK.writeDebugDetail(ModuleName .. ": PROVATESTO2err: " .. tostring(derr2))

		  local provatesto3 = [[
            log.info("test")
            local newText = pString
            return newText
          ]]
	  
		  local dsmcUtbl3, derr3 = net.dostring_in("server", provatesto3)
		  HOOK.writeDebugDetail(ModuleName .. ": PROVATESTO3: " .. tostring(dsmcUtbl3))
		  HOOK.writeDebugDetail(ModuleName .. ": PROVATESTO3err: " .. tostring(derr3))
		  --]=]--

		--("DSMC_NewSaveresourceFiles.lua", DSMC_NewSaveresourceFiles)

		local miz = minizip.zipCreate(NewMizPath)
		if miz then
			HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - new miz zip created")
			
			local function packMissionResources(miz)
				for file, fullPath in pairs(DSMC_NewSaveresourceFiles) do
					local fileIsThere = UTIL.fileExist(fullPath)
					if fileIsThere == true then
						miz:zipAddFile(file, fullPath)
					else
						HOOK.writeDebugBase(ModuleName .. ": missing files to repack: " .. tostring(file))			
					end
					os.remove(fullPath)
				end
			end
			packMissionResources(miz)
			miz:zipClose()
			zipFile:unzClose()		
			HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - repack ok")	
			
			--UTIL.dumpTable("CreatedDirectories.lua", CreatedDirectories)			
			
			while #CreatedDirectories>0 do
				local maxId = 0
				for id, path in pairs(CreatedDirectories) do
					if id > maxId then
						maxId = id
					end
				end			
				
				for id, path in pairs(CreatedDirectories) do
					if id == maxId then
						lfs.rmdir(path)
						table.remove(CreatedDirectories, id)
					end
				end	
			end

			lfs.rmdir(HOOK.missionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir  .. "Scripts/")
			lfs.rmdir(HOOK.missionfilesdirectory .. "Temp/" .. HOOK.NewMizTempDir)
			--lfs.rmdir(HOOK.missionfilesdirectory .. "Temp/")
			HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - dir removed ok")	
			--]]--
			
			
			DSMC_NewSaveresourceFiles = nil
			HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - miz saved, sending message...")
			net.dostring_in("mission", [[a_do_script("trigger.action.outText('scenery saved!', 10)")]])
			--net.dostring_in("mission", [[EMBD.doMessage('scenery saved!')]])

			HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - miz saved, message sent!")
			UTIL.inJectCode("DSMC_allowStop", "DSMC_allowStop = true")

			return true
		else
			HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - no miz created")
		end
		
	else
		HOOK.writeDebugBase(ModuleName .. ": buildNewMizFile, errors: tblAirbases or tblUnitsUpdate missing")	
	end


	tblDeadUnits					= nil
	tblDeadScenObj					= nil
	tblUnitsUpdate					= nil
	tblAirbases						= nil
	tblWarehousesContent			= nil
	tblSpawned						= nil
	tblDictEntries					= nil
	tblToBeKilled					= {}
	HOOK.writeDebugBase(ModuleName .. ": buildNewMizFile ok")
	
end
HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile loaded")

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
--~=