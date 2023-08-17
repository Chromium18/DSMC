-- Dynamic Sequential Mission Campaign -- WAREHOUSES module

local ModuleName  	= "WRHS"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('WRHS', package.seeall)
local require 		= base.require		
local io 			= require('io')
local lfs 			= require('lfs')
local os 			= require('os')
local ME_DB   		= require('me_db_api')

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
WRHSloaded						= false
tblWarehouses					= nil



function updateWarehouses(tblContent, tempWarehouses)

	HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses cycle started")

	if tblContent and tempWarehouses then

		local tblContent_a = {}
		local tblContent_w = {}
		for cId, cData in pairs(tblContent) do
			if type(cData.objCat) == "number" then -- find a more solid way?
				tblContent_a[#tblContent_a+1] = cData

			elseif type(cData.objCat) == "string" then
				tblContent_w[#tblContent_w+1] = cData

			end
		end
		HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses tblContent_w and a created")

		for whCat, whTbl in pairs(tempWarehouses) do -- cycle in warehouse table
			if whCat == "airports" then
				--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses checking airports")
				for whId, whData in pairs(whTbl) do -- cycle in warehouse table

					-- set standard values
					whData.OperatingLevel_Air 		= 99								
					whData.OperatingLevel_Eqp 		= 99
					whData.OperatingLevel_Fuel 		= 99	
					whData.periodicity 				= 5
					--whData.size 					= 99	
					--whData.speed 					= 16.666666				

					-- do fuel
					if whData.unlimitedFuel == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " fuel limited")
						for aId, aData in pairs(tblContent_a) do
							if tonumber(aData.id) == tonumber(whId) then
								for aCat, aCont in pairs(aData.wh) do
									if aCat == "liquids" then
										--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " fuel data found and set")
										whData.jet_fuel.InitFuel 			= aCont[0]/1000
										whData.gasoline.InitFuel 			= aCont[1]/1000
										whData.methanol_mixture.InitFuel 	= aCont[2]/1000
										whData.diesel.InitFuel 				= aCont[3]/1000
									end
								end
							end
						end
					end

					-- do aircrafts
					if whData.unlimitedAircrafts == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " aircrafts limited")
						for aCat, aCatData in pairs(whData.aircrafts) do
							for aType, aTypeData in pairs(aCatData) do

								for aId, aData in pairs(tblContent_a) do
									if tonumber(aData.id) == tonumber(whId) then
										--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " warehouse source found")
										for aCat, aCont in pairs(aData.wh) do
											if aCat == "aircraft" then
												for awId, awData in pairs(aCont) do
													if awId == aType then
														HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " aircrafts found " .. tostring(awId))
														aTypeData.initialAmount = awData
													end
												end
											end
										end
									end
								end

							end
						end
					end

					-- do items
					if whData.unlimitedMunitions == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " weapons limited")
						for iId, iData in pairs(whData.weapons) do 
							local wConv = UTIL.deepCopy(iData.wsType)
							for wId, wData in pairs(wConv) do
								if wId > 4 then
									wConv[wId] = nil
								end
							end

							for aId, aData in pairs(tblContent_a) do
								if tonumber(aData.id) == tonumber(whId) then
									--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " warehouse source found")
									for awId, awData in pairs(aData.wh) do
										if awId == "weapon" then
											for wpnId, wpnData in pairs(awData) do
												local a = wsTypeToString(wpnData.wsd)	
												local b = wsTypeToString(wConv)	
												if a == b then
													--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " weapons data set found")
													iData.initialAmount = wpnData.qty
												end
											end
										end
									end
								end
							end								
						end
					end
				end

			elseif whCat == "warehouses" then

				--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses checking warehouses")
				for whId, whData in pairs(whTbl) do -- cycle in warehouse table

					-- set standard values
					whData.OperatingLevel_Air 		= 99								
					whData.OperatingLevel_Eqp 		= 99
					whData.OperatingLevel_Fuel 		= 99	
					whData.periodicity 				= 5
					--whData.size 					= 99	
					--whData.speed 					= 16.666666		

					-- do fuel
					if whData.unlimitedFuel == false then
						for aId, aData in pairs(tblContent_w) do
							if tonumber(aData.id) == tonumber(whId) then
								for aCat, aCont in pairs(aData.wh) do
									if aCat == "liquids" then
										whData.jet_fuel.InitFuel 			= aCont[0]/1000
										whData.gasoline.InitFuel 			= aCont[1]/1000
										whData.methanol_mixture.InitFuel 	= aCont[2]/1000
										whData.diesel.InitFuel 				= aCont[3]/1000
									end
								end
							end
						end
					end

					-- do aircrafts
					if whData.unlimitedAircrafts == false then
						for aCat, aCatData in pairs(whData.aircrafts) do
							for aType, aTypeData in pairs(aCatData) do

								for aId, aData in pairs(tblContent_w) do
									if tonumber(aData.id) == tonumber(whId) then
										for aCat, aCont in pairs(aData.wh) do
											if aCat == "aircraft" then
												for awId, awData in pairs(aCont) do
													if awId == aType then
														aTypeData.initialAmount = awData
													end
												end
											end
										end
									end
								end

							end
						end
					end

					-- do items
					if whData.unlimitedMunitions == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " weapons limited")
						for iId, iData in pairs(whData.weapons) do 
							local wConv = UTIL.deepCopy(iData.wsType)
							for wId, wData in pairs(wConv) do
								if wId > 4 then
									wConv[wId] = nil
								end
							end

							for aId, aData in pairs(tblContent_w) do
								if tonumber(aData.id) == tonumber(whId) then
									--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " warehouse source found")
									for awId, awData in pairs(aData.wh) do
										if awId == "weapon" then
											for wpnId, wpnData in pairs(awData) do
												local a = wsTypeToString(wpnData.wsd)	
												local b = wsTypeToString(wConv)	
												if a == b then
													--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " weapons data set found")
													iData.initialAmount = wpnData.qty
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

		return tempWarehouses

	else
		HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses missing variables")
	end
