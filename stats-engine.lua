-- Can't access current feed as I have not asked for access
-- No historic scoreboard
local global_debug = true
local cqueues = require("cqueues")
local request = require("http.request")
local lb = require("base64")
local serpent = require("serpent")
local json = require("dkjson")
--local logging = require("logging");
--local db = require("Lightningmdb")
local domain = "https://www.mysportsfeeds.com"
local abspath = "/api/feed/pull"
local leauge = "/nhl"
local years = "/"..arg[1]
local season = "-"..arg[2]

local game = {datepart="",hometeam="",awayTeam=""}

--https://www.mysportsfeeds.com/api/feed/pull/nhl/2016-2017-regular/cumulative_player_stats.json?playerstats=G,A,Pts,Sh
local feedtypes = {"/full_game_schedule.json", "/cumulative_player_stats.json?playerstats=G,A,Pts,Sh", 
  "/game_boxscore.json?gameid=20160211-WSH-MIN&teamstats=W,L,GF,GA,Pts&playerstats=G,A,Pts,Sh"}
local fordate = ""
local stats = ""
local uri  = domain..abspath..leauge..years..season
--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2015-2016-regular/full_game_schedule.json"
--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2013-2014-regular/daily_game_schedule.json?fordate=20140310"

--"https://www.mysportsfeeds+


local username = "dinsdale"
local password = "dinsdale"

--local req_body = arg[2]
local req_timeout = 10


local function printReqHeaders()

  print("## Request Headers:")
  for k, v in req.headers:each() do
    print(k, v)
  end
end

local function printResponseHeaders(t)
  print("## HEADERS")
  for k, v in t:each() do
    print(k, v)
  end
end

local function printResponseBody(body)
  print("## BODY")
  print(body)
end


local function Get(uri, username, password)
  local req = request.new_from_uri(uri)
  local encoded = lb.encode(username..":"..password)
  
  req.headers:upsert("Authorization","Basic ".. encoded)
  if req_body then
    req.headers:upsert(":method", "POST")
    req:set_body(req_body)
  end
 
  if debug then
    for i,v in pairs(req.headers) do
      print(i,v)
    end
  end
  
  return req:go(req_timeout)
end

local function getLocations(body)
    
--  local f = io.open("output.txt","w")
--  f:write(serpent.block(out))
--  f:close()
  local l = {}
  local games = body.fullgameschedule.gameentry
  for i,v in pairs(games) do
    if l[v.location] == nil then
      l[v.location] = v.homeTeam.City .. " " .. v.homeTeam.Name
    end
  end
  return l
end

local function getPlayers(body)
  local pl = {}
  local players = body.cumulativeplayerstats.playerstatsentry
  
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
end

local cq = cqueues.new()

local function Run(debug)
  for i,v in pairs(feedtypes) do
    cq:wrap(function()
        local i=1
        repeat
      print(uri..v)
        local headers, stream = Get(uri..v,username, password)
        local body, err = stream:get_body_as_string()

        if headers == nil then
            io.stderr:write(tostring(stream), "\n")
            os.exit(1)
        else
          if not body and err then
            io.stderr:write(tostring(err), "\n")
            os.exit(1)
          end
          if debug then 
            printResponseHeaders(headers)
            --printResponseBody(body)
          end
        end
        i = i+1
        until i == 150
        
      end)
  end
  
  local cq_ok, err, errno = cq:loop()
  if not cq_ok then
      print("Jumped the loop.", debug.traceback())      
  end
  print("ended")
end  

local function runOne(url)
  local headers, stream = Get(url,username, password)
  local body, err = stream:get_body_as_string()

  if headers == nil then
      io.stderr:write(tostring(stream), "\n")
      os.exit(1)
  else
    if not body and err then
      io.stderr:write(tostring(err), "\n")
      os.exit(1)
    end
    if debug then 
      printResponseHeaders(headers)
      printResponseBody(body)
    end
  end  
  return json.decode(body)  
end

debug = false
--Run(global_debug)
--runOne
print(uri..feedtypes[1])
print(uri..feedtypes[2])

--print(runOne(uri..feedtypes[1]))
--print(serpent.block(runOne("https://www.mysportsfeeds.com/api/feed/pull/nhl/2015-2016-regular/full_game_schedule.json")))
--serpent.block(getLocations(runOne(uri..feedtypes[1])))

print(serpent.block(getPlayers(runOne(uri..feedtypes[2]))))



  