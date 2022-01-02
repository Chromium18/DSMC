-- Dynamic Sequential Mission Campaign -- GOAP planning module

local ModuleName  	= "GOAP"
local MainVersion 	= HOOK.DSMC_MainVersion
local SubVersion 	= HOOK.DSMC_SubVersion
local Build 		= HOOK.DSMC_Build
local Date			= HOOK.DSMC_Date

--## LIBS
local base 			= _G
module('GOAP', package.seeall)	

HOOK.writeDebugDetail(ModuleName .. ": local required loaded")

-- ## plan variables
local inAreaRadius				= 15000 -- m
local maxShellDistance			= 20000 -- m
local minShellDistance			= 3000 -- m
local maxRelocateDistance		= 150000 -- m
local minRelocateDistance		= 15000 -- m
local inTownRadius				= 5000 -- m

-- # CHECK WSM STATES

-- return true/false + table of forces
function check_forcesInArea(Coa, terr, variable, radius, min_radius) -- radius & category are optional, if nil goes to global variables for area and fighting vehicles as Ranged, Tank, Armored or Movers.
	--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea c1")
	if Coa and terr then

		if type(Coa) == "number" and type(terr) == "table" then
			
			local forces = {}
			local found = false 

			if not radius then
				radius = inAreaRadius
			end

			-- identify terr information type
			local dest_pos = nil
			if terr.pos then
				dest_pos = terr.pos
			elseif terr.x and terr.y and terr.z then
				dest_pos = terr
			end

			if dest_pos then
				for _, gData in pairs(tblORBATDb) do
					if gData.plan == false then
						if gData.coa == Coa then
							--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea checking group: " .. tostring(gData.id))
							
							local dist = PLAN.getDist(gData.pos, dest_pos)

							local validated = false
							if min_radius then
								if dist < radius and dist > min_radius then
									validated = true
								end
							elseif dist < radius then
								validated = true
							end

							--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea validated: " .. tostring(validated))

							if validated then
								if variable then -- category!
									
									--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea radius variable checked")

									local catFound = false
									for _, cat in pairs(gData.attributes) do
										if cat == variable then
											found = true
											catFound = true											
										end
									end

									if catFound == true then
										forces[#forces+1] = {grp = gData.id, str = gData.strenght, dist = dist}
										--gData.plan = true
									end

								else
									--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea radius variable gData.strenght: " .. tostring(gData.strenght))
									if gData.strenght > 0 then
										found = true
										forces[#forces+1] = {grp = gData.id, str = gData.strenght, dist = dist}
										--gData.plan = true
									end

								end
							end
						end
					end
				end
			end

			--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea results found: " .. tostring(found))
			if found then
				--HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea results #forces: " .. tostring(#forces))
			end
			return found, forces

		else
			HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea wrong type variables")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": check_forcesInArea missing variables")
	end
end

-- return true/false + table of forces
function check_enemiesInArea(Coa, terr, variable, radius, min_radius) -- radius & category are optional, if nil goes to global variables for area and fighting vehicles as Ranged, Tank, Armored or Movers.
	--HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea c1")
	if Coa and terr then

		if type(Coa) == "number" and type(terr) == "table" then
			
			local forces = {}
			local found = false 

			if not radius then
				radius = inAreaRadius
			end

			-- identify terr information type
			local dest_pos = nil
			if terr.pos then
				dest_pos = terr.pos
			elseif terr.x and terr.y and terr.z then
				dest_pos = terr
			end

			if dest_pos then
				for _, gData in pairs(tblORBATDb) do
					if gData.coa ~= Coa then
						--HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea checking group: " .. tostring(gData.id))
						
						local dist = PLAN.getDist(gData.pos, dest_pos)

						local validated = false
						if min_radius then
							if dist < radius and dist > min_radius then
								validated = true
							end
						elseif dist < radius then
							validated = true
						end

						if validated then
							if variable then -- category!
								
								--HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea radius variable checked")

								local catFound = false
								for _, cat in pairs(gData.attributes) do
									if cat == variable then
										found = true
										catFound = true											
									end
								end

								if catFound == true then
									forces[#forces+1] = {grp = gData.id, str = gData.strenght, dist = dist}
									--gData.plan = true
								end

							else

								if gData.strenght > 0 then
									forces[#forces+1] = {grp = gData.id, str = gData.strenght, dist = dist}
									--gData.plan = true
								end

							end
						end
					end
				end
			end

			--HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea results found: " .. tostring(found))
			if found == true then
				--HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea results #forces: " .. tostring(#forces))
			end
			return found, forces

		else
			HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea wrong type variables")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": check_enemiesInArea missing variables")
	end
end

-- this function verify enemy forces within radius range
-- return true/false The coa is the coalition of the "allied" forces
function check_allyAbsent(Coa, terr, variable, radius) -- terr now is assumed as "data" in objective table
	if Coa and terr then
		if type(Coa) == "number" and type(terr) == "table" then
			

			-- if radius not specified, use default
			if not radius then
				radius = inTownRadius
			end

			if terr.pos then
				for _, gData in pairs(tblORBATDb) do
					if gData.coa == Coa then
						local dist = PLAN.getDist(gData.pos, terr.pos)
						if dist < radius then

							if gData.strenght and gData.strenght > 0 then
								return false
								--gData.plan = true
							end

						end
					end
				end
			end			

			return true

		else
			HOOK.writeDebugDetail(ModuleName .. ": check_allyAbsent wrong type variables")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": check_allyAbsent missing variables")
	end
end

-- this function verify enemy forces within radius range
-- return true/false The coa is the coalition of the "allied" forces
function check_enemyAbsent(Coa, terr, variable, radius) -- terr now is assumed as "data" in objective table
	if Coa and terr then
		if type(Coa) == "number" and type(terr) == "table" then
			

			-- if radius not specified, use default
			if not radius then
				radius = inTownRadius
			end

			if terr.pos then
				for _, gData in pairs(tblORBATDb) do
					if gData.coa ~= Coa then
						local dist = PLAN.getDist(gData.pos, terr.pos)
						if dist < radius then

							if gData.strenght > 0 then
								return false
								--gData.plan = true
							end

						end
					end
				end
			end			

			return true

		else
			HOOK.writeDebugDetail(ModuleName .. ": check_enemyAbsent wrong type variables")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": check_enemyAbsent missing variables")
	end
end

-- return true/false + table of enemies. The coa is the coalition of the "allied" forces
function check_enemyPresent(Coa, terr, variable, radius)
	if Coa and terr then
		if type(Coa) == "number" and type(terr) == "table" then
			
			local forces = {}
			local found = false

			-- if radius not specified, use default
			if not radius then
				radius = inTownRadius
			end

			if terr.pos then
				for _, gData in pairs(tblORBATDb) do
					if gData.coa ~= Coa then
						local dist = PLAN.getDist(gData.pos, terr.pos)
						if dist < radius then
							if gData.strenght > 0 then
								return true
								--gData.plan = true
							end

						end
					end
				end
			end		

			return false

		else
			HOOK.writeDebugDetail(ModuleName .. ": check_enemyPresent wrong type variables")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": check_enemyPresent missing variables")
	end
end

-- this function verify ownership of a territory
-- return true/false
function check_verifyOwnership(Coa, terr, variable) -- THIS
	if terr and Coa and type(Coa) == "number" then
		--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership started")
		local terrTbl = nil
		if type(terr) == "string" then
			--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership terr is a string")
			for _, tData in pairs(tblTerrainDb.towns) do
				if terr == tData.display_name then
					--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership found terrain data")
					terrTbl = tData
				end
			end
		elseif type(terr) == "table" then
			--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership terr is a table")
			terrTbl = terr
		end

		if terrTbl then
			if Coa == terrTbl.owner then
				--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, return true")
				return true
			else
				--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, return false: Coa = " ..tostring(Coa) .. ", owner = " .. tostring(terrTbl.owner))
				return false
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, return false: terrTbl not found!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, missing variables or wrong Coa")
	end
end

-- this function verify allied forces available for relocation
-- return true/false + table of forces
function check_availableForRelocate(Coa, terr, variable, radius, min_radius)
	if Coa and terr then
		if type(Coa) == "number" and type(terr) == "table" then
			
			local forces = {}
			local found = false

			--identify nearest territory
			--local nearestTerritoryPos = nil
			local nearestDist = 500000
			local nearest = nil
			for pId, pData in pairs(terr.proxy) do
				if Coa == pData.owner then
					if pData.distance < nearestDist then
						nearestDist = pData.distance
						--nearestTerritoryPos = pData.pos
						nearest = pData
						--HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate found allied proxy: " .. tostring(pData.name))
					end
				end
			end

			if nearest then
				--HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate nearest territory: " .. tostring(nearest.name))
				-- if radius not specified, use default
				if not radius then
					radius = maxRelocateDistance
				end

				if not min_radius then
					min_radius = minRelocateDistance
				end

				--HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate radius: " .. tostring(radius))
				--HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate min_radius: " .. tostring(min_radius))

				found, forces = check_forcesInArea(Coa, nearest, variable, radius, min_radius)

			else
				HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate unable to find allied territory in proxies")
			end

			--HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate found: " .. tostring(found))
			return found, forces

		else
			HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate wrong type variables")
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": check_availableForRelocate missing variables")
	end
