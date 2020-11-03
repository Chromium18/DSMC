-- Dynamic Sequential Mission Campaign -- UTIL module

local ModuleName  	= "UTIL"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0100"
local Date			= "17/10/2020"

-- ## LIBS
module('UTIL', package.seeall)
local require 		= _G.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

-- ## DEBUG


HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
UTILloaded						= false

-- ## UTILS
function copyFile(old, new)
	local i = io.open(old, "r")
	local o = io.open(new, "w")
	if i then
		o:write(i:read("*a"))
		o:close()
		i:close()
	end		
end

function moveFile(old, new)
   copyFile(old, new)
   os.remove(old)
end

function get2Ddistance(point1, point2)

    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function fileExist(name)
	local f=io.open(name,"r")
	if f~=nil then 
		io.close(f)
		return true 
	else 
		io.close(f) 
		return false 
	end
end

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
	if lfs and io then
		local fdir = lfs.writedir() .. [[DSMC\Debug\]] .. fname
		local f = io.open(fdir, 'w')
		f:write(tableShow(tabledata))
		f:close()
	end
end

function saveTable(fname, tabledata, savedir)
	local filespath = savedir
	if io then
		local fdir = filespath .. fname .. ".lua"
		local f = io.open(fdir, 'w')
		local str = IntegratedserializeWithCycles(fname, tabledata)
		f:write(str)
		f:close()
	end
end

function inJectTable(Table_name, Table_code)	
	local tbl_serial = IntegratedserializeWithCycles(Table_name, Table_code)	
	local str, strErr = net.dostring_in("mission", "a_do_script(" .. "[===[" .. tbl_serial .. "]===]" .. ")")
	if not strErr then
		HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", str= " .. tostring("a_do_script(" .. "[===[" .. tbl_serial .. "]===]" .. ")") )
	else
		HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", " .. tostring(Table_name) .. " loaded in mission env" )
	end
end

function inJectCode(Code_name, CodeString)		
	local str, strErr = net.dostring_in("mission", "a_do_script(" .. "[===[" .. CodeString .. "]===]" .. ")")	
	if not strErr then
		HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", str: " .. tostring(str))
	else
		HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", " .. tostring(Code_name) .. " loaded in mission env" )
	end
end

-- #### UNITS DATA INFO UTILITIES
function dbYearsBuilder()
	if _G.dbYears then	
		UTIL.dumpTable("dbYears.lua", _G.dbYears) 
		-- funziona già così!
	end
end
--dbYearsBuilder()

-- #### CAMPAIGN BUILD UTILITIES, MANUAL CONTROLLED ####
local DB = require('me_db_api')
--UTIL.dumpTable("DB.lua", DB) 

