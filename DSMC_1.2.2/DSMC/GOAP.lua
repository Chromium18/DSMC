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
local coaRiskMultiplier = 0 -- variable number from - 10 to + 10 that goes along the ALR, to be implemented.
local zeroDistance = 1500 -- m, fake distance applied when calculating forces proximity to target in the same territory
local townControlRadius = 3000 -- m from town center in which the update function will check presence of more than 1 coalition to define owner
local closeAttackRadius = townControlRadius
local rangeAttackRadius = townControlRadius*5
local contemporaryObjectives = 3 -- number of major cities with attack plans at the same time per coalition


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
		UTIL.dumpTable("tblIntelDb.lua", tblIntelDb)
		UTIL.dumpTable("tblORBATDb.lua", tblORBATDb)
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
		UTIL.inJectCode("GOAP_contrRadius", "GOAP.townControlRadius = " .. tostring(townControlRadius)) -- DSMC_disableF10  menu option

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
function createNearbyWptToRoad(TempWpt, a_typeRoad, missionEnv) -- ,dictEnv
	
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
			-- DICTPROBLEM
			--HOOK.writeDebugDetail(ModuleName .. ": createNearbyWptToRoad, tblDictEntries set")
			--missionEnv.maxDictId = missionEnv.maxDictId+1	
			--local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			--dictEnv[WptDictEntry] = ""

			wpt.name = "" --WptDictEntry
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

function createGenericWpt(TempWpt, missionEnv, destination) -- , dictEnv
	
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
			-- DICTPROBLEM
			--HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, tblDictEntries set")
			--missionEnv.maxDictId = missionEnv.maxDictId+1	
			--local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			--dictEnv[WptDictEntry] = ""

			wpt.name = "" -- WptDictEntry
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

