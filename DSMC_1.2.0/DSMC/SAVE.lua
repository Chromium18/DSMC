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
--UTIL.dumpTable("ME_DB.lua", ME_DB)

--## VARS
tblToBeKilled 		= {}
HOOK.writeDebugDetail(ModuleName .. ": vars required loaded")

--## FUNCTIONS

function updateAirbaseTable(missionEnv)
	for admId, admData in pairs(tblAirbases) do
		HOOK.writeDebugDetail(ModuleName .. ": updating id " .. tostring(admData.id) .. ", name " .. tostring(admData.name))
		
		local paramsInsertFARP = {
			["SHELTER"] = 0,
			["FOR_HELICOPTERS"] = 1,
			["FOR_AIRPLANES"] = 0,
			["HEIGHT"] = 50,
			["LENGTH"] = 50,
			["WIDTH"] = 50,
		}

		local paramsInsertCarrier = {
			["SHELTER"] = 0,
			["FOR_HELICOPTERS"] = 1,
			["FOR_AIRPLANES"] = 1,
			["HEIGHT"] = 40,
			["LENGTH"] = 40,
			["WIDTH"] = 40,
		}
		
		HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: checking type: " .. tostring(admData.desc.typeName))

		if admData.desc.category == 0 then
			HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: category 0")
			local nearestAFB = ME_DB.getNearestAirdrome(admData.pos.x, admData.pos.z)
			local parkList = getStandList(nearestAFB.roadnet)		-- ME_parking.
			admData["parkings"] = parkList
			HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: added parkings")

		elseif admData.desc.category == 1 then
			admData["parkings"] = {}
			for i=1, 4 do
				table.insert(admData["parkings"], {name = tostring(i), numParking = i, params = paramsInsertFARP, flag = 64, crossroad_index = 0, x = admData.pos.x, y = admData.pos.z})
			end
			HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: added parkings")
			
		elseif admData.desc.category == 2 then
			HOOK.writeDebugDetail(ModuleName .. " updateAirbaseTable: category 2")
			local unitDef = ME_DB.unit_by_type[admData.desc.typeName]
			local dataFound = false

			if admData.desc.attributes.Buildings == true then -- this include also single helipad and invisible farps!
				HOOK.writeDebugDetail(ModuleName .. " updateAirbaseTable: building, 1 parking available for next mission")					
				admData["parkings"] = {}
				table.insert(admData["parkings"], {name = tostring(1), numParking = 1, params = paramsInsertFARP, flag = 64, crossroad_index = 0, x = admData.pos.x, y = admData.pos.z})
				HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: added parkings")
				dataFound = true
			end

			if dataFound == false then
				if unitDef then
					if unitDef.RunWays then
						admData["parkings"] = getStandListForShip(admData.pos.x, admData.pos.z, unitDef.RunWays) -- ME_parking.
						for spId, spData in pairs(admData["parkings"]) do
							spData["params"] = paramsInsertCarrier
						end
						HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: added parkings")
						
					elseif unitDef.numParking then
						admData["parkings"] = {}
						if unitDef.numParking == 1 then
							table.insert(admData["parkings"], {name = tostring(1), numParking = 1, params = paramsInsertFARP, flag = 64, crossroad_index = 0, x = admData.pos.x, y = admData.pos.z})
						else
							for i=1, unitDef.numParking do
								table.insert(admData["parkings"], {name = tostring(i), numParking = i, params = paramsInsertFARP, flag = 64, crossroad_index = 0, x = admData.pos.x, y = admData.pos.z})
							end
						end
						HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: added parkings")
					end
				else
					HOOK.writeDebugDetail(ModuleName .. " updateAirbaseTable: type not available: ERROR")
				end
			else
				HOOK.writeDebugDetail(ModuleName .. " updateAirbaseTable: already defined as building")
			end
		end

		-- remove used parking from me
		for coalitionID,coalition in pairs(missionEnv["coalition"]) do
			for countryID,country in pairs(coalition["country"]) do
				for attrID,attr in pairs(country) do
					if (type(attr)=="table") then
						if attrID == "plane" then
							for groupID,group in pairs(attr["group"]) do
								if (group) then
									local baseId = nil
									if group.route then
										for pId, pData in pairs(group.route.points) do
											if pId == 1 then
												if pData.airdromeId then
													baseId = pData.airdromeId
												elseif pData.helipadId then
													baseId = pData.helipadId
												end
											end
										end
									end
									if baseId then
										if tonumber(baseId) == tonumber(admData.id) then
											HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable, removing used parking: found admData")
											for unitID,unit in pairs(group["units"]) do
												if unit.parking_id then
													for prId, prData in pairs(admData["parkings"]) do
														if tonumber(prData.name) == tonumber(unit.parking_id) then
															HOOK.writeDebugDetail(ModuleName .. ": updateAirbaseTable: removed parking " .. tostring(unit.parking))
															table.remove(admData["parkings"], prId)
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
		--]]--

	end
	UTIL.dumpTable("tblAirbases.lua", tblAirbases)
