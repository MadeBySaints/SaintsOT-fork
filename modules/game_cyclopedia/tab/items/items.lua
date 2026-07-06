Cyclopedia.Items = {}
Cyclopedia.Items.currentItemId = nil

-- Additional variables for new features
local itemsData = {}
local lastSelectedItem = nil
local lastSelectedItemId = nil
local oldBuyChild = nil
local oldSaleChild = nil

-- =============== NEW HELPER FUNCTION ===============
local function getItemFromWidget(widget)
    if not widget then
        return nil
    end
    
    -- Primary method
    if widget.Sprite and widget.Sprite.getItem then
        local item = widget.Sprite:getItem()
        if item then
            return item
        end
    end
    
    -- Alternative 1: get child by id
    local spriteChild = widget:getChildById("Sprite")
    if spriteChild and spriteChild.getItem then
        local item = spriteChild:getItem()
        if item then
            return item
        end
    end
    
    -- Alternative 2: fallback using widget ID
    local itemId = tonumber(widget:getId())
    if itemId and itemId > 0 then
        return Item.create(itemId)
    end
    
    return nil
end
-- ===================================================

local function getItemWidgetId(widget)
    if not widget then
        return nil
    end
    if widget.getId then
        return tonumber(widget:getId())
    end
    return tonumber(widget.id)
end

Cyclopedia.CategoryItems = {
    { id = 1, name = "Armors" },
    { id = 2, name = "Amulets" },
    { id = 3, name = "Boots" },
    { id = 4, name = "Containers" },
    { id = 24, name = "Creature Products" },
    { id = 5, name = "Decoration" },
    { id = 6, name = "Food" },
    { id = 30, name = "Gold" },
    { id = 7, name = "Helmets and Hats" },
    { id = 8, name = "Legs" },
    { id = 9, name = "Others" },
    { id = 10, name = "Potions" },
    { id = 25, name = "Quivers" },
    { id = 11, name = "Rings" },
    { id = 12, name = "Runes" },
    { id = 13, name = "Shields" },
    { id = 26, name = "Soul Cores" },
    { id = 14, name = "Tools" },
    { id = 31, name = "Unsorted" },
    { id = 15, name = "Valuables" },
    { id = 16, name = "Weapons: Ammo" },
    { id = 17, name = "Weapons: Axe" },
    { id = 18, name = "Weapons: Clubs" },
    { id = 19, name = "Weapons: Distance" },
    { id = 20, name = "Weapons: Swords" },
    { id = 21, name = "Weapons: Wands" },
    { id = 1000, name = "Weapons: All" }
}

local UI = nil

focusCategoryList = nil

-- JSON Data Management Functions
function Cyclopedia.Items.terminate()
	Cyclopedia.Items.saveJson()
end

function Cyclopedia.Items.loadJson()
	if not LoadedPlayer or not LoadedPlayer:isLoaded() then
		return true
	end

	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/itemprices.json"
	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			g_logger.error("Error while reading characterdata file. Details: " .. result)
			itemsData = {
				["primaryLootValueSources"] = {},
				["customSalePrices"] = {}
			}
			return
		end

		itemsData = result
	else
		itemsData = {
			["customSalePrices"] = {},
			["primaryLootValueSources"] = {}
		}
		Cyclopedia.Items.saveJson()
	end

	if table.empty(itemsData) then
		itemsData = {
			["primaryLootValueSources"] = {},
			["customSalePrices"] = {}
		}
	end

	if not itemsData["primaryLootValueSources"] then
		itemsData["primaryLootValueSources"] = {}
	end
	if not itemsData["customSalePrices"] then
		itemsData["customSalePrices"] = {}
	end
	if not itemsData["dropTrackerItems"] then
		itemsData["dropTrackerItems"] = {}
	end

	local useMarketPrice = {}
	for k, v in pairs(itemsData["primaryLootValueSources"]) do
		table.insert(useMarketPrice, k)
	end

	local customPrice = {}
	if g_things.getItemsPrice then
		customPrice = g_things.getItemsPrice()
	end
	
	for k, v in pairs(itemsData["customSalePrices"]) do
		local key = tonumber(k) or k
		customPrice[key] = v
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return true
	end

	if player.setCyclopediaMarketList then
		player:setCyclopediaMarketList(useMarketPrice)
	end
	if player.setCyclopediaCustomPrice then
		player:setCyclopediaCustomPrice(customPrice)
	end
end

function Cyclopedia.Items.saveJson()
	if not LoadedPlayer or not LoadedPlayer:isLoaded() then
		return true
	end

	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/itemprices.json"
	local status, result = pcall(function() return json.encode(itemsData, 2) end)
	if not status then
		g_logger.error("Error while saving profile itemsData. Data won't be saved. Details: " .. result)
		return
	end

	if result:len() > 100 * 1024 * 1024 then
		g_logger.error("Something went wrong, file is above 100MB, won't be saved")
		return
	end
	g_resources.writeFileContents(file, result)
end

function Cyclopedia.ResetItemCategorySelection(list)
    for i, child in pairs(list:getChildren()) do
        child:setChecked(false)
        child:setBackgroundColor(child.BaseColor)
    end
end

