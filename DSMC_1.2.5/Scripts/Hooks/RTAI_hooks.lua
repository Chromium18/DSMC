-- Dynamic Sequential Mission Campaign -- RTAI module


-- ## LIBS	
module('RTAI', package.seeall)	-- module name. All function in this file, if used outside, should be called "HOOK.functionname"
base 						= _G	
require 					= base.require		
io 							= require('io')
lfs 						= require('lfs')
os 							= require('os')
minizip 					= require('minizip')
local lang					= require('i18n')
local ModuleName            = 'RTAI'

--## UTIL


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

function inJectCode(Code_name, CodeString)
    if HOOK then		
        local str, strErr = net.dostring_in("mission", "a_do_script(" .. "[===[" .. CodeString .. "]===]" .. ")")	
        if not strErr then
            HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", str: " .. tostring(str))
        else
            HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", " .. tostring(Code_name) .. " loaded in mission env" )
        end
        return str
    end
end

function inJectTable(Table_name, Table_code)
    if HOOK then	
        local tbl_serial = IntegratedserializeWithCycles(Table_name, Table_code)	
        local str, strErr = net.dostring_in("mission", "a_do_script(" .. "[===[" .. tbl_serial .. "]===]" .. ")")
        if not strErr then
            HOOK.writeDebugDetail(ModuleName .. ": inject not worked: " .. tostring(strErr) .. ", str= " .. tostring("a_do_script(" .. "[===[" .. tbl_serial .. "]===]" .. ")") )
        else
            HOOK.writeDebugDetail(ModuleName .. ": inject worked: " .. tostring(strErr) .. ", " .. tostring(Table_name) .. " loaded in mission env" )
        end
    end
end

