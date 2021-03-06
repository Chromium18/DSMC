-- Dynamic Sequential Mission Campaign -- START TIME UPDATE module

local ModuleName  	= "GOAP"
local MainVersion 	= "2"
local SubVersion 	= "0"
local Build 		= "2044"
local Date			= "17/10/2020"

--## LIBS
local base 			= _G
module('GOAP', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')
local Terrain		= require('terrain')
local ME_DB   		= require('me_db_api')

local GOAPfiles = lfs.writedir() .. "Missions/Temp/Files/GOAP/"

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## variables
local onRoadSpeed = 12 -- m/s, about 43.2 km/h
local offRoadSpeed = 6 -- m/s, about 21.6 km/h
local wpt2altitude = 610 -- m, 610 = 2000 ft, altitude for first waypoint after T/O
local wptBDZdist = 9266 -- m, about 5 nm
  





--[[ util


function myDot(vec3a, vec3b)
    return (vec3a.x * vec3b.x) + (vec3a.z * vec3b.z) + (vec3a.y * vec3b.y)
end

function myMag(vec3a)
    return math.sqrt((vec3a.x * vec3a.x) + (vec3a.z * vec3a.z) + (vec3a.y * vec3a.y))
end

function doAngle(vec3a, vec3b)
	local ansAgain = math.acos(myDot(vec3a, vec3b) / (myMag(vec3a) * myMag(vec3b)))
	local angDegree = toDegree(ansAgain)
	return angDegree
end
--]]

function toDegree(radian)
	local a = radian*180/math.pi
	if a < 0 then
		a = a + 360
	end
	return a
end

function toRadian(angle)
	local a = angle*(math.pi/180)
	return a
end

function getAngleByPos(p1,p2)
    local p = {}
    p.x = p2.x-p1.x
    p.y = p2.z-p1.z
 
    local r = math.atan2(p.y,p.x)   -- *180/math.pi
    return r
end

function getVec3ByAngDistAlt(p1, distance, radiant, angle, altitude)
	local x1 = p1.x
	local y1 = p1.y
	local z1 = p1.z

	-- angle entry has priority to radian
	if angle then
		radiant = toRadian(angle)
	end

	local x2 = distance*math.cos(radiant)+x1
	local z2 = distance*math.sin(radiant)+z1
	local y2 = y1

	-- correct altitude if provided
	if altitude then
		y2 = altitude
	end

	local p2 = {x= x2, y=y2, z = z2}
    return p2
end

function getDist(point1, point2)
    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone
    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

-- load GOAP
function loadCode()
    HOOK.writeDebugDetail(ModuleName .. ": loadCode opening GOAP_inj")  
    local ey = io.open(lfs.writedir() .. "DSMC/" .. "GOAP_inj.lua", "r")
    local EmbeddedcodeGOAP = nil
    if ey then
        HOOK.writeDebugDetail(ModuleName .. ": loadCode reading GOAP_inj") 
        EmbeddedcodeGOAP = tostring(ey:read("*all"))
        ey:close()    
        HOOK.writeDebugDetail(ModuleName .. ": loadCode loading GOAP_inj into the mission")  
        UTIL.inJectCode("EmbeddedcodeGOAP", EmbeddedcodeGOAP)
        HOOK.writeDebugDetail(ModuleName .. ": loadCode done & Ready")  
    else
        HOOK.writeDebugBase(ModuleName .. ": GOAP_inj.lua not found")
	end
	
	-- make directory
	lfs.mkdir(GOAPfiles)
end

HOOK.writeDebugDetail(ModuleName .. ": local function loadCode loaded")

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
TMUPloaded = true

-- bingo
function townTableCheck(town)
    if town then
        if type(town) == 'string' then -- assuming name
            local townTable = nil
            for tName, tData in pairs(tblTerrainDb.towns) do
                if town == tData.display_name then
                    return tData
                end
            end
            HOOK.writeDebugDetail(ModuleName .. ": townTableCheck: no town available")
            return nil

        elseif type(town) == 'table' then
            return town
        else
            HOOK.writeDebugDetail(ModuleName .. ": townTableCheck: wrong variable")
            return nil
        end
    else
        HOOK.writeDebugDetail(ModuleName .. ": townTableCheck: missing variable")
        return nil
    end
end

function createColourZones(missionEnv, tblTerrain)
	if missionEnv and tblTerrain then

		local currentZoneNum 	= table.getn(missionEnv.triggers.zones) + 1
		local currentZoneId		= 9000

		-- add zones & trigger
		for ds_id, ds_data in pairs(tblTerrain.towns) do	-- tblTerrain.towns		

			local okDoDestZone = true
			if #missionEnv.triggers.zones > 0 then
				for zoneNum, zoneData in pairs(missionEnv.triggers.zones) do
					if zoneData.name == tostring("DSMC_AreaOwn_" .. tostring(currentZoneId)) then
						HOOK.writeDebugDetail(ModuleName .. ": createColourZones, trigger is already there! : " .. tostring(currentZoneId))
						okDoDestZone = false
					end
				end
			end

			-- create zone
			if okDoDestZone and ds_data.pos and ds_data.colour then

				if not missionEnv.triggers.zones[currentZoneNum] then
					missionEnv.triggers.zones[currentZoneNum] = {
						["x"] = ds_data.pos.x,
						["y"] = ds_data.pos.z,
						["radius"] = 1500,
						["zoneId"] = currentZoneId,
						["color"] = 
						{
							[1] = ds_data.colour[1],
							[2] = ds_data.colour[2],
							[3] = ds_data.colour[3],
							[4] = ds_data.colour[4],
						},
						["hidden"] = true,
						["name"] = "DSMC_AreaOwn_" .. ds_id,
						["properties"] = 
						{
						},
					}

					currentZoneNum 	= currentZoneNum +1
					currentZoneId	= currentZoneId +1
					HOOK.writeDebugDetail(ModuleName .. ": createColourZones, created zone name " .. tostring("DSMC_AreaOwn_" .. tostring(currentZoneId)))
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": createColourZones, zone skipped, already there!")
			end

		end
		HOOK.writeDebugDetail(ModuleName .. ": createColourZones, added code for zone owning")
	else
		HOOK.writeDebugDetail(ModuleName .. ": createColourZones, missing variables")
	end
