-- Dynamic Sequential Mission Campaign -- START TIME UPDATE module

local ModuleName  	= "GOAP"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('GOAP', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')
local Terrain		= require('terrain')
local ME_DB   		= require('me_db_api')
local loadoutUtils  = require('me_loadoututils') -- check this
local ConfigHelper = require('ConfigHelper')
local TableUtils	= require('TableUtils')

local GOAPfiles = lfs.writedir() .. "Missions/Temp/Files/GOAP/"

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## debug variables
local Table_Debug = true

-- ## variables
local onRoadSpeed = 12 -- m/s, about 43.2 km/h
local offRoadSpeed = 6 -- m/s, about 21.6 km/h
local wpt2altitude = 610 -- m, 610 = 2000 ft, altitude for first waypoint after T/O
local wptBDZdist = 9266 -- m, about 5 nm

-- ## parameter variables
local planeSpeed 				= 190 --m/s
local heloSpeed					= 50 -- m/seeall
local planeRange				= 600 -- km
local heloRange					= 50 --km


-- ## task variables
local CAP_engage_distance 		= 92600 -- 50 nm
local DCA_engage_distance 		= 74080 -- 40 nm
local Sweep_engage_distance 	= 185200 -- 100 nm
local AmbCAP_engage_distance 	= 55560 -- 30 nm
local SEAD_engage_distance		= 129640 -- 70 nm
local ArRecon_engage_distance	= 15000 -- 15 km
local mission_Duration			= 120 -- mins


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

local tblPayloads = nil
local tblTasks = nil
if loadoutUtils then
	--HOOK.writeDebugDetail(ModuleName .. ": c1a")
	local function loadPayloads_()
		-- загрузка базы данных	
		local unitPayloadsFolder = ConfigHelper.getUnitPayloadsSysPath()
		local filenames = loadoutUtils.getUnitPayloadFileNames()
		
		local defaultUnitsPayload = {}
		local unitsPayload = {}
		local unitPayloadsFilename = {}
		HOOK.writeDebugDetail(ModuleName .. ": c1b")
		for i, filename in pairs(filenames) do
			local path = loadoutUtils.getUnitPayloadsReadPath(filename)
			local f, err = loadfile(path)
			
			if f then
				--HOOK.writeDebugDetail(ModuleName .. ": c1c")
				local ok, res = base.pcall(f)
				if ok then
					local unitPayloads = res
					local unitType = unitPayloads.unitType or unitPayloads.name
					defaultUnitsPayload[unitType] = unitPayloads
					unitPayloadsFilename[unitType] = filename
				else
					--log.error('ERROR: loadPayloads_() failed to pcall "'..filename..'": '..res)
					HOOK.writeDebugDetail(ModuleName .. ": ERROR: loadPayloads_() failed to pcall ".. tostring(filename))
				end				              
			else
				--print('Cannot load payloads!',filename,path, err)
				HOOK.writeDebugDetail(ModuleName .. ": Cannot load payloads!")
			end
		end
		
		--HOOK.writeDebugDetail(ModuleName .. ": c1d")
		TableUtils.recursiveCopyTable(unitsPayload, defaultUnitsPayload)
		--HOOK.writeDebugDetail(ModuleName .. ": c1e")
		--HOOK.writeDebugDetail(ModuleName .. ": c1f")
		return unitsPayload
	end

	tblPayloads = loadPayloads_()
	tblTasks = loadoutUtils.getTasks()
	if Table_Debug then
		UTIL.dumpTable("tblPayloads.lua", tblPayloads)
		UTIL.dumpTable("tblTasks.lua", tblTasks)
	end
end

-- this check to be sure that payloads tables are available
local GOAP_proceed = false
if tblPayloads and tblTasks then
	if type(tblPayloads) == "table" and type(tblTasks) == "table" then
		GOAP_proceed = true
	end
end
if GOAP_proceed == false then
	HOOK.writeDebugDetail(ModuleName .. ": halting process, failed to retrieve tblPayloads and tblTasks")
	return
end

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

function createWpts_aircraft(TempWpt, missionEnv, dictEnv, position, altitude, altType, speed, wpName, option1, stoption1, option2, stoption2, task1, sttask1, task2, sttask2, option3, stoption3, option4, stoption4)
	
	local wpt = UTIL.deepCopy(TempWpt)

	-- define primary parameters
	local x, y, h, s, at, wn
	x = position.x
	y = position.z
	s = speed
	h = altitude
	if not h then
		h = Terrain.GetHeight(x, y) + 6096 -- 20kFt above ground!
	end
	at = altType
	if not at then
		at = "RADIO"
	end
	wn = wpName
	if not wn then
		wn = ""
	end	

	-- define tasks
	local suTasks = {}
	local curTaskNum = 1

	if option1 then 
		if stoption1 then
			for oType, oTable in pairs(stoption1) do
				option1.params.task[oType] = oTable
			end
		end

		option1.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option1
	end

	if option2 then 
		if stoption2 then
			for oType, oTable in pairs(stoption2) do
				option2.params.task[oType] = oTable
			end
		end

		option2.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option2
	end

	if task1 then 
		if sttask1 then
			for oType, oTable in pairs(sttask1) do
				task1.params.task[oType] = oTable
			end
		end

		task1.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = task1
	end
	
	if task2 then 
		if sttask2 then
			for oType, oTable in pairs(sttask2) do
				task1.params.task[oType] = oTable
			end
		end

		task2.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = task2
	end

	if option3 then 
		if stoption3 then
			for oType, oTable in pairs(stoption3) do
				option3.params.task[oType] = oTable
			end
		end

		option3.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option3
	end


	if option4 then 
		if stoption4 then
			for oType, oTable in pairs(stoption4) do
				option4.params.task[oType] = oTable
			end
		end

		option4.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option4
	end

	-- check fighter
	if x and y and h and s and suTasks then
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
				["tasks"] = suTasks,
			}, -- end of ["params"]
		}

		-- create wptName
		if missionEnv.maxDictId then
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, tblDictEntries set")
			missionEnv.maxDictId = missionEnv.maxDictId+1	
			local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			dictEnv[WptDictEntry] = wn

			wpt.name = WptDictEntry
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, done")
			return wpt

		else
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, no missionEnv.maxDictId!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft missing key variables")
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

