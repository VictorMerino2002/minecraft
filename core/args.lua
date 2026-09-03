-- core/args.lua -- tiny command-line argument parser for CC: Tweaked programs.
--
--   local args = require("core.args")
--   local a = args.parse({ ... })
--
--   a:get(1)              -- first positional as string (or nil)
--   a:get(2, "up")        -- with a default
--   a:number(1)           -- first positional as number (errors if not numeric)
--   a:number(2, 5)        -- with a default
--   a:opt("dir", "up")    -- value of --dir (or the default)
--   a:number_opt("n", 1)  -- value of --n as a number
--   a:flag("force")       -- true if --force / -f was passed
--   a.positional          -- { ... } list of positionals
--   a.options             -- { key = value | true } table of options
--
-- Parsing rules:
--   --key value   -> options.key = "value"
--   --key=value   -> options.key = "value"
--   --key         -> options.key = true        (bare flag)
--   -abc          -> options.a, options.b, options.c = true  (short flags)
--   anything else -> positional argument

local M = {}

local Args = {}
Args.__index = Args

function M.parse(argv)
	local self = setmetatable({ positional = {}, options = {} }, Args)
	local i = 1
	while i <= #argv do
		local a = argv[i]
		local key, val = a:match("^%-%-([%w_%-]+)=(.*)$")
		if key then
			self.options[key] = val
		elseif a:match("^%-%-[%w_%-]+$") then
			key = a:sub(3)
			local nxt = argv[i + 1]
			if nxt ~= nil and not nxt:match("^%-") then
				self.options[key] = nxt
				i = i + 1
			else
				self.options[key] = true
			end
		elseif a:match("^%-%a+$") then
			for c in a:sub(2):gmatch(".") do
				self.options[c] = true
			end
		else
			self.positional[#self.positional + 1] = a
		end
		i = i + 1
	end
	return self
end

-- Positional string, or `default` if absent.
function Args:get(n, default)
	local v = self.positional[n]
	if v == nil then return default end
	return v
end

-- Positional number. Errors if present but not numeric; returns `default` if absent.
function Args:number(n, default)
	local v = self.positional[n]
	if v == nil then return default end
	return tonumber(v) or error("argument #" .. n .. " must be a number, got '" .. v .. "'", 0)
end

-- Option value (string), or `default`.
function Args:opt(name, default)
	local v = self.options[name]
	if v == nil or v == true then return default end
	return v
end

-- Option value as a number, or `default`.
function Args:number_opt(name, default)
	local v = self.options[name]
	if v == nil or v == true then return default end
	return tonumber(v) or error("--" .. name .. " must be a number, got '" .. v .. "'", 0)
end

-- True if the option/flag was passed at all.
function Args:flag(name)
	return self.options[name] ~= nil
end

function Args:count()
	return #self.positional
end

-- Allow `require("core.args")({ ... })` as shorthand for `.parse`.
setmetatable(M, { __call = function(_, argv) return M.parse(argv) end })

return M