local xEnv = {}
local basicPylonDB = {}
function basicPylonDB_builder(database)
	local tempPdb = {}
	--populate index
	for dbId, dbData in pairs(database) do
		if dbId == "unit_by_type" then
			for uType, uData in pairs(dbData) do
				for cId, cData in pairs(uData) do
					if cId == "attribute" then
						for aId, aData in pairs(cData) do
							if aData == "Planes" or aData == "Helicopters" then
								local addfuel = 0
								if uData.MaxFuelWeight then
									addfuel = tonumber(uData.MaxFuelWeight)
								end
								tempPdb[uType] = {pylons = {}, fuel = addfuel}
							end
						end
					end
				end
			end
		end
	end
	--UTIL.dumpTable("tempPdb_a.lua", tempPdb) 

	-- populate pylons
	for hId, hData in pairs(tempPdb) do
		if hData.pylons then
			for dbId, dbData in pairs(database) do
				if dbId == "unit_by_type" then
					for uType, uData in pairs(dbData) do
						if uType == hId then
							if uData.Pylons then
								--local Piloni = {}
								for pId, pData in pairs(uData.Pylons) do
									hData.pylons[pId] = {}
									
									if pData.Launchers then
										for lId, lData in pairs(pData.Launchers) do
											if lData.CLSID then
												hData.pylons[pId][lData.CLSID] = {}
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
	--UTIL.dumpTable("tempPdb_b.lua", tempPdb) 

	-- populate wpnInfo
	for hId, hData in pairs(tempPdb)do
		if hData.pylons then
			--HOOK.writeDebugDetail(ModuleName .. ": x1")
			for bId, bData in pairs(hData.pylons)do
				--for pyId, pyData in pairs(bData) do
					for clId, clData in pairs(bData) do -- pyData
						--HOOK.writeDebugDetail(ModuleName .. ": x2")

						for dbId, dbData in pairs(database) do
							if dbId == "category_by_weapon_CLSID" then
								for cId, cData in pairs(dbData) do
									if cData.Launchers then
										for wId, wData in pairs(cData.Launchers) do
											
											-- check direct weapons
											if wData.CLSID then
												if tostring(wData.CLSID) == tostring(clId) then
													--HOOK.writeDebugDetail(ModuleName .. ": x3")
													local attrTbl 	= wData.attribute
													local wsTble 	= wData.wsTypeOfWeapon
													local wpnName 	= wData.displayName
													local wpnweight	= wData.Weight
													local wpnCount	= wData.Count
													--HOOK.writeDebugDetail(ModuleName .. ": wpnDBbuilder, aircraft: " .. tostring(bId) ..  ", adding: " .. tostring(wpnName))

													bData[clId] = {name = wpnName, wsType = wsTble, attrType = attrTbl, weight = wpnweight, count = wpnCount} -- pyData
												end
											end
										end	
									end
								end
							end
						end
					end
				--end
			end
		end
	end
	--UTIL.dumpTable("tempPdb_c.lua", tempPdb) 
	return tempPdb
end