-- ## tables (After all to make available those functions)
local tblOptions = {
	["restrictABuse"] = {
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
	},
	["freeABuse"] = {
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
	},
	["allowAbortMission"] = {
		["enabled"] = true,
		["auto"] = true,
		["id"] = "WrappedAction",
		["number"] = 1,
		["params"] = 
		{
			["action"] = 
			{
				["id"] = "Option",
				["params"] = 
				{
					["value"] = 4,
					["name"] = 1,
				}, -- end of ["params"]
			}, -- end of ["action"]
		}, -- end of ["params"]
	}, -- end of [1]
	["EPLRSon"] = {
		["enabled"] = true,
		["auto"] = true,
		["id"] = "WrappedAction",
		["number"] = 2,
		["params"] = 
		{
			["action"] = 
			{
				["id"] = "EPLRS",
				["params"] = 
				{
					["value"] = true,
					["groupId"] = 1, -- REMEMBER TO UPDATE IN MISSION FUNCTION !!!!!!
				}, -- end of ["params"]
			}, -- end of ["action"]
		}, -- end of ["params"]
	}, -- end of [2]
	["ROE_return_fire"] = {
		["enabled"] = true,
		["auto"] = false,
		["id"] = "WrappedAction",
		["number"] = 1,
		["params"] = 
		{
			["action"] = 
			{
				["id"] = "Option",
				["params"] = 
				{
					["value"] = 3,
					["name"] = 0,
				}, -- end of ["params"]
			}, -- end of ["action"]
		}, -- end of ["params"]
	}, -- end of [1]
	["RTB_on_Bingo"] = {
		["enabled"] = true,
		["auto"] = false,
		["id"] = "WrappedAction",
		["number"] = 1,
		["params"] = 
		{
			["action"] = 
			{
				["id"] = "Option",
				["params"] = 
				{
					["value"] = true,
					["name"] = 6,
				}, -- end of ["params"]
			}, -- end of ["action"]
		}, -- end of ["params"]
	}, -- end of [1]
	["Radar_attack_only"] = {
		["enabled"] = true,
		["auto"] = false,
		["id"] = "WrappedAction",
		["number"] = 1,
		["params"] = 
		{
			["action"] = 
			{
				["id"] = "Option",
				["params"] = 
				{
					["value"] = 1,
					["name"] = 3,
				}, -- end of ["params"]
			}, -- end of ["action"]
		}, -- end of ["params"]
	}, -- end of [1]
	["SET_TACAN"] = {
		["number"] = 1,
		["auto"] = true,
		["id"] = "WrappedAction",
		["enabled"] = true,
		["params"] = 
		{
			["action"] = 
			{
				["id"] = "ActivateBeacon",
				["params"] = 
				{
					["type"] = 4,
					["frequency"] = 1088000000, -- set freq
					["callsign"] = "TKR",
					["channel"] = 1, -- set channel
					["modeChannel"] = "X", -- set X or Y
					["bearing"] = true,
					["system"] = 4,
				}, -- end of ["params"]
			}, -- end of ["action"]
		}, -- end of ["params"]
	}, -- end of [2]
	["StopOnDuration"] = {
		["stopCondition"] = 
		{
			["duration"] = d,
		}, -- end of ["stopCondition"]
	},
}	

