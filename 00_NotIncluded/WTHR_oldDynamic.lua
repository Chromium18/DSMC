-- Dynamic Sequential Mission Campaign -- WEATHER module

local ModuleName  	= "WTHR"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0001"
local Date			= "09/03/2020"

--## LIBS
local base 			= _G
module('WTHR', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

--## VARS
local tempWeatherTable			= nil
local randomizeDynWeather		= false
local strWeather				= nil
temp_tblWeather					= nil
WTHRloaded						= false

-- ## TABLES
local tblWeatherDatabase = {
	["PersianGulf"] = {
		["MonthlyAverage"] = {		
			["tempmax"] =  {
				[1] = 25,
				[2] = 27,			
				[3] = 31,			
				[4] = 36,			
				[5] = 41,
				[6] = 44,
				[7] = 45,
				[8] = 45,
				[9] = 42,
				[10] = 37,
				[11] = 32,
				[12] = 27,				
			},
			["tempmin"] =  {
				[1] = 14,
				[2] = 14,			
				[3] = 17,			
				[4] = 20,			
				[5] = 22,
				[6] = 24,
				[7] = 26,
				[8] = 26,
				[9] = 24,
				[10] = 21,
				[11] = 18,
				[12] = 15,				
			},			
			["dust"] =  {
				[1] = 5,
				[2] = 5,			
				[3] = 5,			
				[4] = 5,			
				[5] = 5,
				[6] = 5,
				[7] = 5,
				[8] = 5,
				[9] = 5,
				[10] = 5,
				[11] = 5,
				[12] = 5,				
			},			
			["fog"] =  {
				[1] = 0,
				[2] = 0,			
				[3] = 0,			
				[4] = 0,			
				[5] = 0,
				[6] = 0,
				[7] = 0,
				[8] = 0,
				[9] = 0,
				[10] = 0,
				[11] = 0,
				[12] = 0,			
			},			
			["storm"] =  {
				[1] = 2,
				[2] = 2,			
				[3] = 3,			
				[4] = 1,			
				[5] = 0,
				[6] = 0,
				[7] = 0,
				[8] = 0,
				[9] = 0,
				[10] = 0,
				[11] = 0,
				[12] = 1,			
			},				
			["precipitation"] =  {
				[1] = 10,
				[2] = 11,			
				[3] = 12,			
				[4] = 7,			
				[5] = 1,
				[6] = 0,
				[7] = 0,
				[8] = 1,
				[9] = 0,
				[10] = 2,
				[11] = 3,
				[12] = 8,			
			},				
			["cloud"] =  {
				[1] = 35,
				[2] = 30,			
				[3] = 35,			
				[4] = 22,			
				[5] = 13,
				[6] = 13,
				[7] = 15,
				[8] = 12,
				[9] = 12,
				[10] = 15,
				[11] = 20,
				[12] = 31,			
			},				
		},
		["WeatherTable"] = {		
			["CAVOK"] = {
				[1] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 1121688,
							["centerZ"] = -67977,
							["ellipticity"] = 1.247,
							["rotation"] = 1.368,
							["pressure_excess"] = 1120,
							["centerX"] = 171442,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 950404,
							["centerZ"] = 1078674,
							["ellipticity"] = 1.247,
							["rotation"] = -1.3688559423717,
							["pressure_excess"] = -440,
							["centerX"] = -252523,
						}, -- end of [2]
					}, -- end of ["cyclones"]
					["name"] = "CAVOK_1",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]			
				},
				[2] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 1200387,
							["centerZ"] = -30621,
							["ellipticity"] = 1.08,
							["rotation"] = 0.172,
							["pressure_excess"] = 1132,
							["centerX"] = 231085,
						}, -- end of [1]
					}, -- end of ["cyclones"]
					["name"] = "CAVOK_2",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]			
				},
				[3] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 900000,
							["centerZ"] = -700000,
							["ellipticity"] = 1.4,
							["rotation"] = 3,
							["pressure_excess"] = 1300,
							["centerX"] = -250000,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 550000,
							["centerZ"] = 300000,
							["ellipticity"] = 1.4,
							["rotation"] = -3,
							["pressure_excess"] = 510,
							["centerX"] = -200000,
						}, -- end of [2]
					}, -- end of ["cyclones"]
					["name"] = "CAVOK_3",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]			
				},				
			},		
			["Cloudy"] = {
				[1] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 1121688,
							["centerZ"] = -67977,
							["ellipticity"] = 1.2476801867589,
							["rotation"] = 1.36,
							["pressure_excess"] = 1120,
							["centerX"] = 171442,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 950404,
							["centerZ"] = -1078674,
							["ellipticity"] = 1.2476801867589,
							["rotation"] = -1.36,
							["pressure_excess"] = -440,
							["centerX"] = 252523,
						}, -- end of [2]
					}, -- end of ["cyclones"]
					["name"] = "Cloudy_1",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]			
				},
				[2] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 900000,
							["centerZ"] = -700000,
							["ellipticity"] = 1.4,
							["rotation"] = 3,
							["pressure_excess"] = -800,
							["centerX"] = 250000,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 550000,
							["centerZ"] = 300000,
							["ellipticity"] = 1.4,
							["rotation"] = -3,
							["pressure_excess"] = -1200,
							["centerX"] = 200000,
						}, -- end of [2]
					}, -- end of ["cyclones"]
					["name"] = "Cloudy_2",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]			
				},				
			},	
			["Rainy"] = {
				[1] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 900000,
							["centerZ"] = -700000,
							["ellipticity"] = 1.4,
							["rotation"] = 3,
							["pressure_excess"] = -700,
							["centerX"] = 250000,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 250000,
							["centerZ"] = 15000,
							["ellipticity"] = 1.2,
							["rotation"] = -1,
							["pressure_excess"] = -1550,
							["centerX"] = -10000,
						}, -- end of [2]
						[3] = 
						{
							["pressure_spread"] = 550000,
							["centerZ"] = 300000,
							["ellipticity"] = 1.4,
							["rotation"] = -3,
							["pressure_excess"] = -210,
							["centerX"] = 200000,
						}, -- end of [3]					
					}, -- end of ["cyclones"]
					["name"] = "Rainy_1",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]				
				},
				[2] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 500000,
							["centerZ"] = -300000,
							["ellipticity"] = 1.3,
							["rotation"] = -1.1,
							["pressure_excess"] = -900,
							["centerX"] = 200000,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 150000,
							["centerZ"] = 15000,
							["ellipticity"] = 1.1,
							["rotation"] = 1.8,
							["pressure_excess"] = -550,
							["centerX"] = -10000,
						}, -- end of [2]
						[3] = 
						{
							["pressure_spread"] = 550000,
							["centerZ"] = 300000,
							["ellipticity"] = 1.4,
							["rotation"] = -1.4,
							["pressure_excess"] = -310,
							["centerX"] = 200000,
						}, -- end of [3]					
					}, -- end of ["cyclones"]
					["name"] = "Rainy_2",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]				
				},
				[3] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 500000,
							["centerZ"] = -300000,
							["ellipticity"] = 1.3,
							["rotation"] = -1.1,
							["pressure_excess"] = -900,
							["centerX"] = 200000,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 150000,
							["centerZ"] = 15000,
							["ellipticity"] = 1.1,
							["rotation"] = 1.8,
							["pressure_excess"] = -250,
							["centerX"] = -10000,
						}, -- end of [2]
						[3] = 
						{
							["pressure_spread"] = 550000,
							["centerZ"] = 300000,
							["ellipticity"] = 1.4,
							["rotation"] = -1.4,
							["pressure_excess"] = -410,
							["centerX"] = 200000,
						}, -- end of [3]					
					}, -- end of ["cyclones"]
					["name"] = "Rainy_3",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]				
				},				
			},			
			["Stormy"] = {
				[1] =     {
					["atmosphere_type"] = 1,
					["wind"] = 
					{
						["at8000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at8000"]
						["at2000"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["at2000"]
						["atGround"] = 
						{
							["speed"] = 0,
							["dir"] = 0,
						}, -- end of ["atGround"]
					}, -- end of ["wind"]
					["enable_fog"] = false,
					["dust_density"] = 0,
					["season"] = 
					{
						["temperature"] = 20,
					}, -- end of ["season"]
					["type_weather"] = 1,
					["qnh"] = 760,
					["cyclones"] = 
					{
						[1] = 
						{
							["pressure_spread"] = 180000,
							["centerZ"] = -60000,
							["ellipticity"] = 0.87,
							["rotation"] = 1.25,
							["pressure_excess"] = -1135,
							["centerX"] = 180000,
						}, -- end of [1]
						[2] = 
						{
							["pressure_spread"] = 1210000,
							["centerZ"] = -430000,
							["ellipticity"] = 0.87,
							["rotation"] = 1.2,
							["pressure_excess"] = 905,
							["centerX"] = 939062,
						}, -- end of [2]
						[3] = 
						{
							["pressure_spread"] = 1210000,
							["centerZ"] = 330000,
							["ellipticity"] = 0.87,
							["rotation"] = 1.26,
							["pressure_excess"] = 105,
							["centerX"] = -600000,
						}, -- end of [3]					
					}, -- end of ["cyclones"]
					["name"] = "Stormy_1",
					["fog"] = 
					{
						["thickness"] = 0,
						["visibility"] = 25,
					}, -- end of ["fog"]
					["visibility"] = 
					{
						["distance"] = 80000,
					}, -- end of ["visibility"]
					["groundTurbulence"] = 0,
					["enable_dust"] = false,
					["clouds"] = 
					{
						["density"] = 0,
						["thickness"] = 200,
						["base"] = 300,
						["iprecptns"] = 0,
					}, -- end of ["clouds"]				
				},		
			},
		},
	},	
}


