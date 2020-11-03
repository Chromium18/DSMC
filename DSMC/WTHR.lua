-- Dynamic Sequential Mission Campaign -- WEATHER module

local ModuleName  	= "WTHR"
local MainVersion 	= "1"
local SubVersion 	= "0"
local Build 		= "0100"
local Date			= "17/10/2020"

--## LIBS
local base 			= _G
module('WTHR', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')

--## SOURCES
-- https://weatherspark.com/y/2228/Average-Weather-in-Las-Vegas-Nevada-United-States-Year-Round
-- https://yandex.com/weather/ras-al-khaimah/month/january?via=cnav


HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

--## VARS
WTHRloaded						= false
DewPointCalc					= nil
local rndFactorPerc				= 15 --% of randomization on calculated values
local cloudFog					= false


--# RND SEED
math.randomseed(os.time())

--# TABLES
meanMapBaseHeight = 
{
	["Caucasus"] = 
	{
		["Tbase"] = 100, 
	},
	["PersianGulf"] = 
	{
		["Tbase"] = 100, 
	},
	["Nevada"] = 
	{
		["Tbase"] = 1000, 
	},
	["Syria"] = 
	{
		["Tbase"] = 500, 
	},			
}

staticWeatherDb =  -- theatre, date.Month, probability data
{
	["Syria"] = -- Damascus
	{
		[1] = 
		{
			["Tmax"] = 13.4, 
			["Tmin"] = -2,
			["CL4_6"] = 0.40,
			["CL7_8"] = 0.65,
			["CL9_10"] = 0.80,
			["Rain"] = 0.55,
			["Storm"] = 0.995,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 4, 
			["Pmax"] = 805, 
			["Pmin"] = 765,
			["Umed"] = 80,
			["Umin"] = 65,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,				
		},
		[2] = 
		{
			["Tmax"] = 16.2,  
			["Tmin"] = -1.5,
			["CL4_6"] = 0.45, 
			["CL7_8"] = 0.67,
			["CL9_10"] = 0.75,
			["Rain"] = 0.6,
			["Storm"] = 0.995,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 4, 
			["Pmax"] = 806.8, 
			["Pmin"] = 747.8,
			["Umed"] = 70,
			["Umin"] = 50,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},	
		[3] = 
		{
			["Tmax"] = 21, 
			["Tmin"] = 6,
			["CL4_6"] = 0.45, 
			["CL7_8"] = 0.70,
			["CL9_10"] = 0.78,
			["Rain"] = 0.65,
			["Storm"] = 0.985,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 5, 
			["Pmax"] = 824.8, 
			["Pmin"] = 746.2,
			["Umed"] = 65,
			["Umin"] = 50,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,			
		},		
		[4] = 
		{
			["Tmax"] = 26, 
			["Tmin"] = 9,
			["CL4_6"] = 0.60, 
			["CL7_8"] = 0.70,
			["CL9_10"] = 0.85,
			["Rain"] = 0.75,
			["Storm"] = 0.98,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 5, 
			["Pmax"] = 777.4, 
			["Pmin"] = 697.4,
			["Umed"] = 55,
			["Umin"] = 40,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},			
		[5] = 
		{
			["Tmax"] = 31, 
			["Tmin"] = 13,
			["CL4_6"] = 0.65, 
			["CL7_8"] = 0.81,
			["CL9_10"] = 0.84,
			["Rain"] = 0.85,
			["Storm"] = 0.96,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 5, 
			["Pmax"] = 824.0, 
			["Pmin"] = 749.7,
			["Umed"] = 35,
			["Umin"] = 20,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},		
		[6] = 
		{
			["Tmax"] = 35, 
			["Tmin"] = 17,
			["CL4_6"] = 0.84, 
			["CL7_8"] = 0.86,
			["CL9_10"] = 0.88,
			["Rain"] = 0.92,
			["Storm"] = 0.95,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 6, 
			["Pmax"] = 824.0, 
			["Pmin"] = 749.7,
			["Umed"] = 45,
			["Umin"] = 20,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,		
			["windVar"] = 0.15,	
		},	
		[7] = 
		{
			["Tmax"] = 38, 
			["Tmin"] = 19,
			["CL4_6"] = 0.93, 
			["CL7_8"] = 0.94,
			["CL9_10"] = 0.95,
			["Rain"] = 0.96,
			["Storm"] = 0.97,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 6, 
			["Pmax"] = 824.0, 
			["Pmin"] = 749.7,
			["Umed"] = 42,
			["Umin"] = 30,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,			
			["windVar"] = 0.15,
		},	
		[8] = 
		{
			["Tmax"] = 38, 
			["Tmin"] = 20,
			["CL4_6"] = 0.865, 
			["CL7_8"] = 0.87,
			["CL9_10"] = 0.875,
			["Rain"] = 0.88,
			["Storm"] = 0.91,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 5, 
			["Pmax"] = 763.8, 
			["Pmin"] = 751.3,
			["Umed"] = 48,
			["Umin"] = 30,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},	
		[9] = 
		{
			["Tmax"] = 35, 
			["Tmin"] = 17,
			["CL4_6"] = 0.70, 
			["CL7_8"] = 0.80,
			["CL9_10"] = 0.82,
			["Rain"] = 0.84,
			["Storm"] = 0.96,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 5, 
			["Pmax"] = 770.2, 
			["Pmin"] = 763.8,
			["Umed"] = 50,
			["Umin"] = 30,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},	
		[10] = 
		{
			["Tmax"] = 28, 
			["Tmin"] = 12,
			["CL4_6"] = 0.60, 
			["CL7_8"] = 0.68,
			["CL9_10"] = 0.77,
			["Rain"] = 0.65,
			["Storm"] = 0.98,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 2.5, 
			["Pmax"] = 773.5, 
			["Pmin"] = 742.4,
			["Umed"] = 65,
			["Umin"] = 30,
			["fogAllowed"] = false,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},
		[11] = 
		{
			["Tmax"] = 21, 
			["Tmin"] = 6,
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.65,
			["CL9_10"] = 0.72,
			["Rain"] = 0.78,
			["Storm"] = 0.995,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 1.7, 
			["Pmax"] = 776.8, 
			["Pmin"] = 749.1,
			["Umed"] = 60,
			["Umin"] = 40,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,			
		},
		[12] = 
		{
			["Tmax"] = 15, 
			["Tmin"] = 2,
			["CL4_6"] = 0.35, 
			["CL7_8"] = 0.50,
			["CL9_10"] = 0.68,
			["Rain"] = 0.72,
			["Storm"] = 0.995,
			["WD_day"] = 225, 
			["WD_night"] = 45,
			["WD_speed"] = 2, 
			["Pmax"] = 824.8, 
			["Pmin"] = 746.1,
			["Umed"] = 80,
			["Umin"] = 60,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,			
		},

	},	
	["Caucasus"] = -- Kutaisi
	{
		[1] = 
		{
			["Tmax"] = 12.8, 
			["Tmin"] = -7.8,
			["CL4_6"] = 0.40,
			["CL7_8"] = 0.55,
			["CL9_10"] = 0.70,
			["Rain"] = 0.88,
			["Storm"] = 0.96,
			["WD_day"] = 90, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["WD_night"] = 270,
			["WD_speed"] = 8, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 805, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 765,
			["Umed"] = 69,
			["Umin"] = 20,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,				
		},
		[2] = 
		{
			["Tmax"] = 13.2,  -- https://rp5.ru/Weather_archive_in_Kutaisi X 2
			["Tmin"] = -4.8,
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.50,
			["CL9_10"] = 0.63,
			["Rain"] = 0.89,
			["Storm"] = 0.96,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 4, 
			["Pmax"] = 806.8, 
			["Pmin"] = 747.8,
			["Umed"] = 67,
			["Umin"] = 21,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},	
		[3] = 
		{
			["Tmax"] = 17.5, 
			["Tmin"] = -2,
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.50,
			["CL9_10"] = 0.63,
			["Rain"] = 0.87,
			["Storm"] = 0.96,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 7, 
			["Pmax"] = 824.8, 
			["Pmin"] = 746.2,
			["Umed"] = 69,
			["Umin"] = 12,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,			
		},		
		[4] = 
		{
			["Tmax"] = 18.8, 
			["Tmin"] = 8.5,
			["CL4_6"] = 0.35, 
			["CL7_8"] = 0.47,
			["CL9_10"] = 0.61,
			["Rain"] = 0.80,
			["Storm"] = 0.95,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 5.5, 
			["Pmax"] = 777.4, 
			["Pmin"] = 697.4,
			["Umed"] = 69,
			["Umin"] = 22,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},			
		[5] = 
		{
			["Tmax"] = 21.5, 
			["Tmin"] = 11.6,
			["CL4_6"] = 0.42, 
			["CL7_8"] = 0.57,
			["CL9_10"] = 0.66,
			["Rain"] = 0.74,
			["Storm"] = 0.95,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 7, 
			["Pmax"] = 824.0, 
			["Pmin"] = 749.7,
			["Umed"] = 71,
			["Umin"] = 26,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},		
		[6] = 
		{
			["Tmax"] = 29.0, 
			["Tmin"] = 18.4,
			["CL4_6"] = 0.50, 
			["CL7_8"] = 0.75,
			["CL9_10"] = 0.79,
			["Rain"] = 0.83,
			["Storm"] = 0.93,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 4, 
			["Pmax"] = 824.0, 
			["Pmin"] = 749.7,
			["Umed"] = 72,
			["Umin"] = 12,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,		
			["windVar"] = 0.15,	
		},	
		[7] = 
		{
			["Tmax"] = 33.0, 
			["Tmin"] = 23.0,
			["CL4_6"] = 0.65, 
			["CL7_8"] = 0.90,
			["CL9_10"] = 0.905,
			["Rain"] = 0.91,
			["Storm"] = 0.93,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 3, 
			["Pmax"] = 824.0, 
			["Pmin"] = 749.7,
			["Umed"] = 72,
			["Umin"] = 12,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,			
			["windVar"] = 0.15,
		},	
		[8] = 
		{
			["Tmax"] = 30.0, 
			["Tmin"] = 19.0,
			["CL4_6"] = 0.65, 
			["CL7_8"] = 0.90,
			["CL9_10"] = 0.905,
			["Rain"] = 0.91,
			["Storm"] = 0.93,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 5, 
			["Pmax"] = 763.8, 
			["Pmin"] = 751.3,
			["Umed"] = 76,
			["Umin"] = 29,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},	
		[9] = 
		{
			["Tmax"] = 29.0, 
			["Tmin"] = 15.0,
			["CL4_6"] = 0.45, 
			["CL7_8"] = 0.72,
			["CL9_10"] = 0.83,
			["Rain"] = 0.84,
			["Storm"] = 0.94,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 8, 
			["Pmax"] = 770.2, 
			["Pmin"] = 763.8,
			["Umed"] = 69,
			["Umin"] = 25,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},	
		[10] = 
		{
			["Tmax"] = 24.0, 
			["Tmin"] = 10.0,
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.51,
			["CL9_10"] = 0.70,
			["Rain"] = 0.73,
			["Storm"] = 0.95,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 7, 
			["Pmax"] = 773.5, 
			["Pmin"] = 742.4,
			["Umed"] = 71,
			["Umin"] = 29,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,	
			["windVar"] = 0.15,		
		},
		[11] = 
		{
			["Tmax"] = 18.3, 
			["Tmin"] = 2.8,
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.51,
			["CL9_10"] = 0.70,
			["Rain"] = 0.73,
			["Storm"] = 0.95,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 13, 
			["Pmax"] = 776.8, 
			["Pmin"] = 749.1,
			["Umed"] = 71,
			["Umin"] = 29,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,			
		},
		[12] = 
		{
			["Tmax"] = 10.0, 
			["Tmin"] = -3.8,
			["CL4_6"] = 0.28, 
			["CL7_8"] = 0.40,
			["CL9_10"] = 0.60,
			["Rain"] = 0.69,
			["Storm"] = 0.95,
			["WD_day"] = 90,
			["WD_night"] = 270,
			["WD_speed"] = 12, 
			["Pmax"] = 824.8, 
			["Pmin"] = 746.1,
			["Umed"] = 67,
			["Umin"] = 20,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,			
		},

	},
	["PersianGulf"] = 
	{
		[1] = 
		{
			["Tmax"] = 24.8, 
			["Tmin"] = 11.8,
			["CL4_6"] = 0.70,
			["CL7_8"] = 0.78,
			["CL9_10"] = 0.83,
			["Rain"] = 0.91,
			["Storm"] = 0.97,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.5, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 764, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 740,
			["Umed"] = 61,
			["Umin"] = 11,
			["fogAllowed"] = true,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},	
		[2] = 
		{
			["Tmax"] = 25.9, 
			["Tmin"] = 12.9,
			["CL4_6"] = 0.72,
			["CL7_8"] = 0.79,
			["CL9_10"] = 0.85,
			["Rain"] = 0.93,
			["Storm"] = 0.98,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.2, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 745, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 738,
			["Umed"] = 55,
			["Umin"] = 22,
			["fogAllowed"] = true,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},		
		[3] = 
		{
			["Tmax"] = 29.5, 
			["Tmin"] = 15.5,
			["CL4_6"] = 0.68,
			["CL7_8"] = 0.72,
			["CL9_10"] = 0.79,
			["Rain"] = 0.93,
			["Storm"] = 0.98,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.2, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 745, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 738,
			["Umed"] = 48,
			["Umin"] = 17,
			["fogAllowed"] = true,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},			
		[4] = 
		{
			["Tmax"] = 35.2, 
			["Tmin"] = 18.9,
			["CL4_6"] = 0.68,
			["CL7_8"] = 0.73,
			["CL9_10"] = 0.80,
			["Rain"] = 0.95,
			["Storm"] = 0.99,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 7, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 740, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 733,
			["Umed"] = 44,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},			
		[5] = 
		{
			["Tmax"] = 39.3, 
			["Tmin"] = 22.6,
			["CL4_6"] = 0.80,
			["CL7_8"] = 0.86,
			["CL9_10"] = 0.92,
			["Rain"] = 0.99,
			["Storm"] = 0.999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 8.5, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 740, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 733,
			["Umed"] = 34,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},
		[6] = 
		{
			["Tmax"] = 42.1, 
			["Tmin"] = 25.6,
			["CL4_6"] = 0.70,
			["CL7_8"] = 0.84,
			["CL9_10"] = 0.88,
			["Rain"] = 0.99,
			["Storm"] = 0.999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.5, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 733, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 729,
			["Umed"] = 41,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},		
		[7] = 
		{
			["Tmax"] = 42.7, 
			["Tmin"] = 28.5,
			["CL4_6"] = 0.73,
			["CL7_8"] = 0.81,
			["CL9_10"] = 0.85,
			["Rain"] = 0.9999,
			["Storm"] = 0.99999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.5, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 729, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 727,
			["Umed"] = 48,
			["Umin"] = 21,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},			
		[8] = 
		{
			["Tmax"] = 41.9, 
			["Tmin"] = 28.6,
			["CL4_6"] = 0.73,
			["CL7_8"] = 0.81,
			["CL9_10"] = 0.85,
			["Rain"] = 0.9999,
			["Storm"] = 0.99999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.5, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 733, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 731,
			["Umed"] = 53,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},	
		[9] = 
		{
			["Tmax"] = 40.1, 
			["Tmin"] = 24.7,
			["CL4_6"] = 0.68,
			["CL7_8"] = 0.82,
			["CL9_10"] = 0.90,
			["Rain"] = 0.9999,
			["Storm"] = 0.99999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.5, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 734, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 731,
			["Umed"] = 52,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},	
		[10] = 
		{
			["Tmax"] = 36.7, 
			["Tmin"] = 20.7,
			["CL4_6"] = 0.85,
			["CL7_8"] = 0.92,
			["CL9_10"] = 0.96,
			["Rain"] = 0.9999,
			["Storm"] = 0.99999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 5.1, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 734, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 731,
			["Umed"] = 52,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},	
		[11] = 
		{
			["Tmax"] = 31.4, 
			["Tmin"] = 16.6,
			["CL4_6"] = 0.77,
			["CL7_8"] = 0.82,
			["CL9_10"] = 0.88,
			["Rain"] = 0.98,
			["Storm"] = 0.999,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 7.1, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 734, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 731,
			["Umed"] = 56,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},	
		[12] = 
		{
			["Tmax"] = 26.8, 
			["Tmin"] = 13.5,
			["CL4_6"] = 0.71,
			["CL7_8"] = 0.78,
			["CL9_10"] = 0.83,
			["Rain"] = 0.93,
			["Storm"] = 0.98,
			["WD_day"] = 270, 
			["WD_night"] = 90,
			["WD_speed"] = 7.1, -- https://rp5.ru/Weather_archive_in_Kutaisi -> 2/3
			["Pmax"] = 743, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 739,
			["Umed"] = 59,
			["Umin"] = 17,
			["fogAllowed"] = false,
			["sandAllowed"] = true,
			["windVar"] = 0.5,
		},	
	},	
	["Nevada"] = 
	{
		[1] = 
		{
			["Tmax"] = 15, 
			["Tmin"] = 3,
			["CL4_6"] = 0.55,
			["CL7_8"] = 0.63,
			["CL9_10"] = 0.71,
			["Rain"] = 0.92,
			["Storm"] = 0.97,
			["WD_day"] = 0,
			["WD_night"] = 215,
			["WD_speed"] = 4.5,
			["Pmax"] = 674,
			["Pmin"] = 672,
			["Umed"] = 54,
			["Umin"] = 41,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,				
		},	
		[2] = 
		{
			["Tmax"] = 18.8, 
			["Tmin"] = 5.6,
			["CL4_6"] = 0.52,
			["CL7_8"] = 0.60,
			["CL9_10"] = 0.70,
			["Rain"] = 0.87,
			["Storm"] = 0.96,
			["WD_day"] = 30,
			["WD_night"] = 225,
			["WD_speed"] = 7.2,
			["Pmax"] = 672,
			["Pmin"] = 668,
			["Umed"] = 56,
			["Umin"] = 38,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.35,				
		},		
		[3] = 
		{
			["Tmax"] = 22.2, 
			["Tmin"] = 10,
			["CL4_6"] = 0.59,
			["CL7_8"] = 0.65,
			["CL9_10"] = 0.73,
			["Rain"] = 0.92,
			["Storm"] = 0.98,
			["WD_day"] = 30,
			["WD_night"] = 225,
			["WD_speed"] = 8.6,
			["Pmax"] = 672,
			["Pmin"] = 668,
			["Umed"] = 38,
			["Umin"] = 23,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.35,				
		},		
		[4] = 
		{
			["Tmax"] = 26.7, 
			["Tmin"] = 11.7,
			["CL4_6"] = 0.64,
			["CL7_8"] = 0.71,
			["CL9_10"] = 0.78,
			["Rain"] = 0.94,
			["Storm"] = 0.99,
			["WD_day"] = 45,
			["WD_night"] = 225,
			["WD_speed"] = 9.7,
			["Pmax"] = 670,
			["Pmin"] = 668,
			["Umed"] = 27,
			["Umin"] = 16,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.40,				
		},			
		[5] = 
		{
			["Tmax"] = 32, 
			["Tmin"] = 18,
			["CL4_6"] = 0.68,
			["CL7_8"] = 0.74,
			["CL9_10"] = 0.82,
			["Rain"] = 0.97,
			["Storm"] = 0.999,
			["WD_day"] = 270,
			["WD_night"] = 90,
			["WD_speed"] = 8.8,
			["Pmax"] = 669,
			["Pmin"] = 665,
			["Umed"] = 26,
			["Umin"] = 12,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.50,				
		},			
		[6] = 
		{
			["Tmax"] = 38, 
			["Tmin"] = 23,
			["CL4_6"] = 0.76,
			["CL7_8"] = 0.87,
			["CL9_10"] = 0.89,
			["Rain"] = 0.97,
			["Storm"] = 0.999,
			["WD_day"] = 270,
			["WD_night"] = 180,
			["WD_speed"] = 8.2,
			["Pmax"] = 668,
			["Pmin"] = 665,
			["Umed"] = 18,
			["Umin"] = 8,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.30,				
		},		
		[7] = 
		{
			["Tmax"] = 40, 
			["Tmin"] = 27,
			["CL4_6"] = 0.65,
			["CL7_8"] = 0.81,
			["CL9_10"] = 0.87,
			["Rain"] = 0.91,
			["Storm"] = 0.98,
			["WD_day"] = 180,
			["WD_night"] = 270,
			["WD_speed"] = 6.8,
			["Pmax"] = 670,
			["Pmin"] = 665,
			["Umed"] = 20,
			["Umin"] = 15,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.30,				
		},				
		[8] = 
		{
			["Tmax"] = 39, 
			["Tmin"] = 26,
			["CL4_6"] = 0.70,
			["CL7_8"] = 0.83,
			["CL9_10"] = 0.90,
			["Rain"] = 0.92,
			["Storm"] = 0.98,
			["WD_day"] = 180,
			["WD_night"] = 270,
			["WD_speed"] = 6.7,
			["Pmax"] = 670,
			["Pmin"] = 665,
			["Umed"] = 23,
			["Umin"] = 13,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.30,				
		},			
		[9] = 
		{
			["Tmax"] = 35, 
			["Tmin"] = 21,
			["CL4_6"] = 0.76,
			["CL7_8"] = 0.87,
			["CL9_10"] = 0.91,
			["Rain"] = 0.94,
			["Storm"] = 0.98,
			["WD_day"] = 220,
			["WD_night"] = 60,
			["WD_speed"] = 6.1,
			["Pmax"] = 670,
			["Pmin"] = 668,
			["Umed"] = 24,
			["Umin"] = 17,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.50,				
		},	
		[10] = 
		{
			["Tmax"] = 28, 
			["Tmin"] = 15,
			["CL4_6"] = 0.66,
			["CL7_8"] = 0.79,
			["CL9_10"] = 0.85,
			["Rain"] = 0.96,
			["Storm"] = 0.99,
			["WD_day"] = 005,
			["WD_night"] = 185,
			["WD_speed"] = 6.0,
			["Pmax"] = 672,
			["Pmin"] = 669,
			["Umed"] = 28,
			["Umin"] = 21,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.25,				
		},	
		[11] = 
		{
			["Tmax"] = 19, 
			["Tmin"] = 8,
			["CL4_6"] = 0.58,
			["CL7_8"] = 0.71,
			["CL9_10"] = 0.77,
			["Rain"] = 0.95,
			["Storm"] = 0.99,
			["WD_day"] = 0,
			["WD_night"] = 160,
			["WD_speed"] = 6.0,
			["Pmax"] = 674,
			["Pmin"] = 669,
			["Umed"] = 35,
			["Umin"] = 28,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.20,				
		},
		[12] = 
		{
			["Tmax"] = 14, 
			["Tmin"] = 3,
			["CL4_6"] = 0.58,
			["CL7_8"] = 0.63,
			["CL9_10"] = 0.71,
			["Rain"] = 0.93,
			["Storm"] = 0.98,
			["WD_day"] = 0,
			["WD_night"] = 180,
			["WD_speed"] = 7.3,
			["Pmax"] = 674,
			["Pmin"] = 669,
			["Umed"] = 51,
			["Umin"] = 31,
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,	
		},
	},
}

--# FUNCTIONS

function rndFactorCorrection(value)
	if type(value) == "number" then
		local maxPerc = 100 + rndFactorPerc
		local minPerc = 100 - rndFactorPerc
		local randCorr = math.random(minPerc, maxPerc)/100
		local corrValue = value*randCorr
		HOOK.writeDebugDetail(ModuleName .. ": rndFactorCorrection corrected value")
		return corrValue
	else
		HOOK.writeDebugDetail(ModuleName .. ": rndFactorCorrection error: value is not a number")
		return value
	end
end	

function getWeatherRefTable(theatre, month)
	if theatre and month then
		local terrainheight = nil
		for hId, hData in pairs(meanMapBaseHeight) do
			if theatre == hId then
				terrainheight = hData.Tbase
			end
		end
		
		if terrainheight then
			for tId, tData in pairs(staticWeatherDb) do
				if tId == theatre then
					for mId, mData in pairs(tData) do
						if mId == month then	
							return mData, terrainheight
						end
					end
				end
			end
		else
			for tId, tData in pairs(staticWeatherDb) do
				if tId == "Syria" then
					for mId, mData in pairs(tData) do
						if mId == month then	
							return mData, 500
						end
					end
				end
			end
		end
	end
end	

function getTemperature(w, h)
	if w and h then
		local Tspan = tonumber(w.Tmax) - tonumber(w.Tmin)
		local funcA = Tspan/2
		local tempB = w.Tmin + funcA
		local tempNum = funcA*math.sin(h*0.27+4)+tempB
		HOOK.writeDebugDetail(ModuleName .. ": getTemperature, tempNum: " .. tostring(tempNum))
		local tempNumRnd = rndFactorCorrection(tempNum)
		local tempNumDef = math.floor(tempNumRnd*10)/10
		HOOK.writeDebugDetail(ModuleName .. ": getTemperature ok: got " .. tostring(tempNumDef) .. " degrees")
		return tempNumDef
	else
		HOOK.writeDebugDetail(ModuleName .. ": getTemperature error: variable missing")
		return false
	end
end

function getCloudBase(wthTable, temperature, iprecptns, theatre)
	local humidity = nil
	local dewPoint = nil
	local basecorrection = 0
	
	if theatre then
		if theatre == "Caucasus" then
			basecorrection = 200
		elseif theatre == "PersianGulf" then		
			basecorrection = 800
		elseif theatre == "Nevada" then
			basecorrection = 800
		end		
	end
	
	
	if iprecptns > 0 then
		humidity = math.random(30, 80) 
	else
		local minUm = wthTable.Umed - (wthTable.Umed-wthTable.Umin)
		local maxUm = wthTable.Umed + (wthTable.Umed-wthTable.Umin)
		if maxUm > 100 then maxUm = 100 end
		humidity = math.random(minUm, maxUm)
	end

	if humidity then
		local sonntag90_a = math.log(humidity/100) + (17.62*temperature)/(243.12+temperature)
		local dewPointAbs = (243.12*sonntag90_a) / (17.62 - sonntag90_a) -- https://www.omnicalculator.com/physics/dew-point#howto
		dewPoint = math.floor(dewPointAbs*10)/10
		HOOK.writeDebugDetail(ModuleName .. ": getCloudBase, dewPoint " .. tostring(dewPoint))
	else
		HOOK.writeDebugDetail(ModuleName .. ": getCloudBase error on humidity")
	end

	if dewPoint then
		local tFarh = (temperature * (9/5)) +32
		local dFarh = (dewPoint * (9/5)) +32
		local clBaseFeet = (tFarh-dFarh)/4.4*1000		
		local clBaseMetres = math.floor(clBaseFeet* 0.3048)+basecorrection
		HOOK.writeDebugDetail(ModuleName .. ": getCloudBase result " .. tostring(clBaseMetres))
		if iprecptns > 0 and clBaseMetres > 2000 then		
			clBaseMetres = math.random(1200+basecorrection, 2000+basecorrection)
			HOOK.writeDebugDetail(ModuleName .. ": getCloudBase it's raining, corrected base to " .. tostring(clBaseMetres))
			return clBaseMetres, humidity
		else
			if clBaseMetres < 600 then
				cloudFog = true
			end
			
			return clBaseMetres, humidity, dewPoint
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getCloudBase error on dewPoint")
	end

end

function getCloudThks(wthTable, iprecptns, baseLayer)
	if cloudFog then
		local thickness = 0
		return thickness
	else

		if iprecptns == 2 or iprecptns == 4 then
			local TopHeight = math.random (9000, 12000)
			local thickness = TopHeight - baseLayer
			HOOK.writeDebugDetail(ModuleName .. ": getCloudThks storm, cloud thickness formed cumulonimbus " .. tostring(thickness))
			return thickness
		elseif iprecptns == 1 or iprecptns == 3 then		
			local thickness = math.random (800, 1500)
			HOOK.writeDebugDetail(ModuleName .. ": getCloudThks rain, cloud thickness nimbus " .. tostring(thickness))
			return thickness
		else
			local thickness = math.random (300, 1100)
			HOOK.writeDebugDetail(ModuleName .. ": getCloudThks no precipitation, thickness " .. tostring(thickness))
			return thickness
		end
	end
end

function getIprecptns(wthTable, temperature, rdnValue)
	if wthTable and temperature and rdnValue then
		if rdnValue > wthTable.Storm then
			if temperature < 0 then
				HOOK.writeDebugDetail(ModuleName .. ": getIprecptns result snowstormy")
				return 4						
			else
				HOOK.writeDebugDetail(ModuleName .. ": getIprecptns result stormy")
				return 2
			end
		elseif rdnValue > wthTable.Rain then
			if temperature < 0 then
				HOOK.writeDebugDetail(ModuleName .. ": getIprecptns result snowstormy")
				return 3						
			else
				HOOK.writeDebugDetail(ModuleName .. ": getIprecptns result stormy")
				return 1
			end
		else
			return 0
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getIprecptns error: variable missing")
		return false
	end
end

function getCloudDens(iprecptns, wthTable, rdnValue)
	if cloudFog then
		return 0
	else

		if iprecptns == 2 or iprecptns == 4 then
			HOOK.writeDebugDetail(ModuleName .. ": getCloudDens stormy or snowstormy")
			return math.random(9,10)
		elseif rdnValue > wthTable.CL9_10 then 
			HOOK.writeDebugDetail(ModuleName .. ": getCloudDens overcast")
			return math.random(9,10)
		elseif rdnValue > wthTable.CL7_8 then 
			HOOK.writeDebugDetail(ModuleName .. ": getCloudDens cloudy")
			return math.random(7,8)
		elseif rdnValue > wthTable.CL4_6 then 
			HOOK.writeDebugDetail(ModuleName .. ": getCloudDens scattered")
			return math.random(4,6)
		else
			HOOK.writeDebugDetail(ModuleName .. ": getCloudDens clear")
			return math.random(0,3)
		end
	end
end

function getWind(wthTable, hour)
	if wthTable and hour then
		-- define direction
		local Wspan = wthTable.WD_day - wthTable.WD_night
		local funcA = Wspan/2
		local windB = wthTable.WD_night + funcA
		local windNum = funcA*math.sin(hour*0.27+4.5)+windB
		local windNumRnd = math.floor(math.random((windNum*(1-wthTable.windVar)),(windNum*(1+wthTable.windVar))))   -- math.floor(rndFactorCorrection(windNum))
		HOOK.writeDebugDetail(ModuleName .. ": getWind direction ok: got " .. tostring(windNumRnd) .. " degrees")
		
		-- define intensity
		local windMinSpeed = math.floor(rndFactorCorrection(wthTable.WD_speed*0.8))*10
		local windMaxSpeed = math.floor(rndFactorCorrection(wthTable.WD_speed*1.2))*10
		local windSpeed = math.floor(math.random(windMinSpeed, windMaxSpeed))/10
		HOOK.writeDebugDetail(ModuleName .. ": getWind, windSpeed var: got " .. tostring(windSpeed))
		local WSspan = windSpeed - 0
		local SfuncA = WSspan/2
		local windSB = 0 + SfuncA
		local SpeedNum = math.floor((SfuncA*math.sin(hour*0.54+4.5)+windSB)*10)/10
		HOOK.writeDebugDetail(ModuleName .. ": getWind speed ok: got " .. tostring(SpeedNum))

		-- define gust
		local windGustSpeed = math.random(SpeedNum/4*10, SpeedNum*2*10)/10
		if windGustSpeed > 60 then windGustSpeed = 60 end
		HOOK.writeDebugDetail(ModuleName .. ": getWind gust speed ok: got " .. tostring(windGustSpeed))

		return windNumRnd, SpeedNum, windGustSpeed
	else
		HOOK.writeDebugDetail(ModuleName .. ": getWind error: variable missing")
		return false
	end
end

function getFog(wthTable, iprecptns, temperature, windSpeed, humidity, clDensity, dewPoint) -- simplified estimation
	if cloudFog then
		HOOK.writeDebugDetail(ModuleName .. ": getFog is doing cloud fog setting")
		return true, math.random(500,1000), math.random(100,1000)
	else
		if wthTable.fogAllowed == true then
			if wthTable and iprecptns and temperature and windSpeed and humidity and clDensity and dewPoint then -- https://blog.metservice.com/Fog
				local tempDewCheck = temperature-dewPoint
				if iprecptns == 0 then
					if humidity > 80 then
						if tempDewCheck < 2 then
							if windSpeed < 4 then
								if clDensity < 4 and temperature > 10 then
									local fogIndex = 1/((humidity-80)/(100-80))     -- the lower, the more fog
									local fogVis = 6000*fogIndex
									if fogVis < 1000 then fogVis = math.random(1000,2000) end 
									local fogThick = 500*fogIndex
									HOOK.writeDebugDetail(ModuleName .. ": getFog, fog present with visibility " .. tostring(fogVis) .. " and thickness " .. tostring(fogThick))
									return true, fogThick, fogVis
								else
									HOOK.writeDebugDetail(ModuleName .. ": getFog, too many clouds with temperature more than freezing point, temperature inversion less probable")
									return false, 0, 6000
								end
							else
								HOOK.writeDebugDetail(ModuleName .. ": getFog, wind below 4 mps")
								return false, 0, 6000
							end
						else
							HOOK.writeDebugDetail(ModuleName .. ": getFog, temperature too high")
							return false, 0, 6000
						end
					else
						HOOK.writeDebugDetail(ModuleName .. ": getFog, humidity below 80 perc")
						return false, 0, 6000
					end
				else
					HOOK.writeDebugDetail(ModuleName .. ": getFog, rain or snow")
					return false, 0, 6000						
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": getFog variable missing")
				return false, 0, 6000
			end

		else
			HOOK.writeDebugDetail(ModuleName .. ": getFog fog not allowed")
			return false, 0, 6000
		end
	end
