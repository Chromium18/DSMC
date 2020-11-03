-- Dynamic Sequential Mission Campaign -- AI ENHANCEMENT MOVE injected module

local ModuleName  	= "MOVE"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0100"
local Date			= "17/10/2020"

--## MAIN TABLE
MOVE                                = {}

--## LOCAL VARIABLES
--env.setErrorMessageBoxEnabled(false)
local base 						    = _G
local DSMC_io 					    = base.io  	-- check if io is available in mission environment
local DSMC_lfs 					    = base.lfs		-- check if lfs is available in mission environment
local phase_index                      = 1

MOVE.debugProcessDetail             = DSMC_debugProcessDetail or false
MOVE.outRoadSpeed                   = 28,8/3.6	-- km/h /3.6, cause DCS thinks in m/s	
MOVE.inRoadSpeed                    = 54/3.6	-- km/h /3.6, cause DCS thinks in m/s
MOVE.outAmmoLowLevel                = 0.7		-- factor on total amount
MOVE.TerrainDb                      = {}
MOVE.disperseActionTime				= 120		-- seconds
MOVE.emergencyWithdrawDistance		= 2000 		-- meters
MOVE.repositionDistance				= 300		-- meters
MOVE.supportDist                    = 20000     -- m of distance max between objective point and group
MOVE.townControlRadius              = 1500      -- m from town center in which the update function will check presence of more than 1 coalition to define owner
MOVE.supportUnitCategories  ={
    [1] = "Armed vehicles",
    [2] = "AntiAir Armed Vehicles",
}

MOVE.intel                          = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}
MOVE.ORBAT                          = {}

if DSMC_io and DSMC_lfs then
	env.info(("MOVE loading desanitized additional function"))
	
	DSMC_MOVEmodule 	= "funzia"
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

	function MOVE.saveTable(fname, tabledata)		
		if DSMC_lfs and DSMC_io then
			local DSMCfiles = DSMC_lfs.writedir() .. "Missions/Temp/Files/"
			local fdir = DSMCfiles .. fname .. ".lua"
			local f = DSMC_io.open(fdir, 'w')
			local str = IntegratedserializeWithCycles(fname, tabledata)
			f:write(str)
			f:close()
		end
	end
	
	env.info(("MOVE desanitized additional function loaded"))
end

