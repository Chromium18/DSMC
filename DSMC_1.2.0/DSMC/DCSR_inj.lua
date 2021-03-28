-- DSMC DCSR
-- THIS IS MODIFIED VERSION OF CSAR Script by Ciribob, with added code to remove mist dependancies and add some automation.

-- ORIGINAL VERSION:
-- CSAR Script for DCS Ciribob - 2015
-- Version 1.9.2 - 23/04/2018
-- DCS 1.5 Compatible - Needs Mist 4.0.55 or higher!
--
-- 4 Options:
--      0 - No Limit - NO Aircraft disabling or pilot lives
--      1 - Disable Aircraft when its down - Timeout to reenable aircraft
--      2 - Disable Aircraft for Pilot when he's shot down -- timeout to reenable pilot for aircraft
--      3 - Pilot Life Limit - No Aircraft Disabling 

local ModuleName  	= "DCSR_inj"
local MainVersion 	= DSMC_MainVersion or "missing, loaded without DSMC"
local SubVersion 	= DSMC_SubVersion or "missing, loaded without DSMC"
local Build 		= DSMC_Build or "missing, loaded without DSMC"
local Date			= DSMC_Date or "missing, loaded without DSMC"

DCSR = {}
local debugProcessDetail = DSMC_debugProcessDetail or false

-- SETTINGS FOR MISSION DESIGNER vvvvvvvvvvvvvvvvvv
--Enable CSar Options -HELICOPTERS
--enableAllslots and Use prefix will work for Helicopter 

-- All slot / Limit settings

if not DSMC_baseGcounter then
	DSMC_baseGcounter = 20010000
end
if not DSMC_baseUcounter then
	DSMC_baseUcounter = 19010000
end

local DCSRDynAddIndex 		= {[' air '] = 0, [' hel '] = 0, [' gnd '] = 0, [' bld '] = 0, [' static '] = 0, [' shp '] = 0}
local DCSRAddedObjects 		= {}  -- da mist
local DCSRAddedGroups 		= {}  -- da mist

function DCSR.deepCopy(object)
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

if TRPS then
    if TRPS.unitLoadLimits then
        DCSR.aircraftType = DCSR.deepCopy(TRPS.unitLoadLimits)
        if debugProcessDetail then
            env.info(ModuleName .. " DCSR.aircraftType created using TRPS")
        end
    end
end

if not DCSR.aircraftType then
    if debugProcessDetail then
        env.info(ModuleName .. " DCSR.aircraftType created manually, no TRPS available")
    end
    DCSR.aircraftType = {} -- Type and limit
    DCSR.aircraftType["SA342Mistral"] = 2
    DCSR.aircraftType["SA342Minigun"] = 2
    DCSR.aircraftType["SA342L"] = 2
    DCSR.aircraftType["SA342M"] = 2
    DCSR.aircraftType["UH-1H"] = 8
    DCSR.aircraftType["Mi-8MT"] = 16
end


DCSR.getNextGroupId = function()
    DSMC_baseGcounter = DSMC_baseGcounter + 1

    return DSMC_baseGcounter
end

DCSR.getNextUnitId = function()
    DSMC_baseUcounter = DSMC_baseUcounter + 1

    return DSMC_baseUcounter
end


-- MIST import
function DCSR.zoneToVec3(zone)
    local new = {}
	if type(zone) == 'table' then
		if zone.point then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
		elseif zone.x and zone.y and zone.z then
			return zone
		end
		return new
	elseif type(zone) == 'string' then
		zone = trigger.misc.getZone(zone)
		if zone then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
			return new
		end
	end
end

function DCSR.round(num, idp)
    local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function DCSR.getPayload(unitName)
    -- refactor to search by groupId and allow groupId and groupName as inputs
	local unitTbl = Unit.getByName(unitName)
	local unitId = unitTbl:getID()
	local gpTbl = unitTbl:getGroup()
	local gpId = gpTbl:getID()

	if gpId and unitId then
		for coa_name, coa_data in pairs(env.mission.coalition) do
			if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
				if coa_data.country then --there is a country table
					for cntry_id, cntry_data in pairs(coa_data.country) do
						for obj_type_name, obj_type_data in pairs(cntry_data) do
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then	-- only these types have points
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
									for group_num, group_data in pairs(obj_type_data.group) do
										if group_data and group_data.groupId == gpId then
											for unitIndex, unitData in pairs(group_data.units) do --group index
												if unitData.unitId == unitId then
													return unitData.payload
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
		if debugProcessDetail then
			env.info(ModuleName .. " getPayload error, no gId or unitId")
		end	
		return false
	end
	return
end

function DCSR.deepCopy(object)
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

