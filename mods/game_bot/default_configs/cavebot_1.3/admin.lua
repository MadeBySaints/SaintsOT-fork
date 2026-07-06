-- Admin Tab
-- Quality-of-life admin functions in one place.
setDefaultTab("Admin")

UI.Label("Admin Tools")
UI.Separator()

-- ============================================================
-- ITEM FINDER
-- Search any item by name, then give it to yourself or drop
-- it on the tile directly in front of you.
-- ============================================================

UI.Label("Item Finder")

if type(storage.adminGiveAmount) ~= "number" then
  storage.adminGiveAmount = 1
end

local amountRow = setupUI([[
Panel
  height: 20

  Label
    id: label
    !text: tr('Amount:')
    anchors.left: parent.left
    anchors.top: parent.top
    width: 70

  BotTextEdit
    id: amount
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: parent.top
]])

amountRow.amount:setText(tostring(storage.adminGiveAmount))
amountRow.amount.onTextChange = function(widget, text)
  local n = tonumber(text)
  if n and n > 0 then
    storage.adminGiveAmount = math.floor(n)
  end
end

local searchRow = setupUI([[
Panel
  height: 20
  margin-top: 4

  Label
    id: label
    !text: tr('Search item:')
    anchors.left: parent.left
    anchors.top: parent.top
    width: 80

  BotTextEdit
    id: search
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: parent.top
]])

local GREEN = "#4caf50"
local SELECTED_BG = "#3a5a3a"
local UNSELECTED_BG = "#00000000"

local selectedItemEntry = nil
local selectedItemRow = nil

local giveButton = UI.Button("Give to inventory", function()
  if not selectedItemEntry then
    warn("Search and select an item first.")
    return
  end
  say("/i " .. selectedItemEntry.name .. ", " .. storage.adminGiveAmount)
end)
giveButton:setEnabled(false)

local dropButton = UI.Button("Drop in front (/idrop)", function()
  if not selectedItemEntry then
    warn("Search and select an item first.")
    return
  end
  say("/idrop " .. selectedItemEntry.name .. ", " .. storage.adminGiveAmount)
end)
dropButton:setEnabled(false)

local itemListOuter = UI.createWidget("BotPanel")
itemListOuter:setHeight(200)
local itemList = itemListOuter.content

local rowOtml = [[
Panel
  height: 38
  margin-top: 2
  phantom: false

  BotItem
    id: icon
    size: 34 34
    phantom: true
    draggable: false
    anchors.left: parent.left
    anchors.top: parent.top

  Label
    id: name
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    margin-left: 6
    text-auto-resize: false
    text-wrap: false
    phantom: true
    text-align: left
]]

local clearItemSelection = function()
  if selectedItemRow then
    selectedItemRow:setBackgroundColor(UNSELECTED_BG)
  end
  selectedItemEntry = nil
  selectedItemRow = nil
  giveButton:setEnabled(false)
  giveButton:setImageColor("#ffffff")
  dropButton:setEnabled(false)
  dropButton:setImageColor("#ffffff")
end

local selectItemRow = function(row, entry)
  if selectedItemRow then
    selectedItemRow:setBackgroundColor(UNSELECTED_BG)
  end
  row:setBackgroundColor(SELECTED_BG)
  selectedItemRow = row
  selectedItemEntry = entry
  giveButton:setEnabled(true)
  giveButton:setImageColor(GREEN)
  dropButton:setEnabled(true)
  dropButton:setImageColor(GREEN)
end

local buildItemResults = function(query)
  clearItemSelection()
  itemList:destroyChildren()
  if not query or query:len() < 2 then return end

  query = query:lower()
  local count = 0
  for _, entry in ipairs(allItems) do
    if entry.name:lower():find(query, 1, true) then
      local row = setupUI(rowOtml, itemList)
      row:setBackgroundColor(UNSELECTED_BG)
      row.icon:setItem(Item.create(entry.id, 1))
      row.name:setText(entry.name)
      row.onClick = function()
        selectItemRow(row, entry)
        return true
      end
      count = count + 1
      if count >= 50 then break end
    end
  end
end

searchRow.search.onTextChange = function(widget, text)
  buildItemResults(text)
end

UI.Separator()

-- ============================================================
-- BATTLE LIST → TARGETBOT
-- Reads every monster currently visible on screen, deduplicates
-- by name, and adds each to TargetBot with exori kor + best
-- area rune based on elemental weakness data.
-- ============================================================

