-- Dynamic Sequential Mission Campaign -- WEATHER module

local ModuleName  	= "WTHR"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

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
		["Umax"] = 50,
		["Umin"] = 20,
	},
	["PersianGulf"] = 
	{
		["Tbase"] = 100, 
		["Umax"] = 25,
		["Umin"] = 15,
	},
	["Nevada"] = 
	{
		["Tbase"] = 1000, 
		["Umax"] = 25,
		["Umin"] = 15,
	},
	["Syria"] = 
	{
		["Tbase"] = 500, 
		["Umax"] = 40,
		["Umin"] = 20,
	},
	["TheChannel"] = 
	{
		["Tbase"] = 100,
		["Umax"] = 60,
		["Umin"] = 25,
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
			["Pmax"] = 770, 
			["Pmin"] = 735,
			["fogAllowed"] = false,		
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
			["Pmax"] = 768, 
			["Pmin"] = 742,
			["fogAllowed"] = false,		
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
			["Pmax"] = 769, 
			["Pmin"] = 736,
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
			["Pmax"] = 770, 
			["Pmin"] = 736,
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
			["Pmax"] = 775, 
			["Pmin"] = 748,
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
			["Pmax"] = 769, 
			["Pmin"] = 756,
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
			["Pmax"] = 771, 
			["Pmin"] = 752,
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
			["fogAllowed"] = false,		
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
			["Pmax"] = 770, 
			["Pmin"] = 746.1,
			["fogAllowed"] = false,		
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
			["Pmax"] = 770, -- https://rp5.ru/Weather_archive_in_Kutaisi
			["Pmin"] = 743,
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
			["Pmax"] = 770, 
			["Pmin"] = 738,
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
			["Pmax"] = 771, 
			["Pmin"] = 746.2,
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
			["Pmax"] = 782, 
			["Pmin"] = 749.7,
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
			["Pmax"] = 782, 
			["Pmin"] = 749.7,
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
			["Pmax"] = 782, 
			["Pmin"] = 749.7,
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
			["Pmax"] = 782, 
			["Pmin"] = 746.1,
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
			["fogAllowed"] = true,		
			["sandAllowed"] = false,
			["windVar"] = 0.15,	
		},
	},
	["TheChannel"] = -- Based on data for Calais https://de.weatherspark.com/y/48617/Durchschnittswetter-in-Merville-Frankreich-das-ganze-Jahr-%C3%BCber
	{
		[1] = 
		{
			["Tmax"] = 7.0, -- Done 
			["Tmin"] = 3.0, -- Done
			["CL4_6"] = 0.40,
			["CL7_8"] = 0.55,
			["CL9_10"] = 0.70,
			["Rain"] = 0.69, -- Done 
			["Storm"] = 0.96,
			["WD_day"] = 0, -- Done "S"
			["WD_night"] = 0, -- Done
			["WD_speed"] = 7, -- Done 
			["Pmax"] = 780, -- Done https://rp5.ru/Weather_archive_in_Boulogne-sur-Mer between 2005 and 2020
			["Pmin"] = 726,
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 
			["windVar"] = 0.25, -- Done 				
		},
		[2] = 
		{
			["Tmax"] = 7.5, -- Done
			["Tmin"] = 3.5, -- Done
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.50,
			["CL9_10"] = 0.63,
			["Rain"] = 0.74, -- Done 
			["Storm"] = 0.96,
			["WD_day"] = 45, -- Done "SW
			["WD_night"] = 45, -- Done "SW"
			["WD_speed"] = 6.66, -- Done 
			["Pmax"] = 775, -- Done  
			["Pmin"] = 723, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 	
			["windVar"] = 0.25, -- Done 		
		},	
		[3] = 
		{
			["Tmax"] = 9.5,  -- Done
			["Tmin"] = 4.5, -- Done
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.50,
			["CL9_10"] = 0.63,
			["Rain"] = 0.74, -- Done 
			["Storm"] = 0.96,
			["WD_day"] = 90, -- Done "W"
			["WD_night"] = 90,  -- Done "W"
			["WD_speed"] = 5.8, -- Done 
			["Pmax"] = 775, -- Done  
			["Pmin"] = 732, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 
			["windVar"] = 0.25, -- Done 		
		},		
		[4] = 
		{
			["Tmax"] = 12.5,  -- Done
			["Tmin"] = 6.5, -- Done
			["CL4_6"] = 0.35, 
			["CL7_8"] = 0.47,
			["CL9_10"] = 0.61,
			["Rain"] = 0.77, -- Done 
			["Storm"] = 0.95,
			["WD_day"] = 135, -- Done "NW"
			["WD_night"] = 135, -- Done "NW"
			["WD_speed"] = 5.5, -- Done
			["Pmax"] = 772, -- Done 
			["Pmin"] = 730, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 	
			["windVar"] = 0.25, -- Done 		
		},			
		[5] = 
		{
			["Tmax"] = 15.5,  -- Done
			["Tmin"] = 9.0, -- Done
			["CL4_6"] = 0.42, 
			["CL7_8"] = 0.57,
			["CL9_10"] = 0.66,
			["Rain"] = 0.745, -- Done 
			["Storm"] = 0.95,
			["WD_day"] = 180, -- Done "N"
			["WD_night"] = 180, -- Done "N"
			["WD_speed"] = 5, -- Done 
			["Pmax"] = 774, -- Done  
			["Pmin"] = 737, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 	
			["windVar"] = 0.25, -- Done 		
		},		
		[6] = 
		{
			["Tmax"] = 20.5,  -- Done
			["Tmin"] = 13.5, -- Done
			["CL4_6"] = 0.50, 
			["CL7_8"] = 0.75,
			["CL9_10"] = 0.79,
			["Rain"] = 0.75, -- Done 
			["Storm"] = 0.93,
			["WD_day"] = 135, -- Done "NW"
			["WD_night"] = 135, -- Done "NW"
			["WD_speed"] = 4.5, -- Done 
			["Pmax"] = 769, -- Done  
			["Pmin"] = 739, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 		
			["windVar"] = 0.25, -- Done 	
		},	
		[7] = 
		{
			["Tmax"] = 20.5,  -- Done
			["Tmin"] = 13.5, -- Done
			["CL4_6"] = 0.65, 
			["CL7_8"] = 0.90,
			["CL9_10"] = 0.905,
			["Rain"] = 0.77, -- Done 
			["Storm"] = 0.93,
			["WD_day"] = 90, -- Done "W"
			["WD_night"] = 90, -- Done "W"
			["WD_speed"] = 4.5, -- Done
			["Pmax"] = 766, -- Done  
			["Pmin"] = 741, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 			
			["windVar"] = 0.25, -- Done 
		},	
		[8] = 
		{
			["Tmax"] = 20.5,  -- Done
			["Tmin"] = 13.5, -- Done
			["CL4_6"] = 0.65, 
			["CL7_8"] = 0.90,
			["CL9_10"] = 0.905,
			["Rain"] = 0.77, -- Done 
			["Storm"] = 0.93,
			["WD_day"] = 90, -- Done "W"
			["WD_night"] = 90, -- Done "W"
			["WD_speed"] = 5, -- Done
			["Pmax"] = 766, -- Done  
			["Pmin"] = 740, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 	
			["windVar"] = 0.25, -- Done 	
		},	
		[9] = 
		{
			["Tmax"] = 18.5,  -- Done
			["Tmin"] = 12.5, -- Done
			["CL4_6"] = 0.45, 
			["CL7_8"] = 0.72,
			["CL9_10"] = 0.83,
			["Rain"] = 0.785, -- Done 
			["Storm"] = 0.94,
			["WD_day"] =  45, -- Done "SW"
			["WD_night"] = 45, -- Done "SW"
			["WD_speed"] = 5.5, -- Done
			["Pmax"] = 734, -- Done  
			["Pmin"] = 733, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 	
			["windVar"] = 0.25, -- Done 		
		},	
		[10] = 
		{
			["Tmax"] = 14.5,  -- Done
			["Tmin"] = 9.5, -- Done
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.51,
			["CL9_10"] = 0.70,
			["Rain"] = 0.67, -- Done 
			["Storm"] = 0.95,
			["WD_day"] = 0, -- Done "S"
			["WD_night"] = 0, -- Done "S"
			["WD_speed"] = 6.66, -- Done
			["Pmax"] = 771, -- Done  
			["Pmin"] = 730, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 	
			["windVar"] = 0.25, -- Done 	
		},
		[11] = 
		{
			["Tmax"] = 10.5,  -- Done
			["Tmin"] = 5.5, -- Done
			["CL4_6"] = 0.40, 
			["CL7_8"] = 0.51,
			["CL9_10"] = 0.70,
			["Rain"] = 0.64, -- Done 
			["Storm"] = 0.95,
			["WD_day"] = 0, -- Done "S"
			["WD_night"] = 0, -- Done "S"
			["WD_speed"] = 7, -- Done
			["Pmax"] = 774, -- Done  
			["Pmin"] = 721, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 
			["windVar"] = 0.25, -- Done 			
		},
		[12] = 
		{
			["Tmax"] = 8.0,  -- Done
			["Tmin"] = 4.0, -- Done
			["CL4_6"] = 0.28, 
			["CL7_8"] = 0.40,
			["CL9_10"] = 0.60,
			["Rain"] = 0.65, -- Done 
			["Storm"] = 0.95,
			["WD_day"] = 0, -- Done "S"
			["WD_night"] = 0, -- Done "S"
			["WD_speed"] = 7.5, -- Done
			["Pmax"] = 778, -- Done  
			["Pmin"] = 720, -- Done 
			["fogAllowed"] = true, -- Done 	
			["sandAllowed"] = false, -- Done 
			["windVar"] = 0.25, -- Done 			
		},
	},
}

