-- Dynamic Sequential Mission Campaign -- DSMC core injected functions module
-- REWORK T/O and LAND to allow multiple sorties!

local ModuleName  	= "WRHS"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0019"
local Date			= "05/07/2020"

--env.setErrorMessageBoxEnabled(false)
local base 						= _G
local DSMC_io 					= base.io  	-- check if io is available in mission environment
local DSMC_lfs 					= base.lfs	-- check if lfs is available in mission environment
local sanitizedMode             = true
local minimumPercentageBuilding = 0.70      -- 40% building
local PSupdate                  = 60        -- seconds
local maxAptdistance            = 3000      -- m distance of nearest airbase

-- logistic specific setup
local allowPhysicalLogistic     = false
local allowLogistic             = true
local POLtonByhours             = 10
local AMMOtonByhours            = 5

WRHSJ 							= {}

if not tblLogisticAdds then
    tblLogisticAdds = {}
    if DSMC_debugProcessDetail == true then
        env.info(("WRHSJ created tblLogisticAdds"))
    end  
end

if DSMC_io and DSMC_lfs then
    sanitizedMode             = false
    env.info(("WRHSJ sanitizedMode : " .. tostring(sanitizedMode)))
end

if EMBD and dbWeapon then
    allowLogistic = true
    env.info(("WRHSJ allowLogistic : " .. tostring(allowLogistic)))
else
    env.info(("WRHSJ code stopped: no EMBD & dbWeapon available"))
    return
end

-- built zone table
-- this function requires Scenery setup by the player, which will need to create "word coded" zones (see manual).
-- i.e. A zone named "Example refinery" will be set as POL production site, due to the keyword "refinery". 
-- DSMC use scenery object to define logistic production site: no additional object is required! 
-- To make a production site work, its zone must contain at least 1 object, more than a certain percentage of builings must be alive (minimumPercentageBuilding), and at least one group of a coalition must be within the zone (to define coalition)
-- production sites MUST be choosen nearby a road

WRHSJ.tblProdSites 	= {}
WRHSJ.tblAirbases	= {}

WRHSJ.POLkeywords 	= {
    [1] = "refinery",
    [2] = "oil facility",
    [3] = "gas processing",
    [4] = "oil rig",
    [5] = "oil platform",
}

WRHSJ.AMMOkeywords 	= {
    [1] = "weapon factory",
    [2] = "ammunition deposit",
}

WRHSJ.ELECkeywords 	= {
    [1] = "electric plant",
}

WRHSJ.availableTransport = {}

WRHSJ.radioCommTracker = {}

WRHSJ.actionsType = {
    ["Request transport by road"] = "convoy",
    ["Request transport by sea"] = "ship",
    ["Request transport by air"] = "plane",
}

WRHSJ.contentType = {
    ["POL"] = "exist",
    ["Ammo"] = "exist",
}

WRHSJ.transportType = {
    ["ship"] = {speed = 10, lag = 1800},
    ["plane"] = {speed = 150, lag = 1800},
    ["convoy"] = {speed = 15, lag = 1},
    ["helicopter"] = {speed = 50, lag = 600},
}

-- util functions
function WRHSJ.getDistance(_point1, _point2)

    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function WRHSJ.getGroupId(_unit)
	if _unit then
		
		local _group = _unit:getGroup()
		local _groupId = _group:getID()
		return _groupId
	
	end
	
	return nil
    
end