local tblTasks = {
	["AWACS_role"] = 
	{
		["dcsTask"] = "AWACS",
		["task"] = {		
			["number"] = 1,
			["auto"] = true,
			["id"] = "AWACS",
			["enabled"] = true,
			["params"] = 
			{
			}, -- end of ["params"]
		},
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 9266,
		["useEPLRS"] = true,
	},
	["Tanker_role"] = 
	{
		["dcsTask"] = "Tanker",
		["task"] = {
			["number"] = 1,
			["auto"] = true,
			["id"] = "Tanker",
			["enabled"] = true,
			["params"] = 
			{
			}, -- end of ["params"]
		},
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 9266,
		["useTacan"] = true,
	},
	["CAP"] = 
	{
		["dcsTask"] = "CAP",
		["task"] = {
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
				["maxDist"] = CAP_engage_distance,
			}, -- end of ["params"]
		},
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 9266,
		["duration"] = mission_Duration, -- minutes
	},
	["DCA"] = 
	{
		["dcsTask"] = "CAP",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "EngageTargets",
			["name"] = "DCA_Task",
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
				["maxDist"] = DCA_engage_distance,
			}, -- end of ["params"]
		},
		["altitude"] = 6096,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 18532,
		["duration"] = mission_Duration, -- minutes
	},
	["AmbushCAP"] = 
	{
		["dcsTask"] = "CAP",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "EngageTargets",
			["name"] = "AmbCAP_Task",
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
				["maxDist"] = AmbCAP_engage_distance,
			}, -- end of ["params"]
		},
		["altitude"] = 300,
		["altType"] = "RADIO",
		["enroute"] = true,
		["orbit"] = 9266,
		["duration"] = mission_Duration, -- minutes
	},
	["Sweep"] = 
	{
		["dcsTask"] = "CAP",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "EngageTargets",
			["name"] = "Sweep_Task",
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
				["maxDist"] = Sweep_engage_distance,
			}, -- end of ["params"]
		},
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 37064,
		["duration"] = mission_Duration, -- minutes
	},
	["SEAD"] = 
	{
		["dcsTask"] = "SEAD",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "EngageTargets",
			["name"] = "SEAD_Task",
			["enabled"] = true,
			["params"] = 
			{
				["targetTypes"] = 
				{
					[1] = "Air Defence",
				}, -- end of ["targetTypes"]
				["noTargetTypes"] = 
				{
				}, -- end of ["noTargetTypes"]
				["value"] = "Air Defence;",
				["priority"] = 0,
				["maxDistEnabled"] = true,
				["maxDist"] = SEAD_engage_distance,
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 37064,
		["duration"] = mission_Duration, -- minutes
	},
	["Strike"] = -- func available, CAP
	{
		["dcsTask"] = "Ground Attack",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "Bombing",
			["name"] = "Bomb_Task",
			["enabled"] = true,
			["params"] = 
			{
				["direction"] = 0,
				["attackQtyLimit"] = false,
				["attackQty"] = 1,
				["expend"] = "Auto",
				["altitude"] = 2000,
				["directionEnabled"] = false,
				["groupAttack"] = true,
				["y"] = 0,
				["altitudeEnabled"] = false,
				["weaponType"] = 1073741822,
				["x"] = 0,
			}, -- end of ["params"]
		}, 
		["altitude"] = 9144,
		["altType"] = "RADIO",
	},
	["LoLevelStrike"] = -- func available, CAP
	{
		["dcsTask"] = "Ground Attack",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "Bombing",
			["name"] = "Bomb_Task",
			["enabled"] = true,
			["params"] = 
			{
				["direction"] = 0,
				["attackQtyLimit"] = false,
				["attackQty"] = 1,
				["expend"] = "Auto",
				["altitude"] = 2000,
				["directionEnabled"] = false,
				["groupAttack"] = true,
				["y"] = 0,
				["altitudeEnabled"] = false,
				["weaponType"] = 1073741822,
				["x"] = 0,
			}, -- end of ["params"]
		}, 
		["altitude"] = 9144,
		["altType"] = "RADIO",
		["LowLevel"] = 200,
	},
	["StrikeMapObj"] = -- func available, CAP
	{
		["dcsTask"] = "Ground Attack",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "AttackMapObject",
			["name"] = "Map_Task",
			["enabled"] = true,
			["params"] = 
			{
				["direction"] = 0,
				["attackQtyLimit"] = true,
				["attackQty"] = 1,
				["expend"] = "Auto",
				["altitude"] = 2000,
				["directionEnabled"] = false,
				["groupAttack"] = false,
				["y"] = 0,
				["altitudeEnabled"] = false,
				["weaponType"] = 1073741822,
				["x"] = 0,
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 9144,
		["altType"] = "RADIO",
	},
	["Escort"] = -- func available, CAP
	{
		["dcsTask"] = "Escort",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "Escort",
			["name"] = "Escort_Task",
			["enabled"] = true,
			["params"] = 
			{
				["groupId"] = 18,
				["engagementDistMax"] = CAP_engage_distance,
				["lastWptIndexFlagChangedManually"] = false,
				["targetTypes"] = 
				{
					[1] = "Planes",
				}, -- end of ["targetTypes"]
				["lastWptIndex"] = 4,
				["lastWptIndexFlag"] = false,
				["noTargetTypes"] = 
				{
					[1] = "Helicopters",
				}, -- end of ["noTargetTypes"]
				["pos"] = 
				{
					["y"] = 0,
					["x"] = -500,
					["z"] = 200,
				}, -- end of ["pos"]
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 9144,
		["altType"] = "BARO",
	},
	["Armed_Recon"] = -- func available, CAP
	{
		["dcsTask"] = "EngageTargets",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "EngageTargets",
			["name"] = "ArRecon_Task",
			["enabled"] = true,
			["params"] = 
			{
				["targetTypes"] = 
				{
					[1] = "All",
				}, -- end of ["targetTypes"]
				["noTargetTypes"] = 
				{
				}, -- end of ["noTargetTypes"]
				["value"] = "All;",
				["priority"] = 0,
				["maxDistEnabled"] = true,
				["maxDist"] = ArRecon_engage_distance,
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 80,
		["altType"] = "RADIO",
	},
	["Convoy_escort"] = -- func available, CAP
	{
		["dcsTask"] = "GroundEscort",
		["task"] = {
			["number"] = 1,
			["auto"] = false,
			["id"] = "GroundEscort",
			["name"] = "ConvoyEscort_Task",
			["enabled"] = true,
			["params"] = 
			{
				["targetTypes"] = 
				{
					[1] = "Helicopters",
					[2] = "Ground Units",
				}, -- end of ["targetTypes"]
				["groupId"] = 22,
				["engagementDistMax"] = 500,
				["lastWptIndexFlag"] = false,
				["lastWptIndexFlagChangedManually"] = true,
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 80,
		["altType"] = "RADIO",
	},
	["Orbit"] = -- func available, CAP
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
					["altitude"] = 2000,
					["pattern"] = "Race-Track",
					["speed"] = 300,
					["speedEdited"] = true,
				}, -- end of ["params"]
			}, -- end of ["task"]
		}, -- end of ["params"]
	}, -- end of [1]
}

