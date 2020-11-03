local base 							= _G

SUPP                                = {}
SUPP.outRoadSpeed                   = 30/3.6	-- km/h /3.6, cause DCS thinks in m/s. speed of units moving offroad
SUPP.inRoadSpeed                    = 60/3.6	-- km/h /3.6, cause DCS thinks in m/s. speed of units moving on road
SUPP.supportDist                    = 50000     -- m of distance max between objective point and group


SUPP.supportUnitCategories  ={
    [1] = "Armed vehicles",
    [2] = "AntiAir Armed Vehicles",
}






-- optional parameter: if it's raining, any unit MUST use roads to avoid getting stuck in mud
SUPP.forceRoadUse = nil
if env.mission.weather.clouds.iprecptns > 0 then
    SUPP.forceRoadUse = true
end

-- optional parameter: any unit must use road, due to DCS issues
SUPP.forceRoadUse = true

--##### DO NOT TOUCH BELOW UNLESS YOU KNOW WHAT YOU'RE DOING #####--


function SUPP.getDist(point1, point2)
    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone
    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function SUPP.groupTableCheck(group)
	if group then
		if type(group) == 'string' then -- assuming name
			local groupTable = Group.getByName(group)
			return groupTable
		elseif type(group) == 'table' then
			return group
		else
			env.error(("SUPP, groupTableCheck: wrong variable"))
			return nil
		end
	else
		env.error(("SUPP, groupTableCheck: missing variable"))
		return nil
	end
end

function SUPP.getRandPointInCircle(point, radius, innerRadius)
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

function SUPP.vec3Check(vec3)
	if vec3 then
		if type(vec3) == 'table' then -- assuming name
			if vec3.x and vec3.y and vec3.z then			
				return vec3
			else
				env.error(("SUPP, vec3Check: wrong vector format"))
				return nil
			end
		else
			env.error(("SUPP, vec3Check: wrong variable"))
			return nil
		end
	else
		env.error(("SUPP, vec3Check: missing variable"))
		return nil
	end
end

function SUPP.getRandTerrainPointInCircle(var, radius, innerRadius)
    local point = SUPP.vec3Check(var)	
	if point and radius and innerRadius then
		
		for i = 1, 5 do
			local coordRun = SUPP.getRandPointInCircle(point, radius, innerRadius)
			local destlandtype = land.getSurfaceType({coordRun.x, coordRun.z})
			if destlandtype == 1 or destlandtype == 4 then
				env.info(("SUPP, getRandTerrainPointInCircle found valid vec3 point"))
				return coordRun
			end
		end
		env.info(("SUPP, getRandTerrainPointInCircle no valid Vec3 point found!"))
		return nil -- this means that no valid result has found
		
	end
end

function SUPP.groupRoadOnly(group)
	if group then
        local grTbl = nil
        if type(group) == 'string' then -- assuming name
			grTbl = Group.getByName(group)
		elseif type(group) == 'table' then
			grTbl =  group
		else
			env.error(("SUPP, groupRoadOnly: wrong variable"))
        end

        if grTbl then
            local units = grTbl:getUnits()
            for uId, uData in pairs(units) do
                if uData:hasAttribute("Trucks") or uData:hasAttribute("Cars") or uData:hasAttribute("Unarmed vehicles") then
                    env.info(("SUPP, groupRoadOnly found at least one road only unit!"))
                    return true
                end
            end
        end
        env.info(("SUPP, groupRoadOnly no road only unit found, or no grTbl"))
        return false
	else
		env.error(("SUPP, groupRoadOnly: missing variable"))
		return nil
	end
end