function WRHSJ.getAptInfo()
	local apt_Table = world.getAirbases()
	for Aid, Adata in pairs(apt_Table) do
		local aptInfo = Adata:getDesc()
		local aptName = Adata:getName()
		local aptID	  = Adata:getID()
		local indexId = Aid
		local aptPos = Adata:getPosition().p
		if aptPos then
			local zApt_x, zApt_z = land.getClosestPointOnRoads('roads',aptPos.x, aptPos.z)
			local zRoad = {x = zApt_x, y = aptPos.y, z = zApt_z}
			WRHSJ.tblAirbases[#WRHSJ.tblAirbases+1] = {id = aptID, index = aptID, name = aptName, desc = aptInfo, pos = aptPos, roadPos = zRoad}
		end
    end
    
    if DSMC_debugProcessDetail == true then
        dumpTable("WRHSJ.tblAirbases.lua", WRHSJ.tblAirbases)
    end    
end

-- populate production site
function WRHSJ.builtProductionSitesTable()
    for zId, zData in pairs(env.mission.triggers.zones) do
        
        local yAlt = land.getHeight({zData.x, zData.y})
        local zPos = {x = zData.x, y = yAlt, z = zData.y}
        local zRoad_x, zRoad_y = land.getClosestPointOnRoads('roads',zData.x, zData.y)
        local zRoad = {x = zRoad_x, y = land.getHeight({zRoad_x, zRoad_y}), z = zRoad_y}
        local tempObj = {}
        local numSO = 0
        local vol = {
            id = world.VolumeType.BOX,
            params = {
                min = {x=zData.x-zData.radius, z=zData.y-zData.radius, y=0},
                max = {x=zData.x+zData.radius, z=zData.y+zData.radius, y=10000}, -- Or a high altitude if math.huge doesn't work
            }
        }        
        --[[
        local volS = {
          id = world.VolumeType.SPHERE,
          params = {
            point = zPos,
            radius = zData.radius
          }
        }
        --]]--        
        local ifFound  = function(foundItem, val)
            numSO = numSO + 1
            local name = foundItem:getName()
            local obj = SceneryObject.getDescByName(name)
            tempObj[#tempObj+1] = tostring(obj.typeName)
        end     
        world.searchObjects(Object.Category.SCENERY, vol, ifFound)  

        -- check POL sites. Keywords defined in WRHSJ.POLkeywords table
        local isPol = false
        for _, keyword in pairs(WRHSJ.POLkeywords) do
            if string.find(zData.name, keyword) then 
                isPol = true
            end
        end        
        
        -- check AMMO sites. Keywords defined in WRHSJ.AMMOkeywords table
        local isAmmo = false
        for _, keyword in pairs(WRHSJ.AMMOkeywords) do
            if string.find(zData.name, keyword) then 
                isAmmo = true
            end
        end

        -- check ELEC sites. Keywords defined in WRHSJ.ELECkeywords table
        local isElec = false
        for _, keyword in pairs(WRHSJ.ELECkeywords) do
            if string.find(zData.name, keyword) then 
                isElec = true
            end
        end

        local identiFiedSite = false
        if isPol == true then
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ zone " .. tostring(zData.name) .. " is POL prod. site"))
            end
            identiFiedSite = true
            WRHSJ.tblProdSites[#WRHSJ.tblProdSites +1] = {Otype = "POL", id = zData.zoneId, name = zData.name, pos = zPos, nearbyRoadVec3 = zRoad, coa = 0, radius = zData.radius, productivity = 1, sizeObj = tempObj, size = numSO, airbase = false, POLton = POLtonByhours, AMMOton = 0}
        elseif isAmmo == true then
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ zone " .. tostring(zData.name) .. " is AMMO prod. site"))
            end   
            identiFiedSite = true     
            WRHSJ.tblProdSites[#WRHSJ.tblProdSites +1] = {Otype = "Ammo",id = zData.zoneId, name = zData.name, pos = zPos, nearbyRoadVec3 = zRoad, coa = 0, radius = zData.radius, productivity = 1, sizeObj = tempObj, size = numSO, airbase = false, POLton = 0, AMMOton = AMMOtonByhours}
        elseif isElec == true then
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ zone " .. tostring(zData.name) .. " is ELEC prod. site"))
            end      
            identiFiedSite = true  
            WRHSJ.tblProdSites[#WRHSJ.tblProdSites +1] = {Otype = "Power",id = zData.zoneId, name = zData.name, pos = zPos, nearbyRoadVec3 = zRoad, coa = 0, radius = zData.radius, productivity = 1, sizeObj = tempObj, size = numSO, airbase = false, POLton = 0, AMMOton = 0}
        else
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ zone " .. tostring(zData.name) .. " is not a precise site"))
            end            
        end

        if identiFiedSite == true then
            for eId, eData in pairs(env.mission.triggers.zones) do
                local start, stop = string.find(eData.name, "DSMC_ScenDest_")
                if start and stop then
                    local sub = string.sub(eData.name, stop+1)
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ sub: " .. tostring(sub)))
                    end
                    
                    for xId, xData in pairs(WRHSJ.tblProdSites) do
                        local curValue = nil
                        for tId, tData in pairs(xData.sizeObj) do
                            if tData == sub then
                                if DSMC_debugProcessDetail == true then
                                    env.info(("WRHSJ sub removed 1 object"))
                                end                        
                                table.remove(xData.sizeObj, tId)
                                --tId = nil
                            end
                        end

                        local curValue = table.getn(xData.sizeObj)
                        if DSMC_debugProcessDetail == true then
                            env.info(("WRHSJ sub removed 1 object"))
                        end                      
                        local prodVal = nil
                        if curValue then
                            prodVal = curValue/xData.productivity
                        end

                        if prodVal then
                            xData.productivity = prodVal
                        end
                    end
                end
            end
        end

    end

    if DSMC_debugProcessDetail == true then
        dumpTable("WRHSJ.tblProdSites.lua", WRHSJ.tblProdSites)
    end
end

-- update prod site for coalition and airbase availability
function WRHSJ.updateProductionSites()

    for pId, pData in pairs(WRHSJ.tblProdSites) do
        if DSMC_debugProcessDetail == true then
            env.info(("WRHSJ updateProductionSites, checking site: " ..tostring(pData.name)))
        end        
        -- update coalition
        local numBlue = 0
        local numRed = 0
        local numNeut = 0
        local grFound = function(foundItem, val)
            if foundItem:getCoalition() == 0 then
                numNeut = numNeut + 1
            elseif foundItem:getCoalition() == 1 then
                numRed = numRed + 1
            elseif foundItem:getCoalition() == 2 then
                numBlue = numBlue + 1
            end
            --return true
        end 

        local vol = {
            id = world.VolumeType.BOX,
            params = {
                min = {x=pData.pos.x-pData.radius, z=pData.pos.z-pData.radius, y=0},
                max = {x=pData.pos.x+pData.radius, z=pData.pos.z+pData.radius, y=10000}, -- Or a high altitude if math.huge doesn't work
            }
        } 

        world.searchObjects(Object.Category.UNIT, vol, grFound) 

        if numNeut > 0 and numBlue == 0 and numRed == 0 then
            pData.coa = 0
        elseif numRed > 0 and numBlue == 0 and numNeut == 0 then
            pData.coa = 1
        elseif numBlue > 0 and numRed == 0 and numNeut == 0 then
            pData.coa = 2
        end

        if DSMC_debugProcessDetail == true then
            env.info(("WRHSJ updateProductionSites, site: " ..tostring(pData.name) .." updated coalition to " .. tostring(pData.coa)))
        end

        -- check airbase capacity
        if tostring(pData.coa) == "1" or tostring(pData.coa) == "2" then
            pData.airbase = false
            local abTbl = coalition.getAirbases(tonumber(pData.coa))
            if abTbl then                 
                if table.getn(abTbl) > 0 then                     
                    for aId, aData in pairs(abTbl) do
                        local aName = aData:getName()                                                  
                        if aData then
                            local helipadExclusion = aData:hasAttribute("Heliports")
                            local aPos = aData:getPosition().p
                            local dist = WRHSJ.getDistance(aPos, pData.pos)
                            if dist then
                                if dist < maxAptdistance and not helipadExclusion then
                                    pData.airbase = true
                                    if DSMC_debugProcessDetail == true then
                                        env.info(("WRHSJ updateProductionSites, site: " ..tostring(pData.name) .." is nearby an airbase"))
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
        env.info(("WRHSJ updateProductionSites, cicle done"))
        dumpTable("WRHSJ.tblProdSites.lua", WRHSJ.tblProdSites)
    end
    timer.scheduleFunction(WRHSJ.updateProductionSites, {}, timer.getTime() + PSupdate) 
end

-- populate availableTransport
function WRHSJ.builtAvailableTransport()
    for i = 1,2,1 do
        WRHSJ.availableTransport[i] = {}
        for wId, wType in pairs(WRHSJ.contentType) do
            WRHSJ.availableTransport[i][wId] = {}
            WRHSJ.availableTransport[i][wId]["convoy"] = {}
        end
        
        if DSMC_debugProcessDetail == true then
            env.info(("WRHSJ builtAvailableTransport, checking coalition: " ..tostring(i)))
        end  
        local apt_Table = coalition.getAirbases(i)
        if apt_Table then
            dumpTable("WRHSJ.apt_Table.lua", apt_Table)
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ builtAvailableTransport, there is an apt_Table"))
            end              
            for Aid, Adata in pairs(apt_Table) do
                local Aname = Adata:getName()
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ builtAvailableTransport, checking airbase: " ..tostring(Aname)))
                end                 
            
                if Adata:hasAttribute("Heliports") then
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ builtAvailableTransport, it's an helipad: " .. tostring(Aname)))
                    end                     
                    WRHSJ.transportType["ship"] = nil -- future update
                    WRHSJ.transportType["plane"] = nil
                    WRHSJ.transportType["helicopter"] = nil -- future update
                else
                    WRHSJ.transportType["ship"] = nil -- future update
                    WRHSJ.transportType["helicopter"] = nil -- future update
                end

                local Apos = Adata:getPosition().p
                
                -- roadType definition
                if Apos then
                    local siteList = {}
                    					
					for eId, eType in pairs(WRHSJ.contentType) do
                        --WRHSJ.availableTransport[i][eId] = {}
                        --WRHSJ.availableTransport[i][eId]["convoy"] = {}
                        local atLeastOnePath = false
                        for pId, pData in pairs(WRHSJ.tblProdSites) do                        
                            
                            if tostring(pData.coa) == tostring(i) then
								if eId == pData.Otype then
									if DSMC_debugProcessDetail == true then
										env.info(("WRHSJ builtAvailableTransport, site: " ..tostring(pData.name) .." is for coalition " .. tostring(pData.coa)))
									end                            
									local point1X, point1Y = land.getClosestPointOnRoads("roads", Apos.x, Apos.z)                    
                                    local path = land.findPathOnRoads("roads", point1X, point1Y, pData.nearbyRoadVec3.x, pData.nearbyRoadVec3.z)
                                    if not path then
                                        path = land.findPathOnRoads("roads", point1X+1000, point1Y+1000, pData.nearbyRoadVec3.x, pData.nearbyRoadVec3.z)
                                    end
                                    if not path then
                                        path = land.findPathOnRoads("roads", point1X-1000, point1Y-1000, pData.nearbyRoadVec3.x, pData.nearbyRoadVec3.z)
                                    end
                                    if not path then
                                        path = land.findPathOnRoads("roads", point1X+1000, point1Y-1000, pData.nearbyRoadVec3.x, pData.nearbyRoadVec3.z)
                                    end
                                    if not path then
                                        path = land.findPathOnRoads("roads", point1X-1000, point1Y+1000, pData.nearbyRoadVec3.x, pData.nearbyRoadVec3.z)
                                    end

                                    --local path = land.findPathOnRoads("roads", Apos.x, Apos.z, pData.nearbyRoadVec3.x, pData.nearbyRoadVec3.z)  
									if path then
										if DSMC_debugProcessDetail == true then
											env.info(("WRHSJ builtAvailableTransport, path has valid points to " .. tostring(Aname)))
										end
										atLeastOnePath = true
										siteList[#siteList+1] = {name = pData.name}   --, data = pData

									else
										if DSMC_debugProcessDetail == true then
											env.info(("WRHSJ builtAvailableTransport, no path available! to " .. tostring(Aname)))
										end  
									end
								end
							end
						end
						if atLeastOnePath then	
							WRHSJ.availableTransport[i][eId]["convoy"][Aname] = siteList
						end
					end

                else
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ builtAvailableTransport, missing airport position " .. tostring(Aname)))
                    end                          
                end



            end
        end
    end
    if DSMC_debugProcessDetail == true then
        env.info(("WRHSJ builtAvailableTransport, cicle done"))
        dumpTable("WRHSJ.availableTransport.lua", WRHSJ.availableTransport)
    end

end

-- populate radio menù for relevant groups
WRHSJ.addF10MenuOptions = {}
function WRHSJ.addF10MenuOptions:onEvent(event)
    
    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
    
        if DSMC_debugProcessDetail == true then
            env.info(("WRHSJ.addF10MenuOptions started"))
        end

        --timer.scheduleFunction(WRHSJ.addF10MenuOptions, {}, timer.getTime() + 10)

        local currentPlayers = {}
        for i = 1,2,1 do
            local Pl = coalition.getPlayers(i)
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ.addF10MenuOptions Pl ok, coalition: " ..tostring(i)))
                --dumpTable("Pl.lua", Pl)
            end        
            for oId, Obj in pairs(Pl) do
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ.addF10MenuOptions Obj tbl"))
                end              
                if Obj then
                    currentPlayers[#currentPlayers+1] = {id = Obj:getID(), name = Obj:getName(), unit = Obj}
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ.addF10MenuOptions added one player: " .. tostring(Obj:getName())))
                    end                
                end
            end
        end

        if event.initiator then
            --for _, plData in pairs(currentPlayers) do
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ.addF10MenuOptions there is event.initiator"))
                end              
                local _groupId = WRHSJ.getGroupId(event.initiator) -- plData.unit
                if _groupId then
                    if WRHSJ.radioCommTracker[tostring(_groupId)] == nil then
                        local _groupCoa = event.initiator:getCoalition()
                        if WRHSJ.radioCommTracker[tostring(_groupId)] == nil then
                            -- add submenù
                            local _rootPath = missionCommands.addSubMenuForGroup(_groupId, "Coalition Logistic", {"DSMC"})

                            -- add actions submenù
                            for eId, eData in pairs(WRHSJ.contentType) do
                                local _opsPath = missionCommands.addSubMenuForGroup(_groupId, "Request " .. tostring(eId) .. " supply", _rootPath)
                                for _subMenuName, aData in pairs(WRHSJ.actionsType) do
                                    local _actionPath = missionCommands.addSubMenuForGroup(_groupId, _subMenuName, _opsPath)
                                    

                                    
                                    for cId, cData in pairs (WRHSJ.availableTransport) do
                                        if tostring(cId) == tostring(_groupCoa) then
                                            if DSMC_debugProcessDetail == true then
                                                env.info(("WRHSJ.addF10MenuOptions coalition: " .. tostring(cId)))
                                            end  

                                            for rId, rData in pairs(cData) do
                                                if DSMC_debugProcessDetail == true then
                                                    env.info(("WRHSJ.addF10MenuOptions eId: " .. tostring(eId) .. ", rId: " .. tostring(rId)))
                                                end                                                  
                                                if eId == rId then
                                                    for tId, tData in pairs(rData) do
                                                        if DSMC_debugProcessDetail == true then
                                                            env.info(("WRHSJ.addF10MenuOptions tId: " .. tostring(tId) .. ", aData: " .. tostring(aData)))
                                                        end                                                     
                                                        if aData == tId then 
                                                            for sId, sData in pairs(tData) do
                                                                if DSMC_debugProcessDetail == true then
                                                                    env.info(("WRHSJ.addF10MenuOptions sId: " .. tostring(sId)))
                                                                end                                                          
                                                                local _airbasePath = missionCommands.addSubMenuForGroup(_groupId, sId, _actionPath)
                                                                
                                                                
                                                                for dId, dData in pairs(sData) do
                                                                    
                                                                    if eId == "POL" then
                                                                        missionCommands.addCommandForGroup(_groupId, "Issue order from ".. tostring(dData.name), _airbasePath, WRHSJ.planTransport, {from = dData.name, to = sId, vector = tId, fuelKg = 30, ammoAdd = nil})
                                                                        --trigger.action.outTextForCoalition(_groupCoa, "added a POL transport; from: " .. tostring(dData.name) .. " to: " ..tostring(sId) .. "by road, 30 tons of fuel", 10)
                                                                        if DSMC_debugProcessDetail == true then
                                                                            env.info(("WRHSJ.addF10MenuOptions added a POL transport; from: " .. tostring(dData.name) .. " to: " ..tostring(sId)))
                                                                        end   
                                                                    elseif eId == "Ammo" then
                                                                        missionCommands.addCommandForGroup(_groupId, "Issue order from ".. tostring(dData.name), _airbasePath, WRHSJ.planTransport, {from = dData.name, to = sId, vector = tId, fuelKg = nil, ammoAdd = true})
                                                                        --trigger.action.outTextForCoalition(_groupCoa, "added a POL transport; from: " .. tostring(dData.name) .. " to: " ..tostring(sId) .. "by road, ammunition replenishment", 10)
                                                                        if DSMC_debugProcessDetail == true then
                                                                            env.info(("WRHSJ.addF10MenuOptions added a POL transport; from: " .. tostring(dData.name) .. " to: " ..tostring(sId)))
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
                        WRHSJ.radioCommTracker[tostring(_groupId)] = true				
                    end
                else
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ.addF10MenuOptions missing _groupId"))
                    end  
                end

            --end
        else
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ.addF10MenuOptions missing event.initiator"))
            end  
        end
    end
end
world.addEventHandler(WRHSJ.addF10MenuOptions)

function WRHSJ.planTransport(args) 

    if args then
        
        local fromName = args.from
        local toName = args.to
        local vector = args.vector
        local fuelKg = args.fuelKg
        local ammoAdd = args.ammoAdd

        if DSMC_debugProcessDetail == true then
            env.info(("WRHSJ planTransport, vars list; fromName: " .. tostring(fromName) .. ", toName: " .. tostring(toName) .. ", vector: " .. tostring(vector) .. ", fuelKg: " .. tostring(fuelKg) .. ", ammoAdd: " .. tostring(ammoAdd)))
        end	        

        local fromPos = nil
        local toPos = nil
        local coalition = nil
        
        for pId, pData in pairs(WRHSJ.tblProdSites) do
            if pData.name == fromName then
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ planTransport, got fromPos"))
                end            
                fromPos = pData.nearbyRoadVec3
            end
        end
        
        for aId, aData in pairs(WRHSJ.tblAirbases) do
            if aData.name == toName then
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ planTransport, got toPos"))
                end            
                toPos = aData.roadPos
            end
        end
        
        if fromPos and toPos then
            if allowPhysicalLogistic then
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ planTransport, allowPhysicalLogistic is true"))
                end		
            
            else
                local dist = WRHSJ.getDistance(fromPos, toPos)
                if dist then
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ planTransport, dist: " .. tostring(dist)))
                    end                
                    for tId, tData in pairs(WRHSJ.transportType) do
                        if tId == vector then
                            local time = dist/tData.speed + tData.lag
                            if DSMC_debugProcessDetail == true then
                                env.info(("WRHSJ planTransport, time: " .. tostring(time)))
                            end	
                            local site = Airbase.getByName(toName)

                            if site then
                                coalition = site:getCoalition()
                                trigger.action.outTextForCoalition(coalition, "added a transport; from: " .. tostring(fromName) .. " to: " ..tostring(toName) .. "by road. ETA " .. tostring(math.floor(time/60)) .. " minutes", 10)
                                timer.scheduleFunction(WRHSJ.addResource, {site, fuelKg, ammoAdd}, timer.getTime() + time)
                                if DSMC_debugProcessDetail == true then
                                    env.info(("WRHSJ planTransport, set transport from: " .. tostring(fromName) .. ", to: " .. tostring(toName) .. ", by: " .. tostring(vector) .. ", POLton: " .. tostring(fuelKg) .. ", ammo: " .. tostring(ammoAdd)))
                                end	
                            else
                                if DSMC_debugProcessDetail == true then
                                    env.info(("WRHSJ planTransport, site missing"))
                                end	                            
                            end
                        end
                    end
                end
            end
        else
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ planTransport, missing fromPos and toPos"))
            end
        end
    else
        if DSMC_debugProcessDetail == true then
            env.info(("WRHSJ planTransport, missing args"))
        end   
    end
end


-- add resource to warehouse
function WRHSJ.addResource(args)
    if DSMC_debugProcessDetail == true then
        env.info(("WRHSJ.addResource started"))
    end	    
    
    if args then
        local site = args[1]
        local fuelKg = args[2]
        local ammoAdd = args[3]

        if site then
            local placeId_E 	= "none"
            local placeId_code	= "none"
            local placeName_E 	= "none"
            local placeType_E 	= "none"
            local placeCoa      = "none"
            if  site ~= "none" then             
                
                placeId_code	= tonumber(site:getID())
                placeId_E		= "missing"
                placeName_E		= tostring(site:getName())   
                placeCoa        = site:getCoalition()       
                if site:hasAttribute("Helipad") or site:hasAttribute("Ships") then
                    placeType_E 	= "warehouses"
                    placeId_E		= placeId_code               
                else
                    placeType_E 		= "airports"
                    for Anum, Adata in pairs(WRHSJ.tblAirbases) do
                        if Adata.name == placeName_E then
                            placeId_E = Adata.index
                            if DSMC_debugProcessDetail == true then
                                env.info(("WRHSJ.addResource identified airport id: " .. tostring(placeId_E) .. ", name: " .. tostring(Adata.name)))
                            end		                       						
                        end
                    end					
                end						
            end		
            
            if fuelKg then            
                if fuelKg > 0 then
                    fuelKg = fuelKg *1000
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ addResource, set POL operation"))
                    end	              
                    trigger.action.outTextForCoalition(placeCoa, "completed transport to " .. tostring(placeName_E) .. ", fuel added: " ..tostring(fuelKg) .. " kg", 10)	
                    tblLogisticAdds[#tblLogisticAdds+1] = {action = "arrival", acf = nil, placeId = placeId_E, placeName = placeName_E, placeType = placeType_E, fuel = fuelKg, ammo = nil, directammo = nil}           
                    if DSMC_debugProcessDetail == true then
                        env.info(("WRHSJ addResource, set POL operation done"))
                    end	   
                end
            end
            
            if ammoAdd then
                if DSMC_debugProcessDetail == true then
                    env.info(("WRHSJ addResource, set ammo operation"))
                end	
                trigger.action.outTextForCoalition(placeCoa, "completed transport to " .. tostring(placeName_E) .. ", ammunition added", 10)
                tblLogisticAdds[#tblLogisticAdds+1] = {action = "arrival", acf = nil, placeId = placeId_E, placeName = placeName_E, placeType = placeType_E, fuel = nil, ammo = nil, directammo = ammoAdd} 							
            end
        else
            if DSMC_debugProcessDetail == true then
                env.info(("WRHSJ.addResource site missing"))
            end          
        end
    end
end


-- function scheduler
WRHSJ.getAptInfo()
WRHSJ.builtProductionSitesTable()
timer.scheduleFunction(WRHSJ.updateProductionSites, {}, timer.getTime() + 2)
timer.scheduleFunction(WRHSJ.builtAvailableTransport, {}, timer.getTime() + 4)


