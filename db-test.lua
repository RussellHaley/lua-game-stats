#!/usr/local/bin/lua

local data = require("lmdb_env")

local env = data.new("data")
local serpent = require("serpent")
db_players = env.open_database("players")
db_year_player = env.open_database("year_players")

local function getPlayerYears(k,v,p)
--  if type(k) ~= 'number' then
--    return nil
--  end
--print(k)
  if(string.sub(k,1,4) == tostring(p)) then
    return string.sub(k,5),{k,v,p}
  end
end


local function getPlayersByCity(k,v,...) 
  local p = ...
  if type(v) == 'string' then
    ok, res = assert(serpent.load(v))
  else
    return nil
  end
  
  if res.Team.City == p then 
    return k,res
  else
    return nil
  end
end

--local retvals = db_players:search(getPlayersByCity,"Vancouver")

local playersIn2015 = db_year_player:search(getPlayerYears,2015)

if playersIn2015 then
  local count = 0
  for i,v in pairs(playersIn2015) do
    count = count + 1
    local res, player = serpent.load(db_players:get(i))
    print(player.FirstName, player.LastName)
  end
  print("players in ".."2015"..":"..count)
end

--if retvals then 
--  for i,v in pairs(retvals) do
--    print(v.FirstName, v.LastName)
--  end
--else
--  print('not found')
--end

env:close_env()




