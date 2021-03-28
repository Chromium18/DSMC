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
local tblTasksDCS = nil
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
	tblTasksDCS = loadoutUtils.getTasks()
	if Table_Debug then
		UTIL.dumpTable("tblPayloads.lua", tblPayloads)
		UTIL.dumpTable("tblTasksDCS.lua", tblTasksDCS)
	end
end

-- this check to be sure that payloads tables are available
local GOAP_proceed = false
if tblPayloads and tblTasksDCS then
	if type(tblPayloads) == "table" and type(tblTasksDCS) == "table" then
		GOAP_proceed = true
	end
end
if GOAP_proceed == false then
	HOOK.writeDebugDetail(ModuleName .. ": halting process, failed to retrieve tblPayloads and tblTasks")
	return
end


-- ############# UTILS ######################

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
						--HOOK.writeDebugDetail(ModuleName .. ": createColourZones, trigger is already there! : " .. tostring(currentZoneId))
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
					--HOOK.writeDebugDetail(ModuleName .. ": createColourZones, created zone name " .. tostring("DSMC_AreaOwn_" .. tostring(currentZoneId)))
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

	HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, basic parameters set")

	-- define tasks
	local suTasks = {}
	local curTaskNum = 1

	if option1 then 
		if stoption1 then
			for oType, oTable in pairs(stoption1) do
				option1.params[oType] = oTable
			end
		end

		option1.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option1
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, opt 1 set")
	end

	if option2 then 
		if stoption2 then
			for oType, oTable in pairs(stoption2) do
				option2.params[oType] = oTable
			end
		end

		option2.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option2
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, opt 2 set")
	end

	if task1 then
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, task 1 exist")
		if sttask1 then
			HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, stop task 1 exist")
			for oType, oTable in pairs(sttask1) do
				HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, stop task insert")
				task1.params[oType] = oTable
				HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, stop task inserted")
			end
		end

		task1.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = task1
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, task 1 set")
	end
	
	if task2 then 
		if sttask2 then
			for oType, oTable in pairs(sttask2) do
				task1.params[oType] = oTable
			end
		end

		task2.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = task2
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, task 2 set")
	end

	if option3 then 
		if stoption3 then
			for oType, oTable in pairs(stoption3) do
				option3.params[oType] = oTable
			end
		end

		option3.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option3
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, opt 3 set")
	end


	if option4 then 
		if stoption4 then
			for oType, oTable in pairs(stoption4) do
				option4.params[oType] = oTable
			end
		end

		option4.number = curTaskNum
		curTaskNum = curTaskNum+1

		suTasks[#suTasks+1] = option4
		HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, opt 4 set")
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
			["duration"] = mission_Duration*60,
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
		["altitude"] = 8839,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 37064,
		["useEPLRS"] = true,
	},
	["Tanker_high"] = 
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
		["altitude"] = 7135,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 37064,
		["useTacan"] = true,
	},
	["Tanker_low"] = 
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
		["altitude"] = 5486,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 37064,
		["useTacan"] = true,
	},
	["Intercept"] = 
	{
		["dcsTask"] = "Intercept",
		["task"] = {
			["enabled"] = true,
			["auto"] = true,
			["id"] = "WrappedAction",
			["number"] = 1,
			["params"] = 
			{
				["action"] = 
				{
					["id"] = "EPLRS",
					["params"] = 
					{
						["value"] = true,
						["groupId"] = 1,
					}, -- end of ["params"]
				}, -- end of ["action"]
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 9266,
		["duration"] = mission_Duration*60, -- minutes
	},
	["Reconnaissance"] = 
	{
		["dcsTask"] = "Reconnaissance",
		["task"] = {
			["id"] = "ComboTask",
			["params"] = 
			{
				["tasks"] = 
				{
				}, -- end of ["tasks"]
			}, -- end of ["params"]
		},
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 9266,
		["duration"] = mission_Duration*60, -- minutes
	},
	["Antiship Strike"] = 
	{
		["dcsTask"] = "Antiship Strike",
		["task"] = {
			["enabled"] = true,
			["key"] = "AntiShip",
			["id"] = "EngageTargets",
			["number"] = 1,
			["auto"] = true,
			["params"] = 
			{
				["targetTypes"] = 
				{
					[1] = "Ships",
				}, -- end of ["targetTypes"]
				["priority"] = 0,
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 9144,
		["altType"] = "BARO",
		["enroute"] = true,
		["orbit"] = 9266,
		["duration"] = mission_Duration*60, -- minutes
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
		["duration"] = mission_Duration*60, -- minutes
	},
	["CAS"] = 
	{
		["dcsTask"] = "CAS",
		["task"] = {
			["enabled"] = true,
			["key"] = "CAS",
			["id"] = "EngageTargets",
			["number"] = 1,
			["auto"] = true,
			["params"] = 
			{
				["targetTypes"] = 
				{
					[1] = "Helicopters",
					[2] = "Ground Units",
					[3] = "Light armed ships",
				}, -- end of ["targetTypes"]
				["priority"] = 0,
			}, -- end of ["params"]
		}, -- end of [1]
		["altitude"] = 915,
		["altType"] = "RADIO",
		["enroute"] = true,
		["orbit"] = 9266,
		["duration"] = mission_Duration*60, -- minutes
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
		["duration"] = mission_Duration*60, -- minutes
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
		["duration"] = mission_Duration*60, -- minutes
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
		["duration"] = mission_Duration*60, -- minutes
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
		["duration"] = mission_Duration*60, -- minutes
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
																				taskToUse = taskParameters.dcsTask
																				taskTable = taskParameters.task
																				enrouteFunc = taskParameters.enroute
																				altToset = taskParameters.altitude
																				altTySet = taskParameters.altType
																				orbitDist = taskParameters.orbit
																				stationTime = taskParameters.duration -- set before options
																				missionPayload = nil

																				local availPayloads = {}
																				local taskWorldId = nil
																				for wId, wData in pairs(tblTasksDCS) do
																					if wData == taskToUse then
																						taskWorldId = wId
																						HOOK.writeDebugDetail(ModuleName .. ": planAirGroup found taskWorldId: " .. tostring(taskWorldId))
																					end
																				end

																				if not taskWorldId then
																					taskWorldId = 15	
																					HOOK.writeDebugDetail(ModuleName .. ": planAirGroup NOT found taskWorldId. So, make it nothing: " .. tostring(taskWorldId))
																				end

																				for pId, pData in pairs(tblPayloads) do
																					if pData.unitType == acfName then
																						for tId, tData in pairs(pData.payloads) do
																							for uId, uData in pairs(tData.tasks) do
																								if uData == taskWorldId then
																									HOOK.writeDebugDetail(ModuleName .. ": planAirGroup found a payload, id: " .. tostring(tId))
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
																							local defPayload = {}
																							for _, pData in pairs(rData) do
																								defPayload[pData.num] = {CLSID = pData.CLSID}
																							end
																							missionPayload = defPayload
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

													HOOK.writeDebugDetail(ModuleName .. ": planAirGroup taskToUse: " .. tostring(taskToUse) .. ", taskParameters: " .. tostring(taskParameters) .. ", altToset: " .. tostring(altToset) .. ", timestart: " .. tostring(timestart))

													--## PROCEED IF GROUP IS OK AND INFORMATIONS AVAILABLE
													if taskToUse and taskParameters and altToset and missionPayload then

														--## DELAY
														if timestart then
															group.start_time = timestart
															--if timestart > 0 then
															--	group.lateActivation = true
															--end
														end

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

															--# RESET WP1 - parking
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
															
															if timestart then
																wpt_takeoff.ETA = timestart
															end
															
															-- starting parameters for wpt calculation
															local startPos = {x = first.x, y = first.alt, z = first.y}
															local distanceToPos = getDist(startPos, pos)
															local angleToPos = toDegree(getAngleByPos(startPos, pos))
															local angle90 = toDegree(getAngleByPos(startPos, pos))+90
															local angleCardinal = nearestCardinalAngle(angleToPos)

															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup parameters set; distanceToPos: " .. tostring(distanceToPos) ..", angleToPos: " .. tostring(angleToPos)  ..", angle90: " .. tostring(angle90)  ..", angleCardinal: " .. tostring(angleCardinal)) 


															--# SET WP2 - limit on the BDZ, 2000 ft AGL
															-- nearest point 5 nm nearby the most aligned cardinal angle
															if attrID == "helicopter" then
																wpt2altitude = 100
															end
															local wpt2alt = wpt2altitude
															local wpt2pos = getVec3ByAngDistAlt(startPos, wptBDZdist, nil, angleCardinal, wpt2alt)
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp2 pos set")
															local wpt_BDZ = createWpts_aircraft(first, mizEnv, dicEnv, wpt2pos, wpt2alt, "RADIO", s_cruise, "BDZ", tblOptions.restrictABuse)
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp2 wpt set")


															--# SET WP3 - enroute point

															-- 3/4 distance aligned with the destination, altitude already on set.
															local wpt3dist = math.floor(distanceToPos*0.75)
															local wpt3alt = altToset
															local wpt3pos = getVec3ByAngDistAlt(startPos, wpt3dist, nil, angleToPos, wpt3alt)
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp3 pos set")

															-- if the task is enroute type, enlisting hercules
															if enrouteFunc then
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp3 is enroute")
																wpt_enroute = createWpts_aircraft(first, mizEnv, dicEnv, wpt3pos, wpt3alt, altTySet, s_cruise, "Enroute", tblOptions.RTB_on_Bingo, nil, tblOptions.restrictABuse, nil, taskTable)
															else
																wpt_enroute = createWpts_aircraft(first, mizEnv, dicEnv, wpt3pos, wpt3alt, altTySet, s_cruise, "", tblOptions.RTB_on_Bingo, nil, tblOptions.restrictABuse, nil)
															end
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp3 wpt set")

															
															--# SET WP4 - destination point

															-- full distance at destination, altitude on set.
															local wpt4alt = altToset
															local wpt4pos = pos
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp4 pos set")
															if enrouteFunc then
																local taskOrbitRev = UTIL.deepCopy(tblTasks.Orbit)
																taskOrbitRev.params.task.params.altitude = altToset
																taskOrbitRev.params.task.params.speed = s_cruise

																local stopOptionTime = UTIL.deepCopy(tblOptions.StopOnDuration)
																if stationTime and type(stationTime) == "number" then
																	stopOptionTime.stopCondition.duration = stationTime
																end

																wpt_destination = createWpts_aircraft(first, mizEnv, dicEnv, wpt4pos, wpt4alt, altTySet, s_cruise, "", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse, nil, taskOrbitRev, stopOptionTime)
															else
																-- revise pos
																local wpt4dist = math.floor(distanceToPos*0.9)
																wpt4pos = getVec3ByAngDistAlt(startPos, wpt4dist, nil, angleToPos, wpt4alt)																
																
																-- revise task
																local execTask = UTIL.deepCopy(taskTable)
																execTask.altitude = pos.y + 915 -- 3000 ft for strike
																execTask.params.x = pos.x
																execTask.params.y = pos.z

																-- add waypoint
																HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp4 is target")
																wpt_destination = createWpts_aircraft(first, mizEnv, dicEnv, wpt4pos, wpt4alt, altTySet, s_cruise, "Target", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse, nil, execTask)
															end
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp4 wpt set")


															--# SET WP5 - orbit span 

															-- full distance at destination, altitude on set.
															local wpt5dist = orbitDist or 3706 -- 2 nm
															local wpt5alt = altToset
															local wpt5pos = getVec3ByAngDistAlt(pos, wpt5dist, nil, angle90, wpt5alt)
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp5 pos set")
															wpt_orbit = createWpts_aircraft(first, mizEnv, dicEnv, wpt5pos, wpt5alt, altTySet, s_cruise, "", tblOptions.RTB_on_Bingo, nil, tblOptions.freeABuse, nil)
															HOOK.writeDebugDetail(ModuleName .. ": planAirGroup wp5 wpt set")


															--# SET WP6 - landing

															-- landing
															local wpt_Landing = createWpts_Landing(first, mizEnv, dicEnv, s_cruise)

															-- summarize points
															newPoints[#newPoints+1] = wpt_takeoff
															newPoints[#newPoints+1] = wpt_BDZ
															newPoints[#newPoints+1] = wpt_enroute
															newPoints[#newPoints+1] = wpt_destination
															newPoints[#newPoints+1] = wpt_orbit
															newPoints[#newPoints+1] = wpt_BDZ
															newPoints[#newPoints+1] = wpt_Landing
															
															group.route.points = newPoints
															group.lateActivation = nil
															group.task = taskToUse

															-- set payloads
															for _, uData in pairs(group.units) do
																if uData.payload.pylons then
																	HOOK.writeDebugDetail(ModuleName .. ": planAirGroup changed payload for unit id: " .. tostring(uData.unitId))
																	uData.payload.pylons = missionPayload
																end
															
															end

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


-- ############# GOAP GROUND MOVEMENT #############


-- ## State descriptor and functions

-- AllyGroundPresence - EnemyGroundPresence
function getTerrainState(terrName, coaId) 
	if coaId and type(coaId) == "number" and terrName and type(terrName) == "string" then
		if not tblTerrainDb then
			for _, tData in pairs(tblTerrainDb.towns) do
				if string.lower(tData.display_name) == string.lower(terrName) then
					
					local state = {}

					-- owner
					if tData.owner == coaId then
						state["TerritoryOwned"] = true
						state["TerritoryNotOwned"] = false
						state["TerritoryContended"] = false
					elseif tData.owner == 9 then
						state["TerritoryOwned"] = false
						state["TerritoryNotOwned"] = true
						state["TerritoryContended"] = true
					else
						state["TerritoryOwned"] = false
						state["TerritoryNotOwned"] = true
						state["TerritoryContended"] = false
					end

					-- ground presence
					local ally = false
					local allyAbsent = true
					local enemy = false
					local enemyAbsent = true
					local arty = false
					local tank = false
					local atgm = false
					local mSAM = false
					local armd = false
					local mvrs = false

					-- strenght
					local str = 0
					local btlGroups = {}

					for iId, iData in pairs(tData.coalition) do
						if iId == coaId then
							if #iData > 0 then
								ally = true
								allyAbsent = false
								for gId, gData in pairs(iData) do
									for aId, aData in pairs(gData.attributes) do
										if aData == "Arty" then
											arty = true
										elseif aData == "Tank" then
											btlGroups[#btlGroups+1] = {id = gId, strenght = gData.strenght}
											str = str + gData.strenght
											tank = true
										elseif aData == "Ranged" then
											btlGroups[#btlGroups+1] = {id = gId, strenght = gData.strenght}
											str = str + gData.strenght
											atgm = true
										elseif aData == "MovingSAM" then
											mSAM = true
										elseif aData == "Armored" then
											btlGroups[#btlGroups+1] = {id = gId, strenght = gData.strenght}
											str = str + gData.strenght
											armd = true
										elseif aData == "Movers" then
											btlGroups[#btlGroups+1] = {id = gId, strenght = gData.strenght}
											str = str + gData.strenght
											mvrs = true
										-- otherclass? -- check lines 6745 _inj
										end
									end
								end					
							end
						else
							if #iData > 0 then
								enemy = true
								enemyAbsent = false
							end						
						end
					end
					HOOK.writeDebugDetail(ModuleName .. ": getTerrainState, ally = " .. tostring(ally) .. ", enemy = " .. tostring(enemy))
					state["AllyGroundPresence"] = ally
					state["AlliedGroundAbsent"] = allyAbsent
					state["EnemyGroundPresence"] = enemy	
					state["EnemyGroundAbsent"] = enemyAbsent
					state["artyAvailable"] = arty
					state["tankAvailable"] = tank
					state["atgmAvailable"] = atgm
					state["msamAvailable"] = mSAM
					state["armdAvailable"] = armd
					state["mvrsAvailable"] = mvrs
					-- otherclass?

					-- strenght
					state["strenght"] = str -- refers to battlegroups only

					-- battlegroups
					state["battleGroups"] = btlGroups

					
					return state
				end
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": getTerrainState, missing tblTerrainDb, return false")
			return nil
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getTerrainState, missing variables, return false")
		return nil
	end
end


-- ## GOAP basics

GOAP.tblTerrainWS = {
	["owned"] = {
		["pre"] = {
			[1] = "AllyGroundPresence",
			[2] = "EnemyGroundAbsent",
			[3] = "TerritoryNotOwned",
		},		
		["eff"] = {
			[1] = "TerritoryOwned",
		},			
	},
	["not_owned"] = {
		["pre"] = {
			[1] = "EnemyGroundPresence",
			[2] = "AlliedGroundAbsent",
		},		
		["eff"] = {
			[1] = "TerritoryNotOwned",
		},			
	},
	["contended"] = {
		["pre"] = {
			[1] = "EnemyGroundPresence",
			[2] = "AllyGroundPresence",
		},		
		["eff"] = {
			[1] = "TerritoryContended",
		},			
	},
}

GOAP.tblActions = {
	["AttackTerritory"] = {
		["pre"] = {
			[1] = "AllyGroundAvailable",
			[2] = "routeAvailable",
		},		
		["eff"] = {
			[1] = "AllyGroundPresence",
			[2] = "IntelAvailable",
		},
		["cost"] = 0,	
	},
	["ReconTerritory"] = {
		["pre"] = {
			[1] = "AllyGroundAvailable",
			[2] = "routeAvailable",
		},		
		["eff"] = {
			[1] = "IntelAvailable",
		},
		["cost"] = 0,
	},
	["ShellTerritory"] = {
		["pre"] = {
			[1] = "artyAvailable",
			[2] = "withinRange",
			[3] = "IntelAvailable",
		},		
		["eff"] = {
			[1] = "EnemyGroundAbsent",
		},
		["cost"] = 0,		
	},
	["moveToTerritory"] = {
		["pre"] = {
			[1] = "mvrsAvailable",
			[2] = "EnemyGroundAbsent",
		},		
		["eff"] = {
			[1] = "AllyGroundPresence",
		},
		["cost"] = 0,		
	},	
}

function getActionCost(actionName, terr1, terr2, groupId) -- terr are tables, not names
	if actionName and terr1 and terr2 and groupId then
		HOOK.writeDebugDetail(ModuleName .. ": getActionCost starting, variables: actionName = " .. tostring(actionName) .. ", terr1 = " .. tostring(terr1) .. ", terr2 = " .. tostring(terr2) .. ", groupId = " .. tostring(groupId))
		
		local dist = math.floor(getDist(terr1.pos, terr2.pos)/100)/10 -- km, up to hundreds meters
		











	else
		HOOK.writeDebugDetail(ModuleName .. ": getActionCost missin variables, actionName = " .. tostring(actionName) .. ", terr1 = " .. tostring(terr1) .. ", terr2 = " .. tostring(terr2) .. ", groupId = " .. tostring(groupId))
	end
end












--------------------------------------------

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
GOAPloaded = true

--~=