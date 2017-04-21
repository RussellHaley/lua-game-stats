
local db_env

local databases = {}
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

local function open_tx(name,readonly)
  local t,dh
  local opts 
  
  if readonly then opts = MDB.RDONLY else opts = 0 end
  t = assert(db_env:txn_begin(nil, opts))
  dh = assert(t:dbi_open(name, MDB.CREATE))
  return t, dh
end

local function printEntries(self)
  local t,d = open_tx(self.name, true)
  local cursor, error, errorno = t:cursor_open(d)
  local k
  for k, v in cursor_pairs(cursor) do
    print(k,v)
  end

  cursor:close()
  t:abort()
end

--If the item exists, throws an exception
local function addItem(self,key,value)
  local t,d = open_tx(self.name)
  --Need to wrap in pcall to catch errors.
  --should return key if success or 
  --nil, error, errorno
  local out, err, errno = t:put(d, key, value, MDB.NOOVERWRITE)
  if not out then
    t:abort()
    return nil, err, errno
  end
  t:commit()
  return key
end

local function updateItem(key,value)
  local t,d = open_tx(self.name)

  local out, err, errno = t:put(d, key, value, 0)
  if not out then
    t:abort()
    return nil, err, errno
  end
  t:commit()
  return key
end

local function open_database(name)
  if db_env then
    if databases[name] then 
      return databases[name]
    end

    local t = db_env:txn_begin(nil, 0)
    local dh = t:dbi_open(name, MDB.CREATE)
    local cursor = t:cursor_open(dh)
    cursor:close()
    t:abort()
    databases[name] = true
    print("created"..name)
    local db = {
      name = name,
      update = updateItem,
      add = addItem,
      cursor_pairs = cursor_pairs,
      printAll = printEntries
    }

    return db
  else
    return nil, "NO_ENV_AVAIL", 100
  end
end


local function stats()    
  return db_env:stat()
end

local function close_env()
  db_env:close()
end

local function new(datadir)
  db_env = lightningmdb.env_create()
  db_env:set_mapsize(10485760)
  db_env:set_maxdbs(4)     
  db_env:open(datadir, 0, 420)

  return {  
    datadir = datadir,
    databases = databases,
    open_database = open_database,
    open_tx = open_tx,
    close_env = close_env,
    stats = stats
  }
end


return { 
  new = new
}