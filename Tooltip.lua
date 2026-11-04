local _, ns = ...

local function TooltipItem(tooltip, data)
    local link, guid = nil, nil
    if type(data) == "table" then
        if type(data.hyperlink) == "string" and not ns.Secret(data.hyperlink) then
            link = data.hyperlink
        end
        if data.guid and not ns.Secret(data.guid) and type(data.guid) == "string" then
            guid = data.guid
        end
        if not link and guid and C_Item and C_Item.GetItemLinkByGUID then
            local byGuid = C_Item.GetItemLinkByGUID(guid)
            if type(byGuid) == "string" and not ns.Secret(byGuid) then
                link = byGuid
            end
        end
    end
    if not link and TooltipUtil and TooltipUtil.GetDisplayedItem then
        local ok, name, itemLink = pcall(TooltipUtil.GetDisplayedItem, tooltip)
        if ok then
            if type(name) == "string" and type(itemLink) == "string" then
                link = itemLink
            elseif type(name) == "table" then
                link = name.hyperlink or name.link
            end
        end
    end
    if not link and tooltip.GetItem then
        local ok, _, itemLink = pcall(tooltip.GetItem, tooltip)
        if ok and type(itemLink) == "string" then
            link = itemLink
        end
    end
    return link, guid
end

function ns.HoveredLink()
    local link = TooltipItem(GameTooltip, nil)
    if type(link) == "string" then
        return link
    end
    if ItemRefTooltip and ItemRefTooltip.IsShown and ItemRefTooltip:IsShown() then
        link = TooltipItem(ItemRefTooltip, nil)
        if type(link) == "string" then
            return link
        end
    end
    return nil
end

local function ShiftDown()
    if type(IsShiftKeyDown) ~= "function" then
        return false
    end
    local down = IsShiftKeyDown()
    if ns.Secret(down) then
        return false
    end
    return down and true or false
end

-- Half of Pawn's 32px arrow. The Blizzard micro-stream points down, and a
-- tex-coord flip in the text tag blew the line apart, so these point the
-- right way already.
local ARROW_UP = "|TInterface\\AddOns\\ForeverUpgrade\\Media\\UpgradeArrow:16|t"
local ARROW_DOWN = "|TInterface\\AddOns\\ForeverUpgrade\\Media\\DowngradeArrow:16|t"

-- Whole percent versus the equipped piece. 36 means the item is 36% higher.
-- No number when the equipped score is 0, because there is no baseline.
function ns.UpgradePercent(score, equipped)
    if type(score) ~= "number" or type(equipped) ~= "number" or equipped <= 0 then
        return nil
    end
    local pct = (score - equipped) / equipped * 100
    local rounded = tonumber(string.format("%.0f", math.abs(pct))) or 0
    if rounded < 1 and math.abs(pct) > 0 then
        rounded = 1
    end
    return rounded
end

local function SpecLine(label, verdict, score, equipped)
    local name = "|cffffffff" .. (label or "Spec") .. ":|r "
    local pct = ns.UpgradePercent(score, equipped)
    if verdict == "upgrade" then
        local body = pct and ("+" .. pct .. "% upgrade") or "upgrade"
        return name .. ARROW_UP .. " |cff00ff00" .. body .. "|r"
    end
    if verdict == "downgrade" then
        local body = pct and ("-" .. pct .. "% downgrade") or "downgrade"
        return name .. ARROW_DOWN .. " |cffff6666" .. body .. "|r"
    end
    return name .. "|cffc0c0c0similar|r"
end

local function AddSpecLine(tooltip, label, verdict, score, equipped)
    if verdict ~= "upgrade" and verdict ~= "downgrade" and verdict ~= "similar" then
        return
    end
    tooltip:AddLine(SpecLine(label, verdict, score, equipped), 1, 1, 1, true)
end

local function AddOtherSpecs(tooltip, link, guid, result)
    if not ns.char or ns.char.otherSpecs == false or not result.spec then
        return
    end
    local specs = ns.SpecsForClass(ns.ClassFile())
    if type(specs) ~= "table" then
        return
    end
    for i = 1, #specs do
        local spec = specs[i]
        if spec ~= result.spec then
            local alt = ns.Evaluate(link, guid, spec)
            if alt and alt.verdict ~= "pending" and alt.verdict ~= "ignore" and alt.verdict ~= "cannot" then
                local label = ns.SPEC_LABEL[spec] or spec
                AddSpecLine(tooltip, label, alt.verdict, alt.score, alt.equippedScore)
            end
        end
    end
end

