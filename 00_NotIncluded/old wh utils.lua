

function whFixer(path1, path2)
	-- this function is done to update a warehouse file starting from another one to avoid the DCS "blank lines" issue when ED update the standard warehouse inventory
	-- this will substantially take every available data from a warehouse file (you previously edited) and overwrite those info into the new warehouse file
	-- all data whitout available info will be set as "0" items. This function is not done to set anything to "unlimited"!
	-- it's recommended to perform this particoular fix as soon as possibile anytime you notice "blank lines bugs"
	-- THIS FUNCTION IS NOT AUTOMATED
	-- you need to take you warehouse file and name it "from.lua", and the updated warehouse file re-named "to.lua". both files must be placed into \DSMC mod directory
	-- if both files are there, the function will perform it's job and you will se a "HOOK warehouse fixed!" message in DSMC.log and a new "fixedWH.lua" file that should be renamed in "warehouse" file
	-- after the fix, REMOVE ALL the files!


	if fileExist(path1) and fileExist(path2) then
		local fromTbl = {}
		local toTbl = {}
		local whEnv = {}

		if path2 == lfs.writedir() .. "DSMC/warehouses" then
			moveFile(path2, lfs.writedir() .. "DSMC/warehousesFrom")
			path2 = lfs.writedir() .. "DSMC/warehousesFrom"
		end

		local from = io.open(path1, 'r')
		local fromStr = ""
		if from then 
			fromStr = from:read('*all')
			if fromStr then 
				local fromFun = loadstring(fromStr)
				setfenv(fromFun, whEnv)
				fromFun()
				if whEnv.warehouses then
					fromTbl = whEnv.warehouses
					HOOK.writeDebugDetail(ModuleName .. ": whFixer: found fromTbl warehouse file")
				end
			end
			from:close()
		end

		local to = io.open(path2, 'r')
		local toStr = ""
		if to then 
			toStr = to:read('*all')
			if toStr then
				local toFun = loadstring(toStr)
				setfenv(toFun, whEnv)
				toFun()
				if whEnv.warehouses then
					toTbl = whEnv.warehouses
					HOOK.writeDebugDetail(ModuleName .. ": whFixer: found toTbl warehouse file")
				end
			end
			to:close()
		end		

		whEnv = nil

		if fromTbl and toTbl then
			HOOK.writeDebugDetail(ModuleName .. ": whFixer: found both table, proceeding fix overwrites")

			local baseTblAcf = nil
			local baseTblWpn = nil
			local foundAlimitedBase = false
			for ztId, ztData in pairs(toTbl) do			
				if ztId == "airports" then
					for zbId, zbData in pairs(ztData) do
						if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false then
							foundAlimitedBase = true
							baseTblAcf = zbData.aircrafts
							baseTblWpn = zbData.weapons
							HOOK.writeDebugDetail(ModuleName .. ": whFixer: defined baseTblAcf & baseTblWpn")

							for wId, wData in pairs(baseTblWpn) do
								wData.initialAmount = 0
							end
							for aTy, aTyData in pairs(baseTblAcf) do
								for aId, aData in pairs(aTyData) do
									aData.initialAmount = 0
								end
							end		
							HOOK.writeDebugDetail(ModuleName .. ": whFixer: baseTblWpn & baseTblAcf zeroed")		
													
							break

						end
					end
				end
			end

			if foundAlimitedBase and baseTblAcf and baseTblWpn then
				for ftId, ftData in pairs(fromTbl) do
					for fbId, fbData in pairs(ftData) do
						for ttId, ttData in pairs(toTbl) do
							for tbId, tbData in pairs(ttData) do
								if fbId == tbId then
									HOOK.writeDebugDetail(ModuleName .. ": whFixer: base data corrispondence, Id = " .. tostring(tbId))
									tbData.unlimitedFuel = fbData.unlimitedFuel
									tbData.unlimitedMunitions = fbData.unlimitedMunitions
									tbData.unlimitedAircrafts = fbData.unlimitedAircrafts
									HOOK.writeDebugDetail(ModuleName .. ": whFixer: unlimited parameters fixed")


									-- fix supplier
									tbData.suppliers = fbData.suppliers
									HOOK.writeDebugDetail(ModuleName .. ": whFixer: supplier fixed")

									-- fix fuel
									tbData.gasoline.InitFuel = fbData.gasoline.InitFuel
									tbData.methanol_mixture.InitFuel = fbData.methanol_mixture.InitFuel
									tbData.jet_fuel.InitFuel = fbData.jet_fuel.InitFuel
									tbData.diesel.InitFuel = fbData.diesel.InitFuel
									HOOK.writeDebugDetail(ModuleName .. ": whFixer: fuel fixed")

									-- fix operatingLevel and other parameters
									tbData.OperatingLevel_Air = fbData.OperatingLevel_Air
									tbData.OperatingLevel_Eqp = fbData.OperatingLevel_Eqp
									tbData.OperatingLevel_Fuel = fbData.OperatingLevel_Fuel
									tbData.speed = fbData.speed
									tbData.size = fbData.size
									tbData.periodicity = fbData.periodicity
									HOOK.writeDebugDetail(ModuleName .. ": whFixer: ops level & parameter fixed")

									-- fix aircraft
									if tbData.unlimitedAircrafts == false then
										for ttyType, ttyTable in pairs (tbData.aircrafts) do
											for ttyName, ttyData in pairs(ttyTable) do												
												local found = false
												for ftyType, ftyTable in pairs (fbData.aircrafts) do
													for ftyName, ftyData in pairs(ftyTable) do										
														if ttyName == ftyName then
															found = true
															ttyData.initialAmount = ftyData.initialAmount
															HOOK.writeDebugDetail(ModuleName .. ": whFixer: fixed acf quantity: " .. tostring(ttyName))
														end
													end
												end

												if found == false then
													HOOK.writeDebugDetail(ModuleName .. ": whFixer: aircraft " .. tostring(ttyName) .. " not found, set to 0")
													ttyData.initialAmount = 0
												end
											end
										end
										HOOK.writeDebugDetail(ModuleName .. ": whFixer: aircraft fixed")
									else
										tbData.aircrafts = {}
										HOOK.writeDebugDetail(ModuleName .. ": whFixer: aircraft fixed: unlimited")
									end


									-- fix weapons
									if tbData.unlimitedMunitions == false then
										for ttyId, ttyWData in pairs (tbData.weapons) do
											ttyWData.initialAmount = 0
											local ttString = wsTypeToString(ttyWData.wsType)
											for ftyId, ftyWData in pairs (fbData.weapons) do												
												local ftString = wsTypeToString(ftyWData.wsType)
												--HOOK.writeDebugDetail(ModuleName .. ": whFixer: checking ftString=" ..tostring(ftString) .. " with ttString=" ..tostring(ttString))
												if ttString == ftString then
													if ttyWData.initialAmount ~= ftyWData.initialAmount then
														HOOK.writeDebugDetail(ModuleName .. ": whFixer: to amount: " .. tostring(ttyWData.initialAmount) .. " changed to " .. tostring(ftyWData.initialAmount))
														
														ttyWData.initialAmount = ftyWData.initialAmount
														--HOOK.writeDebugDetail(ModuleName .. ": whFixer: weapon updated")
														break
													end
												end

											end
										end


										HOOK.writeDebugDetail(ModuleName .. ": whFixer: weapon fixed")
									else
										tbData.weapons = {}
										HOOK.writeDebugDetail(ModuleName .. ": whFixer: weapon fixed: unlimited")
									end
								end
							end
						end
					end
				end
			end

			HOOK.writeDebugDetail(ModuleName .. ": whFixer: toTbl updated")

			--warehouses
			local wrhsName = lfs.writedir() .. "DSMC/warehouses"
			local w_outFile = io.open(wrhsName, "w");
			local newWrhsStr = UTIL.Integratedserialize('warehouses', toTbl);
			w_outFile:write(newWrhsStr);
			io.close(w_outFile);
	
			HOOK.writeDebugDetail(ModuleName .. ": whFixer: fixedWH wrote")			
		end
		

	else
		HOOK.writeDebugDetail(ModuleName .. ": whFixer: files missing!")
	end
