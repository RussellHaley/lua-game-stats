#!/usr/local/bin/lua

local data = require("lmdb_env")

local env = data.new("data")
local serpent = require("serpent")
db = env.open_database("players")

local function searchPlayers(k,v,p) 
  if type(v) == 'string' then
    ok, res = serpent.load(v)
  else
    return nil
  end
  
  if res.Team.City == p then 
    return k,res
  else
    return nil
  end
end

local retvals = db:search(searchPlayers,"Vancouver")

if retvals then 
  for i,v in pairs(retvals) do
    print(v.FirstName, v.LastName)
  end
else
  print('not found')
end

env:close_env()




