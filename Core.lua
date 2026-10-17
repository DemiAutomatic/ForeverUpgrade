local addonName, ns = ...

ns.addonName = addonName
ns.cacheGen = 1
ns.ready = false
ns.handlers = {}

function ns.Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) or false
end

function ns.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4b15aForever Upgrade|r  " .. tostring(msg))
    end
end

function ns.Copy(src)
    local out = {}
    if src then
        for key, value in pairs(src) do
            out[key] = value
        end
    end
    return out
end

function ns.FormatNum(n)
    if type(n) ~= "number" then
        return "0"
    end
    local text = string.format("%.2f", n)
    text = text:gsub("(%..-)0+$", "%1")
    text = text:gsub("%.$", "")
    if text == "-0" then
        text = "0"
    end
    return text
end

function ns.FormatScore(n)
    if type(n) ~= "number" then
        return "0"
    end
    local text = string.format("%.1f", n)
    text = text:gsub("%.0$", "")
    if text == "-0" then
        text = "0"
    end
    return text
end

function ns.Changed()
    ns.cacheGen = (ns.cacheGen or 0) + 1
    if ns.RefreshOptions then
        ns.RefreshOptions()
    end
    if ns.RefreshTooltip then
        ns.RefreshTooltip()
    end
end

function ns.InitDB()
    if type(ForeverUpgradeDB) ~= "table" then
        ForeverUpgradeDB = {}
    end
    if type(ForeverUpgradeCharDB) ~= "table" then
        ForeverUpgradeCharDB = {}
    end
    ns.db = ForeverUpgradeDB
    ns.char = ForeverUpgradeCharDB
    local char = ns.char
    if char.enabled == nil then
        char.enabled = true
    end
    if type(char.custom) ~= "table" then
        char.custom = {}
    end
    if type(char.customOn) ~= "table" then
        char.customOn = {}
    end
    if type(char.margin) ~= "number" then
        char.margin = 0.5
    end
    if type(char.window) ~= "table" then
        char.window = {}
    end
    ns.ready = true
end

function ns.ClassFile()
    if type(UnitClass) ~= "function" then
        return nil
    end
    local _, classFile = UnitClass("player")
    if type(classFile) ~= "string" or ns.Secret(classFile) then
        return nil
    end
    return classFile
end

function ns.PlayerLevel()
    if type(UnitLevel) ~= "function" then
        return nil
    end
    local level = UnitLevel("player")
    if type(level) ~= "number" or ns.Secret(level) then
        return nil
    end
    return level
end

local events = CreateFrame("Frame")
ns.events = events
events:SetScript("OnEvent", function(_, event, ...)
    local handler = ns.handlers[event]
    if handler then
        handler(...)
    end
end)

function ns.On(event, handler)
    ns.handlers[event] = handler
    pcall(events.RegisterEvent, events, event)
end

function ForeverUpgrade_OnCompartmentClick()
    if ns.ToggleOptions then
        ns.ToggleOptions()
    end
end

local function SlashHelp()
    ns.Print("Hover gear for an upgrade line. Hold Shift for the stat breakdown.")
    ns.Print("/fu  opens weights.  /fu spec fury  or  /fu auto")
    ns.Print("/fu weight hit 16   /fu import str=1,hit=16   /fu export")
    ns.Print("/fu reset   /fu margin 0.5   /fu on   /fu off   /fu list   /fu debug")
end

