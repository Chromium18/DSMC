-- Dynamic Sequential Mission Campaign -- DSMC core injected functions module
-- PLACEHOLDER WORKAROUND FOR CAUCASUS AIRBASE ID ON LINE 183 

local ModuleName  	= "EMBD"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0001"
local Date			= "09/03/2020"

env.setErrorMessageBoxEnabled(false)
local base 						= _G
local DSMC_io 					= base.io  	-- check if io is available in mission environment
local DSMC_lfs 					= base.lfs		-- check if lfs is available in mission environment

local texttimer					= 1
local mapObj_deathcounter 		= 0
local StaticStartNumber			= 0
local baseGcounter				= 200000
local messageunitId				= 1
local tblSpawnedcounter			= 0
local playerShutEngine			= false
local playerCrashed				= false
local playerShutEngine			= false

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
tblDeadScenObj					= {}
tblUnitsUpdate					= {}
tblAirbases						= {} 
tblLogistic						= {}
tblLogCollect					= {}
tblSpawned						= {}
tblConquer						= {}
--tblConquerCollect				= {}

trigger.action.outText("DSMC active in this mission!\nto save scenery progress, you can use the communication F10 menù and choose DSMC - save mission", 20)

-- DSMC_multy = true -- used for testing purposes!
if not DSMC_multy then
	trigger.action.outText("DSMC is in single player mode: you must remember to save the mission on your own!", 20)
end

if DSMC_debugProcessDetail == true then
	env.setErrorMessageBoxEnabled(true)
	env.info(("EMBD set setErrorMessageBoxEnabled : true"))
	trigger.action.outText("EMBD set setErrorMessageBoxEnabled : true", 10)
	trigger.action.outText(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build, 10)
end		

if dbWeapon and DSMC_debugProcessDetail == true then
	env.info(("DSMC dbWeapon exist"))
	trigger.action.outText("DSMC dbWeapon exist", 10)
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
			local fdir = DSMC_lfs.writedir() .. [[Logs\]] .. fname
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
			f:write(str)
			f:close()
		end
	end
	
	env.info(("EMBD desanitized additional function loaded"))
end

-- ##CORE

