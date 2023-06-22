-- Dynamic Sequential Mission Campaign -- DSMC core injected functions module

local ModuleName  	= "EMBD"
local MainVersion 	= DSMC_MainVersion
local SubVersion 	= DSMC_SubVersion
local Build 		= DSMC_Build
local Date			= DSMC_Date

env.setErrorMessageBoxEnabled(false)
local base 						= _G
local DSMC_io 					= base.io  	-- check if io is available in mission environment
local DSMC_lfs 					= base.lfs		-- check if lfs is available in mission environment
local DSMC_allowStop			= true

local texttimer					= 1
local mapObj_deathcounter 		= 0
--local baseGcounter				= DSMC_baseGcounter or 20000000
--local baseUcounter				= DSMC_baseUcounter or 19000000
if not DSMC_baseGcounter then
	DSMC_baseGcounter = 20000000
end

if not DSMC_baseUcounter then
	DSMC_baseUcounter = 19000000
end

local messageunitId				= 1
local tblSpawnedcounter			= 0
local playerShutEngine			= false
local playerCrashed				= false
local playerShutEngine			= false
local firstNeutralCountry		= 2	
local nearestAFBonLand			= 5000 -- this should be really improved, but atm no other solution than a fixed number.

local ExclusionTag				= DSMC_ExclusionTag or "DSMC_NoUp"

strAirbases						= ""
completeStringstrAirbases		= ""
strDeadUnits					= ""
completeStringstrDeadUnits		= ""
strDeadScenObj					= ""
completeStringstrUnitsUpdate	= ""
strLogistic						= ""
completeStringstrLogistic		= ""
strSpawned						= ""
completeStringstrSpawned		= ""
strConquer						= ""
completeStringstrConquer		= ""
strinlogisticUnits				= ""
completeStringstrlogisticUnits	= ""

EMBD 							= {}
tblDeadUnits					= {}
tblMissingUnits					= {}
tblDeadScenObj					= {}
tblUnitsUpdate					= {}
tblAirbases						= {}
tblLogistic						= {}
tblLogCollect					= {}
tblSpawned						= {}
tblConquer						= {}
--tblConquerCollect				= {}
tblWarehouseChangeCoa 			= {}

-- airlift crates cross support
local checkLOGIandCTLD = function()
	if LOGI then
		spawnableCrates					= LOGI.spawnableCrates
		upscaleResupplyFactor    		= LOGI.upscaleResupplyFactor
	elseif ctld_c then
		spawnableCrates					= ctld_c.spawnableCrates
		upscaleResupplyFactor    		= ctld_c.upscaleResupplyFactor
	elseif ctld then
		spawnableCrates					= ctld.spawnableCrates
		upscaleResupplyFactor    		= ctld.upscaleResupplyFactor
	end
end
timer.scheduleFunction(checkLOGIandCTLD, {}, timer.getTime() + 5)


trigger.action.outText("DSMC is active in this mission", 10)
if not DSMC_DisableF10save then
	trigger.action.outText("to save scenery progress, you can use the communication F10 menù and choose DSMC - save mission", 5)
end

if not DSMC_multy then
	trigger.action.outText("DSMC is in single player mode: you must remember to save the mission on your own!", 5)
end

if DSMC_debugProcessDetail == true then
	env.info(("EMBD set setErrorMessageBoxEnabled : true"))
	env.info(("EMBD DSMC_ExclusionTag : " .. tostring(DSMC_ExclusionTag)))
	env.info(("EMBD set ExclusionTag : " .. tostring(ExclusionTag)))
	env.info(("EMBD set WRHS_module_active : " .. tostring(WRHS_module_active)))
	
end		

if dbWarehouse and DSMC_debugProcessDetail == true then
	env.info(("DSMC dbWarehouse exist"))
end

if dbWeapon and DSMC_debugProcessDetail == true then
	env.info(("DSMC dbWeapon exist"))
end

--### UTILS	

function IntegratedbasicSerialize(s)
	if s == nil then
		return "\"\""
	else
		if ((type(s) == 'number') or (type(s) == 'boolean') or (type(s) == 'function') or (type(s) == 'table') or (type(s) == 'userdata') ) then
			return tostring(s)
		elseif type(s) == 'string' then
			return string.format('%q', s)
		end
	end
end

function Integratedserialize(name, value, level)
	-----Based on ED's serialize_simple2
	local basicSerialize = function (o)
	  if type(o) == "number" then
		return tostring(o)
	  elseif type(o) == "boolean" then
		return tostring(o)
	  else -- assume it is a string
		return IntegratedbasicSerialize(o)
	  end
	end

	local serialize_to_t = function (name, value, level)
	----Based on ED's serialize_simple2

	  local var_str_tbl = {}
	  if level == nil then level = "" end
	  if level ~= "" then level = level.."  " end

	  table.insert(var_str_tbl, level .. name .. " = ")

	  if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
		table.insert(var_str_tbl, basicSerialize(value) ..  ",\n")
	  elseif type(value) == "table" then
		  table.insert(var_str_tbl, "\n"..level.."{\n")

		  for k,v in pairs(value) do -- serialize its fields
			local key
			if type(k) == "number" then
			  key = string.format("[%s]", k)
			else
			  key = string.format("[%q]", k)
			end

			table.insert(var_str_tbl, Integratedserialize(key, v, level.."  "))

		  end
		  if level == "" then
			table.insert(var_str_tbl, level.."} -- end of "..name.."\n")

		  else
			table.insert(var_str_tbl, level.."}, -- end of "..name.."\n")

		  end
	  else
		print("Cannot serialize a "..type(value))
	  end
	  return var_str_tbl
	end

	local t_str = serialize_to_t(name, value, level)

	return table.concat(t_str)
end

function IntegratedserializeWithCycles(name, value, saved)
	local basicSerialize = function (o)
		if type(o) == "number" then
			return tostring(o)
		elseif type(o) == "boolean" then
			return tostring(o)
		else -- assume it is a string
			return IntegratedbasicSerialize(o)
		end
	end

	local t_str = {}
	saved = saved or {}       -- initial value
	if ((type(value) == 'string') or (type(value) == 'number') or (type(value) == 'table') or (type(value) == 'boolean')) then
		table.insert(t_str, name .. " = ")
		if type(value) == "number" or type(value) == "string" or type(value) == "boolean" then
			table.insert(t_str, basicSerialize(value) ..  "\n")
		else

			if saved[value] then    -- value already saved?
				table.insert(t_str, saved[value] .. "\n")
			else
				saved[value] = name   -- save name for next time
				table.insert(t_str, "{}\n")
				for k,v in pairs(value) do      -- save its fields
					local fieldname = string.format("%s[%s]", name, basicSerialize(k))
					table.insert(t_str, IntegratedserializeWithCycles(fieldname, v, saved))
				end
			end
		end
		return table.concat(t_str)
	else
		return ""
	end
end

function deepCopy(object)
    local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