end

function getDust(wthTable, iprecptns, temperature, windSpeed, windDir) -- https://iopscience.iop.org/article/10.1088/1748-9326/11/11/114013
	if wthTable.sandAllowed == true then
		if wthTable and iprecptns and temperature and windSpeed and windDir then
			if iprecptns == 0 then
				if windSpeed > 10 then -- wind must be strong
					if windDir > 20 and windDir < 140 then -- wind must come from desert
						if temperature > 30 then							
							local probable = math.random(1,100) -- still only 10% probable
							if probable > 90 then
								local dustVis = math.random(300,3000)
								HOOK.writeDebugDetail(ModuleName .. ": getDust, fog present with visibility " .. tostring(fogVis) .. " and thickness " .. tostring(fogThick))
								return true, dustVis
							end
						else
							HOOK.writeDebugDetail(ModuleName .. ": getDust, temperature too low")
							return false, 3000
						end
					else
						HOOK.writeDebugDetail(ModuleName .. ": getDust, wind not from desert")
						return false, 3000
					end
				else
					HOOK.writeDebugDetail(ModuleName .. ": getDust, wind below 10 mps")
					return false, 3000
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": getDust, rain or snow")
				return false, 3000					
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": getDust variable missing")
			return false, 3000
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": getDust fog not allowed")
		return false, 3000
	end