function Cyclopedia.Items.getNpcValue(itemOrThingType, useBuyPrice)
	local npcValue = 0
	if useBuyPrice == nil then
		useBuyPrice = true  -- Default to buyPrice for backward compatibility
	end
	
	if itemOrThingType and itemOrThingType.getNpcSaleData then
		local success, npcSaleData = pcall(function() return itemOrThingType:getNpcSaleData() end)
		if success and npcSaleData and #npcSaleData > 0 then
			if useBuyPrice then
				for _, npcData in ipairs(npcSaleData) do
					if npcData.buyPrice and npcData.buyPrice > npcValue then
						npcValue = npcData.buyPrice
					end
				end
			else
				for _, npcData in ipairs(npcSaleData) do
					if npcData.salePrice and npcData.salePrice > npcValue then
						npcValue = npcData.salePrice
					end
				end
			end
		end
	end
	
	return npcValue
end

function Cyclopedia.Items.getMarketOfferAverages(itemId)
	return 0
end

function Cyclopedia.Items.showItemPrice(obj)
	if not obj then
		return 0
	end

	local item, thingType, itemId
	if obj.getMarketData then
		thingType = obj
		itemId = thingType:getId()
		item = Item.create(itemId)
	else
		item = obj
		itemId = item:getId()
		thingType = g_things.getThingType(itemId, ThingCategoryItem)
	end

	local avgMarket = 0
	if itemId then
		avgMarket = Cyclopedia.Items.getMarketOfferAverages(itemId)
	end
	
	if UI.InfoBase.MarketGoldPriceBase and UI.InfoBase.MarketGoldPriceBase.Value then
        local marketOfferAverages = Cyclopedia.Items.getMarketOfferAverages(itemId)        
		UI.InfoBase.MarketGoldPriceBase.Value:setText(comma_value(marketOfferAverages))
	end

	local isMarketPrice = false
	if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][tostring(itemId)] then
		isMarketPrice = true
	end

	local npcValue = Cyclopedia.Items.getNpcValue(thingType or item, true)
	
	if npcValue == 0 then
		npcValue = avgMarket
	end

	local resulting = 0
	if itemsData["customSalePrices"] and itemsData["customSalePrices"][tostring(itemId)] then
		resulting = itemsData["customSalePrices"][tostring(itemId)]
		if UI.InfoBase.OwnValueEdit then
			UI.InfoBase.OwnValueEdit:setText(tostring(resulting))
		end
	else
		if isMarketPrice then
			resulting = avgMarket
		else
			resulting = npcValue
		end
		
		if UI.InfoBase.OwnValueEdit then
			UI.InfoBase.OwnValueEdit:clearText(true)
		end
	end

	Cyclopedia.Items.updateResultGoldValue(itemId, resulting, avgMarket, npcValue)

	if UI.LootValue then
		local npcCallback = UI.LootValue.NpcBuyCheck.onCheckChange
		local marketCallback = UI.LootValue.MarketCheck.onCheckChange
		UI.LootValue.NpcBuyCheck.onCheckChange = nil
		UI.LootValue.MarketCheck.onCheckChange = nil

		if isMarketPrice then
			UI.LootValue.NpcBuyCheck:setChecked(false)
			UI.LootValue.MarketCheck:setChecked(true)
		else
			UI.LootValue.NpcBuyCheck:setChecked(true)
			UI.LootValue.MarketCheck:setChecked(false)
		end

		UI.LootValue.NpcBuyCheck.onCheckChange = npcCallback
		UI.LootValue.MarketCheck.onCheckChange = marketCallback
	end

	return resulting
end

function Cyclopedia.Items.getCurrentItemValue(item)
	if not item then
		return 0
	end

	local avgMarket = 0
	local itemId = item:getId()
	if itemId then
		avgMarket = Cyclopedia.Items.getMarketOfferAverages(itemId)
	end

	local isMarketPrice = false
	if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][tostring(item:getId())] then
		isMarketPrice = true
	end

	local npcValue = Cyclopedia.Items.getNpcValue(item, true)
	
	if npcValue == 0 then
		npcValue = avgMarket
	end

	local resulting = 0
	if itemsData["customSalePrices"] and itemsData["customSalePrices"][tostring(item:getId())] then
		resulting = itemsData["customSalePrices"][tostring(item:getId())]
	else
		if isMarketPrice then
			resulting = avgMarket
		else
			resulting = npcValue
		end
	end
	
	return resulting
end