function EMBD.getAptInfo()
	local apt_Table = world.getAirbases()
	for Aid, Adata in pairs(apt_Table) do
		local aptInfo = Adata:getDesc()
		local aptName = Adata:getName()
		local aptID	  = Adata:getID()
		local indexId = Aid
		if env.mission.theatre == "Caucasus" then
			indexId = indexId +11			
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.getAptInfo added 11 to airport index due to Caucasus scenery, from: " .. tostring(Aid) .. " to: " .. tostring(indexId)))
			end				
		end	
		tblAirbases[#tblAirbases+1] = {id = aptID, index = indexId, name = aptName, desc = aptInfo}
	end
end

function EMBD.sendUnitsData(missionEnv)	--what does it do with statics??
	tblUnitsUpdate = {}
	for coalitionID,coalition in pairs(missionEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					for groupID,group in pairs(attr["group"]) do
						if (group) then						
							for unitID, unit in pairs(group["units"]) do																			
								local isAlive = true
								for id, deadData in pairs (tblDeadUnits) do
									if tonumber(deadData.unitId) == tonumber(unit.unitId) then
										isAlive = false
									end
								end																
								
								if isAlive == true and group and unit then							
									
									if attrID == "plane" or attrID =="helicopter" then							
										--[[
										uName 			= env.getValueDictByKey(unit.name)
										curUnit 		= Unit.getByName(uName)
										
										if curUnit then
											curUnitPos 		= curUnit:getPosition().p

											tblUnitsUpdate[#tblUnitsUpdate + 1] = {unitId = unit.unitId, x = curUnitPos.x, y = curUnitPos.y, z = curUnitPos.z, aircraft = true}

											if DSMC_debugProcessDetail == true then
												env.info(("EMBD.sendUnitsData add a record in tblUnitsUpdate, unit"))
											end												
										end										
										--]]--
										
										
										
										--
										if DSMC_debugProcessDetail == true then
											env.info(("EMBD.sendUnitsData object is plane or helo: no position update"))
										end
										--]]--
										
									elseif attrID == "static" then
										uName 			= env.getValueDictByKey(unit.name)
										uCat			= unit.category
										if uCat == "Cargos" then
											curUnit 		= StaticObject.getByName(uName)																					
											if curUnit then -- cargo still exist
												curUnitPos 		= curUnit:getPosition().p
												tblUnitsUpdate[#tblUnitsUpdate + 1] = {unitId = unit.unitId, x = curUnitPos.x, y = curUnitPos.y, z = curUnitPos.z, aircraft = false}
												if DSMC_debugProcessDetail == true then
													env.info(("EMBD.sendUnitsData add a record in tblUnitsUpdate, cargo"))
												end													
											else
												tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unit.unitId), objCategory = 6}
												if DSMC_debugProcessDetail == true then
													env.info(("EMBD.sendUnitsData add a record in tblDeadUnits to remove cargo"))
												end														
											end
										end
									else
										uName 			= env.getValueDictByKey(unit.name)
										curUnit 		= Unit.getByName(uName)
										
										if curUnit then
											curUnitPos 		= curUnit:getPosition().p

											tblUnitsUpdate[#tblUnitsUpdate + 1] = {unitId = unit.unitId, x = curUnitPos.x, y = curUnitPos.y, z = curUnitPos.z, aircraft = false}

											if DSMC_debugProcessDetail == true then
												env.info(("EMBD.sendUnitsData add a record in tblUnitsUpdate, unit"))
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
		env.info(("EMBD.sendUnitsData ok"))
	end		
end	

function EMBD.updateSpawnedPosition(tblSpawned)	
	if tblSpawned then
		for id, idData in pairs(tblSpawned) do		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.updateSpawnedPosition checking group " ..tostring(idData.gName)))
		end
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
							if unit:getLife() > 0 then
								local unitPos  	= unit:getPosition().p					
								uData.uPos = unitPos
								env.info(("EMBD.updateSpawnedPosition udata updated"))
							else
								uData.uAlive = false
								env.info(("EMBD.updateSpawnedPosition unit dead, removed"))
							end
						else
							uData.uAlive = false
							env.info(("EMBD.updateSpawnedPosition unit missing, removed"))					
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
							if object:getLife() > 0 then
								local unitPos  	= object:getPosition().p					
								uData.uPos = unitPos
								env.info(("EMBD.updateSpawnedPosition udata updated"))
							else
								idData.gStaticAlive = false
								env.info(("EMBD.updateSpawnedPosition static dead, removed"))
							end
						else
							idData.gStaticAlive = false
							env.info(("EMBD.updateSpawnedPosition static missing, removed"))					
						end
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.updateSpawnedPosition static check complete"))
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

							if object:getLife() > 0 then
								local unitPos  	= object:getPosition().p					
								uData.uPos = unitPos
								env.info(("EMBD.updateSpawnedPosition udata updated"))
							else
								idData.gStaticAlive = false
								env.info(("EMBD.updateSpawnedPosition cargo dead, removed"))
							end
						else
							if id then
								table.remove(tblSpawned, tonumber(id))
								idData.gStaticAlive = false
								env.info(("EMBD.updateSpawnedPosition cargo missing, removed"))					
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
	if DSMC_debugProcessDetail == true then
		env.info(("EMBD.updateSpawnedPosition ok"))
	end		
end

function EMBD.elabLogistic(tblLogCollect)	
	tblLogistic						= {}
	for uId, uData in pairs(tblLogCollect) do
		if uId and uData.unit and uData.init_fuel and uData.init_ammo and uData.desc and uData.init_place and uData.hits and uData.end_place and uData.end_ammo and uData.end_fuel then
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.elabLogistic valid entry, unitId: " .. tostring(uId)))
				trigger.action.outText("EMBD.elabLogistic valid entry, unitId: " .. tostring(uId), 10)
			end		
			
			--tblLogistic[uId] = {}
			
			--## new variables, departure (must exist)			
			-- departure
			local placeDepartureId 		= "none"
			local placeDepartureId_code	= "none"
			local placeDepartureName 	= "none"
			local placeDepartureType 	= "none"
			if  uData.init_place ~= "none" then
				placeDepartureId_code	= tonumber(uData.init_place:getID())
				placeDepartureId		= "missing"
				placeDepartureName		= tostring(uData.init_place:getName())
				if uData.init_place:hasAttribute("Helipad") or uData.init_place:hasAttribute("Ships") then
					placeDepartureType 		= "warehouses"
					placeDepartureId		= placeDepartureId_code
				else
					placeDepartureType 		= "airports"
					for Anum, Adata in pairs(tblAirbases) do
						if Adata.name == placeDepartureName then
							placeDepartureId = Adata.index
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.elabLogistic identified airport id: " .. tostring(placeDepartureId) .. ", name: " .. tostring(Adata.name)))
								trigger.action.outText("EMBD.elabLogistic identified airport id: " .. tostring(placeDepartureId) .. ", name: " .. tostring(Adata.name), 10)
							end								
						end
					end					
				end						
			end
	
			--fuel
			local fuelDepartureKg		= 0
			if uData.init_fuel ~= "none" then
				fuelDepartureKg		= tonumber(uData.init_fuel)*tonumber(uData.desc.fuelMassMax)
			end
			--ammo, symplified
			local ammoDepartureTbl = {}
			if uData.init_ammo ~= "none" then
				for aId, aData in pairs(uData.init_ammo) do
					if aData.desc then
						local wName = aData.desc.typeName --    string.gsub(aData.desc.displayName, "-", "%%-" )
						local wQty	= aData.count
							
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.elabLogistic departure check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty)))
							trigger.action.outText("EMBD.elabLogistic departure check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty), 10)
						end	
						
						for db_id, db_Data in pairs(dbWeapon) do
							if wName == db_Data.unique or wName == db_Data.name then
								ammoDepartureTbl[db_Data.unique] = {amount = wQty, wsString = db_Data.wsData}
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.elabLogistic departure wpn added: " .. tostring(wName) .. ", quantity: " .. tostring(wQty)))
								end	
							end
						end
						
						--[[
						local wName = string.gsub(aData.desc.displayName, "-", "%%-" )
						local wQty	= aData.count
						
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.elabLogistic departure check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty)))
							trigger.action.outText("EMBD.elabLogistic departure check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty), 10)
						end	
						
						for vwName, vwCode in pairs(validWeaponsCode) do
							--env.info(("EMBD.elabLogistic departure wpn vwName: " .. tostring(vwName) .. " on " .. tostring(wName)))
							if string.find(tostring(vwName), tostring(wName)) then 	
								ammoDepartureTbl[vwCode] = wQty
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.elabLogistic departure wpn added: " .. tostring(vwName)))
								end								
								wName = "xxxxxxxx"
							end
						end
						]]--
					end
				end
			end
			--aircraft
			local acfDepartureType		= uData.desc.typeName
						
			--## new variables, arrival (may not exist)
			-- arrival
			local placeArrivalId		= "none"
			local placeArrivalId_code	= "none"
			local placeArrivalType 		= "none"
			local placeArrivalName		= "none"
			if uData.end_place ~= "none" then
				placeArrivalId = "missing"
				placeArrivalId_code = tonumber(uData.end_place:getID())
				placeArrivalName = tostring(uData.end_place:getName())				
				if uData.end_place:hasAttribute("Helipad") or uData.init_place:hasAttribute("Ships")  then
					placeArrivalType = "warehouses"
					placeArrivalId = placeArrivalId_code
				else
					placeArrivalType = "airports"
					for Anum, Adata in pairs(tblAirbases) do
						if Adata.name == placeArrivalName then
							placeArrivalId = Adata.index					
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.elabLogistic identified airport id: " .. tostring(placeArrivalId) .. ", name: " .. tostring(Adata.name)))
								trigger.action.outText("EMBD.elabLogistic identified airport id: " .. tostring(placeArrivalId) .. ", name: " .. tostring(Adata.name), 10)
							end								
						end
					end
				end				
			end
			--fuel
			local fuelArrivalKg		= 0
			if uData.end_fuel ~= "none" then
				fuelArrivalKg = tonumber(uData.end_fuel)*tonumber(uData.desc.fuelMassMax)
			end
			--ammo, symplified
			local ammoArrivalTbl = {}
			if uData.end_ammo ~= "none" then
				for aId, aData in pairs(uData.end_ammo) do
					if aData.desc then
						local wName = aData.desc.typeName --    string.gsub(aData.desc.displayName, "-", "%%-" )
						local wQty	= aData.count
	
						
						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.elabLogistic arrival check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty)))
							trigger.action.outText("EMBD.elabLogistic arrival check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty), 10)
						end	
						
						for db_id, db_Data in pairs(dbWeapon) do
							if wName == db_Data.unique or wName == db_Data.name then
								ammoArrivalTbl[db_Data.unique] = {amount = wQty, wsString = db_Data.wsData}
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.elabLogistic arrival wpn added: " .. tostring(wName) .. ", quantity: " .. tostring(wQty)))
								end	
							end
						end


						--[[
						local wName = string.gsub(aData.desc.displayName, "-", "%%-" )
						local wQty	= aData.count

						if DSMC_debugProcessDetail == true then
							env.info(("EMBD.elabLogistic arrival check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty)))
							trigger.action.outText("EMBD.elabLogistic arrival check wpn: " .. tostring(wName) .. ", wQty: " .. tostring(wQty), 10)
						end	
						
						--wpn name corrections, done cause DCS can't recognise every wpn
						if wName == "Vikhr M" then	
							wName = "Vikhr"
						end						
						
						for vwName, vwCode in pairs(validWeaponsCode) do
							--env.info(("EMBD.elabLogistic arrival wpn vwName: " .. tostring(vwName) .. " on " .. tostring(wName)))
							if string.find(tostring(vwName), tostring(wName)) then 							
								ammoArrivalTbl[vwCode] = wQty
								if DSMC_debugProcessDetail == true then
									env.info(("EMBD.elabLogistic arrival wpn added: " .. tostring(vwName)))
								end								
								wName = "xxxxxxxx"
							end
						end
						]]--
						
					end
				end	
			end
			--aircraft
			local acfArrivalType		= 0
			if placeArrivalId ~= "none" then
				acfArrivalType = acfDepartureType
			end
			
			
			tblLogistic[#tblLogistic+1] = {action = "departure", acf = acfDepartureType, placeId = placeDepartureId, placeName = placeDepartureName, placeType = placeDepartureType, fuel = fuelDepartureKg, ammo = ammoDepartureTbl, hits = uData.hits} -- mod ammo here
			if placeArrivalId ~= "none" then
				tblLogistic[#tblLogistic+1] = {action = "arrival", acf = acfArrivalType, placeId = placeArrivalId, placeName = placeArrivalName, placeType = placeArrivalType, fuel = fuelArrivalKg, ammo = ammoArrivalTbl, hits = uData.hits}
			end
			
		end
	end
end

EMBD.oncallworkflow = function(sanivar, recall)
	env.info(("EMBD.oncallworkflow sanivar: " .. tostring(sanivar) .. ", recall: " .. tostring(recall)))
	if sanivar == "desanitized" then
		env.info(("EMBD.oncallworkflow (desan) saveProcess start"))
		--not used now
		local msg_duration = 0.05
		local prt_stack = 0.1
		cur_Stack = 0.1 -- start point
		
		EMBD.sendUnitsData(env.mission)
		EMBD.updateSpawnedPosition(tblSpawned)
		EMBD.elabLogistic(tblLogCollect)
		
		local function funcAirbases()
			EMBD.saveTable("tblAirbases", tblAirbases)
			env.info(("EMBD.oncallworkflow (desan) saved tblAirbases"))
		end

		local function funcDeadUnits()
			EMBD.saveTable("tblDeadUnits", tblDeadUnits)
			env.info(("EMBD.oncallworkflow (desan) saved tblDeadUnits"))
		end

		local function funcDeadScenObj()
			EMBD.saveTable("tblDeadScenObj", tblDeadScenObj)
			env.info(("EMBD.oncallworkflow (desan) saved tblDeadScenObj"))
		end

		local function funcUnitsUpdate()
			EMBD.saveTable("tblUnitsUpdate", tblUnitsUpdate)
			env.info(("EMBD.oncallworkflow (desan) saved tblUnitsUpdate"))
		end	

		local function funcLogistic()
			EMBD.saveTable("tblLogistic", tblLogistic)
			env.info(("EMBD.oncallworkflow (desan) saved tblLogistic"))
		end

		local function funcSpawned()
			EMBD.saveTable("tblSpawned", tblSpawned)
			env.info(("EMBD.oncallworkflow (desan) saved tblSpawned"))
		end

		local function funcConquer()
			EMBD.saveTable("tblConquer", tblConquer)
			env.info(("EMBD.oncallworkflow (desan) saved tblConquer"))
		end			

		local function saveProcess()
			trigger.action.outText("DSMC save...", msg_duration)
			env.info(("EMBD.oncallworkflow called saveProcess function"))
		end			
		
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
		if recall == "recall" then
			timer.scheduleFunction(saveProcess, {}, timer.getTime() + cur_Stack)
		end
		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.oncallworkflow (desan) scheduled files saving"))
		end	

		cur_Stack = 0.1	
		
	else
		env.info(("EMBD.oncallworkflow saveProcess standard start"))
		local msg_duration = 0.05
		local msg_Stack = 0.1
		cur_Stack = 0.1 -- start point
		
		EMBD.sendUnitsData(env.mission)
		EMBD.updateSpawnedPosition(tblSpawned)
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
		
		strAirbases = IntegratedserializeWithCycles("tblAirbases", tblAirbases)
		completeStringstrAirbases = tostring(strAirbases)
		local function funcAirbases()
			trigger.action.outText(completeStringstrAirbases, msg_duration)
		end
		
		strDeadUnits = IntegratedserializeWithCycles("tblDeadUnits", tblDeadUnits)
		completeStringstrDeadUnits = tostring(strDeadUnits)
		local function funcDeadUnits()
			trigger.action.outText(completeStringstrDeadUnits, msg_duration)
		end
		
		strDeadScenObj = IntegratedserializeWithCycles("tblDeadScenObj", tblDeadScenObj)
		local completeStringstrDeadScenObj = tostring(strDeadScenObj)
		local function funcDeadScenObj()
			trigger.action.outText(completeStringstrDeadScenObj, msg_duration)
		end
		
		local strUnitsUpdate = IntegratedserializeWithCycles("tblUnitsUpdate", tblUnitsUpdate)
		completeStringstrUnitsUpdate = tostring(strUnitsUpdate)
		local function funcUnitsUpdate()
			trigger.action.outText(completeStringstrUnitsUpdate, msg_duration)
		end	
		
		local strLogistic = IntegratedserializeWithCycles("tblLogistic", tblLogistic)
		completeStringstrLogistic = tostring(strLogistic)
		local function funcLogistic()
			trigger.action.outText(completeStringstrLogistic, msg_duration)
		end

		local strSpawned = IntegratedserializeWithCycles("tblSpawned", tblSpawned)
		completeStringstrSpawned = tostring(strSpawned)
		local function funcSpawned()
			trigger.action.outText(completeStringstrSpawned, msg_duration)
		end
		
		local strConquer = IntegratedserializeWithCycles("tblConquer", tblConquer)
		completeStringstrConquer = tostring(strConquer)
		local function funcConquer()
			trigger.action.outText(completeStringstrConquer, msg_duration)
		end	

		local function saveProcess()			
			trigger.action.outText("DSMC save...", msg_duration)
			env.info(("EMBD.oncallworkflow called saveProcess function"))
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
		if recall == "recall" then
			timer.scheduleFunction(saveProcess, {}, timer.getTime() + cur_Stack)
		end
		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.oncallworkflow scheduled strings printing"))
		end	

		cur_Stack = 0.1
	end
end

EMBD.executeSAVE = function(recall)
	env.info(("EMBD.executeSAVE launched. recall = " .. tostring(recall)))
	if DSMC_lfs and DSMC_io then
		EMBD.oncallworkflow("desanitized", recall)
	else
		EMBD.oncallworkflow("sanitized", recall)
	end
end


--### EVENT HANDLERS

EMBD.deathRecorder = {}
function EMBD.deathRecorder:onEvent(event)
	if event.id == world.event.S_EVENT_DEAD then --world.event.S_EVENT_DEAD
		
		local SOcategory 	= event.initiator:getCategory()
		local SOpos 		= event.initiator:getPosition().p
		local SOtypeName	= event.initiator:getTypeName()		
		
		if SOcategory == 5 then -- map object
		
			mapObj_deathcounter = mapObj_deathcounter + 1
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.deathRecorder death event categoria 5, oggetto mappa"))		
			end		
			
			tblDeadScenObj[#tblDeadScenObj + 1] = {id = mapObj_deathcounter, x = SOpos.x, y = SOpos.z}					
		 
		elseif SOcategory == 1 or SOcategory == 3 then -- unit or static object. Cargos, Bases and Weapons are left out
		
			if DSMC_debugProcessDetail == true then
				env.info(("EMBD.deathRecorder death event di categoria diversa da 5, unità o oggetto statico"))	
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
				unitTable 			= Unit.getByName(unitName)
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
				StaticStartNumber = StaticStartNumber +1
			
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
									["groupId"] = baseGcounter + 1,
									["hidden"] = true,
									["units"] = 
									{
										[1] = 
										{
											["type"] = unitTypeName,
											["unitId"] = baseGcounter + 1,
											["livery_id"] = "autumn",
											["rate"] = 20,
											["y"] = unitPos.z,
											["x"] = unitPos.x,
											["name"] = "CreatedStatic " .. tostring(StaticStartNumber),
											["category"] = correctCategory,
											["canCargo"] = false,
											["heading"] = 0,
										}, -- end of [1]
									}, -- end of ["units"]
									["y"] = unitPos.z,
									["x"] = unitPos.x,
									["name"] = unitName,
									["dead"] = true,
								} -- end of [1]				
				baseGcounter = baseGcounter +1
			
				tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unitID), coalitionID = unitCoalition, countryID = unitCountry, staticTable = groupTable, objCategory = unitCatEnum, objTypeName = unitTypeName}
				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.deathRecorder added unit"))	
				end					
			elseif unitShip == true then
				tblDeadUnits[#tblDeadUnits + 1] = {unitId = tonumber(unitID), unitShip = true}
				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.deathRecorder added ship"))	
				end						
			end
		
		end
	end	
end
world.addEventHandler(EMBD.deathRecorder)	

EMBD.LogisticUnload = {}
function EMBD.LogisticUnload:onEvent(event)	

	if event.id == world.event.S_EVENT_ENGINE_SHUTDOWN and dbWeapon then -- 18	
		
		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.LogisticUnload shutdown registered"))
			trigger.action.outText("EMBD.LogisticUnload shutdown registered", 10)
		end	
	
		local unit 			= event.initiator
		local unitCategory	= event.initiator:getCategory()
		local unitPos 		= event.initiator:getPosition().p
		local unitTypeName	= event.initiator:getTypeName()
		local unitCoalition	= event.initiator:getCoalition()
		local tblCoaBases	= coalition.getAirbases(unitCoalition)
		local UNITID		= unit:getID()
		
		local ShutDownOnAlliedBase = false
		
		local function GetDistance(Vec3a, Vec3b)
			local deltax = Vec3b.x - Vec3a.x
			local deltay = Vec3b.z - Vec3a.z
			return math.sqrt(math.pow(deltax, 2) + math.pow(deltay, 2))
		end		
			
		local NearestBaseDist = 1000000000
		local Nearest_abId 		= nil
		local Nearest_abType 	= nil
		local Nearest_ab        = nil
		for id, airbase in pairs(tblCoaBases) do
			local abName 		= airbase:getName()
			local abPos			= airbase:getPosition().p
			local ab			= Airbase.getByName(abName)
			local abId			= ab:getID()
			local abType		= "airports"
			if ab:hasAttribute("Helipad") then
				abType  = "warehouses"
			end
			
			local dist = GetDistance(unitPos, abPos)
			if dist < NearestBaseDist then
				NearestBaseDist = dist
				Nearest_ab = ab
				Nearest_abId = abId
			end				
		end		
		
		if NearestBaseDist < 3000 then -- check different number?
			ShutDownOnAlliedBase = true
		end

		if DSMC_debugProcessDetail == true then
			env.info(("EMBD.LogisticUnload unit: " .. tostring(UNITID) .. ", base: " .. tostring(Nearest_ab) .. ", ShutDownOnAlliedBase: " .. tostring(ShutDownOnAlliedBase) .. ", NearestBaseDist: " .. tostring(NearestBaseDist) .. "\n"))
			trigger.action.outText("EMBD.LogisticUnload unit: " .. tostring(UNITID) .. ", base: " .. tostring(Nearest_ab) .. "\n", 10)
		end

		
		if ShutDownOnAlliedBase == true then		
			local TookOff = false	
			for unitIds, unitDatas in pairs(tblLogCollect) do
				if unitIds == UNITID then
					TookOff = true
					local residualAmmo = unit:getAmmo()
					local residualFuel = unit:getFuel()
					if residualAmmo then
						unitDatas.end_ammo		= residualAmmo
					end
					if residualFuel then
						unitDatas.end_fuel		= residualFuel
					end
					unitDatas.end_place 	= Nearest_ab				
				end
			end
			
			if TookOff == false then
				local UNITID		= unit:getID()	
				local UNITAMMO		= unit:getAmmo()
				local UNITFUEL		= unit:getFuel()
				local UNITDESC		= unit:getDesc()

				local residualAmmo = UNITAMMO
				local residualFuel = UNITFUEL
				if not residualAmmo then
					residualAmmo		= "none"
				end
				if not residualFuel then
					residualFuel		= "none"
				end					
				
				if UNITID and residualAmmo and residualFuel and UNITDESC and Nearest_ab then
					tblLogCollect[UNITID] = {unit = unit, init_ammo = "none", init_place = "none", init_fuel = "none", desc = UNITDESC, hits = 0, end_place = Nearest_ab, end_ammo = residualAmmo, end_fuel = residualFuel}
					if DSMC_debugProcessDetail == true then
						env.info(("EMBD.LogisticUnload ha registrato un atterraggio da unità non decollata, unità: " .. tostring(UNITID)))
						trigger.action.outText("EMBD.LogisticUnload ha registrato un atterraggio da unità non decollata, unità: " .. tostring(UNITID), 10)
					end
				end			
			end
			
			
		end
	end
end
world.addEventHandler(EMBD.LogisticUnload)		

EMBD.LogisticLoad = {} 
function EMBD.LogisticLoad:onEvent(event)		
	if event.id == world.event.S_EVENT_TAKEOFF and dbWeapon then -- 3						
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
				tblLogCollect[UNITID] = {unit = UNIT, init_ammo = UNITAMMO, init_place = UNITPLACE, init_fuel = UNITFUEL, desc = UNITDESC, hits = 0, end_place = "none", end_ammo = "none", end_fuel = "none"}  -- changed UNITPLACE with placeName, due to enumerator refactor in 2.5.6
				if DSMC_debugProcessDetail == true then
					env.info(("EMBD.LogisticLoad ha registrato un decollo, unità: " .. tostring(UNITID)))
					trigger.action.outText("EMBD.LogisticLoad ha registrato un decollo, unità: " .. tostring(UNITID), 10)
				end
			else
				trigger.action.outText("EMBD.LogisticLoad non ha potuto generare un decollo, unità: " .. tostring(UNITID) .. "" .. tostring(UNITAMMO) .. "" .. tostring(UNITFUEL) .. "" .. tostring(UNITDESC) .. "" .. tostring(placeName), 10)
			end
		end
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
			trigger.action.outText("EMBD.LogisticTOrecord ha registrato un decollo, unità: " .. tostring(unitId), 10)
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
				env.info(("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", category: " .. tostring(unitCategory)))
				trigger.action.outText("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", category: " .. tostring(unitCategory), 10)
			end			
			
			if unitCategory == 1 then
				local unitId		= unit:getID()
				local unitair  	= unit:hasAttribute("Air")
				if unitair == true then
					for uid, udata in pairs(tblLogCollect) do
						if unitId == uid then
							udata.hits = udata.hits + 1
							if DSMC_debugProcessDetail == true then
								env.info(("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", colpi totali: " .. tostring(udata.hits)))
								trigger.action.outText("EMBD.assetHit ha registrato un colpo, unità: " .. tostring(unitTypeName) .. ", colpi totali: " .. tostring(udata.hits), 10)
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
		env.info(("EMBD.baseCapture started"))
		local conquer = event.initiator
		local base = event.place
		local conquerCoa = conquer:getCoalition()
		local conquerCountry = conquer:getCountry()
		local baseID = base:getID()
		local baseName = base:getName()
		--local baseDesc = base:getDesc()	
		local baseTYPE = nil		
		
		if base:hasAttribute("Helipad") or base:hasAttribute("Ships")  then
			baseTYPE = "warehouses"
		else
			baseTYPE = "airports"
		end	
	
		env.info(("EMBD.baseCapture ha registrato un cambio di fazione della base: " .. tostring(baseName)))
		trigger.action.outText("EMBD.baseCapture ha registrato un cambio di fazione della base: " .. tostring(baseID), 10)

		tblConquer[#tblConquer+1] = {id = baseID, name = baseName, coa = conquerCoa, country = conquerCountry, baseType = baseTYPE}
		env.info(("EMBD.baseCapture tblConquer populated"))
		
	end
end
world.addEventHandler(EMBD.baseCapture)	
	
EMBD.collectSpawned = {} -- CONTROLLA COMPORTAMENTO CON STATIC E CRATES
function EMBD.collectSpawned:onEvent(event)
	if event.id == world.event.S_EVENT_BIRTH and timer.getTime0() < timer.getAbsTime() then
		if event.initiator:hasAttribute("Air") == false then
			if Object.getCategory(event.initiator) == 1 then
				if not Unit.getPlayerName(event.initiator) then
					env.info(("EMBD.collectSpawned started"))
					local ei_gName = Unit.getGroup(event.initiator):getName()
					local ei = Unit.getGroup(event.initiator)
					local ei_pos = event.initiator:getPosition().p
					local ei_unitTableSource = ei:getUnits()
					local ei_unitTable = {}
					local ei_coalition = ei:getCoalition()
					local ei_country = event.initiator:getCountry()
					local ei_ID = ei:getID()
					local ei_Altitude = land.getHeight({x = ei_pos.x, y = ei_pos.z})
					env.info(("EMBD.collectSpawned data collected"))
					if ei_unitTableSource and #ei_unitTableSource > 0 then
						for _id, _eiUnitData in pairs(ei_unitTableSource) do
							if DSMC_trackspawnedinfantry then
								ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
							else
								if not _eiUnitData:hasAttribute("Infantry") then  -- infantry wont't be tracked
									ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
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
			elseif Object.getCategory(event.initiator) == 3 then
				local _eiUnitData = event.initiator
				local ei_gName = StaticObject.getName(event.initiator)
				local ei = StaticObject.getByName(ei_gName)
				local ei_pos = ei:getPosition().p
				--local ei_unitTableSource = ei:getUnits()
				local ei_unitTable = {}
				local ei_coalition = ei:getCoalition()
				local ei_country = event.initiator:getCountry()
				local ei_ID = ei:getID()
				
				if ei_gName then
					ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true}
				end

				if ei and not tblSpawned[ei_gName] then
					tblSpawnedcounter = tblSpawnedcounter + 1
					tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(event.initiator), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "static", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}
					
				end
			elseif Object.getCategory(event.initiator) == 6 then -- cargo
				local _eiUnitData = event.initiator
				local ei_gName = StaticObject.getName(event.initiator)
				local ei = StaticObject.getByName(ei_gName)
				local ei_pos = ei:getPosition().p
				--local ei_unitTableSource = ei:getUnits()
				local ei_unitTable = {}
				local ei_coalition = ei:getCoalition()
				local ei_country = event.initiator:getCountry()
				local ei_ID = ei:getID()
				local ei_Weight = event.initiator:getCargoWeight()
				
				if ei_gName then
					ei_unitTable[#ei_unitTable+1] = {uID = tonumber(_eiUnitData:getID()), uName = _eiUnitData:getName(), uPos = _eiUnitData:getPosition().p, uType = _eiUnitData:getTypeName(), uDesc = _eiUnitData:getDesc(), uAlive = true, uWeight = ei_Weight}
				end

				if ei and not tblSpawned[ei_gName] then
					tblSpawnedcounter = tblSpawnedcounter + 1
					tblSpawned[ei_gName] = {gID = tonumber(ei_ID), gCat = Object.getCategory(event.initiator), gAlt= ei_Altitude, gName = ei_gName, gCoalition = ei_coalition, gCountry = ei_country, gType = "static", gCounter = tblSpawnedcounter, gTable = ei, gPos = ei_pos, gUnits = ei_unitTable, gStaticAlive = true}					
				end			

			end
		end
	end
end
world.addEventHandler(EMBD.collectSpawned)
--]]--



--### FUNCTION LAUNCH FEATURES

-- at the end this should be removed for the campaign... maybe?
EMBD.createRadioMenu = function()
	--[[
	local menuBlue = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "DSMC")
	missionCommands.addCommandForCoalition(coalition.side.BLUE, "Save scenery", menuBlue, EMBD.oncallworkflow, "auto")
	
	local menuRed = missionCommands.addSubMenuForCoalition(coalition.side.RED, "DSMC")
	missionCommands.addCommandForCoalition(coalition.side.RED, "Save scenery", menuRed, EMBD.oncallworkflow, "auto")
	
	]]--
	missionCommands.addCommand("DSMC - save progress", nil, EMBD.executeSAVE, "recall")
	--missionCommands.addCommand("DSMC - save progress 1 min", nil, EMBD.oncallworkflowRet)
	
	if DSMC_debugProcessDetail == true then
		env.info(("EMBD.CreateRadioMenu ok"))
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
	
--### SET FUNCTIONS

--check vars for debug
env.info(("EMBD: DSMC variable settings: DSMC_multy = " ..tostring(DSMC_multy)))
env.info(("EMBD: DSMC variable settings: DSMC_server = " ..tostring(DSMC_server)))
env.info(("EMBD: DSMC variable settings: DSMC_debugProcessDetail = " ..tostring(DSMC_debugProcessDetail)))
env.info(("EMBD: DSMC variable settings: DSMC_autosavefrequency = " ..tostring(DSMC_autosavefrequency)))

--do functions
EMBD.getAptInfo()
EMBD.createRadioMenu()
if DSMC_autosavefrequency then
	timer.scheduleFunction(EMBD.scheduleAutosave, {}, timer.getTime() + tonumber(DSMC_autosavefrequency))
end