end

function getPressure(wthTable, iprecptns, clDensity)
	if wthTable and iprecptns then
		if iprecptns == 0 then
			if clDensity <5 then
				local pressureNorm = math.random(wthTable.Pmin, wthTable.Pmax)
				HOOK.writeDebugDetail(ModuleName .. ": getPressure no rain, no snow, no clouds")
				return pressureNorm
			else
				local pressureNorm = math.random(wthTable.Pmin-5, wthTable.Pmin+15)
				HOOK.writeDebugDetail(ModuleName .. ": getPressure no rain or snow but clouds, stay low on pressure")
				return pressureNorm
			end
		else
			local pressureLow = math.random(wthTable.Pmin-20, wthTable.Pmin+5)
			HOOK.writeDebugDetail(ModuleName .. ": getPressure rain or snow, stay low on pressure")
			return pressureLow
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getPressure error: variable missing")
	end
end

-- NOT SURE IF FUNCTION BELOW HAS EFFECT I NEW DCS WORLD!
function getVisibility(Humidity)  --https://meetingorganizer.copernicus.org/FOGDEW2010/FOGDEW2010-112.pdf
	if Humidity then
		HOOK.writeDebugDetail(ModuleName .. ": getVisibility no rain or snow")
		local visibility = (-41.5*math.log(Humidity)+192.3)*1000 -- 41.5 * ln(RHw) + 192.30
		if visibility > 80000 then visibility = 80000 end
		return visibility
	else
		HOOK.writeDebugDetail(ModuleName .. ": getVisibility error: variable missing")
	end