end

-- function to load tables
function loadtables()
	HOOK.writeDebugBase(ModuleName .. ": loadtables started")
	for entry in lfs.dir(GOAPfiles) do
		if entry ~= "." and entry ~= ".." then
			local attr = lfs.attributes(GOAPfiles .. entry)
			if attr.mode == "file" then
				HOOK.writeDebugDetail(ModuleName .. ".loadtables : checking file = " .. tostring(entry))
				if string.find(entry, ".lua") and string.sub(entry, 1, 3) == "tbl" then
					local path = GOAPfiles .. entry
					HOOK.writeDebugDetail(ModuleName .. ".loadtables : check 1")
					local tbl_fcn, tbl_err = dofile(path)
					if tbl_err then
						HOOK.writeDebugDetail(ModuleName .. " loadtables : tbl_fcn = " .. tostring(tbl_fcn))
						HOOK.writeDebugDetail(ModuleName .. " loadtables : tbl_err = " .. tostring(tbl_err))
					else
						HOOK.writeDebugDetail(ModuleName .. " loadtables : imported table = " .. tostring(entry))
					end
				end
			end
		end
	end

	-- debug utility
	--if debugProcessDetail == true then
		HOOK.writeDebugDetail(ModuleName .. ": dumping tables..")
		UTIL.dumpTable("tblTerrainDb.lua", tblTerrainDb)
	--end
	--]]--
end

-- ############# GROUND PLANNING #############

-- creating ground waypoint
function createNearbyWptToRoad(TempWpt, a_typeRoad, missionEnv, dictEnv)
	
	local wpt = UTIL.deepCopy(TempWpt)

	local x, y
	if Terrain.getClosestPointOnRoads then
		x, y = Terrain.getClosestPointOnRoads(a_typeRoad, wpt.x, wpt.y)
	elseif a_typeRoad == "roads" then
		x, y = Terrain.FindNearestPoint(wpt.x, wpt.y, 40000.0)
	end

	if x and y then
		wpt.x = x
		wpt.y = y
		wpt.alt = Terrain.GetHeight(x, y)
		wpt.type = "Turning Point"
		wpt.ETA = 0
		wpt.formation_template = ""
		wpt.speed = onRoadSpeed
		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		} -- end of ["task"]
		wpt.speed_locked = true
		wpt.action = "On Road"
		wpt.ETA_locked = false

		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createNearbyWptToRoad, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = ""

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createNearbyWptToRoad, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createNearbyWptToRoad, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createNearbyWptToRoad missing x or y")
		return false
	end
