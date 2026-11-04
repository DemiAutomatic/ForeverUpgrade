local _, ns = ...

local announced = false
local announcedSpec = nil

function ns.SpecAllowed(class, spec)
    if not class or not spec then
        return false
    end
    if class == "DRUID" and spec == "feraltank" then
        return true
    end
    local order = ns.TREE_ORDER[class]
    if not order then
        return false
    end
    for i = 1, #order do
        if order[i] == spec then
            return true
        end
    end
    return false
end

function ns.SpecsForClass(class)
    local list = {}
    local order = class and ns.TREE_ORDER[class]
    if order then
        for i = 1, #order do
            list[#list + 1] = order[i]
        end
    end
    if class == "DRUID" then
        list[#list + 1] = "feraltank"
    end
    return list
end

function ns.MatchSpecName(class, name)
    if type(name) ~= "string" or ns.Secret(name) then
        return nil
    end
    local lower = name:lower()
    local spec = ns.SPEC_ALIAS[lower]
    if spec and class and ns.SpecAllowed(class, spec) then
        return spec
    end
    if spec and not class then
        return spec
    end
    local word = lower:match("^([%a]+)")
    if word then
        spec = ns.SPEC_ALIAS[word]
        if spec and class and ns.SpecAllowed(class, spec) then
            return spec
        end
    end
    local collapsed = lower:gsub("%s+", "")
    spec = ns.SPEC_ALIAS[collapsed]
    if spec and class and ns.SpecAllowed(class, spec) then
        return spec
    end
    return nil
end

function ns.InvalidateSpec()
    ns.specCache = nil
end

local function Detail(class, points)
    local order = ns.TREE_ORDER[class] or {}
    local bits = {}
    for i = 1, #order do
        local spec = order[i]
        bits[#bits + 1] = (ns.SPEC_LABEL[spec] or spec) .. " " .. tostring(points[spec] or 0)
    end
    return table.concat(bits, " / ")
end

local function PickLeading(class, points)
    local bestSpec = nil
    local best = -1
    local second = -1
    local total = 0
    local order = ns.TREE_ORDER[class] or {}
    for i = 1, #order do
        local spec = order[i]
        local pts = points[spec] or 0
        total = total + pts
        if pts > best then
            second = best
            best = pts
            bestSpec = spec
        elseif pts > second then
            second = pts
        end
    end
    local detail = Detail(class, points)
    if total <= 0 or not bestSpec then
        return nil, detail, false
    end
    local confident = best >= 10 and (best - math.max(second, 0)) >= 5
    return bestSpec, detail, confident
end

local function FromOldAPI(class)
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentTabInfo) ~= "function" then
        return nil
    end
    local count = GetNumTalentTabs()
    if type(count) ~= "number" or ns.Secret(count) or count <= 0 then
        return nil
    end
    local points = {}
    local order = ns.TREE_ORDER[class] or {}
    for i = 1, count do
        local name, _, spent = GetTalentTabInfo(i)
        if ns.Secret(spent) then
            spent = 0
        end
        spent = tonumber(spent) or 0
        local spec = ns.MatchSpecName(class, name) or order[i]
        if spec == "feraltank" then
            spec = "feral"
        end
        if spec then
            points[spec] = (points[spec] or 0) + spent
        end
    end
    return PickLeading(class, points)
end

local function SubTreeName(configID, subTreeID)
    if type(C_Traits) ~= "table" or type(C_Traits.GetSubTreeInfo) ~= "function" then
        return nil
    end
    local info = C_Traits.GetSubTreeInfo(configID, subTreeID)
    if type(info) ~= "table" then
        info = C_Traits.GetSubTreeInfo(subTreeID)
    end
    if type(info) == "table" and type(info.name) == "string" and not ns.Secret(info.name) then
        return info.name
    end
    return nil
end

local function FromTraits(class)
    if type(C_ClassTalents) ~= "table" or type(C_ClassTalents.GetActiveConfigID) ~= "function" then
        return nil, "Talent config is not available on this build.", false
    end
    if type(C_Traits) ~= "table" or type(C_Traits.GetConfigInfo) ~= "function" or type(C_Traits.GetTreeNodes) ~= "function" then
        return nil, "Trait data is not available on this build.", false
    end
    local configID = C_ClassTalents.GetActiveConfigID()
    if type(configID) ~= "number" or ns.Secret(configID) then
        return nil, "No active talent config yet.", false
    end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if type(configInfo) ~= "table" or type(configInfo.treeIDs) ~= "table" then
        return nil, "Talent tree is not loaded yet.", false
    end

    local nodes = {}
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    for t = 1, #configInfo.treeIDs do
        local nodeIDs = C_Traits.GetTreeNodes(configInfo.treeIDs[t])
        if type(nodeIDs) == "table" then
            for n = 1, #nodeIDs do
                local info = C_Traits.GetNodeInfo(configID, nodeIDs[n])
                if type(info) == "table" and type(info.ID) == "number" and info.ID ~= 0 then
                    local pts = info.ranksPurchased
                    if type(pts) ~= "number" then
                        pts = info.currentRank
                    end
                    if type(pts) ~= "number" or ns.Secret(pts) then
                        pts = 0
                    end
                    local x = info.posX
                    local y = info.posY
                    if type(x) ~= "number" or ns.Secret(x) then
                        x = 0
                    end
                    local yOk = type(y) == "number" and not ns.Secret(y)
                    if not yOk then
                        y = 0
                    end
                    local sub = info.subTreeID
                    if type(sub) ~= "number" or ns.Secret(sub) or sub < 0 then
                        sub = 0
                    end
                    nodes[#nodes + 1] = { pts = pts, x = x, y = y, sub = sub }
                    if not minX or x < minX then minX = x end
                    if not maxX or x > maxX then maxX = x end
                    if not minY or y < minY then minY = y end
                    if not maxY or y > maxY then maxY = y end
                end
            end
        end
    end

    if #nodes == 0 then
        return nil, "No talent nodes were returned.", false
    end

    local groupMap = {}
    local groupList = {}
    local function group(key, pts, pos, name)
        local row = groupMap[key]
        if not row then
            row = { points = 0, posSum = 0, count = 0, name = name }
            groupMap[key] = row
            groupList[#groupList + 1] = row
        end
        row.points = row.points + pts
        row.posSum = row.posSum + pos
        row.count = row.count + 1
        if name and not row.name then
            row.name = name
        end
    end

    local hasSub = false
    for i = 1, #nodes do
        if nodes[i].sub > 0 then
            hasSub = true
            break
        end
    end

    if hasSub then
        for i = 1, #nodes do
            local node = nodes[i]
            local key = node.sub > 0 and node.sub or -1
            local name = node.sub > 0 and SubTreeName(configID, node.sub) or nil
            group(key, node.pts, node.x, name)
        end
    else
        local xRange = (maxX or 0) - (minX or 0)
        local yRange = (maxY or 0) - (minY or 0)
        if xRange < 10 and yRange < 10 then
            return nil, "Talent positions were not available. Pick a spec with /fu spec.", false
        end
        local useY = yRange > xRange * 1.2
        local minV = useY and minY or minX
        local maxV = useY and maxY or maxX
        local span = maxV - minV
        for i = 1, #nodes do
            local node = nodes[i]
            local value = useY and node.y or node.x
            local band = 1
            if span > 0 then
                band = math.floor(((value - minV) / span) * 3) + 1
                if band > 3 then
                    band = 3
                end
                if band < 1 then
                    band = 1
                end
            end
            group(band, node.pts, value, nil)
        end
    end

    local list = {}
    for i = 1, #groupList do
        local row = groupList[i]
        list[#list + 1] = {
            points = row.points,
            pos = row.count > 0 and (row.posSum / row.count) or 0,
            name = row.name,
        }
    end
    table.sort(list, function(a, b)
        return a.pos < b.pos
    end)

    local named = 0
    local points = {}
    for i = 1, #list do
        local spec = list[i].name and ns.MatchSpecName(class, list[i].name)
        if spec == "feraltank" then
            spec = "feral"
        end
        if spec then
            named = named + 1
            points[spec] = (points[spec] or 0) + list[i].points
        end
    end
    if named == 0 or named ~= #list then
        points = {}
        local order = ns.TREE_ORDER[class] or {}
        for i = 1, #list do
            local spec = order[i]
            if spec then
                points[spec] = (points[spec] or 0) + list[i].points
            end
        end
    end
    return PickLeading(class, points)
end

function ns.DetectSpec(class)
    local ok, spec, detail, confident = pcall(function()
        local oldSpec, oldDetail, oldConfident = FromOldAPI(class)
        if oldSpec or oldDetail then
            return oldSpec, oldDetail, oldConfident
        end
        return FromTraits(class)
    end)
    if not ok then
        local err = tostring(spec)
        if #err > 180 then
            err = err:sub(1, 180)
        end
        return nil, "Could not read talents (" .. err .. "). Pick a spec with /fu spec.", false
    end
    return spec, detail, confident
end

local function Summary(info)
    local label = info.label or "this spec"
    if info.mode == "manual" then
        return "Using " .. label .. " (chosen by you)."
    end
    if info.mode == "leveling" then
        local detail = info.detail and info.detail ~= "" and (" " .. info.detail .. ".") or ""
        return "No clear spec yet. Using " .. label .. " leveling weights." .. detail
    end
    local tail = info.detail and info.detail ~= "" and (" (" .. info.detail .. ")") or ""
    if info.lowConfidence then
        return "Using " .. label .. " from talents, low confidence" .. tail .. ". Set it with /fu spec if this is wrong."
    end
    return "Using " .. label .. " from talents" .. tail .. "."
end

function ns.GetSpecInfo()
    if ns.specCache then
        return ns.specCache
    end
    local class = ns.ClassFile()
    local info = {
        class = class,
        spec = nil,
        label = "Unknown",
        mode = "leveling",
        summary = "Class is not available yet.",
        custom = false,
        lowConfidence = false,
        detail = nil,
    }
    if not class then
        return info
    end
    local manual = ns.char and ns.char.manualSpec
    if type(manual) == "string" and ns.SpecAllowed(class, manual) then
        info.spec = manual
        info.mode = "manual"
    else
        local spec, detail, confident = ns.DetectSpec(class)
        info.detail = detail
        if spec and ns.SpecAllowed(class, spec) then
            info.spec = spec
            info.mode = "talents"
            info.lowConfidence = not confident
        else
            info.spec = ns.LEVELING[class]
            info.mode = "leveling"
        end
    end
    info.label = ns.SPEC_LABEL[info.spec] or info.spec or "Unknown"
    info.custom = ns.UsingCustom(class, info.spec)
    info.summary = Summary(info)
    ns.specCache = info
    return info
end

function ns.GetSpec()
    return ns.GetSpecInfo().spec
end

function ns.SetManualSpec(spec)
    if not ns.char then
        return
    end
    if spec == nil then
        ns.char.manualSpec = nil
    else
        ns.char.manualSpec = spec
    end
    ns.InvalidateSpec()
    ns.Changed()
end

local function Announce()
    local info = ns.GetSpecInfo()
    if announced and announcedSpec == info.spec then
        return
    end
    local changed = announced and announcedSpec ~= info.spec and not (ns.char and ns.char.manualSpec)
    announced = true
    announcedSpec = info.spec
    if not ns.tooltipOK then
        ns.Print("This client has no tooltip data API, so upgrade lines cannot be added.")
    end
    if changed then
        ns.Print("Spec updated. " .. (info.summary or ""))
    else
        ns.Print("Hover gear to see if it is an upgrade. /fu opens weights. " .. (info.summary or ""))
    end
end

ns.On("PLAYER_LOGIN", function()
    ns.InvalidateSpec()
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            ns.InvalidateSpec()
            Announce()
        end)
    else
        Announce()
    end
end)

local function TalentsChanged()
    local before = ns.specCache and ns.specCache.spec
    ns.InvalidateSpec()
    local info = ns.GetSpecInfo()
    if announced and before and info.spec ~= before and not (ns.char and ns.char.manualSpec) then
        Announce()
    end
    ns.Changed()
end

ns.On("TRAIT_CONFIG_UPDATED", TalentsChanged)
ns.On("PLAYER_TALENT_UPDATE", TalentsChanged)
ns.On("CHARACTER_POINTS_CHANGED", TalentsChanged)
ns.On("PLAYER_LEVEL_UP", function()
    ns.InvalidateSpec()
    ns.Changed()
end)
