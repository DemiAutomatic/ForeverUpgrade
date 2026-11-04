local _, ns = ...

local boxes = {}

local function SelectedSpec()
    local info = ns.GetSpecInfo()
    return info.spec
end

local function SavePosition(frame)
    if not ns.char then
        return
    end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point and x and y then
        ns.char.window = { point = point, relPoint = relPoint, x = x, y = y }
    end
end

local function RestorePosition(frame)
    local window = ns.char and ns.char.window
    frame:ClearAllPoints()
    if window and window.point and window.x and window.y then
        frame:SetPoint(window.point, UIParent, window.relPoint or window.point, window.x, window.y)
    else
        frame:SetPoint("CENTER")
    end
end

function ns.RefreshOptions()
    local frame = ns.frame
    if not frame or not frame:IsShown() then
        return
    end
    local info = ns.GetSpecInfo()
    local class = ns.ClassFile()
    local weights = ns.MergedWeights(class, info.spec)
    frame.status:SetText(info.summary or "")
    frame.custom:SetChecked(info.custom and true or false)
    if frame.toggles then
        for i = 1, #frame.toggles do
            local check = frame.toggles[i]
            check:SetChecked(ns.char and ns.char[check.key] ~= false)
        end
    end

    if frame.specButtons then
        for i = 1, #frame.specButtons do
            local button = frame.specButtons[i]
            local spec = button.spec
            local label = spec and (ns.SPEC_LABEL[spec] or spec) or "Auto"
            local selected = false
            if not spec and info.mode ~= "manual" then
                selected = true
            elseif spec and info.mode == "manual" and spec == info.spec then
                selected = true
            end
            if selected then
                button:LockHighlight()
            else
                button:UnlockHighlight()
            end
            button:SetText(label)
        end
    end

    for i = 1, #boxes do
        local box = boxes[i]
        if not box:HasFocus() then
            local value = weights[box.statKey]
            if value == nil then
                value = ns.ResolveWeight(weights, box.statKey) or 0
            end
            box.value = value
            box:SetText(ns.FormatNum(value))
        end
    end
end

local function CommitBox(box)
    local text = (box:GetText() or ""):gsub(",", ".")
    if text == "" then
        text = "0"
    end
    local number = tonumber(text)
    if not number then
        box:SetText(ns.FormatNum(box.value or 0))
        return
    end
    box.value = number
    ns.SetWeight(box.statKey, number)
end

