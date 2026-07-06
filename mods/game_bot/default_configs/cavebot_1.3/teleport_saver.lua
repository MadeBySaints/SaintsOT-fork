-- Saved Teleports tab
-- Save your current position (optionally with the monster you're currently
-- attacking/targeting shown as a portrait) and recall it later with one click.
setDefaultTab("X,Y,Z")

if type(storage.savedTeleports) ~= "table" then
  storage.savedTeleports = {}
end

local titleLabel = UI.Label("Save current position")
titleLabel:setFont("verdana-9px-rounded")

local newTeleportName = UI.TextEdit("", function(widget, text)
  storage.newTeleportName = text
end)
newTeleportName:setText(storage.newTeleportName or "")

local listPanelOuter = UI.createWidget("BotPanel")
listPanelOuter:setHeight(300)
local listPanel = listPanelOuter.content

local refreshList

local removeTeleport = function(index)
  table.remove(storage.savedTeleports, index)
  refreshList()
end

local goToTeleport = function(entry)
  say(string.format("!pos %d, %d, %d", entry.x, entry.y, entry.z))
end

refreshList = function()
  listPanel:destroyChildren()
  for index, entry in ipairs(storage.savedTeleports) do
    local rowOtml = [[
Panel
  height: 36
  margin-top: 2

  UICreature
    id: creature
    phantom: true
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    size: 32 32
    image-source: /images/ui/panel_flat
    image-border: 1

  Label
    id: name
    anchors.left: prev.right
    anchors.top: parent.top
    anchors.right: parent.right
    margin-left: 6
    margin-right: 46
    text-auto-resize: true
    text-wrap: true
    height: 16

  Label
    id: coords
    anchors.left: prev.left
    anchors.top: prev.bottom
    font: verdana-11px-rounded
    color: #aaaaaa
    text-auto-resize: true
    height: 14

  BotButton
    id: go
    !text: tr('Go')
    anchors.top: parent.top
    anchors.right: parent.right
    width: 40
    height: 17
    margin-top: 0

  BotButton
    id: remove
    !text: tr('X')
    anchors.top: prev.bottom
    anchors.right: parent.right
    width: 40
    height: 17
    margin-top: 2
    image-color: #cc4444
]]
    local row = setupUI(rowOtml, listPanel)

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

    row.go:setImageColor("#4caf50") -- green
    row.go.onClick = function()
      goToTeleport(entry)
    end

    row.remove:setImageColor("#f44336") -- red
    row.remove.onClick = function()
      removeTeleport(index)
    end

    UI.Separator(listPanel)
  end
end

UI.Button("Save Current Position", function()
  local name = storage.newTeleportName
  if not name or name:len() == 0 then
    warn("Enter a name for the teleport first.")
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

UI.Separator()

refreshList()