function ns.Slash(msg)
    if not ns.ready then
        ns.Print("Still loading. Enter the world, then try again.")
        return
    end
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "" or cmd == "show" or cmd == "options" or cmd == "config" then
        if ns.ToggleOptions then
            ns.ToggleOptions()
        end
        return
    end
    if cmd == "help" then
        SlashHelp()
        return
    end
    if cmd == "on" then
        ns.char.enabled = true
        ns.Changed()
        ns.Print("Upgrade lines are on.")
        return
    end
    if cmd == "off" then
        ns.char.enabled = false
        ns.Changed()
        ns.Print("Upgrade lines are off.")
        return
    end
    if cmd == "auto" then
        ns.SetManualSpec(nil)
        local info = ns.GetSpecInfo()
        ns.Print(info.summary or "Spec set to automatic.")
        return
    end
    if cmd == "spec" then
        local name = rest:lower()
        if name == "" or name == "auto" then
            ns.SetManualSpec(nil)
        else
            local spec = ns.MatchSpecName(ns.ClassFile(), name) or ns.SPEC_ALIAS[name]
            if not spec or not ns.SpecAllowed(ns.ClassFile(), spec) then
                ns.Print("Unknown spec for this class. Try /fu spec arms, or /fu auto.")
                return
            end
            ns.SetManualSpec(spec)
        end
        local info = ns.GetSpecInfo()
        ns.Print(info.summary or "Spec updated.")
        return
    end
    if cmd == "margin" then
        local n = tonumber((rest:gsub(",", ".")))
        if not n or n < 0 then
            ns.Print("Usage: /fu margin 0.5")
            return
        end
        ns.char.margin = n
        ns.Changed()
        ns.Print("Scores within " .. ns.FormatNum(n) .. " points count as similar.")
        return
    end
    if cmd == "reset" then
        if ns.ResetCustom then
            ns.ResetCustom()
            ns.Print("Custom weights cleared for this spec. Built-in weights are active.")
        end
        return
    end
    if cmd == "list" then
        local info = ns.GetSpecInfo()
        local weights = ns.MergedWeights()
        ns.Print((info.summary or "Weights") .. (info.custom and " Custom weights:" or " Built-in weights:"))
        local bits = {}
        for i = 1, #ns.STAT_GROUPS do
            local group = ns.STAT_GROUPS[i]
            for r = 1, #group.stats do
                local stat = group.stats[r]
                local value = weights[stat.key]
                if type(value) == "number" and value ~= 0 then
                    bits[#bits + 1] = stat.key .. "=" .. ns.FormatNum(value)
                end
            end
        end
        if #bits == 0 then
            ns.Print("No non-zero weights.")
        else
            ns.Print(table.concat(bits, ", "))
        end
        return
    end
    if cmd == "export" then
        if ns.ExportWeights then
            ns.Print(ns.ExportWeights())
        end
        return
    end
    if cmd == "import" then
        if ns.ImportWeights then
            local count, skipped = ns.ImportWeights(rest)            ns.Print("Imported " .. tostring(count) .. " weights." .. (skipped > 0 and (" Skipped " .. skipped .. ".") or ""))
        end
        return
    end
    if cmd == "weight" or cmd == "w" then
        local statName, numberText = rest:match("^(%S+)%s+([%+%-]?%d+[%d%.,]*)$")
        if not statName then
            ns.Print("Usage: /fu weight hit 16")
            return
        end
        local key = ns.CanonStat(statName)
        local number = tonumber((numberText:gsub(",", ".")))
        if not key or not number then
            ns.Print("Unknown stat. Example keys: str, agi, hit, crit, sp, heal, dps2h, dpsMH, speedOH.")
            return
        end
        ns.SetWeight(key, number)
        ns.Print(key .. " set to " .. ns.FormatNum(number) .. " for this spec.")
        return
    end
    if cmd == "debug" then
        if ns.DebugTooltip then
            ns.DebugTooltip()
        end
        return
    end
    SlashHelp()
end

SLASH_FOREVERUPGRADE1 = "/fu"
SLASH_FOREVERUPGRADE2 = "/foreverupgrade"
SlashCmdList.FOREVERUPGRADE = function(msg)
    ns.Slash(msg)
end

ns.On("ADDON_LOADED", function(loaded)
    if loaded ~= addonName then
        return
    end
    ns.InitDB()
    ns.events:UnregisterEvent("ADDON_LOADED")
end)