function ns.BuildOptions()
    if ns.frame then
        return
    end
    local frame = CreateFrame("Frame", "ForeverUpgradeFrame", UIParent, "BackdropTemplate")
    ns.frame = frame
    frame:SetSize(540, 640)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:Hide()
    tinsert(UISpecialFrames, "ForeverUpgradeFrame")
    RestorePosition(frame)

    local titleDrag = CreateFrame("Frame", nil, frame)
    titleDrag:SetPoint("TOPLEFT", 12, -10)
    titleDrag:SetPoint("TOPRIGHT", -12, -10)
    titleDrag:SetHeight(24)
    titleDrag:EnableMouse(true)
    titleDrag:RegisterForDrag("LeftButton")
    titleDrag:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleDrag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame)
    end)

    local title = titleDrag:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("Forever Upgrade")

    local status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 24, -40)
    status:SetPoint("TOPRIGHT", -24, -40)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")
    status:SetWordWrap(true)
    status:SetHeight(36)
    frame.status = status

    local classLine = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    classLine:SetPoint("TOPLEFT", 24, -76)
    classLine:SetText("Saved on this character.")
    frame.classLine = classLine

    local class = ns.ClassFile()
    local specs = ns.SpecsForClass(class)
    local buttons = {}
    local labels = { { spec = nil, label = "Auto" } }
    for i = 1, #specs do
        labels[#labels + 1] = { spec = specs[i], label = ns.SPEC_LABEL[specs[i]] or specs[i] }
    end
    local gap = 6
    local width = (492 - gap * (#labels - 1)) / #labels
    if width > 110 then
        width = 110
    end
    for i = 1, #labels do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetPoint("TOPLEFT", 24 + (i - 1) * (width + gap), -96)
        button.spec = labels[i].spec
        local font = button:GetFontString()
        if font then
            font:SetFontObject(GameFontNormalSmall)
        end
        button:SetScript("OnClick", function(self)
            ns.SetManualSpec(self.spec)
            local info = ns.GetSpecInfo()
            ns.Print(info.summary or "Spec updated.")
        end)
        buttons[#buttons + 1] = button
    end
    frame.specButtons = buttons

    local custom = CreateFrame("CheckButton", "ForeverUpgradeCustomCheck", frame, "UICheckButtonTemplate")
    custom:SetPoint("TOPLEFT", 20, -126)
    custom:SetScript("OnClick", function(self)
        ns.SetCustomEnabled(self:GetChecked() and true or false)
    end)
    local customLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    customLabel:SetPoint("LEFT", custom, "RIGHT", 2, 0)
    customLabel:SetText("Use my weights for this spec")
    frame.custom = custom

    local scroll = CreateFrame("ScrollFrame", "ForeverUpgradeScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -158)
    scroll:SetPoint("BOTTOMRIGHT", -36, 126)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        if ns.Secret(delta) or type(delta) ~= "number" then
            return
        end
        local bar = self.ScrollBar or _G[self:GetName() .. "ScrollBar"]
        if not bar then
            return
        end
        pcall(function()
            bar:SetValue(bar:GetValue() - delta * 36)
        end)
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(450)
    scroll:SetScrollChild(content)

    local y = -4
    for g = 1, #ns.STAT_GROUPS do
        local group = ns.STAT_GROUPS[g]
        local header = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", 8, y)
        header:SetText(group.title)
        y = y - 22
        for r = 1, #group.stats do
            local stat = group.stats[r]
            local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("TOPLEFT", 8, y - 2)
            label:SetText(stat.label)
            local box = CreateFrame("EditBox", nil, content, "BackdropTemplate")
            box:SetSize(78, 20)
            box:SetPoint("TOPRIGHT", -8, y)
            box:SetAutoFocus(false)
            box:SetFontObject(GameFontHighlightSmall)
            box:SetJustifyH("RIGHT")
            box:SetTextInsets(4, 6, 0, 0)
            box:SetMaxLetters(10)
            box:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            box:SetBackdropColor(0, 0, 0, 0.45)
            box:SetBackdropBorderColor(0.55, 0.45, 0.22, 0.9)
            box.statKey = stat.key
            box:SetScript("OnEnterPressed", function(self)
                CommitBox(self)
                self:ClearFocus()
            end)
            box:SetScript("OnEditFocusLost", function(self)
                CommitBox(self)
            end)
            box:SetScript("OnEscapePressed", function(self)
                self:SetText(ns.FormatNum(self.value or 0))
                self:ClearFocus()
            end)
            boxes[#boxes + 1] = box
            y = y - 24
        end
        y = y - 8
    end
    content:SetHeight(math.abs(y) + 8)

    local toggleInfo = {
        { key = "bagAdvisor", label = "Bags", name = "ForeverUpgradeBagCheck", x = 12 },
        { key = "lootAdvisor", label = "Loot", name = "ForeverUpgradeLootCheck", x = 118 },
        { key = "questAdvisor", label = "Quests", name = "ForeverUpgradeQuestCheck", x = 214 },
        { key = "otherSpecs", label = "Other specs", name = "ForeverUpgradeSpecsCheck", x = 330 },
    }
    frame.toggles = {}
    for i = 1, #toggleInfo do
        local info = toggleInfo[i]
        local check = CreateFrame("CheckButton", info.name, frame, "UICheckButtonTemplate")
        check:SetPoint("BOTTOMLEFT", info.x, 84)
        check.key = info.key
        local text = check.Text or _G[info.name .. "Text"]
        if text then
            text:SetFontObject(GameFontHighlightSmall)
            text:SetText(info.label)
        end
        check:SetScript("OnClick", function(self)
            if not ns.char then
                return
            end
            ns.char[self.key] = self:GetChecked() and true or false
            ns.Changed()
        end)
        frame.toggles[#frame.toggles + 1] = check
    end

    local help = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    help:SetPoint("BOTTOMLEFT", 20, 48)
    help:SetPoint("BOTTOMRIGHT", -20, 48)
    help:SetJustifyH("LEFT")
    help:SetJustifyV("TOP")
    help:SetWordWrap(true)
    help:SetHeight(32)
    help:SetText("Starter weights for Classic Era and Forever. Forever counts 10 hit, 14 crit, 12 dodge, or 15 parry as 1%. Era gear is already in percent. Hold Shift for the breakdown.")

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(140, 22)
    reset:SetPoint("BOTTOMLEFT", 20, 16)
    reset:SetText("Reset this spec")
    reset:SetScript("OnClick", function()
        ns.ResetCustom()
        ns.Print("Custom weights cleared for this spec.")
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(90, 22)
    close:SetPoint("BOTTOMRIGHT", -20, 16)
    close:SetText("Close")
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:SetScript("OnShow", function()
        ns.RefreshOptions()
    end)
end

function ns.ToggleOptions()
    if not ns.ready then
        ns.Print("Enter the world first.")
        return
    end
    if not ns.ClassFile() then
        ns.Print("Enter the world first.")
        return
    end
    ns.BuildOptions()
    if ns.frame:IsShown() then
        ns.frame:Hide()
    else
        RestorePosition(ns.frame)
        ns.frame:Show()
    end
end