newWeatherPresets = {}

-- new preset
local cPath = lfs.currentdir() .. "Config/Effects/clouds.lua"
local t = io.open(cPath, "r")
local enableNewCloud = false
if t then
	local cString = nil
	HOOK.writeDebugDetail(ModuleName .. ": c1")
	cString = t:read("*all")
	t:close()
	if cString then
		HOOK.writeDebugDetail(ModuleName .. ": c2")
		local cFun, cErr = loadstring(cString);
		HOOK.writeDebugDetail(ModuleName .. ": c2b, cErr = " .. tostring(cErr))
		if cFun then
			HOOK.writeDebugDetail(ModuleName .. ": c3")
			--wthrEnv = {}
			--setfenv(cFun, wthrEnv)
			HOOK.writeDebugDetail(ModuleName .. ": c4")
			cFun()
			HOOK.writeDebugDetail(ModuleName .. ": c5")
			enableNewCloud = true
		end
	end
else
	HOOK.writeDebugDetail(ModuleName .. ": clouds.lua not found")	
end

function round(num, idp)
    local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end
HOOK.writeDebugDetail(ModuleName .. ": c6")
UTIL.dumpTable("clouds.lua", clouds)

if clouds and enableNewCloud == true then

	for cId, cData in pairs(clouds.presets) do
		if cData.visibleInGUI == true then 
			local cname = cData.readableName
			HOOK.writeDebugDetail(ModuleName .. ": clouds: checing preset " .. tostring(cname))
			local crain = false
			if cData.precipitationPower > 0 then
				crain = true
			end
			local coktasMax = 0
			local coktasMin = 10
			if cData.layers then
				for _, lData in ipairs(cData.layers) do
					if lData.coverage > coktasMax then
						coktasMax = lData.coverage 
					end
				end

				for _, lData in ipairs(cData.layers) do
					if lData.coverage > 0 and lData.coverage < coktasMin then
						coktasMin = lData.coverage
					end
				end
			end		
			coktasMax = round(coktasMax*10)+1
			coktasMin = round(coktasMin*10)-1

			newWeatherPresets[#newWeatherPresets+1] = {id = cId, rain = crain, oktasMin = coktasMin, oktasMax = coktasMax, name = cname}
		end
	end

	if #newWeatherPresets == 0 then
		enableNewCloud = false
	end
end
UTIL.dumpTable("newWeatherPresets.lua", newWeatherPresets)

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
							HOOK.writeDebugDetail(ModuleName .. ": getWeatherRefTable has terrain and height data for " .. tostring(theatre))
							return mData, terrainheight
						end
					end
				end
			end
		else
			for tId, tData in pairs(staticWeatherDb) do
				if tId == theatre then -- "Syria"
					for mId, mData in pairs(tData) do
						if mId == month then	
							HOOK.writeDebugDetail(ModuleName .. ": getWeatherRefTable has terrain data for " .. tostring(theatre) .. ", no height so it will be 500")
							return mData, 500
						end
					end
				end
			end
		end

		-- if you get here, then you don't have a valid map for weather
		for tId, tData in pairs(staticWeatherDb) do
			if tId == "Syria" then -- "Syria"
				for mId, mData in pairs(tData) do
					if mId == month then	
						HOOK.writeDebugDetail(ModuleName .. ": getWeatherRefTable error: no valid theatre, using Syria defaults")
						return mData, 500
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

function getHumidity(Hmax, Hmin, m, h) -- t = teatro, m = mese, h = ora
	if Hmax and Hmin and m and h then
	
		local Uspan = tonumber(Hmax) - tonumber(Hmin)
		local funcA = Uspan/2
		local humA = Hmin + funcA
		local humMese = math.floor(funcA*math.sin(m*0.54+1)+humA)

		HOOK.writeDebugDetail(ModuleName .. ": getHumidity, humMese: " .. tostring(humMese))

		if humMese then
			-- now get hour
			local H2max = humMese+math.random(1, 5)
			local H2min = humMese-math.random(1, 10)
			local Uspan2 = H2max-H2min
			local funcB = Uspan2/2
			local humB = H2min + funcB
			local humHour = math.floor(funcB*math.sin(m*0.27+8)+humB)

			if humHour then
				HOOK.writeDebugDetail(ModuleName .. ": getHumidity, returning humHour: " .. tostring(humHour))
				return humHour
			else
				HOOK.writeDebugDetail(ModuleName .. ": getHumidity error: failed to calculate humHour, returnin humMese")
				return humMese
			end

		else
			HOOK.writeDebugDetail(ModuleName .. ": getHumidity error: failed to calculate humMese")
			return false

		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getHumidity error: variable missing")
		return false
	end
end

function getCloudBase(mEnv, temperature, iprecptns, theatre)
	local humidity = nil
	local dewPoint = nil
	local basecorrection = 0
	local Hmin = nil
	local Hmax = nil
	
	if theatre then
		for hId, hData in pairs(meanMapBaseHeight) do
			if theatre == hId then
				basecorrection = hData.Tbase
				Hmax = hData.Umax
				Hmin = hData.Umin
			end
		end	
	end

	HOOK.writeDebugDetail(ModuleName .. ": getCloudBase theatre data retrieved")

	if Hmax == nil or Hmin == nil then
		HOOK.writeDebugDetail(ModuleName .. ": getCloudBase error: failed to retrieve humidity, give fixed data")
		Hmax = 40
		Hmin = 15
	end
	
	if basecorrection then

		if iprecptns > 0 then
			humidity = math.random(30, 80) 
		else
			local hour = math.floor(tonumber(mEnv.start_time)/3600)
			humidity = getHumidity(Hmax, Hmin, mEnv.date.Month, hour)
			HOOK.writeDebugDetail(ModuleName .. ": getCloudBase, humidity: " .. tostring(humidity) .. " percent")

			if not humidity then
				HOOK.writeDebugDetail(ModuleName .. ": getCloudBase error: failed to calculate humidity")
				humidity = 30
			end
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
	else
		HOOK.writeDebugDetail(ModuleName .. ": getCloudBase error on humidity retrieval")
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
			if enableNewCloud then
				return math.random(2,4)
			else
				return math.random(0,3)
			end
		end
	end
end

function getCloudPreset(isRaining, coverageVal)
	
	if enableNewCloud == true then
		--missionEnv, missionEnv.weather.clouds.iprecptns, clBase, missionEnv.weather.clouds.density
		HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, values. isRaining = " .. tostring(isRaining) .. ", coverageVal = " .. tostring(coverageVal))
		
		-- conversion
		local precipitation = false
		if isRaining > 0 then
			precipitation = true -- refine with power!
		end
		
		local availPreset = {}
		if precipitation == true then
			for _, pData in pairs(newWeatherPresets) do
				if pData.rain == precipitation  then
					availPreset[#availPreset+1] = pData.id
					HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, adding " .. tostring(pData.id))
				end
			end
		else
			local foundOne = false
			for _, pData in pairs(newWeatherPresets) do
				if pData.rain == precipitation  then
					if coverageVal >= pData.oktasMin and coverageVal <= pData.oktasMax then			 
						foundOne = true
						availPreset[#availPreset+1] = pData.id
						HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, found on first round, adding " .. tostring(pData.id))
					end
				end
			end

			if foundOne == false then
				for _, pData in pairs(newWeatherPresets) do
					if pData.rain == precipitation  then
						if (coverageVal+2) >= pData.oktasMin and (coverageVal-2) <= pData.oktasMax then			 
							foundOne = true
							availPreset[#availPreset+1] = pData.id
							HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, found on second round, adding " .. tostring(pData.id))
						end
					end
				end
			end
			
			if foundOne == false then
				for _, pData in pairs(newWeatherPresets) do
					if pData.rain == precipitation  then
						availPreset[#availPreset+1] = pData.id
						HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, found on third round, adding " .. tostring(pData.id))		
					end
				end
			end
		end

		local rnVal = math.random(1, #availPreset)
		for aId, aData in pairs(availPreset) do 
			if rnVal == aId then
				HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, preset choosen: " .. tostring(aData))
				return aData
			end
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": getCloudPreset, enableNewCloud false, return false")
		return false
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
									return true, fogThick, fogVis, 3000
								else
									HOOK.writeDebugDetail(ModuleName .. ": getFog, too many clouds with temperature more than freezing point, temperature inversion less probable")
									return false, 0, 6000, 3000
								end
							else
								HOOK.writeDebugDetail(ModuleName .. ": getFog, wind below 4 mps")
								return false, 0, 6000, 3000
							end
						else
							HOOK.writeDebugDetail(ModuleName .. ": getFog, temperature too high")
							return false, 0, 6000, 3000
						end
					else
						HOOK.writeDebugDetail(ModuleName .. ": getFog, humidity below 80 perc")
						return false, 0, 6000, 3000
					end
				else
					HOOK.writeDebugDetail(ModuleName .. ": getFog, rain or snow")
					return false, 0, 6000	, 3000					
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": getFog variable missing")
				return false, 0, 6000, 3000
			end

		else
			HOOK.writeDebugDetail(ModuleName .. ": getFog fog not allowed")
			return false, 0, 6000, 3000
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
		local clBase, clHumid, clDewPoint = getCloudBase(missionEnv, missionEnv.weather.season.temperature, missionEnv.weather.clouds.iprecptns, theatre)	
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getCloudBase")
		
		
		local clPreset = getCloudPreset(missionEnv.weather.clouds.iprecptns, missionEnv.weather.clouds.density)	
		HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getCloudPreset")

		if clBase and clHumid and clDewPoint then
			
			DewPointCalc = clDewPoint
			missionEnv.weather.clouds.base = clBase + tbase			
			
			if clPreset then
				missionEnv.weather.clouds.thickness = 200
				missionEnv.weather.clouds.iprecptns = 0
				missionEnv.weather.clouds.density = 0
				missionEnv.weather.clouds.preset = clPreset
				
			else
				local newThickness = getCloudThks(wthTable, missionEnv.weather.clouds.iprecptns, missionEnv.weather.clouds.base)
				if newThickness then
					missionEnv.weather.clouds.thickness = newThickness
				end	
				HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getCloudThks: " .. tostring(missionEnv.weather.clouds.thickness))
			end

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
			local fogEnable, fogThickness, fogDistance, fogDensity = getFog(wthTable, missionEnv.weather.clouds.iprecptns, missionEnv.weather.season.temperature, missionEnv.weather.wind.atGround.speed, clHumid, missionEnv.weather.clouds.density, clDewPoint)
			HOOK.writeDebugDetail(ModuleName .. ": elabWeather, done getFog")
			
			if fogThickness and fogDistance and hour < 9 then
				missionEnv.weather.enable_fog = fogEnable
				missionEnv.weather.fog.thickness = fogThickness
				missionEnv.weather.fog.visibility = fogDistance
				missionEnv.weather.fog.dust_density = fogDensity
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
			--
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