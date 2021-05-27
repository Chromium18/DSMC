-- Dynamic Sequential Mission Campaign -- UTIL module

local ModuleName  	= "UTIL"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

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
tblFARP 						= {}
--basic_fuel_amount				= 6
--basic_AGM_amount				= 30
--basic_RCK_amount				= 100

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

function filterNamingTables(mission)	 -- DICTPROBLEM: dictionary

	HOOK.writeDebugDetail(ModuleName .. ": tblFOBnames starting items: " .. tostring(#tblFOBnames))
	
	--DICTPROBLEM (added with new structure)
	for coalitionID,coalition in pairs(mission["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if (type(attr)=="table") then
					if attrID == "static" then
						for groupID,group in pairs(attr["group"]) do
							for unitID, unit in pairs(group["units"]) do	
								for aId, aData in pairs(tblFOBnames) do
									local dData = unit.name
									if string.find(dData, aData) then
										HOOK.writeDebugDetail(ModuleName .. ": tblFOBnames removing: " .. tostring(aData))
										table.remove(tblFOBnames, aId)
									end
								end										
							end
						end
					end
				end
			end
		end
	end

	--DICTPROBLEM (deleted with new structure)
	--[[
	for _, dData in pairs(dictionary) do
		if dData ~= "" then
		--filter FOB tables
			
			for aId, aData in pairs(tblFOBnames) do
				if string.find(dData, aData) then
					HOOK.writeDebugDetail(ModuleName .. ": tblFOBnames removing: " .. tostring(aData))
					table.remove(tblFOBnames, aId)
				end
			end
		end
	end
	--]]--

	HOOK.writeDebugDetail(ModuleName .. ": tblFOBnames items: " .. tostring(#tblFOBnames))
	if #tblFOBnames > 30 then
		inJectTable("tblFOBnames", tblFOBnames)
		HOOK.writeDebugDetail(ModuleName .. ": tblFOBnames incjected with items: " .. tostring(#tblFOBnames))
	else
		HOOK.writeDebugDetail(ModuleName .. ": tblFOBnames insufficient items, not injecting")
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

function addFARPwhBase(unitId, coa, wh, voidIt)
	HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase start for id: " .. tostring(unitId))

	local defaultWhTbl = {
		["gasoline"] = 
		{
			["InitFuel"] = 100,
		}, -- end of ["gasoline"]
		["unlimitedMunitions"] = true,
		["methanol_mixture"] = 
		{
			["InitFuel"] = 100,
		}, -- end of ["methanol_mixture"]
		["OperatingLevel_Air"] = 1,
		["diesel"] = 
		{
			["InitFuel"] = 100,
		}, -- end of ["diesel"]
		["speed"] = 1,
		["size"] = 200,
		["periodicity"] = 1000,
		["suppliers"] = 
		{
		}, -- end of ["suppliers"]
		["coalition"] = coa,
		["jet_fuel"] = 
		{
			["InitFuel"] = 100,
		}, -- end of ["jet_fuel"]
		["OperatingLevel_Eqp"] = 1,
		["unlimitedFuel"] = true,
		["aircrafts"] = 
		{
		}, -- end of ["aircrafts"]
		["weapons"] = 
		{
		}, -- end of ["weapons"]
		["OperatingLevel_Fuel"] = 1,
		["unlimitedAircrafts"] = true,
	}

	HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase default warehouse, all void but unlimited, created")

	local toZero = nil
	if voidIt then
		for ztId, ztData in pairs(wh) do			
			for zbId, zbData in pairs(ztData) do
				--HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase c2")
				if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false and zbData.unlimitedFuel == false then	
					toZero = zbData
					HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase found a fully not limited warehouse to void")
					--break
				end
			end
		end

		--HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase c3")

		if toZero then
			-- zero weapons
			HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase: zeroing weapons ")
			for wId, wData in pairs(toZero.weapons) do
				wData.initialAmount = 0
			end

			-- zero aircraft
			HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase: zeroing aircraft")
			for aTy, aTyData in pairs(toZero.aircrafts) do
				for aId, aData in pairs(aTyData) do
					aData.initialAmount = 0
				end
			end	
			
			-- zero fuel
			toZero.gasoline.InitFuel 			= 0
			toZero.diesel.InitFuel 				= 0
			toZero.methanol_mixture.InitFuel 	= 0
			toZero.jet_fuel.InitFuel 			= 0

			-- reset parameters
			toZero.unlimitedMunitions  			= false
			toZero.unlimitedFuel				= false
			toZero.unlimitedAircrafts			= false

			-- reset others
			toZero.OperatingLevel_Air			= 1
			toZero.OperatingLevel_Eqp			= 1
			toZero.OperatingLevel_Fuel			= 1
			toZero.speed						= 1
			toZero.size							= 200
			toZero.periodicity					= 1000
			toZero.suppliers					= {}

			defaultWhTbl = toZero

			HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase: warehouse has been set to all 0, id: " .. tostring(unitId))
		else
			HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase: no zero wh available")
		end
	end

	tblFARP[unitId] = defaultWhTbl
	HOOK.writeDebugDetail(ModuleName .. ": addFARPwhBase: added entry to tblFARP, id: " .. tostring(unitId))
end

function addFARPwh(wh)
	if tblFARP then
		HOOK.writeDebugDetail(ModuleName .. ": addFARPwh start!")
		--UTIL.dumpTable("tblFARP.lua", tblFARP)
		for _id, _FARPdata in pairs(tblFARP) do
			HOOK.writeDebugDetail(ModuleName .. ": checking id: " .. tostring(_id))
			wh["warehouses"][tonumber(_id)] = _FARPdata
			HOOK.writeDebugDetail(ModuleName .. ": addFARPwh adding warehouse entry for id: " .. tostring(_id))
			--for wCat, wIds in pairs(wh) do
			--	if wCat == "warehouses" then
			--		HOOK.writeDebugDetail(ModuleName .. ": addFARPwh adding warehouse entry for id: " .. tostring(_id))
			--		wIds[tostring(_id)] = _FARPdata
			--	end
			--end
		end
		tblFARP = {}
		--UTIL.dumpTable("wh.lua", wh)
		return wh
	end
	HOOK.writeDebugDetail(ModuleName .. ": addFARPwh done")
end




function makeWhZero(whData, whTbl, base_qty) -- used in whRestart
	local zWpn = nil
	local zAcf = nil
	for ztId, ztData in pairs(whTbl) do			
		for zbId, zbData in pairs(ztData) do
			if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false then

				HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: found limited base")

				-- zero weapons
				for wId, wData in pairs(zbData.weapons) do
					wData.initialAmount = base_qty or 0
				end
				zWpn = zbData.weapons

				-- zero aircraft
				HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: zeroing aircraft also")
				for aTy, aTyData in pairs(zbData.aircrafts) do
					for aId, aData in pairs(aTyData) do
						aData.initialAmount = base_qty or 0
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
		bData.gasoline.InitFuel 			= base_qty or 0
		bData.diesel.InitFuel 				= base_qty or 0
		bData.methanol_mixture.InitFuel 	= base_qty or 0
		bData.jet_fuel.InitFuel 			= base_qty or 0

		-- reset parameters
		bData.unlimitedMunitions  			= false
		bData.unlimitedFuel					= false
		bData.unlimitedAircrafts			= false

		-- reset others
		bData.OperatingLevel_Air			= 1
		bData.OperatingLevel_Eqp			= 1
		bData.OperatingLevel_Fuel			= 1
		bData.speed							= 1
		bData.size							= 200
		bData.periodicity					= 1000
		bData.suppliers						= {}				

		-- reset weapons & aircrafts
		bData.weapons = zWpn
		bData.aircrafts = zAcf

		return bData

	else
		HOOK.writeDebugDetail(ModuleName .. ": makeWhZero: zTbl not identified")
	end

end

function getZeroedAirbase(whTbl) -- used here and in SAVE
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
				bData.speed							= 1
				bData.size							= 200
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
																		bData.size							= 200
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
																		bData.size							= 200
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

function getUnlimitedWhTbl(sourceWhMizFile, base_qty)
	
	if sourceWhMizFile then
	
		local  whTableFileStr = nil
		HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl starting ")
		--TempMizPath = HOOK.tempmissionfilesdirectory .. HOOK.StartFilterCode .. "-tempfile.miz"
		--HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl TempMizPath: " .. tostring(TempMizPath))
		
		HOOK.writeDebugDetail(ModuleName .. ": minizip.unzOpen opening=" .. tostring(sourceWhMizFile))
		local zipFile, err = minizip.unzOpen(sourceWhMizFile, 'rb')
		HOOK.writeDebugDetail(ModuleName .. ": minizip.unzOpen loaded")
		zipFile:unzGoToFirstFile() --vai al primo file dello zip		
		local NewSaveresourceFiles = {}
		local CreatedDirectories = {}
		local function Unpack()
			while true do --scompattalo e passa al prossimo
				local filename = zipFile:unzGetCurrentFileName()
				HOOK.writeDebugDetail(ModuleName .. ": unzipping " .. tostring(filename))
				local BaseTempDir = lfs.writedir() .. "DSMC/Utils/warehouse_fix"
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
				NewSaveresourceFiles[filename] = fullPath
				
				if string.find(fullPath, "warehouses") then
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
							whTableFileStr = f:read('*all')
							f:close()
											
						end
					end										
				end
				
				if not zipFile:unzGoToNextFile() then 
					break
				end
			end
			return NewSaveresourceFiles, whTableFileStr
		end
		Unpack() -- execute the unpacking
		zipFile:unzClose()
		--zipFile = nil
		HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - unpack ok")
		
		local function deleteFiles()
			for file, fullPath in pairs(NewSaveresourceFiles) do
				local fileIsThere = UTIL.fileExist(fullPath)
				if fileIsThere == true then
					os.remove(fullPath)				
				end
			end
		end
		deleteFiles()	
		HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - files deleted")
		
		-- remove directories
		for id, path in pairs(CreatedDirectories) do		
			lfs.rmdir(path)
		end

		HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - dir removed ok")
		
		if whTableFileStr then
			HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - whTableFileStr returned")
			local wFun = loadstring(whTableFileStr)
			local wEnv = {}
			setfenv(wFun, wEnv)
			wFun()
			

			local wh = nil

			-- now check for fully limited wh and make it zero
			local whZeroed = false
			for hCat, hIndex in pairs(wEnv.warehouses) do
				for hId, hData in pairs(hIndex) do
					if hData.unlimitedMunitions == true and hData.unlimitedAircrafts == true and hData.unlimitedFuel == true then
						HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - found free wh")
						local voidTable = makeWhZero(hData, wEnv.warehouses, base_qty)
						wh = voidTable
						whZeroed = true
					end
				end
			end

			if whZeroed then
				wEnv = nil
				dumpTable("whFixer_wh.lua", wh)
				--local act, actErr = os.remove(sourceWhMizFile)
				--HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - act: " .. tostring(act))
				--HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - actErr: " .. tostring(actErr))
				HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - wh table returned")
				return wh
			else
				HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - unable to find a limite wh in the fixer file")
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - whTableFileStr not available!")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getUnlimitedWhTbl - sourceWhMizFile is not available")
	end

end

function getSourceWh(sourceWhMizFile)
	
	if sourceWhMizFile then
	
		local  whTableFileStr = nil
		HOOK.writeDebugDetail(ModuleName .. ": getSourceWh starting ")
		--TempMizPath = HOOK.tempmissionfilesdirectory .. HOOK.StartFilterCode .. "-tempfile.miz"
		--HOOK.writeDebugDetail(ModuleName .. ": getSourceWh TempMizPath: " .. tostring(TempMizPath))
		
		HOOK.writeDebugDetail(ModuleName .. ": minizip.unzOpen opening=" .. tostring(sourceWhMizFile))
		local zipFile, err = minizip.unzOpen(sourceWhMizFile, 'rb')
		HOOK.writeDebugDetail(ModuleName .. ": minizip.unzOpen loaded")
		zipFile:unzGoToFirstFile() --vai al primo file dello zip		
		local NewSaveresourceFiles = {}
		local CreatedDirectories = {}
		local function Unpack()
			while true do --scompattalo e passa al prossimo
				local filename = zipFile:unzGetCurrentFileName()
				HOOK.writeDebugDetail(ModuleName .. ": unzipping " .. tostring(filename))
				local BaseTempDir = lfs.writedir() .. "DSMC/Utils/warehouse_fix"
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
				NewSaveresourceFiles[filename] = fullPath
				
				if string.find(fullPath, "warehouses") then
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
							whTableFileStr = f:read('*all')
							f:close()
											
						end
					end										
				end
				
				if not zipFile:unzGoToNextFile() then 
					break
				end
			end
			return NewSaveresourceFiles, whTableFileStr
		end
		Unpack() -- execute the unpacking
		zipFile:unzClose()
		--zipFile = nil
		HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - unpack ok")
		
		local function deleteFiles()
			for file, fullPath in pairs(NewSaveresourceFiles) do
				local fileIsThere = UTIL.fileExist(fullPath)
				if fileIsThere == true then
					os.remove(fullPath)				
				end
			end
		end
		deleteFiles()	
		HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - files deleted")
		
		-- remove directories
		for id, path in pairs(CreatedDirectories) do		
			lfs.rmdir(path)
		end

		HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - dir removed ok")
		
		if whTableFileStr then
			HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - whTableFileStr returned")
			local wFun = loadstring(whTableFileStr)
			local wEnv = {}
			setfenv(wFun, wEnv)
			wFun()

			local whD = wEnv.warehouses
			wEnv = nil

			if whD then
				
				dumpTable("whFixer_source.lua", whD)
				os.remove(sourceWhMizFile)
				return whD
			else
				HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - whD missing")
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - whTableFileStr not available!")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getSourceWh - sourceWhMizFile is not available")
	end

end

function getAcfItemNumber(wh, whType, whId, acfId)
	for afbType, afbIds in pairs(wh) do
		if whType == afbType then

			for afbId, afbData in pairs(afbIds) do
				
				if afbId == whId then

					--HOOK.writeDebugDetail(ModuleName .. ": getAcfItemNumber, found same wh entry")
					if afbData.unlimitedAircrafts == false then
						for acfCat, acfData in pairs(afbData.aircrafts) do
							for aId, aData in pairs(acfData) do
								--HOOK.writeDebugDetail(ModuleName .. ": getAcfItemNumber, aId: " ..tostring(aId) .. ", acfId: " .. tostring(acfId))
								if aId == acfId then
									--HOOK.writeDebugDetail(ModuleName .. ": getAcfItemNumber, returning " .. tostring(aData.initialAmount) .. ", acfId: " .. tostring(acfId))
									return aData.initialAmount
								end
							end
						end
					else
						HOOK.writeDebugDetail(ModuleName .. ": getAcfItemNumber, unlimitedAircrafts is true, returning nil")
						return nil
					end
				end
			end
		end
	end
end

function getWpnItemNumber(wh, whType, whId, wpnStr)
	for afbType, afbIds in pairs(wh) do
		if whType == afbType then
			for afbId, afbData in pairs(afbIds) do

				if afbId == whId then
					--HOOK.writeDebugDetail(ModuleName .. ": getWpnItemNumber, wpnStr: " .. tostring(wpnStr))
					
					if afbData.unlimitedMunitions == false then
						for lId, lData in pairs(afbData.weapons) do
							local lWs = wsTypeToString(lData.wsType)
							if wpnStr == lWs then
								--HOOK.writeDebugDetail(ModuleName .. ": getWpnItemNumber, lData.initialAmount: " .. tostring(lData.initialAmount))
								return lData.initialAmount
							end
						end
					else
						HOOK.writeDebugDetail(ModuleName .. ": getWpnItemNumber, unlimitedMunitions is true, returning nil")
						return nil
					end
				end
			end
		end
	end
end

function getDefaultWh(wh, fwh)
	local twh = deepCopy(wh)
	for afbType, afbIds in pairs(twh) do
		for afbId, afbData in pairs(afbIds) do
			if afbData.unlimitedAircrafts == false then
				afbData.aircrafts = fwh.aircrafts
			end
			if afbData.unlimitedMunitions == false then
				afbData.weapons = fwh.weapons
			end			
		end
	end
	return twh
end

function fixWarehouse(warehouse, base_qty)
	-- source and fixer must be of the same scenery!!!!
	if not base_qty then
		base_qty = 0
	end

	local isFixer = fileExist(lfs.writedir() .. "Missions/DSMC_fix_warehouse.miz")
	
	if isFixer and warehouse then -- 
		local fixTbl = getUnlimitedWhTbl(lfs.writedir() .. "Missions/DSMC_fix_warehouse.miz", base_qty)
		local sourceTbl = warehouse
		local sCopy = deepCopy(sourceTbl)

		if fixTbl and sCopy then
			-- now iterate source to update any basic content with numbers
			local new_wh = getDefaultWh(sourceTbl, fixTbl)

			-- refill
			for afbType, afbIds in pairs(new_wh) do
				for afbId, afbData in pairs(afbIds) do
					HOOK.writeDebugDetail(ModuleName .. ": fixWarehouse - fixing afbId: " .. tostring(afbId))
					if afbData.unlimitedAircrafts == false then
						for acfCat, acfData in pairs(afbData.aircrafts) do
							for aId, aData in pairs(acfData) do
								local oldDAta = aData.initialAmount
								aData.initialAmount = getAcfItemNumber(sCopy, afbType, afbId, aId) or base_qty
								--HOOK.writeDebugDetail(ModuleName .. ": fixWarehouse - " .. tostring(aId) .. " from " .. tostring(oldDAta) .. " to " .. tostring(aData.initialAmount))
								--aData.initialAmount = getAcfItemNumber(sCopy, aId) or base_qty -- remove or 66
							end
						end
					end
					if afbData.unlimitedMunitions == false then
						for wId, wData in pairs(afbData.weapons) do
							local wWs = wsTypeToString(wData.wsType)
							--HOOK.writeDebugDetail(ModuleName .. ": fixWarehouse - " .. tostring(wWs) .. " from " .. tostring(wData.initialAmount) .. " to " .. tostring(getWpnItemNumber(sourceTbl, wWs)))
							wData.initialAmount = getWpnItemNumber(sCopy, afbType, afbId, wWs) or base_qty -- remove or 66
							--HOOK.writeDebugDetail(ModuleName .. ": fixWarehouse - wWs: ".. tostring(wWs) .. ", wData.initialAmount: " .. tostring(wData.initialAmount))
						end
					end			
				end
			end

			
			moveFile(lfs.writedir() .. "Missions/DSMC_fix_warehouse.miz", lfs.writedir() .. "Missions/DSMC_fix_warehouse_used.miz")
			return new_wh
			--local f = io.open(lfs.writedir() .. "Missions/warehouses", "w");
			--local w_string = UTIL.Integratedserialize('warehouses', new_wh);
			--f:write(w_string);
			--io.close(f);

		else
			HOOK.writeDebugDetail(ModuleName .. ": fixWarehouse - missing variable")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": fixWarehouse - no warehouse to fix")
	end
end

function reBuildSupplyNet(warehouse, mission)
	if warehouse and mission then

		-- set temporary tables
		local fuelDepots = {}
		local ammoDepots = {}
		local heliports = {} -- only 4 slots FARP!

		for afbType, afbIds in pairs(warehouse) do
			if afbType == "warehouses" then
				for afbId, afbData in pairs(afbIds) do
					for coalitionID,coalition in pairs(mission["coalition"]) do
						for countryID,country in pairs(coalition["country"]) do
							for attrID,attr in pairs(country) do
								if (type(attr)=="table") then
									if attrID == "static" then
										for groupID,group in pairs(attr["group"]) do
											if (group) then
												for unitID,unit in pairs(group["units"]) do
													if unit.unitId == afbId then
														local c_w = nil
														if coalitionID == "blue" then
															c_w = 2
														elseif coalitionID == "red" then
															c_w = 1
														elseif coalitionID == "neutrals" then
															c_w = 0
														end

														local un_fuel = afbData.unlimitedFuel
														local un_muni = afbData.unlimitedMunitions
														HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: checking un_fuel: " .. tostring(un_fuel) .. ", un_muni:" .. tostring(un_muni))

														if c_w then
															-- check type!
															if unit.type == "Tank" or unit.type == "Tank 2" or unit.type == "Tank 3" then
																fuelDepots[#fuelDepots+1] = {coa = c_w, id = unit.unitId, unlimited = un_fuel}
																HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: added fuelDepots id:" .. tostring(unit.unitId))
															elseif unit.type == ".Ammunition depot" or unit.type == "Warehouse" then
																ammoDepots[#ammoDepots+1] = {coa = c_w, id = unit.unitId, unlimited = un_muni}
																HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: added ammoDepots id:" .. tostring(unit.unitId))
															elseif unit.type == "FARP" then
																heliports[#heliports+1] = {coa = c_w, id = unit.unitId}
																HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: added heliports id:" .. tostring(unit.unitId))
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

		-- now create the net
		for afbType, afbIds in pairs(warehouse) do
			if afbType == "airports" then
				for afbId, afbData in pairs(afbIds) do
					local c_a = nil
					if afbData.coalition == "BLUE" then
						c_a = 2
					elseif afbData.coalition == "RED" then
						c_a = 1
					elseif afbData.coalition == "NEUTRAL" then
						c_a = 0
					end
					
					if c_a then

						HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: airport id:" .. tostring(afbId) .. ", coa:" .. tostring(c_a))

						-- reset
						afbData.suppliers = {}

						-- built fuel
						if #fuelDepots > 0 then
							for _, fData in pairs(fuelDepots) do
								if fData.coa == c_a then
									--if fData.unlimited == false then
										afbData.suppliers[#afbData.suppliers+1] = {Id = fData.id, type = "warehouses"}
									--end
								end
							end
						end
						
						-- built ammo
						if #ammoDepots > 0 then
							for _, aData in pairs(ammoDepots) do
								if aData.coa == c_a then
									--if aData.unlimited == false then
										afbData.suppliers[#afbData.suppliers+1] = {Id = aData.id, type = "warehouses"}
									--end
								end
							end
						end
					end
				end
			elseif afbType == "warehouses" then
				for afbId, afbData in pairs(afbIds) do
					local c_a = nil
					if afbData.coalition == "blue" then
						c_a = 2
					elseif afbData.coalition == "red" then
						c_a = 1
					elseif afbData.coalition == "neutral" then
						c_a = 0
					end

					if c_a then

						-- reset
						afbData.suppliers = {}

						-- set FARPs
						for _, farps in pairs(heliports) do
							if farps.id == afbId then

								HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: FARP id:" .. tostring(afbId) .. ", coa:" .. tostring(c_a))

								-- built fuel
								if #fuelDepots > 0 then
									for _, fData in pairs(fuelDepots) do
										if fData.coa == c_a then
											--if fData.unlimited == false then
												afbData.suppliers[#afbData.suppliers+1] = {Id = fData.id, type = "warehouses"}
											--end
										end
									end
								end
								
								-- built ammo
								if #ammoDepots > 0 then
									for _, aData in pairs(ammoDepots) do
										if aData.coa == c_a then
											--if aData.unlimited == false then
												afbData.suppliers[#afbData.suppliers+1] = {Id = aData.id, type = "warehouses"}
											--end
										end
									end
								end
							end
						end

						-- set fuel net
						for _, fuels in pairs(fuelDepots) do
							if fuels.id == afbId then

								HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: Fuel Depot id:" .. tostring(afbId) .. ", coa:" .. tostring(c_a))

								if afbData.unlimitedFuel == false then

									-- built fuel from "refineries"
									if #fuelDepots > 0 then
										for _, fData in pairs(fuelDepots) do
											if fData.coa == c_a then
												if afbId ~= fData.id then
													if fData.unlimited == true then
														afbData.suppliers[#afbData.suppliers+1] = {Id = fData.id, type = "warehouses"}
													end
												end
											end
										end
									end

								end

							end
						end

						-- set ammo net
						for _, ammos in pairs(ammoDepots) do
							if ammos.id == afbId then

								HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet: Ammo Depot id:" .. tostring(afbId) .. ", coa:" .. tostring(c_a))

								if afbData.unlimitedMunitions == false then

									-- built fuel
									if #ammoDepots > 0 then
										for _, aData in pairs(ammoDepots) do
											if aData.coa == c_a then
												if afbId ~= aData.id then
													if aData.unlimited == true then
														afbData.suppliers[#afbData.suppliers+1] = {Id = aData.id, type = "warehouses"}
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
		HOOK.writeDebugDetail(ModuleName .. ": reBuildSupplyNet missing variables")
	end

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



-- ## ADDED GLOBAL TABLES

tblFOBnames = {
	[1] = "New York City",
	[2] = "Los Angeles",
	[3] = "Chicago",
	[4] = "Houston",
	[5] = "Phoenix",
	[6] = "Philadelphia",
	[7] = "San Antonio",
	[8] = "San Diego",
	[9] = "Dallas",
	[10] = "San Jose",
	[11] = "Austin",
	[12] = "Jacksonville",
	[13] = "Fort Worth",
	[14] = "Columbus",
	[15] = "Charlotte",
	[16] = "San Francisco",
	[17] = "Indianapolis",
	[18] = "Seattle",
	[19] = "Denver",
	[20] = "Washington",
	[21] = "Boston",
	[22] = "El Paso",
	[23] = "Nashville",
	[24] = "Detroit",
	[25] = "Oklahoma City",
	[26] = "Portland",
	[27] = "Memphis",
	[28] = "Louisville",
	[29] = "Baltimore",
	[30] = "Milwaukee",
	[31] = "Albuquerque",
	[32] = "Tucson",
	[33] = "Fresno",
	[34] = "Mesa",
	[35] = "Sacramento",
	[36] = "Atlanta",
	[37] = "Kansas City",
	[38] = "Colorado Springs",
	[39] = "Omaha",
	[40] = "Raleigh",
	[41] = "Miami",
	[42] = "Long Beach",
	[43] = "Virginia Beach",
	[44] = "Oakland",
	[45] = "Minneapolis",
	[46] = "Tulsa",
	[47] = "Tampa",
	[48] = "Arlington",
	[49] = "New Orleans",
	[50] = "Wichita",
	[51] = "Bakersfield",
	[52] = "Cleveland",
	[53] = "Aurora",
	[54] = "Anaheim",
	[55] = "Honolulu",
	[56] = "Santa Ana",
	[57] = "Riverside",
	[58] = "Corpus Christi",
	[59] = "Lexington",
	[60] = "Stockton",
	[61] = "Saint Paul",
	[62] = "Cincinnati",
	[63] = "St. Louis",
	[64] = "Pittsburgh",
	[65] = "Greensboro",
	[66] = "Lincoln",
	[67] = "Anchorage",
	[68] = "Plano",
	[69] = "Orlando",
	[70] = "Irvine",
	[71] = "Newark",
	[72] = "Durham",
	[73] = "Chula Vista",
	[74] = "Toledo",
	[75] = "Fort Wayne",
	[76] = "St. Petersburg",
	[77] = "Laredo",
	[78] = "Jersey City",
	[79] = "Chandler",
	[80] = "Madison",
	[81] = "Lubbock",
	[82] = "Scottsdale",
	[83] = "Buffalo",
	[84] = "Gilbert",
	[85] = "Glendale",
	[86] = "Winston�Salem",
	[87] = "Chesapeake",
	[88] = "Norfolk",
	[89] = "Fremont",
	[90] = "Garland",
	[91] = "Irving",
	[92] = "Hialeah",
	[93] = "Richmond",
	[94] = "Boise",
	[95] = "Spokane",
	[96] = "Baton Rouge",
	[97] = "Tacoma",
	[98] = "San Bernardino",
	[99] = "Modesto",
	[100] = "Fontana",
	[101] = "Des Moines",
	[102] = "Moreno Valley",
	[103] = "Santa Clarita",
	[104] = "Fayetteville",
	[105] = "Birmingham",
	[106] = "Oxnard",
	[107] = "Rochester",
	[108] = "Port St. Lucie",
	[109] = "Grand Rapids",
	[110] = "Huntsville",
	[111] = "Salt Lake City",
	[112] = "Frisco",
	[113] = "Yonkers",
	[114] = "Amarillo",
	[115] = "Glendale",
	[116] = "Huntington Beach",
	[117] = "McKinney",
	[118] = "Montgomery",
	[119] = "Augusta",
	[120] = "Aurora",
	[121] = "Akron",
	[122] = "Little Rock",
	[123] = "Tempe",
	[124] = "Columbus",
	[125] = "Overland Park",
	[126] = "Grand Prairie",
	[127] = "Tallahassee",
	[128] = "Cape Coral",
	[129] = "Mobile",
	[130] = "Knoxville",
	[131] = "Shreveport",
	[132] = "Worcester",
	[133] = "Ontario",
	[134] = "Vancouver",
	[135] = "Sioux Falls",
	[136] = "Chattanooga",
	[137] = "Brownsville",
	[138] = "Fort Lauderdale",
	[139] = "Providence",
	[140] = "Newport News",
	[141] = "Rancho Cucamonga",
	[142] = "Santa Rosa",
	[143] = "Peoria",
	[144] = "Oceanside",
	[145] = "Elk Grove",
	[146] = "Salem",
	[147] = "Pembroke Pines",
	[148] = "Eugene",
	[149] = "Garden Grove",
	[150] = "Cary",
	[151] = "Fort Collins",
	[152] = "Corona",
	[153] = "Springfield",
	[154] = "Jackson",
	[155] = "Alexandria",
	[156] = "Hayward",
	[157] = "Clarksville",
	[158] = "Lakewood",
	[159] = "Lancaster",
	[160] = "Salinas",
	[161] = "Palmdale",
	[162] = "Hollywood",
	[163] = "Springfield",
	[164] = "Macon",
	[165] = "Kansas City",
	[166] = "Sunnyvale",
	[167] = "Pomona",
	[168] = "Killeen",
	[169] = "Escondido",
	[170] = "Pasadena",
	[171] = "Naperville",
	[172] = "Bellevue",
	[173] = "Joliet",
	[174] = "Murfreesboro",
	[175] = "Midland",
	[176] = "Rockford",
	[177] = "Paterson",
	[178] = "Savannah",
	[179] = "Bridgeport",
	[180] = "Torrance",
	[181] = "McAllen",
	[182] = "Syracuse",
	[183] = "Surprise",
	[184] = "Denton",
	[185] = "Roseville",
	[186] = "Thornton",
	[187] = "Miramar",
	[188] = "Pasadena",
	[189] = "Mesquite",
	[190] = "Olathe",
	[191] = "Dayton",
	[192] = "Carrollton",
	[193] = "Waco",
	[194] = "Orange",
	[195] = "Fullerton",
	[196] = "Charleston",
	[197] = "West Valley City",
	[198] = "Visalia",
	[199] = "Hampton",
	[200] = "Gainesville",
	[201] = "Warren",
	[202] = "Coral Springs",
	[203] = "Cedar Rapids",
	[204] = "Round Rock",
	[205] = "Sterling Heights",
	[206] = "Kent",
	[207] = "Columbia",
	[208] = "Santa Clara",
	[209] = "New Haven",
	[210] = "Stamford",
	[211] = "Concord",
	[212] = "Elizabeth",
	[213] = "Athens",
	[214] = "Thousand Oaks",
	[215] = "Lafayette",
	[216] = "Simi Valley",
	[217] = "Topeka",
	[218] = "Norman",
	[219] = "Fargo",
	[220] = "Wilmington",
	[221] = "Abilene",
	[222] = "Odessa",
	[223] = "Columbia",
	[224] = "Pearland",
	[225] = "Victorville",
	[226] = "Hartford",
	[227] = "Vallejo",
	[228] = "Allentown",
	[229] = "Berkeley",
	[230] = "Richardson",
	[231] = "Arvada",
	[232] = "Ann Arbor",
	[233] = "Rochester",
	[234] = "Cambridge",
	[235] = "Sugar Land",
	[236] = "Lansing",
	[237] = "Evansville",
	[238] = "College Station",
	[239] = "Fairfield",
	[240] = "Clearwater",
	[241] = "Beaumont",
	[242] = "Independence",
	[243] = "Provo",
	[244] = "Murrieta",
	[245] = "Palm Bay",
	[246] = "El Monte",
	[247] = "Carlsbad",
	[248] = "North Charleston",
	[249] = "Temecula",
	[250] = "Clovis",
	[251] = "Springfield",
	[252] = "Meridian",
	[253] = "Westminster",
	[254] = "Costa Mesa",
	[255] = "High Point",
	[256] = "Manchester",
	[257] = "Pueblo",
	[258] = "Lakeland",
	[259] = "Pompano Beach",
	[260] = "West Palm Beach",
	[261] = "Antioch",
	[262] = "Everett",
	[263] = "Downey",
	[264] = "Lowell",
	[265] = "Centennial",
	[266] = "Elgin",
	[267] = "Richmond",
	[268] = "Peoria",
	[269] = "Broken Arrow",
	[270] = "Miami Gardens",
	[271] = "Billings",
	[272] = "Jurupa Valley",
	[273] = "Sandy Springs",
	[274] = "Gresham",
	[275] = "Lewisville",
	[276] = "Hillsboro",
	[277] = "Ventura",
	[278] = "Greeley",
	[279] = "Inglewood",
	[280] = "Waterbury",
	[281] = "League City",
	[282] = "Santa Maria",
	[283] = "Tyler",
	[284] = "Davie",
	[285] = "Daly City",
	[286] = "Boulder",
	[287] = "Allen",
	[288] = "West Covina",
	[289] = "Wichita Falls",
	[290] = "Green Bay",
	[291] = "San Mateo",
	[292] = "Norwalk",
	[293] = "Rialto",
	[294] = "Las Cruces",
	[295] = "Chico",
	[296] = "El Cajon",
	[297] = "Burbank",
	[298] = "South Bend",
	[299] = "Renton",
	[300] = "Vista",
	[301] = "Davenport",
	[302] = "Edinburg",
	[303] = "Tuscaloosa",
	[304] = "Carmel",
	[305] = "Spokane Valley",
	[306] = "San Angelo",
	[307] = "Vacaville",
	[308] = "Bend",
}






--inJectTable("tblFOBnames", tblFOBnames)