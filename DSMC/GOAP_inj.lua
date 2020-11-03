-- Dynamic Sequential Mission Campaign -- AI ENHANCEMENT GOAP injected module

local ModuleName  	= "GOAP"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0100"
local Date			= "17/10/2020"

--## MAIN TABLE
GOAP                                = {}

--## LOCAL VARIABLES
--env.setErrorMessageBoxEnabled(false)
local base 						    = _G
local DSMC_io 					    = base.io  	-- check if io is available in mission environment
local DSMC_lfs 					    = base.lfs		-- check if lfs is available in mission environment
local phase_index                   = 1

GOAP.debugProcessDetail             = DSMC_debugProcessDetail or true
GOAP.outRoadSpeed                   = 28,8/3.6	-- km/h /3.6, cause DCS thinks in m/s	
GOAP.inRoadSpeed                    = 54/3.6	-- km/h /3.6, cause DCS thinks in m/s
GOAP.outAmmoLowLevel                = 0.7		-- factor on total amount
GOAP.TerrainDb                      = {}
GOAP.disperseActionTime				= 120		-- seconds
GOAP.emergencyWithdrawDistance		= 2000 		-- meters
GOAP.repositionDistance				= 300		-- meters
GOAP.supportDist                    = 20000     -- m of distance max between objective point and group
GOAP.townControlRadius              = 1500      -- m from town center in which the update function will check presence of more than 1 coalition to define owner
GOAP.obsoleteIntelValue             = 3600      -- seconds after the collected intel, if not renewed, are removed as "obsolete"
GOAP.townInfluenceRange             = 5000      -- m from town center for ownership & buildings count calculation    
GOAP.phaseCycleTimer                = 0.5         -- frequency of phased cycle calculations


GOAP.supportUnitCategories  ={
    [1] = "Armed vehicles",
    [2] = "AntiAir Armed Vehicles",
}
GOAP.intel                          = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}

if DSMC_io and DSMC_lfs then
	env.info(("GOAP loading desanitized additional function"))
	
	DSMC_GOAPmodule 	= "funzia"
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

	function GOAP.saveTable(fname, tabledata)		
		if DSMC_lfs and DSMC_io then
			local DSMCfiles = DSMC_lfs.writedir() .. "Missions/Temp/Files/"
			local fdir = DSMCfiles .. fname .. ".lua"
			local f = DSMC_io.open(fdir, 'w')
			local str = IntegratedserializeWithCycles(fname, tabledata)
			f:write(str)
			f:close()
		end
	end
	
	env.info(("GOAP desanitized additional function loaded"))
end

