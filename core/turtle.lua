-- core/turtle.lua -- OOP wrapper around the CC: Tweaked turtle API.
-- Tracks position and heading. Movement never breaks blocks or hits mobs:
-- if the way is blocked, the move simply fails.
--
--   local Turtle = require("core.turtle")
--   local t = Turtle.new({ fuelMin = 100 })
--   t:forward(3):turnRight():up(2)
--   t:moveTo(0, 64, 0)

local Turtle = {}
Turtle.__index = Turtle

-- Heading: 0 = south (+Z), 1 = west (-X), 2 = north (-Z), 3 = east (+X).
-- turnRight increments, turnLeft decrements (both mod 4).
local VEC = {
	[0] = { x = 0, z = 1 },
	[1] = { x = -1, z = 0 },
	[2] = { x = 0, z = -1 },
	[3] = { x = 1, z = 0 },
}

local MOVE = {
	forward = turtle.forward,
	back    = turtle.back,
	up      = turtle.up,
	down    = turtle.down,
}

-- Turtle.new{ x=, y=, z=, heading=, fuelMin=0, retries=6 }
function Turtle.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Turtle)
	self.x = opts.x or 0
	self.y = opts.y or 0
	self.z = opts.z or 0
	self.heading = (opts.heading or 0) % 4
	self.fuelMin = opts.fuelMin or 0  -- auto-refuel below this level before moving
	self.retries = opts.retries or 6  -- retries while blocked (e.g. a mob passing by)
	return self
end

-- Try to move one block in `dir`. Never digs, never attacks: retries a few
-- times (in case something is temporarily in the way) then gives up.
function Turtle:_tryMove(dir)
	local go = MOVE[dir]
	if go() then return true end
	for _ = 1, self.retries do
		os.sleep(0.5)
		if go() then return true end
	end
	return false
end

function Turtle:_advance(dir, n)
	n = n or 1
	for _ = 1, n do
		if self.fuelMin > 0 then self:refuel(self.fuelMin) end
		if not self:_tryMove(dir) then return false end
		if dir == "up" then
			self.y = self.y + 1
		elseif dir == "down" then
			self.y = self.y - 1
		else
			local v = VEC[self.heading]
			local s = (dir == "forward") and 1 or -1
			self.x = self.x + v.x * s
			self.z = self.z + v.z * s
		end
	end
	return true
end

function Turtle:forward(n) return self:_advance("forward", n) and self or false end
function Turtle:back(n)    return self:_advance("back", n) and self or false end
function Turtle:up(n)      return self:_advance("up", n) and self or false end
function Turtle:down(n)    return self:_advance("down", n) and self or false end

function Turtle:turnRight(n)
	for _ = 1, n or 1 do
		turtle.turnRight()
		self.heading = (self.heading + 1) % 4
	end
	return self
end

function Turtle:turnLeft(n)
	for _ = 1, n or 1 do
		turtle.turnLeft()
		self.heading = (self.heading - 1) % 4
	end
	return self
end

-- Rotate to an absolute heading (0..3) using the shortest turn.
function Turtle:turnTo(h)
	local diff = (h % 4 - self.heading) % 4
	if diff == 1 then self:turnRight()
	elseif diff == 2 then self:turnRight(2)
	elseif diff == 3 then self:turnLeft() end
	return self
end

-- Move to an absolute position: Y first, then X, then Z.
function Turtle:moveTo(x, y, z)
	while self.y < y do if not self:up() then return false end end
	while self.y > y do if not self:down() then return false end end

	if self.x ~= x then
		self:turnTo(self.x < x and 3 or 1)
		while self.x ~= x do if not self:forward() then return false end end
	end

	if self.z ~= z then
		self:turnTo(self.z < z and 0 or 2)
		while self.z ~= z do if not self:forward() then return false end end
	end
	return true
end

-- Detection
function Turtle:detect()     return turtle.detect() end
function Turtle:detectUp()   return turtle.detectUp() end
function Turtle:detectDown() return turtle.detectDown() end

-- Digging (single swing)
function Turtle:dig()     return turtle.dig() end
function Turtle:digUp()   return turtle.digUp() end
function Turtle:digDown() return turtle.digDown() end

-- Dig repeatedly until the space is clear (handles falling gravel/sand).
-- Returns false if a block cannot be broken.
function Turtle:mine()
	while turtle.detect() do
		if not turtle.dig() then return false end
		os.sleep(0)
	end
	return true
end

function Turtle:mineUp()
	while turtle.detectUp() do
		if not turtle.digUp() then return false end
		os.sleep(0)
	end
	return true
end

function Turtle:mineDown()
	while turtle.detectDown() do
		if not turtle.digDown() then return false end
		os.sleep(0)
	end
	return true
end

-- Placing
function Turtle:place(text)     return turtle.place(text) end
function Turtle:placeUp(text)   return turtle.placeUp(text) end
function Turtle:placeDown(text) return turtle.placeDown(text) end

-- Dropping items (into a container or on the ground)
function Turtle:drop(count)     return turtle.drop(count) end
function Turtle:dropUp(count)   return turtle.dropUp(count) end
function Turtle:dropDown(count) return turtle.dropDown(count) end

-- Inspection
function Turtle:inspect()     return turtle.inspect() end
function Turtle:inspectUp()   return turtle.inspectUp() end
function Turtle:inspectDown() return turtle.inspectDown() end

-- Fuel
function Turtle:fuelLevel()
	return turtle.getFuelLevel()
end

-- Burn inventory items until fuel reaches `target` (defaults to self.fuelMin).
function Turtle:refuel(target)
	target = target or self.fuelMin
	if turtle.getFuelLevel() == "unlimited" then return true end
	for slot = 1, 16 do
		if turtle.getFuelLevel() >= target then return true end
		turtle.select(slot)
		while turtle.getFuelLevel() < target and turtle.refuel(1) do end
	end
	return turtle.getFuelLevel() >= target
end

-- Inventory
function Turtle:select(slot)
	turtle.select(slot)
	return self
end

function Turtle:itemCount(slot)
	return turtle.getItemCount(slot)
end

-- True when every inventory slot holds something.
function Turtle:isFull()
	for slot = 1, 16 do
		if turtle.getItemCount(slot) == 0 then return false end
	end
	return true
end

-- Drop the whole inventory in the direction the turtle faces (into a chest,
-- for example). Returns false if any slot could not be emptied.
function Turtle:dumpAll()
	local ok = true
	for slot = 1, 16 do
		if turtle.getItemCount(slot) > 0 then
			turtle.select(slot)
			if not turtle.drop() then ok = false end
		end
	end
	turtle.select(1)
	return ok
end

function Turtle:findItem(name)
	for slot = 1, 16 do
		local d = turtle.getItemDetail(slot)
		if d and d.name == name then return slot end
	end
	return nil
end

function Turtle:selectItem(name)
	local slot = self:findItem(name)
	if slot then turtle.select(slot) end
	return slot
end

-- Try to read the real position from GPS and sync internal coordinates.
function Turtle:locate(timeout)
	local x, y, z = gps.locate(timeout or 2)
	if not x then return false end
	self.x, self.y, self.z = x, y, z
	return true
end

function Turtle:pos()
	return { x = self.x, y = self.y, z = self.z, heading = self.heading }
end

return Turtle
