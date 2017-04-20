
local db_env
local db
local name
local datadir

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


local function printEntries()

  t = db_env:txn_begin(nil, 0)
  local cursor = t:cursor_open(db)
  local k
  for k, v in cursor_pairs(cursor) do
    print(k,v)
  end

  cursor:close()
  t:abort()
end



--If the item exists, throws an exception
local function addItem(key,value)
  local t = db_env:txn_begin(nil, 0)
    t:put(db, key, value, MDB.NOOVERWRITE)
  t:commit()
end

local function updateItem(key,value)
  local t = db_env:txn_begin(nil, 0)

  t:put(db, key, value, 0)
  t:commit()
end


local function new(datadir,database_name)
  db_env = lightningmdb.env_create()
  db_env:set_mapsize(10485760)
  db_env:set_maxdbs(4)     
  db_env:open(datadir, 0, 420)
  local t = db_env:txn_begin(nil, 0)
  db = t:dbi_open(name, MDB.CREATE)
  local cursor = t:cursor_open(db)
  cursor:close()
  t:abort()
  
  return {  
  updateItem = updateItem,
  addItem = addItem,
  printEntries = printEntries
  database_name = database_name
  datadir = datadir
  }
end

local function close()
  db_env:close()
end


return { 
  new = new,
}