end

--[[
function updateWarehouses(tblContent, tempWarehouses)

	HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses cycle started")

	if tblContent and tempWarehouses then

		local tblContent_a = {}
		local tblContent_w = {}
		for cId, cData in pairs(tblContent) do
			if type(cData.objCat) == "number" then -- find a more solid way?
				tblContent_a[#tblContent_a+1] = cData

			elseif type(cData.objCat) == "string" then
				tblContent_w[#tblContent_w+1] = cData

			end
		end

		--UTIL.dumpTable("tblContent_a.lua", tblContent_a)
		--UTIL.dumpTable("tblContent_w.lua", tblContent_w)


		HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses tblContent_w and a created")

		for whCat, whTbl in pairs(tempWarehouses) do -- cycle in warehouse table
			if whCat == "airports" then

				HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses checking airports")

				for whId, whData in pairs(whTbl) do -- cycle in warehouse table
					
					-- do fuel
					if whData.unlimitedFuel == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " fuel limited")
						for aId, aData in pairs(tblContent_a) do
							if tonumber(aData.id) == tonumber(whId) then
								--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " fuel data found and set")
								whData.jet_fuel.InitFuel 			= aData.pol.jet_fuel
								whData.gasoline.InitFuel 			= aData.pol.gasoline
								whData.methanol_mixture.InitFuel 	= aData.pol.methanol_mixture
								whData.diesel.InitFuel 				= aData.pol.diesel
							end
						end
					end

					-- do aircrafts
					if whData.unlimitedAircrafts == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " aircrafts limited")
						for aCat, aCatData in pairs(whData.aircrafts) do
							for aType, aTypeData in pairs(aCatData) do
								local wConv = UTIL.deepCopy(aTypeData.wsType)
								for wId, wData in pairs(wConv) do
									if wId > 4 then
										wConv[wId] = nil
									end
								end

								for aId, aData in pairs(tblContent_a) do
									if tonumber(aData.id) == tonumber(whId) then
										--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " warehouse source found")
										for awId, awData in pairs(aData.wh) do
											local a = wsTypeToString(awData.ws)	
											local b = wsTypeToString(wConv)	
											if a == b then
												--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " aircrafts data set found")
												aTypeData.initialAmount = awData.amount
											end
										end
									end
								end								
							end
						end
					end

					-- do items
					if whData.unlimitedMunitions == false then
						--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " weapons limited")
						for iId, iData in pairs(whData.weapons) do 
							local wConv = UTIL.deepCopy(iData.wsType)
							for wId, wData in pairs(wConv) do
								if wId > 4 then
									wConv[wId] = nil
								end
							end

							for aId, aData in pairs(tblContent_a) do
								if tonumber(aData.id) == tonumber(whId) then
									--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " warehouse source found")
									for awId, awData in pairs(aData.wh) do
										local a = wsTypeToString(awData.ws)	
										local b = wsTypeToString(wConv)	
										if a == b then
											--HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses whId " .. tostring(whId) .. " weapons data set found")
											iData.initialAmount = awData.amount
										end
									end
								end
							end								
						end
					end

				end
			elseif whCat == "warehouses" then

				HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses checking warehouses")

				for whId, whData in pairs(whTbl) do -- cycle in warehouse table
					
					-- do fuel
					if whData.unlimitedFuel == false then
						for aId, aData in pairs(tblContent_w) do
							if tonumber(aData.id) == tonumber(whId) then
								whData.jet_fuel.InitFuel 			= aData.pol.jet_fuel
								whData.gasoline.InitFuel 			= aData.pol.gasoline
								whData.methanol_mixture.InitFuel 	= aData.pol.methanol_mixture
								whData.diesel.InitFuel 				= aData.pol.diesel
							end
						end
					end

					-- do aircrafts
					if whData.unlimitedAircrafts == false then
						for aCat, aCatData in pairs(whData.aircrafts) do
							for aType, aTypeData in pairs(aCatData) do
								local wConv = UTIL.deepCopy(aTypeData.wsType)
								for wId, wData in pairs(wConv) do
									if wId > 4 then
										wConv[wId] = nil
									end
								end

								for aId, aData in pairs(tblContent_w) do
									if tonumber(aData.id) == tonumber(whId) then
										for awId, awData in pairs(aData.wh) do
											local a = wsTypeToString(awData.ws)	
											local b = wsTypeToString(wConv)	
											if a == b then
												aTypeData.initialAmount = awData.amount
											end
										end
									end
								end								
							end
						end
					end

					-- do items
					if whData.unlimitedMunitions == false then
						for iId, iData in pairs(whData.weapons) do 
							local wConv = UTIL.deepCopy(iData.wsType)
							for wId, wData in pairs(wConv) do
								if wId > 4 then
									wConv[wId] = nil
								end
							end

							for aId, aData in pairs(tblContent_w) do
								if tonumber(aData.id) == tonumber(whId) then
									for awId, awData in pairs(aData.wh) do
										local a = wsTypeToString(awData.ws)	
										local b = wsTypeToString(wConv)	
										if a == b then
											iData.initialAmount = awData.amount
										end
									end
								end
							end								
						end
					end

				end

			end
		end

		return tempWarehouses

	else
		HOOK.writeDebugDetail(ModuleName .. ": updateWarehouses missing variables")
	end
end
--]]--

function warehouseUpdateCycle(tblWarehousesContent, tblWh)

	HOOK.writeDebugDetail(ModuleName .. ": warehouseUpdateCycle start!")

	local updatedWh = updateWarehouses(tblWarehousesContent, tblWh)

	if updatedWh then
		tblWarehouses = updatedWh
		HOOK.writeDebugDetail(ModuleName .. ": warehouseUpdateCycle updated wh")
	else
		HOOK.writeDebugDetail(ModuleName .. ": warehouseUpdateCycle didn't work!")
	end
end



HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
WRHSloaded = true
