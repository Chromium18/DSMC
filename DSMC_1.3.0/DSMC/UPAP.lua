-- Dynamic Sequential Mission Campaign -- WEATHER module

local ModuleName  	= "UPAP"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('UPAP', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

--## SOURCES
-- https://weatherspark.com/y/2228/Average-Weather-in-Las-Vegas-Nevada-United-States-Year-Round
-- https://yandex.com/weather/ras-al-khaimah/month/january?via=cnav


HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

--## VARS
UPAPloaded						= false
weatherExport 					= true


--## VARS
local monthsData = {
	[1] = 
	{
		["name"] = "JAN",
		["days"] = 31,
	},
	[2] = 
	{
		["name"] = "FEB",
		["days"] = 28,
	},	
	[3] = 
	{
		["name"] = "MAR",
		["days"] = 31,
	},	
	[4] = 
	{
		["name"] = "APR",
		["days"] = 30,
	},	
	[5] = 
	{
		["name"] = "MAY",
		["days"] = 31,
	},	
	[6] = 
	{
		["name"] = "JUN",
		["days"] = 30,
	},				
	[7] = 
	{
		["name"] = "JUL",
		["days"] = 31,
	},
	[8] = 
	{
		["name"] = "AUG",
		["days"] = 31,
	},
	[9] = 
	{
		["name"] = "SEP",
		["days"] = 30,
	},
	[10] = 
	{
		["name"] = "OCT",
		["days"] = 31,
	},
	[11] = 
	{
		["name"] = "NOV",
		["days"] = 30,
	},
	[12] = 
	{
		["name"] = "DEC",
		["days"] = 31,
	},
}


-- NOT SURE IF FUNCTION BELOW HAS EFFECT I NEW DCS WORLD!
function expWthToText(missionEnv)
	if weatherExport then
		HOOK.writeDebugDetail(ModuleName .. ": weatherExport on")
		
		local mTxt = "Nodate"
		for mId, mData in pairs(monthsData) do
			if mId == missionEnv.date.Month then
				mTxt = mData.name
			end		
		end

		local DTGformatD 	= string.format("%02d", missionEnv.date.Day)
		local DTGformatH 	= string.format("%02d", math.floor(missionEnv.start_time/3600))
		local DTGformatM 	= string.format("%02d", math.floor(missionEnv.start_time - math.floor(missionEnv.start_time/3600)*3600 )/60)
		local DTGformatY	= string.sub(missionEnv.date.Year, 3, 4)
		local DTGformatC 	= DTGformatD .. " " .. DTGformatH .. DTGformatM .. "J " .. mTxt .. " " .. DTGformatY

		local visby = nil
		if missionEnv.weather.enable_fog then
			visby = missionEnv.weather.fog.visibility
		else
			visby = missionEnv.weather.visibility.distance
		end

		local precipitation = nil
		if missionEnv.weather.clouds.iprecptns == 1 then
			precipitation = "RAIN"
		elseif missionEnv.weather.clouds.iprecptns == 2 then
			precipitation = "THUNDERSTORM"
		elseif missionEnv.weather.clouds.iprecptns == 3 then
			precipitation = "SNOW"
		elseif missionEnv.weather.clouds.iprecptns == 4 then
			precipitation = "SNOWSTORM"
		else
			precipitation = "-"
		end

		local freezeLevel = nil
		if WTHR.DewPointCalc then
			if WTHR.DewPointCalc > 0 then
				freezeLevel = math.floor(WTHR.DewPointCalc * 3.28084)
			else
				freezeLevel = "-"
			end
		else
			freezeLevel = "-"
		end

		local windDirection = nil
		if missionEnv.weather.wind.atGround.dir then
			windDirection = missionEnv.weather.wind.atGround.dir + 180

			if windDirection > 360 then
				windDirection = windDirection - 360
			end
		end	

		local windDirection2000 = nil
		local windSpeed2000 = nil
		if missionEnv.weather.wind.at2000.dir then
			windDirection2000 	= missionEnv.weather.wind.at2000.dir + 180
			windSpeed2000		= missionEnv.weather.wind.at2000.speed
			if windDirection2000 > 360 then
				windDirection2000 = windDirection2000 - 360
			end
		end	

		local windDirection8000 = nil
		local windSpeed8000 = nil
		if missionEnv.weather.wind.at8000.dir then
			windDirection8000 	= missionEnv.weather.wind.at8000.dir + 180
			windSpeed8000		= missionEnv.weather.wind.at8000.speed
			if windDirection8000 > 360 then
				windDirection8000 = windDirection8000 - 360
			end
		end	

		local pressure 		= tostring(missionEnv.weather.qnh)
		local pressureIn 	= tostring(math.floor(missionEnv.weather.qnh*0.03937*100)/100)

		local wthTable = missionEnv.weather
		local text = "W020 - WEATHER FORECAST - WXFCST\n"
		local text = text .. "DATE AND TIME " .. tostring(DTGformatC) .. "\n"
		local text = text .. "UNIT " .. "-" .. "\n"
		local text = text .. "LOCATION " .. "-" .. "\n"
		local text = text .. "VARIATION " .. "NOT RELEVANT" .. "\n"
		local text = text .. "VALID " .. tostring(DTGformatC) .. "\n"
		local text = text .. "UNTIL " .. "CURRENT + 6" .. "\n"

		local text = text .. "CEILING " .. tostring(math.floor(missionEnv.weather.clouds.base * 3.28084  )) .. " ft\n" --/ 100
		local text = text .. "COVER " .. tostring(missionEnv.weather.clouds.density)  .. "/10\n"
		local text = text .. "VISBY " .. tostring(visby) .. " m\n"
		local text = text .. "WEATHER " .. tostring(precipitation) .. "\n"
		local text = text .. "MAX " .. tostring(missionEnv.weather.season.temperature + 1) .. "°C\n"
		local text = text .. "MIN " .. tostring(missionEnv.weather.season.temperature - 1) .. "°C\n"
		local text = text .. "FREEZE LEVEL " .. tostring(freezeLevel) .. "FT\n"
		local text = text .. "WIND " .. tostring(windDirection) .. " °\n"
		
		local text = text .. "SPEED " .. tostring(math.floor(missionEnv.weather.wind.atGround.speed*1.94384)) .. " kn\n"
		local text = text .. "GUSTS " .. tostring(math.floor(missionEnv.weather.groundTurbulence*1.94384)) .. " kn\n"
		local text = text .. "ALTIMETER " .. pressure .. " mmHg; " .. pressureIn .. " inHg\n"
		local text = text .. "WIND @ 10000FT " .. tostring(windDirection2000) .. " ° @ " .. tostring(windSpeed2000) .. " kn\n"
		local text = text .. "WIND @ 20000FT " .. tostring(windDirection8000) .. " ° @ " .. tostring(windSpeed8000) .. " kn\n"
		local text = text .. "NARRATIVE " .. "-" .. "\n"
		local text = text .. "AUTHENTICATION " .. "-" .. "\n"

		HOOK.writeDebugDetail(ModuleName .. ": weather text \n " .. tostring(text))

		n = io.open(lfs.writedir() .. "DSMC/Reports/" .. "weather.txt", "w")		
		n:write(text)
		n:close()
	else
		HOOK.writeDebugDetail(ModuleName .. ": weatherExport off")
	end
end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
UPAPloaded = true