end

function getStandList(roadnet)
	local sList = Terrain.getStandList(roadnet, {"SHELTER","FOR_HELICOPTERS","FOR_AIRPLANES","WIDTH","LENGTH","HEIGHT"})    
	local listP = {}
	for k, v in pairs(sList) do
		listP[v.crossroad_index] = v	  
        if v.params then
            local params = {}
            for kk, vv in pairs(v.params) do
                params[kk] = tonumber(vv)
            end
            v.params = params
        end    
	end
	return listP
end

function getStandListForShip(a_x, a_y, a_RunWays)
	local listP = {}
							
	for k, RunWay in pairs(a_RunWays) do
		if type(k) == 'number' and k > 1 then
			table.insert(listP, {name = tostring(k-1), numParking = k-1, x = a_x, y = a_y, offsetX = RunWay[1][1], offsetY = RunWay[1][3]})			
		end
	end
	return listP
end

function IncludeSpawned(missionEnv, tbl, dictEnv, whEnv)
	if SPWN and missionEnv and tbl and dictEnv and whEnv then
		local lthStr, lthStrErr = SPWN.doSpawned(missionEnv, tbl, dictEnv, whEnv)		
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
												HOOK.writeDebugDetail(ModuleName .. ": killUnits unit is not alive, removing unit table")									
												table.remove(group.units, unitID);
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

function updateUnits(missionEnv)	
	local unitsUpdatePreview = table.getn(tblUnitsUpdate)
	local unitsUpdateNumber = 0 
	--usedParkings = {}
	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					if attrID == "plane" or attrID == "helicopter" then
						HOOK.writeDebugDetail(ModuleName .. ": plane or helo found, skip")
					elseif attrID == "ship" then
						for groupID,group in pairs(attr["group"]) do
							if (group) then		
								local isCarrierGroup = false
								HOOK.writeDebugDetail(ModuleName .. ": updateUnits checking carrier group")
								for unitID,unit in pairs(group["units"]) do		
									for id, updatedData in pairs (tblUnitsUpdate) do
										if tonumber(updatedData.unitId) == tonumber(unit.unitId) then
											if updatedData.carrier == true then
												isCarrierGroup = true
												HOOK.writeDebugDetail(ModuleName .. ": updateUnits, unit " .. tonumber(unit.unitId) .. " is a carrier")
											end
										end
									end
								end
								
								if isCarrierGroup == false then
									for unitID,unit in pairs(group["units"]) do
										HOOK.writeDebugDetail(ModuleName .. ": updateUnits looking for unit number " .. tostring(unitID) .. ", unitId: " .. tostring(unit.unitId))
										local isAlive = true
										for id, deadData in pairs (tblDeadUnits) do -- check if this unit is dead
											if tonumber(deadData.unitId) == tonumber(unit.unitId) then
												isAlive = false
											end
										end
										HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive))
										if isAlive == false then
											tblToBeKilled[#tblToBeKilled+1] = {uId = unit.unitId, gId = group.groupId}
											HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive) .. ", unit added to tblToBeKilled")
										else
											--update the unit
											if group and unit then
												HOOK.writeDebugDetail(ModuleName .. ": updateUnits updating unit")
												for id, updatedData in pairs (tblUnitsUpdate) do
													if tonumber(updatedData.unitId) == tonumber(unit.unitId) then										
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
																				}, -- end of ["spans"]
															HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 spans")												
														end
														
														for id, pointData in pairs (group.route.points) do
															if id > 1 then
																table.remove(group.route.points, id);
															end
														end
														
														if group.route.spans then
															group.route.spans = nil 
														end
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
					else
						for groupID,group in pairs(attr["group"]) do
							if (group) then						
								for unitID,unit in pairs(group["units"]) do
									HOOK.writeDebugDetail(ModuleName .. ": updateUnits looking for unit number " .. tostring(unitID) .. ", unitId: " .. tostring(unit.unitId))
									local isAlive = true
									for id, deadData in pairs (tblDeadUnits) do -- check if this unit is dead
										if tonumber(deadData.unitId) == tonumber(unit.unitId) then
											isAlive = false
										end
									end
									HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive))
									if isAlive == false then
										tblToBeKilled[#tblToBeKilled+1] = {uId = unit.unitId, gId = group.groupId}
										HOOK.writeDebugDetail(ModuleName .. ": updateUnits isAlive: " .. tostring(isAlive) .. ", unit added to tblToBeKilled")
									else
										--update the unit
										if group and unit then
											--HOOK.writeDebugDetail(ModuleName .. ": updateUnits updating unit")
											for id, updatedData in pairs (tblUnitsUpdate) do
												if tonumber(updatedData.unitId) == tonumber(unit.unitId) then	
													HOOK.writeDebugDetail(ModuleName .. ": updateUnits updating unit: found update data ")							
													if updatedData.aircraft == false then
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
																				}, -- end of ["spans"]
															HOOK.writeDebugDetail(ModuleName .. ": updateUnits updated unit 1 spans")													
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