end

function check_BattleCost(Coa, terr)
	if Coa and terr then
		if type(Coa) == "number" and type(terr) == "table" then

			-- ## ALLIED ##

			local a_tbl = {}
			local a_str = 0

			-- evaluate territory
			local x, a = check_forcesInArea(Coa, terr)
			if a  then -- and #a > 0
				for gId, gData in pairs(a) do
					if gData.str and gData.str > 0 then
						a_tbl[#a_tbl+1] = gData
						a_str = a_str + gData.str
					end
				end
			end	
			
			if a_tbl then
				--HOOK.writeDebugDetail(ModuleName .. ": check_BattleCost allied in area: strenght = " .. tostring(a_str)) --  .. ",  groups = " .. tostring(#a_tbl)
			end

			-- evaluate proxies
			for pId, pData in pairs(terr.proxy) do
				if Coa == pData.owner then
					local y, f = check_forcesInArea(Coa, pData)
					if f  then -- and #f > 0
						for gId, gData in pairs(f) do
							if gData.str and gData.str > 0 then
								-- check already there
								local addOk = true
								for aId, aData in pairs(a_tbl) do
									if aData.grp == gData.grp then
										addOk = false
									end
								end

								if addOk then
									a_tbl[#a_tbl+1] = gData
									a_str = a_str + gData.str
								end
							end
						end
					end
				end
			end

			if a_tbl then
				--HOOK.writeDebugDetail(ModuleName .. ": check_BattleCost allied total: strenght = " .. tostring(a_str)) --  .. ",  groups = " .. tostring(#a_tbl)
			end

			-- ## ENEMY ##

			local e_tbl = {}
			local e_str = 0

			-- evaluate territory
			local z, e = check_enemiesInArea(Coa, terr)
			--HOOK.writeDebugDetail(ModuleName .. ": check_BattleCost enemy data gathered")
			if e then
				--HOOK.writeDebugDetail(ModuleName .. ": check_BattleCost e exist")
				for _, eData in pairs(e) do
					if eData and eData.str and eData.str > 0 then
						e_tbl[#e_tbl+1] = eData
						e_str = e_str + eData.str
					end
				end
			end		

			if e_tbl then
				--HOOK.writeDebugDetail(ModuleName .. ": check_BattleCost enemy total: strenght = " .. tostring(e_str)) --  .. ",  groups = " .. tostring(#e_tbl)
			end

			-- ## MATH ##
			if a_str == 0 then
				return false, 100
			elseif e_str == 0 then
				return true, 0
			elseif e_str > 0 and a_str > 0 then
				if e_str > a_str then
					return false, 100				
				else
					local cost = a_str/(a_str/e_str)
					return true, cost
				end

			end
		end
	end
end

-- this function verify ownership of a territory
-- return true/false
function check_verifyOwnership(Coa, terr, variable) -- THIS
	if terr and Coa and type(Coa) == "number" then
		--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership started")
		local terrTbl = nil
		if type(terr) == "string" then
			--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership terr is a string")
			for _, tData in pairs(tblTerrainDb.towns) do
				if terr == tData.display_name then
					--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership found terrain data")
					terrTbl = tData
				end
			end
		elseif type(terr) == "table" then
			--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership terr is a table")
			terrTbl = terr
		end

		if terrTbl then
			if Coa == terrTbl.owner then
				--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, return true")
				return true
			else
				--HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, return false: Coa = " ..tostring(Coa) .. ", owner = " .. tostring(terrTbl.owner))
				return false
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, return false: terrTbl not found!")
			return false
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": check_verifyOwnership, missing variables or wrong Coa")
	end
end

-- this function verify allied forces available for relocation
-- return true/false + table of forces
function check_acf_available(Coa, terr, variable, radius) -- variable is the aircraft type
	return true
end


-- ############# GOAP GROUND PLANNING #############

-- world state table
--
local tblWS = {
	[1] = {
		keyValue = "ownTerritory",
		evalFunction = check_verifyOwnership,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},
	[2] = {
		keyValue = "availableForRelocate",
		evalFunction = check_availableForRelocate,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},
	[3] = {
		keyValue = "forcesInArea",
		evalFunction = check_forcesInArea,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},
	[4] = {
		keyValue = "enemyAbsent",
		evalFunction = check_enemyAbsent,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},	
	[5] = {
		keyValue = "enemyPresent",
		evalFunction = check_enemyPresent,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},
	[6] = {
		keyValue = "artyInArea",
		evalFunction = check_forcesInArea,
		evalVariable = "Arty",
		evalRadius_max = nil,
		evalRadius_min = nil,
	},
	[7] = {
		keyValue = "attack_acf_available",
		evalFunction = check_acf_available,
		evalVariable = "Ground Attack", -- this is to filter aicraft type by available DCS tasking, not for task itself!!
	},
	[8] = {
		keyValue = "positiveCost",
		evalFunction = check_BattleCost,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},
	[9] = {
		keyValue = "allyGuarding",
		evalFunction = check_forcesInArea,
		evalVariable = nil,
		evalRadius_max = inTownRadius,
		evalRadius_min = nil, 
	},
	[10] = {
		keyValue = "allyAbsent",
		evalFunction = check_allyAbsent,
		evalVariable = nil,
		evalRadius_max = nil,
		evalRadius_min = nil,
	},



	
}
--]]--


-- actions table
tblActions = {}


-- ############### CLASS ACTION ############################

Action = {}
Action.__index = Action

function Action:create(v)

	--[[
	It serves as an example of how an Action should be structured to work with a Planning Algorithm

	Properties
	preconditions - Conditions to be achieved before the action can run. Each precondition must be presented in the following structure: {key:string, value: boolean} 
	effects - effects caused by the action. Each effect must be presented in the following structure: {key:string, value: boolean} 
	cost - Action Execution Cost
	parent - the object who cast this action
	target - the action who the action is cast into

	Methods
	addEffect - Inserts an effect in the effect list, must be cast in the constructor of child classes
	addPrecondition - Inserts a precondition in the preconditions list, must be cast in the constructor of child classes
	isDone - Tells if the action is over
	Run - Executes the Action
	contextCheck - Checks advanced things
	simbolicCheck - Checks basic things, simulation method

	NOT IMPLEMENTED removeEffect - Remove an effect from the effect list
	NOT IMPLEMENTED removePrecondition - Removes a precondition from preconditions list
	NOT IMPLEMENTED reset - Resets all properties
	--]]--

	local t = {
		preconditions = {},
		effects = {},
		cost = 1,
		parent = nil,
		target = nil,
		done = false,
		name = "none"
	}

	setmetatable(t, self)
	tblActions[#tblActions+1] = self

	return t
end

function Action:Run()
end

function Action:addPrecondition(o)
	--HOOK.writeDebugDetail(ModuleName .. ": Action addPrecondition s0")
	self.preconditions[#self.preconditions+1] = o -- o.keyValue
	--HOOK.writeDebugDetail(ModuleName .. ": Action addPrecondition s1")
end

function Action:addEffect(o)
	--HOOK.writeDebugDetail(ModuleName .. ": Action addEffect s0")
	self.effects[#self.effects+1] = o -- o.keyValue
	--HOOK.writeDebugDetail(ModuleName .. ": Action addEffect s1")
end


-- ############### GOAPNER CODE #############

Planner = {}
Planner.__index = Planner

-- Initiatin functions
function Planner:create(t, c, g)

	--reset
	self.objective = nil
	self.actions = nil
	self.plans = nil
	--self.objective
	--self.objective
	--UTIL.dumpTable("GOAP.P.init.lua" , self)

	-- init self structure
	self.objective = {
		id = t,
		coa = c,
		--descriptors = w,
		goal = "",
	}
	HOOK.writeDebugDetail(ModuleName .. ": Planner create, basic data set, coalition: " .. tostring(self.objective.coa) .. ", objective: " .. tostring(self.objective.id))

	-- add territory data
	self.objective.data = PLAN.townTableCheck(self.objective.id)
	HOOK.writeDebugDetail(ModuleName .. ": Planner create, territory data added")

	if self.objective.data then
		-- set default goal if missing
		if self.objective.data.owner == c then
			self.objective.goal = "allyGuarding"
			--self.goal = "guardTerritory"
		else
			self.objective.goal = "ownTerritory"
			--self.goal = "ownTerritory"
		end
		
		-- set goal if specified
		if g and type(g) == "string" then
			for _, wData in pairs(tblWS) do
				if wData.keyValue == g then
					HOOK.writeDebugDetail(ModuleName .. ": Planner create, different goal set: " .. tostring(g))
					self.objective.goal = g
					--self.goal = g
				end
			end
		end

		if self.objective ~= true and self.objective ~= false then
			HOOK.writeDebugDetail(ModuleName .. ": Planner create, objective exist: " .. tostring(self.objective.goal))

			self.actions = {}
			self:initActions(self.actions)
			
			--setmetatable(self, Planner)
			HOOK.writeDebugDetail(ModuleName .. ": Planner create, done")

			self:doPlan()

			UTIL.dumpTable("GOAP.P_" .. tostring(self.objective.id) .. ".lua" , self.plans)
			setmetatable(self, Planner)
			
			return self

		else
			HOOK.writeDebugDetail(ModuleName .. ": Planner create, objective does not exist, is " .. tostring(self.objective))
			return self.objective
		end
	else
		HOOK.writeDebugBase(ModuleName .. ": Planner create, unable to get objective data, return false")
		return false
	end
end

function Planner:initActions(tbl)

	HOOK.writeDebugDetail(ModuleName .. ": Planner.initActions...")
	-- sobstitute with tblActions entries?

	--
	attackTerritory:Init(tbl)
	relocateForces:Init(tbl)
	shellTerritory:Init(tbl)	
	relocateArty:Init(tbl)
	guardTerritory:Init(tbl)
	--]]--

	HOOK.writeDebugDetail(ModuleName .. ": Planner.initActions done")
	--UTIL.dumpTable("GOAP.initActions_tbl.lua" , tbl)
	return self
end

-- Utils functions
function Planner:checkState(s) -- return true if world state is verified
	for _, wData in pairs(tblWS) do
		if s == wData.keyValue then
			--HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, checkState vars: coa " .. tostring(self.objective.coa) .. ", data " .. tostring(self.objective.data))
			local check = wData.evalFunction(self.objective.coa, self.objective.data, wData.evalVariable, wData.evalRadius_max, wData.evalRadius_min)
			HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, checkState for " .. tostring(wData.keyValue) .. " is " .. tostring(check))
			if not check then
				check = false
			end
			return check
		end
	end		
end

function Planner:getPreconditions(a) -- return preconditions array of that specific action
	for _, aData in pairs(self.actions) do
		if aData.name == a then
			if aData.preconditions and #aData.preconditions > 0 then				
				HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, getPreconditions for " .. tostring(a) .. " found")
				return aData.preconditions
			end
		end
	end
	HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, getPreconditions for " .. tostring(a) .. " not found")
	return nil
end

function Planner:checkAction(a) -- returns true if all preconditions'states are already verified, or an array of precondition if not
	-- verify state of action precoditions
	local p = self:getPreconditions(a)
	if p and #p > 0 then
		for pId, pData in pairs(p) do
			local v = self:checkState(pData.keyValue)
			if v then
				p[pId] = nil
			end
		end

		--rebuilt p
		local r = {}
		for pId, pData in pairs(p) do
			r[#r+1] = pData
		end

		if #r > 0 then
			HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, checkAction for " .. tostring(a) .. " not verified preconditions: " .. tostring(#r))
			return r
		else
			HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, checkAction for " .. tostring(a) .. " all preconditions verified")
			return true
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, checkAction for " .. tostring(a) .. " failed to retrieve preconditions")
	end
end

function Planner:getActions(g) -- return actions array with actions names
	
	-- aPool is an array of valid actions to obtain effect g
	local aPool = {}
	for aId, aData in pairs(self.actions) do
		--UTIL.dumpTable("GOAP.self.actions.lua" , self.actions)
		if aData.effects then
			for eId, eData in pairs(aData.effects) do
				if eData.keyValue == g then
					HOOK.writeDebugDetail(ModuleName .. ": Planner getActions for " .. tostring(g) .. " found: " .. tostring(aData.name) .. ", eId: " .. tostring(eId))
					aPool[#aPool+1] = {name = aData.name, conditions = aData.preconditions}
				end
			end
		end
	end

	return aPool

	--[[
	-- now checking if actions are already doable or if it requires further steps
	if aPool and #aPool > 0 then
		HOOK.writeDebugDetail(ModuleName .. ": Planner getActions, found " .. tostring(#aPool) .. " valid actions for " .. tostring(g))
		for _, aData in pairs(aPool) do
			local v = self:checkAction(aData.n)
			if type(v) == "table" then
				HOOK.writeDebugDetail(ModuleName .. ": Planner getActions, missing " .. tostring(#v) .. " precondition for  " .. tostring(aData.n))
				aData.ready = false
				aData.conditions = v 
			elseif v == true then
				HOOK.writeDebugDetail(ModuleName .. ": Planner getActions, all precondition are in place for  " .. tostring(aData.n))
				aData.ready = true
			end
		end
		return aPool

	else
		HOOK.writeDebugDetail(ModuleName .. ": Planner getActions for " .. tostring(g) .. " no valid actions found")
	end
	--]]--
end

-- planner function
function Planner:doPlan()
	--local t = self
	local outcome = "no outcome identified"
	if self then
		if self.objective and self.objective.id and self.objective.coa and self.objective.goal then
			if type(self.objective.id) == "string" and type(self.objective.coa) == "number"  and type(self.objective.goal) == "string" then
				HOOK.writeDebugDetail(ModuleName .. ": Planner doPlan: creating net...")
				--local nodes = self:createNodes(self.objective.goal)
				--HOOK.writeDebugDetail(ModuleName .. ": Planner nodes done, #nodes: " .. tostring(#nodes))

				self:buildNet(self.objective.goal)
				HOOK.writeDebugDetail(ModuleName .. ": Planner doPlan: process finished")

			else
				HOOK.writeDebugDetail(ModuleName .. ": Planner doPlan: objective id or coa are wrong format")
				outcome = "error"
				return false, outcome
			end
		else
			HOOK.writeDebugDetail(ModuleName .. ": Planner doPlan: objective is missing or incomplete")
			outcome = "error"
			return false, outcome	
		end

	else
		HOOK.writeDebugDetail(ModuleName .. ": Planner doPlan: issue creating t from self")
		outcome = "error"
		return false, outcome
	end
end

-- IL COSTO DELLE AZIONI DEVE ESSERE < 100 PER ESSERE VALIDO!

function Planner:buildNet(goal)

	-- init first state
	local net = {}
	if goal then
		net.keyValue = goal
		net.done = false
		net.act = {}
		net.steps = 0
		net.cost = 0
		net.dist = 0
	end

	local plans = {}

	HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, basic net added for goal " .. tostring(net.keyValue))

	-- create raw net
	local function doStep(t)
		if t.keyValue then
			local v = self:checkState(t.keyValue)
			if v == true then
				HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, state " .. tostring(t.keyValue) .. " is done")
				t.done = true
				--t.keyValue = nil
				--plans[#plans+1] = t	
			else
				HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, state " .. tostring(t.keyValue) .. " not done")
				t.actions = self:getActions(t.keyValue)
				if t.actions and #t.actions > 0 then
					--UTIL.dumpTable("GOAP.self.lua" , self)
					--UTIL.dumpTable("GOAP.t.actions.lua" , t.actions)
					HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, state " .. tostring(t.keyValue) .. ", found " .. tostring(#t.actions) .. " actions")
					for aId, aData in pairs(t.actions) do
						if aData.conditions then
							
							HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, state " .. tostring(t.keyValue) .. ", calculating cost for " .. tostring(aData.name))
							local cost = 0
							for fId, fData in pairs(self.actions) do
								if fData.name == aData.name then
									--UTIL.dumpTable("GOAP.Plans_self_" .. tostring(aData.name) .. ".lua" , self)
									cost = fData:calculateCost(self)
								end
							end

							HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, state " .. tostring(t.keyValue) .. ", calculating distance for " .. tostring(aData.name))

							local dist = 0
							for fId, fData in pairs(self.actions) do
								if fData.name == aData.name then
									--UTIL.dumpTable("GOAP.Plans_self_" .. tostring(aData.name) .. ".lua" , self)
									dist = fData:calculateDist(self)
								end
							end

							HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, state " .. tostring(t.keyValue) .. ", needed conditions for  " .. tostring(aData.name) .. ": " .. tostring(#aData.conditions) .. ", action cost: " .. tostring(cost) .. ", action dist: " .. tostring(dist))
							local s = t.steps + 1
							local c = t.cost + cost
							local d = t.dist + dist
							-- do a full condition test check
							local necessaryConds = #aData.conditions
							local verifiedConds = 0
							for cId, cData in pairs(aData.conditions) do
								local v = self:checkState(cData.keyValue)
								if v then
									verifiedConds = verifiedConds + 1
								end
							end

							if verifiedConds == necessaryConds and cost < 100 then
								HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, all conditions verified, plan closed")
								local x = UTIL.deepCopy(t)
								
								x.steps = s
								x.cost = c	
								x.dist = d
								local curAct = UTIL.deepCopy(x.act)
								curAct[#curAct+1] = aData.name
								x.act = curAct
								x.actions = nil
								x.done = nil
								x.keyValue = nil
								plans[#plans+1] = x								
							else
								HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, one or more conditions is not verified")
								-- go for additional cheks
								for cId, cData in pairs(aData.conditions) do
									HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, start checking condition " .. tostring(cData.keyValue))

									local curAct = UTIL.deepCopy(t.act)
									curAct[#curAct+1] = aData.name
									cData.act = curAct

									cData.steps = s
									cData.cost = c
									cData.dist = d

									--HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, launching next step")
									doStep(cData)
								end
							end
						end
					end
				else
					HOOK.writeDebugDetail(ModuleName .. ": Planner buildNet, no actions verify the result")
				end
			end
		end
	end
	doStep(net)

	self.plans = plans

	--UTIL.dumpTable("GOAP.Planner.lua" , self)

end



-- #######################################################################
-- ############################## ACTIONS DB #############################
-- #######################################################################

--------------------------------------------------------------------------------------
--guardTerritory
--------------------------------------------------------------------------------------
--
guardTerritory = Action:create()

function guardTerritory:Launch() -- this is a configuration function that 
	self.name = "guardTerritory"
	
	local p1 = {keyValue = "ownTerritory", done = false}
	local p2 = {keyValue = "enemyAbsent", done = false}
	local p3 = {keyValue = "forcesInArea", done = false}
	self:addPrecondition(p1)
	self:addPrecondition(p2)
	self:addPrecondition(p3)

	local e1 = {keyValue = "allyGuarding", done = false}
	self:addEffect(e1)

end

function guardTerritory:Init(t)
	if t then
		t[#t+1] = self
	end
end

function guardTerritory:calculateCost(s) 
	local c = 100

	local r_true, r_value = check_forcesInArea(s.objective.coa, s.objective.data, nil, 80000, 1000)
	
	if r_value then

		local base_cost = 15
			
		-- some calculations done to average the values of the calculation between 15 and 50 cost
		if #r_value > 5 then
			c = base_cost
		else
			c = base_cost + 10
		end
	end

	return c
end

function guardTerritory:calculateDist(s) 
	--UTIL.dumpTable("GOAP_s.lua", s)
	if s then
		
		local d

		local a_avail, a_table = check_forcesInArea(s.objective.coa, s.objective.data, nil, 80000, 1000)
		--HOOK.writeDebugDetail(ModuleName .. ": guardTerritory: c3")
		if a_table then
			local minDist = 100000
			for fId, fData in pairs(a_table) do
				if fData.dist and type(fData.dist) == "number" then
					if fData.dist < minDist then
						minDist = fData.dist
					end
				end
			end

			if minDist < 100000 then
				d = minDist
			end
		end

		if d then
			return math.floor(d/1000)
		else
			return 100
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": guardTerritory: missing s")
		return nil
	end
end


HOOK.writeDebugDetail(ModuleName .. ": guardTerritory inserted")
--]]--
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--attackTerritory
--------------------------------------------------------------------------------------

attackTerritory = Action:create() 

function attackTerritory:Launch()
	
	self.name = "attackTerritory"

	local p1 = {keyValue = "forcesInArea", done = false}
	local p2 = {keyValue = "positiveCost", done = false}
	self:addPrecondition(p1)
	self:addPrecondition(p2)

	local e1 = {keyValue = "ownTerritory", done = false}
	self:addEffect(e1)

end

function attackTerritory:Init(t)
	if t then
		t[#t+1] = self
	end
end

function attackTerritory:calculateCost(s) 
	--UTIL.dumpTable("GOAP_s.lua", s)
	if s then

		local base_cost = 30
		local v, c = check_BattleCost(s.objective.coa, s.objective.data)
		if c then
			c = c + base_cost
		else
			c = 100
		end

		return c
	else
		HOOK.writeDebugDetail(ModuleName .. ": attackTerritory: missing s")
		return nil
	end
end

function attackTerritory:calculateDist(s) 
	--UTIL.dumpTable("GOAP_s.lua", s)
	if s then
		
		local d

		local a_avail, a_table = check_forcesInArea(s.objective.coa, s.objective.data)
		--HOOK.writeDebugDetail(ModuleName .. ": attackTerritory: c3")
		if a_table then
			local minDist = 100000
			for fId, fData in pairs(a_table) do
				if fData.dist and type(fData.dist) == "number" then
					if fData.dist < minDist then
						minDist = fData.dist
					end
				end
			end

			if minDist < 100000 then
				d = minDist
			end
		end

		if d then
			return math.floor(d/1000)
		else
			return 100
		end
	else
		HOOK.writeDebugDetail(ModuleName .. ": attackTerritory: missing s")
		return nil
	end
end


HOOK.writeDebugDetail(ModuleName .. ": attackTerritory inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--relocateForces
--------------------------------------------------------------------------------------

relocateForces = Action:create() 

function relocateForces:Launch(t)

	self.name = "relocateForces"
	
	local p1 = {keyValue = "availableForRelocate", done = false}
	self:addPrecondition(p1)

	local e1 = {keyValue = "forcesInArea", done = false}
	local e2 = {keyValue = "positiveCost", done = false}
	--local e3 = {keyValue = "guardTerritory", done = false}
	self:addEffect(e1)
	self:addEffect(e2)
	--self:addEffect(e3)

end

function relocateForces:Init(t)
	if t then
		t[#t+1] = self
	end
end

function relocateForces:calculateCost(s) 
	local c = 100

	local r_true, r_value = check_availableForRelocate(s.objective.coa, s.objective.data)
	
	if r_value then

		local base_cost = 10
			
		-- some calculations done to average the values of the calculation between 15 and 50 cost
		if #r_value < 5 then
			c = base_cost + 10
		else
			c = base_cost + 2
		end
	end

	return c

end

function relocateForces:calculateDist(s) 
	--UTIL.dumpTable("GOAP_s.lua", s)
	if s then
		
		local d

		local a_avail, a_table = check_availableForRelocate(s.objective.coa, s.objective.data)
		if a_table then
			local minDist = 100000
			for fId, fData in pairs(a_table) do
				if fData.dist and type(fData.dist) == "number" then
					if fData.dist < minDist then
						minDist = fData.dist
					end
				end
			end
	
			if minDist < 100000 then
				d = minDist
			end
		end
	
		if d then
			return math.floor(d/1000)
		else
			return 100
		end
	end
end


HOOK.writeDebugDetail(ModuleName .. ": relocateForces inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--shellTerritory
--------------------------------------------------------------------------------------

shellTerritory = Action:create()

function shellTerritory:Launch(t)

	self.name = "shellTerritory"
	
	local p1 = {keyValue = "artyInArea", done = false}
	local p2 = {keyValue = "enemyPresent", done = false}
	self:addPrecondition(p1)
	self:addPrecondition(p2)

	local e1 = {keyValue = "enemyAbsent", done = false}
	local e2 = {keyValue = "positiveCost", done = false}
	self:addEffect(e1)
	self:addEffect(e2)

end

function shellTerritory:Init(t)
	if t then
		t[#t+1] = self
	end
end

function shellTerritory:calculateCost(s) 
	--UTIL.dumpTable("GOAP_s.lua", s)
	if s then
		--HOOK.writeDebugDetail(ModuleName .. ": attackTerritory: c1")
		local c = 100
		--HOOK.writeDebugDetail(ModuleName .. ": attackTerritory: c1b")

		local r_true, r_table = check_forcesInArea(s.objective.coa, s.objective.data, "Arty", maxShellDistance, minShellDistance)
		if r_table and #r_table > 0 then
			
			local r_value = #r_table
			
			-- forces[#forces+1] = {grp = gData.id, str = gData.strenght, dist = dist}

			local base_cost = 5
			
			-- some calculations done to average the values of the calculation between 15 and 50 cost
			c = base_cost+20/r_value
		end

		return c
	else
		HOOK.writeDebugDetail(ModuleName .. ": attackTerritory: missing s")
		return nil
	end
end

function shellTerritory:calculateDist(s) 
	if s then
		local d
		local r_true, r_value = check_forcesInArea(s.objective.coa, s.objective.data, "Arty", maxShellDistance, minShellDistance)

		if r_true then
			d = 0
		else
			d = 100
		end

		return d
	end
end


HOOK.writeDebugDetail(ModuleName .. ": shellTerritory inserted")
--------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------
--relocateArty
--------------------------------------------------------------------------------------

relocateArty = Action:create() 

function relocateArty:Launch(t)

	self.name = "relocateArty"
	
	local p1 = {keyValue = "availableForRelocate", done = false}
	self:addPrecondition(p1)

	local e1 = {keyValue = "artyInArea", done = false}
	self:addEffect(e1)

end

function relocateArty:Init(t)
	if t then
		t[#t+1] = self
	end
end

function relocateArty:calculateCost(s) 
	local c = 100

	local r_true, r_value = check_availableForRelocate(s.objective.coa, s.objective.data, "Arty")
	
	if r_value then

		local base_cost = 10
			
		-- some calculations done to average the values of the calculation between 15 and 50 cost
		if #r_value < 5 then
			c = base_cost + 10
		else
			c = base_cost + 2
		end
	end

	return c

end

function relocateArty:calculateDist(s) 
	--UTIL.dumpTable("GOAP_s.lua", s)
	if s then
		
		local d

		local a_avail, a_table = check_availableForRelocate(s.objective.coa, s.objective.data, "Arty")
		if a_table then
			local minDist = 100000
			for fId, fData in pairs(a_table) do
				if fData.dist and type(fData.dist) == "number" then
					if fData.dist < minDist then
						minDist = fData.dist
					end
				end
			end
	
			if minDist < 100000 then
				d = minDist
			end
		end
	
		if d then
			return math.floor(d/1000)
		else
			return 100
		end
	end
end


HOOK.writeDebugDetail(ModuleName .. ": relocateArty inserted")
--------------------------------------------------------------------------------------



-- #######################################################################
-- ############################## INIT ACTIONS ###########################
-- #######################################################################

attackTerritory:Launch()
relocateForces:Launch()
shellTerritory:Launch()	
relocateArty:Launch()
guardTerritory:Launch()


--------------------------------------------

HOOK.writeDebugBase(ModuleName .. ": Loaded " .. MainVersion .. "." .. SubVersion .. "." .. Build .. ", released " .. Date)
GOAPloaded = true

--~=