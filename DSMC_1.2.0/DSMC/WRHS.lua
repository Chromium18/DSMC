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

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## LOCAL VARIABLES
local tempWarehousesTable		= nil
local strWarehouses				= nil
temp_tblWarehouses				= nil
WRHSloaded						= false
tblWarehouses					= nil


-- ## TABLES
dbWeapon = {}
local supplierFeed = {}

function createdbWeapon()	
	local wpnAddnum = 0
	dbWeapon = {}
	HOOK.writeDebugDetail(ModuleName .. ": createdbWeapon, launched")
	--UTIL.dumpTable("nightlyGb.lua", _G)
	--HOOK.writeDebugDetail(ModuleName .. ": createdbWeapon, G exported")
	for uniID, uniData in pairs(resource_by_unique_name) do
		--HOOK.writeDebugDetail(ModuleName .. ": createdbWeapon, checking " .. tostring(uniID))
		local wsTable = uniData.wsTypeOfWeapon or uniData.ws_type
		if wsTable then
			if type(wsTable) == "table" then
				if #wsTable == 4 then
					--HOOK.writeDebugDetail(ModuleName .. ": createdbWeapon, wsTable found for " .. tostring(uniID))
					local wsString = wsTypeToString(wsTable)	
					HOOK.writeDebugDetail(ModuleName .. ": createdbWeapon, wsString for  " .. tostring(uniID).. " is " .. tostring(wsString))
					dbWeapon[#dbWeapon+1] = {unique = uniID, name = uniData.name, wsData = wsString}
					wpnAddnum = wpnAddnum + 1
				end
			end
		end
	end
	HOOK.writeDebugDetail(ModuleName .. ": createdbWeapon, added " .. tostring(wpnAddnum) .. " weapons")
	
	if HOOK.debugProcessDetail then
		UTIL.dumpTable("dbWeapon.lua", dbWeapon)
	end
end

-- ## ELAB FUNCTION
function consolidateStandardLogistic(curr_tblLogistic)
	local temp_tblLogistic ={}
	HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic started")
	for oId, oData in pairs(curr_tblLogistic) do
		HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic checking: " .. tostring(oId))

		-- check direct ammo category supply
		if oData.directfuel or oData.directammo then
			HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, supply is a direct ammo or fuel, skipping")
		else

			-- check airport there or add it
			local tempTbl = {}
			local found = false
			if table.getn(temp_tblLogistic) > 0 then
				for cId, cData in pairs(temp_tblLogistic) do
					local o_id = tostring(oData.placeId) .. "_" .. tostring(oData.placeType)
					local c_id = tostring(cData.placeId) .. "_" .. tostring(cData.placeType)
					if o_id == c_id then
						found = true
						tempTbl = cData
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found existing temp_tblLogistic entry for  " .. tostring(c_id))
					end
				end
			end

			if found == false then
				tempTbl = {placeId = oData.placeId, placeType = oData.placeType, jet_fuel = {InitFuel = 0}, weapons = {}, aircrafts = {}, dAmmo = oData.directammo, dQty = oData.dirQty}
				HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, no previous temp_tblLogistic entry for  " .. tostring(oData.placeId))
			end

			-- fuel ops
			if oData.action == "departure" then
				tempTbl.jet_fuel.InitFuel = tempTbl.jet_fuel.InitFuel - (math.floor(oData.fuel/100)/10)
				HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, fuel recorded, departure")
			elseif oData.action == "arrival" then
				tempTbl.jet_fuel.InitFuel = tempTbl.jet_fuel.InitFuel + math.floor(oData.fuel/100)/10
				HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, fuel recorded, arrival")
			end

			-- wpn ops
			if oData.action == "departure" then
				local wpnTemp = tempTbl.weapons
				for dId, dData in pairs(oData.ammo) do
					HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, wpn recorded, departure: " .. tostring(dData.wsString))
					
					local wfound = false
					for rId, rData in pairs(wpnTemp) do
						if dData.wsString == rData.wsString then
							rData.amount = rData.amount - dData.amount
							wfound = true
							HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found wpn in wpnTemp, removing from there")
						end
					end

					if wfound == false then
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, wpn is new in wpnTemp, removing from there")
						wpnTemp[#wpnTemp+1] = {amount = - dData.amount, wsString = dData.wsString}
					end

				end
				tempTbl.weapons = wpnTemp
				wpnTemp = nil

			elseif oData.action == "arrival" then

				-- normal ammo
				local wpnTemp = tempTbl.weapons
				for dId, dData in pairs(oData.ammo) do
					HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, wpn recorded, arrival: " .. tostring(dData.wsString))
					
					local wfound = false
					for rId, rData in pairs(wpnTemp) do
						if dData.wsString == rData.wsString then
							rData.amount = rData.amount + dData.amount
							wfound = true
							HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found wpn in wpnTemp, adding there")
						end
					end

					if wfound == false then
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, wpn is new in wpnTemp, adding there")
						wpnTemp[#wpnTemp+1] = {amount = dData.amount, wsString = dData.wsString}
					end

				end
				tempTbl.weapons = wpnTemp
				wpnTemp = nil
			end

			--acf ops
			if oData.action == "departure" then
				local tmpAcf = tempTbl.aircrafts
				local afound = false
				for aId, aNumber in pairs(tmpAcf) do
					if aId == oData.acf then
						afound = true
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found acf in tmpAcf, remove action, curVal = " ..tostring(aNumber))
						aNumber = aNumber - 1
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found acf in tmpAcf, remove action, newVal = " ..tostring(aNumber))
						tmpAcf[oData.acf] = aNumber
					end
				end

				if afound == false then
					tmpAcf[oData.acf] = -1
					HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, acf is new in tmpAcf, removing there")
				end
				tempTbl.aircrafts = tmpAcf
				tmpAcf = nil			

			elseif oData.action == "arrival" then
				local tmpAcf = tempTbl.aircrafts
				local afound = false
				for aId, aNumber in pairs(tmpAcf) do
					if aId == oData.acf then
						afound = true
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found acf in tmpAcf, add action, curVal = " ..tostring(aNumber))
						aNumber = aNumber + 1
						HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, found acf in tmpAcf, add action, curVal = " ..tostring(aNumber))
						tmpAcf[oData.acf] = aNumber
					end
				end

				if afound == false then
					tmpAcf[oData.acf] = 1
					HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic, acf is new in tmpAcf, adding there")
				end

				tempTbl.aircrafts = tmpAcf
				tmpAcf = nil	
			end

			if found == true then
				for cId, cData in pairs(temp_tblLogistic) do
					if oData.placeId == cData.placeId then			
						cData = tempTbl
					end
				end
			elseif found == false then
				temp_tblLogistic[#temp_tblLogistic+1] = tempTbl
			end
		end
	end

	--UTIL.dumpTable("WRHS.consolidateStandardLogistic.lua", temp_tblLogistic)
	HOOK.writeDebugDetail(ModuleName .. ": consolidateStandardLogistic done")
	return temp_tblLogistic

end

function elabCratesLogistic(inj_tblLogistic, inj_tempWarehouses)

	HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic cycle started")

	tblLogistic = inj_tblLogistic
	tempWarehouses = inj_tempWarehouses
	
	if tblLogistic and tempWarehouses then
		--UTIL.dumpTable("tempWarehouses.lua", tempWarehouses)	-- DEBUG
		for LogId, LogData in pairs(tblLogistic) do
			if LogData.directfuel or LogData.directammo then
				HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic working on direct supply, supply index: " .. tostring(LogId))

				for afbType, afbIds in pairs(tempWarehouses) do
					if afbType == LogData.placeType then
						for afbId, afbData in pairs(afbIds) do
							if tonumber(afbId) == tonumber(LogData.placeId) then
								
								HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic placeId ok: " .. tostring(afbId))
								local tempAfbData = UTIL.deepCopy(afbData)
								if tempAfbData.unlimitedFuel == false and LogData.directfuel then
									tempAfbData.jet_fuel.InitFuel = tempAfbData.jet_fuel.InitFuel + LogData.directfuel
									HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic fuel added: " ..tostring(LogData.directfuel) .. "\n")
								elseif tempAfbData.unlimitedMunitions == false and LogData.directammo and LogData.dirQty then
									HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic directammo request, category: " .. tostring(LogData.directammo)  .. ", qty: " .. tostring(LogData.dirQty))	
									
									for _, wData in pairs(tempAfbData.weapons) do
										local agreed = false
										for wsId, wsData in pairs(wData.wsType) do
											if wsId == 3 then
												if wsData == tonumber(LogData.directammo) then
													agreed = true
												end
											end
										end

										if agreed then
											HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic directammo adding weapon, quantity: " .. tostring(LogData.dirQty))	
											wData.initialAmount = wData.initialAmount + tonumber(LogData.dirQty)
										end
									end

								end

								afbIds[afbId] = tempAfbData

							end
						end
					end
				end
			end
		end

		HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic cycle done")
		return tempWarehouses
	else
		HOOK.writeDebugDetail(ModuleName .. ": elabCratesLogistic variable missing!")
	end
end

function elabStandardLogistic(inj_tblLogistic, inj_tempWarehouses)
	tblLogistic = inj_tblLogistic
	tempWarehouses = inj_tempWarehouses
	
	if tblLogistic and tempWarehouses then
		--UTIL.dumpTable("tempWarehouses.lua", tempWarehouses)	-- DEBUG
		for _, LogData in pairs(tblLogistic) do
			for afbType, afbIds in pairs(tempWarehouses) do
				for afbId, afbData in pairs(afbIds) do
					
					-- set none operating level to comply DSMC rules, apply to ALL warehouses
					afbData.OperatingLevel_Air 		= 1								
					afbData.OperatingLevel_Eqp 		= 1
					afbData.OperatingLevel_Fuel 	= 1	

					local code_id = tostring(afbId) .. "_" .. tostring(afbType)
					local log_id = tostring(LogData.placeId) .. "_" .. tostring(LogData.placeType)

					--HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic code_id: " .. tostring(code_id) .. ", log_id: " .. tostring(log_id))

					if code_id == log_id then						
						HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic code_id ok: " .. tostring(code_id))
						
						--local code_id = tostring(afbId) .. "_" .. tostring(afbType)
						
						--fuel
						if afbData.unlimitedFuel == false then
							if LogData.jet_fuel.InitFuel and type(LogData.jet_fuel.InitFuel) == "number" then
								if LogData.jet_fuel.InitFuel < 0 then
									HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic to remove fuel: " .. tostring(LogData.jet_fuel.InitFuel))
									
									-- try to catch supplier!
									HOOK.writeDebugDetail(ModuleName .. ": current fuel amount: " .. tostring(afbData.jet_fuel.InitFuel))
									local qty = executeFuelSupply(code_id, afbData.suppliers, -LogData.jet_fuel.InitFuel, afbData.coalition)
									if qty then
										HOOK.writeDebugDetail(ModuleName .. ": recovered by supply: " .. tostring(qty))	
										afbData.jet_fuel.InitFuel = afbData.jet_fuel.InitFuel + LogData.jet_fuel.InitFuel + qty
										HOOK.writeDebugDetail(ModuleName .. ": new fuel amount: " .. tostring(afbData.jet_fuel.InitFuel))	

									else
										afbData.jet_fuel.InitFuel = afbData.jet_fuel.InitFuel + LogData.jet_fuel.InitFuel 
										HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic ERROR, so fuel removed: " ..tostring(LogData.jet_fuel.InitFuel) .. "\n")
									end

								else
									afbData.jet_fuel.InitFuel = afbData.jet_fuel.InitFuel + LogData.jet_fuel.InitFuel 
									HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic fuel added: " ..tostring(LogData.jet_fuel.InitFuel) .. "\n")
								end
							end
						end
						
						--aircraft
						if LogData.aircrafts then
							for aName, aNumber in pairs(LogData.aircrafts) do
								for acCategory, acNames in pairs(afbData.aircrafts) do
									for acName, acData in pairs(acNames) do
										if acName == aName then
											acData.initialAmount = acData.initialAmount + aNumber
											HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic adjusted acf type: " .. tostring(aName) .. ", qty: " .. tostring(aNumber) .. "\n")	
										end
									end
								end

							end
						else
							HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic no aircraft variable")	
						end
						
						--ammo  
						if afbData.unlimitedMunitions == false then

							if LogData.weapons then -- check weapons ONLY if 
								if table.getn(LogData.weapons) > 0 then
									for rId, rData in pairs(LogData.weapons) do
										HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic wpn request: " .. tostring(rData.wsString)  .. ", qty: " .. tostring(rData.amount))	
										for wId, wData in pairs(afbData.weapons) do
											local w_wsType_str = wsTypeToString(wData.wsType)					
											if w_wsType_str then
												if w_wsType_str == rData.wsString then

													if rData.amount < 0 then
														HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic to remove ammo: " .. tostring(rData.amount))
														
														-- try to catch supplier!
														HOOK.writeDebugDetail(ModuleName .. ": current ammo amount: " .. tostring(wData.initialAmount))
														local qty = executeAmmoSupply(code_id, afbData.suppliers, -rData.amount, rData.wsString, afbData.coalition, wData.wsType[3])
														if qty then
															HOOK.writeDebugDetail(ModuleName .. ": recovered by supply: " .. tostring(qty))	
															wData.initialAmount = wData.initialAmount + rData.amount + qty
															HOOK.writeDebugDetail(ModuleName .. ": new ammo amount: " .. tostring(wData.initialAmount))	
					
														else
															wData.initialAmount = wData.initialAmount + rData.amount
															HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic ERROR, so ammo removed: " ..tostring(rData.amount) .. "\n")
														end
					
													else
														wData.initialAmount = wData.initialAmount + rData.amount
														HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic ammo added: " ..tostring(rData.amount) .. "\n")
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

		--tblWarehouses = tempWarehouses
		HOOK.writeDebugDetail(ModuleName .. ": elabStandardLogistic cycle done")
		return tempWarehouses
		
	else
		HOOK.writeDebugDetail(ModuleName .. ": tblLogistic not available")
	end
end

function executeFuelSupply(code_ori, tbl_su, req_quantity, coa)
	HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply \n")
	HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply req_quantity: " .. tostring(req_quantity) .. ", coa: " .. tostring(coa))
	if req_quantity and coa then
		HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply is a fuel supply request")
		local bestSupplier = nil
		local currentFuel = 0
		local best_unli = false

		if #tbl_su > 0 then
			for _, sData in pairs(tbl_su) do
				for afbType, afbIds in pairs(tempWarehouses) do
					for afbId, afbData in pairs(afbIds) do
						local code_cur = tostring(afbId) .. "_" .. tostring(afbType)
						local code_match = tostring(sData.Id) .. "_" .. tostring(sData.type)
						if code_cur == code_match then

							--local code_cur = tostring(afbId) .. "_" .. tostring(afbType)

							HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply code_ori: " .. tostring(code_ori) .. ", code_cur: " .. tostring(code_cur))
							if code_ori ~= code_cur then
								HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply found a warehouse")
								HOOK.writeDebugDetail(ModuleName .. ": coa: " .. tostring(coa) .. ", afbData.coalition: " .. tostring(afbData.coalition))
								if string.lower(coa) == string.lower(afbData.coalition) then
									HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply coalition checked")

									local fuel_avail  	= nil
									--local fuel_total 	= nil
									if afbData.unlimitedFuel == true then
										fuel_avail  	= afbData.size or 999999999
									else
										if afbData.jet_fuel.InitFuel < afbData.size then
											fuel_avail  	= afbData.jet_fuel.InitFuel
										else
											fuel_avail  	= afbData.size
										end
										--fuel_total		= afbData.jet_fuel.InitFuel
									end

									local fuel_req		= req_quantity
									local fuel_rem		= fuel_avail - fuel_req
									HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply evaluate supplier: " .. tostring(afbId) .. ", fuel_avail: " .. tostring(fuel_avail) .. ", fuel_req: " .. tostring(fuel_req) .. ", fuel_rem: " .. tostring(fuel_rem))
									if fuel_avail > 0 then -- there is fuel
										HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply fuel availability confirmed")
										if fuel_rem < 0 then -- fuel is not sufficient to cover entire request, check for best supplier (more fuel available)
											if fuel_avail > currentFuel then
												bestSupplier = code_cur
												currentFuel = fuel_avail
												best_unli = afbData.unlimitedFuel
												HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply found partial supplier; fuel_avail: " .. tostring(fuel_avail))
											end
										else -- fuel is sufficient, check for best supplier (more fuel available)
											if fuel_avail > currentFuel then
												bestSupplier = code_cur
												currentFuel = fuel_req
												best_unli = afbData.unlimitedFuel
												HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply found complete supplier; fuel_avail: " .. tostring(fuel_avail))
											end
										end

									else
										HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply no fuel available here")
									end
								else
									HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply coalition wrong, skip")
								end
							end
						end
					end
				end
			
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply tbl_su don't have entries")
			return 0
		end

		HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply bestSupplier: " .. tostring(bestSupplier) .. ", currentFuel: " .. tostring(currentFuel))
		if bestSupplier and currentFuel > 0 then
			for r_afbType, r_afbIds in pairs(tempWarehouses) do
				for r_afbId, r_afbData in pairs(r_afbIds) do			
					local r_code_cur = tostring(r_afbId) .. "_" .. tostring(r_afbType)
					if bestSupplier == r_code_cur then

						if best_unli == false then
							local re_req = currentFuel
							HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply request re_req: " .. tostring(re_req))
							local re_qty = executeFuelSupply(r_code_cur, r_afbData.suppliers, re_req, coa)
							HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply re-supplier check re_qty: " .. tostring(re_qty))
							if re_qty then
								if re_qty > 0 then
									r_afbData.jet_fuel.InitFuel = r_afbData.jet_fuel.InitFuel - re_req + re_qty
									HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply re-supply available amount re_qty: " .. tostring(re_qty))
									return re_req
								else
									HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply no valid re-supplier found, removed entire re_req")
									r_afbData.jet_fuel.InitFuel = r_afbData.jet_fuel.InitFuel - re_req
									return re_req
								end
							else
								HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply fail re-supplier function, removed entire re_req")
								r_afbData.jet_fuel.InitFuel = r_afbData.jet_fuel.InitFuel - re_req
								return re_req
							end
						else
							HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply warehouse is unlimited, no sum required")
							return currentFuel
						end

					end
				end
			end

		else
			HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply no valid supplier found, returning 0")
			return 0
		end

		return 0
	else
		HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply missing fuel value!!")
		return 0
	end
end

function executeAmmoSupply(code_ori, tbl_su, req_quantity, req_wsType, coa, req_wsThird)
	HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply req_quantity: " .. tostring(req_quantity) .. ", coa: " .. tostring(coa))
	if req_quantity and coa then
		HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply is a ammo supply request")
		local bestSupplier = nil
		local currentAmmo = 0
		local best_unli = false

		local complexWeapon = nil
		if req_wsThird == 7 or req_wsThird == 8 or req_wsThird == 36 or req_wsThird == 38 or req_wsThird == 37 then
			complexWeapon = true
		else
			complexWeapon = false
		end
		HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply, complexWeapon: " .. tostring(complexWeapon))

		if #tbl_su > 0 then
			for _, sData in pairs(tbl_su) do
				for afbType, afbIds in pairs(tempWarehouses) do
					for afbId, afbData in pairs(afbIds) do
						local code_cur = tostring(afbId) .. "_" .. tostring(afbType)
						local code_match = tostring(sData.Id) .. "_" .. tostring(sData.type)
						if code_cur == code_match then
							
							HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply code_ori: " .. tostring(code_ori) .. ", code_cur: " .. tostring(code_cur))
							if code_ori ~= code_cur then					
								if string.lower(coa) == string.lower(afbData.coalition) then

									if afbData.unlimitedMunitions == true then
										
										if complexWeapon == true then
											if math.floor(afbData.size/5) > currentAmmo then
												currentAmmo  = math.floor(afbData.size/5) or 999999999
												bestSupplier = code_cur
												best_unli = true
												HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply unlimited, currentAmmo: " .. tostring(currentAmmo))
											else
												HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply unlimited but worse than current bestSupplier")
											end
										else
											if afbData.size > currentAmmo then
												currentAmmo  = afbData.size
												bestSupplier = code_cur
												best_unli = true
												HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply unlimited, currentAmmo: " .. tostring(currentAmmo))
											else
												HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply unlimited but worse than current bestSupplier")
											end
										end
										

									else
										for wId, wData in pairs(afbData.weapons) do
											local w_wsType_str = wsTypeToString(wData.wsType)			


											if w_wsType_str then
												if w_wsType_str == req_wsType then

													local ammo_avail  	= nil
													local val = nil
													if complexWeapon == true then
														val = 	math.floor(afbData.size/5)
													else
														val = afbData.size
													end

													if val then
														if wData.initialAmount < val then
															ammo_avail = wData.initialAmount
														else
															ammo_avail = val
														end

														HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply limited, ammo_avail: " .. tostring(ammo_avail))
													else
														HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply, error getting val")
														ammo_avail  	= wData.initialAmount
													end

													local ammo_req		= req_quantity
													local ammo_rem		= ammo_avail - req_quantity		
						
													HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply evaluate supplier: " .. tostring(afbId) .. ", weapon: " .. tostring(req_wsType) .. ", ammo_avail: " .. tostring(ammo_avail) .. ", ammo_req: " .. tostring(ammo_req) .. ", ammo_rem: " .. tostring(ammo_rem) .. ",complexWeapon: " .. tostring(complexWeapon))
													if ammo_avail > 0 then -- there is fuel
														HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply weapon availability confirmed")
														if ammo_rem < 0 then -- fuel is not sufficient to cover entire request, check for best supplier role
															if ammo_avail > currentAmmo then
																bestSupplier = code_cur
																currentAmmo = ammo_avail
																best_unli = false
																HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply found partial supplier; ammo_avail: " .. tostring(ammo_avail))
															end
														else
															if ammo_avail > currentAmmo then
																bestSupplier = code_cur
																currentAmmo = ammo_req
																best_unli = false
																HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply found complete supplier; ammo_avail: " .. tostring(ammo_avail))
															end
														end
						
													else
														HOOK.writeDebugDetail(ModuleName .. ": no ammo available here")
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
			HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply tbl_su don't have entries")
			return 0
		end

		HOOK.writeDebugDetail(ModuleName .. ": executeFuelSupply bestSupplier: " .. tostring(bestSupplier) .. ", currentAmmo: " .. tostring(currentAmmo))
		if bestSupplier and currentAmmo > 0 then
			for r_afbType, r_afbIds in pairs(tempWarehouses) do
				for r_afbId, r_afbData in pairs(r_afbIds) do	
					local r_code_cur = tostring(r_afbId) .. "_" .. tostring(r_afbType)							
					if bestSupplier == r_code_cur then
						
						if best_unli == false then
							for r_wId, r_wData in pairs(r_afbData.weapons) do
								local w_wsType_str = wsTypeToString(r_wData.wsType)					
								if w_wsType_str then
									if w_wsType_str == req_wsType then			
							
										local re_req = currentAmmo
										HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply request re_req: " .. tostring(re_req))
										local re_qty = executeAmmoSupply(r_code_cur, r_afbData.suppliers, re_req, req_wsType, coa, req_wsThird)
										HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply re-supplier check re_qty: " .. tostring(re_qty))
										if re_qty then
											if re_qty > 0 then
												r_wData.initialAmount = r_wData.initialAmount - re_req + re_qty
												HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply re-supply available amount re_qty: " .. tostring(re_qty))
												return re_req
											else								
												HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply no valid re-supplier found, removed entire re_req")
												r_wData.initialAmount = r_wData.initialAmount - re_req
												return re_req
											end
										else									
											HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply fail re-supplier function, removed entire re_req")
												r_wData.initialAmount = r_wData.initialAmount - re_req
											return re_req
										end
									end
								end
							end
						else
							HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply warehouse is unlimited, no sum required")
							return currentAmmo
						end


					end
				end
			end

		else
			HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply no valid supplier found, returning 0")
			return 0
		end

		return 0
	else
		HOOK.writeDebugDetail(ModuleName .. ": executeAmmoSupply missing ammo value!!")
		return 0
	end
end

function warehouseUpdateCycle(tblLog, tblWh)
	HOOK.writeDebugDetail(ModuleName .. ": warehouseUpdateCycle start!")
	--local FARPadd = UTIL.addFARPwh(inj_tempWarehouses)
	local tblWhWithCrates = elabCratesLogistic(tblLog, tblWh)
	local tblLogConsolidated = consolidateStandardLogistic(tblLog)
	local updatedWh = elabStandardLogistic(tblLogConsolidated, tblWhWithCrates)
	

	if updatedWh then
		tblWarehouses = updatedWh
	else
		HOOK.writeDebugDetail(ModuleName .. ": warehouseUpdateCycle didn't work!")
	end
end



HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
WRHSloaded = true
