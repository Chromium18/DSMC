-- Dynamic Sequential Mission Campaign -- START TIME UPDATE module

local ModuleName  	= "TMUP"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('TMUP', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
TMUPloaded						= false
local minHourTime				= DSMC_StarTimeHourMin or 4   -- this is the minimum clock hour that could be set for mission start
local maxHourTime				= DSMC_StarTimeHourMax or 16  -- this is the maximum clock hour that could be set for mission start

-- ## MANUAL TABLES



-- ## CHECK FUNCTION
if minHourTime < 1 or minHourTime > 14 then
	minHourTime = 4
end
if maxHourTime < 15 or maxHourTime > 23 then
	maxHourTime = 16
end

-- ## ELAB FUNCTION
function updateStTime(missionEnv)

	local CURstartDateDay			= missionEnv["date"]["Day"]
	local CURstartDateYear			= missionEnv["date"]["Year"]
	local CURstartDateMonth			= missionEnv["date"]["Month"]	
	local CURstartTime				= missionEnv["start_time"]
	local CURhours					= math.floor((missionEnv["start_time"]/3600))
	local CURmin					= math.floor(((missionEnv["start_time"] - (3600*CURhours)))/60)
	local CURsec					= 0 
	local CURday					= os.time{year=CURstartDateYear, month=CURstartDateMonth, day=CURstartDateDay, hour=0}
	local CURtime					= CURday + missionEnv["start_time"]
	HOOK.writeDebugDetail(ModuleName .. ": CURtime = " ..tostring(CURtime))
	HOOK.writeDebugDetail(ModuleName .. ": DCS.getRealTime() = " ..tostring(DCS.getRealTime()))
	HOOK.writeDebugDetail(ModuleName .. ": DCS.getModelTime() = " ..tostring(DCS.getModelTime()))
	

	if HOOK.TMUP_cont_var == 1 then

		HOOK.writeDebugDetail(ModuleName .. ": HOOK.TMUP_cont_var 1")
		local NEWtime 				= CURtime + DCS.getModelTime() -- CURtime --((math.floor((timer.getTime()/60))+1)*60)			
		--local NEWtimeTable			= os.date("*t", NEWtime)			
		NEWstartDateYear			= tonumber(os.date("%Y", NEWtime))
		NEWstartDateMonth			= tonumber(os.date("%m", NEWtime))
		NEWstartDateDay				= tonumber(os.date("%d", NEWtime))
		--local zeroTime				= tonumber(os.time{year=1970, month=1, day=1, hour=0, sec=1})
		local NEWstartTimeZero		= tonumber(os.time{year=NEWstartDateYear, month=NEWstartDateMonth, day=NEWstartDateDay, hour=0}) -- + zeroTime		
		NEWstartTime				= NEWtime - NEWstartTimeZero
	
	elseif HOOK.TMUP_cont_var == 2 then
	
		HOOK.writeDebugDetail(ModuleName .. ": HOOK.TMUP_cont_var 2")

		math.randomseed(os.time())
		math.random(); math.random(); math.random()
		local RandomHour = math.random(minHourTime, maxHourTime)
		
		--[[ old code
		local RandomHour			= math.random(0, 23) -- math.floor(8 + RandomSeed*13)
		if RandomHour > maxHourDay and RandomHour < minHournight then
			local delta = RandomHour - maxHourDay
			if delta < 4 then
				RandomHour = math.random(minHournight, 23)
			else
				RandomHour = math.random(14, maxHourDay)
			end
		end
		--]]--
	
		local RandomTime			= RandomHour*60*60
		local NEWtime 				= CURday + 24*60*60 -- + RandomTime
		local NEWtimeTable			= os.date("*t", NEWtime)			
		NEWstartDateYear			= tonumber(os.date("%Y", NEWtime))
		NEWstartDateMonth			= tonumber(os.date("%m", NEWtime))
		NEWstartDateDay				= tonumber(os.date("%d", NEWtime))
		NEWstartTime				= RandomTime		

	else
		
		HOOK.writeDebugDetail(ModuleName .. ": HOOK.TMUP_cont_var 3")
		
		NEWstartDateYear			= tonumber(os.date("%Y"))
		NEWstartDateMonth			= tonumber(os.date("%m"))
		NEWstartDateDay				= tonumber(os.date("%d"))
		NEWstartTime				= CURstartTime
	
	end

	missionEnv.start_time 			= NEWstartTime
	missionEnv["date"]["Day"] 		= NEWstartDateDay
	missionEnv["date"]["Year"] 		= NEWstartDateYear
	missionEnv["date"]["Month"] 	= NEWstartDateMonth	
		
	HOOK.writeDebugDetail(ModuleName .. ": updateStTime ok")
end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
TMUPloaded = true
