
local lmdb_env

local databases = {}
--- LMDB Wrapper
local lightningmdb_lib = require("lightningmdb")
--- Filesystem
local lfs = require("lfs")
local serpent = require("serpent")

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
  t = assert(lmdb_env:txn_begin(nil, opts))
  dh = assert(t:dbi_open(name, MDB.CREATE))
  return t, dh
end

local function clean_items(key,value,throw_on_key)
    if type(key) == 'table' then 
      if throw_on_key then error('Key cannot be of type table.') end
      key = serpent.block(key)
    end
    if type(value) == 'table' then 
      value = serpent.block(value) 
    elseif type(value) == 'boolean' then
      if value then value = 1 else value = 0 end
    end
    return key,value
end

local function db_print_entries(self)
  local t,d = open_tx(self.name, true)
  local cursor, error, errorno = t:cursor_open(d)
  local k
  for k, v in cursor_pairs(cursor) do
    print(k,v)
  end

  cursor:close()
  t:abort()
end

local function db_search_entries(self,func,...)
  local t,d = open_tx(self.name, true)
  local cursor, error, errorno = t:cursor_open(d)
  local k
  local retval= {}
  for k, v in cursor_pairs(cursor) do
    local ok,val = func(k,v,...)
    if ok then 
      retval[ok] = val
    end
  end
  cursor:close()
  t:abort()
  return retval
end

local function db_get_item(self,key)
  local t,d = open_tx(self.name, true)
  local ok,res,errno = t:get(d,key, _, 0)  
  t:commit()
  return ok,res,errno
end

local function db_add_table_item(self,table, check_dups)
  local t,d = open_tx(self.name)
  local ok, err, errno
  local cursor
  cursor, err, errno= t:cursor_open(d)
  if not cursor then 
    t:abort()
    return nil, err, errno
  end
  local tmp = 0
  for k,v in pairs(table) do
    if check_dups then
      clean_items(k,nil,true)
      ok, err, errno = cursor:get(k, MDB.FIRST)
      if not ok and err == MDB.NOTFOUND then return end
    end
    k,v = clean_items(k,v,true)
    ok, err, errno = cursor:put(k,v,0)
    if not ok then 
      cursor:close()
      t:abort()
      return err, errno
    end
  end
  cursor:close()
  t:commit()
end

local function db_item_exists(self,key)
  local t,d = open_tx(self.name)
  clean_items(key, nil, true)
  local ok, err, errno = t:get(d, key)
  if not ok then
    t:abort()
    return nil, err, errno
  end
  t:commit()
  return key
end




--If the item exists, throws an exception
local function db_add_item(self,key,value)
  local t,d = open_tx(self.name)
  --Need to wrap in pcall to catch errors.
  --should return key if success or 
  --nil, error, errorno
  key, value = clean_items(key,value, true)
  local ok, err, errno = t:put(d, key, value, MDB.NOOVERWRITE)
  if not ok then
    t:abort()
    return nil, err, errno
  end
  t:commit()
  return key
end

local function db_upsert_item(key,value)
  local t,d = open_tx(self.name)
  key, value = clean_items(key,value, true)
  local ok, err, errno = t:put(d, key, value, 0)
  if not ok then
    t:abort()
    return nil, err, errno
  end
  t:commit()
  return key
end

local function open_database(name)
  if lmdb_env then
    if databases[name] then 
      return databases[name]
    end

    local t = lmdb_env:txn_begin(nil, 0)
    local dh = assert(t:dbi_open(name, MDB.CREATE))
    
    local cursor = t:cursor_open(dh)
    cursor:close()
    t:abort()
    
    local db = {
      name = name,
      update = db_upsert_item,
      add = db_add_item,
      add_table = db_add_table_item,
      print_all = db_print_entries,
      search = db_search_entries,
      get = db_get_item
    }
    
    databases[name] = db
    return db
  else
    return nil, "NO_ENV_AVAIL", 100
  end
end


local function stats()    
  return lmdb_env:stat()
end

local function close_env()
  lmdb_env:close()
end

local function new(datadir)
  lmdb_env = lightningmdb.env_create()
  lmdb_env:set_mapsize(10485760)
  lmdb_env:set_maxdbs(4)     
  lmdb_env:open(datadir, 0, 420)

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