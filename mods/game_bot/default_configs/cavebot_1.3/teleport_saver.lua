-- Saved Teleports tool
-- Adds a panel to save your current position (optionally with the monster
-- you're currently attacking/targeting shown as a portrait) and recall it
-- later with a single click, the same way the !pos buttons work.
--
-- Saved entries persist in storage.savedTeleports across reloads/restarts.

importStyle("/teleport_saver.otui")

if type(storage.savedTeleports) ~= "table" then
  storage.savedTeleports = {}
end

UI.Separator()
UI.Label("Saved Teleports")

local newTeleportName = UI.TextEdit("", function(widget, text)
  storage.newTeleportName = text
end)
newTeleportName:setText(storage.newTeleportName or "")

local teleportList -- forward declare, assigned after refreshList is defined

local refreshList

local removeTeleport = function(index)
  table.remove(storage.savedTeleports, index)
  refreshList()
end

local goToTeleport = function(entry)
  say(string.format("!pos %d, %d, %d", entry.x, entry.y, entry.z))
end

refreshList = function()
  teleportList:destroyChildren()
  for index, entry in ipairs(storage.savedTeleports) do
    local row = g_ui.createWidget("SavedTeleportEntry", teleportList)
    row.botWidget = true

    row.name:setText(entry.name)
    row.coords:setText(string.format("%d, %d, %d", entry.x, entry.y, entry.z))

    if entry.outfit then
      local ok = pcall(function()
        row.creature:setOutfit(entry.outfit)
      end)
      if not ok then
        row.creature:setImageSource("/images/ui/panel_flat")
      end
    end

    row.go.onClick = function()
      goToTeleport(entry)
    end

    row.remove.onClick = function()
      removeTeleport(index)
    end
  end
end

UI.Button("Save Current Position", function()
  local name = storage.newTeleportName
  if not name or name:len() == 0 then
    displayFailureMessage("Enter a name for the teleport first.")
    return
  end

  local pos = player:getPosition()
  if not pos then
    return
  end

  local entry = {
    name = name,
    x = pos.x,
    y = pos.y,
    z = pos.z,
  }

  local target = g_game.getAttackingCreature()
  if target then
    local ok, outfit = pcall(function() return target:getOutfit() end)
    if ok then
      entry.outfit = outfit
    end
  end

  table.insert(storage.savedTeleports, entry)

  storage.newTeleportName = ""
  newTeleportName:setText("")

  refreshList()
end)

teleportList = UI.createWidget("SavedTeleportListPanel")
teleportList = teleportList.list -- the scrollable inner panel that holds rows

refreshList()
