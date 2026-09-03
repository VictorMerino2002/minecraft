-- dig/script.lua -- excavate a rectangular volume starting at the turtle.
--
--   dig/script --x <forward> --y <down> --z <right> [--storage]
--
--   --x        blocks forward  (length,  default 1)
--   --y        blocks down     (depth,   default 1)
--   --z        blocks right    (width,   default 1)
--   --storage  empty the inventory into a chest placed behind the turtle's
--              starting position (when full, and again at the end) instead
--              of stopping when the inventory fills up
--
-- The turtle digs layer by layer, snaking through each one, and returns to
-- the starting position when finished.

package.path = "/?.lua;/?/init.lua;" .. package.path
local Turtle = require("core.turtle")
local args   = require("core.args")

local a = args.parse({ ... })

local X = a:number_opt("x", 1)
local Y = a:number_opt("y", 1)
local Z = a:number_opt("z", 1)

if a:flag("help") or X < 1 or Y < 1 or Z < 1 then
	print("usage: dig/script --x <forward> --y <down> --z <right> [--storage]")
	return
end

local storage = a:flag("storage")

local t = Turtle.new()

-- Dig the block ahead and step into it.
local function ahead()
	if not t:mine() then
		error("unbreakable block ahead at " .. textutils.serialise(t:pos()), 0)
	end
	if not t:forward() then
		error("blocked moving forward at " .. textutils.serialise(t:pos()), 0)
	end
end

-- Dig the block below and step down into it.
local function descend()
	if not t:mineDown() then
		error("unbreakable block below at " .. textutils.serialise(t:pos()), 0)
	end
	if not t:down() then
		error("blocked moving down at " .. textutils.serialise(t:pos()), 0)
	end
end

-- Layer geometry. Rows run along Z; each new row steps one block along -X.
-- Odd rows are dug facing +Z (heading 0) starting at z = 0;
-- even rows are dug facing -Z (heading 2) starting at z = X - 1.
local layerY = 0                                        -- y of the layer being dug
local function rowHeading(row) return (row % 2 == 1) and 0 or 2 end
local function rowStartZ(row)  return (row % 2 == 1) and 0 or (X - 1) end
local function rowStartX(row)  return -(row - 1) end

-- Walk (never digging) between the current spot on `row` and the start, then
-- home up the spine column at x = z = 0. Only follows already-carved blocks:
-- back along the row, along the connecting line to the spine, then the spine.
local function goHome(row)
	t:turnTo((rowHeading(row) + 2) % 4)
	while t.z ~= rowStartZ(row) do
		if not t:forward() then error("stuck heading home", 0) end
	end
	t:turnTo(3)                                         -- +X toward the spine
	while t.x ~= 0 do
		if not t:forward() then error("stuck heading home", 0) end
	end
	t:turnTo(2)                                         -- -Z toward the spine origin
	while t.z ~= 0 do
		if not t:forward() then error("stuck heading home", 0) end
	end
	t:moveTo(0, 0, 0)
end

-- Reverse of goHome: from home back to (row, targetZ), facing the dig direction.
local function goBack(row, targetZ)
	t:moveTo(0, layerY, 0)
	t:turnTo(0)                                         -- +Z along the spine (x = 0)
	while t.z ~= rowStartZ(row) do
		if not t:forward() then error("stuck going back", 0) end
	end
	t:turnTo(1)                                         -- -X along the connecting line
	while t.x ~= rowStartX(row) do
		if not t:forward() then error("stuck going back", 0) end
	end
	t:turnTo(rowHeading(row))
	while t.z ~= targetZ do
		if not t:forward() then error("stuck going back", 0) end
	end
end

-- Empty the inventory into the chest behind the start, then resume digging.
local function unload(row)
	local targetZ = t.z
	print("unloading into storage...")
	goHome(row)
	t:turnTo(2)                                         -- face the chest behind the start
	if not t:dumpAll() then
		error("storage chest is full or missing", 0)
	end
	goBack(row, targetZ)
end

local function checkInventory(row)
	if not t:isFull() then return end
	if storage then unload(row) else error("inventory full", 0) end
end

-- Snake through one horizontal layer: Z rows, each X blocks long.
local function digLayer()
	layerY = t.y
	for row = 1, Z do
		for _ = 1, X - 1 do
			checkInventory(row)
			ahead()
		end
		if row < Z then
			checkInventory(row)
			local right = (row % 2 == 1)
			if right then t:turnRight() else t:turnLeft() end
			ahead()
			if right then t:turnRight() else t:turnLeft() end
		end
	end
end

-- Fuel: rough upper bound on blocks moved (dig path + returns between layers,
-- plus a round trip to the chest for every ~512 blocks when --storage is set).
local total = X * Y * Z
local needed = total + (X + Z) * Y + Y + 20
if storage then
	needed = needed + (math.ceil(total / 512) + 1) * (X + Y + Z) * 2
end
if not t:refuel(needed) then
	printError(("not enough fuel: have %s, need %d"):format(tostring(t:fuelLevel()), needed))
	return
end

local ok, err = pcall(function()
	for layer = 1, Y do
		print(("layer %d/%d"):format(layer, Y))
		digLayer()
		-- The whole layer is now air, so moving back to its corner never digs.
		t:moveTo(0, t.y, 0)
		t:turnTo(0)
		if layer < Y then descend() end
	end
end)

-- Go home whatever happened (path is already carved out).
t:moveTo(0, 0, 0)

if storage then
	t:turnTo(2)
	if not t:dumpAll() then
		printError("could not empty everything: storage chest full or missing")
	end
end
t:turnTo(0)

if ok then
	print(("done, fuel %s"):format(tostring(t:fuelLevel())))
else
	printError("stopped: " .. tostring(err))
end