UI.Label("Battle List -> TargetBot")

UI.Button("Copy battle list to TargetBot", function()
  if not TargetBot or not TargetBot.Creature then
    warn("TargetBot is not loaded.")
    return
  end

  local mapPanel = modules.game_interface.getMapPanel()
  if not mapPanel then
    warn("Map panel not available.")
    return
  end

  local spectators = mapPanel:getSpectators()
  local seenNames = {}
  local added = 0

  local existingNames = {}
  if TargetBot.targetList then
    for _, widget in ipairs(TargetBot.targetList:getChildren()) do
      if widget.value and widget.value.name then
        existingNames[widget.value.name:lower()] = true
      end
    end
  end

  for _, creature in ipairs(spectators) do
    if not creature:isLocalPlayer() and not creature:isDead() and creature:isMonster() then
      local name = creature:getName()
      if name and name:len() > 0 then
        local nameLower = name:lower()
        if not seenNames[nameLower] and not existingNames[nameLower] then
          seenNames[nameLower] = true

          local runeId = 0
          local useGroupRune = false
          if monsterWeaknessRunes and monsterWeaknessRunes[nameLower] then
            runeId = monsterWeaknessRunes[nameLower]
            useGroupRune = true
          end

          TargetBot.Creature.addConfig({
            name = name,
            priority = 1,
            danger = 1,
            maxDistance = 10,
            keepDistanceRange = 1,
            lureCount = 1,
            chase = false,
            keepDistance = false,
            dontLoot = false,
            lure = false,
            lureCavebot = false,
            avoidAttacks = false,
            useSpellAttack = true,
            attackSpell = "exori kor",
            minMana = 0,
            attackSpellDelay = 2500,
            useRuneAttack = false,
            attackRune = 0,
            runeAttackDelay = 200,
            useGroupAttack = false,
            groupAttackSpell = "",
            minManaGroup = 0,
            groupAttackTargets = 1,
            groupAttackRadius = 1,
            groupAttackDelay = 200,
            groupAttackIgnorePlayers = false,
            groupAttackIgnoreParty = false,
            useGroupAttackRune = useGroupRune,
            groupAttackRune = runeId,
            groupRuneAttackTargets = 1,
            groupRuneAttackRadius = 1,
            groupRuneAttackDelay = 200,
          })
          added = added + 1
        end
      end
    end
  end

  TargetBot.save()

  if added > 0 then
    warn("Added " .. added .. " creature(s) to TargetBot.")
  else
    warn("No new creatures found on screen (already added or none visible).")
  end
end)

UI.Separator()

-- ============================================================
-- FORGE QUICK ACCESS
-- Uses existing forge_functions.lua commands:
-- /adddusts name, amount  - adds dust (capped at current level)
-- /adddustlevel name, N   - upgrades dust capacity
-- /openforge              - refreshes forge window to show new cap
-- /fiendish / /influenced - teleport to forge monsters
-- ============================================================

UI.Label("Forge Tools")

if type(storage.adminDustAmount) ~= "number" then
  storage.adminDustAmount = 100
end

local dustRow = setupUI([[
Panel
  height: 20
  margin-top: 4

  Label
    id: label
    !text: tr('Dust amount:')
    anchors.left: parent.left
    anchors.top: parent.top
    width: 90

  BotTextEdit
    id: amount
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: parent.top
]])

dustRow.amount:setText(tostring(storage.adminDustAmount))
dustRow.amount.onTextChange = function(widget, text)
  local n = tonumber(text)
  if n then
    storage.adminDustAmount = math.floor(n)
  end
end

UI.Button("Teleport to nearest fiendish", function()
  say("/fiendish")
end)

UI.Button("Teleport to nearest influenced", function()
  say("/influenced")
end)

UI.Button("Add dust", function()
  if storage.adminDustAmount == 0 then
    warn("Dust amount is 0.")
    return
  end
  say("/adddusts " .. g_game.getCharacterName() .. ", " .. storage.adminDustAmount)
end)

UI.Separator()

-- ============================================================
-- BOSS TELEPORTS
-- One-click /pos teleport to specific boss rooms.
-- ============================================================

UI.Label("Boss Teleports")

UI.Button("Soul of Dragonking Zyrtarch", function()
  say("/pos 33391, 31178, 10")
end)

UI.Separator()