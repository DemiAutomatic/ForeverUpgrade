local _, ns = ...

-- Bag, loot, and quest markers. The arrow means the item beats what you
-- have equipped for the current spec. A full bag scan also remembers the
-- best item you currently own in each slot, so a tooltip can point at it.

local marked = {}
local running = false
local queued = false

local function BagCount()
    local n = NUM_BAG_SLOTS
    if type(n) == "number" and not ns.Secret(n) and n >= 0 then
        return n
    end
    return 4
end

local function ContainerLink(bag, slot)
    local fn = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
    if type(fn) ~= "function" then
        return nil
    end
    local ok, link = pcall(fn, bag, slot)
    if ok and type(link) == "string" and not ns.Secret(link) then
        return link
    end
    return nil
end

local function ContainerSize(bag)
    local fn = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if type(fn) ~= "function" then
        return 0
    end
    local ok, n = pcall(fn, bag)
    if ok and type(n) == "number" and not ns.Secret(n) and n > 0 then
        return n
    end
    return 0
end

local function ButtonBagSlot(button)
    local name = button.GetName and button:GetName()
    if type(name) == "string" and name:match("^BankFrameItem%d+$") then
        local slot = button:GetID()
        if type(slot) == "number" and not ns.Secret(slot) and slot > 0 then
            return -1, slot
        end
    end
    if button.GetBagID then
        local bag = button:GetBagID()
        local slot = button:GetID()
        if type(bag) == "number" and not ns.Secret(bag) and type(slot) == "number" and not ns.Secret(slot) and slot > 0 then
            return bag, slot
        end
    end
    if type(button.bag) == "number" and not ns.Secret(button.bag) and button.GetID then
        local slot = button:GetID()
        if type(slot) == "number" and not ns.Secret(slot) and slot > 0 then
            return button.bag, slot
        end
    end
    local parent = button.GetParent and button:GetParent()
    if parent and parent.GetID and button.GetID then
        local bag = parent:GetID()
        local slot = button:GetID()
        if type(bag) == "number" and not ns.Secret(bag) and type(slot) == "number" and not ns.Secret(slot) and slot > 0 then
            return bag, slot
        end
    end
    return nil
end

local function Arrow(button, anchor)
    local arrow = button._fuArrow
    if not arrow then
        -- A child frame draws above Bagnon's junk coin, which is a texture on the button itself.
        local host = CreateFrame("Frame", nil, button)
        host:SetAllPoints(button)
        host:EnableMouse(false)
        arrow = host:CreateTexture(nil, "OVERLAY", nil, 7)
        arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
        -- The stock texture points down. Flip it so an upgrade points up.
        arrow:SetTexCoord(0, 1, 1, 0)
        if arrow.SetDesaturated then
            pcall(arrow.SetDesaturated, arrow, true)
        end
        button._fuArrowHost = host
        button._fuArrow = arrow
    end
    local host = button._fuArrowHost
    if host then
        if host.SetFrameStrata then
            pcall(host.SetFrameStrata, host, "HIGH")
        end
        if host.SetFrameLevel then
            local level = 200
            if button.GetFrameLevel then
                local ok, buttonLevel = pcall(button.GetFrameLevel, button)
                if ok and type(buttonLevel) == "number" then
                    level = buttonLevel + 50
                end
            end
            pcall(host.SetFrameLevel, host, level)
        end
    end
    arrow:ClearAllPoints()
    -- Quest rows pass the item icon. That arrow is larger and sits in the
    -- bottom-left of the icon. Bags and other slots keep the small bottom-right corner.
    if type(anchor) == "table" and anchor.GetObjectType and anchor ~= button then
        arrow:SetSize(32, 32)
        arrow:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 2, 2)
    else
        arrow:SetSize(24, 24)
        arrow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, -4)
    end
    return arrow
end

local function JunkIcon(button)
    local junk = button.JunkIcon
    if junk then
        return junk
    end
    local name = button.GetName and button:GetName()
    if type(name) == "string" then
        return _G[name .. "JunkIcon"]
    end
end

local function RestoreJunk(button)
    local junk = JunkIcon(button)
    local info = button.info
    if junk and junk.Show and info and info.quality == 0 and not info.hasNoValue then
        junk:Show()
    end