function updateWarehouse(tblLogistic, tbl)
	if WRHS and tblLogistic and tbl and WRHS.WRHSloaded == true then		
		
		local lthStr, lthStrErr = WRHS.warehouseUpdateCycle(tblLogistic, tbl)		
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse, warehouseUpdateCycle errors: " .. tostring(lthStr))
		end
		
		if WRHS.tblWarehouses then
			tbl = WRHS.tblWarehouses
			WRHS.tblWarehouses = nil
			HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse ok")
		else
			HOOK.writeDebugDetail(ModuleName .. ": updateWarehouse: tblLogistic not found")
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

function createSlots(misEnv, whEnv, dictEnv)
	if SLOT and SLOT.SLOTloaded == true then
		local lthStr, lthStrErr = SLOT.addSlot(misEnv, whEnv, dictEnv)	
		if not lthStrErr then
			HOOK.writeDebugDetail(ModuleName .. ": slotUpdate, createSlots errors: " .. tostring(lthStr))
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": slotUpdate: SLOT not found")
	end
end
HOOK.writeDebugDetail(ModuleName .. ": SLOT loaded")

function updateBriefing(missionEnv, dictionaryEnv)
	if UPAP and UPAP.UPAPloaded == true then
		UPAP.expWthToText(missionEnv)
	end
