-- Dynamic Sequential Mission Campaign -- CREATE STATIC module

local ModuleName  	= "CRST"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('CRST', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
CRSTloaded						= false

-- ## MANUAL TABLES


-- ## ELAB FUNCTION
function doStatics(missionEnv, tblDeaths)
	if HOOK.debugProcessDetail then
		UTIL.dumpTable("tblDeaths.lua", tblDeaths)
	end
	local addedDeathsDone = 0
	local addedDeathsPreview = 0 
	for id, deadData in pairs (tblDeaths) do
		if deadData.objCategory ~= 3 and deadData.objCategory ~= 6 and deadData.unitShip ~= true and deadData.unitInfantry ~= true and deadData.staticTable then -- not cargos
			if deadData.objTypeName 	~= "Soldier M4" -- not infantry
			and deadData.objTypeName 	~= "Soldier M249"
			and deadData.objTypeName 	~= "Stinger manpad GRG"
			and deadData.objTypeName 	~= "Stinger comm"
			and deadData.objTypeName 	~= "2B11 mortar"
			and deadData.objTypeName 	~= "Infantry AK"
			and deadData.objTypeName 	~= "Paratrooper AKS-74"
			and deadData.objTypeName 	~= "Paratrooper RPG-16"
			and deadData.objTypeName 	~= "SA-18 Igla-S manpad"
			and deadData.objTypeName 	~= "SA-18 Igla-S comm"
			and deadData.staticTable	~= "none"
			then
			
				addedDeathsPreview = addedDeathsPreview + 1
				
				if tonumber(deadData.coalitionID) == 0 then
					correctCoalition = "neutral"
				elseif tonumber(deadData.coalitionID) == 1 then
					correctCoalition = "red"				
				elseif tonumber(deadData.coalitionID) == 2 then
					correctCoalition = "blue"				
				end			

				for ctryID, ctryData in pairs (missionEnv.coalition[correctCoalition]["country"]) do
					if tonumber(deadData.countryID) == tonumber(ctryData.id) then
						correctCountry = ctryID
					end
				end			
				
				-- check static existence
				if not missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"] then
					missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"] = {}				
				end						

				-- check group existence in static
				if not missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"]["group"] then
					missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"]["group"] = {}						
				end				
				
				local groupTable = missionEnv.coalition[correctCoalition]["country"][correctCountry]["static"]["group"]
				
				if	groupTable and correctCoalition and correctCountry then
					groupTable[#groupTable + 1] = deadData.staticTable
					addedDeathsDone = addedDeathsDone +1
				else
					return false
				end
			end
		end
	end
	if table.getn(tblDeaths) > 0 and addedDeathsDone == addedDeathsPreview then
		HOOK.writeDebugDetail(ModuleName .. ": doStatics ok")
	elseif addedDeathsDone ~= addedDeathsPreview then
		HOOK.writeDebugDetail(ModuleName .. ":doStatics, errors: addedDeathsDone = " .. tostring(addedDeathsDone) .. ", addedDeathsPreview = " .. tostring(addedDeathsPreview))
	end		
end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
CRSTloaded = true