function Cyclopedia.Items.updateResultGoldValue(itemId, customValue, avgMarket, npcValue)
	if not UI.InfoBase.ResultGoldBase or not UI.InfoBase.ResultGoldBase.Value then
		return
	end
	
	local finalValue = customValue
	
	local ownValueText = ""
	if UI.InfoBase.OwnValueEdit then
		ownValueText = UI.InfoBase.OwnValueEdit:getText() or ""
		ownValueText = ownValueText:gsub("%s+", "")
	end
	
	if #ownValueText == 0 and (not itemsData["customSalePrices"] or not itemsData["customSalePrices"][tostring(itemId)]) then
		local isMarketPrice = false
		if itemsData["primaryLootValueSources"] and itemsData["primaryLootValueSources"][tostring(itemId)] then
			isMarketPrice = true
		end
		
		if isMarketPrice then
			local marketValue = 0
			if UI.InfoBase.MarketGoldPriceBase and UI.InfoBase.MarketGoldPriceBase.Value then
				local marketValueText = UI.InfoBase.MarketGoldPriceBase.Value:getText() or "0"
				marketValueText = marketValueText:gsub(",", "")
				marketValue = tonumber(marketValueText) or 0
			end
			
			if marketValue == 0 then
				finalValue = npcValue
			else
				finalValue = marketValue
			end
		else
			finalValue = npcValue
		end
		
		if not finalValue or finalValue == 0 then
			finalValue = 0
		end
	end
	
	UI.InfoBase.ResultGoldBase.Value:setText(comma_value(finalValue))
	
	if finalValue > 0 and UI.InfoBase.ResultGoldBase.Rarity then
		ItemsDatabase.setRarityItem(UI.InfoBase.ResultGoldBase.Rarity, finalValue)
	elseif UI.InfoBase.ResultGoldBase.Rarity then
		UI.InfoBase.ResultGoldBase.Rarity:setImageSource("")
	end
	
	return finalValue
end

function Cyclopedia.Items.getResultGoldValue()
	if not UI.InfoBase.ResultGoldBase or not UI.InfoBase.ResultGoldBase.Value then
		return 0
	end
	
	local valueText = UI.InfoBase.ResultGoldBase.Value:getText() or "0"
	valueText = valueText:gsub(",", "")
	return tonumber(valueText) or 0
end

function Cyclopedia.Items.onSourceValueChange(checked, npcSource)
	if checked or not lastSelectedItem then
		return
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	local item = getItemFromWidget(lastSelectedItem)
	if not item then
		g_logger.warning("Cyclopedia: Could not retrieve item from lastSelectedItem")
		return
	end
	
	local itemId = item:getId()
	local currentItemID = tostring(itemId)
	local currentPrice = 0

	if not itemsData["primaryLootValueSources"] then
		itemsData["primaryLootValueSources"] = {}
	end

	if npcSource then
		local newItemList = {}
		newItemList["primaryLootValueSources"] = {}
		for k, v in pairs(itemsData["primaryLootValueSources"]) do
			if k ~= currentItemID then
				newItemList["primaryLootValueSources"][k] = v
			end
		end

		itemsData["primaryLootValueSources"] = newItemList["primaryLootValueSources"]
		Cyclopedia.Items.showItemPrice(item)
		if player.updateCyclopediaMarketList then
			player:updateCyclopediaMarketList(itemId, true)
		end
	else
		itemsData["primaryLootValueSources"][currentItemID] = "market"
		Cyclopedia.Items.showItemPrice(item)
		if player.updateCyclopediaMarketList then
			player:updateCyclopediaMarketList(itemId, false)
		end
	end

	if UI.InfoBase.ResultGoldBase and UI.InfoBase.ResultGoldBase.Value then
		local valueText = UI.InfoBase.ResultGoldBase.Value:getText() or "0"
		valueText = valueText:gsub(",", "")
		currentPrice = tonumber(valueText) or 0
	else
		currentPrice = Cyclopedia.Items.getCurrentItemValue(item)
	end

	if player.updateCyclopediaCustomPrice then
		player:updateCyclopediaCustomPrice(itemId, currentPrice)
	end
	
	if modules.game_analyser then
		if modules.game_analyser.HuntingAnalyser and modules.game_analyser.HuntingAnalyser.updateLootedItemValue then
			modules.game_analyser.HuntingAnalyser:updateLootedItemValue(itemId, currentPrice)
		end
		if modules.game_analyser.LootAnalyser and modules.game_analyser.LootAnalyser.updateBasePriceFromLootedItems then
			modules.game_analyser.LootAnalyser:updateBasePriceFromLootedItems(itemId, currentPrice)
		end
	end
end