if DSMC_io and DSMC_lfs then
	env.info(("EMBD loading desanitized additional function"))
	
	DSMC_EMBDmodule 	= "funzia"
	--env.info(("EMBD module test = " .. tostring(HOOK.StartFilterCode)))
	--env.info(("EMBD requiring net module... "))
	--DSMC_net = require('net')

	function tableShow(tbl, loc, indent, tableshow_tbls)
		tableshow_tbls = tableshow_tbls or {} --create table of tables
		loc = loc or ""
		indent = indent or ""
		if type(tbl) == 'table' then --function only works for tables!
			tableshow_tbls[tbl] = loc
			
			local tbl_str = {}

			tbl_str[#tbl_str + 1] = indent .. '{\n'
			
			for ind,val in pairs(tbl) do -- serialize its fields
				if type(ind) == "number" then
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = tostring(ind)
					tbl_str[#tbl_str + 1] = '] = '
				else
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = IntegratedbasicSerialize(ind)
					tbl_str[#tbl_str + 1] = '] = '
				end
						
				if ((type(val) == 'number') or (type(val) == 'boolean')) then
					tbl_str[#tbl_str + 1] = tostring(val)
					tbl_str[#tbl_str + 1] = ',\n'		
				elseif type(val) == 'string' then
					tbl_str[#tbl_str + 1] = IntegratedbasicSerialize(val)
					tbl_str[#tbl_str + 1] = ',\n'
				elseif type(val) == 'nil' then -- won't ever happen, right?
					tbl_str[#tbl_str + 1] = 'nil,\n'
				elseif type(val) == 'table' then
					if tableshow_tbls[val] then
						tbl_str[#tbl_str + 1] = tostring(val) .. ' already defined: ' .. tableshow_tbls[val] .. ',\n'
					else
						tableshow_tbls[val] = loc ..  '[' .. IntegratedbasicSerialize(ind) .. ']'
						tbl_str[#tbl_str + 1] = tostring(val) .. ' '
						tbl_str[#tbl_str + 1] = tableShow(val,  loc .. '[' .. IntegratedbasicSerialize(ind).. ']', indent .. '    ', tableshow_tbls)
						tbl_str[#tbl_str + 1] = ',\n'  
					end
				elseif type(val) == 'function' then
					if debug and debug.getinfo then
						local fcnname = tostring(val)
						local info = debug.getinfo(val, "S")
						if info.what == "C" then
							tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', C function') .. ',\n'
						else 
							if (string.sub(info.source, 1, 2) == [[./]]) then
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')' .. info.source) ..',\n'
							else
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')') ..',\n'
							end
						end
						
					else
						tbl_str[#tbl_str + 1] = 'a function,\n'	
					end
				else
					tbl_str[#tbl_str + 1] = 'unable to serialize value type ' .. IntegratedbasicSerialize(type(val)) .. ' at index ' .. tostring(ind)
				end
			end
			
			tbl_str[#tbl_str + 1] = indent .. '}'
			return table.concat(tbl_str)
		end
	end

	function dumpTable(fname, tabledata)
		if DSMC_lfs and DSMC_io then
			local fdir = DSMC_lfs.writedir() .. [[DSMC\Debug\]] .. fname
			local f = DSMC_io.open(fdir, 'w')
			f:write(tableShow(tabledata))
			f:close()
		end
	end	

	function EMBD.saveTable(fname, tabledata)		
		if DSMC_lfs and DSMC_io then
			local DSMCfiles = DSMC_lfs.writedir() .. "Missions/Temp/Files/"
			local fdir = DSMCfiles .. fname .. ".lua"
			local f = DSMC_io.open(fdir, 'w')
			local str = IntegratedserializeWithCycles(fname, tabledata)
			if f then
				f:write(str)
				f:close()
			else
				env.info(("EMBD saveTable f missing"))
			end
		end
	end
	
	--dumpTable("_G_SSE.lua", _G)

	env.info(("EMBD desanitized additional function loaded"))
end

-- ##CORE

--[[
function EMBD.getFreeCountry()
	for i=1,100 do		
		local found = true
		for cId, cData in pairs(env.mission.coalitions) do
		--dumpTable("env.mission.coalitions.lua", env.mission.coalitions)
			--env.info(("EMBD firstNeutralCountry check 1"))
			if cId == "blue" or cId == "red" then
				if cData then
					for fId, fData in pairs(cData) do
						if fData == i then
							env.info(("EMBD.getAptInfo: firstNeutralCountry excluded " .. tostring(i)))
							found = false
						end
					end
				end
			end
		end
		if found == true then
			firstNeutralCountry = tonumber(i)
			env.info(("EMBD.getAptInfo: firstNeutralCountry =  " .. tostring(firstNeutralCountry)))	
			break
		end		
	end 
end
--]]--


function EMBD.getAptInfo()
	tblAirbases = {}
	local apt_Table = world.getAirbases()
	--dumpTable("apt_Table.lua", apt_Table)
	for Aid, Adata in pairs(apt_Table) do
		if Adata and Adata:isExist() == true then
			local aptInfo = Adata:getDesc()
			local aptName = Adata:getName()
			local aptID	  = Adata:getID()
			local indexId = Aid
			local aptPos = Adata:getPosition().p
			local aptCoa = Adata:getCoalition()
			--if env.mission.theatre == "Caucasus" then
			--	indexId = indexId +11			
			--	if DSMC_debugProcessDetail == true then
			--		env.info(("EMBD.getAptInfo added 11 to airport index due to Caucasus scenery, from: " .. tostring(Aid) .. " to: " .. tostring(indexId)))
			--	end				
			--end	
			--for cat

			tblAirbases[#tblAirbases+1] = {id = aptID, index = aptID, name = aptName, desc = aptInfo, pos = aptPos, coa = aptCoa}
		end
	end
end
                                                                                                                                                           
function EMBD.sendUnitsData(missionEnv)
	tblUnitsUpdate = {}
	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					for groupID,group in pairs(attr["group"]) do

						if (group) then						

							-- check excluded
							local exclude = false
							local gName = nil
							if group.name then
								--DICTPROBLEM
								--gName = env.getValueDictByKey(group.name)
								gName = group.name
								if gName and type(gName) == "string" then
									if string.find(gName, ExclusionTag) then
										exclude = true
									end
								end
							end

							if exclude == false then
								for unitID, unit in pairs(group["units"]) do																			
									local isAlive = true

									-- filter dead units // REMOVED CHECK 2022.06.26 due to death units bug
									--for id, deadData in pairs (tblDeadUnits) do
									--	if tonumber(deadData.unitId) == tonumber(unit.unitId) then
									--		isAlive = false
									--	end
									--end																
									
									if isAlive == true and group and unit then							
										if attrID == "plane" then	--or attrID == "plane" 	
											if DSMC_debugProcessDetail == true then
												--env.info(("EMBD.sendUnitsData found plane, skip"))
											end

										elseif attrID == "helicopter" then	--or attrID == "plane" 	 -- IS THIS STILL EFFECTIVELY NEEDED!?
											--DICTPROBLEM
											--local uName 		= env.getValueDictByKey(unit.name)
											local uName 		= unit.name
											local curUnit 		= Unit.getByName(uName)
																	
											if curUnit  then
												local uInAir		= curUnit:inAir()
												if uInAir == false then -- flying things must be grounded!
													local curUnitPos 		= curUnit:getPosition().p

													tblUnitsUpdate[#tblUnitsUpdate + 1] = {unitId = unit.unitId, x = curUnitPos.x, y = curUnitPos.y, z = curUnitPos.z, aircraft = true, carrier = false}

													if DSMC_debugProcessDetail == true then
														--env.info(("EMBD.sendUnitsData add a record in tblUnitsUpdate, helicopter"))
													end	
												end
											end										

										elseif attrID == "static" then
											--DICTPROBLEM
											--local uName 		= env.getValueDictByKey(unit.name)
											local uName 		= unit.name
											local uCat			= unit.category
											if uCat == "Cargos" then
												curUnit 		= StaticObject.getByName(uName)																					
												if curUnit then -- cargo still exist
													curUnitPos 		= curUnit:getPosition().p
													if curUnitPos then
														tblUnitsUpdate[#tblUnitsUpdate + 1] = {unitId = unit.unitId, x = curUnitPos.x, y = curUnitPos.y, z = curUnitPos.z, aircraft = false, carrier = false}
														
														for dId, dData in pairs(tblDeadUnits) do
															if dData.unitId == unit.unitId then
																tblDeadUnits[dId] = nil
															end
														end
														
														if DSMC_debugProcessDetail == true then
															--env.info(("EMBD.sendUnitsData add a record in tblUnitsUpdate, cargo"))
														end
													else													
														if DSMC_debugProcessDetail == true then
															--env.info(("EMBD.sendUnitsData can't find the cargo position, assuming dead!"))
														end			
														tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unit.unitId), unitInfantry = true}		
													end												
												else
													if DSMC_debugProcessDetail == true then
														--env.info(("EMBD.sendUnitsData add a record in tblDeadUnits to remove cargo"))
													end		
													tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unit.unitId), unitInfantry = true}												
												end										
											end
										
										else
											--DICTPROBLEM
											--local uName 		= env.getValueDictByKey(unit.name)
											local uName 		= unit.name
											if uName then
												local curUnit 		= Unit.getByName(uName)
												
												if curUnit then
													curUnitPos 		= curUnit:getPosition().p
													curUnitCarrier	= curUnit:hasAttribute("Aircraft Carriers")
													if curUnitPos then
														tblUnitsUpdate[#tblUnitsUpdate + 1] = {unitId = unit.unitId, x = curUnitPos.x, y = curUnitPos.y, z = curUnitPos.z, aircraft = false, carrier = curUnitCarrier}
														if DSMC_debugProcessDetail == true then
															--env.info(("EMBD.sendUnitsData add a record in tblUnitsUpdate, unit id " .. tostring(unit.unitId) ))
														end	

														for dId, dData in pairs(tblDeadUnits) do
															if dData.unitId == unit.unitId then
																if DSMC_debugProcessDetail == true then
																	--env.info(("EMBD.sendUnitsData unit was recorded death, removing from table, unit id " .. tostring(unit.unitId) ))
																end
																table.remove(tblDeadUnits, dId)
																--tblDeadUnits[dId] = nil
															end
														end

			
													else
														--if DSMC_debugProcessDetail == true then
														--	env.info(("EMBD.sendUnitsData can't find the unit position, assuming dead as infantry to prevent spawning wreckage!"))
														--end		
														--tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unit.unitId), unitInfantry = true}

														if DSMC_debugProcessDetail == true then
															--env.info(("EMBD.sendUnitsData can't find the unit position, assuming dead due to ed dead tracking, unit id " .. tostring(unit.unitId)))
														end	

														-- check if already there, registered with a standard kill or death
														local proceed = true
														for dId, dData in pairs(tblDeadUnits) do 
															if dData.unitId == unit.unitId then
																if DSMC_debugProcessDetail == true then
																	--env.info(("EMBD.sendUnitsData unit identified as already in the table due to death event, unit id " .. tostring(unit.unitId)))
																end
																proceed = false
															end
														end

														if proceed == true then
															tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unit.unitId), unitInfantry = false}
														end
													end
												else

													if DSMC_debugProcessDetail == true then
														--env.info(("EMBD.sendUnitsData can't find the unit, assuming dead due to ed dead tracking, unit id " .. tostring(unit.unitId)))
													end	

													-- check if already there, registered with a standard kill or death
													local proceed = true
													for dId, dData in pairs(tblDeadUnits) do 
														if dData.unitId == unit.unitId then
															if DSMC_debugProcessDetail == true then
																--env.info(("EMBD.sendUnitsData unit identified as already in the table due to death event, unit id " .. tostring(unit.unitId)))
															end
															proceed = false
														end
													end

													if proceed == true then
														tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unit.unitId), unitInfantry = false}
													end
												end
											end
										end
									end
								end
							else
								env.info(("EMBD.sendUnitsData excluded group from update: " .. tostring(gName)))
							end
						end
					end
				end
			end
		end
	end
	if DSMC_debugProcessDetail == true then
		env.info(("EMBD.sendUnitsData ok"))
	end		
end	

function EMBD.changeWarehouseCoalition(missionEnv)
	if DSMC_debugProcessDetail == true then
		env.info(("EMBD.changeWarehouseCoalition started"))
	end	
	tblWarehouseChangeCoa = {}
	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					for groupID,group in pairs(attr["group"]) do
						if (group) then						
							for unitID, unit in pairs(group["units"]) do
								if group and unit then
									if attrID == "static" then
										--DICTPROBLEM
										--local uName 		= env.getValueDictByKey(unit.name)
										local uName 		= unit.name
										local curUnit 		= StaticObject.getByName(uName)
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.changeWarehouseCoalition, uName: " .. tostring(uName) ))
										end										
										if curUnit then -- obj still exist
											if curUnit:getLife() > 1 then
												local curUnitCat 		= curUnit:getCategory()
												if curUnitCat == 3 then
													local curUnitPos 		= curUnit:getPosition().p
													local curUnitCoa 		= curUnit:getCoalition()

													if DSMC_debugProcessDetail == true then
														env.info(("EMBD.changeWarehouseCoalition, curUnitCoa: " .. tostring(curUnitCoa) ))
													end

													local _volume = {
														id = world.VolumeType.SPHERE,
														params = {
															point = curUnitPos,
															radius = 1000,
														},
													}

													local t_coa = {red = false, blue = false, neutral = false}
													local o_ctry = nil
													local _search = function(_obj)
														pcall(function()
															if _obj ~= nil then

																local o_coa = _obj:getCoalition()
																o_ctry = _obj:getCountry()
																if DSMC_debugProcessDetail == true then
																	--env.info(("EMBD.changeWarehouseCoalition, o_coa: " .. tostring(o_coa) ))
																end

																if o_coa == 0 then
																	t_coa["neutral"] = true
																	if DSMC_debugProcessDetail == true then
																		--env.info(("EMBD.changeWarehouseCoalition, t_coa neutral"))
																	end	
																elseif o_coa == 1 then
																	t_coa["red"] = true
																	if DSMC_debugProcessDetail == true then
																		--env.info(("EMBD.changeWarehouseCoalition, t_coa red"))
																	end	
																elseif o_coa == 2 then
																	t_coa["blue"] = true
																	if DSMC_debugProcessDetail == true then
																		--env.info(("EMBD.changeWarehouseCoalition, t_coa blue"))
																	end	
																end
															end
														end)
													end
												
													world.searchObjects(Object.Category.UNIT, _volume, _search)	
													
													if o_ctry then
														if t_coa["neutral"] == true and t_coa["red"] == false and t_coa["blue"] == false and curUnitCoa ~= 0 then
															if DSMC_debugProcessDetail == true then
																env.info(("EMBD.changeWarehouseCoalition, single different than curUnitCoa. unit " .. tostring(curUnit:getID()) .. ", going neutral"))
															end	
															tblWarehouseChangeCoa[#tblWarehouseChangeCoa+1] = {id = curUnit:getID(), coa = 0, name = curUnit:getName(), country = o_ctry}
														elseif t_coa["neutral"] == false and t_coa["red"] == true and t_coa["blue"] == false and curUnitCoa ~= 1 then
															if DSMC_debugProcessDetail == true then
																env.info(("EMBD.changeWarehouseCoalition, single different than curUnitCoa. unit " .. tostring(curUnit:getID()) .. ", going red"))
															end	
															tblWarehouseChangeCoa[#tblWarehouseChangeCoa+1] = {id = curUnit:getID(), coa = 1, name = curUnit:getName(), country = o_ctry}
														elseif t_coa["neutral"] == false and t_coa["red"] == false and t_coa["blue"] == true and curUnitCoa ~= 2 then
															if DSMC_debugProcessDetail == true then
																env.info(("EMBD.changeWarehouseCoalition, single different than curUnitCoa. unit " .. tostring(curUnit:getID()) .. ", going blue"))
															end	
															tblWarehouseChangeCoa[#tblWarehouseChangeCoa+1] = {id = curUnit:getID(), coa = 2, name = curUnit:getName(), country = o_ctry}
														else
															if DSMC_debugProcessDetail == true then
																env.info(("EMBD.changeWarehouseCoalition, no change required for id:" .. tostring(curUnit:getID())))
															end	
														end
													else
														if DSMC_debugProcessDetail == true then
															env.info(("EMBD.changeWarehouseCoalition, no country identified!"))
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
	if DSMC_debugProcessDetail == true then
		env.info(("EMBD.changeWarehouseCoalition end"))
	end	
end

function EMBD.getNorthCorrection(gPoint)	--gets the correction needed for true north
	local point = deepCopy(gPoint)
	if not point.z then --Vec2; convert to Vec3
		point.z = point.y
		point.y = 0
	end
	local lat, lon = coord.LOtoLL(point)
	local north_posit = coord.LLtoLO(lat + 1, lon)
	return math.atan2(north_posit.z - point.z, north_posit.x - point.x)
end

function EMBD.getHeading(u, rawHeading)
	local unitpos = u:getPosition()
	if unitpos then
		local Heading = math.atan2(unitpos.x.z, unitpos.x.x)
		if not rawHeading then
			Heading = Heading + EMBD.getNorthCorrection(unitpos.p)
		end
		if Heading < 0 then
			Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
		end
		return Heading
	end
end

function EMBD.updateSpawnedPosition(tblSpawned, missionEnv)	
	if tblSpawned then
		for id, idData in pairs(tblSpawned) do	

			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.updateSpawnedPosition checking group " ..tostring(idData.gName)))
			end

			local exclude = false
			if string.find(idData.gName, ExclusionTag) then
				exclude = true
			end

			if exclude == false then
				-- verify existing
				local proceed = true
				for coalitionID,coalition in pairs(missionEnv["coalition"]) do
					for countryID,country in pairs(coalition["country"]) do
						for attrID,attr in pairs(country) do
							if (type(attr)=="table") then
								for groupID,group in pairs(attr["group"]) do
									if (group) then
										if group.name == idData.gName then
											proceed = false
											tblSpawned[id] = nil
											if DSMC_debugProcessDetail == true then
												env.info(("EMBD.updateSpawnedPosition group already existing, skipping"))
											end	
										end
									end
								end
							end
						end
					end
				end

				if proceed == true then				
					if idData.gUnits then			
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.updateSpawnedPosition idData.gUnits exist"))
						end				
						if tonumber(idData.gCat) == 1 then
							for uId, uData in pairs(idData.gUnits) do
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition checking unit " .. tostring(uData.uName)))
								end					
								local unit	 	= Unit.getByName(uData.uName)					
								if unit then
									if unit:getLife() > 1 then
										local unitPos  	= unit:getPosition().p	
										uData.uPos = unitPos
										if 	uData.uHdg then
											local unitHdg	= EMBD.getHeading(unit, true)	
											uData.uHdg = unitHdg
										end
										
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.updateSpawnedPosition udata updated"))
										end
									else
										uData.uAlive = false
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.updateSpawnedPosition unit dead, removed"))
										end
									end
								else
									uData.uAlive = false
									if DSMC_debugProcessDetail == true then
										env.info(("EMBD.updateSpawnedPosition unit missing, removed"))		
									end			
								end
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition unit check complete"))
								end
							end
						elseif tonumber(idData.gCat) == 3 then --- static
							for uId, uData in pairs(idData.gUnits) do
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition checking static " .. tostring(uData.uName)))
								end					
								local object	 	= StaticObject.getByName(uData.uName)					
								if object then
									if object:getLife() > 1 then
										local unitPos  	= object:getPosition().p	
										uData.uPos = unitPos
										if 	uData.uHdg then
											local unitHdg	= EMBD.getHeading(object, true)	
											uData.uHdg = unitHdg
										end
										env.info(("EMBD.updateSpawnedPosition udata updated"))
									else
										tblSpawned[id] = nil
										--idData.gStaticAlive = false
										env.info(("EMBD.updateSpawnedPosition static dead, removed"))
									end
								else
									tblSpawned[id] = nil
									--idData.gStaticAlive = false
									env.info(("EMBD.updateSpawnedPosition static missing, removed"))					
								end
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition static check complete"))
								end
							end
						elseif tonumber(idData.gCat) == 4 then --- airbase
							for uId, uData in pairs(idData.gUnits) do
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition checking airbase " .. tostring(uData.uName)))
								end					
								local object	 	= Airbase.getByName(uData.uName)					
								if object then
									if object:getLife() > 1 then
										local unitPos  	= object:getPosition().p					
										uData.uPos = unitPos
										env.info(("EMBD.updateSpawnedPosition udata updated"))
									else
										tblSpawned[id] = nil
										--idData.gStaticAlive = false
										env.info(("EMBD.updateSpawnedPosition airbase dead, removed"))
									end
								else
									tblSpawned[id] = nil
									--idData.gStaticAlive = false
									env.info(("EMBD.updateSpawnedPosition airbase missing, removed"))					
								end
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition airbase check complete"))
								end
							end				
						elseif tonumber(idData.gCat) == 6 then --- cargo
							for uId, uData in pairs(idData.gUnits) do
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition checking cargo " .. tostring(uData.uName)))
								end					
								local object	 	= StaticObject.getByName(uData.uName)				
								if object then
									if DSMC_debugProcessDetail == true then
										env.info(("EMBD.updateSpawnedPosition cargo life " .. tostring(object:getLife())))
									end							

									if object:getLife() > 1 then
										local unitPos  	= object:getPosition().p					
										uData.uPos = unitPos
										env.info(("EMBD.updateSpawnedPosition udata updated"))
									else
										tblSpawned[id] = nil
										--idData.gStaticAlive = false
										env.info(("EMBD.updateSpawnedPosition cargo dead, removed"))
									end
								else
									if id then
										tblSpawned[id] = nil
										--table.remove(tblSpawned, id) -- modified from "tonumber(id)"
										idData.gStaticAlive = false
										env.info(("EMBD.updateSpawnedPosition cargo missing, removed"))	
										--tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(uData.uID), coalitionID = idData.gCoalition, countryID = idData.gCountry, staticTable = nil, objCategory = idData.gCat, objTypeName = uData.uType}
									end
								end
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.updateSpawnedPosition cargo check complete"))
								end
							end					
						end
					end
				end
			end
		end
	end
	if DSMC_debugProcessDetail == true then
		env.info(("EMBD.updateSpawnedPosition ok"))
	end		
end

function EMBD.elabLogistic(tblLogCollect)	
	
	--clean tblLogCollect from dead warehouses ships & similar
	for eId, eData in pairs(tblLogCollect) do
		if eData.place then
			local exist = eData.place:isExist()
			if exist == false then
				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.elabLogistic tblLogCollect place data not existing in the mission: missing place"))
				end	
				tblLogCollect[eId] = nil				
			end

		else
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.elabLogistic tblLogCollect place data not existing in the table: missing place"))
			end	
			tblLogCollect[eId] = nil
		end
	end

	if tblLogisticAdds then
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.elabLogistic adding entries from WRHSJ"))
		end	

		for id, data in pairs(tblLogisticAdds) do
			tblLogistic[#tblLogistic+1] = data
		end
	end

	if DSMC_debugProcessDetail == true then
		if DSMC_io and DSMC_lfs then
			dumpTable("tblLogCollect.lua", tblLogCollect)
		end
	end			

	for uId, uData in pairs(tblLogCollect) do
		if uId and uData.action and uData.unit and uData.fuel and uData.ammo and uData.desc and uData.place then
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.elabLogistic valid entry, unitId: " .. tostring(uId)))
			end		


			--## variables conversion: place, ammo & fuel checking		
			local placeId_E 	= "none"
			local placeId_code	= "none"
			local placeName_E 	= "none"
			local placeType_E 	= "none"
			if  uData.place ~= "none" then
				placeId_code	= tonumber(uData.place:getID())
				placeId_E			= "missing"
				placeName_E		= tostring(uData.place:getName())
				
				if uData.place:hasAttribute("Airfields") then
					placeType_E 		= "airports"
					for Anum, Adata in pairs(tblAirbases) do
						if Adata.name == placeName_E then
							placeId_E = Adata.index
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.elabLogistic identified airport id: " .. tostring(placeId_E) .. ", name: " .. tostring(Adata.name)))
							end								
						end
					end		
				else
					placeType_E 	= "warehouses"
					placeId_E		= placeId_code			
				end						
			end

			--fuel
			local fuelKg		= 0
			if uData.fuel ~= "none" then
				fuelKg		= tonumber(uData.fuel)*tonumber(uData.desc.fuelMassMax)
			end			

			--ammo, symplified
			local ammoTbl = {}
			if uData.ammo ~= "none" then
				for aId, aData in pairs(uData.ammo) do
					if aData.desc then
						local wName = aData.desc.typeName 
						local wQty	= aData.count
							
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.elabLogistic departure check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty)))
						end	
						
						for db_id, db_Data in pairs(dbWeapon) do
							if wName == db_Data.unique or wName == db_Data.name then
								ammoTbl[db_Data.unique] = {amount = wQty, wsString = db_Data.wsData}
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.elabLogistic departure wpn added: " .. tostring(wName) .. ", quantity: " .. tostring(wQty)))
								end	
							end
						end
					end
				end
			end

			--aircraft
			local acfType		= uData.desc.typeName

			tblLogistic[#tblLogistic+1] = {action = uData.action, acf = acfType, placeId = placeId_E, placeName = placeName_E, placeType = placeType_E, fuel = fuelKg, ammo = ammoTbl, directammo = nil, directfuel = nil} 			
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.elabLogistic tblLogistic entry added"))
			end			

		end
	end
end

EMBD.collectLogCrates = function()

	if spawnableCrates and upscaleResupplyFactor then

		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.collectLogCrates active, spawnableCrates table available"))
		end		
		--tblLogistic[#tblLogistic+1] = {action = uData.action, acf = acfType, placeId = placeId_E, placeName = placeName_E, placeType = placeType_E, fuel = fuelKg, ammo = ammoTbl, directammo = nil}
		
		for _, aData in pairs(tblAirbases) do

			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.collectLogCrates checking airbase or farp: " .. tostring(aData.name)))
			end	

			local isAB = false
			if aData.desc.category == 0 then
				isAB = true
			end

			if isAB == true then
				local _volume = {
					id = world.VolumeType.SPHERE,
					params = {
						point = aData.pos,
						radius = 5000
					}
				}

				local _searchAB = function(cargo)
					pcall(function()
						if cargo ~= nil then

							if cargo:getLife() > 1 then
								local c_wh = cargo:getCargoWeight()
								local c_type = cargo:getTypeName()
								local c_Id = cargo:getID()
								local c_Coa = cargo:getCoalition()
								local c_Country = cargo:getCountry()
								local c_Pos = cargo:getPosition().p
								local c_Name = cargo:getName()

								local warehouseId = nil
								local w_string_init, w_string_start = string.find(c_Name, "WID")
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.collectLogCrates warehouseId w_string_init: " .. tostring(w_string_init)))
									env.info(("EMBD.collectLogCrates warehouseId w_string_start: " .. tostring(w_string_start)))
								end	

								if w_string_init and w_string_start then
									local w_string = string.sub(c_Name, w_string_start+1)

									if DSMC_debugProcessDetail == true then
										env.info(("EMBD.collectLogCrates warehouseId w_string: " .. tostring(w_string)))
									end	

									if w_string then
										warehouseId = string.match(w_string, "%d+")  -- QUIIIIIIIIIIIIIII
									end
								end

								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.collectLogCrates warehouseId identified: " .. tostring(warehouseId)))
								end	

								local posOnAirbase = false
								if c_Pos then
									local lType = land.getSurfaceType({x = c_Pos.x, y = c_Pos.z})
									if lType == 5 then
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.collectLogCrates found crate, lType: " .. tostring(lType)))
										end		
										posOnAirbase = true
									else
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.collectLogCrates found crate, lType: " .. tostring(lType)))
										end		
									end
								end
								
								if posOnAirbase then
									for C_cat, C_data in pairs(spawnableCrates) do
										if C_cat == "Airlift supplies" then
											for sC_ind, sC_logData in pairs(C_data) do	
												for C_ind, C_logData in pairs(sC_logData) do								
													if C_ind == "Fuel resupplies" or C_ind == "Ammo resupplies" then
														for _, _crData in pairs(C_logData) do
															if _crData.weight == c_wh then
																if DSMC_debugProcessDetail == true then
																	env.info(("EMBD.collectLogCrates found crate, type: " .. tostring(c_type) .. ", weight: " .. tostring(c_wh)  .. ", id: " .. tostring(c_Id) .. ", name: " .. tostring(c_Name)))
																end															

																local ab = Airbase.getByName(aData.name)
																if ab then
																	local ab_type = nil
																	if ab:hasAttribute("Airfields") then
																		ab_type  = "airports"
																	else
																		if DSMC_debugProcessDetail == true then
																			env.info(("EMBD.collectLogCrates ab is not an airport, skip"))
																		end		
																	end

																	if ab_type then											
																		if c_type == "fueltank_cargo" then -- assess fuel
																			local addedTons = (c_wh-60)*upscaleResupplyFactor/1000 -- 60 kilos is the "standard" void crate weight. Obviously assumed.
																			
																			
																			tblLogistic[#tblLogistic+1] = {action = "arrival", acf = "none", placeId = aData.id, placeName = aData.name, placeType = ab_type, fuel = 0, ammo = {}, directammo = nil, directfuel = addedTons}
																			if warehouseId then
																				if DSMC_debugProcessDetail == true then
																					env.info(("EMBD.collectLogCrates removing amount from wh id: " .. tostring(warehouseId)))
																				end	
																				tblLogistic[#tblLogistic+1] = {action = "departure", acf = "none", placeId = warehouseId, placeName = "none", placeType = "warehouses", fuel = 0, ammo = {}, directammo = nil, directfuel = -addedTons}
																			end

																			-- remove if spawned
																			local spawned = false
																			for sId, sData in pairs(tblSpawned) do
																				for _, suData in pairs(sData.gUnits) do 																			
																					if tostring(c_Id) == tostring(suData.uID) or c_Name == suData.uName then
																						
																						tblSpawned[sId] = nil
																						spawned = true
																						if DSMC_debugProcessDetail == true then
																							env.info(("EMBD.collectLogCrates removed from spawned list"))
																						end	
																					end
																				end
																			end

																			-- remove if ME
																			--if spawned == false then
																				tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(c_Id), coalitionID = c_Coa, countryID = c_Country, staticTable = nil, objCategory = 6, objTypeName = c_type}
																				if DSMC_debugProcessDetail == true then
																					env.info(("EMBD.collectLogCrates removed from mission editor existing cargo"))
																				end	
																			--end
																		elseif c_type == "ammo_cargo" then -- assess ammo
																			if _crData.dirAmmo then
																				local addedTons = 0 

																				tblLogistic[#tblLogistic+1] = {action = "arrival", acf = "none", placeId = aData.id, placeName = aData.name, placeType = ab_type, fuel = addedTons, ammo = {}, directammo = _crData.dirAmmo, dirQty = _crData.dirAmmoQty, directfuel = nil}
																				if warehouseId then
																					if DSMC_debugProcessDetail == true then
																						env.info(("EMBD.collectLogCrates removing amount from wh id: " .. tostring(warehouseId)))
																					end	
																					tblLogistic[#tblLogistic+1] = {action = "departure", acf = "none", placeId = warehouseId, placeName = "none", placeType = "warehouses", fuel = addedTons, ammo = {}, directammo = _crData.dirAmmo, dirQty = -_crData.dirAmmoQty, directfuel = nil}
																				end

																				-- remove if spawned
																				local spawned = false
																				for sId, sData in pairs(tblSpawned) do
																					for _, suData in pairs(sData.gUnits) do 
																						if tostring(c_Id) == tostring(suData.uID) or c_Name == suData.uName then
																							
																							tblSpawned[sId] = nil
																							spawned = true
																							if DSMC_debugProcessDetail == true then
																								env.info(("EMBD.collectLogCrates removed from spawned list"))
																							end	
																						end
																					end
																				end

																				-- remove if ME
																				--if spawned == false then
																				tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(c_Id), coalitionID = c_Coa, countryID = c_Country, staticTable = nil, objCategory = 6, objTypeName = c_type}
																				if DSMC_debugProcessDetail == true then
																					env.info(("EMBD.collectLogCrates removed from mission editor existing cargo"))
																				end	
																			else
																				if DSMC_debugProcessDetail == true then
																					env.info(("EMBD.collectLogCrates ammo class not available"))
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
								else
									if DSMC_debugProcessDetail == true then
										env.info(("EMBD.collectLogCrates : Crates is not over a paved area"))
									end	
								end
							end	

						end
					end)
					return true
				end      
				world.searchObjects(Object.Category.CARGO, _volume, _searchAB)	

			else
				local _volume = {
					id = world.VolumeType.SPHERE,
					params = {
						point = aData.pos,
						radius = 200
					}
				}

				local _search = function(cargo)
					pcall(function()
						if cargo ~= nil then
							if cargo:getLife() > 1 then
								local c_wh = cargo:getCargoWeight()
								local c_type = cargo:getTypeName()
								local c_Id = cargo:getID()
								local c_Coa = cargo:getCoalition()
								local c_Country = cargo:getCountry()
								local c_Name = cargo:getName()

								local warehouseId = nil
								local w_string_init, w_string_start = string.find(c_Name, "WID")
								if w_string_init and w_string_start then
									local w_string = string.sub(c_Name, w_string_start+1)
									if w_string then
										warehouseId = string.match(w_string, "%d+")
									end
								end

								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.collectLogCrates warehouseId identified: " .. tostring(warehouseId)))
								end	
								
								for C_cat, C_data in pairs(spawnableCrates) do
									if C_cat == "Airlift supplies" then
										for sC_ind, sC_logData in pairs(C_data) do	
											for C_ind, C_logData in pairs(sC_logData) do
												if C_ind == "Fuel resupplies" or C_ind == "Ammo resupplies" then
													for _, _crData in pairs(C_logData) do
														if _crData.weight == c_wh then
															if DSMC_debugProcessDetail == true then
																env.info(("EMBD.collectLogCrates found crate, type: " .. tostring(c_type) .. ", weight: " .. tostring(c_wh)  .. ", id: " .. tostring(c_Id) .. ", name: " .. tostring(c_Name)))
															end															
															
															if c_type == "fueltank_cargo" then -- assess fuel
																local addedTons = (c_wh-60)*upscaleResupplyFactor/1000 -- 60 kilos is the "standard" void crate weight. Obviously assumed.
																local ab_type = "warehouses"
																local ab = Airbase.getByName(aData.name)
																if ab then
																	if ab:hasAttribute("Airfields") then
																		ab_type  = "airports"
																	end

																	if ab_type == "warehouses" then

																		tblLogistic[#tblLogistic+1] = {action = "arrival", acf = "none", placeId = aData.id, placeName = aData.name, placeType = ab_type, fuel = 0, ammo = {}, directammo = nil, directfuel = addedTons}
																		if warehouseId then
																			if DSMC_debugProcessDetail == true then
																				env.info(("EMBD.collectLogCrates removing amount from wh id: " .. tostring(warehouseId)))
																			end	
																			tblLogistic[#tblLogistic+1] = {action = "departure", acf = "none", placeId = warehouseId, placeName = "none", placeType = "warehouses", fuel = 0, ammo = {}, directammo = nil, directfuel = -addedTons}
																		end

																		-- remove if spawned
																		local spawned = false
																		for sId, sData in pairs(tblSpawned) do
																			for _, suData in pairs(sData.gUnits) do 
																				if tostring(c_Id) == tostring(suData.uID) or c_Name == suData.uName then
																					
																					tblSpawned[sId] = nil
																					spawned = true
																					if DSMC_debugProcessDetail == true then
																						env.info(("EMBD.collectLogCrates removed from spawned list"))
																					end	
																				end
																			end
																		end

																		tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(c_Id), coalitionID = c_Coa, countryID = c_Country, staticTable = nil, objCategory = 6, objTypeName = c_type}
																		if DSMC_debugProcessDetail == true then
																			env.info(("EMBD.collectLogCrates removed from mission editor existing cargo"))
																		end	
																	end
																end
															elseif c_type == "ammo_cargo" then -- assess ammo
																if _crData.dirAmmo then
																	local addedTons = 0 
																	local ab_type = "warehouses"
																	local ab = Airbase.getByName(aData.name)
																	if ab then
																		if ab:hasAttribute("Airfields") then
																			ab_type  = "airports"
																		end

																		if ab_type == "warehouses" then

																			tblLogistic[#tblLogistic+1] = {action = "arrival", acf = "none", placeId = aData.id, placeName = aData.name, placeType = ab_type, fuel = addedTons, ammo = {}, directammo = _crData.dirAmmo, dirQty = _crData.dirAmmoQty, directfuel = nil}
																			if warehouseId then
																				if DSMC_debugProcessDetail == true then
																					env.info(("EMBD.collectLogCrates removing amount from wh id: " .. tostring(warehouseId)))
																				end	
																				tblLogistic[#tblLogistic+1] = {action = "departure", acf = "none", placeId = warehouseId, placeName = "none", placeType = "warehouses", fuel = addedTons, ammo = {}, directammo = _crData.dirAmmo, dirQty = -_crData.dirAmmoQty, directfuel = nil}
																			end
																			-- remove if spawned
																			local spawned = false
																			for sId, sData in pairs(tblSpawned) do
																				for _, suData in pairs(sData.gUnits) do 
																					if tostring(c_Id) == tostring(suData.uID) or c_Name == suData.uName then
																						
																						tblSpawned[sId] = nil
																						spawned = true
																						if DSMC_debugProcessDetail == true then
																							env.info(("EMBD.collectLogCrates removed from spawned list"))
																						end	
																					end
																				end
																			end

																			tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(c_Id), coalitionID = c_Coa, countryID = c_Country, staticTable = nil, objCategory = 6, objTypeName = c_type}
																			if DSMC_debugProcessDetail == true then
																				env.info(("EMBD.collectLogCrates removed from mission editor existing cargo"))
																			end	
																		end

																	end
																else
																	if DSMC_debugProcessDetail == true then
																		env.info(("EMBD.collectLogCrates ammo class not available"))
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
					end)
					return true
				end      
				world.searchObjects(Object.Category.CARGO, _volume, _search)	
			end 
		
		end
	end

end

EMBD.oncallworkflow = function(sanivar, recall)
	env.info(("EMBD.oncallworkflow sanivar: " .. tostring(sanivar) .. ", recall: " .. tostring(recall)))
	DSMC_allowStop = false
	if sanivar == "desanitized" then
		env.info(("EMBD.oncallworkflow (desan) saveProcess start"))
		--not used now
		local msg_duration = 0.05
		local prt_stack = 0.5
		cur_Stack = 0.5 -- start point

		tblLogistic	= {}
		EMBD.getAptInfo()
		EMBD.collectLogCrates()
		EMBD.sendUnitsData(env.mission)
		EMBD.changeWarehouseCoalition(env.mission)
		EMBD.updateSpawnedPosition(tblSpawned, env.mission)
		EMBD.elabLogistic(tblLogCollect)
		
		
		local function funcAirbases()
			EMBD.saveTable("tblAirbases", tblAirbases)
			--env.info(("EMBD.oncallworkflow (desan) saved tblAirbases"))
		end

		local function funcDeadUnits()
			EMBD.saveTable("tblDeadUnits", tblDeadUnits)
			--env.info(("EMBD.oncallworkflow (desan) saved tblDeadUnits"))
		end

		local function funcDeadScenObj()
			EMBD.saveTable("tblDeadScenObj", tblDeadScenObj)
			--env.info(("EMBD.oncallworkflow (desan) saved tblDeadScenObj"))
		end

		local function funcUnitsUpdate()
			EMBD.saveTable("tblUnitsUpdate", tblUnitsUpdate)
			--env.info(("EMBD.oncallworkflow (desan) saved tblUnitsUpdate"))
		end	

		local function funcLogistic()
			EMBD.saveTable("tblLogistic", tblLogistic)
			--env.info(("EMBD.oncallworkflow (desan) saved tblLogistic"))
		end

		local function funcSpawned()
			EMBD.saveTable("tblSpawned", tblSpawned)
			--env.info(("EMBD.oncallworkflow (desan) saved tblSpawned"))
		end

		local function funcConquer()
			EMBD.saveTable("tblConquer", tblConquer)
			--env.info(("EMBD.oncallworkflow (desan) saved tblConquer"))
		end			
		
		local function funcStaticChange()
			EMBD.saveTable("tblWarehouseChangeCoa", tblWarehouseChangeCoa)
			--env.info(("EMBD.oncallworkflow (desan) saved tblWarehouseChangeCoa"))
		end		

		local function saveProcess()
			trigger.action.outText("DSMC save...", 10)
			--env.info(("EMBD.oncallworkflow called saveProcess function"))
		end			

		--local function updateTablesOutsideSSE()
		--	trigger.action.outText("DSMC update tables...", msg_duration)
			--env.info(("EMBD.oncallworkflow called saveProcess function"))
		--end			
		
		timer.scheduleFunction(funcAirbases, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack
		timer.scheduleFunction(funcDeadUnits, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack
		timer.scheduleFunction(funcDeadScenObj, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack
		timer.scheduleFunction(funcUnitsUpdate, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack
		timer.scheduleFunction(funcLogistic, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack
		timer.scheduleFunction(funcSpawned, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack
		timer.scheduleFunction(funcConquer, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack	
		timer.scheduleFunction(funcStaticChange, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + prt_stack	
		--timer.scheduleFunction(funcLand, {}, timer.getTime() + cur_Stack)
		--cur_Stack = cur_Stack + prt_stack			
		if recall == "recall" then
			timer.scheduleFunction(saveProcess, {}, timer.getTime() + cur_Stack)
		end
		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.oncallworkflow (desan) scheduled files saving"))
		end	

		cur_Stack = 0.5	
	else
		env.info(("EMBD.oncallworkflow saveProcess standard start"))
		local msg_duration = 0.05
		local msg_Stack = 0.5
		cur_Stack = 0.5 -- start point

		tblLogistic	= {}
		EMBD.getAptInfo()
		EMBD.collectLogCrates()
		EMBD.sendUnitsData(env.mission)
		EMBD.changeWarehouseCoalition(env.mission)
		EMBD.updateSpawnedPosition(tblSpawned, env.mission)
		EMBD.elabLogistic(tblLogCollect)
		
		strAirbases						= ""
		completeStringstrAirbases		= ""
		strDeadUnits					= ""
		completeStringstrDeadUnits		= ""
		strDeadScenObj					= ""
		completeStringstrUnitsUpdate	= ""
		strLogistic						= ""
		completeStringstrLogistic		= ""
		strSpawned						= ""
		completeStringstrSpawned		= ""
		strConquer						= ""
		completeStringstrConquer		= ""		
		strinlogisticUnits				= ""
		completeStringstrlogisticUnits	= ""
		strLandPosition					= ""
		completeStringstrLandPosition	= ""
		strChngStatic					= ""
		completeStringstrChngStatic		= ""
		
		strAirbases = IntegratedserializeWithCycles("tblAirbases", tblAirbases)
		completeStringstrAirbases = tostring(strAirbases)
		local function funcAirbases()
			trigger.action.outText(completeStringstrAirbases, msg_duration)
			env.info(("EMBD.oncallworkflow standard saved tblAirbases"))
		end
		
		strDeadUnits = IntegratedserializeWithCycles("tblDeadUnits", tblDeadUnits)
		completeStringstrDeadUnits = tostring(strDeadUnits)
		local function funcDeadUnits()
			trigger.action.outText(completeStringstrDeadUnits, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblDeadUnits"))
		end
		
		strDeadScenObj = IntegratedserializeWithCycles("tblDeadScenObj", tblDeadScenObj)
		local completeStringstrDeadScenObj = tostring(strDeadScenObj)
		local function funcDeadScenObj()
			trigger.action.outText(completeStringstrDeadScenObj, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblDeadScenObj"))
		end
		
		local strUnitsUpdate = IntegratedserializeWithCycles("tblUnitsUpdate", tblUnitsUpdate)
		completeStringstrUnitsUpdate = tostring(strUnitsUpdate)
		local function funcUnitsUpdate()
			trigger.action.outText(completeStringstrUnitsUpdate, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblUnitsUpdate"))
		end	
		
		local strLogistic = IntegratedserializeWithCycles("tblLogistic", tblLogistic)
		completeStringstrLogistic = tostring(strLogistic)
		local function funcLogistic()
			trigger.action.outText(completeStringstrLogistic, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblLogistic"))
		end

		local strSpawned = IntegratedserializeWithCycles("tblSpawned", tblSpawned)
		completeStringstrSpawned = tostring(strSpawned)
		local function funcSpawned()
			trigger.action.outText(completeStringstrSpawned, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblSpawned"))
		end
		
		local strConquer = IntegratedserializeWithCycles("tblConquer", tblConquer)
		completeStringstrChngStatic = tostring(strConquer)
		local function funcConquer()
			trigger.action.outText(completeStringstrChngStatic, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblConquer"))
		end	
		
		local strChngStatic = IntegratedserializeWithCycles("tblWarehouseChangeCoa", tblWarehouseChangeCoa)
		completeStringstrConquer = tostring(strChngStatic)
		local function funcStaticChange()
			trigger.action.outText(completeStringstrConquer, msg_duration)
			--env.info(("EMBD.oncallworkflow standard saved tblWarehouseChangeCoa"))
		end	
		
		local function saveProcess()			
			trigger.action.outText("DSMC save...", msg_duration)
			--env.info(("EMBD.oncallworkflow called saveProcess function"))
		end	

		timer.scheduleFunction(funcAirbases, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack
		timer.scheduleFunction(funcDeadUnits, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack
		timer.scheduleFunction(funcDeadScenObj, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack
		timer.scheduleFunction(funcUnitsUpdate, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack
		timer.scheduleFunction(funcLogistic, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack
		timer.scheduleFunction(funcSpawned, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack
		timer.scheduleFunction(funcConquer, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack		
		timer.scheduleFunction(funcStaticChange, {}, timer.getTime() + cur_Stack)
		cur_Stack = cur_Stack + msg_Stack	

		if recall == "recall" then
			timer.scheduleFunction(saveProcess, {}, timer.getTime() + cur_Stack)
		end
		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.oncallworkflow scheduled strings printing"))
		end	

		cur_Stack = 0.5
	end
	env.info(("EMBD.oncallworkflow saveProcess finished"))
end

EMBD.preSaveCallback = nil
-- original save method, renamed and called from the timer below
EMBD.executeSAVEFunction = function(recall)
	env.info(("EMBD.executeSAVEFunction launched. recall = " .. tostring(recall)))
  
	if DSMC_ServerMode == true then
	  env.info(("EMBD.executeSAVE is in dedicated server mode"))
	  if DSMC_lfs and DSMC_io then
		EMBD.oncallworkflow("desanitized", recall)
	  else
		EMBD.runDesanMessage()
	  end
	else
	  env.info(("EMBD.executeSAVE is in standard mode"))
	  if DSMC_lfs and DSMC_io then
		EMBD.oncallworkflow("desanitized", recall)
	  else
		EMBD.oncallworkflow("sanitized", recall)
	  end  
	end
	--dumpTable("wh_after.lua", env.warehouses)
end

  -- new entry to make the callback detached and allow DSMC to process any mission changes.
EMBD.executeSAVE = function(recall)
	env.info(("EMBD.executeSAVE launched. recall = " .. tostring(recall)))
  
	if EMBD.preSaveCallback ~= nil then
	  EMBD.preSaveCallback()
	end
  
	timer.scheduleFunction(EMBD.executeSAVEFunction, recall, timer.getTime() + 0.1)
end

EMBD.runDesanMessage = function()
	local function Desanmessage()
		trigger.action.outText("DSMC can't work as required!, you need to desanitize the server or change your options. Check manual!", 10)
		env.info(("DSMC can't work as required!, you need to desanitize the server or change your options. Check manual!"))
	end
	timer.scheduleFunction(Desanmessage, {}, timer.getTime() + 60)
end


--### EVENT HANDLERS

EMBD.deathRecorder = {}
function EMBD.deathRecorder:onEvent(event)

	if event.id == world.event.S_EVENT_DEAD or event.id ==  world.event.S_EVENT_CRASH then --world.event.S_EVENT_DEAD
		if event.initiator then
			local SOcategory 	= event.initiator:getCategory()
			local SOpos 		= event.initiator:getPosition().p
			local SOtypeName	= event.initiator:getTypeName()	
			env.info(("EMBD.deathRecorder death event "))

			if SOcategory and SOpos and SOtypeName then
				if type(SOcategory) == "number" and type(SOpos) == "table" and type(SOtypeName) == "string" then
				
					if SOcategory == 5 then -- map object
					
						mapObj_deathcounter = mapObj_deathcounter + 1
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.deathRecorder death event category 5, map object"))		
						end		
						
						local exist = false
						for _, deadData in pairs(tblDeadScenObj) do 
							if tostring(deadData.objId) == tostring(event.initiator:getName()) then
								env.info(("EMBD.deathRecorder death event category 5, skipped cause already there"))
								exist = true
							end
						end
						if exist == false then
							local Objdesc = event.initiator:getDesc()
							if Objdesc.life > 1 then

								local y = env.mission.date.Year
								local m = env.mission.date.Month
								local d = env.mission.date.Day

								local dayValue = nil

								if y and m and d then
									if type(y) == "number" and type(m) == "number" and type(d) == "number" then 
										dayValue = y*365+m*30+d -- (can't use os.time and os.date cause I can't be sure to have os available!)	
									end
								end

								tblDeadScenObj[#tblDeadScenObj + 1] = {id = mapObj_deathcounter, x = SOpos.x, y = SOpos.z, objId = event.initiator:getName(), SOdesc = Objdesc, deathDay = dayValue} 
							end
						end


					elseif SOcategory == 3 then 
						local ObjdescCat = event.initiator:getDesc().category
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.deathRecorder death event category 3, static object"))	
							env.info(("EMBD.deathRecorder Objdesc: " .. tostring(ObjdescCat)))
							env.info(("EMBD.deathRecorder SOtypeName: " .. tostring(SOtypeName)))


						end							
						
						local y = env.mission.date.Year
						local m = env.mission.date.Month
						local d = env.mission.date.Day

						local dayValue = nil

						if y and m and d then
							if type(y) == "number" and type(m) == "number" and type(d) == "number" then 
								dayValue = y*365+m*30+d -- (can't use os.time and os.date cause I can't be sure to have os available!)	
							end
						end

						tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(event.initiator:getID()), objCategory = 3, deathDay = dayValue}		
						

						--[[--
						env.info(("EMBD.deathRecorder object added to dead units"))

						if ObjdescCat == 0 or ObjdescCat == 1 then
							if SOpos then
								env.info(("EMBD.deathRecorder define helo or plane to be removed"))	

								local UNITID		= event.initiator:getID()	
								local UNITAMMO		= {}
								local UNITFUEL		= 0
								local UNITDESC		= event.initiator:getDesc()
								--local placeName		= event.place:getName()
								local UNITPLACE		= nil

								local getLandType = land.getSurfaceType({x = SOpos.x, y = SOpos.z})
								env.info(("EMBD.deathRecorder getLandType: " .. tostring(getLandType)))
								if getLandType == 5 then
									
									local _volume = {
										id = world.VolumeType.SPHERE,
										params = {
											point = SOpos,
											radius = 5000
										}
									}
									
									local distance_func = function(point1, point2)
										local xUnit = point1.x
										local yUnit = point1.z
										local xZone = point2.x
										local yZone = point2.z
										local xDiff = xUnit - xZone
										local yDiff = yUnit - yZone
										return math.sqrt(xDiff * xDiff + yDiff * yDiff)
									end

									local _nearest = nil
									local _nearDist = 5000
									local _search = function(_obj)
										pcall(function()
											if _obj ~= nil then
												env.info(("EMBD.deathRecorder checking base"))
												local n = _obj:getName()
												env.info(("EMBD.deathRecorder n: " .. tostring(n)))
												local a = Airbase.getByName(n)
												env.info(("EMBD.deathRecorder base found"))
												local pos = a:getPosition().p
												env.info(("EMBD.deathRecorder pos defined"))
												if pos then
													local d = distance_func(pos, SOpos)
													env.info(("EMBD.deathRecorder d: " .. tostring(d)))
													if d <= _nearDist then
														_nearDist = d
														_nearest = a
														env.info(("EMBD.deathRecorder found near base"))
													end
												end
											end
										end)
									end       
									
									world.searchObjects(Object.Category.BASE, _volume, _search)
					
									if _nearest then
										UNITPLACE = _nearest
										env.info(("EMBD.deathRecorder found ab: " .. tostring(UNITPLACE:getName())))
									end

									if UNITID and UNITPLACE and UNITDESC then
										tblLogCollect[#tblLogCollect+1] = {action = "departure", unitId = UNITID, unit = event.initiator, ammo = UNITAMMO, place = UNITPLACE, fuel = UNITFUEL, desc = UNITDESC, hits = 0} 
							
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.deathRecorder adding logistic removal from: " .. tostring(UNITPLACE:getName()) .. ", object: " ..tostring(SOtypeName)       ))
											--trigger.action.outText("EMBD.LogisticLoad ha registrato un decollo, unità: " .. tostring(UNITID), 10)
										end
									end

								end
							end
						end
						--]]--

					elseif SOcategory == 1 then -- unit. Cargos, Bases and Weapons are left out 
					
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.deathRecorder death event di category 1, unit"))	
						end	

						local y = env.mission.date.Year
						local m = env.mission.date.Month
						local d = env.mission.date.Day

						local dayValue = nil

						if y and m and d then
							if type(y) == "number" and type(m) == "number" and type(d) == "number" then 
								dayValue = y*365+m*30+d -- (can't use os.time and os.date cause I can't be sure to have os available!)
							end
						end
					
						--dead
						local unitName		 	= nil
						local unitTable			= nil
						local unitPos			= nil
						local unitCategory		= nil
						local unitCoalition		= nil
						local unitCountry		= nil
						local unitTypeName		= nil
						local unitID			= nil
						
						local groupTable 	= {}
						if event.initiator then
							unitName 			= event.initiator:getName()
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.deathRecorder dead unit name: " .. tostring(unitName)))	
							end					
							unitTable 			= event.initiator -- Unit.getByName(unitName)
							if unitTable then
								unitPos 		= SOpos
								unitCategory 	= unitTable:getDesc().category
								unitCatEnum		= SOcategory
								unitCoalition 	= unitTable:getCoalition()
								unitCountry 	= unitTable:getCountry()
								unitTypeName	= SOtypeName
								unitID			= event.initiator:getID()
								unitInfantry	= event.initiator:hasAttribute("Infantry")
								unitShip		= event.initiator:hasAttribute("Ships")
							end
						end			
						
						if unitName and unitTable and unitCategory and unitCategory ~= 3 and unitInfantry == false and unitShip == false then
						
							local HiddenSet = true		
							
							local correctCategory = nil
							if unitCategory == 0 then
								correctCategory = "Planes"
							elseif unitCategory == 1 then
								correctCategory = "Helicopters"				
							elseif unitCategory == 2 then
								correctCategory = "Unarmed"
							elseif unitCategory == 4 then
								correctCategory = "Fortifications"				
							end
							
							local surface = land.getSurfaceType({x = unitPos.x, y = unitPos.z})

							local groupTable = nil
							if surface == 1 or surface == 2 or surface == 3 then
								DSMC_baseUcounter = DSMC_baseUcounter + 1
								DSMC_baseGcounter = DSMC_baseGcounter + 1
								groupTable = 	{
													["heading"] = 0,
													["route"] = 
													{
														["points"] = 
														{
															[1] = 
															{
																["alt"] = unitPos.y,
																["type"] = "",
																["name"] = "",
																["y"] = unitPos.z,
																["speed"] = 0,
																["x"] = unitPos.x,
																["formation_template"] = "",
																["action"] = "",
															}, -- end of [1]
														}, -- end of ["points"]
													}, -- end of ["route"]
													["groupId"] = DSMC_baseGcounter,
													["hidden"] = true,
													["units"] = 
													{
														[1] = 
														{
															["type"] = unitTypeName,
															["unitId"] = DSMC_baseUcounter,
															["livery_id"] = "autumn",
															["rate"] = 20,
															["y"] = unitPos.z,
															["x"] = unitPos.x,
															["name"] = "DSMC_CreatedStatic_unit_" .. tostring(DSMC_baseUcounter),
															["category"] = correctCategory,
															["canCargo"] = false,
															["heading"] = 0,
														}, -- end of [1]
													}, -- end of ["units"]
													["y"] = unitPos.z,
													["x"] = unitPos.x,
													["name"] = unitName .. "_dsmc_dd_" .. tostring(dayValue),
													["dead"] = true,
												} -- end of [1]			
							else
								groupTable = "none"
							end	
						
							tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unitID), coalitionID = unitCoalition, countryID = unitCountry, staticTable = groupTable, objCategory = unitCatEnum, objTypeName = unitTypeName, deathDay = dayValue}
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.deathRecorder added unit"))	
							end	
						elseif unitShip == true then
							tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unitID), unitShip = true}
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.deathRecorder added ship"))	
							end	
						elseif unitInfantry == true then
							tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unitID), unitInfantry = true}
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.deathRecorder added infantry"))	
							end					
						end
					else
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.deathRecorder no object found, skip"))	
						end	
					end
				else
					if DSMC_debugProcessDetail == true then
						env.info(("EMBD.deathRecorder skip: SO variable type is wrong!"))	
					end	
				end
			else
				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.deathRecorder skip: missing SO variables"))	
				end	
			end

		end
	end	
end
world.addEventHandler(EMBD.deathRecorder)

local takeofflandLocker = {}

EMBD.LogisticUnload = {}
function EMBD.LogisticUnload:onEvent(event)	

	if event.id == world.event.S_EVENT_LAND and dbWeapon then -- 18	
		env.info(("EMBD.LogisticUnload land event identified"))	
		local unit 			= event.initiator
		local ab			= event.place	
		if unit and ab then

			local baseName		= ab:getName()
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.LogisticUnload registered, string: " .. tostring(baseName)))	
			end

			if unit:inAir() == false and unit:getLife() > 1 then
				
				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.LogisticUnload land registered"))
					--trigger.action.outText("EMBD.LogisticUnload shutdown registered", 10)
				end

				local abType		= "airports"
				if ab:hasAttribute("Helipad") then
					abType  = "warehouses"
				end

				local UNITID		= unit:getID()	
				local UNITAMMO		= unit:getAmmo()
				local UNITFUEL		= unit:getFuel()
				local UNITDESC		= unit:getDesc()

				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.LogisticUnload unit: " .. tostring(UNITID) .. ", base: " .. tostring(ab) .. ", baseName: " .. tostring(baseName) .. "\n"))
				end

				local continue = true
				for _, tlData in pairs(takeofflandLocker) do
					if tlData.unitId == UNITID and tlData.action == "arrival" then
						if (timer.getTime()- tlData.time) < 30 then
							continue = false
						end
					end
				end				
				
				if continue == true then
					if not UNITAMMO then
						UNITAMMO		= "none"
					end
					if not UNITFUEL then
						UNITFUEL		= "none"
					end	

					if UNITID and UNITFUEL and UNITAMMO and UNITDESC and ab then
						tblLogCollect[#tblLogCollect+1] = {action = "arrival", unitId = UNITID, unit = unit, desc = UNITDESC, hits = 0, place = ab, ammo = UNITAMMO, fuel = UNITFUEL}
						takeofflandLocker[#takeofflandLocker+1] = {unitId = UNITID, action = "arrival", time = timer.getTime()}
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.LogisticUnload ha registrato un atterraggio, unità: " .. tostring(UNITID)))
							--trigger.action.outText("DSMC debug: EMBD.LogisticUnload ha registrato un atterraggio, unità: " .. tostring(UNITID), 10)
						end

					end
				end
			end
		else
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.LogisticUnload no unit or ab!"))
			end
		end
	end
end
world.addEventHandler(EMBD.LogisticUnload)		

EMBD.LogisticLoad = {} 
function EMBD.LogisticLoad:onEvent(event)		
	if event.id == world.event.S_EVENT_TAKEOFF and dbWeapon then -- 3
		env.info(("EMBD.LogisticLoad takeoff event identified"))							
		local UNIT 				= event.initiator
		if UNIT and event.place then

			local UNITID		= UNIT:getID()	
			local UNITAMMO		= UNIT:getAmmo()
			local UNITFUEL		= UNIT:getFuel()
			local UNITDESC		= UNIT:getDesc()
			local placeName		= event.place:getName()
			local UNITPLACE		= Airbase.getByName(placeName)
			
			
			if not UNITAMMO then
				UNITAMMO = {}
			end
			
			if UNITID and UNITAMMO and UNITFUEL and UNITDESC and UNITPLACE then
				local continue = true
				for _, tlData in pairs(takeofflandLocker) do
					if tlData.unitId == UNITID and tlData.action == "departure" then
						if (timer.getTime()- tlData.time) < 30 then
							continue = false
						end
					end
				end
				
				if continue == true then
					tblLogCollect[#tblLogCollect+1] = {action = "departure", unitId = UNITID, unit = UNIT, ammo = UNITAMMO, place = UNITPLACE, fuel = UNITFUEL, desc = UNITDESC, hits = 0} 
					takeofflandLocker[#takeofflandLocker+1] = {unitId = UNITID, action = "departure", time = timer.getTime()}
					if DSMC_debugProcessDetail == true then
						env.info(("EMBD.LogisticLoad departure recorded: " .. tostring(UNITID)))
						--trigger.action.outText("EMBD.LogisticLoad ha registrato un decollo, unità: " .. tostring(UNITID), 10)
					end
				end
			else
				env.info(("EMBD.LogisticLoad can't record departure event: " .. tostring(UNITID) .. "" .. tostring(UNITAMMO) .. "" .. tostring(UNITFUEL) .. "" .. tostring(UNITDESC) .. "" .. tostring(placeName)))
			end
		end
	--[[ not working cause no event, dead, crash, kill or lost is triggered with a object destruction by fire	
	elseif event.id == world.event.S_EVENT_DEAD then -- try to add planes killed on taxi, runway or uncontrolled
		if event.initiator then

			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.LogisticLoad unit lost event detected" ))	
			end

			local SOcategory 	= event.initiator:getCategory()
			local SOpos 		= event.initiator:getPosition().p
			local SOtypeName	= event.initiator:getTypeName()	

			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.LogisticLoad death event SOcategory..." .. tostring(SOcategory) ))	
				env.info(("EMBD.LogisticLoad death event SOtypeName..." .. tostring(SOtypeName) ))	
			end

			if SOcategory and SOpos and SOtypeName then
				if type(SOcategory) == "number" and type(SOpos) == "table" and type(SOtypeName) == "string" then		
					if SOcategory == 1 then
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.LogisticLoad death event checking..." .. tostring(SOtypeName) ))	
						end
						local ObjectinAir		= event.initiator:inAir()
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.LogisticLoad ObjectinAir: " .. tostring(ObjectinAir)))
						end
						if ObjectinAir == false then -- the aircraft is still on ground
							if SOpos then
								local isRunway = land.getSurfaceType({x = SOpos.x, y = SOpos.z})
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.LogisticLoad isRunway: " .. tostring(isRunway)))
								end

								if isRunway == 5 then
									
									-- find the airbase
									local distance_func = function(point1, point2)
										local xUnit = point1.x
										local yUnit = point1.z
										local xZone = point2.x
										local yZone = point2.z
										local xDiff = xUnit - xZone
										local yDiff = yUnit - yZone
										return math.sqrt(xDiff * xDiff + yDiff * yDiff)
									end
									local ab = nil
									local dist = 30000 -- meters

									for abId, abData in pairs(tblAirbases) do
										if abData.pos then
											local d = distance_func(abData.pos, SOpos)
											if d < dist then
												dist = d									
												ab = abData.name
											end
										end
									end

									local UNIT = event.initiator

									if DSMC_debugProcessDetail == true then
										env.info(("EMBD.LogisticLoad ab: " .. tostring(ab)))
									end

									if UNIT and ab then

										local UNITID		= UNIT:getID()	
										local UNITAMMO		= UNIT:getAmmo()
										local UNITFUEL		= UNIT:getFuel()
										local UNITDESC		= UNIT:getDesc()
										local placeName		= ab
										local UNITPLACE		= Airbase.getByName(placeName)

										if not UNITAMMO then
											UNITAMMO = {}
										end
										
										if UNITID and UNITAMMO and UNITFUEL and UNITDESC and UNITPLACE then
											local UNITCAT 		= UNITDESC.category

											if DSMC_debugProcessDetail == true then
												env.info(("EMBD.LogisticLoad UNITCAT: " .. tostring(UNITCAT)))
											end

											if UNITCAT == 0 or UNITCAT == 1 then

												tblLogCollect[#tblLogCollect+1] = {action = "departure", unitId = UNITID, unit = UNIT, ammo = UNITAMMO, place = UNITPLACE, fuel = UNITFUEL, desc = UNITDESC, hits = 0} 
												takeofflandLocker[#takeofflandLocker+1] = {unitId = UNITID, action = "departure", time = timer.getTime()}
												if DSMC_debugProcessDetail == true then
													env.info(("EMBD.LogisticLoad dead on airbase recorded: " .. tostring(UNITID)))
													--trigger.action.outText("EMBD.LogisticLoad ha registrato un decollo, unità: " .. tostring(UNITID), 10)
												end
											end

										else
											env.info(("EMBD.LogisticLoad can't record dead on airbase event: " .. tostring(UNITID) .. "" .. tostring(UNITAMMO) .. "" .. tostring(UNITFUEL) .. "" .. tostring(UNITDESC) .. "" .. tostring(placeName)))
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
end
world.addEventHandler(EMBD.LogisticLoad)	

EMBD.systemFail = {}
function EMBD.systemFail:onEvent(event)	
	if event.id == world.event.S_EVENT_HUMAN_FAILURE then --world.event.S_EVENT_HUMAN_FAILURE		
		local unit 			= event.initiator
		local unitTypeName	= event.initiator:getTypeName()
		local unitCoalition	= event.initiator:getCoalition()

		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.systemFail ha registrato un danneggiamento, unità: " .. tostring(unitId)))
			--trigger.action.outText("EMBD.LogisticTOrecord ha registrato un decollo, unità: " .. tostring(unitId), 10)
		end
	end
end
world.addEventHandler(EMBD.systemFail)

EMBD.assetHit = {}
function EMBD.assetHit:onEvent(event)	
	if event.id == world.event.S_EVENT_HIT then --world.event.S_EVENT_HIT		
		local unit 			= event.target
		if unit then
			local unitCategory	= unit:getCategory()
			local unitTypeName	= unit:getTypeName()		
			if DSMC_debugProcessDetail == true then
				--env.info(("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", category: " .. tostring(unitCategory)))
				--trigger.action.outText("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", category: " .. tostring(unitCategory), 10)
			end			
			
			if unitCategory == 1 then
				local unitId		= unit:getID()
				local unitair  	= unit:hasAttribute("Air")
				if unitair == true then
					for uid, udata in pairs(tblLogCollect) do
						if unitId == uid then
							udata.hits = udata.hits + 1
							if DSMC_debugProcessDetail == true then
								--env.info(("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", colpi totali: " .. tostring(udata.hits)))
								--trigger.action.outText("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", colpi totali: " .. tostring(udata.hits), 10)
							end			
						end
					end			
				end
			end
		end
	end
end
world.addEventHandler(EMBD.assetHit)	

EMBD.baseCapture = {}
function EMBD.baseCapture:onEvent(event)	
	if event.id == world.event.S_EVENT_BASE_CAPTURED then --world.event.S_EVENT_HIT		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.baseCapture event happened"))
		end	
		--env.info(("EMBD.baseCapture started"))
		local conquer = event.initiator
		local base = event.place
		if conquer and base then
			local conquerCoa = conquer:getCoalition()
			local conquerCountry = conquer:getCountry()
			local baseID = base:getID()
			local baseName = base:getName()
			--local baseDesc = base:getDesc()	
			local baseTYPE = nil		
			
			if base:hasAttribute("Airfields") then
				baseTYPE = "airports"
			else
				baseTYPE = "warehouses"
			end	
			
			if DSMC_debugProcessDetail == true then
				--trigger.action.outText("EMBD.baseCapture ha registrato un cambio di fazione della base: " .. tostring(baseID), 10)
				env.info(("EMBD.baseCapture base name: " .. tostring(baseName) .. " has been captured by: " .. tostring(conquerCoa)))
			end	
			tblConquer[#tblConquer+1] = {id = baseID, name = baseName, coa = conquerCoa, country = conquerCountry, baseType = baseTYPE}
			--env.info(("EMBD.baseCapture tblConquer populated"))
		else
			env.info(("EMBD.baseCapture FAILED to return conquer & base"))
		end
	end
end
world.addEventHandler(EMBD.baseCapture)	

EMBD.collectSpawned = {} 
function EMBD.collectSpawned:onEvent(event)
	if event.id == world.event.S_EVENT_BIRTH and timer.getTime0() < timer.getAbsTime() then
		env.info(("EMBD.collectSpawned started"))
		
		if Object.getCategory(event.initiator) == 1 then -- unit
			if event.initiator:hasAttribute("Air") == false then
				if not Unit.getPlayerName(event.initiator) then					
					env.info(("EMBD.collectSpawned unit, non-player"))
					local ei_gName = Unit.getGroup(event.initiator):getName()

					if ei_gName and type(ei_gName) == "string" then
						if string.find(ei_gName, "Downed Pilot") or string.find(ei_gName, ExclusionTag) then
							env.info(("EMBD.collectSpawned unit is a downed pilot or an excluded unit, skipping: " .. tostring(ei_gName)))
							return
						end
					end


					local ei = Unit.getGroup(event.initiator)
					local ei_pos = event.initiator:getPosition().p
					local ei_unitTableSource = ei:getUnits()
					local ei_unitTable = {}
					local ei_coalition = ei:getCoalition()
					local ei_country = event.initiator:getCountry()
					DSMC_baseGcounter = DSMC_baseGcounter + 1
					local ei_ID = DSMC_baseGcounter -- ei:getID()
					local ei_Altitude = land.getHeight({x = ei_pos.x, y = ei_pos.z})
					env.info(("EMBD.collectSpawned unit data collected"))

					if ei_unitTableSource and #ei_unitTableSource > 0 then
						for _id, _eiUnitData in pairs(ei_unitTableSource) do

							local unitHdg	= EMBD.getHeading(_eiUnitData, true)	
							local uPosition = _eiUnitData:getPosition().p

							if DSMC_trackspawnedinfantry == true then
								DSMC_baseUcounter = DSMC_baseUcounter + 1
								ei_unitTable[#ei_unitTable+1] = {uID = DSMC_baseUcounter, uName = _eiUnitData:getName(), uPos = uPosition, uHdg = unitHdg, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
							else
								if not _eiUnitData:hasAttribute("Infantry") then  -- infantry wont't be tracked
									DSMC_baseUcounter = DSMC_baseUcounter + 1
									ei_unitTable[#ei_unitTable+1] = {uID = DSMC_baseUcounter, uName = _eiUnitData:getName(), uPos = uPosition, uHdg = uHeading, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
								end
							end
						end
					end
					env.info(("EMBD.collectSpawned units data collected"))
					if #ei_unitTable > 0 then
						if ei and not tblSpawned[ei_gName] then
							tblSpawnedcounter = tblSpawnedcounter + 1
							tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(event.initiator), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "vehicle", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}
							env.info(("EMBD.collectSpawned data added to tblSpawned"))
						end
					end
					
				end
			else
				env.info(("EMBD.collectSpawned unit is a flying thing, removed"))
			end

		elseif Object.getCategory(event.initiator) == 4 then -- FARP
			env.info(("EMBD.collectSpawned FARP"))
			local _eiUnitData = event.initiator
			local ei_gName = Airbase.getName(event.initiator)

			if ei_gName and type(ei_gName) == "string" then
				if string.find(ei_gName, ExclusionTag) then
					env.info(("EMBD.collectSpawned unit is an excluded object, skipping: " .. tostring(ei_gName)))
					return
				end
			end

			local ei = Airbase.getByName(ei_gName)
			local ei_pos = ei:getPosition().p
			local ei_unitTable = {}
			local ei_coalition = ei:getCoalition()
			local ei_country = event.initiator:getCountry()
			DSMC_baseGcounter = DSMC_baseGcounter + 1
			local ei_ID = DSMC_baseGcounter -- ei:getID()
			env.info(("EMBD.collectSpawned FARP data collected, ei_gName: " .. tostring(ei_gName)))
			
			if ei_gName then
				ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
			end

			if ei and not tblSpawned[ei_gName] then
				tblSpawnedcounter = tblSpawnedcounter + 1
				env.info(("EMBD.collectSpawned airbase_farp added"))
				tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(event.initiator), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "static", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}
			end
		elseif Object.getCategory(event.initiator) == 6 then -- cargo
			env.info(("EMBD.collectSpawned cargo"))
			local _eiUnitData = event.initiator
			local ei_gName = StaticObject.getName(event.initiator)

			if ei_gName and type(ei_gName) == "string" then
				if string.find(ei_gName, ExclusionTag) then
					env.info(("EMBD.collectSpawned unit is an excluded object, skipping: " .. tostring(ei_gName)))
					return
				end
			end

			local ei = StaticObject.getByName(ei_gName)
			local ei_pos = ei:getPosition().p
			--local ei_unitTableSource = ei:getUnits()
			local ei_unitTable = {}
			local ei_coalition = ei:getCoalition()
			local ei_country = event.initiator:getCountry()
			DSMC_baseGcounter = DSMC_baseGcounter + 1
			local ei_ID = DSMC_baseGcounter -- ei:getID()
			local ei_Weight = event.initiator:getCargoWeight()

			env.info(("EMBD.collectSpawned static, ei_gName " .. tostring(ei_gName)))
			
			if ei_gName then
				ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true, uWeight = ei_Weight}
			end

			if ei and not tblSpawned[ei_gName] then
				env.info(("EMBD.collectSpawned static, adding " .. tostring(ei_gName) .. " to the tblSpawned table"))
				tblSpawnedcounter = tblSpawnedcounter + 1
				tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(event.initiator), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "static", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}					
			end		
		elseif Object.getCategory(event.initiator) == 3 then -- static
			env.info(("EMBD.collectSpawned static"))
			local _eiUnitData = event.initiator
			local ei_gName = StaticObject.getName(event.initiator)

			if ei_gName and type(ei_gName) == "string" then
				if string.find(ei_gName, ExclusionTag) then
					env.info(("EMBD.collectSpawned unit is an excluded object, skipping: " .. tostring(ei_gName)))
					return
				end
			end

			local ei = StaticObject.getByName(ei_gName)
			if ei then
				local ei_pos = ei:getPosition().p
				local ei_unitTable = {}
				local ei_coalition = ei:getCoalition()
				local ei_country = event.initiator:getCountry()
				DSMC_baseGcounter = DSMC_baseGcounter + 1
				local ei_ID = DSMC_baseGcounter -- ei:getID()
				env.info(("EMBD.collectSpawned static data collected, ei_gName: " .. tostring(ei_gName)))
				
				if ei_gName then

					local unitHdg	= EMBD.getHeading(_eiUnitData, true)	
					local uPosition = _eiUnitData:getPosition().p

					ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = uPosition, uHdg = unitHdg, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
				end

				if ei and not tblSpawned[ei_gName] then
					tblSpawnedcounter = tblSpawnedcounter + 1
					env.info(("EMBD.collectSpawned static added"))
					tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(event.initiator), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "static", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}			
				end
			end
		else
			env.info(("EMBD.collectSpawned can't add object, category not found: " .. tostring(Object.getCategory(event.initiator))))

		end
	end
end
world.addEventHandler(EMBD.collectSpawned)

EMBD.sceneryDestroyRefresh = {}
function EMBD.sceneryDestroyRefresh:onEvent(event) -- used for scenery destruction obj
	if event.id == world.event.S_EVENT_MISSION_START then 

		trigger.action.setUserFlag("12345" , true )
		env.info(("EMBD.sceneryDestroyRefresh at mission start, flag set"))
		local function resetFlag()
			trigger.action.setUserFlag("12345" , false )
			env.info(("EMBD.sceneryDestroyRefresh at mission start, flag reset done"))
		end
		timer.scheduleFunction(resetFlag, {}, timer.getTime() + 5)
	end
end
world.addEventHandler(EMBD.sceneryDestroyRefresh)

function EMBD.sceneryDestroyRefreshRemote()
	local function setFlag()
		trigger.action.setUserFlag("12345" , true )
		env.info(("EMBD.sceneryDestroyRefreshRemote is a client, flag set done"))
	end	
	local function resetFlag()
		trigger.action.setUserFlag("12345" , false )
		env.info(("EMBD.sceneryDestroyRefreshRemote is a client, flag reset done"))
	end
	timer.scheduleFunction(setFlag, {}, timer.getTime() + 1)	
	timer.scheduleFunction(resetFlag, {}, timer.getTime() + 2)
end

--
EMBD.airbaseFuelIndex = {}
EMBD.fuelTest = {}
function EMBD.fuelTest:onEvent(event)
	if event.id == world.event.S_EVENT_BIRTH then 
		env.info(("EMBD.fuelTest event birth found"))
		if event.initiator then
			if Object.getCategory(event.initiator) == 1 then -- unit. if it's a unit, can have fuel
				local fuel = event.initiator:getFuel()
				env.info(("EMBD.fuelTest event birth found, fuel: " .. tostring(fuel)))
				if fuel then
					local isClient = event.initiator:getPlayerName()
					if fuel == 0 and isClient == false then
						local obj_pos = event.initiator:getPosition().p
						local obj_coa = event.initiator:getCoalition()
						local obj_type = event.initiator:getTypeName()
						local airbases = coalition.getAirbases(obj_coa)

						env.info(("EMBD.fuelTest removing object: " .. tostring(obj_type)))

						local distance_func = function(point1, point2)
							local xUnit = point1.x
							local yUnit = point1.z
							local xZone = point2.x
							local yZone = point2.z
							local xDiff = xUnit - xZone
							local yDiff = yUnit - yZone
							return math.sqrt(xDiff * xDiff + yDiff * yDiff)
						end


						if obj_pos and obj_coa and airbases then
							local nName = nil
							local nDist = 1000000000
							
							for id, data in pairs(airbases) do
								local afb_pos = data:getPosition().p
								if afb_pos then
									local d = distance_func(afb_pos, obj_pos)
									local n = data:getName()
									if d and n then
										if d < nDist then
											nDist = d
											nName = n
										end
									end
								end
							end

							if nName then
								env.info(("EMBD.fuelTest setting airbase not usable: " .. tostring(nName)))
								EMBD.airbaseFuelIndex[nName] = true
							end
						end
						event.initiator:destroy()
					end
				end
			end
		end
	end
end
world.addEventHandler(EMBD.fuelTest)


--### FARP Workaround!
function EMBD.addFARPtoSpawned(object)
	if Object.getCategory(object) == 4 then -- FARP
		env.info(("EMBD.addFARPtoSpawned farp"))
		local _eiUnitData = object
		local ei_gName = Airbase.getName(object)
		local ei = Airbase.getByName(ei_gName)
		local ei_pos = ei:getPosition().p
		local ei_unitTable = {}
		local ei_coalition = ei:getCoalition()
		local ei_country = object:getCountry()
		DSMC_baseGcounter = DSMC_baseGcounter + 1
		local ei_ID = DSMC_baseGcounter -- ei:getID()
		env.info(("EMBD.addFARPtoSpawned FARP data collected, ei_gName: " .. tostring(ei_gName)))
		
		if ei_gName then
			ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
		end

		if ei and not tblSpawned[ei_gName] then
			tblSpawnedcounter = tblSpawnedcounter + 1
			env.info(("EMBD.addFARPtoSpawned FARP added"))
			tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(object), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "static", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}
		end
	end

end

--### FUNCTION LAUNCH FEATURES

-- at the end this should be removed for the campaign... maybe?
EMBD.createRadioMenu = function()
	--local _basePath = missionCommands.addSubMenuForGroup(_groupId, "DSMC-CTLD")
	DSMC_Rmenu = missionCommands.addSubMenu("DSMC")

	if not DSMC_DisableF10save then
		missionCommands.addCommand("Save scenery", DSMC_Rmenu, EMBD.executeSAVE, "recall")
		--missionCommands.addCommandForCoalition(coalition.side.RED, "Save scenery", DSMC_RmenuRed, EMBD.executeSAVE, "recall")
		
		--]]--
		--missionCommands.addCommand("DSMC - save progress", nil, EMBD.executeSAVE, "recall")
		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.CreateRadioMenu ok"))
		end
	else
		env.info(("EMBD.CreateRadioMenu didn't load F10 menù save option cause DSMC_DisableF10save is true"))
	end
end

EMBD.scheduleAutosave = function()
	env.info(("EMBD.scheduleAutosave launched"))
	if DSMC_autosavefrequency then -- and DSMC_server and DSMC_multy 
		env.info(("EMBD.scheduleAutosave DSMC_autosavefrequency = " .. tostring(DSMC_autosavefrequency)))		
		EMBD.executeSAVE()
		env.info(("EMBD.scheduleAutosave automessage message printed!"))
	end
	timer.scheduleFunction(EMBD.scheduleAutosave, {}, timer.getTime() + tonumber(DSMC_autosavefrequency))
end


EMBD.setDestroyedObjectAtStart = function()
	local function fxc()
		trigger.action.setUserFlag("12345" , true )
		local function resetFlag()
			trigger.action.setUserFlag("12345" , false )
			env.info(("EMBD.sceneryDestroyRefresh is a client, flag reset done"))
		end
		timer.scheduleFunction(resetFlag, {}, timer.getTime() + 1)
	end
	timer.scheduleFunction(fxc, {}, timer.getTime() + 1)
end
EMBD.setDestroyedObjectAtStart()

--### SET FUNCTIONS

--check vars for debug
if DSMC_debugProcessDetail then
	env.info(("EMBD: DSMC variable settings: DSMC_multy = " ..tostring(DSMC_multy)))
	env.info(("EMBD: DSMC variable settings: DSMC_server = " ..tostring(DSMC_server)))
	env.info(("EMBD: DSMC variable settings: DSMC_debugProcessDetail = " ..tostring(DSMC_debugProcessDetail)))
	env.info(("EMBD: DSMC variable settings: DSMC_autosavefrequency = " ..tostring(DSMC_autosavefrequency)))
	env.info(("EMBD: DSMC variable settings: DSMC_AutosaveExit_timer = " ..tostring(DSMC_AutosaveExit_timer)))
end

--do functions
--EMBD.getFreeCountry()
EMBD.getAptInfo()
EMBD.createRadioMenu()
if DSMC_autosavefrequency and DSMC_multy and DSMC_io and DSMC_lfs then
	timer.scheduleFunction(EMBD.scheduleAutosave, {}, timer.getTime() + tonumber(DSMC_autosavefrequency))
end

if DSMC_AutosaveExit_timer then
	if DSMC_AutosaveExit_timer > 0 then
		local function autostop()
			if DSMC_allowStop == false then
				trigger.action.outText("DSMC is trying to restart the server! land or disconnect as soon as you can: DSMC will try again in 10 minutes", 10)		
				timer.scheduleFunction(autostop, {}, timer.getTime() + 600)
			else
				timer.scheduleFunction(autostop, {}, timer.getTime() + 10)
			end
		end
		timer.scheduleFunction(autostop, {}, timer.getTime() + tonumber(DSMC_AutosaveExit_timer))
	end
end

EMBD.updateTimedCall = function()
	if updateTimedCall then
		for tlId, tlData in pairs(takeofflandLocker) do
			if (timer.getTime()- tlData.time) > 30 then
				takeofflandLocker[tlId] = nil
				--table.remove(takeofflandLocker, tlId)
			end
		end
	end
	timer.scheduleFunction(EMBD.updateTimedCall, {}, timer.getTime() + 30)
end

-- CTLD support code
EMBD.update_ctld_Tables = function(addHelos, addVehicles)
	env.info("DSMC:  update_ctld_Tables looking for ME helo, IFV, APC for add transport table and infantry groups")
	for _coalitionName, _coalitionData in pairs(env.mission.coalition) do		
		if (_coalitionName == 'red' or _coalitionName == 'blue')
				and type(_coalitionData) == 'table' then
			if _coalitionData.country then --there is a country table
				for _, _countryData in pairs(_coalitionData.country) do

					if type(_countryData) == 'table' then
						for _objectTypeName, _objectTypeData in pairs(_countryData) do
							if _objectTypeName == "vehicle" or _objectTypeName == "helicopter" then

								if ((type(_objectTypeData) == 'table')
										and _objectTypeData.group
										and (type(_objectTypeData.group) == 'table')
										and (#_objectTypeData.group > 0)) then

									for _groupId, _group in pairs(_objectTypeData.group) do
										if _group and _group.units and type(_group.units) == 'table' then
											local infantryCount = 0
											local unitCount = 0		
											local groupName = _group.name
											local Table_group = Group.getByName(groupName)
											local check_JTAC = false
											if Table_group then
												local Table_group_ID = Table_group:getID()
																			
												for _unitNum, _unit in pairs(_group.units) do
													--if _unitNum == 1 then
														-- DICTPROBLEM
														--local unitName = env.getValueDictByKey(_unit.name)
														local unitName = _unit.name

														if unitName then

															local unit = Unit.getByName(unitName)
															if unit then
																if unit:getLife() > 0 then
																	unitCount = unitCount + 1
																	local unitID = unit:getID()
																	if unit:hasAttribute("APC") or unit:hasAttribute("IFV") or unit:hasAttribute("Trucks") then -- preload a ground group in everyone
																		if addVehicles == true then
																			table.insert(ctld.transportPilotNames, unitName)
																			
																			local unit_typeName = unit:getTypeName()
																			if unit_typeName then
																				if unit:hasAttribute("Trucks") then
																					ctld.unitLoadLimits[unit_typeName] = 24
																					ctld.unitActions[unit_typeName] = {crates=true, troops=true}
																				elseif unit:hasAttribute("APC") then
																					ctld.unitLoadLimits[unit_typeName] = 8
																					ctld.unitActions[unit_typeName] = {crates=false, troops=true}
																				elseif unit:hasAttribute("IFV") then
																					ctld.unitLoadLimits[unit_typeName] = 4    
																					ctld.unitActions[unit_typeName] = {crates=false, troops=true}
																				end
																			end     

																			env.info("DSMC:  update_ctld_Tables: unit " .. tostring(unitName) .. " is an APC or IFV, ctld.transportPilotNames updated")																
																		end

																	elseif addHelos == true and unit:hasAttribute("Helicopters") then
																		table.insert(ctld.transportPilotNames, unitName)
																		env.info("DSMC:  update_ctld_Tables: unit " .. tostring(unitName) .. " is an helo, ctld.transportPilotNames updated")																						
																	
																	elseif unit:hasAttribute("Infantry") then
																		infantryCount = infantryCount +1
																		--if unit:hasAttribute("MANPADS") then
																		--    check_JTAC = true
																		--end
																	end
																end
															end
														end
													--end
												end
											end
											
											if infantryCount == unitCount and infantryCount > 0 and addVehicles == true then -- make group with only infantry transportable by default
												local groupTable = Group.getByName(groupName)
												if groupTable then												
													if not ctld.extractableGroups[groupName] then
														table.insert(ctld.extractableGroups, groupName)
														env.info("DSMC:  update_ctld_Tables: group ".. tostring(groupName) .. " of units added as extractable")													
													end
												end
											end
										end
									end
								end
							elseif _objectTypeName == "static" then
								if ((type(_objectTypeData) == 'table')
										and _objectTypeData.group
										and (type(_objectTypeData.group) == 'table')
										and (#_objectTypeData.group > 0)) then
									for _groupId, _group in pairs(_objectTypeData.group) do
										if _group and _group.units and type(_group.units) == 'table' then								
											if _group.dead == false then
												for _unitNum, _unit in pairs(_group.units) do
													local unitName = _unit.name
													if unitName then		
														local unitTable = StaticObject.getByName(unitName)
														local unitCoa = nil
														if unitTable then
															unitCoa = unitTable:getCoalition()
														end

														if _unit.category == "Fortifications" and _unit.type == "outpost" then           
															env.info("DSMC:  update_ctld_Tables: checking FOB, found outpost object:" .. tostring(unitName))	
															local stObject = StaticObject.getByName(unitName)
															if stObject then																	
																local centerposUnit = stObject:getPosition().p
																if centerposUnit then
																	env.info("DSMC:  update_ctld_Tables: checking FOB, outpost has position")
																	
																	local foundUnits = {}
																	local volS = {
																	id = world.VolumeType.SPHERE,
																	params = {
																		point = centerposUnit,
																		radius = 150
																	}
																	}
																	
																	local ifFound = function(foundItem, val)
																		env.info("DSMC:  update_ctld_Tables: checking FOB, proximity object found")	                                                            
																		if foundItem:getTypeName() == "TACAN_beacon" then
																			env.info("DSMC:  update_ctld_Tables: checking FOB, object is a beacon")	 
																			foundUnits[#foundUnits + 1] = foundItem:getName()
																			return true
																		end
																	end                                                           
																	world.searchObjects(Object.Category.UNIT, volS, ifFound)
																	
																	if table.getn(foundUnits) > 0 then -- there's a beacon nearby an outpost: it's a FOB                                                            
																		
																		--adding FOB
																		table.insert(ctld.logisticUnits, unitName)
																		env.info("DSMC:  update_ctld_Tables: checking FOB, outpost added as FOB")	 
																		--if ctld.troopPickupAtFOB == true then
																		table.insert(ctld.builtFOBS, unitName)			
																		--end							
																		env.info("DSMC:  update_ctld_Tables: unit " .. tostring(unitName) .. " is an outpost, ctld.logisticUnits updated")	                                                            
																		
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
		end
	end
	env.info("DSMC:  update_ctld_Tables done")
end

EMBD.scheduleCTLDsupport = function()
	local timesec = timer.getTime() + 5
	env.info((ModuleName .. ": checking CTLD needed support code in " .. tostring(timesec) .. " seconds"))
	local launchCTLDsupport = function()
		if ctld then
			if not ctld_c then
				
				local a = DSMC_ctld_var1 or false
				local b = DSMC_ctld_var2 or false
				env.info(ModuleName .. " AddHeloOnBirth DSMC_ctld_var1 " .. tostring(a))
				env.info(ModuleName .. " AddHeloOnBirth DSMC_ctld_var2 " .. tostring(b))

				EMBD.update_ctld_Tables(a, b)

				EMBD.AddHeloOnBirth = {}
				function EMBD.AddHeloOnBirth:onEvent(event)	
					if event.id == world.event.S_EVENT_BIRTH and event.initiator then
						if Object.getCategory(event.initiator) == 1 then
							local unit 			= event.initiator
							if unit then
								local unitID = unit:getID()	
								local unitName = unit:getName()									
								if a == true and unit:hasAttribute("Helicopters") then
									table.insert(ctld.transportPilotNames, unitName)

									env.info(ModuleName .. " AddHeloOnBirth unit " .. tostring(unitName) .. " is an helo, ctld.transportPilotNames updated")

								elseif unit:hasAttribute("APC") or unit:hasAttribute("IFV") or unit:hasAttribute("Trucks") then
									if b == true then
										table.insert(ctld.transportPilotNames, unitName)

										env.info(ModuleName .. " AddHeloOnBirth unit " .. tostring(unitName) .. " is an APC or IFV, ctld.transportPilotNames updated")

									end
								end	
							end
						end
					end
				end
				world.addEventHandler(EMBD.AddHeloOnBirth)	

				EMBD.AddInfantriesOnBirth = {}
				function EMBD.AddInfantriesOnBirth:onEvent(event)	
					if	b == true then
						if event.id == world.event.S_EVENT_BIRTH and event.initiator then
							if Object.getCategory(event.initiator) == 1 then	
								local unit = event.initiator
								if unit then
									--local unitID = unit:getID()					
									if unit:hasAttribute("Infantry") then

										env.info(ModuleName .. " AddInfantriesOnBirth unit " .. tostring(unit:getName()) .. " is an infantry, evaluating group composition")

										
										local group = unit:getGroup()
										if group then
											local countTot = 0
											local countInf = 0
											local unitsCoa = nil
											for units_id, units_data in pairs(group:getUnits()) do
												countTot = countTot + 1
												if units_data:hasAttribute("Infantry") then
													countInf = countInf +1
													unitsCoa = units_data:getCoalition()
												end
											end
											
											if countInf == countTot and unitsCoa then

													env.info(ModuleName .. " AddInfantriesOnBirth all units in the group are infantry")

					
												local groupID = group:getID()
												local groupName = group:getName()
												local placefree = true
												if not ctld.extractableGroups[groupName] then
													table.insert(ctld.extractableGroups, groupName)
					
													if unitsCoa == 1 then
														table.insert(ctld.droppedTroopsRED, groupName)
														env.info(ModuleName .. " added group to RED dropped: " .. tostring(groupName))
													elseif unitsCoa == 2 then
														table.insert(ctld.droppedTroopsBLUE, groupName)
														env.info(ModuleName .. " added group to BLUE dropped: " .. tostring(groupName))
													else 
														table.insert(ctld.droppedTroopsNEUTRAL, groupName)
														env.info(ModuleName .. " added group to RED dropped: " .. tostring(groupName))
													end
					
													env.info(ModuleName .. " AddInfantriesOnBirth group of units added as extractable")
												end
											end
										end
									end			
								end
							end
						end					
					end
				end
				world.addEventHandler(EMBD.AddInfantriesOnBirth)
			else
				env.info(ModuleName .. " DSMC custom ctld version also detected, this SHOULD NOT HAPPEN")
			end
		end
	end

	timer.scheduleFunction(launchCTLDsupport, {}, timesec)
end
EMBD.scheduleCTLDsupport()

env.info((ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date))


--timer.scheduleFunction(EMBD.executeSAVE, {}, timer.getTime() + 30)
if DSMC_lfs and DSMC_io then
	EMBD.oncallworkflow("desanitized")
else
	EMBD.oncallworkflow("sanitized")
end	


local function dumpThreats()
	if DSMC_io and DSMC_lfs then
		dumpTable("EMBD.tblThreatsRange.lua", EMBD.tblThreatsRange)
		dumpTable("EMBD.dbWarehouse.lua", dbWarehouse)
	end
end
timer.scheduleFunction(dumpThreats, {}, timer.getTime() + 2)

--~=