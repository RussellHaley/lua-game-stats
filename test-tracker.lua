local track = require('table-tracker')

local t = {}

t["one"] = 1
t[2] = "two"

t = track.readOnly(t)

t[2] = "three"

print(t[2])

print("tracking test")
local u = {}

u = track.track(u,"testing")
u["one"] = 1
u["one"] = 2
u[2] = "three"
print(u["one"], u[2])
u[2] = nil

u:commit()