end

function whZeroer(path) --  FUNZIA
	-- this function is done to set every warehouses to: 
	-- airbase: 0 aircraft, 0 weapons, 0 fuel & standard 60 mins - 20 m/s - 99% ops level  - 100 ton values
	-- farp: 0 aircraft, 0 weapons, 0 fuel & standard 1 mins - 1000 m/s - 99% ops level  - 100 ton values 
	-- works similar to whFixer but needs only 1 file named zerowh.lua
	-- in the zerowh.lua at least ONE base must be set with NOT unlimited aircraft/weapons


	if fileExist(path) then
		local zeroTbl = nil
		local whEnv = {}

		local zero = io.open(path, 'r')
		local zeroStr = ""

		if zero then 
			zeroStr = zero:read('*all')
			if zeroStr then
				local zeroFun = loadstring(zeroStr)
				setfenv(zeroFun, whEnv)
				zeroFun()
				if whEnv.warehouses then
					zeroTbl = whEnv.warehouses
					HOOK.writeDebugDetail(ModuleName .. ": whZeroer: found zeroTbl warehouse file")
				end
			end
			zero:close()
		end

		whEnv = nil

		if zeroTbl then
			HOOK.writeDebugDetail(ModuleName .. ": whZeroer: found zero table, proceeding fix overwrites")
			local foundAlimitedBase = false
			local baseTblAcf = nil
			local baseTblWpn = nil

			for ztId, ztData in pairs(zeroTbl) do			
				if ztId == "airports" then
					for zbId, zbData in pairs(ztData) do
						if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false then
							foundAlimitedBase = true
							baseTblAcf = zbData.aircrafts
							baseTblWpn = zbData.weapons
							HOOK.writeDebugDetail(ModuleName .. ": whZeroer: found limited base")
							for wId, wData in pairs(baseTblWpn) do
								wData.initialAmount = 0
							end
							for aTy, aTyData in pairs(baseTblAcf) do
								for aId, aData in pairs(aTyData) do
									aData.initialAmount = 0
								end
							end	
							HOOK.writeDebugDetail(ModuleName .. ": whZeroer: baseTblWpn & baseTblAcf zeroed")													
							break
						end
					end
				end
			end
			
			if foundAlimitedBase == true and baseTblAcf and baseTblWpn then

				--zeroing warehouse
				for ztId, ztData in pairs(zeroTbl) do			
					if ztId == "warehouses" then				
						for zbId, zbData in pairs(ztData) do

							zbData.unlimitedFuel = false
							zbData.unlimitedMunitions = false
							zbData.unlimitedAircrafts = false

							zbData.gasoline.InitFuel = 0
							zbData.methanol_mixture.InitFuel = 0
							zbData.jet_fuel.InitFuel = 0
							zbData.diesel.InitFuel = 0

							zbData.OperatingLevel_Air = 99
							zbData.OperatingLevel_Eqp = 99
							zbData.OperatingLevel_Fuel = 99
							zbData.speed = 1000
							zbData.size = 100
							zbData.periodicity = 1

							zbData.aircrafts = baseTblAcf
							zbData.weapons = baseTblWpn
						end
					else
						for zbId, zbData in pairs(ztData) do

							zbData.unlimitedFuel = false
							zbData.unlimitedMunitions = false
							zbData.unlimitedAircrafts = false

							zbData.gasoline.InitFuel = 0
							zbData.methanol_mixture.InitFuel = 0
							zbData.jet_fuel.InitFuel = 0
							zbData.diesel.InitFuel = 0

							zbData.OperatingLevel_Air = 99
							zbData.OperatingLevel_Eqp = 99
							zbData.OperatingLevel_Fuel = 99
							zbData.speed = 20
							zbData.size = 100
							zbData.periodicity = 60

							zbData.aircrafts = baseTblAcf
							zbData.weapons = baseTblWpn
						end						
					end
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": whZeroer: no limited base found")
			end
			HOOK.writeDebugDetail(ModuleName .. ": whZeroer: zeroTbl updated")

			--warehouses
			local wrhsName = lfs.writedir() .. "DSMC/warehouses"
			local w_outFile = io.open(wrhsName, "w");
			local newWrhsStr = UTIL.Integratedserialize('warehouses', zeroTbl);
			w_outFile:write(newWrhsStr);
			io.close(w_outFile);
	
			HOOK.writeDebugDetail(ModuleName .. ": whZeroer: whZeroed wrote")			
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": whZeroer: files missing!")
	end
