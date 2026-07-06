-- Imbuement Materials Tool
-- Gives 300 of every imbuement crafting material via the /i command, then
-- immediately stashes it (mode 2: stow all of this type) so it never has to
-- sit in a backpack. You must be near a depot/stash for this to work -
-- same requirement as the in-game right-click "Stow" option.
setDefaultTab("Stash")

-- name -> real item id, cross-checked against this server's items.xml
local stashThis = {
  { name = "green dragon leather",     id = 5877 },
  { name = "green dragon scale",       id = 5920 },
  { name = "demon horn",               id = 5954 },
  { name = "bloody pincers",           id = 9633 },
  { name = "elvish talisman",          id = 9635 },
  { name = "fiery heart",              id = 9636 },
  { name = "cultish mask",             id = 9638 },
  { name = "cultish robe",             id = 9639 },
  { name = "poisonous slime",          id = 9640 },
  { name = "piece of scarab shell",    id = 9641 },
  { name = "wyvern talisman",          id = 9644 },
  { name = "demonic skeletal hand",    id = 9647 },
  { name = "polar bear paw",           id = 9650 },
  { name = "war crystal",              id = 9654 },
  { name = "cyclops toe",              id = 9657 },
  { name = "mystical hourglass",       id = 9660 },
  { name = "frosty heart",             id = 9661 },
  { name = "piece of dead brain",      id = 9663 },
  { name = "wyrm scale",               id = 9665 },
  { name = "vampire teeth",            id = 9685 },
  { name = "swamp grass",              id = 9686 },
  { name = "ghostly tissue",           id = 9690 },
  { name = "lion's mane",              id = 9691 },
  { name = "snake skin",               id = 9694 },
  { name = "orc tooth",                id = 10196 },
  { name = "tarantula egg",            id = 10281 },
  { name = "winter wolf fur",          id = 10295 },
  { name = "metal spike",              id = 10298 },
  { name = "compass",                  id = 10302 },
  { name = "hellspawn tail",           id = 10304 },
  { name = "thick fur",                id = 10307 },
  { name = "strand of medusa hair",    id = 10309 },
  { name = "sabretooth",               id = 10311 },
  { name = "warmaster's wristguards",  id = 10405 },
  { name = "petrified scream",         id = 10420 },
  { name = "protective charm",         id = 11444 },
  { name = "battle stone",             id = 11447 },
  { name = "broken shamanic staff",    id = 11452 },
  { name = "elven scouting glass",     id = 11464 },
  { name = "flask of embalming fluid", id = 11466 },
  { name = "pile of grave earth",      id = 11484 },
  { name = "mantassin tail",           id = 11489 },
  { name = "rope belt",                id = 11492 },
  { name = "draken sulphur",           id = 11658 },
  { name = "brimstone fangs",          id = 11702 },
  { name = "brimstone shell",          id = 11703 },
  { name = "deepling warts",           id = 14012 },
  { name = "crawler head plating",     id = 14079 },
  { name = "waspoid wing",             id = 14081 },
  { name = "blazing bone",             id = 16131 },
  { name = "17458",                    id = 17458 }, --damselfly wing
  { name = "piece of swampling wood",  id = 17823 },
  { name = "rorc feather",             id = 18993 },
  { name = "elven hoof",               id = 18994 },
  { name = "frazzle skin",             id = 20199 },
  { name = "silencer claws",           id = 20200 },
  { name = "goosebump leather",        id = 20205 },
  { name = "slime heart",              id = 21194 },
  { name = "moohtant horn",            id = 21200 },
  { name = "mooh'tah shell",           id = 21202 },
  { name = "seacrest hair",            id = 21801 },
  { name = "peacock feather fan",      id = 21975 },
  { name = "gloom wolf fur",           id = 22007 },
  { name = "wereboar hooves",          id = 22053 },
  { name = "ogre nose ring",           id = 22189 },
  { name = "vexclaw talon",            id = 22728 },
  { name = "some grimeleech wings",    id = 22730 },
  { name = "crystallized anger",       id = 23507 },
  { name = "fairy wings",              id = 25694 },
  { name = "little bowl of myrrh",     id = 25702 },
  { name = "quill",                    id = 28567 },
  { name = "gold-brocaded cloth",      id = 40529 },
}