end

local function SuppressJunk(button)
    local junk = JunkIcon(button)
    if junk and junk.Hide then
        junk:Hide()
    end
end

-- Bagnon calls JunkIcon:SetShown again from UpdateBorder after we hide it.
local function HookBorder(button)
    if button._fuBorderHook or type(hooksecurefunc) ~= "function" or type(button.UpdateBorder) ~= "function" then
        return
    end
    button._fuBorderHook = true
    hooksecurefunc(button, "UpdateBorder", function(self)
        if self._fuArrow and self._fuArrow.IsShown and self._fuArrow:IsShown() then
            SuppressJunk(self)
        end
    end)
end

local function HideJunk(button)
    HookBorder(button)
    local junk = JunkIcon(button)
    if junk and not junk._fuHooked and type(hooksecurefunc) == "function" then
        junk._fuHooked = true
        local function cover(self)
            local parent = self.GetParent and self:GetParent()
            local arrow = parent and parent._fuArrow
            if arrow and arrow.IsShown and arrow:IsShown() and self.IsShown and self:IsShown() then
                self:Hide()
            end
        end
        if junk.SetShown then
            hooksecurefunc(junk, "SetShown", cover)
        end
        if junk.Show then
            hooksecurefunc(junk, "Show", cover)
        end
    end
    SuppressJunk(button)
end

local function HideMarked()
    for button in pairs(marked) do
        if button._fuArrow then
            button._fuArrow:Hide()
        end
        RestoreJunk(button)
    end
    marked = {}
end

local function ShowArrow(button, red, green, blue, anchor, coin)
    if not button or not button.CreateTexture then
        return
    end
    local arrow = Arrow(button, anchor)
    if coin then
        arrow:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        arrow:SetTexCoord(0, 1, 0, 1)
        if arrow.SetDesaturated then
            pcall(arrow.SetDesaturated, arrow, false)
        end
        arrow:SetVertexColor(1, 1, 1)
    else
        arrow:SetTexture("Interface\\Buttons\\UI-MicroStream-Green")
        arrow:SetTexCoord(0, 1, 1, 0)
        if arrow.SetDesaturated then
            pcall(arrow.SetDesaturated, arrow, true)
        end
        arrow:SetVertexColor(red or 1, green or 1, blue or 1)
    end
    arrow:Show()
    HideJunk(button)
    marked[button] = true
end

local function EachBagButton(fn)
    local function frameButtons(frame)
        if not frame then
            return
        end
        if type(frame.Items) == "table" then
            for i = 1, #frame.Items do
                fn(frame.Items[i])
            end
        end
        local name = frame.GetName and frame:GetName()
        if type(name) ~= "string" then
            return
        end
        local maxSlots = MAX_CONTAINER_ITEMS
        if type(maxSlots) ~= "number" or ns.Secret(maxSlots) or maxSlots < 1 then
            maxSlots = 36
        end
        for i = 1, maxSlots do
            local button = _G[name .. "Item" .. i]
            if button then
                fn(button)
            end
        end
    end
    frameButtons(ContainerFrameCombinedBags)
    local function walkList(list)
        if type(list) ~= "table" then
            return
        end
        for i = 1, #list do
            local button = list[i]
            if type(button) == "table" then
                fn(button)
            end
        end
    end
    local function walkFrame(frame)
        if type(frame) ~= "table" then
            return
        end
        walkList(frame.buttons)
        walkList(frame.Items)
        if type(frame.ItemGroup) == "table" then
            walkList(frame.ItemGroup.buttons)
        end
    end
    local prefixes = { "BagBrotherInventory", "BagBrotherBank", "BagnonInventory", "BagnonBank" }
    for p = 1, #prefixes do
        for n = 1, 2 do
            walkFrame(_G[prefixes[p] .. n])
        end
    end
    local frames = NUM_CONTAINER_FRAMES
    if type(frames) ~= "number" or ns.Secret(frames) or frames < 1 then
        frames = 13
    end
    for i = 1, frames do
        frameButtons(_G["ContainerFrame" .. i])
    end
    for i = 1, 28 do
        local button = _G["BankFrameItem" .. i]
        if button then
            fn(button)
        end
    end
end