function createDelayWpt(TempWpt, missionEnv, delay) -- , dictEnv
	
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
			-- DICTPROBLEM
			--HOOK.writeDebugDetail(ModuleName .. ": createGenericWpt, tblDictEntries set")
			--missionEnv.maxDictId = missionEnv.maxDictId+1	
			--local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			--dictEnv[WptDictEntry] = ""

			wpt.name = "" -- WptDictEntry
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
function planGroundMovement(missionEnv, id, destPos, roadUse, delay) -- , dictEnv

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
									HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement found group: " .. tostring(id))
									if group.route then
										if group.route.points then
											HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement got point table for group: " .. tostring(id))

											local newPoints = {}

											-- delete all points but first
											local first = nil
											for pId, pData in pairs(group.route.points) do
												if pId == 1 then
													first = pData
													HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement identified first point")
												elseif pId > 1 then
													pId = nil
												end
											end

											if first then

												-- re-add first waypoint
												newPoints[#newPoints+1] = first

												-- built first onRoadWp
												local dWpt = createDelayWpt(first, missionEnv, delay) --, dictEnv
												newPoints[#newPoints+1] = dWpt

												if roadUse then
													local second = createNearbyWptToRoad(first, "roads", missionEnv) --, dictEnv
													newPoints[#newPoints+1] = second
												end

												-- built destination point
												local last = createGenericWpt(first, missionEnv, vec3place) --, dictEnv

												-- build intermediate point
												if roadUse then
													local third = createNearbyWptToRoad(last, "roads", missionEnv)  --, dictEnv
													newPoints[#newPoints+1] = third
												end

												newPoints[#newPoints+1] = last
												

												group.route.points = newPoints
												UTIL.dumpTable("GroupId_" .. tostring(id) .. "_route.points.lua", group.route.points)

												HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement done with route.points")

												if #group.route.points > 1 then
													group.route.spans = nil

													local p1, p2
													local spans = {}
													for i = 2, #group.route.points do
														p1 = group.route.points[i-1]
														p2 = group.route.points[i]

														if p1.action ~= "On Road" or p2.action ~= "On Road" then
															HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement adding span not on road")
															spans[i-1] = {{y = p1.y, x = p1.x}, {y = p2.y, x = p2.x}}   
														else
															local typeRoad = 'roads'
															HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement span pre path")
															local path = findOptimalPath(typeRoad, p1.x, p1.y, p2.x, p2.y)
															HOOK.writeDebugDetail(ModuleName .. ": planGroundMovement span post path")
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
												HOOK.writeDebugBase(ModuleName .. ": planGroundMovement failed identifing first waypoint")
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

-- ## function to plan an arty fire with delay
function planFireMission(missionEnv, id, tgtPos, roadUse, delay) -- , dictEnv

	local tgtValid = false
	if type(tgtPos) == "table" then
		if tgtPos.x and tgtPos.z then
			tgtValid = true
		end
	end
	UTIL.dumpTable("GroupId_" .. tostring(id) .. "_tgtPos.lua", tgtPos)
	
	if tgtValid then

		--local vec3place = vec3town.pos

		for coalitionID,coalition in pairs(missionEnv["coalition"]) do
			for countryID,country in pairs(coalition["country"]) do
				for attrID,attr in pairs(country) do
					if (type(attr)=="table") then
						for groupID,group in pairs(attr["group"]) do
							if (group) then
								if id == group.groupId then  -- this filter the correct group

									HOOK.writeDebugDetail(ModuleName .. ": planFireMission found group: " .. tostring(id))
									if group.route then
										if group.route.points then

											HOOK.writeDebugDetail(ModuleName .. ": planFireMission got point table for group: " .. tostring(id))

											if group.route.points[1] then
												HOOK.writeDebugDetail(ModuleName .. ": planFireMission got first point")

												if group.route.points[1]["task"]["params"]["tasks"] then

													local tCopy = UTIL.deepCopy(group.route.points[1]["task"]["params"]["tasks"])
													HOOK.writeDebugDetail(ModuleName .. ": planFireMission got tasks")

													local tnumber = #tCopy
												
													if tnumber then
														tnumber = tnumber + 1
													else
														tnumber = 1
													end

													local fireTask = {
														["enabled"] = true,
														["auto"] = false,
														["id"] = "ControlledTask",
														["number"] = tnumber,
														["params"] = 
														{
															["condition"] = 
															{
																["time"] = delay,
															}, -- end of ["condition"]
															["task"] = 
															{
																["id"] = "FireAtPoint",
																["params"] = 
																{
																	["y"] = tgtPos.z,
																	["x"] = tgtPos.x,
																	["expendQty"] = 1,
																	["expendQtyEnabled"] = false,
																	["templateId"] = "",
																	["weaponType"] = 1073741822,
																	["zoneRadius"] = 100,
																}, -- end of ["params"]
															}, -- end of ["task"]
														}, -- end of ["params"]
													} -- end of [2]

													tCopy[#tCopy+1] = fireTask

													HOOK.writeDebugDetail(ModuleName .. ": planFireMission fire task created")

													group.route.points[1]["task"]["params"]["tasks"] = tCopy

													HOOK.writeDebugDetail(ModuleName .. ": planFireMission fire task set")

												end
											else
												HOOK.writeDebugBase(ModuleName .. ": planFireMission failed identifing first waypoint")
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
		HOOK.writeDebugBase(ModuleName .. ": planFireMission target is not a valid point")
	end
end




-- ############# AIR PLANNING #############

function createWpts_aircraft(TempWpt, missionEnv, position, altitude, altType, speed, wpName, option1, stoption1, option2, stoption2, task1, sttask1, task2, sttask2, option3, stoption3, option4, stoption4) -- , dictEnv
	
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
			--DICTPROBLEM
			--HOOK.writeDebugDetail(ModuleName .. ": createWpts_aircraft, tblDictEntries set")
			--missionEnv.maxDictId = missionEnv.maxDictId+1	
			--local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			--dictEnv[WptDictEntry] = wn

			wpt.name = wn-- WptDictEntry
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

function createWpts_Landing(TempWpt, missionEnv, speed) -- , dictEnv
	
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
			-- DICTPROBLEM
			--HOOK.writeDebugDetail(ModuleName .. ": createWpts_Landing, tblDictEntries set")
			--missionEnv.maxDictId = missionEnv.maxDictId+1	
			--local WptDictEntry = "DictKey_WptName_" .. missionEnv.maxDictId
			--dictEnv[WptDictEntry] = "Landing"

			wpt.name = "Landing" --WptDictEntry
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


-- ############# GOAP GROUND PLANNING #############



























-- ############# GOAP GROUND PLANNING #############


-- ############### CLASS LIST & LISTNODES ###############

ListNode = {}
ListNode.__index = ListNode

function ListNode:create()
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, ListNode create s0")
	local t = {
		value = nil,
		next = nil,
		prev = nil,
	}
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, ListNode create s1")
	setmetatable(t, self)
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, ListNode create s2")
	return t

end

function ListNode:__eq(o, p)
	if(o == nil or p == nil) then return false end
	if(o.value == p.value and o.next == p.next and o.prev == p.prev) then return true end
	return false
end

function ListNode:print()
	if self.value == nil then 
		--print("Root or nil")
		HOOK.writeDebugDetail(ModuleName .. ": ListNode Root or nil")
		return
	end
	HOOK.writeDebugDetail(ModuleName .. ": ListNode : " ..tostring(self.value))
	--print(self.value)
end

List = {}
List.__index = List

function List:create()

	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s0")
	self.root = ListNode:create()
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s1")
	self.root.next = self.root
	self.root.prev = self.root
	self.root.value = -1
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s2")
	self.len = 0

	setmetatable(self, List)
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s3")
	return self

	--[[
	local t = {}
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s0")
	t.root = ListNode:create()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s1")
	t.root.next = self.root
	t.root.prev = self.root
	t.root.value = -1
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s2")
	t.len = 0

	setmetatable(t, self)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List s3")
	return t
	--]]--
end

function List:__len()
	return self.len
end

function List:iterate()
	local i = self.root
	UTIL.dumpTable("GOAP.i.lua", i )
	return function()
		i = i.next
		if i ~= self.root then 
			return i.value 
		end 
	end
end

function List:getFirst()
	return self.root.next.value
end

function List:getLast()
	return self.root.prev.value
end

function List:isEmpty()
	HOOK.writeDebugDetail(ModuleName .. ": isEmpty = " .. tostring(self.root.next == self.root))
	return self.root.next == self.root
end

function List:insertLast(o)
	local element = ListNode:create()
	element.value = o
	
	element.prev = self.root.prev
	self.root.prev = element
	element.next = self.root
	element.prev.next = element
	self.len = self.len + 1
end

function List:insertFirst(o) 
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List insertFirst s0")
	local element = ListNode:create()
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List insertFirst s1")
	element.value = o
	
	element.next = self.root.next
	self.root.next = element
	element.prev = self.root
	element.next.prev = element
	self.len = self.len + 1
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, List insertFirst s2")
end

function List:removeElement(o)
    local i = self.root.next
    if(i == self.root) then return nil end
    while i ~= self.root do
        if(i.value == o) then
            i.prev.next = i.next
            i.next.prev = i.prev
			self.len = self.len - 1
            return i.value
        end
        i = i.next
    end
    return nil
end

function List:contains(o)
    local i = self.root.next
    if (i == self.root) then return false end
    
    while i ~= self.root do
        if(i.value == o) then return true end
        
        i = i.next
    end
    return false
end

function List:removeFirst()
	local result = self.root.next
	if(result == nil) then return nil end
	
	self.root.next = self.root.next.next
	self.root.next.prev = self.root
	self.len = self.len - 1
	
	return result.value
end

function List:removeLast()

	local result = self.root.prev
	if(result == nil) then return nil end
	
	self.root.prev = self.root.prev.prev
	self.root.prev.next = self.root
	self.len = self.len - 1
	
	return result
end

function List:print()	
	local i = self.root.next
	
	while i ~= self.root do
		HOOK.writeDebugDetail(ModuleName .. ": List i: " .. tostring(i))
		i = i.next
	end
end



-- ############### CLASS ACTION ###############

Action = {}
Action.__index = Action

function Action:create()

	--[[
	It serves as an example of how an Action should be structured to work with a Planning Algorithm

	Properties
	preconditions - Conditions to be achieved before the action can run. Each precondition must be presented in the following structure: {key:string, value: boolean} 
	effects - effects caused by the action. Each effect must be presented in the following structure: {key:string, value: boolean} 
	cost - Action Execution Cost
	parent - the object who cast this action
	target - the action who the action is cast into

	Methods
	addEffect - Inserts an effect in the effect list, must be cast in the constructor of child classes
	addPrecondition - Inserts a precondition in the preconditions list, must be cast in the constructor of child classes
	isDone - Tells if the action is over
	Run - Executes the Action
	contextCheck - Checks advanced things
	simbolicCheck - Checks basic things, simulation method

	NOT IMPLEMENTED removeEffect - Remove an effect from the effect list
	NOT IMPLEMENTED removePrecondition - Removes a precondition from preconditions list
	NOT IMPLEMENTED reset - Resets all properties
	--]]--

	local t = {
		preconditions = {},
		effects = {},
		cost = 1,
		parent = nil,
		target = nil,
		done = false,
	}
	setmetatable(t, self)
	return t
end

function Action:Run()
end

function Action:addPrecondition(o)
	--HOOK.writeDebugDetail(ModuleName .. ": Action addPrecondition s0")
	self.preconditions[o.keyValue] = o
	--HOOK.writeDebugDetail(ModuleName .. ": Action addPrecondition s1")
end

function Action:addEffect(o)
	--HOOK.writeDebugDetail(ModuleName .. ": Action addEffect s0")
	self.effects[o.keyValue] = o
	--HOOK.writeDebugDetail(ModuleName .. ": Action addEffect s1")
end

function Action:isDone()
	--HOOK.writeDebugDetail(ModuleName .. ": Action isDone s0")
	return self.done
end

function Action:symbolicCheck(o)
	--HOOK.writeDebugDetail(ModuleName .. ": Action symbolicCheck s0")
	for v in pairs(o.descriptors) do
		--HOOK.writeDebugDetail(ModuleName .. ": Action symbolicCheck s1")
		if self.effects[v] ~= nil and self.effects[v].keyValue == v and self.effects[v].currValue == o.descriptors[v].goalValue and o.descriptors[v].goalValue ~= o.descriptors[v].currValue then
			--HOOK.writeDebugDetail(ModuleName .. ": Action symbolicCheck s2")
			return true
		end
	end
	--HOOK.writeDebugDetail(ModuleName .. ": Action symbolicCheck failed")
	return false
end

function Action:contextCheck(o)
	--this should be updated for each action!
	--HOOK.writeDebugDetail(ModuleName .. ": Action contextCheck s0")
	return true
end



-- ############### CLASS WORLD STATE MANAGER ###############

WorldStateManager = {}
WorldStateManager.__index = WorldStateManager

function WorldStateManager:create()
	--[[
	Properties
	descriptors: world state Table - Holds the states that make the worldState
	f: double - estimated total cost
	g: double - walk cost
	h: double - heuristic cost
	parent: WorldStateManager - The parent node in a search Graph
	parentAction: Action - The action that transitioned to this world state

	Methods
	addDescriptor - adds a world state to the descriptors table
	isPerfect - Verify if all preconditions are satisfied, if true the plan is done
	generateSucessor - Receives an Action and adds its modifications to the current World description, returns a new table of World Manager
	Print - Print all descriptors inside the structure

	--]]--

	local t = {
		descriptors = {},
		f = 0.0,
		g = 0.0,
		h = 0.0,
		len = 0,
		parent = nil,
		parentAction = nil,
	}
	setmetatable(t, self)
	return t
end

function WorldStateManager:addDescriptor(o)
	if o and type(o) == "table" and type(o.keyValue) == "string" then
		--HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager addDescriptor s1")
		self.descriptors[o.keyValue] = o
		self.len = self.len + 1
		--HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager addDescriptor s2")
	else
		HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager addDescriptor s3")
		t = {
			keyValue = "",
			currValue = nil,
			goalValue = nil,
		}
		return t
	end
end

function WorldStateManager:isPerfect()
	--if Menu.common.devMode then print("Called WorldStateManager:isPerfect") end
	HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager isPerfect, self.len : " .. tostring(self.len))
	if(self.len == 0) then 
		return false 
	end
	
	for v in pairs(self.descriptors) do
		HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager isPerfect, checking " .. tostring(v) .. ", currValue: " .. tostring(self.descriptors[v].currValue))
		HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager isPerfect, checking " .. tostring(v) .. ", goalValue: " .. tostring(self.descriptors[v].goalValue))
		if(self.descriptors[v].currValue ~= self.descriptors[v].goalValue) then
			return false 
		end
	end
	HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager isPerfect, self.descriptors is ok!")
	return true
end

function WorldStateManager:generateSucessor(action)

	local result = WorldStateManager:create()  -- CHANGETHIS from WorldStateManager()
	
	for v in pairs(self.descriptors) do
		local t_descriptor = {keyValue = self.descriptors[v].keyValue, currValue = self.descriptors[v].currValue, goalValue = self.descriptors[v].goalValue}
		result:addDescriptor(t_descriptor)
	end
	
	for v in pairs(action.effects) do
		if result[v] == nil then
			local t_descriptor = {keyValue = v, currValue = action.effects[v].currValue, goalValue = true}
			result:addDescriptor(t_descriptor) 
		else
			result[v].currValue = v.currValue
		end
	end
	
	for v in pairs(action.preconditions) do
		if result[v] == nil then 
			local t_descriptor = {keyValue = v, currValue = action:contextCheck(), goalValue = action.preconditions[v].goalValue}
			result:addDescriptor(t_descriptor) 
		else
			result[v].goalValue = v.goalValue
		end
	end

	result.parentAction = action
	return result
end

function WorldStateManager:print()
	count = 0
	for _ in pairs(self.descriptors) do count = count + 1 end
	--print("descriptor size: "..count)
	HOOK.writeDebugDetail(ModuleName .. ": WorldStateManager print descriptor size: ".. tostring(count))
	
	for v in pairs(self.descriptors) do
		self.descriptors[v]:print()
	end
end

-- ############### PLANNER WORLD STATE MANAGER ###############

Planner = {}
Planner.__index = Planner

function Planner:create()

	--local t = {}
	self.allActions = List:create()
	self:initActions()
	UTIL.dumpTable("GOAP.Planner.lua" , Planner)
	setmetatable(self, Planner)
	--UTIL.dumpTable("GOAP.Planner.lua" , Planner)
	return self

end

function Planner:initActions()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s0a")
	attackTerritory:Launch()
	occupyTerritory:Launch()
	relocateForces:Launch()
	shellTerritory:Launch()
	hasORBAT:Launch()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s0b")

	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s0c")
	self.allActions:insertFirst(attackTerritory)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s1")
	self.allActions:insertFirst(occupyTerritory)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s2")
	self.allActions:insertFirst(relocateForces)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s3")
	self.allActions:insertFirst(shellTerritory)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s4")
	self.allActions:insertFirst(hasORBAT)

	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.initActions s5")
	UTIL.dumpTable("GOAP.self.allActions.lua" , self.allActions)
	return self
end

function Planner:getValidActions(state)
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions s0")
	--if Menu.common.devMode then print("called Planner:getValidActions") end
	result = List:create()-- List()
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions s1")
	UTIL.dumpTable("GOAP.getValidActions_self.allActions.lua" , self.allActions)
	UTIL.dumpTable("GOAP.getValidActions_ActionsIterate.lua" , self.allActions:iterate())
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions allActions found")

	for v in self.allActions:iterate() do 	
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions checking action: " .. tostring(v))
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions v:symbolicCheck(state): " .. tostring(v:symbolicCheck(state)))
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions v:contextCheck(): " .. tostring(v:contextCheck()))
		
		if(v:symbolicCheck(state) and v:contextCheck()) then
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions adding action: " .. tostring(v))
			result:insertFirst(v) 
			--v:print()
		end
	end
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.getValidActions s2")
	return result

end

function Planner:mountPlan(o)
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.mountPlan s0")
	local result = List:create()
	i = o
	while (i ~= nil) do
		result:insertFirst(i)

		i = i.parent
	end
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.mountPlan s1")
	return result
end

function Planner:BFSearch(start)
	UTIL.dumpTable("GOAP.BFSearch_s0.lua", self)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s0")
	local marked = List:create()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s1")
	local FIFO = List:create()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s2")
	
	FIFO:insertLast(start)
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s3")
	
	--UTIL.dumpTable("GOAP.FIFO.lua", FIFO)
	while not FIFO:isEmpty() do
		local myState = FIFO:getFirst()
		--UTIL.dumpTable("GOAP.myState_first.lua", myState)
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s4")
		UTIL.dumpTable("GOAP.BFSearch_4_myState.lua", myState)
		if(myState:isPerfect()) then 
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch DONE")
			
			return self:mountPlan(myState) 
		end
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s5")
		UTIL.dumpTable("GOAP.BFSearch_s5.lua", self)
		local myActions = self:getValidActions(myState)
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s6")

		local neighbors = List:create()

		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s7")
		UTIL.dumpTable("GOAP.BFSearch_7_myActions.lua", myActions)
		for v in myActions:iterate() do
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s8a. v: " .. tostring(v))
			local neighbor = FIFO:getFirst():generateSucessor(v)
			--UTIL.dumpTable("GOAP.neighbor_" .. tostring(v) .. ".lua", neighbor)
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s8b")
			neighbors:insertFirst(neighbor)
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s8c")
		end
		
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s9")
		UTIL.dumpTable("GOAP.BFSearch_9_neighbors.lua", neighbors)

		for v in neighbors:iterate() do
			if not marked:contains(v) then
				HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s48")
				marked:insertFirst(v)
				FIFO:insertLast(v)
				v.parent = FIFO:getFirst()
			end
		end
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s5")
		FIFO:removeFirst()
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, Planner.BFSearch s6")
	end
	return nil
end


-- ############### DSMC GOAP ACTIONS DB ###############

--------------------------------------------------------------------------------------
--occupyTerritory
--------------------------------------------------------------------------------------
occupyTerritory = Action:create() 

function occupyTerritory:Launch() -- this is a configuration function that 
	local p1 = {keyValue = "forceInArea", goalValue = true}
	local p2 = {keyValue = "enemyAbsent", goalValue = true}
	self:addPrecondition(p1)
	self:addPrecondition(p2)

	local e1 = {keyValue = "ownTerritory", currValue = true}
	self:addEffect(e1)
end

function occupyTerritory:contextCheck() -- add function
	return true
end

function occupyTerritory:Run() -- add function
	-- DSMC ADD THINGS (i.e. add to planTable)
	HOOK.writeDebugDetail(ModuleName .. ": action: Run launched with occupyTerritory")
end

function occupyTerritory:print()
	HOOK.writeDebugDetail(ModuleName .. ": action: occupyTerritory")
end



HOOK.writeDebugDetail(ModuleName .. ": occupyTerritory inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--attackTerritory
--------------------------------------------------------------------------------------

attackTerritory = Action:create() 

function attackTerritory:Launch()
	local p1 = {keyValue = "forceInArea", goalValue = true}
	local p2 = {keyValue = "positiveAttack", goalValue = true}
	self:addPrecondition(p1)
	self:addPrecondition(p2)

	local e1 = {keyValue = "ownTerritory", currValue = true}
	self:addEffect(e1)
end

function attackTerritory:contextCheck() -- add function
	return true
end

function attackTerritory:Run() -- add function
end

function attackTerritory:print()
	HOOK.writeDebugDetail(ModuleName .. ": action: attackTerritory")
end

HOOK.writeDebugDetail(ModuleName .. ": attackTerritory inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--relocateForces
--------------------------------------------------------------------------------------

relocateForces = Action:create() 

function relocateForces:Launch()
	local p1 = {keyValue = "availableForRelocate", goalValue = true}
	self:addPrecondition(p1)

	local e1 = {keyValue = "forceInArea", currValue = true}
	self:addEffect(e1)
end

function relocateForces:contextCheck() -- add function
	return true
end

function relocateForces:Run() -- add function
end

function relocateForces:print()
	HOOK.writeDebugDetail(ModuleName .. ": action: relocateForces")
end

HOOK.writeDebugDetail(ModuleName .. ": relocateForces inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--shellTerritory
--------------------------------------------------------------------------------------

shellTerritory = Action:create()

function shellTerritory:Launch()
	local p1 = {keyValue = "artyInArea", goalValue = true}
	local p2 = {keyValue = "enemyPresent", goalValue = true}
	self:addPrecondition(p1)
	self:addPrecondition(p2)

	local e1 = {keyValue = "enemyAbsent", currValue = true}
	self:addEffect(e1)
end

function shellTerritory:contextCheck() -- add function
	return true
end

function shellTerritory:Run() -- add function
end

function shellTerritory:print()
	HOOK.writeDebugDetail(ModuleName .. ": action: shellTerritory")
end

HOOK.writeDebugDetail(ModuleName .. ": shellTerritory inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--hasORBAT
--------------------------------------------------------------------------------------

hasORBAT = Action:create()

function hasORBAT:Launch()
	local e1 = {keyValue = "availableForRelocate", currValue = true}
	self:addEffect(e1)
end

function hasORBAT:contextCheck() -- add function
	return true
end

function hasORBAT:Run() -- add function
end

function hasORBAT:print()
	HOOK.writeDebugDetail(ModuleName .. ": action: hasORBAT")
end

HOOK.writeDebugDetail(ModuleName .. ": hasORBAT inserted")
--------------------------------------------------------------------------------------


-- ############### DSMC EVALUATION FUNCTIONS ###############

function getNearestMajorCities(coa)
	if tblTerrainDb then
		local allyT = {}
		local objT = {}
		for _, tData in pairs(tblTerrainDb.towns) do
			if tData.owner == coa and type(tData.pos) == "table" then
				allyT[#allyT+1] = tData
			elseif tData.owner ~= coa and tData.majorCity == true and type(tData.pos) == "table" then
				objT[#objT+1] = tData
			end
		end

		if #allyT == 0 then
			HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, no allied cities, campaign lost")
			return false
		end		


		if #objT > 0 then
			for _, oData in pairs(objT) do
				if oData.pos then
					
					local minDist = 1000000000
					for _, aData in pairs(allyT) do
						local dist = getDist(oData.pos, aData.pos)
						if dist then
							if dist < minDist then
								minDist = dist
							end
						end
					end

					if minDist < 1000000000 then
						oData.borderDistance = minDist
					end
				end
			end
			HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, step1")

			table.sort(objT, function(a,b)
				if a.borderDistance and b.borderDistance then
					return a.borderDistance < b.borderDistance 
				end
			end)
			HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, step2")

			for oId, oData in pairs(objT) do
				if oId > contemporaryObjectives then
					objT[oId] = nil
				end
			end
			HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, step3")


			if objT then
				HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, SUMMARY FOR COALITION: " .. tostring(coa))
				HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, nearest enemy major city to border are:")
				for _, nData in pairs(objT) do
					HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, town: " .. tostring(nData.display_name))
				end
				return objT

			else
				HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, no nearest found")
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, no objective, campaign win")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getNearestMajorCities, tblTerrainDb missing")
	end
end

function verifyOwnership(t, c)
	if t and c and type(c) == "number" then
		local terr = nil
		if type(t) == "string" then
			for _, tData in pairs(tblTerrainDb.towns) do
				if t == tData.display_name then
					terr = tData
				end
			end
		elseif type(t) == "table" then
			terr = t
		end

		if c == terr.owner then
			HOOK.writeDebugDetail(ModuleName .. ": verifyOwnership, return true")
			return true
		else
			HOOK.writeDebugDetail(ModuleName .. ": verifyOwnership, return false: c = " ..tostring(c) .. ", owner = " .. tostring(terr.owner))
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": verifyOwnership, missing variables or wrong c")
	end
end

function verifyAlliedEnemy(terrName, coaId)  
	HOOK.writeDebugDetail(ModuleName .. ": verifyAlliedEnemy, terrName = " .. tostring(terrName) .. ", coaId = " .. tostring(coaId))
	if coaId and type(coaId) == "number" and terrName and type(terrName) == "string" then
		if tblTerrainDb then
			for _, tData in pairs(tblTerrainDb.towns) do
				if string.lower(tData.display_name) == string.lower(terrName) then
					
					--local state = {}
					--state["owner"] = tData.owner
					--state["name"] = tData.display_name
					--state["conditions"] = {}
					--state["position"] = tData.pos

					--[[ owner
					if tData.owner == coaId then
						state["conditions"]["TerritoryOwned"] = true
						state["conditions"]["TerritoryNotOwned"] = false
						state["conditions"]["TerritoryContended"] = false
					elseif tData.owner == 9 then
						state["conditions"]["TerritoryOwned"] = false
						state["conditions"]["TerritoryNotOwned"] = true
						state["conditions"]["TerritoryContended"] = true
					else
						state["conditions"]["TerritoryOwned"] = false
						state["conditions"]["TerritoryNotOwned"] = true
						state["conditions"]["TerritoryContended"] = false
					end
					--]]--

					-- check allied
					local ally = {}
					local allyThere = false
					for _, aData in pairs(tblORBATDb) do
						if aData.coa == coaId then
							if aData.pos then
								local dist = getDist(tData.pos, aData.pos)
								if type(dist) == "number" then 
									dist = math.floor(dist)
								end
								
								if dist <= closeAttackRadius then
									aData["type"] = "closeAttack"
									aData["distance"] = dist
									ally[#ally+1] = aData
									allyThere = true
								end
							end
						end
					end

					-- check enemy if allied is there
					local enemyThere = false
					if #ally > 0 then
						for _, aData in pairs(tblORBATDb) do
							if aData.coa ~= coaId then
								if aData.pos then
									local dist = getDist(tData.pos, aData.pos)
									if dist <= closeAttackRadius then
										enemyThere = true
									end
								end
							end
						end
					end		

					-- check intel to add known enemies
					--local enemy = {}
					if enemyThere == false then
						for cId, cData in pairs(tblIntelDb) do
							if cId == coaId then
								for eId, eData in pairs(cData) do
									if eData.pos then
										local dist = getDist(tData.pos, eData.pos)
										if dist <= closeAttackRadius then
											enemyThere = true
										end
									end
								end
							end
						end
					end

					HOOK.writeDebugDetail(ModuleName .. ": verifyAlliedEnemy, allyThere = " .. tostring(allyThere) .. ", enemyThere = " .. tostring(enemyThere))
					return allyThere, enemyThere
					
				end
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": verifyAlliedEnemy, missing tblTerrainDb, return false")
			return nil
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": verifyAlliedEnemy, missing variables, return false")
		return nil
	end
end

-- ############### DSMC GOAP TEST & DEBUG ###############

--UTIL.dumpTable("GOAP.occupyTerritory.lua" , occupyTerritory)

function Gtest()

	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP, initializing WSM for = " .. tostring(cData.display_name) .. ", cId = " .. tostring(cId))
	local initWSM = WorldStateManager:create()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, WSM done")

	initWSM:addDescriptor({keyValue = "ownTerritory", currValue = false, goalValue = true})
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, added to WSM")

	UTIL.dumpTable("GOAP.initWSM.lua", initWSM)
	local P = Planner:create()
	HOOK.writeDebugDetail(ModuleName .. ": initGOAP, set Plan initialization")

	UTIL.dumpTable("GOAP.planner_P.lua", P)
	--cData.WSM = initWSM
	--HOOK.writeDebugDetail(ModuleName .. ": initGOAP cData done")

	local plan = P:BFSearch(initWSM)
	UTIL.dumpTable("GOAP.foundPlan.lua" , plan)


end


function initGOAP()  

	HOOK.writeDebugDetail(ModuleName .. ": initGOAP started")
	-- init objectives table
	GOAP.Objectives = {}
	GOAP.Objectives[1] = getNearestMajorCities(1)
	GOAP.Objectives[2] = getNearestMajorCities(2)

	-- add worldStatesManager and goal values!
	for oId, oData in pairs(GOAP.Objectives) do
		HOOK.writeDebugDetail(ModuleName .. ": initGOAP, initializing WSM for oId = " .. tostring(oId))
		for cId, cData in pairs(oData) do
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, initializing WSM for = " .. tostring(cData.display_name) .. ", cId = " .. tostring(cId))
			local initWSM = WorldStateManager:create()
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, WSM done")

			initWSM:addDescriptor({keyValue = "ownTerritory", currValue = false, goalValue = true})
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, added to WSM")

			UTIL.dumpTable("GOAP.initWSM.lua", initWSM)
			local P = Planner:create()
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP, set Plan initialization")

			cData.WSM = initWSM
			HOOK.writeDebugDetail(ModuleName .. ": initGOAP cData done")

			local plan = P:BFSearch(initWSM)
			UTIL.dumpTable("GOAP.foundPlan.lua" , plan)

		end
	end

	UTIL.dumpTable("GOAP.Objectives_step1.lua", GOAP.Objectives)


end
HOOK.writeDebugDetail(ModuleName .. ": initGOAP function inserted")

Gtest()












--------------------------------------------

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
GOAPloaded = true

--~=