local wpnDB = {}
function wpnDB_builder(pDB)    -- pDB level index: a = aircraft, p = pylon, w = weapon / wpnDB index: acf = aircraft, wpn = weapon
	local tempWdb = {}
	if pDB then
		for aType, aData in pairs(pDB) do
			HOOK.writeDebugDetail(ModuleName .. ": aType: " .. tostring(aType))
			--if aData.pylons then -- if table.getn(aData) > 0 then
				local a_check = false
				local currentTbl = nil
				if table.getn(tempWdb) > 0 then
					for iaId, iaData in pairs(tempWdb) do
						HOOK.writeDebugDetail(ModuleName .. ": iaId: " .. tostring(iaId))
						if iaId == aType then
							a_check = true
							currentTbl = iaData
							HOOK.writeDebugDetail(ModuleName .. ": wpnDB_builder, found currentTbl")
						end
					end
				end

				HOOK.writeDebugDetail(ModuleName .. ": a_check: " .. tostring(a_check))
				if a_check == false then
					--wpnDB[aType] = currentTbl
					currentTbl = {pylons = {}, fuel = aData.fuel}
				end

				-- da qui.
				if currentTbl.fuel == nil then
					currentTbl.fuel = 0
					HOOK.writeDebugDetail(ModuleName .. ": wpnDB_builder, fuelerror")
				end

				if currentTbl.pylons then -- currentTbl
					for pId, pData in pairs(aData.pylons) do
						for wId, wData in pairs(pData) do				
							local wpn_check = false
							--for acfId, acfData in pairs(currentTbl) do
								--if table.getn(acfData) > 0 then   
									for wpnId, wpnData in pairs(currentTbl.pylons) do -- acfData
										if wpnData.name == wData.name then
											wpn_check = true
											local qty = 1
											if wData.count then
												qty = wData.count
											end
											wpnData.num = wpnData.num + qty
										end
									end
								--end
							--end

							if wpn_check == false then
								local qty = 1
								if wData.count then
									qty = wData.count
								end					
								
								local ws = wData.wsType
								local at = wData.attrType
								--[[
								if wData.wsType then
									ws = wData.wsType
								elseif wData.attrType then
									ws = wData.attrType
								else
									ws = "none"
								end
								--]]--

								currentTbl.pylons[#currentTbl.pylons+1] = {name = wData.name, num = qty, wsStr = ws, atStr = at, weight = wData.weight}
							end

						end
					end
				
					tempWdb[aType] = currentTbl
				else
					HOOK.writeDebugDetail(ModuleName .. ": wpnDB_builder, error 1")

				end

				
			--end
		end

		return tempWdb
	else
		HOOK.writeDebugDetail(ModuleName .. ": wpnDB_builder, pDB nil")
	end
end

if HOOK.SBEO_var == true then
	HOOK.writeDebugDetail(ModuleName .. ": HOOK.SBEO_var true")
	if fileExist(HOOK.DSMCdirectory .. "wpnDB.lua") then
		local f = io.open(HOOK.DSMCdirectory ..  "wpnDB.lua", 'r')
		if f then
			local fileContent = f:read('*all')
			f:close()
			local strFun = loadstring(fileContent)
			if strFun then
				setfenv(strFun, xEnv)
				strFun()
				HOOK.writeDebugDetail(ModuleName .. ": used existing, wpnDB.lua")

				if xEnv.wpnDB then
					wpnDB = xEnv.wpnDB
				end
			end
		end

	else

		if fileExist(HOOK.DSMCdirectory ..  "basicPylonDB.lua") then
			local f = io.open(HOOK.DSMCdirectory ..  "basicPylonDB.lua", 'r')
			if f then
				local fileContent = f:read('*all')
				f:close()
				local strFun = loadstring(fileContent)
				if strFun then	
					setfenv(strFun, xEnv)
					strFun()
					HOOK.writeDebugDetail(ModuleName .. ": used existing, basicPylonDB.lua")
					--UTIL.dumpTable("basicPylonDB_xEnv.lua", xEnv.basicPylonDB) 
					
					if xEnv.basicPylonDB then
						basicPylonDB = xEnv.basicPylonDB
					end	

				end
			end

		else
			basicPylonDB = basicPylonDB_builder(DB)
			UTIL.dumpTable("basicPylonDB_fine.lua", basicPylonDB) 
			local bName = "basicPylonDB.lua"
			local bpath = HOOK.DSMCdirectory .. bName
			local boutFile = io.open(bpath, "w");
			local bStr = Integratedserialize("basicPylonDB", basicPylonDB)
			boutFile:write(bStr);
			io.close(boutFile);
		end
		wpnDB = wpnDB_builder(basicPylonDB)
		UTIL.dumpTable("wpnDB_fine.lua", wpnDB) 
		local fName = "wpnDB.lua"
		local path = HOOK.DSMCdirectory .. fName
		local outFile = io.open(path, "w");
		local fStr = Integratedserialize("wpnDB", wpnDB)
		outFile:write(fStr);
		io.close(outFile);
		UTIL.dumpTable("basicPylonDB_loaded.lua", basicPylonDB) 
		UTIL.dumpTable("wpnDB_loaded.lua", wpnDB) 

	end
end

-- this is OK
function makeWhZero(whData, whTbl)
	local zWpn = nil
	local zAcf = nil
	for ztId, ztData in pairs(whTbl) do			
		for zbId, zbData in pairs(ztData) do
			if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false then

				HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: found limited base")


				-- zero weapons
				for wId, wData in pairs(zbData.weapons) do
					wData.initialAmount = 0
				end
				zWpn = zbData.weapons

				-- zero aircraft
				HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: zeroing aircraft also")
				for aTy, aTyData in pairs(zbData.aircrafts) do
					for aId, aData in pairs(aTyData) do
						aData.initialAmount = 0
					end
				end	
				zAcf = zbData.aircrafts
				HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: reset complete")

				break
			end
		end
	end
	
	if zAcf and zWpn then
		bData = whData

		-- zero fuel
		bData.gasoline.InitFuel 			= 0
		bData.diesel.InitFuel 				= 0
		bData.methanol_mixture.InitFuel 	= 0
		bData.jet_fuel.InitFuel 			= 0

		-- reset parameters
		bData.unlimitedMunitions  			= false
		bData.unlimitedFuel					= false
		bData.unlimitedAircrafts			= false

		-- reset others
		bData.OperatingLevel_Air			= 1
		bData.OperatingLevel_Eqp			= 1
		bData.OperatingLevel_Fuel			= 1
		bData.speed						= 1
		bData.size							= 1
		bData.periodicity					= 1000
		bData.suppliers					= {}				

		-- reset weapons & aircrafts
		bData.weapons = zWpn
		bData.aircrafts = zAcf

		return bData

	else
		HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: zTbl not identified")
	end

end

function getZeroedAirbase(whTbl)
	local zWpn = nil
	local zAcf = nil
	for ztId, ztData in pairs(whTbl) do			
		for zbId, zbData in pairs(ztData) do
			if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false then

				HOOK.writeDebugDetail(ModuleName .. ": zeroWarehouse: found limited base")


				-- zero weapons
				for wId, wData in pairs(zbData.weapons) do
					wData.initialAmount = 0
				end
				zWpn = zbData.weapons

				-- zero aircraft
				HOOK.writeDebugDetail(ModuleName .. ": zeroWarehouse: zeroing aircraft also")
				for aTy, aTyData in pairs(zbData.aircrafts) do
					for aId, aData in pairs(aTyData) do
						aData.initialAmount = 0
					end
				end	
				zAcf = zbData.aircrafts
				HOOK.writeDebugDetail(ModuleName .. ": zeroWarehouse: reset complete")

				break
			end
		end
	end
	
	if zAcf and zWpn then
		for tId, tData in pairs(whTbl) do			
			for bId, bData in pairs(tData) do
				
				
				-- zero fuel
				bData.gasoline.InitFuel 			= 0
				bData.diesel.InitFuel 				= 0
				bData.methanol_mixture.InitFuel 	= 0
				bData.jet_fuel.InitFuel 			= 0

				-- reset parameters
				bData.unlimitedMunitions  			= false
				bData.unlimitedFuel					= false
				bData.unlimitedAircrafts			= false

				-- reset others
				bData.OperatingLevel_Air			= 1
				bData.OperatingLevel_Eqp			= 1
				bData.OperatingLevel_Fuel			= 1
				bData.speed						= 1
				bData.size							= 1
				bData.periodicity					= 1000
				bData.suppliers					= {}				

				-- reset weapons & aircrafts
				bData.weapons = zWpn
				bData.aircrafts = zAcf

			end
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": zeroWarehouse: zTbl not identified")
	end
