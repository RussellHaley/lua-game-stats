local time1
local total_requests = 0
local request = require("http.request")
local lb = require("base64")
local cqueues = require("cqueues")
local serpent = require("serpent")
local json = require("dkjson")
local zlib = require "http.zlib"
local zDefate = zlib.deflate()
local zInflate = zlib.inflate()

local configuration = require "lib.configuration"
local conf
local rolling_logger = require "logging.rolling_file"
local log
local loaded
local debugFlag
local slash = "/"
local dash = "-"

--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2015-2016-regular/full_game_schedule.json"
--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2013-2014-regular/daily_game_schedule.json?fordate=20140310"
--https://www.mysportsfeeds.com/api/feed/pull/nhl/2016-2017-regular/cumulative_player_stats.json?playerstats=G,A,Pts,Sh

 
local feedtypes = {
  ["game_schedule"] = "full_game_schedule.json", 
  ["player_stats"] = "cumulative_player_stats.json?playerstats=G,A,Pts,Sh", 
  ["box_scores"] = "game_boxscore.json?gameid=20160211-WSH-MIN&teamstats=W,L,GF,GA,Pts&playerstats=G,A,Pts,Sh"
}

local uri  


local function printHeaders(t,type)  
  print("## ".. (type or "") .. " HEADERS")
  log:debug("## ".. (type or "") .. " HEADERS")
  for k, v in t:each() do
    log:debug(string.format("%s %s",k,v))
    print(k, v)
  end
end

local function printBody(body,type)
  log:debug("## "..(type or "").." BODY")
  print("## "..(type or "").." BODY")
  log:debug("body")
  print(body)
end


--- Gets the json body from a request if the request was successful.
-- /return Returns a table built from the json string
local function Get(uri, username, password, req_body)
  local req = request.new_from_uri(uri)
  local retVal = nil
  if username then
    local encoded = lb.encode(username..":"..password)  
    req.headers:upsert("Authorization","Basic ".. encoded)
  end
  if conf.useZLib == true then    
    req.headers:upsert("Accept-Encoding","gzip")
  end
  if req_body then
    req.headers:upsert(":method", "POST")
    req:set_body(req_body)
  end
  
    

  local headers, stream = req:go(conf.req_timeout)
  total_requests = total_requests + 1
  if headers == nil then
    log:warn(tostring(stream), "\n")
    io.stderr:write(tostring(stream), "\n")    
  else
    if debugFlag then 
      printHeaders(req.headers,"REQUEST")          
      printHeaders(headers,"RESPONSE")
    end
    local body, err
    if headers:get(":status") ~= "200" then
      log:warn("Failed to execute request. Status Code:"..headers:get(":status"))
    else
      if conf.useZLib == true then
        body, err= zInflate(stream:get_body_as_string(),true)
      else
        body, err  = stream:get_body_as_string()
      end
      if not body and err then
        io.stderr:write(tostring(err), "\n")
        os.exit(1) --Maybe return something instead
      end
--      if debugFlag then 
--        --printResponseHeaders(headers)
--        printBody(body, "RESPONSE")
--      end     
      retVal = json.decode(body)      
    end
  end    

  return retVal
end


--*******************************************************************************************************
--*******************************************************************************************************
local Players = {}
local TeamLocations = {}
local GamesByYear = {}
local PlayerStatsPerTeam
local Years = {["2012-2013"] = {},["2014-2015"]={},["2015-2016"]={}}--,["2016-2017"]={}}
local Seasons = {"regular","post-season"}

local function getPlayersYear(year,season)
  url =uri..slash..year..dash..season..slash..feedtypes["player_stats"]..conf.force
  log:info("Entered getPlayers")
  local body = Get(url,conf.username,conf.password)
  
  if body then
    local players = body.cumulativeplayerstats.playerstatsentry

    local pl = {}
    for i,v in pairs(players) do
      local p = {}
      for j,item in pairs(v) do 
        if j == "player" then         
          p.ID = item.ID
          p.FirstName = item.FirstName
          p.LastName = item.LastName
          --print(item.ID,item.FirstName,item.LastName)        
        elseif j == "team" then
          p.Team = item
        end
      end
      table.insert(pl,p)
    end
    return pl
  else
    log:warn("Failed to retrieve players.");
    return nil
  end
end

local function getBoxscores()
  url =uri..feedtypes.box_score
  log:info("entered getBoxscores")
  local t = Get(url,conf.username, conf.password)
  
  print(serpent.block(t))
end

local function getGameSchedule(year,season)
  log:info("entered getGameSchedule")  
  url =uri..slash..year..dash..season..slash..feedtypes["game_schedule"]
  return Get(url,conf.username, conf.password)  
end

local function parseLocations(body)
  local l = {}
  local games = body.fullgameschedule.gameentry
  for i,v in pairs(games) do
    if l[v.location] == nil then
      l[v.location] = v.homeTeam.City .. " " .. v.homeTeam.Name
    end
  end
  return l
end

local function Loop()
  for i,v in pairs(Years) do
    Players[i] = getPlayersYear(i,"regular")       
    t = {}
    --for s in ipairs(seasons) do
    t["regular"] = getGameSchedule(i,"regular")
    --end
    Years[i] = t          
    TeamLocations[i] = parseLocations(Years[i]["regular"])          
    --serpent.block(TeamLocations[i])
  end  
end

-- Can't access current feed as I have not asked for access
-- No historic scoreboard

local function RunHistoric(cq)
  if not cq then 
    cq = cqueues.new()
  end
print(debugFlag)
  --add the historic getter routine
  -- add the interface server
  -- add the get current routine
  
  for i,v in pairs(Years) do
    log:info("Creating Loops...")
    cq:wrap(function()       
        Players[i] = getPlayersYear(i,"regular")
        print(#Players[i])
        --log:info(serpent.block(Players[i]))
      end)
    cq:wrap(function()
        local t = {}
        
        --for s in ipairs(seasons) do
        t["regular"] = getGameSchedule(i,"regular")
        --end

        Years[i] = t          
        TeamLocations[i] = parseLocations(Years[i]["regular"])          
      end)
  end
  log:info("Running...")
  local cq_ok, err, errno = cq:loop()
  if not cq_ok then
    print("Execution failed, check logs for messages.")
    local out 
    if errno then out = err .. errno else out = err end
    log:warn("Jumped the loop.".. out)      
    log:warn(debug.traceback())
  else    
    --print(serpent.block(Years))
  end
end   



local function Start(debug_flag)  
  
  time1 = cqueues.monotime() 
  total_requests = 0
  conf = configuration.new([[stats-engine.conf]],true)
  
  print("Log file is at:"..conf.debug_file_name)
  log = assert(rolling_logger(conf.debug_file_name, conf.file_roll_size or 1024*1024*10, conf.max_log_files or 31))
  if not log then
    print("logger failed")
    os.exit(0)
  end  
  
  debugFlag = debug_flag or conf.debug_flag  
  log:debug(string.format("Debug logging is %s",debug))  
  uri = conf.domain..slash..conf.abspath..slash..conf.leauge
  log:info("uri is "..uri)

  log:info("Starting Stats Engine at" .. os.date("%b-%d-%C %H:%M:%S"))
end

local function Shutdown()
  log:info("Shutdown at " .. os.date("%b-%d-%C %H:%M:%S"))
  log:info("Total number of requests was " .. total_requests)
  log:info("Total runtime was " .. string.format("%.1fs", cqueues.monotime() - time1))  
end

Start(arg[1])
RunHistoric()
--Loop()
Shutdown()