local function AddPin(tooltip, result)
    local pin = ns.char and ns.char.pin
    if type(pin) ~= "string" or pin == result.link then
        return
    end
    local other = ns.Evaluate(pin, nil, result.spec)
    local name = pin:match("%[(.-)%]") or "that item"
    if other.verdict == "pending" then
        tooltip:AddLine("Pinned item is still loading.", 0.7, 0.7, 0.7, true)
        return
    end
    if other.name then
        name = other.name
    end
    if other.verdict == "ignore" then
        tooltip:AddLine("Pinned " .. name .. " is not gear.", 0.7, 0.7, 0.7, true)
        return
    end
    if other.verdict == "cannot" then
        tooltip:AddLine("Pinned " .. name .. " cannot be equipped.", 0.7, 0.7, 0.7, true)
        return
    end
    if not result.family or other.family ~= result.family or type(other.score) ~= "number" or type(result.score) ~= "number" then
        tooltip:AddLine("Pinned " .. name .. " is a different slot.", 0.7, 0.7, 0.7, true)
        return
    end
    local delta = result.score - other.score
    local pct = ns.UpgradePercent(result.score, other.score)
    local text
    local r, g, b = 0.75, 0.75, 0.75
    if delta > 0 then
        r, g, b = 0.2, 1, 0.35
        text = pct and ("+" .. pct .. "% vs pinned " .. name) or ("Upgrade vs pinned " .. name)
    elseif delta < 0 then
        r, g, b = 1, 0.4, 0.35
        text = pct and ("-" .. pct .. "% vs pinned " .. name) or ("Downgrade vs pinned " .. name)
    else
        text = "Similar to pinned " .. name
    end
    tooltip:AddLine(text, r, g, b, true)
end

local function AddBagBest(tooltip, result)
    local best = ns.bagBest and result.family and ns.bagBest[result.family]
    if type(best) ~= "table" or type(best.score) ~= "number" or type(result.score) ~= "number" then
        return
    end
    if best.link and result.link and best.link == result.link then
        return
    end
    if best.score <= result.score then
        return
    end
    local pct = ns.UpgradePercent(best.score, result.score)
    local text = "Better in your bags: " .. (best.name or "an item")
    if pct then
        text = text .. ", +" .. pct .. "%"
    end
    tooltip:AddLine(text, 0.45, 0.9, 0.55, true)
end