--## ALL EXTERNAL FUNCTIONS AND PROCESSES ARE ALWAYS ACTIVATED BY TRIGGER MESSAGE. ALSO MAIN INFORMATION ARE PASSED BY WITH TRIGGER MESSAGES
function RTAI.onChatMessage(message, from)	
    if HOOK then
        local isServer 	= DCS.isServer()
        if isServer == true then
            if string.find(string.lower(message), "request fire support") then	-- this will import & save any table that starts with "tbl"					
                
                HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - from: " .. tostring(from))

                -- check asking unit
                local u_init = string.find(message, ", ")
                if u_init then

                    -- identify units
                    HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - identified g_unit: " .. tostring(u_init))
                    u_init = u_init + 2
                    local message = string.sub(message, u_init)
                    HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - message: " .. tostring(message))
                    local u_stop = string.find(message, ", ")
                    local unitName = string.sub(message, 1, u_stop-1)
                    HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - unitName: " .. tostring(unitName))

                    if unitName then 
                        -- step 1 done unit name defined
                        inJectCode("artyCaller", [[RTAI.artyCaller = ']] .. tostring(unitName) .. "'")
                    
                        --inJectCode("fExec", "RTAI.artyCallbyChat()")

                        -- check coordinates
                        local nord = string.match(string.lower(message), "n%d%d%.%d+")
                        local est = string.match(string.lower(message), "e%d%d%d%.%d+")
                        local sud = string.match(string.lower(message), "s%d%d%.%d+")
                        local west = string.match(string.lower(message), "w%d%d%d%.%d+")
                        local mgrs = string.find(string.lower(message), "mgrs")

                        local n = nil
                        local e = nil
                        local s = nil
                        local w = nil
                        local m = nil
                        
                        if nord then
                            n = string.sub(nord,2,9)
                        end
                        if est then
                            e = string.sub(est,2,10)
                        end
                        if sud then
                            s = string.sub(sud,2,9)
                        end
                        if west then
                            w = string.sub(west,2,10)
                        end
                        if mgrs then
                            m = string.sub(message, mgrs + 5, mgrs + 25)
                        end

                        HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - nord: " .. tostring(n))
                        HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - est: " .. tostring(e))
                        HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - sud: " .. tostring(s))
                        HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - west: " .. tostring(w))
                        HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - mgrs: " .. tostring(m))
                        
                        local validCoordData = false
                        if m then
                            local zone = string.match(string.lower(m), "[%d]?%d%d%a")
                            local grid = string.match(string.lower(m), "%a%a")

                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - zone: " .. tostring(zone))
                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - grid: " .. tostring(grid))

                            if zone and grid then
                                local s_start = string.find(string.lower(m), grid)
                                HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - s_start: " .. tostring(s_start))
                                local sub_message = string.sub(m , s_start+2)
                                local easting = string.match(string.lower(sub_message), "%d%d%d+")

                                HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - easting: " .. tostring(easting))
                                
                                if easting then
                                    local s2_start = string.find(string.lower(sub_message), easting)
                                    HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - s2_start: " .. tostring(s2_start))
                                    local sub2_message = string.sub(sub_message , s2_start+string.len(easting))
                                    local northing = string.match(string.lower(sub2_message), "%d%d%d+")
                            
                                    HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - northing: " .. tostring(northing))
                            
                                    if zone and grid and easting and northing then
                                        local tblMGRS = {
                                            ["UTMZone"] = string.upper(zone),
                                            ["MGRSDigraph"] = string.upper(grid),
                                            ["Northing"] = northing,
                                            ["Easting"] = easting,
                                        }

                                        inJectTable("RTAI.artymgrsCoord", tblMGRS)
                                        validCoordData = true

                                    end
                                end
                            end

                            --inJectCode("artymgrsCoord", [[RTAI.artymgrsCoord = ']] .. tostring(m) .. "'")
                            validCoordData = true
                        end

                        local x = nil
                        local y = nil

                        if validCoordData == false then
                            if n then
                                y = n
                            elseif s then
                                y = "-" .. tostring(s)  
                            end

                            if e then
                                x = e
                            elseif w then
                                x = "-" .. tostring(w)   
                            end                        
                            
                            if x and y then
                                validCoordData = true
                                inJectCode("artyXCoord", [[RTAI.artyXCoord = ']] .. tostring(x) .. "'")
                                inJectCode("artyYCoord", [[RTAI.artyYCoord = ']] .. tostring(y) .. "'")
                            end
                        end

                        if validCoordData == true then
                            -- step 2 done coordinates
                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - validCoordData: " .. tostring(validCoordData))

                            -- check altitude
                            local a_init = string.find(string.lower(message), "altitude ")
                            if a_init then
                                local a_string = string.sub(message, a_init+1)
                                if a_string then
                                    local aa = string.match(a_string, "%d+")
                                    if aa then
                                        HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - altitude: " .. tostring(aa))
                                        inJectCode("artyaltitude", [[RTAI.artyaltitude = ']] .. tostring(aa) .. "'")
                                    end
                                end
                            end

                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - c1")

                            -- check time
                            local h1 = string.match(message, "%d%d:")
                            local hh = nil
                            if h1 then
                                hh = string.match(h1, "%d+")
                            end
                            local m1 = string.match(message, ":%d%d")     
                            local mm = nil    
                            if m1 then
                                mm = string.match(m1, "%d+")
                            end

                            if hh and mm then
                                HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - hh: " .. tostring(hh))
                                HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - mm: " .. tostring(mm))

                                local hours = tostring(hh) .. ":" .. tostring(mm)
                                HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - hours: " .. tostring(hours))
                                inJectCode("artyhour", [[RTAI.artyhour = ']] .. tostring(hours) .. "'")
                            end

                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - c2")

                            -- check rounds
                            local r = string.find(string.lower(message), "rounds ")
                            if r then
                                local submessage = string.sub(message, r+7)
                                local rnd = string.match(string.lower(submessage), "%d+")
                                if rnd then
                                    inJectCode("artyround", [[RTAI.artyround = ']] .. tostring(rnd) .. "'")
                                end
                            end

                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - filter done, sending data in")
                            inJectCode("fExec", "RTAI.artyCallbyChat()")
                        else
                            HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - missing valid coordinates data")

                        end

                        unitName = nil
                    end
                else
                    HOOK.writeDebugDetail(ModuleName .. ": chatRequestArty - unit not identified")
                end
            end

        end
    end
end

DCS.setUserCallbacks(RTAI)
