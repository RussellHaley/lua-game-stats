--- Depenedcies Getter.
-- Gets all application dependencies via luarocks
-- @copyright (c) 2016 Russell Haley
-- @license FreeBSD License. See License.txt

local list = require("luarocks.list")
--local cmd = require("luarocks.command_line")
local s = require("serpent")


local results, trees, flags, version  = list.list({"--outdated"})
local command = "luarocks list".. " --outdated"

print ("Version:\n"..(version or ""))
print ("Trees:\n"..s.block(trees))
print ("results:\n"..s.block(results))
print ("Flags Specified:\n"..s.block(flags))


local handle = io.popen(command)
local result = handle:read("*a")
handle:close()

print(result)
