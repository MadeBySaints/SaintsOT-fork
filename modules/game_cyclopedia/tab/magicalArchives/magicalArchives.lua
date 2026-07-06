local UI = nil
local allSpells = {}
local selectedRow = nil

function showMagicalArchives()
    UI = g_ui.loadUI("magicalArchives", contentContainer)
    if not UI then return end
    UI:show()

    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end

    allSpells = Spells.getSpellList() or {}

    -- Vocation Filter
    local vocCombo = UI.InformationBase.VocationFilter
    if vocCombo then
        vocCombo:clearOptions()
        vocCombo:addOption("All Vocations", 0)
        for id, name in pairs(VocationNames) do
            if name then vocCombo:addOption(name, id) end
        end
        vocCombo.onOptionChange = filterSpells
    end

    -- Custom Group Filter (as requested)
    local groupCombo = UI.InformationBase.GroupFilter
    if groupCombo then
        groupCombo:clearOptions()
        groupCombo:addOption("All Types", "")
        groupCombo:addOption("Attack", "Attack")
        groupCombo:addOption("Healing", "Healing")
        groupCombo:addOption("Support", "Support")
        groupCombo:addOption("Conjure", "Conjure")
        groupCombo:addOption("Instant", "Instant")
        groupCombo:addOption("Rune", "Rune")
        groupCombo.onOptionChange = filterSpells
    end

    -- Search
    if UI.InformationBase.SearchEdit then
        UI.InformationBase.SearchEdit.onTextChange = filterSpells
    end

    filterSpells()
end

function populateSpellList(spells)
    local area = UI.InformationBase.SpellListBase.SpellList
    if not area then return end

    area:destroyChildren()
    selectedRow = nil

    for _, spell in ipairs(spells) do
        -- IMPORTANT: a plain UIWidget does not render text at all (no Label
        -- code in its drawSelf). Use Label instead so the row is actually
        -- visible AND so it reports a real, non-zero height/width to the
        -- verticalBox layout -- this is what makes scrolling work.
        local widget = g_ui.createWidget("Label", area)
        widget:setText(spell.name .. " (Lvl " .. (spell.level or 0) .. ")")
        widget:setHeight(26)
        widget:setWidth(area:getWidth())
        widget:setTextAlign(AlignLeft)
        widget:setColor("#dfdfdf")
        widget:setBackgroundColor("#2a2a2a")
        widget:setPhantom(false)
        widget:setPadding(6)
        widget.spellData = spell

        function widget:onClick()
            if selectedRow then
                selectedRow:setBackgroundColor("#2a2a2a")
            end
            self:setBackgroundColor("#454545")
            selectedRow = self
            showSpellDetails(self.spellData)
        end

        function widget:onHoverChange(hovered)
            if self ~= selectedRow then
                self:setBackgroundColor(hovered and "#3a3a3a" or "#2a2a2a")
            end
        end
    end
end

function filterSpells()
    local searchText = UI.InformationBase.SearchEdit and UI.InformationBase.SearchEdit:getText():lower():trim() or ""

    local selectedVoc = 0
    local vocCombo = UI.InformationBase.VocationFilter
    if vocCombo then
        local opt = vocCombo:getCurrentOption()
        if opt then selectedVoc = opt.data or 0 end
    end

    local selectedGroup = ""
    local groupCombo = UI.InformationBase.GroupFilter
    if groupCombo then
        local opt = groupCombo:getCurrentOption()
        if opt then selectedGroup = opt.data or "" end
    end

    local filtered = {}
    for _, spell in ipairs(allSpells) do
        local matchSearch = (searchText == "") or 
            spell.name:lower():find(searchText) or 
            (spell.words and spell.words:lower():find(searchText))

        local matchVoc = (selectedVoc == 0) or table.contains(spell.vocations or {}, selectedVoc)

        local matchGroup = true
        if selectedGroup ~= "" then
            local spellType = spell.type or ""
            if selectedGroup == "Rune" then
                -- The spell data has no dedicated "is this a rune" flag --
                -- clientId is a spell-icon sprite index, not an item id, so
                -- it can't tell runes apart from other Conjure spells (ammo
                -- conjures, wand/staff enchants, etc). The only consistent
                -- signal in this data set is the name ending in "Rune".
                matchGroup = (spellType == "Conjure" and spell.name:lower():find("rune$") ~= nil)
            elseif selectedGroup == "Conjure" then
                matchGroup = (spellType == "Conjure")
            elseif selectedGroup == "Instant" then
                matchGroup = (spellType == "Instant")
            elseif selectedGroup == "Attack" then
                matchGroup = spellType == "Instant" and spell.group and spell.group[1]
            elseif selectedGroup == "Healing" then
                matchGroup = spellType == "Instant" and spell.group and spell.group[2]
            elseif selectedGroup == "Support" then
                matchGroup = spellType == "Instant" and spell.group and spell.group[3]
            end
        end

        if matchSearch and matchVoc and matchGroup then
            table.insert(filtered, spell)
        end
    end

    populateSpellList(filtered)
end

function showSpellDetails(spell)
    if not spell or not UI.spellAndRune then return end
    local panel = UI.spellAndRune

    if panel.SpellIcon then
        -- spell.clientId is NOT an item id -- it's an index into the spell
        -- icon spritesheet (/images/game/spells/spell-icons-32x32), used via
        -- Spells.getImageClip(). UIItem:setItemId was the wrong call entirely;
        -- this is a plain image-clip lookup, same as the real Cyclopedia spell
        -- list and the in-game spellbook use.
        local clip = Spells.getImageClip(spell.clientId or 0, "Default")
        panel.SpellIcon:setImageClip(clip)
        panel.SpellIcon:setVisible(true)
    end
    if panel.SpellName then panel.SpellName:setText(spell.name) end
    if panel.Formula then panel.Formula:setText("Formula: " .. (spell.words or "—")) end
    if panel.LevelInfo then panel.LevelInfo:setText("Level: " .. (spell.level or 0)) end
    if panel.ManaInfo then panel.ManaInfo:setText("Mana: " .. (spell.mana or 0)) end
    if panel.SoulInfo then panel.SoulInfo:setText("Soul: " .. (spell.soul or 0)) end
    if panel.TypeInfo then panel.TypeInfo:setText("Type: " .. (spell.type or "Unknown")) end
end