-- ## ELAB FUNCTION
function elabWeather(temp_tblMission)	
	
	HOOK.writeDebugDetail(ModuleName .. ": starting")
	local newWeatherTable = nil
	tempWeatherTable = temp_tblMission.weather

	local mizTheater 	= temp_tblMission.theatre
	local mizMonth 		= temp_tblMission.date.Month
	local mizHour		= math.floor((temp_tblMission["start_time"]/3600))
	HOOK.writeDebugDetail(ModuleName .. ": mizTheater: " .. tostring(mizTheater) .. ", mizMonths: " .. tostring(mizMonth) .. ", mizHour " .. tostring(mizHour))

	if mizTheater and mizMonth and mizHour and tempWeatherTable then
		
		local thTable = nil
		for th, thData in pairs(tblWeatherDatabase) do
			if mizTheater == th then
				thTable = thData
			end
		end
		HOOK.writeDebugDetail(ModuleName .. ": thTable ok")

		if thTable then
			HOOK.writeDebugDetail(ModuleName .. ": thTable filter passed")
		
			local canSnow 		= false
			local climaType		= "none"
			
			local isPrec		= false
			local isStorm		= false
			local isCloud		= false
			local isClear		= false
			local isDust		= false
			local isFog			= false
			
			local new_tempmax 	= nil
			local new_tempmin 	= nil
			local new_temp		= nil
			local new_dust 		= nil
			local new_fog 		= nil
			local new_weather 	= nil

			local prob			= math.random(1,100)
			HOOK.writeDebugDetail(ModuleName .. ": prob: " .. tostring(prob))				
			
			for par, parData in pairs(thTable.MonthlyAverage) do
				if par == "tempmax" then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							new_tempmax = value
						end
					end					
				elseif par == "tempmin" then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							new_tempmin = value
						end
					end							
				elseif par == "dust" then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							if tonumber(prob) < tonumber(value) then
								isDust = true
							end								
						end
					end						
				elseif par == "fog" then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							if tonumber(prob) < tonumber(value) then
								isFog = true
							end								
						end
					end
				end
			end				
			
			local normHour = nil
			if mizHour < 13 then
				normHour = mizHour
			else
				normHour = 24 - mizHour
			end
			local incremental = (new_tempmax-new_tempmin)/11
			
			
			new_temp = math.floor((new_tempmin+incremental*(normHour-1))*10)/10

			if new_temp < 5 then
				canSnow = true
			end

			--check weather
			for par, parData in pairs(thTable.MonthlyAverage) do
				if par == "storm" then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							if tonumber(prob) < tonumber(value) then
								isStorm = true
							end
						end
					end								
				elseif par == "precipitation" and isStorm == false then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							if tonumber(prob) < tonumber(value) then
								isPrec = true
							end
						end
					end					
				elseif par == "cloud" and isStorm == false and isPrec == false then
					for num, value in pairs(parData) do
						if tonumber(num) == tonumber(mizMonth) then
							if tonumber(prob) < tonumber(value) then
								isCloud = true
							end
						end
					end								
				elseif isStorm == false and isPrec == false and isCloud == false then
					isClear = true
				end
			end
			HOOK.writeDebugDetail(ModuleName .. ": variables:\n" 
										.. ModuleName .. ": isFog: " .. tostring(isFog) .. "\n"
										.. ModuleName .. ": isDust: " .. tostring(isDust) .. "\n"
										.. ModuleName .. ": incremental: " .. tostring(incremental) .. "\n"
										.. ModuleName .. ": new_tempmax: " .. tostring(new_tempmax) .. "\n"
										.. ModuleName .. ": new_tempmin: " .. tostring(new_tempmin) .. "\n"					
										.. ModuleName .. ": new_temp: " .. tostring(new_temp) .. "\n"
										.. ModuleName .. ": canSnow: " .. tostring(canSnow) .. "\n"					
										.. ModuleName .. ": isStorm: " .. tostring(isStorm) .. "\n"
										.. ModuleName .. ": isPrec: " .. tostring(isPrec) .. "\n"
										.. ModuleName .. ": isCloud: " .. tostring(isCloud) .. "\n"
										.. ModuleName .. ": isClear: " .. tostring(isClear))
	
			-- choose table
			if isClear == true or isCloud == true or isPrec == true or isStorm == true then
				
				if isStorm == true and canSnow == false then
					for wType, wData in pairs(thTable.WeatherTable) do
						if wType == "Stormy" then
							local num = table.getn(wData)
							local choose = 1
							if num and num > 1 then
								choose = math.random(1,num)
							end
							
							for n, nTable in pairs(wData) do
								if n == choose then
									tempWeatherTable = nTable
									HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable num: " .. tostring(choose))										
								end
							end
						end
					end
				elseif isStorm == true and canSnow == true then
					for wType, wData in pairs(thTable.WeatherTable) do
						if wType == "SnowStormy" then
							local num = table.getn(wData)
							local choose = 1
							if num and num > 1 then
								choose = math.random(1,num)
							end
							
							for n, nTable in pairs(wData) do
								if n == choose then
									tempWeatherTable = nTable
									HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable num: " .. tostring(choose))										
								end
							end
						end
					end						
				elseif isPrec == true and canSnow == false then
					for wType, wData in pairs(thTable.WeatherTable) do
						if wType == "Rainy" then
							local num = table.getn(wData)
							local choose = 1
							if num and num > 1 then
								choose = math.random(1,num)
							end
							
							for n, nTable in pairs(wData) do
								if n == choose then
									tempWeatherTable = nTable
									HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable num: " .. tostring(choose))										
								end
							end
						end
					end
				elseif isPrec == true and canSnow == true then
					for wType, wData in pairs(thTable.WeatherTable) do
						if wType == "Snowy" then
							local num = table.getn(wData)
							local choose = 1
							if num and num > 1 then
								choose = math.random(1,num)
							end
							
							for n, nTable in pairs(wData) do
								if n == choose then
									tempWeatherTable = nTable
									HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable num: " .. tostring(choose))										
								end
							end
						end
					end						
				elseif isCloud == true then
					for wType, wData in pairs(thTable.WeatherTable) do
						if wType == "Cloudy" then
							local num = table.getn(wData)
							local choose = 1
							if num and num > 1 then
								choose = math.random(1,num)
							end
							
							for n, nTable in pairs(wData) do
								if n == choose then
									tempWeatherTable = nTable
									HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable num: " .. tostring(choose))										
								end
							end
						end
					end
				elseif isClear == true then
					for wType, wData in pairs(thTable.WeatherTable) do
						if wType == "CAVOK" then
							local num = table.getn(wData)
							local choose = 1
							if num and num > 1 then
								choose = math.random(1,num)
							end
							
							for n, nTable in pairs(wData) do
								if n == choose then
									tempWeatherTable = nTable
									HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable num: " .. tostring(choose))										
								end
							end
						end
					end						
				end
			else	
				HOOK.writeDebugDetail(ModuleName .. ": filter isClear,isRain,isStormy not there")
			end
			
			if tempWeatherTable then
				HOOK.writeDebugDetail(ModuleName .. ": tempWeatherTable is there")

				tempWeatherTable.atmosphere_type = 1
				
				if tempWeatherTable.season then
					tempWeatherTable.season.temperature = new_temp
				end
			
				if isDust == true then
					tempWeatherTable.enable_dust = true
					tempWeatherTable.dust_density = math.random(500, 2500)
				end						
							
				if isFog == true then
					tempWeatherTable.enable_fog = true
					tempWeatherTable.fog.thickness = math.random(250, 800)
					tempWeatherTable.fog.visibility = math.random(500, 5500)
				end
				
				if randomizeDynWeather == true then
					if tempWeatherTable.cyclones then
						for c, cData in pairs(tempWeatherTable.cyclones) do
							cData.centerZ = cData.centerZ*(1+(math.random()*cData.centerZ)/10) 
							cData.centerX = cData.centerX*(1+(math.random()*cData.centerX)/10) 
							cData.pressure_spread = cData.pressure_spread*(1+(math.random()*cData.pressure_spread)/10)
							cData.pressure_excess = cData.pressure_excess*(1+(math.random()*cData.pressure_excess)/10)
						end
					end
				end
				
				newWeatherTable = tempWeatherTable
				HOOK.writeDebugDetail(ModuleName .. ": newWeatherTable done")						
				tempWeatherTable = nil
			end
		end
	end		
	
	if newWeatherTable then
		tblWeather = newWeatherTable
		newWeatherTable = nil		
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather ok")		
	end
end
HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
WTHRloaded = true