end

function whUnlimitedRemover(path) --  FUNZIA
	-- this function is done to set every warehouses to: 
	-- airbase: 0 aircraft, 0 weapons, 0 fuel & standard 60 mins - 20 m/s - 99% ops level  - 100 ton values
	-- farp: 0 aircraft, 0 weapons, 0 fuel & standard 1 mins - 1000 m/s - 99% ops level  - 100 ton values 
	-- works similar to whFixer but needs only 1 file named zerowh.lua
	-- in the zerowh.lua at least ONE base must be set with NOT unlimited aircraft/weapons


	if fileExist(path) then
		local zeroTbl = nil
		local whEnv = {}

		local zero = io.open(path, 'r')
		local zeroStr = ""

		if zero then 
			zeroStr = zero:read('*all')
			if zeroStr then
				local zeroFun = loadstring(zeroStr)
				setfenv(zeroFun, whEnv)
				zeroFun()
				if whEnv.warehouses then
					zeroTbl = whEnv.warehouses
					HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: found zeroTbl warehouse file")
				end
			end
			zero:close()
		end

		whEnv = nil

		if zeroTbl then
			HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: found zero table, proceeding fix overwrites")
			local foundAlimitedBase = false
			local baseTblAcf = nil
			local baseTblWpn = nil

			for ztId, ztData in pairs(zeroTbl) do			
				if ztId == "airports" then
					for zbId, zbData in pairs(ztData) do
						if zbData.unlimitedMunitions == false and zbData.unlimitedAircrafts == false then
							foundAlimitedBase = true
							baseTblAcf = zbData.aircrafts
							baseTblWpn = zbData.weapons
							HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: found limited base")
							for wId, wData in pairs(baseTblWpn) do
								wData.initialAmount = 0
							end
							for aTy, aTyData in pairs(baseTblAcf) do
								for aId, aData in pairs(aTyData) do
									aData.initialAmount = 0
								end
							end	
							HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: baseTblWpn & baseTblAcf zeroed")													
							break
						end
					end
				end
			end
			
			if foundAlimitedBase == true and baseTblAcf and baseTblWpn then

				--zeroing warehouse
				for ztId, ztData in pairs(zeroTbl) do			
					if ztId == "warehouses" then				
						for zbId, zbData in pairs(ztData) do
							if zbData.unlimitedFuel == true then
								zbData.unlimitedFuel = false
								zbData.gasoline.InitFuel = 0
								zbData.methanol_mixture.InitFuel = 0
								zbData.jet_fuel.InitFuel = 0
								zbData.diesel.InitFuel = 0
								HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroed fuel base Id " .. tostring(zbId))
							end

							if zbData.unlimitedAircrafts == true then
								zbData.unlimitedAircrafts = false
								zbData.aircrafts = baseTblAcf
								HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroed acf base Id " .. tostring(zbId))
							end

							if zbData.unlimitedMunitions == true then
								zbData.unlimitedMunitions = false
								zbData.weapons = baseTblWpn
								HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroed wpn base Id " .. tostring(zbId))
							end

							zbData.OperatingLevel_Air = 1
							zbData.OperatingLevel_Eqp = 1
							zbData.OperatingLevel_Fuel = 1
							zbData.speed = 1
							zbData.size = 1
							zbData.periodicity = 1000

						end
					else
						for zbId, zbData in pairs(ztData) do

							if zbData.unlimitedFuel == true then
								zbData.unlimitedFuel = false
								zbData.gasoline.InitFuel = 0
								zbData.methanol_mixture.InitFuel = 0
								zbData.jet_fuel.InitFuel = 0
								zbData.diesel.InitFuel = 0
								HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroed fuel base Id " .. tostring(zbId))
							end

							if zbData.unlimitedAircrafts == true then
								zbData.unlimitedAircrafts = false
								zbData.aircrafts = baseTblAcf
								HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroed acf base Id " .. tostring(zbId))
							end

							if zbData.unlimitedMunitions == true then
								zbData.unlimitedMunitions = false
								zbData.weapons = baseTblWpn
								HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroed wpn base Id " .. tostring(zbId))
							end

							zbData.OperatingLevel_Air = 1
							zbData.OperatingLevel_Eqp = 1
							zbData.OperatingLevel_Fuel = 1
							zbData.speed = 1
							zbData.size = 1
							zbData.periodicity = 1000

						end						
					end
				end
			else
				HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: no limited base found")
			end
			HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: zeroTbl updated")

			--warehouses
			local wrhsName = lfs.writedir() .. "DSMC/warehouses"
			local w_outFile = io.open(wrhsName, "w");
			local newWrhsStr = UTIL.Integratedserialize('warehouses', zeroTbl);
			w_outFile:write(newWrhsStr);
			io.close(w_outFile);
	
			HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: whZeroed wrote")			
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": whUnlimitedRemover: files missing!")
	end
end

function whCleaner(path1, path2)
	whZeroer(path1)
	whFixer(lfs.writedir() .. "DSMC/from.lua", lfs.writedir() .. "DSMC/warehouses")
end
