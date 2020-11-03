airbaseFuelIndex = {}
fuelTest = {}
function fuelTest:onEvent(event)	
	if event.id == world.event.S_EVENT_BIRTH then -- 18	
		if event.initiator then
			local fuel = event.initiator:getFuel()
			if fuel then
				if fuel == 0 then
					local obj_pos = event.initiator:getPosition().p
					local obj_coa = event.initiator:getCoalition()
					local obj_type = event.initiator:getTypeName()
					local airbases = coalition.getAirbases(obj_coa)

					env.info(("EMBD.fuelTest removing object: " .. tostring(obj_type)))

					local distance_func = function(point1, point2)
						local xUnit = point1.x
						local yUnit = point1.z
						local xZone = point2.x
						local yZone = point2.z
						local xDiff = xUnit - xZone
						local yDiff = yUnit - yZone
						return math.sqrt(xDiff * xDiff + yDiff * yDiff)
					end


					if obj_pos and obj_coa and airbases then
						local nName = nil
						local nDist = 1000000000
						
						for id, data in pairs(airbases) do
							local afb_pos = data:getPosition().p
							if afb_pos then
								local d = distance_func(afb_pos, obj_pos)
								local n = data:getName()
								if d and n then
									if d < nDist then
										nDist = d
										nName = n
									end
								end
							end
						end

						if nName then
							env.info(("EMBD.fuelTest setting airbase not usable: " .. tostring(nName)))
							airbaseFuelIndex[nName] = true
						end
					end
					event.initiator:destroy()
				end
			end
		end
	end
end
world.addEventHandler(fuelTest)