function nearestCardinalAngle(angle)
	local d1 = angle - 0
	local d2 = angle - 90
	local d3 = angle - 180
	local d4 = angle - 270

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

	return mind
end

function planAirGroup(id, mizEnv, dicEnv, task, pos, delay)

	if id and pos and type(pos) == "table" then

		-- calculate delay
		for coalitionID,coalition in pairs(mizEnv["coalition"]) do
			for countryID,country in pairs(coalition["country"]) do
				for attrID,attr in pairs(country) do
					if attrID == "plane" or attrID == "helicopter" then
						if (type(attr)=="table") then
							for _,group in pairs(attr["group"]) do
								if (group) then
									if id == group.groupId then  -- this filter the correct group
										HOOK.writeDebugDetail(ModuleName .. ": planAirGroup found group: " .. tostring(id))

										--### CHECK GROUP
										if group.route then
											if group.route.points then
												HOOK.writeDebugDetail(ModuleName .. ": planAirGroup got point table for group: " .. tostring(id))

												--# check aircraft type exist
												local acfType = group["units"][1]["type"]
												if acfType then

													--# verify task and available data for tasking
													local taskParameters = nil
													local taskToUse = nil
													local enrouteFunc = nil
													local altToset = nil
													local orbitDist = nil
													local stationTime = nil
													local missionPayload = nil
													local timestart = delay

													for tsId, tsPar in pairs(tblTasks) do
														if task == tsId then
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup got task: " .. tostring(task))
															taskParameters = tsPar

															for acfName, acfData in pairs(ME_DB.unit_by_type) do
																if acfName == acfType then
																	if type(acfData.Tasks) == "table" then
																		for _, tData in pairs(acfData.Tasks) do
																			if tData.Name == taskParameters.dcsTask then
																				HOOK.writeDebugDetail(ModuleName .. ": planAirGroup got tData.Name: " .. tostring(tData.Name))													
																				taskToUse = taskParameters.wptFunc
																				enrouteFunc = taskParameters.enroute
																				altToset = taskParameters.altitude
																				orbitDist = taskParameters.orbit
																				stationTime = taskParameters.duration
																				missionPayload = nil

																				local availPayloads = {}
																				for pId, pData in pairs(tblPayloads) do
																					if pData.unitType == acfName then
																						for tId, tData in pairs(pData.payloads) do
																							for uId, uData in pairs(tData.tasks) do
																								if uData == tData.WorldID then
																									availPayloads[#availPayloads+1] = tData.pylons
																								end
																							end
																						end
																					end
																				end

																				if #availPayloads > 0 then
																					local value = math.random(1, #availPayloads)
																					for rId, rData in pairs(availPayloads) do
																						if rId == value then
																							missionPayload = rData
																							HOOK.writeDebugDetail(ModuleName .. ": planAirGroup payload choosen for task: " .. tostring(tData.Name))		
																						end

																					end
																				else
																					-- check a void table, like for AWACS
																					missionPayload = {}
																					HOOK.writeDebugDetail(ModuleName .. ": planAirGroup no payload available, stayin void for task: " .. tostring(tData.Name))
																				end
																			end
																		end
																	end
																end
															end
														end
													end

													--# verify flight parameters
													local s_cruise = nil		-- m/s
													local s_range = nil  		-- meters

													local uTbl = group.units[1]
													local uType = DCS.getUnitType(uTbl.unitId)
													for tName, tData in pairs(ME_DB.unit_by_type) do
														if tName == uType then

															-- range
															if tData.range then
																s_range = tData.range*1000/2 -- meters
															end

															-- speed
															if tData.V_opt then
																s_cruise = tData.V_opt -- m/s
															end

														end
													end

													-- refine & recheck data
													if not s_cruise then
														if attrID == "plane" then
															s_cruise = planeSpeed
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup speed & climb rate set. s_cruise not found, as plane:" .. tostring(s_cruise))
														else
															s_cruise = heloSpeed
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup speed & climb rate set. s_cruise not found, as helo:" .. tostring(s_cruise))
														end															
													end
													
													if not s_range then
														if attrID == "plane" then
															s_range = planeRange
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup range set. s_range not found, as plane:" .. tostring(s_range))
														else
															s_range = heloRange
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup range set. s_range not found, as helo:" .. tostring(s_range))
														end
													end
													
													if not missionPayload then
														missionPayload = {}
														HOOK.writeDebugDetail(ModuleName .. ": planAirGroup missionPayload was missing, setting to void")
													end

													HOOK.writeDebugDetail(ModuleName .. ": planAirGroup taskToUse: " .. tostring(taskToUse) .. ", taskParameters: " .. tostring(taskParameters) .. ", altToset: " .. tostring(altToset))

													--## PROCEED IF GROUP IS OK AND INFORMATIONS AVAILABLE
													if taskToUse and taskParameters and altToset and missionPayload then

														--## DELAY
														group.start_time = timestart

														--## ROUTE

														--# create new table
														local newPoints = {}

														--# delete all points but first
														local first = nil
														for pId, pData in pairs(group.route.points) do
															if pId == 1 then
																first = pData
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup identified first point")
															elseif pId > 1 then
																pId = nil
															end
														end

														--# delete all points but first
														if first then

															--# RESET WP1
															local wpt_takeoff = first

															wpt_takeoff.task = {
																["id"] = "ComboTask",
																["params"] = 
																{
																	["tasks"] = 
																	{
																	}, -- end of ["tasks"]
																}, -- end of ["params"]
															} -- end of ["task"]		
														
															
															-- starting parameters for wpt calculation
															local startPos = {x = first.x, y = first.alt, z = first.y}
															local distanceToPos = getDist(startPos, pos)
															local angleToPos = toDegree(getAngleByPos(startPos, pos))
															local angle90 = toDegree(getAngleByPos(startPos, pos))+90
															local angleCardinal = nearestCardinalAngle(angleToPos)

															--# SET WP2
															-- nearest point 5 nm nearby the most aligned cardinal angle
															local wpt2alt = first.alt+wpt2altitude
															local wpt2pos = getVec3ByAngDistAlt(startPos, wptBDZdist, nil, angleCardinal, wpt2alt) 
															local wpt_BDZ = createWpts_aircraft(first, mizEnv, dicEnv, wpt2pos, wpt2alt, "BARO", s_cruise, "BDZ", tblOptions.restrictABuse)

															-- DA QUIIIIIIIIIIIIIIIIIIIIIIIIII
															 
															-- retrieve flight parameters
						
															-- all the others
															local wpt_enroute = nil
															local wpt_mainAction = nil
															local wpt_90turn = nil
															if enrouteFunc then -- set wp3 & wp4 & wp5 as activate task + 1st orbit point, 2nd orbit point
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup enroute task start")

																if distanceToPos and type(distanceToPos) == "number" then
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup distanceToPos: " .. tostring(distanceToPos))
																	local effSpan = math.floor(distanceToPos/2)

																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan: " .. tostring(effSpan))

																	--wp3
																	if effSpan < wptBDZdist then
																		local wpt3pos = getVec3ByAngDistAlt(startPos, wptBDZdist, nil, mind, wpt2alt) 
																		--HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan angleToPos")
																		--TempWpt, missionEnv, dictEnv, position, altitude, altType, speed, wpName, option1, stoption1, option2, stoption2, task1, sttask1, task2, sttask2, option3, stoption3, option4, stoption4
																		wpt_enroute = createWpts_aircraft(first, mizEnv, dicEnv, wpt3pos, wpt2alt, "BARO", s_cruise, "Enroute", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse, nil, taskToUse)
																		
																		--taskToUse(first, mizEnv, dicEnv, wpt3pos, wpt2alt, s_cruise)
																		HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan b")											
																	else
																		HOOK.writeDebugDetail(ModuleName .. ": planAirGroup enroute")
																		local wp3dist = distanceToPos*0.75
																		if (distanceToPos - wp3dist) < (5*1852) then
																			wp3dist = distanceToPos*0.5
																		end

																		local wpt3pos = getVec3ByAngDistAlt(startPos, wp3dist, nil, angleToPos, altToset)
																		wpt_enroute = createWpts_aircraft(first, mizEnv, dicEnv, wpt3pos, altToset, "BARO", s_cruise, "Enroute", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse, nil, taskToUse)
																		--taskToUse(first, mizEnv, dicEnv, wpt3pos, altToset, s_cruise)
																	end

																	--wp4
																	--for sId, sData in pairs(tblOptions.StopOnDuration do
																	wpt_mainAction = createWpts_aircraft(first, mizEnv, dicEnv, pos, altToset, "BARO", s_cruise, "Orbit", nil, nil, nil, nil, tblTasks.Orbit, tblOptions.StopOnDuration)
																	--createWpts_Orbit(first, mizEnv, dicEnv, pos, altToset, s_cruise, stationTime)

																	--wp5
																	if orbitDist then
																		local wpt5pos = getVec3ByAngDistAlt(pos, orbitDist, nil, angle90, altToset)
																		HOOK.writeDebugDetail(ModuleName .. ": planAirGroup altToset with orbitDist: " .. tostring(altToset))
																		wpt_90turn = createWpts_aircraft(first, mizEnv, dicEnv, wpt5pos, altToset, "BARO", s_cruise)
																		--createWpts_Generic(first, mizEnv, dicEnv, wpt5pos, altToset, s_cruise)
																	else
																		local wpt5pos = getVec3ByAngDistAlt(pos, 9266, nil, angle90, altToset)
																		HOOK.writeDebugDetail(ModuleName .. ": planAirGroup altToset wo orbitDist: " .. tostring(altToset))
																		wpt_90turn = createWpts_aircraft(first, mizEnv, dicEnv, wpt5pos, altToset, "BARO", s_cruise)
																	end
																else
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup unable to calculate enroute distanceToPos, halting planning process!\n\n")
																	return false
																end
															else
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup point task start")

																if distanceToPos and type(distanceToPos) == "number" then
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup distanceToPos: " .. tostring(distanceToPos))
																	local effSpan = math.floor(distanceToPos/2)

																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan: " .. tostring(effSpan))

																	--wp3
																	if effSpan < wptBDZdist then
																		local wpt3pos = getVec3ByAngDistAlt(startPos, wptBDZdist, nil, mind, wpt2alt) 
																		--HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan angleToPos")
																		--TempWpt, missionEnv, dictEnv, position, altitude, altType, speed, wpName, option1, stoption1, option2, stoption2, task1, sttask1, task2, sttask2, option3, stoption3, option4, stoption4
																		wpt_enroute = createWpts_aircraft(first, mizEnv, dicEnv, wpt3pos, wpt2alt, "BARO", s_cruise, "Enroute", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse, nil, taskToUse)
																		
																		--taskToUse(first, mizEnv, dicEnv, wpt3pos, wpt2alt, s_cruise)
																		HOOK.writeDebugDetail(ModuleName .. ": planAirGroup effSpan b")											
																	else
																		HOOK.writeDebugDetail(ModuleName .. ": planAirGroup intermediate wpt")
																		local wp3dist = distanceToPos*0.75
																		if (distanceToPos - wp3dist) < (5*1852) then
																			wp3dist = distanceToPos*0.5
																		end

																		local wpt3pos = getVec3ByAngDistAlt(startPos, wp3dist, nil, a, altToset)
																		wpt_enroute = createWpts_aircraft(first, mizEnv, dicEnv, wpt3pos, altToset, "BARO", s_cruise, "Enroute", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse)
																		--taskToUse(first, mizEnv, dicEnv, wpt3pos, altToset, s_cruise)
																	end
																
																	-- wp4 specific task (like bombing)
																	-- define pos altitude
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup target wpt")
																	local wp4alt = Terrain.GetHeight(x, y)
																	local wp4pos = {x = pox.x, y = 	wp4alt, z = pos.z}
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup target wpt altitude set: " .. tostring(wp4alt))
																	wpt_mainAction = createWpts_aircraft(first, mizEnv, dicEnv, wp4pos, wp4alt, "RADIO", s_cruise, "Orbit", nil, nil, nil, nil, taskToUse)

																	-- wp5 90 degree turn and go back
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup turn after tgt")
																	local wp5alt = wp4alt+610
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup turn after tgt wpt altitude set: " .. tostring(wp5alt))
																	local wpt5pos = getVec3ByAngDistAlt(wp4pos, 9266, nil, angle90, wp5alt)
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup altToset wo orbitDist: " .. tostring(altToset))
																	wpt_90turn = createWpts_aircraft(first, mizEnv, dicEnv, wpt5pos, wp5alt, "BARO", s_cruise)

																end


															end

															-- landing
															local wpt_Landing = createWpts_Landing(first, mizEnv, dicEnv, s_cruise)

															-- summarize points
															newPoints[#newPoints+1] = wpt_takeoff
															newPoints[#newPoints+1] = wpt_BDZ
															newPoints[#newPoints+1] = wpt_enroute
															newPoints[#newPoints+1] = wpt_mainAction
															newPoints[#newPoints+1] = wpt_90turn
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
	else
		HOOK.writeDebugBase(ModuleName .. ": planAirGroup missing id or pos data")
		return false
	end

end







--~=