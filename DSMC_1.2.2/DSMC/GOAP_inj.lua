-- Dynamic Sequential Mission Campaign -- AI ENHANCEMENT GOAP injected module

local ModuleName  	= "GOAP"
local MainVersion 	= DSMC_MainVersion
local SubVersion 	= DSMC_SubVersion
local Build 		= DSMC_Build
local Date			= DSMC_Date

--## MAIN TABLE
GOAP                                = {}

--## LOCAL VARIABLES
--env.setErrorMessageBoxEnabled(false)
local base 						    = _G
local DSMC_io 					    = base.io  	-- check if io is available in mission environment
local DSMC_lfs 					    = base.lfs		-- check if lfs is available in mission environment
local phase_index                   = 1

if not DSMC_baseGcounter then
	DSMC_baseGcounter = 20000000
end
if not DSMC_baseUcounter then
	DSMC_baseUcounter = 19000000
end

GOAP.debugProcessDetail             = true -- DSMC_debugProcessDetail or true
GOAP.outRoadSpeed                   = 28,8/3.6	-- km/h /3.6, cause DCS thinks in m/s	
GOAP.inRoadSpeed                    = 54/3.6	        -- km/h /3.6, cause DCS thinks in m/s
GOAP.outAmmoLowLevel                = 0.7		        -- factor on total amount
GOAP.TerrainDb                      = {}
GOAP.disperseActionTime				= 120		        -- seconds
GOAP.emergencyWithdrawDistance		= 2000 		        -- meters
GOAP.repositionDistance				= 300		        -- meters
GOAP.supportDist                    = 20000             -- m of distance max between objective point and group
GOAP.townControlRadius              = 3000              -- THIS SHALL BE OVERWRITTEN BY GOAP.lua value if all goes well
GOAP.obsoleteIntelValue             = 3600              -- seconds after the collected intel, if not renewed, are removed as "obsolete"
GOAP.townInfluenceRange             = 2000                -- m from town center for ownership & buildings count calculation for size
GOAP.phaseCycleTimer                = 0.1               -- frequency of phased cycle calculations
GOAP.territoryVoidColour            = {1, 1, 0, 0.55}   -- standard yellow   -- 0.19607843137255
GOAP.territoryNeutralColour         = {1, 1, 1, 0.55}   -- standard white
GOAP.territoryRedColour             = {1, 0.2, 0.2, 0.55}     -- standard red
GOAP.territoryBlueColour            = {0.2, 0.2, 1, 0.55}     -- standard blue
GOAP.territoryContendedColour       = {0, 0, 0, 0.55}         -- standard black
GOAP.C2commIndex                    = {}
GOAP.inTransitTroops                = {}
GOAP.numberOfTroops                 = 6                    -- default number of troops to load on a vehicle
GOAP.transportVehicleNames          = {}
GOAP.unitLoadLimits                 = {}
GOAP.unitActions                    = {}
GOAP.droppedTroopsRED               = {} -- stores dropped troop groups
GOAP.droppedTroopsBLUE              = {} -- stores dropped troop groups
GOAP.droppedTroopsNEUTRAL           = {} -- stores dropped troop groups
GOAP.maxExtractDistance             = 300 -- max distance from vehicle to troops to allow a group extraction
GOAP.soldierWeight                  = 110
GOAP.f10menuUpdateFreq              = 10
GOAP.addedTo                        = {}
GOAP.maximumSearchDistance          = 2000
GOAP.maximumMoveDistance            = 80
GOAP.terrainDbElements              = 500   -- integer: define the number of filtered elements in the terrain table. If a scenery has 2000 towns, it will come down to this filtering by size
GOAP.terrainIntelCheckDistance      = 10000 -- m

GOAP.supportUnitCategories  ={
    [1] = "Armed vehicles",
    [2] = "AntiAir Armed Vehicles",
}

GOAP.intel                          = {[0] = {}, [1] = {}, [2] = {}, [3] = {}} 

GOAP.loadableGroups = {
    -- the "word definition" inside the name specify also the preload vehicles:
    -- fireteam will be used for IFV vehicles, squad for APC, platoon for trucks

    {name = "Infantry platoon", inf = 6, mg = 4, at = 4, aa = 2},
    
    {name = "Rifle squad", inf = 4, mg = 2, at = 1 },
    {name = "Anti air squad", inf = 2, mg = 2, aa = 2},
    {name = "Anti tank squad", inf = 2, at = 4},
    {name = "Mortar squad", mortar = 5},
    
    {name = "Rifle fireteam", inf = 3, mg = 1},    
    {name = "Mortar fireteam",  mortar = 3},
    {name = "Anti air fireteam", inf = 2, aa = 1 },
    {name = "Anti tank fireteam", inf = 1, at = 2 },
    
    --{name = "Standard Group", inf = 6, mg = 2, at = 2 }, -- will make a loadable group with 5 infantry, 2 MGs and 2 anti-tank for both coalitions
    --{name = "Anti Air", inf = 2, aa = 3  },
    --{name = "Anti Tank", inf = 2, at = 6  },
    --{name = "Mortar Squad", mortar = 6 },
}

GOAP.vehicleTransportEnabled = {
    "76MD", -- the il-76 mod doesnt use a normal - sign so il-76md wont match... !!!! GRR
    "C-130",
}

GOAP.dbORBAT = {}  -- QUIIIII




if DSMC_io and DSMC_lfs then
	env.info(("GOAP loading desanitized additional function"))
	
	DSMC_GOAPmodule 	= "funzia"

	function tableShow(tbl, loc, indent, tableshow_tbls)
		tableshow_tbls = tableshow_tbls or {} --create table of tables
		loc = loc or ""
		indent = indent or ""
		if type(tbl) == 'table' then --function only works for tables!
			tableshow_tbls[tbl] = loc
			
			local tbl_str = {}

			tbl_str[#tbl_str + 1] = indent .. '{\n'
			
			for ind,val in pairs(tbl) do -- serialize its fields
				if type(ind) == "number" then
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = tostring(ind)
					tbl_str[#tbl_str + 1] = '] = '
				else
					tbl_str[#tbl_str + 1] = indent 
					tbl_str[#tbl_str + 1] = loc .. '['
					tbl_str[#tbl_str + 1] = IntegratedbasicSerialize(ind)
					tbl_str[#tbl_str + 1] = '] = '
				end
						
				if ((type(val) == 'number') or (type(val) == 'boolean')) then
					tbl_str[#tbl_str + 1] = tostring(val)
					tbl_str[#tbl_str + 1] = ',\n'		
				elseif type(val) == 'string' then
					tbl_str[#tbl_str + 1] = IntegratedbasicSerialize(val)
					tbl_str[#tbl_str + 1] = ',\n'
				elseif type(val) == 'nil' then -- won't ever happen, right?
					tbl_str[#tbl_str + 1] = 'nil,\n'
				elseif type(val) == 'table' then
					if tableshow_tbls[val] then
						tbl_str[#tbl_str + 1] = tostring(val) .. ' already defined: ' .. tableshow_tbls[val] .. ',\n'
					else
						tableshow_tbls[val] = loc ..  '[' .. IntegratedbasicSerialize(ind) .. ']'
						tbl_str[#tbl_str + 1] = tostring(val) .. ' '
						tbl_str[#tbl_str + 1] = tableShow(val,  loc .. '[' .. IntegratedbasicSerialize(ind).. ']', indent .. '    ', tableshow_tbls)
						tbl_str[#tbl_str + 1] = ',\n'  
					end
				elseif type(val) == 'function' then
					if debug and debug.getinfo then
						local fcnname = tostring(val)
						local info = debug.getinfo(val, "S")
						if info.what == "C" then
							tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', C function') .. ',\n'
						else 
							if (string.sub(info.source, 1, 2) == [[./]]) then
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')' .. info.source) ..',\n'
							else
								tbl_str[#tbl_str + 1] = string.format('%q', fcnname .. ', defined in (' .. info.linedefined .. '-' .. info.lastlinedefined .. ')') ..',\n'
							end
						end
						
					else
						tbl_str[#tbl_str + 1] = 'a function,\n'	
					end
				else
					tbl_str[#tbl_str + 1] = 'unable to serialize value type ' .. IntegratedbasicSerialize(type(val)) .. ' at index ' .. tostring(ind)
				end
			end
			
			tbl_str[#tbl_str + 1] = indent .. '}'
			return table.concat(tbl_str)
		end
	end

	function dumpTable(fname, tabledata)
		if DSMC_lfs and DSMC_io then
			local fdir = DSMC_lfs.writedir() .. [[DSMC\Debug\]] .. fname
			local f = DSMC_io.open(fdir, 'w')
			f:write(tableShow(tabledata))
			f:close()
		end
	end	

	function GOAP.saveTable(fname, tabledata)		
		if DSMC_lfs and DSMC_io then
			local GOAPfiles = DSMC_lfs.writedir() .. "Missions/Temp/Files/GOAP/"
			local fdir = GOAPfiles .. fname .. ".lua"
			local f = DSMC_io.open(fdir, 'w')
			local str = IntegratedserializeWithCycles(fname, tabledata)
			f:write(str)
			f:close()
		end
	end
	
	env.info(("GOAP desanitized additional function loaded"))
end

--## TOWNS TABLE
CaucasusTowns = {
    ["AMBROLAURI"] = { latitude = 42.530195, longitude = 43.150121, display_name = "AMBROLAURI"},
    ["KUTAISI"] = { latitude = 42.267086, longitude = 42.696849, display_name = "KUTAISI"},
    ["BATUMI"] = { latitude = 41.654059, longitude = 41.655372, display_name = "BATUMI"},
    ["POTI"] = { latitude = 42.157804, longitude = 41.677693, display_name = "POTI"},
    ["ZUGDIDI"] = { latitude = 42.516379, longitude = 41.879016, display_name = "ZUGDIDI"},
    ["MAYKOP"] = { latitude = 44.607053, longitude = 40.096197, display_name = "MAYKOP"},
    ["KRASNODAR"] = { latitude = 45.053964, longitude = 39.000128, display_name = "KRASNODAR"},
    ["NOVOROSSIYSK"] = { latitude = 44.719335, longitude = 37.751757, display_name = "NOVOROSSIYSK"},
    ["KISLOVODSK"] = { latitude = 43.913866, longitude = 42.723910, display_name = "KISLOVODSK"},
    ["SUKHUMI"] = { latitude = 43.010963, longitude = 40.999400, display_name = "SUKHUMI"},
    ["SOCHI"] = { latitude = 43.604619, longitude = 39.721483, display_name = "SOCHI"},
    ["NAL'CHIK"] = { latitude = 43.485073, longitude = 43.623441, display_name = "NAL'CHIK"},
    ["PYATIGORSK"] = { latitude = 44.052891, longitude = 43.048264, display_name = "PYATIGORSK"},
    ["MINERAL'NYE VODY"] = { latitude = 44.201454, longitude = 43.137392, display_name = "MINERAL'NYE VODY"},
    ["GEORGIEVSK"] = { latitude = 44.148896, longitude = 43.458776, display_name = "GEORGIEVSK"},
    ["CHERKESSK"] = { latitude = 44.226950, longitude = 42.060347, display_name = "CHERKESSK"},
    ["LANCHHUTI"] = { latitude = 42.089007, longitude = 42.027661, display_name = "LANCHHUTI"},
    ["SAMTREDIA"] = { latitude = 42.174739, longitude = 42.336138, display_name = "SAMTREDIA"},
    ["ABASHA"] = { latitude = 42.221963, longitude = 42.211652, display_name = "ABASHA"},
    ["SENAKI"] = { latitude = 42.285411, longitude = 42.045822, display_name = "SENAKI"},
    ["HONI"] = { latitude = 42.326943, longitude = 42.412159, display_name = "HONI"},
    ["MARTVILI"] = { latitude = 42.400702, longitude = 42.368318, display_name = "MARTVILI"},
    ["TSHALTUBO"] = { latitude = 42.323088, longitude = 42.614660, display_name = "TSHALTUBO"},
    ["TKIBULI"] = { latitude = 42.352385, longitude = 42.997191, display_name = "TKIBULI"},
    ["ZESTAFONI"] = { latitude = 42.111455, longitude = 43.037536, display_name = "ZESTAFONI"},
    ["CHIATURA"] = { latitude = 42.293616, longitude = 43.270537, display_name = "CHIATURA"},
    ["SACHHERE"] = { latitude = 42.342501, longitude = 43.404049, display_name = "SACHHERE"},
    ["OZURGETI"] = { latitude = 41.936007, longitude = 42.018441, display_name = "OZURGETI"},
    ["KOBULETI"] = { latitude = 41.808106, longitude = 41.780942, display_name = "KOBULETI"},
    ["ONI"] = { latitude = 42.591213, longitude = 43.449897, display_name = "ONI"},
    ["DZHVARI"] = { latitude = 42.703382, longitude = 42.042828, display_name = "DZHVARI"},
    ["GALI"] = { latitude = 42.624895, longitude = 41.727731, display_name = "GALI"},
    ["OCHAMCHIRA"] = { latitude = 42.722153, longitude = 41.474646, display_name = "OCHAMCHIRA"},
    ["UST'-DZHEGUTA"] = { latitude = 44.080182, longitude = 41.969081, display_name = "UST'-DZHEGUTA"},
    ["APSHERONSK"] = { latitude = 44.459654, longitude = 39.729136, display_name = "APSHERONSK"},
    ["TUAPSE"] = { latitude = 44.114132, longitude = 39.068294, display_name = "TUAPSE"},
    ["GELENDZHIK"] = { latitude = 44.578432, longitude = 38.018660, display_name = "GELENDZHIK"},
    ["PASHKOVSKIY"] = { latitude = 45.029117, longitude = 39.094463, display_name = "PASHKOVSKIY"},
    ["UST'-LABINSK"] = { latitude = 45.221626, longitude = 39.683478, display_name = "UST'-LABINSK"},
    ["BELORECHENSK"] = { latitude = 44.771687, longitude = 39.875183, display_name = "BELORECHENSK"},
    ["ABINSK"] = { latitude = 44.870561, longitude = 38.156475, display_name = "ABINSK"},
    ["KRYMSK"] = { latitude = 44.927837, longitude = 38.011490, display_name = "KRYMSK"},
    ["SLAVYANSK-NA-KUBANI"] = { latitude = 45.253951, longitude = 38.123431, display_name = "SLAVYANSK-NA-KUBANI"},
    ["ANAPA"] = { latitude = 44.932503, longitude = 37.298006, display_name = "ANAPA"},
    ["TEMRYUK"] = { latitude = 45.261076, longitude = 37.432072, display_name = "TEMRYUK"},
    ["TKVARCHELI"] = { latitude = 42.853781, longitude = 41.674307, display_name = "TKVARCHELI"},
    ["ESSENTUKI"] = { latitude = 44.043909, longitude = 42.860779, display_name = "ESSENTUKI"},
    ["ADLER"] = { latitude = 43.453776, longitude = 39.915595, display_name = "ADLER"},
    ["HOSTA"] = { latitude = 43.515628, longitude = 39.864624, display_name = "HOSTA"},
    ["LAZAREVSKOE"] = { latitude = 43.917274, longitude = 39.326891, display_name = "LAZAREVSKOE"},
    ["LERMONTOV"] = { latitude = 44.108783, longitude = 42.974445, display_name = "LERMONTOV"},
    ["TYRNYAUZ"] = { latitude = 43.391341, longitude = 42.921969, display_name = "TYRNYAUZ"},
    ["NOVOPAVLOVSK"] = { latitude = 43.962533, longitude = 43.641826, display_name = "NOVOPAVLOVSK"},
    ["BAKSAN"] = { latitude = 43.686840, longitude = 43.544814, display_name = "BAKSAN"},
    ["NARTKALA"] = { latitude = 43.554316, longitude = 43.853943, display_name = "NARTKALA"},
    ["ZHELEZNOVODSK"] = { latitude = 44.141803, longitude = 43.023059, display_name = "ZHELEZNOVODSK"},
    ["Helvachauri"] = { latitude = 41.596451, longitude = 41.668302, display_name = "Helvachauri"},
    ["Mahindzhauri"] = { latitude = 41.673079, longitude = 41.699531, display_name = "Mahindzhauri"},
    ["Kur.Bahmaro"] = { latitude = 41.848456, longitude = 42.327860, display_name = "Kur.Bahmaro"},
    ["Kur.Sairme"] = { latitude = 41.907942, longitude = 42.743349, display_name = "Kur.Sairme"},
    ["Chakva"] = { latitude = 41.727030, longitude = 41.734648, display_name = "Chakva"},
    ["Laituri"] = { latitude = 41.918270, longitude = 41.900378, display_name = "Laituri"},
    ["Kvedo-Nasakirali"] = { latitude = 41.977199, longitude = 42.061216, display_name = "Kvedo-Nasakirali"},
    ["Kulashi"] = { latitude = 42.210505, longitude = 42.349080, display_name = "Kulashi"},
    ["Gagma-Pirveli-Horga"] = { latitude = 42.267520, longitude = 41.859143, display_name = "Gagma-Pirveli-Horga"},
    ["Gamogma-Pirveli-Horga"] = { latitude = 42.288279, longitude = 41.845307, display_name = "Gamogma-Pirveli-Horga"},
    ["Ordzhonikidze"] = { latitude = 42.008849, longitude = 43.173219, display_name = "Ordzhonikidze"},
    ["Terzhola"] = { latitude = 42.195788, longitude = 42.983178, display_name = "Terzhola"},
    ["Haristvala"] = { latitude = 42.415940, longitude = 43.041115, display_name = "Haristvala"},
    ["Zeda-Sairme"] = { latitude = 42.564224, longitude = 42.882795, display_name = "Zeda-Sairme"},
    ["kur.Skuri"] = { latitude = 42.697552, longitude = 42.161497, display_name = "kur.Skuri"},
    ["Tsalendzhiha"] = { latitude = 42.619409, longitude = 42.070900, display_name = "Tsalendzhiha"},
    ["Muzhava"] = { latitude = 42.713559, longitude = 41.992057, display_name = "Muzhava"},
    ["Ingurges"] = { latitude = 42.672937, longitude = 41.853299, display_name = "Ingurges"},
    ["Severo-Vostochnye Sady"] = { latitude = 44.635280, longitude = 40.131508, display_name = "Severo-Vostochnye Sady"},
    ["Psebay"] = { latitude = 44.138091, longitude = 40.803699, display_name = "Psebay"},
    ["Kamennomostskiy"] = { latitude = 44.302330, longitude = 40.184071, display_name = "Kamennomostskiy"},
    ["Tul'skiy"] = { latitude = 44.513927, longitude = 40.170579, display_name = "Tul'skiy"},
    ["Magri"] = { latitude = 44.022796, longitude = 39.163094, display_name = "Magri"},
    ["Vishnevka"] = { latitude = 44.010679, longitude = 39.186179, display_name = "Vishnevka"},
    ["Goryachiy Klyuch"] = { latitude = 44.631585, longitude = 39.125779, display_name = "Goryachiy Klyuch"},
    ["Hadyzhensk"] = { latitude = 44.427144, longitude = 39.530325, display_name = "Hadyzhensk"},
    ["Grozneft'"] = { latitude = 44.096137, longitude = 39.100269, display_name = "Grozneft'"},
    ["Novomihaylovskiy"] = { latitude = 44.258430, longitude = 38.854150, display_name = "Novomihaylovskiy"},
    ["Dzhubga"] = { latitude = 44.325968, longitude = 38.703843, display_name = "Dzhubga"},
    ["Arhipo-Osipovka"] = { latitude = 44.376981, longitude = 38.530670, display_name = "Arhipo-Osipovka"},
    ["Pshada"] = { latitude = 44.474606, longitude = 38.401898, display_name = "Pshada"},
    ["Divnomorskoe"] = { latitude = 44.503462, longitude = 38.132761, display_name = "Divnomorskoe"},
    ["Kabardinka"] = { latitude = 44.657320, longitude = 37.934694, display_name = "Kabardinka"},
    ["Giaginskaya"] = { latitude = 44.872978, longitude = 40.056178, display_name = "Giaginskaya"},
    ["Vasyurinskaya"] = { latitude = 45.117847, longitude = 39.420083, display_name = "Vasyurinskaya"},
    ["Adygeysk"] = { latitude = 44.887801, longitude = 39.187143, display_name = "Adygeysk"},
    ["Tlyustenhabl'"] = { latitude = 44.980442, longitude = 39.092968, display_name = "Tlyustenhabl'"},
    ["Kalinino"] = { latitude = 45.097761, longitude = 39.016695, display_name = "Kalinino"},
    ["Afipskiy"] = { latitude = 44.904156, longitude = 38.844197, display_name = "Afipskiy"},
    ["Il'skiy"] = { latitude = 44.843810, longitude = 38.563777, display_name = "Il'skiy"},
    ["Chernomorskiy"] = { latitude = 44.851048, longitude = 38.491750, display_name = "Chernomorskiy"},
    ["Holmskiy"] = { latitude = 44.844059, longitude = 38.390536, display_name = "Holmskiy"},
    ["Ahtyrskiy"] = { latitude = 44.848464, longitude = 38.305640, display_name = "Ahtyrskiy"},
    ["Enem"] = { latitude = 44.926601, longitude = 38.903816, display_name = "Enem"},
    ["Yablonovskiy"] = { latitude = 44.986937, longitude = 38.944217, display_name = "Yablonovskiy"},
    ["Troitskiy"] = { latitude = 45.146496, longitude = 38.133592, display_name = "Troitskiy"},
    ["Gayduk"] = { latitude = 44.787974, longitude = 37.699085, display_name = "Gayduk"},
    ["Nizhnebakanskiy "] = { latitude = 44.868592, longitude = 37.861945, display_name = "Nizhnebakanskiy "},
    ["Verhnebakanskiy "] = { latitude = 44.843629, longitude = 37.660287, display_name = "Verhnebakanskiy "},
    ["Abrau-Dyurso"] = { latitude = 44.701124, longitude = 37.599438, display_name = "Abrau-Dyurso"},
    ["Achigvara"] = { latitude = 42.680590, longitude = 41.628738, display_name = "Achigvara"},
    ["Dzhukmur"] = { latitude = 42.746085, longitude = 41.450590, display_name = "Dzhukmur"},
    ["Okumi"] = { latitude = 42.724566, longitude = 41.754616, display_name = "Okumi"},
    ["Chkhortoli"] = { latitude = 42.761492, longitude = 41.733044, display_name = "Chkhortoli"},
    ["Beshaluba"] = { latitude = 42.757691, longitude = 41.515278, display_name = "Beshaluba"},
    ["Merkula"] = { latitude = 42.765603, longitude = 41.478017, display_name = "Merkula"},
    ["Aradu"] = { latitude = 42.779854, longitude = 41.463354, display_name = "Aradu"},
    ["Tsagera"] = { latitude = 42.779645, longitude = 41.422951, display_name = "Tsagera"},
    ["Labra"] = { latitude = 42.812025, longitude = 41.394992, display_name = "Labra"},
    ["Varcha"] = { latitude = 42.841492, longitude = 41.138267, display_name = "Varcha"},
    ["Babushara"] = { latitude = 42.853206, longitude = 41.116261, display_name = "Babushara"},
    ["Adzyubzha"] = { latitude = 42.838793, longitude = 41.191593, display_name = "Adzyubzha"},
    ["Arakich"] = { latitude = 42.845023, longitude = 41.248912, display_name = "Arakich"},
    ["Estonka"] = { latitude = 42.887601, longitude = 41.199704, display_name = "Estonka"},
    ["Nizh.- Pshap"] = { latitude = 42.888750, longitude = 41.125540, display_name = "Nizh.- Pshap"},
    ["Verh.- Pshap"] = { latitude = 42.891730, longitude = 41.155013, display_name = "Verh.- Pshap"},
    ["Shaumyanovka"] = { latitude = 42.909981, longitude = 41.190234, display_name = "Shaumyanovka"},
    ["Bagazhiashta"] = { latitude = 42.918151, longitude = 41.132147, display_name = "Bagazhiashta"},
    ["Gul'ripsh"] = { latitude = 42.926240, longitude = 41.101427, display_name = "Gul'ripsh"},
    ["Lentehi"] = { latitude = 42.790946, longitude = 42.724648, display_name = "Lentehi"},
    ["Mestia"] = { latitude = 43.049600, longitude = 42.729598, display_name = "Mestia"},
    ["Pervomayskoe"] = { latitude = 43.939875, longitude = 42.487590, display_name = "Pervomayskoe"},
    ["Uchkeken"] = { latitude = 43.943106, longitude = 42.514172, display_name = "Uchkeken"},
    ["Tereze"] = { latitude = 43.934122, longitude = 42.446490, display_name = "Tereze"},
    ["Bambora"] = { latitude = 43.101065, longitude = 40.593551, display_name = "Bambora"},
    ["Gudauta"] = { latitude = 43.106705, longitude = 40.635279, display_name = "Gudauta"},
    ["Novyy Afon"] = { latitude = 43.090391, longitude = 40.809345, display_name = "Novyy Afon"},
    ["Gagra"] = { latitude = 43.296491, longitude = 40.249993, display_name = "Gagra"},
    ["Bzyb'"] = { latitude = 43.229864, longitude = 40.360523, display_name = "Bzyb'"},
    ["Myussera"] = { latitude = 43.155608, longitude = 40.454065, display_name = "Myussera"},
    ["Pitsunda"] = { latitude = 43.163846, longitude = 40.338462, display_name = "Pitsunda"},
    ["Teberda"] = { latitude = 43.452155, longitude = 41.739692, display_name = "Teberda"},
    ["Karachaevsk"] = { latitude = 43.770235, longitude = 41.898619, display_name = "Karachaevsk"},
    ["Ordzhonikidzevskiy"] = { latitude = 43.844148, longitude = 41.892512, display_name = "Ordzhonikidzevskiy"},
    ["Gantiadi"] = { latitude = 43.393301, longitude = 40.088996, display_name = "Gantiadi"},
    ["Krasnaya Polyana"] = { latitude = 43.682548, longitude = 40.204334, display_name = "Krasnaya Polyana"},
    ["Kurdzhinovo"] = { latitude = 44.003499, longitude = 40.946645, display_name = "Kurdzhinovo"},
    ["Nov.Matsesta"] = { latitude = 43.560079, longitude = 39.801623, display_name = "Nov.Matsesta"},
    ["Star.Matsesta"] = { latitude = 43.582022, longitude = 39.802334, display_name = "Star.Matsesta"},
    ["Dagomys"] = { latitude = 43.665053, longitude = 39.658538, display_name = "Dagomys"},
    ["UDARNYY"] = { latitude = 44.351550, longitude = 42.502748, display_name = "UDARNYY"},
    ["SVOBODY"] = { latitude = 44.025747, longitude = 43.044756, display_name = "SVOBODY"},
    ["GORYACHEVODSKIY"] = { latitude = 44.023610, longitude = 43.098525, display_name = "GORYACHEVODSKIY"},
    ["INOZEMTSEVO"] = { latitude = 44.099998, longitude = 43.088585, display_name = "INOZEMTSEVO"},
    ["ANDZHIEVSKIY"] = { latitude = 44.239664, longitude = 43.084935, display_name = "ANDZHIEVSKIY"},
    ["Soldato-Aleksandrovskoe"] = { latitude = 44.266128, longitude = 43.758362, display_name = "Soldato-Aleksandrovskoe"},
    ["Aleksandriyskaya"] = { latitude = 44.226368, longitude = 43.341033, display_name = "Aleksandriyskaya"},
    ["Podgornaya"] = { latitude = 44.201130, longitude = 43.427100, display_name = "Podgornaya"},
    ["ZALUKOKOAZHE"] = { latitude = 43.902365, longitude = 43.218663, display_name = "ZALUKOKOAZHE"},
    ["CHEGEM PERVYY"] = { latitude = 43.569862, longitude = 43.581955, display_name = "CHEGEM PERVYY"},
    ["KENZHE"] = { latitude = 43.499694, longitude = 43.554187, display_name = "KENZHE"},
    ["HASAN'YA"] = { latitude = 43.438242, longitude = 43.578239, display_name = "HASAN'YA"},
    ["BELAYA RECHKA"] = { latitude = 43.434090, longitude = 43.509509, display_name = "BELAYA RECHKA"},
    ["KASHHATAU"] = { latitude = 43.318498, longitude = 43.607567, display_name = "KASHHATAU"},
    ["ZHemtala"] = { latitude = 43.285507, longitude = 43.651954, display_name = "ZHemtala"},
    ["Zaragizh"] = { latitude = 43.331056, longitude = 43.707394, display_name = "Zaragizh"},
    ["Yanikoy"] = { latitude = 43.544208, longitude = 43.507782, display_name = "Yanikoy"},
    ["ZHanhoteko"] = { latitude = 43.560102, longitude = 43.207769, display_name = "ZHanhoteko"},
    ["Zayukovo"] = { latitude = 43.620891, longitude = 43.316939, display_name = "Zayukovo"},
    ["Yantarnoe"] = { latitude = 43.762016, longitude = 43.881024, display_name = "Yantarnoe"},
    ["Zalukodes"] = { latitude = 43.836692, longitude = 43.154045, display_name = "Zalukodes"},
    ["Zol'skoe"] = { latitude = 43.842530, longitude = 43.202659, display_name = "Zol'skoe"},
    ["Zol'skaya"] = { latitude = 43.905414, longitude = 43.299699, display_name = "Zol'skaya"},
    ["Zarechnoe"] = { latitude = 43.937403, longitude = 43.856933, display_name = "Zarechnoe"},
    ["Yutsa"] = { latitude = 43.967055, longitude = 43.011684, display_name = "Yutsa"},
    ["Zakavkazskiy Partizan"] = { latitude = 44.116442, longitude = 43.838405, display_name = "Zakavkazskiy Partizan"},
    ["Zmeyka"] = { latitude = 44.141831, longitude = 43.116065, display_name = "Zmeyka"},
    ["Zagorskiy"] = { latitude = 44.258175, longitude = 43.124187, display_name = "Zagorskiy"},
    ["ZHeleznodorozhnyy"] = { latitude = 44.283840, longitude = 43.730236, display_name = "ZHeleznodorozhnyy"},
    ["Yasnaya Polyana"] = { latitude = 44.026131, longitude = 42.751359, display_name = "Yasnaya Polyana"},
    ["Zolotushka"] = { latitude = 44.048106, longitude = 42.968682, display_name = "Zolotushka"},
    ["Zheleznovodskiy"] = { latitude = 44.155908, longitude = 42.989749, display_name = "Zheleznovodskiy"},
    ["Vodorazdel'nyy"] = { latitude = 44.253379, longitude = 42.343575, display_name = "Vodorazdel'nyy"},
    ["Vorovskolesskaya"] = { latitude = 44.379548, longitude = 42.404731, display_name = "Vorovskolesskaya"},
    ["Volkonka"] = { latitude = 43.869753, longitude = 39.394933, display_name = "Volkonka"},
    ["Volkovka"] = { latitude = 43.697214, longitude = 39.665990, display_name = "Volkovka"},
    ["Vorontsovka"] = { latitude = 43.620869, longitude = 39.918245, display_name = "Vorontsovka"},
    ["Verhne-Veseloe"] = { latitude = 43.426208, longitude = 39.979875, display_name = "Verhne-Veseloe"},
    ["Veseloe"] = { latitude = 43.412545, longitude = 40.002760, display_name = "Veseloe"},
    ["Zelenchukskaya"] = { latitude = 43.858968, longitude = 41.582415, display_name = "Zelenchukskaya"},
    ["Verhnyaya-Mtsara"] = { latitude = 43.169050, longitude = 40.766431, display_name = "Verhnyaya-Mtsara"},
    ["Verhnyaya Eshera"] = { latitude = 43.075860, longitude = 40.892093, display_name = "Verhnyaya Eshera"},
    ["Znamenka"] = { latitude = 44.146904, longitude = 42.058306, display_name = "Znamenka"},
    ["Vinsady"] = { latitude = 44.080854, longitude = 42.959745, display_name = "Vinsady"},
    ["Zemo-Machara"] = { latitude = 43.007251, longitude = 41.185583, display_name = "Zemo-Machara"},
    ["Zemo-Azhara"] = { latitude = 43.111753, longitude = 41.749381, display_name = "Zemo-Azhara"},
    ["Vladimirovka"] = { latitude = 42.893409, longitude = 41.233317, display_name = "Vladimirovka"},
    ["Zaporozhskaya"] = { latitude = 45.380489, longitude = 36.863126, display_name = "Zaporozhskaya"},
    ["Volna Revolyutsii"] = { latitude = 45.335780, longitude = 36.945070, display_name = "Volna Revolyutsii"},
    ["Vinogradnyy"] = { latitude = 45.194969, longitude = 36.898478, display_name = "Vinogradnyy"},
    ["Veselovka"] = { latitude = 45.130495, longitude = 36.900949, display_name = "Veselovka"},
    ["Vyshesteblievskaya"] = { latitude = 45.197182, longitude = 36.997904, display_name = "Vyshesteblievskaya"},
    ["Vestnik"] = { latitude = 45.102251, longitude = 37.452285, display_name = "Vestnik"},
    ["Yurovka"] = { latitude = 45.116079, longitude = 37.412790, display_name = "Yurovka"},
    ["Vinogradnyy"] = { latitude = 45.058888, longitude = 37.327405, display_name = "Vinogradnyy"},
    ["Vityazevo"] = { latitude = 44.998498, longitude = 37.272707, display_name = "Vityazevo"},
    ["Voskresenskiy"] = { latitude = 44.967396, longitude = 37.326592, display_name = "Voskresenskiy"},
    ["Vinogradnyy"] = { latitude = 44.980235, longitude = 37.912105, display_name = "Vinogradnyy"},
    ["Vladimirovka"] = { latitude = 44.792068, longitude = 37.675603, display_name = "Vladimirovka"},
    ["Vorontsovskaya"] = { latitude = 45.221638, longitude = 38.736370, display_name = "Vorontsovskaya"},
    ["Yuzhnyy"] = { latitude = 45.033052, longitude = 38.079312, display_name = "Yuzhnyy"},
    ["ZHeleznyy"] = { latitude = 45.299309, longitude = 39.553831, display_name = "ZHeleznyy"},
    ["Voronezhskaya"] = { latitude = 45.212918, longitude = 39.561800, display_name = "Voronezhskaya"},
    ["Zarozhdenie"] = { latitude = 45.159335, longitude = 39.231552, display_name = "Zarozhdenie"},
    ["Znamenskiy"] = { latitude = 45.060774, longitude = 39.142515, display_name = "Znamenskiy"},
    ["Vysotnyy"] = { latitude = 44.956537, longitude = 39.680462, display_name = "Vysotnyy"},
    ["Vochepshiy"] = { latitude = 44.876265, longitude = 39.284439, display_name = "Vochepshiy"},
    ["Zarechnyy"] = { latitude = 44.757202, longitude = 39.826973, display_name = "Zarechnyy"},
    ["Yuzhnyy"] = { latitude = 44.730125, longitude = 39.864296, display_name = "Yuzhnyy"},
    ["Veselyy"] = { latitude = 44.676962, longitude = 39.936165, display_name = "Veselyy"},
    ["Yuzhnyy"] = { latitude = 45.148146, longitude = 39.027375, display_name = "Yuzhnyy"},
    ["Vozdvizhenskaya"] = { latitude = 45.129818, longitude = 40.142530, display_name = "Vozdvizhenskaya"},
    ["Zarevo"] = { latitude = 45.002707, longitude = 40.081195, display_name = "Zarevo"},
    ["Vozrozhdenie"] = { latitude = 44.549250, longitude = 38.217419, display_name = "Vozrozhdenie"},
    ["Vpered"] = { latitude = 44.550175, longitude = 39.705213, display_name = "Vpered"},
    ["Zeyuko"] = { latitude = 44.118806, longitude = 41.826530, display_name = "Zeyuko"},
    ["Zubi"] = { latitude = 42.571365, longitude = 42.669290, display_name = "Zubi"},
    ["Zeda-Gordi"] = { latitude = 42.456377, longitude = 42.522623, display_name = "Zeda-Gordi"},
    ["Zeda-Mesheti"] = { latitude = 42.222265, longitude = 42.656102, display_name = "Zeda-Mesheti"},
    ["Zeda-Dimi"] = { latitude = 42.073116, longitude = 42.839455, display_name = "Zeda-Dimi"},
    ["Zemo-Shuhuti"] = { latitude = 42.081785, longitude = 42.093085, display_name = "Zemo-Shuhuti"},
    ["Zeda-Etseri"] = { latitude = 42.081659, longitude = 42.417598, display_name = "Zeda-Etseri"},
    ["Zeda-Tsihesulori"] = { latitude = 42.087890, longitude = 42.505130, display_name = "Zeda-Tsihesulori"},
    ["Zeindari"] = { latitude = 42.093768, longitude = 42.674916, display_name = "Zeindari"},
    ["Zeda-Mukedi"] = { latitude = 42.067746, longitude = 42.468248, display_name = "Zeda-Mukedi"},
    ["Zeda-Vani"] = { latitude = 42.066098, longitude = 42.519928, display_name = "Zeda-Vani"},
    ["Zeda-Gora"] = { latitude = 42.059853, longitude = 42.690921, display_name = "Zeda-Gora"},
    ["Zeda-Zegani"] = { latitude = 42.038936, longitude = 42.921891, display_name = "Zeda-Zegani"},
    ["Zemo-Partshma"] = { latitude = 42.036261, longitude = 42.247299, display_name = "Zemo-Partshma"},
    ["Zeda-Dzimiti"] = { latitude = 42.013334, longitude = 42.062550, display_name = "Zeda-Dzimiti"},
    ["Zovreti"] = { latitude = 42.180543, longitude = 43.040004, display_name = "Zovreti"},
    ["Zeda-Bahvi"] = { latitude = 41.947222, longitude = 42.111167, display_name = "Zeda-Bahvi"},
    ["Zoti"] = { latitude = 41.893183, longitude = 42.444286, display_name = "Zoti"},
    ["Zvare"] = { latitude = 41.982828, longitude = 43.415672, display_name = "Zvare"},
    ["Zeni"] = { latitude = 42.520439, longitude = 41.713372, display_name = "Zeni"},
    ["Zeni"] = { latitude = 42.384638, longitude = 41.968533, display_name = "Zeni"},
    ["Zeda-Etseri"] = { latitude = 42.585548, longitude = 41.920678, display_name = "Zeda-Etseri"},
    ["Zeda-Lia"] = { latitude = 42.676335, longitude = 42.023392, display_name = "Zeda-Lia"},
    ["Zaragula"] = { latitude = 42.627553, longitude = 42.712001, display_name = "Zaragula"},
    ["Zemo-ZHoshkha"] = { latitude = 42.586561, longitude = 42.952919, display_name = "Zemo-ZHoshkha"},
    ["Zogishi"] = { latitude = 42.554181, longitude = 42.841330, display_name = "Zogishi"},
    ["Zeda-Shavra"] = { latitude = 42.503286, longitude = 42.990015, display_name = "Zeda-Shavra"},
    ["Zubi"] = { latitude = 42.397134, longitude = 42.013864, display_name = "Zubi"},
    ["Zemo-Huntsi"] = { latitude = 42.407792, longitude = 42.426617, display_name = "Zemo-Huntsi"},
    ["Zarati"] = { latitude = 42.355384, longitude = 42.723736, display_name = "Zarati"},
    ["Zomleti"] = { latitude = 42.035595, longitude = 42.138993, display_name = "Zomleti"},
    ["Zemo-Aketi"] = { latitude = 42.046732, longitude = 42.099893, display_name = "Zemo-Aketi"},
    ["Zemo-"] = { latitude = 42.522736, longitude = 43.301035, display_name = "Zemo-"},
    ["Zeda-Kveda"] = { latitude = 42.341887, longitude = 43.488780, display_name = "Zeda-Kveda"},
    ["Zaarnadzeebi"] = { latitude = 42.256196, longitude = 43.012686, display_name = "Zaarnadzeebi"},
    ["Zeda-Beretisa"] = { latitude = 42.195126, longitude = 43.402533, display_name = "Zeda-Beretisa"},
    ["Vertkvichala"] = { latitude = 42.105803, longitude = 43.304873, display_name = "Vertkvichala"},
    ["Zedubani"] = { latitude = 41.962796, longitude = 43.310404, display_name = "Zedubani"},
    ["Zemo-Gumurishi"] = { latitude = 42.710482, longitude = 41.788429, display_name = "Zemo-Gumurishi"},
    ["Zeni"] = { latitude = 42.617798, longitude = 41.882572, display_name = "Zeni"},
    ["Zeni"] = { latitude = 42.565132, longitude = 41.819593, display_name = "Zeni"},
    ["Zeni"] = { latitude = 42.312676, longitude = 41.922268, display_name = "Zeni"},
    ["Zemo-Natanebi"] = { latitude = 41.963000, longitude = 41.870221, display_name = "Zemo-Natanebi"},
    ["Zeda-Dagva"] = { latitude = 41.754863, longitude = 41.807808, display_name = "Zeda-Dagva"},
    ["Zartsupa"] = { latitude = 42.493699, longitude = 41.644697, display_name = "Zartsupa"},
    ["ZHoneti"] = { latitude = 42.370197, longitude = 42.703253, display_name = "ZHoneti"},
    ["Zeda-Sameba"] = { latitude = 41.791274, longitude = 41.859312, display_name = "Zeda-Sameba"},
    ["Verhne-Nikolaevskoe"] = { latitude = 43.529614, longitude = 39.929520, display_name = "Verhne-Nikolaevskoe"},
    ["Verhne-Imeretinskaya Buhta"] = { latitude = 43.417052, longitude = 39.975434, display_name = "Verhne-Imeretinskaya Buhta"},
    ["Verhne-Armyanskoe Loo"] = { latitude = 43.739337, longitude = 39.617997, display_name = "Verhne-Armyanskoe Loo"},
    ["Verh.ZHemtala"] = { latitude = 43.236728, longitude = 43.669495, display_name = "Verh.ZHemtala"},
    ["Verh.Teberda"] = { latitude = 43.538315, longitude = 41.782876, display_name = "Verh.Teberda"},
    ["Verh.Mara"] = { latitude = 43.771537, longitude = 42.136894, display_name = "Verh.Mara"},
    ["Verh.Kurkuzhin"] = { latitude = 43.705952, longitude = 43.296825, display_name = "Verh.Kurkuzhin"},
    ["Verh.Chegem"] = { latitude = 43.240698, longitude = 43.134321, display_name = "Verh.Chegem"},
    ["Verh.Balkariya"] = { latitude = 43.131049, longitude = 43.456872, display_name = "Verh.Balkariya"},
    ["Verh.Baksan"] = { latitude = 43.309417, longitude = 42.750280, display_name = "Verh.Baksan"},
    ["Verevkin"] = { latitude = 45.220310, longitude = 40.354313, display_name = "Verevkin"},
    ["Velikovechnoe"] = { latitude = 44.936567, longitude = 39.749784, display_name = "Velikovechnoe"},
    ["Vazhnoe"] = { latitude = 43.992853, longitude = 41.940704, display_name = "Vazhnoe"},
    ["Vasil'evskiy"] = { latitude = 45.091406, longitude = 38.531103, display_name = "Vasil'evskiy"},
    ["Varvarovka"] = { latitude = 44.834052, longitude = 37.372957, display_name = "Varvarovka"},
    ["Vartsihe"] = { latitude = 42.144134, longitude = 42.718334, display_name = "Vartsihe"},
    ["Varnavinskoe"] = { latitude = 44.995514, longitude = 38.192444, display_name = "Varnavinskoe"},
    ["Varenikovskaya"] = { latitude = 45.120464, longitude = 37.634587, display_name = "Varenikovskaya"},
    ["Vardane"] = { latitude = 43.734603, longitude = 39.553328, display_name = "Vardane"},
    ["Vani"] = { latitude = 41.986843, longitude = 43.203182, display_name = "Vani"},
    ["Vani"] = { latitude = 42.048170, longitude = 42.149633, display_name = "Vani"},
    ["Vakidzhvari"] = { latitude = 41.915906, longitude = 42.141490, display_name = "Vakidzhvari"},
    ["Vachevi"] = { latitude = 42.319197, longitude = 43.198124, display_name = "Vachevi"},
    ["Utsera"] = { latitude = 42.633276, longitude = 43.538861, display_name = "Utsera"},
    ["Utash"] = { latitude = 45.097694, longitude = 37.319662, display_name = "Utash"},
    ["Usahelo"] = { latitude = 42.597293, longitude = 42.828361, display_name = "Usahelo"},
    ["Usahelo"] = { latitude = 42.232442, longitude = 43.371765, display_name = "Usahelo"},
    ["Urvani"] = { latitude = 42.642964, longitude = 43.282974, display_name = "Urvani"},
    ["Urvan'"] = { latitude = 43.490777, longitude = 43.764370, display_name = "Urvan'"},
    ["Urup"] = { latitude = 43.846970, longitude = 41.152495, display_name = "Urup"},
    ["Uruhskaya"] = { latitude = 44.153716, longitude = 43.669649, display_name = "Uruhskaya"},
    ["Urta"] = { latitude = 42.430754, longitude = 41.841157, display_name = "Urta"},
    ["Urozhaynyy"] = { latitude = 44.116948, longitude = 42.762639, display_name = "Urozhaynyy"},
    ["Ureki"] = { latitude = 41.994268, longitude = 41.778543, display_name = "Ureki"},
    ["Ulyap"] = { latitude = 45.055071, longitude = 39.950905, display_name = "Ulyap"},
    ["Uluria"] = { latitude = 42.585800, longitude = 42.113808, display_name = "Uluria"},
    ["Ul'yanovka"] = { latitude = 44.303471, longitude = 42.927167, display_name = "Ul'yanovka"},
    ["Ukrainskiy"] = { latitude = 45.254040, longitude = 39.354076, display_name = "Ukrainskiy"},
    ["Ukanava"] = { latitude = 41.934585, longitude = 42.186210, display_name = "Ukanava"},
    ["Uhuti"] = { latitude = 42.040771, longitude = 42.683152, display_name = "Uhuti"},
    ["Udobnaya"] = { latitude = 44.214925, longitude = 41.562212, display_name = "Udobnaya"},
    ["Uchkulan"] = { latitude = 43.455180, longitude = 42.087454, display_name = "Uchkulan"},
    ["Uchashona"] = { latitude = 42.493247, longitude = 41.924453, display_name = "Uchashona"},
    ["Ubisi"] = { latitude = 42.098775, longitude = 43.226444, display_name = "Ubisi"},
    ["Ubinskaya"] = { latitude = 44.737000, longitude = 38.541069, display_name = "Ubinskaya"},
    ["Uazabaa"] = { latitude = 43.054593, longitude = 40.976749, display_name = "Uazabaa"},
    ["Tyumenskiy"] = { latitude = 44.182244, longitude = 38.972674, display_name = "Tyumenskiy"},
    ["Tvrini"] = { latitude = 42.073237, longitude = 43.072609, display_name = "Tvrini"},
    ["Tvishi"] = { latitude = 42.515837, longitude = 42.788506, display_name = "Tvishi"},
    ["Tverskaya"] = { latitude = 44.604805, longitude = 39.610687, display_name = "Tverskaya"},
    ["Tvalueti"] = { latitude = 42.227705, longitude = 43.268895, display_name = "Tvalueti"},
    ["Tuzi"] = { latitude = 42.272471, longitude = 43.110811, display_name = "Tuzi"},
    ["Tsvirmi"] = { latitude = 43.017141, longitude = 42.801118, display_name = "Tsvirmi"},
    ["Tsvane"] = { latitude = 42.370055, longitude = 41.654112, display_name = "Tsvane"},
    ["Tsutshvati"] = { latitude = 42.289077, longitude = 42.860776, display_name = "Tsutshvati"},
    ["Tskrysh"] = { latitude = 42.782967, longitude = 41.373482, display_name = "Tskrysh"},
    ["Tsknori"] = { latitude = 42.402082, longitude = 42.890375, display_name = "Tsknori"},
    ["Tskemi"] = { latitude = 42.269262, longitude = 42.174364, display_name = "Tskemi"},
    ["Tskavroka"] = { latitude = 41.859784, longitude = 41.888202, display_name = "Tskavroka"},
    ["Tskaltsminda"] = { latitude = 42.011212, longitude = 41.778545, display_name = "Tskaltsminda"},
    ["Tskaltashua"] = { latitude = 42.022671, longitude = 42.828904, display_name = "Tskaltashua"},
    ["Tskalshavi"] = { latitude = 42.219307, longitude = 43.341725, display_name = "Tskalshavi"},
    ["Tskalaporeti"] = { latitude = 42.031419, longitude = 43.078673, display_name = "Tskalaporeti"},
    ["Tsipnara"] = { latitude = 42.024010, longitude = 42.293819, display_name = "Tsipnara"},
    ["Tsipnagvara"] = { latitude = 41.955727, longitude = 42.224549, display_name = "Tsipnagvara"},
    ["Tsiperchi"] = { latitude = 42.603636, longitude = 42.695129, display_name = "Tsiperchi"},
    ["Tsipa"] = { latitude = 42.046461, longitude = 42.949247, display_name = "Tsipa"},
    ["Tsipa"] = { latitude = 42.009347, longitude = 43.451125, display_name = "Tsipa"},
    ["Tsihisdziri"] = { latitude = 41.772133, longitude = 41.762802, display_name = "Tsihisdziri"},
    ["Tsibanobalka"] = { latitude = 44.982008, longitude = 37.342091, display_name = "Tsibanobalka"},
    ["Tshunkuri"] = { latitude = 42.396804, longitude = 42.570436, display_name = "Tshunkuri"},
    ["Tshmori"] = { latitude = 42.536955, longitude = 43.478057, display_name = "Tshmori"},
    ["Tshentaro"] = { latitude = 42.147873, longitude = 42.837507, display_name = "Tshentaro"},
    ["Tshenis-Tskali"] = { latitude = 42.796462, longitude = 41.419871, display_name = "Tshenis-Tskali"},
    ["Tshemlishidi"] = { latitude = 41.921541, longitude = 42.071692, display_name = "Tshemlishidi"},
    ["Tshami"] = { latitude = 42.291453, longitude = 43.510570, display_name = "Tshami"},
    ["Tsesi"] = { latitude = 42.542767, longitude = 43.196616, display_name = "Tsesi"},
    ["Tsedisi"] = { latitude = 42.532887, longitude = 43.548207, display_name = "Tsedisi"},
    ["Tsebel'da"] = { latitude = 43.022159, longitude = 41.269029, display_name = "Tsebel'da"},
    ["Tsatshvi"] = { latitude = 42.414906, longitude = 41.789573, display_name = "Tsatshvi"},
    ["Tsalkoti"] = { latitude = 43.407001, longitude = 40.052620, display_name = "Tsalkoti"},
    ["Tsaishi"] = { latitude = 42.431382, longitude = 41.803488, display_name = "Tsaishi"},
    ["Tsahi"] = { latitude = 42.526030, longitude = 42.922673, display_name = "Tsahi"},
    ["Trudobelikovskiy"] = { latitude = 45.285178, longitude = 38.142705, display_name = "Trudobelikovskiy"},
    ["Travlev"] = { latitude = 44.370687, longitude = 39.537629, display_name = "Travlev"},
    ["Tolebi"] = { latitude = 42.074187, longitude = 42.240400, display_name = "Tolebi"},
    ["Tkviri"] = { latitude = 42.169336, longitude = 42.246736, display_name = "Tkviri"},
    ["Tklapivake"] = { latitude = 42.172575, longitude = 43.068294, display_name = "Tklapivake"},
    ["Tkelvani"] = { latitude = 42.047842, longitude = 42.551287, display_name = "Tkelvani"},
    ["Tkaya"] = { latitude = 42.622523, longitude = 41.928621, display_name = "Tkaya"},
    ["Tkachiri"] = { latitude = 42.142229, longitude = 42.632747, display_name = "Tkachiri"},
    ["Tihovskiy"] = { latitude = 45.194706, longitude = 38.218835, display_name = "Tihovskiy"},
    ["Thmelari"] = { latitude = 42.145418, longitude = 42.263166, display_name = "Thmelari"},
    ["Thina"] = { latitude = 42.881268, longitude = 41.544684, display_name = "Thina"},
    ["Thilnari"] = { latitude = 41.569953, longitude = 41.647305, display_name = "Thilnari"},
    ["Teuchezhkhabl'"] = { latitude = 44.931656, longitude = 39.562499, display_name = "Teuchezhkhabl'"},
    ["Tenginskaya"] = { latitude = 45.100953, longitude = 40.008266, display_name = "Tenginskaya"},
    ["Tenginka"] = { latitude = 44.328982, longitude = 38.783412, display_name = "Tenginka"},
    ["Telmani"] = { latitude = 42.041496, longitude = 42.055072, display_name = "Telmani"},
    ["Telepa"] = { latitude = 42.199325, longitude = 43.013716, display_name = "Telepa"},
    ["Teklati"] = { latitude = 42.253536, longitude = 42.009190, display_name = "Teklati"},
    ["Taya"] = { latitude = 42.610109, longitude = 42.213082, display_name = "Taya"},
    ["Tavisupleba"] = { latitude = 43.041709, longitude = 41.016536, display_name = "Tavisupleba"},
    ["Tavasa"] = { latitude = 42.275571, longitude = 43.082456, display_name = "Tavasa"},
    ["Tashly-Tala"] = { latitude = 43.146908, longitude = 43.697247, display_name = "Tashly-Tala"},
    ["Tambukan"] = { latitude = 43.932197, longitude = 43.142965, display_name = "Tambukan"},
    ["Tamanskiy"] = { latitude = 45.150180, longitude = 36.782611, display_name = "Tamanskiy"},
    ["Taman'"] = { latitude = 45.211080, longitude = 36.712001, display_name = "Taman'"},
    ["Tamakoni"] = { latitude = 42.458194, longitude = 42.305573, display_name = "Tamakoni"},
    ["Tallyk"] = { latitude = 44.153193, longitude = 42.343567, display_name = "Tallyk"},
    ["Tahtamukay"] = { latitude = 44.922632, longitude = 38.994206, display_name = "Tahtamukay"},
    ["Tagiloni"] = { latitude = 42.547563, longitude = 41.772461, display_name = "Tagiloni"},
    ["Tabori"] = { latitude = 42.605990, longitude = 42.892410, display_name = "Tabori"},
    ["Tabakini"] = { latitude = 42.065905, longitude = 43.036069, display_name = "Tabakini"},
    ["Tabagrebi"] = { latitude = 42.328721, longitude = 43.275940, display_name = "Tabagrebi"},
    ["Tabachnyy"] = { latitude = 44.556422, longitude = 40.091093, display_name = "Tabachnyy"},
    ["Svoboda"] = { latitude = 44.155825, longitude = 42.768210, display_name = "Svoboda"},
    ["svh.Tagrskiy"] = { latitude = 43.199276, longitude = 40.284213, display_name = "svh.Tagrskiy"},
    ["svh.Nasakirali"] = { latitude = 41.970377, longitude = 42.020224, display_name = "svh.Nasakirali"},
    ["svh.Kohora"] = { latitude = 42.659065, longitude = 41.708095, display_name = "svh.Kohora"},
    ["svh.Horshi"] = { latitude = 42.341095, longitude = 42.035080, display_name = "svh.Horshi"},
    ["svh.Didi-Chkonskiy"] = { latitude = 42.539708, longitude = 42.290066, display_name = "svh.Didi-Chkonskiy"},
    ["svh.Ahalsopeli"] = { latitude = 42.249177, longitude = 41.857919, display_name = "svh.Ahalsopeli"},
    ["Svetlyy Put' Lenina"] = { latitude = 45.208583, longitude = 37.656995, display_name = "Svetlyy Put' Lenina"},
    ["Svetlovodskoe"] = { latitude = 43.896544, longitude = 43.180565, display_name = "Svetlovodskoe"},
    ["Sveri"] = { latitude = 42.226188, longitude = 43.303560, display_name = "Sveri"},
    ["Suzdal'skaya"] = { latitude = 44.766994, longitude = 39.368694, display_name = "Suzdal'skaya"},
    ["Suvorovskoe"] = { latitude = 45.286566, longitude = 39.460538, display_name = "Suvorovskoe"},
    ["Suvorovskaya"] = { latitude = 44.187846, longitude = 42.658805, display_name = "Suvorovskaya"},
    ["Suvorov-Cherkesskiy"] = { latitude = 45.069861, longitude = 37.271582, display_name = "Suvorov-Cherkesskiy"},
    ["Surmushi"] = { latitude = 42.592088, longitude = 42.878475, display_name = "Surmushi"},
    ["Supseh"] = { latitude = 44.861146, longitude = 37.364340, display_name = "Supseh"},
    ["Supovskiy"] = { latitude = 44.902356, longitude = 38.942116, display_name = "Supovskiy"},
    ["Sulori"] = { latitude = 42.025049, longitude = 42.577617, display_name = "Sulori"},
    ["Sukko"] = { latitude = 44.798695, longitude = 37.420789, display_name = "Sukko"},
    ["Suhoy Kut"] = { latitude = 45.127745, longitude = 40.207372, display_name = "Suhoy Kut"},
    ["Suhcha"] = { latitude = 42.417076, longitude = 42.468544, display_name = "Suhcha"},
    ["Sudzhuna"] = { latitude = 42.200960, longitude = 42.146446, display_name = "Sudzhuna"},
    ["Strelka"] = { latitude = 45.204296, longitude = 37.286910, display_name = "Strelka"},
    ["Storozhevaya"] = { latitude = 43.883112, longitude = 41.453295, display_name = "Storozhevaya"},
    ["Stavropol'skaya"] = { latitude = 44.718327, longitude = 38.825185, display_name = "Stavropol'skaya"},
    ["Starotitarovskaya"] = { latitude = 45.219384, longitude = 37.161638, display_name = "Starotitarovskaya"},
    ["Staropavlovskaya"] = { latitude = 43.846862, longitude = 43.635628, display_name = "Staropavlovskaya"},
    ["Starokorsunskaya"] = { latitude = 45.056256, longitude = 39.314748, display_name = "Starokorsunskaya"},
    ["Starobzhegokay"] = { latitude = 45.037835, longitude = 38.890909, display_name = "Starobzhegokay"},
    ["Star.Cherek"] = { latitude = 43.474391, longitude = 43.858173, display_name = "Star.Cherek"},
    ["Stantsionnyy"] = { latitude = 44.438859, longitude = 39.474111, display_name = "Stantsionnyy"},
    ["Spokoynaya"] = { latitude = 44.259312, longitude = 41.390173, display_name = "Spokoynaya"},
    ["Speti"] = { latitude = 42.322001, longitude = 43.523397, display_name = "Speti"},
    ["Spatagori"] = { latitude = 42.612449, longitude = 42.820431, display_name = "Spatagori"},
    ["Sovhoznyy"] = { latitude = 44.543971, longitude = 40.152743, display_name = "Sovhoznyy"},
    ["Sovhoznyy"] = { latitude = 45.297970, longitude = 38.106763, display_name = "Sovhoznyy"},
    ["Sovhoznoe"] = { latitude = 43.803855, longitude = 43.147584, display_name = "Sovhoznoe"},
    ["Sormoni"] = { latitude = 42.320448, longitude = 42.736131, display_name = "Sormoni"},
    ["Soloniki"] = { latitude = 43.884949, longitude = 39.378103, display_name = "Soloniki"},
    ["Solenoe"] = { latitude = 44.044307, longitude = 40.872960, display_name = "Solenoe"},
    ["Soldatskaya"] = { latitude = 43.812310, longitude = 43.823078, display_name = "Soldatskaya"},
    ["Soglasnyy"] = { latitude = 45.237391, longitude = 39.975613, display_name = "Soglasnyy"},
    ["Sochkheti"] = { latitude = 42.395196, longitude = 42.910288, display_name = "Sochkheti"},
    ["Smolenskaya"] = { latitude = 44.786688, longitude = 38.800768, display_name = "Smolenskaya"},
    ["Skurdi"] = { latitude = 42.476765, longitude = 42.368497, display_name = "Skurdi"},
    ["Skura"] = { latitude = 41.866696, longitude = 41.925186, display_name = "Skura"},
    ["Skindori"] = { latitude = 42.242029, longitude = 43.249227, display_name = "Skindori"},
    ["Sinegorsk"] = { latitude = 44.775835, longitude = 38.338404, display_name = "Sinegorsk"},
    ["Simoneti"] = { latitude = 42.238107, longitude = 42.912135, display_name = "Simoneti"},
    ["Siktarva"] = { latitude = 42.192302, longitude = 42.940934, display_name = "Siktarva"},
    ["Sida"] = { latitude = 42.570767, longitude = 41.712233, display_name = "Sida"},
    ["Shuntuk"] = { latitude = 44.455608, longitude = 40.164758, display_name = "Shuntuk"},
    ["Shuamta"] = { latitude = 42.097609, longitude = 42.451121, display_name = "Shuamta"},
    ["Shua-shvava"] = { latitude = 42.501499, longitude = 43.221855, display_name = "Shua-shvava"},
    ["Shua-Nosiri"] = { latitude = 42.280291, longitude = 42.094655, display_name = "Shua-Nosiri"},
    ["Shua-Gubi"] = { latitude = 42.261628, longitude = 42.466473, display_name = "Shua-Gubi"},
    ["Shua-Gezruli"] = { latitude = 42.153417, longitude = 43.219613, display_name = "Shua-Gezruli"},
    ["Shua-Bashi"] = { latitude = 42.143434, longitude = 42.493907, display_name = "Shua-Bashi"},
    ["Shturbino"] = { latitude = 45.054728, longitude = 39.912252, display_name = "Shturbino"},
    ["Shrosha"] = { latitude = 42.115040, longitude = 43.179695, display_name = "Shrosha"},
    ["Shromiskari"] = { latitude = 42.358092, longitude = 42.116093, display_name = "Shromiskari"},
    ["Shroma"] = { latitude = 42.522152, longitude = 43.061884, display_name = "Shroma"},
    ["Shroma"] = { latitude = 43.082720, longitude = 41.035309, display_name = "Shroma"},
    ["Shovgenovskiy"] = { latitude = 45.021933, longitude = 40.235745, display_name = "Shovgenovskiy"},
    ["Shomaheti"] = { latitude = 42.214857, longitude = 43.428888, display_name = "Shomaheti"},
    ["Shkol'nyy"] = { latitude = 45.034098, longitude = 37.615478, display_name = "Shkol'nyy"},
    ["Shkol'noe"] = { latitude = 44.916928, longitude = 39.856176, display_name = "Shkol'noe"},
    ["Shitskvara"] = { latitude = 43.070784, longitude = 40.927797, display_name = "Shitskvara"},
    ["Shithala"] = { latitude = 43.555555, longitude = 43.798022, display_name = "Shithala"},
    ["Shirvanskaya"] = { latitude = 44.380256, longitude = 39.807018, display_name = "Shirvanskaya"},
    ["Shirokaya Balka"] = { latitude = 44.487080, longitude = 39.412907, display_name = "Shirokaya Balka"},
    ["Shevchenko"] = { latitude = 44.899509, longitude = 39.516976, display_name = "Shevchenko"},
    ["Shepsi"] = { latitude = 44.038265, longitude = 39.141680, display_name = "Shepsi"},
    ["Shendzhiy"] = { latitude = 44.887778, longitude = 39.060568, display_name = "Shendzhiy"},
    ["Shedok"] = { latitude = 44.221288, longitude = 40.837051, display_name = "Shedok"},
    ["Shaumyanskiy"] = { latitude = 44.163229, longitude = 43.539348, display_name = "Shaumyanskiy"},
    ["Shaumyan"] = { latitude = 44.323123, longitude = 39.290108, display_name = "Shaumyan"},
    ["Shardakovo"] = { latitude = 43.879279, longitude = 43.102586, display_name = "Shardakovo"},
    ["Shamgona"] = { latitude = 42.521753, longitude = 41.769134, display_name = "Shamgona"},
    ["Shalushka"] = { latitude = 43.530601, longitude = 43.568470, display_name = "Shalushka"},
    ["Shahe"] = { latitude = 43.789565, longitude = 39.474887, display_name = "Shahe"},
    ["Severskaya"] = { latitude = 44.854150, longitude = 38.678560, display_name = "Severskaya"},
    ["Severnyy"] = { latitude = 44.658857, longitude = 40.117073, display_name = "Severnyy"},
    ["Sevastopol'skaya"] = { latitude = 44.354847, longitude = 40.303966, display_name = "Sevastopol'skaya"},
    ["Seva"] = { latitude = 42.555444, longitude = 43.351597, display_name = "Seva"},
    ["Sergieti"] = { latitude = 42.391498, longitude = 42.323468, display_name = "Sergieti"},
    ["Sepieti"] = { latitude = 42.281965, longitude = 42.243453, display_name = "Sepieti"},
    ["Sennoy"] = { latitude = 45.294518, longitude = 36.989450, display_name = "Sennoy"},
    ["Semisvodnyy"] = { latitude = 45.300754, longitude = 37.969587, display_name = "Semisvodnyy"},
    ["Schastlivoe"] = { latitude = 44.164789, longitude = 42.271165, display_name = "Schastlivoe"},
    ["Sazano"] = { latitude = 42.218143, longitude = 43.062941, display_name = "Sazano"},
    ["Savane"] = { latitude = 42.315460, longitude = 43.467280, display_name = "Savane"},
    ["Saukdere"] = { latitude = 44.903911, longitude = 37.885750, display_name = "Saukdere"},
    ["Satkebuchao"] = { latitude = 42.402993, longitude = 42.058518, display_name = "Satkebuchao"},
    ["Sashamugio"] = { latitude = 42.580189, longitude = 41.658063, display_name = "Sashamugio"},
    ["Sasashi"] = { latitude = 42.800320, longitude = 42.978569, display_name = "Sasashi"},
    ["Sary-Tyuz"] = { latitude = 43.902060, longitude = 41.893315, display_name = "Sary-Tyuz"},
    ["Sarmakovo"] = { latitude = 43.741446, longitude = 43.196640, display_name = "Sarmakovo"},
    ["Sareki"] = { latitude = 42.330518, longitude = 43.359819, display_name = "Sareki"},
    ["Saratovskiy"] = { latitude = 45.212657, longitude = 39.980321, display_name = "Saratovskiy"},
    ["Saratovskiy"] = { latitude = 45.101815, longitude = 39.762800, display_name = "Saratovskiy"},
    ["Saratovskaya"] = { latitude = 44.711278, longitude = 39.218458, display_name = "Saratovskaya"},
    ["Sarakoni"] = { latitude = 42.503838, longitude = 42.058830, display_name = "Sarakoni"},
    ["Saprasia"] = { latitude = 42.037612, longitude = 42.645146, display_name = "Saprasia"},
    ["Saodishario"] = { latitude = 42.246902, longitude = 42.114695, display_name = "Saodishario"},
    ["San.Im.Lenina"] = { latitude = 42.926139, longitude = 41.115398, display_name = "San.Im.Lenina"},
    ["Samikao"] = { latitude = 42.263550, longitude = 42.296038, display_name = "Samikao"},
    ["Samelalio"] = { latitude = 42.707453, longitude = 41.749466, display_name = "Samelalio"},
    ["Salominao"] = { latitude = 42.088135, longitude = 42.719745, display_name = "Salominao"},
    ["Salieti"] = { latitude = 42.271758, longitude = 43.209060, display_name = "Salieti"},
    ["Salhino"] = { latitude = 43.486466, longitude = 40.054114, display_name = "Salhino"},
    ["Salhino"] = { latitude = 42.515468, longitude = 42.341970, display_name = "Salhino"},
    ["Sal'me"] = { latitude = 43.427666, longitude = 40.024911, display_name = "Sal'me"},
    ["Sakulia"] = { latitude = 42.134432, longitude = 42.561555, display_name = "Sakulia"},
    ["Sakraula"] = { latitude = 42.031286, longitude = 42.984628, display_name = "Sakraula"},
    ["Saketsia"] = { latitude = 42.529619, longitude = 43.087889, display_name = "Saketsia"},
    ["Sairhe"] = { latitude = 42.313435, longitude = 43.408683, display_name = "Sairhe"},
    ["Sagvichio"] = { latitude = 42.213265, longitude = 41.874584, display_name = "Sagvichio"},
    ["Sagvamichavo"] = { latitude = 42.228483, longitude = 41.827094, display_name = "Sagvamichavo"},
    ["Saeliavo"] = { latitude = 42.437401, longitude = 42.387708, display_name = "Saeliavo"},
    ["Sadovyy"] = { latitude = 45.319973, longitude = 38.053711, display_name = "Sadovyy"},
    ["Sadovyy"] = { latitude = 44.227462, longitude = 43.195699, display_name = "Sadovyy"},
    ["Sadovyy"] = { latitude = 45.018190, longitude = 37.747990, display_name = "Sadovyy"},
    ["Sadovoe"] = { latitude = 45.003356, longitude = 39.693078, display_name = "Sadovoe"},
    ["Sadovoe"] = { latitude = 44.332447, longitude = 42.038087, display_name = "Sadovoe"},
    ["Sadovoe"] = { latitude = 44.018527, longitude = 42.972176, display_name = "Sadovoe"},
    ["Sadmeli"] = { latitude = 42.540139, longitude = 43.114993, display_name = "Sadmeli"},
    ["Sachochuo"] = { latitude = 42.209857, longitude = 41.766596, display_name = "Sachochuo"},
    ["Sachino"] = { latitude = 42.647290, longitude = 42.083729, display_name = "Sachino"},
    ["Sabuliskerio"] = { latitude = 42.675257, longitude = 41.675785, display_name = "Sabuliskerio"},
    ["Saberio"] = { latitude = 42.645920, longitude = 41.907494, display_name = "Saberio"},
    ["Sabe"] = { latitude = 42.046961, longitude = 43.251094, display_name = "Sabe"},
    ["Sabazho"] = { latitude = 42.222720, longitude = 41.798622, display_name = "Sabazho"},
    ["Ryazanskaya"] = { latitude = 44.961990, longitude = 39.578809, display_name = "Ryazanskaya"},
    ["Russkoe"] = { latitude = 44.961940, longitude = 37.836869, display_name = "Russkoe"},
    ["Russkaya Mamayka"] = { latitude = 43.650247, longitude = 39.714431, display_name = "Russkaya Mamayka"},
    ["Ruhi"] = { latitude = 42.544316, longitude = 41.847535, display_name = "Ruhi"},
    ["Rtshilati"] = { latitude = 42.325175, longitude = 43.134800, display_name = "Rtshilati"},
    ["Roschinskiy"] = { latitude = 44.383885, longitude = 42.148785, display_name = "Roschinskiy"},
    ["Rohi"] = { latitude = 42.107479, longitude = 42.706407, display_name = "Rohi"},
    ["Rodnikovyy"] = { latitude = 44.683532, longitude = 39.999878, display_name = "Rodnikovyy"},
    ["Rodniki"] = { latitude = 44.740312, longitude = 39.912532, display_name = "Rodniki"},
    ["Rodinauli"] = { latitude = 42.150130, longitude = 42.871330, display_name = "Rodinauli"},
    ["Rioni"] = { latitude = 42.332956, longitude = 42.714852, display_name = "Rioni"},
    ["Rim-Gorskiy"] = { latitude = 43.958096, longitude = 42.524108, display_name = "Rim-Gorskiy"},
    ["Rike"] = { latitude = 42.588840, longitude = 41.890551, display_name = "Rike"},
    ["Repo-Etseri"] = { latitude = 42.631793, longitude = 41.658992, display_name = "Repo-Etseri"},
    ["Rechkhi"] = { latitude = 42.659807, longitude = 41.747882, display_name = "Rechkhi"},
    ["Razdol'noe"] = { latitude = 43.592801, longitude = 39.798031, display_name = "Razdol'noe"},
    ["Rassvet"] = { latitude = 44.898001, longitude = 37.454519, display_name = "Rassvet"},
    ["Raevskaya"] = { latitude = 44.835329, longitude = 37.559541, display_name = "Raevskaya"},
    ["Pyatihatki"] = { latitude = 44.976064, longitude = 37.304959, display_name = "Pyatihatki"},
    ["Pyatigorskiy"] = { latitude = 43.974984, longitude = 43.261010, display_name = "Pyatigorskiy"},
    ["Psyzh"] = { latitude = 44.241128, longitude = 42.022016, display_name = "Psyzh"},
    ["Psyrtsha"] = { latitude = 43.087430, longitude = 40.879180, display_name = "Psyrtsha"},
    ["Psynshoko"] = { latitude = 43.758797, longitude = 43.716771, display_name = "Psynshoko"},
    ["Psynodaha"] = { latitude = 43.861800, longitude = 43.244666, display_name = "Psynodaha"},
    ["Psyhurey"] = { latitude = 43.838650, longitude = 43.577387, display_name = "Psyhurey"},
    ["Psygansu"] = { latitude = 43.415515, longitude = 43.789113, display_name = "Psygansu"},
    ["Psychoh"] = { latitude = 43.718672, longitude = 43.525482, display_name = "Psychoh"},
    ["Pshizov"] = { latitude = 45.095471, longitude = 40.104028, display_name = "Pshizov"},
    ["Pshicho"] = { latitude = 45.066198, longitude = 40.173833, display_name = "Pshicho"},
    ["Pshehskaya"] = { latitude = 44.698485, longitude = 39.790475, display_name = "Pshehskaya"},
    ["Pshap"] = { latitude = 42.900098, longitude = 41.103230, display_name = "Pshap"},
    ["Pseytuh"] = { latitude = 45.053705, longitude = 38.704020, display_name = "Pseytuh"},
    ["Psemen"] = { latitude = 43.983633, longitude = 40.975741, display_name = "Psemen"},
    ["Psekups"] = { latitude = 44.835444, longitude = 39.207383, display_name = "Psekups"},
    ["Psauch'e-Dahe"] = { latitude = 44.215163, longitude = 41.879390, display_name = "Psauch'e-Dahe"},
    ["Protichka"] = { latitude = 45.378976, longitude = 38.070425, display_name = "Protichka"},
    ["Proletarskiy"] = { latitude = 44.619952, longitude = 40.181767, display_name = "Proletarskiy"},
    ["Progress"] = { latitude = 43.818331, longitude = 43.335369, display_name = "Progress"},
    ["Progress"] = { latitude = 44.871644, longitude = 40.189500, display_name = "Progress"},
    ["Privol'noe"] = { latitude = 44.006071, longitude = 42.941312, display_name = "Privol'noe"},
    ["Prirechnoe"] = { latitude = 43.803274, longitude = 43.305037, display_name = "Prirechnoe"},
    ["Prirechenskiy"] = { latitude = 44.755341, longitude = 39.241202, display_name = "Prirechenskiy"},
    ["Primorskoe"] = { latitude = 43.094709, longitude = 40.704462, display_name = "Primorskoe"},
    ["Primorskiy"] = { latitude = 45.264384, longitude = 36.909279, display_name = "Primorskiy"},
    ["Prikubanskiy"] = { latitude = 44.958409, longitude = 39.027413, display_name = "Prikubanskiy"},
    ["Prikubanskie hutora"] = { latitude = 45.161087, longitude = 38.072122, display_name = "Prikubanskie hutora"},
    ["Prigorodnyy"] = { latitude = 44.124347, longitude = 39.118629, display_name = "Prigorodnyy"},
    ["Prigorodnoe"] = { latitude = 44.238742, longitude = 42.120034, display_name = "Prigorodnoe"},
    ["Preobrazhenskoe"] = { latitude = 45.087444, longitude = 39.623111, display_name = "Preobrazhenskoe"},
    ["Pregradnaya"] = { latitude = 43.951487, longitude = 41.184826, display_name = "Pregradnaya"},
    ["Pravokubanskiy"] = { latitude = 43.919953, longitude = 41.883161, display_name = "Pravokubanskiy"},
    ["Potsho"] = { latitude = 42.432617, longitude = 42.167673, display_name = "Potsho"},
    ["Ponezhukay"] = { latitude = 44.891919, longitude = 39.381016, display_name = "Ponezhukay"},
    ["Pokvesh"] = { latitude = 42.797212, longitude = 41.568194, display_name = "Pokvesh"},
    ["Pokrovskiy"] = { latitude = 45.111818, longitude = 38.415735, display_name = "Pokrovskiy"},
    ["Podkumok"] = { latitude = 43.970835, longitude = 42.775149, display_name = "Podkumok"},
    ["Podgornyy"] = { latitude = 44.692614, longitude = 40.083808, display_name = "Podgornyy"},
    ["Podgornaya"] = { latitude = 44.214940, longitude = 41.283165, display_name = "Podgornaya"},
    ["Pobegaylovka"] = { latitude = 44.241492, longitude = 43.014814, display_name = "Pobegaylovka"},
    ["Plavnenskiy"] = { latitude = 45.036542, longitude = 37.930622, display_name = "Plavnenskiy"},
    ["Plastunovskaya"] = { latitude = 45.296667, longitude = 39.265353, display_name = "Plastunovskaya"},
    ["Plastunka"] = { latitude = 43.671607, longitude = 39.761316, display_name = "Plastunka"},
    ["Pitsargali"] = { latitude = 42.533189, longitude = 41.596891, display_name = "Pitsargali"},
    ["Pirveli-Tola"] = { latitude = 42.573555, longitude = 42.984611, display_name = "Pirveli-Tola"},
    ["Pirveli-Sviri"] = { latitude = 42.106504, longitude = 42.960607, display_name = "Pirveli-Sviri"},
    ["Pirveli-Ontopo"] = { latitude = 42.250454, longitude = 42.246871, display_name = "Pirveli-Ontopo"},
    ["Pirveli-Obcha"] = { latitude = 42.097058, longitude = 42.857916, display_name = "Pirveli-Obcha"},
    ["Pirveli-Maisi"] = { latitude = 42.101253, longitude = 43.085303, display_name = "Pirveli-Maisi"},
    ["Pirveli-Gurdzemi"] = { latitude = 42.469479, longitude = 42.265483, display_name = "Pirveli-Gurdzemi"},
    ["Pirveli-Gudava"] = { latitude = 42.662997, longitude = 41.558282, display_name = "Pirveli-Gudava"},
    ["Pirveli-Etseri"] = { latitude = 42.183070, longitude = 42.158404, display_name = "Pirveli-Etseri"},
    ["Pirveli-Choga"] = { latitude = 42.574126, longitude = 42.198176, display_name = "Pirveli-Choga"},
    ["Pirveli-Akvaga"] = { latitude = 42.602194, longitude = 41.772756, display_name = "Pirveli-Akvaga"},
    ["Pervorechenskoe"] = { latitude = 45.164385, longitude = 39.308994, display_name = "Pervorechenskoe"},
    ["Pervomayskiy"] = { latitude = 45.180051, longitude = 38.305376, display_name = "Pervomayskiy"},
    ["Pervomayskiy"] = { latitude = 44.897833, longitude = 39.739162, display_name = "Pervomayskiy"},
    ["Pervomayskiy"] = { latitude = 44.694004, longitude = 39.306035, display_name = "Pervomayskiy"},
    ["Pervomayskiy"] = { latitude = 44.408531, longitude = 40.186120, display_name = "Pervomayskiy"},
    ["Perveli-Ohurey"] = { latitude = 42.736365, longitude = 41.575883, display_name = "Perveli-Ohurey"},
    ["Persati"] = { latitude = 42.068078, longitude = 42.788478, display_name = "Persati"},
    ["Perevisa"] = { latitude = 42.260370, longitude = 43.294406, display_name = "Perevisa"},
    ["Perevalka"] = { latitude = 44.053160, longitude = 40.756944, display_name = "Perevalka"},
    ["Pereta"] = { latitude = 42.062818, longitude = 42.715368, display_name = "Pereta"},
    ["Peredovaya"] = { latitude = 44.119929, longitude = 41.476287, display_name = "Peredovaya"},
    ["Pchegatlukay"] = { latitude = 44.888976, longitude = 39.262451, display_name = "Pchegatlukay"},
    ["Pavlovskoe"] = { latitude = 43.067519, longitude = 41.114584, display_name = "Pavlovskoe"},
    ["Pavlovskiy"] = { latitude = 45.078137, longitude = 37.772047, display_name = "Pavlovskiy"},
    ["Patriketi"] = { latitude = 42.156221, longitude = 42.656848, display_name = "Patriketi"},
    ["Patara-Poti"] = { latitude = 42.190478, longitude = 41.731759, display_name = "Patara-Poti"},
    ["Patara-Oni"] = { latitude = 42.535801, longitude = 42.981056, display_name = "Patara-Oni"},
    ["Patara-Dzhihaishi"] = { latitude = 42.284101, longitude = 42.404035, display_name = "Patara-Dzhihaishi"},
    ["Partshnali"] = { latitude = 42.007781, longitude = 43.124335, display_name = "Partshnali"},
    ["Partshanakanevi"] = { latitude = 42.207220, longitude = 42.557555, display_name = "Partshanakanevi"},
    ["Partonohori"] = { latitude = 42.651198, longitude = 41.861593, display_name = "Partonohori"},
    ["Paraheti"] = { latitude = 42.553093, longitude = 43.320122, display_name = "Paraheti"},
    ["Panahes"] = { latitude = 44.987973, longitude = 38.713089, display_name = "Panahes"},
    ["Pahulani"] = { latitude = 42.654425, longitude = 41.989393, display_name = "Pahulani"},
    ["Otradnyy"] = { latitude = 44.874473, longitude = 38.952471, display_name = "Otradnyy"},
    ["Otradnoe"] = { latitude = 43.265661, longitude = 40.288506, display_name = "Otradnoe"},
    ["otd.N3 SKZNIISiV"] = { latitude = 45.136100, longitude = 38.965099, display_name = "otd.N3 SKZNIISiV"},
    ["Ostrovskaya Shel'"] = { latitude = 44.278869, longitude = 39.291550, display_name = "Ostrovskaya Shel'"},
    ["Ostrogorka"] = { latitude = 44.123258, longitude = 42.979051, display_name = "Ostrogorka"},
    ["Orsantia"] = { latitude = 42.470203, longitude = 41.669408, display_name = "Orsantia"},
    ["Orpiri"] = { latitude = 42.332106, longitude = 42.817570, display_name = "Orpiri"},
    ["Orlovka"] = { latitude = 43.990864, longitude = 43.777097, display_name = "Orlovka"},
    ["Orka"] = { latitude = 42.308786, longitude = 42.246602, display_name = "Orka"},
    ["Orhvi"] = { latitude = 42.506220, longitude = 42.801449, display_name = "Orhvi"},
    ["Orel "] = { latitude = 43.461316, longitude = 39.920078, display_name = "Orel "},
    ["Ordzhonikidze"] = { latitude = 42.640714, longitude = 42.025758, display_name = "Ordzhonikidze"},
    ["Orbeli"] = { latitude = 42.636184, longitude = 42.822917, display_name = "Orbeli"},
    ["Orbel'yanovka"] = { latitude = 44.232740, longitude = 42.878746, display_name = "Orbel'yanovka"},
    ["Opshkviti"] = { latitude = 42.147389, longitude = 42.604859, display_name = "Opshkviti"},
    ["Opachkhapu"] = { latitude = 42.448393, longitude = 41.903878, display_name = "Opachkhapu"},
    ["Ondzhoheti"] = { latitude = 42.032045, longitude = 42.507565, display_name = "Ondzhoheti"},
    ["Ol'ginskiy"] = { latitude = 45.126611, longitude = 38.359099, display_name = "Ol'ginskiy"},
    ["Okureshi"] = { latitude = 42.543283, longitude = 42.672827, display_name = "Okureshi"},
    ["Oktyabr'skoe"] = { latitude = 43.889818, longitude = 43.176085, display_name = "Oktyabr'skoe"},
    ["Oktyabr'skiy"] = { latitude = 44.849738, longitude = 38.471831, display_name = "Oktyabr'skiy"},
    ["Oktyabr'skiy"] = { latitude = 45.236696, longitude = 38.290841, display_name = "Oktyabr'skiy"},
    ["Oktyabr'skiy"] = { latitude = 44.253774, longitude = 42.486886, display_name = "Oktyabr'skiy"},
    ["Oktyabr'skiy"] = { latitude = 44.322918, longitude = 39.339558, display_name = "Oktyabr'skiy"},
    ["Oktyabr'skaya"] = { latitude = 44.854025, longitude = 39.617850, display_name = "Oktyabr'skaya"},
    ["Oktomberi"] = { latitude = 42.208187, longitude = 42.430870, display_name = "Oktomberi"},
    ["Oktomberi"] = { latitude = 42.443933, longitude = 41.743717, display_name = "Oktomberi"},
    ["Oktomberi"] = { latitude = 43.030969, longitude = 41.229984, display_name = "Oktomberi"},
    ["Oireme"] = { latitude = 42.467632, longitude = 41.808728, display_name = "Oireme"},
    ["Ohvamekari"] = { latitude = 42.369398, longitude = 41.833464, display_name = "Ohvamekari"},
    ["Odzhola"] = { latitude = 42.388595, longitude = 42.785896, display_name = "Odzhola"},
    ["Odishi"] = { latitude = 43.075147, longitude = 41.091600, display_name = "Odishi"},
    ["Odishi"] = { latitude = 42.526251, longitude = 41.923614, display_name = "Odishi"},
    ["Ochkhomuri"] = { latitude = 42.471584, longitude = 42.079849, display_name = "Ochkhomuri"},
    ["Ochkhamuri"] = { latitude = 41.856720, longitude = 41.833105, display_name = "Ochkhamuri"},
    ["Oche"] = { latitude = 42.524586, longitude = 42.313209, display_name = "Oche"},
    ["Obudzhi"] = { latitude = 42.556017, longitude = 42.015172, display_name = "Obudzhi"},
    ["Obil'noe"] = { latitude = 44.245620, longitude = 43.557820, display_name = "Obil'noe"},
    ["Novyy Sad"] = { latitude = 44.907033, longitude = 38.908686, display_name = "Novyy Sad"},
    ["Novyy Karachay "] = { latitude = 43.819752, longitude = 41.904403, display_name = "Novyy Karachay "},
    ["Novyy"] = { latitude = 45.007971, longitude = 38.979031, display_name = "Novyy"},
    ["Novyy"] = { latitude = 44.151786, longitude = 43.439254, display_name = "Novyy"},
    ["Novyy"] = { latitude = 44.935888, longitude = 40.166760, display_name = "Novyy"},
    ["Novyy"] = { latitude = 44.726360, longitude = 39.824853, display_name = "Novyy"},
    ["Novye Polyany"] = { latitude = 44.302384, longitude = 39.825372, display_name = "Novye Polyany"},
    ["Novozavedennoe"] = { latitude = 44.265326, longitude = 43.639520, display_name = "Novozavedennoe"},
    ["Novovelichkovskaya"] = { latitude = 45.282561, longitude = 38.846433, display_name = "Novovelichkovskaya"},
    ["Novoukrainskiy"] = { latitude = 44.897714, longitude = 38.047940, display_name = "Novoukrainskiy"},
    ["Novotroitskiy"] = { latitude = 45.031839, longitude = 38.007409, display_name = "Novotroitskiy"},
    ["Novotitarovskaya"] = { latitude = 45.243806, longitude = 38.981038, display_name = "Novotitarovskaya"},
    ["Novoterskiy"] = { latitude = 44.150120, longitude = 43.092246, display_name = "Novoterskiy"},
    ["Novosrednenskoe"] = { latitude = 44.094686, longitude = 43.823821, display_name = "Novosrednenskoe"},
    ["Novosevastopol'skoe"] = { latitude = 45.063035, longitude = 39.704568, display_name = "Novosevastopol'skoe"},
    ["Novomyshastovskaya"] = { latitude = 45.201414, longitude = 38.574925, display_name = "Novomyshastovskaya"},
    ["Novolabinskaya"] = { latitude = 45.114755, longitude = 39.900432, display_name = "Novolabinskaya"},
    ["Novoispravnenskoe"] = { latitude = 43.979804, longitude = 41.542656, display_name = "Novoispravnenskoe"},
    ["Novodmitrievskaya"] = { latitude = 44.834141, longitude = 38.877951, display_name = "Novodmitrievskaya"},
    ["Novobzhegokay"] = { latitude = 44.934656, longitude = 38.837614, display_name = "Novobzhegokay"},
    ["Novoblagodarnoe"] = { latitude = 44.144876, longitude = 42.878900, display_name = "Novoblagodarnoe"},
    ["Novoalekseevskoe"] = { latitude = 44.957243, longitude = 39.860670, display_name = "Novoalekseevskoe"},
    ["Novaya Akvaskia"] = { latitude = 42.794629, longitude = 41.540276, display_name = "Novaya Akvaskia"},
    ["Novaya Adygeya"] = { latitude = 45.028796, longitude = 38.933988, display_name = "Novaya Adygeya"},
    ["Nov.Teberda "] = { latitude = 43.673906, longitude = 41.894978, display_name = "Nov.Teberda "},
    ["Nov.Dzheguta"] = { latitude = 43.996395, longitude = 42.048760, display_name = "Nov.Dzheguta"},
    ["Nosiri"] = { latitude = 42.275005, longitude = 42.139716, display_name = "Nosiri"},
    ["Noga"] = { latitude = 42.474952, longitude = 42.208261, display_name = "Noga"},
    ["Nizhnyaya Gostagayka"] = { latitude = 45.040575, longitude = 37.349826, display_name = "Nizhnyaya Gostagayka"},
    ["Nizhnezol'skiy"] = { latitude = 44.120358, longitude = 43.639111, display_name = "Nizhnezol'skiy"},
    ["Nizhnepodkumskiy"] = { latitude = 44.078935, longitude = 43.212710, display_name = "Nizhnepodkumskiy"},
    ["Nizhne-Vysokoe"] = { latitude = 43.474346, longitude = 39.972717, display_name = "Nizhne-Vysokoe"},
    ["Nizh.Teberda"] = { latitude = 43.638667, longitude = 41.872969, display_name = "Nizh.Teberda"},
    ["Nizh.Shilovka"] = { latitude = 43.463994, longitude = 40.023461, display_name = "Nizh.Shilovka"},
    ["Nizh.Kurkuzhin"] = { latitude = 43.752549, longitude = 43.362675, display_name = "Nizh.Kurkuzhin"},
    ["Nizh.Ermolovka"] = { latitude = 43.750379, longitude = 41.510216, display_name = "Nizh.Ermolovka"},
    ["Nizh.Chegem"] = { latitude = 43.498349, longitude = 43.296418, display_name = "Nizh.Chegem"},
    ["Nizh.Arhyz"] = { latitude = 43.680448, longitude = 41.458998, display_name = "Nizh.Arhyz"},
    ["Nizh. Mtsara "] = { latitude = 43.141038, longitude = 40.761450, display_name = "Nizh. Mtsara "},
    ["Nizh. Armyanskoe Uschel'e"] = { latitude = 43.084525, longitude = 40.794689, display_name = "Nizh. Armyanskoe Uschel'e"},
    ["Ninoshvili"] = { latitude = 42.042257, longitude = 41.948968, display_name = "Ninoshvili"},
    ["Nikortsminda"] = { latitude = 42.464696, longitude = 43.097630, display_name = "Nikortsminda"},
    ["Nikolaevskoe"] = { latitude = 44.122613, longitude = 42.129337, display_name = "Nikolaevskoe"},
    ["Nikolaenko"] = { latitude = 44.409057, longitude = 39.673508, display_name = "Nikolaenko"},
    ["Nigvziani"] = { latitude = 42.067004, longitude = 41.879237, display_name = "Nigvziani"},
    ["Nigvzara"] = { latitude = 42.213600, longitude = 43.465632, display_name = "Nigvzara"},
    ["Niabauri"] = { latitude = 41.868343, longitude = 42.013388, display_name = "Niabauri"},
    ["Nezlobnaya"] = { latitude = 44.118949, longitude = 43.410519, display_name = "Nezlobnaya"},
    ["Nezhinskiy"] = { latitude = 43.931930, longitude = 42.685571, display_name = "Nezhinskiy"},
    ["Neshukay"] = { latitude = 44.910399, longitude = 39.416240, display_name = "Neshukay"},
    ["Nergeeti"] = { latitude = 42.054518, longitude = 42.823643, display_name = "Nergeeti"},
    ["Nekrasovskaya"] = { latitude = 45.148939, longitude = 39.755071, display_name = "Nekrasovskaya"},
    ["Neftyanaya"] = { latitude = 44.377554, longitude = 39.643419, display_name = "Neftyanaya"},
    ["Neftegorsk"] = { latitude = 44.366015, longitude = 39.713219, display_name = "Neftegorsk"},
    ["Nebug"] = { latitude = 44.171632, longitude = 38.998327, display_name = "Nebug"},
    ["Nebodziri"] = { latitude = 41.988354, longitude = 43.370345, display_name = "Nebodziri"},
    ["Neberdzhaevskaya"] = { latitude = 44.828654, longitude = 37.893678, display_name = "Neberdzhaevskaya"},
    ["Navenahevi"] = { latitude = 42.250740, longitude = 42.859437, display_name = "Navenahevi"},
    ["Navaginka"] = { latitude = 43.618130, longitude = 39.745794, display_name = "Navaginka"},
    ["Natuhaevskaya"] = { latitude = 44.911294, longitude = 37.567604, display_name = "Natuhaevskaya"},
    ["Natsatu"] = { latitude = 42.567541, longitude = 41.979564, display_name = "Natsatu"},
    ["Nasperi"] = { latitude = 42.590925, longitude = 42.770482, display_name = "Nasperi"},
    ["Nartan"] = { latitude = 43.511529, longitude = 43.704153, display_name = "Nartan"},
    ["Narazeni"] = { latitude = 42.393980, longitude = 41.913391, display_name = "Narazeni"},
    ["Naposhtu"] = { latitude = 42.326551, longitude = 41.933522, display_name = "Naposhtu"},
    ["Naochi"] = { latitude = 42.776851, longitude = 41.352702, display_name = "Naochi"},
    ["Namohvani"] = { latitude = 42.421347, longitude = 42.697503, display_name = "Namohvani"},
    ["Namikolavo"] = { latitude = 42.474821, longitude = 42.329612, display_name = "Namikolavo"},
    ["Nalepsao"] = { latitude = 42.434450, longitude = 42.365644, display_name = "Nalepsao"},
    ["Nakuraleshi"] = { latitude = 42.552601, longitude = 42.746391, display_name = "Nakuraleshi"},
    ["Nakipu"] = { latitude = 42.562322, longitude = 42.073330, display_name = "Nakipu"},
    ["Nahurtsilavo"] = { latitude = 42.446389, longitude = 42.263325, display_name = "Nahurtsilavo"},
    ["Nahunao"] = { latitude = 42.430549, longitude = 42.323061, display_name = "Nahunao"},
    ["Nahshirgele"] = { latitude = 42.224265, longitude = 42.824321, display_name = "Nahshirgele"},
    ["Nahahulevi"] = { latitude = 42.359411, longitude = 42.438140, display_name = "Nahahulevi"},
    ["Naguru"] = { latitude = 42.694093, longitude = 42.097908, display_name = "Naguru"},
    ["Nagomari"] = { latitude = 41.990544, longitude = 42.112949, display_name = "Nagomari"},
    ["Nageberavo"] = { latitude = 42.332468, longitude = 42.314506, display_name = "Nageberavo"},
    ["Naesakao"] = { latitude = 42.178447, longitude = 42.209197, display_name = "Naesakao"},
    ["Nadezhnaya"] = { latitude = 44.207001, longitude = 41.404721, display_name = "Nadezhnaya"},
    ["Nadaburi"] = { latitude = 42.126553, longitude = 43.427983, display_name = "Nadaburi"},
    ["Nabakevi"] = { latitude = 42.503987, longitude = 41.662352, display_name = "Nabakevi"},
    ["Mziani"] = { latitude = 41.976759, longitude = 42.151579, display_name = "Mziani"},
    ["Myshako"] = { latitude = 44.667140, longitude = 37.759021, display_name = "Myshako"},
    ["Muhuri"] = { latitude = 42.634638, longitude = 42.176056, display_name = "Muhuri"},
    ["Muhuri"] = { latitude = 42.689556, longitude = 41.697291, display_name = "Muhuri"},
    ["Muhura"] = { latitude = 42.326650, longitude = 43.087842, display_name = "Muhura"},
    ["Mtsvane-Kontshi"] = { latitude = 41.689072, longitude = 41.709726, display_name = "Mtsvane-Kontshi"},
    ["Mtispiri"] = { latitude = 41.941767, longitude = 42.157494, display_name = "Mtispiri"},
    ["Morzoh"] = { latitude = 43.567536, longitude = 43.840579, display_name = "Morzoh"},
    ["Mongiri"] = { latitude = 42.490006, longitude = 42.152069, display_name = "Mongiri"},
    ["Molodezhnyy"] = { latitude = 44.680002, longitude = 39.675713, display_name = "Molodezhnyy"},
    ["Moldovka"] = { latitude = 43.454585, longitude = 39.940029, display_name = "Moldovka"},
    ["Moldavanskoe"] = { latitude = 44.946939, longitude = 37.868979, display_name = "Moldavanskoe"},
    ["Moidanahe"] = { latitude = 42.545104, longitude = 42.138447, display_name = "Moidanahe"},
    ["Mohva"] = { latitude = 42.406014, longitude = 43.331100, display_name = "Mohva"},
    ["Mohashi"] = { latitude = 42.415311, longitude = 42.190616, display_name = "Mohashi"},
    ["Mogukorovskiy"] = { latitude = 45.156215, longitude = 38.198283, display_name = "Mogukorovskiy"},
    ["Mogiri"] = { latitude = 42.374700, longitude = 41.729160, display_name = "Mogiri"},
    ["Modzvi"] = { latitude = 42.262543, longitude = 43.423399, display_name = "Modzvi"},
    ["Mitsatsiteli"] = { latitude = 42.237341, longitude = 42.538850, display_name = "Mitsatsiteli"},
    ["Mirnyy"] = { latitude = 44.608512, longitude = 39.008222, display_name = "Mirnyy"},
    ["Mingrel'skaya"] = { latitude = 45.014629, longitude = 38.338356, display_name = "Mingrel'skaya"},
    ["Mikava"] = { latitude = 42.622078, longitude = 42.105739, display_name = "Mikava"},
    ["Mihaylovskoe"] = { latitude = 45.010440, longitude = 38.505502, display_name = "Mihaylovskoe"},
    ["Mihaylovskiy Pereval"] = { latitude = 44.515937, longitude = 38.308302, display_name = "Mihaylovskiy Pereval"},
    ["Mihaylovka"] = { latitude = 44.220290, longitude = 43.715318, display_name = "Mihaylovka"},
    ["Mhkhiani"] = { latitude = 42.198488, longitude = 42.599261, display_name = "Mhkhiani"},
    ["Mgvimevi"] = { latitude = 42.324557, longitude = 43.325751, display_name = "Mgvimevi"},
    ["Mezmay"] = { latitude = 44.201951, longitude = 39.954704, display_name = "Mezmay"},
    ["Messazhay"] = { latitude = 44.141813, longitude = 39.118127, display_name = "Messazhay"},
    ["Meria"] = { latitude = 41.944845, longitude = 41.895503, display_name = "Meria"},
    ["Merheuli"] = { latitude = 42.987272, longitude = 41.159733, display_name = "Merheuli"},
    ["Merdzhevi"] = { latitude = 42.306727, longitude = 43.431058, display_name = "Merdzhevi"},
    ["Merchanskoe"] = { latitude = 44.953938, longitude = 38.129010, display_name = "Merchanskoe"},
    ["Meore-Tola"] = { latitude = 42.590570, longitude = 43.004131, display_name = "Meore-Tola"},
    ["Meore-Sviri"] = { latitude = 42.109908, longitude = 42.927318, display_name = "Meore-Sviri"},
    ["Meore-Otobaya"] = { latitude = 42.454627, longitude = 41.646351, display_name = "Meore-Otobaya"},
    ["Meore-Obcha"] = { latitude = 42.107171, longitude = 42.887676, display_name = "Meore-Obcha"},
    ["Meore-Mohashi"] = { latitude = 42.391827, longitude = 42.155776, display_name = "Meore-Mohashi"},
    ["Meore-Gudava"] = { latitude = 42.643386, longitude = 41.544281, display_name = "Meore-Gudava"},
    ["Meore-Choga"] = { latitude = 42.553676, longitude = 42.195803, display_name = "Meore-Choga"},
    ["Meore-Balda"] = { latitude = 42.499520, longitude = 42.391396, display_name = "Meore-Balda"},
    ["Meore Guripuli"] = { latitude = 42.293696, longitude = 41.890921, display_name = "Meore Guripuli"},
    ["Melauri"] = { latitude = 42.190643, longitude = 42.384720, display_name = "Melauri"},
    ["Medzhinistskali"] = { latitude = 41.591304, longitude = 41.634544, display_name = "Medzhinistskali"},
    ["Mednogorskiy"] = { latitude = 43.915956, longitude = 41.186234, display_name = "Mednogorskiy"},
    ["Medani"] = { latitude = 42.672074, longitude = 42.137770, display_name = "Medani"},
    ["Mechkheturi"] = { latitude = 42.156947, longitude = 43.357366, display_name = "Mechkheturi"},
    ["Mazandara"] = { latitude = 42.619401, longitude = 42.045884, display_name = "Mazandara"},
    ["Mayskiy"] = { latitude = 44.304185, longitude = 42.414766, display_name = "Mayskiy"},
    ["Mathodzhi"] = { latitude = 42.387197, longitude = 42.442078, display_name = "Mathodzhi"},
    ["Maruha"] = { latitude = 43.765166, longitude = 41.633133, display_name = "Maruha"},
    ["Martotubani"] = { latitude = 42.129811, longitude = 43.099587, display_name = "Martotubani"},
    ["Martanskaya"] = { latitude = 44.762337, longitude = 39.437253, display_name = "Martanskaya"},
    ["Marelisi"] = { latitude = 41.957941, longitude = 43.275197, display_name = "Marelisi"},
    ["Marani"] = { latitude = 42.167287, longitude = 42.279974, display_name = "Marani"},
    ["Mar'yanskaya"] = { latitude = 45.105603, longitude = 38.639941, display_name = "Mar'yanskaya"},
    ["Mar'inskaya"] = { latitude = 43.883397, longitude = 43.485856, display_name = "Mar'inskaya"},
    ["Mar'ina Roscha"] = { latitude = 44.622675, longitude = 38.028581, display_name = "Mar'ina Roscha"},
    ["Mandaeti"] = { latitude = 42.183777, longitude = 43.335150, display_name = "Mandaeti"},
    ["Mamheg"] = { latitude = 45.014362, longitude = 40.218094, display_name = "Mamheg"},
    ["Mamayka"] = { latitude = 43.635005, longitude = 39.702864, display_name = "Mamayka"},
    ["Malotenginskaya"] = { latitude = 44.281730, longitude = 41.526014, display_name = "Malotenginskaya"},
    ["Malokurgannyy"] = { latitude = 43.844057, longitude = 41.906286, display_name = "Malokurgannyy"},
    ["Malka"] = { latitude = 43.800714, longitude = 43.326704, display_name = "Malka"},
    ["Mal.Zelenchuk"] = { latitude = 44.160376, longitude = 41.864663, display_name = "Mal.Zelenchuk"},
    ["Makopse"] = { latitude = 43.994893, longitude = 39.213327, display_name = "Makopse"},
    ["Makatubani"] = { latitude = 42.124781, longitude = 43.243436, display_name = "Makatubani"},
    ["Maidani"] = { latitude = 42.284090, longitude = 42.312674, display_name = "Maidani"},
    ["Mahatauri"] = { latitude = 42.288011, longitude = 43.463631, display_name = "Mahatauri"},
    ["Mahashi"] = { latitude = 42.606742, longitude = 42.749978, display_name = "Mahashi"},
    ["Maharadze"] = { latitude = 41.935696, longitude = 41.974045, display_name = "Maharadze"},
    ["Maglaki"] = { latitude = 42.261039, longitude = 42.565289, display_name = "Maglaki"},
    ["Maevskiy"] = { latitude = 45.172039, longitude = 38.161598, display_name = "Maevskiy"},
    ["Machkhvareti"] = { latitude = 42.068987, longitude = 42.008697, display_name = "Machkhvareti"},
    ["Lysogorskaya"] = { latitude = 44.106014, longitude = 43.281068, display_name = "Lysogorskaya"},
    ["Lunacharskiy"] = { latitude = 43.905269, longitude = 42.690928, display_name = "Lunacharskiy"},
    ["Loo"] = { latitude = 43.705439, longitude = 39.587153, display_name = "Loo"},
    ["Lineynaya"] = { latitude = 44.594594, longitude = 39.487620, display_name = "Lineynaya"},
    ["Liheti"] = { latitude = 42.608896, longitude = 43.238178, display_name = "Liheti"},
    ["Lidzava"] = { latitude = 43.178993, longitude = 40.363041, display_name = "Lidzava"},
    ["Lia"] = { latitude = 42.636237, longitude = 41.988812, display_name = "Lia"},
    ["Levokumka"] = { latitude = 44.234481, longitude = 43.139161, display_name = "Levokumka"},
    ["Letsurtsume"] = { latitude = 42.533360, longitude = 42.119200, display_name = "Letsurtsume"},
    ["Lesogorskaya"] = { latitude = 44.547683, longitude = 39.536450, display_name = "Lesogorskaya"},
    ["Leso-Kefar' "] = { latitude = 43.788871, longitude = 41.449272, display_name = "Leso-Kefar' "},
    ["Lesnoe"] = { latitude = 43.776488, longitude = 43.893822, display_name = "Lesnoe"},
    ["Leselidze"] = { latitude = 43.394992, longitude = 40.031382, display_name = "Leselidze"},
    ["Lesa"] = { latitude = 42.077277, longitude = 41.963379, display_name = "Lesa"},
    ["Lepochkhue"] = { latitude = 42.330917, longitude = 42.247525, display_name = "Lepochkhue"},
    ["Leninskiy"] = { latitude = 45.172744, longitude = 38.234987, display_name = "Leninskiy"},
    ["Leninskiy"] = { latitude = 44.192230, longitude = 43.153106, display_name = "Leninskiy"},
    ["Lemikave"] = { latitude = 42.427247, longitude = 42.241238, display_name = "Lemikave"},
    ["Lekadzhaie"] = { latitude = 42.405106, longitude = 42.292257, display_name = "Lekadzhaie"},
    ["Leharchile"] = { latitude = 42.644704, longitude = 42.136081, display_name = "Leharchile"},
    ["Lehaindravo"] = { latitude = 42.354513, longitude = 42.340358, display_name = "Lehaindravo"},
    ["Legvani"] = { latitude = 41.967060, longitude = 43.250167, display_name = "Legvani"},
    ["Legogie-Nasadzhu"] = { latitude = 42.445929, longitude = 42.182047, display_name = "Legogie-Nasadzhu"},
    ["Ledgebe"] = { latitude = 42.486240, longitude = 42.276690, display_name = "Ledgebe"},
    ["Ledarsale"] = { latitude = 42.590914, longitude = 42.179511, display_name = "Ledarsale"},
    ["Lechkop"] = { latitude = 43.006797, longitude = 40.947857, display_name = "Lechkop"},
    ["Lechinkay"] = { latitude = 43.564141, longitude = 43.434332, display_name = "Lechinkay"},
    ["Lashkuta"] = { latitude = 43.561224, longitude = 43.220160, display_name = "Lashkuta"},
    ["Larchva"] = { latitude = 42.351435, longitude = 41.835304, display_name = "Larchva"},
    ["Lailashi"] = { latitude = 42.611170, longitude = 42.859131, display_name = "Lailashi"},
    ["L'vovskoe"] = { latitude = 44.996451, longitude = 38.629714, display_name = "L'vovskoe"},
    ["Kyzyl-Urup"] = { latitude = 44.007355, longitude = 41.222594, display_name = "Kyzyl-Urup"},
    ["Kyzyl-Pokun"] = { latitude = 43.931009, longitude = 42.322452, display_name = "Kyzyl-Pokun"},
    ["Kyzyl-Oktyabr'skiy"] = { latitude = 43.821981, longitude = 41.784413, display_name = "Kyzyl-Oktyabr'skiy"},
    ["Kyzyl-Kala"] = { latitude = 43.916362, longitude = 42.022165, display_name = "Kyzyl-Kala"},
    ["Kyzburun 3-y"] = { latitude = 43.661503, longitude = 43.539209, display_name = "Kyzburun 3-y"},
    ["Kyzburun 1-y"] = { latitude = 43.649090, longitude = 43.398417, display_name = "Kyzburun 1-y"},
    ["Kvitiri"] = { latitude = 42.240290, longitude = 42.627891, display_name = "Kvitiri"},
    ["Kvishona"] = { latitude = 42.483267, longitude = 41.605369, display_name = "Kvishona"},
    ["Kvishari"] = { latitude = 42.556177, longitude = 42.944007, display_name = "Kvishari"},
    ["Kvilishori"] = { latitude = 42.367595, longitude = 42.633262, display_name = "Kvilishori"},
    ["Kvemo-Natanebi"] = { latitude = 41.940818, longitude = 41.821619, display_name = "Kvemo-Natanebi"},
    ["Kvemo-Nagvazavo"] = { latitude = 42.369523, longitude = 42.351584, display_name = "Kvemo-Nagvazavo"},
    ["Kvemo-Merheuli"] = { latitude = 42.953562, longitude = 41.083145, display_name = "Kvemo-Merheuli"},
    ["Kvemo-Makvaneti"] = { latitude = 41.899174, longitude = 42.004806, display_name = "Kvemo-Makvaneti"},
    ["Kvemo-Linda"] = { latitude = 43.052983, longitude = 41.084562, display_name = "Kvemo-Linda"},
    ["Kvemo-Huntsi"] = { latitude = 42.386495, longitude = 42.408388, display_name = "Kvemo-Huntsi"},
    ["Kvemo-Heti"] = { latitude = 42.036326, longitude = 42.345654, display_name = "Kvemo-Heti"},
    ["Kvemo-Gumurishi"] = { latitude = 42.695293, longitude = 41.779772, display_name = "Kvemo-Gumurishi"},
    ["Kvemo-Chibati"] = { latitude = 42.084840, longitude = 41.984109, display_name = "Kvemo-Chibati"},
    ["Kvemo-Bargebi"] = { latitude = 42.550507, longitude = 41.597211, display_name = "Kvemo-Bargebi"},
    ["Kvemo-Aketi"] = { latitude = 42.018515, longitude = 42.086106, display_name = "Kvemo-Aketi"},
    ["Kvemo-Abasha"] = { latitude = 42.067810, longitude = 42.332917, display_name = "Kvemo-Abasha"},
    ["Kvemo-"] = { latitude = 42.534733, longitude = 43.277237, display_name = "Kvemo-"},
    ["Kveda-Zegani"] = { latitude = 42.053654, longitude = 42.882304, display_name = "Kveda-Zegani"},
    ["Kveda-Tsageri"] = { latitude = 42.636375, longitude = 42.752565, display_name = "Kveda-Tsageri"},
    ["Kveda-Tlugi"] = { latitude = 42.450272, longitude = 43.131812, display_name = "Kveda-Tlugi"},
    ["Kveda-Simoneti"] = { latitude = 42.224997, longitude = 42.857157, display_name = "Kveda-Simoneti"},
    ["Kveda-Mesheti"] = { latitude = 42.212940, longitude = 42.627000, display_name = "Kveda-Mesheti"},
    ["Kveda-Kvaliti"] = { latitude = 42.090228, longitude = 42.983547, display_name = "Kveda-Kvaliti"},
    ["Kveda-Kinchkha"] = { latitude = 42.487021, longitude = 42.561627, display_name = "Kveda-Kinchkha"},
    ["Kveda-Ilemi"] = { latitude = 42.079259, longitude = 43.128506, display_name = "Kveda-Ilemi"},
    ["Kveda-Gvirishi"] = { latitude = 42.579735, longitude = 42.800770, display_name = "Kveda-Gvirishi"},
    ["Kveda-Gordi"] = { latitude = 42.441570, longitude = 42.521019, display_name = "Kveda-Gordi"},
    ["Kveda-Gora"] = { latitude = 42.072625, longitude = 42.664264, display_name = "Kveda-Gora"},
    ["Kveda-Chkhorotsku"] = { latitude = 42.494847, longitude = 42.101203, display_name = "Kveda-Chkhorotsku"},
    ["Kveda-Chelovani"] = { latitude = 42.361088, longitude = 43.275404, display_name = "Kveda-Chelovani"},
    ["Kveda-Bzvani"] = { latitude = 42.076868, longitude = 42.589309, display_name = "Kveda-Bzvani"},
    ["Kveda-Bahvi"] = { latitude = 41.961494, longitude = 42.091267, display_name = "Kveda-Bahvi"},
    ["Kveda-Alisubani"] = { latitude = 42.241205, longitude = 43.093737, display_name = "Kveda-Alisubani"},
    ["Kvatsihe"] = { latitude = 42.291298, longitude = 43.146492, display_name = "Kvatsihe"},
    ["Kvashkhieti"] = { latitude = 42.548421, longitude = 43.384416, display_name = "Kvashkhieti"},
    ["Kvakude"] = { latitude = 42.054600, longitude = 42.299292, display_name = "Kvakude"},
    ["Kvaiti"] = { latitude = 42.425612, longitude = 42.418926, display_name = "Kvaiti"},
    ["Kvahchiri"] = { latitude = 42.205749, longitude = 42.738452, display_name = "Kvahchiri"},
    ["Kvabga"] = { latitude = 41.923119, longitude = 42.401623, display_name = "Kvabga"},
    ["Kuzhorskaya"] = { latitude = 44.670893, longitude = 40.302495, display_name = "Kuzhorskaya"},
    ["Kutol"] = { latitude = 42.847172, longitude = 41.384156, display_name = "Kutol"},
    ["Kutiri"] = { latitude = 42.266691, longitude = 42.357876, display_name = "Kutiri"},
    ["Kutaisskaya"] = { latitude = 44.648472, longitude = 39.310268, display_name = "Kutaisskaya"},
    ["Kutais"] = { latitude = 44.526035, longitude = 39.297980, display_name = "Kutais"},
    ["Kushubauri"] = { latitude = 42.050474, longitude = 42.439897, display_name = "Kushubauri"},
    ["Kurzu"] = { latitude = 42.586949, longitude = 42.289336, display_name = "Kurzu"},
    ["Kursebi"] = { latitude = 42.324736, longitude = 42.782359, display_name = "Kursebi"},
    ["Kurinskaya"] = { latitude = 44.412581, longitude = 39.419430, display_name = "Kurinskaya"},
    ["Kurdzhipskaya"] = { latitude = 44.466941, longitude = 40.052631, display_name = "Kurdzhipskaya"},
    ["Kurdzhinovo"] = { latitude = 43.955447, longitude = 40.955449, display_name = "Kurdzhinovo"},
    ["Kurchanskaya"] = { latitude = 45.226181, longitude = 37.567587, display_name = "Kurchanskaya"},
    ["Kunchukohabl'"] = { latitude = 44.986007, longitude = 39.473929, display_name = "Kunchukohabl'"},
    ["Kumysh"] = { latitude = 43.883288, longitude = 41.895281, display_name = "Kumysh"},
    ["Kumuri"] = { latitude = 42.035760, longitude = 42.465455, display_name = "Kumuri"},
    ["Kumistavi"] = { latitude = 42.385156, longitude = 42.587147, display_name = "Kumistavi"},
    ["Kulishkari"] = { latitude = 42.513092, longitude = 41.958707, display_name = "Kulishkari"},
    ["Kulevi"] = { latitude = 42.272143, longitude = 41.658712, display_name = "Kulevi"},
    ["Kul'tubani"] = { latitude = 43.411775, longitude = 40.018098, display_name = "Kul'tubani"},
    ["Kuheshi"] = { latitude = 42.680133, longitude = 42.113696, display_name = "Kuheshi"},
    ["Kudepsta"] = { latitude = 43.500558, longitude = 39.893815, display_name = "Kudepsta"},
    ["Kuchugury"] = { latitude = 45.408297, longitude = 36.957851, display_name = "Kuchugury"},
    ["Kubina"] = { latitude = 44.064788, longitude = 41.946525, display_name = "Kubina"},
    ["Kubanskiy"] = { latitude = 44.617741, longitude = 39.773434, display_name = "Kubanskiy"},
    ["Kubanskaya"] = { latitude = 44.607766, longitude = 39.710965, display_name = "Kubanskaya"},
    ["Kuba-Taba"] = { latitude = 43.781922, longitude = 43.445360, display_name = "Kuba-Taba"},
    ["Kuba"] = { latitude = 43.861071, longitude = 43.454167, display_name = "Kuba"},
    ["Kroyanskoe"] = { latitude = 44.095332, longitude = 39.120379, display_name = "Kroyanskoe"},
    ["Krizhanovskiy"] = { latitude = 45.250930, longitude = 38.164738, display_name = "Krizhanovskiy"},
    ["Krivenkovskoe"] = { latitude = 44.192196, longitude = 39.231930, display_name = "Krivenkovskoe"},
    ["Krikuna"] = { latitude = 45.267052, longitude = 38.212063, display_name = "Krikuna"},
    ["Krepostnaya"] = { latitude = 44.712451, longitude = 38.678714, display_name = "Krepostnaya"},
    ["Kremenchug-Konstantinovskiy"] = { latitude = 43.795032, longitude = 43.648364, display_name = "Kremenchug-Konstantinovskiy"},
    ["Krasnyy Pahar'"] = { latitude = 44.202575, longitude = 43.104153, display_name = "Krasnyy Pahar'"},
    ["Krasnyy Oktyabr'"] = { latitude = 45.195279, longitude = 37.655732, display_name = "Krasnyy Oktyabr'"},
    ["Krasnyy Kurgan"] = { latitude = 45.016457, longitude = 37.339404, display_name = "Krasnyy Kurgan"},
    ["Krasnyy"] = { latitude = 44.981641, longitude = 38.043088, display_name = "Krasnyy"},
    ["Krasnovostochnyy"] = { latitude = 43.967766, longitude = 42.295034, display_name = "Krasnovostochnyy"},
    ["Krasnosel'skoe"] = { latitude = 45.292325, longitude = 39.165057, display_name = "Krasnosel'skoe"},
    ["Krasnooktyabr'skiy"] = { latitude = 44.932096, longitude = 38.368635, display_name = "Krasnooktyabr'skiy"},
    ["Krasnokumskoe"] = { latitude = 44.176715, longitude = 43.484738, display_name = "Krasnokumskoe"},
    ["Krasnogvardeyskoe"] = { latitude = 45.124528, longitude = 39.575543, display_name = "Krasnogvardeyskoe"},
    ["Krasnogorskaya"] = { latitude = 43.942361, longitude = 41.886798, display_name = "Krasnogorskaya"},
    ["Krasnodarskiy"] = { latitude = 45.157592, longitude = 39.135852, display_name = "Krasnodarskiy"},
    ["Krasnaya Volya"] = { latitude = 43.562303, longitude = 39.917862, display_name = "Krasnaya Volya"},
    ["Krasnaya Batareya"] = { latitude = 45.089560, longitude = 37.786608, display_name = "Krasnaya Batareya"},
    ["Krasn.Kurgan"] = { latitude = 43.946104, longitude = 42.607477, display_name = "Krasn.Kurgan"},
    ["Kraevsko-Armyanskoe"] = { latitude = 43.607677, longitude = 39.824782, display_name = "Kraevsko-Armyanskoe"},
    ["Kozet"] = { latitude = 44.995830, longitude = 38.997301, display_name = "Kozet"},
    ["Koydan"] = { latitude = 44.107503, longitude = 42.158336, display_name = "Koydan"},
    ["Kosovichi"] = { latitude = 45.090116, longitude = 38.562291, display_name = "Kosovichi"},
    ["Kosh-Habl'"] = { latitude = 44.140522, longitude = 41.848038, display_name = "Kosh-Habl'"},
    ["Korzhevskiy"] = { latitude = 45.223751, longitude = 38.190642, display_name = "Korzhevskiy"},
    ["Korzhevskiy"] = { latitude = 45.196991, longitude = 37.716494, display_name = "Korzhevskiy"},
    ["Kortsheli"] = { latitude = 42.561060, longitude = 41.946838, display_name = "Kortsheli"},
    ["Koreti"] = { latitude = 42.301668, longitude = 43.380740, display_name = "Koreti"},
    ["Korbouli"] = { latitude = 42.239897, longitude = 43.467509, display_name = "Korbouli"},
    ["Kopanskiy"] = { latitude = 45.174892, longitude = 38.803876, display_name = "Kopanskiy"},
    ["Kontuati"] = { latitude = 42.349493, longitude = 42.418258, display_name = "Kontuati"},
    ["Kontianeti"] = { latitude = 42.326672, longitude = 42.166574, display_name = "Kontianeti"},
    ["Konstantinovskaya"] = { latitude = 44.049269, longitude = 43.158315, display_name = "Konstantinovskaya"},
    ["Konchkati"] = { latitude = 41.983654, longitude = 41.897403, display_name = "Konchkati"},
    ["Konchkati"] = { latitude = 42.010778, longitude = 42.018563, display_name = "Konchkati"},
    ["Komsomolets"] = { latitude = 44.022420, longitude = 43.562616, display_name = "Komsomolets"},
    ["Komsomol'skiy"] = { latitude = 44.936557, longitude = 39.703550, display_name = "Komsomol'skiy"},
    ["Kommayak"] = { latitude = 44.110647, longitude = 43.858365, display_name = "Kommayak"},
    ["Kolosistyy"] = { latitude = 45.135919, longitude = 38.896495, display_name = "Kolosistyy"},
    ["Kolos"] = { latitude = 45.151407, longitude = 38.345172, display_name = "Kolos"},
    ["Kolobani"] = { latitude = 42.203259, longitude = 42.267792, display_name = "Kolobani"},
    ["Kolhida"] = { latitude = 43.248837, longitude = 40.294920, display_name = "Kolhida"},
    ["Koki"] = { latitude = 42.478988, longitude = 41.705012, display_name = "Koki"},
    ["Koka"] = { latitude = 42.317730, longitude = 42.829199, display_name = "Koka"},
    ["Kochetinskiy"] = { latitude = 45.178268, longitude = 39.238568, display_name = "Kochetinskiy"},
    ["Kochara"] = { latitude = 42.853821, longitude = 41.442319, display_name = "Kochara"},
    ["Kobuleti"] = { latitude = 41.805916, longitude = 41.884158, display_name = "Kobuleti"},
    ["Kobu-Bashi"] = { latitude = 43.932621, longitude = 41.313135, display_name = "Kobu-Bashi"},
    ["Kishpek"] = { latitude = 43.649391, longitude = 43.645297, display_name = "Kishpek"},
    ["Kirtshi"] = { latitude = 42.483754, longitude = 42.054947, display_name = "Kirtshi"},
    ["Kirpichnyy"] = { latitude = 44.041877, longitude = 42.829060, display_name = "Kirpichnyy"},
    ["Kirpichnoe"] = { latitude = 44.168178, longitude = 39.201378, display_name = "Kirpichnoe"},
    ["Kirov"] = { latitude = 42.415340, longitude = 41.661494, display_name = "Kirov"},
    ["Kirilovka"] = { latitude = 44.771935, longitude = 37.724488, display_name = "Kirilovka"},
    ["Kievskoe"] = { latitude = 45.039183, longitude = 37.886756, display_name = "Kievskoe"},
    ["Kichmalka"] = { latitude = 43.793482, longitude = 42.941509, display_name = "Kichmalka"},
    ["Kichi-Balyk"] = { latitude = 43.792728, longitude = 42.650712, display_name = "Kichi-Balyk"},
    ["Ketilari"] = { latitude = 42.146402, longitude = 42.169710, display_name = "Ketilari"},
    ["Keslerovo"] = { latitude = 45.065249, longitude = 37.820617, display_name = "Keslerovo"},
    ["Kerken"] = { latitude = 42.876960, longitude = 41.454944, display_name = "Kerken"},
    ["Kemal'pasha"] = { latitude = 41.468809, longitude = 41.519062, display_name = "Kemal'pasha"},
    ["Kelermesskaya"] = { latitude = 44.793224, longitude = 40.128338, display_name = "Kelermesskaya"},
    ["Kelasuri"] = { latitude = 43.024991, longitude = 41.107288, display_name = "Kelasuri"},
    ["Kazazov"] = { latitude = 44.905153, longitude = 39.174224, display_name = "Kazazov"},
    ["Kavkazskiy"] = { latitude = 44.269490, longitude = 42.230278, display_name = "Kavkazskiy"},
    ["Katshi"] = { latitude = 42.292364, longitude = 43.206406, display_name = "Katshi"},
    ["Karskiy"] = { latitude = 44.828921, longitude = 38.509046, display_name = "Karskiy"},
    ["Karla Marksa"] = { latitude = 45.239177, longitude = 39.058650, display_name = "Karla Marksa"},
    ["Kardonikskaya"] = { latitude = 43.864866, longitude = 41.716166, display_name = "Kardonikskaya"},
    ["Karagach"] = { latitude = 43.804645, longitude = 43.776369, display_name = "Karagach"},
    ["Kangly"] = { latitude = 44.259543, longitude = 43.029475, display_name = "Kangly"},
    ["Kamlyuko"] = { latitude = 43.778866, longitude = 43.260087, display_name = "Kamlyuko"},
    ["Kamennomostskoe"] = { latitude = 43.735328, longitude = 43.047845, display_name = "Kamennomostskoe"},
    ["Kamennomostskiy"] = { latitude = 43.750261, longitude = 41.907820, display_name = "Kamennomostskiy"},
    ["Kaluzhskaya"] = { latitude = 44.763438, longitude = 38.974839, display_name = "Kaluzhskaya"},
    ["Kalinovoe Ozero"] = { latitude = 43.615339, longitude = 39.884288, display_name = "Kalinovoe Ozero"},
    ["Kalininskiy"] = { latitude = 45.207233, longitude = 40.043834, display_name = "Kalininskiy"},
    ["Kalinina"] = { latitude = 44.503982, longitude = 39.720655, display_name = "Kalinina"},
    ["Kalezh"] = { latitude = 44.009759, longitude = 39.353566, display_name = "Kalezh"},
    ["Kaldahvara"] = { latitude = 43.223294, longitude = 40.418047, display_name = "Kaldahvara"},
    ["Kaladzhinskaya"] = { latitude = 44.307522, longitude = 40.905076, display_name = "Kaladzhinskaya"},
    ["Kakuti"] = { latitude = 41.859621, longitude = 41.975559, display_name = "Kakuti"},
    ["Kahun"] = { latitude = 43.539108, longitude = 43.881699, display_name = "Kahun"},
    ["Kahati"] = { latitude = 42.491554, longitude = 41.767683, display_name = "Kahati"},
    ["Kachaeti"] = { latitude = 42.475414, longitude = 43.108621, display_name = "Kachaeti"},
    ["Kabehabl'"] = { latitude = 45.046603, longitude = 40.180256, display_name = "Kabehabl'"},
    ["Kabardinskaya"] = { latitude = 44.501303, longitude = 39.490572, display_name = "Kabardinskaya"},
    ["Izumrud"] = { latitude = 43.467734, longitude = 39.956954, display_name = "Izumrud"},
    ["Izmaylovka"] = { latitude = 43.630299, longitude = 39.824872, display_name = "Izmaylovka"},
    ["Ivanovskaya"] = { latitude = 45.276018, longitude = 38.459475, display_name = "Ivanovskaya"},
    ["Ivanov"] = { latitude = 45.114713, longitude = 37.449495, display_name = "Ivanov"},
    ["Ithvisi"] = { latitude = 42.299871, longitude = 43.345725, display_name = "Ithvisi"},
    ["Isunderi"] = { latitude = 42.556323, longitude = 42.653318, display_name = "Isunderi"},
    ["Isula"] = { latitude = 42.234284, longitude = 42.066794, display_name = "Isula"},
    ["Ispravnaya"] = { latitude = 44.073144, longitude = 41.608052, display_name = "Ispravnaya"},
    ["Islamey"] = { latitude = 43.674212, longitude = 43.451668, display_name = "Islamey"},
    ["Inzhich-Chukun"] = { latitude = 44.047223, longitude = 41.782859, display_name = "Inzhich-Chukun"},
    ["Inzhi-Chishko"] = { latitude = 44.199712, longitude = 41.716677, display_name = "Inzhi-Chishko"},
    ["Intabueti"] = { latitude = 41.974858, longitude = 42.230582, display_name = "Intabueti"},
    ["Inkit"] = { latitude = 43.178272, longitude = 40.295540, display_name = "Inkit"},
    ["Ingiri"] = { latitude = 42.495609, longitude = 41.813885, display_name = "Ingiri"},
    ["Indyuk"] = { latitude = 44.224273, longitude = 39.236887, display_name = "Indyuk"},
    ["Industrial'nyy"] = { latitude = 45.097241, longitude = 39.101407, display_name = "Industrial'nyy"},
    ["Inchkhuri"] = { latitude = 42.449647, longitude = 42.398849, display_name = "Inchkhuri"},
    ["Imeretinskaya"] = { latitude = 44.687871, longitude = 39.425248, display_name = "Imeretinskaya"},
    ["im.Tel'mana"] = { latitude = 44.075250, longitude = 42.855761, display_name = "im.Tel'mana"},
    ["im.Kosta Hetagurova "] = { latitude = 43.806385, longitude = 41.902590, display_name = "im.Kosta Hetagurova "},
    ["Il'ichevskoe"] = { latitude = 44.189752, longitude = 42.146887, display_name = "Il'ichevskoe"},
    ["Il'ich"] = { latitude = 45.425374, longitude = 36.769869, display_name = "Il'ich"},
    ["Il'ich"] = { latitude = 43.953727, longitude = 41.527379, display_name = "Il'ich"},
    ["Ianeuli"] = { latitude = 41.996073, longitude = 42.284336, display_name = "Ianeuli"},
    ["Ianeti"] = { latitude = 42.185880, longitude = 42.420261, display_name = "Ianeti"},
    ["Hvanchkara"] = { latitude = 42.564505, longitude = 43.017793, display_name = "Hvanchkara"},
    ["Hutsubani"] = { latitude = 41.814393, longitude = 41.820341, display_name = "Hutsubani"},
    ["Husy-Kardonik"] = { latitude = 43.788087, longitude = 41.572828, display_name = "Husy-Kardonik"},
    ["Hushtosyrt"] = { latitude = 43.436177, longitude = 43.236374, display_name = "Hushtosyrt"},
    ["Hurzuk"] = { latitude = 43.432373, longitude = 42.149492, display_name = "Hurzuk"},
    ["Hunevi"] = { latitude = 42.106239, longitude = 43.362778, display_name = "Hunevi"},
    ["Hundzhulouri"] = { latitude = 42.190578, longitude = 42.306336, display_name = "Hundzhulouri"},
    ["Humeni-Natopuri"] = { latitude = 42.624068, longitude = 41.611103, display_name = "Humeni-Natopuri"},
    ["Humara"] = { latitude = 43.861423, longitude = 41.912994, display_name = "Humara"},
    ["Hrialeti"] = { latitude = 42.008259, longitude = 41.820575, display_name = "Hrialeti"},
    ["Hresili"] = { latitude = 42.347693, longitude = 42.890246, display_name = "Hresili"},
    ["Hreiti"] = { latitude = 42.348511, longitude = 43.178584, display_name = "Hreiti"},
    ["Hotevi"] = { latitude = 42.467876, longitude = 43.135786, display_name = "Hotevi"},
    ["Horiti"] = { latitude = 42.074583, longitude = 43.212767, display_name = "Horiti"},
    ["Honchiori"] = { latitude = 42.498535, longitude = 43.036221, display_name = "Honchiori"},
    ["Holodnaya Rechka"] = { latitude = 43.362803, longitude = 40.132876, display_name = "Holodnaya Rechka"},
    ["Hole"] = { latitude = 42.629201, longitude = 41.834447, display_name = "Hole"},
    ["Hidmagala"] = { latitude = 42.040528, longitude = 41.789749, display_name = "Hidmagala"},
    ["Hidistavi"] = { latitude = 41.962817, longitude = 42.192399, display_name = "Hidistavi"},
    ["Hidari"] = { latitude = 42.018357, longitude = 43.100231, display_name = "Hidari"},
    ["Hevi"] = { latitude = 41.964098, longitude = 42.278006, display_name = "Hevi"},
    ["Hetsera"] = { latitude = 42.431467, longitude = 41.879320, display_name = "Hetsera"},
    ["Heledi"] = { latitude = 42.794395, longitude = 42.640247, display_name = "Heledi"},
    ["Hatukay"] = { latitude = 45.193082, longitude = 39.661811, display_name = "Hatukay"},
    ["Hatazhukay"] = { latitude = 45.072561, longitude = 40.182799, display_name = "Hatazhukay"},
    ["Hasaut-Grecheskoe "] = { latitude = 43.714868, longitude = 41.668144, display_name = "Hasaut-Grecheskoe "},
    ["Hantski"] = { latitude = 42.578465, longitude = 42.222137, display_name = "Hantski"},
    ["Hanskaya"] = { latitude = 44.676366, longitude = 39.960442, display_name = "Hanskaya"},
    ["Hani"] = { latitude = 41.956643, longitude = 42.957650, display_name = "Hani"},
    ["Han'kov"] = { latitude = 45.163180, longitude = 37.866697, display_name = "Han'kov"},
    ["Hamyshki"] = { latitude = 44.100538, longitude = 40.129130, display_name = "Hamyshki"},
    ["Hamiskuri"] = { latitude = 42.387923, longitude = 41.809094, display_name = "Hamiskuri"},
    ["Halipauri"] = { latitude = 42.345266, longitude = 43.305217, display_name = "Halipauri"},
    ["Hadzhiko"] = { latitude = 44.008582, longitude = 39.333321, display_name = "Hadzhiko"},
    ["Hachemziy"] = { latitude = 44.955574, longitude = 40.318034, display_name = "Hachemziy"},
    ["Habez"] = { latitude = 44.042203, longitude = 41.765924, display_name = "Habez"},
    ["Habaz"] = { latitude = 43.730189, longitude = 42.931830, display_name = "Habaz"},
    ["h.im.Lenina"] = { latitude = 45.024109, longitude = 39.217630, display_name = "h.im.Lenina"},
    ["Gyuryul'deuk"] = { latitude = 43.981930, longitude = 42.060924, display_name = "Gyuryul'deuk"},
    ["Gvishtibi"] = { latitude = 42.313702, longitude = 42.570687, display_name = "Gvishtibi"},
    ["Gvimaroni"] = { latitude = 42.276655, longitude = 41.967510, display_name = "Gvimaroni"},
    ["Gverki"] = { latitude = 42.058676, longitude = 43.195791, display_name = "Gverki"},
    ["Gvankiti"] = { latitude = 42.168099, longitude = 42.981755, display_name = "Gvankiti"},
    ["Gvandra"] = { latitude = 43.046780, longitude = 40.908764, display_name = "Gvandra"},
    ["Gurna"] = { latitude = 42.403730, longitude = 42.854106, display_name = "Gurna"},
    ["Guriyskaya"] = { latitude = 44.663547, longitude = 39.614414, display_name = "Guriyskaya"},
    ["Gurianta"] = { latitude = 41.951175, longitude = 41.931424, display_name = "Gurianta"},
    ["Gupagu"] = { latitude = 42.890107, longitude = 41.593118, display_name = "Gupagu"},
    ["Gundelen"] = { latitude = 43.597443, longitude = 43.180901, display_name = "Gundelen"},
    ["Gundaeti"] = { latitude = 42.241907, longitude = 43.328842, display_name = "Gundaeti"},
    ["Gumista"] = { latitude = 43.027157, longitude = 40.945511, display_name = "Gumista"},
    ["Gumati"] = { latitude = 42.340711, longitude = 42.678726, display_name = "Gumati"},
    ["Guluheti"] = { latitude = 42.240583, longitude = 42.274605, display_name = "Guluheti"},
    ["Gubskaya"] = { latitude = 44.317053, longitude = 40.626591, display_name = "Gubskaya"},
    ["Gubistskali"] = { latitude = 42.304960, longitude = 42.519440, display_name = "Gubistskali"},
    ["Groznyy"] = { latitude = 44.558225, longitude = 40.132270, display_name = "Groznyy"},
    ["Grigor'evskaya"] = { latitude = 44.772915, longitude = 38.839703, display_name = "Grigor'evskaya"},
    ["Grigolishi"] = { latitude = 42.538524, longitude = 41.972442, display_name = "Grigolishi"},
    ["Grigalati"] = { latitude = 42.091739, longitude = 43.397697, display_name = "Grigalati"},
    ["Grebeshok"] = { latitude = 43.349031, longitude = 40.158298, display_name = "Grebeshok"},
    ["Grazhdanskoe"] = { latitude = 44.223626, longitude = 42.765001, display_name = "Grazhdanskoe"},
    ["Goyth"] = { latitude = 44.248215, longitude = 39.372450, display_name = "Goyth"},
    ["Gostagaevskaya"] = { latitude = 45.022014, longitude = 37.503797, display_name = "Gostagaevskaya"},
    ["Gornyy"] = { latitude = 44.284635, longitude = 39.276932, display_name = "Gornyy"},
    ["Gornyy"] = { latitude = 43.958726, longitude = 42.858514, display_name = "Gornyy"},
    ["Gorgadzeebi"] = { latitude = 41.719152, longitude = 41.779467, display_name = "Gorgadzeebi"},
    ["Goresha"] = { latitude = 42.075887, longitude = 43.257362, display_name = "Goresha"},
    ["Goraberezhouli"] = { latitude = 42.004796, longitude = 42.210148, display_name = "Goraberezhouli"},
    ["Gonio"] = { latitude = 41.563835, longitude = 41.573319, display_name = "Gonio"},
    ["Gonebiskari"] = { latitude = 41.902497, longitude = 42.089475, display_name = "Gonebiskari"},
    ["Goncharka"] = { latitude = 44.809236, longitude = 39.954964, display_name = "Goncharka"},
    ["Gomi"] = { latitude = 41.887530, longitude = 42.105644, display_name = "Gomi"},
    ["Gomi"] = { latitude = 42.613091, longitude = 43.534511, display_name = "Gomi"},
    ["Golubitskaya"] = { latitude = 45.325805, longitude = 37.273542, display_name = "Golubitskaya"},
    ["Golubeva Dacha"] = { latitude = 43.985387, longitude = 39.231989, display_name = "Golubeva Dacha"},
    ["Golovinka"] = { latitude = 43.800018, longitude = 39.460479, display_name = "Golovinka"},
    ["Golaskuri"] = { latitude = 42.237078, longitude = 41.979639, display_name = "Golaskuri"},
    ["Gogni"] = { latitude = 42.277496, longitude = 42.987314, display_name = "Gogni"},
    ["Gofitskoe"] = { latitude = 44.252679, longitude = 40.973461, display_name = "Gofitskoe"},
    ["Godogani"] = { latitude = 42.260281, longitude = 42.781294, display_name = "Godogani"},
    ["Gocha-Dzhihaishi"] = { latitude = 42.259725, longitude = 42.404511, display_name = "Gocha-Dzhihaishi"},
    ["Glola"] = { latitude = 42.703835, longitude = 43.646352, display_name = "Glola"},
    ["Glebovskoe"] = { latitude = 44.711034, longitude = 37.639464, display_name = "Glebovskoe"},
    ["Gimozgondzhili"] = { latitude = 42.261354, longitude = 41.952437, display_name = "Gimozgondzhili"},
    ["Gezati"] = { latitude = 42.222157, longitude = 42.259945, display_name = "Gezati"},
    ["Gerpegezh"] = { latitude = 43.375311, longitude = 43.654756, display_name = "Gerpegezh"},
    ["Germenchik"] = { latitude = 43.588735, longitude = 43.766319, display_name = "Germenchik"},
    ["Georgievskoe"] = { latitude = 44.164187, longitude = 39.251783, display_name = "Georgievskoe"},
    ["Georgievskaya"] = { latitude = 44.113588, longitude = 43.480279, display_name = "Georgievskaya"},
    ["Gelati"] = { latitude = 42.299240, longitude = 42.763434, display_name = "Gelati"},
    ["Geguti"] = { latitude = 42.171259, longitude = 42.674274, display_name = "Geguti"},
    ["Gedzheti"] = { latitude = 42.300316, longitude = 42.180255, display_name = "Gedzheti"},
    ["Gebi"] = { latitude = 42.769923, longitude = 43.506725, display_name = "Gebi"},
    ["Gay-Kodzor"] = { latitude = 44.855566, longitude = 37.436302, display_name = "Gay-Kodzor"},
    ["Gaverdovskiy"] = { latitude = 44.615979, longitude = 40.022495, display_name = "Gaverdovskiy"},
    ["Gautskinari"] = { latitude = 42.128638, longitude = 42.272212, display_name = "Gautskinari"},
    ["Gatlukay"] = { latitude = 44.893152, longitude = 39.232372, display_name = "Gatlukay"},
    ["Garkusha"] = { latitude = 45.321862, longitude = 36.849719, display_name = "Garkusha"},
    ["Garaha"] = { latitude = 42.517950, longitude = 42.154883, display_name = "Garaha"},
    ["Gantiadi"] = { latitude = 42.041995, longitude = 42.389471, display_name = "Gantiadi"},
    ["Ganardzhiis-Muhuri"] = { latitude = 42.425698, longitude = 41.627546, display_name = "Ganardzhiis-Muhuri"},
    ["Ganahleba"] = { latitude = 42.043143, longitude = 42.199876, display_name = "Ganahleba"},
    ["Ganahleba"] = { latitude = 42.929130, longitude = 41.276155, display_name = "Ganahleba"},
    ["Gamogma-Shua-Horga"] = { latitude = 42.269829, longitude = 41.795750, display_name = "Gamogma-Shua-Horga"},
    ["Gamogma Kariata"] = { latitude = 42.274404, longitude = 41.748423, display_name = "Gamogma Kariata"},
    ["Gahomela"] = { latitude = 42.347325, longitude = 42.191623, display_name = "Gahomela"},
    ["Gagma-Zanati"] = { latitude = 42.224803, longitude = 42.116445, display_name = "Gagma-Zanati"},
    ["Gagma-Shua-Horga"] = { latitude = 42.259303, longitude = 41.816329, display_name = "Gagma-Shua-Horga"},
    ["Gagma-Sadzhidzhao"] = { latitude = 42.365068, longitude = 42.038665, display_name = "Gagma-Sadzhidzhao"},
    ["Gagma-Dvabzu"] = { latitude = 41.952223, longitude = 42.074319, display_name = "Gagma-Dvabzu"},
    ["Gagma-Boslevi"] = { latitude = 42.187975, longitude = 43.175391, display_name = "Gagma-Boslevi"},
    ["Fontalovskaya"] = { latitude = 45.365963, longitude = 36.932416, display_name = "Fontalovskaya"},
    ["Feria"] = { latitude = 41.632954, longitude = 41.657343, display_name = "Feria"},
    ["Fedorovskaya"] = { latitude = 45.080625, longitude = 38.461367, display_name = "Fedorovskaya"},
    ["Fazannyy"] = { latitude = 44.039908, longitude = 43.589867, display_name = "Fazannyy"},
    ["Fadeevskiy"] = { latitude = 44.642871, longitude = 39.866300, display_name = "Fadeevskiy"},
    ["Fadeevo"] = { latitude = 45.068450, longitude = 37.549202, display_name = "Fadeevo"},
    ["Ezhedughabl'"] = { latitude = 44.978179, longitude = 39.704512, display_name = "Ezhedughabl'"},
    ["Evseevskiy"] = { latitude = 45.055579, longitude = 38.136915, display_name = "Evseevskiy"},
    ["Etseri"] = { latitude = 42.554075, longitude = 42.307231, display_name = "Etseri"},
    ["Etseri"] = { latitude = 42.259355, longitude = 43.163529, display_name = "Etseri"},
    ["Etseri"] = { latitude = 42.212272, longitude = 42.927395, display_name = "Etseri"},
    ["Etoko"] = { latitude = 43.948323, longitude = 43.173746, display_name = "Etoko"},
    ["Etoka"] = { latitude = 43.916666, longitude = 43.055886, display_name = "Etoka"},
    ["Esto-Sadok"] = { latitude = 43.688264, longitude = 40.257190, display_name = "Esto-Sadok"},
    ["Essentukskaya"] = { latitude = 44.029667, longitude = 42.870161, display_name = "Essentukskaya"},
    ["Erivanskaya"] = { latitude = 44.727221, longitude = 38.181969, display_name = "Erivanskaya"},
    ["Erik"] = { latitude = 44.586302, longitude = 39.697324, display_name = "Erik"},
    ["Ergeta"] = { latitude = 42.385459, longitude = 41.676872, display_name = "Ergeta"},
    ["Erge"] = { latitude = 41.562487, longitude = 41.695039, display_name = "Erge"},
    ["Energetik"] = { latitude = 44.071767, longitude = 43.093184, display_name = "Energetik"},
    ["Elizavetinskaya"] = { latitude = 45.047901, longitude = 38.795941, display_name = "Elizavetinskaya"},
    ["Elenovskoe"] = { latitude = 45.102689, longitude = 39.704562, display_name = "Elenovskoe"},
    ["El'tarkach"] = { latitude = 43.982717, longitude = 42.129497, display_name = "El'tarkach"},
    ["El'burgan"] = { latitude = 44.076878, longitude = 41.797260, display_name = "El'burgan"},
    ["El'brusskiy"] = { latitude = 43.568403, longitude = 42.134528, display_name = "El'brusskiy"},
    ["El'brus"] = { latitude = 43.253522, longitude = 42.644636, display_name = "El'brus"},
    ["Ekonomicheskoe"] = { latitude = 44.993663, longitude = 37.940817, display_name = "Ekonomicheskoe"},
    ["Ekaterinovskiy"] = { latitude = 45.091212, longitude = 38.487168, display_name = "Ekaterinovskiy"},
    ["Dzveli-Senaki"] = { latitude = 42.296082, longitude = 42.129269, display_name = "Dzveli-Senaki"},
    ["Dzveli-Hibula"] = { latitude = 42.451272, longitude = 41.939322, display_name = "Dzveli-Hibula"},
    ["Dzuluhi"] = { latitude = 42.026843, longitude = 42.617118, display_name = "Dzuluhi"},
    ["Dzuknuri"] = { latitude = 42.324671, longitude = 42.884988, display_name = "Dzuknuri"},
    ["Dzmuisi"] = { latitude = 42.428631, longitude = 42.914125, display_name = "Dzmuisi"},
    ["Dzirovani"] = { latitude = 42.351689, longitude = 42.944612, display_name = "Dzirovani"},
    ["Dziridzhumati"] = { latitude = 42.017218, longitude = 41.972763, display_name = "Dziridzhumati"},
    ["Dziguta"] = { latitude = 43.006590, longitude = 41.058366, display_name = "Dziguta"},
    ["Dziguri"] = { latitude = 42.238451, longitude = 42.148827, display_name = "Dziguri"},
    ["Dzhvarisa"] = { latitude = 42.383886, longitude = 42.812210, display_name = "Dzhvarisa"},
    ["Dzhurukveti"] = { latitude = 42.076304, longitude = 41.922513, display_name = "Dzhurukveti"},
    ["Dzhumiti 2-e"] = { latitude = 42.578580, longitude = 42.134227, display_name = "Dzhumiti 2-e"},
    ["Dzhumiti 1-e"] = { latitude = 42.551824, longitude = 42.104516, display_name = "Dzhumiti 1-e"},
    ["Dzhumi"] = { latitude = 42.451885, longitude = 41.873382, display_name = "Dzhumi"},
    ["Dzholevi"] = { latitude = 42.373371, longitude = 42.248034, display_name = "Dzholevi"},
    ["Dzhingirik"] = { latitude = 43.736185, longitude = 41.886758, display_name = "Dzhingirik"},
    ["Dzhimostaro"] = { latitude = 42.302029, longitude = 42.707023, display_name = "Dzhimostaro"},
    ["Dzhihaskari"] = { latitude = 42.511728, longitude = 42.017798, display_name = "Dzhihaskari"},
    ["Dzhiginka"] = { latitude = 45.135915, longitude = 37.340154, display_name = "Dzhiginka"},
    ["Dzhidzhihabl'"] = { latitude = 44.951191, longitude = 39.408519, display_name = "Dzhidzhihabl'"},
    ["Dzhgydyrhva"] = { latitude = 43.178246, longitude = 40.703367, display_name = "Dzhgydyrhva"},
    ["Dzhgerda"] = { latitude = 42.910810, longitude = 41.361978, display_name = "Dzhgerda"},
    ["Dzherokay"] = { latitude = 44.990610, longitude = 40.307349, display_name = "Dzherokay"},
    ["Dzheguta"] = { latitude = 43.967182, longitude = 42.043303, display_name = "Dzheguta"},
    ["Dzhapshakari"] = { latitude = 42.409636, longitude = 41.979744, display_name = "Dzhapshakari"},
    ["Dzhapana"] = { latitude = 42.095931, longitude = 42.193642, display_name = "Dzhapana"},
    ["Dzhambichi"] = { latitude = 45.089652, longitude = 39.854614, display_name = "Dzhambichi"},
    ["Dzhalaurta"] = { latitude = 42.248976, longitude = 43.388858, display_name = "Dzhalaurta"},
    ["Dzhahunderi"] = { latitude = 42.799916, longitude = 43.022380, display_name = "Dzhahunderi"},
    ["Dzhagira"] = { latitude = 42.539297, longitude = 42.056917, display_name = "Dzhagira"},
    ["Dzhaga"] = { latitude = 43.954443, longitude = 42.558665, display_name = "Dzhaga"},
    ["Dzedzileti"] = { latitude = 42.422529, longitude = 42.560392, display_name = "Dzedzileti"},
    ["Dutshuni"] = { latitude = 42.014905, longitude = 42.472516, display_name = "Dutshuni"},
    ["Durgena"] = { latitude = 42.240344, longitude = 41.939394, display_name = "Durgena"},
    ["Dukmasov"] = { latitude = 45.007570, longitude = 39.914292, display_name = "Dukmasov"},
    ["Druzhnyy"] = { latitude = 44.733770, longitude = 39.770438, display_name = "Druzhnyy"},
    ["Druzhelyubnyy"] = { latitude = 45.128403, longitude = 39.157197, display_name = "Druzhelyubnyy"},
    ["Druzhba"] = { latitude = 44.202308, longitude = 42.015159, display_name = "Druzhba"},
    ["Doshake"] = { latitude = 42.522922, longitude = 42.247888, display_name = "Doshake"},
    ["Dolina"] = { latitude = 44.237984, longitude = 42.933208, display_name = "Dolina"},
    ["Dolgogusevskiy"] = { latitude = 44.813826, longitude = 39.783494, display_name = "Dolgogusevskiy"},
    ["Dinskaya"] = { latitude = 45.216067, longitude = 39.228527, display_name = "Dinskaya"},
    ["Dimi"] = { latitude = 42.103108, longitude = 42.814050, display_name = "Dimi"},
    ["Dilikauri"] = { latitude = 42.156207, longitude = 43.097258, display_name = "Dilikauri"},
    ["Dihazurga"] = { latitude = 42.609395, longitude = 41.858275, display_name = "Dihazurga"},
    ["Dihashkho"] = { latitude = 42.070267, longitude = 42.560686, display_name = "Dihashkho"},
    ["Didvela"] = { latitude = 42.128678, longitude = 42.773856, display_name = "Didvela"},
    ["Didi-Opeti"] = { latitude = 42.067712, longitude = 42.370916, display_name = "Didi-Opeti"},
    ["Didi-Nedzis-Kahati"] = { latitude = 42.426746, longitude = 41.725656, display_name = "Didi-Nedzis-Kahati"},
    ["Didi-Nedzi"] = { latitude = 42.401566, longitude = 41.698956, display_name = "Didi-Nedzi"},
    ["Didi-Kuhi"] = { latitude = 42.292505, longitude = 42.452544, display_name = "Didi-Kuhi"},
    ["Didi-Horshi"] = { latitude = 42.341781, longitude = 42.084974, display_name = "Didi-Horshi"},
    ["Didi-Gantiadi"] = { latitude = 42.097633, longitude = 43.182894, display_name = "Didi-Gantiadi"},
    ["Didi-Dzhihaishi"] = { latitude = 42.235623, longitude = 42.438275, display_name = "Didi-Dzhihaishi"},
    ["Didi-Chkoni"] = { latitude = 42.494580, longitude = 42.312053, display_name = "Didi-Chkoni"},
    ["Dgvaba"] = { latitude = 42.345038, longitude = 41.733485, display_name = "Dgvaba"},
    ["Dgnorisa"] = { latitude = 42.469657, longitude = 42.815037, display_name = "Dgnorisa"},
    ["Derchi"] = { latitude = 42.468882, longitude = 42.773539, display_name = "Derchi"},
    ["Derbentskaya"] = { latitude = 44.768096, longitude = 38.498924, display_name = "Derbentskaya"},
    ["Deisi"] = { latitude = 41.967611, longitude = 43.351327, display_name = "Deisi"},
    ["Dehviri"] = { latitude = 42.624887, longitude = 42.770402, display_name = "Dehviri"},
    ["Defanovka"] = { latitude = 44.432955, longitude = 38.780654, display_name = "Defanovka"},
    ["Dedalauri"] = { latitude = 42.354735, longitude = 42.515552, display_name = "Dedalauri"},
    ["Davitiani"] = { latitude = 42.458197, longitude = 41.780691, display_name = "Davitiani"},
    ["Dausuz"] = { latitude = 43.799532, longitude = 41.550776, display_name = "Dausuz"},
    ["Darcheli"] = { latitude = 42.440610, longitude = 41.691733, display_name = "Darcheli"},
    ["Dapnari"] = { latitude = 42.103547, longitude = 42.334468, display_name = "Dapnari"},
    ["Damanka"] = { latitude = 44.971429, longitude = 37.786142, display_name = "Damanka"},
    ["Dahovskaya"] = { latitude = 44.231585, longitude = 40.205041, display_name = "Dahovskaya"},
    ["Dagestanskaya"] = { latitude = 44.377390, longitude = 40.019213, display_name = "Dagestanskaya"},
    ["Dabla-Gomi"] = { latitude = 42.092557, longitude = 42.383587, display_name = "Dabla-Gomi"},
    ["Dabadzveli"] = { latitude = 42.326223, longitude = 42.921560, display_name = "Dabadzveli"},
    ["Chvele"] = { latitude = 42.681685, longitude = 41.980907, display_name = "Chvele"},
    ["Chuneshi"] = { latitude = 42.356359, longitude = 42.566710, display_name = "Chuneshi"},
    ["Chukuli"] = { latitude = 42.811275, longitude = 43.016349, display_name = "Chukuli"},
    ["Chuburhindzhi"] = { latitude = 42.582487, longitude = 41.806660, display_name = "Chuburhindzhi"},
    ["Chorvila"] = { latitude = 42.284002, longitude = 43.416914, display_name = "Chorvila"},
    ["Chordzho-Didi"] = { latitude = 42.562477, longitude = 43.053728, display_name = "Chordzho-Didi"},
    ["Chognari"] = { latitude = 42.087419, longitude = 42.284283, display_name = "Chognari"},
    ["Chognari"] = { latitude = 42.220218, longitude = 42.760049, display_name = "Chognari"},
    ["Chochkhati"] = { latitude = 42.034916, longitude = 41.884302, display_name = "Chochkhati"},
    ["Chlou"] = { latitude = 42.872872, longitude = 41.493654, display_name = "Chlou"},
    ["Chkvishi"] = { latitude = 42.124911, longitude = 42.435224, display_name = "Chkvishi"},
    ["Chkvaleri"] = { latitude = 42.719689, longitude = 42.088272, display_name = "Chkvaleri"},
    ["Chkonagora"] = { latitude = 42.088123, longitude = 42.140278, display_name = "Chkonagora"},
    ["Chkhuteli"] = { latitude = 42.649842, longitude = 42.789429, display_name = "Chkhuteli"},
    ["Chkhoria"] = { latitude = 42.605132, longitude = 41.954171, display_name = "Chkhoria"},
    ["Chkhenishi"] = { latitude = 42.228963, longitude = 42.314718, display_name = "Chkhenishi"},
    ["Chkaduashi"] = { latitude = 42.599065, longitude = 42.017694, display_name = "Chkaduashi"},
    ["Chitatskari"] = { latitude = 42.472242, longitude = 41.852826, display_name = "Chitatskari"},
    ["Chiora"] = { latitude = 42.746269, longitude = 43.553631, display_name = "Chiora"},
    ["Chihu"] = { latitude = 42.325806, longitude = 41.889458, display_name = "Chihu"},
    ["Chiha"] = { latitude = 42.348364, longitude = 43.444360, display_name = "Chiha"},
    ["Chernyshov"] = { latitude = 45.053069, longitude = 40.037395, display_name = "Chernyshov"},
    ["Chernomorskaya"] = { latitude = 44.702545, longitude = 39.359728, display_name = "Chernomorskaya"},
    ["Chernigovskoe"] = { latitude = 44.255092, longitude = 39.760512, display_name = "Chernigovskoe"},
    ["Chernigovskaya"] = { latitude = 44.703771, longitude = 39.668488, display_name = "Chernigovskaya"},
    ["Chernigovka"] = { latitude = 43.014930, longitude = 41.164718, display_name = "Chernigovka"},
    ["Chernaya Rechka"] = { latitude = 43.609516, longitude = 43.836128, display_name = "Chernaya Rechka"},
    ["Chereshnya"] = { latitude = 43.444920, longitude = 39.980335, display_name = "Chereshnya"},
    ["Chemitokvadze"] = { latitude = 43.839550, longitude = 39.417020, display_name = "Chemitokvadze"},
    ["Chemburka"] = { latitude = 44.931292, longitude = 37.340168, display_name = "Chemburka"},
    ["Chekon"] = { latitude = 45.109331, longitude = 37.506382, display_name = "Chekon"},
    ["Chegem 2-y"] = { latitude = 43.590681, longitude = 43.599375, display_name = "Chegem 2-y"},
    ["Chapaevskoe"] = { latitude = 44.286271, longitude = 42.063673, display_name = "Chapaevskoe"},
    ["Chalatke"] = { latitude = 42.146661, longitude = 43.025774, display_name = "Chalatke"},
    ["Chala"] = { latitude = 41.929410, longitude = 42.048230, display_name = "Chala"},
    ["Chakvindzhi"] = { latitude = 42.487273, longitude = 41.979719, display_name = "Chakvindzhi"},
    ["Chaisubani"] = { latitude = 41.696688, longitude = 41.781638, display_name = "Chaisubani"},
    ["Chagani"] = { latitude = 42.227874, longitude = 42.373545, display_name = "Chagani"},
    ["Chagan-Tskvishi"] = { latitude = 42.122079, longitude = 42.415750, display_name = "Chagan-Tskvishi"},
    ["Chabanlug"] = { latitude = 43.106712, longitude = 40.797033, display_name = "Chabanlug"},
    ["Bzybta 5-y km"] = { latitude = 43.285386, longitude = 40.395535, display_name = "Bzybta 5-y km"},
    ["Bzybta 3-y km"] = { latitude = 43.269965, longitude = 40.394210, display_name = "Bzybta 3-y km"},
    ["Bzheduhovskaya"] = { latitude = 44.841591, longitude = 39.679353, display_name = "Bzheduhovskaya"},
    ["Bynthva"] = { latitude = 43.156061, longitude = 40.739326, display_name = "Bynthva"},
    ["BYLYM"] = { latitude = 43.461933, longitude = 43.040023, display_name = "BYLYM"},
    ["Bykogorka"] = { latitude = 44.182870, longitude = 42.944364, display_name = "Bykogorka"},
    ["Bulitsku"] = { latitude = 42.353732, longitude = 41.883748, display_name = "Bulitsku"},
    ["Buknari"] = { latitude = 41.999917, longitude = 42.167892, display_name = "Buknari"},
    ["Bratskiy"] = { latitude = 45.233923, longitude = 39.952950, display_name = "Bratskiy"},
    ["Bostana"] = { latitude = 42.550059, longitude = 43.075697, display_name = "Bostana"},
    ["Borodynovka"] = { latitude = 44.146297, longitude = 43.133294, display_name = "Borodynovka"},
    ["Borisovka"] = { latitude = 44.757955, longitude = 37.694273, display_name = "Borisovka"},
    ["Bori"] = { latitude = 42.057428, longitude = 43.117675, display_name = "Bori"},
    ["Borgustanskaya"] = { latitude = 44.054855, longitude = 42.528751, display_name = "Borgustanskaya"},
    ["Bonchkovskiy"] = { latitude = 44.895977, longitude = 38.755977, display_name = "Bonchkovskiy"},
    ["Bolgov"] = { latitude = 45.235017, longitude = 39.885843, display_name = "Bolgov"},
    ["Bol.Raznokol"] = { latitude = 45.146444, longitude = 37.460326, display_name = "Bol.Raznokol"},
    ["Bol'shie Hutora"] = { latitude = 44.747716, longitude = 37.598760, display_name = "Bol'shie Hutora"},
    ["Bol'shesidorovskoe"] = { latitude = 45.036635, longitude = 39.838694, display_name = "Bol'shesidorovskoe"},
    ["Blagoveschenskaya"] = { latitude = 45.057185, longitude = 37.126383, display_name = "Blagoveschenskaya"},
    ["Bia"] = { latitude = 42.344970, longitude = 41.920094, display_name = "Bia"},
    ["Bezymyannoe"] = { latitude = 44.553021, longitude = 39.125341, display_name = "Bezymyannoe"},
    ["Bezengi"] = { latitude = 43.216814, longitude = 43.286057, display_name = "Bezengi"},
    ["Betlemi"] = { latitude = 42.381164, longitude = 42.203732, display_name = "Betlemi"},
    ["Besstrashnaya"] = { latitude = 44.253809, longitude = 41.142638, display_name = "Besstrashnaya"},
    ["Besleney"] = { latitude = 44.245709, longitude = 41.739140, display_name = "Besleney"},
    ["Berezovyy"] = { latitude = 45.150230, longitude = 38.989015, display_name = "Berezovyy"},
    ["Belyy Ugol'"] = { latitude = 44.022682, longitude = 42.805498, display_name = "Belyy Ugol'"},
    ["Belyy"] = { latitude = 45.170924, longitude = 37.268281, display_name = "Belyy"},
    ["Belozernyy"] = { latitude = 45.063400, longitude = 38.674394, display_name = "Belozernyy"},
    ["Belokamenskoe"] = { latitude = 43.883528, longitude = 43.022891, display_name = "Belokamenskoe"},
    ["Beloe"] = { latitude = 45.051372, longitude = 39.647983, display_name = "Beloe"},
    ["Bekeshevskaya"] = { latitude = 44.114902, longitude = 42.433215, display_name = "Bekeshevskaya"},
    ["Bazaleti"] = { latitude = 42.034984, longitude = 43.206468, display_name = "Bazaleti"},
    ["Bateh"] = { latitude = 43.853210, longitude = 43.231378, display_name = "Bateh"},
    ["Bataria"] = { latitude = 42.287102, longitude = 42.014499, display_name = "Bataria"},
    ["Bashi"] = { latitude = 42.566591, longitude = 41.926095, display_name = "Bashi"},
    ["Bardubani"] = { latitude = 42.210034, longitude = 42.886425, display_name = "Bardubani"},
    ["Baranovka"] = { latitude = 43.677734, longitude = 39.708917, display_name = "Baranovka"},
    ["Baranikovskiy"] = { latitude = 45.344972, longitude = 38.014303, display_name = "Baranikovskiy"},
    ["Banodzha"] = { latitude = 42.287579, longitude = 42.657884, display_name = "Banodzha"},
    ["Bandza"] = { latitude = 42.348392, longitude = 42.286405, display_name = "Bandza"},
    ["Baksanenok"] = { latitude = 43.687349, longitude = 43.656569, display_name = "Baksanenok"},
    ["Bakinskaya"] = { latitude = 44.768913, longitude = 39.281876, display_name = "Bakinskaya"},
    ["Bagmarani"] = { latitude = 42.470354, longitude = 41.960753, display_name = "Bagmarani"},
    ["Baglan"] = { latitude = 42.830993, longitude = 41.177605, display_name = "Baglan"},
    ["Bagikyta"] = { latitude = 43.128318, longitude = 40.696648, display_name = "Bagikyta"},
    ["Babugent"] = { latitude = 43.275353, longitude = 43.545330, display_name = "Babugent"},
    ["Azovskaya"] = { latitude = 44.793619, longitude = 38.616989, display_name = "Azovskaya"},
    ["Aushiger"] = { latitude = 43.395553, longitude = 43.735509, display_name = "Aushiger"},
    ["Atydzta"] = { latitude = 43.210846, longitude = 40.392670, display_name = "Atydzta"},
    ["Atsydzhkva"] = { latitude = 43.202142, longitude = 40.342933, display_name = "Atsydzhkva"},
    ["Assokolay"] = { latitude = 44.845762, longitude = 39.469337, display_name = "Assokolay"},
    ["Ashe"] = { latitude = 43.959800, longitude = 39.273025, display_name = "Ashe"},
    ["Asfal'tovaya Gora"] = { latitude = 44.463265, longitude = 39.445555, display_name = "Asfal'tovaya Gora"},
    ["Armyanskiy"] = { latitude = 44.863314, longitude = 37.993278, display_name = "Armyanskiy"},
    ["Arhyz"] = { latitude = 43.565971, longitude = 41.279307, display_name = "Arhyz"},
    ["Arhipovskoe"] = { latitude = 45.011892, longitude = 39.852296, display_name = "Arhipovskoe"},
    ["Argveta"] = { latitude = 42.142478, longitude = 42.986815, display_name = "Argveta"},
    ["Arasadzyh"] = { latitude = 43.233581, longitude = 40.322434, display_name = "Arasadzyh"},
    ["Aosyrhva"] = { latitude = 43.198313, longitude = 40.722300, display_name = "Aosyrhva"},
    ["Anuhva"] = { latitude = 43.121339, longitude = 40.810995, display_name = "Anuhva"},
    ["Anhashtun"] = { latitude = 43.235568, longitude = 40.493729, display_name = "Anhashtun"},
    ["Angisa"] = { latitude = 41.631328, longitude = 41.604173, display_name = "Angisa"},
    ["Andreevskiy"] = { latitude = 44.228128, longitude = 43.626096, display_name = "Andreevskiy"},
    ["Andreevskaya"] = { latitude = 45.320084, longitude = 38.666237, display_name = "Andreevskaya"},
    ["Anastasievskaya"] = { latitude = 45.220343, longitude = 37.887568, display_name = "Anastasievskaya"},
    ["Anapskaya"] = { latitude = 44.900888, longitude = 37.383960, display_name = "Anapskaya"},
    ["Anaklia"] = { latitude = 42.395927, longitude = 41.594732, display_name = "Anaklia"},
    ["Amzara"] = { latitude = 43.092069, longitude = 40.991820, display_name = "Amzara"},
    ["Amtkel"] = { latitude = 43.036020, longitude = 41.317733, display_name = "Amtkel"},
    ["Amsaisi"] = { latitude = 42.135288, longitude = 43.169279, display_name = "Amsaisi"},
    ["Amagleba"] = { latitude = 42.085251, longitude = 42.627377, display_name = "Amagleba"},
    ["Altud"] = { latitude = 43.719412, longitude = 43.869467, display_name = "Altud"},
    ["Alioni"] = { latitude = 42.284723, longitude = 41.949045, display_name = "Alioni"},
    ["Ali-Berdukovskiy"] = { latitude = 43.988847, longitude = 41.737681, display_name = "Ali-Berdukovskiy"},
    ["Aleksee-Tenginskaya"] = { latitude = 45.210939, longitude = 40.179187, display_name = "Aleksee-Tenginskaya"},
    ["Aleksandrovskiy"] = { latitude = 45.255475, longitude = 40.053689, display_name = "Aleksandrovskiy"},
    ["Alaverdi"] = { latitude = 42.052523, longitude = 43.065241, display_name = "Alaverdi"},
    ["Alambari"] = { latitude = 41.827980, longitude = 41.873672, display_name = "Alambari"},
    ["Alahadzy"] = { latitude = 43.221239, longitude = 40.306870, display_name = "Alahadzy"},
    ["Al'piyskoe"] = { latitude = 43.290388, longitude = 40.273733, display_name = "Al'piyskoe"},
    ["Akvara"] = { latitude = 43.239058, longitude = 40.387451, display_name = "Akvara"},
    ["Akvacha"] = { latitude = 43.114639, longitude = 40.833294, display_name = "Akvacha"},
    ["Akapa"] = { latitude = 43.037614, longitude = 41.123880, display_name = "Akapa"},
    ["Akalamra"] = { latitude = 43.111710, longitude = 40.775246, display_name = "Akalamra"},
    ["Ahuti"] = { latitude = 42.471687, longitude = 42.171137, display_name = "Ahuti"},
    ["Ahtanizovskaya"] = { latitude = 45.327959, longitude = 37.106970, display_name = "Ahtanizovskaya"},
    ["Ahmetovskaya"] = { latitude = 44.151458, longitude = 41.050762, display_name = "Ahmetovskaya"},
    ["Ahalsopeli"] = { latitude = 42.251948, longitude = 42.069669, display_name = "Ahalsopeli"},
    ["Ahalsopeli"] = { latitude = 42.310765, longitude = 42.949723, display_name = "Ahalsopeli"},
    ["Ahalsopeli"] = { latitude = 41.579313, longitude = 41.592645, display_name = "Ahalsopeli"},
    ["Ahalsopeli"] = { latitude = 42.166163, longitude = 42.395170, display_name = "Ahalsopeli"},
    ["Ahalsopeli"] = { latitude = 42.054131, longitude = 41.841410, display_name = "Ahalsopeli"},
    ["Ahalsheni"] = { latitude = 41.971235, longitude = 42.443065, display_name = "Ahalsheni"},
    ["Ahalsheni"] = { latitude = 41.624355, longitude = 41.709249, display_name = "Ahalsheni"},
    ["Ahalsheni"] = { latitude = 43.118808, longitude = 41.020391, display_name = "Ahalsheni"},
    ["Ahalkahati"] = { latitude = 42.468560, longitude = 41.733919, display_name = "Ahalkahati"},
    ["Ahali-Terzhola"] = { latitude = 42.232184, longitude = 42.976529, display_name = "Ahali-Terzhola"},
    ["Ahali-Sviri"] = { latitude = 42.161011, longitude = 42.903090, display_name = "Ahali-Sviri"},
    ["Ahali-Kindgi"] = { latitude = 42.797881, longitude = 41.273547, display_name = "Ahali-Kindgi"},
    ["Ahali-Abastumani"] = { latitude = 42.529007, longitude = 41.816390, display_name = "Ahali-Abastumani"},
    ["Ahalhibula"] = { latitude = 42.435747, longitude = 42.009298, display_name = "Ahalhibula"},
    ["Ahalbediseuli"] = { latitude = 42.382299, longitude = 42.478211, display_name = "Ahalbediseuli"},
    ["Agvavera"] = { latitude = 42.733256, longitude = 41.741064, display_name = "Agvavera"},
    ["Aguy_Shapsug"] = { latitude = 44.183957, longitude = 39.065643, display_name = "Aguy_Shapsug"},
    ["Agronom"] = { latitude = 45.143214, longitude = 39.189885, display_name = "Agronom"},
    ["Agoy"] = { latitude = 44.148270, longitude = 39.033715, display_name = "Agoy"},
    ["Agaraki"] = { latitude = 43.201028, longitude = 40.412177, display_name = "Agaraki"},
    ["Afipsip"] = { latitude = 44.995201, longitude = 38.777506, display_name = "Afipsip"},
    ["Adzigezh"] = { latitude = 43.065018, longitude = 40.951904, display_name = "Adzigezh"},
    ["Adzhkhahara"] = { latitude = 43.206934, longitude = 40.489845, display_name = "Adzhkhahara"},
    ["Adzhazhv"] = { latitude = 42.803694, longitude = 41.475439, display_name = "Adzhazhv"},
    ["Adzhapsha"] = { latitude = 43.095728, longitude = 40.735466, display_name = "Adzhapsha"},
    ["Adzhameti"] = { latitude = 42.190927, longitude = 42.795745, display_name = "Adzhameti"},
    ["Adlia"] = { latitude = 41.616935, longitude = 41.603396, display_name = "Adlia"},
    ["Aderbievka"] = { latitude = 44.603960, longitude = 38.106226, display_name = "Aderbievka"},
    ["Adamiy"] = { latitude = 45.072339, longitude = 39.495960, display_name = "Adamiy"},
    ["Adagum"] = { latitude = 45.095386, longitude = 37.722798, display_name = "Adagum"},
    ["Achkvistavi"] = { latitude = 41.829486, longitude = 41.912643, display_name = "Achkvistavi"},
    ["Abzhakva"] = { latitude = 43.025609, longitude = 41.068063, display_name = "Abzhakva"},
    ["Abgarhuk"] = { latitude = 43.115109, longitude = 40.701987, display_name = "Abgarhuk"},
    ["Abedati"] = { latitude = 42.386144, longitude = 42.278763, display_name = "Abedati"},
    ["Abastumani"] = { latitude = 42.396615, longitude = 41.876711, display_name = "Abastumani"},
    ["Abashispiri"] = { latitude = 42.207775, longitude = 42.166122, display_name = "Abashispiri"},
    ["Abanoeti"] = { latitude = 42.539051, longitude = 43.024062, display_name = "Abanoeti"},
    ["Abadzehskaya"] = { latitude = 44.393866, longitude = 40.217713, display_name = "Abadzehskaya"},
    ["Aatsy"] = { latitude = 43.135637, longitude = 40.731036, display_name = "Aatsy"},
    ["Aualitsa"] = { latitude = 43.171207, longitude = 40.665543, display_name = "Aualitsa"},
    ["Mugudzyrhva"] = { latitude = 43.155409, longitude = 40.515015, display_name = "Mugudzyrhva"},
    ["Othara"] = { latitude = 43.228966, longitude = 40.531859, display_name = "Othara"},
    ["Achkatsa"] = { latitude = 43.147649, longitude = 40.685803, display_name = "Achkatsa"},
    ["Tvanaarhu"] = { latitude = 43.197101, longitude = 40.652253, display_name = "Tvanaarhu"},
    ["Duripsh"] = { latitude = 43.206697, longitude = 40.624055, display_name = "Duripsh"},
    ["Abgara"] = { latitude = 43.190179, longitude = 40.624511, display_name = "Abgara"},
    ["Synyrhva"] = { latitude = 43.192922, longitude = 40.552701, display_name = "Synyrhva"},
    ["Dzhirhva"] = { latitude = 43.206313, longitude = 40.548323, display_name = "Dzhirhva"},
    ["Bgardvany"] = { latitude = 43.205393, longitude = 40.595447, display_name = "Bgardvany"},
    ["Arhva"] = { latitude = 43.226315, longitude = 40.572106, display_name = "Arhva"},
    ["Garp"] = { latitude = 43.237879, longitude = 40.546746, display_name = "Garp"},
    ["Adzhimchigra"] = { latitude = 43.167841, longitude = 40.614085, display_name = "Adzhimchigra"},
    ["Adzlagara"] = { latitude = 43.148709, longitude = 40.623547, display_name = "Adzlagara"},
    ["Algyt"] = { latitude = 43.127564, longitude = 40.557333, display_name = "Algyt"},
    ["Mzahva"] = { latitude = 43.137750, longitude = 40.584290, display_name = "Mzahva"},
    ["Ahalsopeli"] = { latitude = 43.141474, longitude = 40.553312, display_name = "Ahalsopeli"},
    ["Tushurebi"] = { latitude = 42.122766, longitude = 44.912051, display_name = "Tushurebi"},
    ["Aloti"] = { latitude = 42.051855, longitude = 44.950279, display_name = "Aloti"},
    ["Kvemo-Chala"] = { latitude = 42.029348, longitude = 44.394200, display_name = "Kvemo-Chala"},
    ["Mchadidzhvari"] = { latitude = 42.020135, longitude = 44.596836, display_name = "Mchadidzhvari"},
    ["Lamiskana"] = { latitude = 42.013894, longitude = 44.490553, display_name = "Lamiskana"},
    ["Igoeti"] = { latitude = 41.991304, longitude = 44.413732, display_name = "Igoeti"},
    ["Okami"] = { latitude = 41.983290, longitude = 44.474383, display_name = "Okami"},
    ["Ksovrisi"] = { latitude = 41.983403, longitude = 44.525294, display_name = "Ksovrisi"},
    ["Magraneti"] = { latitude = 41.933666, longitude = 44.988583, display_name = "Magraneti"},
    ["Misaktsieli"] = { latitude = 41.948382, longitude = 44.738270, display_name = "Misaktsieli"},
    ["Metekhi"] = { latitude = 41.923040, longitude = 44.340959, display_name = "Metekhi"},
    ["Khovle"] = { latitude = 41.895157, longitude = 44.239944, display_name = "Khovle"},
    ["Zemo-Khandaki"] = { latitude = 41.901323, longitude = 44.313301, display_name = "Zemo-Khandaki"},
    ["Garikula"] = { latitude = 41.881470, longitude = 44.334464, display_name = "Garikula"},
    ["Agayani"] = { latitude = 41.913671, longitude = 44.546796, display_name = "Agayani"},
    ["Tskhvarichamia"] = { latitude = 41.880083, longitude = 44.913670, display_name = "Tskhvarichamia"},
    ["Saguramo"] = { latitude = 41.898619, longitude = 44.760362, display_name = "Saguramo"},
    ["Kavtishevi"] = { latitude = 41.856681, longitude = 44.442001, display_name = "Kavtishevi"},
    ["Gorovani"] = { latitude = 41.884935, longitude = 44.670882, display_name = "Gorovani"},
    ["Gldani"] = { latitude = 41.823116, longitude = 44.825815, display_name = "Gldani"},
    ["Dzegvi"] = { latitude = 41.846163, longitude = 44.604396, display_name = "Dzegvi"},
    ["Norio"] = { latitude = 41.790500, longitude = 44.979697, display_name = "Norio"},
    ["Tabakhmela"] = { latitude = 41.653487, longitude = 44.754861, display_name = "Tabakhmela"},
    ["farm Krtsanisi"] = { latitude = 41.615412, longitude = 44.908523, display_name = "farm Krtsanisi"},
    ["Gamardzhveba"] = { latitude = 41.651053, longitude = 44.988995, display_name = "Gamardzhveba"},
    ["Karadzhalari"] = { latitude = 41.622402, longitude = 44.962092, display_name = "Karadzhalari"},
    ["Karatagla"] = { latitude = 41.598333, longitude = 44.978450, display_name = "Karatagla"},
    ["Asureti"] = { latitude = 41.593966, longitude = 44.671603, display_name = "Asureti"},
    ["Tsintskaro"] = { latitude = 41.541691, longitude = 44.617983, display_name = "Tsintskaro"},
    ["Kolagiri"] = { latitude = 41.472666, longitude = 44.715622, display_name = "Kolagiri"},
    ["Azizkendi"] = { latitude = 41.421746, longitude = 44.945430, display_name = "Azizkendi"},
    ["Didi-Mughanlo"] = { latitude = 41.389660, longitude = 44.957250, display_name = "Didi-Mughanlo"},
    ["Kizil-Adzhlo"] = { latitude = 41.480203, longitude = 44.767707, display_name = "Kizil-Adzhlo"},
    ["State Farm Samgori"] = { latitude = 41.597409, longitude = 45.028851, display_name = "State Farm Samgori"},
    ["Birliki"] = { latitude = 41.487802, longitude = 45.072609, display_name = "Birliki"},
    ["Hashmi"] = { latitude = 41.758709, longitude = 45.189443, display_name = "Hashmi"},
    ["Jandari"] = { latitude = 41.447936, longitude = 45.168489, display_name = "Jandari"},
    ["Nazarlo"] = { latitude = 41.423063, longitude = 45.111234, display_name = "Nazarlo"},
    ["Patardzeuli"] = { latitude = 41.744385, longitude = 45.248301, display_name = "Patardzeuli"},
    ["Zhinvali"] = { latitude = 42.145771, longitude = 44.772532, display_name = "Zhinvali"},
    ["Zhinvali"] = { latitude = 42.109544, longitude = 44.765639, display_name = "Zhinvali"},
    ["Tianeti"] = { latitude = 42.109786, longitude = 44.965735, display_name = "Tianeti"},
    ["Didi-Lilo"] = { latitude = 41.737000, longitude = 44.964292, display_name = "Didi-Lilo"},
    ["Manglisi"] = { latitude = 41.699392, longitude = 44.373647, display_name = "Manglisi"},
    ["ZAGES"] = { latitude = 41.825864, longitude = 44.757579, display_name = "ZAGES"},
    ["Sioni"] = { latitude = 41.990655, longitude = 45.028461, display_name = "Sioni"},
    ["Metekhi"] = { latitude = 41.942381, longitude = 44.339043, display_name = "Metekhi"},
    ["settlement workers"] = { latitude = 41.871657, longitude = 44.723509, display_name = "settlement workers"},
    ["p.Hramzavodstroya"] = { latitude = 41.671265, longitude = 44.916548, display_name = "p.Hramzavodstroya"},
    ["Kiketi"] = { latitude = 41.653426, longitude = 44.650357, display_name = "Kiketi"},
    ["Vaziani"] = { latitude = 41.693761, longitude = 45.053892, display_name = "Vaziani"},
    ["MTSKHETA"] = { latitude = 41.836870, longitude = 44.696831, display_name = "MTSKHETA"},
    ["Dzartsemi"] = { latitude = 42.301195, longitude = 43.966521, display_name = "Dzartsemi"},
    ["Dzari"] = { latitude = 42.292148, longitude = 43.872880, display_name = "Dzari"},
    ["Zemo-Dodoti"] = { latitude = 42.270493, longitude = 43.888601, display_name = "Zemo-Dodoti"},
    ["Khetagurov"] = { latitude = 42.212180, longitude = 43.892906, display_name = "Khetagurov"},
    ["Ergneti"] = { latitude = 42.198008, longitude = 43.993198, display_name = "Ergneti"},
    ["Zemo-Nikozi"] = { latitude = 42.198215, longitude = 43.959361, display_name = "Zemo-Nikozi"},
    ["Avnevi"] = { latitude = 42.194477, longitude = 43.876406, display_name = "Avnevi"},
    ["Didmukha"] = { latitude = 42.175856, longitude = 43.880354, display_name = "Didmukha"},
    ["Phvenisi"] = { latitude = 42.157559, longitude = 43.992365, display_name = "Phvenisi"},
    ["Dirbi"] = { latitude = 42.113711, longitude = 43.874980, display_name = "Dirbi"},
    ["Sakasheti"] = { latitude = 42.093926, longitude = 43.970841, display_name = "Sakasheti"},
    ["Dzlevidzhvari"] = { latitude = 42.106787, longitude = 43.929563, display_name = "Dzlevidzhvari"},
    ["Tsveri"] = { latitude = 42.074543, longitude = 43.886696, display_name = "Tsveri"},
    ["Kvemo-Hvedureti"] = { latitude = 42.004504, longitude = 43.933894, display_name = "Kvemo-Hvedureti"},
    ["Charebi"] = { latitude = 42.266892, longitude = 44.113843, display_name = "Charebi"},
    ["Satihari"] = { latitude = 42.256968, longitude = 44.085042, display_name = "Satihari"},
    ["Eredvi"] = { latitude = 42.246823, longitude = 44.035496, display_name = "Eredvi"},
    ["Berula"] = { latitude = 42.237767, longitude = 44.024776, display_name = "Berula"},
    ["Mereti"] = { latitude = 42.225721, longitude = 44.076519, display_name = "Mereti"},
    ["Kvemo-Mahisi"] = { latitude = 42.212282, longitude = 44.229800, display_name = "Kvemo-Mahisi"},
    ["Karbi"] = { latitude = 42.199130, longitude = 44.075680, display_name = "Karbi"},
    ["Ditsi"] = { latitude = 42.209424, longitude = 44.032437, display_name = "Ditsi"},
    ["Megvrekisi"] = { latitude = 42.182147, longitude = 44.003578, display_name = "Megvrekisi"},
    ["Brotsleti"] = { latitude = 42.179239, longitude = 44.035211, display_name = "Brotsleti"},
    ["Didi-Gromi"] = { latitude = 42.159974, longitude = 44.216156, display_name = "Didi-Gromi"},
    ["Goyata"] = { latitude = 42.150563, longitude = 44.160480, display_name = "Goyata"},
    ["Plavi"] = { latitude = 42.167888, longitude = 44.110547, display_name = "Plavi"},
    ["Tkviavi"] = { latitude = 42.158148, longitude = 44.068454, display_name = "Tkviavi"},
    ["Shindisi"] = { latitude = 42.129670, longitude = 44.009758, display_name = "Shindisi"},
    ["Marana"] = { latitude = 42.143492, longitude = 44.060515, display_name = "Marana"},
    ["Kitsnisi"] = { latitude = 42.128901, longitude = 44.091163, display_name = "Kitsnisi"},
    ["Kvemo-Artsevi"] = { latitude = 42.137430, longitude = 44.123166, display_name = "Kvemo-Artsevi"},
    ["Medzhudispiri"] = { latitude = 42.130753, longitude = 44.197309, display_name = "Medzhudispiri"},
    ["Patara-Medzhvrishevi"] = { latitude = 42.138801, longitude = 44.215694, display_name = "Patara-Medzhvrishevi"},
    ["Zerti"] = { latitude = 42.105513, longitude = 44.220610, display_name = "Zerti"},
    ["Ahrisi"] = { latitude = 42.113127, longitude = 44.169207, display_name = "Ahrisi"},
    ["Satemo"] = { latitude = 42.111461, longitude = 44.109531, display_name = "Satemo"},
    ["Dzevera"] = { latitude = 42.118587, longitude = 44.052329, display_name = "Dzevera"},
    ["Variani"] = { latitude = 42.076311, longitude = 44.033619, display_name = "Variani"},
    ["Kvarhiti"] = { latitude = 42.080103, longitude = 44.194531, display_name = "Kvarhiti"},
    ["Zegduleti"] = { latitude = 42.053744, longitude = 44.222579, display_name = "Zegduleti"},
    ["Heltubani"] = { latitude = 42.051003, longitude = 44.153117, display_name = "Heltubani"},
    ["Arashenda"] = { latitude = 42.055347, longitude = 44.026474, display_name = "Arashenda"},
    ["Reha"] = { latitude = 42.037624, longitude = 44.116712, display_name = "Reha"},
    ["Sveneti"] = { latitude = 42.027015, longitude = 44.147642, display_name = "Sveneti"},
    ["Otarasheni"] = { latitude = 42.013074, longitude = 44.086605, display_name = "Otarasheni"},
    ["Kldu"] = { latitude = 41.983296, longitude = 43.856146, display_name = "Kldu"},
    ["Vedreba"] = { latitude = 41.985291, longitude = 43.821404, display_name = "Vedreba"},
    ["Heoba"] = { latitude = 41.970626, longitude = 43.912736, display_name = "Heoba"},
    ["Gvleti"] = { latitude = 41.979952, longitude = 43.971435, display_name = "Gvleti"},
    ["Skra"] = { latitude = 41.997101, longitude = 44.011659, display_name = "Skra"},
    ["Tinihidi"] = { latitude = 41.992653, longitude = 44.084712, display_name = "Tinihidi"},
    ["Kvahvreli"] = { latitude = 41.959105, longitude = 44.218573, display_name = "Kvahvreli"},
    ["Hidistavi"] = { latitude = 41.959612, longitude = 44.134644, display_name = "Hidistavi"},
    ["Bnavisi"] = { latitude = 41.953044, longitude = 44.063967, display_name = "Bnavisi"},
    ["settlement workers"] = { latitude = 42.098091, longitude = 44.177467, display_name = "settlement workers"},
    ["Tedeleti"] = { latitude = 42.415927, longitude = 43.608474, display_name = "Tedeleti"},
    ["Dzhalabeti"] = { latitude = 42.405402, longitude = 43.651559, display_name = "Dzhalabeti"},
    ["Perevi"] = { latitude = 42.371801, longitude = 43.598444, display_name = "Perevi"},
    ["Dzhriya"] = { latitude = 42.348672, longitude = 43.582496, display_name = "Dzhriya"},
    ["Darka"] = { latitude = 42.332744, longitude = 43.555666, display_name = "Darka"},
    ["Didi-Tsihiata"] = { latitude = 42.265642, longitude = 43.777229, display_name = "Didi-Tsihiata"},
    ["Kornisi"] = { latitude = 42.273295, longitude = 43.820488, display_name = "Kornisi"},
    ["Bekmari"] = { latitude = 42.251183, longitude = 43.815920, display_name = "Bekmari"},
    ["Ahalsheni"] = { latitude = 42.229380, longitude = 43.768622, display_name = "Ahalsheni"},
    ["Nedlati"] = { latitude = 42.215220, longitude = 43.770585, display_name = "Nedlati"},
    ["Samtskaro"] = { latitude = 42.200998, longitude = 43.833958, display_name = "Samtskaro"},
    ["Nabakevi"] = { latitude = 42.187277, longitude = 43.770297, display_name = "Nabakevi"},
    ["Balta"] = { latitude = 42.181644, longitude = 43.720810, display_name = "Balta"},
    ["Khvani"] = { latitude = 42.198434, longitude = 43.533608, display_name = "Khvani"},
    ["Chalovani"] = { latitude = 42.179914, longitude = 43.504613, display_name = "Chalovani"},
    ["Caleti"] = { latitude = 42.168803, longitude = 43.717894, display_name = "Caleti"},
    ["Atotsi"] = { latitude = 42.152690, longitude = 43.747844, display_name = "Atotsi"},
    ["Lychee"] = { latitude = 42.155902, longitude = 43.482475, display_name = "Lychee"},
    ["Tsagvli"] = { latitude = 42.120081, longitude = 43.698204, display_name = "Tsagvli"},
    ["Satsihuri"] = { latitude = 42.118858, longitude = 43.731642, display_name = "Satsihuri"},
    ["Bredza"] = { latitude = 42.129362, longitude = 43.745254, display_name = "Bredza"},
    ["Abisi"] = { latitude = 42.094465, longitude = 43.763261, display_name = "Abisi"},
    ["Ptsa"] = { latitude = 42.086530, longitude = 43.786340, display_name = "Ptsa"},
    ["Tkotsa"] = { latitude = 42.093459, longitude = 43.702879, display_name = "Tkotsa"},
    ["Tshetisdzhvari"] = { latitude = 42.105024, longitude = 43.651165, display_name = "Tshetisdzhvari"},
    ["Shaved"] = { latitude = 42.077063, longitude = 43.610677, display_name = "Shaved"},
    ["Didi-Plevi"] = { latitude = 42.073444, longitude = 43.698010, display_name = "Didi-Plevi"},
    ["Mohisi"] = { latitude = 42.053041, longitude = 43.769400, display_name = "Mohisi"},
    ["Vaca"] = { latitude = 42.043164, longitude = 43.713762, display_name = "Vaca"},
    ["Nabahtevi"] = { latitude = 42.060954, longitude = 43.666875, display_name = "Nabahtevi"},
    ["Tsotshnara"] = { latitude = 42.050883, longitude = 43.579242, display_name = "Tsotshnara"},
    ["Gomi"] = { latitude = 42.020584, longitude = 43.725902, display_name = "Gomi"},
    ["Kvishheti"] = { latitude = 41.968277, longitude = 43.501974, display_name = "Kvishheti"},
    ["Savanisubani"] = { latitude = 41.987763, longitude = 43.524168, display_name = "Savanisubani"},
    ["Htsisi"] = { latitude = 41.982473, longitude = 43.675254, display_name = "Htsisi"},
    ["Gverdzineti"] = { latitude = 41.934464, longitude = 43.712739, display_name = "Gverdzineti"},
    ["Patara-Keleti"] = { latitude = 41.978368, longitude = 43.747280, display_name = "Patara-Keleti"},
    ["Sukaantubani"] = { latitude = 41.966189, longitude = 43.782483, display_name = "Sukaantubani"},
    ["Surami"] = { latitude = 42.023579, longitude = 43.551661, display_name = "Surami"},
    ["Kvomo-Hvtse"] = { latitude = 42.417978, longitude = 43.956401, display_name = "Kvomo-Hvtse"},
    ["Garbani"] = { latitude = 42.607571, longitude = 44.583726, display_name = "Garbani"},
    ["Hevsha"] = { latitude = 42.397988, longitude = 44.683859, display_name = "Hevsha"},
    ["Chargali"] = { latitude = 42.329329, longitude = 44.920772, display_name = "Chargali"},
    ["KAZBEGI"] = { latitude = 42.659479, longitude = 44.641080, display_name = "KAZBEGI"},
    ["NIGNIY PASANAURI"] = { latitude = 42.395430, longitude = 44.649680, display_name = "NIGNIY PASANAURI"},
    ["PASANAURI"] = { latitude = 42.354728, longitude = 44.689155, display_name = "PASANAURI"},
    ["MALIY PASANAURI"] = { latitude = 42.352053, longitude = 44.705106, display_name = "MALIY PASANAURI"},
    ["NIGNIY PASANAURI"] = { latitude = 42.327877, longitude = 44.681794, display_name = "NIGNIY PASANAURI"},
    ["Pavlodolskaya"] = { latitude = 43.725429, longitude = 44.476820, display_name = "Pavlodolskaya"},
    ["Kalininskiy"] = { latitude = 43.728693, longitude = 44.688696, display_name = "Kalininskiy"},
    ["Stoderevskaya"] = { latitude = 43.725108, longitude = 44.841465, display_name = "Stoderevskaya"},
    ["Kievskoye"] = { latitude = 43.706989, longitude = 44.649667, display_name = "Kievskoye"},
    ["Kizlyar"] = { latitude = 43.706249, longitude = 44.597507, display_name = "Kizlyar"},
    ["Razdolnoe"] = { latitude = 43.698447, longitude = 44.537709, display_name = "Razdolnoe"},
    ["Vinogradnoye"] = { latitude = 43.699684, longitude = 44.492810, display_name = "Vinogradnoye"},
    ["Novoosetinskaya"] = { latitude = 43.705838, longitude = 44.391716, display_name = "Novoosetinskaya"},
    ["Hamidiye"] = { latitude = 43.675286, longitude = 44.377288, display_name = "Hamidiye"},
    ["Suhotskoe"] = { latitude = 43.678340, longitude = 44.440575, display_name = "Suhotskoe"},
    ["Bratskoye"] = { latitude = 43.654801, longitude = 44.890888, display_name = "Bratskoye"},
    ["Chkalovo"] = { latitude = 43.525346, longitude = 44.861239, display_name = "Chkalovo"},
    ["Voznesenskaya"] = { latitude = 43.544554, longitude = 44.749833, display_name = "Voznesenskaya"},
    ["Stariy Malgobek"] = { latitude = 43.547550, longitude = 44.576478, display_name = "Stariy Malgobek"},
    ["Yugnoye"] = { latitude = 43.517917, longitude = 44.743613, display_name = "Yugnoye"},
    ["Noviy Redant"] = { latitude = 43.473166, longitude = 44.812043, display_name = "Noviy Redant"},
    ["Hurikau"] = { latitude = 43.457393, longitude = 44.459515, display_name = "Hurikau"},
    ["Nigniye Achaluki"] = { latitude = 43.402997, longitude = 44.763903, display_name = "Nigniye Achaluki"},
    ["Sredniye Achaluki"] = { latitude = 43.371071, longitude = 44.731465, display_name = "Sredniye Achaluki"},
    ["Stariy Bataksyurt"] = { latitude = 43.377826, longitude = 44.539760, display_name = "Stariy Bataksyurt"},
    ["Verhniy Kurpie"] = { latitude = 43.481149, longitude = 44.372481, display_name = "Verhniy Kurpie"},
    ["Zamankul"] = { latitude = 43.349395, longitude = 44.405192, display_name = "Zamankul"},
    ["Coban"] = { latitude = 42.917909, longitude = 44.478096, display_name = "Coban"},
    ["Tarskoye"] = { latitude = 42.966945, longitude = 44.776350, display_name = "Tarskoye"},
    ["Kardzhin"] = { latitude = 43.275762, longitude = 44.304301, display_name = "Kardzhin"},
    ["Darg-Koh"] = { latitude = 43.270288, longitude = 44.363370, display_name = "Darg-Koh"},
    ["Brut"] = { latitude = 43.269754, longitude = 44.443816, display_name = "Brut"},
    ["Humalag"] = { latitude = 43.241187, longitude = 44.478346, display_name = "Humalag"},
    ["Zilga"] = { latitude = 43.239199, longitude = 44.522993, display_name = "Zilga"},
    ["Dalakova"] = { latitude = 43.240951, longitude = 44.588774, display_name = "Dalakova"},
    ["Fahrn"] = { latitude = 43.181612, longitude = 44.497644, display_name = "Fahrn"},
    ["Kirovo"] = { latitude = 43.176702, longitude = 44.404846, display_name = "Kirovo"},
    ["Noviy Batakoyurt"] = { latitude = 43.220011, longitude = 44.498692, display_name = "Noviy Batakoyurt"},
    ["Kadgaron"] = { latitude = 43.134260, longitude = 44.327729, display_name = "Kadgaron"},
    ["Ali-Yurt"] = { latitude = 43.143623, longitude = 44.855216, display_name = "Ali-Yurt"},
    ["Galashki"] = { latitude = 43.084641, longitude = 44.986559, display_name = "Galashki"},
    ["Dongaron"] = { latitude = 43.108707, longitude = 44.720818, display_name = "Dongaron"},
    ["Oktyabrskoe"] = { latitude = 43.053531, longitude = 44.746773, display_name = "Oktyabrskoe"},
    ["Arhonskaya"] = { latitude = 43.109215, longitude = 44.514273, display_name = "Arhonskaya"},
    ["Nart"] = { latitude = 43.119502, longitude = 44.429664, display_name = "Nart"},
    ["Komgaron"] = { latitude = 43.054635, longitude = 44.873359, display_name = "Komgaron"},
    ["Mayramadag"] = { latitude = 43.022685, longitude = 44.480014, display_name = "Mayramadag"},
    ["Dzuarikau"] = { latitude = 43.021167, longitude = 44.406716, display_name = "Dzuarikau"},
    ["Nowaya Sabiba"] = { latitude = 43.042338, longitude = 44.533605, display_name = "Nowaya Sabiba"},
    ["Hataldon"] = { latitude = 43.037818, longitude = 44.359631, display_name = "Hataldon"},
    ["Terk"] = { latitude = 42.931648, longitude = 44.661428, display_name = "Terk"},
    ["Bamut"] = { latitude = 43.153786, longitude = 45.199457, display_name = "Bamut"},
    ["KARABULAK"] = { latitude = 43.308244, longitude = 44.902324, display_name = "KARABULAK"},
    ["Sett. Chapaeva"] = { latitude = 43.544240, longitude = 44.659527, display_name = "Sett. Chapaeva"},
    ["Sett. Sheripova"] = { latitude = 43.542711, longitude = 44.617595, display_name = "Sett. Sheripova"},
    ["Barzikau"] = { latitude = 42.840858, longitude = 44.311978, display_name = "Barzikau"},
    ["Lats"] = { latitude = 42.830939, longitude = 44.291897, display_name = "Lats"},
    ["Maloe Kantyshevo"] = { latitude = 43.215812, longitude = 44.676116, display_name = "Maloe Kantyshevo"},
    ["Malie Galashki"] = { latitude = 43.119389, longitude = 44.991516, display_name = "Malie Galashki"},
    ["Chermen"] = { latitude = 43.124973, longitude = 44.707396, display_name = "Chermen"},
    ["YUGNIY"] = { latitude = 42.965960, longitude = 44.689516, display_name = "YUGNIY"},
    ["KARTSA"] = { latitude = 43.044612, longitude = 44.729882, display_name = "KARTSA"},
    ["Verhniy Komgaron"] = { latitude = 43.056066, longitude = 44.907189, display_name = "Verhniy Komgaron"},
    ["Redant 2nd"] = { latitude = 42.988657, longitude = 44.670222, display_name = "Redant 2nd"},
    ["DATCHNOE"] = { latitude = 42.976949, longitude = 44.670218, display_name = "DATCHNOE"},
    ["Redant 1st"] = { latitude = 42.961780, longitude = 44.658172, display_name = "Redant 1st"},
    ["Maliy Terk"] = { latitude = 42.910962, longitude = 44.641989, display_name = "Maliy Terk"},
    ["Novopoltavskoe"] = { latitude = 43.690510, longitude = 43.971403, display_name = "Novopoltavskoe"},
    ["Novoivanovskoe"] = { latitude = 43.640512, longitude = 43.957150, display_name = "Novoivanovskoe"},
    ["Priblizhnaya"] = { latitude = 43.771987, longitude = 44.123433, display_name = "Priblizhnaya"},
    ["Yrogainoe"] = { latitude = 43.702547, longitude = 44.216846, display_name = "Yrogainoe"},
    ["Terekskoe"] = { latitude = 43.673364, longitude = 44.297188, display_name = "Terekskoe"},
    ["Stavd-Durta"] = { latitude = 43.362683, longitude = 44.056242, display_name = "Stavd-Durta"},
    ["Zmeyskaya"] = { latitude = 43.344694, longitude = 44.149100, display_name = "Zmeyskaya"},
    ["Arik"] = { latitude = 43.581259, longitude = 44.125132, display_name = "Arik"},
    ["Verh.Akbash"] = { latitude = 43.474962, longitude = 44.235607, display_name = "Verh.Akbash"},
    ["Planovskoye"] = { latitude = 43.403198, longitude = 44.200263, display_name = "Planovskoye"},
    ["Lesken"] = { latitude = 43.277818, longitude = 43.829816, display_name = "Lesken"},
    ["Chikola"] = { latitude = 43.188667, longitude = 43.919901, display_name = "Chikola"},
    ["Ahsay"] = { latitude = 42.957234, longitude = 43.717210, display_name = "Ahsay"},
    ["Galiat"] = { latitude = 42.924405, longitude = 43.849611, display_name = "Galiat"},
    ["Verhniy Tsey"] = { latitude = 42.803812, longitude = 43.939140, display_name = "Verhniy Tsey"},
    ["Verhniy Zaramag"] = { latitude = 42.699861, longitude = 43.961273, display_name = "Verhniy Zaramag"},
    ["Tib"] = { latitude = 42.673957, longitude = 43.909848, display_name = "Tib"},
    ["Dur-Dur"] = { latitude = 43.122325, longitude = 44.026365, display_name = "Dur-Dur"},
    ["Khora"] = { latitude = 43.083592, longitude = 44.067681, display_name = "Khora"},
    ["Hod"] = { latitude = 42.878956, longitude = 44.011978, display_name = "Hod"},
    ["Nogkau"] = { latitude = 42.869024, longitude = 44.044631, display_name = "Nogkau"},
    ["Gusoyta"] = { latitude = 42.866307, longitude = 44.066896, display_name = "Gusoyta"},
    ["Nigniy Unal"] = { latitude = 42.863339, longitude = 44.151339, display_name = "Nigniy Unal"},
    ["Chasavali"] = { latitude = 42.527264, longitude = 43.645950, display_name = "Chasavali"},
    ["Cobet"] = { latitude = 42.524742, longitude = 43.769973, display_name = "Cobet"},
    ["Kasagini"] = { latitude = 42.489340, longitude = 43.728148, display_name = "Kasagini"},
    ["Biteta"] = { latitude = 42.470286, longitude = 43.696121, display_name = "Biteta"},
    ["Hampalgomi"] = { latitude = 42.456412, longitude = 43.736447, display_name = "Hampalgomi"},
    ["Dadikau"] = { latitude = 42.463106, longitude = 43.755227, display_name = "Dadikau"},
    ["Ertso"] = { latitude = 42.463195, longitude = 43.778098, display_name = "Ertso"},
    ["Muguti"] = { latitude = 42.426175, longitude = 43.931004, display_name = "Muguti"},
    ["Kotanto"] = { latitude = 42.435038, longitude = 43.842742, display_name = "Kotanto"},
    ["Kvemo-Korsevi"] = { latitude = 42.404016, longitude = 43.870838, display_name = "Kvemo-Korsevi"},
    ["Stariye Kvemo-Korsevi"] = { latitude = 42.411866, longitude = 43.873899, display_name = "Stariye Kvemo-Korsevi"},
    ["Sakire"] = { latitude = 42.378590, longitude = 43.910177, display_name = "Sakire"},
    ["Didi-Gupta"] = { latitude = 42.352565, longitude = 43.902265, display_name = "Didi-Gupta"},
    ["Kvemo-Sba"] = { latitude = 42.569275, longitude = 44.168972, display_name = "Kvemo-Sba"},
    ["Zemo-Roka"] = { latitude = 42.578612, longitude = 44.119959, display_name = "Zemo-Roka"},
    ["Kvemo-Roka"] = { latitude = 42.546843, longitude = 44.115709, display_name = "Kvemo-Roka"},
    ["Edisa"] = { latitude = 42.538407, longitude = 44.215896, display_name = "Edisa"},
    ["Kvemo-Khoshka"] = { latitude = 42.468209, longitude = 44.057935, display_name = "Kvemo-Khoshka"},
    ["Elbakita"] = { latitude = 42.428988, longitude = 44.005024, display_name = "Elbakita"},
    ["Tsru"] = { latitude = 42.383653, longitude = 44.022967, display_name = "Tsru"},
    ["Shua-Tshviri"] = { latitude = 42.372013, longitude = 44.184655, display_name = "Shua-Tshviri"},
    ["Klarsi"] = { latitude = 42.353604, longitude = 44.051562, display_name = "Klarsi"},
    ["Tsiara"] = { latitude = 42.353420, longitude = 44.022577, display_name = "Tsiara"},
    ["VERHNIY ZGID"] = { latitude = 42.871325, longitude = 43.960613, display_name = "VERHNIY ZGID"},
    ["SADON"] = { latitude = 42.852012, longitude = 43.995197, display_name = "SADON"},
    ["BURON"] = { latitude = 42.795036, longitude = 44.006793, display_name = "BURON"},
    ["MIZUR"] = { latitude = 42.851027, longitude = 44.056755, display_name = "MIZUR"},
    ["JAVA"] = { latitude = 42.396920, longitude = 43.926887, display_name = "JAVA"},
    ["MAISKIY"] = { latitude = 43.641799, longitude = 44.033974, display_name = "MAISKIY"},
    ["Uvarovskoye"] = { latitude = 43.815010, longitude = 44.427222, display_name = "Uvarovskoye"},
    ["Inarkiev"] = { latitude = 43.472488, longitude = 44.543341, display_name = "Inarkiev"},
    ["Verhniye Achaluki"] = { latitude = 43.350538, longitude = 44.699020, display_name = "Verhniye Achaluki"},
    ["Yandyrka"] = { latitude = 43.273597, longitude = 44.916689, display_name = "Yandyrka"},
    ["Ekazhevo"] = { latitude = 43.210327, longitude = 44.823799, display_name = "Ekazhevo"},
    ["Surkhakhi"] = { latitude = 43.187870, longitude = 44.905782, display_name = "Surkhakhi"},
    ["Chermen"] = { latitude = 43.148441, longitude = 44.712624, display_name = "Chermen"},
    ["Olginskoe"] = { latitude = 43.161052, longitude = 44.691985, display_name = "Olginskoe"},
    ["Sunzha"] = { latitude = 43.057253, longitude = 44.825846, display_name = "Sunzha"},
    ["Gizel"] = { latitude = 43.047232, longitude = 44.567211, display_name = "Gizel"},
    ["Nesterovskaya"] = { latitude = 43.239607, longitude = 45.059246, display_name = "Nesterovskaya"},
    ["MALGOBEK"] = { latitude = 43.518590, longitude = 44.599399, display_name = "MALGOBEK"},
    ["Carman"] = { latitude = 43.109120, longitude = 44.115426, display_name = "Carman"},
    ["Ursdon"] = { latitude = 43.095719, longitude = 44.085430, display_name = "Ursdon"},
    ["DIGORA"] = { latitude = 43.159497, longitude = 44.161233, display_name = "DIGORA"},
    ["Dzalisi"] = { latitude = 41.963611, longitude = 44.605056, display_name = "Dzalisi"},
    ["Digomi"] = { latitude = 41.770418, longitude = 44.741961, display_name = "Digomi"},
    ["Kumisi"] = { latitude = 41.615003, longitude = 44.781197, display_name = "Kumisi"},
    ["Algeti"] = { latitude = 41.444696, longitude = 44.905321, display_name = "Algeti"},
    ["Tsereteli"] = { latitude = 41.449287, longitude = 44.822309, display_name = "Tsereteli"},
    ["Akhali-Samgori"] = { latitude = 41.571700, longitude = 45.074511, display_name = "Akhali-Samgori"},
    ["Ulyanovka"] = { latitude = 41.389915, longitude = 45.118498, display_name = "Ulyanovka"},
    ["Sadyhly"] = { latitude = 41.374920, longitude = 45.144642, display_name = "Sadyhly"},
    ["Tskneti"] = { latitude = 41.691738, longitude = 44.698812, display_name = "Tskneti"},
    ["TETRA-Tskaro"] = { latitude = 41.547350, longitude = 44.468209, display_name = "TETRA-Tskaro"},
    ["Kurta"] = { latitude = 42.283254, longitude = 43.956290, display_name = "Kurta"},
    ["Kekhvi"] = { latitude = 42.307566, longitude = 43.940875, display_name = "Kekhvi"},
    ["Russkoye"] = { latitude = 43.835069, longitude = 44.579918, display_name = "Russkoye"},
    ["Novogeorgievskoe"] = { latitude = 43.763115, longitude = 44.703801, display_name = "Novogeorgievskoe"},
    ["Veselovskoye"] = { latitude = 43.771709, longitude = 44.727163, display_name = "Veselovskoye"},
    ["Barsuki"] = { latitude = 43.263814, longitude = 44.810861, display_name = "Barsuki"},
    ["Pliyevo"] = { latitude = 43.283551, longitude = 44.840391, display_name = "Pliyevo"},
    ["Kantyshevo"] = { latitude = 43.230063, longitude = 44.631288, display_name = "Kantyshevo"},
    ["Nogir"] = { latitude = 43.078872, longitude = 44.638090, display_name = "Nogir"},
    ["Troickaya"] = { latitude = 43.305363, longitude = 45.010858, display_name = "Troickaya"},
    ["ZAVODSKOY"] = { latitude = 43.098096, longitude = 44.654284, display_name = "ZAVODSKOY"},
    ["BESLAN"] = { latitude = 43.195476, longitude = 44.531621, display_name = "BESLAN"},
    ["Nazran"] = { latitude = 43.226212, longitude = 44.777861, display_name = "Nazran"},
    ["Ekaterinogradskaya"] = { latitude = 43.766466, longitude = 44.232838, display_name = "Ekaterinogradskaya"},
    ["Elhotovo"] = { latitude = 43.356191, longitude = 44.210087, display_name = "Elhotovo"},
    ["TEREK"] = { latitude = 43.482380, longitude = 44.141438, display_name = "TEREK"},
    ["ALAGIR"] = { latitude = 43.039424, longitude = 44.220280, display_name = "ALAGIR"},
    ["Aleksandrovskaya"] = { latitude = 43.485711, longitude = 44.068899, display_name = "Aleksandrovskaya"},
    ["Ikoti"] = { latitude = 42.152918, longitude = 44.495123, display_name = "Ikoti"},
    ["Mukhrani"] = { latitude = 41.936298, longitude = 44.575647, display_name = "Mukhrani"},
    ["Martkobi"] = { latitude = 41.787685, longitude = 45.020138, display_name = "Martkobi"},
    ["Mughanlo"] = { latitude = 41.731105, longitude = 45.160083, display_name = "Mughanlo"},
    ["Sartichala"] = { latitude = 41.709697, longitude = 45.171715, display_name = "Sartichala"},
    ["Leningori"] = { latitude = 42.131932, longitude = 44.485444, display_name = "Leningori"},
    ["Lilo"] = { latitude = 41.681176, longitude = 44.976380, display_name = "Lilo"},
    ["Dusheti"] = { latitude = 42.084899, longitude = 44.689336, display_name = "Dusheti"},
    ["KASPI"] = { latitude = 41.924404, longitude = 44.425303, display_name = "KASPI"},
    ["Gardabani"] = { latitude = 41.461640, longitude = 45.092311, display_name = "Gardabani"},
    ["Sagarejo"] = { latitude = 41.728389, longitude = 45.332577, display_name = "Sagarejo"},
    ["TSKHINVALI"] = { latitude = 42.230304, longitude = 43.970695, display_name = "TSKHINVALI"},
    ["GORI"] = { latitude = 41.983833, longitude = 44.110383, display_name = "GORI"},
    ["AGARA"] = { latitude = 42.044088, longitude = 43.826962, display_name = "AGARA"},
    ["KARELI"] = { latitude = 42.020888, longitude = 43.892648, display_name = "KARELI"},
    ["Ruisi"] = { latitude = 42.035966, longitude = 43.964884, display_name = "Ruisi"},
    ["Karaleti"] = { latitude = 42.068062, longitude = 44.091374, display_name = "Karaleti"},
    ["MOZDOK"] = { latitude = 43.752121, longitude = 44.640819, display_name = "MOZDOK"},
    ["VLADIKAVKAZ"] = { latitude = 43.029636, longitude = 44.679665, display_name = "VLADIKAVKAZ"},
    ["PROHLADNIY"] = { latitude = 43.756426, longitude = 44.038869, display_name = "PROHLADNIY"},
    ["MAYSKIY"] = { latitude = 43.630769, longitude = 44.066323, display_name = "MAYSKIY"},
    ["Kurtat"] = { latitude = 43.071083, longitude = 44.751840, display_name = "Kurtat"},
    ["RUSTAVI"] = { latitude = 41.559705, longitude = 44.986424, display_name = "RUSTAVI"},
    ["Marneuli"] = { latitude = 41.479596, longitude = 44.808583, display_name = "Marneuli"},
    ["TBILISI"] = { latitude = 41.736457, longitude = 44.825608, display_name = "TBILISI"},
    ["KHASHURI"] = { latitude = 41.985651, longitude = 43.604230, display_name = "KHASHURI"},
    }

NevadaTowns = {
    ["Strawberry Hill"] = { latitude = 37.619965, longitude = -114.513327, display_name = "Strawberry Hill"},
    ["Lovell"] = { latitude = 36.291359, longitude = -115.043058, display_name = "Lovell"},
    ["Victory Village"] = { latitude = 36.037199, longitude = -114.976103, display_name = "Victory Village"},
    ["Henderson"] = { latitude = 36.039146, longitude = -114.981924, display_name = "Henderson"},
    ["Bracken"] = { latitude = 36.108915, longitude = -115.189151, display_name = "Bracken"},
    ["Cold Spring"] = { latitude = 37.751354, longitude = -114.424713, display_name = "Cold Spring"},
    ["Farrier"] = { latitude = 36.812748, longitude = -114.653881, display_name = "Farrier"},
    ["Tule Springs"] = { latitude = 36.297317, longitude = -115.260856, display_name = "Tule Springs"},
    ["Tempiute"] = { latitude = 37.652452, longitude = -115.635865, display_name = "Tempiute"},
    ["Centennial Hills"] = { latitude = 36.270423, longitude = -115.264929, display_name = "Centennial Hills"},
    ["Mack"] = { latitude = 35.977835, longitude = -115.172707, display_name = "Mack"},
    ["Fish Island"] = { latitude = 36.457755, longitude = -114.346086, display_name = "Fish Island"},
    ["Ridgebrook"] = { latitude = 36.124761, longitude = -115.333778, display_name = "Ridgebrook"},
    ["Forks Station"] = { latitude = 37.495766, longitude = -117.166185, display_name = "Forks Station"},
    ["Mount Charleston"] = { latitude = 36.257191, longitude = -115.642799, display_name = "Mount Charleston"},
    ["Mellan"] = { latitude = 37.712440, longitude = -116.594780, display_name = "Mellan"},
    ["Mercury"] = { latitude = 36.660510, longitude = -115.994475, display_name = "Mercury"},
    ["Summerlin South"] = { latitude = 36.141031, longitude = -115.329198, display_name = "Summerlin South"},
    ["Foothills"] = { latitude = 36.050286, longitude = -114.949043, display_name = "Foothills"},
    ["East Las Vegas"] = { latitude = 36.094419, longitude = -115.041940, display_name = "East Las Vegas"},
    ["Tuscany Residential Village"] = { latitude = 36.080446, longitude = -114.972675, display_name = "Tuscany Residential Village"},
    ["Lathrop Wells"] = { latitude = 36.643842, longitude = -116.400325, display_name = "Lathrop Wells"},
    ["Bard"] = { latitude = 35.987751, longitude = -115.237496, display_name = "Bard"},
    ["Caselton"] = { latitude = 37.919130, longitude = -114.485271, display_name = "Caselton"},
    ["Lake Las Vegas"] = { latitude = 36.107874, longitude = -114.924442, display_name = "Lake Las Vegas"},
    ["Calico Ridge"] = { latitude = 36.081107, longitude = -114.950406, display_name = "Calico Ridge"},
    ["Crystal"] = { latitude = 36.491623, longitude = -116.167536, display_name = "Crystal"},
    ["Winchester"] = { latitude = 36.129978, longitude = -115.118889, display_name = "Winchester"},
    ["Sunrise"] = { latitude = 36.188514, longitude = -115.062977, display_name = "Sunrise"},
    ["North Las Vegas"] = { latitude = 36.200837, longitude = -115.112096, display_name = "North Las Vegas"},
    ["Nyala"] = { latitude = 38.248825, longitude = -115.728646, display_name = "Nyala"},
    ["Green Valley"] = { latitude = 36.048848, longitude = -115.080472, display_name = "Green Valley"},
    ["Anthem"] = { latitude = 35.949582, longitude = -115.102098, display_name = "Anthem"},
    ["Arden"] = { latitude = 36.018028, longitude = -115.230830, display_name = "Arden"},
    ["Searchlight"] = { latitude = 35.465186, longitude = -114.919112, display_name = "Searchlight"},
    ["Labbe Camp"] = { latitude = 36.450790, longitude = -116.056420, display_name = "Labbe Camp"},
    ["Valley View"] = { latitude = 38.068267, longitude = -117.224527, display_name = "Valley View"},
    ["Jackman"] = { latitude = 36.642195, longitude = -114.540263, display_name = "Jackman"},
    ["Dry Lake"] = { latitude = 36.455425, longitude = -114.847762, display_name = "Dry Lake"},
    ["Gemfield"] = { latitude = 37.739655, longitude = -117.295081, display_name = "Gemfield"},
    ["Laplace"] = { latitude = 37.086776, longitude = -116.025913, display_name = "Laplace"},
    ["Vegas Heights"] = { latitude = 36.199396, longitude = -115.156301, display_name = "Vegas Heights"},
    ["Hadley"] = { latitude = 38.694376, longitude = -117.160364, display_name = "Hadley"},
    ["Joseco"] = { latitude = 37.501912, longitude = -114.229147, display_name = "Joseco"},
    ["Jean"] = { latitude = 35.779008, longitude = -115.324314, display_name = "Jean"},
    ["Crystal Springs"] = { latitude = 37.531627, longitude = -115.233910, display_name = "Crystal Springs"},
    ["Amargosa Valley"] = { latitude = 36.494326, longitude = -116.424946, display_name = "Amargosa Valley"},
    ["Indian Cove"] = { latitude = 37.655243, longitude = -114.495271, display_name = "Indian Cove"},
    ["Montezuma"] = { latitude = 37.703821, longitude = -117.368972, display_name = "Montezuma"},
    ["Rhyolite"] = { latitude = 36.903824, longitude = -116.828884, display_name = "Rhyolite"},
    ["Riverside"] = { latitude = 36.736085, longitude = -114.220527, display_name = "Riverside"},
    ["Downtown Henderson"] = { latitude = 36.031272, longitude = -114.981263, display_name = "Downtown Henderson"},
    ["West Spring"] = { latitude = 37.722155, longitude = -117.270636, display_name = "West Spring"},
    ["Flat Nose"] = { latitude = 37.893296, longitude = -114.300542, display_name = "Flat Nose"},
    ["Lida Junction"] = { latitude = 37.502322, longitude = -117.184597, display_name = "Lida Junction"},
    ["Ute"] = { latitude = 36.566082, longitude = -114.715551, display_name = "Ute"},
    ["Stewart Mill"] = { latitude = 37.423600, longitude = -117.468525, display_name = "Stewart Mill"},
    ["Goldfield"] = { latitude = 37.708694, longitude = -117.236631, display_name = "Goldfield"},
    ["Blue Diamond"] = { latitude = 36.046365, longitude = -115.403898, display_name = "Blue Diamond"},
    ["Goodsprings"] = { latitude = 35.832609, longitude = -115.433981, display_name = "Goodsprings"},
    ["Gold Point"] = { latitude = 37.354653, longitude = -117.365077, display_name = "Gold Point"},
    ["Florence Hill"] = { latitude = 37.707577, longitude = -117.220863, display_name = "Florence Hill"},
    ["Corn Creek"] = { latitude = 36.422854, longitude = -115.386428, display_name = "Corn Creek"},
    ["Mountain's Edge"] = { latitude = 36.017276, longitude = -115.272118, display_name = "Mountain's Edge"},
    ["Enterprise"] = { latitude = 36.046711, longitude = -115.224557, display_name = "Enterprise"},
    ["Amber"] = { latitude = 36.608029, longitude = -114.494149, display_name = "Amber"},
    ["Hiko"] = { latitude = 37.596904, longitude = -115.224189, display_name = "Hiko"},
    ["Sunnyside"] = { latitude = 38.423284, longitude = -115.021124, display_name = "Sunnyside"},
    ["Chinatown"] = { latitude = 36.125976, longitude = -115.195989, display_name = "Chinatown"},
    ["Paradise"] = { latitude = 36.115086, longitude = -115.173414, display_name = "Paradise"},
    ["Five Points"] = { latitude = 36.159098, longitude = -115.118228, display_name = "Five Points"},
    ["Overton"] = { latitude = 36.540734, longitude = -114.442989, display_name = "Overton"},
    ["Angel Peak"] = { latitude = 36.318288, longitude = -115.584883, display_name = "Angel Peak"},
    ["Gold Center"] = { latitude = 36.868326, longitude = -116.766614, display_name = "Gold Center"},
    ["Stewarts Point"] = { latitude = 36.380534, longitude = -114.407754, display_name = "Stewarts Point"},
    ["Battleship Rock"] = { latitude = 36.118034, longitude = -114.733040, display_name = "Battleship Rock"},
    ["Moapa"] = { latitude = 36.682189, longitude = -114.594147, display_name = "Moapa"},
    ["Black Island"] = { latitude = 36.103312, longitude = -114.778042, display_name = "Black Island"},
    ["Valley"] = { latitude = 36.274136, longitude = -115.071392, display_name = "Valley"},
    ["Tybo"] = { latitude = 38.369934, longitude = -116.401168, display_name = "Tybo"},
    ["Crescent Island"] = { latitude = 36.113033, longitude = -114.831655, display_name = "Crescent Island"},
    ["Desert Rock"] = { latitude = 36.627177, longitude = -116.020031, display_name = "Desert Rock"},
    ["Boulder Islands"] = { latitude = 36.039702, longitude = -114.767762, display_name = "Boulder Islands"},
    ["Pony Springs"] = { latitude = 38.318845, longitude = -114.606665, display_name = "Pony Springs"},
    ["Plutonium Valley"] = { latitude = 37.005821, longitude = -116.025618, display_name = "Plutonium Valley"},
    ["Silver Peak"] = { latitude = 37.755278, longitude = -117.634177, display_name = "Silver Peak"},
    ["Mesquite"] = { latitude = 36.804009, longitude = -114.068059, display_name = "Mesquite"},
    ["Spring Valley"] = { latitude = 36.111142, longitude = -115.242869, display_name = "Spring Valley"},
    ["Caliente"] = { latitude = 37.614965, longitude = -114.511938, display_name = "Caliente"},
    ["Glassand"] = { latitude = 36.556919, longitude = -114.464703, display_name = "Glassand"},
    ["Cactus Springs"] = { latitude = 36.577737, longitude = -115.727522, display_name = "Cactus Springs"},
    ["Islen"] = { latitude = 37.529688, longitude = -114.321651, display_name = "Islen"},
    ["Ash Springs"] = { latitude = 37.463051, longitude = -115.194211, display_name = "Ash Springs"},
    ["Bonnie Springs"] = { latitude = 36.059137, longitude = -115.453339, display_name = "Bonnie Springs"},
    ["Carvers"] = { latitude = 38.786598, longitude = -117.179254, display_name = "Carvers"},
    ["Midway City"] = { latitude = 36.065587, longitude = -115.004889, display_name = "Midway City"},
    ["Sierra Vista City"] = { latitude = 36.060574, longitude = -115.006541, display_name = "Sierra Vista City"},
    ["Charleston Heights"] = { latitude = 36.166664, longitude = -115.232729, display_name = "Charleston Heights"},
    ["Round Mountain"] = { latitude = 38.711574, longitude = -117.066021, display_name = "Round Mountain"},
    ["Inner Northwest"] = { latitude = 36.189735, longitude = -115.247664, display_name = "Inner Northwest"},
    ["Primm"] = { latitude = 35.611588, longitude = -115.385862, display_name = "Primm"},
    ["Mission Hills"] = { latitude = 35.994793, longitude = -114.968469, display_name = "Mission Hills"},
    ["Echo Bay"] = { latitude = 36.309146, longitude = -114.427477, display_name = "Echo Bay"},
    ["Desert Shores"] = { latitude = 36.207674, longitude = -115.267662, display_name = "Desert Shores"},
    ["Sun City Summerlin"] = { latitude = 36.213422, longitude = -115.317787, display_name = "Sun City Summerlin"},
    ["Caselton Heights"] = { latitude = 37.913852, longitude = -114.479159, display_name = "Caselton Heights"},
    ["Summerlin"] = { latitude = 36.191317, longitude = -115.301861, display_name = "Summerlin"},
    ["Ruppes Place"] = { latitude = 38.754111, longitude = -115.060571, display_name = "Ruppes Place"},
    ["Rose Valley"] = { latitude = 37.938018, longitude = -114.252484, display_name = "Rose Valley"},
    ["Ursine"] = { latitude = 37.984684, longitude = -114.215261, display_name = "Ursine"},
    ["Lida"] = { latitude = 37.458265, longitude = -117.498138, display_name = "Lida"},
    ["Currant"] = { latitude = 38.742268, longitude = -115.473796, display_name = "Currant"},
    ["Canyon Gate"] = { latitude = 36.148785, longitude = -115.284743, display_name = "Canyon Gate"},
    ["Siena"] = { latitude = 36.107982, longitude = -115.321934, display_name = "Siena"},
    ["Cal-Nev-Ari"] = { latitude = 35.300440, longitude = -114.879304, display_name = "Cal-Nev-Ari"},
    ["Seven Hills"] = { latitude = 35.980531, longitude = -115.117204, display_name = "Seven Hills"},
    ["Ralston"] = { latitude = 37.556044, longitude = -117.152852, display_name = "Ralston"},
    ["Glendale"] = { latitude = 36.665250, longitude = -114.569154, display_name = "Glendale"},
    ["Cold Creek"] = { latitude = 36.413062, longitude = -115.742231, display_name = "Cold Creek"},
    ["Queensridge"] = { latitude = 36.161121, longitude = -115.302681, display_name = "Queensridge"},
    ["Beatty"] = { latitude = 36.908422, longitude = -116.759275, display_name = "Beatty"},
    ["Johnnie"] = { latitude = 36.419974, longitude = -116.072087, display_name = "Johnnie"},
    ["Arrolime"] = { latitude = 36.351360, longitude = -114.909166, display_name = "Arrolime"},
    ["Garnet"] = { latitude = 36.388582, longitude = -114.871110, display_name = "Garnet"},
    ["Apex"] = { latitude = 36.329138, longitude = -114.927777, display_name = "Apex"},
    ["Bunkerville"] = { latitude = 36.771772, longitude = -114.126766, display_name = "Bunkerville"},
    ["Rox"] = { latitude = 36.880803, longitude = -114.667216, display_name = "Rox"},
    ["Sandy Valley"] = { latitude = 35.816923, longitude = -115.632233, display_name = "Sandy Valley"},
    ["Sandy Mill"] = { latitude = 35.804142, longitude = -115.605005, display_name = "Sandy Mill"},
    ["Alkali"] = { latitude = 37.823922, longitude = -117.333900, display_name = "Alkali"},
    ["Wann"] = { latitude = 36.233303, longitude = -115.113336, display_name = "Wann"},
    ["Panaca"] = { latitude = 37.790520, longitude = -114.389434, display_name = "Panaca"},
    ["Moapa Valley"] = { latitude = 36.580531, longitude = -114.470268, display_name = "Moapa Valley"},
    ["Dome Mountain"] = { latitude = 37.007357, longitude = -116.312331, display_name = "Dome Mountain"},
    ["Calico Basin"] = { latitude = 36.150689, longitude = -115.419029, display_name = "Calico Basin"},
    ["Shoshone Mountain"] = { latitude = 36.995315, longitude = -116.213760, display_name = "Shoshone Mountain"},
    ["Sloan"] = { latitude = 35.941234, longitude = -115.216500, display_name = "Sloan"},
    ["Barclay"] = { latitude = 37.513300, longitude = -114.251647, display_name = "Barclay"},
    ["Logandale"] = { latitude = 36.596637, longitude = -114.484155, display_name = "Logandale"},
    ["Trout Canyon"] = { latitude = 36.181736, longitude = -115.679231, display_name = "Trout Canyon"},
    ["Yucca Pass"] = { latitude = 36.933060, longitude = -116.051728, display_name = "Yucca Pass"},
    ["Eastland Heights"] = { latitude = 36.192191, longitude = -115.188058, display_name = "Eastland Heights"},
    ["Tonopah"] = { latitude = 38.068101, longitude = -117.230950, display_name = "Tonopah"},
    ["Dike"] = { latitude = 36.301359, longitude = -115.013336, display_name = "Dike"},
    ["Nye"] = { latitude = 38.354484, longitude = -116.406962, display_name = "Nye"},
    ["Boulder City"] = { latitude = 35.978591, longitude = -114.832485, display_name = "Boulder City"},
    ["Mountain Springs"] = { latitude = 36.018304, longitude = -115.506990, display_name = "Mountain Springs"},
    ["Sand Island"] = { latitude = 36.110255, longitude = -114.818322, display_name = "Sand Island"},
    ["Las Vegas"] = { latitude = 36.166286, longitude = -115.149225, display_name = "Las Vegas"},
    ["Saddle Island"] = { latitude = 36.069145, longitude = -114.801097, display_name = "Saddle Island"},
    ["Sentinel Island"] = { latitude = 36.056647, longitude = -114.744984, display_name = "Sentinel Island"},
    ["Alamo"] = { latitude = 37.364961, longitude = -115.164461, display_name = "Alamo"},
    ["Etna"] = { latitude = 37.555242, longitude = -114.571385, display_name = "Etna"},
    ["Sundown"] = { latitude = 37.635081, longitude = -115.806882, display_name = "Sundown"},
    ["Palm Gardens"] = { latitude = 35.198359, longitude = -114.856716, display_name = "Palm Gardens"},
    ["Pahrump"] = { latitude = 36.208301, longitude = -115.983913, display_name = "Pahrump"},
    ["Laughlin"] = { latitude = 35.167777, longitude = -114.573021, display_name = "Laughlin"},
    ["Pioche"] = { latitude = 37.929685, longitude = -114.452214, display_name = "Pioche"},
    ["Millers"] = { latitude = 38.130504, longitude = -117.458401, display_name = "Millers"},
    ["Whitney"] = { latitude = 36.088532, longitude = -115.037213, display_name = "Whitney"},
    ["Pyramid Island"] = { latitude = 36.051646, longitude = -114.802208, display_name = "Pyramid Island"},
    ["Ripley"] = { latitude = 35.798031, longitude = -115.601671, display_name = "Ripley"},
    ["Indian Springs"] = { latitude = 36.569677, longitude = -115.670571, display_name = "Indian Springs"},
    ["Boulder Junction"] = { latitude = 36.081083, longitude = -115.198054, display_name = "Boulder Junction"},
    ["Manse"] = { latitude = 36.155165, longitude = -115.902679, display_name = "Manse"},
    ["Torino Ranch"] = { latitude = 36.168451, longitude = -115.578663, display_name = "Torino Ranch"},
    ["Nelson"] = { latitude = 35.708042, longitude = -114.824701, display_name = "Nelson"},
    ["Rachel"] = { latitude = 37.644333, longitude = -115.744743, display_name = "Rachel"},
    ["Green Springs"] = { latitude = 37.139958, longitude = -113.527589, display_name = "Green Springs"},
    ["Green Valley"] = { latitude = 37.105265, longitude = -113.621155, display_name = "Green Valley"},
    ["Harrisburg Junction"] = { latitude = 37.161927, longitude = -113.431618, display_name = "Harrisburg Junction"},
    ["Zane"] = { latitude = 37.925247, longitude = -113.583300, display_name = "Zane"},
    ["St. George"] = { latitude = 37.104153, longitude = -113.584131, display_name = "St. George"},
    ["Beryl Junction"] = { latitude = 37.709417, longitude = -113.656077, display_name = "Beryl Junction"},
    ["Coral Canyon"] = { latitude = 37.156942, longitude = -113.454613, display_name = "Coral Canyon"},
    ["Shem"] = { latitude = 37.191645, longitude = -113.768854, display_name = "Shem"},
    ["Washington Fields"] = { latitude = 37.097612, longitude = -113.511290, display_name = "Washington Fields"},
    ["Little Valley"] = { latitude = 37.063157, longitude = -113.537139, display_name = "Little Valley"},
    ["Middleton"] = { latitude = 37.114426, longitude = -113.536624, display_name = "Middleton"},
    ["Bloomington"] = { latitude = 37.046649, longitude = -113.606073, display_name = "Bloomington"},
    ["Gunlock"] = { latitude = 37.286089, longitude = -113.763299, display_name = "Gunlock"},
    ["Enterprise"] = { latitude = 37.573587, longitude = -113.719133, display_name = "Enterprise"},
    ["Dixie Downs"] = { latitude = 37.131873, longitude = -113.624103, display_name = "Dixie Downs"},
    ["Washington"] = { latitude = 37.130537, longitude = -113.508287, display_name = "Washington"},
    ["Shivwits"] = { latitude = 37.181090, longitude = -113.757465, display_name = "Shivwits"},
    ["Bloomington Hills"] = { latitude = 37.060260, longitude = -113.556068, display_name = "Bloomington Hills"},
    ["Harrisburg"] = { latitude = 37.205760, longitude = -113.394050, display_name = "Harrisburg"},
    ["Santa Clara"] = { latitude = 37.133036, longitude = -113.654127, display_name = "Santa Clara"},
    ["Heist"] = { latitude = 37.853447, longitude = -113.846074, display_name = "Heist"},
    ["Ivins"] = { latitude = 37.168591, longitude = -113.679406, display_name = "Ivins"},
    ["Nellis AFB"] = { latitude = 36.240329, longitude = -115.045146, display_name = "Nellis AFB"},
    ["Creech AFB"] = { latitude = 36.580612, longitude = -115.674929, display_name = "Creech AFB"},
    ["Area 51"] = { latitude = 37.243011, longitude = -115.808955, display_name = "Area 51"},
    ["McCarran Airport"] = { latitude = 36.082081, longitude = -115.150024, display_name = "McCarran Airport"},
    ["Cottonwood Island"] = { latitude = 35.491453, longitude = -114.684390, display_name = "Cottonwood Island"},
    ["Babbitt"] = { latitude = 38.539313, longitude = -118.637656, display_name = "Babbitt"},
    ["Dyer"] = { latitude = 37.678229, longitude = -118.084527, display_name = "Dyer"},
    ["Dyer Postoffice"] = { latitude = 37.613027, longitude = -118.022021, display_name = "Dyer Postoffice"},
    ["Hawthorne"] = { latitude = 38.524618, longitude = -118.624563, display_name = "Hawthorne"},
    ["Luning"] = { latitude = 38.506315, longitude = -118.181452, display_name = "Luning"},
    ["Mina"] = { latitude = 38.390411, longitude = -118.108740, display_name = "Mina"},
    ["Sodaville"] = { latitude = 38.341018, longitude = -118.102850, display_name = "Sodaville"},
    ["The Crossing"] = { latitude = 37.869625, longitude = -117.971427, display_name = "The Crossing"},
    ["Walker Lake"] = { latitude = 38.648203, longitude = -118.755169, display_name = "Walker Lake"},
    ["BeaverDam"] = { latitude = 36.913517, longitude = -113.936678, display_name = "BeaverDam"},
    ["LittleField"] = { latitude = 36.884514, longitude = -113.932807, display_name = "LittleField"},
    ["Sinik"] = { latitude = 36.779553, longitude = -114.004749, display_name = "Sinik"},
    ["WillowValley"] = { latitude = 34.899448, longitude = -114.590344, display_name = "WillowValley"},
    ["MohaveValley"] = { latitude = 34.914863, longitude = -114.571586, display_name = "MohaveValley"},
    ["Needles"] = { latitude = 34.846168, longitude = -114.611751, display_name = "Needles"},
    ["ArizonaVillage"] = { latitude = 34.849610, longitude = -114.588015, display_name = "ArizonaVillage"},
    ["Topock"] = { latitude = 34.772075, longitude = -114.491186, display_name = "Topock"},
    ["GoldenShores"] = { latitude = 34.786187, longitude = -114.474000, display_name = "GoldenShores"},
    ["MesquiteCreek"] = { latitude = 34.966401, longitude = -114.567241, display_name = "MesquiteCreek"},
    ["FortMohave"] = { latitude = 35.036838, longitude = -114.583450, display_name = "FortMohave"},
    ["BullheadCity"] = { latitude = 35.139316, longitude = -114.533905, display_name = "BullheadCity"},
    ["MormonPeak"] = { latitude = 36.717075, longitude = -114.722555, display_name = "MormonPeak"},
    ["MeadowValleyWash"] = { latitude = 36.658967, longitude = -114.623654, display_name = "MeadowValleyWash"},
    ["BigSmoky"] = { latitude = 38.305164, longitude = -117.519070, display_name = "BigSmoky"},
    ["IdlewildCreek"] = { latitude = 38.387220, longitude = -117.446783, display_name = "IdlewildCreek"},
    ["RainierMountain"] = { latitude = 38.489207, longitude = -117.424881, display_name = "RainierMountain"},
    }

NormandyTowns = {
    ["Flottemanville-Hague"] = { latitude = 49.618445, longitude = -1.741614, display_name = "Flottemanville-Hague"},
    ["Querqueville"] = { latitude = 49.661362, longitude = -1.686411, display_name = "Querqueville"},
    ["Port Militaire Cherbourg"] = { latitude = 49.652657, longitude = -1.617060, display_name = "Port Militaire Cherbourg"},
    ["Cherbourg"] = { latitude = 49.635153, longitude = -1.618563, display_name = "Cherbourg"},
    ["Tourlaville"] = { latitude = 49.645438, longitude = -1.548781, display_name = "Tourlaville"},
    ["Digosville"] = { latitude = 49.631408, longitude = -1.526746, display_name = "Digosville"},
    ["Maupertus"] = { latitude = 49.647869, longitude = -1.473875, display_name = "Maupertus"},
    ["Bordetie"] = { latitude = 49.687132, longitude = -1.459066, display_name = "Bordetie"},
    ["Cap Levy"] = { latitude = 49.705422, longitude = -1.477389, display_name = "Cap Levy"},
    ["Cosqueville"] = { latitude = 49.692031, longitude = -1.431940, display_name = "Cosqueville"},
    ["Renouville"] = { latitude = 49.698121, longitude = -1.386481, display_name = "Renouville"},
    ["Rethoville"] = { latitude = 49.693423, longitude = -1.359594, display_name = "Rethoville"},
    ["St.Pierre Eglise"] = { latitude = 49.666383, longitude = -1.404967, display_name = "St.Pierre Eglise"},
    ["Gouberville"] = { latitude = 49.687378, longitude = -1.312058, display_name = "Gouberville"},
    ["Gatteville"] = { latitude = 49.687585, longitude = -1.283647, display_name = "Gatteville"},
    ["Barfleur"] = { latitude = 49.669847, longitude = -1.267027, display_name = "Barfleur"},
    ["Montfarville"] = { latitude = 49.656466, longitude = -1.267706, display_name = "Montfarville"},
    ["La Mare a Canards"] = { latitude = 49.610471, longitude = -1.601112, display_name = "La Mare a Canards"},
    ["Vincent la Galle"] = { latitude = 49.608810, longitude = -1.538096, display_name = "Vincent la Galle"},
    ["Rufosses"] = { latitude = 49.582448, longitude = -1.522347, display_name = "Rufosses"},
    ["Les Tourtorelles"] = { latitude = 49.581428, longitude = -1.555062, display_name = "Les Tourtorelles"},
    ["Martirivast"] = { latitude = 49.586030, longitude = -1.633745, display_name = "Martirivast"},
    ["Les Mouchels"] = { latitude = 49.583417, longitude = -1.489358, display_name = "Les Mouchels"},
    ["St.Vaast la Hougue"] = { latitude = 49.585182, longitude = -1.266384, display_name = "St.Vaast la Hougue"},
    ["St.Martin le Greard"] = { latitude = 49.553510, longitude = -1.646690, display_name = "St.Martin le Greard"},
    ["Les Pieux"] = { latitude = 49.517913, longitude = -1.803060, display_name = "Les Pieux"},
    ["Girot"] = { latitude = 49.492912, longitude = -1.739170, display_name = "Girot"},
    ["Pierreville"] = { latitude = 49.465307, longitude = -1.773096, display_name = "Pierreville"},
    ["Surtainville"] = { latitude = 49.455449, longitude = -1.815690, display_name = "Surtainville"},
    ["Culule"] = { latitude = 49.437132, longitude = -1.803942, display_name = "Culule"},
    ["Le Meaudenaville"] = { latitude = 49.403933, longitude = -1.774806, display_name = "Le Meaudenaville"},
    ["Le Grand Breuil"] = { latitude = 49.408065, longitude = -1.743457, display_name = "Le Grand Breuil"},
    ["Sortosville-en-Beaumont"] = { latitude = 49.421909, longitude = -1.689124, display_name = "Sortosville-en-Beaumont"},
    ["Le Grand Hameau"] = { latitude = 49.412695, longitude = -1.674365, display_name = "Le Grand Hameau"},
    ["Bricquebec"] = { latitude = 49.468823, longitude = -1.630366, display_name = "Bricquebec"},
    ["Negreville"] = { latitude = 49.489366, longitude = -1.553241, display_name = "Negreville"},
    ["Etang-Bertrand"] = { latitude = 49.469301, longitude = -1.557704, display_name = "Etang-Bertrand"},
    ["Sottevast"] = { latitude = 49.520441, longitude = -1.598187, display_name = "Sottevast"},
    ["St.Joseph"] = { latitude = 49.532355, longitude = -1.530809, display_name = "St.Joseph"},
    ["Les Bouterillers"] = { latitude = 49.542341, longitude = -1.498460, display_name = "Les Bouterillers"},
    ["Valognes"] = { latitude = 49.507376, longitude = -1.470518, display_name = "Valognes"},
    ["Dutot"] = { latitude = 49.517226, longitude = -1.438270, display_name = "Dutot"},
    ["St.Martin d'Audouville"] = { latitude = 49.533225, longitude = -1.346837, display_name = "St.Martin d'Audouville"},
    ["Quineville"] = { latitude = 49.510559, longitude = -1.305649, display_name = "Quineville"},
    ["De Foutenay"] = { latitude = 49.502493, longitude = -1.279406, display_name = "De Foutenay"},
    ["St.Marcouf"] = { latitude = 49.472402, longitude = -1.287885, display_name = "St.Marcouf"},
    ["Azeville"] = { latitude = 49.458890, longitude = -1.311933, display_name = "Azeville"},
    ["Joganville"] = { latitude = 49.469731, longitude = -1.347591, display_name = "Joganville"},
    ["Montebourg"] = { latitude = 49.486865, longitude = -1.389988, display_name = "Montebourg"},
    ["Urville"] = { latitude = 49.447486, longitude = -1.430728, display_name = "Urville"},
    ["Magneville"] = { latitude = 49.446502, longitude = -1.377143, display_name = "Magneville"},
    ["Fresville"] = { latitude = 49.441019, longitude = -1.338624, display_name = "Fresville"},
    ["Neuville-au-Plain"] = { latitude = 49.426837, longitude = -1.331020, display_name = "Neuville-au-Plain"},
    ["St.Mere Eglise"] = { latitude = 49.408474, longitude = -1.319755, display_name = "St.Mere Eglise"},
    ["Gambosville"] = { latitude = 49.396753, longitude = -1.307330, display_name = "Gambosville"},
    ["Ecoqueneauville"] = { latitude = 49.401561, longitude = -1.290892, display_name = "Ecoqueneauville"},
    ["Amfreville"] = { latitude = 49.411751, longitude = -1.392101, display_name = "Amfreville"},
    ["Orglandes"] = { latitude = 49.421789, longitude = -1.448537, display_name = "Orglandes"},
    ["St.Colombe"] = { latitude = 49.426109, longitude = -1.511110, display_name = "St.Colombe"},
    ["Le Hequet"] = { latitude = 49.407466, longitude = -1.575545, display_name = "Le Hequet"},
    ["Reigneville"] = { latitude = 49.405031, longitude = -1.485040, display_name = "Reigneville"},
    [" St.Sauveur le Vicomte"] = { latitude = 49.385633, longitude = -1.528363, display_name = " St.Sauveur le Vicomte"},
    ["Gueutteville"] = { latitude = 49.393286, longitude = -1.389450, display_name = "Gueutteville"},
    ["Etienville"] = { latitude = 49.376985, longitude = -1.419887, display_name = "Etienville"},
    ["Neuville"] = { latitude = 49.380115, longitude = -1.452685, display_name = "Neuville"},
    ["Chef-du-Pont"] = { latitude = 49.383201, longitude = -1.338971, display_name = "Chef-du-Pont"},
    ["Blosville"] = { latitude = 49.373273, longitude = -1.287510, display_name = "Blosville"},
    ["Foucarville"] = { latitude = 49.442222, longitude = -1.255184, display_name = "Foucarville"},
    ["Les Dunes de Varreville"] = { latitude = 49.435649, longitude = -1.208866, display_name = "Les Dunes de Varreville"},
    ["Motte"] = { latitude = 49.389545, longitude = -1.631608, display_name = "Motte"},
    ["Prunier"] = { latitude = 49.369607, longitude = -1.700143, display_name = "Prunier"},
    ["Barneville"] = { latitude = 49.380984, longitude = -1.754264, display_name = "Barneville"},
    ["St.Lo d'Ourville"] = { latitude = 49.326323, longitude = -1.669902, display_name = "St.Lo d'Ourville"},
    ["La Eosserie"] = { latitude = 49.317726, longitude = -1.559271, display_name = "La Eosserie"},
    ["Doville"] = { latitude = 49.332415, longitude = -1.530180, display_name = "Doville"},
    ["La Detrousse"] = { latitude = 49.303138, longitude = -1.595436, display_name = "La Detrousse"},
    ["La Broquiere"] = { latitude = 49.292662, longitude = -1.650076, display_name = "La Broquiere"},
    ["Glatigny"] = { latitude = 49.268011, longitude = -1.635669, display_name = "Glatigny"},
    ["La Haye Du Puits"] = { latitude = 49.292278, longitude = -1.548849, display_name = "La Haye Du Puits"},
    ["La Poterie"] = { latitude = 49.305221, longitude = -1.487285, display_name = "La Poterie"},
    ["Surville"] = { latitude = 49.251060, longitude = -1.652232, display_name = "Surville"},
    ["St. Germain-sur-Ay"] = { latitude = 49.232190, longitude = -1.630097, display_name = "St. Germain-sur-Ay"},
    ["Lessay"] = { latitude = 49.216857, longitude = -1.526942, display_name = "Lessay"},
    ["Gouville sur Mer"] = { latitude = 49.093932, longitude = -1.586803, display_name = "Gouville sur Mer"},
    ["La Bagotterie"] = { latitude = 49.263216, longitude = -1.463424, display_name = "La Bagotterie"},
    ["Sainteny"] = { latitude = 49.240875, longitude = -1.330467, display_name = "Sainteny"},
    ["Baupte"] = { latitude = 49.307872, longitude = -1.371843, display_name = "Baupte"},
    ["Vindefontaine"] = { latitude = 49.337254, longitude = -1.420777, display_name = "Vindefontaine"},
    ["Liveteau"] = { latitude = 49.356249, longitude = -1.373288, display_name = "Liveteau"},
    ["Houesville"] = { latitude = 49.352178, longitude = -1.293180, display_name = "Houesville"},
    ["St.Come du Mont"] = { latitude = 49.333516, longitude = -1.287879, display_name = "St.Come du Mont"},
    ["Cantepie"] = { latitude = 49.293772, longitude = -1.307115, display_name = "Cantepie"},
    ["Carentan"] = { latitude = 49.303467, longitude = -1.248146, display_name = "Carentan"},
    ["Vierville"] = { latitude = 49.358664, longitude = -1.243376, display_name = "Vierville"},
    ["Brevands"] = { latitude = 49.328153, longitude = -1.183022, display_name = "Brevands"},
    ["Heisville"] = { latitude = 49.372560, longitude = -1.262884, display_name = "Heisville"},
    ["St.Marie du Mont"] = { latitude = 49.377429, longitude = -1.221049, display_name = "St.Marie du Mont"},
    ["Grandcamp les Bains"] = { latitude = 49.385101, longitude = -1.047646, display_name = "Grandcamp les Bains"},
    ["Letanville"] = { latitude = 49.368382, longitude = -1.028866, display_name = "Letanville"},
    ["Jucoville"] = { latitude = 49.357813, longitude = -1.024705, display_name = "Jucoville"},
    ["Fontenay"] = { latitude = 49.355974, longitude = -1.081025, display_name = "Fontenay"},
    ["Cardonville"] = { latitude = 49.344717, longitude = -1.066262, display_name = "Cardonville"},
    ["Osmanville"] = { latitude = 49.328595, longitude = -1.076969, display_name = "Osmanville"},
    ["Isigny"] = { latitude = 49.310061, longitude = -1.111702, display_name = "Isigny"},
    ["St.Germain du Pert"] = { latitude = 49.339099, longitude = -1.031192, display_name = "St.Germain du Pert"},
    ["Gueret"] = { latitude = 49.333178, longitude = -0.985911, display_name = "Gueret"},
    ["Longueville"] = { latitude = 49.341910, longitude = -0.959385, display_name = "Longueville"},
    ["Asnieres"] = { latitude = 49.369716, longitude = -0.949505, display_name = "Asnieres"},
    ["Vierville sur Mer"] = { latitude = 49.374420, longitude = -0.908132, display_name = "Vierville sur Mer"},
    ["Rouxeville"] = { latitude = 49.274522, longitude = -1.204659, display_name = "Rouxeville"},
    ["Lenauderi"] = { latitude = 49.281125, longitude = -1.153902, display_name = "Lenauderi"},
    ["St.Lambert"] = { latitude = 49.274917, longitude = -1.124010, display_name = "St.Lambert"},
    ["Le Ray"] = { latitude = 49.259737, longitude = -1.143389, display_name = "Le Ray"},
    ["Le Mont"] = { latitude = 49.254620, longitude = -1.167250, display_name = "Le Mont"},
    ["Graignes"] = { latitude = 49.239139, longitude = -1.203792, display_name = "Graignes"},
    ["Marchesieux"] = { latitude = 49.186318, longitude = -1.278556, display_name = "Marchesieux"},
    ["Le Desert"] = { latitude = 49.199317, longitude = -1.170423, display_name = "Le Desert"},
    ["St.Jean de Daye"] = { latitude = 49.224578, longitude = -1.135566, display_name = "St.Jean de Daye"},
    ["Aire"] = { latitude = 49.219685, longitude = -1.094824, display_name = "Aire"},
    ["Cavigny"] = { latitude = 49.195174, longitude = -1.108669, display_name = "Cavigny"},
    ["Port de la Hoderie"] = { latitude = 49.223119, longitude = -1.045656, display_name = "Port de la Hoderie"},
    ["Lison"] = { latitude = 49.255026, longitude = -1.040277, display_name = "Lison"},
    ["Epinay Tesson"] = { latitude = 49.230583, longitude = -0.980239, display_name = "Epinay Tesson"},
    ["Bernesq"] = { latitude = 49.261976, longitude = -0.945131, display_name = "Bernesq"},
    ["La Poterie"] = { latitude = 49.272059, longitude = -0.910479, display_name = "La Poterie"},
    ["Pont-Hebert"] = { latitude = 49.168432, longitude = -1.140419, display_name = "Pont-Hebert"},
    ["St la Creterie"] = { latitude = 49.160741, longitude = -1.121740, display_name = "St la Creterie"},
    ["Le Mesnil-Rouxelin"] = { latitude = 49.148060, longitude = -1.078393, display_name = "Le Mesnil-Rouxelin"},
    ["St.Georges d'Elle"] = { latitude = 49.143979, longitude = -0.972476, display_name = "St.Georges d'Elle"},
    ["Littcau"] = { latitude = 49.142159, longitude = -0.895898, display_name = "Littcau"},
    ["Nebecrevon"] = { latitude = 49.126372, longitude = -1.168853, display_name = "Nebecrevon"},
    ["Hamel"] = { latitude = 49.125055, longitude = -1.131202, display_name = "Hamel"},
    ["St.Georges-Montcocq"] = { latitude = 49.127899, longitude = -1.101280, display_name = "St.Georges-Montcocq"},
    ["St.Lo"] = { latitude = 49.113910, longitude = -1.095168, display_name = "St.Lo"},
    ["Agneaux"] = { latitude = 49.108779, longitude = -1.111396, display_name = "Agneaux"},
    ["Vellechien"] = { latitude = 49.113641, longitude = -1.150543, display_name = "Vellechien"},
    ["St.Gilles"] = { latitude = 49.100090, longitude = -1.179411, display_name = "St.Gilles"},
    ["Canisy"] = { latitude = 49.074727, longitude = -1.173776, display_name = "Canisy"},
    ["St.Martin de Bon Fosse"] = { latitude = 49.045571, longitude = -1.160146, display_name = "St.Martin de Bon Fosse"},
    ["Le Mesnil Herman"] = { latitude = 49.011096, longitude = -1.154973, display_name = "Le Mesnil Herman"},
    ["Moyen"] = { latitude = 48.984329, longitude = -1.092099, display_name = "Moyen"},
    ["Percy"] = { latitude = 48.942222, longitude = -1.162647, display_name = "Percy"},
    ["Tessy sur Vire"] = { latitude = 48.974873, longitude = -1.028374, display_name = "Tessy sur Vire"},
    ["St.Thomas-de St.Lo"] = { latitude = 49.093383, longitude = -1.099652, display_name = "St.Thomas-de St.Lo"},
    ["Fumichon"] = { latitude = 49.093214, longitude = -1.050684, display_name = "Fumichon"},
    ["Crocquevieille"] = { latitude = 49.093109, longitude = -0.970458, display_name = "Crocquevieille"},
    ["St.Jean des Baisants"] = { latitude = 49.088772, longitude = -0.968306, display_name = "St.Jean des Baisants"},
    ["Fontaine"] = { latitude = 49.080884, longitude = -0.992099, display_name = "Fontaine"},
    ["La Guerardlere"] = { latitude = 49.066197, longitude = -0.968169, display_name = "La Guerardlere"},
    ["Le Val"] = { latitude = 49.068809, longitude = -1.014844, display_name = "Le Val"},
    ["St.Sueanne"] = { latitude = 49.058543, longitude = -1.051035, display_name = "St.Sueanne"},
    ["Torigny sur Vire"] = { latitude = 49.033952, longitude = -0.992284, display_name = "Torigny sur Vire"},
    ["St.Amand"] = { latitude = 49.042438, longitude = -0.962980, display_name = "St.Amand"},
    ["Pianches"] = { latitude = 48.707270, longitude = 0.393749, display_name = "Pianches"},
    ["Neuville sur Touques"] = { latitude = 48.861593, longitude = 0.285292, display_name = "Neuville sur Touques"},
    ["Heurtevent"] = { latitude = 48.975655, longitude = 0.159837, display_name = "Heurtevent"},
    ["Livarot"] = { latitude = 48.990789, longitude = 0.170967, display_name = "Livarot"},
    ["St.Pierre-du-Mont"] = { latitude = 49.387904, longitude = -0.976547, display_name = "St.Pierre-du-Mont"},
    ["Villy"] = { latitude = 49.351827, longitude = -0.957134, display_name = "Villy"},
    ["La Vieille Place"] = { latitude = 49.349227, longitude = -0.996531, display_name = "La Vieille Place"},
    ["Ecramnieville"] = { latitude = 49.325529, longitude = -0.938917, display_name = "Ecramnieville"},
    ["Aignerville"] = { latitude = 49.321500, longitude = -0.927696, display_name = "Aignerville"},
    ["Trevieres"] = { latitude = 49.307470, longitude = -0.904232, display_name = "Trevieres"},
    ["Vouilly"] = { latitude = 49.291609, longitude = -1.021497, display_name = "Vouilly"},
    ["Chemin"] = { latitude = 49.294191, longitude = -1.041691, display_name = "Chemin"},
    ["Formigny"] = { latitude = 49.335059, longitude = -0.878164, display_name = "Formigny"},
    ["Colleville-sur-Mer"] = { latitude = 49.348247, longitude = -0.857461, display_name = "Colleville-sur-Mer"},
    ["La Vailee"] = { latitude = 49.349209, longitude = -0.812093, display_name = "La Vailee"},
    ["Cabourg"] = { latitude = 49.346454, longitude = -0.798637, display_name = "Cabourg"},
    ["Bellefontaine"] = { latitude = 49.329620, longitude = -0.826821, display_name = "Bellefontaine"},
    ["Etreham"] = { latitude = 49.319170, longitude = -0.793368, display_name = "Etreham"},
    ["Mosles"] = { latitude = 49.307364, longitude = -0.818248, display_name = "Mosles"},
    ["Mandeville"] = { latitude = 49.306602, longitude = -0.857645, display_name = "Mandeville"},
    ["Moulagny"] = { latitude = 49.289015, longitude = -0.832525, display_name = "Moulagny"},
    ["Rubercy"] = { latitude = 49.290550, longitude = -0.861206, display_name = "Rubercy"},
    ["Blay"] = { latitude = 49.271057, longitude = -0.850463, display_name = "Blay"},
    ["Halt"] = { latitude = 49.258679, longitude = -0.823592, display_name = "Halt"},
    ["Le Molay"] = { latitude = 49.252067, longitude = -0.885121, display_name = "Le Molay"},
    ["Desnoyers"] = { latitude = 49.242595, longitude = -0.859282, display_name = "Desnoyers"},
    ["La Mine"] = { latitude = 49.234900, longitude = -0.851839, display_name = "La Mine"},
    ["Le Tronquay"] = { latitude = 49.227222, longitude = -0.820442, display_name = "Le Tronquay"},
    ["Littry"] = { latitude = 49.223573, longitude = -0.869731, display_name = "Littry"},
    ["Cateaubrave"] = { latitude = 49.234859, longitude = -0.923361, display_name = "Cateaubrave"},
    ["St. Clair l'Elle"] = { latitude = 49.200726, longitude = -1.033220, display_name = "St. Clair l'Elle"},
    ["Cerisy la Foret"] = { latitude = 49.193069, longitude = -0.935797, display_name = "Cerisy la Foret"},
    ["Laval"] = { latitude = 49.205875, longitude = -0.892580, display_name = "Laval"},
    ["La Platiere"] = { latitude = 49.165655, longitude = -0.850934, display_name = "La Platiere"},
    ["Balleroy"] = { latitude = 49.183381, longitude = -0.832773, display_name = "Balleroy"},
    ["Bois de Baugy"] = { latitude = 49.167409, longitude = -0.803062, display_name = "Bois de Baugy"},
    ["Le Fayel"] = { latitude = 49.148941, longitude = -0.790149, display_name = "Le Fayel"},
    ["Le Pont Hebert"] = { latitude = 49.143081, longitude = -0.854847, display_name = "Le Pont Hebert"},
    ["Foulognes"] = { latitude = 49.145249, longitude = -0.823248, display_name = "Foulognes"},
    ["La Quevennerie"] = { latitude = 49.130340, longitude = -0.803080, display_name = "La Quevennerie"},
    ["Vilday"] = { latitude = 49.123900, longitude = -0.825338, display_name = "Vilday"},
    ["Caumont"] = { latitude = 49.090027, longitude = -0.806425, display_name = "Caumont"},
    ["Orbois"] = { latitude = 49.121527, longitude = -0.689285, display_name = "Orbois"},
    ["Villers-Bocage"] = { latitude = 49.078556, longitude = -0.657865, display_name = "Villers-Bocage"},
    ["Hottot"] = { latitude = 49.163032, longitude = -0.646566, display_name = "Hottot"},
    ["Tilly-Sur-Seulles"] = { latitude = 49.171929, longitude = -0.623390, display_name = "Tilly-Sur-Seulles"},
    ["Buceels"] = { latitude = 49.190881, longitude = -0.633577, display_name = "Buceels"},
    ["Verrieres"] = { latitude = 49.175839, longitude = -0.690440, display_name = "Verrieres"},
    ["Trungy"] = { latitude = 49.203830, longitude = -0.732137, display_name = "Trungy"},
    ["St.Andre"] = { latitude = 49.217005, longitude = -0.719135, display_name = "St.Andre"},
    ["Ellon"] = { latitude = 49.225763, longitude = -0.685156, display_name = "Ellon"},
    ["Blary"] = { latitude = 49.238074, longitude = -0.675993, display_name = "Blary"},
    ["Martragny"] = { latitude = 49.252071, longitude = -0.613474, display_name = "Martragny"},
    ["Bayeux"] = { latitude = 49.276360, longitude = -0.705183, display_name = "Bayeux"},
    ["Sommervieu"] = { latitude = 49.292873, longitude = -0.647265, display_name = "Sommervieu"},
    ["Ryes"] = { latitude = 49.312329, longitude = -0.627189, display_name = "Ryes"},
    ["Buhot"] = { latitude = 49.330004, longitude = -0.605138, display_name = "Buhot"},
    ["Arromanches les Bains"] = { latitude = 49.339041, longitude = -0.625254, display_name = "Arromanches les Bains"},
    ["Manvieux"] = { latitude = 49.335856, longitude = -0.655904, display_name = "Manvieux"},
    ["La Rosiere"] = { latitude = 49.323723, longitude = -0.652791, display_name = "La Rosiere"},
    ["Fontenailles"] = { latitude = 49.328694, longitude = -0.681766, display_name = "Fontenailles"},
    ["Longues"] = { latitude = 49.334232, longitude = -0.705692, display_name = "Longues"},
    ["Les Moulins"] = { latitude = 49.356154, longitude = -0.754268, display_name = "Les Moulins"},
    ["Villiers sur Port"] = { latitude = 49.334575, longitude = -0.778138, display_name = "Villiers sur Port"},
    ["Escures"] = { latitude = 49.329526, longitude = -0.756620, display_name = "Escures"},
    ["Maisons"] = { latitude = 49.319359, longitude = -0.758515, display_name = "Maisons"},
    ["Tour-en-Bessin"] = { latitude = 49.288332, longitude = -0.767133, display_name = "Tour-en-Bessin"},
    ["Ranchy"] = { latitude = 49.254267, longitude = -0.755595, display_name = "Ranchy"},
    ["Subles"] = { latitude = 49.243134, longitude = -0.745317, display_name = "Subles"},
    ["Agy"] = { latitude = 49.240450, longitude = -0.761469, display_name = "Agy"},
    ["Ranchy"] = { latitude = 49.260387, longitude = -0.780964, display_name = "Ranchy"},
    ["Le Bas Mougard"] = { latitude = 49.209996, longitude = -0.759984, display_name = "Le Bas Mougard"},
    ["Dodigny"] = { latitude = 49.223805, longitude = -0.782684, display_name = "Dodigny"},
    ["Cahagnes"] = { latitude = 49.065953, longitude = -0.770793, display_name = "Cahagnes"},
    ["Coulvain"] = { latitude = 49.051282, longitude = -0.720056, display_name = "Coulvain"},
    ["Aunay-sur Odon"] = { latitude = 49.020160, longitude = -0.631061, display_name = "Aunay-sur Odon"},
    ["Le Bos"] = { latitude = 49.059354, longitude = -0.893610, display_name = "Le Bos"},
    ["St.Martin des Besaces"] = { latitude = 49.009223, longitude = -0.842690, display_name = "St.Martin des Besaces"},
    ["Guilberville"] = { latitude = 48.989576, longitude = -0.950781, display_name = "Guilberville"},
    ["Le Beny Bocage"] = { latitude = 48.937576, longitude = -0.840767, display_name = "Le Beny Bocage"},
    ["Montcharivel"] = { latitude = 48.947697, longitude = -0.742417, display_name = "Montcharivel"},
    ["St.Jean le Blance"] = { latitude = 48.934196, longitude = -0.655342, display_name = "St.Jean le Blance"},
    ["Sourdeval"] = { latitude = 48.924449, longitude = -0.928677, display_name = "Sourdeval"},
    ["Etouvy"] = { latitude = 48.894967, longitude = -0.886152, display_name = "Etouvy"},
    ["Forgues"] = { latitude = 48.881350, longitude = -0.809324, display_name = "Forgues"},
    ["Vire"] = { latitude = 48.846852, longitude = -0.891349, display_name = "Vire"},
    ["Roullours"] = { latitude = 48.829258, longitude = -0.844830, display_name = "Roullours"},
    ["La Bauillante"] = { latitude = 48.823551, longitude = -0.788667, display_name = "La Bauillante"},
    ["St.Germain de Tallevende"] = { latitude = 48.796370, longitude = -0.909158, display_name = "St.Germain de Tallevende"},
    ["La Bercendiere"] = { latitude = 48.776719, longitude = -0.888195, display_name = "La Bercendiere"},
    ["Truttemer le Grand"] = { latitude = 48.773470, longitude = -0.838309, display_name = "Truttemer le Grand"},
    ["St.Cornier des Landes"] = { latitude = 48.719134, longitude = -0.712868, display_name = "St.Cornier des Landes"},
    ["Landisacq"] = { latitude = 48.754694, longitude = -0.632607, display_name = "Landisacq"},
    ["Le Grand Celland"] = { latitude = 48.671500, longitude = -1.158563, display_name = "Le Grand Celland"},
    ["Le Hamel"] = { latitude = 49.339687, longitude = -0.587076, display_name = "Le Hamel"},
    ["Meuvaines"] = { latitude = 49.325777, longitude = -0.567301, display_name = "Meuvaines"},
    ["Crepon"] = { latitude = 49.315950, longitude = -0.551635, display_name = "Crepon"},
    ["Mont Fleury"] = { latitude = 49.333719, longitude = -0.524847, display_name = "Mont Fleury"},
    ["Ste.Croix sur Mer"] = { latitude = 49.311865, longitude = -0.512469, display_name = "Ste.Croix sur Mer"},
    ["Banville"] = { latitude = 49.314163, longitude = -0.485883, display_name = "Banville"},
    ["Graye sur Mer"] = { latitude = 49.330428, longitude = -0.475400, display_name = "Graye sur Mer"},
    ["Courseulles sur Mer"] = { latitude = 49.335412, longitude = -0.456503, display_name = "Courseulles sur Mer"},
    ["La Rive"] = { latitude = 49.334208, longitude = -0.414692, display_name = "La Rive"},
    ["Bazenville"] = { latitude = 49.301734, longitude = -0.594567, display_name = "Bazenville"},
    ["Villiers le Sec"] = { latitude = 49.290508, longitude = -0.568656, display_name = "Villiers le Sec"},
    ["Creully"] = { latitude = 49.285667, longitude = -0.537760, display_name = "Creully"},
    ["Amblie"] = { latitude = 49.289167, longitude = -0.494223, display_name = "Amblie"},
    ["Reviers"] = { latitude = 49.302970, longitude = -0.465435, display_name = "Reviers"},
    ["Fontaine Henry"] = { latitude = 49.278735, longitude = -0.457721, display_name = "Fontaine Henry"},
    ["Basly"] = { latitude = 49.278846, longitude = -0.425515, display_name = "Basly"},
    ["Douvres"] = { latitude = 49.296918, longitude = -0.376828, display_name = "Douvres"},
    ["La Delivrande"] = { latitude = 49.299767, longitude = -0.366933, display_name = "La Delivrande"},
    ["Langrune sur Mer"] = { latitude = 49.324829, longitude = -0.372841, display_name = "Langrune sur Mer"},
    ["Lion sur Mer"] = { latitude = 49.300622, longitude = -0.324756, display_name = "Lion sur Mer"},
    ["Hermanville sur Mer"] = { latitude = 49.283126, longitude = -0.317108, display_name = "Hermanville sur Mer"},
    ["Cazelle"] = { latitude = 49.255818, longitude = -0.371735, display_name = "Cazelle"},
    ["Thaon"] = { latitude = 49.258637, longitude = -0.454057, display_name = "Thaon"},
    ["Le Fresne-Camilly"] = { latitude = 49.259691, longitude = -0.488481, display_name = "Le Fresne-Camilly"},
    ["Coulombs"] = { latitude = 49.244755, longitude = -0.564702, display_name = "Coulombs"},
    ["Ste.Croix Grand Tonne"] = { latitude = 49.230538, longitude = -0.569522, display_name = "Ste.Croix Grand Tonne"},
    ["Secqueville-en-Bessin"] = { latitude = 49.240908, longitude = -0.510847, display_name = "Secqueville-en-Bessin"},
    ["Vieux Cairon"] = { latitude = 49.232302, longitude = -0.446368, display_name = "Vieux Cairon"},
    ["Les Buissons"] = { latitude = 49.237513, longitude = -0.414384, display_name = "Les Buissons"},
    ["Halt"] = { latitude = 49.231457, longitude = -0.384247, display_name = "Halt"},
    ["Buron"] = { latitude = 49.218399, longitude = -0.420302, display_name = "Buron"},
    ["Rots"] = { latitude = 49.218392, longitude = -0.466183, display_name = "Rots"},
    ["Epron"] = { latitude = 49.221199, longitude = -0.368307, display_name = "Epron"},
    ["Lebisey"] = { latitude = 49.218157, longitude = -0.343518, display_name = "Lebisey"},
    ["Couvre-Chef"] = { latitude = 49.210787, longitude = -0.365427, display_name = "Couvre-Chef"},
    ["Fleury-sur-Orne"] = { latitude = 49.135469, longitude = -0.354643, display_name = "Fleury-sur-Orne"},
    ["Caen"] = { latitude = 49.184505, longitude = -0.353785, display_name = "Caen"},
    ["Faubg De Vaucelles"] = { latitude = 49.169054, longitude = -0.340431, display_name = "Faubg De Vaucelles"},
    ["Cormelles"] = { latitude = 49.153486, longitude = -0.325377, display_name = "Cormelles"},
    ["Mondeville"] = { latitude = 49.175629, longitude = -0.303943, display_name = "Mondeville"},
    ["Colombelles"] = { latitude = 49.202725, longitude = -0.321348, display_name = "Colombelles"},
    ["Blainville"] = { latitude = 49.224644, longitude = -0.309631, display_name = "Blainville"},
    ["Bieville"] = { latitude = 49.240198, longitude = -0.328138, display_name = "Bieville"},
    ["St.Aubin d'Arquenay"] = { latitude = 49.263695, longitude = -0.284482, display_name = "St.Aubin d'Arquenay"},
    ["Ouistreham"] = { latitude = 49.281785, longitude = -0.259996, display_name = "Ouistreham"},
    ["Benouville"] = { latitude = 49.241948, longitude = -0.283385, display_name = "Benouville"},
    ["Ranville"] = { latitude = 49.230554, longitude = -0.261228, display_name = "Ranville"},
    ["Honorine la Chardonnerette"] = { latitude = 49.208859, longitude = -0.276920, display_name = "Honorine la Chardonnerette"},
    ["Herouvillette"] = { latitude = 49.218913, longitude = -0.241893, display_name = "Herouvillette"},
    ["Escoville"] = { latitude = 49.210302, longitude = -0.239214, display_name = "Escoville"},
    ["Touffreville"] = { latitude = 49.183502, longitude = -0.224920, display_name = "Touffreville"},
    ["Cuverville"] = { latitude = 49.189700, longitude = -0.267832, display_name = "Cuverville"},
    ["Banneville la Campagne"] = { latitude = 49.175813, longitude = -0.210734, display_name = "Banneville la Campagne"},
    ["Troarn"] = { latitude = 49.184552, longitude = -0.186578, display_name = "Troarn"},
    ["Bures"] = { latitude = 49.199561, longitude = -0.174364, display_name = "Bures"},
    ["Bavent"] = { latitude = 49.231272, longitude = -0.195849, display_name = "Bavent"},
    ["Amfreville"] = { latitude = 49.249618, longitude = -0.233303, display_name = "Amfreville"},
    ["Goneville sur Merville"] = { latitude = 49.260924, longitude = -0.190508, display_name = "Goneville sur Merville"},
    ["Varaville"] = { latitude = 49.254539, longitude = -0.161521, display_name = "Varaville"},
    ["Petiville"] = { latitude = 49.241124, longitude = -0.177081, display_name = "Petiville"},
    ["Bricqueville"] = { latitude = 49.230287, longitude = -0.155597, display_name = "Bricqueville"},
    ["Cabourg"] = { latitude = 49.288563, longitude = -0.128986, display_name = "Cabourg"},
    ["Dives-sur-Mer"] = { latitude = 49.277712, longitude = -0.102591, display_name = "Dives-sur-Mer"},
    ["Houlgate"] = { latitude = 49.301433, longitude = -0.088493, display_name = "Houlgate"},
    ["Dozule"] = { latitude = 49.241506, longitude = -0.068623, display_name = "Dozule"},
    ["Auberville"] = { latitude = 49.311254, longitude = -0.030769, display_name = "Auberville"},
    ["Blonville-sur-Mer"] = { latitude = 49.324807, longitude = 0.005283, display_name = "Blonville-sur-Mer"},
    ["Danesta"] = { latitude = 49.252992, longitude = 0.006003, display_name = "Danesta"},
    ["Crevecceur-en-Auge "] = { latitude = 49.117414, longitude = 0.015095, display_name = "Crevecceur-en-Auge "},
    ["La Butte"] = { latitude = 49.098037, longitude = -0.078017, display_name = "La Butte"},
    ["Moult"] = { latitude = 49.113502, longitude = -0.164138, display_name = "Moult"},
    ["Vimont"] = { latitude = 49.119944, longitude = -0.177341, display_name = "Vimont"},
    ["Frenouville"] = { latitude = 49.139944, longitude = -0.242853, display_name = "Frenouville"},
    ["Cagny"] = { latitude = 49.146062, longitude = -0.259222, display_name = "Cagny"},
    ["Soliers"] = { latitude = 49.135973, longitude = -0.295543, display_name = "Soliers"},
    ["Bourguebus"] = { latitude = 49.121085, longitude = -0.300123, display_name = "Bourguebus"},
    ["St.Martin de Fontenay"] = { latitude = 49.103638, longitude = -0.360562, display_name = "St.Martin de Fontenay"},
    ["Fontenay le Marmion"] = { latitude = 49.092377, longitude = -0.353818, display_name = "Fontenay le Marmion"},
    ["Roquancourt"] = { latitude = 49.096610, longitude = -0.320404, display_name = "Roquancourt"},
    ["Gaugains"] = { latitude = 49.063049, longitude = -0.328094, display_name = "Gaugains"},
    ["Cintheaux"] = { latitude = 49.058909, longitude = -0.250852, display_name = "Cintheaux"},
    ["Rue Vilaine"] = { latitude = 49.057082, longitude = -0.214058, display_name = "Rue Vilaine"},
    ["Bronay"] = { latitude = 49.215087, longitude = -0.590474, display_name = "Bronay"},
    ["Putot-en Bessin"] = { latitude = 49.213936, longitude = -0.543085, display_name = "Putot-en Bessin"},
    ["Bretteville el'Orgueilleuse"] = { latitude = 49.208221, longitude = -0.515429, display_name = "Bretteville el'Orgueilleuse"},
    ["Authie"] = { latitude = 49.207220, longitude = -0.430038, display_name = "Authie"},
    ["Cussy"] = { latitude = 49.201748, longitude = -0.409956, display_name = "Cussy"},
    ["St.Contest"] = { latitude = 49.211063, longitude = -0.404091, display_name = "St.Contest"},
    ["St.Gemain la Blanche-Herbe"] = { latitude = 49.186525, longitude = -0.403088, display_name = "St.Gemain la Blanche-Herbe"},
    ["Carpiquet"] = { latitude = 49.185997, longitude = -0.443262, display_name = "Carpiquet"},
    ["Marcelet"] = { latitude = 49.180476, longitude = -0.481972, display_name = "Marcelet"},
    ["St.Mauvieu"] = { latitude = 49.181079, longitude = -0.506301, display_name = "St.Mauvieu"},
    ["Cheux"] = { latitude = 49.167237, longitude = -0.521517, display_name = "Cheux"},
    ["Fontenay le Pesnel"] = { latitude = 49.166568, longitude = -0.574714, display_name = "Fontenay le Pesnel"},
    ["Seint Pierre"] = { latitude = 49.184957, longitude = -0.604466, display_name = "Seint Pierre"},
    ["Juvigny"] = { latitude = 49.157128, longitude = -0.603752, display_name = "Juvigny"},
    ["Vendes"] = { latitude = 49.146308, longitude = -0.601269, display_name = "Vendes"},
    ["Noyers"] = { latitude = 49.121659, longitude = -0.571080, display_name = "Noyers"},
    ["Tourville"] = { latitude = 49.140216, longitude = -0.495784, display_name = "Tourville"},
    ["Mouen"] = { latitude = 49.149658, longitude = -0.461249, display_name = "Mouen"},
    ["Bretteville sur Odon"] = { latitude = 49.166530, longitude = -0.420827, display_name = "Bretteville sur Odon"},
    ["Louvigny"] = { latitude = 49.157554, longitude = -0.392790, display_name = "Louvigny"},
    ["Basse"] = { latitude = 49.144088, longitude = -0.380812, display_name = "Basse"},
    ["Eterville"] = { latitude = 49.144763, longitude = -0.426415, display_name = "Eterville"},
    ["Maltot"] = { latitude = 49.129926, longitude = -0.423413, display_name = "Maltot"},
    ["Baron"] = { latitude = 49.132450, longitude = -0.476524, display_name = "Baron"},
    ["St.Andre-sur Orne"] = { latitude = 49.112625, longitude = -0.375274, display_name = "St.Andre-sur Orne"},
    ["Clinohamp-sur-Orne"] = { latitude = 49.085286, longitude = -0.376488, display_name = "Clinohamp-sur-Orne"},
    ["Amaye-sur Orne"] = { latitude = 49.079710, longitude = -0.444843, display_name = "Amaye-sur Orne"},
    ["Mutrecy"] = { latitude = 49.062589, longitude = -0.426782, display_name = "Mutrecy"},
    ["St.Honorine-da Fay"] = { latitude = 49.074341, longitude = -0.498031, display_name = "St.Honorine-da Fay"},
    ["Esquay"] = { latitude = 49.112357, longitude = -0.470765, display_name = "Esquay"},
    ["Evrecy"] = { latitude = 49.098853, longitude = -0.503690, display_name = "Evrecy"},
    ["Le Locheur"] = { latitude = 49.105947, longitude = -0.552664, display_name = "Le Locheur"},
    ["Preaux-Bocage"] = { latitude = 49.053832, longitude = -0.468072, display_name = "Preaux-Bocage"},
    ["Grimbosa"] = { latitude = 49.051831, longitude = -0.435208, display_name = "Grimbosa"},
    ["St.Laurents-de Counel"] = { latitude = 49.039562, longitude = -0.413450, display_name = "St.Laurents-de Counel"},
    ["La Bagotiere"] = { latitude = 49.036902, longitude = -0.448292, display_name = "La Bagotiere"},
    ["La Moissonniere"] = { latitude = 49.023095, longitude = -0.463609, display_name = "La Moissonniere"},
    ["Neumer"] = { latitude = 49.019788, longitude = -0.489521, display_name = "Neumer"},
    ["Bretteville-sur-Laize"] = { latitude = 49.054922, longitude = -0.294649, display_name = "Bretteville-sur-Laize"},
    ["Abbaye"] = { latitude = 49.043394, longitude = -0.324357, display_name = "Abbaye"},
    ["Urville"] = { latitude = 49.037654, longitude = -0.280875, display_name = "Urville"},
    ["St.Quentin"] = { latitude = 48.974187, longitude = -0.242503, display_name = "St.Quentin"},
    ["St.Pierre la Vieille"] = { latitude = 48.918145, longitude = -0.578851, display_name = "St.Pierre la Vieille"},
    ["La Manceliere"] = { latitude = 48.751014, longitude = -0.483766, display_name = "La Manceliere"},
    ["Falaise"] = { latitude = 48.888644, longitude = -0.196072, display_name = "Falaise"},
    ["Ners"] = { latitude = 48.881392, longitude = -0.092520, display_name = "Ners"},
    ["Cantepie"] = { latitude = 48.915116, longitude = -0.067606, display_name = "Cantepie"},
    ["Barou"] = { latitude = 48.926620, longitude = -0.042490, display_name = "Barou"},
    ["Ailly"] = { latitude = 48.940579, longitude = -0.081820, display_name = "Ailly"},
    ["Epaney"] = { latitude = 48.949240, longitude = -0.132951, display_name = "Epaney"},
    ["Vendeuvre"] = { latitude = 48.998638, longitude = -0.085034, display_name = "Vendeuvre"},
    ["Morieres"] = { latitude = 48.993329, longitude = -0.032705, display_name = "Morieres"},
    ["Pommainville"] = { latitude = 48.794259, longitude = -0.039323, display_name = "Pommainville"},
    ["Argentan"] = { latitude = 48.728498, longitude = -0.013975, display_name = "Argentan"},
    ["Fontenai-sur Orne"] = { latitude = 48.718430, longitude = -0.054875, display_name = "Fontenai-sur Orne"},
    ["Noisville"] = { latitude = 48.693429, longitude = -0.094988, display_name = "Noisville"},
    ["Tourville la Chapelle"] = { latitude = 49.955181, longitude = 1.255610, display_name = "Tourville la Chapelle"},
    ["St.Martin de Boscherville"] = { latitude = 49.432927, longitude = 0.960349, display_name = "St.Martin de Boscherville"},
    ["Sotteville-les Rouen"] = { latitude = 49.423897, longitude = 1.081984, display_name = "Sotteville-les Rouen"},
    ["Rouen"] = { latitude = 49.445075, longitude = 1.098650, display_name = "Rouen"},
    ["Darnetal"] = { latitude = 49.456068, longitude = 1.131969, display_name = "Darnetal"},
    ["Roncherolles"] = { latitude = 49.471987, longitude = 1.205728, display_name = "Roncherolles"},
    ["Alizay"] = { latitude = 49.320605, longitude = 1.191936, display_name = "Alizay"},
    ["St.Pierre le Elbeuf"] = { latitude = 49.285502, longitude = 1.114084, display_name = "St.Pierre le Elbeuf"},
    ["Bernieres"] = { latitude = 49.232082, longitude = 1.338018, display_name = "Bernieres"},
    ["Venables"] = { latitude = 49.216272, longitude = 1.319689, display_name = "Venables"},
    ["Gaillon"] = { latitude = 49.158928, longitude = 1.340989, display_name = "Gaillon"},
    ["Epegard"] = { latitude = 49.184127, longitude = 0.879974, display_name = "Epegard"},
    ["Le Neubourg"] = { latitude = 49.140185, longitude = 0.942918, display_name = "Le Neubourg"},
    ["Gauville la Campagne"] = { latitude = 49.059162, longitude = 1.101011, display_name = "Gauville la Campagne"},
    ["Evreux"] = { latitude = 49.014668, longitude = 1.154038, display_name = "Evreux"},
    ["St.Jean de Livet"] = { latitude = 49.096585, longitude = 0.241335, display_name = "St.Jean de Livet"},
    ["Lisieux"] = { latitude = 49.150695, longitude = 0.233016, display_name = "Lisieux"},
    ["St.Jacques"] = { latitude = 49.144098, longitude = 0.269036, display_name = "St.Jacques"},
    ["Ouilly-du Houley"] = { latitude = 49.163526, longitude = 0.348815, display_name = "Ouilly-du Houley"},
    ["Bernay"] = { latitude = 49.086491, longitude = 0.593858, display_name = "Bernay"},
    ["Boisney"] = { latitude = 49.158761, longitude = 0.666811, display_name = "Boisney"},
    ["Bonnesosq"] = { latitude = 49.203412, longitude = 0.058928, display_name = "Bonnesosq"},
    ["La Chapelle Hainfray"] = { latitude = 49.240932, longitude = 0.100079, display_name = "La Chapelle Hainfray"},
    ["L'Hubert"] = { latitude = 49.241061, longitude = 0.156198, display_name = "L'Hubert"},
    ["Bas Fauiq"] = { latitude = 49.238181, longitude = 0.358965, display_name = "Bas Fauiq"},
    ["Cormeilles"] = { latitude = 49.236793, longitude = 0.400230, display_name = "Cormeilles"},
    ["Morainville pres Lieurey"] = { latitude = 49.227428, longitude = 0.447221, display_name = "Morainville pres Lieurey"},
    ["Benerville"] = { latitude = 49.344535, longitude = 0.055094, display_name = "Benerville"},
    ["Arnoult"] = { latitude = 49.335471, longitude = 0.099470, display_name = "Arnoult"},
    ["Touques"] = { latitude = 49.353817, longitude = 0.119795, display_name = "Touques"},
    ["St.Martin-aux-Chartrams"] = { latitude = 49.323801, longitude = 0.183140, display_name = "St.Martin-aux-Chartrams"},
    ["St.Gatien"] = { latitude = 49.347401, longitude = 0.192596, display_name = "St.Gatien"},
    ["Theil"] = { latitude = 49.347027, longitude = 0.276307, display_name = "Theil"},
    ["Trouville"] = { latitude = 49.368090, longitude = 0.094909, display_name = "Trouville"},
    ["Les Aubets"] = { latitude = 49.378503, longitude = 0.121194, display_name = "Les Aubets"},
    ["Criqueboeut"] = { latitude = 49.399185, longitude = 0.150794, display_name = "Criqueboeut"},
    ["Honfleur"] = { latitude = 49.411740, longitude = 0.261542, display_name = "Honfleur"},
    ["Gonfreville l'Orcher"] = { latitude = 49.485569, longitude = 0.242180, display_name = "Gonfreville l'Orcher"},
    ["Berville-sur-Mer"] = { latitude = 49.427525, longitude = 0.378374, display_name = "Berville-sur-Mer"},
    ["St.Pierre-du Val"] = { latitude = 49.409237, longitude = 0.379186, display_name = "St.Pierre-du Val"},
    ["Potiers"] = { latitude = 49.412427, longitude = 0.402296, display_name = "Potiers"},
    ["Pont-Audemer"] = { latitude = 49.394116, longitude = 0.527479, display_name = "Pont-Audemer"},
    ["Tricqueville"] = { latitude = 49.336364, longitude = 0.440749, display_name = "Tricqueville"},
    ["La Lande"] = { latitude = 49.303870, longitude = 0.365869, display_name = "La Lande"},
    ["Campigny"] = { latitude = 49.325916, longitude = 0.548844, display_name = "Campigny"},
    ["Bosc-Renoult en Roumois"] = { latitude = 49.304735, longitude = 0.762344, display_name = "Bosc-Renoult en Roumois"},
    ["Routot"] = { latitude = 49.379446, longitude = 0.752233, display_name = "Routot"},
    ["Tocqueville"] = { latitude = 49.417802, longitude = 0.617799, display_name = "Tocqueville"},
    ["La Haye de Routot"] = { latitude = 49.420033, longitude = 0.732834, display_name = "La Haye de Routot"},
    ["Le Bose Lambert"] = { latitude = 49.426386, longitude = 0.786168, display_name = "Le Bose Lambert"},
    ["Hauville"] = { latitude = 49.396399, longitude = 0.800170, display_name = "Hauville"},
    ["Englesqueville"] = { latitude = 49.342539, longitude = 0.149485, display_name = "Englesqueville"},
    ["Brehal"] = { latitude = 48.900998, longitude = -1.507316, display_name = "Brehal"},
    ["Granville"] = { latitude = 48.840537, longitude = -1.561122, display_name = "Granville"},
    ["Le Havre"] = { latitude = 49.479181, longitude = 0.123491, display_name = "Le Havre"},
    }

PersianGulfTowns = {
    ["Aqr"] = { latitude = 24.810000, longitude = 56.440000, display_name = "Aqr"},
    ["Al Hadd"] = { latitude = 24.490000, longitude = 56.590000, display_name = "Al Hadd"},
    ["Magan"] = { latitude = 24.420000, longitude = 56.580000, display_name = "Magan"},
    ["Lar"] = { latitude = 27.661306, longitude = 54.323267, display_name = "Lar"},
    ["Bukha"] = { latitude = 26.140000, longitude = 56.150000, display_name = "Bukha"},
    ["Al Khadhrawain"] = { latitude = 24.850000, longitude = 56.400000, display_name = "Al Khadhrawain"},
    ["Al Bulaydah"] = { latitude = 24.840000, longitude = 56.410000, display_name = "Al Bulaydah"},
    ["Al Wadiyat"] = { latitude = 24.800180, longitude = 56.450043, display_name = "Al Wadiyat"},
    ["Dabbagh"] = { latitude = 24.540000, longitude = 56.560000, display_name = "Dabbagh"},
    ["Sallan"] = { latitude = 24.394327, longitude = 56.726862, display_name = "Sallan"},
    ["Majhal"] = { latitude = 24.470000, longitude = 56.330000, display_name = "Majhal"},
    ["An Naqdah"] = { latitude = 24.500000, longitude = 56.590000, display_name = "An Naqdah"},
    ["Al Liwa"] = { latitude = 24.540000, longitude = 56.570000, display_name = "Al Liwa"},
    ["Lekfayir"] = { latitude = 26.040000, longitude = 56.350000, display_name = "Lekfayir"},
    ["Maritime City"] = { latitude = 25.267084, longitude = 55.268159, display_name = "Maritime City"},
    ["Shaqu"] = { latitude = 27.236470, longitude = 56.361992, display_name = "Shaqu"},
    ["Larak Island"] = { latitude = 26.883481, longitude = 56.388735, display_name = "Larak Island"},
    ["A Treef"] = { latitude = 24.370000, longitude = 56.710000, display_name = "A Treef"},
    ["Falaj al Qabail"] = { latitude = 24.430000, longitude = 56.610000, display_name = "Falaj al Qabail"},
    ["Al Mamzar"] = { latitude = 25.303968, longitude = 55.342519, display_name = "Al Mamzar"},
    ["Ghadfan"] = { latitude = 24.470000, longitude = 56.600000, display_name = "Ghadfan"},
    ["Al Ghashbah"] = { latitude = 24.390000, longitude = 56.690000, display_name = "Al Ghashbah"},
    ["Sohar"] = { latitude = 24.344558, longitude = 56.742477, display_name = "Sohar"},
    ["Abu Musa Island"] = { latitude = 25.871497, longitude = 55.031741, display_name = "Abu Musa Island"},
    ["Ar Ramlah"] = { latitude = 25.508331, longitude = 55.587911, display_name = "Ar Ramlah"},
    ["As Salamah"] = { latitude = 25.493873, longitude = 55.591668, display_name = "As Salamah"},
    ["Sayh al Asfal"] = { latitude = 26.079096, longitude = 56.340000, display_name = "Sayh al Asfal"},
    ["Al Burayk"] = { latitude = 24.399949, longitude = 56.669999, display_name = "Al Burayk"},
    ["Sharyat Ayqal"] = { latitude = 26.081123, longitude = 56.341464, display_name = "Sharyat Ayqal"},
    ["Al Afifah"] = { latitude = 24.410000, longitude = 56.700000, display_name = "Al Afifah"},
    ["Hillat Jan Muhammad Khan"] = { latitude = 24.619982, longitude = 56.520001, display_name = "Hillat Jan Muhammad Khan"},
    ["Sur al Mazari"] = { latitude = 24.639898, longitude = 56.519994, display_name = "Sur al Mazari"},
    ["Asrar Bani Sad"] = { latitude = 24.590000, longitude = 56.550000, display_name = "Asrar Bani Sad"},
    ["Al Makhamarah"] = { latitude = 24.622574, longitude = 56.523492, display_name = "Al Makhamarah"},
    ["Juyom"] = { latitude = 28.252947, longitude = 53.982912, display_name = "Juyom"},
    ["Khatam Malahah"] = { latitude = 24.970000, longitude = 56.370000, display_name = "Khatam Malahah"},
    ["Dadna"] = { latitude = 25.522473, longitude = 56.357902, display_name = "Dadna"},
    ["Niad"] = { latitude = 26.100000, longitude = 56.330000, display_name = "Niad"},
    ["Hayr Salam"] = { latitude = 26.080000, longitude = 56.330000, display_name = "Hayr Salam"},
    ["Ghubn Hamad"] = { latitude = 26.080000, longitude = 56.290000, display_name = "Ghubn Hamad"},
    ["Ar Rawdah"] = { latitude = 25.860000, longitude = 56.300000, display_name = "Ar Rawdah"},
    ["Al Dhaid"] = { latitude = 25.284179, longitude = 55.879651, display_name = "Al Dhaid"},
    ["Hajiabad"] = { latitude = 28.359072, longitude = 54.420670, display_name = "Hajiabad"},
    ["Murbah"] = { latitude = 25.282317, longitude = 56.363613, display_name = "Murbah"},
    ["Baharestan"] = { latitude = 26.936736, longitude = 56.259130, display_name = "Baharestan"},
    ["Hormoz"] = { latitude = 27.095503, longitude = 56.452739, display_name = "Hormoz"},
    ["Greater Tunb"] = { latitude = 26.263735, longitude = 55.304914, display_name = "Greater Tunb"},
    ["Humaydah"] = { latitude = 24.571042, longitude = 56.387500, display_name = "Humaydah"},
    ["Wab Mubarak"] = { latitude = 26.200000, longitude = 56.220000, display_name = "Wab Mubarak"},
    ["Tawj"] = { latitude = 26.179087, longitude = 56.219030, display_name = "Tawj"},
    ["Farfarah"] = { latitude = 24.720000, longitude = 56.460000, display_name = "Farfarah"},
    ["Humayrah"] = { latitude = 24.690031, longitude = 56.469996, display_name = "Humayrah"},
    ["Siri Island"] = { latitude = 25.911203, longitude = 54.529233, display_name = "Siri Island"},
    ["Rekab al Shib"] = { latitude = 26.130000, longitude = 56.200000, display_name = "Rekab al Shib"},
    ["Harf Ghabi"] = { latitude = 26.230105, longitude = 56.210382, display_name = "Harf Ghabi"},
    ["Qarat az Zingi"] = { latitude = 26.138520, longitude = 56.216353, display_name = "Qarat az Zingi"},
    ["Chahchekor"] = { latitude = 27.278383, longitude = 56.346864, display_name = "Chahchekor"},
    ["Baghoo"] = { latitude = 27.311286, longitude = 56.441230, display_name = "Baghoo"},
    ["Falara"] = { latitude = 24.749915, longitude = 56.470030, display_name = "Falara"},
    ["Al Shinas"] = { latitude = 24.740188, longitude = 56.467926, display_name = "Al Shinas"},
    ["Al Hamiliyah"] = { latitude = 24.729932, longitude = 56.459993, display_name = "Al Hamiliyah"},
    ["Al Umani"] = { latitude = 24.759906, longitude = 56.459930, display_name = "Al Umani"},
    ["Al Ima"] = { latitude = 25.942633, longitude = 56.422684, display_name = "Al Ima"},
    ["Salhad"] = { latitude = 25.860000, longitude = 56.220000, display_name = "Salhad"},
    ["Masafi"] = { latitude = 25.300995, longitude = 56.161498, display_name = "Masafi"},
    ["Al Maksuriyah"] = { latitude = 25.938574, longitude = 56.421403, display_name = "Al Maksuriyah"},
    ["Al Quoz"] = { latitude = 25.169070, longitude = 55.253398, display_name = "Al Quoz"},
    ["Dib Dibba"] = { latitude = 26.200000, longitude = 56.260000, display_name = "Dib Dibba"},
    ["As Sudiyah"] = { latitude = 24.553249, longitude = 56.152529, display_name = "As Sudiyah"},
    ["Jask"] = { latitude = 25.643616, longitude = 57.774564, display_name = "Jask"},
    ["Dibba Al-Hisn"] = { latitude = 25.614408, longitude = 56.267410, display_name = "Dibba Al-Hisn"},
    ["Waab al Lif"] = { latitude = 26.100000, longitude = 56.150000, display_name = "Waab al Lif"},
    ["Ghubrat ar Ras"] = { latitude = 26.160000, longitude = 56.250000, display_name = "Ghubrat ar Ras"},
    ["Lahbab"] = { latitude = 25.041542, longitude = 55.592377, display_name = "Lahbab"},
    ["Nazwa"] = { latitude = 25.005300, longitude = 55.661728, display_name = "Nazwa"},
    ["Al Awir"] = { latitude = 25.170430, longitude = 55.546354, display_name = "Al Awir"},
    ["Murqquab"] = { latitude = 24.820809, longitude = 55.586540, display_name = "Murqquab"},
    ["Sima"] = { latitude = 26.059458, longitude = 56.310949, display_name = "Sima"},
    ["Margham"] = { latitude = 24.899518, longitude = 55.625454, display_name = "Margham"},
    ["Salakh"] = { latitude = 26.691055, longitude = 55.708540, display_name = "Salakh"},
    ["Ghamtha"] = { latitude = 26.110000, longitude = 56.130000, display_name = "Ghamtha"},
    ["Al Usayli"] = { latitude = 25.626760, longitude = 56.008144, display_name = "Al Usayli"},
    ["Wad Wid"] = { latitude = 25.625149, longitude = 56.013964, display_name = "Wad Wid"},
    ["Al Hillah"] = { latitude = 26.101415, longitude = 56.139522, display_name = "Al Hillah"},
    ["Fawhfallam"] = { latitude = 26.109031, longitude = 56.150113, display_name = "Fawhfallam"},
    ["Al Khan"] = { latitude = 24.225589, longitude = 56.326442, display_name = "Al Khan"},
    ["Shahr-e ghadim"] = { latitude = 27.680462, longitude = 54.339229, display_name = "Shahr-e ghadim"},
    ["Shahr-e jadid"] = { latitude = 27.649446, longitude = 54.318973, display_name = "Shahr-e jadid"},
    ["Gharbiyah"] = { latitude = 25.610141, longitude = 56.250002, display_name = "Gharbiyah"},
    ["Kavarzin"] = { latitude = 26.796507, longitude = 55.831578, display_name = "Kavarzin"},
    ["Khonj"] = { latitude = 27.889926, longitude = 53.436782, display_name = "Khonj"},
    ["Bayah"] = { latitude = 25.670000, longitude = 56.260000, display_name = "Bayah"},
    ["Al Shuwara"] = { latitude = 26.150000, longitude = 56.290000, display_name = "Al Shuwara"},
    ["Diba al Bayah"] = { latitude = 25.640977, longitude = 56.267373, display_name = "Diba al Bayah"},
    ["Al Karsha"] = { latitude = 25.656732, longitude = 56.267520, display_name = "Al Karsha"},
    ["Al Hubayl"] = { latitude = 26.100000, longitude = 56.240000, display_name = "Al Hubayl"},
    ["Bur Dubai"] = { latitude = 25.262134, longitude = 55.297289, display_name = "Bur Dubai"},
    ["Port Saeed"] = { latitude = 25.245766, longitude = 55.333673, display_name = "Port Saeed"},
    ["Gerash"] = { latitude = 27.670884, longitude = 54.139243, display_name = "Gerash"},
    ["Al Raffa"] = { latitude = 25.255162, longitude = 55.288470, display_name = "Al Raffa"},
    ["Al Mankhool"] = { latitude = 25.250062, longitude = 55.294734, display_name = "Al Mankhool"},
    ["Deh-e Now"] = { latitude = 27.347680, longitude = 56.544424, display_name = "Deh-e Now"},
    ["Umm Al Quwain"] = { latitude = 25.552043, longitude = 55.547498, display_name = "Umm Al Quwain"},
    ["Majaz al Kubra"] = { latitude = 24.240000, longitude = 56.840000, display_name = "Majaz al Kubra"},
    ["Simah"] = { latitude = 26.061530, longitude = 56.309655, display_name = "Simah"},
    ["Al Garhoud"] = { latitude = 25.241767, longitude = 55.350073, display_name = "Al Garhoud"},
    ["Umm Ramool"] = { latitude = 25.232361, longitude = 55.366826, display_name = "Umm Ramool"},
    ["Bandar Abbas"] = { latitude = 27.178121, longitude = 56.276645, display_name = "Bandar Abbas"},
    ["Dayrestan"] = { latitude = 26.745164, longitude = 55.934918, display_name = "Dayrestan"},
    ["Al Madam"] = { latitude = 24.976101, longitude = 55.789605, display_name = "Al Madam"},
    ["Abu Musa"] = { latitude = 25.885745, longitude = 55.037629, display_name = "Abu Musa"},
    ["Ajman"] = { latitude = 25.393656, longitude = 55.445143, display_name = "Ajman"},
    ["Dehbarez"] = { latitude = 27.447061, longitude = 57.190751, display_name = "Dehbarez"},
    ["Al Fiduk"] = { latitude = 26.030000, longitude = 56.360000, display_name = "Al Fiduk"},
    ["Tomban"] = { latitude = 26.769382, longitude = 55.864493, display_name = "Tomban"},
    ["Dargahan"] = { latitude = 26.967400, longitude = 56.078113, display_name = "Dargahan"},
    ["Al Wasl"] = { latitude = 25.197181, longitude = 55.254978, display_name = "Al Wasl"},
    ["Ziaratali"] = { latitude = 27.739415, longitude = 57.219915, display_name = "Ziaratali"},
    ["Muslaf"] = { latitude = 24.700000, longitude = 56.290000, display_name = "Muslaf"},
    ["Subakh"] = { latitude = 24.720000, longitude = 56.180000, display_name = "Subakh"},
    ["Sur Khusaybi"] = { latitude = 24.660000, longitude = 56.510000, display_name = "Sur Khusaybi"},
    ["Birkat Khaldiyah"] = { latitude = 26.040000, longitude = 56.360000, display_name = "Birkat Khaldiyah"},
    ["Turayf"] = { latitude = 24.670000, longitude = 56.480000, display_name = "Turayf"},
    ["Salib"] = { latitude = 26.369819, longitude = 56.359555, display_name = "Salib"},
    ["Al Darai"] = { latitude = 26.150000, longitude = 56.260000, display_name = "Al Darai"},
    ["Sharjah"] = { latitude = 25.350866, longitude = 55.384186, display_name = "Sharjah"},
    ["Rayy"] = { latitude = 24.650000, longitude = 56.110000, display_name = "Rayy"},
    ["Fin"] = { latitude = 27.627471, longitude = 55.902724, display_name = "Fin"},
    ["Al Jari"] = { latitude = 26.216764, longitude = 56.185602, display_name = "Al Jari"},
    ["Sarriq-e Meyguni"] = { latitude = 27.300313, longitude = 56.276998, display_name = "Sarriq-e Meyguni"},
    ["Sawt"] = { latitude = 25.660000, longitude = 56.260000, display_name = "Sawt"},
    ["Jenah"] = { latitude = 27.017683, longitude = 54.282941, display_name = "Jenah"},
    ["Hashtbandi"] = { latitude = 26.813131, longitude = 57.832783, display_name = "Hashtbandi"},
    ["Fiqa"] = { latitude = 24.716533, longitude = 55.621624, display_name = "Fiqa"},
    ["Arabian Ranches"] = { latitude = 25.051751, longitude = 55.265756, display_name = "Arabian Ranches"},
    ["Mukhaylif"] = { latitude = 24.520000, longitude = 56.570000, display_name = "Mukhaylif"},
    ["Umm Suqeim 3"] = { latitude = 25.138722, longitude = 55.195982, display_name = "Umm Suqeim 3"},
    ["Al Manara"] = { latitude = 25.145203, longitude = 55.214933, display_name = "Al Manara"},
    ["Umm Suqueim 1"] = { latitude = 25.165045, longitude = 55.217017, display_name = "Umm Suqueim 1"},
    ["Harat ash Shaykh"] = { latitude = 24.500000, longitude = 56.580000, display_name = "Harat ash Shaykh"},
    ["Al Jowar"] = { latitude = 26.070000, longitude = 56.220000, display_name = "Al Jowar"},
    ["Bandar-e Lengeh"] = { latitude = 26.557134, longitude = 54.881714, display_name = "Bandar-e Lengeh"},
    ["Suza"] = { latitude = 26.777574, longitude = 56.063126, display_name = "Suza"},
    ["Al Mabrak"] = { latitude = 26.150000, longitude = 56.310000, display_name = "Al Mabrak"},
    ["Seerik"] = { latitude = 26.518435, longitude = 57.104636, display_name = "Seerik"},
    ["Bandar Khamir"] = { latitude = 26.951638, longitude = 55.587708, display_name = "Bandar Khamir"},
    ["Khasab"] = { latitude = 26.180182, longitude = 56.249618, display_name = "Khasab"},
    ["Al Marqadh"] = { latitude = 25.169438, longitude = 55.289759, display_name = "Al Marqadh"},
    ["Fujairah"] = { latitude = 25.125387, longitude = 56.343680, display_name = "Fujairah"},
    ["Al Masharta"] = { latitude = 26.150000, longitude = 56.280000, display_name = "Al Masharta"},
    ["Senderk"] = { latitude = 26.593623, longitude = 57.863963, display_name = "Senderk"},
    ["Bikah"] = { latitude = 27.354812, longitude = 57.180416, display_name = "Bikah"},
    ["Al Jadi"] = { latitude = 26.160000, longitude = 56.170000, display_name = "Al Jadi"},
    ["Fareghan"] = { latitude = 28.007798, longitude = 56.255127, display_name = "Fareghan"},
    ["Bastak"] = { latitude = 27.105005, longitude = 54.455254, display_name = "Bastak"},
    ["Patil Posht-e Banu Band"] = { latitude = 27.298063, longitude = 56.180439, display_name = "Patil Posht-e Banu Band"},
    ["Mobarakabad"] = { latitude = 28.359589, longitude = 53.328186, display_name = "Mobarakabad"},
    ["Din ar Rukayb"] = { latitude = 26.050000, longitude = 56.300000, display_name = "Din ar Rukayb"},
    ["Evaz"] = { latitude = 27.762532, longitude = 54.005150, display_name = "Evaz"},
    ["Sabakh"] = { latitude = 24.527897, longitude = 56.468961, display_name = "Sabakh"},
    ["Sahil Harmul"] = { latitude = 24.530000, longitude = 56.600000, display_name = "Sahil Harmul"},
    ["Sistan"] = { latitude = 26.940766, longitude = 56.257473, display_name = "Sistan"},
    ["Bayt ash Shaykh"] = { latitude = 26.070000, longitude = 56.210000, display_name = "Bayt ash Shaykh"},
    ["Kabir"] = { latitude = 25.432204, longitude = 55.705133, display_name = "Kabir"},
    ["United Arab Emirates"] = { latitude = 24.871963, longitude = 55.255096, display_name = "United Arab Emirates"},
    ["Pa Tall-e Isin"] = { latitude = 27.301953, longitude = 56.239318, display_name = "Pa Tall-e Isin"},
    ["Abu Dhabi"] = { latitude = 24.474796, longitude = 54.370576, display_name = "Abu Dhabi"},
    ["Sihlat"] = { latitude = 24.336032, longitude = 56.498075, display_name = "Sihlat"},
    ["Shufra"] = { latitude = 26.180000, longitude = 56.260000, display_name = "Shufra"},
    ["Al Uwaynat"] = { latitude = 24.270000, longitude = 56.810000, display_name = "Al Uwaynat"},
    ["Ras al Salam"] = { latitude = 26.030000, longitude = 56.350000, display_name = "Ras al Salam"},
    ["New Madha"] = { latitude = 25.284452, longitude = 56.332977, display_name = "New Madha"},
    ["Suhaylah"] = { latitude = 24.270000, longitude = 56.370000, display_name = "Suhaylah"},
    ["Tabl"] = { latitude = 26.755208, longitude = 55.726098, display_name = "Tabl"},
    ["Haqil"] = { latitude = 25.445791, longitude = 56.358072, display_name = "Haqil"},
    ["`Aqqah"] = { latitude = 25.499746, longitude = 56.357323, display_name = "`Aqqah"},
    ["Rul Dadna"] = { latitude = 25.554184, longitude = 56.345325, display_name = "Rul Dadna"},
    ["Wab al Sebil"] = { latitude = 26.050000, longitude = 56.330000, display_name = "Wab al Sebil"},
    ["Latifi"] = { latitude = 27.690078, longitude = 54.387140, display_name = "Latifi"},
    ["Khur"] = { latitude = 27.645907, longitude = 54.345362, display_name = "Khur"},
    ["Fudgha"] = { latitude = 26.120061, longitude = 56.129647, display_name = "Fudgha"},
    ["Zaymi"] = { latitude = 24.450000, longitude = 56.280000, display_name = "Zaymi"},
    ["Tazeyan-e Zir"] = { latitude = 27.291694, longitude = 56.153102, display_name = "Tazeyan-e Zir"},
    ["Zabyat"] = { latitude = 24.350000, longitude = 56.370000, display_name = "Zabyat"},
    ["Hadhf"] = { latitude = 24.789995, longitude = 56.010010, display_name = "Hadhf"},
    ["Ar Rajmi"] = { latitude = 24.640000, longitude = 56.290000, display_name = "Ar Rajmi"},
    ["Hansi"] = { latitude = 24.221653, longitude = 56.349073, display_name = "Hansi"},
    ["Ghuzayyil"] = { latitude = 24.480000, longitude = 56.600000, display_name = "Ghuzayyil"},
    ["Al Khywayriyyah"] = { latitude = 24.450000, longitude = 56.630000, display_name = "Al Khywayriyyah"},
    ["Dubai"] = { latitude = 25.268352, longitude = 55.296196, display_name = "Dubai"},
    ["Bayda"] = { latitude = 24.364497, longitude = 56.408018, display_name = "Bayda"},
    ["Hadirah"] = { latitude = 24.380000, longitude = 56.740000, display_name = "Hadirah"},
    ["Bu Baqarah"] = { latitude = 24.879549, longitude = 56.408535, display_name = "Bu Baqarah"},
    ["As Sifah"] = { latitude = 24.830000, longitude = 56.430000, display_name = "As Sifah"},
    ["Aswad"] = { latitude = 24.870000, longitude = 56.330000, display_name = "Aswad"},
    ["Ash Sharjah"] = { latitude = 24.530000, longitude = 56.280000, display_name = "Ash Sharjah"},
    ["Ghassah"] = { latitude = 26.240422, longitude = 56.318323, display_name = "Ghassah"},
    ["Bat"] = { latitude = 24.520000, longitude = 56.280000, display_name = "Bat"},
    ["Sal al Ala"] = { latitude = 26.050206, longitude = 56.374287, display_name = "Sal al Ala"},
    ["Towla"] = { latitude = 26.972305, longitude = 56.223269, display_name = "Towla"},
    ["Kaboli"] = { latitude = 26.951816, longitude = 56.209809, display_name = "Kaboli"},
    ["Hamiri"] = { latitude = 26.944973, longitude = 56.202666, display_name = "Hamiri"},
    ["Guran"] = { latitude = 26.725618, longitude = 55.617993, display_name = "Guran"},
    ["Chahu Sharghi"] = { latitude = 26.691591, longitude = 55.508721, display_name = "Chahu Sharghi"},
    ["Chahu Gharbi"] = { latitude = 26.683830, longitude = 55.482802, display_name = "Chahu Gharbi"},
    ["Bandar-e-Doulab"] = { latitude = 26.676472, longitude = 55.460577, display_name = "Bandar-e-Doulab"},
    ["Konar Siah"] = { latitude = 26.661945, longitude = 55.433527, display_name = "Konar Siah"},
    ["Gori"] = { latitude = 26.632805, longitude = 55.365481, display_name = "Gori"},
    ["Moradi"] = { latitude = 26.636508, longitude = 55.345794, display_name = "Moradi"},
    ["Basa'idu"] = { latitude = 26.640952, longitude = 55.283018, display_name = "Basa'idu"},
    ["Ash Shishah"] = { latitude = 26.260724, longitude = 56.393230, display_name = "Ash Shishah"},
    ["Ras Salti Ali"] = { latitude = 26.213012, longitude = 56.233535, display_name = "Ras Salti Ali"},
    ["Al Haqt"] = { latitude = 26.123078, longitude = 56.250251, display_name = "Al Haqt"},
    ["Luwayb"] = { latitude = 25.770222, longitude = 56.226061, display_name = "Luwayb"},
    ["Ras al Khaimah"] = { latitude = 25.761937, longitude = 55.935012, display_name = "Ras al Khaimah"},
    ["Dibba al Fujairah"] = { latitude = 25.588498, longitude = 56.264200, display_name = "Dibba al Fujairah"},
    ["Sharm"] = { latitude = 25.469538, longitude = 56.353863, display_name = "Sharm"},
    ["Al Hawayah"] = { latitude = 25.372171, longitude = 56.345103, display_name = "Al Hawayah"},
    ["Al Hutain"] = { latitude = 25.361035, longitude = 56.344583, display_name = "Al Hutain"},
    ["Al Qadisa"] = { latitude = 25.337383, longitude = 56.346792, display_name = "Al Qadisa"},
    ["Al Hayl"] = { latitude = 25.091823, longitude = 56.246812, display_name = "Al Hayl"},
    ["Khalba"] = { latitude = 25.051499, longitude = 56.352167, display_name = "Khalba"},
    ["Bani Jabir"] = { latitude = 24.776926, longitude = 56.449487, display_name = "Bani Jabir"},
    ["Liwa"] = { latitude = 24.518034, longitude = 56.561109, display_name = "Liwa"},
    ["At Tarayf"] = { latitude = 24.388600, longitude = 56.708776, display_name = "At Tarayf"},
    ["Bahjat al Anzar"] = { latitude = 24.320845, longitude = 56.760297, display_name = "Bahjat al Anzar"},
    ["Yal Burayk"] = { latitude = 24.012293, longitude = 57.035907, display_name = "Yal Burayk"},
    ["Muzeira"] = { latitude = 24.839201, longitude = 56.035361, display_name = "Muzeira"},
    ["Hatta"] = { latitude = 24.809872, longitude = 56.114054, display_name = "Hatta"},
    ["Al Hayer"] = { latitude = 24.584657, longitude = 55.762584, display_name = "Al Hayer"},
    ["Nahel"] = { latitude = 24.533336, longitude = 55.559137, display_name = "Nahel"},
    ["Sweihan"] = { latitude = 24.488015, longitude = 55.343260, display_name = "Sweihan"},
    ["Al Uthrat"] = { latitude = 24.353779, longitude = 56.050471, display_name = "Al Uthrat"},
    ["Al Khubayn"] = { latitude = 24.323580, longitude = 56.100938, display_name = "Al Khubayn"},
    ["Al Ashqar"] = { latitude = 24.309377, longitude = 56.132881, display_name = "Al Ashqar"},
    ["Al Khrair"] = { latitude = 24.150677, longitude = 55.825251, display_name = "Al Khrair"},
    ["Al Salamat"] = { latitude = 24.214094, longitude = 55.591883, display_name = "Al Salamat"},
    ["Al Yahar North"] = { latitude = 24.241616, longitude = 55.557785, display_name = "Al Yahar North"},
    ["Al Yahar South"] = { latitude = 24.202040, longitude = 55.534305, display_name = "Al Yahar South"},
    ["Al Khazna"] = { latitude = 24.172745, longitude = 55.118734, display_name = "Al Khazna"},
    ["Al Khatim"] = { latitude = 24.212594, longitude = 55.004704, display_name = "Al Khatim"},
    ["Al Mafreq Industrial Area"] = { latitude = 24.272547, longitude = 54.591075, display_name = "Al Mafreq Industrial Area"},
    ["Kang"] = { latitude = 26.596327, longitude = 54.936964, display_name = "Kang"},
    ["Al Ain"] = { latitude = 24.222700, longitude = 55.692779, display_name = "Al Ain"},
    ["Al Buraimi"] = { latitude = 24.261588, longitude = 55.792935, display_name = "Al Buraimi"},
    ["Bandar Shenas"] = { latitude = 26.517778, longitude = 54.784529, display_name = "Bandar Shenas"},
    ["Ghazi Castle"] = { latitude = 27.455000, longitude = 56.564467, display_name = "Ghazi Castle"},
    ["Berentin"] = { latitude = 27.293682, longitude = 57.252660, display_name = "Berentin"},
    ["Minab"] = { latitude = 27.138592, longitude = 57.072786, display_name = "Minab"},
    ["The World Islands"] = { latitude = 25.224572, longitude = 55.164474, display_name = "The World Islands"},
    ["Palm Jumeirah"] = { latitude = 25.120103, longitude = 55.129655, display_name = "Palm Jumeirah"},
    [" Palm Jebel Ali"] = { latitude = 25.009022, longitude = 54.987897, display_name = " Palm Jebel Ali"},
    ["Jebel Ali Port"] = { latitude = 24.974838, longitude = 55.070788, display_name = "Jebel Ali Port"},
    ["Dubai Investments Park"] = { latitude = 24.981667, longitude = 55.179209, display_name = "Dubai Investments Park"},
    ["Sir Abu Ny'air"] = { latitude = 25.226516, longitude = 54.217534, display_name = "Sir Abu Ny'air"},
    ["Ghantoot"] = { latitude = 24.848710, longitude = 54.831340, display_name = "Ghantoot"},
    ["EMAL Industrial City"] = { latitude = 24.791622, longitude = 54.721420, display_name = "EMAL Industrial City"},
    ["Kizad"] = { latitude = 24.707434, longitude = 54.811143, display_name = "Kizad"},
    ["Al Samkha"] = { latitude = 24.690096, longitude = 54.758042, display_name = "Al Samkha"},
    ["Al Sharia"] = { latitude = 24.628021, longitude = 54.781774, display_name = "Al Sharia"},
    ["Al Rahba"] = { latitude = 24.622200, longitude = 54.705903, display_name = "Al Rahba"},
    ["Al Bahia"] = { latitude = 24.572522, longitude = 54.650999, display_name = "Al Bahia"},
    ["Rawdat al Reef"] = { latitude = 24.508450, longitude = 54.718527, display_name = "Rawdat al Reef"},
    ["Yas Island"] = { latitude = 24.490761, longitude = 54.612231, display_name = "Yas Island"},
    ["Al Reef"] = { latitude = 24.454224, longitude = 54.670993, display_name = "Al Reef"},
    ["Al Falah New Community"] = { latitude = 24.442883, longitude = 54.726928, display_name = "Al Falah New Community"},
    ["Al Shamkha"] = { latitude = 24.381746, longitude = 54.709066, display_name = "Al Shamkha"},
    ["Masdar City"] = { latitude = 24.427375, longitude = 54.625464, display_name = "Masdar City"},
    ["Khalifa City"] = { latitude = 24.419081, longitude = 54.576085, display_name = "Khalifa City"},
    ["Shakhbout City"] = { latitude = 24.364088, longitude = 54.632717, display_name = "Shakhbout City"},
    ["Al Shawamekh"] = { latitude = 24.346064, longitude = 54.665524, display_name = "Al Shawamekh"},
    ["Baniyas City"] = { latitude = 24.302115, longitude = 54.636742, display_name = "Baniyas City"},
    ["Mohammed bin Zayed City"] = { latitude = 24.334233, longitude = 54.552368, display_name = "Mohammed bin Zayed City"},
    ["Musaffah Industrial Area"] = { latitude = 24.348649, longitude = 54.491514, display_name = "Musaffah Industrial Area"},
    ["Abu Dhabi Industrial Area"] = { latitude = 24.286298, longitude = 54.466256, display_name = "Abu Dhabi Industrial Area"},
    ["Al Muqatra"] = { latitude = 24.215471, longitude = 54.462245, display_name = "Al Muqatra"},
    ["Al Wathba"] = { latitude = 24.201053, longitude = 54.722964, display_name = "Al Wathba"},
    ["Zayed Military City"] = { latitude = 24.503534, longitude = 54.872741, display_name = "Zayed Military City"},
    ["Al Maqta"] = { latitude = 24.406182, longitude = 54.502626, display_name = "Al Maqta"},
    ["Umm al Nar"] = { latitude = 24.434628, longitude = 54.500575, display_name = "Umm al Nar"},
    ["Al Sa'adah"] = { latitude = 24.437465, longitude = 54.425519, display_name = "Al Sa'adah"},
    ["Al Rawdah"] = { latitude = 24.421667, longitude = 54.437131, display_name = "Al Rawdah"},
    ["Al Muzoun"] = { latitude = 24.411611, longitude = 54.430731, display_name = "Al Muzoun"},
    ["Al Mushrif"] = { latitude = 24.432836, longitude = 54.394401, display_name = "Al Mushrif"},
    ["Al Qurm"] = { latitude = 24.422772, longitude = 54.393330, display_name = "Al Qurm"},
    ["Al Bateen"] = { latitude = 24.446453, longitude = 54.352998, display_name = "Al Bateen"},
    ["Al Kasir"] = { latitude = 24.474630, longitude = 54.320160, display_name = "Al Kasir"},
    ["Al Mina"] = { latitude = 24.519893, longitude = 54.370686, display_name = "Al Mina"},
    ["Saadiyat Beach"] = { latitude = 24.543537, longitude = 54.435444, display_name = "Saadiyat Beach"},
    ["Oman"] = { latitude = 26.128194, longitude = 56.245636, display_name = "Oman"},
    ["Iran"] = { latitude = 27.697861, longitude = 55.847496, display_name = "Iran"},
    ["Sir Abu Ny'air Island"] = { latitude = 25.234987, longitude = 54.215139, display_name = "Sir Abu Ny'air Island"},
    ["Qeshm Island"] = { latitude = 26.818904, longitude = 55.901246, display_name = "Qeshm Island"},
    ["Naif"] = { latitude = 25.272292, longitude = 55.311253, display_name = "Naif"},
    ["Oud Metha"] = { latitude = 25.240796, longitude = 55.309122, display_name = "Oud Metha"},
    ["Al Hudaiba"] = { latitude = 25.239402, longitude = 55.274196, display_name = "Al Hudaiba"},
    ["Al Rigga"] = { latitude = 25.259060, longitude = 55.320567, display_name = "Al Rigga"},
    ["Downtown Burj Khalifa"] = { latitude = 25.193372, longitude = 55.276023, display_name = "Downtown Burj Khalifa"},
    ["Al Majaz"] = { latitude = 25.330634, longitude = 55.384092, display_name = "Al Majaz"},
    ["Abu Hail"] = { latitude = 25.285615, longitude = 55.329179, display_name = "Abu Hail"},
    ["Jumeirah"] = { latitude = 25.218588, longitude = 55.254966, display_name = "Jumeirah"},
    ["Al Barsha"] = { latitude = 25.095399, longitude = 55.206466, display_name = "Al Barsha"},
    ["Emirates Hills"] = { latitude = 25.068473, longitude = 55.171652, display_name = "Emirates Hills"},
    ["Merdonu"] = { latitude = 27.322500, longitude = 54.474428, display_name = "Merdonu"},
    ["Gowdegaz"] = { latitude = 27.300118, longitude = 54.496949, display_name = "Gowdegaz"},
    ["Todruyeh"] = { latitude = 27.304580, longitude = 54.708803, display_name = "Todruyeh"},
    ["Dehong"] = { latitude = 27.310218, longitude = 54.655915, display_name = "Dehong"},
    ["Chah Benard"] = { latitude = 27.247221, longitude = 54.624649, display_name = "Chah Benard"},
    ["Kookherd"] = { latitude = 27.088970, longitude = 54.493979, display_name = "Kookherd"},
    ["Eelood"] = { latitude = 27.217003, longitude = 54.673731, display_name = "Eelood"},
    ["Berkeh Lary"] = { latitude = 27.211954, longitude = 54.716274, display_name = "Berkeh Lary"},
    ["Chah Dezdan"] = { latitude = 27.209354, longitude = 54.745048, display_name = "Chah Dezdan"},
    ["Dehtal"] = { latitude = 27.210763, longitude = 54.785315, display_name = "Dehtal"},
    ["Dashte Jayhun"] = { latitude = 27.276316, longitude = 55.079159, display_name = "Dashte Jayhun"},
    ["Tang-e Dalan"] = { latitude = 27.333724, longitude = 55.093729, display_name = "Tang-e Dalan"},
    ["Khoerde"] = { latitude = 27.781969, longitude = 54.420895, display_name = "Khoerde"},
    ["Kanakh"] = { latitude = 26.899358, longitude = 55.389228, display_name = "Kanakh"},
    ["Gavmiri"] = { latitude = 26.890173, longitude = 55.316569, display_name = "Gavmiri"},
    ["Sayeh Khvosh"] = { latitude = 26.830745, longitude = 55.373321, display_name = "Sayeh Khvosh"},
    ["Bandar e Pol"] = { latitude = 27.008738, longitude = 55.739849, display_name = "Bandar e Pol"},
    ["Demilu"] = { latitude = 27.182336, longitude = 55.832653, display_name = "Demilu"},
    ["Keshar e Bala"] = { latitude = 27.267073, longitude = 55.955476, display_name = "Keshar e Bala"},
    ["Sargap"] = { latitude = 27.247097, longitude = 55.931328, display_name = "Sargap"},
    ["Chamerdan"] = { latitude = 27.247713, longitude = 55.977965, display_name = "Chamerdan"},
    ["Ghalat e Bala"] = { latitude = 27.319302, longitude = 56.099257, display_name = "Ghalat e Bala"},
    ["Konaru"] = { latitude = 27.310582, longitude = 56.135679, display_name = "Konaru"},
    ["Keshar e Paeen"] = { latitude = 27.230860, longitude = 55.906989, display_name = "Keshar e Paeen"},
    ["Mogh Ahmad Paeen"] = { latitude = 27.155902, longitude = 55.882218, display_name = "Mogh Ahmad Paeen"},
    ["Gachin Bala"] = { latitude = 27.125532, longitude = 55.872022, display_name = "Gachin Bala"},
    ["Gachin Paeen"] = { latitude = 27.090410, longitude = 55.891007, display_name = "Gachin Paeen"},
    ["Chahu"] = { latitude = 27.242365, longitude = 56.066446, display_name = "Chahu"},
    ["Bostanu"] = { latitude = 27.080847, longitude = 55.996042, display_name = "Bostanu"},
    ["Rajaei Port"] = { latitude = 27.102766, longitude = 56.060752, display_name = "Rajaei Port"},
    ["Paiposht"] = { latitude = 26.879825, longitude = 55.928558, display_name = "Paiposht"},
    ["Kuvei"] = { latitude = 26.946337, longitude = 56.005579, display_name = "Kuvei"},
    ["Giahdan"] = { latitude = 26.923002, longitude = 56.069731, display_name = "Giahdan"},
    ["Tourian"] = { latitude = 26.880562, longitude = 56.030528, display_name = "Tourian"},
    ["Kousha"] = { latitude = 26.857848, longitude = 56.017255, display_name = "Kousha"},
    ["Sarkhun"] = { latitude = 27.402982, longitude = 56.412849, display_name = "Sarkhun"},
    ["Sarhez"] = { latitude = 27.580306, longitude = 56.098990, display_name = "Sarhez"},
    ["Tola Industrial City"] = { latitude = 26.968887, longitude = 56.179724, display_name = "Tola Industrial City"},
    ["Hajji Khademi"] = { latitude = 27.230324, longitude = 57.043880, display_name = "Hajji Khademi"},
    ["Tirour"] = { latitude = 27.324834, longitude = 56.965962, display_name = "Tirour"},
    ["Kormon"] = { latitude = 27.432573, longitude = 56.874832, display_name = "Kormon"},
    ["Takht"] = { latitude = 27.493904, longitude = 56.656532, display_name = "Takht"},
    ["Chahestan"] = { latitude = 27.519748, longitude = 56.752911, display_name = "Chahestan"},
    ["Ramkan"] = { latitude = 26.867639, longitude = 56.043939, display_name = "Ramkan"},
    ["Zirang"] = { latitude = 26.854199, longitude = 56.061282, display_name = "Zirang"},
    ["Kerman"] = { latitude = 30.323533, longitude = 57.023611, display_name = "Kerman"},
    ["Shiraz"] = { latitude = 29.559969, longitude = 52.618058, display_name = "Shiraz"},
    ["Fasa"] = { latitude = 28.936639, longitude = 53.651068, display_name = "Fasa"},
    ["Darab"] = { latitude = 28.753194, longitude = 54.548149, display_name = "Darab"},
    ["Choghadak"] = { latitude = 28.985545, longitude = 51.032761, display_name = "Choghadak"},
    ["Borazjan"] = { latitude = 29.266143, longitude = 51.212060, display_name = "Borazjan"},
    ["Dalaki"] = { latitude = 29.430861, longitude = 51.295021, display_name = "Dalaki"},
    ["Firuzabad"] = { latitude = 28.845604, longitude = 52.572724, display_name = "Firuzabad"},
    ["Masiri"] = { latitude = 30.244395, longitude = 51.524174, display_name = "Masiri"},
    ["Nurabad Mamasani"] = { latitude = 30.115407, longitude = 51.522963, display_name = "Nurabad Mamasani"},
    ["Qaemiyeh"] = { latitude = 29.851002, longitude = 51.581912, display_name = "Qaemiyeh"},
    ["Konartakhteh"] = { latitude = 29.532781, longitude = 51.396080, display_name = "Konartakhteh"},
    ["Saadat Shahr"] = { latitude = 30.079995, longitude = 53.136456, display_name = "Saadat Shahr"},
    ["Arsanjan"] = { latitude = 29.914968, longitude = 53.308976, display_name = "Arsanjan"},
    ["Farashband"] = { latitude = 28.855378, longitude = 52.094644, display_name = "Farashband"},
    ["Najafshahr"] = { latitude = 29.389703, longitude = 55.720301, display_name = "Najafshahr"},
    ["Ab Pakhsh"] = { latitude = 29.360784, longitude = 51.071375, display_name = "Ab Pakhsh"},
    ["Shabankareh"] = { latitude = 29.469683, longitude = 50.990973, display_name = "Shabankareh"},
    ["Saadabad"] = { latitude = 29.384835, longitude = 51.116629, display_name = "Saadabad"},
    ["Delvar"] = { latitude = 28.762873, longitude = 51.071923, display_name = "Delvar"},
    ["Vahdatiyeh"] = { latitude = 29.482557, longitude = 51.243308, display_name = "Vahdatiyeh"},
    ["Ahram"] = { latitude = 28.883028, longitude = 51.274202, display_name = "Ahram"},
    ["Qir"] = { latitude = 28.482802, longitude = 53.035756, display_name = "Qir"},
    ["Qotbabad"] = { latitude = 28.639302, longitude = 53.637805, display_name = "Qotbabad"},
    ["Zahedshahr"] = { latitude = 28.748435, longitude = 53.804106, display_name = "Zahedshahr"},
    ["Miandeh"] = { latitude = 28.716296, longitude = 53.855430, display_name = "Miandeh"},
    ["Now Bandegan"] = { latitude = 28.854560, longitude = 53.825902, display_name = "Now Bandegan"},
    ["Sheshdeh"] = { latitude = 28.948635, longitude = 53.995505, display_name = "Sheshdeh"},
    ["Emamshahr"] = { latitude = 28.446670, longitude = 53.152544, display_name = "Emamshahr"},
    ["Aliabad"] = { latitude = 28.789843, longitude = 51.055410, display_name = "Aliabad"},
    ["Jaeinak"] = { latitude = 28.786242, longitude = 51.069132, display_name = "Jaeinak"},
    ["Marvdasht"] = { latitude = 29.876291, longitude = 52.806290, display_name = "Marvdasht"},
    ["Jahrom"] = { latitude = 28.496176, longitude = 53.559337, display_name = "Jahrom"},
    ["Ij"] = { latitude = 29.020374, longitude = 54.247745, display_name = "Ij"},
    ["Aviz"] = { latitude = 28.916223, longitude = 52.057212, display_name = "Aviz"},
    ["Nudan"] = { latitude = 29.801949, longitude = 51.693599, display_name = "Nudan"},
    ["Khesht"] = { latitude = 29.567944, longitude = 51.339531, display_name = "Khesht"},
    }

TheChannelTowns = {
    ["Canterbury"] = { latitude = 51.280028, longitude = 1.080253, display_name = "Canterbury"},
    ["Rochester"] = { latitude = 51.389062, longitude = 0.504935, display_name = "Rochester"},
    ["Battle"] = { latitude = 50.917771, longitude = 0.483654, display_name = "Battle"},
    ["Rye"] = { latitude = 50.951187, longitude = 0.732767, display_name = "Rye"},
    ["Minnis Bay"] = { latitude = 51.380177, longitude = 1.285780, display_name = "Minnis Bay"},
    ["Margate"] = { latitude = 51.389433, longitude = 1.382151, display_name = "Margate"},
    ["Deal"] = { latitude = 51.223924, longitude = 1.402865, display_name = "Deal"},
    ["Ramsgate"] = { latitude = 51.333473, longitude = 1.419648, display_name = "Ramsgate"},
    ["Chatham"] = { latitude = 51.380484, longitude = 0.529276, display_name = "Chatham"},
    ["Gillingham"] = { latitude = 51.387656, longitude = 0.545771, display_name = "Gillingham"},
    ["Winchelsea"] = { latitude = 50.924390, longitude = 0.708636, display_name = "Winchelsea"},
    ["Winchelsea Beach"] = { latitude = 50.915916, longitude = 0.723579, display_name = "Winchelsea Beach"},
    ["Cliff End"] = { latitude = 50.888757, longitude = 0.683912, display_name = "Cliff End"},
    ["Pett Level"] = { latitude = 50.889759, longitude = 0.687214, display_name = "Pett Level"},
    ["Sheerness"] = { latitude = 51.439170, longitude = 0.758572, display_name = "Sheerness"},
    ["Whitstable"] = { latitude = 51.360629, longitude = 1.024063, display_name = "Whitstable"},
    ["Dover"] = { latitude = 51.125128, longitude = 1.313423, display_name = "Dover"},
    ["Elham"] = { latitude = 51.153771, longitude = 1.110679, display_name = "Elham"},
    ["Wingham"] = { latitude = 51.272594, longitude = 1.215429, display_name = "Wingham"},
    ["Eastry"] = { latitude = 51.247183, longitude = 1.307598, display_name = "Eastry"},
    ["Maidstone"] = { latitude = 51.274826, longitude = 0.523165, display_name = "Maidstone"},
    ["Loose"] = { latitude = 51.241150, longitude = 0.516822, display_name = "Loose"},
    ["Aylesford"] = { latitude = 51.303717, longitude = 0.482638, display_name = "Aylesford"},
    ["Headcorn"] = { latitude = 51.168427, longitude = 0.627622, display_name = "Headcorn"},
    ["Ashford"] = { latitude = 51.148555, longitude = 0.872257, display_name = "Ashford"},
    ["Wye"] = { latitude = 51.183248, longitude = 0.936922, display_name = "Wye"},
    ["Folkestone"] = { latitude = 51.079134, longitude = 1.179407, display_name = "Folkestone"},
    ["Burham"] = { latitude = 51.328820, longitude = 0.482294, display_name = "Burham"},
    ["Herne Bay"] = { latitude = 51.371951, longitude = 1.130695, display_name = "Herne Bay"},
    ["Hawkinge"] = { latitude = 51.118042, longitude = 1.166441, display_name = "Hawkinge"},
    ["Boughton Lees"] = { latitude = 51.188913, longitude = 0.892375, display_name = "Boughton Lees"},
    ["Challock"] = { latitude = 51.219886, longitude = 0.876510, display_name = "Challock"},
    ["Sevington"] = { latitude = 51.133271, longitude = 0.904052, display_name = "Sevington"},
    ["Borstal"] = { latitude = 51.374409, longitude = 0.485466, display_name = "Borstal"},
    ["Brede"] = { latitude = 50.935783, longitude = 0.596550, display_name = "Brede"},
    ["Chartham"] = { latitude = 51.254268, longitude = 1.020390, display_name = "Chartham"},
    ["Charing"] = { latitude = 51.211424, longitude = 0.794972, display_name = "Charing"},
    ["Harrietsham"] = { latitude = 51.243350, longitude = 0.671526, display_name = "Harrietsham"},
    ["Hinxhill"] = { latitude = 51.145818, longitude = 0.928268, display_name = "Hinxhill"},
    ["Smeeth"] = { latitude = 51.118147, longitude = 0.959869, display_name = "Smeeth"},
    ["Mersham"] = { latitude = 51.119423, longitude = 0.932362, display_name = "Mersham"},
    ["Hythe"] = { latitude = 51.069142, longitude = 1.084163, display_name = "Hythe"},
    ["Stowting"] = { latitude = 51.136687, longitude = 1.035279, display_name = "Stowting"},
    ["Lyminge"] = { latitude = 51.128744, longitude = 1.087791, display_name = "Lyminge"},
    ["Molash"] = { latitude = 51.230119, longitude = 0.898823, display_name = "Molash"},
    ["Godmersham"] = { latitude = 51.215166, longitude = 0.950298, display_name = "Godmersham"},
    ["Lydd"] = { latitude = 50.951567, longitude = 0.907511, display_name = "Lydd"},
    ["Pluckley"] = { latitude = 51.175264, longitude = 0.754645, display_name = "Pluckley"},
    ["Hamstreet"] = { latitude = 51.064901, longitude = 0.855344, display_name = "Hamstreet"},
    ["Woodchurch"] = { latitude = 51.076741, longitude = 0.775834, display_name = "Woodchurch"},
    ["Tenterden"] = { latitude = 51.070096, longitude = 0.688827, display_name = "Tenterden"},
    ["High Halden"] = { latitude = 51.103550, longitude = 0.711234, display_name = "High Halden"},
    ["Faversham"] = { latitude = 51.314409, longitude = 0.891189, display_name = "Faversham"},
    ["Shepherdswell"] = { latitude = 51.185588, longitude = 1.231137, display_name = "Shepherdswell"},
    ["West Malling"] = { latitude = 51.295403, longitude = 0.409461, display_name = "West Malling"},
    ["Little Chart"] = { latitude = 51.179579, longitude = 0.780473, display_name = "Little Chart"},
    ["Minster"] = { latitude = 51.333898, longitude = 1.316084, display_name = "Minster"},
    ["Acol"] = { latitude = 51.357756, longitude = 1.311721, display_name = "Acol"},
    ["Alkham"] = { latitude = 51.135740, longitude = 1.223693, display_name = "Alkham"},
    ["Adisham"] = { latitude = 51.239153, longitude = 1.188543, display_name = "Adisham"},
    ["Ditton"] = { latitude = 51.296383, longitude = 0.453567, display_name = "Ditton"},
    ["Biddenden"] = { latitude = 51.115357, longitude = 0.642861, display_name = "Biddenden"},
    ["Smarden"] = { latitude = 51.148932, longitude = 0.686724, display_name = "Smarden"},
    ["Preston"] = { latitude = 51.303539, longitude = 1.227388, display_name = "Preston"},
    ["Sandwich"] = { latitude = 51.275253, longitude = 1.340831, display_name = "Sandwich"},
    ["St. Margaret's at Cliffe"] = { latitude = 51.154196, longitude = 1.372227, display_name = "St. Margaret's at Cliffe"},
    ["Whitfield"] = { latitude = 51.159496, longitude = 1.288821, display_name = "Whitfield"},
    ["Detling"] = { latitude = 51.294758, longitude = 0.569084, display_name = "Detling"},
    ["Ash"] = { latitude = 51.280986, longitude = 1.280306, display_name = "Ash"},
    ["New Romney"] = { latitude = 50.985120, longitude = 0.942657, display_name = "New Romney"},
    ["Dymchurch"] = { latitude = 51.026329, longitude = 0.993650, display_name = "Dymchurch"},
    ["Dungeness"] = { latitude = 50.914178, longitude = 0.972894, display_name = "Dungeness"},
    ["Blean"] = { latitude = 51.309226, longitude = 1.041400, display_name = "Blean"},
    ["Bramling"] = { latitude = 51.266099, longitude = 1.191608, display_name = "Bramling"},
    ["Upstreet"] = { latitude = 51.323878, longitude = 1.195885, display_name = "Upstreet"},
    ["Cliffsend"] = { latitude = 51.328048, longitude = 1.365472, display_name = "Cliffsend"},
    ["Broadstairs"] = { latitude = 51.358676, longitude = 1.440785, display_name = "Broadstairs"},
    ["Wickhambreaux"] = { latitude = 51.285060, longitude = 1.183971, display_name = "Wickhambreaux"},
    ["Pegwell"] = { latitude = 51.327407, longitude = 1.392171, display_name = "Pegwell"},
    ["Chilton"] = { latitude = 51.330792, longitude = 1.391433, display_name = "Chilton"},
    ["Manston"] = { latitude = 51.345980, longitude = 1.369626, display_name = "Manston"},
    ["Westwood"] = { latitude = 51.361166, longitude = 1.394531, display_name = "Westwood"},
    ["Northiam"] = { latitude = 50.990862, longitude = 0.606276, display_name = "Northiam"},
    ["St Marys Bay"] = { latitude = 51.011714, longitude = 0.978640, display_name = "St Marys Bay"},
    ["Lympne"] = { latitude = 51.075782, longitude = 1.027252, display_name = "Lympne"},
    ["Brabourne Lees"] = { latitude = 51.125756, longitude = 0.972561, display_name = "Brabourne Lees"},
    ["Lymbridge Green"] = { latitude = 51.156119, longitude = 1.037883, display_name = "Lymbridge Green"},
    ["Dunkirk"] = { latitude = 51.292033, longitude = 0.977125, display_name = "Dunkirk"},
    ["Rough Common"] = { latitude = 51.291596, longitude = 1.047419, display_name = "Rough Common"},
    ["Seasalter"] = { latitude = 51.348220, longitude = 1.005063, display_name = "Seasalter"},
    ["Tankerton"] = { latitude = 51.364112, longitude = 1.043862, display_name = "Tankerton"},
    ["Swalecliffe"] = { latitude = 51.366045, longitude = 1.068187, display_name = "Swalecliffe"},
    ["Herne"] = { latitude = 51.350351, longitude = 1.133792, display_name = "Herne"},
    ["Westbere"] = { latitude = 51.308149, longitude = 1.144101, display_name = "Westbere"},
    ["Wouldham"] = { latitude = 51.351228, longitude = 0.460243, display_name = "Wouldham"},
    ["Stelling Minnis"] = { latitude = 51.179301, longitude = 1.068386, display_name = "Stelling Minnis"},
    ["Saltwood"] = { latitude = 51.080165, longitude = 1.081790, display_name = "Saltwood"},
    ["Sandgate"] = { latitude = 51.074379, longitude = 1.148713, display_name = "Sandgate"},
    ["Hersden"] = { latitude = 51.314705, longitude = 1.160170, display_name = "Hersden"},
    ["Broomfield"] = { latitude = 51.357427, longitude = 1.154917, display_name = "Broomfield"},
    ["St Nicholas-at-Wade"] = { latitude = 51.352050, longitude = 1.253523, display_name = "St Nicholas-at-Wade"},
    ["Monkton"] = { latitude = 51.338792, longitude = 1.281998, display_name = "Monkton"},
    ["Woodnesborough"] = { latitude = 51.265848, longitude = 1.305345, display_name = "Woodnesborough"},
    ["Elvington"] = { latitude = 51.206252, longitude = 1.248205, display_name = "Elvington"},
    ["Eythorne"] = { latitude = 51.198082, longitude = 1.266917, display_name = "Eythorne"},
    ["Stockbury"] = { latitude = 51.327200, longitude = 0.641439, display_name = "Stockbury"},
    ["Hartlip"] = { latitude = 51.348055, longitude = 0.639520, display_name = "Hartlip"},
    ["Halling"] = { latitude = 51.354593, longitude = 0.444094, display_name = "Halling"},
    ["Birling"] = { latitude = 51.319026, longitude = 0.410614, display_name = "Birling"},
    ["Strood"] = { latitude = 51.395857, longitude = 0.495080, display_name = "Strood"},
    ["Westgate-on-Sea"] = { latitude = 51.381577, longitude = 1.337211, display_name = "Westgate-on-Sea"},
    ["Etchingham"] = { latitude = 51.008586, longitude = 0.438025, display_name = "Etchingham"},
    ["Hurst Green"] = { latitude = 51.018451, longitude = 0.469524, display_name = "Hurst Green"},
    ["Lydden"] = { latitude = 51.162264, longitude = 1.241301, display_name = "Lydden"},
    ["Temple Ewell"] = { latitude = 51.152250, longitude = 1.269622, display_name = "Temple Ewell"},
    ["Kearsney"] = { latitude = 51.148482, longitude = 1.266451, display_name = "Kearsney"},
    ["Ringwould"] = { latitude = 51.183706, longitude = 1.376369, display_name = "Ringwould"},
    ["Ripple"] = { latitude = 51.200491, longitude = 1.357389, display_name = "Ripple"},
    ["Walmer"] = { latitude = 51.206888, longitude = 1.399915, display_name = "Walmer"},
    ["Northbourne"] = { latitude = 51.220424, longitude = 1.337825, display_name = "Northbourne"},
    ["Sholden"] = { latitude = 51.224973, longitude = 1.375277, display_name = "Sholden"},
    ["Worth"] = { latitude = 51.256253, longitude = 1.348298, display_name = "Worth"},
    ["Stone Cross"] = { latitude = 51.265876, longitude = 1.338865, display_name = "Stone Cross"},
    ["Bossingham"] = { latitude = 51.200445, longitude = 1.076820, display_name = "Bossingham"},
    ["Petham"] = { latitude = 51.222798, longitude = 1.045879, display_name = "Petham"},
    ["Robertsbridge"] = { latitude = 50.985640, longitude = 0.474452, display_name = "Robertsbridge"},
    ["Kemsley"] = { latitude = 51.363471, longitude = 0.739047, display_name = "Kemsley"},
    ["Harbledown"] = { latitude = 51.281829, longitude = 1.056575, display_name = "Harbledown"},
    ["Orlestone"] = { latitude = 51.076644, longitude = 0.853228, display_name = "Orlestone"},
    ["Horsmonden"] = { latitude = 51.139145, longitude = 0.431837, display_name = "Horsmonden"},
    ["Denton"] = { latitude = 51.181449, longitude = 1.169768, display_name = "Denton"},
    ["Goodnestone"] = { latitude = 51.246747, longitude = 1.230529, display_name = "Goodnestone"},
    ["Bexhill-on-Sea"] = { latitude = 50.842438, longitude = 0.467572, display_name = "Bexhill-on-Sea"},
    ["Hastings"] = { latitude = 50.855389, longitude = 0.582470, display_name = "Hastings"},
    ["Sutton Valence"] = { latitude = 51.212634, longitude = 0.592560, display_name = "Sutton Valence"},
    ["Egerton"] = { latitude = 51.195112, longitude = 0.729017, display_name = "Egerton"},
    ["Walderslade"] = { latitude = 51.342945, longitude = 0.526780, display_name = "Walderslade"},
    ["Shorne"] = { latitude = 51.413153, longitude = 0.433041, display_name = "Shorne"},
    ["Cuxton"] = { latitude = 51.375046, longitude = 0.455713, display_name = "Cuxton"},
    ["Higham"] = { latitude = 51.415105, longitude = 0.459730, display_name = "Higham"},
    ["Bluebell Hill"] = { latitude = 51.332465, longitude = 0.505855, display_name = "Bluebell Hill"},
    ["Bredhurst"] = { latitude = 51.331700, longitude = 0.579602, display_name = "Bredhurst"},
    ["Upper Upnor"] = { latitude = 51.405943, longitude = 0.525429, display_name = "Upper Upnor"},
    ["Wateringbury"] = { latitude = 51.255749, longitude = 0.416423, display_name = "Wateringbury"},
    ["East Malling"] = { latitude = 51.287380, longitude = 0.438542, display_name = "East Malling"},
    ["Lower Upnor"] = { latitude = 51.412433, longitude = 0.530373, display_name = "Lower Upnor"},
    ["Frindsbury"] = { latitude = 51.400196, longitude = 0.506504, display_name = "Frindsbury"},
    ["Wainscott"] = { latitude = 51.411234, longitude = 0.510528, display_name = "Wainscott"},
    ["Hale"] = { latitude = 51.363531, longitude = 0.555123, display_name = "Hale"},
    ["Lower Rainham"] = { latitude = 51.379150, longitude = 0.605817, display_name = "Lower Rainham"},
    ["Moor Street"] = { latitude = 51.358628, longitude = 0.628863, display_name = "Moor Street"},
    ["Eccles"] = { latitude = 51.317774, longitude = 0.481066, display_name = "Eccles"},
    ["Hempstead"] = { latitude = 51.351133, longitude = 0.569747, display_name = "Hempstead"},
    ["Boxley"] = { latitude = 51.301603, longitude = 0.543120, display_name = "Boxley"},
    ["Thurnham"] = { latitude = 51.291306, longitude = 0.591831, display_name = "Thurnham"},
    ["Royal British Legion Village"] = { latitude = 51.293880, longitude = 0.475714, display_name = "Royal British Legion Village"},
    ["Lower Halstow"] = { latitude = 51.372477, longitude = 0.669655, display_name = "Lower Halstow"},
    ["Upchurch"] = { latitude = 51.376198, longitude = 0.649188, display_name = "Upchurch"},
    ["Newington"] = { latitude = 51.351563, longitude = 0.665701, display_name = "Newington"},
    ["Yalding"] = { latitude = 51.224363, longitude = 0.431451, display_name = "Yalding"},
    ["Nettlestead"] = { latitude = 51.243649, longitude = 0.412021, display_name = "Nettlestead"},
    ["Hunton"] = { latitude = 51.218873, longitude = 0.459449, display_name = "Hunton"},
    ["West Farleigh"] = { latitude = 51.251037, longitude = 0.455152, display_name = "West Farleigh"},
    ["East Farleigh"] = { latitude = 51.253071, longitude = 0.483908, display_name = "East Farleigh"},
    ["St Michaels"] = { latitude = 51.082873, longitude = 0.692405, display_name = "St Michaels"},
    ["Broad Oak"] = { latitude = 50.950030, longitude = 0.599972, display_name = "Broad Oak"},
    ["Crowhurst"] = { latitude = 50.882407, longitude = 0.497905, display_name = "Crowhurst"},
    ["Ninfield"] = { latitude = 50.888399, longitude = 0.418847, display_name = "Ninfield"},
    ["Westfield"] = { latitude = 50.908967, longitude = 0.576927, display_name = "Westfield"},
    ["Icklesham"] = { latitude = 50.916764, longitude = 0.666258, display_name = "Icklesham"},
    ["Newingreen"] = { latitude = 51.084584, longitude = 1.034409, display_name = "Newingreen"},
    ["Bethersden"] = { latitude = 51.127249, longitude = 0.752789, display_name = "Bethersden"},
    ["Netherfield"] = { latitude = 50.943373, longitude = 0.435069, display_name = "Netherfield"},
    ["Hollingbourne"] = { latitude = 51.265694, longitude = 0.641462, display_name = "Hollingbourne"},
    ["Birchington"] = { latitude = 51.373802, longitude = 1.307125, display_name = "Birchington"},
    ["Sedlescombe"] = { latitude = 50.940424, longitude = 0.529209, display_name = "Sedlescombe"},
    ["Sedlescombe Street"] = { latitude = 50.932365, longitude = 0.533243, display_name = "Sedlescombe Street"},
    ["Fairlight"] = { latitude = 50.875316, longitude = 0.662418, display_name = "Fairlight"},
    ["St Leonards"] = { latitude = 50.855726, longitude = 0.548014, display_name = "St Leonards"},
    ["Old Hawkinge"] = { latitude = 51.114871, longitude = 1.184821, display_name = "Old Hawkinge"},
    ["Hawkhurst"] = { latitude = 51.046963, longitude = 0.508255, display_name = "Hawkhurst"},
    ["Ticehurst"] = { latitude = 51.045772, longitude = 0.413924, display_name = "Ticehurst"},
    ["Pett"] = { latitude = 50.895003, longitude = 0.669064, display_name = "Pett"},
    ["Boughton Monchelsea"] = { latitude = 51.232170, longitude = 0.530222, display_name = "Boughton Monchelsea"},
    ["Catsfield"] = { latitude = 50.897500, longitude = 0.450511, display_name = "Catsfield"},
    ["East Guldeford"] = { latitude = 50.958813, longitude = 0.755803, display_name = "East Guldeford"},
    ["Rye Harbour"] = { latitude = 50.938298, longitude = 0.759768, display_name = "Rye Harbour"},
    ["Camber"] = { latitude = 50.935201, longitude = 0.795683, display_name = "Camber"},
    ["Peasmarsh"] = { latitude = 50.972788, longitude = 0.690662, display_name = "Peasmarsh"},
    ["Oversland"] = { latitude = 51.279307, longitude = 0.951784, display_name = "Oversland"},
    ["Penenden Heath"] = { latitude = 51.288097, longitude = 0.538713, display_name = "Penenden Heath"},
    ["Sittingbourne"] = { latitude = 51.339737, longitude = 0.734232, display_name = "Sittingbourne"},
    ["Snodland"] = { latitude = 51.329623, longitude = 0.442632, display_name = "Snodland"},
    ["River"] = { latitude = 51.143546, longitude = 1.274147, display_name = "River"},
    ["Sole Street"] = { latitude = 51.204643, longitude = 0.999889, display_name = "Sole Street"},
    ["Shorne Ridgeway"] = { latitude = 51.408383, longitude = 0.431770, display_name = "Shorne Ridgeway"},
    ["Flimwell"] = { latitude = 51.054847, longitude = 0.446861, display_name = "Flimwell"},
    ["Tyler Hill"] = { latitude = 51.307809, longitude = 1.069309, display_name = "Tyler Hill"},
    ["Chestfield"] = { latitude = 51.353758, longitude = 1.067317, display_name = "Chestfield"},
    ["Boughton Malherbe"] = { latitude = 51.215256, longitude = 0.694976, display_name = "Boughton Malherbe"},
    ["Iwade"] = { latitude = 51.376599, longitude = 0.727962, display_name = "Iwade"},
    ["Bobbing"] = { latitude = 51.353954, longitude = 0.709361, display_name = "Bobbing"},
    ["Rodmersham Green"] = { latitude = 51.319209, longitude = 0.747733, display_name = "Rodmersham Green"},
    ["Bredgar"] = { latitude = 51.313023, longitude = 0.696771, display_name = "Bredgar"},
    ["Milstead"] = { latitude = 51.295834, longitude = 0.728404, display_name = "Milstead"},
    ["Borden"] = { latitude = 51.333949, longitude = 0.702481, display_name = "Borden"},
    ["Tunstall"] = { latitude = 51.323568, longitude = 0.717667, display_name = "Tunstall"},
    ["Wormshill"] = { latitude = 51.283577, longitude = 0.694398, display_name = "Wormshill"},
    ["Sarre"] = { latitude = 51.338879, longitude = 1.238516, display_name = "Sarre"},
    ["Capel-le-Ferne"] = { latitude = 51.102164, longitude = 1.211693, display_name = "Capel-le-Ferne"},
    ["Playden"] = { latitude = 50.962397, longitude = 0.732905, display_name = "Playden"},
    ["Mountfield"] = { latitude = 50.956032, longitude = 0.479411, display_name = "Mountfield"},
    ["Seabrook"] = { latitude = 51.072958, longitude = 1.118642, display_name = "Seabrook"},
    ["Conyer"] = { latitude = 51.347093, longitude = 0.816969, display_name = "Conyer"},
    ["Guestling"] = { latitude = 50.890229, longitude = 0.630193, display_name = "Guestling"},
    ["Staplecross"] = { latitude = 50.973103, longitude = 0.539617, display_name = "Staplecross"},
    ["Kingsdown"] = { latitude = 51.186841, longitude = 1.402737, display_name = "Kingsdown"},
    ["Sandwich Bay"] = { latitude = 51.267788, longitude = 1.385374, display_name = "Sandwich Bay"},
    ["Minster on Sea"] = { latitude = 51.420236, longitude = 0.803194, display_name = "Minster on Sea"},
    ["Tonbridge"] = { latitude = 51.198712, longitude = 0.277477, display_name = "Tonbridge"},
    ["Royal Tunbridge Wells"] = { latitude = 51.138667, longitude = 0.261915, display_name = "Royal Tunbridge Wells"},
    ["Sevenoaks"] = { latitude = 51.275888, longitude = 0.182776, display_name = "Sevenoaks"},
    ["Oxted"] = { latitude = 51.260298, longitude = 0.031627, display_name = "Oxted"},
    ["East Grinstead"] = { latitude = 51.129870, longitude = -0.010519, display_name = "East Grinstead"},
    ["Crowborough"] = { latitude = 51.057392, longitude = 0.159431, display_name = "Crowborough"},
    ["Heathfield"] = { latitude = 50.965302, longitude = 0.250549, display_name = "Heathfield"},
    ["Burwash Common"] = { latitude = 50.984654, longitude = 0.316699, display_name = "Burwash Common"},
    ["Horam"] = { latitude = 50.933414, longitude = 0.246359, display_name = "Horam"},
    ["Hailsham"] = { latitude = 50.866286, longitude = 0.258547, display_name = "Hailsham"},
    ["Windmill Hill"] = { latitude = 50.883438, longitude = 0.348513, display_name = "Windmill Hill"},
    ["Eastbourne"] = { latitude = 50.769830, longitude = 0.282343, display_name = "Eastbourne"},
    ["Dunkirk"] = { latitude = 51.034771, longitude = 2.377253, display_name = "Dunkirk"},
    ["Coudekerque-Branche"] = { latitude = 51.020878, longitude = 2.389432, display_name = "Coudekerque-Branche"},
    ["Bailleul"] = { latitude = 50.739667, longitude = 2.734929, display_name = "Bailleul"},
    ["Grande-Synthe"] = { latitude = 51.013481, longitude = 2.302997, display_name = "Grande-Synthe"},
    ["Le Portel"] = { latitude = 50.707458, longitude = 1.573716, display_name = "Le Portel"},
    ["Isbergues"] = { latitude = 50.621124, longitude = 2.457463, display_name = "Isbergues"},
    ["Longuenesse"] = { latitude = 50.737100, longitude = 2.248330, display_name = "Longuenesse"},
    ["Gravelines"] = { latitude = 50.987070, longitude = 2.127312, display_name = "Gravelines"},
    ["Calais"] = { latitude = 50.948800, longitude = 1.874680, display_name = "Calais"},
    ["Saint-Martin-Boulogne"] = { latitude = 50.722905, longitude = 1.646774, display_name = "Saint-Martin-Boulogne"},
    ["Saint-Omer"] = { latitude = 50.752191, longitude = 2.254075, display_name = "Saint-Omer"},
    ["Hazebrouck"] = { latitude = 50.722611, longitude = 2.536033, display_name = "Hazebrouck"},
    ["Boulogne-sur-Mer"] = { latitude = 50.725998, longitude = 1.611877, display_name = "Boulogne-sur-Mer"},
    ["Ghyvelde"] = { latitude = 51.051857, longitude = 2.526378, display_name = "Ghyvelde"},
    ["Aire-sur-la-Lys"] = { latitude = 50.639594, longitude = 2.400060, display_name = "Aire-sur-la-Lys"},
    ["Vieux-Berquin"] = { latitude = 50.694805, longitude = 2.643792, display_name = "Vieux-Berquin"},
    ["Cappelle-la-Grande"] = { latitude = 50.997722, longitude = 2.367794, display_name = "Cappelle-la-Grande"},
    ["Bergues"] = { latitude = 50.968389, longitude = 2.432525, display_name = "Bergues"},
    ["Vendin-les-Bethune"] = { latitude = 50.546200, longitude = 2.604230, display_name = "Vendin-les-Bethune"},
    ["Desvres"] = { latitude = 50.667874, longitude = 1.834827, display_name = "Desvres"},
    ["Armbouts-Cappel"] = { latitude = 50.978044, longitude = 2.351581, display_name = "Armbouts-Cappel"},
    ["Cassel"] = { latitude = 50.800001, longitude = 2.486831, display_name = "Cassel"},
    ["Steenvoorde"] = { latitude = 50.810126, longitude = 2.581641, display_name = "Steenvoorde"},
    ["Teteghem"] = { latitude = 51.016805, longitude = 2.441295, display_name = "Teteghem"},
    ["Eperlecques"] = { latitude = 50.815400, longitude = 2.158610, display_name = "Eperlecques"},
    ["Camiers"] = { latitude = 50.563800, longitude = 1.614410, display_name = "Camiers"},
    ["Chocques"] = { latitude = 50.539186, longitude = 2.569606, display_name = "Chocques"},
    ["Meteren"] = { latitude = 50.740908, longitude = 2.691174, display_name = "Meteren"},
    ["Blendecques"] = { latitude = 50.717084, longitude = 2.281795, display_name = "Blendecques"},
    ["Marquise"] = { latitude = 50.812582, longitude = 1.699554, display_name = "Marquise"},
    ["Lestrem"] = { latitude = 50.621621, longitude = 2.685753, display_name = "Lestrem"},
    ["Saint-Etienne-au-Mont"] = { latitude = 50.681686, longitude = 1.626043, display_name = "Saint-Etienne-au-Mont"},
    ["Saint-Folquin"] = { latitude = 50.945910, longitude = 2.123789, display_name = "Saint-Folquin"},
    ["Beuvry"] = { latitude = 50.533719, longitude = 2.686479, display_name = "Beuvry"},
    ["Bourbourg"] = { latitude = 50.946662, longitude = 2.197370, display_name = "Bourbourg"},
    ["Rinxent"] = { latitude = 50.806400, longitude = 1.739970, display_name = "Rinxent"},
    ["Morbecque"] = { latitude = 50.691853, longitude = 2.515558, display_name = "Morbecque"},
    ["Saint-Venant"] = { latitude = 50.623765, longitude = 2.549267, display_name = "Saint-Venant"},
    ["Samer"] = { latitude = 50.639272, longitude = 1.746919, display_name = "Samer"},
    ["Saint-Leonard"] = { latitude = 50.688814, longitude = 1.627086, display_name = "Saint-Leonard"},
    ["Marck"] = { latitude = 50.949000, longitude = 1.951990, display_name = "Marck"},
    ["Ambleteuse"] = { latitude = 50.811233, longitude = 1.606669, display_name = "Ambleteuse"},
    ["Renescure"] = { latitude = 50.727611, longitude = 2.369521, display_name = "Renescure"},
    ["Hondschoote"] = { latitude = 50.980856, longitude = 2.586264, display_name = "Hondschoote"},
    ["Coulogne"] = { latitude = 50.925743, longitude = 1.884090, display_name = "Coulogne"},
    ["Grand-Fort-Philippe"] = { latitude = 51.001446, longitude = 2.104597, display_name = "Grand-Fort-Philippe"},
    ["Equihen-Plage"] = { latitude = 50.679393, longitude = 1.571665, display_name = "Equihen-Plage"},
    ["Guines"] = { latitude = 50.869086, longitude = 1.870441, display_name = "Guines"},
    ["Merville"] = { latitude = 50.643658, longitude = 2.638750, display_name = "Merville"},
    ["Loon-Plage"] = { latitude = 50.994610, longitude = 2.219246, display_name = "Loon-Plage"},
    ["Locon"] = { latitude = 50.570500, longitude = 2.666170, display_name = "Locon"},
    ["Lillers"] = { latitude = 50.560600, longitude = 2.476040, display_name = "Lillers"},
    ["Wimille"] = { latitude = 50.764109, longitude = 1.630328, display_name = "Wimille"},
    ["Gonnehem"] = { latitude = 50.562287, longitude = 2.573843, display_name = "Gonnehem"},
    ["Racquinghem"] = { latitude = 50.692974, longitude = 2.356774, display_name = "Racquinghem"},
    ["Watten"] = { latitude = 50.832402, longitude = 2.212066, display_name = "Watten"},
    ["La Gorgue"] = { latitude = 50.637260, longitude = 2.713401, display_name = "La Gorgue"},
    ["Esquelbecq"] = { latitude = 50.886213, longitude = 2.430913, display_name = "Esquelbecq"},
    ["Audruicq"] = { latitude = 50.878649, longitude = 2.075236, display_name = "Audruicq"},
    ["Saint-Martin-au-Laert"] = { latitude = 50.754529, longitude = 2.234968, display_name = "Saint-Martin-au-Laert"},
    ["Condette"] = { latitude = 50.649000, longitude = 1.642110, display_name = "Condette"},
    ["Arques"] = { latitude = 50.739664, longitude = 2.306207, display_name = "Arques"},
    ["Oye-Plage"] = { latitude = 50.980900, longitude = 2.041980, display_name = "Oye-Plage"},
    ["Bray-Dunes"] = { latitude = 51.071002, longitude = 2.524513, display_name = "Bray-Dunes"},
    ["Leffrinckoucke"] = { latitude = 51.050940, longitude = 2.438674, display_name = "Leffrinckoucke"},
    ["Hoymille"] = { latitude = 50.973018, longitude = 2.448505, display_name = "Hoymille"},
    ["Wizernes"] = { latitude = 50.711594, longitude = 2.230686, display_name = "Wizernes"},
    ["Burbure"] = { latitude = 50.537016, longitude = 2.465564, display_name = "Burbure"},
    ["Neufchatel-Hardelot"] = { latitude = 50.618849, longitude = 1.630616, display_name = "Neufchatel-Hardelot"},
    ["La Couture"] = { latitude = 50.580187, longitude = 2.712909, display_name = "La Couture"},
    ["Lumbres"] = { latitude = 50.705136, longitude = 2.121790, display_name = "Lumbres"},
    ["Ardres"] = { latitude = 50.853632, longitude = 1.978607, display_name = "Ardres"},
    ["Estaires"] = { latitude = 50.644026, longitude = 2.722651, display_name = "Estaires"},
    ["Richebourg"] = { latitude = 50.579253, longitude = 2.739930, display_name = "Richebourg"},
    ["Allouagne"] = { latitude = 50.532500, longitude = 2.507060, display_name = "Allouagne"},
    ["Annezin"] = { latitude = 50.541500, longitude = 2.619300, display_name = "Annezin"},
    ["Killem"] = { latitude = 50.957849, longitude = 2.562633, display_name = "Killem"},
    ["Watou"] = { latitude = 50.858554, longitude = 2.620280, display_name = "Watou"},
    ["Saint-Tricat"] = { latitude = 50.893532, longitude = 1.831895, display_name = "Saint-Tricat"},
    ["Escalles"] = { latitude = 50.917985, longitude = 1.713605, display_name = "Escalles"},
    ["Sint-Idesbald"] = { latitude = 51.109274, longitude = 2.612880, display_name = "Sint-Idesbald"},
    ["De Panne"] = { latitude = 51.098831, longitude = 2.592409, display_name = "De Panne"},
    ["Poperinge"] = { latitude = 50.855665, longitude = 2.726496, display_name = "Poperinge"},
    ["Winnezeele"] = { latitude = 50.840061, longitude = 2.551238, display_name = "Winnezeele"},
    ["Les Moeres"] = { latitude = 51.014607, longitude = 2.548824, display_name = "Les Moeres"},
    ["Wylder"] = { latitude = 50.911643, longitude = 2.493981, display_name = "Wylder"},
    ["Alveringem"] = { latitude = 51.011998, longitude = 2.710503, display_name = "Alveringem"},
    ["La Capelle-les-Boulogne"] = { latitude = 50.730602, longitude = 1.701125, display_name = "La Capelle-les-Boulogne"},
    ["Fletre"] = { latitude = 50.753348, longitude = 2.645652, display_name = "Fletre"},
    ["Godewaersvelde"] = { latitude = 50.794256, longitude = 2.642912, display_name = "Godewaersvelde"},
    ["Hesdigneul-les-Boulogne"] = { latitude = 50.659243, longitude = 1.672432, display_name = "Hesdigneul-les-Boulogne"},
    ["Saint-Inglevert"] = { latitude = 50.875508, longitude = 1.742566, display_name = "Saint-Inglevert"},
    ["Febvin-Palfart"] = { latitude = 50.538485, longitude = 2.315797, display_name = "Febvin-Palfart"},
    ["Laires"] = { latitude = 50.539137, longitude = 2.255314, display_name = "Laires"},
    ["Beaumetz-les-Aire"] = { latitude = 50.542628, longitude = 2.224930, display_name = "Beaumetz-les-Aire"},
    ["Uxem"] = { latitude = 51.020525, longitude = 2.485008, display_name = "Uxem"},
    ["Le Doulieu"] = { latitude = 50.682338, longitude = 2.718519, display_name = "Le Doulieu"},
    ["Neuf-Berquin"] = { latitude = 50.660048, longitude = 2.670113, display_name = "Neuf-Berquin"},
    ["Haverskerque"] = { latitude = 50.640764, longitude = 2.541629, display_name = "Haverskerque"},
    ["Merris"] = { latitude = 50.715997, longitude = 2.661152, display_name = "Merris"},
    ["Saint-Jans-Cappel"] = { latitude = 50.763955, longitude = 2.721262, display_name = "Saint-Jans-Cappel"},
    ["Berthen"] = { latitude = 50.783094, longitude = 2.694833, display_name = "Berthen"},
    ["Strazeele"] = { latitude = 50.726931, longitude = 2.632214, display_name = "Strazeele"},
    ["Pradelles"] = { latitude = 50.731925, longitude = 2.604972, display_name = "Pradelles"},
    ["Borre"] = { latitude = 50.731291, longitude = 2.584293, display_name = "Borre"},
    ["Caestre"] = { latitude = 50.758358, longitude = 2.603998, display_name = "Caestre"},
    ["Hondeghem"] = { latitude = 50.756499, longitude = 2.521257, display_name = "Hondeghem"},
    ["Thiennes"] = { latitude = 50.651121, longitude = 2.465992, display_name = "Thiennes"},
    ["Boeseghem"] = { latitude = 50.662021, longitude = 2.436942, display_name = "Boeseghem"},
    ["Steenbecque"] = { latitude = 50.673869, longitude = 2.484934, display_name = "Steenbecque"},
    ["Wallon-Cappel"] = { latitude = 50.727114, longitude = 2.474017, display_name = "Wallon-Cappel"},
    ["Boeschepe"] = { latitude = 50.800274, longitude = 2.691633, display_name = "Boeschepe"},
    ["Blaringhem"] = { latitude = 50.691533, longitude = 2.404284, display_name = "Blaringhem"},
    ["Sercus"] = { latitude = 50.706649, longitude = 2.456155, display_name = "Sercus"},
    ["Courset"] = { latitude = 50.647060, longitude = 1.840437, display_name = "Courset"},
    ["Clairmarais"] = { latitude = 50.769714, longitude = 2.303873, display_name = "Clairmarais"},
    ["Lynde"] = { latitude = 50.712720, longitude = 2.419570, display_name = "Lynde"},
    ["Ebblinghem"] = { latitude = 50.733310, longitude = 2.409402, display_name = "Ebblinghem"},
    ["Staple"] = { latitude = 50.749534, longitude = 2.454854, display_name = "Staple"},
    ["Bavinchove"] = { latitude = 50.786146, longitude = 2.455895, display_name = "Bavinchove"},
    ["Oxelaere"] = { latitude = 50.788573, longitude = 2.476408, display_name = "Oxelaere"},
    ["Saint-Sylvestre-Cappel"] = { latitude = 50.776539, longitude = 2.554424, display_name = "Saint-Sylvestre-Cappel"},
    ["Sainte-Marie-Cappel"] = { latitude = 50.783643, longitude = 2.510021, display_name = "Sainte-Marie-Cappel"},
    ["Eecke"] = { latitude = 50.779085, longitude = 2.596637, display_name = "Eecke"},
    ["Terdeghem"] = { latitude = 50.798750, longitude = 2.540184, display_name = "Terdeghem"},
    ["Wissant"] = { latitude = 50.885779, longitude = 1.663546, display_name = "Wissant"},
    ["Hardifort"] = { latitude = 50.820723, longitude = 2.485908, display_name = "Hardifort"},
    ["Oudezeele"] = { latitude = 50.838533, longitude = 2.510881, display_name = "Oudezeele"},
    ["Zuytpeene"] = { latitude = 50.793706, longitude = 2.430557, display_name = "Zuytpeene"},
    ["Noordpeene"] = { latitude = 50.805883, longitude = 2.396303, display_name = "Noordpeene"},
    ["Nieurlet"] = { latitude = 50.788599, longitude = 2.282161, display_name = "Nieurlet"},
    ["Saint-Momelin"] = { latitude = 50.794897, longitude = 2.250181, display_name = "Saint-Momelin"},
    ["Buysscheure"] = { latitude = 50.803823, longitude = 2.333426, display_name = "Buysscheure"},
    ["Lederzeele"] = { latitude = 50.819633, longitude = 2.303059, display_name = "Lederzeele"},
    ["Broxeele"] = { latitude = 50.830041, longitude = 2.319521, display_name = "Broxeele"},
    ["Rubrouck"] = { latitude = 50.838312, longitude = 2.353890, display_name = "Rubrouck"},
    ["Ochtezeele"] = { latitude = 50.817454, longitude = 2.400885, display_name = "Ochtezeele"},
    ["Wemaers-Cappel"] = { latitude = 50.806728, longitude = 2.440173, display_name = "Wemaers-Cappel"},
    ["Arneke"] = { latitude = 50.832041, longitude = 2.411757, display_name = "Arneke"},
    ["Frethun"] = { latitude = 50.919591, longitude = 1.825603, display_name = "Frethun"},
    ["Zermezeele"] = { latitude = 50.823506, longitude = 2.450104, display_name = "Zermezeele"},
    ["Wulverdinghe"] = { latitude = 50.831729, longitude = 2.255670, display_name = "Wulverdinghe"},
    ["Volckerinckhove"] = { latitude = 50.838367, longitude = 2.305745, display_name = "Volckerinckhove"},
    ["Bollezeele"] = { latitude = 50.865595, longitude = 2.327453, display_name = "Bollezeele"},
    ["Ledringhem"] = { latitude = 50.854568, longitude = 2.439630, display_name = "Ledringhem"},
    ["Holque"] = { latitude = 50.853697, longitude = 2.203616, display_name = "Holque"},
    ["Millam"] = { latitude = 50.854929, longitude = 2.248551, display_name = "Millam"},
    ["Merckeghem"] = { latitude = 50.861588, longitude = 2.295689, display_name = "Merckeghem"},
    ["Saint-Pierre-Brouck"] = { latitude = 50.896030, longitude = 2.189389, display_name = "Saint-Pierre-Brouck"},
    ["Cappelle-Brouck"] = { latitude = 50.901860, longitude = 2.223000, display_name = "Cappelle-Brouck"},
    ["Eringhem"] = { latitude = 50.896922, longitude = 2.344936, display_name = "Eringhem"},
    ["Zegerscappel"] = { latitude = 50.887716, longitude = 2.385718, display_name = "Zegerscappel"},
    ["Houtkerque"] = { latitude = 50.876696, longitude = 2.595551, display_name = "Houtkerque"},
    ["Bambecque"] = { latitude = 50.901262, longitude = 2.547679, display_name = "Bambecque"},
    ["Drincham"] = { latitude = 50.906747, longitude = 2.310390, display_name = "Drincham"},
    ["Bissezeele"] = { latitude = 50.911634, longitude = 2.408987, display_name = "Bissezeele"},
    ["Crochte"] = { latitude = 50.935284, longitude = 2.386984, display_name = "Crochte"},
    ["Pitgam"] = { latitude = 50.927799, longitude = 2.330493, display_name = "Pitgam"},
    ["Looberghe"] = { latitude = 50.916504, longitude = 2.272060, display_name = "Looberghe"},
    ["Steene"] = { latitude = 50.952225, longitude = 2.369409, display_name = "Steene"},
    ["West-Cappel"] = { latitude = 50.928273, longitude = 2.507585, display_name = "West-Cappel"},
    ["Socx"] = { latitude = 50.936013, longitude = 2.422840, display_name = "Socx"},
    ["Quaedypre"] = { latitude = 50.935395, longitude = 2.455633, display_name = "Quaedypre"},
    ["Bierne"] = { latitude = 50.963476, longitude = 2.409818, display_name = "Bierne"},
    ["Oost-Cappel"] = { latitude = 50.924611, longitude = 2.597743, display_name = "Oost-Cappel"},
    ["Rexpoede"] = { latitude = 50.939354, longitude = 2.538858, display_name = "Rexpoede"},
    ["Warhem"] = { latitude = 50.976760, longitude = 2.492958, display_name = "Warhem"},
    ["Brouckerque"] = { latitude = 50.954119, longitude = 2.292949, display_name = "Brouckerque"},
    ["Spycker"] = { latitude = 50.968436, longitude = 2.322961, display_name = "Spycker"},
    ["Saint-Georges-sur-l'Aa"] = { latitude = 50.970102, longitude = 2.164564, display_name = "Saint-Georges-sur-l'Aa"},
    ["Craywick"] = { latitude = 50.970686, longitude = 2.235816, display_name = "Craywick"},
    ["Coudekerque-Village"] = { latitude = 50.994443, longitude = 2.417163, display_name = "Coudekerque-Village"},
    ["Zuydcoote"] = { latitude = 51.063909, longitude = 2.490711, display_name = "Zuydcoote"},
    ["Hardinghen"] = { latitude = 50.805869, longitude = 1.821639, display_name = "Hardinghen"},
    ["Boursin"] = { latitude = 50.776524, longitude = 1.834829, display_name = "Boursin"},
    ["Colembert"] = { latitude = 50.747612, longitude = 1.838257, display_name = "Colembert"},
    ["Le Wast"] = { latitude = 50.750291, longitude = 1.802118, display_name = "Le Wast"},
    ["Wierre-Effroy"] = { latitude = 50.779597, longitude = 1.738891, display_name = "Wierre-Effroy"},
    ["Belle-et-Houllefort"] = { latitude = 50.744787, longitude = 1.760298, display_name = "Belle-et-Houllefort"},
    ["Cremarest"] = { latitude = 50.701073, longitude = 1.785933, display_name = "Cremarest"},
    ["Bellebrune"] = { latitude = 50.726348, longitude = 1.774510, display_name = "Bellebrune"},
    ["Pittefaux"] = { latitude = 50.756594, longitude = 1.684987, display_name = "Pittefaux"},
    ["Pernes-les-Boulogne"] = { latitude = 50.752184, longitude = 1.701034, display_name = "Pernes-les-Boulogne"},
    ["Offrethun"] = { latitude = 50.783693, longitude = 1.693148, display_name = "Offrethun"},
    ["Wacquinghen"] = { latitude = 50.783066, longitude = 1.667264, display_name = "Wacquinghen"},
    ["Audresselles"] = { latitude = 50.824181, longitude = 1.595736, display_name = "Audresselles"},
    ["Audinghen"] = { latitude = 50.852665, longitude = 1.614320, display_name = "Audinghen"},
    ["Tardinghen"] = { latitude = 50.866592, longitude = 1.631452, display_name = "Tardinghen"},
    ["Bazinghen"] = { latitude = 50.825670, longitude = 1.662221, display_name = "Bazinghen"},
    ["Leulinghen-Bernes"] = { latitude = 50.832894, longitude = 1.712123, display_name = "Leulinghen-Bernes"},
    ["Audembert"] = { latitude = 50.861176, longitude = 1.694268, display_name = "Audembert"},
    ["Leubringhen"] = { latitude = 50.858229, longitude = 1.720168, display_name = "Leubringhen"},
    ["Hervelinghen"] = { latitude = 50.881809, longitude = 1.713988, display_name = "Hervelinghen"},
    ["Pihen-les-Guines"] = { latitude = 50.870387, longitude = 1.787442, display_name = "Pihen-les-Guines"},
    ["Landrethun-le-Nord"] = { latitude = 50.847112, longitude = 1.782324, display_name = "Landrethun-le-Nord"},
    ["Ferques"] = { latitude = 50.831049, longitude = 1.767750, display_name = "Ferques"},
    ["Caffiers"] = { latitude = 50.841202, longitude = 1.809751, display_name = "Caffiers"},
    ["Fiennes"] = { latitude = 50.828352, longitude = 1.827018, display_name = "Fiennes"},
    ["Doudeauville"] = { latitude = 50.614815, longitude = 1.835048, display_name = "Doudeauville"},
    ["Wirwignes"] = { latitude = 50.683400, longitude = 1.762810, display_name = "Wirwignes"},
    ["Bonningues-les-Calais"] = { latitude = 50.890385, longitude = 1.774088, display_name = "Bonningues-les-Calais"},
    ["Hucqueliers"] = { latitude = 50.569576, longitude = 1.907205, display_name = "Hucqueliers"},
    ["Bourthes"] = { latitude = 50.606253, longitude = 1.932188, display_name = "Bourthes"},
    ["Brunembert"] = { latitude = 50.713746, longitude = 1.893926, display_name = "Brunembert"},
    ["Selles"] = { latitude = 50.700539, longitude = 1.896464, display_name = "Selles"},
    ["Dannes"] = { latitude = 50.588960, longitude = 1.616037, display_name = "Dannes"},
    ["Wardrecques"] = { latitude = 50.708784, longitude = 2.345237, display_name = "Wardrecques"},
    ["Quiestede"] = { latitude = 50.679231, longitude = 2.316379, display_name = "Quiestede"},
    ["Roquetoire"] = { latitude = 50.668017, longitude = 2.337788, display_name = "Roquetoire"},
    ["Wittes"] = { latitude = 50.669305, longitude = 2.389990, display_name = "Wittes"},
    ["Tatinghem"] = { latitude = 50.742310, longitude = 2.206800, display_name = "Tatinghem"},
    ["Wisques"] = { latitude = 50.722827, longitude = 2.192666, display_name = "Wisques"},
    ["Hallines"] = { latitude = 50.709050, longitude = 2.209680, display_name = "Hallines"},
    ["Helfaut"] = { latitude = 50.696726, longitude = 2.240340, display_name = "Helfaut"},
    ["Echinghen"] = { latitude = 50.703418, longitude = 1.647763, display_name = "Echinghen"},
    ["Baincthun"] = { latitude = 50.710464, longitude = 1.680928, display_name = "Baincthun"},
    ["Isques"] = { latitude = 50.682451, longitude = 1.644526, display_name = "Isques"},
    ["Alincthun"] = { latitude = 50.731247, longitude = 1.803067, display_name = "Alincthun"},
    ["Henneveux"] = { latitude = 50.723805, longitude = 1.851491, display_name = "Henneveux"},
    ["Menneville"] = { latitude = 50.675532, longitude = 1.861136, display_name = "Menneville"},
    ["Saint-Martin-Choquel"] = { latitude = 50.671384, longitude = 1.880557, display_name = "Saint-Martin-Choquel"},
    ["Senlecques"] = { latitude = 50.648719, longitude = 1.937276, display_name = "Senlecques"},
    ["Lottinghen"] = { latitude = 50.683841, longitude = 1.932854, display_name = "Lottinghen"},
    ["Quesques"] = { latitude = 50.704463, longitude = 1.934006, display_name = "Quesques"},
    ["Longueville"] = { latitude = 50.731896, longitude = 1.879146, display_name = "Longueville"},
    ["Nabringhen"] = { latitude = 50.743744, longitude = 1.863321, display_name = "Nabringhen"},
    ["Bournonville"] = { latitude = 50.706454, longitude = 1.850190, display_name = "Bournonville"},
    ["Bainghen"] = { latitude = 50.752865, longitude = 1.907283, display_name = "Bainghen"},
    ["Saint-Omer-Capelle"] = { latitude = 50.939181, longitude = 2.104024, display_name = "Saint-Omer-Capelle"},
    ["Vieille-Eglise"] = { latitude = 50.928821, longitude = 2.078158, display_name = "Vieille-Eglise"},
    ["Nouvelle-Eglise"] = { latitude = 50.924954, longitude = 2.053725, display_name = "Nouvelle-Eglise"},
    ["Offekerque"] = { latitude = 50.941212, longitude = 2.019745, display_name = "Offekerque"},
    ["Guemps"] = { latitude = 50.916922, longitude = 1.996767, display_name = "Guemps"},
    ["Nortkerque"] = { latitude = 50.876134, longitude = 2.025252, display_name = "Nortkerque"},
    ["Sainte-Marie-Kerque"] = { latitude = 50.900592, longitude = 2.137458, display_name = "Sainte-Marie-Kerque"},
    ["Zutkerque"] = { latitude = 50.853410, longitude = 2.067984, display_name = "Zutkerque"},
    ["Polincove"] = { latitude = 50.854509, longitude = 2.102259, display_name = "Polincove"},
    ["Ruminghem"] = { latitude = 50.860075, longitude = 2.157454, display_name = "Ruminghem"},
    ["Recques-sur-Hem"] = { latitude = 50.836537, longitude = 2.088250, display_name = "Recques-sur-Hem"},
    ["Muncq-Nieurlet"] = { latitude = 50.848774, longitude = 2.115295, display_name = "Muncq-Nieurlet"},
    ["Houlle"] = { latitude = 50.797741, longitude = 2.172855, display_name = "Houlle"},
    ["Moulle"] = { latitude = 50.788109, longitude = 2.175840, display_name = "Moulle"},
    ["Serques"] = { latitude = 50.793517, longitude = 2.202695, display_name = "Serques"},
    ["Tilques"] = { latitude = 50.777735, longitude = 2.205176, display_name = "Tilques"},
    ["Campagne-les-Boulonnais"] = { latitude = 50.613667, longitude = 1.996914, display_name = "Campagne-les-Boulonnais"},
    ["Coyecques"] = { latitude = 50.603247, longitude = 2.183082, display_name = "Coyecques"},
    ["Remilly-Wirquin"] = { latitude = 50.667494, longitude = 2.164347, display_name = "Remilly-Wirquin"},
    ["Acquin-Westbecourt"] = { latitude = 50.728756, longitude = 2.089946, display_name = "Acquin-Westbecourt"},
    ["Quercamps"] = { latitude = 50.753074, longitude = 2.051011, display_name = "Quercamps"},
    ["Bomy"] = { latitude = 50.572070, longitude = 2.234239, display_name = "Bomy"},
    ["Tournehem-sur-la-Hem"] = { latitude = 50.804719, longitude = 2.044890, display_name = "Tournehem-sur-la-Hem"},
    ["Coulomby"] = { latitude = 50.706189, longitude = 2.008824, display_name = "Coulomby"},
    ["Conteville-les-Boulogne"] = { latitude = 50.745072, longitude = 1.730434, display_name = "Conteville-les-Boulogne"},
    ["Widehem"] = { latitude = 50.585707, longitude = 1.672850, display_name = "Widehem"},
    ["Halinghen"] = { latitude = 50.602146, longitude = 1.691053, display_name = "Halinghen"},
    ["Carly"] = { latitude = 50.652045, longitude = 1.701175, display_name = "Carly"},
    ["Questrecques"] = { latitude = 50.664563, longitude = 1.746874, display_name = "Questrecques"},
    ["Hesdin-l'Abbe"] = { latitude = 50.667044, longitude = 1.680201, display_name = "Hesdin-l'Abbe"},
    ["Tubeauville"] = { latitude = 50.589381, longitude = 1.785342, display_name = "Tubeauville"},
    ["Parenty"] = { latitude = 50.588629, longitude = 1.810162, display_name = "Parenty"},
    ["Rety"] = { latitude = 50.796762, longitude = 1.774046, display_name = "Rety"},
    ["Le Bois-Julien"] = { latitude = 50.637308, longitude = 1.815147, display_name = "Le Bois-Julien"},
    ["Zouafques"] = { latitude = 50.816142, longitude = 2.054475, display_name = "Zouafques"},
    ["La Capelle-les-Boulogne"] = { latitude = 50.731180, longitude = 1.714619, display_name = "La Capelle-les-Boulogne"},
    ["Beuvrequen"] = { latitude = 50.801434, longitude = 1.665049, display_name = "Beuvrequen"},
    ["Heuringhem"] = { latitude = 50.696059, longitude = 2.283668, display_name = "Heuringhem"},
    ["Inghem"] = { latitude = 50.668344, longitude = 2.243240, display_name = "Inghem"},
    ["Therouanne"] = { latitude = 50.636334, longitude = 2.257719, display_name = "Therouanne"},
    ["Herbelles"] = { latitude = 50.655227, longitude = 2.222924, display_name = "Herbelles"},
    ["Pollinkhove"] = { latitude = 50.969266, longitude = 2.730865, display_name = "Pollinkhove"},
    ["Proven"] = { latitude = 50.890344, longitude = 2.654287, display_name = "Proven"},
    ["Roesbrugge-Haringe"] = { latitude = 50.915053, longitude = 2.626259, display_name = "Roesbrugge-Haringe"},
    ["Westvleteren"] = { latitude = 50.927286, longitude = 2.717444, display_name = "Westvleteren"},
    ["Oostvleteren"] = { latitude = 50.933701, longitude = 2.741004, display_name = "Oostvleteren"},
    ["Adinkerke"] = { latitude = 51.076216, longitude = 2.598567, display_name = "Adinkerke"},
    ["Avekapelle"] = { latitude = 51.066764, longitude = 2.733326, display_name = "Avekapelle"},
    ["Oostduinkerke"] = { latitude = 51.115634, longitude = 2.681266, display_name = "Oostduinkerke"},
    ["Sangatte"] = { latitude = 50.945804, longitude = 1.753713, display_name = "Sangatte"},
    ["Alquines"] = { latitude = 50.740526, longitude = 1.992636, display_name = "Alquines"},
    ["Amettes"] = { latitude = 50.531129, longitude = 2.394840, display_name = "Amettes"},
    ["Andres"] = { latitude = 50.863969, longitude = 1.914154, display_name = "Andres"},
    ["Auchy-au-Bois"] = { latitude = 50.555179, longitude = 2.371047, display_name = "Auchy-au-Bois"},
    ["Audincthun"] = { latitude = 50.582893, longitude = 2.143174, display_name = "Audincthun"},
    ["Avroult"] = { latitude = 50.633519, longitude = 2.146319, display_name = "Avroult"},
    ["Busnes"] = { latitude = 50.587892, longitude = 2.518470, display_name = "Busnes"},
    ["Witternesse"] = { latitude = 50.610836, longitude = 2.359894, display_name = "Witternesse"},
    ["Blessy"] = { latitude = 50.616305, longitude = 2.331492, display_name = "Blessy"},
    ["Bourecq"] = { latitude = 50.571648, longitude = 2.433932, display_name = "Bourecq"},
    ["Calonne-sur-la-Lys"] = { latitude = 50.623651, longitude = 2.615153, display_name = "Calonne-sur-la-Lys"},
    ["Clety"] = { latitude = 50.651854, longitude = 2.181948, display_name = "Clety"},
    ["Dennebroeucq"] = { latitude = 50.572489, longitude = 2.152864, display_name = "Dennebroeucq"},
    ["Ecquedecques"] = { latitude = 50.562119, longitude = 2.448703, display_name = "Ecquedecques"},
    ["Enguinegatte"] = { latitude = 50.607409, longitude = 2.271558, display_name = "Enguinegatte"},
    ["Enquin-les-Mines"] = { latitude = 50.588395, longitude = 2.286359, display_name = "Enquin-les-Mines"},
    ["Erny-Saint-Julien"] = { latitude = 50.585429, longitude = 2.253229, display_name = "Erny-Saint-Julien"},
    ["Essars"] = { latitude = 50.547241, longitude = 2.664094, display_name = "Essars"},
    ["Estree-Blanche"] = { latitude = 50.592872, longitude = 2.321795, display_name = "Estree-Blanche"},
    ["Festubert"] = { latitude = 50.542610, longitude = 2.736511, display_name = "Festubert"},
    ["Flechin"] = { latitude = 50.558738, longitude = 2.292781, display_name = "Flechin"},
    ["Guarbecque"] = { latitude = 50.609751, longitude = 2.488475, display_name = "Guarbecque"},
    ["Hames-Boucres"] = { latitude = 50.880241, longitude = 1.841748, display_name = "Hames-Boucres"},
    ["Ham-en-Artois"] = { latitude = 50.590203, longitude = 2.454749, display_name = "Ham-en-Artois"},
    ["Hinges"] = { latitude = 50.565461, longitude = 2.621913, display_name = "Hinges"},
    ["Le Maisnil-Boutry"] = { latitude = 50.644241, longitude = 2.002657, display_name = "Le Maisnil-Boutry"},
    ["Drionville"] = { latitude = 50.645111, longitude = 2.053126, display_name = "Drionville"},
    ["Lambres"] = { latitude = 50.617833, longitude = 2.395999, display_name = "Lambres"},
    ["Ledinghem"] = { latitude = 50.652450, longitude = 1.988667, display_name = "Ledinghem"},
    ["Liettres"] = { latitude = 50.595750, longitude = 2.341847, display_name = "Liettres"},
    ["Ligny-les-Aire"] = { latitude = 50.557335, longitude = 2.349206, display_name = "Ligny-les-Aire"},
    ["Linghem"] = { latitude = 50.595558, longitude = 2.371814, display_name = "Linghem"},
    ["Westrehem"] = { latitude = 50.545780, longitude = 2.345838, display_name = "Westrehem"},
    ["Mont-Bernanchon"] = { latitude = 50.593087, longitude = 2.602329, display_name = "Mont-Bernanchon"},
    ["Norrent-Fontes"] = { latitude = 50.585552, longitude = 2.410162, display_name = "Norrent-Fontes"},
    ["Merck-Saint-Lievin"] = { latitude = 50.627330, longitude = 2.114108, display_name = "Merck-Saint-Lievin"},
    ["Matringhem"] = { latitude = 50.545919, longitude = 2.165546, display_name = "Matringhem"},
    ["Quernes"] = { latitude = 50.605240, longitude = 2.363373, display_name = "Quernes"},
    ["Robecq"] = { latitude = 50.595018, longitude = 2.563650, display_name = "Robecq"},
    ["Saint-Floris"] = { latitude = 50.627363, longitude = 2.570130, display_name = "Saint-Floris"},
    ["Vieille-Chapelle"] = { latitude = 50.590701, longitude = 2.703245, display_name = "Vieille-Chapelle"},
    ["Renty"] = { latitude = 50.580661, longitude = 2.073618, display_name = "Renty"},
    ["Radinghem"] = { latitude = 50.553405, longitude = 2.122892, display_name = "Radinghem"},
    ["Rely"] = { latitude = 50.572872, longitude = 2.360502, display_name = "Rely"},
    ["Saint-Hilaire-Cottes"] = { latitude = 50.570344, longitude = 2.414031, display_name = "Saint-Hilaire-Cottes"},
    ["Senlis"] = { latitude = 50.533161, longitude = 2.152329, display_name = "Senlis"},
    ["Ecques"] = { latitude = 50.669543, longitude = 2.286275, display_name = "Ecques"},
    ["Clarques"] = { latitude = 50.646610, longitude = 2.276508, display_name = "Clarques"},
    ["Nielles-les-Blequin"] = { latitude = 50.673466, longitude = 2.030379, display_name = "Nielles-les-Blequin"},
    ["Delettes"] = { latitude = 50.618732, longitude = 2.213249, display_name = "Delettes"},
    ["Dohem"] = { latitude = 50.637767, longitude = 2.186722, display_name = "Dohem"},
    ["Setques"] = { latitude = 50.712219, longitude = 2.157863, display_name = "Setques"},
    ["Sainte-Cecile-Plage"] = { latitude = 50.574716, longitude = 1.582627, display_name = "Sainte-Cecile-Plage"},
    ["Inxent"] = { latitude = 50.535681, longitude = 1.784042, display_name = "Inxent"},
    ["Campagne-les-Guines"] = { latitude = 50.841095, longitude = 1.902068, display_name = "Campagne-les-Guines"},
    ["Peuplingues"] = { latitude = 50.915136, longitude = 1.769888, display_name = "Peuplingues"},
    ["Framezelle"] = { latitude = 50.863571, longitude = 1.592289, display_name = "Framezelle"},
    ["Wormhout"] = { latitude = 50.882763, longitude = 2.468733, display_name = "Wormhout"},
    ["Herzeele"] = { latitude = 50.886001, longitude = 2.531993, display_name = "Herzeele"},
    ["Le Grand Millebrugghe"] = { latitude = 50.965001, longitude = 2.347062, display_name = "Le Grand Millebrugghe"},
    ["Veurne"] = { latitude = 51.072427, longitude = 2.662132, display_name = "Veurne"},
    ["Moringhem"] = { latitude = 50.763120, longitude = 2.127110, display_name = "Moringhem"},
    ["Quelmes"] = { latitude = 50.732691, longitude = 2.136718, display_name = "Quelmes"},
    ["Leulinghem"] = { latitude = 50.734748, longitude = 2.164308, display_name = "Leulinghem"},
    ["Affringues"] = { latitude = 50.689861, longitude = 2.074325, display_name = "Affringues"},
    ["Bayenghem-les-Seninghem"] = { latitude = 50.699930, longitude = 2.075930, display_name = "Bayenghem-les-Seninghem"},
    ["Bernieulles"] = { latitude = 50.554600, longitude = 1.772850, display_name = "Bernieulles"},
    ["Bezinghem"] = { latitude = 50.593710, longitude = 1.825480, display_name = "Bezinghem"},
    ["Bimont"] = { latitude = 50.541460, longitude = 1.902770, display_name = "Bimont"},
    ["Blequin"] = { latitude = 50.663360, longitude = 1.989060, display_name = "Blequin"},
    ["Boisdinghem"] = { latitude = 50.748520, longitude = 2.093420, display_name = "Boisdinghem"},
    ["Bouvelinghem"] = { latitude = 50.734246, longitude = 2.034073, display_name = "Bouvelinghem"},
    ["Elnes"] = { latitude = 50.689520, longitude = 2.125570, display_name = "Elnes"},
    ["Enquin-sur-Baillons"] = { latitude = 50.572260, longitude = 1.835850, display_name = "Enquin-sur-Baillons"},
    ["Ergny"] = { latitude = 50.583410, longitude = 1.980800, display_name = "Ergny"},
    ["Escoeuilles"] = { latitude = 50.725650, longitude = 1.925600, display_name = "Escoeuilles"},
    ["Esquerdes"] = { latitude = 50.705520, longitude = 2.182975, display_name = "Esquerdes"},
    ["Haut-Loquin"] = { latitude = 50.739450, longitude = 1.966310, display_name = "Haut-Loquin"},
    ["Herly"] = { latitude = 50.546650, longitude = 1.985770, display_name = "Herly"},
    ["Mametz"] = { latitude = 50.634220, longitude = 2.324090, display_name = "Mametz"},
    ["Maninghem"] = { latitude = 50.542670, longitude = 1.939360, display_name = "Maninghem"},
    ["Ouve-Wirquin"] = { latitude = 50.650160, longitude = 2.143190, display_name = "Ouve-Wirquin"},
    ["Preures"] = { latitude = 50.571740, longitude = 1.876730, display_name = "Preures"},
    ["Rebecques"] = { latitude = 50.644890, longitude = 2.305600, display_name = "Rebecques"},
    ["Rumilly"] = { latitude = 50.576510, longitude = 2.014770, display_name = "Rumilly"},
    ["Seninghem"] = { latitude = 50.702354, longitude = 2.036721, display_name = "Seninghem"},
    ["Surques"] = { latitude = 50.739934, longitude = 1.916742, display_name = "Surques"},
    ["Verchocq"] = { latitude = 50.564189, longitude = 2.036242, display_name = "Verchocq"},
    ["Wavrans-sur-l'Aa"] = { latitude = 50.682410, longitude = 2.135580, display_name = "Wavrans-sur-l'Aa"},
    ["Wicquinghem"] = { latitude = 50.575170, longitude = 1.961230, display_name = "Wicquinghem"},
    ["Wismes"] = { latitude = 50.653230, longitude = 2.071140, display_name = "Wismes"},
    ["Zoteux"] = { latitude = 50.610360, longitude = 1.878690, display_name = "Zoteux"},
    ["Les Attaques"] = { latitude = 50.907231, longitude = 1.933694, display_name = "Les Attaques"},
    ["Nielles-les-Calais"] = { latitude = 50.907587, longitude = 1.829358, display_name = "Nielles-les-Calais"},
    ["Maninghen-Henne"] = { latitude = 50.768253, longitude = 1.668139, display_name = "Maninghen-Henne"},
    ["Hermelinghen"] = { latitude = 50.802584, longitude = 1.858957, display_name = "Hermelinghen"},
    ["Bouquehault"] = { latitude = 50.826595, longitude = 1.902510, display_name = "Bouquehault"},
    ["Alembon"] = { latitude = 50.784734, longitude = 1.887005, display_name = "Alembon"},
    ["Sanghen"] = { latitude = 50.776102, longitude = 1.900075, display_name = "Sanghen"},
    ["Balinghem"] = { latitude = 50.860659, longitude = 1.943506, display_name = "Balinghem"},
    ["Bremes"] = { latitude = 50.857017, longitude = 1.961340, display_name = "Bremes"},
    ["Rodelinghem"] = { latitude = 50.838050, longitude = 1.928728, display_name = "Rodelinghem"},
    ["Herbinghen"] = { latitude = 50.772682, longitude = 1.912526, display_name = "Herbinghen"},
    ["Licques"] = { latitude = 50.784662, longitude = 1.931790, display_name = "Licques"},
    ["Nielles-les-Ardres"] = { latitude = 50.842190, longitude = 2.016594, display_name = "Nielles-les-Ardres"},
    ["Autingues"] = { latitude = 50.842121, longitude = 1.985072, display_name = "Autingues"},
    ["Louches"] = { latitude = 50.829819, longitude = 2.004976, display_name = "Louches"},
    ["Hocquinghen"] = { latitude = 50.769037, longitude = 1.937095, display_name = "Hocquinghen"},
    ["Clerques"] = { latitude = 50.793353, longitude = 1.993673, display_name = "Clerques"},
    ["Audrehem"] = { latitude = 50.781378, longitude = 1.989835, display_name = "Audrehem"},
    ["Bonningues-les-Ardres"] = { latitude = 50.791896, longitude = 2.013201, display_name = "Bonningues-les-Ardres"},
    ["Rebergues"] = { latitude = 50.754289, longitude = 1.958913, display_name = "Rebergues"},
    ["Journy"] = { latitude = 50.753379, longitude = 1.994703, display_name = "Journy"},
    ["Nordausques"] = { latitude = 50.818666, longitude = 2.079704, display_name = "Nordausques"},
    ["Nort-Leulinghem"] = { latitude = 50.801674, longitude = 2.092434, display_name = "Nort-Leulinghem"},
    ["Bayenghem-les-Eperlecques"] = { latitude = 50.806406, longitude = 2.125144, display_name = "Bayenghem-les-Eperlecques"},
    ["Mentque-Nortbecourt"] = { latitude = 50.769882, longitude = 2.090772, display_name = "Mentque-Nortbecourt"},
    ["Zudausques"] = { latitude = 50.749725, longitude = 2.149092, display_name = "Zudausques"},
    ["Vaudringhem"] = { latitude = 50.661744, longitude = 2.029476, display_name = "Vaudringhem"},
    ["Campagne-les-Wardrecques"] = { latitude = 50.717803, longitude = 2.333551, display_name = "Campagne-les-Wardrecques"},
    ["Longfosse"] = { latitude = 50.651674, longitude = 1.805305, display_name = "Longfosse"},
    ["Wierre-au-Bois"] = { latitude = 50.645164, longitude = 1.762960, display_name = "Wierre-au-Bois"},
    ["Tingry"] = { latitude = 50.618031, longitude = 1.730393, display_name = "Tingry"},
    ["Lacres"] = { latitude = 50.600977, longitude = 1.761913, display_name = "Lacres"},
    ["Becourt"] = { latitude = 50.638133, longitude = 1.910800, display_name = "Becourt"},
    ["Hubersent"] = { latitude = 50.581108, longitude = 1.726437, display_name = "Hubersent"},
    ["Frencq"] = { latitude = 50.561810, longitude = 1.699536, display_name = "Frencq"},
    ["Cormont"] = { latitude = 50.561374, longitude = 1.735293, display_name = "Cormont"},
    ["Lefaux"] = { latitude = 50.542416, longitude = 1.659116, display_name = "Lefaux"},
    ["Longvilliers"] = { latitude = 50.543611, longitude = 1.727947, display_name = "Longvilliers"},
    ["Beussent"] = { latitude = 50.545930, longitude = 1.795064, display_name = "Beussent"},
    ["Avesnes"] = { latitude = 50.550698, longitude = 1.969351, display_name = "Avesnes"},
    ["Reclinghem"] = { latitude = 50.572213, longitude = 2.174423, display_name = "Reclinghem"},
    ["Vincly"] = { latitude = 50.559224, longitude = 2.171241, display_name = "Vincly"},
    ["Ames"] = { latitude = 50.536715, longitude = 2.408654, display_name = "Ames"},
    ["Lespesses"] = { latitude = 50.563281, longitude = 2.422028, display_name = "Lespesses"},
    ["Lieres"] = { latitude = 50.554453, longitude = 2.417038, display_name = "Lieres"},
    ["Mazinghem"] = { latitude = 50.601999, longitude = 2.405251, display_name = "Mazinghem"},
    ["Rombly"] = { latitude = 50.596850, longitude = 2.388703, display_name = "Rombly"},
    ["Oblinghem"] = { latitude = 50.549723, longitude = 2.599434, display_name = "Oblinghem"},
    ["Landrethun-les-Ardres"] = { latitude = 50.825020, longitude = 1.960463, display_name = "Landrethun-les-Ardres"},
    ["Audenfort"] = { latitude = 50.783137, longitude = 1.970780, display_name = "Audenfort"},
    ["Mentque"] = { latitude = 50.783977, longitude = 2.085649, display_name = "Mentque"},
    ["Pihem"] = { latitude = 50.682756, longitude = 2.213203, display_name = "Pihem"},
    ["Wandonne"] = { latitude = 50.564399, longitude = 2.126731, display_name = "Wandonne"},
    ["Cuhem"] = { latitude = 50.569579, longitude = 2.277348, display_name = "Cuhem"},
    ["Le Clivet"] = { latitude = 50.567150, longitude = 1.888315, display_name = "Le Clivet"},
    ["Wimereux"] = { latitude = 50.769686, longitude = 1.611861, display_name = "Wimereux"},
    ["Thiembronne"] = { latitude = 50.621035, longitude = 2.058926, display_name = "Thiembronne"},
    ["Outtersteene"] = { latitude = 50.712098, longitude = 2.682043, display_name = "Outtersteene"},
    ["Salperwick"] = { latitude = 50.771874, longitude = 2.230078, display_name = "Salperwick"},
    ["Noeux-les-Mines"] = { latitude = 50.475400, longitude = 2.662190, display_name = "Noeux-les-Mines"},
    ["Bethune"] = { latitude = 50.519900, longitude = 2.647810, display_name = "Bethune"},
    ["Abbeville"] = { latitude = 50.106083, longitude = 1.833703, display_name = "Abbeville"},
    ["Etaples"] = { latitude = 50.513955, longitude = 1.638625, display_name = "Etaples"},
    ["Albert"] = { latitude = 50.001802, longitude = 2.650922, display_name = "Albert"},
    ["Berck"] = { latitude = 50.405258, longitude = 1.571162, display_name = "Berck"},
    ["Dieppe"] = { latitude = 49.924618, longitude = 1.079144, display_name = "Dieppe"},
    ["Bruay-la-Buissiere"] = { latitude = 50.482196, longitude = 2.546192, display_name = "Bruay-la-Buissiere"},
    ["Auchel"] = { latitude = 50.503749, longitude = 2.468206, display_name = "Auchel"},
    ["Gamaches"] = { latitude = 49.985523, longitude = 1.555718, display_name = "Gamaches"},
    ["Avesnes-le-Comte"] = { latitude = 50.276202, longitude = 2.527700, display_name = "Avesnes-le-Comte"},
    ["Blangy-sur-Bresle"] = { latitude = 49.932376, longitude = 1.629683, display_name = "Blangy-sur-Bresle"},
    ["Flesselles"] = { latitude = 50.004900, longitude = 2.263360, display_name = "Flesselles"},
    ["Hesdin"] = { latitude = 50.373000, longitude = 2.036614, display_name = "Hesdin"},
    ["Doullens"] = { latitude = 50.157209, longitude = 2.341053, display_name = "Doullens"},
    ["Saint-Valery-sur-Somme"] = { latitude = 50.188701, longitude = 1.627915, display_name = "Saint-Valery-sur-Somme"},
    ["Haillicourt"] = { latitude = 50.475100, longitude = 2.577930, display_name = "Haillicourt"},
    ["Beauval"] = { latitude = 50.106225, longitude = 2.331653, display_name = "Beauval"},
    ["Mers-les-Bains"] = { latitude = 50.065632, longitude = 1.388970, display_name = "Mers-les-Bains"},
    ["Feuquieres-en-Vimeu"] = { latitude = 50.060937, longitude = 1.609549, display_name = "Feuquieres-en-Vimeu"},
    ["Barlin"] = { latitude = 50.456836, longitude = 2.617477, display_name = "Barlin"},
    ["Fressenneville"] = { latitude = 50.068204, longitude = 1.575208, display_name = "Fressenneville"},
    ["Ault"] = { latitude = 50.101564, longitude = 1.447301, display_name = "Ault"},
    ["Hersin-Coupigny"] = { latitude = 50.447236, longitude = 2.648495, display_name = "Hersin-Coupigny"},
    ["Merlimont"] = { latitude = 50.455808, longitude = 1.613436, display_name = "Merlimont"},
    ["Cayeux-sur-Mer"] = { latitude = 50.179200, longitude = 1.493384, display_name = "Cayeux-sur-Mer"},
    ["Saint-Ouen"] = { latitude = 50.036830, longitude = 2.122374, display_name = "Saint-Ouen"},
    ["Frevent"] = { latitude = 50.278213, longitude = 2.292979, display_name = "Frevent"},
    ["Verquin"] = { latitude = 50.501142, longitude = 2.641114, display_name = "Verquin"},
    ["Auxi-le-Chateau"] = { latitude = 50.231491, longitude = 2.117761, display_name = "Auxi-le-Chateau"},
    ["Friville-Escarbotin"] = { latitude = 50.086995, longitude = 1.545222, display_name = "Friville-Escarbotin"},
    ["Divion"] = { latitude = 50.469400, longitude = 2.507220, display_name = "Divion"},
    ["Le Touquet-Paris-Plage"] = { latitude = 50.521120, longitude = 1.590932, display_name = "Le Touquet-Paris-Plage"},
    ["Saint-Pol-sur-Ternoise"] = { latitude = 50.381211, longitude = 2.336105, display_name = "Saint-Pol-sur-Ternoise"},
    ["Lapugnoy"] = { latitude = 50.520400, longitude = 2.534200, display_name = "Lapugnoy"},
    ["Flixecourt"] = { latitude = 50.011710, longitude = 2.082582, display_name = "Flixecourt"},
    ["Rang-du-Fliers"] = { latitude = 50.416897, longitude = 1.643935, display_name = "Rang-du-Fliers"},
    ["Criel-sur-Mer"] = { latitude = 50.016093, longitude = 1.313944, display_name = "Criel-sur-Mer"},
    ["Eu"] = { latitude = 50.049170, longitude = 1.417574, display_name = "Eu"},
    ["Ailly-sur-Somme"] = { latitude = 49.928085, longitude = 2.198100, display_name = "Ailly-sur-Somme"},
    ["Labourse"] = { latitude = 50.497298, longitude = 2.679865, display_name = "Labourse"},
    ["Montreuil"] = { latitude = 50.463892, longitude = 1.763113, display_name = "Montreuil"},
    ["Marles-les-Mines"] = { latitude = 50.501949, longitude = 2.506041, display_name = "Marles-les-Mines"},
    ["Cauchy-a-la-Tour"] = { latitude = 50.503104, longitude = 2.452112, display_name = "Cauchy-a-la-Tour"},
    ["Bouvigny-Boyeffles"] = { latitude = 50.421195, longitude = 2.672681, display_name = "Bouvigny-Boyeffles"},
    ["Fruges"] = { latitude = 50.515039, longitude = 2.134929, display_name = "Fruges"},
    ["Sains-en-Gohelle"] = { latitude = 50.447328, longitude = 2.683388, display_name = "Sains-en-Gohelle"},
    ["Airaines"] = { latitude = 49.966270, longitude = 1.941064, display_name = "Airaines"},
    ["Wailly-Beaucamp"] = { latitude = 50.410866, longitude = 1.726233, display_name = "Wailly-Beaucamp"},
    ["Azincourt"] = { latitude = 50.463383, longitude = 2.128827, display_name = "Azincourt"},
    ["Tortefontaine"] = { latitude = 50.322728, longitude = 1.923292, display_name = "Tortefontaine"},
    ["Saulchoy"] = { latitude = 50.349999, longitude = 1.850295, display_name = "Saulchoy"},
    ["Douriez"] = { latitude = 50.332920, longitude = 1.877159, display_name = "Douriez"},
    ["Maintenay"] = { latitude = 50.366386, longitude = 1.813077, display_name = "Maintenay"},
    ["Roussent"] = { latitude = 50.368082, longitude = 1.777043, display_name = "Roussent"},
    ["Nempont-Saint-Firmin"] = { latitude = 50.355394, longitude = 1.732144, display_name = "Nempont-Saint-Firmin"},
    ["Gouy-Saint-Andre"] = { latitude = 50.373606, longitude = 1.900334, display_name = "Gouy-Saint-Andre"},
    ["Mouriez"] = { latitude = 50.340945, longitude = 1.947197, display_name = "Mouriez"},
    ["Bertangles"] = { latitude = 49.970940, longitude = 2.299291, display_name = "Bertangles"},
    ["Villers-Bocage"] = { latitude = 49.995675, longitude = 2.314198, display_name = "Villers-Bocage"},
    ["Molliens-au-Bois"] = { latitude = 49.989616, longitude = 2.385043, display_name = "Molliens-au-Bois"},
    ["Montigny-sur-l'Hallue"] = { latitude = 49.980230, longitude = 2.443205, display_name = "Montigny-sur-l'Hallue"},
    ["Behencourt"] = { latitude = 49.974472, longitude = 2.451315, display_name = "Behencourt"},
    ["Pont-Noyelles"] = { latitude = 49.939781, longitude = 2.440894, display_name = "Pont-Noyelles"},
    ["Querrieu"] = { latitude = 49.939113, longitude = 2.431445, display_name = "Querrieu"},
    ["Enocq"] = { latitude = 50.498729, longitude = 1.703481, display_name = "Enocq"},
    ["Lucheux"] = { latitude = 50.196945, longitude = 2.411534, display_name = "Lucheux"},
    ["Cambligneul"] = { latitude = 50.379859, longitude = 2.615773, display_name = "Cambligneul"},
    ["Lahoussoye"] = { latitude = 49.952856, longitude = 2.483167, display_name = "Lahoussoye"},
    ["Bonnay"] = { latitude = 49.934650, longitude = 2.512065, display_name = "Bonnay"},
    ["Picquigny"] = { latitude = 49.944326, longitude = 2.141807, display_name = "Picquigny"},
    ["Hallencourt"] = { latitude = 49.992824, longitude = 1.876855, display_name = "Hallencourt"},
    ["Lisbourg"] = { latitude = 50.507259, longitude = 2.216503, display_name = "Lisbourg"},
    ["Verchin"] = { latitude = 50.494047, longitude = 2.184971, display_name = "Verchin"},
    ["Lugy"] = { latitude = 50.523288, longitude = 2.173914, display_name = "Lugy"},
    ["Heuchin"] = { latitude = 50.474619, longitude = 2.269143, display_name = "Heuchin"},
    ["Bergueneuse"] = { latitude = 50.468606, longitude = 2.253501, display_name = "Bergueneuse"},
    ["Anvin"] = { latitude = 50.446435, longitude = 2.252243, display_name = "Anvin"},
    ["Monchy-Cayeux"] = { latitude = 50.436459, longitude = 2.278342, display_name = "Monchy-Cayeux"},
    ["Wavrans-sur-Ternoise"] = { latitude = 50.414381, longitude = 2.299602, display_name = "Wavrans-sur-Ternoise"},
    ["Hernicourt"] = { latitude = 50.407907, longitude = 2.304976, display_name = "Hernicourt"},
    ["Gauchin-Verloingt"] = { latitude = 50.395392, longitude = 2.312410, display_name = "Gauchin-Verloingt"},
    ["Fiefs"] = { latitude = 50.503443, longitude = 2.328885, display_name = "Fiefs"},
    ["Tangry"] = { latitude = 50.465104, longitude = 2.354806, display_name = "Tangry"},
    ["Valhuon"] = { latitude = 50.435419, longitude = 2.375445, display_name = "Valhuon"},
    ["Brias"] = { latitude = 50.409802, longitude = 2.378303, display_name = "Brias"},
    ["Pernes"] = { latitude = 50.484100, longitude = 2.410092, display_name = "Pernes"},
    ["Fontaine-les-Boulans"] = { latitude = 50.498360, longitude = 2.275293, display_name = "Fontaine-les-Boulans"},
    ["Naours"] = { latitude = 50.034144, longitude = 2.274822, display_name = "Naours"},
    ["Ramecourt"] = { latitude = 50.370249, longitude = 2.314578, display_name = "Ramecourt"},
    ["Le Parcq"] = { latitude = 50.379561, longitude = 2.099157, display_name = "Le Parcq"},
    ["Huby-Saint-Leu"] = { latitude = 50.381317, longitude = 2.037182, display_name = "Huby-Saint-Leu"},
    ["Marconne"] = { latitude = 50.370368, longitude = 2.045287, display_name = "Marconne"},
    ["Regnauville"] = { latitude = 50.313621, longitude = 2.013962, display_name = "Regnauville"},
    ["Le Boisle"] = { latitude = 50.271777, longitude = 1.985295, display_name = "Le Boisle"},
    ["Froyelles"] = { latitude = 50.226877, longitude = 1.929308, display_name = "Froyelles"},
    ["Drucat"] = { latitude = 50.141850, longitude = 1.868445, display_name = "Drucat"},
    ["Grand-Laviers"] = { latitude = 50.128684, longitude = 1.785705, display_name = "Grand-Laviers"},
    ["Ville-le-Marclet"] = { latitude = 50.022943, longitude = 2.088392, display_name = "Ville-le-Marclet"},
    ["Saint-Leger-les-Domart"] = { latitude = 50.053579, longitude = 2.139729, display_name = "Saint-Leger-les-Domart"},
    ["Domart-en-Ponthieu"] = { latitude = 50.074166, longitude = 2.126317, display_name = "Domart-en-Ponthieu"},
    ["La Calotterie"] = { latitude = 50.475205, longitude = 1.726325, display_name = "La Calotterie"},
    ["Dernancourt"] = { latitude = 49.973252, longitude = 2.631678, display_name = "Dernancourt"},
    ["Buire-sur-l'Ancre"] = { latitude = 49.965182, longitude = 2.592539, display_name = "Buire-sur-l'Ancre"},
    ["Ribemont-sur-Ancre"] = { latitude = 49.960156, longitude = 2.565479, display_name = "Ribemont-sur-Ancre"},
    ["Mericourt-l'Abbe"] = { latitude = 49.952297, longitude = 2.563810, display_name = "Mericourt-l'Abbe"},
    ["Ancourt"] = { latitude = 49.910934, longitude = 1.179063, display_name = "Ancourt"},
    ["Arrest"] = { latitude = 50.126994, longitude = 1.616619, display_name = "Arrest"},
    ["Rubempre"] = { latitude = 50.018360, longitude = 2.384620, display_name = "Rubempre"},
    ["Estreboeuf"] = { latitude = 50.156111, longitude = 1.615395, display_name = "Estreboeuf"},
    ["Boismont"] = { latitude = 50.153208, longitude = 1.684135, display_name = "Boismont"},
    ["Crecy-en-Ponthieu"] = { latitude = 50.252146, longitude = 1.884066, display_name = "Crecy-en-Ponthieu"},
    ["Nouvion"] = { latitude = 50.212477, longitude = 1.777915, display_name = "Nouvion"},
    ["Saint-Martin-en-Campagne"] = { latitude = 49.956823, longitude = 1.221892, display_name = "Saint-Martin-en-Campagne"},
    ["Grandcourt"] = { latitude = 49.913749, longitude = 1.491097, display_name = "Grandcourt"},
    ["Le Treport"] = { latitude = 50.059110, longitude = 1.382766, display_name = "Le Treport"},
    ["Le Crotoy"] = { latitude = 50.216569, longitude = 1.624047, display_name = "Le Crotoy"},
    ["Estree"] = { latitude = 50.499322, longitude = 1.791475, display_name = "Estree"},
    ["Montcavrel"] = { latitude = 50.514675, longitude = 1.810636, display_name = "Montcavrel"},
    ["Marles-sur-Canche"] = { latitude = 50.458151, longitude = 1.826960, display_name = "Marles-sur-Canche"},
    ["Saint-Josse"] = { latitude = 50.467477, longitude = 1.663984, display_name = "Saint-Josse"},
    ["Saint-Aubin"] = { latitude = 50.457369, longitude = 1.665185, display_name = "Saint-Aubin"},
    ["Sorrus"] = { latitude = 50.456844, longitude = 1.715139, display_name = "Sorrus"},
    ["Brimeux"] = { latitude = 50.445700, longitude = 1.834628, display_name = "Brimeux"},
    ["Campigneulles-les-Petites"] = { latitude = 50.444800, longitude = 1.733805, display_name = "Campigneulles-les-Petites"},
    ["Bouzincourt"] = { latitude = 50.026323, longitude = 2.610171, display_name = "Bouzincourt"},
    ["Vacqueriette-Erquieres"] = { latitude = 50.322689, longitude = 2.078418, display_name = "Vacqueriette-Erquieres"},
    ["Miannay"] = { latitude = 50.097549, longitude = 1.717694, display_name = "Miannay"},
    ["Valines"] = { latitude = 50.076011, longitude = 1.621392, display_name = "Valines"},
    ["Epagne-Epagnette"] = { latitude = 50.073673, longitude = 1.870325, display_name = "Epagne-Epagnette"},
    ["Eaucourt-sur-Somme"] = { latitude = 50.064496, longitude = 1.884941, display_name = "Eaucourt-sur-Somme"},
    ["Ailly-le-Haut-Clocher"] = { latitude = 50.076495, longitude = 1.992357, display_name = "Ailly-le-Haut-Clocher"},
    ["Pont-Remy"] = { latitude = 50.055774, longitude = 1.901735, display_name = "Pont-Remy"},
    ["Canaples"] = { latitude = 50.056802, longitude = 2.218586, display_name = "Canaples"},
    ["Havernas"] = { latitude = 50.036637, longitude = 2.233241, display_name = "Havernas"},
    ["Halloy-les-Pernois"] = { latitude = 50.050258, longitude = 2.201617, display_name = "Halloy-les-Pernois"},
    ["Berteaucourt-les-Dames"] = { latitude = 50.045899, longitude = 2.153166, display_name = "Berteaucourt-les-Dames"},
    ["Woignarue"] = { latitude = 50.109473, longitude = 1.494677, display_name = "Woignarue"},
    ["Ponthoile"] = { latitude = 50.215635, longitude = 1.711600, display_name = "Ponthoile"},
    ["Noyelles-sur-Mer"] = { latitude = 50.182840, longitude = 1.707460, display_name = "Noyelles-sur-Mer"},
    ["Cambron"] = { latitude = 50.111747, longitude = 1.769661, display_name = "Cambron"},
    ["Morlancourt"] = { latitude = 49.950469, longitude = 2.628832, display_name = "Morlancourt"},
    ["Etinehem-Mericourt"] = { latitude = 49.927788, longitude = 2.688331, display_name = "Etinehem-Mericourt"},
    ["Franvillers"] = { latitude = 49.966473, longitude = 2.507860, display_name = "Franvillers"},
    ["Ville-sur-Ancre"] = { latitude = 49.961707, longitude = 2.610144, display_name = "Ville-sur-Ancre"},
    ["Moyenneville"] = { latitude = 50.070794, longitude = 1.749657, display_name = "Moyenneville"},
    ["Yonval"] = { latitude = 50.089952, longitude = 1.789253, display_name = "Yonval"},
    ["Franleu"] = { latitude = 50.098909, longitude = 1.639044, display_name = "Franleu"},
    ["Acheux-en-Vimeu"] = { latitude = 50.064489, longitude = 1.675123, display_name = "Acheux-en-Vimeu"},
    ["Beaucourt-sur-l'Hallue"] = { latitude = 49.986218, longitude = 2.444484, display_name = "Beaucourt-sur-l'Hallue"},
    ["Varennes"] = { latitude = 50.049134, longitude = 2.534710, display_name = "Varennes"},
    ["Senlis-le-Sec"] = { latitude = 50.024504, longitude = 2.578660, display_name = "Senlis-le-Sec"},
    ["Bertrancourt"] = { latitude = 50.093358, longitude = 2.555917, display_name = "Bertrancourt"},
    ["Bus-les-Artois"] = { latitude = 50.104208, longitude = 2.541676, display_name = "Bus-les-Artois"},
    ["Authie"] = { latitude = 50.120757, longitude = 2.489984, display_name = "Authie"},
    ["Marieux"] = { latitude = 50.106205, longitude = 2.441478, display_name = "Marieux"},
    ["Louvencourt"] = { latitude = 50.094201, longitude = 2.499360, display_name = "Louvencourt"},
    ["Vauchelles-les-Authie"] = { latitude = 50.095571, longitude = 2.473944, display_name = "Vauchelles-les-Authie"},
    ["Raincheval"] = { latitude = 50.073792, longitude = 2.437531, display_name = "Raincheval"},
    ["Arqueves"] = { latitude = 50.071686, longitude = 2.469114, display_name = "Arqueves"},
    ["Acheux-en-Amienois"] = { latitude = 50.072899, longitude = 2.530620, display_name = "Acheux-en-Amienois"},
    ["Puchevillers"] = { latitude = 50.054352, longitude = 2.409105, display_name = "Puchevillers"},
    ["Beauquesne"] = { latitude = 50.084686, longitude = 2.394203, display_name = "Beauquesne"},
    ["Terramesnil"] = { latitude = 50.106253, longitude = 2.379393, display_name = "Terramesnil"},
    ["Humbercourt"] = { latitude = 50.210223, longitude = 2.454904, display_name = "Humbercourt"},
    ["Brevillers"] = { latitude = 50.215587, longitude = 2.376572, display_name = "Brevillers"},
    ["Grouches-Luchuel"] = { latitude = 50.179760, longitude = 2.381204, display_name = "Grouches-Luchuel"},
    ["Neuvillette"] = { latitude = 50.209127, longitude = 2.319330, display_name = "Neuvillette"},
    ["Bouquemaison"] = { latitude = 50.211581, longitude = 2.335495, display_name = "Bouquemaison"},
    ["Le Souich"] = { latitude = 50.222057, longitude = 2.367014, display_name = "Le Souich"},
    ["Allonville"] = { latitude = 49.939767, longitude = 2.364224, display_name = "Allonville"},
    ["Meaulte"] = { latitude = 49.983122, longitude = 2.664155, display_name = "Meaulte"},
    ["Saint-Sauveur"] = { latitude = 49.938093, longitude = 2.212011, display_name = "Saint-Sauveur"},
    ["Dreuil-les-Amiens"] = { latitude = 49.914115, longitude = 2.233500, display_name = "Dreuil-les-Amiens"},
    ["Quesnoy-sur-Airaines"] = { latitude = 49.956626, longitude = 1.990594, display_name = "Quesnoy-sur-Airaines"},
    ["Saint-Vaast-en-Chaussee"] = { latitude = 49.969551, longitude = 2.204214, display_name = "Saint-Vaast-en-Chaussee"},
    ["Vaux-en-Amienois"] = { latitude = 49.962606, longitude = 2.247945, display_name = "Vaux-en-Amienois"},
    ["Poulainville"] = { latitude = 49.947348, longitude = 2.311602, display_name = "Poulainville"},
    ["Coisy"] = { latitude = 49.959888, longitude = 2.326859, display_name = "Coisy"},
    ["Cardonnette"] = { latitude = 49.952245, longitude = 2.359868, display_name = "Cardonnette"},
    ["Rainneville"] = { latitude = 49.972235, longitude = 2.355317, display_name = "Rainneville"},
    ["Contay"] = { latitude = 50.005329, longitude = 2.478641, display_name = "Contay"},
    ["Warloy-Baillon"] = { latitude = 50.010790, longitude = 2.522951, display_name = "Warloy-Baillon"},
    ["Baizieux"] = { latitude = 49.992474, longitude = 2.518960, display_name = "Baizieux"},
    ["Henencourt"] = { latitude = 50.002171, longitude = 2.563231, display_name = "Henencourt"},
    ["Millencourt"] = { latitude = 50.000761, longitude = 2.587326, display_name = "Millencourt"},
    ["Mailly-Maillet"] = { latitude = 50.079767, longitude = 2.604249, display_name = "Mailly-Maillet"},
    ["Vaire-sous-Corbie"] = { latitude = 49.914717, longitude = 2.546964, display_name = "Vaire-sous-Corbie"},
    ["Heilly"] = { latitude = 49.953015, longitude = 2.536172, display_name = "Heilly"},
    ["Sailly-le-Sec"] = { latitude = 49.920759, longitude = 2.582747, display_name = "Sailly-le-Sec"},
    ["Sailly-Laurette"] = { latitude = 49.912221, longitude = 2.606709, display_name = "Sailly-Laurette"},
    ["Oisemont"] = { latitude = 49.956082, longitude = 1.764936, display_name = "Oisemont"},
    ["Allery"] = { latitude = 49.963050, longitude = 1.897986, display_name = "Allery"},
    ["Colline-Beaumont"] = { latitude = 50.339831, longitude = 1.680815, display_name = "Colline-Beaumont"},
    ["Fort-Mahon-Plage"] = { latitude = 50.341429, longitude = 1.568313, display_name = "Fort-Mahon-Plage"},
    ["Talmas"] = { latitude = 50.029580, longitude = 2.325057, display_name = "Talmas"},
    ["Neuilly-l'Hopital"] = { latitude = 50.170034, longitude = 1.878572, display_name = "Neuilly-l'Hopital"},
    ["Riencourt"] = { latitude = 49.922113, longitude = 2.050381, display_name = "Riencourt"},
    ["Cavillon"] = { latitude = 49.921717, longitude = 2.083588, display_name = "Cavillon"},
    ["Belloy-sur-Somme"] = { latitude = 49.966846, longitude = 2.135439, display_name = "Belloy-sur-Somme"},
    ["Warlus"] = { latitude = 50.275515, longitude = 2.668715, display_name = "Warlus"},
    ["Willencourt"] = { latitude = 50.238886, longitude = 2.091478, display_name = "Willencourt"},
    ["Acq"] = { latitude = 50.348457, longitude = 2.655962, display_name = "Acq"},
    ["Agnieres"] = { latitude = 50.355059, longitude = 2.607809, display_name = "Agnieres"},
    ["Aix-en-Issart"] = { latitude = 50.475171, longitude = 1.858967, display_name = "Aix-en-Issart"},
    ["Ambricourt"] = { latitude = 50.467973, longitude = 2.175626, display_name = "Ambricourt"},
    ["Ambrines"] = { latitude = 50.310247, longitude = 2.468694, display_name = "Ambrines"},
    ["Aubigny-en-Artois"] = { latitude = 50.351595, longitude = 2.589628, display_name = "Aubigny-en-Artois"},
    ["Aubin-Saint-Vaast"] = { latitude = 50.397660, longitude = 1.974479, display_name = "Aubin-Saint-Vaast"},
    ["Aubrometz"] = { latitude = 50.304194, longitude = 2.177230, display_name = "Aubrometz"},
    ["Bailleul-aux-Cornailles"] = { latitude = 50.371330, longitude = 2.443230, display_name = "Bailleul-aux-Cornailles"},
    ["Bajus"] = { latitude = 50.421067, longitude = 2.481147, display_name = "Bajus"},
    ["Le Titre"] = { latitude = 50.188785, longitude = 1.798457, display_name = "Le Titre"},
    ["Beaumetz-les-Loges"] = { latitude = 50.243641, longitude = 2.655521, display_name = "Beaumetz-les-Loges"},
    ["Berneville"] = { latitude = 50.265960, longitude = 2.670953, display_name = "Berneville"},
    ["Bethonsart"] = { latitude = 50.375325, longitude = 2.551191, display_name = "Bethonsart"},
    ["Beugin"] = { latitude = 50.442082, longitude = 2.514646, display_name = "Beugin"},
    ["Bienvillers-au-Bois"] = { latitude = 50.174926, longitude = 2.620271, display_name = "Bienvillers-au-Bois"},
    ["Boisjean"] = { latitude = 50.407192, longitude = 1.767314, display_name = "Boisjean"},
    ["Bouin-Plumoison"] = { latitude = 50.381981, longitude = 1.988686, display_name = "Bouin-Plumoison"},
    ["Buire-au-Bois"] = { latitude = 50.262317, longitude = 2.152020, display_name = "Buire-au-Bois"},
    ["Buire-le-Sec"] = { latitude = 50.381962, longitude = 1.832624, display_name = "Buire-le-Sec"},
    ["Crequy"] = { latitude = 50.494717, longitude = 2.046920, display_name = "Crequy"},
    ["Carency"] = { latitude = 50.378876, longitude = 2.703589, display_name = "Carency"},
    ["Campagne-les-Hesdin"] = { latitude = 50.398470, longitude = 1.878694, display_name = "Campagne-les-Hesdin"},
    ["Camblain-Chatelain"] = { latitude = 50.482288, longitude = 2.463744, display_name = "Camblain-Chatelain"},
    ["Camblain-l'Abbe"] = { latitude = 50.371375, longitude = 2.632892, display_name = "Camblain-l'Abbe"},
    ["Canlers"] = { latitude = 50.482216, longitude = 2.142202, display_name = "Canlers"},
    ["Capelle-les-Hesdin"] = { latitude = 50.341267, longitude = 1.998372, display_name = "Capelle-les-Hesdin"},
    ["Caucourt"] = { latitude = 50.399633, longitude = 2.570931, display_name = "Caucourt"},
    ["Chelers"] = { latitude = 50.375943, longitude = 2.484191, display_name = "Chelers"},
    ["Coullemont"] = { latitude = 50.214546, longitude = 2.471392, display_name = "Coullemont"},
    ["Couturelle"] = { latitude = 50.207486, longitude = 2.499051, display_name = "Couturelle"},
    ["Crepy"] = { latitude = 50.472526, longitude = 2.201140, display_name = "Crepy"},
    ["Drouvin-le-Marais"] = { latitude = 50.493415, longitude = 2.627614, display_name = "Drouvin-le-Marais"},
    ["Embry"] = { latitude = 50.492782, longitude = 1.967237, display_name = "Embry"},
    ["Estree-Cauchy"] = { latitude = 50.398375, longitude = 2.608935, display_name = "Estree-Cauchy"},
    ["Etrun"] = { latitude = 50.314529, longitude = 2.700925, display_name = "Etrun"},
    ["Wamin"] = { latitude = 50.413414, longitude = 2.058777, display_name = "Wamin"},
    ["Fressin"] = { latitude = 50.446563, longitude = 2.055354, display_name = "Fressin"},
    ["Ferfay"] = { latitude = 50.519583, longitude = 2.422769, display_name = "Ferfay"},
    ["Foncquevillers"] = { latitude = 50.148739, longitude = 2.631933, display_name = "Foncquevillers"},
    ["Fouquereuil"] = { latitude = 50.518441, longitude = 2.600400, display_name = "Fouquereuil"},
    ["Fouquieres-les-Bethune"] = { latitude = 50.514124, longitude = 2.611136, display_name = "Fouquieres-les-Bethune"},
    ["Frevillers"] = { latitude = 50.397655, longitude = 2.518940, display_name = "Frevillers"},
    ["Frevin-Capelle"] = { latitude = 50.350238, longitude = 2.638829, display_name = "Frevin-Capelle"},
    ["Gauchin-Legal"] = { latitude = 50.415413, longitude = 2.580783, display_name = "Gauchin-Legal"},
    ["Gosnay"] = { latitude = 50.508288, longitude = 2.585141, display_name = "Gosnay"},
    ["Gouy-Servins"] = { latitude = 50.402467, longitude = 2.649541, display_name = "Gouy-Servins"},
    ["Guisy"] = { latitude = 50.389043, longitude = 2.001358, display_name = "Guisy"},
    ["Hesmond"] = { latitude = 50.451619, longitude = 1.950778, display_name = "Hesmond"},
    ["Habarcq"] = { latitude = 50.305638, longitude = 2.611375, display_name = "Habarcq"},
    ["Hannescamps"] = { latitude = 50.166406, longitude = 2.638869, display_name = "Hannescamps"},
    ["Haute-Avesnes"] = { latitude = 50.328849, longitude = 2.639675, display_name = "Haute-Avesnes"},
    ["Hebuterne"] = { latitude = 50.125337, longitude = 2.636355, display_name = "Hebuterne"},
    ["Hermaville"] = { latitude = 50.323366, longitude = 2.583539, display_name = "Hermaville"},
    ["Hermin"] = { latitude = 50.418676, longitude = 2.558363, display_name = "Hermin"},
    ["Hesdigneul-les-Bethune"] = { latitude = 50.501317, longitude = 2.593630, display_name = "Hesdigneul-les-Bethune"},
    ["Houchin"] = { latitude = 50.482338, longitude = 2.619552, display_name = "Houchin"},
    ["Izel-les-Hameau"] = { latitude = 50.314623, longitude = 2.531383, display_name = "Izel-les-Hameau"},
    ["La Comte"] = { latitude = 50.427123, longitude = 2.499043, display_name = "La Comte"},
    ["La Loge"] = { latitude = 50.410128, longitude = 2.031768, display_name = "La Loge"},
    ["Labeuvriere"] = { latitude = 50.520376, longitude = 2.563110, display_name = "Labeuvriere"},
    ["Lebiez"] = { latitude = 50.469253, longitude = 1.982758, display_name = "Lebiez"},
    ["Lespinoy"] = { latitude = 50.426840, longitude = 1.878623, display_name = "Lespinoy"},
    ["Loison-sur-Crequoise"] = { latitude = 50.437403, longitude = 1.925334, display_name = "Loison-sur-Crequoise"},
    ["Lozinghem"] = { latitude = 50.517819, longitude = 2.499672, display_name = "Lozinghem"},
    ["Maresquel-Ecquemicourt"] = { latitude = 50.408102, longitude = 1.933883, display_name = "Maresquel-Ecquemicourt"},
    ["Magnicourt-en-Comte"] = { latitude = 50.403634, longitude = 2.486591, display_name = "Magnicourt-en-Comte"},
    ["Magnicourt-sur-Canche"] = { latitude = 50.303018, longitude = 2.409031, display_name = "Magnicourt-sur-Canche"},
    ["Maisnil-les-Ruitz"] = { latitude = 50.453376, longitude = 2.585746, display_name = "Maisnil-les-Ruitz"},
    ["Maizieres"] = { latitude = 50.323792, longitude = 2.447266, display_name = "Maizieres"},
    ["Manin"] = { latitude = 50.297024, longitude = 2.511387, display_name = "Manin"},
    ["Mont-Saint-Eloi"] = { latitude = 50.351429, longitude = 2.692501, display_name = "Mont-Saint-Eloi"},
    ["Marconnelle"] = { latitude = 50.373859, longitude = 2.018381, display_name = "Marconnelle"},
    ["Marant"] = { latitude = 50.461734, longitude = 1.835891, display_name = "Marant"},
    ["Mondicourt"] = { latitude = 50.173591, longitude = 2.462474, display_name = "Mondicourt"},
    ["Marenla"] = { latitude = 50.446101, longitude = 1.868635, display_name = "Marenla"},
    ["Mingoval"] = { latitude = 50.373024, longitude = 2.574754, display_name = "Mingoval"},
    ["Puisieux"] = { latitude = 50.116703, longitude = 2.693897, display_name = "Puisieux"},
    ["Ourton"] = { latitude = 50.455251, longitude = 2.477867, display_name = "Ourton"},
    ["Pas-en-Artois"] = { latitude = 50.154193, longitude = 2.490704, display_name = "Pas-en-Artois"},
    ["Penin"] = { latitude = 50.328137, longitude = 2.484400, display_name = "Penin"},
    ["Pommera"] = { latitude = 50.172195, longitude = 2.442457, display_name = "Pommera"},
    ["Pommier"] = { latitude = 50.184254, longitude = 2.599698, display_name = "Pommier"},
    ["Royon"] = { latitude = 50.472399, longitude = 1.992301, display_name = "Royon"},
    ["Villers-Chatel"] = { latitude = 50.376786, longitude = 2.585568, display_name = "Villers-Chatel"},
    ["Noeux-les-Auxi"] = { latitude = 50.235132, longitude = 2.174807, display_name = "Noeux-les-Auxi"},
    ["Rebreuve-Ranchicourt"] = { latitude = 50.437012, longitude = 2.558185, display_name = "Rebreuve-Ranchicourt"},
    ["Rimboval"] = { latitude = 50.508085, longitude = 1.985654, display_name = "Rimboval"},
    ["Ruisseauville"] = { latitude = 50.480788, longitude = 2.123324, display_name = "Ruisseauville"},
    ["Ruitz"] = { latitude = 50.466503, longitude = 2.588501, display_name = "Ruitz"},
    ["Sailly-Labourse"] = { latitude = 50.500806, longitude = 2.695613, display_name = "Sailly-Labourse"},
    ["Verquigneul"] = { latitude = 50.502031, longitude = 2.665051, display_name = "Verquigneul"},
    ["Vaudricourt"] = { latitude = 50.499351, longitude = 2.627253, display_name = "Vaudricourt"},
    ["Avesnes-en-Val"] = { latitude = 49.920193, longitude = 1.398231, display_name = "Avesnes-en-Val"},
    ["Sains-les-Fressin"] = { latitude = 50.466471, longitude = 2.040777, display_name = "Sains-les-Fressin"},
    ["Saint-Amand"] = { latitude = 50.163989, longitude = 2.557766, display_name = "Saint-Amand"},
    ["Saint-Denoeux"] = { latitude = 50.471621, longitude = 1.905215, display_name = "Saint-Denoeux"},
    ["Savy-Berlette"] = { latitude = 50.353870, longitude = 2.570194, display_name = "Savy-Berlette"},
    ["Sempy"] = { latitude = 50.492124, longitude = 1.876173, display_name = "Sempy"},
    ["Servins"] = { latitude = 50.409664, longitude = 2.642820, display_name = "Servins"},
    ["Sombrin"] = { latitude = 50.240107, longitude = 2.498782, display_name = "Sombrin"},
    ["Saulty"] = { latitude = 50.216647, longitude = 2.534072, display_name = "Saulty"},
    ["Souastre"] = { latitude = 50.152737, longitude = 2.564129, display_name = "Souastre"},
    ["Tilloy-les-Hermaville"] = { latitude = 50.327542, longitude = 2.555282, display_name = "Tilloy-les-Hermaville"},
    ["Tincques"] = { latitude = 50.358091, longitude = 2.493038, display_name = "Tincques"},
    ["Villers-au-Bois"] = { latitude = 50.373476, longitude = 2.671491, display_name = "Villers-au-Bois"},
    ["Villers-Brulin"] = { latitude = 50.368300, longitude = 2.539641, display_name = "Villers-Brulin"},
    ["Barly"] = { latitude = 50.251285, longitude = 2.547855, display_name = "Barly"},
    ["Beutin"] = { latitude = 50.491368, longitude = 1.723943, display_name = "Beutin"},
    ["Bouret-sur-Canche"] = { latitude = 50.267561, longitude = 2.320685, display_name = "Bouret-sur-Canche"},
    ["Fontaine-l'Etalon"] = { latitude = 50.304808, longitude = 2.062972, display_name = "Fontaine-l'Etalon"},
    ["Fortel-en-Artois"] = { latitude = 50.258340, longitude = 2.224950, display_name = "Fortel-en-Artois"},
    ["Humbercamps"] = { latitude = 50.184811, longitude = 2.574128, display_name = "Humbercamps"},
    ["Liencourt"] = { latitude = 50.271114, longitude = 2.454495, display_name = "Liencourt"},
    ["Quoeux-Haut-Mainil"] = { latitude = 50.299738, longitude = 2.109808, display_name = "Quoeux-Haut-Mainil"},
    ["Friaucourt"] = { latitude = 50.088504, longitude = 1.477432, display_name = "Friaucourt"},
    ["Allenay"] = { latitude = 50.090232, longitude = 1.494030, display_name = "Allenay"},
    ["Brutelles"] = { latitude = 50.140851, longitude = 1.522464, display_name = "Brutelles"},
    ["Vaudricourt"] = { latitude = 50.119989, longitude = 1.549379, display_name = "Vaudricourt"},
    ["Saint-Blimont"] = { latitude = 50.120352, longitude = 1.567875, display_name = "Saint-Blimont"},
    ["Nibas"] = { latitude = 50.099336, longitude = 1.588243, display_name = "Nibas"},
    ["Lancheres"] = { latitude = 50.156881, longitude = 1.550766, display_name = "Lancheres"},
    ["Pende"] = { latitude = 50.160419, longitude = 1.586523, display_name = "Pende"},
    ["Saint-Quentin-Lamotte-Croix-au-Bailly"] = { latitude = 50.073532, longitude = 1.452558, display_name = "Saint-Quentin-Lamotte-Croix-au-Bailly"},
    ["Mons-Boubert"] = { latitude = 50.128830, longitude = 1.662704, display_name = "Mons-Boubert"},
    ["Saigneville"] = { latitude = 50.136906, longitude = 1.712312, display_name = "Saigneville"},
    ["Ponts-et-Marais"] = { latitude = 50.040459, longitude = 1.442832, display_name = "Ponts-et-Marais"},
    ["Woincourt"] = { latitude = 50.064974, longitude = 1.537203, display_name = "Woincourt"},
    ["Dargnies"] = { latitude = 50.042273, longitude = 1.526040, display_name = "Dargnies"},
    ["Beauchamps"] = { latitude = 50.017920, longitude = 1.508522, display_name = "Beauchamps"},
    ["Embreville"] = { latitude = 50.029763, longitude = 1.542338, display_name = "Embreville"},
    ["Mareuil-Caubert"] = { latitude = 50.068518, longitude = 1.829495, display_name = "Mareuil-Caubert"},
    ["Huchenneville"] = { latitude = 50.050529, longitude = 1.798512, display_name = "Huchenneville"},
    ["Aigneville"] = { latitude = 50.033267, longitude = 1.618383, display_name = "Aigneville"},
    ["Bouillancourt-en-Sery"] = { latitude = 49.962078, longitude = 1.629067, display_name = "Bouillancourt-en-Sery"},
    ["Port-le-Grand"] = { latitude = 50.151333, longitude = 1.749128, display_name = "Port-le-Grand"},
    ["Favieres"] = { latitude = 50.237656, longitude = 1.663845, display_name = "Favieres"},
    ["Villers-sur-Authie"] = { latitude = 50.317121, longitude = 1.690718, display_name = "Villers-sur-Authie"},
    ["Forest-Montiers"] = { latitude = 50.245116, longitude = 1.741668, display_name = "Forest-Montiers"},
    ["Buigny-Saint-Maclou"] = { latitude = 50.155218, longitude = 1.813248, display_name = "Buigny-Saint-Maclou"},
    ["Vismes"] = { latitude = 50.011591, longitude = 1.672669, display_name = "Vismes"},
    ["Toeufles"] = { latitude = 50.066957, longitude = 1.715689, display_name = "Toeufles"},
    ["Behen"] = { latitude = 50.056974, longitude = 1.755319, display_name = "Behen"},
    ["Bealencourt"] = { latitude = 50.435337, longitude = 2.121538, display_name = "Bealencourt"},
    ["Fontaine-sur-Somme"] = { latitude = 50.029171, longitude = 1.941005, display_name = "Fontaine-sur-Somme"},
    ["Longpre-les-Corps-Saints"] = { latitude = 50.013403, longitude = 1.991743, display_name = "Longpre-les-Corps-Saints"},
    ["Bettencourt-Riviere"] = { latitude = 49.996197, longitude = 1.976653, display_name = "Bettencourt-Riviere"},
    ["Conde-Folie"] = { latitude = 50.010437, longitude = 2.021068, display_name = "Conde-Folie"},
    ["Hangest-sur-Somme"] = { latitude = 49.980232, longitude = 2.065232, display_name = "Hangest-sur-Somme"},
    ["L'Etoile"] = { latitude = 50.020280, longitude = 2.045751, display_name = "L'Etoile"},
    ["Huppy"] = { latitude = 50.024552, longitude = 1.764234, display_name = "Huppy"},
    ["Bray-les-Mareuil"] = { latitude = 50.054739, longitude = 1.855303, display_name = "Bray-les-Mareuil"},
    ["Erondelle"] = { latitude = 50.053317, longitude = 1.884265, display_name = "Erondelle"},
    ["Limeux"] = { latitude = 50.019278, longitude = 1.815791, display_name = "Limeux"},
    ["Frucourt"] = { latitude = 49.995513, longitude = 1.807079, display_name = "Frucourt"},
    ["Crouy-Saint-Pierre"] = { latitude = 49.969409, longitude = 2.086307, display_name = "Crouy-Saint-Pierre"},
    ["Frechencourt"] = { latitude = 49.965039, longitude = 2.441864, display_name = "Frechencourt"},
    ["Calonne-Ricouart"] = { latitude = 50.489409, longitude = 2.484482, display_name = "Calonne-Ricouart"},
    ["Stella-Plage"] = { latitude = 50.479940, longitude = 1.577138, display_name = "Stella-Plage"},
    ["Recques-sur-Course"] = { latitude = 50.521554, longitude = 1.785264, display_name = "Recques-sur-Course"},
    ["Fienvillers"] = { latitude = 50.117793, longitude = 2.228164, display_name = "Fienvillers"},
    ["Houdain"] = { latitude = 50.453813, longitude = 2.536784, display_name = "Houdain"},
    ["Pernois"] = { latitude = 50.051806, longitude = 2.181309, display_name = "Pernois"},
    ["Caours"] = { latitude = 50.129588, longitude = 1.881779, display_name = "Caours"},
    ["Saint-Riquier"] = { latitude = 50.135782, longitude = 1.946800, display_name = "Saint-Riquier"},
    ["Neufmoulin"] = { latitude = 50.128545, longitude = 1.908033, display_name = "Neufmoulin"},
    ["Millencourt-en-Ponthieu"] = { latitude = 50.151836, longitude = 1.901300, display_name = "Millencourt-en-Ponthieu"},
    ["Hautvillers-Ouville"] = { latitude = 50.172747, longitude = 1.812496, display_name = "Hautvillers-Ouville"},
    ["Forest-l'Abbaye"] = { latitude = 50.203667, longitude = 1.822246, display_name = "Forest-l'Abbaye"},
    ["Marcheville"] = { latitude = 50.221449, longitude = 1.902782, display_name = "Marcheville"},
    ["Bernay-en-Ponthieu"] = { latitude = 50.269179, longitude = 1.744496, display_name = "Bernay-en-Ponthieu"},
    ["Arry"] = { latitude = 50.278391, longitude = 1.720847, display_name = "Arry"},
    ["Regniere-Ecluse"] = { latitude = 50.279957, longitude = 1.769164, display_name = "Regniere-Ecluse"},
    ["Vron"] = { latitude = 50.314832, longitude = 1.755027, display_name = "Vron"},
    ["Nampont"] = { latitude = 50.347932, longitude = 1.745303, display_name = "Nampont"},
    ["Vironchaux"] = { latitude = 50.285888, longitude = 1.828922, display_name = "Vironchaux"},
    ["Vercourt"] = { latitude = 50.300467, longitude = 1.700853, display_name = "Vercourt"},
    ["Machiel"] = { latitude = 50.269881, longitude = 1.822936, display_name = "Machiel"},
    ["Machy"] = { latitude = 50.271234, longitude = 1.799760, display_name = "Machy"},
    ["Sachin"] = { latitude = 50.486649, longitude = 2.375360, display_name = "Sachin"},
    ["Boyaval"] = { latitude = 50.474299, longitude = 2.304088, display_name = "Boyaval"},
    ["Tollent"] = { latitude = 50.277620, longitude = 2.013841, display_name = "Tollent"},
    ["Siracourt"] = { latitude = 50.372126, longitude = 2.270515, display_name = "Siracourt"},
    ["Wanquetin"] = { latitude = 50.276266, longitude = 2.612965, display_name = "Wanquetin"},
    ["Simencourt"] = { latitude = 50.257176, longitude = 2.643434, display_name = "Simencourt"},
    ["Wail"] = { latitude = 50.343675, longitude = 2.126523, display_name = "Wail"},
    ["Villers-l'Hopital"] = { latitude = 50.228001, longitude = 2.213403, display_name = "Villers-l'Hopital"},
    ["Beaucourt-sur-l'Ancre"] = { latitude = 50.079855, longitude = 2.687121, display_name = "Beaucourt-sur-l'Ancre"},
    ["Basseux"] = { latitude = 50.225691, longitude = 2.644203, display_name = "Basseux"},
    ["Bailleulval"] = { latitude = 50.221240, longitude = 2.634088, display_name = "Bailleulval"},
    ["Riviere"] = { latitude = 50.233728, longitude = 2.685614, display_name = "Riviere"},
    ["Ransart"] = { latitude = 50.209100, longitude = 2.687046, display_name = "Ransart"},
    ["Bailleulmont"] = { latitude = 50.215951, longitude = 2.612239, display_name = "Bailleulmont"},
    ["La Cauchie"] = { latitude = 50.201207, longitude = 2.582186, display_name = "La Cauchie"},
    ["Monchy-au-Bois"] = { latitude = 50.179778, longitude = 2.657847, display_name = "Monchy-au-Bois"},
    ["Gapennes"] = { latitude = 50.182745, longitude = 1.952581, display_name = "Gapennes"},
    ["Buigny-l'Abbe"] = { latitude = 50.097853, longitude = 1.938007, display_name = "Buigny-l'Abbe"},
    ["Bresle"] = { latitude = 49.983572, longitude = 2.557272, display_name = "Bresle"},
    ["Fosseux"] = { latitude = 50.256212, longitude = 2.562805, display_name = "Fosseux"},
    ["Grand-Rullecourt"] = { latitude = 50.255160, longitude = 2.473003, display_name = "Grand-Rullecourt"},
    ["Bavincourt"] = { latitude = 50.225523, longitude = 2.567702, display_name = "Bavincourt"},
    ["Gouy-en-Artois"] = { latitude = 50.247612, longitude = 2.592830, display_name = "Gouy-en-Artois"},
    ["La Herliere"] = { latitude = 50.207756, longitude = 2.559321, display_name = "La Herliere"},
    ["Neuville-sous-Montreuil"] = { latitude = 50.475693, longitude = 1.772682, display_name = "Neuville-sous-Montreuil"},
    ["Ponches-Estruval"] = { latitude = 50.310024, longitude = 1.893326, display_name = "Ponches-Estruval"},
    ["Le Ponchel"] = { latitude = 50.257722, longitude = 2.071385, display_name = "Le Ponchel"},
    ["La Chaussee-Tirancourt"] = { latitude = 49.952940, longitude = 2.148340, display_name = "La Chaussee-Tirancourt"},
    ["Ligescourt"] = { latitude = 50.288349, longitude = 1.876473, display_name = "Ligescourt"},
    ["Canettemont"] = { latitude = 50.278814, longitude = 2.364928, display_name = "Canettemont"},
    ["Montenescourt"] = { latitude = 50.293878, longitude = 2.622887, display_name = "Montenescourt"},
    ["Saint-Georges"] = { latitude = 50.358395, longitude = 2.087431, display_name = "Saint-Georges"},
    ["Berles-au-Bois"] = { latitude = 50.199002, longitude = 2.627526, display_name = "Berles-au-Bois"},
    ["Bettencourt-Saint-Ouen"] = { latitude = 50.024972, longitude = 2.110299, display_name = "Bettencourt-Saint-Ouen"},
    ["Lepine"] = { latitude = 50.385461, longitude = 1.735686, display_name = "Lepine"},
    ["Floringhem"] = { latitude = 50.496938, longitude = 2.425733, display_name = "Floringhem"},
    ["Buneville"] = { latitude = 50.324403, longitude = 2.357109, display_name = "Buneville"},
    ["Laleu"] = { latitude = 49.941220, longitude = 1.932334, display_name = "Laleu"},
    ["Agenvillers"] = { latitude = 50.176756, longitude = 1.917494, display_name = "Agenvillers"},
    ["Boufflers"] = { latitude = 50.261571, longitude = 2.020652, display_name = "Boufflers"},
    ["Brailly-Cornehotte"] = { latitude = 50.217280, longitude = 1.959455, display_name = "Brailly-Cornehotte"},
    ["Domvast"] = { latitude = 50.198286, longitude = 1.921579, display_name = "Domvast"},
    ["Estrees-les-Crecy"] = { latitude = 50.253385, longitude = 1.927624, display_name = "Estrees-les-Crecy"},
    ["Fontaine-sur-Maye"] = { latitude = 50.235651, longitude = 1.925212, display_name = "Fontaine-sur-Maye"},
    ["Gueschart"] = { latitude = 50.238987, longitude = 2.011477, display_name = "Gueschart"},
    ["Lamotte-Buleux"] = { latitude = 50.188737, longitude = 1.827387, display_name = "Lamotte-Buleux"},
    ["Noyelles-en-Chaussee"] = { latitude = 50.208602, longitude = 1.979836, display_name = "Noyelles-en-Chaussee"},
    ["Agenville"] = { latitude = 50.165070, longitude = 2.102450, display_name = "Agenville"},
    ["Autheux"] = { latitude = 50.142580, longitude = 2.228620, display_name = "Autheux"},
    ["Barly"] = { latitude = 50.202120, longitude = 2.272490, display_name = "Barly"},
    ["Bavelincourt"] = { latitude = 49.986440, longitude = 2.454680, display_name = "Bavelincourt"},
    ["Beaumetz"] = { latitude = 50.140950, longitude = 2.119650, display_name = "Beaumetz"},
    ["Bellancourt"] = { latitude = 50.090260, longitude = 1.909777, display_name = "Bellancourt"},
    ["Bernaville"] = { latitude = 50.132351, longitude = 2.164393, display_name = "Bernaville"},
    ["Bernatre"] = { latitude = 50.197320, longitude = 2.090690, display_name = "Bernatre"},
    ["Bouchon"] = { latitude = 50.035275, longitude = 2.028775, display_name = "Bouchon"},
    ["Bourdon"] = { latitude = 49.987030, longitude = 2.074940, display_name = "Bourdon"},
    ["Brucamps"] = { latitude = 50.072220, longitude = 2.056640, display_name = "Brucamps"},
    ["Bussus-Bussuel"] = { latitude = 50.109490, longitude = 1.998690, display_name = "Bussus-Bussuel"},
    ["Canchy"] = { latitude = 50.185670, longitude = 1.876900, display_name = "Canchy"},
    ["Conteville"] = { latitude = 50.177440, longitude = 2.074270, display_name = "Conteville"},
    ["Coulonvillers"] = { latitude = 50.141880, longitude = 2.006440, display_name = "Coulonvillers"},
    ["Cramont"] = { latitude = 50.148130, longitude = 2.053520, display_name = "Cramont"},
    ["Domleger-Longvillers"] = { latitude = 50.159560, longitude = 2.085780, display_name = "Domleger-Longvillers"},
    ["Domqueur"] = { latitude = 50.114380, longitude = 2.048880, display_name = "Domqueur"},
    ["Ergnies"] = { latitude = 50.085540, longitude = 2.036850, display_name = "Ergnies"},
    ["Francieres"] = { latitude = 50.072004, longitude = 1.940737, display_name = "Francieres"},
    ["Franqueville"] = { latitude = 50.094150, longitude = 2.106500, display_name = "Franqueville"},
    ["Fransu"] = { latitude = 50.109320, longitude = 2.092270, display_name = "Fransu"},
    ["Frohen-sur-Authie"] = { latitude = 50.202322, longitude = 2.206451, display_name = "Frohen-sur-Authie"},
    ["Gorenflos"] = { latitude = 50.095791, longitude = 2.049428, display_name = "Gorenflos"},
    ["Heucourt-Croquoison"] = { latitude = 49.930668, longitude = 1.881624, display_name = "Heucourt-Croquoison"},
    ["Heuzecourt"] = { latitude = 50.172710, longitude = 2.166640, display_name = "Heuzecourt"},
    ["Hiermont"] = { latitude = 50.194510, longitude = 2.075350, display_name = "Hiermont"},
    ["Le Meillard"] = { latitude = 50.170104, longitude = 2.194871, display_name = "Le Meillard"},
    ["Le Mesge"] = { latitude = 49.944630, longitude = 2.052050, display_name = "Le Mesge"},
    ["Maison-Ponthieu"] = { latitude = 50.206830, longitude = 2.042950, display_name = "Maison-Ponthieu"},
    ["Maison-Roland"] = { latitude = 50.127893, longitude = 2.020570, display_name = "Maison-Roland"},
    ["Maizicourt"] = { latitude = 50.195750, longitude = 2.121500, display_name = "Maizicourt"},
    ["Mesnil-Domqueur"] = { latitude = 50.135190, longitude = 2.069450, display_name = "Mesnil-Domqueur"},
    ["Montigny-les-Jongleurs"] = { latitude = 50.180560, longitude = 2.132950, display_name = "Montigny-les-Jongleurs"},
    ["Mouflers"] = { latitude = 50.047010, longitude = 2.048740, display_name = "Mouflers"},
    ["Metigny"] = { latitude = 49.944500, longitude = 1.926760, display_name = "Metigny"},
    ["Mezerolles"] = { latitude = 50.186630, longitude = 2.234950, display_name = "Mezerolles"},
    ["Neuilly-le-Dien"] = { latitude = 50.223000, longitude = 2.042640, display_name = "Neuilly-le-Dien"},
    ["Occoches"] = { latitude = 50.174360, longitude = 2.269295, display_name = "Occoches"},
    ["Oneux"] = { latitude = 50.145194, longitude = 1.970786, display_name = "Oneux"},
    ["Outrebois"] = { latitude = 50.174160, longitude = 2.251920, display_name = "Outrebois"},
    ["Prouville"] = { latitude = 50.147280, longitude = 2.125130, display_name = "Prouville"},
    ["Ribeaucourt"] = { latitude = 50.116690, longitude = 2.118670, display_name = "Ribeaucourt"},
    ["Saint-Acheul"] = { latitude = 50.190650, longitude = 2.163550, display_name = "Saint-Acheul"},
    ["Saint-Gratien"] = { latitude = 49.965740, longitude = 2.408160, display_name = "Saint-Gratien"},
    ["Soues"] = { latitude = 49.956320, longitude = 2.053220, display_name = "Soues"},
    ["Surcamps"] = { latitude = 50.068760, longitude = 2.073450, display_name = "Surcamps"},
    ["Vauchelles-les-Quesnoy"] = { latitude = 50.102607, longitude = 1.888834, display_name = "Vauchelles-les-Quesnoy"},
    ["Villers-sous-Ailly"] = { latitude = 50.061130, longitude = 2.016390, display_name = "Villers-sous-Ailly"},
    ["Vitz-sur-Authie"] = { latitude = 50.252906, longitude = 2.064327, display_name = "Vitz-sur-Authie"},
    ["Yaucourt-Bussus"] = { latitude = 50.103020, longitude = 1.976480, display_name = "Yaucourt-Bussus"},
    ["Yvrench"] = { latitude = 50.177790, longitude = 2.004340, display_name = "Yvrench"},
    ["Yvrencheux"] = { latitude = 50.181246, longitude = 1.992521, display_name = "Yvrencheux"},
    ["Yzeux"] = { latitude = 49.974700, longitude = 2.108600, display_name = "Yzeux"},
    ["Longroy"] = { latitude = 49.988960, longitude = 1.535680, display_name = "Longroy"},
    ["Rieux"] = { latitude = 49.934680, longitude = 1.580390, display_name = "Rieux"},
    ["Agnez-les-Duisans"] = { latitude = 50.307060, longitude = 2.658735, display_name = "Agnez-les-Duisans"},
    ["Alette"] = { latitude = 50.517430, longitude = 1.827260, display_name = "Alette"},
    ["Attin"] = { latitude = 50.487875, longitude = 1.743784, display_name = "Attin"},
    ["Auchy-les-Hesdin"] = { latitude = 50.398823, longitude = 2.101955, display_name = "Auchy-les-Hesdin"},
    ["Aumerval"] = { latitude = 50.506482, longitude = 2.399188, display_name = "Aumerval"},
    ["Averdoingt"] = { latitude = 50.343970, longitude = 2.441610, display_name = "Averdoingt"},
    ["Bailleul-les-Pernes"] = { latitude = 50.510004, longitude = 2.387600, display_name = "Bailleul-les-Pernes"},
    ["Beaufort-Blavincourt"] = { latitude = 50.278670, longitude = 2.496980, display_name = "Beaufort-Blavincourt"},
    ["Beaumerie-Saint-Martin"] = { latitude = 50.455200, longitude = 1.797770, display_name = "Beaumerie-Saint-Martin"},
    ["Beauvois"] = { latitude = 50.374280, longitude = 2.233510, display_name = "Beauvois"},
    ["Bermicourt"] = { latitude = 50.408797, longitude = 2.230856, display_name = "Bermicourt"},
    ["Blangerval-Blangermont"] = { latitude = 50.323080, longitude = 2.230080, display_name = "Blangerval-Blangermont"},
    ["Blangy-sur-Ternoise"] = { latitude = 50.421450, longitude = 2.169560, display_name = "Blangy-sur-Ternoise"},
    ["Blingel"] = { latitude = 50.407830, longitude = 2.147310, display_name = "Blingel"},
    ["Bonnieres"] = { latitude = 50.244380, longitude = 2.259194, display_name = "Bonnieres"},
    ["Boubers-sur-Canche"] = { latitude = 50.291293, longitude = 2.236901, display_name = "Boubers-sur-Canche"},
    ["Bours"] = { latitude = 50.453854, longitude = 2.410986, display_name = "Bours"},
    ["Campigneulles-les-Grandes"] = { latitude = 50.435490, longitude = 1.712490, display_name = "Campigneulles-les-Grandes"},
    ["Cavron-Saint-Martin"] = { latitude = 50.417635, longitude = 1.999383, display_name = "Cavron-Saint-Martin"},
    ["Cheriennes"] = { latitude = 50.313630, longitude = 2.035310, display_name = "Cheriennes"},
    ["Clenleu"] = { latitude = 50.522310, longitude = 1.869390, display_name = "Clenleu"},
    ["Contes"] = { latitude = 50.409136, longitude = 1.961080, display_name = "Contes"},
    ["Conteville-en-Ternois"] = { latitude = 50.432745, longitude = 2.323704, display_name = "Conteville-en-Ternois"},
    ["Croisette"] = { latitude = 50.352900, longitude = 2.260500, display_name = "Croisette"},
    ["Croix-en-Ternois"] = { latitude = 50.383689, longitude = 2.280064, display_name = "Croix-en-Ternois"},
    ["Denier"] = { latitude = 50.287307, longitude = 2.443385, display_name = "Denier"},
    ["Duisans"] = { latitude = 50.305979, longitude = 2.688110, display_name = "Duisans"},
    ["Eps"] = { latitude = 50.454550, longitude = 2.295560, display_name = "Eps"},
    ["Estree-Wamin"] = { latitude = 50.269353, longitude = 2.394498, display_name = "Estree-Wamin"},
    ["Estreelles"] = { latitude = 50.498150, longitude = 1.782670, display_name = "Estreelles"},
    ["Flers"] = { latitude = 50.320530, longitude = 2.252550, display_name = "Flers"},
    ["Fleury"] = { latitude = 50.421990, longitude = 2.253860, display_name = "Fleury"},
    ["Fontaine-les-Hermans"] = { latitude = 50.526059, longitude = 2.349442, display_name = "Fontaine-les-Hermans"},
    ["Foufflin-Ricametz"] = { latitude = 50.350106, longitude = 2.385308, display_name = "Foufflin-Ricametz"},
    ["Framecourt"] = { latitude = 50.330239, longitude = 2.304849, display_name = "Framecourt"},
    ["Fresnoy"] = { latitude = 50.367300, longitude = 2.128340, display_name = "Fresnoy"},
    ["Galametz"] = { latitude = 50.327860, longitude = 2.137430, display_name = "Galametz"},
    ["Gaudiempre"] = { latitude = 50.177793, longitude = 2.530880, display_name = "Gaudiempre"},
    ["Givenchy-le-Noble"] = { latitude = 50.301509, longitude = 2.497085, display_name = "Givenchy-le-Noble"},
    ["Gouves"] = { latitude = 50.298885, longitude = 2.635911, display_name = "Gouves"},
    ["Gouy-en-Ternois"] = { latitude = 50.319846, longitude = 2.411787, display_name = "Gouy-en-Ternois"},
    ["Grigny"] = { latitude = 50.385624, longitude = 2.065831, display_name = "Grigny"},
    ["Guigny"] = { latitude = 50.329467, longitude = 1.998550, display_name = "Guigny"},
    ["Guinecourt"] = { latitude = 50.348190, longitude = 2.225490, display_name = "Guinecourt"},
    ["Herlin-le-Sec"] = { latitude = 50.354811, longitude = 2.330732, display_name = "Herlin-le-Sec"},
    ["Herlincourt"] = { latitude = 50.344072, longitude = 2.302256, display_name = "Herlincourt"},
    ["Hestrus"] = { latitude = 50.447560, longitude = 2.329400, display_name = "Hestrus"},
    ["Houvin-Houvigneul"] = { latitude = 50.297612, longitude = 2.382772, display_name = "Houvin-Houvigneul"},
    ["Huclier"] = { latitude = 50.429750, longitude = 2.356340, display_name = "Huclier"},
    ["Humbert"] = { latitude = 50.503790, longitude = 1.906400, display_name = "Humbert"},
    ["Humeroeuille"] = { latitude = 50.404779, longitude = 2.212303, display_name = "Humeroeuille"},
    ["Humieres"] = { latitude = 50.387224, longitude = 2.203771, display_name = "Humieres"},
    ["Hericourt"] = { latitude = 50.344780, longitude = 2.253600, display_name = "Hericourt"},
    ["Incourt"] = { latitude = 50.390810, longitude = 2.151810, display_name = "Incourt"},
    ["Ivergny"] = { latitude = 50.238690, longitude = 2.392370, display_name = "Ivergny"},
    ["La Thieuloye"] = { latitude = 50.413245, longitude = 2.434301, display_name = "La Thieuloye"},
    ["Lattre-Saint-Quentin"] = { latitude = 50.288187, longitude = 2.579949, display_name = "Lattre-Saint-Quentin"},
    ["Le Quesnoy-en-Artois"] = { latitude = 50.333480, longitude = 2.047560, display_name = "Le Quesnoy-en-Artois"},
    ["Lignereuil"] = { latitude = 50.290257, longitude = 2.472974, display_name = "Lignereuil"},
    ["Ligny-Saint-Flochel"] = { latitude = 50.358524, longitude = 2.428236, display_name = "Ligny-Saint-Flochel"},
    ["Ligny-sur-Canche"] = { latitude = 50.285305, longitude = 2.256618, display_name = "Ligny-sur-Canche"},
    ["Linzeux"] = { latitude = 50.340901, longitude = 2.204534, display_name = "Linzeux"},
    ["Maisnil"] = { latitude = 50.345400, longitude = 2.364430, display_name = "Maisnil"},
    ["Maisoncelle"] = { latitude = 50.447300, longitude = 2.142420, display_name = "Maisoncelle"},
    ["Marest"] = { latitude = 50.466914, longitude = 2.412207, display_name = "Marest"},
    ["Marquay"] = { latitude = 50.382133, longitude = 2.421446, display_name = "Marquay"},
    ["Moncheaux-les-Frevent"] = { latitude = 50.315119, longitude = 2.366697, display_name = "Moncheaux-les-Frevent"},
    ["Monchel-sur-Canche"] = { latitude = 50.302352, longitude = 2.206383, display_name = "Monchel-sur-Canche"},
    ["Monchiet"] = { latitude = 50.241219, longitude = 2.627880, display_name = "Monchiet"},
    ["Monchy-Breton"] = { latitude = 50.400701, longitude = 2.440284, display_name = "Monchy-Breton"},
    ["Monts-en-Ternois"] = { latitude = 50.321300, longitude = 2.384886, display_name = "Monts-en-Ternois"},
    ["Neulette"] = { latitude = 50.381981, longitude = 2.166513, display_name = "Neulette"},
    ["Neuville-au-Cornet"] = { latitude = 50.334717, longitude = 2.369580, display_name = "Neuville-au-Cornet"},
    ["Noyelles-les-Humieres"] = { latitude = 50.373000, longitude = 2.174570, display_name = "Noyelles-les-Humieres"},
    ["Noyellette"] = { latitude = 50.299034, longitude = 2.595646, display_name = "Noyellette"},
    ["Nuncq-Hautecote"] = { latitude = 50.305812, longitude = 2.287741, display_name = "Nuncq-Hautecote"},
    ["Nedon"] = { latitude = 50.524960, longitude = 2.369200, display_name = "Nedon"},
    ["Nedonchel"] = { latitude = 50.524010, longitude = 2.357950, display_name = "Nedonchel"},
    ["Orville"] = { latitude = 50.134376, longitude = 2.409865, display_name = "Orville"},
    ["Ostreville"] = { latitude = 50.395774, longitude = 2.394440, display_name = "Ostreville"},
    ["Pierremont"] = { latitude = 50.401179, longitude = 2.259532, display_name = "Pierremont"},
    ["Predefin"] = { latitude = 50.502780, longitude = 2.254070, display_name = "Predefin"},
    ["Quilen"] = { latitude = 50.529100, longitude = 1.926980, display_name = "Quilen"},
    ["Raye-sur-Authie"] = { latitude = 50.297650, longitude = 1.947310, display_name = "Raye-sur-Authie"},
    ["Rebreuve-sur-Canche"] = { latitude = 50.264927, longitude = 2.340054, display_name = "Rebreuve-sur-Canche"},
    ["Rebreuviette"] = { latitude = 50.262936, longitude = 2.361126, display_name = "Rebreuviette"},
    ["Rollancourt"] = { latitude = 50.407650, longitude = 2.122020, display_name = "Rollancourt"},
    ["Roellecourt"] = { latitude = 50.366485, longitude = 2.389433, display_name = "Roellecourt"},
    ["Sains-les-Pernes"] = { latitude = 50.477320, longitude = 2.355730, display_name = "Sains-les-Pernes"},
    ["Saint-Michel-sous-Bois"] = { latitude = 50.513880, longitude = 1.931520, display_name = "Saint-Michel-sous-Bois"},
    ["Saint-Michel-sur-Ternoise"] = { latitude = 50.376360, longitude = 2.357629, display_name = "Saint-Michel-sur-Ternoise"},
    ["Sars-le-Bois"] = { latitude = 50.294530, longitude = 2.428140, display_name = "Sars-le-Bois"},
    ["Sibiville"] = { latitude = 50.298490, longitude = 2.322970, display_name = "Sibiville"},
    ["Sus-Saint-Leger"] = { latitude = 50.238951, longitude = 2.432944, display_name = "Sus-Saint-Leger"},
    ["Sericourt"] = { latitude = 50.294063, longitude = 2.314864, display_name = "Sericourt"},
    ["Teneur"] = { latitude = 50.450490, longitude = 2.218290, display_name = "Teneur"},
    ["Ternas"] = { latitude = 50.341970, longitude = 2.396740, display_name = "Ternas"},
    ["Tilly-Capelle"] = { latitude = 50.443180, longitude = 2.197320, display_name = "Tilly-Capelle"},
    ["Tramecourt"] = { latitude = 50.463510, longitude = 2.150580, display_name = "Tramecourt"},
    ["Troisvaux"] = { latitude = 50.401834, longitude = 2.343038, display_name = "Troisvaux"},
    ["Vaulx"] = { latitude = 50.267362, longitude = 2.096494, display_name = "Vaulx"},
    ["Wambercourt"] = { latitude = 50.428460, longitude = 2.023280, display_name = "Wambercourt"},
    ["Warluzel"] = { latitude = 50.228915, longitude = 2.470100, display_name = "Warluzel"},
    ["Willeman"] = { latitude = 50.353056, longitude = 2.156880, display_name = "Willeman"},
    ["Eclimeux"] = { latitude = 50.398789, longitude = 2.178689, display_name = "Eclimeux"},
    ["Ecoivres"] = { latitude = 50.322530, longitude = 2.287590, display_name = "Ecoivres"},
    ["Ecuires"] = { latitude = 50.444689, longitude = 1.763966, display_name = "Ecuires"},
    ["Equirre"] = { latitude = 50.472375, longitude = 2.236755, display_name = "Equirre"},
    ["Erin"] = { latitude = 50.438760, longitude = 2.208630, display_name = "Erin"},
    ["Oeuf-en-Ternois"] = { latitude = 50.358938, longitude = 2.211600, display_name = "Oeuf-en-Ternois"},
    ["Groffliers"] = { latitude = 50.382729, longitude = 1.622814, display_name = "Groffliers"},
    ["Tubersent"] = { latitude = 50.519779, longitude = 1.704451, display_name = "Tubersent"},
    ["Maresville"] = { latitude = 50.526554, longitude = 1.731015, display_name = "Maresville"},
    ["Brexent-Enocq"] = { latitude = 50.509592, longitude = 1.728742, display_name = "Brexent-Enocq"},
    ["La Madelaine-sous-Montreuil"] = { latitude = 50.468627, longitude = 1.749413, display_name = "La Madelaine-sous-Montreuil"},
    ["Airon-Saint-Vaast"] = { latitude = 50.431377, longitude = 1.669146, display_name = "Airon-Saint-Vaast"},
    ["Airon-Notre-Dame"] = { latitude = 50.436507, longitude = 1.655822, display_name = "Airon-Notre-Dame"},
    ["Verton"] = { latitude = 50.401553, longitude = 1.650798, display_name = "Verton"},
    ["Caumont"] = { latitude = 50.289437, longitude = 2.029945, display_name = "Caumont"},
    ["Fillievres"] = { latitude = 50.319387, longitude = 2.158198, display_name = "Fillievres"},
    ["Conchil-le-Temple"] = { latitude = 50.370928, longitude = 1.665754, display_name = "Conchil-le-Temple"},
    ["Tigny-Noyelle"] = { latitude = 50.351400, longitude = 1.717952, display_name = "Tigny-Noyelle"},
    ["Waben"] = { latitude = 50.380072, longitude = 1.653436, display_name = "Waben"},
    ["Coupelle-Vieille"] = { latitude = 50.524957, longitude = 2.099054, display_name = "Coupelle-Vieille"},
    ["Saint-Remy-au-Bois"] = { latitude = 50.368111, longitude = 1.873131, display_name = "Saint-Remy-au-Bois"},
    ["Avondance"] = { latitude = 50.476049, longitude = 2.098952, display_name = "Avondance"},
    ["Boubers-les-Hesmond"] = { latitude = 50.475020, longitude = 1.949731, display_name = "Boubers-les-Hesmond"},
    ["Coupelle-Neuve"] = { latitude = 50.500689, longitude = 2.119716, display_name = "Coupelle-Neuve"},
    ["Offin"] = { latitude = 50.445176, longitude = 1.942315, display_name = "Offin"},
    ["Torcy"] = { latitude = 50.483063, longitude = 2.023020, display_name = "Torcy"},
    ["Sainte-Austreberthe"] = { latitude = 50.363513, longitude = 2.046351, display_name = "Sainte-Austreberthe"},
    ["Beauvoir-Wavans"] = { latitude = 50.218474, longitude = 2.163085, display_name = "Beauvoir-Wavans"},
    ["Conchy-sur-Canche"] = { latitude = 50.300792, longitude = 2.195983, display_name = "Conchy-sur-Canche"},
    ["Gennes-Ivergny"] = { latitude = 50.264791, longitude = 2.047602, display_name = "Gennes-Ivergny"},
    ["Rougefay"] = { latitude = 50.272935, longitude = 2.171032, display_name = "Rougefay"},
    ["Vacquerie-le-Boucq"] = { latitude = 50.269647, longitude = 2.218496, display_name = "Vacquerie-le-Boucq"},
    ["Vieil-Hesdin"] = { latitude = 50.356193, longitude = 2.098040, display_name = "Vieil-Hesdin"},
    ["Boffles"] = { latitude = 50.253988, longitude = 2.202852, display_name = "Boffles"},
    ["Canteleux"] = { latitude = 50.216291, longitude = 2.306973, display_name = "Canteleux"},
    ["Pressy"] = { latitude = 50.475604, longitude = 2.397533, display_name = "Pressy"},
    ["Dieval"] = { latitude = 50.434914, longitude = 2.448034, display_name = "Dieval"},
    ["Berles-Monchel"] = { latitude = 50.345477, longitude = 2.537601, display_name = "Berles-Monchel"},
    ["Berlencourt-le-Cauroy"] = { latitude = 50.279325, longitude = 2.423454, display_name = "Berlencourt-le-Cauroy"},
    ["Noyelle-Vion"] = { latitude = 50.294571, longitude = 2.547255, display_name = "Noyelle-Vion"},
    ["Villers-Sir-Simon"] = { latitude = 50.317131, longitude = 2.491699, display_name = "Villers-Sir-Simon"},
    ["Warlincourt-les-Pas"] = { latitude = 50.174255, longitude = 2.505313, display_name = "Warlincourt-les-Pas"},
    ["Sailly-au-Bois"] = { latitude = 50.119868, longitude = 2.595678, display_name = "Sailly-au-Bois"},
    ["Hem-Hardinval"] = { latitude = 50.163187, longitude = 2.303552, display_name = "Hem-Hardinval"},
    ["Vauchelles-les-Domart"] = { latitude = 50.055224, longitude = 2.057334, display_name = "Vauchelles-les-Domart"},
    ["Herissart"] = { latitude = 50.027715, longitude = 2.415546, display_name = "Herissart"},
    ["Dompierre-sur-Authie"] = { latitude = 50.303624, longitude = 1.916875, display_name = "Dompierre-sur-Authie"},
    ["Incheville"] = { latitude = 50.015656, longitude = 1.497900, display_name = "Incheville"},
    ["Saint-Pierre-en-Val"] = { latitude = 50.021065, longitude = 1.446089, display_name = "Saint-Pierre-en-Val"},
    ["Fourdrinoy"] = { latitude = 49.917409, longitude = 2.107841, display_name = "Fourdrinoy"},
    ["Hauteville"] = { latitude = 50.273637, longitude = 2.573024, display_name = "Hauteville"},
    ["Acquet"] = { latitude = 50.226910, longitude = 2.056536, display_name = "Acquet"},
    ["Labroye"] = { latitude = 50.278221, longitude = 1.989908, display_name = "Labroye"},
    ["Vignacourt"] = { latitude = 50.011839, longitude = 2.196777, display_name = "Vignacourt"},
    ["Lealvillers"] = { latitude = 50.065428, longitude = 2.509457, display_name = "Lealvillers"},
    ["Fieffes-Montrelet"] = { latitude = 50.083938, longitude = 2.231165, display_name = "Fieffes-Montrelet"},
    ["Beaurainville"] = { latitude = 50.424843, longitude = 1.900946, display_name = "Beaurainville"},
    ["Heudelimont"] = { latitude = 50.011780, longitude = 1.375816, display_name = "Heudelimont"},
    ["Valencendre"] = { latitude = 50.485801, longitude = 1.693873, display_name = "Valencendre"},
    ["Boisbergues"] = { latitude = 50.156183, longitude = 2.229787, display_name = "Boisbergues"},
    ["Auchonvillers"] = { latitude = 50.081345, longitude = 2.630008, display_name = "Auchonvillers"},
    ["Rue"] = { latitude = 50.272874, longitude = 1.667305, display_name = "Rue"},
    ["Amiens"] = { latitude = 49.899546, longitude = 2.295089, display_name = "Amiens"},
    ["Corbie"] = { latitude = 49.908415, longitude = 2.510957, display_name = "Corbie"},
    ["Arras"] = { latitude = 50.288691, longitude = 2.776158, display_name = "Arras"},
    ["Douai"] = { latitude = 50.367849, longitude = 3.089882, display_name = "Douai"},
    ["Lens"] = { latitude = 50.427170, longitude = 2.832500, display_name = "Lens"},
    }

SyriaTowns = {
    ["Racetrack for Camel Racing"] = { latitude = 34.403706, longitude = 38.198771, display_name = "Racetrack for Camel Racing"},
    ["Marbat El-Hassan Reservoir"] = { latitude = 34.667083, longitude = 38.224691, display_name = "Marbat El-Hassan Reservoir"},
    ["Sharqiyah Mine"] = { latitude = 34.199641, longitude = 38.014742, display_name = "Sharqiyah Mine"},
    ["Solonchak Sabhat al-Jabbul"] = { latitude = 36.044571, longitude = 37.521323, display_name = "Solonchak Sabhat al-Jabbul"},
    ["Adana"] = { latitude = 37.009025, longitude = 35.305756, display_name = "Adana"},
    ["Aleppo"] = { latitude = 36.206786, longitude = 37.142391, display_name = "Aleppo"},
    ["Raqqa"] = { latitude = 35.960290, longitude = 39.015335, display_name = "Raqqa"},
    ["Latakia"] = { latitude = 35.525744, longitude = 35.785411, display_name = "Latakia"},
    ["Hama"] = { latitude = 35.147288, longitude = 36.757011, display_name = "Hama"},
    ["Homs"] = { latitude = 34.731897, longitude = 36.711724, display_name = "Homs"},
    ["Palmyra"] = { latitude = 34.565481, longitude = 38.284229, display_name = "Palmyra"},
    ["Tartus"] = { latitude = 34.893779, longitude = 35.892245, display_name = "Tartus"},
    ["Tripoli"] = { latitude = 34.435775, longitude = 35.837320, display_name = "Tripoli"},
    ["Beirut"] = { latitude = 33.861187, longitude = 35.526848, display_name = "Beirut"},
    ["Damascus"] = { latitude = 33.518073, longitude = 36.296386, display_name = "Damascus"},
    ["Haifa"] = { latitude = 32.813432, longitude = 34.987236, display_name = "Haifa"},
    ["Idlib"] = { latitude = 35.930952, longitude = 36.633923, display_name = "Idlib"},
    ["Qudssaya"] = { latitude = 33.536740, longitude = 36.234351, display_name = "Qudssaya"},
    ["Qudssaya Suburb"] = { latitude = 33.540064, longitude = 36.192270, display_name = "Qudssaya Suburb"},
    ["At Tall"] = { latitude = 33.600323, longitude = 36.315657, display_name = "At Tall"},
    ["Alassad"] = { latitude = 33.581558, longitude = 36.358940, display_name = "Alassad"},
    ["Duma"] = { latitude = 33.571938, longitude = 36.405781, display_name = "Duma"},
    ["Harasta"] = { latitude = 33.559036, longitude = 36.366581, display_name = "Harasta"},
    ["Arbil"] = { latitude = 33.539070, longitude = 36.366804, display_name = "Arbil"},
    ["Madryara"] = { latitude = 33.544681, longitude = 36.395586, display_name = "Madryara"},
    ["Ad Dumayr"] = { latitude = 33.643665, longitude = 36.691055, display_name = "Ad Dumayr"},
    ["Al Qutayfah"] = { latitude = 33.741700, longitude = 36.594686, display_name = "Al Qutayfah"},
    ["Kafr Batna"] = { latitude = 33.514919, longitude = 36.384188, display_name = "Kafr Batna"},
    ["Ein Tamra"] = { latitude = 33.518276, longitude = 36.352033, display_name = "Ein Tamra"},
    ["Al Mleha"] = { latitude = 33.484569, longitude = 36.373028, display_name = "Al Mleha"},
    ["Babbila"] = { latitude = 33.477200, longitude = 36.336357, display_name = "Babbila"},
    ["El Hajar Al Aswad"] = { latitude = 33.468749, longitude = 36.309625, display_name = "El Hajar Al Aswad"},
    ["Set Zaynab"] = { latitude = 33.448837, longitude = 36.338214, display_name = "Set Zaynab"},
    ["Shebaa"] = { latitude = 33.449565, longitude = 36.398202, display_name = "Shebaa"},
    ["Al Ghuzlaniyah"] = { latitude = 33.398953, longitude = 36.454461, display_name = "Al Ghuzlaniyah"},
    ["Jdaydet Alkhas"] = { latitude = 33.405680, longitude = 36.544628, display_name = "Jdaydet Alkhas"},
    ["Harran al'Awamid"] = { latitude = 33.447575, longitude = 36.561596, display_name = "Harran al'Awamid"},
    ["Otaybah"] = { latitude = 33.483517, longitude = 36.610154, display_name = "Otaybah"},
    ["Hayjanah"] = { latitude = 33.358906, longitude = 36.544664, display_name = "Hayjanah"},
    ["Al Baytariyah"] = { latitude = 33.315697, longitude = 36.543629, display_name = "Al Baytariyah"},
    ["Buraq"] = { latitude = 33.185661, longitude = 36.479501, display_name = "Buraq"},
    ["Hazm"] = { latitude = 33.132337, longitude = 36.524319, display_name = "Hazm"},
    ["Qura Al-Assad"] = { latitude = 33.556956, longitude = 36.135584, display_name = "Qura Al-Assad"},
    ["Al-Dimass"] = { latitude = 33.588011, longitude = 36.091209, display_name = "Al-Dimass"},
    ["Al Moadamyeh"] = { latitude = 33.463478, longitude = 36.187321, display_name = "Al Moadamyeh"},
    ["Darayya"] = { latitude = 33.460294, longitude = 36.235558, display_name = "Darayya"},
    ["Sahnaya"] = { latitude = 33.432227, longitude = 36.237736, display_name = "Sahnaya"},
    ["Jdaydet Artooz"] = { latitude = 33.438519, longitude = 36.159494, display_name = "Jdaydet Artooz"},
    ["Zakyah"] = { latitude = 33.337249, longitude = 36.165773, display_name = "Zakyah"},
    ["As Sanamayn"] = { latitude = 33.077101, longitude = 36.185811, display_name = "As Sanamayn"},
    ["Jasim"] = { latitude = 32.996681, longitude = 36.064041, display_name = "Jasim"},
    ["Ankhul"] = { latitude = 33.017328, longitude = 36.130427, display_name = "Ankhul"},
    ["Kafr Shams"] = { latitude = 33.122908, longitude = 36.115409, display_name = "Kafr Shams"},
    ["Aqrabac"] = { latitude = 33.111487, longitude = 36.001655, display_name = "Aqrabac"},
    ["Al Harah"] = { latitude = 33.057838, longitude = 36.006797, display_name = "Al Harah"},
    ["Cotlu"] = { latitude = 36.874264, longitude = 35.487177, display_name = "Cotlu"},
    ["Ceyhan"] = { latitude = 37.032204, longitude = 35.820925, display_name = "Ceyhan"},
    ["Karsi"] = { latitude = 36.761068, longitude = 36.223837, display_name = "Karsi"},
    ["Sariseki"] = { latitude = 36.629934, longitude = 36.220243, display_name = "Sariseki"},
    ["Iskenderun"] = { latitude = 36.570207, longitude = 36.147166, display_name = "Iskenderun"},
    ["Kirikhan"] = { latitude = 36.501251, longitude = 36.361665, display_name = "Kirikhan"},
    ["Akincilar"] = { latitude = 36.388407, longitude = 36.231198, display_name = "Akincilar"},
    ["Kumlu"] = { latitude = 36.365700, longitude = 36.465543, display_name = "Kumlu"},
    ["Reyhanli"] = { latitude = 36.263975, longitude = 36.567831, display_name = "Reyhanli"},
    ["Antakya"] = { latitude = 36.211221, longitude = 36.157590, display_name = "Antakya"},
    ["Samandag"] = { latitude = 36.081880, longitude = 35.981085, display_name = "Samandag"},
    ["Maarrat Misrin"] = { latitude = 36.013735, longitude = 36.678771, display_name = "Maarrat Misrin"},
    ["Sarmin"] = { latitude = 35.906478, longitude = 36.725726, display_name = "Sarmin"},
    ["Saraqib"] = { latitude = 35.861085, longitude = 36.808029, display_name = "Saraqib"},
    ["Arihah"] = { latitude = 35.819453, longitude = 36.616768, display_name = "Arihah"},
    ["Al Rami"] = { latitude = 35.804366, longitude = 36.487599, display_name = "Al Rami"},
    ["Jisr Ash-Shughur"] = { latitude = 35.814383, longitude = 36.318373, display_name = "Jisr Ash-Shughur"},
    ["Khan Assubul"] = { latitude = 35.751556, longitude = 36.758686, display_name = "Khan Assubul"},
    ["Abu Ad Dhuhur"] = { latitude = 35.749513, longitude = 37.049436, display_name = "Abu Ad Dhuhur"},
    ["Al Ghadfah"] = { latitude = 35.677496, longitude = 36.801608, display_name = "Al Ghadfah"},
    ["Maarat al-Numan"] = { latitude = 35.641889, longitude = 36.675356, display_name = "Maarat al-Numan"},
    ["Kafr Nabi"] = { latitude = 35.614837, longitude = 36.568447, display_name = "Kafr Nabi"},
    ["Tell Arn"] = { latitude = 36.124066, longitude = 37.333972, display_name = "Tell Arn"},
    ["Al-Safirah"] = { latitude = 36.069189, longitude = 37.377062, display_name = "Al-Safirah"},
    ["Al Bab"] = { latitude = 36.366231, longitude = 37.512118, display_name = "Al Bab"},
    ["Manbij"] = { latitude = 36.525941, longitude = 37.960087, display_name = "Manbij"},
    ["Maskanah"] = { latitude = 35.964663, longitude = 38.042601, display_name = "Maskanah"},
    ["Al Tabqah"] = { latitude = 35.827092, longitude = 38.541302, display_name = "Al Tabqah"},
    ["Sqoubin"] = { latitude = 35.558660, longitude = 35.829224, display_name = "Sqoubin"},
    ["Sett Markho"] = { latitude = 35.589482, longitude = 35.851695, display_name = "Sett Markho"},
    ["Al Hannadi"] = { latitude = 35.480731, longitude = 35.927036, display_name = "Al Hannadi"},
    ["Jablah"] = { latitude = 35.363965, longitude = 35.927291, display_name = "Jablah"},
    ["Baniyas"] = { latitude = 35.189238, longitude = 35.953516, display_name = "Baniyas"},
    ["Ein Elkorum"] = { latitude = 35.368802, longitude = 36.409242, display_name = "Ein Elkorum"},
    ["Muhradah"] = { latitude = 35.249643, longitude = 36.572717, display_name = "Muhradah"},
    ["Halfaya"] = { latitude = 35.260712, longitude = 36.606798, display_name = "Halfaya"},
    ["Ar Rastan"] = { latitude = 34.923488, longitude = 36.732503, display_name = "Ar Rastan"},
    ["Hawash"] = { latitude = 34.762026, longitude = 36.322719, display_name = "Hawash"},
    ["Zaidal"] = { latitude = 34.718672, longitude = 36.773686, display_name = "Zaidal"},
    ["Fairuzah"] = { latitude = 34.702436, longitude = 36.757134, display_name = "Fairuzah"},
    ["Al Qusayr"] = { latitude = 34.512113, longitude = 36.587781, display_name = "Al Qusayr"},
    ["Khirbe"] = { latitude = 34.583839, longitude = 36.017331, display_name = "Khirbe"},
    ["Al Aabde"] = { latitude = 34.511339, longitude = 35.962268, display_name = "Al Aabde"},
    ["Chekka"] = { latitude = 34.323663, longitude = 35.731135, display_name = "Chekka"},
    ["Hamat"] = { latitude = 34.285622, longitude = 35.692717, display_name = "Hamat"},
    ["Batroun"] = { latitude = 34.252986, longitude = 35.666329, display_name = "Batroun"},
    ["Maqne"] = { latitude = 34.076334, longitude = 36.206335, display_name = "Maqne"},
    ["Baalbek"] = { latitude = 34.005549, longitude = 36.204317, display_name = "Baalbek"},
    ["Jounieh"] = { latitude = 33.979290, longitude = 35.633664, display_name = "Jounieh"},
    ["Rayak"] = { latitude = 33.853182, longitude = 36.021607, display_name = "Rayak"},
    ["Serghaya"] = { latitude = 33.811850, longitude = 36.161077, display_name = "Serghaya"},
    ["Al Zabadani"] = { latitude = 33.726458, longitude = 36.101596, display_name = "Al Zabadani"},
    ["Madaya"] = { latitude = 33.682698, longitude = 36.095064, display_name = "Madaya"},
    ["Zahle"] = { latitude = 33.842402, longitude = 35.925711, display_name = "Zahle"},
    ["Taalabaya"] = { latitude = 33.814138, longitude = 35.873182, display_name = "Taalabaya"},
    ["Bar Elias"] = { latitude = 33.774479, longitude = 35.900918, display_name = "Bar Elias"},
    ["Anjar"] = { latitude = 33.727388, longitude = 35.931892, display_name = "Anjar"},
    ["Majdel Anjar"] = { latitude = 33.707532, longitude = 35.907553, display_name = "Majdel Anjar"},
    ["Ghazze"] = { latitude = 33.668655, longitude = 35.831698, display_name = "Ghazze"},
    ["Joub Jannine"] = { latitude = 33.627189, longitude = 35.783124, display_name = "Joub Jannine"},
    ["Qaraoun"] = { latitude = 33.567601, longitude = 35.721222, display_name = "Qaraoun"},
    ["Khalde"] = { latitude = 33.777551, longitude = 35.475219, display_name = "Khalde"},
    ["Haret Chbib"] = { latitude = 33.740920, longitude = 35.457533, display_name = "Haret Chbib"},
    ["Chim"] = { latitude = 33.620974, longitude = 35.488638, display_name = "Chim"},
    ["Saida"] = { latitude = 33.563094, longitude = 35.377028, display_name = "Saida"},
    ["Nabatieh"] = { latitude = 33.381200, longitude = 35.479974, display_name = "Nabatieh"},
    ["Qatana"] = { latitude = 33.438131, longitude = 36.079687, display_name = "Qatana"},
    ["Khan Alsheh"] = { latitude = 33.373053, longitude = 36.113067, display_name = "Khan Alsheh"},
    ["Kanaker"] = { latitude = 33.268693, longitude = 36.094640, display_name = "Kanaker"},
    ["Jabah"] = { latitude = 33.164877, longitude = 35.927233, display_name = "Jabah"},
    ["Khan Arnabeh"] = { latitude = 33.182506, longitude = 35.890276, display_name = "Khan Arnabeh"},
    ["Naba Alsakher"] = { latitude = 33.088327, longitude = 35.947298, display_name = "Naba Alsakher"},
    ["Ghabagheb"] = { latitude = 33.182552, longitude = 36.224414, display_name = "Ghabagheb"},
    ["Jabab"] = { latitude = 33.113405, longitude = 36.264712, display_name = "Jabab"},
    ["As Sawara"] = { latitude = 33.028305, longitude = 36.578694, display_name = "As Sawara"},
    ["Shahba"] = { latitude = 32.858367, longitude = 36.632505, display_name = "Shahba"},
    ["Muadamyat Al Qalamon"] = { latitude = 33.741316, longitude = 36.640933, display_name = "Muadamyat Al Qalamon"},
    ["Al Kafr"] = { latitude = 32.632244, longitude = 36.648252, display_name = "Al Kafr"},
    ["El Karak"] = { latitude = 32.685853, longitude = 36.353277, display_name = "El Karak"},
    ["Eastern Garyiah"] = { latitude = 32.677965, longitude = 36.260940, display_name = "Eastern Garyiah"},
    ["Western Garyiah"] = { latitude = 32.687917, longitude = 36.225685, display_name = "Western Garyiah"},
    ["Khirbet Ghazaleh"] = { latitude = 32.737882, longitude = 36.201831, display_name = "Khirbet Ghazaleh"},
    ["Busra"] = { latitude = 32.517997, longitude = 36.481645, display_name = "Busra"},
    ["Dibin"] = { latitude = 32.439463, longitude = 36.567784, display_name = "Dibin"},
    ["Miarbah"] = { latitude = 32.544797, longitude = 36.428341, display_name = "Miarbah"},
    ["Ghasam"] = { latitude = 32.549096, longitude = 36.374564, display_name = "Ghasam"},
    ["Al Jeezah"] = { latitude = 32.565680, longitude = 36.316322, display_name = "Al Jeezah"},
    ["El Taebah"] = { latitude = 32.564137, longitude = 36.246336, display_name = "El Taebah"},
    ["Ramtha"] = { latitude = 32.565921, longitude = 36.008365, display_name = "Ramtha"},
    ["Et Turra"] = { latitude = 32.641456, longitude = 35.990626, display_name = "Et Turra"},
    ["Irbid"] = { latitude = 32.557292, longitude = 35.856121, display_name = "Irbid"},
    ["Tiberias"] = { latitude = 32.790725, longitude = 35.526414, display_name = "Tiberias"},
    ["Nazareth"] = { latitude = 32.704739, longitude = 35.306182, display_name = "Nazareth"},
    ["Daliyat al-Karmel"] = { latitude = 32.692722, longitude = 35.050793, display_name = "Daliyat al-Karmel"},
    ["Umm al-Fahm"] = { latitude = 32.522954, longitude = 35.151370, display_name = "Umm al-Fahm"},
    ["Afula"] = { latitude = 32.610048, longitude = 35.289515, display_name = "Afula"},
    ["Ein Harod"] = { latitude = 32.556165, longitude = 35.394209, display_name = "Ein Harod"},
    ["Beit Shean"] = { latitude = 32.492844, longitude = 35.501891, display_name = "Beit Shean"},
    ["Iksal"] = { latitude = 32.684349, longitude = 35.325562, display_name = "Iksal"},
    ["Hatzor HaGlilit"] = { latitude = 32.980146, longitude = 35.545722, display_name = "Hatzor HaGlilit"},
    ["Migdal HaEmek"] = { latitude = 32.678191, longitude = 35.241797, display_name = "Migdal HaEmek"},
    ["Nahalal"] = { latitude = 32.690694, longitude = 35.198958, display_name = "Nahalal"},
    ["Ramat Yishai"] = { latitude = 32.705166, longitude = 35.166819, display_name = "Ramat Yishai"},
    ["Kfar Yehoshua"] = { latitude = 32.681006, longitude = 35.153116, display_name = "Kfar Yehoshua"},
    ["Kiryat Tivon"] = { latitude = 32.717158, longitude = 35.126145, display_name = "Kiryat Tivon"},
    ["Yokneam Illit"] = { latitude = 32.653497, longitude = 35.102342, display_name = "Yokneam Illit"},
    ["Kafr Qara"] = { latitude = 32.504314, longitude = 35.064774, display_name = "Kafr Qara"},
    ["Pardes Hanna-Karkur"] = { latitude = 32.473446, longitude = 34.969511, display_name = "Pardes Hanna-Karkur"},
    ["Hadera"] = { latitude = 32.428035, longitude = 34.919863, display_name = "Hadera"},
    ["Isfiya"] = { latitude = 32.719767, longitude = 35.062365, display_name = "Isfiya"},
    ["Ein Hod"] = { latitude = 32.698984, longitude = 34.987603, display_name = "Ein Hod"},
    ["Atlit"] = { latitude = 32.688863, longitude = 34.943009, display_name = "Atlit"},
    ["Kiryat Motzkin"] = { latitude = 32.834316, longitude = 35.084219, display_name = "Kiryat Motzkin"},
    ["Kiryat Yam"] = { latitude = 32.842731, longitude = 35.069248, display_name = "Kiryat Yam"},
    ["Kiryat Ata"] = { latitude = 32.809126, longitude = 35.115174, display_name = "Kiryat Ata"},
    ["Shefar-Amr"] = { latitude = 32.804129, longitude = 35.172103, display_name = "Shefar-Amr"},
    ["Ibilin"] = { latitude = 32.822190, longitude = 35.192066, display_name = "Ibilin"},
    ["Kafr Manda"] = { latitude = 32.812136, longitude = 35.262557, display_name = "Kafr Manda"},
    ["Kabul"] = { latitude = 32.869646, longitude = 35.213104, display_name = "Kabul"},
    ["Tamra"] = { latitude = 32.854794, longitude = 35.194876, display_name = "Tamra"},
    ["Karmiel"] = { latitude = 32.907124, longitude = 35.286717, display_name = "Karmiel"},
    ["Deir al-Asad"] = { latitude = 32.929701, longitude = 35.275590, display_name = "Deir al-Asad"},
    ["Jadeidi Makr"] = { latitude = 32.927754, longitude = 35.148612, display_name = "Jadeidi Makr"},
    ["Yarka"] = { latitude = 32.955283, longitude = 35.211219, display_name = "Yarka"},
    ["Kafr Yasif"] = { latitude = 32.957481, longitude = 35.166921, display_name = "Kafr Yasif"},
    ["Acre"] = { latitude = 32.929521, longitude = 35.078140, display_name = "Acre"},
    ["Nahariyya"] = { latitude = 33.008845, longitude = 35.100274, display_name = "Nahariyya"},
    ["Bent Jbail"] = { latitude = 33.125874, longitude = 35.440673, display_name = "Bent Jbail"},
    ["Qiryat Shemona"] = { latitude = 33.209375, longitude = 35.570715, display_name = "Qiryat Shemona"},
    ["Tyre"] = { latitude = 33.275537, longitude = 35.215861, display_name = "Tyre"},
    ["SyADF 24th Brigade"] = { latitude = 33.336071, longitude = 36.418180, display_name = "SyADF 24th Brigade"},
    ["SAA 158th Brigade"] = { latitude = 33.401255, longitude = 36.272973, display_name = "SAA 158th Brigade"},
    ["SAA 100th Regiment"] = { latitude = 33.380777, longitude = 36.213524, display_name = "SAA 100th Regiment"},
    ["SAA 65th Brigade"] = { latitude = 33.766740, longitude = 36.547502, display_name = "SAA 65th Brigade"},
    ["SAA 550th Brigade"] = { latitude = 34.614960, longitude = 38.254372, display_name = "SAA 550th Brigade"},
    ["Chemical Weapons Storage Area"] = { latitude = 34.627713, longitude = 38.249290, display_name = "Chemical Weapons Storage Area"},
    ["SAA 165th Brigade"] = { latitude = 33.283835, longitude = 36.255758, display_name = "SAA 165th Brigade"},
    ["Army Vehicle Training Ground"] = { latitude = 33.365284, longitude = 36.322571, display_name = "Army Vehicle Training Ground"},
    ["SAA 1st Armoured Division"] = { latitude = 33.352760, longitude = 36.296204, display_name = "SAA 1st Armoured Division"},
    ["SyADF 150th Regiment"] = { latitude = 33.251611, longitude = 36.269702, display_name = "SyADF 150th Regiment"},
    ["SAA 121th Brigade"] = { latitude = 33.278919, longitude = 36.082934, display_name = "SAA 121th Brigade"},
    ["Army Vehicle Training Ground"] = { latitude = 33.433665, longitude = 36.124922, display_name = "Army Vehicle Training Ground"},
    ["Artillery Base"] = { latitude = 33.457854, longitude = 36.128248, display_name = "Artillery Base"},
    ["SAA 155th Artillery Regiment"] = { latitude = 33.702711, longitude = 36.526507, display_name = "SAA 155th Artillery Regiment"},
    ["SAA 128th Brigade"] = { latitude = 33.971493, longitude = 36.898243, display_name = "SAA 128th Brigade"},
    ["Al Safira Military Base"] = { latitude = 36.046375, longitude = 37.334725, display_name = "Al Safira Military Base"},
    ["Military Research Base"] = { latitude = 35.983058, longitude = 37.403046, display_name = "Military Research Base"},
    ["Durayhim Military Base"] = { latitude = 35.790074, longitude = 37.728073, display_name = "Durayhim Military Base"},
    ["SAA 156th Brigade"] = { latitude = 33.667855, longitude = 36.735378, display_name = "SAA 156th Brigade"},
    ["Air Defence Academy"] = { latitude = 34.646321, longitude = 36.746346, display_name = "Air Defence Academy"},
    ["SAA 4th Armoured Division"] = { latitude = 33.506039, longitude = 36.201757, display_name = "SAA 4th Armoured Division"},
    ["Army Vehicle Training Ground"] = { latitude = 33.737184, longitude = 36.809278, display_name = "Army Vehicle Training Ground"},
    ["SAA 20th Brigade"] = { latitude = 33.773650, longitude = 36.718297, display_name = "SAA 20th Brigade"},
    ["Army Vehicle Training Ground"] = { latitude = 33.710700, longitude = 36.665598, display_name = "Army Vehicle Training Ground"},
    ["SyADF 159th Regiment"] = { latitude = 33.177072, longitude = 36.577899, display_name = "SyADF 159th Regiment"},
    ["SAA 89th Brigade"] = { latitude = 33.146138, longitude = 36.284818, display_name = "SAA 89th Brigade"},
    ["SAA 7th Division"] = { latitude = 33.456229, longitude = 36.083628, display_name = "SAA 7th Division"},
    ["Army Training Ground"] = { latitude = 33.405091, longitude = 36.319119, display_name = "Army Training Ground"},
}

if env.mission.theatre == "Caucasus" then
    local tTbl = {}
    for tName, tData in pairs(CaucasusTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    CaucasusTowns = nil
elseif env.mission.theatre == "Nevada" then
    local tTbl = {}
    for tName, tData in pairs(NevadaTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    NevadaTowns = nil
elseif env.mission.theatre == "Normandy" then
    local tTbl = {}
    for tName, tData in pairs(NormandyTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    NormandyTowns = nil
elseif env.mission.theatre == "PersianGulf" then
    local tTbl = {}
    for tName, tData in pairs(PersianGulfTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    PersianGulfTowns = nil
elseif env.mission.theatre == "TheChannel" then
    local tTbl = {}
    for tName, tData in pairs(TheChannelTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    TheChannelTowns = nil
elseif env.mission.theatre == "Syria" then
    local tTbl = {}
    for tName, tData in pairs(SyriaTowns) do
        tTbl[#tTbl+1] = tData
    end
    GOAP.TerrainDb["towns"] = tTbl
    SyriaTowns = nil
else
    env.error(("GOAP, no theater identified: halting everything"))
    return
end

if not GOAP.TerrainDb["towns"] then
    env.error(("GOAP, no TerrainDb table: halting everything"))
    return
end

function GOAP.getAngle(vector1, vector2)
    return math.deg(math.atan2(vector2.z-vector1.z, vector2.x-vector1.x))%360
end

function GOAP.findProxy(terrain, source)
    local n = nil
    local e = nil
    local w = nil
    local s = nil

    for tId, tData in pairs(source) do
        if tData.display_name ~= terrain.display_name then

            --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name)))

            if tData.pos then
                local dist1 = GOAP.getDist(terrain.pos, tData.pos)
                local ang1 = GOAP.getAngle(terrain.pos, tData.pos)
                

                if ang1 and dist1 and dist1 < 50000 then -- and dist1 < 50000 

                    local pathExist = true
                    
                    --[[
                    local path = land.profile(terrain.pos, tData.pos)    -- land.findPathOnRoads("roads", terrain.pos.x, terrain.pos.z, tData.pos.x, tData.pos.z )
                    if path then
                        for _, pData in pairs(path) do
                            if pData.y == 0 then
                                pathExist = false
                                env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) .. " - there's sea in the area"))
                            end
                        end
                    end
                    --]]

                    if pathExist then
                        --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) .. " - there is a road connection"))
                        local ang = math.floor(ang1)
                        local dist = math.floor(dist1)

                        --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) ..", ang=" .. tostring(ang) .. ", dist=" .. tostring(dist)))

                        if ang >= 315 or ang < 45 then
                            if n then
                                if n.distance > dist then
                                    n = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                    --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", sobstituted n")))
                                end
                            else
                                n = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", added as n")))
                            end

                        elseif ang >= 45 and ang < 135 then
                            if e then
                                if e.distance > dist then
                                    e = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                    --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", sobstituted e")))
                                end
                            else
                                e = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", added as e")))
                            end
                                        
                        elseif ang >= 135 and ang < 225 then
                            if s then
                                if s.distance > dist then
                                    s = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                    --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", sobstituted s")))
                                end
                            else
                                s = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", added as s")))
                            end

                        elseif ang >= 225 and ang < 315 then
                            if w then
                                if w.distance > dist then
                                    w = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                    --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", sobstituted w")))
                                end
                            else
                                w = {name = tData.display_name, distance = dist, pos = tData.pos, owner = tData.owner}
                                --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name ..", added as w")))
                            end
                            
                        end
                    else
                        --env.error(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) ..", missing road connection"))
                    end
                else
                    --env.error(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) ..", missing ang1 or dist1"))
                end

            else
                --env.error(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) ..", missing tData.pos"))
            end

        else
            --env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .." to " ..tostring(tData.display_name) ..", missing parameters"))

        end
    end

    if GOAP.debugProcessDetail then
        if n then
            env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .. ", n: " ..tostring(n.name)))
        end
        if e then
            env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .. ", e: " ..tostring(e.name)))
        end
        if s then
            env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .. ", s: " ..tostring(s.name)))
        end
        if w then
            env.info(("GOAP, findProxy. From: " ..tostring(terrain.display_name) .. ", w: " ..tostring(w.name)))
        end
    end

    if n or e or w or s then
        if GOAP.debugProcessDetail then
            env.info(("GOAP, findProxy: terrain " .. tostring(terrain.display_name) .. " returning p"))
        end
        local p = {nord = n, east = e, sud = s, west = w}
        return p
    else
        if GOAP.debugProcessDetail then
            env.error(("GOAP, findProxy: missing any proxy, return nil"))
        end
        return nil
    end
end

function GOAP.phase0_initTerrains()
    
    -- fill table
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        tData.owner = -1 -- no one
        --tData.coalition = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}
        tData.pos = GOAP.townToVec3(tData.display_name)
        --[[
        local dataSet0 = {
            ["information"] = false,
            ["guarded"] = false,
        }
        tData.data = {[0] = dataSet0, [1] = dataSet0, [2] = dataSet0, [3] = dataSet0}
        --]]--
        tData.border = false
        tData.value = 0
        tData.majorCity = false
        tData.colour = GOAP.territoryVoidColour
        --tData.intel = {[0] = {}, [1] = {}, [2] = {}, [3] = {}}
    end

    -- sizing cities
    GOAP.sizeTerrain(GOAP.TerrainDb["towns"])

    -- define major
    GOAP.assignMajor(GOAP.TerrainDb["towns"])

    -- filter
    local baseTerrDb = GOAP.deepCopy(GOAP.TerrainDb["towns"])
    GOAP.TerrainDb["towns"] = GOAP.filterTerrain(baseTerrDb, GOAP.terrainDbElements)

    -- assign proxy
    local tCopy = GOAP.deepCopy(GOAP.TerrainDb["towns"])
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        env.info(("GOAP, phase0_initTerrains: Checking Proxy for: " .. tostring(tData.display_name) .. "\n\n"))
        local pr = GOAP.findProxy(tData, tCopy)
        if pr then
            tData.proxy = pr
        else
            tData[tId] = nil -- removing territory from the net
        end
    end


    -- first assignement and update
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        if tData and type(tData) == "table" then
            local vec3 = GOAP.townToVec3(tData.display_name)
            if vec3 then
                local _volume = {
                    id = world.VolumeType.SPHERE,
                    params = {
                        point = vec3,
                        radius = GOAP.townControlRadius
                    }
                }
                
                local _groupList = {}

                local _search = function(_unit)
                    pcall(function()
                        if _unit ~= nil and not _unit:hasAttribute("Air") and not _unit:hasAttribute("Ships") then
                            local gr    = _unit:getGroup()
                            local grId  = gr:getID()
                            local grCoa = gr:getCoalition()

                            local allow = true
                            if #_groupList > 0 then
                                for gIn, gData in pairs(_groupList) do
                                    if gData.id == grId then
                                        allow = false
                                    end
                                end
                            end

                            if allow == true then
                                _groupList[#_groupList+1] = {id = grId, group = gr, coa = grCoa}
                            end

                        end
                    end)
                    return true
                end       
            
                world.searchObjects(Object.Category.UNIT, _volume, _search)
            
                if #_groupList > 0 then
                    local blueHasGroups = false
                    local redHasGroups = false
                    local neutralHasGroups = false

                    for gID, gDATA in pairs(_groupList) do
                        local grdata = gDATA.group
                        local coa = grdata:getCoalition()
                        if coa == 2 then
                            blueHasGroups = true
                        elseif coa == 1 then
                            redHasGroups = true
                        elseif coa == 0 then
                            neutralHasGroups = true
                        end

                        --[[
                        local str, coa, atr = grdata:getClass()
                        if str and coa and atr then
                            if tData.coalition then
                                for cId, cData in pairs(tData.coalition) do
                                    if cId == coa then
                                        cData[gDATA.id] = {strenght = str, attributes = atr}
                                        if coa == 2 then
                                            blueHasGroups = true
                                        elseif coa == 1 then
                                            redHasGroups = true
                                        elseif coa == 0 then
                                            neutralHasGroups = true
                                        end
                                    end
                                end
                            end
                                
                        else
                            env.error(("GOAP, phase0_initTerrains: missing str coa atr for group: " .. tostring(gDATA.id)))
                        end
                        --]]--
                    end

                    if blueHasGroups and not redHasGroups and not neutralHasGroups then
                        tData.owner = 2
                        tData.colour = GOAP.territoryBlueColour

                    elseif redHasGroups and not blueHasGroups and not neutralHasGroups then
                        tData.owner = 1
                        tData.colour = GOAP.territoryRedColour

                    elseif neutralHasGroups and not blueHasGroups and not redHasGroups then
                        tData.owner = 0
                        tData.colour = GOAP.territoryNeutralColour

                    elseif not neutralHasGroups and not blueHasGroups and not redHasGroups then
                        tData.owner = -1
                        tData.colour = GOAP.territoryVoidColour

                    else
                        tData.owner = 9
                        tData.colour = GOAP.territoryContendedColour
 
                    end
                end

                --local borderTrue = false
                if tData.proxy then
                    for dir, didData in pairs(tData.proxy) do
                        if didData.owner ~= tData.owner then
                            if didData.owner ~= -1 then
                                tData.border = true
                            end
                        end
                    end
                end

            else
                env.error(("GOAP, phase0_initTerrains: town missing vec3"))
            end
        else
            env.error(("GOAP, phase0_initTerrains: town missing tData"))
        end
    end    

    -- assign void to coalition
    for tId, tData in pairs(GOAP.TerrainDb["towns"]) do
        if tData.owner == -1 then

            local mindist = 1000000000
            local minOwn = nil
            --for coa, coaData in pairs(tData.coalition) do
                --if coa == 0 then
                    --if #coaData == 0 then
                        
                        -- seek for distance

                        for xId, xData in pairs(GOAP.TerrainDb["towns"]) do
                            if xData.owner ~= -1 and xData.owner ~= 9 then
                                local dist = math.floor(GOAP.getDist(tData.pos, xData.pos))

                                if dist < mindist then
                                    mindist = dist
                                    minOwn = xData.owner

                                end
                            end
                        end

                    --end
                --end
            --end

            if minOwn then
                tData.owner = minOwn

                if tData.owner == -1 then
                    tData.colour = GOAP.territoryVoidColour
                elseif tData.owner == 0 then
                    tData.colour = GOAP.territoryNeutralColour
                elseif tData.owner == 1 then
                    tData.colour = GOAP.territoryRedColour
                elseif tData.owner == 2 then
                    tData.colour = GOAP.territoryBlueColour
                elseif tData.owner == 9 then
                    tData.colour = OAP.territoryContendedColour
                end
            end            
        end
    end

    

end

--## CIRCULAR FINITE STATE MACHINE UPDATE INFO
local phase = "A"
function GOAP.changePhase()
    if phase == "A" then -- udpate terrain data
        phase = "B"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "B" then
        phase = "C"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "C" then
        phase = "D"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "D" then
        phase = "E"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "E" then
        phase = "F"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    elseif phase == "F" then
        phase = "A"
        phase_index = 1
        if GOAP.debugProcessDetail then
            env.info(("GOAP, changePhase, new phase: " .. tostring(phase)))
        end
        -- scrivi la fase qui
    end
end

-- phase cycle
function GOAP.performPhaseCycle()
    if phase == "A" then
        GOAP.phaseA_updateTerrain(GOAP.TerrainDb)
        --if GOAP.debugProcessDetail then
        --    env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        -- dumpTable("GOAP.TerrainDb.lua", GOAP.TerrainDb)
        --end
        --timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
        
    elseif phase == "B" then
        GOAP.phaseB_updateORBAT()


    elseif phase == "C" then
        GOAP.phaseC_updateIntel()
        --phase = "C"
        --timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)

    elseif phase == "D" then
        if GOAP.debugProcessDetail then
            env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        end
            phase = "E"
        timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    elseif phase == "E" then
        if GOAP.debugProcessDetail then
            env.info(("GOAP, performPhaseCycle: phase skipped " .. tostring(phase)))
        end
        phase = "F"
        timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    elseif phase == "F" then
        GOAP.phaseF_exportTable(GOAP.TerrainDb, "desanitized")
        
        --timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
    end
end

-- update terrain data
function GOAP.sizeTerrain(tblTerrain) -- upgrade with group positioning inside a table
    for tId, tData in pairs(tblTerrain) do
        if tData and type(tData) == "table" then

            local vec3 = GOAP.townToVec3(tData.display_name)
            if vec3 then
                local _volume = {
                    id = world.VolumeType.SPHERE,
                    params = {
                        point = vec3,
                        radius = GOAP.townInfluenceRange
                    }
                }
                
                local _count = 0

                local _search = function(_obj)
                    pcall(function()
                        _count = _count + 1
                    end)
                    return true
                end       
            
                world.searchObjects(Object.Category.SCENERY, _volume, _search)
            
                tData.size = _count
            end
        end
    end
end

-- filter terrain on base percentage (20%)
function GOAP.filterTerrain(tblTerrain, size)
    if #tblTerrain > 0 then
        -- sort table
        table.sort(tblTerrain, function(a,b)
            if a.size and b.size then
                return a.size > b.size 
            end
        end)

        if GOAP.debugProcessDetail then
            --dumpTable("GOAP.terrainDB_full.lua", tblTerrain)
        end

        -- size value check & backup
        if not size then
            size = 500
            if GOAP.debugProcessDetail then
                env.info(("GOAP, filterTerrain: size not given, set 500"))
            end
        end

        -- filter
        for tId, tData in pairs(tblTerrain) do 
            if tId > size then
                tblTerrain[tId] = nil
            end
        end

        if GOAP.debugProcessDetail then
            --dumpTable("GOAP.terrainDB_filtered.lua", tblTerrain)
        end

        return tblTerrain

    else
        if GOAP.debugProcessDetail then
            env.info(("GOAP, filterTerrain: terrain is no size, ERROR!"))
        end
    end
end

-- order and define major cities data
function GOAP.assignMajor(tblTerrain)
    table.sort(tblTerrain, function(a,b)
        if a.size and b.size then
            return a.size > b.size 
        end
    end)
 
    for tId, tData in pairs(tblTerrain) do
         if tId < 11 then
             tData.majorCity = true
         end
    end
end

function GOAP.updateProxyOwner(t, tName)
    local updated = false
    for _, tData in pairs(t.towns) do
        if tData.display_name == tName then
            updated = true
            return tData.owner
        end
    end

    if updated == false then
        return -1
    end
end

function GOAP.phaseA_updateTerrain(tblTerrain) -- upgrade with group positioning inside a table

    if phase == "A" then
        if tblTerrain then
            if tblTerrain.towns then
                
                -- check if Cycle is done
                if phase_index > #tblTerrain.towns then
                    if GOAP.debugProcessDetail then
                        env.info(("GOAP, phaseA_updateTerrain: phase A completed"))
                    end
                    
                    -- update colours
                    for _, tData in pairs(tblTerrain.towns) do
                        env.info(("GOAP, phaseA_updateTerrain: updating colour for " .. tostring(tData.display_name) .. ", owner: " .. tostring(tData.owner) .. ", border: " .. tostring(tData.border)    ))
                        if tData.owner == 0 then
                            tData.colour = GOAP.territoryNeutralColour
                            if tData.border == true then
                                tData.colour[4] = 0.55
                            else
                                tData.colour[4] = 0.4
                            end
                        elseif tData.owner == 1 then
                            tData.colour = GOAP.territoryRedColour
                            if tData.border == true then
                                tData.colour[4] = 0.55
                            else
                                tData.colour[4] = 0.4
                            end
                        elseif tData.owner == 2 then
                            tData.colour = GOAP.territoryBlueColour
                            if tData.border == true then
                                tData.colour[4] = 0.55
                            else
                                tData.colour[4] = 0.4
                            end
                        elseif tData.owner == 9 then
                            tData.colour = GOAP.territoryContendedColour        
                        else
                            tData.colour = GOAP.territoryVoidColour        
                            env.error(("GOAP, phaseA_updateTerrain: colour terrain error cause of owner not identified"))                    
                        end   
                    end

                    GOAP.changePhase()
                    timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
                    if GOAP.debugProcessDetail then
                        --dumpTable("GOAP.terrainDB.lua", GOAP.TerrainDb)
                    end

                else
                    for tId, tData in pairs(tblTerrain.towns) do
                        if tId == phase_index then
                            
                            -- get info
                            if GOAP.debugProcessDetail then
                                --env.info(("GOAP, phaseA_updateTerrain: doing: " .. tostring(tId)))
                            end

                            -- perform update
                            if tData and type(tData) == "table" then

                                local vec3 = GOAP.townToVec3(tData.display_name)
                                if vec3 then

                                    -- check border
                                    if tData.proxy then
                                        
                                        for dir, didData in pairs(tData.proxy) do
                                            local newOwn = GOAP.updateProxyOwner(tblTerrain, didData.name)
                                            didData.owner = newOwn
                                        end

                                        for dir, didData in pairs(tData.proxy) do
                                            if didData.owner ~= tData.owner then
                                                --if didData.owner > -1 then
                                                    tData.border = true
                                                --end
                                            end
                                        end
                                    end

                                    local _volume = {
                                        id = world.VolumeType.SPHERE,
                                        params = {
                                            point = vec3,
                                            radius = GOAP.townControlRadius
                                        }
                                    }
                                    
                                    local _groupList = {}

                                    local _search = function(_unit)
                                        pcall(function()
                                            if _unit ~= nil and not _unit:hasAttribute("Air") and not _unit:hasAttribute("Ships") then
                                                local gr    = _unit:getGroup()
                                                if gr then
                                                    local grId  = gr:getID()
                                                    local grCoa = gr:getCoalition()

                                                    local allow = true
                                                    if #_groupList > 0 then
                                                        for gIn, gData in pairs(_groupList) do
                                                            if gData.id == grId then
                                                                allow = false
                                                            end
                                                        end
                                                    end

                                                    if allow == true then
                                                        _groupList[#_groupList+1] = {id = grId, group = gr, coa = grCoa}
                                                    end
                                                end

                                            end
                                        end)
                                        return true
                                    end
                                
                                    world.searchObjects(Object.Category.UNIT, _volume, _search)

                                    if #_groupList > 0 then
                                        local blueHasGroups = false
                                        local redHasGroups = false
                                        local neutralHasGroups = false
                    
                                        for gID, gDATA in pairs(_groupList) do
                                            local grdata = gDATA.group
                                            local coa = grdata:getCoalition()
                                            if coa == 2 then
                                                blueHasGroups = true
                                            elseif coa == 1 then
                                                redHasGroups = true
                                            elseif coa == 0 then
                                                neutralHasGroups = true
                                            end


                                            --[[
                                            local str, coa, atr = grdata:getClass()
                                            if str and coa and atr then
                                                if tData.coalition then
                                                    for cId, cData in pairs(tData.coalition) do
                                                        if cId == coa then
                                                            cData[gDATA.id] = {strenght = str, attributes = atr, plan = false}
                                                            if coa == 2 then
                                                                blueHasGroups = true
                                                            elseif coa == 1 then
                                                                redHasGroups = true
                                                            elseif coa == 0 then
                                                                neutralHasGroups = true
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                env.error(("GOAP, phaseA_updateTerrain: missing str coa atr for group: " .. tostring(gDATA.id)))
                                            end
                                            --]]--

                                        end

                                        if blueHasGroups and not redHasGroups and not neutralHasGroups then
                                            tData.owner = 2
                                        elseif redHasGroups and not blueHasGroups and not neutralHasGroups then
                                            tData.owner = 1
                                        elseif neutralHasGroups and not blueHasGroups and not redHasGroups then
                                            tData.owner = 0
                                        else
                                            tData.owner = 9
                                        end
                                    end

                                    if tData.value then
                                        local base = math.floor(tData.size/100)
                                        local borderExtra = 0
                                        local contendedExtra = 0
                                        local majorCityExtra = 0
                                        if tData.majorCity == true then
                                            majorCityExtra = 50
                                        end
                                        if tData.border == true then
                                            borderExtra = 50
                                        end
                                        if tData.owner == 9 then
                                            contendedExtra = 100
                                        end

                                        tData.value = base + borderExtra + contendedExtra + majorCityExtra

                                    end


                                else
                                    env.error(("GOAP, phaseA_updateTerrain: town missing vec3"))
                                end
                    
                            else
                                env.error(("GOAP, phaseA_updateTerrain: town missing tData"))
                            end
                        end
                    end

                    -- update phase_index
                    phase_index = phase_index + 1
                    timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)

                end
            else
                env.error(("GOAP, phaseA_updateTerrain: tblTerrain.towns missing"))
            end
        else
            env.error(("GOAP, phaseA_updateTerrain: tblTerrain missing"))
        end
    end -- phase check
end

-- collect intel -NEW

function GOAP.phaseB_createORBAT_INTEL()
    GOAP.dbORBAT = {}
    for cId, cNum in pairs(coalition.side) do
        if GOAP.debugProcessDetail then
            env.info(("GOAP, phaseC_updateIntel: updating coa " .. tostring(cId) .. ", id num: " .. tostring(cNum)))   
        end      

        for gId, gData in pairs(coalition.getGroups(cNum)) do
            local gName = gData:getName()
            if gData:getCategory() == 3 or gData:getCategory() == 4 then
                if GOAP.debugProcessDetail then
                    env.info(("GOAP, phaseB_createORBAT_INTEL: adding intel on static " .. tostring(gName)))   
                end
                local coa = gData:getCoalition()
                local t_Id = gData:getID()
                local tgtType = gData:getTypeName()
                local tgtPos = gData:getPosition().p
                local tgtLife = gData:getLife()                                 
                for xCoa, xData in pairs(GOAP.intel) do
                    if coa ~= xCoa then
                        local id = t_Id
                        local tgtData = {}
                        tgtData.type = tgtType
                        tgtData.pos = tgtPos
                        tgtData.static = true
                        tgtData.strenght = tgtLife
                        tgtData.time = timer.getTime()

                        xData[id] = tgtData
                    end
                end
            else

                local gTbl = GOAP.groupTableCheck(gName)
                if gTbl then
                    if GOAP.debugProcessDetail then
                        env.info(("GOAP, phaseB_createORBAT_INTEL: adding intel on unit or else " .. tostring(gName)))   
                    end
                    local g_pos = gTbl:getLeadPos()


                    GOAP.dbORBAT[#GOAP.dbORBAT+1] = {id = gTbl:getID() , Group = gTbl, coa = gTbl:getCoalition(), pos = g_pos}
                    
                end
                
            end
        end        
    end
end


-- collect intel
--[[
local GOAP.dbORBAT = {}
function GOAP.phaseB_createORBAT_INTEL(tblMission)
    for coalitionID,coalition in pairs(tblMission["coalition"]) do
        for countryID,country in pairs(coalition["country"]) do
            for attrID,attr in pairs(country) do
                if attrID ~= "static" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local gName = env.getValueDictByKey(group.name)
                                if gName then
                                    local gTbl = GOAP.groupTableCheck(gName)
                                    if gTbl then
                                        GOAP.dbORBAT[#GOAP.dbORBAT+1] = {id = gTbl:getID() , Group = gTbl, coa = gTbl:getCoalition()}
                                    end
                                end
                            end
                        end
                    end
                elseif attrID == "static" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local gName = env.getValueDictByKey(group.name)
                                if gName then
                                    local gTbl = Airbase.getByName(gName)
                                    if not gTbl then
                                        gTbl = StaticObject.getByName(gName)
                                    end

                                    if gTbl then
                                        if gTbl:getCategory() == 3 or gTbl:getCategory() == 4 then 
                                            if GOAP.debugProcessDetail then
                                                env.info(("GOAP, phaseB_createORBAT_INTEL: adding intel on static " .. tostring(gName)))   
                                            end
                                            local coa = gTbl:getCoalition()
                                            local t_Id = gTbl:getID()
                                            local tgtType = gTbl:getTypeName()
                                            local tgtPos = gTbl:getPosition().p
                                            local tgtLife = gTbl:getLife()                                 
                                            for xCoa, xData in pairs(GOAP.intel) do
                                                if coa ~= xCoa then
                                                    local id = t_Id
                                                    local tgtData = {}
                                                    tgtData.type = tgtType
                                                    tgtData.pos = tgtPos
                                                    tgtData.static = true
                                                    tgtData.strenght = tgtLife
                                                    tgtData.time = timer.getTime()
                        
                                                    xData[id] = tgtData
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
    if GOAP.debugProcessDetail then
        dumpTable("GOAP.dbORBAT.lua", GOAP.dbORBAT)
    end
end
--]]--
function GOAP.phaseB_updateORBAT()

    if phase == "B" then        
        if #GOAP.dbORBAT ~= 0 then
            
            -- check if Cycle is done
            if phase_index > #GOAP.dbORBAT then
                
                -- end loop
                GOAP.changePhase()
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
                if GOAP.debugProcessDetail then
                    --dumpTable("GOAP.dbORBAT.lua", GOAP.dbORBAT)
                    env.info(("GOAP, phaseB_updateORBAT: phase B completed"))
                end
            else
                for gId, gData in pairs(GOAP.dbORBAT) do
                    if gId == phase_index then
                        if gData.Group then

                            -- update position
                            local g = gData.Group
                            local newPos = g:getLeadPos()
                            gData.pos = newPos

                            local str, coa, atr = g:getClass()
                            if str and coa and atr then
                                gData.strenght = str
                                gData.attributes = atr
                                gData.plan = false
                
                            else
                                env.error(("GOAP, phaseB_updateORBAT: missing str coa atr for group: " .. tostring(gId)))
                            end


                            if GOAP.debugProcessDetail then
                                --env.info(("GOAP, phaseB_updateORBAT: update pos of group id: " .. tostring(gId)))
                            end
                        end
                    end
                end
                phase_index = phase_index + 1
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
            end
        else
            env.error(("GOAP, phaseB_updateORBAT: GOAP.dbORBAT is equal to zero"))
        end

    end
end

function GOAP.phaseC_updateIntel()

    if phase == "C" then        
        if #GOAP.dbORBAT ~= 0 then
            
            -- check if Cycle is done
            if phase_index > #GOAP.dbORBAT then
                
                -- remove obsolete
                for coa, coaData in pairs(GOAP.intel) do
                    for gId, gData in pairs(coaData) do
                        if gData.time then
                            local delta = timer.getTime() - gData.time
                            if delta > GOAP.obsoleteIntelValue then
                                if GOAP.debugProcessDetail then
                                    env.info(("GOAP, phaseC_updateIntel: cleaning entry: " .. tostring(gId)))
                                end
                                
                                coaData[gId] = nil
                            end
                        else
                            env.error(("GOAP, phaseC_updateIntel: cleaning entry for missing time: " .. tostring(gId)))
                            coaData[gId] = nil
                        end
                    end
                end
                
                -- end loop
                GOAP.changePhase()
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
                if GOAP.debugProcessDetail then
                    --dumpTable("GOAP.intel.lua", GOAP.intel)
                    env.info(("GOAP, phaseC_updateIntel: phase C completed"))
                end
            else
                for gId, gData in pairs(GOAP.dbORBAT) do
                    if gId == phase_index then
                        local gr = gData.Group
                        gr:hasTargets()
                    end
                end
                phase_index = phase_index + 1
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
            end
        else
            env.error(("GOAP, phaseC_updateIntel: GOAP.dbORBAT is equal to zero"))
        end

    end
end

function GOAP.phaseF_exportTable(tblTerrain, san) -- upgrade with group positioning inside a table

    if phase == "F" then
        if tblTerrain then
            if tblTerrain.towns then

                if GOAP.debugProcessDetail then
                    env.info(("GOAP, phaseF_exportTable: phase F completed"))
                end
                
                timer.scheduleFunction(GOAP.performPhaseCycle, {}, timer.getTime() + GOAP.phaseCycleTimer)
                GOAP.exportTable(san)
                GOAP.changePhase()

            end
        end
    end
end

-- do GOAP
---------------------------add

-- back to update
---------------------------add


-- ## GOAP UTILS

function GOAP.getDist(point1, point2)
    local xUnit = point1.x
    local yUnit = point1.z
    local xZone = point2.x
    local yZone = point2.z
    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone
    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function GOAP.groupTableCheck(group)
    if group then
        if type(group) == 'string' then -- assuming name
            local groupTable = Group.getByName(group)

            if not groupTable then
                groupTable = StaticObject.getByName(group)
            end

            if groupTable then
                return groupTable
            else
                return nil
            end
        elseif type(group) == 'table' then
            return group
        else
            env.error(("GOAP, groupTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, groupTableCheck: missing variable"))
        return nil
    end
end

function GOAP.townTableCheck(town)
    if town then
        if type(town) == 'string' then -- assuming name
            local townTable = nil
            for tName, tData in pairs(GOAP.TerrainDb.towns) do
                if town == tData.display_name then
                    return tData
                end
            end
            env.error(("GOAP, townTableCheck: no town available"))
            return nil

        elseif type(town) == 'table' then
            return town
        else
            env.error(("GOAP, townTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, townTableCheck: missing variable"))
        return nil
    end
end

function GOAP.townToVec3(town)
    local placeData = GOAP.townTableCheck(town)
    --["Strawberry Hill"] = { latitude = 37.619965, longitude = -114.513327, display_name = "Strawberry Hill")},
    if placeData then
        local V2 = coord.LLtoLO(placeData.latitude, placeData.longitude, 0)
        if V2 then
            local V3y = land.getHeight({x = V2.x, y = V2.z})
            local Sty = land.getSurfaceType({x = V2.x, y = V2.z})
            if V3y and Sty then
                local V3 = {x = V2.x, y = V3y, z = V2.z}
                return V3, Sty
            else
                return false
            end
        else
            return false
        end 
    else
        return false
    end
end

function GOAP.unitTableCheck(unit)
    if unit then
        if type(unit) == 'string' then -- assuming name
            local unitTable = Unit.getByName(unit)
            return unitTable
        elseif type(unit) == 'table' then
            return unit
        else
            env.error(("GOAP, unitTableCheck: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, unitTableCheck: missing variable"))
        return nil
    end
end

function GOAP.vec3Check(vec3)
    if vec3 then
        if type(vec3) == 'table' then -- assuming name
            if vec3.x and vec3.y and vec3.z then			
                return vec3
            else
                env.error(("GOAP, vec3Check: wrong vector format"))
                return nil
            end
        else
            env.error(("GOAP, vec3Check: wrong variable"))
            return nil
        end
    else
        env.error(("GOAP, vec3Check: missing variable"))
        return nil
    end
end

function GOAP.roundNumber(num, idp)
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end 

function GOAP.buildWP(point, overRideForm, overRideSpeed)

    if point then 
        local wp = {}
        wp.x = point.x

        if point.z then
            wp.y = point.z
        else
            wp.y = point.y
        end
        local form, speed

        if point.speed and not overRideSpeed then
            wp.speed = point.speed
        elseif type(overRideSpeed) == 'number' then
            wp.speed = overRideSpeed
        else
            wp.speed = 18/3.6
        end

        if point.form and not overRideForm then
            form = point.form
        else
            form = overRideForm
        end

        if not form then
            wp.action = 'Off Road'
        else
            form = string.lower(form)
            if form == 'off_road' or form == 'off road' then
                wp.action = 'Off Road'
            elseif form == 'on_road' or form == 'on road' then
                wp.action = 'On Road'
            elseif form == 'rank' or form == 'line_abrest' or form == 'line abrest' or form == 'lineabrest'then
                wp.action = 'Rank'
            elseif form == 'cone' then
                wp.action = 'Cone'
            elseif form == 'diamond' then
                wp.action = 'Diamond'
            elseif form == 'vee' then
                wp.action = 'Vee'
            elseif form == 'echelon_left' or form == 'echelon left' or form == 'echelonl' then
                wp.action = 'EchelonL'
            elseif form == 'echelon_right' or form == 'echelon right' or form == 'echelonr' then
                wp.action = 'EchelonR'
            else
                wp.action = 'Off Road' -- if nothing matched
            end
        end

        wp.type = 'Turning Point'

        return wp
    else
        return false
    end
end

function GOAP.getRandPointInCircle(point, radius, innerRadius)
    local theta = 2*math.pi*math.random()
    local rad = math.random() + math.random()
    if rad > 1 then
        rad = 2 - rad
    end

    local radMult
    if innerRadius and innerRadius <= radius then
        radMult = (radius - innerRadius)*rad + innerRadius
    else
        radMult = radius*rad
    end

    if not point.z then --might as well work with vec2/3
        point.z = point.y
    end

    local rndCoord
    if radius > 0 then
        rndCoord = {x = math.cos(theta)*radMult + point.x, y = math.sin(theta)*radMult + point.z}
    else
        rndCoord = {x = point.x, y = point.z}
    end
    return rndCoord
end

function GOAP.getRandTerrainPointInCircle(var, radius, innerRadius)
    local point = GOAP.vec3Check(var)	
    if point and radius and innerRadius then
        
        for i = 1, 5 do
            local coordRun = GOAP.getRandPointInCircle(point, radius, innerRadius)
            local destlandtype = land.getSurfaceType({coordRun.x, coordRun.z})
            if destlandtype == 1 or destlandtype == 4 then
                return coordRun
            end
        end
        return nil -- this means that no valid result has found
        
    end
end

function GOAP.deepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function GOAP.addTgtToKnownTarget(tData, coa)
    if tData then
        if tData.object then
            if type(tData.object) == "table" and tData.object:getCategory() == 1 then
                local tgtType = "unknown"
                local tgtPos = "unknown"

                local t_Id = tData.object:getID()
                tgtCoa = tData.object:getCoalition()
                tgtType = tData.object:getTypeName()
                tgtPos = tData.object:getPosition().p
                if GOAP.debugProcessDetail then
                    env.info(("GOAP.addTgtToKnownTarget, data: t_type: " .. tostring(tgtType)))
                end

                for xCoa, xData in pairs(GOAP.intel) do
                    if coa == xCoa then
                        local id = t_Id
                        local tgtData = {}
                        tgtData.type = tgtType
                        tgtData.pos = tgtPos
                        tgtData.time = timer.getTime() 
                        tgtData.strenght = tData.object:getLife()
                        tgtData.coa = tgtCoa
                        --tgtData.identifierCoa = coa

                        xData[id] = tgtData -- xData
                    end
                end

                return true         
            end
        else
            env.error(("GOAP.addTgtToKnownTarget, missing tData.object"))
            return false
        end

    else
        env.error(("GOAP.addTgtToKnownTarget, missing variable"))
        return false	
    end

end

function GOAP.findGroupInRange(support_point, attribute, distance, coalition)
    if support_point then
        
        local mindistance =   distance
        local curGroup = nil
        local volS = {
        id = world.VolumeType.SPHERE,
        params = {
            point = support_point,
            radius = distance
            }
        }
        
        local ifFound = function(foundItem, val)
            local funcCheck = nil
            if type(attribute) == "string" then
                funcCheck = function(attribute)
                    if foundItem:hasAttribute(attribute) then
                        return true
                    else
                        return false
                    end
                end
            elseif type(attribute) == "table" then
                funcCheck = function(attribute)
                    local hasVal = false
                    for att, attVal in pairs(attribute) do
                        if foundItem:hasAttribute(attVal) then
                            hasVal = true
                        end
                    end

                    if hasVal == true then
                        return true
                    else
                        return false
                    end

                end
            end

            if funcCheck(attribute) == true then
                
                local proceed = true
                if coalition then
                    local coaCheck = foundItem:getCoalition()
                    if coalition == coaCheck then
                        proceed = true
                    else
                        proceed = false
                    end
                end
                
                if proceed == true then
                    local itemPos = foundItem:getPosition().p
                    if itemPos then
                        local dist = GOAP.getDist(itemPos, support_point)
                        if dist < mindistance and dist > 1000 then
                            mindistance = dist
                            local foundGroup = foundItem:getGroup()
                            curGroup = foundGroup
                        end
                    end
                end
            end       
        end
        world.searchObjects(Object.Category.UNIT, volS, ifFound)

        if curGroup and mindistance then
            return curGroup
        else
            return false
        end
    end
end

GOAP.getNextUnitId = function()
    DSMC_baseUcounter = DSMC_baseUcounter + 1

    return DSMC_baseUcounter
end
GOAP.getNextGroupId = function()
    DSMC_baseGcounter = DSMC_baseGcounter + 1

    return DSMC_baseGcounter
end

-- ## GOAP UTILS FROM MIST

local GOAPDynAddIndex 		= {[' air '] = 0, [' hel '] = 0, [' gnd '] = 0, [' bld '] = 0, [' static '] = 0, [' shp '] = 0}
local GOAPAddedObjects 		= {}  -- da mist
local GOAPAddedGroups 		= {}  -- da mist


GOAP.tblObjectshapeNames = {
    ["Landmine"] = "landmine",
    ["FARP CP Blindage"] = "kp_ug",
    ["FARP Ammo Dump Coating"] = "SetkaKP",   
    ["FARP Fuel Depot"] = "GSM Rus",     
    ["FARP Tent"] = "PalatkaB",    
    ["Subsidiary structure C"] = "saray-c",
    ["Barracks 2"] = "kazarma2",
    ["Small house 2C"] = "dom2c",
    ["Military staff"] = "aviashtab",
    ["Tech hangar A"] = "ceh_ang_a",
    ["Oil derrick"] = "neftevyshka",
    ["Tech combine"] = "kombinat",
    ["Garage B"] = "garage_b",
    ["Airshow_Crowd"] = "Crowd1",
    ["Hangar A"] = "angar_a",
    ["Repair workshop"] = "tech",
    ["Subsidiary structure D"] = "saray-d",
    ["Small house 1C area"] = "dom2c-all",
    ["Tank 2"] = "airbase_tbilisi_tank_01",
    ["Boiler-house A"] = "kotelnaya_a",
    ["Workshop A"] = "tec_a",
    ["Small werehouse 1"] = "s1",
    ["Garage small B"] = "garagh-small-b",
    ["Small werehouse 4"] = "s4",
    ["Shop"] = "magazin",
    ["Subsidiary structure B"] = "saray-b",
    ["Coach cargo"] = "wagon-gruz",
    ["Electric power box"] = "tr_budka",
    ["Tank 3"] = "airbase_tbilisi_tank_02",
    ["Red_Flag"] = "H-flag_R",
    ["Container red 3"] = "konteiner_red3",
    ["Garage A"] = "garage_a",
    ["Hangar B"] = "angar_b",
    ["Black_Tyre"] = "H-tyre_B",
    ["Cafe"] = "stolovaya",
    ["Restaurant 1"] = "restoran1",
    ["Subsidiary structure A"] = "saray-a",
    ["Container white"] = "konteiner_white",
    ["Warehouse"] = "sklad",
    ["Tank"] = "bak",
    ["Railway crossing B"] = "pereezd_small",
    ["Subsidiary structure F"] = "saray-f",
    ["Farm A"] = "ferma_a",
    ["Small werehouse 3"] = "s3",
    ["Water tower A"] = "wodokachka_a",
    ["Railway station"] = "r_vok_sd",
    ["Coach a tank blue"] = "wagon-cisterna_blue",
    ["Supermarket A"] = "uniwersam_a",
    ["Coach a platform"] = "wagon-platforma",
    ["Garage small A"] = "garagh-small-a",
    ["TV tower"] = "tele_bash",
    ["Comms tower M"] = "tele_bash_m",
    ["Small house 1A"] = "domik1a",
    ["Farm B"] = "ferma_b",
    ["GeneratorF"] = "GeneratorF",
    ["Cargo1"] = "ab-212_cargo",
    ["Container red 2"] = "konteiner_red2",
    ["Subsidiary structure E"] = "saray-e",
    ["Coach a passenger"] = "wagon-pass",
    ["Black_Tyre_WF"] = "H-tyre_B_WF",
    ["Electric locomotive"] = "elektrowoz",
    ["Shelter"] = "ukrytie",
    ["Coach a tank yellow"] = "wagon-cisterna_yellow",
    ["Railway crossing A"] = "pereezd_big",
    [".Ammunition depot"] = "SkladC",
    ["Small werehouse 2"] = "s2",
    ["Windsock"] = "H-Windsock_RW",
    ["Shelter B"] = "ukrytie_b",
    ["Fuel tank"] = "toplivo-bak",
    ["Locomotive"] = "teplowoz",
    [".Command Center"] = "ComCenter",
    ["Pump station"] = "nasos",
    ["Black_Tyre_RF"] = "H-tyre_B_RF",
    ["Coach cargo open"] = "wagon-gruz-otkr",
    ["Subsidiary structure 3"] = "hozdomik3",
    ["White_Tyre"] = "H-tyre_W",
    ["Subsidiary structure G"] = "saray-g",
    ["Container red 1"] = "konteiner_red1",
    ["Small house 1B area"] = "domik1b-all",
    ["Subsidiary structure 1"] = "hozdomik1",
    ["Container brown"] = "konteiner_brown",
    ["Small house 1B"] = "domik1b",
    ["Subsidiary structure 2"] = "hozdomik2",
    ["Chemical tank A"] = "him_bak_a",
    ["WC"] = "WC",
    ["Small house 1A area"] = "domik1a-all",
    ["White_Flag"] = "H-Flag_W",
    ["Airshow_Cone"] = "Comp_cone",
}

function GOAP.zoneToVec3(zone)
    local new = {}
	if type(zone) == 'table' then
		if zone.point then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
		elseif zone.x and zone.y and zone.z then
			return zone
		end
		return new
	elseif type(zone) == 'string' then
		zone = trigger.misc.getZone(zone)
		if zone then
			new.x = zone.point.x
			new.y = zone.point.y
			new.z = zone.point.z
			return new
		end
	end
end

function GOAP.round(num, idp)
    local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function GOAP.getPayload(unitName)
    -- refactor to search by groupId and allow groupId and groupName as inputs
	local unitTbl = Unit.getByName(unitName)
	local unitId = unitTbl:getID()
	local gpTbl = unitTbl:getGroup()
	local gpId = gpTbl:getID()

	if gpId and unitId then
		for coa_name, coa_data in pairs(env.mission.coalition) do
			if (coa_name == 'red' or coa_name == 'blue') and type(coa_data) == 'table' then
				if coa_data.country then --there is a country table
					for cntry_id, cntry_data in pairs(coa_data.country) do
						for obj_type_name, obj_type_data in pairs(cntry_data) do
							if obj_type_name == "helicopter" or obj_type_name == "ship" or obj_type_name == "plane" or obj_type_name == "vehicle" then	-- only these types have points
								if ((type(obj_type_data) == 'table') and obj_type_data.group and (type(obj_type_data.group) == 'table') and (#obj_type_data.group > 0)) then	--there's a group!
									for group_num, group_data in pairs(obj_type_data.group) do
										if group_data and group_data.groupId == gpId then
											for unitIndex, unitData in pairs(group_data.units) do --group index
												if unitData.unitId == unitId then
													return unitData.payload
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
		if GOAP.debugProcessDetail then
			env.info(ModuleName .. " getPayload error, no gId or unitId")
		end	
		return false
	end
	return
end

function GOAP.deepCopy(object)
    local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

function GOAP.dynAdd(newGroup)
    local cntry = newGroup.country
	if newGroup.countryId then
		cntry = newGroup.countryId
	end

	local groupType = newGroup.category
	local newCountry = ''
	-- validate data
	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
	end

	if newCountry == '' then
		if GOAP.debugProcessDetail then
			env.info(ModuleName .. " dynAdd Country not found")
		end		
		return false
	end

	local newCat = ''
	for catName, catId in pairs(Unit.Category) do
		if type(groupType) == 'string' then
			if tostring(catName) == string.upper(groupType) then
				newCat = catName
			end
		elseif type(groupType) == 'number' then
			if catId == groupType then
				newCat = catName
			end
		end

		if catName == 'GROUND_UNIT' and (string.upper(groupType) == 'VEHICLE' or string.upper(groupType) == 'GROUND') then
			newCat = 'GROUND_UNIT'
		elseif catName == 'AIRPLANE' and string.upper(groupType) == 'PLANE' then
			newCat = 'AIRPLANE'
		end
	end
	local typeName
	if newCat == 'GROUND_UNIT' then
		typeName = ' gnd '
	elseif newCat == 'AIRPLANE' then
		typeName = ' air '
	elseif newCat == 'HELICOPTER' then
		typeName = ' hel '
	elseif newCat == 'SHIP' then
		typeName = ' shp '
	elseif newCat == 'BUILDING' then
		typeName = ' bld '
	end
	if newGroup.clone or not newGroup.groupId then
		GOAPDynAddIndex[typeName] = GOAPDynAddIndex[typeName] + 1
		newGroup.groupId = GOAP.getNextGroupId()
    end    
	if newGroup.groupName or newGroup.name then
		if newGroup.groupName then
			newGroup.name = newGroup.groupName
		elseif newGroup.name then
			newGroup.name = newGroup.name
		end
	end

	if newGroup.clone or not newGroup.name then
		newGroup.name = tostring(newCountry .. tostring(typeName) .. GOAPDynAddIndex[typeName])
	end

	if not newGroup.hidden then
		newGroup.hidden = false
	end

	if not newGroup.visible then
		newGroup.visible = false
	end

	if (newGroup.start_time and type(newGroup.start_time) ~= 'number') or not newGroup.start_time then
		if newGroup.startTime then
			newGroup.start_time = GOAP.round(newGroup.startTime)
		else
			newGroup.start_time = 0
		end
	end

    for unitIndex, unitData in pairs(newGroup.units) do
        local originalName = newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name
        if newGroup.clone or not unitData.unitId then
            newGroup.units[unitIndex].unitId = GOAP.getNextUnitId()   -- DSMC
        end
        if newGroup.units[unitIndex].unitName or newGroup.units[unitIndex].name then
            if newGroup.units[unitIndex].unitName then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].unitName
            elseif newGroup.units[unitIndex].name then
                newGroup.units[unitIndex].name = newGroup.units[unitIndex].name
            end
        end
        if newGroup.clone or not unitData.name then
            newGroup.units[unitIndex].name = tostring(newGroup.name .. ' unit' .. unitIndex)
        end

        if not unitData.skill then
            newGroup.units[unitIndex].skill = 'Random'
        end

        if newCat == 'AIRPLANE' or newCat == 'HELICOPTER' then
            if newGroup.units[unitIndex].alt_type and newGroup.units[unitIndex].alt_type ~= 'BARO' or not newGroup.units[unitIndex].alt_type then
                newGroup.units[unitIndex].alt_type = 'RADIO'
            end
            if not unitData.speed then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].speed = 60
                end
            end
            if not unitData.payload then
                newGroup.units[unitIndex].payload = GOAP.getPayload(originalName)
            end
            if not unitData.alt then
                if newCat == 'AIRPLANE' then
                    newGroup.units[unitIndex].alt = 2000
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 150
                elseif newCat == 'HELICOPTER' then
                    newGroup.units[unitIndex].alt = 500
                    newGroup.units[unitIndex].alt_type = 'RADIO'
                    newGroup.units[unitIndex].speed = 60
                end
            end
            
        elseif newCat == 'GROUND_UNIT' then
            if nil == unitData.playerCanDrive then
                unitData.playerCanDrive = true
            end
        
        end
        GOAPAddedObjects[#GOAPAddedObjects + 1] = GOAP.deepCopy(newGroup.units[unitIndex])
    end

	GOAPAddedGroups[#GOAPAddedGroups + 1] = GOAP.deepCopy(newGroup)
	if newGroup.route and not newGroup.route.points then
		if not newGroup.route.points and newGroup.route[1] then
			local copyRoute = newGroup.route
			newGroup.route = {}
			newGroup.route.points = copyRoute
		end
	end
	newGroup.country = newCountry

	-- sanitize table
	newGroup.groupName = nil
	newGroup.clone = nil
	newGroup.category = nil
	newGroup.country = nil

	newGroup.tasks = {}

	for unitIndex, unitData in pairs(newGroup.units) do
		newGroup.units[unitIndex].unitName = nil
	end

	coalition.addGroup(country.id[newCountry], Unit.Category[newCat], newGroup)

	return newGroup

end

function GOAP.dynAddStatic(newObj)

	if newObj.units and newObj.units[1] then 
		for entry, val in pairs(newObj.units[1]) do
			if newObj[entry] and newObj[entry] ~= val or not newObj[entry] then
				newObj[entry] = val
			end
		end
	end
	--log:info(newObj)

	local cntry = newObj.country
	if newObj.countryId then
		cntry = newObj.countryId
	end

	local newCountry = ''

	for countryId, countryName in pairs(country.name) do
		if type(cntry) == 'string' then
			cntry = cntry:gsub("%s+", "_")
			if tostring(countryName) == string.upper(cntry) then
				newCountry = countryName
			end
		elseif type(cntry) == 'number' then
			if countryId == cntry then
				newCountry = countryName
			end
		end
    end

	if newCountry == '' then
		if GOAP.debugProcessDetail then
			env.info(ModuleName .. " dynAddStatic Country not found")
		end
		return false
    end

	if newObj.clone or not newObj.groupId then
		newObj.groupId = GOAP.getNextGroupId()
    end
 
	if newObj.clone or not newObj.unitId then -- 2
		newObj.unitId = GOAP.getNextUnitId()
	end

   -- newObj.name = newObj.unitName
	if newObj.clone or not newObj.name then
		GOAPDynAddIndex[' static '] = GOAPDynAddIndex[' static '] + 1
		newObj.name = (newCountry .. ' static ' .. GOAPDynAddIndex[' static '])
    end

	if not newObj.dead then
		newObj.dead = false
	end

	if not newObj.heading then
		newObj.heading = math.random(360)
	end
	
	if newObj.categoryStatic then
		newObj.category = newObj.categoryStatic
	end
	if newObj.mass then
		newObj.category = 'Cargos'
	end
	
	if newObj.shapeName then
		newObj.shape_name = newObj.shapeName
    end
	if not newObj.shape_name then
		if GOAP.debugProcessDetail then
			env.info(ModuleName .. " dynAddStatic shape not found")
		end
		if GOAP.tblObjectshapeNames[newObj.type] then
			newObj.shape_name = GOAP.tblObjectshapeNames[newObj.type]
		end
    end
	
	GOAPAddedObjects[#GOAPAddedObjects + 1] = GOAP.deepCopy(newObj)
	if newObj.x and newObj.y and newObj.type and type(newObj.x) == 'number' and type(newObj.y) == 'number' and type(newObj.type) == 'string' then

        --log:info('addStaticObject')
		coalition.addStaticObject(country.id[newCountry], newObj)
  
		return newObj
	end
	
	if GOAP.debugProcessDetail then
		env.info(ModuleName .. " dynAddStatic Failed to add static object due to missing or incorrect value")
    end	

	return false
end

function GOAP.vecmag(vec)
	return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
end

function GOAP.vecsub(vec1, vec2)
	return {x = vec1.x - vec2.x, y = vec1.y - vec2.y, z = vec1.z - vec2.z}
end

function GOAP.vecdp(vec1, vec2)
	return vec1.x*vec2.x + vec1.y*vec2.y + vec1.z*vec2.z
end

function GOAP.getNorthCorrection(gPoint)	--gets the correction needed for true north
	local point = GOAP.deepCopy(gPoint)
	if not point.z then --Vec2; convert to Vec3
		point.z = point.y
		point.y = 0
	end
	local lat, lon = coord.LOtoLL(point)
	local north_posit = coord.LLtoLO(lat + 1, lon)
	return math.atan2(north_posit.z - point.z, north_posit.x - point.x)
end

function GOAP.getHeading(unit, rawHeading)
	local unitpos = unit:getPosition()
	if unitpos then
		local Heading = math.atan2(unitpos.x.z, unitpos.x.x)
		if not rawHeading then
			Heading = Heading + GOAP.getNorthCorrection(unitpos.p)
		end
		if Heading < 0 then
			Heading = Heading + 2*math.pi	-- put heading in range of 0 to 2*pi
		end
		return Heading
	end
end

function GOAP.makeVec3(vec, y)
	if not vec.z then
		if vec.alt and not y then
			y = vec.alt
		elseif not y then
			y = 0
		end
		return {x = vec.x, y = y, z = vec.y}
	else
		return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
	end
end

function GOAP.getDir(vec, point)
	local dir = math.atan2(vec.z, vec.x)
	if point then
		dir = dir + GOAP.getNorthCorrection(point)
	end
	if dir < 0 then
		dir = dir + 2 * math.pi	-- put dir in range of 0 to 2*pi
	end
	return dir
end

function GOAP.toDegree(angle)
	return angle*180/math.pi
end

function GOAP.tostringLL(lat, lon, acc, DMS)

	local latHemi, lonHemi
	if lat > 0 then
		latHemi = 'N'
	else
		latHemi = 'S'
	end

	if lon > 0 then
		lonHemi = 'E'
	else
		lonHemi = 'W'
	end

	lat = math.abs(lat)
	lon = math.abs(lon)

	local latDeg = math.floor(lat)
	local latMin = (lat - latDeg)*60

	local lonDeg = math.floor(lon)
	local lonMin = (lon - lonDeg)*60

	if DMS then	-- degrees, minutes, and seconds.
		local oldLatMin = latMin
		latMin = math.floor(latMin)
		local latSec = GOAP.round((oldLatMin - latMin)*60, acc)

		local oldLonMin = lonMin
		lonMin = math.floor(lonMin)
		local lonSec = GOAP.round((oldLonMin - lonMin)*60, acc)

		if latSec == 60 then
			latSec = 0
			latMin = latMin + 1
		end

		if lonSec == 60 then
			lonSec = 0
			lonMin = lonMin + 1
		end

		local secFrmtStr -- create the formatting string for the seconds place
		if acc <= 0 then	-- no decimal place.
			secFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			secFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format('%02d', latMin) .. '\' ' .. string.format(secFrmtStr, latSec) .. '"' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format('%02d', lonMin) .. '\' ' .. string.format(secFrmtStr, lonSec) .. '"' .. lonHemi

	else	-- degrees, decimal minutes.
		latMin = GOAP.round(latMin, acc)
		lonMin = GOAP.round(lonMin, acc)

		if latMin == 60 then
			latMin = 0
			latDeg = latDeg + 1
		end

		if lonMin == 60 then
			lonMin = 0
			lonDeg = lonDeg + 1
		end

		local minFrmtStr -- create the formatting string for the minutes place
		if acc <= 0 then	-- no decimal place.
			minFrmtStr = '%02d'
		else
			local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
			minFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
		end

		return string.format('%02d', latDeg) .. ' ' .. string.format(minFrmtStr, latMin) .. '\'' .. latHemi .. '	 '
		.. string.format('%02d', lonDeg) .. ' ' .. string.format(minFrmtStr, lonMin) .. '\'' .. lonHemi

	end
end

function GOAP.ground_buildWP(point, overRideForm, overRideSpeed)

	local wp = {}
	wp.x = point.x

	if point.z then
		wp.y = point.z
	else
		wp.y = point.y
	end
	local form, speed

	if point.speed and not overRideSpeed then
		wp.speed = point.speed
	elseif type(overRideSpeed) == 'number' then
		wp.speed = overRideSpeed
	else
		wp.speed = GOAP.kmphToMps(20)
	end

	if point.form and not overRideForm then
		form = point.form
	else
		form = overRideForm
	end

	if not form then
		wp.action = 'Cone'
	else
		form = string.lower(form)
		if form == 'off_road' or form == 'off road' then
			wp.action = 'Off Road'
		elseif form == 'on_road' or form == 'on road' then
			wp.action = 'On Road'
		elseif form == 'rank' or form == 'line_abrest' or form == 'line abrest' or form == 'lineabrest'then
			wp.action = 'Rank'
		elseif form == 'cone' then
			wp.action = 'Cone'
		elseif form == 'diamond' then
			wp.action = 'Diamond'
		elseif form == 'vee' then
			wp.action = 'Vee'
		elseif form == 'echelon_left' or form == 'echelon left' or form == 'echelonl' then
			wp.action = 'EchelonL'
		elseif form == 'echelon_right' or form == 'echelon right' or form == 'echelonr' then
			wp.action = 'EchelonR'
		else
			wp.action = 'Cone' -- if nothing matched
		end
	end

	wp.type = 'Turning Point'

	return wp

end

function GOAP.kmphToMps(kmph)
	return kmph/3.6
end

function GOAP.tostringMGRS(MGRS, acc)
	if acc == 0 then
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph
	else
		return MGRS.UTMZone .. ' ' .. MGRS.MGRSDigraph .. ' ' .. string.format('%0' .. acc .. 'd', GOAP.round(MGRS.Easting/(10^(5-acc)), 0))
		.. ' ' .. string.format('%0' .. acc .. 'd', GOAP.round(MGRS.Northing/(10^(5-acc)), 0))
	end
end

--## Group added class function
--GOAP.goToRandomPoint(group, destination, GOAP.repositionDistance, 10, forceRoadUse)

function Group:groupRoadOnly()
    local grTbl = self
    if grTbl then
        local units = grTbl:getUnits()
        for uId, uData in pairs(units) do
            if uData:hasAttribute("Trucks") or uData:hasAttribute("Cars") or uData:hasAttribute("Unarmed vehicles") then
                if GOAP.debugProcessDetail then
                    env.info(("GOAP, groupRoadOnly found at least one road only unit!"))
                end
                return true
            end
        end
    end
    if GOAP.debugProcessDetail then
        env.info(("GOAP, groupRoadOnly no road only unit found, or no grTbl"))
    end
    
    return false
end

function Group:goToRandomPoint(Vec3destination, destRadius, destInnerRadius, useRoad, formation) -- move the group to a point or, if the point is missing, to a random position at about 2 km
    local group = self -- GOAP.groupTableCheck(var)
    if group then	   		
        local unit1 = group:getUnit(1)
        local curPoint = unit1:getPosition().p
        local point = Vec3destination --required
        local dist = GOAP.getDist(point,curPoint)
        if dist > 1000 then
            useRoad = true
        end

        local rndCoord = nil
        if point == nil then
            point = GOAP.getRandTerrainPointInCircle(group:getPosition().p, GOAP.emergencyWithdrawDistance*1.1, GOAP.emergencyWithdrawDistance*0.9) -- IMPROVE DEST POINT CHECKS!
            rndCoord = point
        end
        
        if point then	
            local radius = destRadius or 10
            local innerRadius = destInnerRadius or 1		
            local form = formation or 'Offroad'
            local heading = math.random()*2*math.pi
            --local speed = nil


            local useRoads
            if not useRoad then
                useRoads = group:groupRoadOnly()
            else
                useRoads = useRoad
            end
            
            local speed = nil
            if useRoads == false then
                speed = GOAP.outRoadSpeed
            else
                speed = GOAP.inRoadSpeed
            end

            local path = {}

            if heading >= 2*math.pi then
                heading = heading - 2*math.pi
            end
            
            if not rndCoord then
                rndCoord = GOAP.getRandTerrainPointInCircle(point, radius, innerRadius)
            end
            
            if rndCoord then

                local offset = {}
                local posStart = group:getLeadPos()
                if posStart then
                    offset.x = GOAP.roundNumber(math.sin(heading - (math.pi/2)) * 50 + rndCoord.x, 3)
                    offset.z = GOAP.roundNumber(math.cos(heading + (math.pi/2)) * 50 + rndCoord.y, 3)
                    path[#path + 1] = GOAP.buildWP(posStart, form, speed)


                    if useRoads == true and ((point.x - posStart.x)^2 + (point.z - posStart.z)^2)^0.5 > radius * 1.3 then
                        path[#path + 1] = GOAP.buildWP({x = posStart.x + 11, z = posStart.z + 11}, 'off_road', GOAP.outRoadSpeed)
                        path[#path + 1] = GOAP.buildWP(posStart, 'on_road', speed)
                        path[#path + 1] = GOAP.buildWP(offset, 'on_road', speed)
                    else
                        path[#path + 1] = GOAP.buildWP({x = posStart.x + 25, z = posStart.z + 25}, form, speed)
                    end

                    path[#path + 1] = GOAP.buildWP(offset, form, speed)
                    path[#path + 1] = GOAP.buildWP(rndCoord, form, speed)


                    if GOAP.debugProcessDetail then
                        --dumpTable("path.lua", path)
                    end
                    group:goRoute(path)

                    return
                end
            else
                env.error(("GOAP, goToRandomPoint failed, no valid coord available"))
            end
        else
            env.error(("GOAP, goToRandomPoint failed, no valid destination available"))
        end
    end
end

function Group:getLeadPos(group)
    group = self
    
    --if type(group) == 'string' then -- group name
        --group = Group.getByName(group)
    --end

    local units = group:getUnits()

    local leader = units[1]
    if not Unit.isExist(leader) then	-- SHOULD be good, but if there is a bug, this code future-proofs it then.
        local lowestInd = math.huge
        for ind, unit in pairs(units) do
            if Unit.isExist(unit) and ind < lowestInd then
                lowestInd = ind
                return unit:getPosition().p
            end
        end
    end
    if leader and Unit.isExist(leader) then	-- maybe a little too paranoid now...
        return leader:getPosition().p
    end
end

function Group:goRoute(path)
    local group = self -- GOAP.groupTableCheck(var)
    if group then
        local misTask = {
            id = 'Mission',
            params = {
                route = {
                    points = GOAP.deepCopy(path),
                },
            },
        }

        local groupCon = group:getController()
        if groupCon then
            groupCon:setTask(misTask)
            return true
        end
        return false
    end
end

--## CURRENT MISSION CONDITIONS

-- road usage
local forceRoadUse = nil
if env.mission.weather.clouds.iprecptns > 0 then
    forceRoadUse = true
end


--## AI INFORMATIVE CHECKS
function Group:hasTargets()
    local group = self --GOAP.groupTableCheck(var[1])
    if group then	
        local tblUnits = Group.getUnits(group)
        local coalition = Group.getCoalition(group)
        if table.getn(tblUnits) > 0 then
            local hastargets = false
            local tbltargets = {}
            for uId, uData in pairs(tblUnits) do
                local uController = uData:getController()
                local utblTargets = uController:getDetectedTargets()
                if utblTargets then
                    if table.getn(utblTargets) > 0 then
                        for _, _tData in pairs(utblTargets) do
                            tbltargets[#tbltargets+1] = _tData
                            hastargets = true
                        end
                    end
                else
                    env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " utblTargets is nil"))
                end
            end

            if hastargets == true then
                --dumpTable("tbltargets_" .. tostring(uId) .. ".lua", tbltargets)
                if GOAP.debugProcessDetail then
                    env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " has targets. Coalition: " .. tostring(coalition)))
                end
                

                -- update main tgt table
                local info_avail = false
                for _, tData in pairs(tbltargets) do
                    if GOAP.addTgtToKnownTarget(tData, coalition) then
                        info_avail = true
                    end
                end

                -- end function
                if info_avail then
                    return true, tbltargets
                else
                    if GOAP.debugProcessDetail then
                        env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " has contact but not identified yet"))
                    end
                    
                    return false
                end
            else
                if GOAP.debugProcessDetail then
                    --env.info(("GOAP, hasTargets: group .. " ..  tostring(Group.getName(group)) .. " do not have targets"))
                end
                
                return false
            end            
            
        else
            env.error(("GOAP.hasTargets: tblUnits has 0 units"))
            return false			
        end
    else
        env.error(("GOAP.hasTargets: group is nil"))
        return false	
    end	
end

function Group:groupLowAmmo()
    local group = self--GOAP.groupTableCheck(var)
    if group then	
        local tblUnits = group:getUnits()
        local groupSize = group:getSize()
        local groupOutAmmo = 0
        
        if tblUnits and groupSize then
            if table.getn(tblUnits) > 0 then
                for uId, uData in pairs(tblUnits) do
                    local uAmmo = uData:getAmmo()
                    if uAmmo then
                        for aId, aData in pairs(uAmmo) do
                            if aData.count == 0 then
                                groupOutAmmo = groupOutAmmo + 1
                            end
                        end
                    else    
                        groupOutAmmo = groupOutAmmo + 1
                    end
                end
            else
                env.error(("GOAP.groupLowAmmo, tblUnits is 0"))
                return false				
            end
        else
            env.error(("GOAP.groupLowAmmo, missing tblUnits or groupSize"))
            return false		
        end

        local fraction = groupOutAmmo/tonumber(groupSize)
        if fraction then
            if fraction > GOAP.outAmmoLowLevel then
                return true
            else
                return false
            end
        else
            env.error(("GOAP.groupLowAmmo, error calculating fraction"))
            return false		
        end
    end
end

function Group:groupHasLosses()
    local group = self -- GOAP.groupTableCheck(var)
    if group then		
        local curSize = group:getSize()
        local iniSize = group:getInitialSize()
        if iniSize == curSize then
            return false
        else
            return true
        end
    end
end

function Group:getClass()
    local group = self
    if group then
        local units = group:getUnits()
        local attrib = {}
        local strenght = 0
        local coa = group:getCoalition()
        if units and coa then
            for _, unit in pairs(units) do
            
                if unit:hasAttribute("Ground Units") then
                    if unit:hasAttribute("Air") or unit:hasAttribute("Ships") or unit:hasAttribute("Buildings") then -- cut off all "non ground units", safety check
                        return false

                    elseif unit:hasAttribute("Tanks") then
                        attrib[#attrib+1] = "Tank"
                        strenght = strenght + math.floor(unit:getLife0()*10/3)/10

                    elseif unit:hasAttribute("ATGM") then
                        attrib[#attrib+1] = "Ranged"
                        strenght = strenght + unit:getLife0()

                    elseif unit:hasAttribute("Artillery") then
                        attrib[#attrib+1] = "Arty"
                        strenght = strenght + unit:getLife0()  

                    elseif unit:hasAttribute("SAM") then
                        attrib[#attrib+1] = "MovingSAM"
                        strenght = strenght + 0 -- unit:getLife0()                         

                    elseif unit:hasAttribute("Air Defence vehicles") then
                        attrib[#attrib+1] = "AntiAir"
                        strenght = strenght + 0 -- unit:getLife0() 

                    elseif unit:hasAttribute("Armored vehicles") then
                        attrib[#attrib+1] = "Armored"
                        strenght = strenght + unit:getLife0()

                    elseif unit:hasAttribute("Armed vehicles") then
                        attrib[#attrib+1] = "Movers"
                        strenght = strenght + unit:getLife0()

                    elseif unit:hasAttribute("Unarmed vehicles") then
                        attrib[#attrib+1] = "Logistic"
                        strenght = strenght + 0             

                    elseif unit:hasAttribute("Infantry") then
                        attrib[#attrib+1] = "Infantry"
                        strenght = strenght + 0.1   
                    else
                        attrib[#attrib+1] = "Others"
                        strenght = strenght + 0
                    end
                else
                    return false
                end

            end


            return strenght, coa, attrib

        else
            env.error(("GOAP.getClass, missing units"))
            return false
        end
    else
        env.error(("GOAP.getClass, missing group"))
        return false
    end
end



--## AI BASIC STATE ACTION
function Group:groupGoQuiet()
    local group = self -- GOAP.groupTableCheck(var)
    if group then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 1) -- green -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.groupGoQuiet status quiet"))
        end			
    end
end

function Group:groupGoActive()
    local group = self -- GOAP.groupTableCheck(var)
    if group then	
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 3) -- return fire -- Ground or GROUND?
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.groupGoActive status active and return fire"))
        end				
    end
end

function Group:groupGoShoot()
    local group = self -- GOAP.groupTableCheck(var)
    if group then		
        local gController = group:getController()
        gController:setOption(AI.Option.Ground.id.ALARM_STATE, 2) -- red -- Ground or GROUND?
        gController:setOption(AI.Option.Ground.id.ROE, 2) -- open fire -- Ground or GROUND?
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.groupGoShoot status fire at will"))
        end			
    end
end

function Group:groupAllowDisperse()
    local group = self --GOAP.groupTableCheck(var)
    if group then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, GOAP.disperseActionTime) -- Ground or GROUND?
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupAllowDisperse will allow dispersal"))
            end		
        else
            env.error(("GOAP.groupAllowDisperse, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.error(("GOAP.groupAllowDisperse, missing group"))        
    end
end

function Group:groupPreventDisperse()
    local group = self -- GOAP.groupTableCheck(var)
    if group then
        local gController = group:getController()
        if gController then
            gController:setOption(AI.Option.Ground.id.DISPERSE_ON_ATTACK, false) -- Ground or GROUND?
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupPreventDisperse will prevent dispersal"))
            end		
        else
            env.error(("GOAP.groupPreventDisperse, missing controller for: " ..tostring(group:getName())))
        end
    else
        env.error(("GOAP.groupPreventDisperse, missing group"))    
    end
end


--## AI BASIC MOVEMENT & ACTION
function Group:goStop()
    local group = self
    if group then
        trigger.action.groupStopMoving(group)
        return true
    else
        env.error(("GOAP.goStop, missing variable"))
        return false
    end
end

function Group:groupReposition()
    local group = self -- GOAP.groupTableCheck(var)
    if group then
        local firstUnit = group:getUnit(1)
        if firstUnit then
            local samePosition = firstUnit:getPosition().p
            group:goToRandomPoint(samePosition, GOAP.repositionDistance*1.1, GOAP.repositionDistance*0.9)
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupReposition group is repositioning"))
            end		
        else
            env.error(("GOAP.groupReposition missing firstUnit"))
        end
    end
end

function Group:goToTown(tName, action)
    
    --if var then
        --dumpTable("variables.lua", var)
        local group = self -- var[1] -- GOAP.groupTableCheck(var[1])
        local town = GOAP.townTableCheck(tName)
        --local action = var[2]
        if GOAP.debugProcessDetail then
            env.info(("GOAP, goToTown, tName: " .. tostring(tName)))
            env.info(("GOAP, goToTown, action: " .. tostring(action)))
        end

        if group and town then		
            local destination = coord.LLtoLO(town.latitude, town.longitude , 0)
            if destination then
                group:goToRandomPoint(destination, GOAP.repositionDistance, 10, forceRoadUse)
                if action then -- action is a stored function inside the var table
                    action(group)
                end
                return true		
            else
                env.error(("GOAP, goToTown, missing destination"))
                return false
            end
        else
            env.error(("GOAP, goToTown, missing group or town"))
            return false
        end
    --else
    --    env.error(("GOAP.goToTown, missing variable"))
    --    return false
    --end
end

function Group:haltOnContact()
    local group = self -- var[1] -- GOAP.groupTableCheck(var[1])

    if group then
        --dumpTable("group.lua", group)
        if Group.hasTargets(group) then
            if GOAP.debugProcessDetail then
                env.info(("GOAP.haltOnContact, stopping group"))
            end
            
            group:goStop()
            return true
        else
            if GOAP.debugProcessDetail then
                env.info(("GOAP.haltOnContact, no contact, rescheduling"))
            end
            
            local function schedFunc()
                group:haltOnContact()
            end
            timer.scheduleFunction(schedFunc, {}, timer.getTime() + 30)
        end
    else
        env.error(("GOAP.haltOnContact, missing group"))
    end
end

function Group:groupfireAtPoint(var) -- 1 is group, 2 is vec3, 3 is quantity
    local group = self -- var[1] -- GOAP.groupTableCheck(var[1])
    if group then
        local gController = group:getController()
        local vec3 = GOAP.vec3Check(var[1])
        local qty = var[2]
        if gController and vec3 then
            local expd = true
            if not var[2] then
                expd = nil
                qty = nil
            end

            local _tgtVec2 =  { x = vec3.x  , y = vec3.z} 
            local _task = { 
                id = 'FireAtPoint', 
                params = { 
                point = _tgtVec2,
                radius = 200,
                expendQty = qty,
                expendQtyEnabled = expd,
                }
            } 

            gController:pushTask(_task)
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.groupfireAtPoint will allow dispersal"))
            end		
        else
            env.error(("GOAP.groupfireAtPoint, missing controller for: " .. tostring(group:getName())))
        end	
    else
        env.error(("GOAP.groupfireAtPoint, missing group"))        
    end
end

--## AI EVENT FEEDBACK

-- under attack
GOAP.attackRegister = {}
GOAP.underAttack = {} -- define under attack action and suppression -- METTI FILTRO TEMPO
function GOAP.underAttack:onEvent(event)	
    if event.id == world.event.S_EVENT_HIT then 
        local unit 			= event.target
        local shooter       = event.initiator
        if unit then

            local vehicle   = unit:hasAttribute("Vehicles")
            local infantry  = unit:hasAttribute("Infantry")
            if vehicle or infantry then
                local uName = unit:getName()
                local check = true
                if #GOAP.attackRegister > 0 then
                    for _, nData in pairs(GOAP.attackRegister) do
                        if uName == nData.n then
                            check = false
                        end
                    end
                end

                if check == true then

                    GOAP.attackRegister[#GOAP.attackRegister+1] = {n = nome, t = timer.getTime()}

                    local group     = unit:getGroup()
                    local position  = unit:getPosition().p
                    local coalition = unit:getCoalition()
                    
                    local othercoa  = "none"
                    if shooter then
                        othercoa = shooter:getCoalition()
                    end
                    
                    --local vehicle   = unit:hasAttribute("Vehicles")
                    --local infantry  = unit:hasAttribute("Infantry")

                    if coalition ~= othercoa then
                        --if vehicle or infantry then
                            if GOAP.debugProcessDetail == true then
                                env.info(("GOAP.underAttack group " .. group:getName() .. " is under attack"))
                                --trigger.action.outText("GOAP.underAttack group " .. group:getName() .. " is under attack", 10)
                            end
                            
                            local grp = unit:getGroup()
                            if grp then
                                grp:groupReposition()
                            end

                            if GOAP.debugProcessDetail == true then
                                env.info(("GOAP.underAttack now checking shooter info"))
                            end                        
                            local vCrtl = unit:getController()
                            if vCrtl then
                                local tgtTbl = vCrtl:getDetectedTargets()
                                local actionDone = false
                                if tgtTbl then
                                    if #tgtTbl > 0 then
                                        --GOAP.extractMultiTroops({unit:getName(), true})
                                        for tId, tData in pairs(tgtTbl) do
                                            if GOAP.debugProcessDetail == true then
                                                env.info(("GOAP.underAttack checking shooter id: " .. tostring(tId)))
                                            end
                                            if actionDone == false then
                                                if tData.object == shooter then
                                                    if GOAP.debugProcessDetail == true then
                                                        env.info(("GOAP.underAttack shooter identified"))
                                                    end
                                                    if tData.type == true then
                                                        if shooter:hasAttribute("Air") then
                                                            if GOAP.debugProcessDetail == true then
                                                                env.info(("GOAP.underAttack shooter is air based"))
                                                            end
                                                            GOAP.callSupport({unit, "Mobile AAA", coalition})
                                                            GOAP.callSupport({unit, "SR SAM", coalition})
                                                            actionDone = true
                                                            GOAP.unloadExtractTroops({unit:getName(), true})
                                                        else
                                                            if GOAP.debugProcessDetail == true then
                                                                env.info(("GOAP.underAttack shooter is ground based"))
                                                            end
                                                            GOAP.callSupport({unit, "Armored vehicles", coalition})
                                                            actionDone = true
                                                            GOAP.unloadExtractTroops({unit:getName(), true})
                                                        end
                                                    else
                                                        if GOAP.debugProcessDetail == true then
                                                            env.info(("GOAP.underAttack by unidentified target"))
                                                        end
                                                        GOAP.callSupport({unit, "Armored vehicles", coalition})
                                                        actionDone = true                                             
                                                    end
                                                end  
                                            end
                                        end
                                    end
                                end
                            end
                            -- ADD ACTION!
                            
                        --end
                    end
                end
            end
        else
            env.error(("GOAP.underAttack, missing unit"))
        end
    end
end
world.addEventHandler(GOAP.underAttack)

function GOAP.hitCleaner()
    if #GOAP.attackRegister > 0 then
        for id, data in pairs(GOAP.attackRegister) do
            local tempo = timer.getTime() - data.t
            if tempo > 1800 then
                id = nil
            end
        end
    end
	timer.scheduleFunction(GOAP.hitCleaner, {}, timer.getTime() + 60)
end
GOAP.hitCleaner()


-- birth
GOAP.unitBirth = {} -- define under attack action and suppression
function GOAP.unitBirth:onEvent(event)	
    if event.id == world.event.S_EVENT_BIRTH then
        local unit = event.initiator
        if unit then
            local group = unit:getGroup()
            if group then
                local id = group:getID()
                local check = false
                for iId, iData in pairs(GOAP.dbORBAT) do
                    if iId == iData.id then
                        check = true
                    end
                end

                if check == true then
                    return false
                else
                    local g_pos = group:getLeadPos()

                    GOAP.dbORBAT[#GOAP.dbORBAT+1] = {id = group:getID() , Group = group, coa = group:getCoalition(), pos = g_pos}
                    return true
                end

            else
                env.error(("GOAP.unitBirth, missing group"))
            end
        else
            env.error(("GOAP.unitBirth, missing unit"))
        end
    end
end
world.addEventHandler(GOAP.unitBirth) 


--## AI MOVEMENT TASKS
function GOAP.callSupport(var) -- var[1] can be: vec3, group/unit/static table or name, trigger zone table or name. var[2] is support category requested or, if nil, GOAP.supportUnitCategories. var[3] is coalition, or any
    
    local destPoint = nil
    if type(var[1]) == "table" then        
        -- check vector. if no vector, then is an object (supposed)
        if var[1].x and var[1].y and var[1].z then -- is coordinates
            destPoint = var[1]
        elseif var[1].point then -- is a trigger zone
            destPoint = var[1].point
        else -- SHOULD BE AN OBJECT, HOPEFULLY
            destPoint = var[1]:getPosition().p
        end
    elseif type(var[1]) == "string" then
        local group = Group.getByName(var[1])
        if group then
            local firstUnit = group:getUnit(1)
            destPoint = firstUnit:getPosition().p
        end
        local unit = Unit.getByName(var[1])
        if unit then
            destPoint = unit:getPosition().p
        end
        local static = 	StaticObject.getByName(var[1])
        if static then
            destPoint = static:getPosition().p
        end
        local zone = 	trigger.misc.getZone(var[1])
        if zone then
            destPoint = zone.point
        end
    end

    if destPoint then
        if GOAP.debugProcessDetail == true then
            env.info(("GOAP.callSupport point is identified"))
        end
        local supCat = var[2] or GOAP.supportUnitCategories
        local near_group = GOAP.findGroupInRange(destPoint, supCat, GOAP.supportDist, var[3])

        if near_group then
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.callSupport group found"))
            end
            near_group:goToRandomPoint(destPoint, 200, 50, false)
        else
            if GOAP.debugProcessDetail == true then
                env.info(("GOAP.callSupport no available support in range"))
            end
        end
    else
        env.error(("GOAP.callSupport failed to retrieve destPoint"))
    end
end


-- ## TROOPS TRANSPORT AND HANDLING

-- if its dropped by AI then there is no player name so return the type of unit
function GOAP.getPlayerNameOrType(_vehi)

    if _vehi:getPlayerName() == nil then

        return _vehi:getTypeName()
    else
        return _vehi:getPlayerName()
    end
end

function GOAP.getUnitActions(_unitType)

    if GOAP.unitActions[_unitType] then
        return GOAP.unitActions[_unitType]
    end

    return {crates=true,troops=true}

end

function GOAP.unitCanCarryVehicles(_unit)

    local _type = string.lower(_unit:getTypeName())

    for _, _name in ipairs(GOAP.vehicleTransportEnabled) do
        local _nameLower = string.lower(_name)
        if string.match(_type, _nameLower) then
            return true
        end
    end

    return false
end

function GOAP.getGroupId(_unit)
	if _unit then
		
		local _group = _unit:getGroup()
		local _groupId = _group:getID()
		return _groupId
	
	end
	
	return nil
    
end

function GOAP.displayMessageToGroup(_unit, _text, _time,_clear)

    local _groupId = GOAP.getGroupId(_unit)
    if _groupId then
        if _clear == true then
            trigger.action.outTextForGroup(_groupId, _text, _time,_clear)
        else
            trigger.action.outTextForGroup(_groupId, _text, _time)
        end
    end
end

function GOAP.insertIntoTroopsArray(_troopType,_count,_troopArray)

    for _i = 1, _count do
        local _unitId = GOAP.getNextUnitId()
        table.insert(_troopArray, { type = _troopType, unitId = _unitId, name = string.format("Dropped %s #%i", _troopType, _unitId) })
    end

    return _troopArray

end

function GOAP.generateTroopTypes(_side, _countOrTemplate, _country)

    local _troops = {}

    if type(_countOrTemplate) == "table" then

        if _countOrTemplate.aa then
            if _side == 2 then
                _troops = GOAP.insertIntoTroopsArray("Stinger manpad",_countOrTemplate.aa,_troops)
            else
                _troops = GOAP.insertIntoTroopsArray("SA-18 Igla manpad",_countOrTemplate.aa,_troops)
            end
        end

        if _countOrTemplate.inf then
            if _side == 2 then
                _troops = GOAP.insertIntoTroopsArray("Soldier M4",_countOrTemplate.inf,_troops)
            else
                _troops = GOAP.insertIntoTroopsArray("Soldier AK",_countOrTemplate.inf,_troops)
            end
        end

        if _countOrTemplate.mg then
            _troops = GOAP.insertIntoTroopsArray("Soldier M249",_countOrTemplate.mg,_troops)
        end

        if _countOrTemplate.at then
            _troops = GOAP.insertIntoTroopsArray("Paratrooper RPG-16",_countOrTemplate.at,_troops)
        end

        if _countOrTemplate.mortar then
            _troops = GOAP.insertIntoTroopsArray("2B11 mortar",_countOrTemplate.mortar,_troops)
        end
    end

    local _groupId = GOAP.getNextGroupId()
    local _details = { units = _troops, groupId = _groupId, groupName = string.format("Dropped Group %i", _groupId), side = _side, country = _country }

    return _details
end

function GOAP.AddTroopsToVehicles(_unit, _numberOrTemplate)

    local _onboard = GOAP.inTransitTroops[_unit:getName()]

    --number doesnt apply to vehicles
    if _numberOrTemplate == nil  or (type(_numberOrTemplate) ~= "table" and type(_numberOrTemplate) ~= "number")  then
        _numberOrTemplate = GOAP.numberOfTroops
    end

    if _onboard == nil then
        _onboard = { troops = {}, vehicles = {} }
    end

	_onboard.troops = GOAP.generateTroopTypes(_unit:getCoalition(), _numberOrTemplate, _unit:getCountry())
	
	--trigger.action.outTextForCoalition(_unit:getCoalition(), GOAP.getPlayerNameOrType(_unit) .. " loaded troops into " .. _unit:getTypeName(), 10)
	--GOAP.processCallback({unit = _unit, onboard = _onboard.troops, action = "load_troops"})		
    GOAP.inTransitTroops[_unit:getName()] = _onboard
end

function GOAP.updateTroops()
    if GOAP.debugProcessDetail then
        env.info(ModuleName .. " updateTroops looking for ME IFV, APC or Truck for add transport table and infantry groups")
    end
	
	for _coalitionName, _coalitionData in pairs(env.mission.coalition) do		
		if (_coalitionName == 'red' or _coalitionName == 'blue')
				and type(_coalitionData) == 'table' then
			if _coalitionData.country then --there is a country table
				for _, _countryData in pairs(_coalitionData.country) do
					if type(_countryData) == 'table' then
						for _objectTypeName, _objectTypeData in pairs(_countryData) do
							if _objectTypeName == "vehicle" then

								if ((type(_objectTypeData) == 'table')
										and _objectTypeData.group
										and (type(_objectTypeData.group) == 'table')
										and (#_objectTypeData.group > 0)) then

									for _groupId, _group in pairs(_objectTypeData.group) do
										if _group and _group.units and type(_group.units) == 'table' then									
											local groupName = _group.name -- env.getValueDictByKey(_group.name)
											local Table_group = Group.getByName(groupName)
                                            if Table_group then
												local Table_group_ID = Table_group:getID()
																			
												for _unitNum, _unit in pairs(_group.units) do
													--if _unitNum == 1 then
														local unitName = _unit.name -- env.getValueDictByKey(_unit.name)
														if unitName then
															local unit = Unit.getByName(unitName)
															if unit then
																if unit:getLife() > 0 then
																	local unitID = unit:getID()
																	if unit:hasAttribute("APC") or unit:hasAttribute("IFV") or unit:hasAttribute("Trucks") then -- preload a ground group in everyone
                                                                        table.insert(GOAP.transportVehicleNames, unitName)
                                                                        
                                                                        local unit_typeName = unit:getTypeName()
                                                                        local keyword = "none"
                                                                        if unit_typeName then
                                                                            if unit:hasAttribute("Trucks") then
                                                                                GOAP.unitLoadLimits[unit_typeName] = 24
                                                                                GOAP.unitActions[unit_typeName] = {crates=true, troops=true}
                                                                                keyword = "platoon"
                                                                            elseif unit:hasAttribute("APC") then
                                                                                GOAP.unitLoadLimits[unit_typeName] = 8
                                                                                GOAP.unitActions[unit_typeName] = {crates=false, troops=true}
                                                                                keyword = "squad"
                                                                            elseif unit:hasAttribute("IFV") then
                                                                                GOAP.unitLoadLimits[unit_typeName] = 4    
                                                                                GOAP.unitActions[unit_typeName] = {crates=false, troops=true}
                                                                                keyword = "fireteam"
                                                                            end
                                                                        end     

                                                                        local tableTemplate = nil
                                                                        local code = nil
                                                                        if _unitNum == 1 then
                                                                            code = "Rifle" 
                                                                        elseif _unitNum == 2 then 
                                                                            code = "Anti tank" 
                                                                        elseif _unitNum == 3 then 
                                                                            code = "Anti air" 
                                                                        else
                                                                            code = "Rifle" 
                                                                        end
                                                                        
                                                                        for _id, TableBase in pairs(GOAP.loadableGroups) do
                                                                            if string.find(TableBase.name, code) and string.find(TableBase.name, keyword) then
                                                                                tableTemplate = TableBase
                                                                                if debugProcessDetail then
                                                                                    trigger.action.outText(ModuleName .. " updateTroops, added " .. tostring(TableBase.name), 10)
                                                                                end
                                                                            end
                                                                        end
                                                            
                                                                        if tableTemplate then
                                                                            GOAP.AddTroopsToVehicles(unit, tableTemplate)
                                                                        end																		
																	end
																end
															end
														end
													--end
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
    if GOAP.debugProcessDetail then
        env.info(ModuleName .. " updateTroops done")
    end
end

function GOAP.getTransportUnit(_unitName)
    if _unitName == nil then
        return nil
    end

    local _vehi = Unit.getByName(_unitName)

    if _vehi ~= nil and _vehi:isActive() and _vehi:getLife() > 0 then
        return _vehi
    end

    return nil
end

function GOAP.getDistance(_point1, _point2)

    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

function GOAP.findNearestGroup(_vehi, _groups)

    local _closestGroupDetails = {}
    local _closestGroup = nil

    local _closestGroupDist = GOAP.maxExtractDistance

    local _vehiPoint = _vehi:getPoint()

    for _, _groupName in pairs(_groups) do

        local _group = Group.getByName(_groupName)

        if _group ~= nil then
            local _units = _group:getUnits()

            if _units ~= nil and #_units > 0 then

                local _leader = nil

                local _groupDetails = { groupId = _group:getID(), groupName = _group:getName(), side = _group:getCoalition(), units = {} }

                -- find alive leader
                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then

                        if _leader == nil then
                            _leader = _units[x]
                            -- set country based on leader
                            _groupDetails.country = _leader:getCountry()
                        end

                        local _unitDetails = { type = _units[x]:getTypeName(), unitId = _units[x]:getID(), name = _units[x]:getName() }

                        table.insert(_groupDetails.units, _unitDetails)
                    end
                end

                if _leader ~= nil then
                    local _leaderPos = _leader:getPoint()
                    local _dist = GOAP.getDistance(_vehiPoint, _leaderPos)
                    if _dist < _closestGroupDist then
                        _closestGroupDist = _dist
                        _closestGroupDetails = _groupDetails
                        _closestGroup = _group
                    end
                end
            end
        end
    end


    if _closestGroup ~= nil then

        return { group = _closestGroup, details = _closestGroupDetails }
    else

        return nil
    end
end

function GOAP.checkInternalWeight(_group) --_vehi  --I think in most cases I will aleady have the heli name so just passing that

	if (GOAP.troopsOnboard(_group, true) == false) and  (GOAP.troopsOnboard(_group, false) == false) then   
		_TroopWeight = 0

	else
		local _onboard = GOAP.inTransitTroops[_group:getName()]

        local number = #_onboard.troops.units
        if number then
            _TroopWeight = GOAP.soldierWeight * number
        else
            if GOAP.debugProcessDetail then
                env.error("checkInternalWeight ran but failed to get valid data")
            end
           
            _TroopWeight = 0
        end

	end

	if _TroopWeight  then 
		_cargoweight = _TroopWeight
    else
        if GOAP.debugProcessDetail then
            env.error("Something went wrong calculating current cargo weight")
        end
		
		_cargoweight = 0
	end		
	
    return _cargoweight

end

function GOAP.checkTroopStatus(_args)

    --list onboard troops, if c130
    local _vehi = GOAP.getTransportUnit(_args[1])

    if _vehi == nil then
        return
    end

    local _onboard = GOAP.inTransitTroops[_vehi:getName()]

    if _onboard == nil then
        GOAP.displayMessageToGroup(_vehi, "No troops onboard", 10)
    else
        local _troops = _onboard.troops
        local _vehicles = _onboard.vehicles

        local _txt = ""

        if _troops ~= nil and _troops.units ~= nil and #_troops.units > 0 then
            _txt = _txt .. " " .. #_troops.units .. " troops onboard\n"
        end

        if _vehicles ~= nil and _vehicles.units ~= nil and #_vehicles.units > 0 then
            _txt = _txt .. " " .. #_vehicles.units .. " vehicles onboard\n"
        end

        if _txt ~= "" then
            GOAP.displayMessageToGroup(_vehi, _txt, 10)
        else
            GOAP.displayMessageToGroup(_vehi, "No troops onboard", 10)
        end
    end
end

function GOAP.troopsOnboard(_vehi, _troops)

    if GOAP.inTransitTroops[_vehi:getName()] ~= nil then

        local _onboard = GOAP.inTransitTroops[_vehi:getName()]

        if _troops then

            if _onboard.troops ~= nil and _onboard.troops.units ~= nil and #_onboard.troops.units > 0 then
                return true
            else
                return false
            end
        else

            if _onboard.vehicles ~= nil and _onboard.vehicles.units ~= nil and #_onboard.vehicles.units > 0 then
                return true
            else
                return false
            end
        end

    else
        return false
    end
end

function GOAP.getTransportLimit(_unitType)

    if GOAP.unitLoadLimits[_unitType] then

        return GOAP.unitLoadLimits[_unitType]
    end

    return GOAP.numberOfTroops

end

function GOAP.unloadExtractTroops(_args)

    local _vehi = GOAP.getTransportUnit(_args[1])
    local _auto = _args[2]

    if _vehi == nil then
        return false
    end

    local _extract = nil
    if _vehi:inAir() == false then
        if _vehi:getCoalition() == 1 then
            _extract = GOAP.findNearestGroup(_vehi, GOAP.droppedTroopsRED)
        elseif _vehi:getCoalition() == 2 then
            _extract = GOAP.findNearestGroup(_vehi, GOAP.droppedTroopsBLUE)
        elseif _vehi:getCoalition() == 0 then
            _extract = GOAP.findNearestGroup(_vehi, GOAP.droppedTroopsNEUTRAL)
        end

    end

    if _extract ~= nil and not GOAP.troopsOnboard(_vehi, true) then
        -- search for nearest troops to pickup
        return GOAP.extractMultiTroops({_vehi:getName(), true})  -- TEST DSMC
    else
        return GOAP.unloadMultiTroops({_vehi:getName(),true,true})
    end

    if _auto then
        timer.scheduleFunction( GOAP.unloadExtractTroops, {_args[1]}, timer.getTime() + 300)
    end


end

function GOAP.extractMultiTroops(_args) -- TEST DSMC
    --dumpTable("GOAP.droppedTroopsBLUE.lua", GOAP.droppedTroopsBLUE)
    local _unit = GOAP.getTransportUnit(_args[1]) 
    if _unit then

        local _group = _unit:getGroup()
        if _group then
            local _units = _group:getUnits()
            if _units then
                local sched = 0.05
                for _, uData in pairs(_units) do
                    local uName = uData:getName()

                    local u_vehi = GOAP.getTransportUnit(uName)

                    if u_vehi then
                        local u_extract = nil

                        if u_vehi:getCoalition() == 1 then
                            u_extract = GOAP.findNearestGroup(u_vehi, GOAP.droppedTroopsRED)
                        elseif u_vehi:getCoalition() == 2 then
                            u_extract = GOAP.findNearestGroup(u_vehi, GOAP.droppedTroopsBLUE)
                        elseif u_vehi:getCoalition() == 0 then
                            u_extract = GOAP.findNearestGroup(u_vehi, GOAP.droppedTroopsNEUTRAL)
                        end

                        if u_extract ~= nil and not GOAP.troopsOnboard(u_vehi, true) then
                            -- search for nearest troops to pickup

                            timer.scheduleFunction(GOAP.extractTroops, {uName, true}, timer.getTime() + sched)
                            sched = sched + 0.05

                        end

                    end

                end

            end

        end
    end
end

function GOAP.extractTroops(_args)

    local _vehi = GOAP.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _vehi == nil then
        return false
    end

    if  GOAP.troopsOnboard(_vehi, _troops)  then
        if _troops then
            GOAP.displayMessageToGroup(_vehi, "You already have troops onboard.", 10)
        else
            GOAP.displayMessageToGroup(_vehi, "You already have vehicles onboard.", 10)
        end

        return false
    end

    local _onboard = GOAP.inTransitTroops[_vehi:getName()]

    if _onboard == nil then
        _onboard = { troops = nil, vehicles = nil }
    end

    local _extracted = false

    if _troops then

        local _extractTroops

        if _vehi:getCoalition() == 1 then
            _extractTroops = GOAP.findNearestGroup(_vehi, GOAP.droppedTroopsRED)
        elseif _vehi:getCoalition() == 2 then
            _extractTroops = GOAP.findNearestGroup(_vehi, GOAP.droppedTroopsBLUE)
        elseif _vehi:getCoalition() == 0 then
            _extractTroops = GOAP.findNearestGroup(_vehi, GOAP.droppedTroopsNEUTRAL)
        end


        if _extractTroops ~= nil then

            local _limit = GOAP.getTransportLimit(_vehi:getTypeName())

            local _size =  #_extractTroops.group:getUnits()

            if _limit < #_extractTroops.group:getUnits() then

                GOAP.displayMessageToGroup(_vehi, "Sorry - The group of ".._size.." is too large to fit. \n\nLimit is ".._limit.." for ".._vehi:getTypeName(), 20)

                return
            end


            _onboard.troops = _extractTroops.details

            trigger.action.outTextForCoalition(_vehi:getCoalition(), GOAP.getPlayerNameOrType(_vehi) .. " extracted troops in " .. _vehi:getTypeName() .. " from combat", 10)


            local nameDropped = tostring(_extractTroops.group:getName())
            if _vehi:getCoalition() == 1 then
                GOAP.droppedTroopsRED[nameDropped] = nil

            elseif _vehi:getCoalition() == 2 then
                GOAP.droppedTroopsRED[nameDropped] = nil

            elseif _vehi:getCoalition() == 0 then
                GOAP.droppedTroopsRED[nameDropped] = nil

            end

            _extractTroops.group:destroy()

            _extracted = true
        else
            _onboard.troops = nil
            GOAP.displayMessageToGroup(_vehi, "No extractable troops nearby!", 20)
        end

    else

        local _extractVehicles


        if _vehi:getCoalition() == 1 then

            _extractVehicles = GOAP.findNearestGroup(_vehi, GOAP.droppedVehiclesRED)
        elseif _vehi:getCoalition() == 1 then

            _extractVehicles = GOAP.findNearestGroup(_vehi, GOAP.droppedVehiclesBLUE)
        else
        
            _extractVehicles = GOAP.findNearestGroup(_vehi, GOAP.droppedVehiclesNEUTRAL)
        
        end

        if _extractVehicles ~= nil then
            _onboard.vehicles = _extractVehicles.details

            if _vehi:getCoalition() == 1 then

                GOAP.droppedVehiclesRED[_extractVehicles.group:getName()] = nil
            elseif _vehi:getCoalition() == 2 then

                GOAP.droppedVehiclesBLUE[_extractVehicles.group:getName()] = nil
            else
            
                GOAP.droppedVehiclesNEUTRAL[_extractVehicles.group:getName()] = nil
            end

            trigger.action.outTextForCoalition(_vehi:getCoalition(), GOAP.getPlayerNameOrType(_vehi) .. " extracted vehicles in " .. _vehi:getTypeName() .. " from combat", 10)

            _extractVehicles.group:destroy()
            _extracted = true

        else
            _onboard.vehicles = nil
            GOAP.displayMessageToGroup(_vehi, "No extractable vehicles nearby!", 20)
        end
    end

    GOAP.inTransitTroops[_vehi:getName()] = _onboard
	
	local _weightkg = GOAP.checkInternalWeight(_vehi)
	local _weightlbs = math.floor(_weightkg * 2.20462)
	trigger.action.setUnitInternalCargo(_vehi:getName(), _weightkg )
	--GOAP.displayMessageToGroup(_vehi, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)

    return _extracted
end

function GOAP.unloadMultiTroops(_args) -- TEST DSMC
    local _unit = GOAP.getTransportUnit(_args[1])                
    if _unit then
        local _group = _unit:getGroup()
        if _group then
            local _units = _group:getUnits()
            if _units then
                local sched = 0.05
                for _, uData in pairs(_units) do
                    local uName = uData:getName()

                    local u_vehi = GOAP.getTransportUnit(uName)

                    if u_vehi then
                        if GOAP.troopsOnboard(u_vehi, true) then
                            timer.scheduleFunction(GOAP.unloadTroops, {uName,true,true}, timer.getTime() + sched)
                            sched = sched + 0.05

                        end
                    end


                end
            else
            
            end
        else

        end
    end
end


function GOAP.createUnit(_x, _y, _angle, _details)

    local _newUnit = {
        ["y"] = _y,
        ["type"] = _details.type,
        ["name"] = _details.name,
      --  ["unitId"] = _details.unitId,
        ["heading"] = _angle,
        ["playerCanDrive"] = true,
        ["skill"] = "Random",
        ["x"] = _x,
    }

    return _newUnit
end

function GOAP.findNearestEnemy(_side, _point, _searchDistance)

    local _closestEnemy = nil

    local _groups

    local _closestEnemyDist = _searchDistance

    local _vehiPoint = _point

    if _side == 2 then
        _groups = coalition.getGroups(1, Group.Category.GROUND)
    else
        _groups = coalition.getGroups(2, Group.Category.GROUND)
    end

    for _, _group in pairs(_groups) do

        if _group ~= nil then
            local _units = _group:getUnits()

            if _units ~= nil and #_units > 0 then

                local _leader = nil

                -- find alive leader
                for x = 1, #_units do
                    if _units[x]:getLife() > 0 then
                        _leader = _units[x]
                        break
                    end
                end

                if _leader ~= nil then
                    local _leaderPos = _leader:getPoint()
                    local _dist = GOAP.getDistance(_vehiPoint, _leaderPos)
                    if _dist < _closestEnemyDist then
                        _closestEnemyDist = _dist
                        _closestEnemy = _leaderPos
                    end
                end
            end
        end
    end


    -- no enemy - move to random point
    if _closestEnemy ~= nil then

        return _closestEnemy
    else

        local _x = _vehiPoint.x + math.random(0, GOAP.maximumMoveDistance) - math.random(0, GOAP.maximumMoveDistance)
        local _z = _vehiPoint.z + math.random(0, GOAP.maximumMoveDistance) - math.random(0, GOAP.maximumMoveDistance)
        local _y = _vehiPoint.y + math.random(0, GOAP.maximumMoveDistance) - math.random(0, GOAP.maximumMoveDistance)

        return { x = _x, z = _z,y=_y }
    end
end

function GOAP.getAliveGroup(_groupName)

    local _group = Group.getByName(_groupName)

    if _group and _group:isExist() == true and #_group:getUnits() > 0 then
        return _group
    end

    return nil
end

function GOAP.orderGroupToMoveToPoint(_leader, _destination)

    local _group = _leader:getGroup()

    local _path = {}
    table.insert(_path, GOAP.ground_buildWP(_leader:getPoint(), 'Off Road', 50))
    table.insert(_path, GOAP.ground_buildWP(_destination, 'Off Road', 50))

    local _mission = {
        id = 'Mission',
        params = {
            route = {
                points =_path
            },
        },
    }


    -- delayed 2 second to work around bug
    timer.scheduleFunction(function(_arg)
        local _grp = GOAP.getAliveGroup(_arg[1])

        if _grp ~= nil then
            local _controller = _grp:getController();
            Controller.setOption(_controller, AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.AUTO)
            Controller.setOption(_controller, AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
            _controller:setTask(_arg[2])
        end
    end
        , {_group:getName(), _mission}, timer.getTime() + 2)

end

function GOAP.spawnDroppedGroup(_point, _details, _spawnBehind, _maxSearch)

    local _groupName = _details.groupName

    local _group = {
        ["visible"] = false,
      --  ["groupId"] = _details.groupId,
        ["hidden"] = false,
        ["units"] = {},
        --        ["y"] = _positions[1].z,
        --        ["x"] = _positions[1].x,
        ["name"] = _groupName,
        ["task"] = {},
    }


    if _spawnBehind == false then

        -- spawn in circle around heli

        local _pos = _point

        for _i, _detail in ipairs(_details.units) do

            local _angle = math.pi * 2 * (_i - 1) / #_details.units
            local _xOffset = math.cos(_angle) * 30
            local _yOffset = math.sin(_angle) * 30

            _group.units[_i] = GOAP.createUnit(_pos.x + _xOffset, _pos.z + _yOffset, _angle, _detail)
        end

    else

        local _pos = _point

        --try to spawn at 6 oclock to us
        local _angle = math.atan2(_pos.z, _pos.x)
        local _xOffset = math.cos(_angle) * -30
        local _yOffset = math.sin(_angle) * -30


        for _i, _detail in ipairs(_details.units) do
            _group.units[_i] = GOAP.createUnit(_pos.x + (_xOffset + 10 * _i), _pos.z + (_yOffset + 10 * _i), _angle, _detail)
        end
    end

    _group.category = Group.Category.GROUND;
    _group.country = _details.country;

    local _spawnedGroup = Group.getByName(GOAP.dynAdd(_group).name)

    --local _spawnedGroup = coalition.addGroup(_details.country, Group.Category.GROUND, _group)


    -- find nearest enemy and head there
    if _maxSearch == nil then
        _maxSearch = GOAP.maximumSearchDistance
    end

    local _enemyPos = GOAP.findNearestEnemy(_details.side, _point, _maxSearch)
    if _enemyPos then
        GOAP.orderGroupToMoveToPoint(_spawnedGroup:getUnit(1), _enemyPos)
    end
    return _spawnedGroup
end

function GOAP.unloadTroops(_args)

    local _vehi = GOAP.getTransportUnit(_args[1])
    local _troops = _args[2]

    if _vehi == nil then
        return false
    end

    --local _zone = GOAP.inPickupZone(_vehi)
    if not GOAP.troopsOnboard(_vehi, _troops)  then


        return false
    else

        --[[ troops must be onboard to get here
        if _zone.inZone == true  then

            if _troops then
                --GOAP.displayMessageToGroup(_vehi, "Dropped troops back to base", 20)

                --GOAP.processCallback({unit = _vehi, unloaded = GOAP.inTransitTroops[_vehi:getName()].troops, action = "unload_troops_zone"})

                GOAP.inTransitTroops[_vehi:getName()].troops = nil
				
				local _weightkg = GOAP.checkInternalWeight(_vehi)
				local _weightlbs = math.floor(_weightkg * 2.20462)
				trigger.action.setUnitInternalCargo(_vehi:getName(), _weightkg )
				--GOAP.displayMessageToGroup(_vehi, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)

            else
                --GOAP.displayMessageToGroup(_vehi, "Dropped vehicles back to base", 20)

                --GOAP.processCallback({unit = _vehi, unloaded = GOAP.inTransitTroops[_vehi:getName()].vehicles, action = "unload_vehicles_zone"})

                GOAP.inTransitTroops[_vehi:getName()].vehicles = nil
				
				local _weightkg = GOAP.checkInternalWeight(_vehi)
				local _weightlbs = math.floor(_weightkg * 2.20462)
				trigger.action.setUnitInternalCargo(_vehi:getName(), _weightkg )
				--GOAP.displayMessageToGroup(_vehi, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
				
            end

            -- increase zone counter by 1
            --GOAP.updateZoneCounter(_zone.index, 1)

            return true
            --]]--

        if GOAP.troopsOnboard(_vehi, _troops)  then -- else

            return GOAP.deployTroops(_vehi, _troops)
        end
    end
end

function GOAP.deployTroops(_vehi, _troops)

    local _onboard = GOAP.inTransitTroops[_vehi:getName()]

    -- deploy troops
    if _troops then
        if _onboard.troops ~= nil and #_onboard.troops.units > 0 then

            local _droppedTroops = GOAP.spawnDroppedGroup(_vehi:getPoint(), _onboard.troops, false)

            if _vehi:getCoalition() == 1 then

                table.insert(GOAP.droppedTroopsRED, _droppedTroops:getName())
            elseif _vehi:getCoalition() == 2 then

                table.insert(GOAP.droppedTroopsBLUE, _droppedTroops:getName())

            else
                
                table.insert(GOAP.droppedTroopsNEUTRAL, _droppedTroops:getName())
            end

            GOAP.inTransitTroops[_vehi:getName()].troops = nil
            
            local _weightkg = GOAP.checkInternalWeight(_vehi)
            local _weightlbs = math.floor(_weightkg * 2.20462)
            trigger.action.setUnitInternalCargo(_vehi:getName(), _weightkg )
            --GOAP.displayMessageToGroup(_vehi, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)

            --GOAP.processCallback({unit = _vehi, unloaded = _droppedTroops, action = "dropped_troops"})

        end

    else

        if _onboard.vehicles ~= nil and #_onboard.vehicles.units > 0 then

            local _droppedVehicles = GOAP.spawnDroppedGroup(_vehi:getPoint(), _onboard.vehicles, true)

            if _vehi:getCoalition() == 1 then

                table.insert(GOAP.droppedVehiclesRED, _droppedVehicles:getName())
            elseif _vehi:getCoalition() == 2 then
            
                table.insert(GOAP.droppedVehiclesBLUE, _droppedVehicles:getName())
            
            else



                table.insert(GOAP.droppedVehiclesNEUTRAL, _droppedVehicles:getName())
            end

            GOAP.inTransitTroops[_vehi:getName()].vehicles = nil

            --GOAP.processCallback({unit = _vehi, unloaded = _droppedVehicles, action = "dropped_vehicles"})
            
            local _weightkg = GOAP.checkInternalWeight(_vehi)
            local _weightlbs = math.floor(_weightkg * 2.20462)
            trigger.action.setUnitInternalCargo(_vehi:getName(), _weightkg )
            --GOAP.displayMessageToGroup(_vehi, "Your internal cargo weight is now ".. _weightkg .. "kg/" .. _weightlbs .. "lbs", 20, false)
                
            --trigger.action.outTextForCoalition(_vehi:getCoalition(), GOAP.getPlayerNameOrType(_vehi) .. " dropped vehicles from " .. _vehi:getTypeName() .. " into combat", 10)
        end

    end

end

function GOAP.addF10MenuOptions()

    timer.scheduleFunction(GOAP.addF10MenuOptions, nil, timer.getTime() + GOAP.f10menuUpdateFreq)

    for _, _unitName in pairs(GOAP.transportVehicleNames) do

        local status, error = pcall(function()

            local _unit = GOAP.getTransportUnit(_unitName)

            if _unit ~= nil then

                local _groupId = GOAP.getGroupId(_unit)
                local _unitId = _unit:getID()
                --code to check if it's an vehicle or a plane/helo
                local _addedId = nil
                --local _CTLDpathID = GOAP.getPlayerNameOrUnitName(_unit)
                local _menuCode = nil
                --local _vehicopter = true
                if _unit:hasAttribute("APC") or _unit:hasAttribute("IFV") or _unit:hasAttribute("Trucks") then
                    _addedId = tostring(_groupId)
                    _vehicopter = false
                    local g = _unit:getGroup():getName()
                    _menuCode = "Troops for " .. tostring(g)

                end

                -- code to add menù
                if _groupId and _addedId and _menuCode then


                    if GOAP.addedTo[_addedId] == nil then  -- GOAP.addedTo[_addedId] == nil


                        local _rootPath = missionCommands.addSubMenuForGroup(_groupId, _menuCode, {"DSMC"})
                        local _unitActions = GOAP.getUnitActions(_unit:getTypeName())


                        if _unitActions.troops then
                            missionCommands.addCommandForGroup(_groupId, "Deploy / Load Troops", _rootPath, GOAP.unloadExtractTroops, { _unitName })
                            missionCommands.addCommandForGroup(_groupId, "Check Cargo", _rootPath, GOAP.checkTroopStatus, { _unitName })
                            if GOAP.unitCanCarryVehicles(_unit) then
                                local _vehicleCommandsPath = missionCommands.addSubMenuForGroup(_groupId, "Vehicle Transport", _rootPath)
                                missionCommands.addCommandForGroup(_groupId, "Unload Vehicles", _vehicleCommandsPath, GOAP.unloadTroops, { _unitName, false })
                                missionCommands.addCommandForGroup(_groupId, "Load / Extract Vehicles", _vehicleCommandsPath, GOAP.loadTroopsFromZone, { _unitName, false,"",true })
                                missionCommands.addCommandForGroup(_groupId, "Check Cargo", _vehicleCommandsPath, GOAP.checkTroopStatus, { _unitName })
                            end
                        end
                        GOAP.addedTo[_addedId] = {path = _rootPath, groupId = _groupId, unitId = _unitId, curTime = timer.getTime()}
                    end
                end

            end
        end)

        if (not status) then
            env.error(string.format("Error adding f10 to transport: %s", error), false)
        end
    end
end




--## AI INITIAL SET FUCTION
function GOAP.setAllNotDisperse()
    for coalitionID,coalition in pairs(env.mission["coalition"]) do
        for countryID,country in pairs(coalition["country"]) do
            for attrID,attr in pairs(country) do
                if attrID == "vehicle" then
                    if (type(attr)=="table") then
                        for groupID,group in pairs(attr["group"]) do
                            if (group) then
                                local groupName = group.name-- env.getValueDictByKey(group.name)
                                local groupTbl = Group.getByName(groupName)
                                if groupTbl then
                                    groupTbl:groupPreventDisperse()
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

--## CLIENT GOUND TASK COMMAND (NO CA USER)
local _rootPath = nil
GOAP.groupGoToMark = {} -- command a movement using text format "DSMC move here (groupname)""
function GOAP.groupGoToMark:onEvent(event)	
    if event.id == world.event.S_EVENT_MARK_CHANGE then

        local messageText 	    = event.text
        local destinationPos    = event.pos
        local coalition         = event.coalition
        local markId            = event.idx
        if string.find(messageText, "DSMC") and markId then

            if string.find(messageText, "move here") then
                local notThis, start = string.find(messageText, "move here")
                local this = start + 2
                if notThis and this then
                    local groupName = string.sub(messageText, this)
                    if GOAP.debugProcessDetail then
                        env.info(("GOAP.groupGoToMark, groupName: " .. tostring(groupName)))
                    end

                    if groupName and destinationPos then
                        local group     = Group.getByName(groupName)
                        if coalition then
                            if group then
                                
                                local g_coa = group:getCoalition()

                                if g_coa == coalition then
                                    -- acknowledge moving
                                    trigger.action.outTextForCoalition(coalition, "DSMC - group " .. tostring(groupName) .. " is moving.", 10)
                                    group:goToRandomPoint(destinationPos, GOAP.repositionDistance, 10, forceRoadUse)
                                    if GOAP.debugProcessDetail then
                                        env.info(("GOAP.groupGoToMark, group is moving"))
                                    end
                                    
                                    -- set command menù
                                    local check = true
                                    for n, nData in pairs(GOAP.C2commIndex) do
                                        if n == groupName then
                                            check = false
                                        end
                                    end

                                    if check then
                                        if not _rootPath then
                                            _rootPath = missionCommands.addSubMenuForCoalition(coalition, "C2", {"DSMC"})
                                        end
                                        local _groupPath = missionCommands.addSubMenuForCoalition(coalition, "comm with ".. groupName, _rootPath)
                                        local function gStop()
                                            trigger.action.groupStopMoving(group)
                                        end
                                        local function gResume()
                                            trigger.action.groupContinueMoving(group)
                                        end
                                        missionCommands.addCommandForCoalition(coalition, "Stop moving", _groupPath, gStop)
                                        missionCommands.addCommandForCoalition(coalition, "Resume movement", _groupPath, gResume)
                                        GOAP.C2commIndex[groupName] = true
                                    end

                                else
                                    trigger.action.outTextForCoalition(coalition, "DSMC - you're trying to move a group in a different coalition.", 10)
                                    trigger.action.removeMark(markId)
                                end
                                
                            else
                                trigger.action.outTextForCoalition(coalition, "DSMC - move command error, no group available with name " .. tostring(groupName) .. ". Retry", 10)
                                trigger.action.removeMark(markId)
                            end
                        else
                            env.error(("GOAP.groupGoToMark, missing coalition"))                    
                        end
                    else
                        env.error(("GOAP.groupGoToMark, missing groupName or markId"))
                    end
                else
                    env.error(("GOAP.groupGoToMark, missing move here text parameter"))
                end
            end
        end
    end
end
world.addEventHandler(GOAP.groupGoToMark)	

--## GOAP EXPORT
GOAP.exportTable = function(sanivar)
	DSMC_allowStop = false
	if sanivar == "desanitized" then    
		--not used now
		local msg_duration = 0.05
		local prt_stack = 0.1
		local cur_Stack = 0.5 -- start point

        --local t = {} 
        --for iI, iD in pairs(GOAP.TerrainDb.towns) do 
        --    t[iI] = {col = iD.colour, p = iD.pos, own = iD.owner, name = iD.display_name}
        --end
        
        -- terrain
        local function exportTerrainDb()
            if GOAP.TerrainDb then
                GOAP.saveTable("tblTerrainDb", GOAP.TerrainDb)
            end
		end       

        local function exportIntelDb()
            if GOAP.intel then
                GOAP.saveTable("tblIntelDb", GOAP.intel)
            end
		end 

        local function exportORBATDb()
            if GOAP.dbORBAT then
                GOAP.saveTable("tblORBATDb", GOAP.dbORBAT)
            end
		end 

        timer.scheduleFunction(exportTerrainDb, {}, timer.getTime() + cur_Stack)
        cur_Stack = cur_Stack + prt_stack
        timer.scheduleFunction(exportIntelDb, {}, timer.getTime() + cur_Stack)
        cur_Stack = cur_Stack + prt_stack
        timer.scheduleFunction(exportORBATDb, {}, timer.getTime() + cur_Stack)

        cur_Stack = 0.5
    else
		local msg_duration = 0.05
		local prt_stack = 0.1
		cur_Stack = 0.5 -- start point

        strTerrainDB						= ""
        strIntelDB                          = ""
        completeStringTerrainDB		        = ""
        completeStringIntelDB               = ""
        
        local t = {} 
        for iI, iD in pairs(terrain) do 
            t[iI] = {col = iD.colour, p = iD.pos, own = iD.owner, name = iD.display_name}
        end

		strTerrainDB = IntegratedserializeWithCycles("tblTerrainDb", t)
		completeStringTerrainDB = tostring(strTerrainDB)
		local function funcTerrainDb()
			trigger.action.outText(completeStringTerrainDB, msg_duration)
		end

		strIntelDB = IntegratedserializeWithCycles("tblIntelDb", GOAP.intel)
		completeStringIntelDB = tostring(strIntelDB)
		local function funcIntelDb()
			trigger.action.outText(completeStringIntelDB, msg_duration)
		end

		strORBATDB = IntegratedserializeWithCycles("tblORBATDb", GOAP.dbORBAT)
		completeStringORBATDB = tostring(strORBATDB)
		local function funcORBATDb()
			trigger.action.outText(completeStringORBATDB, msg_duration)
		end

        timer.scheduleFunction(funcTerrainDb, {}, timer.getTime() + cur_Stack)
        cur_Stack = cur_Stack + prt_stack
        timer.scheduleFunction(funcIntelDb, {}, timer.getTime() + cur_Stack)
        cur_Stack = cur_Stack + prt_stack
        timer.scheduleFunction(funcORBATDb, {}, timer.getTime() + cur_Stack)

        cur_Stack = 0.5
    end

end

--## DEBUGGER
local groupTest = Group.getByName("Tester")
if groupTest then
    local coa = groupTest:getCoalition()

    --GOAP.goToTown({groupTest, "ZUGDIDI"})    -- , GOAP.haltOnContact
    local function executeThis()
        groupTest:goToTown("ZUGDIDI", Group.haltOnContact)
    end

    timer.scheduleFunction(executeThis, {}, timer.getTime() + 10)
end

local function callchecks(vars)
    local gtest = vars[1]
    env.info(("GOAP GOAP.hasTargets: " .. tostring(GOAP.hasTargets(gtest))))
    env.info(("GOAP GOAP.groupLowAmmo: " .. tostring(GOAP.groupLowAmmo(gtest))))
    env.info(("GOAP GOAP.groupHasLosses: " .. tostring(GOAP.groupHasLosses(gtest))))

    timer.scheduleFunction(callchecks, {gtest}, timer.getTime() + 60)
end

--## MISSION START PROCESS
env.info(("GOAP is starting initial mission setup"))
-- set all units disperse "off" to prevent halting for movement & escape reactions

-- set troops system
GOAP.updateTroops()

-- get terrains influence
GOAP.phase0_initTerrains()


GOAP.setAllNotDisperse()
-- create the basic unit list table
GOAP.phaseB_createORBAT_INTEL()

-- initialize FSM cycle
phase = "F"
GOAP.performPhaseCycle()





--## MISSION UPDATE PROCESS





timer.scheduleFunction(GOAP.addF10MenuOptions, nil, timer.getTime() + 5)




--
env.info((ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date))