--## TOWNS TABLE
if env.mission.theatre == "Caucasus" then
    local tTbl = {}
    for tName, tData in pairs(CaucasusTowns) do
        tTbl[#tTbl+1] = tData
    end
    MOVE.TerrainDb["towns"] = tTbl
    CaucasusTowns = nil
elseif env.mission.theatre == "Nevada" then
    local tTbl = {}
    for tName, tData in pairs(NevadaTowns) do
        tTbl[#tTbl+1] = tData
    end
    MOVE.TerrainDb["towns"] = tTbl
    NevadaTowns = nil
elseif env.mission.theatre == "Normandy" then
    local tTbl = {}
    for tName, tData in pairs(NormandyTowns) do
        tTbl[#tTbl+1] = tData
    end
    MOVE.TerrainDb["towns"] = tTbl
    NormandyTowns = nil
elseif env.mission.theatre == "PersianGulf" then
    local tTbl = {}
    for tName, tData in pairs(PersianGulfTowns) do
        tTbl[#tTbl+1] = tData
    end
    MOVE.TerrainDb["towns"] = tTbl
    PersianGulfTowns = nil
elseif env.mission.theatre == "TheChannel" then
    local tTbl = {}
    for tName, tData in pairs(TheChannelTowns) do
        tTbl[#tTbl+1] = tData
    end
    MOVE.TerrainDb["towns"] = tTbl
    TheChannelTowns = nil
elseif env.mission.theatre == "Syria" then
    local tTbl = {}
    for tName, tData in pairs(SyriaTowns) do
        tTbl[#tTbl+1] = tData
    end
    MOVE.TerrainDb["towns"] = tTbl
    SyriaTowns = nil
else
    env.error(("MOVE, no theater identified: halting everything"))
    return
end

if not MOVE.TerrainDb["towns"] then
    env.error(("MOVE, no TerrainDb table: halting everything"))
    return
end

--## CIRCULAR FINITE STATE MACHINE UPDATE INFO
local phase = "A"
function MOVE.changePhase()
    if phase == "A" then -- udpate terrain data
        phase = "B"
        phase_index = 1
        if MOVE.debugProcessDetail then
            env.info(("MOVE, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "B" then
        phase = "C"
        phase_index = 1
        if MOVE.debugProcessDetail then
            env.info(("MOVE, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "C" then
        phase = "D"
        phase_index = 1
        if MOVE.debugProcessDetail then
            env.info(("MOVE, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "D" then
        phase = "E"
        phase_index = 1
        if MOVE.debugProcessDetail then
            env.info(("MOVE, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "E" then
        phase = "F"
        phase_index = 1
        if MOVE.debugProcessDetail then
            env.info(("MOVE, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "F" then
        phase = "A"
        phase_index = 1
        if MOVE.debugProcessDetail then
            env.info(("MOVE, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    end
end

-- phase cycle
function MOVE.performPhaseCycle()
    if phase == "A" then
        MOVE.phaseA_updateTerrain(MOVE.TerrainDb)
    elseif phase == "B" then
        MOVE.phaseB_updateIntel(env.mission)
        --env.info(("MOVE, performPhaseCycle: phase skipped " .. tostring(phase)))
        --phase = "C"
        --MOVE.performPhaseCycle()
    elseif phase == "C" then
        env.info(("MOVE, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "D"
        MOVE.performPhaseCycle()
    elseif phase == "D" then
        env.info(("MOVE, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "E"
        MOVE.performPhaseCycle()
    elseif phase == "E" then
        env.info(("MOVE, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "F"
        MOVE.performPhaseCycle()
    elseif phase == "F" then
        env.info(("MOVE, performPhaseCycle: phase skipped " .. tostring(phase)))
        phase = "A"
        MOVE.performPhaseCycle()
    end
end

-- update terrain data
function MOVE.phaseA_updateTerrain(tblTerrain)
    --env.info(("MOVE, phaseA_updateTerrain: starting"))

    if phase == "A" then
        if tblTerrain then
            if tblTerrain.towns then
                
                -- check if Cycle is done
                if phase_index > #tblTerrain.towns then
                    env.info(("MOVE, phaseA_updateTerrain: phase A completed"))
                    MOVE.changePhase()
                    timer.scheduleFunction(MOVE.performPhaseCycle, {}, timer.getTime() + 1)
                    dumpTable("MOVEterrainDB.lua", MOVE.TerrainDb)
                else
                    for tId, tData in pairs(tblTerrain.towns) do
                        if tId == phase_index then
                            
                            -- update phase_index
                            phase_index = phase_index + 1

                            -- perform update
                            if tData and type(tData) == "table" then
                                --env.info(("MOVE, phaseA_updateTerrain updating " .. tostring(tData.display_name)))
                                local vec3 = MOVE.townToVec3(tData.display_name)
                                if vec3 then
                                    local _volume = {
                                        id = world.VolumeType.SPHERE,
                                        params = {
                                            point = vec3,
                                            radius = MOVE.townControlRadius
                                        }
                                    }
                                    
                                    local _unitList = {}

                                    local _search = function(_unit)
                                        pcall(function()
                                            if _unit ~= nil and _unit:getLife() > 0 and not _unit:inAir() then
                                                local _coa =_unit:getCoalition()
                                                if _coa then
                                                    table.insert(_unitList,{unit=_unit, coa=_coa})
                                                end
                                            end
                                        end)
                                        return true
                                    end       
                                
                                    world.searchObjects(Object.Category.UNIT, _volume, _search)
                                
                                    if #_unitList == 0 then
                                        tData.owner = 0  -- zero means no one!
                                        --env.info(("MOVE, phaseA_updateTerrain " .. tostring(tData.display_name) .. " no units, is neutral"))
                                        tblTerrain.towns[tId] = tData
                                    else
                                        local unitscount = 0
                                        local coaBlue = 0
                                        local coaRed = 0
                                        local coaOther = 0
                                        for uId, uData in pairs(_unitList) do
                                            unitscount = unitscount + 1
                                            if uData.coa == 1 then
                                                coaRed = coaRed + 1
                                            elseif uData.coa == 2 then
                                                coaBlue = coaBlue + 1
                                            elseif uData.coa == 3 then
                                                coaOther = coaOther + 1             
                                            end
                                        end

                                        if coaBlue == unitscount then
                                            tData.owner = 2
                                            tblTerrain.towns[tId] = tData
                                            --env.info(("MOVE, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as " .. tostring(2)))
                                        elseif coaRed == unitscount then
                                            tData.owner = 1
                                            tblTerrain.towns[tId] = tData
                                            --env.info(("MOVE, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as " .. tostring(1)))
                                        elseif coaOther == unitscount then
                                            tData.owner = 3
                                            tblTerrain.towns[tId] = tData
                                            --env.info(("MOVE, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as " .. tostring(3)))                                
                                        else
                                            tData.owner = 9
                                            tblTerrain.towns[tId] = tData
                                            --env.info(("MOVE, phaseA_updateTerrain " .. tostring(tData.display_name) .. " defined as contended"))
                                        end
                                    end
                                    --env.info(("MOVE, phaseA_updateTerrain " .. tostring(tData.display_name) .. " updated"))
                                else
                                    env.error(("MOVE, phaseA_updateTerrain: town missing vec3"))
                                end
                            else
                                env.error(("MOVE, phaseA_updateTerrain: town missing tData"))
                            end
                        end
                    end

                    timer.scheduleFunction(MOVE.performPhaseCycle, {}, timer.getTime() + 0.1)

                end
            else
                env.error(("MOVE, phaseA_updateTerrain: tblTerrain.towns missing"))
            end
        else
            env.error(("MOVE, phaseA_updateTerrain: tblTerrain missing"))
        end
    end -- phase check
end

-- collect intel
local currentGroupTable = {}
function MOVE.phaseB_createIntelBase(tblMission)
    for coalitionID,coalition in pairs(tblMission["coalition"]) do
        for countryID,country in pairs(coalition["country"]) do
            for attrID,attr in pairs(country) do
                if attrID ~= "static" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local gName = env.getValueDictByKey(group.name)
                                if gName then
                                    local gTbl = MOVE.groupTableCheck(gName)
                                    if gTbl then
                                        env.info(("MOVE, phaseB_createIntelBase: adding " .. tostring(gName)))   
                                        currentGroupTable[#currentGroupTable+1] = {id = gTbl:getID() , Group = gTbl, coa = gTbl:getCoalition()}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    dumpTable("currentGroupTable.lua", currentGroupTable)
end

function MOVE.phaseB_updateIntel(tblMission)
    --env.info(("MOVE, phaseB_updateIntel: starting"))        

    if phase == "B" then        
        if #currentGroupTable ~= 0 then
            
            -- check if Cycle is done
            if phase_index > #currentGroupTable then
                env.info(("MOVE, phaseB_updateIntel: phase B completed"))
                MOVE.changePhase()
                timer.scheduleFunction(MOVE.performPhaseCycle, {}, timer.getTime() + 1)
                dumpTable("MOVE.intel.lua", MOVE.intel)
            else
                for gId, gData in pairs(currentGroupTable) do
                    if gId == phase_index then
                        --env.info(("MOVE, phaseB_updateIntel: updating target from id: " ..  tostring(gId)))
                        MOVE.groupHasTargets({gData.Group})
                    end
                end
                phase_index = phase_index + 1
                MOVE.performPhaseCycle()
            end
        else
            env.error(("MOVE, phaseB_updateIntel: currentGroupTable is equal to zero"))
        end

    end
end


-- update info
function MOVE.phaseC_updateORBAT(tblMission)
    if phase == "C" then        
        if #currentGroupTable ~= 0 then
            
            -- check if Cycle is done
            if phase_index > #currentGroupTable then
                env.info(("MOVE, phaseC_updateORBAT: phase B completed"))
                MOVE.changePhase()
                timer.scheduleFunction(MOVE.performPhaseCycle, {}, timer.getTime() + 1)
                dumpTable("MOVE.ORBAT.lua", MOVE.intel)
            else
                for gId, gData in pairs(currentGroupTable) do
                    if gId == phase_index then
                        env.info(("MOVE, phaseC_updateORBAT: updating target from id: " ..  tostring(gId)))
                        local group = {}
                        local  g = gData.Group

                        --define Category
                        if g:hasAttribute("Artillery") and  g:hasAttribute("Armed vehicles") then
                            -- DA QUIII
                        end
                                               
                    end
                end
                phase_index = phase_index + 1
                MOVE.performPhaseCycle()
            end
        else
            env.error(("MOVE, phaseB_updateIntel: currentGroupTable is equal to zero"))
        end
    end
end



-- do GOAP
---------------------------add

-- back to update
---------------------------add


--## GOAP IMPLEMENTATION

-- Tables
MOVE.tblActionPlan = {
    ["G_Scout"] = {
        ["preq"] = {"RECON_avail"},
        ["gain"] = "Information",
        ["action"] = "MOVE.groupMoveToTown", 
        ["subaction"] = "MOVE.haltOnContact", 
        ["basecost"] = 10,
    },
    ["G_Attack"] = {
        ["preq"] = {"Information", "PositiveForce", "ARMED_avail"},
        ["gain"] = "TownControl",
        ["action"] = "MOVE.groupMoveToTown",
        ["subaction"] = nil,
        ["basecost"] = 20,
    },
    ["G_FireMission"] = {
        ["preq"] = {"PositiveForce", "ARTY_avail"},
        ["gain"] = "TownControl",
        ["action"] = "MOVE.groupfireAtPoint",
        ["subaction"] = nil,
        ["basecost"] = 5,
    },
    ["G_ARTY_Reposition"] = {
        ["preq"] = {"ARTY_exist"},
        ["gain"] = "ARTY_avail",
        ["action"] = "MOVE.groupMoveToTown",
        ["subaction"] = nil,
        ["basecost"] = 5,
    },
    ["G_ARMED_Reposition"] = {
        ["preq"] = {"ARMED_exist"},
        ["gain"] = "ARMED_avail",
        ["action"] = "MOVE.groupMoveToTown",
        ["subaction"] = "MOVE.haltOnContact", 
        ["basecost"] = 5,
    },
    ["G_SHORAD_Reposition"] = {
        ["preq"] = {"SHORAD_exist"},
        ["gain"] = "SHORAD_avail",
        ["action"] = "MOVE.groupMoveToTown",
        ["subaction"] = nil,
        ["basecost"] = 5,
    },
    ["G_withdraw"] = {
        ["preq"] = {"NegativeForce", "WithdrawAvailable"},
        ["gain"] = "TownControl",
        ["action"] = "MOVE.groupMoveToTown",
        ["subaction"] = nil,
        ["basecost"] = 10,
    },




}




--## UTILS, BASIC CHECK & SAFETY FUNCTIONS
function MOVE.getDist(point1, point2)
    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone
    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function MOVE.groupTableCheck(group)
    if group then
        if type(group) == 'string' then -- assuming name
            local groupTable = Group.getByName(group)
            return groupTable
        elseif type(group) == 'table' then
            return group
        else
            env.error(("MOVE, groupTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("MOVE, groupTableCheck: missing variable"))
        return nil
    end
end

function MOVE.townTableCheck(town)
    if town then
        if type(town) == 'string' then -- assuming name
            local townTable = nil
            for tName, tData in pairs(MOVE.TerrainDb.towns) do
                if town == tData.display_name then
                    return tData
                end
            end
            env.error(("MOVE, townTableCheck: no town available"))
            return nil

        elseif type(town) == 'table' then
            return town
        else
            env.error(("MOVE, townTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("MOVE, townTableCheck: missing variable"))
        return nil
    end
end

function MOVE.townToVec3(town)
    local placeData = MOVE.townTableCheck(town)
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

function MOVE.unitTableCheck(unit)
    if unit then
        if type(unit) == 'string' then -- assuming name
            local unitTable = Unit.getByName(unit)
            return unitTable
        elseif type(unit) == 'table' then
            return unit
        else
            env.error(("MOVE, unitTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("MOVE, unitTableCheck: missing variable"))
        return nil
    end
end

function MOVE.vec3Check(vec3)
    if vec3 then
        if type(vec3) == 'table' then -- assuming name
            if vec3.x and vec3.y and vec3.z then			
                return vec3
            else
                env.error(("MOVE, vec3Check: wrong vector format"))
                return nil
            end
        else
            env.error(("MOVE, vec3Check: wrong variable"))
            return nil
        end
    else
        env.error(("MOVE, vec3Check: missing variable"))
        return nil
    end
end

function MOVE.groupRoadOnly(group)
    if group then
        local grTbl = nil
        if type(group) == 'string' then -- assuming name
            grTbl = Group.getByName(group)
        elseif type(group) == 'table' then
            grTbl =  group
        else
            env.error(("MOVE, groupRoadOnly: wrong variable"))
        end

        if grTbl then
            local units = grTbl:getUnits()
            for uId, uData in pairs(units) do
                if uData:hasAttribute("Trucks") or uData:hasAttribute("Cars") or uData:hasAttribute("Unarmed vehicles") then
                    env.info(("MOVE, groupRoadOnly found at least one road only unit!"))
                    return true
                end
            end
        end
        env.info(("MOVE, groupRoadOnly no road only unit found, or no grTbl"))
        return false
    else
        env.error(("MOVE, groupRoadOnly: missing variable"))
        return nil
    end
end

--## MIST IMPORTED AND MODIFIED FUNCS
--MOVE.groupToRandomPoint(group, destination, MOVE.repositionDistance, 10, forceRoadUse)
function MOVE.groupToRandomPoint(var, Vec3destination, destRadius, destInnerRadius, useRoad, formation) -- move the group to a point or, if the point is missing, to a random position at about 2 km
    local group = MOVE.groupTableCheck(var)
    if group then	   		
        local unit1 = group:getUnit(1)
        local curPoint = unit1:getPosition().p
        local point = Vec3destination --required
        local dist = MOVE.getDist(point,curPoint)
        if dist > 1000 then
            useRoad = true
        end

        local rndCoord = nil
        if point == nil then
            point = MOVE.getRandTerrainPointInCircle(group:getPosition().p, MOVE.emergencyWithdrawDistance*1.1, MOVE.emergencyWithdrawDistance*0.9) -- IMPROVE DEST POINT CHECKS!
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
                useRoads = MOVE.groupRoadOnly(group)
            else
                useRoads = useRoad
            end
            
            local speed = nil
            if useRoads == false then
                speed = MOVE.outRoadSpeed
            else
                speed = MOVE.inRoadSpeed
            end

            local path = {}

            if heading >= 2*math.pi then
                heading = heading - 2*math.pi
            end
            
            if not rndCoord then
                rndCoord = MOVE.getRandTerrainPointInCircle(point, radius, innerRadius)
            end
            
            if rndCoord then
                env.info(("MOVE, groupToRandomPoint has coordinate"))
                local offset = {}
                local posStart = MOVE.getLeadPos(group)

                offset.x = MOVE.roundNumber(math.sin(heading - (math.pi/2)) * 50 + rndCoord.x, 3)
                offset.z = MOVE.roundNumber(math.cos(heading + (math.pi/2)) * 50 + rndCoord.y, 3)
                path[#path + 1] = MOVE.buildWP(posStart, form, speed)


                if useRoads == true and ((point.x - posStart.x)^2 + (point.z - posStart.z)^2)^0.5 > radius * 1.3 then
                    path[#path + 1] = MOVE.buildWP({x = posStart.x + 11, z = posStart.z + 11}, 'off_road', MOVE.outRoadSpeed)
                    path[#path + 1] = MOVE.buildWP(posStart, 'on_road', speed)
                    path[#path + 1] = MOVE.buildWP(offset, 'on_road', speed)
                else
                    path[#path + 1] = MOVE.buildWP({x = posStart.x + 25, z = posStart.z + 25}, form, speed)
                end

                path[#path + 1] = MOVE.buildWP(offset, form, speed)
                path[#path + 1] = MOVE.buildWP(rndCoord, form, speed)

                env.info(("MOVE, groupToRandomPoint routing group"))
                dumpTable("path.lua", path)
                MOVE.goRoute(group, path)

                return
            else
                env.info(("MOVE, groupToRandomPoint failed, no valid destination available"))
            end
        else
            env.info(("MOVE, groupToRandomPoint failed, no valid destination available"))
        end
    end
end

function MOVE.getRandPointInCircle(point, radius, innerRadius)
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

function MOVE.getRandTerrainPointInCircle(var, radius, innerRadius)
    local point = MOVE.vec3Check(var)	
    if point and radius and innerRadius then
        
        for i = 1, 5 do
            local coordRun = MOVE.getRandPointInCircle(point, radius, innerRadius)
            local destlandtype = land.getSurfaceType({coordRun.x, coordRun.z})
            if destlandtype == 1 or destlandtype == 4 then
                env.info(("MOVE, getRandTerrainPointInCircle found valid vec3 point"))
                return coordRun
            end
        end
        env.info(("MOVE, getRandTerrainPointInCircle no valid Vec3 point found!"))
        return nil -- this means that no valid result has found
        
    end
end

function MOVE.getLeadPos(group)
    if type(group) == 'string' then -- group name
        group = Group.getByName(group)
    end

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

function MOVE.roundNumber(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end 

function MOVE.buildWP(point, overRideForm, overRideSpeed)

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

function MOVE.goRoute(var, path)
    local group = MOVE.groupTableCheck(var)
    if group then
        local misTask = {
            id = 'Mission',
            params = {
                route = {
                    points = MOVE.deepCopy(path),
                },
            },
        }

        local groupCon = group:getController()
        if groupCon then
            groupCon:setTask(misTask)
            env.info(("MOVE, goRoute task set"))
            return true
        end
        return false
    end
end

function MOVE.deepCopy(object)
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

--## CURRENT MISSION CONDITIONS

-- road usage
local forceRoadUse = nil
if env.mission.weather.clouds.iprecptns > 0 then
    forceRoadUse = true
end


--## AI INFORMATIVE CHECKS
function MOVE.groupHasTargets(var)
    local group = MOVE.groupTableCheck(var[1])
    if group then	
        local tblUnits = group:getUnits()
        local coalition = group:getCoalition()
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
                    env.info(("MOVE, groupHasTargets: group .. " ..  tostring(group:getName()) .. " utblTargets is nil"))
                end
            end

            if hastargets == true then
                --dumpTable("tbltargets_" .. tostring(uId) .. ".lua", tbltargets)
                env.info(("MOVE, groupHasTargets: group .. " ..  tostring(group:getName()) .. " has targets"))

                -- update main tgt table
                for _, tData in pairs(tbltargets) do
                    MOVE.addTgtToKnownTarget(tData, coalition)
                end

                -- end function
                return true, tbltargets
            else
                env.info(("MOVE, groupHasTargets: group .. " ..  tostring(group:getName()) .. " do not have targets"))
                return false
            end            
            
        else
            env.error(("MOVE.groupHasTargets: tblUnits has 0 units"))
            return false			
        end
    else
        env.error(("MOVE.groupHasTargets: group is nil"))
        return false	
    end	
end

function MOVE.groupLowAmmo(var)
    local group = MOVE.groupTableCheck(var)
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
                env.error(("MOVE.groupLowAmmo, tblUnits is 0"))
                return false				
            end
        else
            env.error(("MOVE.groupLowAmmo, missing tblUnits or groupSize"))
            return false		
        end

        local fraction = groupOutAmmo/tonumber(groupSize)
        if fraction then
            if fraction > MOVE.outAmmoLowLevel then
                return true
            else
                return false
            end
        else
            env.error(("MOVE.groupLowAmmo, error calculating fraction"))
            return false		
        end
    end
end

function MOVE.groupHasLosses(var)
    local group = MOVE.groupTableCheck(var)
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

function MOVE.addTgtToKnownTarget(tData, coa)
    if tData then
        if tData.object then
            local tgtType = "unknown"
            local tgtPos = "unknown"
            local t_type = tData.type
            local t_Id = tData.object:getID()
            if t_type then
                tgtType = tData.object:getTypeName()
                tgtPos = tData.object:getPosition().p
                env.info(("MOVE.addTgtToKnownTarget, data: t_type: " .. tostring(t_type)))

                for xCoa, xData in pairs(MOVE.intel) do
                    if coa == xCoa then
                        local id = tData.object:getID()
                        local tgtData = {}
                        tgtData.type = tgtType
                        tgtData.pos = tgtPos
                        tgtData.time = timer.getTime() 
                        tgtData.strenght = tData.object:getLife0()

                        xData[id] = tgtData
                    end
                end
            else
                env.error(("MOVE.addTgtToKnownTarget, missing type"))
                return false           
            end
        else
            env.error(("MOVE.addTgtToKnownTarget, missing tData.object"))
        end

    else
        env.error(("MOVE.addTgtToKnownTarget, missing variable"))
        return false	
    end

end

function MOVE.findGroupInRange(support_point, attribute, distance, coalition)
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
                        local dist = MOVE.getDist(itemPos, support_point)
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


--## AI BASIC STATE ACTION
function MOVE.groupGoQuiet(var)
    local group = MOVE.groupTableCheck(var)
    if group then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 1) -- green -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if MOVE.debugProcessDetail == true then
            env.info(("MOVE.groupGoQuiet status quiet"))
        end			
    end
end

function MOVE.groupGoActive(var)
    local group = MOVE.groupTableCheck(var)
    if group then	
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if MOVE.debugProcessDetail == true then
            env.info(("MOVE.groupGoActive status active and return fire"))
        end				
    end
end

function MOVE.groupGoShoot(var)
    local group = MOVE.groupTableCheck(var)
    if group then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 2) -- open fire -- Ground or GROUND?
        if MOVE.debugProcessDetail == true then
            env.info(("MOVE.groupGoShoot status fire at will"))
        end			
    end
end

function MOVE.groupAllowDisperse(var)
    local group = MOVE.groupTableCheck(var)
    if group then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, MOVE.disperseActionTime) -- Ground or GROUND?
            if MOVE.debugProcessDetail == true then
                env.info(("MOVE.groupAllowDisperse will allow dispersal"))
            end		
        else
            env.error(("MOVE.groupAllowDisperse, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.error(("MOVE.groupAllowDisperse, missing group"))        
    end
end

function MOVE.groupPreventDisperse(var)
    local group = MOVE.groupTableCheck(var)
    if group then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, false) -- Ground or GROUND?
            if MOVE.debugProcessDetail == true then
                env.info(("MOVE.groupPreventDisperse will prevent dispersal"))
            end		
        else
            env.error(("MOVE.groupPreventDisperse, missing controller for: " ..tostring(group:getName())))
        end
    else
        env.error(("MOVE.groupPreventDisperse, missing group"))    
    end
end


--## AI BASIC MOVEMENT ACTION
function MOVE.groupStop(var)
    local group = var[1]
    if group then
        trigger.action.groupStopMoving(group)
        return true
    else
        env.error(("MOVE.groupStop, missing variable"))
        return false
    end
end

function MOVE.groupReposition(var)
    local group = MOVE.groupTableCheck(var)
    if group then
        local firstUnit = group:getUnit(1)
        if firstUnit then
            local samePosition = firstUnit:getPosition().p
            MOVE.groupToRandomPoint(group, samePosition, MOVE.repositionDistance*1.1, MOVE.repositionDistance*0.9)
            if MOVE.debugProcessDetail == true then
                env.info(("MOVE.groupReposition group is repositioning"))
            end		
        else
            env.error(("MOVE.groupReposition missing firstUnit"))
        end
    end
end

function MOVE.groupMoveToTown(var)
    
    if var then

        local group = MOVE.groupTableCheck(var[1])
        local town = MOVE.townTableCheck(var[2])
        local action = var[3]

        if group and town then		
            local destination = coord.LLtoLO(town.latitude, town.longitude , 0)
            if destination then
                MOVE.groupToRandomPoint(group, destination, MOVE.repositionDistance, 10, forceRoadUse)
                if action then -- action is a stored function inside the var table
                    env.info(("MOVE.groupMoveToTown, action present"))
                    action({group}) -- use haltOnContact here!!
                end
                return true		
            else
                env.error(("MOVE.groupMoveToTown, missing destination"))
                return false
            end
        else
            env.error(("MOVE.groupMoveToTown, missing group or town"))
            return false
        end
    else
        env.error(("MOVE.groupMoveToTown, missing variable"))
        return false
    end
end

function MOVE.haltOnContact(var)
    local group = MOVE.groupTableCheck(var[1])

    if group then
        if MOVE.groupHasTargets({group}) then
            env.info(("MOVE.haltOnContact, stopping group"))
            MOVE.groupStop({group})
            return true
        else
            env.info(("MOVE.haltOnContact, no contact, rescheduling"))
            timer.scheduleFunction(MOVE.haltOnContact, {group}, timer.getTime() + 30)
        end
    else
        env.error(("MOVE.haltOnContact, missing group"))
    end
end

--## AI BASIC TASK ACTION
function MOVE.groupfireAtPoint(var) -- 1 is group, 2 is vec3, 3 is quantity
    local group = MOVE.groupTableCheck(var[1])
    if group then
        local gController = group:getController()
        local vec3 = MOVE.vec3Check(var[2])
        local qty = var[3]
        if gController and vec3 then
            local expd = true
            if not var[3] then
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
            if MOVE.debugProcessDetail == true then
                env.info(("MOVE.groupfireAtPoint will allow dispersal"))
            end		
        else
            env.error(("MOVE.groupfireAtPoint, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.error(("MOVE.groupfireAtPoint, missing group"))        
    end
end

--## AI EVENT FEEDBACK

-- under attack
MOVE.underAttack = {} -- define under attack action and suppression
function MOVE.underAttack:onEvent(event)	
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
                    if MOVE.debugProcessDetail == true then
                        env.info(("MOVE.underAttack group " .. group:getName() .. " is under attack"))
                        --trigger.action.outText("MOVE.underAttack group " .. group:getName() .. " is under attack", 10)
                    end
                    
                    local grp = unit:getGroup()
                    if grp then
                        MOVE.groupReposition(grp)
                    end

                    if MOVE.debugProcessDetail == true then
                        env.info(("MOVE.underAttack now checking shooter info"))
                    end                        
                    local vCrtl = unit:getController()
                    if vCrtl then
                        local tgtTbl = vCrtl:getDetectedTargets()
                        local actionDone = false
                        if tgtTbl then
                            if #tgtTbl > 0 then
                                for tId, tData in pairs(tgtTbl) do
                                    if MOVE.debugProcessDetail == true then
                                        env.info(("MOVE.underAttack checking shooter id: " .. tostring(tId)))
                                    end
                                    if actionDone == false then
                                        if tData.object == shooter then
                                            if MOVE.debugProcessDetail == true then
                                                env.info(("MOVE.underAttack shooter identified"))
                                            end
                                            if tData.type == true then
                                                if shooter:hasAttribute("Air") then
                                                    if MOVE.debugProcessDetail == true then
                                                        env.info(("MOVE.underAttack shooter is air based"))
                                                    end
                                                    MOVE.callSupport({unit, "Mobile AAA", coalition})
                                                    MOVE.callSupport({unit, "SR SAM", coalition})
                                                    actionDone = true

                                                else
                                                    if MOVE.debugProcessDetail == true then
                                                        env.info(("MOVE.underAttack shooter is ground based"))
                                                    end
                                                    MOVE.callSupport({unit, nil, coalition})
                                                    actionDone = true

                                                end
                                            else
                                                if MOVE.debugProcessDetail == true then
                                                    env.info(("MOVE.underAttack by unidentified target"))
                                                end
                                                MOVE.callSupport({unit, nil, coalition})
                                                actionDone = true                                             
                                            end
                                        end  
                                    end
                                end
                            else
                                env.info(("MOVE.underAttack no detected targets"))
                            end
                        else
                            env.info(("MOVE.underAttack target has no detected shooter"))
                        end
                    else
                        env.error(("MOVE.underAttack target vCrtlmissing"))
                    end
                    -- ADD ACTION!
                    
                end
            end
        else
            env.error(("MOVE.underAttack, missing unit"))
        end
    end
end
world.addEventHandler(MOVE.underAttack)	

-- birth
MOVE.unitBirth = {} -- define under attack action and suppression
function MOVE.unitBirth:onEvent(event)	
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
                env.error(("MOVE.unitBirth, missing group"))
            end
        else
            env.error(("MOVE.unitBirth, missing unit"))
        end
    end
end
world.addEventHandler(MOVE.unitBirth)	    


--## AI MOVEMENT TASKS
function MOVE.callSupport(var) -- var[1] can be: vec3, group/unit/static table or name, trigger zone table or name. var[2] is support category requested or, if nil, MOVE.supportUnitCategories. var[3] is coalition, or any
    
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
        if MOVE.debugProcessDetail == true then
            env.info(("MOVE.callSupport point is identified"))
        end
        local supCat = var[2] or MOVE.supportUnitCategories
        local near_group = MOVE.findGroupInRange(destPoint, supCat, MOVE.supportDist, var[3])

        if near_group then
            if MOVE.debugProcessDetail == true then
                env.info(("MOVE.callSupport group found"))
            end
            MOVE.groupToRandomPoint(near_group, destPoint, 200, 50, false)
        else
            if MOVE.debugProcessDetail == true then
                env.info(("MOVE.callSupport no available support in range"))
            end
        end
    else
        env.error(("MOVE.callSupport failed to retrieve destPoint"))
    end
end


--## AI INITIAL SET FUCTION
function MOVE.setAllNotDisperse()
    for coalitionID,coalition in pairs(env.mission["coalition"]) do
        for countryID,country in pairs(coalition["country"]) do
            for attrID,attr in pairs(country) do
                if (type(attr)=="table") then
                    for groupID,group in pairs(attr["group"]) do
                        if (group) then
                            local groupName = env.getValueDictByKey(group.name)
                            local groupTbl = Group.getByName(groupName)
                            MOVE.groupPreventDisperse(groupTbl)
                        end
                    end
                end
            end
        end
    end
end










--## MISSION START PROCESS
env.info(("MOVE is starting initial mission setup"))
-- set all units disperse "off" to prevent halting for movement & escape reactions
MOVE.setAllNotDisperse()
-- create the basic unit list table
MOVE.phaseB_createIntelBase(env.mission)

-- initialize FSM cycle
MOVE.performPhaseCycle()





--## MISSION UPDATE PROCESS 




--## DEBUGGER
local groupTest = Group.getByName("Tester")
if groupTest then
    --MOVE.groupMoveToTown({groupTest, "ZUGDIDI"})    -- , MOVE.haltOnContact
    timer.scheduleFunction(MOVE.groupMoveToTown, {groupTest, "ZUGDIDI", MOVE.haltOnContact}, timer.getTime() + 10)
end

local function callchecks(vars)
    local gtest = vars[1]
    env.info(("MOVE MOVE.groupHasTargets: " .. tostring(MOVE.groupHasTargets(gtest))))
    env.info(("MOVE MOVE.groupLowAmmo: " .. tostring(MOVE.groupLowAmmo(gtest))))
    env.info(("MOVE MOVE.groupHasLosses: " .. tostring(MOVE.groupHasLosses(gtest))))

    timer.scheduleFunction(callchecks, {gtest}, timer.getTime() + 60)
end