end

local wpnMultiplier = 1 
function setWeaponsAndFuel(whData, wpnDb)
	if whData.jet_fuel.InitFuel and whData.aircrafts.helicopters and whData.aircrafts.planes and table.getn(whData.weapons) > 0 then
		local fuelTot = 0
		for aCat, aIndex in pairs(whData.aircrafts) do
			for aType, aData in pairs(aIndex) do
				local acfQuantity = aData.initialAmount
				if acfQuantity > 0 then
					for bType, bData in pairs(wpnDb) do
						if aType == bType then
							if bData.fuel then
								if type(bData.fuel) == "number" then
									fuelTot = fuelTot + (bData.fuel * wpnMultiplier * acfQuantity)/1000
									HOOK.writeDebugDetail(ModuleName .. ": fuel updated")
								end
							end
							
							if bData.pylons then
								for wId, wData in pairs(whData.weapons) do
									local wString = wsTypeToString(wData.wsType)
									for waId, waData in pairs(bData.pylons) do
										local waString = "none"
										local atString = "none"
										
										if waData.wsStr then
											waString = wsTypeToString(waData.wsStr)
										end
										if waData.atStr then
											atString = wsTypeToString(waData.atStr)
										end

										local check_ws = false
										if wString == waString then
											wData.initialAmount = wData.initialAmount + waData.num * wpnMultiplier * acfQuantity
											HOOK.writeDebugDetail(ModuleName .. ": wpn updated using waString")
											check_ws = true
										end
 
										if check_ws == false then
											if wString == atString then
												wData.initialAmount = wData.initialAmount + waData.num * wpnMultiplier * acfQuantity
												HOOK.writeDebugDetail(ModuleName .. ": wpn updated using atString")
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

		whData.jet_fuel.InitFuel = fuelTot

		return whData
	else
		HOOK.writeDebugDetail(ModuleName .. ": setWeaponsAndFuel, error on data format, missing correct structure")
	end
