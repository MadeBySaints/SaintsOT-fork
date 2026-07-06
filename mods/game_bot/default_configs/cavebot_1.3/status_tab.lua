-- Status tab
-- Toggle auto-cure for poison/burning/energy/curse/bleeding/paralyze.
-- Each toggle casts whatever spell text you put in its box, the moment that
-- condition is detected, regardless of combat state.
setDefaultTab("Status")

-- conditions table: key = storage key, label = display name, checkFn = sandbox helper, default spell
-- vocation notes come straight from this server's actual cure_*.lua spell scripts
local conditionDefs = {
  { key = "poison",   label = "Poison (All)",            checkFn = isPoisioned, default = "exana pox" },
  { key = "burning",  label = "Burning (Druid only)",     checkFn = isBurning,   default = "exana flam" },
  { key = "energy",   label = "Energy (Druid only)",      checkFn = isEnergized, default = "exana vis" },
  { key = "curse",    label = "Curse (Paladin only)",     checkFn = isCursed,    default = "exana mort" },
  { key = "bleeding", label = "Bleeding (Druid/Knight)",   checkFn = isBleeding,  default = "exana kor" },
  { key = "paralyze", label = "Paralyze (All - Haste)",    checkFn = isParalyzed, default = "utani hur" },
}

if type(storage.statusCures) ~= "table" then
  storage.statusCures = {}
end

for _, def in ipairs(conditionDefs) do
  if type(storage.statusCures[def.key]) ~= "table" then
    storage.statusCures[def.key] = { on = false, text = def.default }
  end
end

local rowOtml = [[
Panel
  height: 42
  margin-top: 4

  BotSwitch
    id: toggle
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    text-align: center

  BotTextEdit
    id: spell
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: prev.bottom
    margin-top: 3
]]

for _, def in ipairs(conditionDefs) do
  local row = setupUI(rowOtml)
  local cure = storage.statusCures[def.key]

  row.toggle:setText(def.label)
  row.toggle:setOn(cure.on)
  row.toggle.onClick = function()
    cure.on = not cure.on
    row.toggle:setOn(cure.on)
  end

  row.spell:setText(cure.text)
  row.spell.onTextChange = function(widget, text)
    cure.text = text
  end
end

UI.Separator()

for _, def in ipairs(conditionDefs) do
  local cure = storage.statusCures[def.key]
  local lastCast = 0
  local conditionMacro = macro(200, function()
    if cure.on and def.checkFn() and cure.text and cure.text:len() > 0 then
      if now - lastCast >= 2000 then
        say(cure.text)
        lastCast = now
      end
    end
  end)
  conditionMacro.setOn(true)
end