-- Can't access current feed as I have not asked for access
-- No historic scoreboard
local global_debug = false
local request = require("http.request")
local lb = require("base64")
local serpent = require("serpent")
local json = require("dkjson")

local domain = "https://www.mysportsfeeds.com"
local abspath = "/api/feed/pull"
local leauge = "/nhl"
local years = "/"..arg[1]
local season = "-"..arg[2]
local feedtype = "/full_game_schedule.json"
local fordate = ""
local stats = ""
local uri  = domain..abspath..leauge..years..season..feedtype
--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2015-2016-regular/full_game_schedule.json"
--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2013-2014-regular/daily_game_schedule.json?fordate=20140310"

--"https://www.mysportsfeeds.com/api/feed/pull/nhl/2013-2014-regular/game_boxscore.json?gameid=20140310-NYI-VAN&teamstats=W,L,GF,GA,Pts&playerstats=G,A,Pts,Sh"

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
  
  new_headers = require "http.headers".new
  req.headers:upsert("Authorization","Basic ".. encoded)
  if req_body then
    req.headers:upsert(":method", "POST")
    req:set_body(req_body)
  end
  
  return req:go(req_timeout)
end

local function getLocations(body)
    
  local out = json.decode(body)
  local f = io.open("output.txt","w")
  f:write(serpent.block(out))
  f:close()

  local l = {}
  local games = out.fullgameschedule.gameentry
  for i,v in pairs(games) do
    if l[v.location] == nil then
      l[v.location] = v.homeTeam.City .. " " .. v.homeTeam.Name
    end
  end
  return l
end

local function Run(debug)
  print(uri)
  local headers, stream = Get(uri,username, password)
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

  local locations = getLocations(body)
  print(serpent.block(locations))
end

Run(global_debug)