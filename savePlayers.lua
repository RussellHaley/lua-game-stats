
--- LMDB Wrapper
local lightningmdb_lib = require("lightningmdb")
--- Filesystem
local lfs = require("lfs")

--Set up lmdb and a table of constants
local lightningmdb = _VERSION >= "Lua 5.2" and lightningmdb_lib or lightningmdb
local MDB = setmetatable({}, {
    __index = function(_, k)
        return lightningmdb["MDB_" .. k]
    end
})


--- cursor_pairs. Use a coroutine to iterate through the
-- open lmdb data set
local function cursor_pairs(cursor_, key_, op_)
    return coroutine.wrap(function()
        local k = key_
        repeat
            local k, v = cursor_:get(k, op_ or MDB.NEXT)
            if k then
                coroutine.yield(k, v)
            end
        until not k
    end)
end



local datadir = "/tmp/test"
 local e = lightningmdb.env_create()
  e:set_mapsize(10485760)
  e:set_maxdbs(4) 
  e:open(datadir, 0, 420)
  local t = e:txn_begin(nil, 0)
    
  local d = t:dbi_open("players", MDB.CREATE)

  local val1 = "Russell7"
  local val2 = "Haley"
  assert(t:put(d, val1, val2, MDB.NOOVERWRITE))
  --assert(t:put(d, string.format("%03x","Steve"), "Frank", MDB.NOOVERWRITE))
  --assert(t:put(d, string.format("%03x","Testy"), "Testerson", MDB.NOOVERWRITE))
  t:commit()
   local t = e:txn_begin(nil, 0)
   local cursor = t:cursor_open(d)
    local k
    for k, v in cursor_pairs(cursor) do
        print(k,v)
    end
    
    cursor:close()
    t:abort()
  e:close()
  for i,v in pairs(stat) do
    print(i,v)
  end
  