--## TOWNS TABLE
if env.mission.theatre == "Caucasus" then
    local tTbl = {}
    for tName, tData in pairs(CaucasusTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    CaucasusTowns = nil
elseif env.mission.theatre == "Nevada" then
    local tTbl = {}
    for tName, tData in pairs(NevadaTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    NevadaTowns = nil
elseif env.mission.theatre == "Normandy" then
    local tTbl = {}
    for tName, tData in pairs(NormandyTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    NormandyTowns = nil
elseif env.mission.theatre == "PersianGulf" then
    local tTbl = {}
    for tName, tData in pairs(PersianGulfTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    PersianGulfTowns = nil
elseif env.mission.theatre == "TheChannel" then
    local tTbl = {}
    for tName, tData in pairs(TheChannelTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    TheChannelTowns = nil
elseif env.mission.theatre == "Syria" then
    local tTbl = {}
    for tName, tData in pairs(SyriaTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    SyriaTowns = nil
else
    env.error(("GOAP, no theater identified: halting everything"))
    return
end

if not GOAP.TerrainDb["towns"] then
    env.error(("GOAP, no TerrainDb table: halting everything"))
    return
end

function GOAP.getAngle(vector1, vector2)
    return math.deg(math.atan2(vector2.z-vector1.z, vector2.x-vector1.x))%360
end

function GOAP.findProxy(terrain)
    local n = nil
    local e = nil
    local w = nil
    local s = nil
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        if tData.display_name ~= terrain.display_name then
            local dist1 = GOAP.getDist(terrain.pos, tData.pos)
            local ang1 = GOAP.getAngle(terrain.pos, tData.pos)
            if ang1 and dist1 then
                local ang = math.floor(ang1)
                local dist = math.floor(dist1)

                if ang >= 315 or ang < 45 then
                    if n then
                        if n.distance > dist then
                            n = {name = tData.display_name, distance = dist, pos = tData.pos}
                            env.info(("GOAP, findProxy: found n, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))
                        end
                    else
                        n = {name = tData.display_name, distance = dist, pos = tData.pos}
                        env.info(("GOAP, findProxy: found n, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))                        
                    end
                elseif ang >= 45 and ang < 135 then    
                    if e then
                        if e.distance > dist then
                            e = {name = tData.display_name, distance = dist, pos = tData.pos}
                            env.info(("GOAP, findProxy: found e, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))
                        end
                    else
                        e = {name = tData.display_name, distance = dist, pos = tData.pos}
                        env.info(("GOAP, findProxy: found e, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))
                    end                
                elseif ang >= 135 and ang < 225 then    
                    if s then
                        if s.distance > dist then
                            s = {name = tData.display_name, distance = dist, pos = tData.pos}
                            env.info(("GOAP, findProxy: found s, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))
                        end
                    else
                        s = {name = tData.display_name, distance = dist, pos = tData.pos}
                        env.info(("GOAP, findProxy: found s, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))
                    end  
                elseif ang >= 225 and ang < 315 then    
                    if w then
                        if w.distance > dist then
                            w = {name = tData.display_name, distance = dist, pos = tData.pos}
                            env.info(("GOAP, findProxy: found w, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))
                        end
                    else
                        w = {name = tData.display_name, distance = dist, pos = tData.pos}
                        env.info(("GOAP, findProxy: found w, terr " .. tostring(tData.display_name) .. ", name " .. tostring(tData.display_name) .. " dist " .. tostring(dist) .. " angle " .. tostring(ang)    ))                        
                    end 
                end
            else
                env.info(("GOAP, findProxy: found w, terr " .. tostring(tData.display_name) .. ", missing ang or dist "))
            end
        end
    end

    if n and e and w and s then
        local p = {nord = n, east = e, sud = s, west = w}
        return p
    else
        env.error(("GOAP, findProxy: missing one of the proxy"))
        if GOAP.debugProcessDetail then
            env.info(("GOAP, findProxy: terrain " .. tostring(terrain.display_name) .. " n=" .. tostring(n)    ))
            env.info(("GOAP, findProxy: terrain " .. tostring(terrain.display_name) .. " s=" .. tostring(s)    ))
            env.info(("GOAP, findProxy: terrain " .. tostring(terrain.display_name) .. " w=" .. tostring(w)    ))
            env.info(("GOAP, findProxy: terrain " .. tostring(terrain.display_name) .. " e=" .. tostring(e)    ))
        end
    end
end

function GOAP.phase0_initTerrains()
    
    -- fill table
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        tData.owner = 0
        tData.coalition = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}
        tData.pos = GOAP.townToVec3(tData.display_name)
        local dataSet0 = {
            ["information"] = false,
            ["guarded"] = false,
        }
        tData.data = {[0] = dataSet0, [1] = dataSet0, [2] = dataSet0, [3] = dataSet0}
        tData.border = false
        tData.majorCity = false
    end

    -- assign proxy
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        local pr = GOAP.findProxy(tData)
        tData.proxy = pr
    end

    -- size terrains
    GOAP.sizeTerrain(GOAP.TerrainDb["towns"])

    -- define major cities




end

--## CIRCULAR FINITE STATE MACHINE UPDATE INFO
local phase = "A"
function GOAP.changePhase()
    if phase == "A" then -- udpate terrain data
        phase = "B"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "B" then
        phase = "C"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "C" then
        phase = "D"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "D" then
        phase = "E"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "E" then
        phase = "F"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "F" then
        phase = "A"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    end
end

-- phase cycle
function GOAP.performPhaseCycle()
    if phase == "A" then
        GOAP.phaseA_updateTerrain(GOAP.TerrainDb)
    elseif phase == "B" then
        GOAP.phaseB_updateIntel(env.mission)
        --env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        --phase = "C"
        --GOAP.performPhaseCycle()
    elseif phase == "C" then
        env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "D"
        timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    elseif phase == "D" then
        env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "E"
        timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    elseif phase == "E" then
        env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "F"
        timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    elseif phase == "F" then
        env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "A"
        timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    end
end

-- update terrain data
function GOAP.sizeTerrain(tblTerrain) -- upgrade with group positioning inside a table
    for tId, tData in pairs(tblTerrain) do
        if tData and type(tData) == "table" then

            local vec3 = GOAP.townToVec3(tData.display_name)
            if vec3 then
                local _volume = {
                    id = world.VolumeType.SPHERE,
                    params = {
                        point = vec3,
                        radius = GOAP.townInfluenceRange
                    }
                }
                
                local _count = 0
                local _countLife = 0

                local _search = function(_obj)
                    pcall(function()
                        _count = _count + 1
                    end)
                    return true
                end       
            
                world.searchObjects(Object.Category.SCENERY, _volume, _search)
            
                tData.size = _count
                tData.sizeL = _countLife
            end
        end
    end
end

function GOAP.phaseA_updateTerrain(tblTerrain) -- upgrade with group positioning inside a table
    --env.info(("GOAP, phaseA_updateTerrain: starting"))

    if phase == "A" then
        if tblTerrain then
            if tblTerrain.towns then
                
                -- check if Cycle is done
                if phase_index > #tblTerrain.towns then
                    env.info(("GOAP, phaseA_updateTerrain: phase A completed"))
                    GOAP.changePhase()
                    timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
                    if GOAP.debugProcessDetail then
                        dumpTable("GOAPterrainDB.lua", GOAP.TerrainDb)
                    end
                else
                    for tId, tData in pairs(tblTerrain.towns) do
                        if tId == phase_index then
                            
                            -- update phase_index
                            phase_index = phase_index + 1

                            -- perform update
                            if tData and type(tData) == "table" then
                                --env.info(("GOAP, phaseA_updateTerrain updating " .. tostring(tData.display_name)))
                                local vec3 = GOAP.townToVec3(tData.display_name)
                                if vec3 then
                                    local _volume = {
                                        id = world.VolumeType.SPHERE,
                                        params = {
                                            point = vec3,
                                            radius = GOAP.townControlRadius
                                        }
                                    }
                                    
                                    local _groupList = {}

                                    local _search = function(_unit)
                                        pcall(function()
                                            if _unit ~= nil and _unit:getLife() > 0 and not _unit:hasAttribute("Air") and not _unit:hasAttribute("Ships") then
                                                local gr    = _unit:getGroup()
                                                local grId  = gr:getID()
                                                local grCoa = gr:getCoalition()

                                                local allow = true
                                                if #_groupList >0 then
                                                    for gIn, gData in pairs(_groupList) do
                                                        if gData.id == grId then
                                                            allow = false
                                                        end
                                                    end
                                                end

                                                if allow == true then
                                                    _groupList[#_groupList+1] = {id = grId, group = gr, coa = grCoa}
                                                end

                                            end
                                        end)
                                        return true
                                    end       
                                
                                    world.searchObjects(Object.Category.UNIT, _volume, _search)
                                
                                    if #_groupList == 0 then
                                        tData.owner = 0  -- zero means no one!
                                        --env.info(("GOAP, phaseA_updateTerrain " .. tostring(tData.display_name) .. " no units, is neutral"))
                                        tblTerrain.towns[tId] = tData
                                    else
                                        local blueHasGroups = false
                                        local redHasGroups = false

                                        for gID, gDATA in pairs(_groupList) do
                                            local grdata = gDATA.group
                                            local str, coa, atr = grdata:getClass()
                                            if str and coa and atr then
                                                if tData.coalition then
                                                    for cId, cData in pairs(tData.coalition) do
                                                        if cId == coa then
                                                            cData[gDATA.id] = {strenght = str, attributes = atr}
                                                            if coa == 2 then
                                                                blueHasGroups = true
                                                            elseif coa == 1 then
                                                                redHasGroups = true
                                                            end
                                                        end
                                                    end
                                                end
                                                    
                                            else
                                                env.error(("GOAP, phaseA_updateTerrain: missing str coa atr for group: " .. tostring(gDATA.id)))
                                            end
                                        end

                                        if blueHasGroups and redHasGroups then
                                            tData.owner = 9
                                            env.info(("GOAP, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as contended"))
                                        elseif blueHasGroups and not redHasGroups then
                                            tData.owner = 2
                                            env.info(("GOAP, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as blue"))
                                        elseif redHasGroups and not blueHasGroups then
                                            tData.owner = 1
                                            env.info(("GOAP, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as red"))
                                        else
                                            tData.owner = 0
                                            env.info(("GOAP, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as no one"))
                                        end


                                    end
                                    --env.info(("GOAP, phaseA_updateTerrain " .. tostring(tData.display_name) .. " updated"))
                                else
                                    env.error(("GOAP, phaseA_updateTerrain: town missing vec3"))
                                end
                            else
                                env.error(("GOAP, phaseA_updateTerrain: town missing tData"))
                            end
                        end
                    end

                    timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)

                end
            else
                env.error(("GOAP, phaseA_updateTerrain: tblTerrain.towns missing"))
            end
        else
            env.error(("GOAP, phaseA_updateTerrain: tblTerrain missing"))
        end
    end -- phase check
end

-- collect intel
local currentGroupTable = {}
function GOAP.phaseB_createIntelBase(tblMission)
    for coalitionID,coalition in pairs(tblMission["coalition"]) do
        for countryID,country in pairs(coalition["country"]) do
            for attrID,attr in pairs(country) do
                if attrID ~= "static" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local gName = env.getValueDictByKey(group.name)
                                if gName then
                                    local gTbl = GOAP.groupTableCheck(gName)
                                    if gTbl then
                                        env.info(("GOAP, phaseB_createIntelBase: adding " .. tostring(gName)))   
                                        currentGroupTable[#currentGroupTable+1] = {id = gTbl:getID() , Group = gTbl, coa = gTbl:getCoalition()}
                                    end
                                end
                            end
                        end
                    end
                elseif attrID == "static" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local gName = env.getValueDictByKey(group.name)
                                if gName then
                                    local gTbl = Airbase.getByName(gName)
                                    if not gTbl then
                                        gTbl = StaticObject.getByName(gName)
                                    end

                                    if gTbl then
                                        if gTbl:getCategory() == 3 or gTbl:getCategory() == 4 then 
                                            env.info(("GOAP, phaseB_createIntelBase: adding intel on static " .. tostring(gName)))   
                                            
                                            local coa = gTbl:getCoalition()
                                            local t_Id = gTbl:getID()
                                            local tgtType = gTbl:getTypeName()
                                            local tgtPos = gTbl:getPosition().p
                                            local tgtLife = gTbl:getLife()                                 
                                            for xCoa, xData in pairs(GOAP.intel) do
                                                if coa ~= xCoa then
                                                    local id = t_Id
                                                    local tgtData = {}
                                                    tgtData.type = tgtType
                                                    tgtData.pos = tgtPos
                                                    tgtData.static = true
                                                    tgtData.strenght = tgtLife
                                                    tgtData.time = timer.getTime()
                        
                                                    xData[id] = tgtData
                                                end
                                            end
                                            
                                            --currentGroupTable[#currentGroupTable+1] = {id = gTbl:getID() , Group = gTbl, coa = gTbl:getCoalition()}
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
    if GOAP.debugProcessDetail then
        dumpTable("currentGroupTable.lua", currentGroupTable)
    end
end

function GOAP.phaseB_updateIntel(tblMission)
    --env.info(("GOAP, phaseB_updateIntel: starting"))        

    if phase == "B" then        
        if #currentGroupTable ~= 0 then
            
            -- check if Cycle is done
            if phase_index > #currentGroupTable then
                
                -- remove obsolete
                for coa, coaData in pairs(GOAP.intel) do
                    for gId, gData in pairs(coaData) do
                        if gData.time then
                            local delta = timer.getTime() - gData.time
                            if delta > GOAP.obsoleteIntelValue then
                                env.info(("GOAP, phaseB_updateIntel: cleaning entry: " .. tostring(gId)))
                                gId = nil
                            end
                        else
                            env.error(("GOAP, phaseB_updateIntel: cleaning entry for missing time: " .. tostring(gId)))
                            gId = nil
                        end
                    end
                end
                
                -- end loop
                env.info(("GOAP, phaseB_updateIntel: phase B completed"))
                GOAP.changePhase()
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
                if GOAP.debugProcessDetail then
                    dumpTable("GOAP.intel.lua", GOAP.intel)
                end
            else
                for gId, gData in pairs(currentGroupTable) do
                    if gId == phase_index then
                        --env.info(("GOAP, phaseB_updateIntel: updating target from id: " ..  tostring(gId)))
                        local gr = gData.Group
                        gr:hasTargets()
                    end
                end
                phase_index = phase_index + 1
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
            end
        else
            env.error(("GOAP, phaseB_updateIntel: currentGroupTable is equal to zero"))
        end

    end
end




-- do GOAP
---------------------------add

-- back to update
---------------------------add


--## GOAP IMPLEMENTATION

-- Tables
GOAP.tblActionPlan = {
    ["Occupy_Territory"] = {
        ["preq"] = {"Information", "Negative_cost", "Negative_ownership", "Border_Territory"},
        ["gain"] = "Territory_ownership",
        ["action"] = "Group.goToTown", 
        ["subaction"] = nil, 
        ["cost_k"] = 1.5,
    },
    ["Scout_Territory"] = {
        ["preq"] = {"No_Information", "Unknow_cost"},
        ["gain"] = "Information",
        ["action"] = "Group.goToTown", 
        ["subaction"] = "Group.haltOnContact", 
        ["cost_k"] = 1.1,
    },
    ["Guard_Territory"] = {
        ["preq"] = {"Negative_cost", "Positive_ownership", "Border_Territory"},
        ["gain"] = "Territory_guard",
        ["action"] = "Group.goToTown", 
        ["subaction"] = nil, 
        ["cost_k"] = 1,
    },
    ["Shell_Territory"] = {
        ["preq"] = {"Positive_cost", "Negative_ownership", "Border_Territory"},
        ["gain"] = "Territory_guard",
        ["action"] = "Group.goToTown", 
        ["subaction"] = nil, 
        ["cost_k"] = 1.2,
    },
    ["Withdraw_Territory"] = {
        ["preq"] = {"Positive_cost", "Negative_ownership", "No_Border_Territory"},
        ["gain"] = "Territory_guard",
        ["action"] = "Group.goToTown", 
        ["subaction"] = nil, 
        ["cost_k"] = 1.2,
    },
}



--## GOAP internal utils & calculation function
function GOAP.getActionCost()




end

function GOAP.getDist(point1, point2)
    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone
    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function GOAP.groupTableCheck(group)
    if group then
        if type(group) == 'string' then -- assuming name
            local groupTable = Group.getByName(group)

            if not groupTable then
                groupTable = StaticObject.getByName(group)
            end

            if groupTable then
                return groupTable
            else
                --env.info(("GOAP, groupTableCheck: string but not unit or static: skipped"))
                return nil
            end
        elseif type(group) == 'table' then
            return group
        else
            env.error(("GOAP, groupTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, groupTableCheck: missing variable"))
        return nil
    end
end

function GOAP.townTableCheck(town)
    if town then
        if type(town) == 'string' then -- assuming name
            local townTable = nil
            for tName, tData in pairs(GOAP.TerrainDb.towns) do
                if town == tData.display_name then
                    return tData
                end
            end
            env.error(("GOAP, townTableCheck: no town available"))
            return nil

        elseif type(town) == 'table' then
            return town
        else
            env.error(("GOAP, townTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, townTableCheck: missing variable"))
        return nil
    end
end

function GOAP.townToVec3(town)
    local placeData = GOAP.townTableCheck(town)
    --["Strawberry Hill"] = { latitude = 37.619965, longitude = -114.513327, display_name = "Strawberry Hill")},
    if placeData then
        local V2 = coord.LLtoLO(placeData.latitude, placeData.longitude, 0)
        if V2 then
            local V3y = land.getHeight({x = V2.x, y = V2.z})
            local Sty = land.getSurfaceType({x = V2.x, y = V2.z})
            if V3y and Sty then
                local V3 = {x = V2.x, y = V3y, z = V2.z}
                return V3, Sty
            else
                return false
            end
        else
            return false
        end 
    else
        return false
    end
end

function GOAP.unitTableCheck(unit)
    if unit then
        if type(unit) == 'string' then -- assuming name
            local unitTable = Unit.getByName(unit)
            return unitTable
        elseif type(unit) == 'table' then
            return unit
        else
            env.error(("GOAP, unitTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, unitTableCheck: missing variable"))
        return nil
    end
end

function GOAP.vec3Check(vec3)
    if vec3 then
        if type(vec3) == 'table' then -- assuming name
            if vec3.x and vec3.y and vec3.z then			
                return vec3
            else
                env.error(("GOAP, vec3Check: wrong vector format"))
                return nil
            end
        else
            env.error(("GOAP, vec3Check: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, vec3Check: missing variable"))
        return nil
    end
end

function GOAP.roundNumber(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end 

function GOAP.buildWP(point, overRideForm, overRideSpeed)

    local wp = {}
    wp.x = point.x

    if point.z then
        wp.y = point.z
    else
        wp.y = point.y
    end
    local form, speed

    if point.speed and not overRideSpeed then
        wp.speed = point.speed
    elseif type(overRideSpeed) == 'number' then
        wp.speed = overRideSpeed
    else
        wp.speed = 18/3.6
    end

    if point.form and not overRideForm then
        form = point.form
    else
        form = overRideForm
    end

    if not form then
        wp.action = 'Off Road'
    else
        form = string.lower(form)
        if form == 'off_road' or form == 'off road' then
            wp.action = 'Off Road'
        elseif form == 'on_road' or form == 'on road' then
            wp.action = 'On Road'
        elseif form == 'rank' or form == 'line_abrest' or form == 'line abrest' or form == 'lineabrest'then
            wp.action = 'Rank'
        elseif form == 'cone' then
            wp.action = 'Cone'
        elseif form == 'diamond' then
            wp.action = 'Diamond'
        elseif form == 'vee' then
            wp.action = 'Vee'
        elseif form == 'echelon_left' or form == 'echelon left' or form == 'echelonl' then
            wp.action = 'EchelonL'
        elseif form == 'echelon_right' or form == 'echelon right' or form == 'echelonr' then
            wp.action = 'EchelonR'
        else
            wp.action = 'Off Road' -- if nothing matched
        end
    end

    wp.type = 'Turning Point'

    return wp

end


function GOAP.getRandPointInCircle(point, radius, innerRadius)
    local theta = 2*math.pi*math.random()
    local rad = math.random() + math.random()
    if rad > 1 then
        rad = 2 - rad
    end

    local radMult
    if innerRadius and innerRadius <= radius then
        radMult = (radius - innerRadius)*rad + innerRadius
    else
        radMult = radius*rad
    end

    if not point.z then --might as well work with vec2/3
        point.z = point.y
    end

    local rndCoord
    if radius > 0 then
        rndCoord = {x = math.cos(theta)*radMult + point.x, y = math.sin(theta)*radMult + point.z}
    else
        rndCoord = {x = point.x, y = point.z}
    end
    return rndCoord
end

function GOAP.getRandTerrainPointInCircle(var, radius, innerRadius)
    local point = GOAP.vec3Check(var)	
    if point and radius and innerRadius then
        
        for i = 1, 5 do
            local coordRun = GOAP.getRandPointInCircle(point, radius, innerRadius)
            local destlandtype = land.getSurfaceType({coordRun.x, coordRun.z})
            if destlandtype == 1 or destlandtype == 4 then
                env.info(("GOAP, getRandTerrainPointInCircle found valid vec3 point"))
                return coordRun
            end
        end
        env.info(("GOAP, getRandTerrainPointInCircle no valid Vec3 point found!"))
        return nil -- this means that no valid result has found
        
    end
end

function GOAP.deepCopy(object)
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


function GOAP.addTgtToKnownTarget(tData, coa)
    if tData then
        if tData.object then
            if type(tData.object) == "table" and tData.object:getCategory() == 1 then
                local tgtType = "unknown"
                local tgtPos = "unknown"
                --local t_type = tData.type
                local t_Id = tData.object:getID()
                --if t_type then
                    tgtType = tData.object:getTypeName()
                    tgtPos = tData.object:getPosition().p
                    env.info(("GOAP.addTgtToKnownTarget, data: t_type: " .. tostring(tgtType)))

                    for xCoa, xData in pairs(GOAP.intel) do
                        if coa == xCoa then
                            local id = t_Id
                            local tgtData = {}
                            tgtData.type = tgtType
                            tgtData.pos = tgtPos
                            tgtData.time = timer.getTime() 
                            tgtData.strenght = tData.object:getLife()

                            xData[id] = tgtData
                        end
                    end

                    return true
                --else
                --    env.info(("GOAP.addTgtToKnownTarget, missing type"))
                --    return false
                --end          
            end
        else
            env.error(("GOAP.addTgtToKnownTarget, missing tData.object"))
            return false
        end

    else
        env.error(("GOAP.addTgtToKnownTarget, missing variable"))
        return false	
    end

end

function GOAP.findGroupInRange(support_point, attribute, distance, coalition)
    if support_point then
        
        local mindistance =   distance
        local curGroup = nil
        local volS = {
        id = world.VolumeType.SPHERE,
        params = {
            point = support_point,
            radius = distance
            }
        }
        
        local ifFound = function(foundItem, val)
            local funcCheck = nil
            if type(attribute) == "string" then
                funcCheck = function(attribute)
                    if foundItem:hasAttribute(attribute) then
                        return true
                    else
                        return false
                    end
                end
            elseif type(attribute) == "table" then
                funcCheck = function(attribute)
                    local hasVal = false
                    for att, attVal in pairs(attribute) do
                        if foundItem:hasAttribute(attVal) then
                            hasVal = true
                        end
                    end

                    if hasVal == true then
                        return true
                    else
                        return false
                    end

                end
            end

            if funcCheck(attribute) == true then
                
                local proceed = true
                if coalition then
                    local coaCheck = foundItem:getCoalition()
                    if coalition == coaCheck then
                        proceed = true
                    else
                        proceed = false
                    end
                end
                
                if proceed == true then
                    local itemPos = foundItem:getPosition().p
                    if itemPos then
                        local dist = GOAP.getDist(itemPos, support_point)
                        if dist < mindistance and dist > 1000 then
                            mindistance = dist
                            local foundGroup = foundItem:getGroup()
                            curGroup = foundGroup
                        end
                    end
                end
            end       
        end
        world.searchObjects(Object.Category.UNIT, volS, ifFound)

        if curGroup and mindistance then
            return curGroup
        else
            return false
        end
    end
end

--## Group added class function
--GOAP.goToRandomPoint(group, destination, GOAP.repositionDistance, 10, forceRoadUse)

function Group:groupRoadOnly()
    local grTbl = self
    if grTbl then
        local units = grTbl:getUnits()
        for uId, uData in pairs(units) do
            if uData:hasAttribute("Trucks") or uData:hasAttribute("Cars") or uData:hasAttribute("Unarmed vehicles") then
                env.info(("GOAP, groupRoadOnly found at least one road only unit!"))
                return true
            end
        end
    end
    env.info(("GOAP, groupRoadOnly no road only unit found, or no grTbl"))
    return false
end

function Group:goToRandomPoint(Vec3destination, destRadius, destInnerRadius, useRoad, formation) -- move the group to a point or, if the point is missing, to a random position at about 2 km
    local group = self -- GOAP.groupTableCheck(var)
    if group then	   		
        local unit1 = group:getUnit(1)
        local curPoint = unit1:getPosition().p
        local point = Vec3destination --required
        local dist = GOAP.getDist(point,curPoint)
        if dist > 1000 then
            useRoad = true
        end

        local rndCoord = nil
        if point == nil then
            point = GOAP.getRandTerrainPointInCircle(group:getPosition().p, GOAP.emergencyWithdrawDistance*1.1, GOAP.emergencyWithdrawDistance*0.9) -- IMPROVE DEST POINT CHECKS!
            rndCoord = point
        end
        
        if point then	
            local radius = destRadius or 10
            local innerRadius = destInnerRadius or 1		
            local form = formation or 'Offroad'
            local heading = math.random()*2*math.pi
            local speed = nil


            local useRoads
            if not useRoad then
                useRoads = group:groupRoadOnly()
            else
                useRoads = useRoad
            end
            
            local speed = nil
            if useRoads == false then
                speed = GOAP.outRoadSpeed
            else
                speed = GOAP.inRoadSpeed
            end

            local path = {}

            if heading >= 2*math.pi then
                heading = heading - 2*math.pi
            end
            
            if not rndCoord then
                rndCoord = GOAP.getRandTerrainPointInCircle(point, radius, innerRadius)
            end
            
            if rndCoord then
                env.info(("GOAP, goToRandomPoint has coordinate"))
                local offset = {}
                local posStart = group:getLeadPos()

                offset.x = GOAP.roundNumber(math.sin(heading - (math.pi/2)) * 50 + rndCoord.x, 3)
                offset.z = GOAP.roundNumber(math.cos(heading + (math.pi/2)) * 50 + rndCoord.y, 3)
                path[#path + 1] = GOAP.buildWP(posStart, form, speed)


                if useRoads == true and ((point.x - posStart.x)^2 + (point.z - posStart.z)^2)^0.5 > radius * 1.3 then
                    path[#path + 1] = GOAP.buildWP({x = posStart.x + 11, z = posStart.z + 11}, 'off_road', GOAP.outRoadSpeed)
                    path[#path + 1] = GOAP.buildWP(posStart, 'on_road', speed)
                    path[#path + 1] = GOAP.buildWP(offset, 'on_road', speed)
                else
                    path[#path + 1] = GOAP.buildWP({x = posStart.x + 25, z = posStart.z + 25}, form, speed)
                end

                path[#path + 1] = GOAP.buildWP(offset, form, speed)
                path[#path + 1] = GOAP.buildWP(rndCoord, form, speed)

                env.info(("GOAP, goToRandomPoint routing group"))
                if GOAP.debugProcessDetail then
                    dumpTable("path.lua", path)
                end
                group:goRoute(path)

                return
            else
                env.info(("GOAP, goToRandomPoint failed, no valid destination available"))
            end
        else
            env.info(("GOAP, goToRandomPoint failed, no valid destination available"))
        end
    end
end

function Group:getLeadPos(group)
    group = self
    
    --if type(group) == 'string' then -- group name
        --group = Group.getByName(group)
    --end

    local units = group:getUnits()

    local leader = units[1]
    if not Unit.isExist(leader) then	-- SHOULD be good, but if there is a bug, this code future-proofs it then.
        local lowestInd = math.huge
        for ind, unit in pairs(units) do
            if Unit.isExist(unit) and ind < lowestInd then
                lowestInd = ind
                return unit:getPosition().p
            end
        end
    end
    if leader and Unit.isExist(leader) then	-- maybe a little too paranoid now...
        return leader:getPosition().p
    end
end

function Group:goRoute(path)
    local group = self -- GOAP.groupTableCheck(var)
    if group then
        local misTask = {
            id = 'Mission',
            params = {
                route = {
                    points = GOAP.deepCopy(path),
                },
            },
        }

        local groupCon = group:getController()
        if groupCon then
            groupCon:setTask(misTask)
            env.info(("GOAP, goRoute task set"))
            return true
        end
        return false
    end
end

--## CURRENT MISSION CONDITIONS

-- road usage
local forceRoadUse = nil
if env.mission.weather.clouds.iprecptns > 0 then
    forceRoadUse = true
end


--## AI INFORMATIVE CHECKS
function Group:hasTargets()
    local group = self --GOAP.groupTableCheck(var[1])
    if group then	
        local tblUnits = Group.getUnits(group)
        local coalition = Group.getCoalition(group)
        if table.getn(tblUnits) > 0 then
            local hastargets = false
            local tbltargets = {}
            for uId, uData in pairs(tblUnits) do
                local uController = uData:getController()
                local utblTargets = uController:getDetectedTargets()
                if utblTargets then
                    if table.getn(utblTargets) > 0 then
                        for _, _tData in pairs(utblTargets) do
                            tbltargets[#tbltargets+1] = _tData
                            hastargets = true
                        end
                    end
                else
                    env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " utblTargets is nil"))
                end
            end

            if hastargets == true then
                --dumpTable("tbltargets_" .. tostring(uId) .. ".lua", tbltargets)
                env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " has targets"))

                -- update main tgt table
                local info_avail = false
                for _, tData in pairs(tbltargets) do
                    if GOAP.addTgtToKnownTarget(tData, coalition) then
                        info_avail = true
                    end
                end

                -- end function
                if info_avail then
                    return true, tbltargets
                else
                    env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " has contact but not identified yet"))
                    return false
                end
            else
                env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " do not have targets"))
                return false
            end            
            
        else
            env.error(("GOAP.hasTargets: tblUnits has 0 units"))
            return false			
        end
    else
        env.error(("GOAP.hasTargets: group is nil"))
        return false	
    end	
end

function Group:groupLowAmmo()
    local group = self--GOAP.groupTableCheck(var)
    if group then	
        local tblUnits = group:getUnits()
        local groupSize = group:getSize()
        local groupOutAmmo = 0
        
        if tblUnits and groupSize then
            if table.getn(tblUnits) > 0 then
                for uId, uData in pairs(tblUnits) do
                    local uAmmo = uData:getAmmo()
                    if uAmmo then
                        for aId, aData in pairs(uAmmo) do
                            if aData.count == 0 then
                                groupOutAmmo = groupOutAmmo + 1
                            end
                        end
                    else    
                        groupOutAmmo = groupOutAmmo + 1
                    end
                end
            else
                env.error(("GOAP.groupLowAmmo, tblUnits is 0"))
                return false				
            end
        else
            env.error(("GOAP.groupLowAmmo, missing tblUnits or groupSize"))
            return false		
        end

        local fraction = groupOutAmmo/tonumber(groupSize)
        if fraction then
            if fraction > GOAP.outAmmoLowLevel then
                return true
            else
                return false
            end
        else
            env.error(("GOAP.groupLowAmmo, error calculating fraction"))
            return false		
        end
    end
end

function Group:groupHasLosses()
    local group = self -- GOAP.groupTableCheck(var)
    if group then		
        local curSize = group:getSize()
        local iniSize = group:getInitialSize()
        if iniSize == curSize then
            return false
        else
            return true
        end
    end
end

function Group:getClass()
    local group = self
    if group then
        local units = group:getUnits()
        local attrib = {}
        local strenght = 0
        local coa = group:getCoalition()
        if units and coa then
            for _, unit in pairs(units) do
            
                if unit:hasAttribute("Ground Units") then
                    if unit:hasAttribute("Air") or unit:hasAttribute("Ships") or unit:hasAttribute("Buildings") then -- cut off all "non ground units", safety check
                        return false

                    elseif unit:hasAttribute("Tanks") then
                        attrib[#attrib+1] = "Tank"
                        strenght = strenght + math.floor(unit:getLife0()*10/3)/10

                    elseif unit:hasAttribute("ATGM") then
                        attrib[#attrib+1] = "Ranged"
                        strenght = strenght + unit:getLife0()

                    elseif unit:hasAttribute("Artillery") then
                        attrib[#attrib+1] = "Arty"
                        strenght = strenght + unit:getLife0()  

                    elseif unit:hasAttribute("SAM") then
                        attrib[#attrib+1] = "MovingSAM"
                        strenght = strenght + unit:getLife0()                         

                    elseif unit:hasAttribute("Air Defence vehicles") then
                        attrib[#attrib+1] = "AntiAir"
                        strenght = strenght + unit:getLife0() 

                    elseif unit:hasAttribute("Armored vehicles") then
                        attrib[#attrib+1] = "Armored"
                        strenght = strenght + unit:getLife0()

                    elseif unit:hasAttribute("Armed vehicles") then
                        attrib[#attrib+1] = "Movers"
                        strenght = strenght + unit:getLife0()

                    elseif unit:hasAttribute("Unarmed vehicles") then
                        attrib[#attrib+1] = "Logistic"
                        strenght = strenght + unit:getLife0()             

                    elseif unit:hasAttribute("Infantry") then
                        attrib[#attrib+1] = "Infantry"
                        strenght = strenght + unit:getLife0()   
                    else
                        attrib[#attrib+1] = "Others"
                        strenght = strenght + unit:getLife0()   
                    end
                else
                    env.info(("GOAP.getClass, is not a ground unit"))
                    return false
                end

            end

            return strenght, coa, attrib

        else
            env.error(("GOAP.getClass, missing units"))
            return false
        end
    else
        env.error(("GOAP.getClass, missing group"))
        return false
    end
end



--## AI BASIC STATE ACTION
function Group:groupGoQuiet()
    local group = self -- GOAP.groupTableCheck(var)
    if group then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 1) -- green -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.groupGoQuiet status quiet"))
        end			
    end
end

function Group:groupGoActive()
    local group = self -- GOAP.groupTableCheck(var)
    if group then	
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.groupGoActive status active and return fire"))
        end				
    end
end

function Group:groupGoShoot()
    local group = self -- GOAP.groupTableCheck(var)
    if group then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 2) -- open fire -- Ground or GROUND?
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.groupGoShoot status fire at will"))
        end			
    end
end

function Group:groupAllowDisperse()
    local group = self --GOAP.groupTableCheck(var)
    if group then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, GOAP.disperseActionTime) -- Ground or GROUND?
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupAllowDisperse will allow dispersal"))
            end		
        else
            env.error(("GOAP.groupAllowDisperse, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.error(("GOAP.groupAllowDisperse, missing group"))        
    end
end

function Group:groupPreventDisperse()
    local group = self -- GOAP.groupTableCheck(var)
    if group then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, false) -- Ground or GROUND?
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupPreventDisperse will prevent dispersal"))
            end		
        else
            env.error(("GOAP.groupPreventDisperse, missing controller for: " ..tostring(group:getName())))
        end
    else
        env.error(("GOAP.groupPreventDisperse, missing group"))    
    end
end


--## AI BASIC MOVEMENT & ACTION
function Group:goStop()
    local group = self
    if group then
        trigger.action.groupStopMoving(group)
        return true
    else
        env.error(("GOAP.goStop, missing variable"))
        return false
    end
end

function Group:groupReposition()
    local group = self -- GOAP.groupTableCheck(var)
    if group then
        local firstUnit = group:getUnit(1)
        if firstUnit then
            local samePosition = firstUnit:getPosition().p
            group:goToRandomPoint(samePosition, GOAP.repositionDistance*1.1, GOAP.repositionDistance*0.9)
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupReposition group is repositioning"))
            end		
        else
            env.error(("GOAP.groupReposition missing firstUnit"))
        end
    end
end

function Group:goToTown(tName, action)
    
    --if var then
        --dumpTable("variables.lua", var)
        local group = self -- var[1] -- GOAP.groupTableCheck(var[1])
        local town = GOAP.townTableCheck(tName)
        --local action = var[2]
        env.info(("GOAP, goToTown, tName: " .. tostring(tName)))
        env.info(("GOAP, goToTown, action: " .. tostring(action)))

        if group and town then		
            local destination = coord.LLtoLO(town.latitude, town.longitude , 0)
            if destination then
                group:goToRandomPoint(destination, GOAP.repositionDistance, 10, forceRoadUse)
                if action then -- action is a stored function inside the var table
                    env.info(("GOAP, goToTown, action present"))
                    action(group)
                end
                return true		
            else
                env.error(("GOAP, goToTown, missing destination"))
                return false
            end
        else
            env.error(("GOAP, goToTown, missing group or town"))
            return false
        end
    --else
    --    env.error(("GOAP.goToTown, missing variable"))
    --    return false
    --end
end

function Group:haltOnContact()
    local group = self -- var[1] -- GOAP.groupTableCheck(var[1])

    if group then
        --dumpTable("group.lua", group)
        if Group.hasTargets(group) then
            env.info(("GOAP.haltOnContact, stopping group"))
            group:goStop()
            return true
        else
            env.info(("GOAP.haltOnContact, no contact, rescheduling"))
            local function schedFunc()
                group:haltOnContact()
            end
            timer.scheduleFunction(schedFunc, {}, timer.getTime() + 30)
        end
    else
        env.error(("GOAP.haltOnContact, missing group"))
    end
end

function Group:groupfireAtPoint(var) -- 1 is group, 2 is vec3, 3 is quantity
    local group = self -- var[1] -- GOAP.groupTableCheck(var[1])
    if group then
        local gController = group:getController()
        local vec3 = GOAP.vec3Check(var[1])
        local qty = var[2]
        if gController and vec3 then
            local expd = true
            if not var[2] then
                expd = nil
                qty = nil
            end

            local _tgtVec2 =  { x = vec3.x  , y = vec3.z} 
            local _task = { 
                id = 'FireAtPoint', 
                params = { 
                point = _tgtVec2,
                radius = 200,
                expendQty = qty,
                expendQtyEnabled = expd,
                }
            } 

            gController:pushTask(_task)
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupfireAtPoint will allow dispersal"))
            end		
        else
            env.error(("GOAP.groupfireAtPoint, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.error(("GOAP.groupfireAtPoint, missing group"))        
    end
end

--## AI EVENT FEEDBACK

-- under attack
GOAP.underAttack = {} -- define under attack action and suppression
function GOAP.underAttack:onEvent(event)	
    if event.id == world.event.S_EVENT_HIT then 
        local unit 			= event.target
        local shooter       = event.initiator
        if unit then
            local group     = unit:getGroup()
            local position  = unit:getPosition().p
            local coalition = unit:getCoalition()
            
            local othercoa  = "none"
            if shooter then
                othercoa = shooter:getCoalition()
            end
            
            local vehicle   = unit:hasAttribute("Vehicles")
            local infantry  = unit:hasAttribute("Infantry")

            if coalition ~= othercoa then
                if vehicle or infantry then
                    if GOAP.debugProcessDetail == true then
                        env.info(("GOAP.underAttack group " .. group:getName() .. " is under attack"))
                        --trigger.action.outText("GOAP.underAttack group " .. group:getName() .. " is under attack", 10)
                    end
                    
                    local grp = unit:getGroup()
                    if grp then
                        grp:groupReposition()
                    end

                    if GOAP.debugProcessDetail == true then
                        env.info(("GOAP.underAttack now checking shooter info"))
                    end                        
                    local vCrtl = unit:getController()
                    if vCrtl then
                        local tgtTbl = vCrtl:getDetectedTargets()
                        local actionDone = false
                        if tgtTbl then
                            if #tgtTbl > 0 then
                                for tId, tData in pairs(tgtTbl) do
                                    if GOAP.debugProcessDetail == true then
                                        env.info(("GOAP.underAttack checking shooter id: " .. tostring(tId)))
                                    end
                                    if actionDone == false then
                                        if tData.object == shooter then
                                            if GOAP.debugProcessDetail == true then
                                                env.info(("GOAP.underAttack shooter identified"))
                                            end
                                            if tData.type == true then
                                                if shooter:hasAttribute("Air") then
                                                    if GOAP.debugProcessDetail == true then
                                                        env.info(("GOAP.underAttack shooter is air based"))
                                                    end
                                                    GOAP.callSupport({unit, "Mobile AAA", coalition})
                                                    GOAP.callSupport({unit, "SR SAM", coalition})
                                                    actionDone = true

                                                else
                                                    if GOAP.debugProcessDetail == true then
                                                        env.info(("GOAP.underAttack shooter is ground based"))
                                                    end
                                                    GOAP.callSupport({unit, nil, coalition})
                                                    actionDone = true

                                                end
                                            else
                                                if GOAP.debugProcessDetail == true then
                                                    env.info(("GOAP.underAttack by unidentified target"))
                                                end
                                                GOAP.callSupport({unit, nil, coalition})
                                                actionDone = true                                             
                                            end
                                        end  
                                    end
                                end
                            else
                                env.info(("GOAP.underAttack no detected targets"))
                            end
                        else
                            env.info(("GOAP.underAttack target has no detected shooter"))
                        end
                    else
                        env.error(("GOAP.underAttack target vCrtlmissing"))
                    end
                    -- ADD ACTION!
                    
                end
            end
        else
            env.error(("GOAP.underAttack, missing unit"))
        end
    end
end
world.addEventHandler(GOAP.underAttack)	

-- birth
GOAP.unitBirth = {} -- define under attack action and suppression
function GOAP.unitBirth:onEvent(event)	
    if event.id == world.event.S_EVENT_BIRTH then
        local unit = event.initiator
        if unit then
            local group = unit:getGroup()
            if group then
                local id = group:getID()
                local check = false
                for iId, iData in pairs(currentGroupTable) do
                    if iId == iData.id then
                        check = true
                    end
                end

                if check == true then
                    return false
                else
                    currentGroupTable[#currentGroupTable+1] = {id = group:getID() , Group = group}
                    return true
                end

            else
                env.error(("GOAP.unitBirth, missing group"))
            end
        else
            env.error(("GOAP.unitBirth, missing unit"))
        end
    end
end
world.addEventHandler(GOAP.unitBirth)	    


--## AI MOVEMENT TASKS
function GOAP.callSupport(var) -- var[1] can be: vec3, group/unit/static table or name, trigger zone table or name. var[2] is support category requested or, if nil, GOAP.supportUnitCategories. var[3] is coalition, or any
    
    local destPoint = nil
    if type(var[1]) == "table" then        
        -- check vector. if no vector, then is an object (supposed)
        if var[1].x and var[1].y and var[1].z then -- is coordinates
            destPoint = var[1]
        elseif var[1].point then -- is a trigger zone
            destPoint = var[1].point
        else -- SHOULD BE AN OBJECT, HOPEFULLY
            destPoint = var[1]:getPosition().p
        end
    elseif type(var[1]) == "string" then
        local group = Group.getByName(var[1])
        if group then
            local firstUnit = group:getUnit(1)
            destPoint = firstUnit:getPosition().p
        end
        local unit = Unit.getByName(var[1])
        if unit then
            destPoint = unit:getPosition().p
        end
        local static = 	StaticObject.getByName(var[1])
        if static then
            destPoint = static:getPosition().p
        end
        local zone = 	trigger.misc.getZone(var[1])
        if zone then
            destPoint = zone.point
        end
    end

    if destPoint then
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.callSupport point is identified"))
        end
        local supCat = var[2] or GOAP.supportUnitCategories
        local near_group = GOAP.findGroupInRange(destPoint, supCat, GOAP.supportDist, var[3])

        if near_group then
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.callSupport group found"))
            end
            near_group:goToRandomPoint(destPoint, 200, 50, false)
        else
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.callSupport no available support in range"))
            end
        end
    else
        env.error(("GOAP.callSupport failed to retrieve destPoint"))
    end
end


--## AI INITIAL SET FUCTION
function GOAP.setAllNotDisperse()
    for coalitionID,coalition in pairs(env.mission["coalition"]) do
        for countryID,country in pairs(coalition["country"]) do
            for attrID,attr in pairs(country) do
                if attrID == "vehicle" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local groupName = env.getValueDictByKey(group.name)
                                local groupTbl = Group.getByName(groupName)
                                if groupTbl then
                                    groupTbl:groupPreventDisperse()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end










--## MISSION START PROCESS
env.info(("GOAP is starting initial mission setup"))
-- set all units disperse "off" to prevent halting for movement & escape reactions

-- get terrains influence
GOAP.phase0_initTerrains()


GOAP.setAllNotDisperse()
-- create the basic unit list table
GOAP.phaseB_createIntelBase(env.mission)

-- initialize FSM cycle
GOAP.performPhaseCycle()





--## MISSION UPDATE PROCESS 




--## DEBUGGER
local groupTest = Group.getByName("Tester")
if groupTest then
    --GOAP.goToTown({groupTest, "ZUGDIDI"})    -- , GOAP.haltOnContact
    local function executeThis()
        groupTest:goToTown("ZUGDIDI", Group.haltOnContact)
    end

    timer.scheduleFunction(executeThis, {}, timer.getTime() + 10)
end

local function callchecks(vars)
    local gtest = vars[1]
    env.info(("GOAP GOAP.hasTargets: " .. tostring(GOAP.hasTargets(gtest))))
    env.info(("GOAP GOAP.groupLowAmmo: " .. tostring(GOAP.groupLowAmmo(gtest))))
    env.info(("GOAP GOAP.groupHasLosses: " .. tostring(GOAP.groupHasLosses(gtest))))

    timer.scheduleFunction(callchecks, {gtest}, timer.getTime() + 60)
end