local function BreakdownText(result)
    if not result or type(result.parts) ~= "table" or #result.parts == 0 then
        return nil
    end
    local bits = {}
    local seen = {}
    local i
    for i = 1, #result.parts do
        if result.parts[i].racial and #bits < 4 then
            bits[#bits + 1] = result.parts[i].text
            seen[i] = true
        end
    end
    for i = 1, #result.parts do
        if not seen[i] and #bits < 4 then
            bits[#bits + 1] = result.parts[i].text
        end
    end
    if #bits == 0 then
        return nil
    end
    return table.concat(bits, ", ")
end

local function AddBreakdown(tooltip, result)
    local text = BreakdownText(result)
    if not text then
        return false
    end
    tooltip:AddLine(text, 0.8, 0.78, 0.62, true)
    if tooltip.NumLines then
        local count = tooltip:NumLines()
        if type(count) == "number" and not ns.Secret(count) then
            tooltip._fuShiftLine = count
            tooltip._fuShiftText = text
        end
    end
    return true
end

local function AddNote(tooltip, result, link, guid)
    if result.hasProc and result.hasSet then
        tooltip:AddLine("Proc and set bonus are not scored.", 0.65, 0.65, 0.65, true)
    elseif result.hasProc then
        tooltip:AddLine("Proc is not scored.", 0.65, 0.65, 0.65, true)
    elseif result.hasSet then
        tooltip:AddLine("Set bonus is not scored.", 0.65, 0.65, 0.65, true)
    end
    if result.hasUse then
        tooltip:AddLine("On-use effect is not scored.", 0.65, 0.65, 0.65, true)
    end
    if result.note then
        tooltip:AddLine(result.note, 0.75, 0.75, 0.75, true)
    end
    if result.socketIdle then
        tooltip:AddLine("Empty socket. The socket bonus is not in the score.", 0.75, 0.75, 0.75, true)
    end
    if link then
        AddPin(tooltip, result)
        AddBagBest(tooltip, result)
    end
    if ShiftDown() then
        AddBreakdown(tooltip, result)
    end
end

local function Header(result)
    local text = "Forever Upgrade"
    if result.custom then
        text = text .. " - custom"
    end
    return text
end

local function ActiveLabel(result)
    local label = result.specLabel or "Spec"
    if result.lowConfidence then
        label = label .. "?"
    end
    return label
end

local function LineCount(tooltip)
    if not tooltip.NumLines then
        return nil
    end
    local count = tooltip:NumLines()
    if type(count) ~= "number" or ns.Secret(count) then
        return nil
    end
    return count
end

local function LineString(tooltip, index)
    local name = tooltip.GetName and tooltip:GetName()
    if type(name) ~= "string" then
        return nil
    end
    local row = _G[name .. "TextLeft" .. index]
    if not row or not row.GetText then
        return nil
    end
    local ok, text = pcall(row.GetText, row)
    if not ok or type(text) ~= "string" or ns.Secret(text) then
        return nil
    end
    return text
end

-- The client rebuilds item tooltips shortly after they open (TOOLTIP_DATA_UPDATE)
-- and that clears every line an addon appended. A later pass has to add the
-- comparison again. Trust the line only while it is still on screen.
local function HasUpgradeLine(tooltip)
    local count = LineCount(tooltip)
    if not count then
        return false
    end
    for i = count, 1, -1 do
        local text = LineString(tooltip, i)
        if text and text:sub(1, 16) == "Forever Upgrade" then
            return true
        end
    end
    return false
end

local function StillShown(tooltip, stamp)
    return tooltip._fuStamp == stamp and HasUpgradeLine(tooltip)
end

function ns.Annotate(tooltip, data)
    if not ns.ready or not ns.char or ns.char.enabled == false then
        return
    end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
        return
    end
    local link, guid = TooltipItem(tooltip, data)
    if not link then
        return
    end
    local shift = ShiftDown() and "s" or "n"
    local info = ns.GetSpecInfo()
    local stamp = table.concat({
        link,
        tostring(guid or ""),
        info.spec or "",
        info.custom and "c" or "d",
        tostring(ns.cacheGen or 0),
        tostring(ns.bagGen or 0),
        tostring(ns.char.pin or ""),
        shift,
    }, "|")
    if StillShown(tooltip, stamp) or StillShown(tooltip, stamp .. "|p") then
        return
    end

    local result = ns.Evaluate(link, guid)
    tooltip._fuShiftLine = nil
    tooltip._fuShiftText = nil
    if result.verdict == "ignore" then
        tooltip._fuStamp = nil
        return
    end
    if result.verdict == "pending" then
        tooltip._fuStamp = stamp .. "|p"
        tooltip:AddLine("Forever Upgrade - reading item...", 0.7, 0.7, 0.7)
        return
    end

    tooltip._fuStamp = stamp
    tooltip:AddLine(Header(result), 0.83, 0.69, 0.35)

    if result.verdict == "cannot" then
        tooltip:AddLine(result.reason or "Cannot equip.", 1, 0.35, 0.3, true)
        return
    end
    if result.verdict == "equipped" then
        tooltip:AddLine("Equipped", 0.75, 0.75, 0.75, true)
        AddNote(tooltip, result, link, guid)
        return
    end
    if result.verdict == "info" then
        AddNote(tooltip, result, link, guid)
        return
    end

    AddSpecLine(tooltip, ActiveLabel(result), result.verdict, result.score, result.equippedScore)
    AddOtherSpecs(tooltip, link, guid, result)
    AddNote(tooltip, result, link, guid)
end

local function OnItem(tooltip, data)
    if not tooltip or tooltip._fuBusy then
        return
    end
    tooltip._fuBusy = true
    local ok, err = pcall(ns.Annotate, tooltip, data)
    tooltip._fuBusy = false
    if not ok and not ns.reported then
        ns.reported = true
        ns.Print("Tooltip error: " .. tostring(err))
    end
end

local function HookHide(tooltip)
    if not tooltip or tooltip._fuHooked then
        return
    end
    tooltip._fuHooked = true
    tooltip:HookScript("OnHide", function(self)
        self._fuStamp = nil
        self._fuRebuilding = nil
        self._fuShiftLine = nil
        self._fuShiftText = nil
    end)
end

-- Pawn writes its lines from hooksecurefunc on the Set* methods, after those
-- methods return, then calls Show() so the box includes the new text. Show
-- and ProcessInfo run inside Set*, before Pawn and the vendor lines, so
-- appending there leaves Forever Upgrade in the middle. These hooks are
-- registered one frame after PLAYER_LOGIN, after Pawn. AddLine stays on that
-- same call. Show() runs only when the tooltip is already visible.
local SETTERS = {
    "SetAuctionItem",
    "SetAuctionSellItem",
    "SetBagItem",
    "SetBuybackItem",
    "SetExistingSocketGem",
    "SetGuildBankItem",
    "SetHeirloomByItemID",
    "SetHyperlink",
    "SetInboxItem",
    "SetInventoryItem",
    "SetItemByID",
    "SetItemInteractionItem",
    "SetItemKey",
    "SetLootItem",
    "SetLootRollItem",
    "SetMerchantItem",
    "SetQuestItem",
    "SetQuestLogItem",
    "SetRecipeResultItem",
    "SetSendMailItem",
    "SetSocketGem",
    "SetTradePlayerItem",
    "SetTradeSkillItem",
    "SetTradeTargetItem",
    "SetTrainerService",
    "SetVoidDepositItem",
    "SetVoidItem",
    "SetVoidWithdrawalItem",
    "SetWeeklyReward",
}

local function IsItemLink(link)
    return type(link) == "string" and not ns.Secret(link) and link:find("item:", 1, true) ~= nil
end

local function ResizeIfShown(tooltip)
    if not tooltip or tooltip._fuShowGuard or type(tooltip.Show) ~= "function" or type(tooltip.IsShown) ~= "function" then
        return
    end
    local ok, shown = pcall(tooltip.IsShown, tooltip)
    if not ok or not shown then
        return
    end
    tooltip._fuShowGuard = true
    pcall(tooltip.Show, tooltip)
    tooltip._fuShowGuard = false
end

local function AnnotateIfItem(tooltip, data)
    if not tooltip or tooltip._fuBusy or tooltip._fuShowGuard then
        return
    end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
        return
    end
    local link = TooltipItem(tooltip, data)
    if not IsItemLink(link) then
        return
    end
    local had = HasUpgradeLine(tooltip)
    OnItem(tooltip, data)
    if not had and HasUpgradeLine(tooltip) then
        ResizeIfShown(tooltip)
    end
end

local function HookSetters(tooltip)
    if not tooltip or type(hooksecurefunc) ~= "function" then
        return false
    end
    local hooked = false
    local i
    for i = 1, #SETTERS do
        local method = SETTERS[i]
        if type(tooltip[method]) == "function" then
            hooksecurefunc(tooltip, method, function(self)
                AnnotateIfItem(self, nil)
            end)
            hooked = true
        end
    end
    if hooked then
        HookHide(tooltip)
    end
    return hooked
end

local hooksInstalled = false

local function InstallTooltipHooks()
    if hooksInstalled then
        return
    end
    hooksInstalled = true
    local game = HookSetters(GameTooltip)
    local ref = HookSetters(ItemRefTooltip)
    if C_TradeSkillUI and type(C_TradeSkillUI.SetTooltipRecipeResultItem) == "function" and type(hooksecurefunc) == "function" then
        hooksecurefunc(C_TradeSkillUI, "SetTooltipRecipeResultItem", function()
            AnnotateIfItem(GameTooltip, nil)
        end)
        game = true
    end
    ns.tooltipOK = (game or ref) and true or false
end

local prevLogin = ns.handlers.PLAYER_LOGIN
ns.On("PLAYER_LOGIN", function(...)
    if prevLogin then
        prevLogin(...)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, InstallTooltipHooks)
    else
        InstallTooltipHooks()
    end
end)

-- RefreshData rebuilds the tooltip from addon code. On this client that
-- drops the frame until the mouse leaves and comes back. Replay the secure
-- setter for equipment and item-load updates, and never call RefreshData.
-- Shift does not come through here.
local function IsItemTooltip(tooltip)
    if not tooltip or not tooltip.GetPrimaryTooltipData or not Enum or not Enum.TooltipDataType then
        return false
    end
    local ok, isItem = pcall(function()
        local data = tooltip:GetPrimaryTooltipData()
        if type(data) ~= "table" then
            return false
        end
        local tooltipType = data.type
        if tooltipType == nil or ns.Secret(tooltipType) then
            return false
        end
        return tooltipType == Enum.TooltipDataType.Item
    end)
    return ok and isItem or false
end

local function ReshowItem(tooltip)
    if not tooltip.GetPrimaryTooltipInfo then
        return false
    end
    local ok, info = pcall(tooltip.GetPrimaryTooltipInfo, tooltip)
    if not ok or type(info) ~= "table" then
        return false
    end
    local getterName = info.getterName
    if type(getterName) ~= "string" or ns.Secret(getterName) or getterName:sub(1, 3) ~= "Get" then
        return false
    end
    local setter = tooltip["Set" .. getterName:sub(4)]
    if type(setter) ~= "function" then
        return false
    end
    local args = info.getterArgs
    if type(args) ~= "table" then
        return pcall(setter, tooltip)
    end
    if SafeUnpack then
        return pcall(setter, tooltip, SafeUnpack(args))
    end
    local count = args.n
    if type(count) ~= "number" or ns.Secret(count) then
        count = #args
    end
    return pcall(setter, tooltip, unpack(args, 1, count))
end

local function Rerender(tooltip)
    if not tooltip or not tooltip.IsShown or not tooltip:IsShown() then
        return
    end
    if tooltip._fuRebuilding then
        return
    end
    if IsItemTooltip(tooltip) then
        tooltip._fuStamp = nil
        tooltip._fuRebuilding = true
        pcall(ReshowItem, tooltip)
        tooltip._fuRebuilding = false
        return
    end
    -- Classic Era has no tooltip-data accessor. Re-set the item when this
    -- tooltip is already showing gear, so equipment updates redraw.
    if not tooltip.GetItem or not tooltip.SetHyperlink then
        return
    end
    local ok, _, itemLink = pcall(tooltip.GetItem, tooltip)
    if not ok or type(itemLink) ~= "string" or ns.Secret(itemLink) then
        return
    end
    tooltip._fuStamp = nil
    tooltip._fuRebuilding = true
    pcall(tooltip.SetHyperlink, tooltip, itemLink)
    tooltip._fuRebuilding = false
end

function ns.RefreshTooltip()
    Rerender(GameTooltip)
    Rerender(ItemRefTooltip)
end

function ns.DebugTooltip()
    local link = TooltipItem(GameTooltip, nil)
    if not link and ItemRefTooltip and ItemRefTooltip:IsShown() then
        link = TooltipItem(ItemRefTooltip, nil)
    end
    if not link then
        ns.Print("Hover an item, then run /fu debug.")
        return
    end
    local parsed = ns.ParseItem(link)
    local bits = {}
    for key, value in pairs(parsed.stats) do
        if type(value) == "number" then
            bits[#bits + 1] = key .. "=" .. ns.FormatNum(value)
        end
    end
    table.sort(bits)
    ns.Print(link)
    ns.Print(#bits > 0 and table.concat(bits, ", ") or "No stats parsed.")
    if not parsed.flags.complete then
        ns.Print("Item data is not fully loaded yet.")
    end
    if parsed.flags.cannot then
        ns.Print(parsed.flags.reason or "Marked as not equippable.")
    end
end

local function ShiftRow(tooltip)
    local index = tooltip._fuShiftLine
    if type(index) ~= "number" then
        return nil
    end
    local name = tooltip.GetName and tooltip:GetName()
    if type(name) ~= "string" then
        return nil
    end
    return _G[name .. "TextLeft" .. index]
end

-- Rebuilding the item on Shift hides the tooltip until the cursor leaves
-- and comes back. The breakdown is one extra line, so edit that line in place.
local function ApplyShift(tooltip)
    if not tooltip or tooltip._fuBusy or tooltip._fuShowGuard or not tooltip.IsShown then
        return
    end
    local ok, shown = pcall(tooltip.IsShown, tooltip)
    if not ok or not shown or not HasUpgradeLine(tooltip) then
        return
    end
    local row = ShiftRow(tooltip)
    if ShiftDown() then
        if row and tooltip._fuShiftText and row.GetText and row.IsShown then
            local textOk, text = pcall(row.GetText, row)
            local shownOk, rowShown = pcall(row.IsShown, row)
            if textOk and shownOk and rowShown and text == tooltip._fuShiftText then
                return
            end
        end
        if row and tooltip._fuShiftText and row.SetText then
            row:SetText(tooltip._fuShiftText)
            if row.Show then
                row:Show()
            end
            ResizeIfShown(tooltip)
            return
        end
        local link = TooltipItem(tooltip, nil)
        if not IsItemLink(link) then
            return
        end
        local result = ns.Evaluate(link)
        if result and AddBreakdown(tooltip, result) then
            ResizeIfShown(tooltip)
        end
        return
    end
    if not row or not tooltip._fuShiftText or not row.GetText or not row.IsShown then
        return
    end
    local textOk, text = pcall(row.GetText, row)
    local shownOk, rowShown = pcall(row.IsShown, row)
    if not textOk or not shownOk or not rowShown then
        return
    end
    if text ~= tooltip._fuShiftText then
        return
    end
    row:SetText("")
    if row.Hide then
        row:Hide()
    end
    ResizeIfShown(tooltip)
end

ns.On("MODIFIER_STATE_CHANGED", function(key)
    if ns.Secret(key) then
        return
    end
    if key == "LSHIFT" or key == "RSHIFT" then
        ApplyShift(GameTooltip)
        ApplyShift(ItemRefTooltip)
    end
end)
