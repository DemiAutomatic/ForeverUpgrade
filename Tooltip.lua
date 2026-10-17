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

local function FormatDelta(n)
    if type(n) ~= "number" then
        return "0"
    end
    local text = ns.FormatScore(math.abs(n))
    if n > 0 then
        return "+" .. text
    end
    if n < 0 then
        return "-" .. text
    end
    return text
end

local function AddNote(tooltip, result)
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
    if ShiftDown() and result.parts and #result.parts > 0 then
        local bits = {}
        local limit = math.min(4, #result.parts)
        for i = 1, limit do
            bits[#bits + 1] = result.parts[i].text
        end
        tooltip:AddLine(table.concat(bits, ", "), 0.8, 0.78, 0.62, true)
    end
end

local function Header(result)
    local text = "Forever Upgrade"
    if result.specLabel then
        text = text .. " - " .. result.specLabel
        if result.lowConfidence then
            text = text .. "?"
        end
    end
    if result.custom then
        text = text .. " - custom"
    end
    return text
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
-- and that clears every line an addon appended. The post-call runs again on the
-- fresh tooltip, so a "already drawn" flag leaves the comparison visible for a
-- moment and then gone. Trust the line only while it is still on screen.
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
        shift,
    }, "|")
    if StillShown(tooltip, stamp) or StillShown(tooltip, stamp .. "|p") then
        return
    end

    local result = ns.Evaluate(link, guid)
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
        tooltip:AddLine("Equipped - score " .. ns.FormatScore(result.score or 0), 0.75, 0.75, 0.75, true)
        AddNote(tooltip, result)
        return
    end
    if result.verdict == "info" then
        tooltip:AddLine("Score " .. ns.FormatScore(result.score or 0), 0.85, 0.8, 0.55, true)
        AddNote(tooltip, result)
        return
    end

    local color = { 0.75, 0.75, 0.75 }
    local word = "Similar"
    if result.verdict == "upgrade" then
        color = { 0.25, 1, 0.45 }
        word = "Upgrade"
    elseif result.verdict == "downgrade" then
        color = { 1, 0.4, 0.35 }
        word = "Downgrade"
    end
    local line = word
    if result.delta then
        line = line .. " " .. FormatDelta(result.delta)
    end
    line = line .. " - " .. ns.FormatScore(result.score or 0)
    if result.equippedScore then
        line = line .. " vs " .. ns.FormatScore(result.equippedScore)
    end
    if result.slotText then
        line = line .. " " .. result.slotText
    end
    tooltip:AddLine(line, color[1], color[2], color[3], true)
    AddNote(tooltip, result)
end

local function OnItem(tooltip, data)
    local ok, err = pcall(ns.Annotate, tooltip, data)
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
    end)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
    ns.tooltipOK = true
    HookHide(GameTooltip)
    HookHide(ItemRefTooltip)
else
    ns.tooltipOK = false
end

-- RefreshData rebuilds whatever the tooltip is showing from the addon's
-- execution. Unit, spell, and aura tooltips then color their name with
-- UnitPlayerControlled, and that API rejects the secret unit token outside
-- untainted code. Shift, equipment, and item-load updates only need to
-- redraw an item tooltip, and the secure Set* accessor (SetBagItem,
-- SetHyperlink, ...) is the path that stays untainted.
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
    if tooltip._fuRebuilding or not IsItemTooltip(tooltip) then
        return
    end
    tooltip._fuStamp = nil
    tooltip._fuRebuilding = true
    local ok, reshowed = pcall(ReshowItem, tooltip)
    if not (ok and reshowed) and tooltip.RefreshData then
        pcall(tooltip.RefreshData, tooltip)
    end
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

ns.On("MODIFIER_STATE_CHANGED", function(key)
    if ns.Secret(key) then
        return
    end
    if key == "LSHIFT" or key == "RSHIFT" then
        ns.RefreshTooltip()
    end
end)