end

function createGenericWpt(TempWpt, missionEnv, dictEnv, destination)
	
	local wpt = UTIL.deepCopy(TempWpt)

	local x, y
	x = destination.x
	y = destination.z

	if x and y then
		wpt.x = x
		wpt.y = y
		wpt.alt = Terrain.GetHeight(x, y)
		wpt.type = "Turning Point"
		wpt.ETA = 0
		wpt.formation_template = ""
		wpt.speed = offRoadSpeed
		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		} -- end of ["task"]
		wpt.speed_locked = true
		wpt.action = "Off Road"
		wpt.ETA_locked = false

		

		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = ""

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt missing x or y")
		return false
	end
end

function createDelayWpt(TempWpt, missionEnv, dictEnv, delay)
	
	local wpt = UTIL.deepCopy(TempWpt)

	local x, y
	x = wpt.x + 5
	y = wpt.y + 5

	if x and y then
		wpt.x = x
		wpt.y = y
		wpt.alt = Terrain.GetHeight(x, y)
		wpt.type = "Turning Point"
		wpt.ETA = 0
		wpt.formation_template = ""
		wpt.speed = offRoadSpeed
		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
					[1] = 
					{
						["enabled"] = true,
						["auto"] = false,
						["id"] = "ControlledTask",
						["number"] = 1,
						["params"] = 
						{
							["task"] = 
							{
								["id"] = "Hold",
								["params"] = 
								{
									["templateId"] = "",
								}, -- end of ["params"]
							}, -- end of ["task"]
							["stopCondition"] = 
							{
								["time"] = delay,
							}, -- end of ["stopCondition"]
						}, -- end of ["params"]
					}, -- end of [1]
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		} -- end of ["task"]
		wpt.speed_locked = true
		wpt.action = "Off Road"
		wpt.ETA_locked = false

		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = ""

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt missing x or y")
		return false
	end
end

function findOptimalPath(a_typeRoad, x1, y1, x2, y2)
    if (x1 == nil) or (y1 == nil) or (x2 == nil) or (y2 == nil) then
		HOOK.writeDebugDetail(ModuleName .. ": findOptimalPath Not valid coordinats in FindOptimalPath ")
        return
	end

    local path
    if Terrain.findPathOnRoads then
        path = Terrain.findPathOnRoads(a_typeRoad, x1, y1, x2, y2)
    elseif a_typeRoad == "roads" then
        path = Terrain.FindOptimalPath(x1, y1, x2, y2)
    end

	return path
end