function Cyclopedia.Items.onChangeCustomPrice(widget)
	if not lastSelectedItem then
		return
	end

	local player = g_game.getLocalPlayer()
	if not player then
		return
	end

	local item = getItemFromWidget(lastSelectedItem)
	if not item then
		g_logger.warning("Cyclopedia: Could not retrieve item in onChangeCustomPrice")
		return
	end

	local currentText = widget:getText()
	local itemId = item:getId()
	local itemIdStr = tostring(itemId)
	
	if not itemsData["customSalePrices"] then
		itemsData["customSalePrices"] = {}
	end

	if #currentText == 0 then
		local newItemList = {}
		newItemList["customSalePrices"] = {}

		for k, v in pairs(itemsData["customSalePrices"]) do
			if k ~= itemIdStr then
				newItemList["customSalePrices"][k] = v
			end
		end

		itemsData["customSalePrices"] = newItemList["customSalePrices"]
		Cyclopedia.Items.showItemPrice(item)
		
		local itemDefaultValue = Cyclopedia.Items.getCurrentItemValue(item)
		
		if player.updateCyclopediaCustomPrice then
			player:updateCyclopediaCustomPrice(itemId, itemDefaultValue)
		end
		
		if modules.game_analyser then
			if modules.game_analyser.HuntingAnalyser then
				modules.game_analyser.HuntingAnalyser:updateLootedItemValue(itemId, itemDefaultValue)
			end
			if modules.game_analyser.LootAnalyser then
				modules.game_analyser.LootAnalyser:updateBasePriceFromLootedItems(itemId, itemDefaultValue)
			end
		end
		return
	end

	currentText = currentText:gsub("[^%d]", "")
	widget:setText(currentText)

	local numericValue = tonumber(currentText)
	if numericValue then
		if numericValue >= 999999999 then
			currentText = "999999999"
			widget:setText(currentText)
		end
	end

	numericValue = tonumber(currentText)
	if not numericValue then
		widget:setText("0")
		numericValue = 0
	end

	itemsData["customSalePrices"][itemIdStr] = numericValue
	
	local avgMarket = Cyclopedia.Items.getMarketOfferAverages(itemId)
	local npcValue = Cyclopedia.Items.getNpcValue(item, true)
	
	Cyclopedia.Items.updateResultGoldValue(itemId, numericValue, avgMarket, npcValue)
	
	if player.updateCyclopediaCustomPrice then
		player:updateCyclopediaCustomPrice(itemId, numericValue)
	end
	
	if modules.game_analyser then
		if modules.game_analyser.LootAnalyser then
			modules.game_analyser.LootAnalyser:updateBasePriceFromLootedItems(itemId, numericValue)
		end
		if modules.game_analyser.HuntingAnalyser then
			modules.game_analyser.HuntingAnalyser:updateLootedItemValue(itemId, numericValue)
		end
	end
end

function showItems()
    UI = g_ui.loadUI("items", contentContainer)
    UI:show()
    Cyclopedia.Items.VocFilter = false
    Cyclopedia.Items.LevelFilter = false
    Cyclopedia.Items.h1Filter = false
    Cyclopedia.Items.h2Filter = false
    Cyclopedia.Items.ClassificationFilter = 0
    UI.selectedCategory = nil
    UI.EmptyLabel:setVisible(true)
    UI.InfoBase:setVisible(false)
    UI.LootValue:setVisible(false)
    UI.H1Button:disable()
    UI.H2Button:disable()
    UI.ItemFilter:disable()
    
    if table.empty(itemsData) then
        itemsData = {
            ["primaryLootValueSources"] = {},
            ["customSalePrices"] = {}
        }
    end
    
    Cyclopedia.Items.loadJson()
    
    if g_game.sendInspectionObject then
        connect(g_game, { onInspectionObject = Cyclopedia.Items.onInspection })
    end
    
    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(false)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
    local CategoryColor = "#484848"

    for _, data in ipairs(Cyclopedia.CategoryItems) do
        local ItemCat = g_ui.createWidget("ItemCategory", UI.CategoryList)

        ItemCat:setId(data.id)
        ItemCat:setText(data.name)
        ItemCat:setBackgroundColor(CategoryColor)
        ItemCat:setPhantom(false)
        ItemCat.BaseColor = CategoryColor

        function ItemCat:onClick()
            Cyclopedia.ResetItemCategorySelection(UI.CategoryList)
            self:setChecked(true)
            self:setBackgroundColor("#585858")
            Cyclopedia.onCategoryChange(self)
        end

        CategoryColor = CategoryColor == "#484848" and "#414141" or "#484848"
    end

    Cyclopedia.ItemList = {}
    Cyclopedia.AllItemList = {}
    Cyclopedia.loadItemsCategories()

    focusCategoryList = UI.CategoryList

    g_keyboard.bindKeyPress('Down', function()
        focusCategoryList:focusNextChild(KeyboardFocusReason)
    end, focusCategoryList:getParent())

    g_keyboard.bindKeyPress('Up', function()
        focusCategoryList:focusPreviousChild(KeyboardFocusReason)
    end, focusCategoryList:getParent())

    connect(focusCategoryList, {
        onChildFocusChange = function(self, focusedChild)
            if focusedChild == nil then
                return
            end
            focusedChild:onClick()
        end
    })
end

function Cyclopedia.onCategoryChange(widget)
    if widget:isChecked() then
        Cyclopedia.selectItemCategory(tonumber(widget:getId()))
        UI.selectedCategory = widget
    end
end

function Cyclopedia.onChangeLootValue(widget)
    if widget:getId() == "NpcBuyCheck" then
        Cyclopedia.Items.onSourceValueChange(widget:isChecked(), true)
    elseif widget:getId() == "MarketCheck" then
        Cyclopedia.Items.onSourceValueChange(widget:isChecked(), false)
    end
end

function Cyclopedia.vocationFilter(value)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.Items.VocFilter = value
    Cyclopedia.applyFilters()
end

function Cyclopedia.levelFilter(value)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.Items.LevelFilter = value
    Cyclopedia.applyFilters()
end

local ignoreRecursiveCalls = false
local function setCheckedWithoutRecursion(h1Val, h2Val)
    ignoreRecursiveCalls = true
    UI.H1Button:setChecked(h1Val)
    UI.H2Button:setChecked(h2Val)
    ignoreRecursiveCalls = false
end