function DCSR.dynAdd(newGroup)
    local cntry = newGroup.country
	if newGroup.countryId then
		cntry = newGroup.countryId
	end

	local groupType = newGroup.category
	local newCountry = ''
	-- validate data
	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
	end

	if newCountry == '' then
		if debugProcessDetail then
			env.info(ModuleName .. " dynAdd Country not found")
		end		
		return false
	end

	local newCat = ''
	for catName, catId in pairs(Unit.Category) do
		if type(groupType) == 'string' then
			if tostring(catName) == string.upper(groupType) then
				newCat = catName
			end
		elseif type(groupType) == 'number' then
			if catId == groupType then
				newCat = catName
			end
		end

		if catName == 'GROUND_UNIT' and (string.upper(groupType) == 'VEHICLE' or string.upper(groupType) == 'GROUND') then
			newCat = 'GROUND_UNIT'
		elseif catName == 'AIRPLANE' and string.upper(groupType) == 'PLANE' then
			newCat = 'AIRPLANE'
		end
	end
	local typeName
	if newCat == 'GROUND_UNIT' then
		typeName = ' gnd '
	elseif newCat == 'AIRPLANE' then
		typeName = ' air '
	elseif newCat == 'HELICOPTER' then
		typeName = ' hel '
	elseif newCat == 'SHIP' then
		typeName = ' shp '
	elseif newCat == 'BUILDING' then
		typeName = ' bld '
	end
	if newGroup.clone or not newGroup.groupId then
		DCSRDynAddIndex[typeName] = DCSRDynAddIndex[typeName] + 1
		newGroup.groupId = DCSR.getNextGroupId()
    end    
	if newGroup.groupName or newGroup.name then
		if newGroup.groupName then
			newGroup.name = newGroup.groupName
		elseif newGroup.name then
			newGroup.name = newGroup.name
		end
	end

	if newGroup.clone or not newGroup.name then
		newGroup.name = tostring(newCountry .. tostring(typeName) .. DCSRDynAddIndex[typeName])
	end

	if not newGroup.hidden then
		newGroup.hidden = false
	end

	if not newGroup.visible then
		newGroup.visible = false
	end

	if (newGroup.start_time and type(newGroup.start_time) ~= 'number') or not newGroup.start_time then
		if newGroup.startTime then
			newGroup.start_time = DCSR.round(newGroup.startTime)
		else
			newGroup.start_time = 0
		end
	end

    for unitIndex, unitData in pairs(newGroup.units) do
        local originalName = newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name
        if newGroup.clone or not unitData.unitId then
            newGroup.units[unitIndex].unitId = DCSR.getNextUnitId()   -- DSMC
        end
        if newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name then
            if newGroup.units[unitIndex].unitName then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].unitName
            elseif newGroup.units[unitIndex].name then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].name
            end
        end
        if newGroup.clone or not unitData.name then
            newGroup.units[unitIndex].name = tostring(newGroup.name .. ' unit' .. unitIndex)
        end

        if not unitData.skill then
            newGroup.units[unitIndex].skill = 'Random'
        end

        if newCat == 'AIRPLANE' or newCat == 'HELICOPTER' then
            if newGroup.units[unitIndex].alt_type and newGroup.units[unitIndex].alt_type ~= 'BARO' or not newGroup.units[unitIndex].alt_type then
                newGroup.units[unitIndex].alt_type = 'RADIO'
            end
            if not unitData.speed then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].speed = 60
                end
            end
            if not unitData.payload then
                newGroup.units[unitIndex].payload = DCSR.getPayload(originalName)
            end
            if not unitData.alt then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].alt = 2000
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].alt = 500
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 60
                end
            end
            
        elseif newCat == 'GROUND_UNIT' then
            if nil == unitData.playerCanDrive then
                unitData.playerCanDrive = true
                unitData.transportable.randomTransportable = true -- ADDED BY DSMC
            end
        
        end
        DCSRAddedObjects[#DCSRAddedObjects + 1] = DCSR.deepCopy(newGroup.units[unitIndex])
    end

	DCSRAddedGroups[#DCSRAddedGroups + 1] = DCSR.deepCopy(newGroup)
	if newGroup.route and not newGroup.route.points then
		if not newGroup.route.points and newGroup.route[1] then
			local copyRoute = newGroup.route
			newGroup.route = {}
			newGroup.route.points = copyRoute
		end
	end
	newGroup.country = newCountry

	-- sanitize table
	newGroup.groupName = nil
	newGroup.clone = nil
	newGroup.category = nil
	newGroup.country = nil

	newGroup.tasks = {}

	for unitIndex, unitData in pairs(newGroup.units) do
		newGroup.units[unitIndex].unitName = nil
	end

    env.info(ModuleName .. " dynAdd newGroup data is there")
    --dumpTable("newGroup.lua", newGroup)
    env.info(ModuleName .. " dynAdd country.id[newCountry]: " .. tostring(country.id[newCountry]))
    env.info(ModuleName .. " dynAdd Unit.Category[newCat]: " .. tostring(Unit.Category[newCat]))

	coalition.addGroup(country.id[newCountry], Unit.Category[newCat], newGroup)

	return newGroup

end

function DCSR.dynAddStatic(newObj)

	if newObj.units and newObj.units[1] then 
		for entry, val in pairs(newObj.units[1]) do
			if newObj[entry] and newObj[entry] ~= val or not newObj[entry] then
				newObj[entry] = val
			end
		end
	end
	--log:info(newObj)

	local cntry = newObj.country
	if newObj.countryId then
		cntry = newObj.countryId
	end

	local newCountry = ''

	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
    end

	if newCountry == '' then
		if debugProcessDetail then
			env.info(ModuleName .. " dynAddStatic Country not found")
		end
		return false
    end

	if newObj.clone or not newObj.groupId then
		newObj.groupId = DCSR.getNextGroupId()
    end
 
	if newObj.clone or not newObj.unitId then -- 2
		newObj.unitId = DCSR.getNextUnitId()
	end

   -- newObj.name = newObj.unitName
	if newObj.clone or not newObj.name then
		DCSRDynAddIndex[' static '] = DCSRDynAddIndex[' static '] + 1
		newObj.name = (newCountry .. ' static ' .. DCSRDynAddIndex[' static '])
    end

	if not newObj.dead then
		newObj.dead = false
	end

	if not newObj.heading then
		newObj.heading = math.random(360)
	end
	
	if newObj.categoryStatic then
		newObj.category = newObj.categoryStatic
	end
	if newObj.mass then
		newObj.category = 'Cargos'
	end
	
	if newObj.shapeName then
		newObj.shape_name = newObj.shapeName
    end
	if not newObj.shape_name then
		if debugProcessDetail then
			env.info(ModuleName .. " dynAddStatic shape not found")
		end
		if DCSR.tblObjectshapeNames[newObj.type] then
			newObj.shape_name = DCSR.tblObjectshapeNames[newObj.type]
		end
    end
	
	DCSRAddedObjects[#DCSRAddedObjects + 1] = DCSR.deepCopy(newObj)
	if newObj.x and newObj.y and newObj.type and type(newObj.x) == 'number' and type(newObj.y) == 'number' and type(newObj.type) == 'string' then

        --log:info('addStaticObject')
		coalition.addStaticObject(country.id[newCountry], newObj)
  
		return newObj
	end
	
	if debugProcessDetail then
		env.info(ModuleName .. " dynAddStatic Failed to add static object due to missing or incorrect value")
    end	

	return false
end

function DCSR.vecmag(vec)
	return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
end

function DCSR.vecsub(vec1, vec2)
	return {x = vec1.x - vec2.x, y = vec1.y - vec2.y, z = vec1.z - vec2.z}
end

function DCSR.vecdp(vec1, vec2)
	return vec1.x*vec2.x + vec1.y*vec2.y + vec1.z*vec2.z
end

function DCSR.getNorthCorrection(gPoint)	--gets the correction needed for true north
	local point = DCSR.deepCopy(gPoint)
	if not point.z then --Vec2; convert to Vec3
		point.z = point.y
		point.y = 0
	end
	local lat, lon = coord.LOtoLL(point)
	local north_posit = coord.LLtoLO(lat + 1, lon)
	return math.atan2(north_posit.z - point.z, north_posit.x - point.x)
end

function DCSR.getHeading(unit, rawHeading)
	local unitpos = unit:getPosition()
	if unitpos then
		local Heading = math.atan2(unitpos.x.z, unitpos.x.x)
		if not rawHeading then
			Heading = Heading + DCSR.getNorthCorrection(unitpos.p)
		end
		if Heading < 0 then
			Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
		end
		return Heading
	end
end

function DCSR.makeVec3(vec, y)
	if not vec.z then
		if vec.alt and not y then
			y = vec.alt
		elseif not y then
			y = 0
		end
		return {x = vec.x, y = y, z = vec.y}
	else
		return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
	end
end

function DCSR.getDir(vec, point)
	local dir = math.atan2(vec.z, vec.x)
	if point then
		dir = dir + DCSR.getNorthCorrection(point)
	end
	if dir < 0 then
		dir = dir + 2 * math.pi	-- put dir in range of 0 to 2*pi
	end
	return dir
end

function DCSR.toDegree(angle)
	return angle*180/math.pi
end

function DCSR.tostringLL(lat, lon, acc, DMS)

	local latHemi, lonHemi
	if lat > 0 then
		latHemi = 'N'
	else
		latHemi = 'S'
	end

	if lon > 0 then
		lonHemi = 'E'
	else
		lonHemi = 'W'
	end

	lat = math.abs(lat)
	lon = math.abs(lon)

	local latDeg = math.floor(lat)
	local latMin = (lat - latDeg)*60

	local lonDeg = math.floor(lon)
	local lonMin = (lon - lonDeg)*60

	if DMS then	-- degrees, minutes, and seconds.
		local oldLatMin = latMin
		latMin = math.floor(latMin)
		local latSec = DCSR.round((oldLatMin - latMin)*60, acc)

		local oldLonMin = lonMin
		lonMin = math.floor(lonMin)
		local lonSec = DCSR.round((oldLonMin - lonMin)*60, acc)

		if latSec == 60 then
			latSec = 0
			latMin = latMin + 1
		end

		if lonSec == 60 then
			lonSec = 0
			lonMin = lonMin + 1
		end

		local secFrmtStr -- create the formatting string for the seconds place
		if acc <= 0 then	-- no decimal place.
			secFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			secFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format('%02d', latMin) .. '\' ' .. string.format(secFrmtStr, latSec) .. '"' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format('%02d', lonMin) .. '\' ' .. string.format(secFrmtStr, lonSec) .. '"' .. lonHemi

	else	-- degrees, decimal minutes.
		latMin = DCSR.round(latMin, acc)
		lonMin = DCSR.round(lonMin, acc)

		if latMin == 60 then
			latMin = 0
			latDeg = latDeg + 1
		end

		if lonMin == 60 then
			lonMin = 0
			lonDeg = lonDeg + 1
		end

		local minFrmtStr -- create the formatting string for the minutes place
		if acc <= 0 then	-- no decimal place.
			minFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			minFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format(minFrmtStr, latMin) .. '\'' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format(minFrmtStr, lonMin) .. '\'' .. lonHemi

	end
end

function DCSR.ground_buildWP(point, overRideForm, overRideSpeed)

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
		wp.speed = DCSR.kmphToMps(20)
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

function DCSR.kmphToMps(kmph)
	return kmph/3.6
end

function DCSR.tostringMGRS(MGRS, acc)
	if acc == 0 then
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph
	else
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph .. ' ' .. string.format('%0' .. acc .. 'd', DCSR.round(MGRS.Easting/(10^(5-acc)), 0))
		.. ' ' .. string.format('%0' .. acc .. 'd', DCSR.round(MGRS.Northing/(10^(5-acc)), 0))
	end
end

function DCSR.tostringGRID(MGRS, acc)
	if acc == 0 then
		return MGRS.MGRSDigraph
	else
		return MGRS.MGRSDigraph .. string.format('%0' .. acc .. 'd', math.floor(MGRS.Easting/(10^(5-acc)), 0)) -- DCSR.round
		.. string.format('%0' .. acc .. 'd', math.floor(MGRS.Northing/(10^(5-acc)), 0))
	end
end

function DCSR.getAvgPos(unitNames)
	local avgX, avgY, avgZ, totNum = 0, 0, 0, 0
	for i = 1, #unitNames do
		local unit
		if Unit.getByName(unitNames[i]) then
			unit = Unit.getByName(unitNames[i])
		elseif StaticObject.getByName(unitNames[i]) then
			unit = StaticObject.getByName(unitNames[i])
		end
		if unit then
			local pos = unit:getPosition().p
			if pos then -- you never know O.o
				avgX = avgX + pos.x
				avgY = avgY + pos.y
				avgZ = avgZ + pos.z
				totNum = totNum + 1
			end
		end
	end
	if totNum ~= 0 then
		return {x = avgX/totNum, y = avgY/totNum, z = avgZ/totNum}
	end
end

function DCSR.getLLString(vars)
	local units = vars.units
	local acc = vars.acc or 3
	local DMS = vars.DMS
	local avgPos = DCSR.getAvgPos(units)
	if avgPos then
		local lat, lon = coord.LOtoLL(avgPos)
		return DCSR.tostringLL(lat, lon, acc, DMS)
	end
end

function DCSR.getMGRSString(vars)
	local units = vars.units
	local acc = vars.acc or 5
	local avgPos = DCSR.getAvgPos(units)
	if avgPos then
		return DCSR.tostringMGRS(coord.LLtoMGRS(coord.LOtoLL(avgPos)), acc)
	end
end

function DCSR.metersToNM(meters)
    return meters/1852
end

function DCSR.metersToFeet(meters)
    return meters/0.3048
end

function DCSR.tostringBR(az, dist, alt, metric)
    az = DCSR.round(DCSR.toDegree(az), 0)

    if metric then
        dist = DCSR.round(dist/1000, 0)
    else
        dist = DCSR.round(DCSR.metersToNM(dist), 0)
    end

    local s = string.format('%03d', az) .. ' for ' .. dist

    if alt then
        if metric then
            s = s .. ' at ' .. DCSR.round(alt, 0)
        else
            s = s .. ' at ' .. DCSR.round(DCSR.metersToFeet(alt), 0)
        end
    end
    return s
end

function DCSR.getBRString(vars)
	local units = vars.units
	local ref = DCSR.makeVec3(vars.ref, 0)	-- turn it into Vec3 if it is not already.
	local alt = vars.alt
	local metric = vars.metric
	local avgPos = DCSR.getAvgPos(units)
	if avgPos then
        local vec = {x = avgPos.x - ref.x, y = avgPos.y - ref.y, z = avgPos.z - ref.z}
        local dir = DCSR.getDir(vec, ref)
        local dist = DCSR.get2DDist(avgPos, ref)
        if alt then
            alt = avgPos.y
        end
        return DCSR.tostringBR(dir, dist, alt, metric)
	end
end

function DCSR.getPlayerNameOrUnitName(_heli)
    if _heli then
        if _heli:getPlayerName() == nil then
            if _heli:getName() then
                return _heli:getTypeName() .. ", name: " .. _heli:getName()
            end
        else
            return _heli:getPlayerName()
        end
    end
end


-- DSMC added variables
DCSR.useCoalitionMessages = DCSR_useCoalitionMessages_var or true -- if false, no coalition messages will be shown when a pilot is downed (this is for who has a dedicated human in coordination role). Modify line 528
env.info(ModuleName .. ": DCSR.useCoalitionMessages " .. tostring(DCSR.useCoalitionMessages))

-- Fixed Unit Name. -- DSMC left here to ensure retro-compatibility
--E nable Csar Options for the units with the names in the list below                  
DCSR.csarFixedUnits =  {
    "helicargo1",
    "helicargo2",
    "helicargo3",
    "helicargo4",
    "helicargo5",
    "helicargo6",
    "helicargo7",
    "helicargo8",
    "helicargo9",
    "helicargo10",

    "helicargo11",
    "helicargo12",
    "helicargo13",
    "helicargo14",
    "helicargo15",
    "helicargo16",
    "helicargo17",
    "helicargo18",
    "helicargo19",
    "helicargo20",

    "helicargo21",
    "helicargo22",
    "helicargo23",
    "helicargo24",
    "helicargo25",

    "MEDEVAC #1",
    "MEDEVAC #2",
    "MEDEVAC #3",
    "MEDEVAC #4",
    "MEDEVAC #5",
    "MEDEVAC #6",
    "MEDEVAC #7",
    "MEDEVAC #8",
    "MEDEVAC #9",
    "MEDEVAC #10",
    "MEDEVAC #11",
    "MEDEVAC #12",
    "MEDEVAC #13",
    "MEDEVAC #14",
    "MEDEVAC #15",
    "MEDEVAC #16",

    "MEDEVAC RED #1",
    "MEDEVAC RED #2",
    "MEDEVAC RED #3",
    "MEDEVAC RED #4",
    "MEDEVAC RED #5",
    "MEDEVAC RED #6",
    "MEDEVAC RED #7",
    "MEDEVAC RED #8",
    "MEDEVAC RED #9",
    "MEDEVAC RED #10",
    "MEDEVAC RED #11",
    "MEDEVAC RED #12",
    "MEDEVAC RED #13",
    "MEDEVAC RED #14",
    "MEDEVAC RED #15",
    "MEDEVAC RED #16",
    "MEDEVAC RED #17",
    "MEDEVAC RED #18",
    "MEDEVAC RED #19",
    "MEDEVAC RED #20",
    "MEDEVAC RED #21",

    "MEDEVAC BLUE #1",
    "MEDEVAC BLUE #2",
    "MEDEVAC BLUE #3",
    "MEDEVAC BLUE #4",
    "MEDEVAC BLUE #5",
    "MEDEVAC BLUE #6",
    "MEDEVAC BLUE #7",
    "MEDEVAC BLUE #8",
    "MEDEVAC BLUE #9",
    "MEDEVAC BLUE #10",
    "MEDEVAC BLUE #11",
    "MEDEVAC BLUE #12",
    "MEDEVAC BLUE #13",
    "MEDEVAC BLUE #14",
    "MEDEVAC BLUE #15",
    "MEDEVAC BLUE #16",
    "MEDEVAC BLUE #17",
    "MEDEVAC BLUE #18",
    "MEDEVAC BLUE #19",
    "MEDEVAC BLUE #20",
    "MEDEVAC BLUE #21",
} -- List of all the MEDEVAC _UNIT NAMES_ (the line where it says "Pilot" in the ME)!

DCSR.autosmoke = false -- Automatically Smoke when CSAR helicopter is at 5 km

DCSR.bluemash = {
    "BlueMASH #1",
    "BlueMASH #2",
    "BlueMASH #3",
    "BlueMASH #4",
    "BlueMASH #5",
    "BlueMASH #6",
    "BlueMASH #7",
    "BlueMASH #8",
    "BlueMASH #9",
    "BlueMASH #10"
} -- The unit that serves as MASH for the blue side

DCSR.redmash = {
    "RedMASH #1",
    "RedMASH #2",
    "RedMASH #3",
    "RedMASH #4",
    "RedMASH #5",
    "RedMASH #6",
    "RedMASH #7",
    "RedMASH #8",
    "RedMASH #9",
    "RedMASH #10"
} -- The unit that serves as MASH for the red side

DCSR.csarMode = 0

--      0 - No Limit - NO Aircraft disabling
--      1 - Disable Aircraft when its down - Timeout to reenable aircraft
--      2 - Disable Aircraft for Pilot when he's shot down -- timeout to reenable pilot for aircraft
--      3 - Pilot Life Limit - No Aircraft Disabling -- timeout to reset lives?

--DCSR.maxLives = 8 -- Maximum pilot lives

--DCSR.countCSARCrash = false -- If you set to true, pilot lives count for CSAR and CSAR aircraft will count.

--DCSR.csarOncrash = false -- If set to true, will generate a CSAR when crash as well.

--DCSR.reenableIfCSARCrashes = true -- If a CSAR heli crashes, the pilots are counted as rescued anyway. Set to false to Stop this

-- - I recommend you leave the option on below IF USING MODE 1 otherwise the
-- aircraft will be disabled for the duration of the mission
--DCSR.disableAircraftTimeout = true -- Allow aircraft to be used after 20 minutes if the pilot isnt rescued
---DCSR.disableTimeoutTime = 3 -- Time in minutes for TIMEOUT

--DCSR.destructionHeight = 150 -- height in meters an aircraft will be destroyed at if the aircraft is disabled
if debugProcessDetail then
    DCSR.enableForAI = true -- set to false to disable AI units from being rescued.    
else
    DCSR.enableForAI = false -- set to false to disable AI units from being rescued.    
end

DCSR.enableForRED = true -- enable for red side

DCSR.enableForBLUE = true -- enable for blue side

--DCSR.enableSlotBlocking = false -- if set to true, you need to put the csarSlotBlockGameGUI.lua
-- in C:/Users/<YOUR USERNAME>/DCS/Scripts for 1.5 or C:/Users/<YOUR USERNAME>/DCS.openalpha/Scripts for 2.0
-- For missions using FLAGS and this script, the CSAR flags will NOT interfere with your mission :)

DCSR.bluesmokecolor = 4 -- Color of smokemarker for blue side, 0 is green, 1 is red, 2 is white, 3 is orange and 4 is blue
DCSR.redsmokecolor = 1 -- Color of smokemarker for red side, 0 is green, 1 is red, 2 is white, 3 is orange and 4 is blue

DCSR.requestdelay = 5 -- Time in seconds before the survivors will request Medevac -- QUIIIIIIIII

DCSR.coordtype = 0 -- Use Lat/Long DDM (0), Lat/Long DMS (1), MGRS (2), Bullseye imperial (3) or Bullseye metric (4) for coordinates.
DCSR.coordaccuracy = 1 -- Precision of the reported coordinates, see MIST-docs at http://wiki.hoggit.us/view/GetMGRSString
-- only applies to _non_ bullseye coords

DCSR.immortalcrew = false -- Set to true to make wounded crew immortal
DCSR.invisiblecrew = false -- Set to true to make wounded crew insvisible

DCSR.messageTime = 30 -- Time to show the initial wounded message for in seconds

DCSR.weight = 100

DCSR.pilotRuntoExtractPoint = true -- Downed Pilot will run to the rescue helicopter up to DCSR.extractDistance METERS 
DCSR.loadDistance = 100 -- configure distance for pilot to get in helicopter in meters.
DCSR.extractDistance = 500 -- Distance the Downed pilot will run to the rescue helicopter
DCSR.loadtimemax = 135

DCSR.radioSound = "beacon.ogg" -- the name of the sound file to use for the Pilot radio beacons. If this isnt added to the mission BEACONS WONT WORK!

DCSR.allowFARPRescue = true --allows pilot to be rescued by landing at a FARP or Airbase

DCSR.landedStatus = {} -- tracks status of a helis hover above a downed pilot

DCSR.csarUnits =  {}
-- SETTINGS FOR MISSION DESIGNER ^^^^^^^^^^^^^^^^^^^*

-- ***************************************************************
-- **************** Mission Editor Functions *********************
-- ***************************************************************

-----------------------------------------------------------------
-- Resets all life limits so everyone can spawn again. Usage:
-- DCSR.resetAllPilotLives()
--
--[[
function DCSR.resetAllPilotLives()

    for x, _pilot in pairs(DCSR.pilotLives) do

        trigger.action.setUserFlag("CSAR_PILOT" .. _pilot:gsub('%W', ''), DCSR.maxLives + 1)
    end

    DCSR.pilotLives = {}
    env.info("Pilot Lives Reset!")
end
--]]--

-----------------------------------------------------------------
-- Resets all life limits so everyone can spawn again. Usage:
-- DCSR.resetAllPilotLives()
--

--[[
function DCSR.resetPilotLife(_playerName)

    DCSR.pilotLives[_playerName] = nil

    trigger.action.setUserFlag("CSAR_PILOT" .. _playerName:gsub('%W', ''), DCSR.maxLives + 1)

    env.info("Pilot life Reset!")
end
--]]--

-- ***************************************************************
-- **************** BE CAREFUL BELOW HERE ************************
-- ***************************************************************

-- Sanity checks of mission designer

------------------------------

DCSR.addedTo = {}

--DCSR.downedPilotCounterRed = 0
--DCSR.downedPilotCounterBlue = 0

DCSR.woundedGroups = {} -- contains the new group of units
DCSR.inTransitGroups = {} -- contain a table for each SAR with all units he has with the
-- original name of the killed group

DCSR.radioBeacons = {}

DCSR.smokeMarkers = {} -- tracks smoke markers for groups
DCSR.heliVisibleMessage = {} -- tracks if the first message has been sent of the heli being visible

DCSR.heliCloseMessage = {} -- tracks heli close message  ie heli < 500m distance

DCSR.radioBeacons = {} -- all current beacons

DCSR.max_units = 6 --number of pilots that can be carried

--DCSR.currentlyDisabled = {} --stored disabled aircraft

DCSR.hoverStatus = {} -- tracks status of a helis hover above a downed pilot

--DCSR.pilotDisabled = {} -- tracks what aircraft a pilot is disabled for

--DCSR.pilotLives = {} -- tracks how many lives a pilot has

DCSR.takenOff = {}

function DCSR.tableLength(T)

    if T == nil then
        return 0
    end


    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

function DCSR.pilotsOnboard(_heliName)
    local count = 0
    if DCSR.inTransitGroups[_heliName] then
        for _, _group in pairs(DCSR.inTransitGroups[_heliName]) do
            count = count + 1
        end
    end
    return count
end

function DCSR.addCsar(_coalition , _country, _point, _typeName, _unitName, _playerName, _freq, noMessage, _description )
      
  local _spawnedGroup = DCSR.spawnGroup( _coalition, _country, _point, _typeName )
  DCSR.addSpecialParametersToGroup(_spawnedGroup)
  
  if noMessage == true then
    trigger.action.outTextForCoalition(_spawnedGroup:getCoalition(), "MAYDAY MAYDAY! " .. _typeName .. " is down. ", 10)
  end
  
  if _freq == nil then
    _freq = DCSR.generateADFFrequency()
  end 
  
  if _freq ~= nil then
    DCSR.addBeaconToGroup(_spawnedGroup:getName(), _freq)
  end
  
  
  --DCSR.handleEjectOrCrash(_playerName, false)
  
-- Generate DESCRIPTION text
  local _text = " "
  if _playerName ~= nil then
      _text = "Pilot " .. _playerName .. " of " .. _unitName .. " - " .. _typeName
  elseif _typeName ~= nil then
      _text = "AI Pilot of " .. _unitName .. " - " .. _typeName
  else
      _text = _description
  end
  --
  DCSR.woundedGroups[_spawnedGroup:getName()] = { side = _spawnedGroup:getCoalition(), originalUnit = _unitName, desc = _text, typename = _typeName, frequency = _freq, player = _playerName }
  
  -- reversing
  if noMessage == false then
    noMessage = true
  else
    noMessage = false
  end

  DCSR.initSARForPilot(_spawnedGroup, _freq, noMessage)
  
  if _spawnedGroup ~= nil then
     local _controller = _spawnedGroup:getController();
     Controller.setOption(_controller, AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)
     Controller.setOption(_controller, AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.WEAPON_HOLD)
  end

end

-- Handles all world events
DCSR.eventHandler = {}
function DCSR.eventHandler:onEvent(_event)
    local status, err = pcall(function(_event)

        if _event == nil or _event.initiator == nil then
            return false

        elseif _event.id == 3 then -- taken offf

            if _event.initiator:getName() then
                DCSR.takenOff[_event.initiator:getName()] = true
            end

            return true
        elseif _event.id == 15 then --player entered unit

            if _event.initiator:getName() then
                DCSR.takenOff[_event.initiator:getName()] = nil
            end

            -- if its a sar heli, re-add check status script
            for _, _heliName in pairs(DCSR.csarUnits) do

                if _heliName == _event.initiator:getName() then
                    -- add back the status script
                    for _woundedName, _groupInfo in pairs(DCSR.woundedGroups) do

                        if _groupInfo.side == _event.initiator:getCoalition() then

                            --env.info(string.format("Schedule Respawn %s %s",_heliName,_woundedName))
                            -- queue up script
                            -- Schedule timer to check when to pop smoke
                            
                            timer.scheduleFunction(DCSR.checkWoundedGroupStatus, { _heliName, _woundedName }, timer.getTime() + 5)

                        end
                    end
                end
            end

            --if _event.initiator:getName() and _event.initiator:getPlayerName() then

                --env.info("Checking Unit - " .. _event.initiator:getName())
                --DCSR.checkDisabledAircraftStatus({ _event.initiator:getName(), _event.initiator:getPlayerName() })
            --end

            return true

        elseif (_event.id == 9 ) then -- and DCSR.csarOncrash == false
            -- Pilot dead

            env.info("Event unit - Pilot Dead")

            local _unit = _event.initiator

            if _unit == nil then
                return -- error!
            end

            local _coalition = _unit:getCoalition()

            if _coalition == 1 and not DCSR.enableForRED then
                return --ignore!
            end

            if _coalition == 2 and not DCSR.enableForBLUE then
                return --ignore!
            end

            -- Catch multiple events here?
            if DCSR.takenOff[_event.initiator:getName()] == true or _unit:inAir() then

                if DCSR.doubleEjection(_unit) then
                    return
                end

                --trigger.action.outTextForCoalition(_unit:getCoalition(), "MAYDAY MAYDAY! " .. _unit:getTypeName() .. " shot down. No Chute!", 10)
                --DCSR.handleEjectOrCrash(_unit, true)
            else
                env.info("Pilot Hasnt taken off, ignore")
            end

            return

        elseif _event.id == 9 or world.event.S_EVENT_EJECTION == _event.id then  
            --if _event.id == 9  then  -- and DCSR.csarOncrash == false
            --    return     
            --end
            env.info("Event unit - Pilot Ejected")



            local _unit = _event.initiator

            if _unit == nil then
                return -- error!
            end

            --[[
            if _unit:getPoint() then
                local preLand = _unit:getPoint()
                local landType = land.getSurfaceType({x = preLand.x, y = preLand.z})

                if landType == 3 then
                    env.info("Event unit - Pilot Ejected over water, remove")
                    return
                end
            end
            --]]--


            local _coalition = _unit:getCoalition()

            if _coalition == 1 and not DCSR.enableForRED then
                return --ignore!
            end

            if _coalition == 2 and not DCSR.enableForBLUE then
                return --ignore!
            end

            -- TODO catch ejection on runway?

            if DCSR.enableForAI == false and _unit:getPlayerName() == nil then

                return
            end

            if DCSR.takenOff[_event.initiator:getName()] ~= true and not _unit:inAir() then
                env.info("Pilot Hasnt taken off, ignore")
                return -- give up, pilot hasnt taken off
            end

            if DCSR.doubleEjection(_unit) then
                return
            end



            local _freq = DCSR.generateADFFrequency()
            DCSR.addCsar(_coalition, _unit:getCountry(), _unit:getPoint()  , _unit:getTypeName(),  _unit:getName(), _unit:getPlayerName(), _freq, DCSR.useCoalitionMessages, 0)
             
            return true

        elseif world.event.S_EVENT_LAND == _event.id then

            if _event.initiator:getName() then
                DCSR.takenOff[_event.initiator:getName()] = nil
            end

            if DCSR.allowFARPRescue then

                --env.info("Landing")

                local _unit = _event.initiator

                if _unit == nil then
                    env.info("Unit Nil on Landing")
                    return -- error!
                end

                DCSR.takenOff[_event.initiator:getName()] = nil

                local _place = _event.place

                if _place == nil then
                    env.info("Landing Place Nil")
                    return -- error!
                end
                -- Coalition == 3 seems to be a bug... unless it means contested?!
                if _place:getCoalition() == _unit:getCoalition() or _place:getCoalition() == 0 or _place:getCoalition() == 3 then
                    DCSR.rescuePilots(_unit)
                    --env.info("Rescued")
                    --   env.info("Rescued by Landing")

                else
                    --    env.info("Cant Rescue ")

                    env.info(string.format("airfield %d, unit %d", _place:getCoalition(), _unit:getCoalition()))
                end
            end

            return true
        end
    end, _event)
    if (not status) then
        env.error(string.format("Error while handling event %s", err), false)
    end
end

DCSR.lastCrash = {}

function DCSR.doubleEjection(_unit)

    if DCSR.lastCrash[_unit:getName()] then
        local _time = DCSR.lastCrash[_unit:getName()]

        if timer.getTime() - _time < 10 then
            env.info("Caught double ejection!")
            return true
        end
    end

    DCSR.lastCrash[_unit:getName()] = timer.getTime()

    return false
end

--[[
function DCSR.handleEjectOrCrash(_unit, _crashed) -- REMOVE/ON

    -- disable aircraft for ALL pilots
    if DCSR.csarMode == 1 then

        if DCSR.currentlyDisabled[_unit:getName()] ~= nil then
            return --already ejected once!
        end

        --                --mark plane as broken and unflyable
        if _unit:getPlayerName() ~= nil and DCSR.currentlyDisabled[_unit:getName()] == nil then

            if DCSR.countCSARCrash == false then
                for _, _heliName in pairs(DCSR.csarUnits) do

                    if _unit:getName() == _heliName then
                        -- IGNORE Crashed CSAR
                        return
                    end
                end
            end

            DCSR.currentlyDisabled[_unit:getName()] = { timeout = (DCSR.disableTimeoutTime * 60) + timer.getTime(), desc = "", noPilot = _crashed, unitId = _unit:getID(), name = _unit:getName() }

            -- disable aircraft

            trigger.action.setUserFlag("CSAR_AIRCRAFT" .. _unit:getID(), 100)

            env.info("Unit Disabled: " .. _unit:getName() .. " ID:" .. _unit:getID())
        end

    elseif DCSR.csarMode == 2 then -- disable aircraft for pilot

        --DCSR.pilotDisabled
        if _unit:getPlayerName() ~= nil and DCSR.pilotDisabled[_unit:getPlayerName() .. "_" .. _unit:getName()] == nil then

            if DCSR.countCSARCrash == false then
                for _, _heliName in pairs(DCSR.csarUnits) do

                    if _unit:getName() == _heliName then
                        -- IGNORE Crashed CSAR
                        return
                    end
                end
            end

            DCSR.pilotDisabled[_unit:getPlayerName() .. "_" .. _unit:getName()] = { timeout = (DCSR.disableTimeoutTime * 60) + timer.getTime(), desc = "", noPilot = true, unitId = _unit:getID(), player = _unit:getPlayerName(), name = _unit:getName() }

            -- disable aircraft

            -- strip special characters from name gsub('%W','')
            trigger.action.setUserFlag("CSAR_AIRCRAFT" .. _unit:getPlayerName():gsub('%W', '') .. "_" .. _unit:getID(), 100)

            env.info("Unit Disabled for player : " .. _unit:getName())
        end

    elseif DCSR.csarMode == 3 then -- No Disable - Just reduce player lives

        --DCSR.pilotDisabled
        if _unit:getPlayerName() ~= nil then

            if DCSR.countCSARCrash == false then
                for _, _heliName in pairs(DCSR.csarUnits) do

                    if _unit:getName() == _heliName then
                        -- IGNORE Crashed CSAR
                        return
                    end
                end
            end

            local _lives = DCSR.pilotLives[_unit:getPlayerName()]

            if _lives == nil then
                _lives = DCSR.maxLives + 1 --plus 1 because we'll use flag set to 1 to indicate NO MORE LIVES
            end

            DCSR.pilotLives[_unit:getPlayerName()] = _lives - 1

            trigger.action.setUserFlag("CSAR_PILOT" .. _unit:getPlayerName():gsub('%W', ''), _lives - 1)
        end
    end
end
--]]--

--[[
function DCSR.enableAircraft(_name, _playerName) -- REMOVE


    -- enable aircraft for ALL pilots
    if DCSR.csarMode == 1 then

        local _details = DCSR.currentlyDisabled[_name]

        if _details ~= nil then
            DCSR.currentlyDisabled[_name] = nil -- {timeout =  (DCSR.disableTimeoutTime*60) + timer.getTime(),desc="",noPilot = _crashed,unitId=_unit:getID() }

            --use flag to reenable
            trigger.action.setUserFlag("CSAR_AIRCRAFT" .. _details.unitId, 0)
        end

    elseif DCSR.csarMode == 2 and _playerName ~= nil then -- enable aircraft for pilot

        local _details = DCSR.pilotDisabled[_playerName .. "_" .. _name]

        if _details ~= nil then
            DCSR.pilotDisabled[_playerName .. "_" .. _name] = nil

            trigger.action.setUserFlag("CSAR_AIRCRAFT" .. _playerName:gsub('%W', '') .. "_" .. _details.unitId, 0)
        end

    elseif DCSR.csarMode == 3 and _playerName ~= nil then -- No Disable - Just reduce player lives

        -- give back life

        local _lives = DCSR.pilotLives[_playerName]

        if _lives == nil then
            _lives = DCSR.maxLives + 1 --plus 1 because we'll use flag set to 1 to indicate NO MORE LIVES
        else
            _lives = _lives + 1 -- give back live!

            if DCSR.maxLives + 1 <= _lives then
                _lives = DCSR.maxLives + 1 --plus 1 because we'll use flag set to 1 to indicate NO MORE LIVES
            end
        end

    DCSR.pilotLives[_playerName] = _lives

    trigger.action.setUserFlag("CSAR_PILOT" .. _playerName:gsub('%W', ''), _lives)
    end
end
--]]--

--[[
function DCSR.reactivateAircraft() -- REMOVE

    timer.scheduleFunction(DCSR.reactivateAircraft, nil, timer.getTime() + 5)

    -- disable aircraft for ALL pilots
    if DCSR.csarMode == 1 then

        for _unitName, _details in pairs(DCSR.currentlyDisabled) do

            if timer.getTime() >= _details.timeout then

                DCSR.enableAircraft(_unitName)
            end
        end

    elseif DCSR.csarMode == 2 then -- disable aircraft for pilot

    for _key, _details in pairs(DCSR.pilotDisabled) do

        if timer.getTime() >= _details.timeout then

            DCSR.enableAircraft(_details.name, _details.player)
        end
    end

    elseif DCSR.csarMode == 3 then -- No Disable - Just reduce player lives
    end
end
--]]--

--[[
function DCSR.checkDisabledAircraftStatus(_args) -- REMOVE

    local _name = _args[1]
    local _playerName = _args[2]

    local _unit = Unit.getByName(_name)

    --if its not the same user anymore, stop checking
    if _unit ~= nil and _unit:getPlayerName() ~= nil and _playerName == _unit:getPlayerName() then
        -- disable aircraft for ALL pilots
        if DCSR.csarMode == 1 then

            local _details = DCSR.currentlyDisabled[_unit:getName()]

            if _details ~= nil then

                local _time = _details.timeout - timer.getTime()

                if _details.noPilot then

                    if DCSR.disableAircraftTimeout then

                        local _text = string.format("This aircraft cannot be flow as the pilot was killed in a crash. Reinforcements in %.2dM,%.2dS\n\nIt will be DESTROYED on takeoff!", (_time / 60), _time % 60)

                        --display message,
                        DCSR.displayMessageToSAR(_unit, _text, 10, true)
                    else
                        --display message,
                        DCSR.displayMessageToSAR(_unit, "This aircraft cannot be flown again as the pilot was killed in a crash\n\nIt will be DESTROYED on takeoff!", 10, true)
                    end
                else
                    if DCSR.disableAircraftTimeout then
                        --display message,
                        DCSR.displayMessageToSAR(_unit, _details.desc .. " needs to be rescued or reinforcements arrive before this aircraft can be flown again! Reinforcements in " .. string.format("%.2dM,%.2d", (_time / 60), _time % 60) .. "\n\nIt will be DESTROYED on takeoff!", 10, true)
                    else
                        --display message,
                        DCSR.displayMessageToSAR(_unit, _details.desc .. " needs to be rescued before this aircraft can be flown again!\n\nIt will be DESTROYED on takeoff!", 10, true)
                    end
                end

                if DCSR.destroyUnit(_unit) then
                    return --plane destroyed
                else
                    --check again in 10 seconds
                    timer.scheduleFunction(DCSR.checkDisabledAircraftStatus, _args, timer.getTime() + 10)
                end
            end



        elseif DCSR.csarMode == 2 then -- disable aircraft for pilot

            local _details = DCSR.pilotDisabled[_unit:getPlayerName() .. "_" .. _unit:getName()]

            if _details ~= nil then

                local _time = _details.timeout - timer.getTime()

                if _details.noPilot then

                    if DCSR.disableAircraftTimeout then

                        local _text = string.format("This aircraft cannot be flow as the pilot was killed in a crash. Reinforcements in %.2dM,%.2dS\n\nIt will be DESTROYED on takeoff!", (_time / 60), _time % 60)

                        --display message,
                        DCSR.displayMessageToSAR(_unit, _text, 10, true)
                    else
                        --display message,
                        DCSR.displayMessageToSAR(_unit, "This aircraft cannot be flown again as the pilot was killed in a crash\n\nIt will be DESTROYED on takeoff!", 10, true)
                    end
                else
                    if DCSR.disableAircraftTimeout then
                        --display message,
                        DCSR.displayMessageToSAR(_unit, _details.desc .. " needs to be rescued or reinforcements arrive before this aircraft can be flown again! Reinforcements in " .. string.format("%.2dM,%.2d", (_time / 60), _time % 60) .. "\n\nIt will be DESTROYED on takeoff!", 10, true)
                    else
                        --display message,
                        DCSR.displayMessageToSAR(_unit, _details.desc .. " needs to be rescued before this aircraft can be flown again!\n\nIt will be DESTROYED on takeoff!", 10, true)
                    end
                end

                if DCSR.destroyUnit(_unit) then
                    return --plane destroyed
                else
                    --check again in 10 seconds
                    timer.scheduleFunction(DCSR.checkDisabledAircraftStatus, _args, timer.getTime() + 10)
                end
            end


        elseif DCSR.csarMode == 3 then -- No Disable - Just reduce player lives

            local _lives = DCSR.pilotLives[_unit:getPlayerName()]

            if _lives == nil or _lives > 1 then

                if _lives == nil then
                    _lives = DCSR.maxLives + 1
                end

                -- -1 for lives as we use 1 to indicate out of lives!
                local _text = string.format("CSAR ACTIVE! \n\nYou have " .. (_lives - 1) .. " lives remaining. Make sure you eject!")

                DCSR.displayMessageToSAR(_unit, _text, 20, true)

                return

            else

                local _text = string.format("You have run out of LIVES! Lives will be reset on mission restart or when your pilot is rescued.\n\nThis aircraft will be DESTROYED on takeoff!")

                --display message,
                DCSR.displayMessageToSAR(_unit, _text, 10, true)

                if DCSR.destroyUnit(_unit) then
                    return --plane destroyed
                else
                    --check again in 10 seconds
                    timer.scheduleFunction(DCSR.checkDisabledAircraftStatus, _args, timer.getTime() + 10)
                end
            end
        end
    end
end
--]]--

--[[
function DCSR.destroyUnit(_unit)

    --destroy if the SAME player is still in the aircraft
    -- if a new player got in it'll be destroyed in a bit anyways
    if _unit ~= nil and _unit:getPlayerName() ~= nil then

        if DCSR.heightDiff(_unit) > DCSR.destructionHeight then

            DCSR.displayMessageToSAR(_unit, "**** Aircraft Destroyed as the pilot needs to be rescued or you have no lives! ****", 10, true)
            --if we're off the ground then explode
            trigger.action.explosion(_unit:getPoint(), 100);

            return true
        end
        --_unit:destroy() destroy doesnt work for playes who arent the host in multiplayer
    end

    return false
end
--]]--

function DCSR.heightDiff(_unit)

    local _point = _unit:getPoint()

    return _point.y - land.getHeight({ x = _point.x, y = _point.z })
end

DCSR.addBeaconToGroup = function(_woundedGroupName, _freq)

    local _group = Group.getByName(_woundedGroupName)

    if _group == nil then

        --return frequency to pool of available
        for _i, _current in ipairs(DCSR.usedVHFFrequencies) do
            if _current == _freq then
                table.insert(DCSR.freeVHFFrequencies, _freq)
                table.remove(DCSR.usedVHFFrequencies, _i)
            end
        end

        return
    end

    local _sound = "l10n/DEFAULT/" .. DCSR.radioSound

    trigger.action.radioTransmission(_sound, _group:getUnit(1):getPoint(), 0, false, _freq, 1000)

    timer.scheduleFunction(DCSR.refreshRadioBeacon, { _woundedGroupName, _freq }, timer.getTime() + 30)
end

DCSR.refreshRadioBeacon = function(_args)

    DCSR.addBeaconToGroup(_args[1], _args[2])
end

DCSR.addSpecialParametersToGroup = function(_spawnedGroup)

    -- Immortal code for alexej21
    local _setImmortal = {
        id = 'SetImmortal',
        params = {
            value = true
        }
    }
    -- invisible to AI, Shagrat
    local _setInvisible = {
        id = 'SetInvisible',
        params = {
            value = true
        }
    }

    local _controller = _spawnedGroup:getController()

    if (DCSR.immortalcrew) then
        Controller.setCommand(_controller, _setImmortal)
    end

    if (DCSR.invisiblecrew) then
        Controller.setCommand(_controller, _setInvisible)
    end
end

function DCSR.spawnGroup( _coalition, _country, _point, _typeName )

    local _id = DCSR.getNextGroupId()

    local _groupName = "Downed Pilot #" .. _id

   local _side = _coalition

     local _pos = _point

    local _group = {
        ["visible"] = false,
        ["groupId"] = _id,
        ["hidden"] = false,
        ["units"] = {},
        ["name"] = _groupName,
        ["task"] = {},
    }

    if _side == 2 then
        _group.units[1] = DCSR.createUnit(_pos.x + 50, _pos.z + 50, 120, "Soldier M4")
    else
        _group.units[1] = DCSR.createUnit(_pos.x + 50, _pos.z + 50, 120, "Infantry AK")
    end

    _group.category = Group.Category.GROUND;
    _group.country = _country;

    local _spawnedGroup = Group.getByName(DCSR.dynAdd(_group).name)

    return _spawnedGroup
end

function DCSR.createUnit(_x, _y, _heading, _type)

    local _id = DCSR.getNextUnitId();

    local _name = string.format("Wounded Pilot #%s", _id)

    local _newUnit = {
        ["y"] = _y,
        ["type"] = _type,
        ["name"] = _name,
        ["unitId"] = _id,
        ["heading"] = _heading,
        ["playerCanDrive"] = false,
        ["skill"] = "Excellent",
        ["x"] = _x,
    }

    return _newUnit
end

function DCSR.initSARForPilot(_downedGroup, _freq)

    local _leader = _downedGroup:getUnit(1)

    local _coordinatesText = DCSR.getPositionOfWounded(_downedGroup)

    local
    _text = string.format("%s requests SAR at %s, beacon at %.2f KHz",
        _leader:getName(), _coordinatesText, _freq / 1000)

    local _randPercent = math.random(1, 100)

    -- Loop through all the medevac units
    for x, _heliName in pairs(DCSR.csarUnits) do
        local _status, _err = pcall(function(_args)
            local _unitName = _args[1]
            local _woundedSide = _args[2]
            local _medevacText = _args[3]
            local _leaderPos = _args[4]
            local _groupName = _args[5]
            local _group = _args[6]

            local _heli = DCSR.getSARHeli(_unitName)

            -- queue up for all SAR, alive or dead, we dont know the side if they're dead or not spawned so check
            --coalition in scheduled smoke

            if _heli ~= nil then

                -- Check coalition side
                if (_woundedSide == _heli:getCoalition()) then
                    -- Display a delayed message
                    timer.scheduleFunction(DCSR.delayedHelpMessage, { _unitName, _medevacText, _groupName }, timer.getTime() + DCSR.requestdelay)

                    -- Schedule timer to check when to pop smoke
                    timer.scheduleFunction(DCSR.checkWoundedGroupStatus, { _unitName, _groupName }, timer.getTime() + 1)
                end
            else
                --env.warning(string.format("Medevac unit %s not active", _heliName), false)

                -- Schedule timer for Dead unit so when the unit respawns he can still pickup units
                --timer.scheduleFunction(medevac.checkStatus, {_unitName,_groupName}, timer.getTime() + 5)
            end
        end, { _heliName, _leader:getCoalition(), _text, _leader:getPoint(), _downedGroup:getName(), _downedGroup })

        if (not _status) then
            env.warning(string.format("Error while checking with medevac-units %s", _err))
        end
    end
end

function DCSR.checkWoundedGroupStatus(_argument)
    local _status, _err = pcall(function(_args)
        local _heliName = _args[1]
        local _woundedGroupName = _args[2]

        local _woundedGroup = DCSR.getWoundedGroup(_woundedGroupName)
        local _heliUnit = DCSR.getSARHeli(_heliName)

        -- if wounded group is not here then message alread been sent to SARs
        -- stop processing any further
        if DCSR.woundedGroups[_woundedGroupName] == nil then
            return
        end
        
        local _woundedLeader = _woundedGroup[1]
        local _lookupKeyHeli = _heliName .. "_" .. _woundedLeader:getID() --lookup key for message state tracking
                
        if _heliUnit == nil then
            -- stop wounded moving, head back to smoke as target heli is DEAD

            -- in transit cleanup
            --  DCSR.inTransitGroups[_heliName] = nil
  
            DCSR.heliVisibleMessage[_lookupKeyHeli] = nil
            DCSR.heliCloseMessage[_lookupKeyHeli] = nil
            DCSR.landedStatus[_lookupKeyHeli] = nil
            
            return
        end
        

        

        -- double check that this function hasnt been queued for the wrong side

        if DCSR.woundedGroups[_woundedGroupName].side ~= _heliUnit:getCoalition() then
            return --wrong side!
        end

        if DCSR.checkGroupNotKIA(_woundedGroup, _woundedGroupName, _heliUnit, _heliName) then

            local _woundedLeader = _woundedGroup[1]
            local _lookupKeyHeli = _heliUnit:getName() .. "_" .. _woundedLeader:getID() --lookup key for message state tracking

            local _distance = DCSR.getDistance(_heliUnit:getPoint(), _woundedLeader:getPoint())

            if _distance < 3000 then

                if DCSR.checkCloseWoundedGroup(_distance, _heliUnit, _heliName, _woundedGroup, _woundedGroupName) == true then
                    -- we're close, reschedule
                    timer.scheduleFunction(DCSR.checkWoundedGroupStatus, _args, timer.getTime() + 1)
                end

            else
                DCSR.heliVisibleMessage[_lookupKeyHeli] = nil

                --reschedule as units arent dead yet , schedule for a bit slower though as we're far away
                timer.scheduleFunction(DCSR.checkWoundedGroupStatus, _args, timer.getTime() + 5)
            end
        end
    end, _argument)

    if not _status then

        env.error(string.format("error checkWoundedGroupStatus %s", _err))
    end
end

function DCSR.popSmokeForGroup(_woundedGroupName, _woundedLeader)
    -- have we popped smoke already in the last 5 mins
    local _lastSmoke = DCSR.smokeMarkers[_woundedGroupName]
    if _lastSmoke == nil or timer.getTime() > _lastSmoke then

        local _smokecolor
        if (_woundedLeader:getCoalition() == 2) then
            _smokecolor = DCSR.bluesmokecolor
        else
            _smokecolor = DCSR.redsmokecolor
        end
        trigger.action.smoke(_woundedLeader:getPoint(), _smokecolor)

        DCSR.smokeMarkers[_woundedGroupName] = timer.getTime() + 300 -- next smoke time
    end
end

function DCSR.pickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)

    local _woundedLeader = _woundedGroup[1]

    -- GET IN!
    local _heliName = _heliUnit:getName()
    local _groups = DCSR.inTransitGroups[_heliName]
    local _unitsInHelicopter = DCSR.pilotsOnboard(_heliName)

    -- init table if there is none for this helicopter
    if not _groups then
        DCSR.inTransitGroups[_heliName] = {}
        _groups = DCSR.inTransitGroups[_heliName]
    end

    -- if the heli can't pick them up, show a message and return
    local _maxUnits = DCSR.aircraftType[_heliUnit:getTypeName()]
    if _maxUnits == nil then
      _maxUnits = DCSR.max_units
    end
    if _unitsInHelicopter + 1 > _maxUnits then
        DCSR.displayMessageToSAR(_heliUnit, string.format("%s, %s. We're already crammed with %d guys! Sorry!",
            _pilotName, _heliName, _unitsInHelicopter, _unitsInHelicopter), 10)
        return true
    end

    DCSR.inTransitGroups[_heliName][_woundedGroupName] =
    {
        originalUnit = DCSR.woundedGroups[_woundedGroupName].originalUnit,
        woundedGroup = _woundedGroupName,
        side = _heliUnit:getCoalition(),
        desc = DCSR.woundedGroups[_woundedGroupName].desc,
        player = DCSR.woundedGroups[_woundedGroupName].player,
    }

    Group.destroy(_woundedLeader:getGroup())

    DCSR.displayMessageToSAR(_heliUnit, string.format("%s: %s I'm in! Get to the MASH ASAP! ", _heliName, _pilotName), 10)

    timer.scheduleFunction(DCSR.scheduledSARFlight,
        {
            heliName = _heliUnit:getName(),
            groupName = _woundedGroupName
        },
        timer.getTime() + 1)

    return true
end
function DCSR.getAliveGroup(_groupName)

    local _group = Group.getByName(_groupName)

    if _group and _group:isExist() == true and #_group:getUnits() > 0 then
        return _group
    end

    return nil
end
function DCSR.orderGroupToMoveToPoint(_leader, _destination)

    local _group = _leader:getGroup()

    local _path = {}
    table.insert(_path, DCSR.ground_buildWP(_leader:getPoint(), 'Off Road', 50))
    table.insert(_path, DCSR.ground_buildWP(_destination, 'Off Road', 50))

    local _mission = {
        id = 'Mission',
        params = {
            route = {
                points =_path
            },
        },
    }

    -- delayed 2 second to work around bug
    timer.scheduleFunction(function(_arg)
        local _grp = DCSR.getAliveGroup(_arg[1])

        if _grp ~= nil then
            local _controller = _grp:getController();
            Controller.setOption(_controller, AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.GREEN)
            Controller.setOption(_controller, AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.WEAPON_HOLD)
            _controller:setTask(_arg[2])
        end
    end
        , {_group:getName(), _mission}, timer.getTime() + 2)

end

-- Helicopter is within 3km
function DCSR.checkCloseWoundedGroup(_distance, _heliUnit, _heliName, _woundedGroup, _woundedGroupName)

    local _woundedLeader = _woundedGroup[1]
    local _lookupKeyHeli = _heliUnit:getName() .. "_" .. _woundedLeader:getID() --lookup key for message state tracking

    local _pilotName = DCSR.woundedGroups[_woundedGroupName].desc

    local _woundedCount = 1

    local _reset = true
    
    if DCSR.autosmoke == true then
        DCSR.popSmokeForGroup(_woundedGroupName, _woundedLeader)
    end
    
    if DCSR.heliVisibleMessage[_lookupKeyHeli] == nil then
        if DCSR.autosmoke == true then
          DCSR.displayMessageToSAR(_heliUnit, string.format("%s: %s. I hear you! Damn that thing is loud! Land or hover by the smoke.", _heliName, _pilotName), 30)
        else
          DCSR.displayMessageToSAR(_heliUnit, string.format("%s: %s. I hear you! Damn that thing is loud! Request a Flare or Smoke if you need", _heliName, _pilotName), 30)
        end
        --mark as shown for THIS heli and THIS group
        DCSR.heliVisibleMessage[_lookupKeyHeli] = true
    end

    if (_distance < 500) then

        if DCSR.heliCloseMessage[_lookupKeyHeli] == nil then
            if DCSR.autosmoke == true then
              DCSR.displayMessageToSAR(_heliUnit, string.format("%s: %s. You're close now! Land or hover at the smoke.", _heliName, _pilotName), 10)
            else
              DCSR.displayMessageToSAR(_heliUnit, string.format("%s: %s. You're close now! Land in a safe place, i will go there ", _heliName, _pilotName), 10)
            end
            --mark as shown for THIS heli and THIS group
            DCSR.heliCloseMessage[_lookupKeyHeli] = true
        end

        -- have we landed close enough?
        if DCSR.inAir(_heliUnit) == false then

            -- if you land on them, doesnt matter if they were heading to someone else as you're closer, you win! :)
          if DCSR.pilotRuntoExtractPoint == true then
              if (_distance < DCSR.extractDistance) then
                local _time = DCSR.landedStatus[_lookupKeyHeli]
                if _time == nil then
                    --DCSR.displayMessageToSAR(_heliUnit, "Landed at " .. _distance, 10, true)
                    DCSR.landedStatus[_lookupKeyHeli] = math.floor( (_distance * DCSR.loadtimemax ) / DCSR.extractDistance )   
                    _time = DCSR.landedStatus[_lookupKeyHeli] 
                    DCSR.orderGroupToMoveToPoint(_woundedLeader, _heliUnit:getPoint())
                    DCSR.displayMessageToSAR(_heliUnit, "Wait till " .. _pilotName .. ". Gets in \n" .. _time .. " more seconds.", 10, true)
                else
                    _time = DCSR.landedStatus[_lookupKeyHeli] - 1
                    DCSR.landedStatus[_lookupKeyHeli] = _time

                end
                if _time <= 0 then
                   DCSR.landedStatus[_lookupKeyHeli] = nil
                   return DCSR.pickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
                end
              end
          else
            if (_distance < DCSR.loadDistance) then
                return DCSR.pickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
            end
          end
        else

            local _unitsInHelicopter = DCSR.pilotsOnboard(_heliName)
            local _maxUnits = DCSR.aircraftType[_heliUnit:getTypeName()]
            if _maxUnits == nil then
              _maxUnits = DCSR.max_units
            end
            
            if DCSR.inAir(_heliUnit) and _unitsInHelicopter + 1 <= _maxUnits then

                if _distance < 8.0 then

                    --check height!
                    local _height = _heliUnit:getPoint().y - _woundedLeader:getPoint().y

                    if _height <= 30.0 then

                        local _time = DCSR.hoverStatus[_lookupKeyHeli]

                        if _time == nil then
                            DCSR.hoverStatus[_lookupKeyHeli] = 10
                            _time = 10
                        else
                            _time = DCSR.hoverStatus[_lookupKeyHeli] - 1
                            DCSR.hoverStatus[_lookupKeyHeli] = _time
                        end

                        if _time > 0 then
                            DCSR.displayMessageToSAR(_heliUnit, "Hovering above " .. _pilotName .. ". \n\nHold hover for " .. _time .. " seconds to winch them up. \n\nIf the countdown stops you're too far away!", 10, true)
                        else
                            DCSR.hoverStatus[_lookupKeyHeli] = nil
                            return DCSR.pickupUnit(_heliUnit, _pilotName, _woundedGroup, _woundedGroupName)
                        end
                        _reset = false
                    else
                        DCSR.displayMessageToSAR(_heliUnit, "Too high to winch " .. _pilotName .. " \nReduce height and hover for 10 seconds!", 5, true)
                    end
                end
            
            end
        end
    end

    if _reset then
        DCSR.hoverStatus[_lookupKeyHeli] = nil
    end

    return true
end



function DCSR.checkGroupNotKIA(_woundedGroup, _woundedGroupName, _heliUnit, _heliName)

    -- check if unit has died or been picked up
    if #_woundedGroup == 0 and _heliUnit ~= nil then

        local inTransit = false

        for _currentHeli, _groups in pairs(DCSR.inTransitGroups) do

            if _groups[_woundedGroupName] then
                local _group = _groups[_woundedGroupName]
                if _group.side == _heliUnit:getCoalition() then
                    inTransit = true

                    DCSR.displayToAllSAR(string.format("%s has been picked up by %s", _woundedGroupName, _currentHeli), _heliUnit:getCoalition(), _heliName)

                    break
                end
            end
        end


        --display to all sar
        if inTransit == false then
            --DEAD

            DCSR.displayToAllSAR(string.format("%s is KIA ", _woundedGroupName), _heliUnit:getCoalition(), _heliName)
        end

        --     medevac.displayMessageToSAR(_heliUnit, string.format("%s: %s is dead", _heliName,_woundedGroupName ),10)

        --stops the message being displayed again
        DCSR.woundedGroups[_woundedGroupName] = nil

        return false
    end

    --continue
    return true
end


function DCSR.scheduledSARFlight(_args)

    local _status, _err = pcall(function(_args)

        local _heliUnit = DCSR.getSARHeli(_args.heliName)
        local _woundedGroupName = _args.groupName

        if (_heliUnit == nil) then

            DCSR.inTransitGroups[_args.heliName] = nil

            return
        end

        if DCSR.inTransitGroups[_heliUnit:getName()] == nil or DCSR.inTransitGroups[_heliUnit:getName()][_woundedGroupName] == nil then
            -- Groups already rescued
            return
        end


        local _dist = DCSR.getClosetMASH(_heliUnit)

        if _dist == -1 then
            -- Can now rescue to FARP
            -- Mash Dead
            --  DCSR.inTransitGroups[_heliUnit:getName()][_woundedGroupName] = nil

            --  DCSR.displayMessageToSAR(_heliUnit, string.format("%s: NO MASH! The pilot died of despair!", _heliUnit:getName()), 10)

            return
        end

        if _dist < 200 and _heliUnit:inAir() == false then

            DCSR.rescuePilots(_heliUnit)

            return
        end

        -- end
        --queue up
        timer.scheduleFunction(DCSR.scheduledSARFlight,
            {
                heliName = _heliUnit:getName(),
                groupName = _woundedGroupName
            },
            timer.getTime() + 1)
    end, _args)
    if (not _status) then
        env.error(string.format("Error in scheduledSARFlight\n\n%s", _err))
    end
end

function DCSR.rescuePilots(_heliUnit)
    local _rescuedGroups = DCSR.inTransitGroups[_heliUnit:getName()]

    if _rescuedGroups == nil then
        -- Groups already rescued
        return
    end

    DCSR.inTransitGroups[_heliUnit:getName()] = nil

    local _txt = string.format("%s: The pilots have been taken to the\nmedical clinic. Good job!", _heliUnit:getName())

    -- enable pilots again
    for _, _rescueGroup in pairs(_rescuedGroups) do

        --DCSR.enableAircraft(_rescueGroup.originalUnit, _rescueGroup.player)
    end

    DCSR.displayMessageToSAR(_heliUnit, _txt, 10)

    -- env.info("Rescued")
end


function DCSR.getSARHeli(_unitName)

    local _heli = Unit.getByName(_unitName)

    if _heli ~= nil and _heli:isActive() and _heli:getLife() > 0 then

        return _heli
    end

    return nil
end


-- Displays a request for medivac
function DCSR.delayedHelpMessage(_args)
    local status, err = pcall(function(_args)
        local _heliName = _args[1]
        local _text = _args[2]
        local _injuredGroupName = _args[3]

        local _heli = DCSR.getSARHeli(_heliName)

        if _heli ~= nil and #DCSR.getWoundedGroup(_injuredGroupName) > 0 then
            DCSR.displayMessageToSAR(_heli, _text, DCSR.messageTime)


            local _groupId = DCSR.getGroupId(_heli)

            if _groupId then
                trigger.action.outSoundForGroup(_groupId, "l10n/DEFAULT/CSAR.ogg")
            end

        else
            env.info("No Active Heli or Group DEAD")
        end
    end, _args)

    if (not status) then
        env.error(string.format("Error in delayedHelpMessage "))
    end

    return nil
end

function DCSR.displayMessageToSAR(_unit, _text, _time, _clear)

    local _groupId = DCSR.getGroupId(_unit)

    if _groupId then
        if _clear == true then
            trigger.action.outTextForGroup(_groupId, _text, _time, _clear)
        else
            trigger.action.outTextForGroup(_groupId, _text, _time)
        end
    end
end

function DCSR.getWoundedGroup(_groupName)
    local _status, _result = pcall(function(_groupName)

        local _woundedGroup = {}
        local _units = Group.getByName(_groupName):getUnits()

        for _, _unit in pairs(_units) do

            if _unit ~= nil and _unit:isActive() and _unit:getLife() > 0 then
                table.insert(_woundedGroup, _unit)
            end
        end

        return _woundedGroup
    end, _groupName)

    if (_status) then
        return _result
    else
        --env.warning(string.format("getWoundedGroup failed! Returning 0.%s",_result), false)
        return {} --return empty table
    end
end


function DCSR.convertGroupToTable(_group)

    local _unitTable = {}

    for _, _unit in pairs(_group:getUnits()) do

        if _unit ~= nil and _unit:getLife() > 0 then
            table.insert(_unitTable, _unit:getName())
        end
    end

    return _unitTable
end

function DCSR.getPositionOfWounded(_woundedGroup)

    local _woundedTable = DCSR.convertGroupToTable(_woundedGroup)

    local _coordinatesText = ""
    if DCSR.coordtype == 0 then -- Lat/Long DMTM
    _coordinatesText = string.format("%s", DCSR.getLLString({ units = _woundedTable, acc = DCSR.coordaccuracy, DMS = 0 }))

    elseif DCSR.coordtype == 1 then -- Lat/Long DMS
    _coordinatesText = string.format("%s", DCSR.getLLString({ units = _woundedTable, acc = DCSR.coordaccuracy, DMS = 1 }))

    elseif DCSR.coordtype == 2 then -- MGRS
    _coordinatesText = string.format("%s", DCSR.getMGRSString({ units = _woundedTable, acc = DCSR.coordaccuracy }))

    elseif DCSR.coordtype == 3 then -- Bullseye Imperial
    _coordinatesText = string.format("bullseye %s", DCSR.getBRString({ units = _woundedTable, ref = coalition.getMainRefPoint(_woundedGroup:getCoalition()), alt = 0 }))

    else -- Bullseye Metric --(medevac.coordtype == 4)
    _coordinatesText = string.format("bullseye %s", DCSR.getBRString({ units = _woundedTable, ref = coalition.getMainRefPoint(_woundedGroup:getCoalition()), alt = 0, metric = 1 }))
    end

    return _coordinatesText
end

-- Displays all active MEDEVACS/SAR
function DCSR.displayActiveSAR(_unitName)
    local _msg = "Active MEDEVAC/SAR:"

    local _heli = DCSR.getSARHeli(_unitName)

    if _heli == nil then
        return
    end

    local _heliSide = _heli:getCoalition()

    local _csarList = {}

    for _groupName, _value in pairs(DCSR.woundedGroups) do

        local _woundedGroup = DCSR.getWoundedGroup(_groupName)

        if #_woundedGroup > 0 and (_woundedGroup[1]:getCoalition() == _heliSide) then

            local _coordinatesText = DCSR.getPositionOfWounded(_woundedGroup[1]:getGroup())

            local _distance = DCSR.getDistance(_heli:getPoint(), _woundedGroup[1]:getPoint())

            table.insert(_csarList, { dist = _distance, msg = string.format("%s at %s - %.2f KHz ADF - %.3fKM ", _value.desc, _coordinatesText, _value.frequency / 1000, _distance / 1000.0) })
        end
    end

    local function sortDistance(a, b)
        return a.dist < b.dist
    end

    table.sort(_csarList, sortDistance)

    for _, _line in pairs(_csarList) do
        _msg = _msg .. "\n" .. _line.msg
    end

    DCSR.displayMessageToSAR(_heli, _msg, 20)
end


function DCSR.getClosetDownedPilot(_heli)

    local _side = _heli:getCoalition()

    local _closetGroup = nil
    local _shortestDistance = -1
    local _distance = 0
    local _closetGroupInfo = nil

    for _woundedName, _groupInfo in pairs(DCSR.woundedGroups) do

        local _tempWounded = DCSR.getWoundedGroup(_woundedName)

        -- check group exists and not moving to someone else
        if #_tempWounded > 0 and (_tempWounded[1]:getCoalition() == _side) then

            _distance = DCSR.getDistance(_heli:getPoint(), _tempWounded[1]:getPoint())

            if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then


                _shortestDistance = _distance
                _closetGroup = _tempWounded[1]
                _closetGroupInfo = _groupInfo
            end
        end
    end

    return { pilot = _closetGroup, distance = _shortestDistance, groupInfo = _closetGroupInfo }
end

function DCSR.signalFlare(_unitName)

    local _heli = DCSR.getSARHeli(_unitName)

    if _heli == nil then
        return
    end

    local _closet = DCSR.getClosetDownedPilot(_heli)

    if _closet ~= nil and _closet.pilot ~= nil and _closet.distance < 8000.0 then

        local _clockDir = DCSR.getClockDirection(_heli, _closet.pilot)

        local _msg = string.format("%s - %.2f KHz ADF - %.3fM - Popping Signal Flare at your %s ", _closet.groupInfo.desc, _closet.groupInfo.frequency / 1000, _closet.distance, _clockDir)
        DCSR.displayMessageToSAR(_heli, _msg, 20)

        trigger.action.signalFlare(_closet.pilot:getPoint(), 1, 0)
    else
        DCSR.displayMessageToSAR(_heli, "No Pilots within 8KM", 20)
    end
end

function DCSR.displayToAllSAR(_message, _side, _ignore)

    for _, _unitName in pairs(DCSR.csarUnits) do

        local _unit = DCSR.getSARHeli(_unitName)

        if _unit ~= nil and _unit:getCoalition() == _side then

            if _ignore == nil or _ignore ~= _unitName then
                DCSR.displayMessageToSAR(_unit, _message, 10)
            end
        else
            -- env.info(string.format("unit nil %s",_unitName))
        end
    end
end

function DCSR.reqsmoke( _unitName )

    local _heli = DCSR.getSARHeli(_unitName)
    if _heli == nil then
        return
    end

    local _closet = DCSR.getClosetDownedPilot(_heli)

    if _closet ~= nil and _closet.pilot ~= nil and _closet.distance < 8000.0 then

        local _clockDir = DCSR.getClockDirection(_heli, _closet.pilot)

        local _msg = string.format("%s - %.2f KHz ADF - %.3fM - Popping Blue smoke at your %s ", _closet.groupInfo.desc, _closet.groupInfo.frequency / 1000, _closet.distance, _clockDir)
        DCSR.displayMessageToSAR(_heli, _msg, 20)
        
       local _smokecolor
        if (_closet.pilot:getCoalition() == 2) then
            _smokecolor = DCSR.bluesmokecolor
        else
            _smokecolor = DCSR.redsmokecolor
        end

         trigger.action.smoke(_closet.pilot:getPoint(), _smokecolor)
  
    else
        DCSR.displayMessageToSAR(_heli, "No Pilots within 8KM", 20)
    end

end

function DCSR.getClosetMASH(_heli)

    local _mashes = DCSR.bluemash

    if (_heli:getCoalition() == 1) then
        _mashes = DCSR.redmash
    end

    local _shortestDistance = -1
    local _distance = 0

    for _, _mashName in pairs(_mashes) do

        local _mashUnit = Unit.getByName(_mashName)

        if _mashUnit ~= nil and _mashUnit:isActive() and _mashUnit:getLife() > 0 then

            _distance = DCSR.getDistance(_heli:getPoint(), _mashUnit:getPoint())

            if _distance ~= nil and (_shortestDistance == -1 or _distance < _shortestDistance) then

                _shortestDistance = _distance
            end
        end
    end

    if _shortestDistance ~= -1 then
        return _shortestDistance
    else
        return -1
    end
end

function DCSR.checkOnboard(_unitName)
    local _unit = DCSR.getSARHeli(_unitName)

    if _unit == nil then
        return
    end

    --list onboard pilots

    local _inTransit = DCSR.inTransitGroups[_unitName]

    if _inTransit == nil or DCSR.tableLength(_inTransit) == 0 then
        DCSR.displayMessageToSAR(_unit, "No Rescued Pilots onboard", 30)
    else

        local _text = "Onboard - RTB to FARP/Airfield or MASH: "

        for _, _onboard in pairs(DCSR.inTransitGroups[_unitName]) do
            _text = _text .. "\n" .. _onboard.desc
        end

        DCSR.displayMessageToSAR(_unit, _text, 30)
    end
end

function DCSR.addweight( _heli )
  local cargoWeight = 0
  
  local _heliName =  _heli:getName()
  if ctld ~= nil and ctld.troopWeight ~= nil then
      -- TODO Count CTLD troops
          
  end
  ctld.troopWeight = 100
  if DCSR.inTransitGroups[_heliName] then
    local csarcount = 0
    for _, _group in pairs(DCSR.inTransitGroups[_heliName]) do
        csarcount = csarcount + 1
    end
    cargoWeight = cargoWeight + DCSR.weight * csarcount
  end
  
  trigger.action.setUnitInternalCargo(_heli:getName(),0 ) -- Set To  to recalculate 
  trigger.action.setUnitInternalCargo(_heli:getName(), cargoWeight)
  

end
-- Adds menuitem to all medevac units that are active
function DCSR.addMedevacMenuItem()
    -- Loop through all Medevac units

    timer.scheduleFunction(DCSR.addMedevacMenuItem, nil, timer.getTime() + 5)

    local _allHeliGroups = coalition.getGroups(coalition.side.BLUE, Group.Category.HELICOPTER)
    
    for key, val in pairs (coalition.getGroups(coalition.side.RED, Group.Category.HELICOPTER)) do
      table.insert(_allHeliGroups, val)    
    end
    
    for _key, _group in pairs (_allHeliGroups) do
      
        local unitsTbl = _group:getUnits()
        --local _unit = _group:getUnit(1) -- Asume that there is only one unit in the flight for players
        for _, _unit in pairs(unitsTbl) do
            
            if _unit ~= nil then 
                if _unit:isExist() == true then         
                local unitName = _unit:getName()
                    local _type = _unit:getTypeName()
                    if DCSR.aircraftType[_type] ~= nil then
                        if DCSR.csarUnits[_unit:getName()] == nil then
                            DCSR.csarUnits[_unit:getName()] = _unit:getName()
                            
                            for _woundedName, _groupInfo in pairs(DCSR.woundedGroups) do
                                if _groupInfo.side == _group:getCoalition() then
                                
                                -- Schedule timer to check when to pop smoke
                                timer.scheduleFunction(DCSR.checkWoundedGroupStatus, { _unit:getName() , _woundedName }, timer.getTime() + 5)
                                end
                            end
                        end
                    end
                end
            end
        end

    end
    
    for key, unitName in pairs(DCSR.csarFixedUnits) do
      if DCSR.csarUnits[unitName] == nil then
        DCSR.csarUnits[unitName] = unitName
        for _woundedName, _groupInfo in pairs(DCSR.woundedGroups) do
          if _groupInfo.side == _group:getCoalition() then
            -- Schedule timer to check when to pop smoke
              timer.scheduleFunction(DCSR.checkWoundedGroupStatus, { unitName , _woundedName }, timer.getTime() + 5)
           end
        end
      end
    end
    
    for _, _unitName in pairs(DCSR.csarUnits) do

        local _unit = DCSR.getSARHeli(_unitName)
        --env.info("a1")
        if _unit ~= nil then
            --env.info("a2")
            local _CTLDpathID = DCSR.getPlayerNameOrUnitName(_unit)
            --env.info("a3:" .. tostring(_CTLDpathID))
            if _CTLDpathID then
                --env.info("a4")
                local _menuCode = "CSAR for " .. tostring(_CTLDpathID)
                local _addedId = _CTLDpathID
                local _groupId = DCSR.getGroupId(_unit)
                local _unitId = _unit:getID()
                local _group = _unit:getGroup()

                if _groupId then
                    --env.info("a5")
                    if DCSR.addedTo[tostring(_addedId)] == nil then
                        --env.info("a6")
                        

                        local _rootPath = missionCommands.addSubMenuForGroup(_groupId, _menuCode, {"DSMC"})

                        missionCommands.addCommandForGroup(_groupId, "List Active CSAR", _rootPath, DCSR.displayActiveSAR,
                            _unitName)

                        missionCommands.addCommandForGroup(_groupId, "Check Onboard", _rootPath, DCSR.checkOnboard, _unitName)

                        missionCommands.addCommandForGroup(_groupId, "Request Signal Flare", _rootPath, DCSR.signalFlare, _unitName)
                        missionCommands.addCommandForGroup(_groupId, "Request Smoke", _rootPath, DCSR.reqsmoke, _unitName)
                        
                        DCSR.addedTo[tostring(_addedId)] = {path = _rootPath, groupId = _groupId, unitId = _unitId, unitName = _unitName, curTime = timer.getTime(), group = _group}
                    end
                end
            else
                env.info(ModuleName .. " addMedevacMenuItem no : _CTLDpathID for " .. tostring(_unitName))
            end
        else
            -- env.info(string.format("unit nil %s",_unitName))
        end
    end

    return
end

--get distance in meters assuming a Flat world
function DCSR.getDistance(_point1, _point2)

    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

-- 200 - 400 in 10KHz
-- 400 - 850 in 10 KHz
-- 850 - 1250 in 50 KHz
function DCSR.generateVHFrequencies()

    --ignore list
    --list of all frequencies in KHZ that could conflict with
    -- 191 - 1290 KHz, beacon range
    local _skipFrequencies = {
        745, --Astrahan
        381,
        384,
        300.50,
        312.5,
        1175,
        342,
        735,
        300.50,
        353.00,
        440,
        795,
        525,
        520,
        690,
        625,
        291.5,
        300.50,
        435,
        309.50,
        920,
        1065,
        274,
        312.50,
        580,
        602,
        297.50,
        750,
        485,
        950,
        214,
        1025, 730, 995, 455, 307, 670, 329, 395, 770,
        380, 705, 300.5, 507, 740, 1030, 515,
        330, 309.5,
        348, 462, 905, 352, 1210, 942, 435,
        324,
        320, 420, 311, 389, 396, 862, 680, 297.5,
        920, 662,
        866, 907, 309.5, 822, 515, 470, 342, 1182, 309.5, 720, 528,
        337, 312.5, 830, 740, 309.5, 641, 312, 722, 682, 1050,
        1116, 935, 1000, 430, 577
    }

    DCSR.freeVHFFrequencies = {}
    DCSR.usedVHFFrequencies = {}

    local _start = 200000

    -- first range
    while _start < 400000 do

        -- skip existing NDB frequencies
        local _found = false
        for _, value in pairs(_skipFrequencies) do
            if value * 1000 == _start then
                _found = true
                break
            end
        end


        if _found == false then
            table.insert(DCSR.freeVHFFrequencies, _start)
        end

        _start = _start + 10000
    end

    _start = 400000
    -- second range
    while _start < 850000 do

        -- skip existing NDB frequencies
        local _found = false
        for _, value in pairs(_skipFrequencies) do
            if value * 1000 == _start then
                _found = true
                break
            end
        end

        if _found == false then
            table.insert(DCSR.freeVHFFrequencies, _start)
        end

        _start = _start + 10000
    end

    _start = 850000
    -- third range
    while _start <= 1250000 do

        -- skip existing NDB frequencies
        local _found = false
        for _, value in pairs(_skipFrequencies) do
            if value * 1000 == _start then
                _found = true
                break
            end
        end

        if _found == false then
            table.insert(DCSR.freeVHFFrequencies, _start)
        end

        _start = _start + 50000
    end
end

function DCSR.generateADFFrequency()

    if #DCSR.freeVHFFrequencies <= 3 then
        DCSR.freeVHFFrequencies = DCSR.usedVHFFrequencies
        DCSR.usedVHFFrequencies = {}
    end

    local _vhf = table.remove(DCSR.freeVHFFrequencies, math.random(#DCSR.freeVHFFrequencies))

    return _vhf
    --- return {uhf=_uhf,vhf=_vhf}
end

function DCSR.inAir(_heli)

    if _heli:inAir() == false then
        return false
    end

    -- less than 5 cm/s a second so landed
    -- BUT AI can hold a perfect hover so ignore AI
    if DCSR.vecmag(_heli:getVelocity()) < 0.05 and _heli:getPlayerName() ~= nil then
        return false
    end
    return true
end

function DCSR.getClockDirection(_heli, _crate)

    -- Source: Helicopter Script - Thanks!

    local _position = _crate:getPosition().p -- get position of crate
    local _playerPosition = _heli:getPosition().p -- get position of helicopter
    local _relativePosition = DCSR.vecsub(_position, _playerPosition)

    local _playerHeading = DCSR.getHeading(_heli) -- the rest of the code determines the 'o'clock' bearing of the missile relative to the helicopter

    local _headingVector = { x = math.cos(_playerHeading), y = 0, z = math.sin(_playerHeading) }

    local _headingVectorPerpendicular = { x = math.cos(_playerHeading + math.pi / 2), y = 0, z = math.sin(_playerHeading + math.pi / 2) }

    local _forwardDistance = DCSR.vecdp(_relativePosition, _headingVector)

    local _rightDistance = DCSR.vecdp(_relativePosition, _headingVectorPerpendicular)

    local _angle = math.atan2(_rightDistance, _forwardDistance) * 180 / math.pi

    if _angle < 0 then
        _angle = 360 + _angle
    end
    _angle = math.floor(_angle * 12 / 360 + 0.5)
    if _angle == 0 then
        _angle = 12
    end

    return _angle
end

function DCSR.getGroupId(_unit)

	if _unit then
		
		local _group = _unit:getGroup()
		local _groupId = _group:getID()
		return _groupId
	
	end
	
	return nil
end

DCSR.generateVHFrequencies()

-- Schedule timer to add radio item
timer.scheduleFunction(DCSR.addMedevacMenuItem, nil, timer.getTime() + 5)

--if DCSR.disableAircraftTimeout then
    -- Schedule timer to reactivate things
    --timer.scheduleFunction(DCSR.reactivateAircraft, nil, timer.getTime() + 5)
--end
world.addEventHandler(DCSR.eventHandler)

-- looping removal function
function DCSR.playerRemovalLoop()
    -- schedule
    timer.scheduleFunction(DCSR.playerRemovalLoop, nil, timer.getTime() + 1)

    -- check
    for pName, pData in pairs(DCSR.addedTo) do
        local check = false

        if pData and type(pData) == "table" then

            -- name & life checks 
            if pData.unitName then
                local u = Unit.getByName(pData.unitName)
                if u then
                    if u:getLife() > 1 then
                        check = true
                    end
                end
            end

            if check == false then
                if debugProcessDetail then
                    env.info(ModuleName .. " playerRemovalLoop deleting " .. tostring(pName) .. ", unit name: " .. tostring(pData.unitName))
                end

                if pData.path and pData.groupId then

                    --if event.initiator:hasAttribute("Air") then
                        if debugProcessDetail then
                            env.info(ModuleName .. " playerRemovalLoop removing menù entry from addedTo: " .. tostring(pName))
                        end
                        missionCommands.removeItemForGroup(pData.groupId, pData.path)
                    --end

                end

                --[[ remove from transportpilot
                for tId, tData in pairs (TRPS.transportPilotNames) do 
                    if tData == pData.unitName then
                        tId = nil
                        if debugProcessDetail then
                            env.info(ModuleName .. " playerRemovalLoop deleted transportPilotNames entry")
                        end
                    end
                end
                --]]--
                        
                DCSR.addedTo[pName] = nil
                --table.remove(TRPS.addedTo, pName)
                if debugProcessDetail then
                    env.info(ModuleName .. " playerRemovalLoop deleted addedTo entry")
                end
            end
        end
    end
end
DCSR.playerRemovalLoop()


env.info("CSAR event handler added")

--save CSAR MODE
trigger.action.setUserFlag("CSAR_MODE", DCSR.csarMode)

env.info((ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date))