UI.Label("Admin Stasher")
UI.Label("" .. #stashThis .. " items loaded")
UI.Label("MUST STAND NEAR DEPOT")
UI.Label("Green = stash")
UI.Label("Red = skip")

-- persisted on/off state per item, defaults to all-on (green)
-- NOTE: keys are stringified (tostring(id)) because storage round-trips
-- through JSON, which only supports string object keys - using numeric
-- ids directly here would silently reset every choice after a reload.
if type(storage.imbuementItemEnabled) ~= "table" then
  storage.imbuementItemEnabled = {}
end
for _, entry in ipairs(stashThis) do
  local key = tostring(entry.id)
  if storage.imbuementItemEnabled[key] == nil then
    storage.imbuementItemEnabled[key] = true
  end
end

-- persisted amount-to-give, plus separate cooldowns for the give step and
-- the stash step, with sane defaults
if type(storage.imbuementGiveAmount) ~= "number" then
  storage.imbuementGiveAmount = 300
end
if type(storage.imbuementGiveCooldownMs) ~= "number" then
  storage.imbuementGiveCooldownMs = 300
end
if type(storage.imbuementStashCooldownMs) ~= "number" then
  storage.imbuementStashCooldownMs = 500
end
if storage.imbuementStashCooldownMs < 500 then
  storage.imbuementStashCooldownMs = 500
end

local settingsRow = setupUI([[
Panel
  height: 68

  Label
    id: amountLabel
    !text: tr('Amount of each:')
    anchors.left: parent.left
    anchors.top: parent.top
    width: 110

  BotTextEdit
    id: amount
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: parent.top

  Label
    id: giveCooldownLabel
    !text: tr('Cooldown-Item (ms):')
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 4
    width: 120

  BotTextEdit
    id: giveCooldown
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top

  Label
    id: stashCooldownLabel
    !text: tr('Cooldown-Stow (ms):')
    anchors.left: parent.left
    anchors.top: prev.bottom
    margin-top: 4
    width: 120

  BotTextEdit
    id: stashCooldown
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: prev.top
]])

local giveMacro -- forward declare; assigned further down

settingsRow.amount:setText(tostring(storage.imbuementGiveAmount))
settingsRow.amount.onTextChange = function(widget, text)
  local n = tonumber(text)
  if n and n > 0 then
    storage.imbuementGiveAmount = math.floor(n)
  end
end

settingsRow.giveCooldown:setText(tostring(storage.imbuementGiveCooldownMs))
settingsRow.giveCooldown.onTextChange = function(widget, text)
  local n = tonumber(text)
  if n and n >= 0 then
    storage.imbuementGiveCooldownMs = math.floor(n)
  end
end

settingsRow.stashCooldown:setText(tostring(storage.imbuementStashCooldownMs))
settingsRow.stashCooldown.onTextChange = function(widget, text)
  local n = tonumber(text)
  if n and n >= 0 then
    -- the server itself rejects stash actions sooner than 500ms apart
    -- ("You need to wait to do this again") - going lower just causes
    -- silent misses, so this is clamped rather than configurable.
    if n < 500 then
      n = 500
      widget:setText("500")
      warn("Stash cooldown can't go below 500ms - the server itself enforces that minimum.")
    end
    storage.imbuementStashCooldownMs = math.floor(n)
  end
end

UI.Separator()

local searchRow = setupUI([[
Panel
  height: 20
  margin-top: 2

  Label
    id: searchLabel
    !text: tr('Search:')
    anchors.left: parent.left
    anchors.top: parent.top
    width: 60

  BotTextEdit
    id: search
    anchors.left: prev.right
    anchors.right: parent.right
    anchors.top: parent.top
]])

local enableAllButton = UI.Button("Enable All", function() end)
enableAllButton:setImageColor("#4caf50")

local disableAllButton = UI.Button("Disable All", function() end)
disableAllButton:setImageColor("#f44336")

UI.Separator()

local listPanelOuter = UI.createWidget("BotPanel")
listPanelOuter:setHeight(520)
local listPanel = listPanelOuter.content

local rowOtml = [[
Panel
  height: 60
  margin-top: 4

  BotItem
    id: icon
    size: 34 34
    anchors.left: parent.left
    anchors.top: parent.top

  Label
    id: name
    anchors.left: prev.right
    anchors.top: parent.top
    anchors.right: parent.right
    margin-left: 6
    text-auto-resize: false
    text-wrap: true
    height: 34

  BotButton
    id: toggle
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 2
    height: 18
]]

local GREEN = "#4caf50"
local RED = "#f44336"

local rows = {} -- entry, row widget, applyState fn - used by search filter and enable/disable all

for _, entry in ipairs(stashThis) do
  local row = setupUI(rowOtml, listPanel)
  row.icon:setItem(Item.create(entry.id, 1))
  row.name:setText(entry.name)

  local key = tostring(entry.id)

  local applyState = function(enabled)
    row.toggle:setText(enabled and "Give" or "Skip")
    row.toggle:setImageColor(enabled and GREEN or RED)
  end

  applyState(storage.imbuementItemEnabled[key])

  row.toggle.onClick = function()
    local newState = not storage.imbuementItemEnabled[key]
    storage.imbuementItemEnabled[key] = newState
    applyState(newState)
  end

  table.insert(rows, { entry = entry, widget = row, applyState = applyState, key = key })
end

enableAllButton.onClick = function()
  for _, r in ipairs(rows) do
    storage.imbuementItemEnabled[r.key] = true
    r.applyState(true)
  end
end

disableAllButton.onClick = function()
  for _, r in ipairs(rows) do
    storage.imbuementItemEnabled[r.key] = false
    r.applyState(false)
  end
end

searchRow.search.onTextChange = function(widget, text)
  local query = text:lower()
  for _, r in ipairs(rows) do
    if query == "" or r.entry.name:lower():find(query, 1, true) then
      r.widget:setVisible(true)
    else
      r.widget:setVisible(false)
    end
  end
end

UI.Separator()

-- find any item with this id currently in an open container (your backpack)
local findItemById = function(itemId)
  for _, container in pairs(g_game.getContainers()) do
    for _, item in ipairs(container:getItems()) do
      if item:getId() == itemId then
        return item
      end
    end
  end
  return nil
end

-- step: 1 = waiting to send /i, 2 = waiting out the stash cooldown before
-- attempting to stash, 3 = stashing/retrying, 4 = waiting out the give
-- cooldown before moving to the next item
--
-- The macro itself ticks at a fixed 50ms (the bot engine's own hard floor -
-- "min timeout is 50, to avoid lags" - going lower has no effect), so both
-- cooldowns are tracked separately via waitUntil and actually respected down
-- to 50ms, rather than being limited by the macro's own poll rate.
local giveIndex = nil
local step = 1
local retriesLeft = 0
local waitUntil = 0

giveMacro = macro(50, function()
  if giveIndex == nil then return end

  if step == 1 then
    giveIndex = giveIndex + 1
    while giveIndex <= #stashThis and not storage.imbuementItemEnabled[tostring(stashThis[giveIndex].id)] do
      giveIndex = giveIndex + 1
    end
    if giveIndex > #stashThis then
      giveIndex = nil
      step = 1
      return
    end
    say("/i " .. stashThis[giveIndex].name .. ", " .. storage.imbuementGiveAmount)
    waitUntil = now + storage.imbuementStashCooldownMs
    retriesLeft = 60 -- extra safety retries if the item still isn't there after the stash cooldown (~3s at 50ms/tick)
    step = 2
    return
  end

  if step == 2 then
    if now < waitUntil then return end
    step = 3
    -- fall through to step 3 immediately this tick
  end

  if step == 3 then
    local entry = stashThis[giveIndex]
    local item = findItemById(entry.id)
    if item then
      g_game.stashStowItem(item:getPosition(), item:getId(), 0, item:getStackPos(), 2)
      waitUntil = now + storage.imbuementGiveCooldownMs
      step = 4
    else
      retriesLeft = retriesLeft - 1
      if retriesLeft <= 0 then
        warn("Couldn't find " .. entry.name .. " to stash after ~3s - check your backpack.")
        waitUntil = now + storage.imbuementGiveCooldownMs
        step = 4
      end
      -- otherwise stay on step 3 and try again next tick (50ms later)
    end
    return
  end

  -- step == 4: waiting out the give cooldown before moving to the next item
  if now < waitUntil then return end
  step = 1
end)
giveMacro.setOn(true)

UI.Button("Stash selected items", function()
  if not player:isSupplyStashAvailable() then
    warn("You must be near a depot.")
    return
  end
  if giveIndex == nil then
    giveIndex = 0
    step = 1
  end
end)

-- Stash Current: sweeps whatever enabled items you already have in your
-- backpack right now and stashes them, without giving anything new. Uses
-- its own simple index/cooldown state, separate from the give+stash macro
-- above, since there's no "wait for delivery" step needed here.
local stashCurrentIndex = nil
local stashCurrentWaitUntil = 0

local stashCurrentMacro = macro(50, function()
  if stashCurrentIndex == nil then return end
  if now < stashCurrentWaitUntil then return end

  stashCurrentIndex = stashCurrentIndex + 1
  while stashCurrentIndex <= #stashThis and not storage.imbuementItemEnabled[tostring(stashThis[stashCurrentIndex].id)] do
    stashCurrentIndex = stashCurrentIndex + 1
  end
  if stashCurrentIndex > #stashThis then
    stashCurrentIndex = nil
    return
  end

  local entry = stashThis[stashCurrentIndex]
  local item = findItemById(entry.id)
  if item then
    g_game.stashStowItem(item:getPosition(), item:getId(), 0, item:getStackPos(), 2)
  end
  -- no warning if not found here - "stash current" expects many items to
  -- simply not be present, unlike the give flow where absence is an error
  stashCurrentWaitUntil = now + storage.imbuementStashCooldownMs
end)
stashCurrentMacro.setOn(true)

UI.Button("Stash Current", function()
  if not player:isSupplyStashAvailable() then
    warn("You must be near a depot.")
    return
  end
  if stashCurrentIndex == nil then
    stashCurrentIndex = 0
    stashCurrentWaitUntil = 0
  end
end)

UI.Separator()