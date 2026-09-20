-- The whole thing
local WP = {}

-- Local storage
WP.waypoints = {}
WP.nextWaypointID = 1

-- Console message helpers
local function printError(message)
  print("|cffff0000" .. message)
end

local function printSuccess(message)
  print("|cff00ff00" .. message)
end

local function printInfo(message)
  print("|cff00ffff" .. message)
end

-- Parse coordinates
local function getCoordinates(numbers)
  local x = numbers[1] and math.floor(numbers[1] * 100 + 0.5) / 100
  local y = numbers[2] and math.floor(numbers[2] * 100 + 0.5) / 100
  return x, y
end

-- Create a new waypoint
local function createWaypoint(zoneID, x, y, description)
  local waypoint = {
    id = WP.nextWaypointID,
    zoneID = zoneID,
    x = x,
    y = y,
    description = description or "",
    createdAt = GetTime()
  }
  
  WP.waypoints[WP.nextWaypointID] = waypoint
  WP.nextWaypointID = WP.nextWaypointID + 1
  
  return waypoint
end

-- Remove a waypoint by ID
local function removeWaypoint(id)
  if WP.waypoints[id] then
    WP.waypoints[id] = nil
    return true
  end
  return false
end

-- Clear all waypoints
local function clearAllWaypoints()
  WP.waypoints = {}
end

-- Get all waypoints
local function getAllWaypoints()
  return WP.waypoints
end

-- Get a waypoint by ID
local function getWaypointByID(id)
  return WP.waypoints[id]
end

-- Set the superTracked waypoint (the one that appears on the minimap)
local function setSuperTrackedWaypoint(id)
  local waypoint = getWaypointByID(id)
  if waypoint and C_Map.CanSetUserWaypointOnMap(waypoint.zoneID) then
    local vector = CreateVector2D(waypoint.x / 100, waypoint.y / 100)
    local mapPoint = UiMapPoint.CreateFromVector2D(waypoint.zoneID, vector)
    C_Map.SetUserWaypoint(mapPoint)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return true
  end
  return false
end

-- Print waypoint information
local function printWaypoint(waypoint)
  local mapInfo = C_Map.GetMapInfo(waypoint.zoneID)
  local mapName = mapInfo and mapInfo.name or "Unknown Zone"
  local desc = waypoint.description ~= "" and (" - |cffffa500" .. waypoint.description .. "|r") or ""
  
  print(string.format("Waypoint |cff00ff00#%d|r: |cffffa500%s|r - |cffffff00%.2f, %.2f|r%s", 
    waypoint.id, mapName, waypoint.x, waypoint.y, desc))
end

-- Print all waypoints
local function printAllWaypoints()
  local count = 0
  for id, waypoint in pairs(WP.waypoints) do
    count = count + 1
    printWaypoint(waypoint)
  end
  
  if count == 0 then
    printInfo("No waypoints set.")
  else
    printInfo(string.format("Total waypoints: |cff00ff00%d|r", count))
  end
end

-- Waypoint command handler
local function Waypoint(args, editbox)
  args = strtrim(args)
  
  if args == "" then
    printAllWaypoints()
    return
  elseif args == "me" then
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = C_Map.GetMapInfo(mapID)
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    
    if mapInfo and position then
      local mapName = mapInfo.name
      local x = math.floor(position.x * 10000 + 0.5) / 100
      local y = math.floor(position.y * 10000 + 0.5) / 100
      printInfo(string.format("You are currently in |cffffa500%s|r at coordinates: |cffffff00%.2f, %.2f|r", mapName, x, y))
    else
      printError("Cannot determine your current location.")
      printInfo("You might be in an instance.")
    end
    return
  elseif args == "clear" then
    clearAllWaypoints()
    printSuccess("All waypoints cleared.")
    return
  end
  
  -- Parse command arguments
  -- Standardize separators: replace commas with spaces
  args = args:gsub(",", " ")
  
  local tokens = {}
  for token in args:gmatch("%S+") do
    table.insert(tokens, token)
  end

  local zoneID, x, y, id, description
  local numbers, texts = {}, {}
  
  for _, token in ipairs(tokens) do
    if token:match("^#%d+") then
      zoneID = tonumber(token:match("%d+"))
    elseif token:match("^@%d+") then
      id = tonumber(token:match("%d+"))
    elseif tonumber(token) then
      table.insert(numbers, tonumber(token))
    else
      table.insert(texts, token)
    end
  end
  
  x, y = getCoordinates(numbers)
  description = strtrim(table.concat(texts, " "))
  
  -- Handle remove command
  if tokens[1] == "remove" or tokens[1] == "del" then
    local targetID = tonumber(tokens[2])
    if targetID then
      if removeWaypoint(targetID) then
        printSuccess(string.format("Waypoint |cff00ff00#%d|r removed.", targetID))
      else
        printError(string.format("Waypoint |cff00ff00#%d|r not found.", targetID))
      end
    else
      printError("Usage: /way remove [ID]")
    end
    return
  end
  
  -- Handle goto command
  if tokens[1] == "goto" then
    local targetID = tonumber(tokens[2])
    if targetID then
      if setSuperTrackedWaypoint(targetID) then
        printSuccess(string.format("Now tracking waypoint |cff00ff00#%d|r.", targetID))
      else
        printError(string.format("Waypoint |cff00ff00#%d|r not found or cannot be tracked.", targetID))
      end
    else
      printError("Usage: /way goto [ID]")
    end
    return
  end
  
  -- Handle add waypoint
  if x and y then
    if x < 0 or x > 100 or y < 0 or y > 100 then
      printError("Coordinates must be between 0 and 100.")
      return
    end
    
    zoneID = zoneID or C_Map.GetBestMapForUnit("player")
    
    local waypoint
    if id and not WP.waypoints[id] then
      waypoint = createWaypoint(zoneID, x, y, description)
      waypoint.id = id
      WP.waypoints[id] = waypoint
      WP.nextWaypointID = math.max(WP.nextWaypointID, id + 1)
    else
      waypoint = createWaypoint(zoneID, x, y, description)
    end
    
    printWaypoint(waypoint)
    
    -- If it's the first waypoint, automatically track it
    local count = 0
    for _ in pairs(WP.waypoints) do count = count + 1 end
    if count == 1 then
      setSuperTrackedWaypoint(waypoint.id)
    end
  else
    printInfo("Usage: /way [#ZoneID] X Y [@ID] [Description]")
    printInfo("Available |cffffff00Waypoint|r commands:")
    printInfo("/way - List all waypoints")
    printInfo("/way me - Show current location")
    printInfo("/way clear - Clear all waypoints")
    printInfo("/way remove [ID] - Remove a waypoint")
    printInfo("/way goto [ID] - Track a waypoint")
  end
end

-- Initialize the addon
local function Initialize()
  -- Only load if TomTom is not present
  -- if IsAddOnLoaded("TomTom") or (_G.TomTom ~= nil) then
  --   printError("TomTom is detected. |cffffff00Waypoint|r addon will not be loaded.")
  --   return
  -- end
  
  -- Register the slash command
  SLASH_WAYPOINT1 = "/way"
  SlashCmdList["WAYPOINT"] = Waypoint
end

-- Register initialization event
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    Initialize()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
end)

-- Publish the whole thing
_G.Waypoint = WP