function Cyclopedia.handFilter(h1Val, h2Val)
    Cyclopedia.Items.h1Filter = h1Val
    Cyclopedia.Items.h2Filter = h2Val

    if ignoreRecursiveCalls then
        return
    end

    setCheckedWithoutRecursion(h1Val, h2Val)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.applyFilters()
end

function Cyclopedia.classificationFilter(data)
    UI.ItemListBase.List:destroyChildren()
    Cyclopedia.Items.ClassificationFilter = tonumber(data)
    Cyclopedia.applyFilters()
end

local function processItemsById(id)
    local idsToProcess = {}
    local tempTable = {}

    if id == 1000 then
        idsToProcess = {17, 18, 19, 20, 21}
    else
        idsToProcess = {id}
    end

    for _, idToProcess in pairs(idsToProcess) do
        if not table.empty(Cyclopedia.ItemList[idToProcess]) then
            for _, data in pairs(Cyclopedia.ItemList[idToProcess]) do
                table.insert(tempTable, data)
            end
        end
    end

    table.sort(tempTable, function(a, b)
        return string.lower(a:getMarketData().name) < string.lower((b:getMarketData().name))
    end)

    for _, data in pairs(tempTable) do
        local item = Cyclopedia.internalCreateItem(data)
    end
end

function Cyclopedia.applyFilters()
    local isSearching = UI.SearchEdit:getText() ~= ""
    if not isSearching then
        if UI.selectedCategory then
           processItemsById(tonumber(UI.selectedCategory:getId()))
        end
    else
        Cyclopedia.ItemSearch(UI.SearchEdit:getText(), false)
    end
end

function Cyclopedia.internalCreateItem(data)
    local player = g_game.getLocalPlayer()
    local vocation = player:getVocation()
    local level = player:getLevel()
    local classification = data:getClassification()
    local marketData = data:getMarketData()
    local vocFilter = Cyclopedia.Items.VocFilter
    local levelFilter = Cyclopedia.Items.LevelFilter
    local h1Filter = Cyclopedia.Items.h1Filter
    local h2Filter = Cyclopedia.Items.h2Filter
    local classificationFilter = Cyclopedia.Items.ClassificationFilter

    if vocFilter and tonumber(marketData.restrictVocation) > 0 then
        local demotedVoc = vocation > 10 and (vocation - 10) or vocation
        local vocBitMask = Bit.bit(tonumber(demotedVoc))
        if not Bit.hasBit(marketData.restrictVocation, vocBitMask) then
            return
        end
    end

    if levelFilter and level < marketData.requiredLevel then
        return
    end

    if h1Filter and data:getClothSlot() ~= 6 then
        return
    end

    if h2Filter and data:getClothSlot() ~= 0 then
        return
    end

    if classificationFilter == -1 and classification ~= 0 then
        return
    elseif classificationFilter == 1 and classification ~= 1 then
        return
    elseif classificationFilter == 2 and classification ~= 2 then
        return
    elseif classificationFilter == 3 and classification ~= 3 then
        return
    elseif classificationFilter == 4 and classification ~= 4 then
        return
    end

    local item = g_ui.createWidget("ItemsListBaseItem", UI.ItemListBase.List)

    item:setId(data:getId())
    item.Sprite = item:getChildById("Sprite")  -- Force reference to fix nil Sprite error
    item.Sprite:setItemId(data:getId())
    item.Name:setText(marketData.name)
    local price = data:getMeanPrice()

    item.Value = price
    item.Vocation = marketData.restrictVocation
    ItemsDatabase.setRarityItem(item.Sprite, item.Sprite:getItem())
    
    if Cyclopedia.Items.isInDropTracker(data:getId()) then
        item.Name:setColor("#FF9854")
    else
        item.Name:setColor("#c0c0c0")
    end

    function item.onClick(widget)
        UI.InfoBase.SellBase.List:destroyChildren()
        UI.InfoBase.BuyBase.List:destroyChildren()

        local oldSelected = UI.selectItem
        local lootValue = UI.LootValue
        local itemId = data:getId()
        local internalData = g_things.getThingType(itemId, ThingCategoryItem)

        if oldSelected then
            oldSelected:setBackgroundColor("#00000000")
        end

        Cyclopedia.Items.currentItemId = itemId
        g_game.inspectionObject(InspectObjectTypes.INSPECT_CYCLOPEDIA, itemId)

        if not lootValue:isVisible() then
            lootValue:setVisible(true)
        end

        UI.EmptyLabel:setVisible(false)
        UI.InfoBase:setVisible(true)
        UI.InfoBase.ResultGoldBase.Value:setText(Cyclopedia.formatGold(item.Value))
        UI.SelectedItem.Sprite:setItemId(data:getId())

        lastSelectedItem = item
        lastSelectedItem.data = data
        lastSelectedItemId = itemId

        if data then
            Cyclopedia.Items.showItemPrice(data)
        end

        if price > 0 then
            ItemsDatabase.setRarityItem(UI.SelectedItem.Rarity, price)
            ItemsDatabase.setRarityItem(UI.InfoBase.ResultGoldBase.Rarity, price)
        else
            UI.InfoBase.ResultGoldBase.Rarity:setImageSource("")
            UI.SelectedItem.Rarity:setImageSource("")
        end
        item:setBackgroundColor("#585858")
       
        if modules.game_quickloot.QuickLoot.data.filter == 2 then
            UI.InfoBase.quickLootCheck:setText("Loot when Quick Looting")
        else
            UI.InfoBase.quickLootCheck:setText('Skip when Quick Looting')
        end
        UI.InfoBase.quickLootCheck.onCheckChange = function(self, checked)
            if checked then
                modules.game_quickloot.QuickLoot.addLootList(data:getId(), modules.game_quickloot.QuickLoot.data.filter)
            else
                modules.game_quickloot.QuickLoot.removeLootList(data:getId(), modules.game_quickloot.QuickLoot.data.filter)
            end
        end
        UI.InfoBase.quickLootCheck:setChecked(modules.game_quickloot.QuickLoot.lootExists(data:getId(), modules.game_quickloot.QuickLoot.data.filter))

        if UI.InfoBase.TrackCheck then
            local originalCallback = UI.InfoBase.TrackCheck.onCheckChange
            UI.InfoBase.TrackCheck.onCheckChange = nil
            
            UI.InfoBase.TrackCheck.itemId = data:getId()
            local inTracker = Cyclopedia.Items.isInDropTracker(data:getId())
            UI.InfoBase.TrackCheck:setChecked(inTracker)
            
            UI.InfoBase.TrackCheck.onCheckChange = originalCallback
        end

        if UI.InfoBase.quickSellCheck then
            local inWhitelist = Cyclopedia.Items.isInQuickSellWhitelist(data:getId())
            UI.InfoBase.quickSellCheck:setChecked(inWhitelist)
            UI.InfoBase.quickSellCheck.itemId = data:getId()
        end

        if UI.InfoBase.OwnValueEdit then
            UI.InfoBase.OwnValueEdit.onTextChange = function(self)
                Cyclopedia.Items.onChangeCustomPrice(self)
            end
        end

        local buy, sell = Cyclopedia.formatSaleData(internalData:getNpcSaleData())
        local sellColor = "#484848"

        for index, value in ipairs(sell) do
            local t_widget = g_ui.createWidget("UIWidget", UI.InfoBase.SellBase.List)

            t_widget:setId(index)
            t_widget:setText(value)
            t_widget:setTextAlign(AlignLeft)
            t_widget:setBackgroundColor(sellColor)

            t_widget.BaseColor = sellColor

            function t_widget:onClick()
                Cyclopedia.ResetItemCategorySelection(UI.InfoBase.SellBase.List)
                self:setChecked(true)
                self:setBackgroundColor("#585858")
            end

            sellColor = sellColor == "#484848" and "#414141" or "#484848"
        end

        local buyColor = "#484848"

        for index, value in ipairs(buy) do
            local t_widget = g_ui.createWidget("UIWidget", UI.InfoBase.BuyBase.List)

            t_widget:setId(index)
            t_widget:setText(value)
            t_widget:setTextAlign(AlignLeft)
            t_widget:setBackgroundColor(buyColor)

            t_widget.BaseColor = buyColor

            function t_widget:onClick()
                Cyclopedia.ResetItemCategorySelection(UI.InfoBase.BuyBase.List)
                self:setChecked(true)
                self:setBackgroundColor("#585858")
            end

            buyColor = buyColor == "#484848" and "#414141" or "#484848"
        end 

        UI.selectItem = item
    end

    return item