end
HOOK.writeDebugDetail(ModuleName .. ": updateBriefing loaded")

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
		
		if HOOK.SLOT_var == true then -- and HOOK.DSMC_ServerMode == false 
			updateAirbaseTable(env.mission)
		end
		
		updateUnits(env.mission)	
		updateStaticCoa(env.mission)
		killUnits(env.mission)		

		if HOOK.SPWN_var == true then
			IncludeSpawned(env.mission, tblSpawned, dict_env.dictionary, wrhs_env.warehouses)
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

		updateBases(env.mission, wrhs_env.warehouses) -- moved before warehouses.

		if HOOK.WRHS_var == true then

			-- fix wh if necessary
			local wh = UTIL.fixWarehouse(wrhs_env.warehouses) -- basequantity not used.
			if wh then
				wrhs_env.warehouses = UTIL.deepCopy(wh)
				wh = nil
				HOOK.writeDebugDetail(ModuleName .. ": warehouse fix ended")
			end

			local sortieIndex = env.mission.sortie
			local sortieValue = nil
			local sortieId = nil
			for sId, sValue in pairs(dict_env.dictionary) do 
				if sId == sortieIndex then
					sortieValue = sValue
					sortieId = sId
				end
			end
			
			if sortieValue == "DSMC set warehouses" and sortieId then
				HOOK.writeDebugDetail(ModuleName .. ": warehouse asking a pure restart")
				--UTIL.getZeroedAirbase(wrhs_env.warehouses)
				UTIL.getZeroedAirbase(wrhs_env.warehouses)
				UTIL.whRestart(wrhs_env.warehouses, tblAirbases, env.mission)
				dict_env.dictionary[sortieId] = ""
				if HOOK.WRHS_rblt == true then
					UTIL.reBuildSupplyNet(wrhs_env.warehouses, env.mission)
				end
			else
				if HOOK.WRHS_rblt == true then
					UTIL.reBuildSupplyNet(wrhs_env.warehouses, env.mission)
				end
				updateWarehouse(tblLogistic, wrhs_env.warehouses)
			end
		end		

		if HOOK.SLOT_var == true then
			createSlots(env.mission, wrhs_env.warehouses, dict_env.dictionary)
		end		
		
		if HOOK.GOAP_var == true then
			GOAP.loadtables()
			GOAP.createColourZones(env.mission, tblTerrainDb)

			--test
			GOAP.planGroundGroup(env.mission, 6, "Dziguri", true, dict_env.dictionary, 600)
			--planAirGroup(missionEnv, id, task, pos, delay)
			local id = 14
			GOAP.planAirGroup(id, env.mission, dict_env.dictionary, "CAP", {x = 0, y = 1000, z = 0})

		end	

		if ADTR.tblAddResources then
			HOOK.writeDebugDetail(ModuleName .. " adding external files")
			updateResources(env.mission, mRes_env.mapResource, ADTR.tblAddResources)
			HOOK.writeDebugDetail(ModuleName .. " external files added")
		else
			HOOK.writeDebugDetail(ModuleName .. " no external files available")
		end			

		--updateBases(env.mission, wrhs_env.warehouses)
		HOOK.writeDebugDetail(ModuleName .. " d1")
		if HOOK.UPAP_var == true then
			updateBriefing(env.mission, dict_env.dictionary)
		end	
		HOOK.writeDebugDetail(ModuleName .. " d2")

		lfs.mkdir(HOOK.missionfilesdirectory .. "Temp/")
		--mission
		local fName = "mission"
		local missName = HOOK.missionfilesdirectory .. "Temp/" .. fName
		local outFile = io.open(missName, "w");
		local newMissionStr = UTIL.Integratedserialize('mission', env.mission); -- IntegratedserializeWithCycles  --  UTIL.IntegratedserializeWithCycles('mission', env.mission)
		outFile:write(newMissionStr);
		io.close(outFile);
		HOOK.writeDebugDetail(ModuleName .. " d3")
		
		--UTIL.dumpTable("wrhs_env.warehouses.lua", wrhs_env.warehouses)

		--warehouses
		local w_fName = "warehouses"
		local wrhsName = HOOK.missionfilesdirectory .. "Temp/" .. w_fName
		local w_outFile = io.open(wrhsName, "w");
		local newWrhsStr = UTIL.Integratedserialize('warehouses', wrhs_env.warehouses);
		w_outFile:write(newWrhsStr);
		io.close(w_outFile);

		HOOK.writeDebugDetail(ModuleName .. " d3")

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
			

			if string.find(fullPath, "mission") then
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
			elseif string.find(fullPath, "warehouses") then
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
			elseif string.find(fullPath, "dictionary") then
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
			elseif string.find(fullPath, "mapResource") then
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
	--HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - UPAP.weatherExport: " .. tostring(UPAP.weatherExport))
	
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

		UTIL.dumpTable("DSMC_NewSaveresourceFiles.lua", DSMC_NewSaveresourceFiles)

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
			
			if UPAP then
				UPAP.weatherExport = true
				HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile - UPAP.weatherExport: " .. tostring(UPAP.weatherExport))	
			end
			
			DSMC_NewSaveresourceFiles = nil
			net.dostring_in("mission", [[a_do_script("trigger.action.outText('scenery saved!', 10)")]])
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
	tblLogistic						= nil
	tblSpawned						= nil
	tblDictEntries					= nil
	tblToBeKilled					= {}
	HOOK.writeDebugBase(ModuleName .. ": buildNewMizFile ok")
	
end
HOOK.writeDebugDetail(ModuleName .. ": buildNewMizFile loaded")

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
--~=