end

local depositMultiplier = 5

function whRestart(warehouse, airbases, mission)
	local supplynet = {deposit = {}, airports = {}, farps  = {}}

	-- this will make unlimited wh void
	local stepDone = false
	for hCat, hIndex in pairs(warehouse) do
		for hId, hData in pairs(hIndex) do
			if hData.unlimitedMunitions == true or hData.unlimitedAircrafts == true or hData.unlimitedFuel == true then
				local voidTable = makeWhZero(hData, warehouse)
				hId = voidTable
			end
		end
	end
	UTIL.dumpTable("whnuovo_a.lua", warehouse)

	-- this will auto-add weapons & fuel to airports & FARP
	for hCat, hIndex in pairs(warehouse) do
		if hCat == "airports" then
			for hId, hData in pairs(hIndex) do
				for aId, aData in pairs(airbases) do
					if aData.desc.attributes.Airfields then
						if tonumber(hId) == tonumber(aData.id) then
							HOOK.writeDebugDetail(ModuleName .. ": found airbase, id: " .. tostring(aData.id) .. ", name: " .. tostring(aData.desc.displayName))		
							local update = setWeaponsAndFuel(hData, xEnv.wpnDB)
							UTIL.dumpTable("update.lua", update)
							hIndex[hId] = update
							HOOK.writeDebugDetail(ModuleName .. ": airbase, id: " .. tostring(aData.id) .. " reset done")
							supplynet.airports[#supplynet.airports+1] = {Id = hId, type = hCat}
						end
					end
				end
			end
		elseif hCat == "warehouses" then
			for hId, hData in pairs(hIndex) do
				for aId, aData in pairs(airbases) do
					if not aData.desc.attributes.Airfields then
						if tonumber(hId) == tonumber(aData.id) then
							HOOK.writeDebugDetail(ModuleName .. ": found helipad or ship, id: " .. tostring(aData.id) .. ", name: " .. tostring(aData.desc.displayName))		
							local update = setWeaponsAndFuel(hData, xEnv.wpnDB)
							hIndex[hId] = update
							HOOK.writeDebugDetail(ModuleName .. ": helipad or ship, id: " .. tostring(aData.id) .. " reset done")
							if not aData.desc.attributes.AircraftCarrier then
								supplynet.farps[#supplynet.farps+1] = {Id = hId, type = hCat}
							end
						end
					end
				end
			end
		end
	end
	UTIL.dumpTable("whnuovo_b.lua", warehouse)
	
	-- this will calculate the total amount of any resources in any coalition
	local WhTotals = { blue = {weapons = {}, fuel = 0} , red = {weapons = {}, fuel = 0} , neutrals = {weapons = {}, fuel = 0}}
	for hCat, hIndex in pairs(warehouse) do
		for hId, hData in pairs(hIndex) do
			for coa, coaData in pairs(WhTotals) do
				if string.lower(hData.coalition) == string.lower(coa) then
					if hData.jet_fuel.InitFuel then
						if hData.jet_fuel.InitFuel > 0 then
							coaData.fuel = coaData.fuel + hData.jet_fuel.InitFuel * depositMultiplier
						end
					end

					for wId, wData in pairs(hData.weapons) do
						if wData.initialAmount > 0 then
							local ws1 = wsTypeToString(wData.wsType)
							if table.getn(coaData.weapons) > 0 then
								local isThere = false
								for uId, uData in pairs(coaData.weapons) do
									local ws2 = wsTypeToString(uData.wsType)
									if ws1 == ws2 then
										uData.initialAmount = uData.initialAmount + wData.initialAmount * depositMultiplier
										isThere = true
									end
								end

								if isThere == false then
									coaData.weapons[#coaData.weapons+1] = {wsType = wData.wsType, initialAmount = wData.initialAmount * depositMultiplier }
								end
							else
								coaData.weapons[#coaData.weapons+1] = {wsType = wData.wsType, initialAmount = wData.initialAmount * depositMultiplier }
							end
						end
					end
				end
			end
		end
	end
	UTIL.dumpTable("WhTotals.lua", WhTotals) 
	UTIL.dumpTable("whnuovo_c.lua", warehouse)

	-- this will automatically populate stock warehouses as deposit
	for hCat, hIndex in pairs(warehouse) do
		if hCat == "warehouses" then
			for bId, bData in pairs(hIndex) do
				HOOK.writeDebugDetail(ModuleName .. ": checking id: " .. tostring(bId))
				for _coalitionName, _coalitionData in pairs(mission.coalition) do
					if type(_coalitionData) == 'table' then
						if _coalitionData.country then --there is a country table
							for _, _countryData in pairs(_coalitionData.country) do
					
								if type(_countryData) == 'table' then
									for _objectTypeName, _objectTypeData in pairs(_countryData) do
										if _objectTypeName == "static" then
											HOOK.writeDebugDetail(ModuleName .. ": static found")
											if ((type(_objectTypeData) == 'table')
													and _objectTypeData.group
													and (type(_objectTypeData.group) == 'table')
													and (#_objectTypeData.group > 0)) then
					
												for _groupId, _group in pairs(_objectTypeData.group) do
													if _group and _group.units and type(_group.units) == 'table' then
														for _unitNum, _unit in pairs(_group.units) do
															HOOK.writeDebugDetail(ModuleName .. ": _unit.category: " .. tostring(_unit.category))			
															if _unit.category == "Warehouses" then
																HOOK.writeDebugDetail(ModuleName .. ": _unit.unitId: " .. tostring(_unit.unitId) .. ", bId: " .. tostring(bId))
																if tonumber(_unit.unitId) == tonumber(bId) then
																	HOOK.writeDebugDetail(ModuleName .. ": found warehouse object, id: " .. tostring(_unit.unitId) .. ", type: " .. tostring(_unit.type))		

																	if _unit.type == "Tank" or _unit.type == "Tank2" or _unit.type == "Tank3" then
																		-- zero fuel
																		bData.gasoline.InitFuel 			= 0
																		bData.diesel.InitFuel 				= 0
																		bData.methanol_mixture.InitFuel 	= 0
																		bData.jet_fuel.InitFuel 			= 3000

																		-- reset parameters
																		bData.unlimitedMunitions  			= false
																		bData.unlimitedFuel					= false
																		bData.unlimitedAircrafts			= false

																		-- reset others
																		bData.OperatingLevel_Air			= 1
																		bData.OperatingLevel_Eqp			= 1
																		bData.OperatingLevel_Fuel			= 1
																		bData.speed							= 1
																		bData.size							= 1
																		bData.periodicity					= 1000
																		bData.suppliers						= {}				

																		-- reset weapons & aircrafts
																		--bData.weapons 					= {}
																		--bData.aircrafts 					= {}
																		
																		supplynet.deposit[#supplynet.deposit+1] = {Id = bId, type = hCat}

																	elseif _unit.type == ".Ammunition depot" or _unit.type == "Warehouse" then
																		-- zero fuel
																		bData.gasoline.InitFuel 			= 0
																		bData.diesel.InitFuel 				= 0
																		bData.methanol_mixture.InitFuel 	= 0
																		bData.jet_fuel.InitFuel 			= 0

																		-- reset parameters
																		bData.unlimitedMunitions  			= false
																		bData.unlimitedFuel					= false
																		bData.unlimitedAircrafts			= false

																		-- reset others
																		bData.OperatingLevel_Air			= 1
																		bData.OperatingLevel_Eqp			= 1
																		bData.OperatingLevel_Fuel			= 1
																		bData.speed							= 1
																		bData.size							= 1
																		bData.periodicity					= 1000
																		bData.suppliers						= {}				

																		-- reset weapons & aircrafts
																		--HOOK.writeDebugDetail(ModuleName .. ": f1")
																		for wId, wData in pairs(bData.weapons) do
																			local ws1 = wsTypeToString(wData.wsType)																			
																			for coa, coaData in pairs(WhTotals) do
																				if string.lower(coa) == string.lower(_coalitionName) then
																					--HOOK.writeDebugDetail(ModuleName .. ": f2")
																					if table.getn(coaData.weapons) > 0 then
																						for xId, xData in pairs(coaData.weapons) do
																							local ws2 = wsTypeToString(xData.wsType)
																							if ws1 == ws2 then
																								HOOK.writeDebugDetail(ModuleName .. " xData.initialAmount: " .. tostring(xData.initialAmount))
																								bData.weapons[wId] = xData
																								--wData.InitialAmount = xData.InitialAmount
																							end																						
																						end																						
																					end
																				end
																			end
																		end

																		supplynet.deposit[#supplynet.deposit+1] = {Id = bId, type = hCat}
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

	UTIL.dumpTable("supplynet.lua", supplynet)
	UTIL.dumpTable("whnuovo_d.lua", warehouse)

	-- create the supply net
	HOOK.writeDebugDetail(ModuleName .. " creating supply net")
	for hCat, hIndex in pairs(warehouse) do
		if hCat == "airports" then
			for hId, hData in pairs(hIndex) do
				if hData.suppliers then		
					for sCat, sIndex in pairs(supplynet) do
						if sCat == "deposit" or sCat == "airports" then
							for sId, sData in pairs(sIndex) do
								if tonumber(sData.Id) ~= tonumber(hId) then
									hData.suppliers[#hData.suppliers+1] = sData
								end
							end
						end
					end
				end
			end
		elseif hCat == "warehouses" then
			HOOK.writeDebugDetail(ModuleName .. " b1")
			for hId, hData in pairs(hIndex) do
				--HOOK.writeDebugDetail(ModuleName .. " checking: " .. tostring(hId))
				if hData.suppliers then		
					--HOOK.writeDebugDetail(ModuleName .. " b1a")
					local isFARP = false
					
					for sCat, sIndex in pairs(supplynet) do
						if sCat == "farps"then
							--HOOK.writeDebugDetail(ModuleName .. " b1b")
							if table.getn(sIndex) > 0 then
								--HOOK.writeDebugDetail(ModuleName .. " b1c")
								for sId, sData in pairs(sIndex) do
									--HOOK.writeDebugDetail(ModuleName .. " sData.Id: " .. tostring(sData.Id) .. ", hId: " .. tostring(hId))
									if tostring(sData.Id) == tostring(hId) then
										--HOOK.writeDebugDetail(ModuleName .. " b2")
										isFARP = true
									end
								end
							end
						end
					end

					if isFARP == true then
						HOOK.writeDebugDetail(ModuleName .. " b3")
						for sCat, sIndex in pairs(supplynet) do
							if sCat == "deposit" or sCat == "airports" then
								for sId, sData in pairs(sIndex) do
									if tonumber(sData.Id) ~= tonumber(hId) then
										--HOOK.writeDebugDetail(ModuleName .. " b4")
										hData.suppliers[#hData.suppliers+1] = sData
									end
								end
							end
						end
					end

					--HOOK.writeDebugDetail(ModuleName .. " c1")
				end
				--HOOK.writeDebugDetail(ModuleName .. " c2")
			end
			--HOOK.writeDebugDetail(ModuleName .. " c3")
		end
		--HOOK.writeDebugDetail(ModuleName .. " c4")
	end
	HOOK.writeDebugDetail(ModuleName .. " c5")

	UTIL.dumpTable("whnuovo_e.lua", warehouse) 
end



HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
UTILloaded = true
--UTIL.dumpTable("_G.lua", _G) 
--~=


local bName = "dbYears.lua"
local bpath = HOOK.DSMCdirectory .. bName
local boutFile = io.open(bpath, "w");
local bStr = Integratedserialize("TRPS.dbYears", _G.dbYears)
boutFile:write(bStr);
io.close(boutFile);