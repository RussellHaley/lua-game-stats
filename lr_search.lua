--- Search LuaRocks from script.
-- Gets all application dependencies via luarocks
-- @copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt

local srch = require("luarocks.search")
local serpent = require("serpent")

local sources, binaries, flags, name, version = srch.search({"--binary"}, "cqueues")

if sources == nil then
  print("Error "..binaries) 
  print("FLAGS\n:"..serpent.block(flags))
  print("NAME: ".. (name or ""))
  print("VERSION: "..(version or ""))

  return
end

print("SOURCES: \n")
print(serpent.block(sources))
print("BINS: \n")
print(serpent.block(binaries))

print("FLAGS\n:"..serpent.block(flags))
  print("NAME: ".. (name or ""))
  print("VERSION: "..(version or ""))