end

function Cyclopedia.ItemSearch(text, clearTextEdit)
    UI.ItemListBase.List:destroyChildren()
    if text ~= "" then
        UI.SelectedItem.Sprite:setItemId(0)
        UI.SelectedItem.Rarity:setImageSource("")

        local searchedItems = {}

        local oldSelected = UI.selectedCategory
        if oldSelected then
            oldSelected:setBackgroundColor(oldSelected.BaseColor)
            oldSelected:setChecked(false)
        end

        local searchTermLower = string.lower(text)

        for _, data in pairs(Cyclopedia.AllItemList) do
            local marketData = data:getMarketData()
            local itemNameLower = string.lower(marketData.name)
            local _, endIndex = itemNameLower:find(searchTermLower, 1, true)

            if endIndex and (itemNameLower:sub(endIndex + 1, endIndex + 1) == " " or endIndex == #itemNameLower) then
                table.insert(searchedItems, data)
            end
        end

        for _, data in ipairs(searchedItems) do
            local item = Cyclopedia.internalCreateItem(data)
        end

        local firstChild = UI.ItemListBase.List:getFirstChild()
        if firstChild and firstChild.onClick then
            local firstChildItemId = getItemWidgetId(firstChild)
            if firstChildItemId and firstChildItemId ~= lastSelectedItemId then
                lastSelectedItemId = firstChildItemId
                firstChild:onClick()
            end
        end
    else
        UI.SelectedItem.Sprite:setItemId(0)
        UI.SelectedItem.Rarity:setImageSource("")
    end

    if clearTextEdit then
        UI.SearchEdit:setText("")
    end
end

local function isHandWeapon(id)
    if id >= 17 and id <= 21 or id == 1000 then
        return true
    end
end

function Cyclopedia.selectItemCategory(id)
    setCheckedWithoutRecursion(false, false)
    UI.LevelButton:setChecked(false)
    UI.VocationButton:setChecked(false)
    Cyclopedia.Items.VocFilter = false
    Cyclopedia.Items.LevelFilter = false

    if UI.SearchEdit:getText() ~= "" then
        Cyclopedia.ItemSearch("", true)
    end

    UI.ItemListBase.List:destroyChildren()

    if Cyclopedia.hasClassificationFilter(id) then
        UI.ItemFilter:clearOptions()
        UI.ItemFilter:addOption("All", 0, true)
        UI.ItemFilter:addOption("None", -1, true)

        for class = 1, 4 do
            UI.ItemFilter:addOption("Class " .. class, class, true)
        end

        UI.ItemFilter:enable()
    else
        UI.ItemFilter:clearOptions()
        Cyclopedia.Items.ClassificationFilter = 0
    end

    processItemsById(id)

    if Cyclopedia.hasHandedFilter(id) then
        UI.H1Button:enable()
        UI.H2Button:enable()
    else
        UI.H1Button:disable()
        UI.H2Button:disable()
    end
end

function Cyclopedia.loadItemsCategories()
    local types = g_things.findThingTypeByAttr(ThingAttrMarket, 0)
    local tempItemList = {}

    for _, data in pairs(types) do
        local marketData = data:getMarketData()
        if not tempItemList[marketData.category] then
            tempItemList[marketData.category] = {}
        end

        if marketData then
            table.insert(Cyclopedia.AllItemList, data)
        end

        table.insert(tempItemList[marketData.category], data)
    end

    for category, itemList in pairs(tempItemList) do
        table.sort(itemList, Cyclopedia.compareItems)
        Cyclopedia.ItemList[category] = itemList
    end
end

function Cyclopedia.loadItemDetail(data)
    if not (UI and UI.InfoBase and UI.InfoBase.DetailsBase) then
        return
    end
    
    UI.InfoBase.DetailsBase.List:destroyChildren()

    local itemId = data.item:getId()
    local internalData = g_things.getThingType(itemId, ThingCategoryItem)
    local classification = internalData:getClassification()

    for _, description in ipairs(data.descriptions) do
        local widget = g_ui.createWidget("UIWidget", UI.InfoBase.DetailsBase.List)
        widget:setText(description.key .. ": " .. description.value)
        widget:setColor("#C0C0C0")
        widget:setTextWrap(true)
    end

    if classification > 0 then
        local widget = g_ui.createWidget("UIWidget", UI.InfoBase.DetailsBase.List)
        widget:setText("Classification: " .. classification)
        widget:setColor("#C0C0C0")
    end
end

function Cyclopedia.Items.onInspection(data)
    if data.inspectionType ~= InspectObjectTypes.INSPECT_CYCLOPEDIA then return end
    if not data.item or data.item:getId() ~= Cyclopedia.Items.currentItemId then return end
    if UI and UI.InfoBase and UI.InfoBase.DetailsBase then
        Cyclopedia.loadItemDetail(data)
    end
end

function Cyclopedia.openItem(arg)
    local itemName
    if type(arg) == 'number' then
        local thingType = g_things.getThingType(arg, ThingCategoryItem)
        itemName = thingType and thingType:getName() or ''
    else
        itemName = tostring(arg or '')
    end
    if itemName == '' then return end
    if controllerCyclopedia and controllerCyclopedia.ui and controllerCyclopedia.ui:isVisible() then
        SelectWindow('items', false)
    else
        show('items')
    end
    scheduleEvent(function()
        if Cyclopedia.ItemSearch then
            Cyclopedia.ItemSearch(itemName, false)
        end
    end, 100)
end

function comma_value(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

function Cyclopedia.formatGold(value)
    return comma_value(value or 0)
end

function Cyclopedia.Items.sendPartyLootItems()
    if not Cyclopedia.ItemList then return end
    
    local totalList = {}
    for i, category in pairs(Cyclopedia.ItemList) do
        local skipCategory = (i == 1000 or i == 30)

        if not skipCategory then
            for _, itemInfo in ipairs(category) do
                if itemInfo then
                    local item = Item.create(itemInfo:getId())
                    if item then
                        local itemValue = Cyclopedia.Items.getCurrentItemValue(item)
                        totalList[tonumber(itemInfo:getId())] = itemValue
                    end
                end
            end
        end
    end

	if g_game.sendPartyLootPrice then
		g_game.sendPartyLootPrice(totalList)
	end
end

function Cyclopedia.Items.addToDropTracker(itemId)
    if modules.game_analyser and modules.game_analyser.managerDropTracker then
        modules.game_analyser.managerDropTracker(itemId, true)
    end
    
    if not itemsData["dropTrackerItems"] then
        itemsData["dropTrackerItems"] = {}
    end
    itemsData["dropTrackerItems"][tostring(itemId)] = true
    Cyclopedia.Items.saveJson()
    
    Cyclopedia.Items.updateItemVisualFeedback(itemId, true)
end

function Cyclopedia.Items.removeFromDropTracker(itemId)
    if modules.game_analyser and modules.game_analyser.managerDropTracker then
        modules.game_analyser.managerDropTracker(itemId, false)
    end
    
    if itemsData["dropTrackerItems"] then
        itemsData["dropTrackerItems"][tostring(itemId)] = nil
        Cyclopedia.Items.saveJson()
    end
    
    Cyclopedia.Items.updateItemVisualFeedback(itemId, false)
end

function Cyclopedia.Items.updateItemVisualFeedback(itemId, isTracked)
    if UI and UI.ItemListBase and UI.ItemListBase.List then
        for _, widget in pairs(UI.ItemListBase.List:getChildren()) do
            if widget:getId() == tostring(itemId) and widget.Name then
                if isTracked then
                    widget.Name:setColor("#FF9854")
                else
                    widget.Name:setColor("#c0c0c0")
                end
            end
        end
    end
end

function Cyclopedia.Items.isInDropTracker(itemId)
    if modules.game_analyser and modules.game_analyser.isInDropTracker then
        local inAnalyser = modules.game_analyser.isInDropTracker(itemId)
        if inAnalyser then
            return true
        end
    end
    
    if itemsData["dropTrackerItems"] and itemsData["dropTrackerItems"][tostring(itemId)] then
        return true
    end
    
    return false
end

function Cyclopedia.Items.removeFromDropTrackerDirectly(itemId)
    if itemsData["dropTrackerItems"] then
        itemsData["dropTrackerItems"][tostring(itemId)] = nil
        Cyclopedia.Items.saveJson()
    end
    
    Cyclopedia.Items.updateItemVisualFeedback(itemId, false)
end

function Cyclopedia.Items.refreshCurrentItem()
    if UI and UI.InfoBase and UI.InfoBase.TrackCheck and UI.InfoBase.TrackCheck.itemId then
        local itemId = UI.InfoBase.TrackCheck.itemId
        
        local originalCallback = UI.InfoBase.TrackCheck.onCheckChange
        UI.InfoBase.TrackCheck.onCheckChange = nil
        
        local inTracker = Cyclopedia.Items.isInDropTracker(itemId)
        UI.InfoBase.TrackCheck:setChecked(inTracker)
        
        UI.InfoBase.TrackCheck.onCheckChange = originalCallback
    end
end

function Cyclopedia.Items.removeAllFromDropTrackerDirectly()
    if itemsData then
        itemsData["dropTrackerItems"] = {}
        Cyclopedia.Items.saveJson()
    end
    
    if UI and UI.ItemListBase and UI.ItemListBase.List then
        for _, widget in pairs(UI.ItemListBase.List:getChildren()) do
            if widget.Name then
                widget.Name:setColor("#c0c0c0")
            end
        end
    end
end

function Cyclopedia.Items.addToQuickSellWhitelist(itemId)
	if modules.game_npctrade then
		if modules.game_npctrade.addToWhitelist then
			modules.game_npctrade.addToWhitelist(itemId)
		elseif modules.game_npctrade.addToList then
			modules.game_npctrade.addToList(itemId)
		end
	end
end

function Cyclopedia.Items.removeFromQuickSellWhitelist(itemId)
	if modules.game_npctrade then
		if modules.game_npctrade.removeItemInList then
			modules.game_npctrade.removeItemInList(itemId)
		elseif modules.game_npctrade.removeFromList then
			modules.game_npctrade.removeFromList(itemId)
		elseif modules.game_npctrade.removeItem then
			modules.game_npctrade.removeItem(itemId)
		end
	end
end

function Cyclopedia.Items.isInQuickSellWhitelist(itemId)
    if not modules.game_npctrade then return false end
    
    local npctrade = modules.game_npctrade
    if npctrade.inWhiteList then
        return npctrade.inWhiteList(itemId)
    elseif npctrade.isInList then
        return npctrade.isInList(itemId)
    elseif npctrade.contains then
        return npctrade.contains(itemId)
    end
    
    return false
end

function Cyclopedia.Items.onChangeLootValue(self)
    if not self or not self:getParent() then return end
    
    local parent = self:getParent()
    local npcCheck = parent:getChildById('NpcBuyCheck')
    local marketCheck = parent:getChildById('MarketCheck')
    
    if not npcCheck or not marketCheck then return end
    
    if self:getId() == 'NpcBuyCheck' and self:isChecked() then
        marketCheck:setChecked(false)
    elseif self:getId() == 'MarketCheck' and self:isChecked() then
        npcCheck:setChecked(false)
    end
    
    if not npcCheck:isChecked() and not marketCheck:isChecked() then
        npcCheck:setChecked(true)
    end
    
    if lastSelectedItem and lastSelectedItem.data then
        local item = getItemFromWidget(lastSelectedItem)
        if item then
            local itemId = item:getId()
            local currentItemID = tostring(itemId)
            
            if not itemsData["primaryLootValueSources"] then
                itemsData["primaryLootValueSources"] = {}
            end
            
            if marketCheck:isChecked() then
                itemsData["primaryLootValueSources"][currentItemID] = "market"
            else
                itemsData["primaryLootValueSources"][currentItemID] = nil
            end
            
            local player = g_game.getLocalPlayer()
            if player and player.updateCyclopediaMarketList then
                player:updateCyclopediaMarketList(itemId, not marketCheck:isChecked())
            end
        end
        
        Cyclopedia.Items.showItemPrice(lastSelectedItem.data)
    end
end