-- ## function to plan a ground movement with delay
function planGroundGroup(missionEnv, id, destPos, roadUse, dictEnv, delay)

	local vec3town = townTableCheck(destPos)
	UTIL.dumpTable("GroupId_" .. tostring(id) .. "_vec3place.lua", vec3town)
	
	if vec3town then

		local vec3place = vec3town.pos

		for coalitionID,coalition in pairs(missionEnv["coalition"]) do
			for countryID,country in pairs(coalition["country"]) do
				for attrID,attr in pairs(country) do
					if (type(attr)=="table") then
						for groupID,group in pairs(attr["group"]) do
							if (group) then
								if id == group.groupId then  -- this filter the correct group
									HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup found group: " .. tostring(id))
									if group.route then
										if group.route.points then
											HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup got point table for group: " .. tostring(id))

											local newPoints = {}

											-- delete all points but first
											local first = nil
											for pId, pData in pairs(group.route.points) do
												if pId == 1 then
													first = pData
													HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup identified first point")
												elseif pId > 1 then
													pId = nil
												end
											end

											if first then

												-- re-add first waypoint
												newPoints[#newPoints+1] = first

												-- built first onRoadWp
												local dWpt = createDelayWpt(first, missionEnv, dictEnv, delay)
												newPoints[#newPoints+1] = dWpt

												if roadUse then
													local second = createNearbyWptToRoad(first, "roads", missionEnv, dictEnv)
													newPoints[#newPoints+1] = second
												end

												-- built destination point
												local last = createGenericWpt(first, missionEnv, dictEnv, vec3place)

												-- build intermediate point
												if roadUse then
													local third = createNearbyWptToRoad(last, "roads", missionEnv, dictEnv)
													newPoints[#newPoints+1] = third
												end

												newPoints[#newPoints+1] = last
												

												group.route.points = newPoints
												UTIL.dumpTable("GroupId_" .. tostring(id) .. "_route.points.lua", group.route.points)

												HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup done with route.points")

												if #group.route.points > 1 then
													group.route.spans = nil

													local p1, p2
													local spans = {}
													for i = 2, #group.route.points do
														p1 = group.route.points[i-1]
														p2 = group.route.points[i]

														if p1.action ~= "On Road" or p2.action ~= "On Road" then
															HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup adding span not on road")
															spans[i-1] = {{y = p1.y, x = p1.x}, {y = p2.y, x = p2.x}}   
														else
															local typeRoad = 'roads'
															HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup span pre path")
															local path = findOptimalPath(typeRoad, p1.x, p1.y, p2.x, p2.y)
															HOOK.writeDebugDetail(ModuleName .. ": planGroundGroup span post path")
															if path and #path > 0 then
																local s = {}
																for i=1, #path do
																	table.insert(s, {x=path[i].x, y=path[i].y})
																end
																spans[i-1] = s
															end
														end
													end
													
													p1 = group.route.points[#group.route.points]
													spans[#group.route.points] = {{y = p1.y, x = p1.x}, {y = p1.y, x = p1.x}};
													
													group.route.spans = spans
												end

											else
												HOOK.writeDebugBase(ModuleName .. ": planGroundGroup failed identifing first waypoint")
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



-- ############# AIR PLANNING #############

function createWpts_Orbit(TempWpt, missionEnv, dictEnv, position, altitude, speed, duration)
	
	local wpt = UTIL.deepCopy(TempWpt)

	-- define primary loc
	local x, y, h, s, d
	x = position.x
	y = position.z
	h = altitude
	s = speed
	d = duration

	if not h then
		h = Terrain.GetHeight(x, y) + 6096 -- 20kFt above ground!
	end

	-- check fighter

	if x and y and h and s then
		wpt.x = x
		wpt.y = y
		wpt.alt = h
		wpt.type = "Turning Point"
		wpt.ETA = 0
		wpt.formation_template = ""
		wpt.speed = s
		wpt.speed_locked = true
		wpt.action = "Turning Point"
		wpt.ETA_locked = false
		wpt.airdromeId = nil

		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
					[1] = 
					{
						["number"] = 1,
						["auto"] = false,
						["id"] = "ControlledTask",
						["name"] = "Orbit_Task",
						["enabled"] = true,
						["params"] = 
						{
							["task"] = 
							{
								["id"] = "Orbit",
								["params"] = 
								{
									["altitude"] = h,
									["pattern"] = "Race-Track",
									["speed"] = s,
									["speedEdited"] = true,
								}, -- end of ["params"]
							}, -- end of ["task"]
							["stopCondition"] = 
							{
								["duration"] = d,
							}, -- end of ["stopCondition"]
						}, -- end of ["params"]
					}, -- end of [1]
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		}

		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Orbit, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = "Orbit"

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Orbit, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Orbit, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_Orbit missing x or y")
		return false
	end
end

function createWpts_Generic(TempWpt, missionEnv, dictEnv, position, altitude, speed, restrictAB)
	
	local wpt = UTIL.deepCopy(TempWpt)

	-- define primary loc
	local x, y, h, s, d
	x = position.x
	y = position.z
	h = altitude
	s = speed
	r = restrictAB
	--d = duration

	if not h then
		h = Terrain.GetHeight(x, y) + 6096 -- 20kFt above ground!
	end

	-- check fighter
	if x and y and h and s then
		wpt.x = x
		wpt.y = y
		wpt.alt = h
		wpt.type = "Turning Point"
		wpt.ETA = 0
		wpt.formation_template = ""
		wpt.speed = s
		wpt.speed_locked = true
		wpt.action = "Turning Point"
		wpt.ETA_locked = false
		wpt.airdromeId = nil

		local subtask = {}
		if r == "on" then
			subtask = {
				[1] = 
				{
					["number"] = 1,
					["auto"] = false,
					["id"] = "WrappedAction",
					["enabled"] = true,
					["params"] = 
					{
						["action"] = 
						{
							["id"] = "Option",
							["params"] = 
							{
								["value"] = true,
								["name"] = 16,
							}, -- end of ["params"]
						}, -- end of ["action"]
					}, -- end of ["params"]
				}, -- end of [1]
			} -- end of ["tasks"]
		elseif r == "off" then
			subtask = {
				[1] = 
				{
					["number"] = 1,
					["auto"] = false,
					["id"] = "WrappedAction",
					["enabled"] = true,
					["params"] = 
					{
						["action"] = 
						{
							["id"] = "Option",
							["params"] = 
							{
								["value"] = false,
								["name"] = 16,
							}, -- end of ["params"]
						}, -- end of ["action"]
					}, -- end of ["params"]
				}, -- end of [1]
			} -- end of ["tasks"]
		end

		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = subtask,
			}, -- end of ["params"]
		}

		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Generic, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = ""

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Generic, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Generic, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_Generic missing x or y")
		return false
	end
end

function createWpts_Landing(TempWpt, missionEnv, dictEnv, speed)
	
	local wpt = UTIL.deepCopy(TempWpt)

	-- define primary loc
	local s
	s = speed

	-- check fighter
	if s then
		--wpt.alt = 0
		wpt.type = "Land"
		wpt.ETA = 0
		wpt.formation_template = ""
		--wpt.speed = s
		--wpt.speed_locked = true
		wpt.action = "Landing"
		wpt.ETA_locked = false

		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		}


		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Landing, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = "Landing"

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Landing, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_Landing, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_Landing missing x or y")
		return false
	end
end

function createWpts_CAP(TempWpt, missionEnv, dictEnv, position, altitude, speed, altType, range)
	
	-- funcToUse(first, mizEnv, dicEnv, wpt3pos, wpt2alt, s_cruise)

	local wpt = UTIL.deepCopy(TempWpt)

	-- define primary loc
	local x, y, h, s ,r
	x = position.x
	y = position.z
	h = altitude
	s = speed
	r = range
	at = altType

	if not h then
		h = Terrain.GetHeight(x, y) + 6096 -- 20kFt above ground!
	end

	if not r then
		r = 100000
	end

	
	if not at then
		at = "RADIO"
	end
	-- check fighter

	if x and y and h and s then
		wpt.x = x
		wpt.y = y
		wpt.alt = h
		wpt.alt_type = at
		wpt.type = "Turning Point"
		wpt.ETA = 0
		wpt.formation_template = ""
		wpt.speed = s
		wpt.speed_locked = true
		wpt.action = "Turning Point"
		wpt.ETA_locked = false
		wpt.airdromeId = nil
		wpt.task = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
					[1] = 
					{
						["number"] = 1,
						["auto"] = false,
						["id"] = "EngageTargets",
						["name"] = "CAP_Task",
						["enabled"] = true,
						["params"] = 
						{
							["targetTypes"] = 
							{
								[1] = "Air",
							}, -- end of ["targetTypes"]
							["noTargetTypes"] = 
							{
								[1] = "Cruise missiles",
								[2] = "Antiship Missiles",
								[3] = "AA Missiles",
								[4] = "AG Missiles",
								[5] = "SA Missiles",
							}, -- end of ["noTargetTypes"]
							["value"] = "Air;",
							["priority"] = 0,
							["maxDistEnabled"] = true,
							["maxDist"] = r,
						}, -- end of ["params"]
					}, -- end of [1]
					[2] =  -- remove AB restriction
					{
						["number"] = 2,
						["auto"] = false,
						["id"] = "WrappedAction",
						["enabled"] = true,
						["params"] = 
						{
							["action"] = 
							{
								["id"] = "Option",
								["params"] = 
								{
									["value"] = false,
									["name"] = 16,
								}, -- end of ["params"]
							}, -- end of ["action"]
						}, -- end of ["params"]
					}, -- end of [1]
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		}

		-- the bad, creating the wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_CAP, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = "CAP start activity"

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_CAP, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_CAP, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_CAP missing x or y")
		return false
	end
end



-- ## tables (After all to make available those functions)
local tblTasks = {
	["CAP"] = -- func available, CAP
	{
		["dcsTask"] = "CAP",
		["wptFunc"] = createWpts_CAP,
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["engageDist"] = 50000,
		["orbit"] = 9266,
		["duration"] = 150, -- minutes
	},
	["DCA"] =  -- func available, CAP
	{
		["dcsTask"] = "CAP",
		["wptFunc"] = createWpts_CAP,
		["altitude"] = 6096,
		["altType"] = "BARO",
		["enroute"] = true,
		["engageDist"] = 50000,
		["orbit"] = 18532,
		["duration"] = 180, -- minutes
	},
	["AmbushCAP"] = -- func available, CAP
	{
		["dcsTask"] = "CAP",
		["wptFunc"] = createWpts_CAP,
		["altitude"] = 300,
		["altType"] = "RADIO",
		["enroute"] = true,
		["engageDist"] = 30000,
		["orbit"] = 9266,
		["duration"] = 120, -- minutes
	},
	["Sweep"] = -- func available, CAP
	{
		["dcsTask"] = "CAP",
		["wptFunc"] = createWpts_CAP,
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["engageDist"] = 150000,
		["orbit"] = 37064,
		["duration"] = 120, -- minutes
	},
}



function planAirGroup(id, mizEnv, dicEnv, task, pos, delay)

	-- calculate delay
	for coalitionID,coalition in pairs(mizEnv["coalition"]) do
		for countryID,country in pairs(coalition["country"]) do
			for attrID,attr in pairs(country) do
				if attrID == "plane" or attrID == "helicopter" then
					if (type(attr)=="table") then
						for groupID,group in pairs(attr["group"]) do
							if (group) then
								if id == group.groupId then  -- this filter the correct group
									HOOK.writeDebugDetail(ModuleName .. ": planAirGroup found group: " .. tostring(id))
									if group.route then
										if group.route.points then
											HOOK.writeDebugDetail(ModuleName .. ": planAirGroup got point table for group: " .. tostring(id))

											local acfType = group["units"][1]["type"]
											local taskParameters = nil
											local funcToUse = nil
											local enrouteFunc = nil
											local altToset = nil
											local orbitDist = nil
											local stationTime = nil
											local timestart = delay

											if acfType then

												-- verify task
												for tsId, tsPar in pairs(tblTasks) do
													if task == tsId then
														HOOK.writeDebugDetail(ModuleName .. ": planAirGroup got task: " .. tostring(task))
														taskParameters = tsPar

														for acfName, acfData in pairs(ME_DB.unit_by_type) do
															if acfName == acfType then
																if type(acfData.Tasks) == "table" then
																	for tId, tData in pairs(acfData.Tasks) do
																		if tData.Name == taskParameters.dcsTask then
																			HOOK.writeDebugDetail(ModuleName .. ": planAirGroup got tData.Name: " .. tostring(tData.Name))													
																			funcToUse = taskParameters.wptFunc
																			enrouteFunc = taskParameters.enroute
																			altToset = taskParameters.altitude
																			orbitDist = taskParameters.orbit
																			stationTime = taskParameters.duration
																		end
																	end
																end
															end
														end
													end
												end			
												
												HOOK.writeDebugDetail(ModuleName .. ": planAirGroup funcToUse: " .. tostring(funcToUse) .. ", taskParameters: " .. tostring(taskParameters) .. ", altToset: " .. tostring(altToset))

												if funcToUse and taskParameters and altToset then

													local newPoints = {}

													-- delete all points but first
													local first = nil
													for pId, pData in pairs(group.route.points) do
														if pId == 1 then
															first = pData
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup identified first point")
														elseif pId > 1 then
															pId = nil
														end
													end

													if first and pos and type(pos) == "table" then

														local wpt_takeoff = first

														-- modify takeoff for task
														wpt_takeoff.task = {
															["id"] = "ComboTask",
															["params"] = 
															{
																["tasks"] = 
																{
																}, -- end of ["tasks"]
															}, -- end of ["params"]
														} -- end of ["task"]

														-- retrieve flight parameters
														local s_cruise

														local uTbl = group.units[1]
														local uType = DCS.getUnitType(uTbl.unitId)
														for tName, tData in pairs(ME_DB.unit_by_type) do
															if tName == uType then
																
																-- speed
																if tData.V_opt then
																	s_cruise = tData.V_opt -- m/s
																end

															end
														end

														if not s_cruise then
															s_cruise = 190
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup speed & climb rate set. s_cruise no found:" .. tostring(s_cruise))
														end
														HOOK.writeDebugDetail(ModuleName .. ": planAirGroup speed & climb rate set. s_cruise:" .. tostring(s_cruise))
																									
														-- ## starting parameters for wpt calculation
														local startPos = {x = first.x, y = first.alt, z = first.y}
														local distance = getDist(startPos, pos)
														local a = toDegree(getAngleByPos(startPos, pos))
														local a90 = toDegree(getAngleByPos(startPos, pos))+90

														-- ## second waypoint calculation, after T/O to the limit of the BDZ
														local d1 = a - 0
														local d2 = a - 90
														local d3 = a - 180
														local d4 = a - 270

														if d1 < 0 then d1 = -d1 end
														if d2 < 0 then d2 = -d2 end
														if d3 < 0 then d3 = -d3 end
														if d4 < 0 then d4 = -d4 end

														local mind = d1
														if d2 < mind then
															mind = d2
														end
														if d3 < mind then
															mind = d3
														end
														if d4 < mind then
															mind = d4
														end

														-- wpt 2
														local wpt2alt = first.alt+wpt2altitude -- mt
														local wpt2pos = getVec3ByAngDistAlt(startPos, wptBDZdist, nil, mind, wpt2alt) 
														local wpt_BDZ = createWpts_Generic(first, mizEnv, dicEnv, wpt2pos, wpt2alt, s_cruise, "on")

														-- all the others
														local wpt_enroute = nil
														local wpt_mainAction = nil
														local wpt_90turn = nil
														if enrouteFunc then -- set wp3 & wp4 & wp5 as activate task + 1st orbit point, 2nd orbit point
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup enroute start")

															if distance and type(distance) == "number" then
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup distance: " .. tostring(distance))
																local effSpan = math.floor(distance/2)

																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan: " .. tostring(effSpan))

																--wp3
																if effSpan < wptBDZdist then
																	local wpt3pos = getVec3ByAngDistAlt(startPos, wptBDZdist, nil, mind, wpt2alt) 
																	--HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan a")
																	wpt_enroute = funcToUse(first, mizEnv, dicEnv, wpt3pos, wpt2alt, s_cruise)
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan b")											
																else
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup enroute")
																	local wp3dist = distance*0.75
																	if (distance - wp3dist) < (5*1852) then
																		wp3dist = distance*0.5
																	end

																	local wpt3pos = getVec3ByAngDistAlt(startPos, wp3dist, nil, a, altToset)
																	wpt_enroute = funcToUse(first, mizEnv, dicEnv, wpt3pos, altToset, s_cruise)
																end

																--wp4
																wpt_mainAction = createWpts_Orbit(first, mizEnv, dicEnv, pos, altToset, s_cruise, stationTime)

																--wp5
																if orbitDist then
																	local wpt5pos = getVec3ByAngDistAlt(pos, orbitDist, nil, a90, altToset)
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup altToset with orbitDist: " .. tostring(altToset))
																	wpt_90turn = createWpts_Generic(first, mizEnv, dicEnv, wpt5pos, altToset, s_cruise)
																else
																	local wpt5pos = getVec3ByAngDistAlt(pos, 9266, nil, a90, altToset)
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup altToset wo orbitDist: " .. tostring(altToset))
																	wpt_90turn = createWpts_Generic(first, mizEnv, dicEnv, wpt5pos, altToset, s_cruise)
																end
															else
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup unable to calculate enroute distance, halting planning process!\n\n")
																return false
															end
														else

															-- ADD NON ENROUTE CODE


														end

														-- landing
														local wpt_Landing = createWpts_Landing(first, mizEnv, dicEnv, s_cruise)

														-- summarize points
														newPoints[#newPoints+1] = wpt_takeoff
														newPoints[#newPoints+1] = wpt_BDZ
														if enrouteFunc and wpt_enroute then
															newPoints[#newPoints+1] = wpt_enroute
														end
														newPoints[#newPoints+1] = wpt_mainAction
														if enrouteFunc and wpt_90turn then
															newPoints[#newPoints+1] = wpt_90turn
														end
														newPoints[#newPoints+1] = wpt_BDZ
														newPoints[#newPoints+1] = wpt_Landing
														
														group.route.points = newPoints
														--UTIL.dumpTable("GroupId_" .. tostring(id) .. "_route.points.lua", group.route.points)

														HOOK.writeDebugDetail(ModuleName .. ": planAirGroup done with route.points")
													else
														HOOK.writeDebugBase(ModuleName .. ": planAirGroup failed identifing first waypoint")
														return false
													end
												else
													HOOK.writeDebugBase(ModuleName .. ": planAirGroup unable to perform task: " .. tostring(task) .. " for acfType: " .. tostring(acfType))
													return false
												end
											else
												HOOK.writeDebugBase(ModuleName .. ": planAirGroup failed identifing acf unit type")
												return false
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







--~=