local function BagIds()
    local ids = {}
    local last = BagCount()
    for bag = 0, last do
        ids[#ids + 1] = bag
    end
    ids[#ids + 1] = -1
    local bank = NUM_BANKBAGSLOTS
    if type(bank) ~= "number" or ns.Secret(bank) or bank < 1 then
        bank = 7
    end
    for i = 1, bank do
        ids[#ids + 1] = last + i
    end
    if Enum and Enum.BagIndex and type(Enum.BagIndex.ReagentBag) == "number" then
        ids[#ids + 1] = Enum.BagIndex.ReagentBag
    end
    return ids
end

local function Consider(link, best, pending)
    if type(link) ~= "string" then
        return pending
    end
    local result = ns.Evaluate(link)
    if result.verdict == "pending" then
        return true
    end
    if result.verdict == "ignore" or result.verdict == "cannot" or not result.family or type(result.score) ~= "number" then
        return pending
    end
    local current = best[result.family]
    if not current or result.score > current.score then
        best[result.family] = {
            score = result.score,
            name = result.name or "that item",
            link = result.link or link,
        }
    end
    return pending
end

local function ScanBags()
    local best = {}
    local pending = false
    local ids = BagIds()
    for i = 1, #ids do
        local bag = ids[i]
        local n = ContainerSize(bag)
        for slot = 1, n do
            pending = Consider(ContainerLink(bag, slot), best, pending)
        end
    end
    ns.bagBest = best
    return pending
end

local function MarkBags()
    if not ns.char or ns.char.bagAdvisor == false then
        return false
    end
    local pending = false
    EachBagButton(function(button)
        local bag, slot = ButtonBagSlot(button)
        if not bag then
            return
        end
        local link = ContainerLink(bag, slot)
        if not link then
            return
        end
        local result = ns.Evaluate(link)
        if result.verdict == "pending" then
            pending = true
            return
        end
        if result.verdict == "upgrade" then
            ShowArrow(button, 0.25, 1, 0.45)
        end
    end)
    return pending
end

local function MarkLootButton(button, slot, pending)
    if type(slot) ~= "number" or ns.Secret(slot) then
        return pending
    end
    local link = GetLootSlotLink(slot)
    if type(link) ~= "string" or ns.Secret(link) then
        return pending
    end
    local result = ns.Evaluate(link)
    if result.verdict == "pending" then
        return true
    end
    if result.verdict == "upgrade" and button then
        ShowArrow(button, 0.25, 1, 0.45)
    end
    return pending
end

local function MarkLoot()
    if not ns.char or ns.char.lootAdvisor == false then
        return false
    end
    if type(GetNumLootItems) ~= "function" or type(GetLootSlotLink) ~= "function" then
        return false
    end
    local count = GetNumLootItems()
    if type(count) ~= "number" or ns.Secret(count) or count < 1 then
        return false
    end
    local pending = false
    for i = 1, count do
        pending = MarkLootButton(_G["LootButton" .. i], i, pending)
    end
    local scroll = LootFrame and LootFrame.ScrollBox
    if scroll and scroll.ForEachFrame then
        pcall(function()
            scroll:ForEachFrame(function(button)
                local slot = button.slotIndex
                if type(slot) ~= "number" and button.GetSlotIndex then
                    slot = button:GetSlotIndex()
                end
                pending = MarkLootButton(button, slot, pending)
            end)
        end)
    end
    return pending
end

-- The reward button is the wide row. The inventory image is the square on the left.
local function QuestIcon(button)
    if not button then
        return nil
    end
    local icon = button.Icon or button.icon
    if type(icon) == "table" and icon.GetObjectType then
        return icon
    end
    local name = button.GetName and button:GetName()
    if type(name) == "string" then
        icon = _G[name .. "Icon"] or _G[name .. "IconTexture"]
        if type(icon) == "table" and icon.GetObjectType then
            return icon
        end
    end
    local nested = button.itemButton or button.ItemButton or button.IconButton
    if type(nested) == "table" then
        icon = nested.Icon or nested.icon
        if type(icon) == "table" and icon.GetObjectType then
            return icon
        end
        if nested.CreateTexture then
            return nested
        end
    end
    if not button.GetRegions then
        return nil
    end
    local leftOk, left = pcall(button.GetLeft, button)
    local widthOk, width = pcall(button.GetWidth, button)
    local mid = nil
    if leftOk and widthOk and type(left) == "number" and type(width) == "number" and not ns.Secret(left) and not ns.Secret(width) and width > 0 then
        mid = left + (width * 0.45)
    end
    local regions = { button:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then
            local wOk, w = pcall(region.GetWidth, region)
            local hOk, h = pcall(region.GetHeight, region)
            local lOk, regionLeft = pcall(region.GetLeft, region)
            if wOk and hOk and type(w) == "number" and type(h) == "number" and not ns.Secret(w) and not ns.Secret(h) then
                local square = w >= 24 and w <= 48 and h >= 24 and h <= 48 and math.abs(w - h) <= 4
                local onLeft = true
                if mid and lOk and type(regionLeft) == "number" and not ns.Secret(regionLeft) then
                    onLeft = regionLeft < mid
                end
                if square and onLeft then
                    return region
                end
            end
        end
    end
    return nil
end

local function QuestChoiceButton(index)
    local button = _G["QuestRewardItem" .. index] or _G["QuestInfoRewardsFrameQuestInfoItem" .. index]
    if button then
        return button
    end
    local frame = QuestInfoRewardsFrame
    if frame and type(frame.RewardButtons) == "table" then
        return frame.RewardButtons[index]
    end
    return nil
end

local function QuestVisible()
    if QuestFrame and QuestFrame.IsShown and QuestFrame:IsShown() then
        return true
    end
    if QuestInfoRewardsFrame and QuestInfoRewardsFrame.IsShown and QuestInfoRewardsFrame:IsShown() then
        return true
    end
    return false
end

local function ItemSellPrice(link)
    if type(link) ~= "string" or ns.Secret(link) then
        return nil, false
    end
    local function read(fn)
        if type(fn) ~= "function" then
            return nil, false
        end
        local ok, first, _, _, _, _, _, _, _, _, _, sell = pcall(fn, link)
        if not ok or ns.Secret(first) then
            return nil, false
        end
        if type(first) == "table" then
            local value = first.sellPrice
            if type(value) == "number" and not ns.Secret(value) then
                return value, true
            end
            return nil, false
        end
        if type(first) == "string" then
            if type(sell) == "number" and not ns.Secret(sell) then
                return sell, true
            end
            return 0, true
        end
        return nil, false
    end
    local price, known = read(C_Item and C_Item.GetItemInfo)
    if not known then
        price, known = read(GetItemInfo)
    end
    if not known then
        if ns.RequestItem and ns.LinkID then
            ns.RequestItem(ns.LinkID(link))
        end
        return nil, false
    end
    return price, true
end

-- Green on every reward that beats what is equipped. When no choice is an
-- upgrade, one coin marks the choice that vendors for the most.
local function PaintQuestRewards(rows)
    local pending = false
    local choiceUpgrade = false
    local choicePending = false
    for i = 1, #rows do
        local row = rows[i]
        local result = row.result
        if result and result.verdict == "pending" then
            pending = true
            if row.kind ~= "reward" then
                choicePending = true
            end
        elseif result and result.verdict == "upgrade" and row.button then
            ShowArrow(row.button, 0.25, 1, 0.45, QuestIcon(row.button))
            if row.kind ~= "reward" then
                choiceUpgrade = true
            end
        end
    end
    if choiceUpgrade or choicePending then
        return pending
    end
    local bestValue = 0
    local bestButton = nil
    local waiting = false
    for i = 1, #rows do
        local row = rows[i]
        if row.kind ~= "reward" and row.button and type(row.link) == "string" then
            local price, known = ItemSellPrice(row.link)
            if not known then
                waiting = true
            elseif type(price) == "number" and price > bestValue then
                bestValue = price
                bestButton = row.button
            end
        end
    end
    if waiting then
        return true
    end
    if bestButton then
        ShowArrow(bestButton, 1, 1, 1, QuestIcon(bestButton), true)
    end
    return pending
end

local function MarkQuest()
    if not ns.char or ns.char.questAdvisor == false or not QuestVisible() then
        return false
    end
    if type(GetNumQuestChoices) ~= "function" or type(GetQuestItemLink) ~= "function" then
        return false
    end
    local count = GetNumQuestChoices()
    if type(count) ~= "number" or ns.Secret(count) or count < 1 then
        return false
    end
    local rows = {}
    for i = 1, count do
        local link = GetQuestItemLink("choice", i)
        if type(link) ~= "string" or ns.Secret(link) then
            link = nil
        end
        local result = link and ns.Evaluate(link) or nil
        rows[#rows + 1] = {
            button = QuestChoiceButton(i),
            kind = "choice",
            result = result,
            link = link,
        }
    end
    return PaintQuestRewards(rows)
end

local function FrameShown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

-- The quest log is not the turn-in window. Era uses QuestLogItem buttons.
-- Forever's log is the map details pane, whose rewards live on MapQuestInfoRewardsFrame.
local function QuestLogRewardsVisible()
    if FrameShown(QuestFrame) and not (QuestInfoFrame and QuestInfoFrame.questLog) then
        return false
    end
    if FrameShown(QuestLogFrame) or FrameShown(QuestLogPopupDetailFrame) then
        return true
    end
    if FrameShown(MapQuestInfoRewardsFrame) then
        return true
    end
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if details and FrameShown(details) then
        return true
    end
    if QuestInfoFrame and QuestInfoFrame.questLog and FrameShown(QuestInfoRewardsFrame) then
        return true
    end
    return false
end

local function LogItemLink(kind, index)
    if kind == "choice" and type(GetQuestLogChoiceInfo) == "function" then
        pcall(GetQuestLogChoiceInfo, index)
    elseif kind == "reward" and type(GetQuestLogRewardInfo) == "function" then
        pcall(GetQuestLogRewardInfo, index)
    end
    if type(GetQuestLogItemLink) == "function" then
        local ok, link = pcall(GetQuestLogItemLink, kind, index)
        if ok and type(link) == "string" and not ns.Secret(link) and link:find("item:", 1, true) then
            return link
        end
    end
    local itemID = nil
    if kind == "choice" and type(GetQuestLogChoiceInfo) == "function" then
        local ok, _, _, _, _, _, id = pcall(GetQuestLogChoiceInfo, index)
        if ok then
            itemID = id
        end
    elseif kind == "reward" and type(GetQuestLogRewardInfo) == "function" then
        local ok, _, _, _, _, _, id = pcall(GetQuestLogRewardInfo, index)
        if ok then
            itemID = id
        end
    end
    if type(itemID) == "number" and not ns.Secret(itemID) and itemID > 0 then
        return "item:" .. itemID
    end
    return nil
end

local function AddLogButton(list, seen, button)
    if type(button) ~= "table" or seen[button] or not button.IsShown or not button:IsShown() then
        return
    end
    local kind = button.type
    if kind ~= "choice" and kind ~= "reward" then
        return
    end
    if button.objectType and button.objectType ~= "item" then
        return
    end
    if button.rewardType and button.rewardType ~= "item" then
        return
    end
    local index = button.GetID and button:GetID()
    if type(index) ~= "number" or ns.Secret(index) or index < 1 then
        return
    end
    seen[button] = true
    list[#list + 1] = { button = button, kind = kind, index = index }
end

local function AddLogFrameButtons(list, seen, frame)
    if not frame then
        return
    end
    if type(frame.RewardButtons) == "table" then
        for i = 1, #frame.RewardButtons do
            AddLogButton(list, seen, frame.RewardButtons[i])
        end
    end
    if type(frame.activeRewardElements) == "table" then
        for i = 1, #frame.activeRewardElements do
            AddLogButton(list, seen, frame.activeRewardElements[i])
        end
    end
end

local function QuestLogButtons()
    local list = {}
    local seen = {}
    for i = 1, 20 do
        AddLogButton(list, seen, _G["QuestLogItem" .. i])
    end
    AddLogFrameButtons(list, seen, MapQuestInfoRewardsFrame)
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    if details then
        AddLogFrameButtons(list, seen, details.RewardsFrame)
        if details.RewardsFrameContainer then
            AddLogFrameButtons(list, seen, details.RewardsFrameContainer.RewardsFrame)
        end
    end
    if QuestInfoFrame and QuestInfoFrame.questLog then
        AddLogFrameButtons(list, seen, QuestInfoFrame.rewardsFrame)
        AddLogFrameButtons(list, seen, QuestInfoRewardsFrame)
    end
    return list
end

local function MarkQuestLog()
    if not ns.char or ns.char.questAdvisor == false or not QuestLogRewardsVisible() then
        return false
    end
    local buttons = QuestLogButtons()
    if #buttons < 1 then
        return false
    end
    local rows = {}
    for i = 1, #buttons do
        local row = buttons[i]
        local link = LogItemLink(row.kind, row.index)
        local result = link and ns.Evaluate(link) or nil
        rows[#rows + 1] = { button = row.button, kind = row.kind, result = result, link = link }
    end
    return PaintQuestRewards(rows)
end

local function MarkMerchant()
    if not ns.char or ns.char.lootAdvisor == false then
        return false
    end
    if type(GetMerchantNumItems) ~= "function" or type(GetMerchantItemLink) ~= "function" then
        return false
    end
    if MerchantFrame and MerchantFrame.IsShown and not MerchantFrame:IsShown() then
        return false
    end
    local num = GetMerchantNumItems()
    if type(num) ~= "number" or ns.Secret(num) or num < 1 then
        return false
    end
    local per = MERCHANT_ITEMS_PER_PAGE
    if type(per) ~= "number" or ns.Secret(per) or per < 1 then
        per = 10
    end
    local page = MerchantFrame and MerchantFrame.page
    if type(page) ~= "number" or ns.Secret(page) or page < 1 then
        page = 1
    end
    local offset = (page - 1) * per
    local pending = false
    for i = 1, per do
        local index = offset + i
        if index <= num then
            local link = GetMerchantItemLink(index)
            if type(link) == "string" and not ns.Secret(link) then
                local result = ns.Evaluate(link)
                if result.verdict == "pending" then
                    pending = true
                elseif result.verdict == "upgrade" then
                    ShowArrow(_G["MerchantItem" .. i .. "ItemButton"], 0.25, 1, 0.45)
                end
            end
        end
    end
    return pending
end

local PAPER = {
    { name = "CharacterHeadSlot", slot = "HEAD", families = { "INVTYPE_HEAD" } },
    { name = "CharacterNeckSlot", slot = "NECK", families = { "INVTYPE_NECK" } },
    { name = "CharacterShoulderSlot", slot = "SHOULDER", families = { "INVTYPE_SHOULDER" } },
    { name = "CharacterBackSlot", slot = "BACK", families = { "INVTYPE_CLOAK" } },
    { name = "CharacterChestSlot", slot = "CHEST", families = { "INVTYPE_CHEST" } },
    { name = "CharacterWristSlot", slot = "WRIST", families = { "INVTYPE_WRIST" } },
    { name = "CharacterHandsSlot", slot = "HAND", families = { "INVTYPE_HAND" } },
    { name = "CharacterWaistSlot", slot = "WAIST", families = { "INVTYPE_WAIST" } },
    { name = "CharacterLegsSlot", slot = "LEGS", families = { "INVTYPE_LEGS" } },
    { name = "CharacterFeetSlot", slot = "FEET", families = { "INVTYPE_FEET" } },
    { name = "CharacterFinger0Slot", slot = "FINGER1", families = { "INVTYPE_FINGER" } },
    { name = "CharacterFinger1Slot", slot = "FINGER2", families = { "INVTYPE_FINGER" } },
    { name = "CharacterTrinket0Slot", slot = "TRINKET1", families = { "INVTYPE_TRINKET" } },
    { name = "CharacterTrinket1Slot", slot = "TRINKET2", families = { "INVTYPE_TRINKET" } },
    { name = "CharacterRangedSlot", slot = "RANGED", families = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT" } },
}

local function MarkPaper()
    if not ns.char or ns.char.bagAdvisor == false or type(ns.bagBest) ~= "table" then
        return false
    end
    if CharacterFrame and CharacterFrame.IsShown and not CharacterFrame:IsShown() then
        return false
    end
    local slots = ns.Slots()
    local pending = false
    for i = 1, #PAPER do
        local row = PAPER[i]
        local button = _G[row.name]
        local slotId = slots[row.slot]
        local equipped = slotId and ns.EquippedLink(slotId) or nil
        local equippedScore = 0
        local equippedLink = nil
        if equipped then
            local result = ns.Evaluate(equipped)
            if result.verdict == "pending" then
                pending = true
            elseif type(result.score) == "number" and result.verdict ~= "cannot" and result.verdict ~= "ignore" then
                equippedScore = result.score
                equippedLink = result.link or equipped
            end
        end
        local best = nil
        for f = 1, #row.families do
            local candidate = ns.bagBest[row.families[f]]
            if type(candidate) == "table" and type(candidate.score) == "number" and (not best or candidate.score > best.score) then
                best = candidate
            end
        end
        if best and button and best.score > equippedScore and best.link ~= equippedLink then
            ShowArrow(button, 0.25, 1, 0.45)
        end
    end
    return pending
end

local function BestKey(best)
    if type(best) ~= "table" then
        return ""
    end
    local bits = {}
    for family, row in pairs(best) do
        bits[#bits + 1] = tostring(family) .. "=" .. tostring(row and row.score) .. tostring(row and row.link or "")
    end
    table.sort(bits)
    return table.concat(bits, ";")
end

-- True when the bag arrow should show. Nil is not used: a pending item
-- stays false until the next advisor pass, which asks Baganator to redraw.
local function BagUpgrade(itemLink)
    if not ns.ready or not ns.char or ns.char.enabled == false or ns.char.bagAdvisor == false then
        return false
    end
    if type(itemLink) ~= "string" or ns.Secret(itemLink) then
        return false
    end
    local result = ns.Evaluate(itemLink)
    if not result or result.verdict == "pending" then
        return false
    end
    return result.verdict == "upgrade"
end

local function RefreshBaganator()
    if type(Baganator) ~= "table" or type(Baganator.API) ~= "table" or type(Baganator.API.RequestItemButtonsRefresh) ~= "function" then
        return
    end
    local reason = Baganator.Constants and Baganator.Constants.RefreshReason
    if type(reason) == "table" then
        Baganator.API.RequestItemButtonsRefresh({ reason.ItemWidgets, reason.Searches })
    else
        Baganator.API.RequestItemButtonsRefresh()
    end
end

-- Baganator owns the button layout, so the arrow is one of its corner icons.
-- Top-left and first in line, ahead of the junk coin, which is the same
-- overlap the Bagnon buttons needed a child frame to cover.
local function RegisterBaganator()
    if ns._fuBaganator or type(Baganator) ~= "table" or type(Baganator.API) ~= "table" then
        return
    end
    if type(Baganator.API.RegisterCornerWidget) ~= "function" then
        return
    end
    ns._fuBaganator = true
    local ok, err = pcall(function()
        Baganator.API.RegisterCornerWidget("Forever Upgrade", "forever_upgrade", function(_, details)
            return BagUpgrade(details and details.itemLink)
        end, function(itemButton)
            local arrow = itemButton:CreateTexture(nil, "OVERLAY")
            arrow:SetTexture("Interface\\AddOns\\ForeverUpgrade\\Media\\UpgradeArrow")
            arrow:SetSize(16, 16)
            return arrow
        end, { corner = "top_left", priority = 1 })
        if type(Baganator.API.RegisterUpgradePlugin) == "function" then
            Baganator.API.RegisterUpgradePlugin("Forever Upgrade", "forever_upgrade", function(itemLink)
                return BagUpgrade(itemLink)
            end)
        end
    end)
    if not ok and not ns.baganatorReported then
        ns.baganatorReported = true
        ns.Print("Baganator: " .. tostring(err))
    end
end

local function DoRefresh()
    if not ns.ready or not ns.char or ns.char.enabled == false then
        HideMarked()
        local had = type(ns.bagBest) == "table"
        ns.bagBest = nil
        if had then
            ns.bagGen = (ns.bagGen or 0) + 1
            if ns.RefreshTooltip then
                ns.RefreshTooltip()
            end
        end
        RefreshBaganator()
        return
    end
    local before = BestKey(ns.bagBest)
    HideMarked()
    local pending = false
    if ns.char.bagAdvisor ~= false then
        if ScanBags() then
            pending = true
        end
        if MarkBags() then
            pending = true
        end
    else
        ns.bagBest = nil
    end
    if MarkLoot() then
        pending = true
    end
    if MarkMerchant() then
        pending = true
    end
    if MarkPaper() then
        pending = true
    end
    if MarkQuest() then
        pending = true
    end
    if MarkQuestLog() then
        pending = true
    end
    if pending then
        queued = true
    end
    if BestKey(ns.bagBest) ~= before then
        ns.bagGen = (ns.bagGen or 0) + 1
        if ns.RefreshTooltip then
            ns.RefreshTooltip()
        end
    end
    RefreshBaganator()
end

local HookFrames

function ns.RefreshAdvisors()
    queued = true
    if running then
        return
    end
    running = true
    local function pump()
        if not queued then
            running = false
            return
        end
        queued = false
        if HookFrames then
            HookFrames()
        end
        local ok, err = pcall(DoRefresh)
        if not ok and not ns.advisorReported then
            ns.advisorReported = true
            ns.Print("Advisor error: " .. tostring(err))
        end
        if queued and C_Timer and C_Timer.After then
            C_Timer.After(0.2, pump)
        else
            running = false
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, pump)
    else
        pump()
    end
end

local function Wrap(event)
    local prev = ns.handlers[event]
    ns.On(event, function(...)
        if prev then
            prev(...)
        end
        ns.RefreshAdvisors()
    end)
end

Wrap("BAG_UPDATE_DELAYED")
Wrap("PLAYER_EQUIPMENT_CHANGED")
Wrap("ITEM_DATA_LOAD_RESULT")
Wrap("GET_ITEM_INFO_RECEIVED")

local function OnAdvisorEvent()
    ns.RefreshAdvisors()
end

ns.On("LOOT_OPENED", OnAdvisorEvent)
ns.On("LOOT_SLOT_CHANGED", OnAdvisorEvent)
ns.On("LOOT_CLOSED", OnAdvisorEvent)
ns.On("QUEST_COMPLETE", OnAdvisorEvent)
ns.On("QUEST_ITEM_UPDATE", OnAdvisorEvent)
ns.On("QUEST_FINISHED", OnAdvisorEvent)
ns.On("BANKFRAME_OPENED", OnAdvisorEvent)
ns.On("MERCHANT_SHOW", OnAdvisorEvent)
ns.On("MERCHANT_UPDATE", OnAdvisorEvent)
ns.On("MERCHANT_CLOSED", OnAdvisorEvent)

local function HookFrame(frame)
    if not frame or frame._fuAdvisor or not frame.HookScript then
        return
    end
    frame._fuAdvisor = true
    frame:HookScript("OnShow", function()
        ns.RefreshAdvisors()
    end)
end

local function HookQuestLog()
    if ns._fuQuestLogHook or type(hooksecurefunc) ~= "function" then
        return
    end
    ns._fuQuestLogHook = true
    if type(QuestInfo_Display) == "function" then
        hooksecurefunc("QuestInfo_Display", function(template)
            if type(template) == "table" and template.questLog then
                ns.RefreshAdvisors()
            end
        end)
    end
    if type(QuestFrameItems_Update) == "function" then
        hooksecurefunc("QuestFrameItems_Update", function(questState)
            if questState == "QuestLog" then
                ns.RefreshAdvisors()
            end
        end)
    end
end

HookFrames = function()
    RegisterBaganator()
    HookQuestLog()
    HookFrame(ContainerFrameCombinedBags)
    HookFrame(LootFrame)
    HookFrame(MerchantFrame)
    HookFrame(CharacterFrame)
    HookFrame(QuestFrame)
    HookFrame(QuestLogFrame)
    HookFrame(QuestLogPopupDetailFrame)
    HookFrame(QuestMapFrame)
    HookFrame(BankFrame)
    local frames = NUM_CONTAINER_FRAMES
    if type(frames) ~= "number" or ns.Secret(frames) or frames < 1 then
        frames = 13
    end
    for i = 1, frames do
        HookFrame(_G["ContainerFrame" .. i])
    end
end

ns.On("PLAYER_ENTERING_WORLD", function()
    HookFrames()
    ns.RefreshAdvisors()
end)

RegisterBaganator()
