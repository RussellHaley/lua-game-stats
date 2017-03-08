
--- Module implementing the LuaRocks "list" command.
-- Lists currently installed rocks.
-- module("luarocks.list", package.seeall)

local list = {}
package.loaded["luarocks.list"] = list
  
local flags, filter, version, query, trees

--util.add_run_function(list)
local search = require("luarocks.search")
local deps = require("luarocks.deps")
local cfg = require("luarocks.cfg")
local util = require("luarocks.util")
local path = require("luarocks.path")

util.add_run_function(list)
list.help_summary = "List currently installed rocks."
list.help_arguments = "[--porcelain] <filter>"
list.help = [[
<filter> is a substring of a rock name to filter by.

--outdated    List only rocks for which there is a
              higher version available in the rocks server.

--porcelain   Produce machine-friendly output.
]]

---Searches for outdated packages in the given tree
-- @return table,table,table,string: results, trees, flags, version
local function get_outdated()
   local results_installed = {}
   for _, tree in ipairs(trees) do
      search.manifest_search(results_installed, path.rocks_dir(tree), query)
   end
   local outdated = {}
   for name, versions in util.sortedpairs(results_installed) do
      versions = util.keys(versions)
      table.sort(versions, deps.compare_versions)
      local latest_installed = versions[1]

      local query_available = search.make_query(name:lower())
      query.exact_name = true
      local results_available, err = search.search_repos(query_available)
      
      if results_available[name] then
         local available_versions = util.keys(results_available[name])
         table.sort(available_versions, deps.compare_versions)
         local latest_available = available_versions[1]
         local latest_available_repo = results_available[name][latest_available][1].repo
         
         if deps.compare_versions(latest_available, latest_installed) then
            table.insert(outdated, { name = name, installed = latest_installed, available = latest_available, repo = latest_available_repo })
         end
      end
   end
   return outdated, trees, flags, version
end

--- Outputs the outdated packages
-- @return true
local function print_outdated(porcelain)
   util.title("Outdated rocks:", porcelain)
   local outdated = get_outdated()
   for _, item in ipairs(outdated) do
      if porcelain then
         util.printout(item.name, item.installed, item.available, item.repo)
      else
         util.printout(item.name)
         util.printout("   "..item.installed.." < "..item.available.." at "..item.repo)
         util.printout()
      end
   end
   return true
end

--- Driver function for "list" command.
-- @param filter string or nil: A substring of a rock name to filter by.
-- @param version string or nil: a version may also be passed.
-- @return table,table,table,string: results, trees, flags, version
local function get_results()
      
   local results = {}
   for _, tree in ipairs(trees) do
      local ok, err, errcode = search.manifest_search(results, path.rocks_dir(tree), query)
      if not ok and errcode ~= "open" then
         util.warning(err)
      end
   end
   return results, trees, flags, version 
end

--- Parse the arguments, create the query and get the trees. 
local function init()
   query = search.make_query(filter and filter:lower() or "", version)
   query.exact_name = false
   trees = cfg.rocks_trees
   if flags["tree"] then
      trees = { flags["tree"] }
   end
end

--- Run function for "list" command. This is called by command_line  
-- when the user specifies `list`.
-- @param filter string or nil: A substring of a rock name to filter by.
-- @param version string or nil: a version may also be passed.
-- @return true
function list.command(flags_in, filter_in, version_in)
    --flags, filter, version = table.unpack(...)  
  flags = flags_in
  filter = filter_in
  version = version_in
   init() 
   if flags["outdated"] then
      print_outdated(flags["porcelain"])
   else
      util.title("Installed rocks:", flags["porcelain"])
      search.print_results(get_results(), flags["porcelain"])
   end
   
   return true
end

-- Return the table results from the list command
-- @return table,table,table,string: results, trees, flags, version
function list.list(flags_in, filter_in, version_in)
    --flags, filter, version = table.unpack(...)  
  flags = flags_in
  filter = filter_in
  version = version_in
   --flags, filter, version = util.parse_flags(...)
   init()
  if flags["outdated"] then
    return get_outdated()
  else
    return get_results()
  end
end

return list