function SUPP.roundNumber(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end 

function SUPP.buildWP(point, overRideForm, overRideSpeed)

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
        wp.speed = 20/3.6
    end

    if point.form and not overRideForm then
        form = point.form
    else
        form = overRideForm
    end

    if not form then
        wp.action = 'Cone'
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
            wp.action = 'Cone' -- if nothing matched
        end
    end

    wp.type = 'Turning Point'

    return wp

end

function SUPP.deepCopy(object)
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

function SUPP.goRoute(var, path)
    local group = SUPP.groupTableCheck(var)
	if group then
		local misTask = {
			id = 'Mission',
			params = {
				route = {
					points = SUPP.deepCopy(path),
				},
			},
		}
		if type(group) == 'string' then
			group = Group.getByName(group)
		end
		if group then
			local groupCon = group:getController()
			if groupCon then
				groupCon:setTask(misTask)
				return true
			end
		end
		return false
	end
end

function SUPP.getLeadPos(group)
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

function SUPP.groupToRandomPoint(var, Vec3destination, destRadius, destInnerRadius, useRoad, formation) -- move the group to a point or, if the point is missing, to a random position at about 2 km
    local group = SUPP.groupTableCheck(var)
    if group then	   		
        local unit1 = group:getUnit(1)
        local curPoint = unit1:getPosition().p
        local point = Vec3destination --required
        local dist = SUPP.getDist(point,curPoint)
        if dist > 1000 then
            useRoad = true
        end

		local rndCoord = nil
		if point == nil then
			point = SUPP.getRandTerrainPointInCircle(group:getPosition().p, 2000*1.1, 2000*0.9) -- IMPROVE DEST POINT CHECKS!
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
                useRoads = SUPP.groupRoadOnly(group)
			else
				useRoads = useRoad
			end
            
            local speed = nil
            if useRoads == false then
                speed = SUPP.outRoadSpeed
            else
                speed = SUPP.inRoadSpeed
            end


			local path = {}

			if heading >= 2*math.pi then
				heading = heading - 2*math.pi
			end
			
			if not rndCoord then
				rndCoord = SUPP.getRandTerrainPointInCircle(point, radius, innerRadius)
			end
			
			if rndCoord then
				local offset = {}
				local posStart = SUPP.getLeadPos(group)

				offset.x = SUPP.roundNumber(math.sin(heading - (math.pi/2)) * 50 + rndCoord.x, 3)
				offset.z = SUPP.roundNumber(math.cos(heading + (math.pi/2)) * 50 + rndCoord.y, 3)
				path[#path + 1] = SUPP.buildWP(posStart, form, speed)


				if useRoads == true and ((point.x - posStart.x)^2 + (point.z - posStart.z)^2)^0.5 > radius * 1.3 then
					path[#path + 1] = SUPP.buildWP({x = posStart.x + 11, z = posStart.z + 11}, 'off_road', speed)
					path[#path + 1] = SUPP.buildWP(posStart, 'on_road', speed)
					path[#path + 1] = SUPP.buildWP(offset, 'on_road', speed)
				else
					path[#path + 1] = SUPP.buildWP({x = posStart.x + 25, z = posStart.z + 25}, form, speed)
				end

				path[#path + 1] = SUPP.buildWP(offset, form, speed)
				path[#path + 1] = SUPP.buildWP(rndCoord, form, speed)

				SUPP.goRoute(group, path)

				return
			else
				env.info(("SUPP, groupToRandomPoint failed, no valid destination available"))
			end
		else
			env.info(("SUPP, groupToRandomPoint failed, no valid destination available"))
		end
	end
end

function SUPP.findGroupInRange(support_point, attribute, distance)
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
                local itemPos = foundItem:getPosition().p
                if itemPos then
                    local dist = SUPP.getDist(itemPos, support_point)
                    if dist < mindistance and dist > 1000 then
                        mindistance = dist
                        local foundGroup = foundItem:getGroup()
                        curGroup = foundGroup
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

function SUPP.callSupport(var) -- var can be: vec3, group/unit/static table or name, trigger zone table or name.
    
    local destPoint = nil
    if type(var) == "table" then        
        -- check vector. if no vector, then is an object (supposed)
        if var.x and var.y and var.z then -- is coordinates
            destPoint = var
        elseif var.point then -- is a trigger zone
            destPoint = var.point
        else -- SHOULD BE AN OBJECT, HOPEFULLY
            destPoint = var:getPosition().p
        end
    elseif type(var) == "string" then
        local group = Group.getByName(var)
        if group then
            local firstUnit = group:getUnit(1)
            destPoint = firstUnit:getPosition().p
        end
        local unit = Unit.getByName(var)
        if unit then
            destPoint = unit:getPosition().p
        end
        local static = 	StaticObject.getByName(var)
        if static then
            destPoint = static:getPosition().p
        end
        local zone = 	trigger.misc.getZone(var)
        if zone then
            destPoint = zone.point
        end
    end

    if destPoint then
        local near_group = SUPP.findGroupInRange(destPoint, SUPP.supportUnitCategories, SUPP.supportDist)



        if near_group then
            SUPP.groupToRandomPoint(near_group, destPoint, 200, 50, false)
        else
            env.info(("SUPP.callSupport no available support in range"))
        end
    else
        env.error(("SUPP.callSupport failed to retrieve destPoint"))
    end
end