import sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
teile = {
 "mock": os.path.join(ROOT, "tools/mock.luau"),
 "gen": os.path.join(ROOT, "karte/stadt_generator.lua"),
 "inst": os.path.join(ROOT, "dist/fuehrerschein_installer.lua"),
 "test": sys.argv[1],
}
def lang(s):
    n = 12
    while ("]" + "="*n + "]") in s: n += 1
    return "[" + "="*n + "[\n" + s + "]" + "="*n + "]"
out = "--!nocheck\nlocal Q = {}\n"
for k, p in teile.items():
    out += f"Q[{k!r}] = " + lang(open(p).read()) + "\n"
out += r'''
local env = setmetatable({}, { __index = getfenv(1) })
env.os = setmetatable({ date = os.date }, { __index = os })
env._G = env
local cache = {}
local function lade(name, src, extra)
	local f, e = loadstring(src, "=" .. name)
	assert(f, e)
	local fenv = setmetatable(extra or {}, { __index = env, __newindex = env })
	setfenv(f, fenv)
	return f
end
env.lade = lade
local M = lade("mock", Q.mock)()
env.M = M
env.game = M.game
env.require = function(x)
	if type(x) == "table" and x.__klasse == "ModuleScript" then
		if cache[x] == nil then
			cache[x] = lade(x:GetFullName(), x.Source, { script = x })()
		end
		return cache[x]
	end
	error("require of non-module: " .. tostring(x))
end
env.Q = Q
lade("test", Q.test)()
'''
open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "tools/run.luau"), "w").write(out)