end

function elabWeather(missionEnv)
	DewPointCalc = nil
	HOOK.writeDebugDetail(ModuleName .. ": elabWeather, launched")
	local theatre = missionEnv.theatre
	local month = missionEnv.date.Month
	local hour = math.floor(tonumber(missionEnv.start_time)/3600)
	HOOK.writeDebugDetail(ModuleName .. ": elabWeather, got date info")

	-- retrieve weather reference table
	local wthTable, tbase = getWeatherRefTable(theatre, month)
	
	if wthTable and tbase then
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, got wthTable")
		--UTIL.dumpTable("wthTable.lua", wthTable)

		-- prevent dynamic
		missionEnv.weather.atmosphere_type = 0
		missionEnv.weather.cyclones = {}
		missionEnv.weather.type_weather = 0
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, dynamic prevented")

		-- set name
		missionEnv.weather.name = "DSMC modified weather"
		missionEnv.weather.name_cn = "DSMC modified weather"
		missionEnv.weather.name_es = "DSMC modified weather"
		missionEnv.weather.name_fr = "DSMC modified weather"
		missionEnv.weather.name_de = "DSMC modified weather"
		missionEnv.weather.name_ru = "DSMC modified weather"			
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, set weather names")

		-- set temperature
		local newTemp = getTemperature(wthTable, hour)
		missionEnv.weather.season.temperature = newTemp
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, set temperatures: " .. tostring(missionEnv.weather.season.temperature))

		-- set prec, clouds
		local CompleterdnValue = math.random()
		local rdnValue = math.floor(CompleterdnValue*100)/100
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, rdnValue: " .. tostring(rdnValue))
		missionEnv.weather.clouds.iprecptns = getIprecptns(wthTable, missionEnv.weather.season.temperature, rdnValue)
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getIprecptns: " .. tostring(missionEnv.weather.clouds.iprecptns))
		missionEnv.weather.clouds.density = getCloudDens(missionEnv.weather.clouds.iprecptns, wthTable, rdnValue)
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getCloudDens: " .. tostring(missionEnv.weather.clouds.density))
		local clBase, clHumid, clDewPoint = getCloudBase(wthTable, missionEnv.weather.season.temperature, missionEnv.weather.clouds.iprecptns, theatre)	
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getCloudBase")
		if clBase and clHumid and clDewPoint then
			DewPointCalc = clDewPoint
			missionEnv.weather.clouds.base = clBase + tbase
			local newThickness = getCloudThks(wthTable, missionEnv.weather.clouds.iprecptns, missionEnv.weather.clouds.base)
			if newThickness then
				missionEnv.weather.clouds.thickness = newThickness
			end	
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getCloudThks: " .. tostring(missionEnv.weather.clouds.thickness))

			-- set wind
			local windDir, windSpeed, windGusts = getWind(wthTable, hour)
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getWind")
			if windDir and windSpeed and windGusts then
				missionEnv.weather.groundTurbulence = windGusts
				missionEnv.weather.wind.atGround.speed = windSpeed
				missionEnv.weather.wind.atGround.dir = windDir
				missionEnv.weather.wind.at2000.speed = math.floor(rndFactorCorrection(windSpeed*15))/10
				missionEnv.weather.wind.at2000.dir = math.floor(rndFactorCorrection(windDir))
				missionEnv.weather.wind.at8000.speed = math.floor(rndFactorCorrection(windSpeed*20))/10
				missionEnv.weather.wind.at8000.dir = math.floor(rndFactorCorrection(windDir))
			end
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, wind ok")

			--	set fog
			local fogEnable, fogThickness, fogDistance = getFog(wthTable, missionEnv.weather.clouds.iprecptns, missionEnv.weather.season.temperature, missionEnv.weather.wind.atGround.speed, clHumid, missionEnv.weather.clouds.density, clDewPoint)
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getFog")
			
			if fogThickness and fogDistance and hour < 9 then
				missionEnv.weather.enable_fog = fogEnable
				missionEnv.weather.fog.thickness = fogThickness
				missionEnv.weather.fog.visibility = fogDistance
			end
		
			--	set dust
			local dustEnable, dustDistance = getDust(wthTable, missionEnv.weather.clouds.iprecptns, missionEnv.weather.season.temperature, missionEnv.weather.wind.at2000.speed, missionEnv.weather.wind.at2000.dir)			
			if dustDistance then
				missionEnv.weather.enable_dust = dustEnable
				missionEnv.weather.fog.dust_density = dustDistance
			end			
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getDust")
		
			-- set pressure
			local newPressure =getPressure(wthTable, missionEnv.weather.clouds.iprecptns, missionEnv.weather.clouds.density)			
			if newPressure then
				missionEnv.weather.qnh = newPressure
			end
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getPressure: " .. tostring(missionEnv.weather.qnh))

			HOOK.writeDebugDetail(ModuleName .. ": elabWeather elaboration complete")
			if UPAP then
				if UPAP.weatherExport == true then
					HOOK.writeDebugDetail(ModuleName .. ": elabWeather - UPAP.weatherExport: " .. tostring(UPAP.weatherExport ))
					UPAP.expWthToText(missionEnv)
				end
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": updateWeatherTable no wthTable")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather no cloud data")
	end
end

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
WTHRloaded = true