local _, ns = ...

ns.parseCache = {}

local API_STAT = {
    ITEM_MOD_STRENGTH_SHORT = "str",
    ITEM_MOD_AGILITY_SHORT = "agi",
    ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int",
    ITEM_MOD_SPIRIT_SHORT = "spi",
    ITEM_MOD_HEALTH_SHORT = "health",
    ITEM_MOD_MANA_SHORT = "mana",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "fap",
    ITEM_MOD_SPELL_POWER_SHORT = "sp",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5",
    ITEM_MOD_HIT_RATING_SHORT = "hit",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
    ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit",
    ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellHit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellCrit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "def",
    ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry",
    ITEM_MOD_BLOCK_RATING_SHORT = "block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
    ITEM_MOD_EXTRA_ARMOR_SHORT = "armor",
    RESISTANCE0_NAME = "armor",
    ITEM_MOD_FIRE_RESISTANCE_SHORT = "resFire",
    ITEM_MOD_FROST_RESISTANCE_SHORT = "resFrost",
    ITEM_MOD_NATURE_RESISTANCE_SHORT = "resNature",
    ITEM_MOD_SHADOW_RESISTANCE_SHORT = "resShadow",
    ITEM_MOD_ARCANE_RESISTANCE_SHORT = "resArcane",
    ITEM_MOD_FIRE_SPELL_POWER_SHORT = "fire",
    ITEM_MOD_FROST_SPELL_POWER_SHORT = "frost",
    ITEM_MOD_ARCANE_SPELL_POWER_SHORT = "arcane",
    ITEM_MOD_NATURE_SPELL_POWER_SHORT = "nature",
    ITEM_MOD_SHADOW_SPELL_POWER_SHORT = "shadow",
    ITEM_MOD_HOLY_SPELL_POWER_SHORT = "holyDmg",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}

local IGNORE_LOC = {
    INVTYPE_NON_EQUIP = true,
    INVTYPE_BAG = true,
    INVTYPE_AMMO = true,
    INVTYPE_QUIVER = true,
    INVTYPE_BODY = true,
    INVTYPE_TABARD = true,
    INVTYPE_PROFESSION_TOOL = true,
    INVTYPE_PROFESSION_GEAR = true,
    INVTYPE_EQUIPABLESPELL_OFFENSIVE = true,
    INVTYPE_EQUIPABLESPELL_UTILITY = true,
    INVTYPE_EQUIPABLESPELL_DEFENSIVE = true,
    INVTYPE_EQUIPABLESPELL_WEAPON = true,
}

local WEAPON_OK = {
    WARRIOR = { axe1h = true, axe2h = true, bow = true, gun = true, mace1h = true, mace2h = true, polearm = true, sword1h = true, sword2h = true, staff = true, fist = true, dagger = true, thrown = true, crossbow = true },
    PALADIN = { mace1h = true, mace2h = true, sword1h = true, sword2h = true, polearm = true },
    HUNTER = { axe1h = true, axe2h = true, bow = true, gun = true, polearm = true, sword1h = true, sword2h = true, staff = true, fist = true, dagger = true, thrown = true, crossbow = true },
    ROGUE = { bow = true, gun = true, mace1h = true, sword1h = true, fist = true, dagger = true, thrown = true, crossbow = true },
    PRIEST = { mace1h = true, staff = true, dagger = true, wand = true },
    SHAMAN = { axe1h = true, axe2h = true, mace1h = true, mace2h = true, staff = true, fist = true, dagger = true },
    MAGE = { sword1h = true, staff = true, dagger = true, wand = true },
    WARLOCK = { sword1h = true, staff = true, dagger = true, wand = true },
    DRUID = { mace1h = true, mace2h = true, polearm = true, staff = true, fist = true, dagger = true },
}

local SHIELD_OK = { WARRIOR = true, PALADIN = true, SHAMAN = true }

local function CanDualWield(class)
    if class == "WARRIOR" or class == "ROGUE" then
        return true
    end
    -- Forever teaches Dual Wield to hunters. Classic Era hunters do not have it
    -- unless a later spell grant says so.
    if class == "HUNTER" and ns.ClientKind and ns.ClientKind() == "forever" then
        return true
    end
    -- Spell 674 is Dual Wield. Covers a class that learns it later, such as shaman.
    if type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, 674)
        if ok and known ~= nil and not ns.Secret(known) then
            return known and true or false
        end
    end
    return false
end

local function AsNumber(value)
    if value == nil or ns.Secret(value) then
        return nil
    end
    if type(value) == "number" then
        return value
    end
    return tonumber(value)
end

local function EnumID(enumTable, name, fallback)
    local value = enumTable and enumTable[name]
    if type(value) == "number" then
        return value
    end
    return fallback
end

local function WeaponKey(subclassID)
    subclassID = AsNumber(subclassID)
    if not subclassID then
        return nil
    end
    local e = Enum and Enum.ItemWeaponSubclass
    local map = {
        [EnumID(e, "Axe1H", 0)] = "axe1h",
        [EnumID(e, "Axes1H", 0)] = "axe1h",
        [EnumID(e, "Axe2H", 1)] = "axe2h",
        [EnumID(e, "Axes2H", 1)] = "axe2h",
        [EnumID(e, "Bows", 2)] = "bow",
        [EnumID(e, "Guns", 3)] = "gun",
        [EnumID(e, "Mace1H", 4)] = "mace1h",
        [EnumID(e, "Maces1H", 4)] = "mace1h",
        [EnumID(e, "Mace2H", 5)] = "mace2h",
        [EnumID(e, "Maces2H", 5)] = "mace2h",
        [EnumID(e, "Polearm", 6)] = "polearm",
        [EnumID(e, "Polearms", 6)] = "polearm",
        [EnumID(e, "Sword1H", 7)] = "sword1h",
        [EnumID(e, "Swords1H", 7)] = "sword1h",
        [EnumID(e, "Sword2H", 8)] = "sword2h",
        [EnumID(e, "Swords2H", 8)] = "sword2h",
        [EnumID(e, "Staff", 10)] = "staff",
        [EnumID(e, "Staves", 10)] = "staff",
        [EnumID(e, "Fist", 13)] = "fist",
        [EnumID(e, "FistWeapons", 13)] = "fist",
        [EnumID(e, "Dagger", 15)] = "dagger",
        [EnumID(e, "Daggers", 15)] = "dagger",
        [EnumID(e, "Thrown", 16)] = "thrown",
        [EnumID(e, "Spear", 17)] = "polearm",
        [EnumID(e, "Spears", 17)] = "polearm",
        [EnumID(e, "Crossbow", 18)] = "crossbow",
        [EnumID(e, "Crossbows", 18)] = "crossbow",
        [EnumID(e, "Wand", 19)] = "wand",
        [EnumID(e, "Wands", 19)] = "wand",
        [EnumID(e, "FishingPole", 20)] = "fishing",
        [EnumID(e, "FishingPoles", 20)] = "fishing",
    }
    return map[subclassID]
end

local function ArmorKind(subclassID)
    subclassID = AsNumber(subclassID)
    if not subclassID then
        return "other"
    end
    local e = Enum and Enum.ItemArmorSubclass
    if subclassID == EnumID(e, "Cloth", 1) then return "cloth" end
    if subclassID == EnumID(e, "Leather", 2) then return "leather" end
    if subclassID == EnumID(e, "Mail", 3) then return "mail" end
    if subclassID == EnumID(e, "Plate", 4) then return "plate" end
    if subclassID == EnumID(e, "Shield", 6) then return "shield" end
    return "other"
end

local function IsWeaponClass(classID)
    classID = AsNumber(classID)
    if not classID then
        return false
    end
    local e = Enum and Enum.ItemClass
    if e and type(e.Weapon) == "number" then
        return classID == e.Weapon
    end
    return classID == 2
end

function ns.WeaponType(meta)
    if not meta or not IsWeaponClass(meta.classID) then
        return nil
    end
    return WeaponKey(meta.subclassID)
end

local function IsArmorClass(classID)
    classID = AsNumber(classID)
    if not classID then
        return false
    end
    local e = Enum and Enum.ItemClass
    if e and type(e.Armor) == "number" then
        return classID == e.Armor
    end
    return classID == 4
end

function ns.LinkID(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local pendingIDs = {}
local failedLoads = {}

function ns.RequestItem(itemID)
    if not itemID then
        return
    end
    pendingIDs[itemID] = true
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
        return
    end
    if GetItemInfo then
        pcall(GetItemInfo, itemID)
    end
end

local function SlotConst(globalName, fallback)
    local value = _G[globalName]
    if type(value) == "number" then
        return value
    end
    return fallback
end

function ns.Slots()
    if ns.slot then
        return ns.slot
    end
    ns.slot = {
        HEAD = SlotConst("INVSLOT_HEAD", 1),
        NECK = SlotConst("INVSLOT_NECK", 2),
        SHOULDER = SlotConst("INVSLOT_SHOULDER", 3),
        CHEST = SlotConst("INVSLOT_CHEST", 5),
        WAIST = SlotConst("INVSLOT_WAIST", 6),
        LEGS = SlotConst("INVSLOT_LEGS", 7),
        FEET = SlotConst("INVSLOT_FEET", 8),
        WRIST = SlotConst("INVSLOT_WRIST", 9),
        HAND = SlotConst("INVSLOT_HAND", 10),
        FINGER1 = SlotConst("INVSLOT_FINGER1", 11),
        FINGER2 = SlotConst("INVSLOT_FINGER2", 12),
        TRINKET1 = SlotConst("INVSLOT_TRINKET1", 13),
        TRINKET2 = SlotConst("INVSLOT_TRINKET2", 14),
        BACK = SlotConst("INVSLOT_BACK", 15),
        MAINHAND = SlotConst("INVSLOT_MAINHAND", 16),
        OFFHAND = SlotConst("INVSLOT_OFFHAND", 17),
        RANGED = SlotConst("INVSLOT_RANGED", 18),
    }
    return ns.slot
end

function ns.EquippedLink(slot)
    if type(GetInventoryItemLink) == "function" then
        local link = GetInventoryItemLink("player", slot)
        if type(link) == "string" then
            return link
        end
    end
    if ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item and C_Item.GetItemLink then
        local loc = ItemLocation:CreateFromEquipmentSlot(slot)
        if loc and loc.IsValid and loc:IsValid() then
            local link = C_Item.GetItemLink(loc)
            if type(link) == "string" and not ns.Secret(link) then
                return link
            end
        end
    end
    return nil
end

function ns.EquippedGUID(slot)
    if not ItemLocation or not ItemLocation.CreateFromEquipmentSlot or not C_Item or not C_Item.GetItemGUID then
        return nil
    end
    local loc = ItemLocation:CreateFromEquipmentSlot(slot)
    if not loc or not loc.IsValid or not loc:IsValid() then
        return nil
    end
    local guid = C_Item.GetItemGUID(loc)
    if ns.Secret(guid) or type(guid) ~= "string" then
        return nil
    end
    return guid
end

local function ItemInfoInstant(link)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(link)
    end
    if GetItemInfoInstant then
        return GetItemInfoInstant(link)
    end
end

local function ItemInfo(link)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(link)
    end
    if GetItemInfo then
        return GetItemInfo(link)
    end
end

function ns.ItemMeta(link)
    local meta = { link = link, id = ns.LinkID(link) }
    if ItemInfoInstant then
        local _, _, _, equipLoc, _, classID, subclassID = ItemInfoInstant(link)
        meta.equipLoc = equipLoc
        meta.classID = classID
        meta.subclassID = subclassID
        if equipLoc or classID then
            meta.instant = true
        end
    end
    if ItemInfo then
        local name, _, _, _, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = ItemInfo(link)
        if type(name) == "string" and not ns.Secret(name) then
            meta.name = name
            if type(reqLevel) == "number" and not ns.Secret(reqLevel) then
                meta.reqLevel = reqLevel
            end
            meta.equipLoc = equipLoc or meta.equipLoc
            meta.classID = classID or meta.classID
            meta.subclassID = subclassID or meta.subclassID
            meta.loaded = true
        end
    end
    meta.name = (type(meta.name) == "string" and not ns.Secret(meta.name)) and meta.name or nil
    meta.equipLoc = (type(meta.equipLoc) == "string" and not ns.Secret(meta.equipLoc)) and meta.equipLoc or nil
    meta.classID = AsNumber(meta.classID)
    meta.subclassID = AsNumber(meta.subclassID)
    meta.reqLevel = AsNumber(meta.reqLevel)
    return meta
end

local statNames
local armorWord

local function AddName(stat, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if type(name) == "string" and name ~= "" then
            statNames[name:lower()] = stat
        end
    end
end

local function BuildNames()
    if statNames then
        return
    end
    statNames = {}
    AddName("str", _G.ITEM_MOD_STRENGTH_SHORT, _G.SPELL_STAT1_NAME, "Strength")
    AddName("agi", _G.ITEM_MOD_AGILITY_SHORT, _G.SPELL_STAT2_NAME, "Agility")
    AddName("sta", _G.ITEM_MOD_STAMINA_SHORT, _G.SPELL_STAT3_NAME, "Stamina")
    AddName("int", _G.ITEM_MOD_INTELLECT_SHORT, _G.SPELL_STAT4_NAME, "Intellect")
    AddName("spi", _G.ITEM_MOD_SPIRIT_SHORT, _G.SPELL_STAT5_NAME, "Spirit")
    AddName("health", _G.ITEM_MOD_HEALTH_SHORT, "Health")
    AddName("mana", _G.ITEM_MOD_MANA_SHORT, "Mana")
    AddName("ap", _G.ITEM_MOD_ATTACK_POWER_SHORT, "Attack Power")
    AddName("rap", _G.ITEM_MOD_RANGED_ATTACK_POWER_SHORT, "Ranged Attack Power")
    AddName("sp", _G.ITEM_MOD_SPELL_POWER_SHORT, "Spell Power", "Spell Damage")
    AddName("heal", _G.ITEM_MOD_SPELL_HEALING_DONE_SHORT, "Healing", "Healing Spells")
    AddName("mp5", _G.ITEM_MOD_MANA_REGENERATION_SHORT, "Mana per 5 sec.", "Mana Per 5 Sec.")
    AddName("hp5", _G.ITEM_MOD_HEALTH_REGENERATION_SHORT, "Health per 5 sec.")
    AddName("hit", _G.ITEM_MOD_HIT_RATING_SHORT, "Hit", "Hit Rating")
    AddName("crit", _G.ITEM_MOD_CRIT_RATING_SHORT, "Critical Strike", "Critical Strike Rating", "Crit")
    AddName("def", _G.ITEM_MOD_DEFENSE_SKILL_RATING_SHORT, "Defense", "Defense Rating")
    AddName("dodge", _G.ITEM_MOD_DODGE_RATING_SHORT, "Dodge", "Dodge Rating")
    AddName("parry", _G.ITEM_MOD_PARRY_RATING_SHORT, "Parry", "Parry Rating")
    AddName("fire", "Fire Damage", "Fire Spell Damage")
    AddName("frost", "Frost Damage", "Frost Spell Damage")
    AddName("arcane", "Arcane Damage", "Arcane Spell Damage")
    AddName("nature", "Nature Damage", "Nature Spell Damage")
    AddName("shadow", "Shadow Damage", "Shadow Spell Damage")
    AddName("holyDmg", "Holy Damage", "Holy Spell Damage")
    AddName("resFire", _G.ITEM_MOD_FIRE_RESISTANCE_SHORT, "Fire Resistance")
    AddName("resFrost", _G.ITEM_MOD_FROST_RESISTANCE_SHORT, "Frost Resistance")
    AddName("resNature", _G.ITEM_MOD_NATURE_RESISTANCE_SHORT, "Nature Resistance")
    AddName("resShadow", _G.ITEM_MOD_SHADOW_RESISTANCE_SHORT, "Shadow Resistance")
    AddName("resArcane", _G.ITEM_MOD_ARCANE_RESISTANCE_SHORT, "Arcane Resistance")
    armorWord = (_G.RESISTANCE0_NAME or "Armor"):lower()
end

local function Has(text, needle)
    return text:find(needle, 1, true) ~= nil
end

local function Escape(text)
    return (text:gsub("(%p)", "%%%1"))
end

local function Clean(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h", "")
    text = text:gsub("|h", "")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

local function LineText(line)
    local text = nil
    if type(line.leftText) == "string" and not ns.Secret(line.leftText) then
        text = line.leftText
    elseif type(line.args) == "table" then
        local bits = {}
        for i = 1, #line.args do
            local arg = line.args[i]
            if type(arg) == "table" and type(arg.stringVal) == "string" and not ns.Secret(arg.stringVal) then
                bits[#bits + 1] = arg.stringVal
            end
        end
        if #bits > 0 then
            text = table.concat(bits, " ")
        end
    end
    if type(line.rightText) == "string" and line.rightText ~= "" and not ns.Secret(line.rightText) then
        text = (text or "") .. " " .. line.rightText
    end
    if not text or text == "" then
        return nil
    end
    return Clean(text)
end

local function ColorRed(line)
    local color = line.leftColor
    if not color then
        return false
    end
    local r, g, b
    if color.GetRGB then
        local ok, r2, g2, b2 = pcall(color.GetRGB, color)
        if not ok then
            return false
        end
        r, g, b = r2, g2, b2
    else
        r, g, b = color.r, color.g, color.b
    end
    if ns.Secret(r) or ns.Secret(g) or ns.Secret(b) then
        return false
    end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
        return false
    end
    return r > 0.8 and g < 0.25 and b < 0.25
end

local function AddNumber(dest, key, amount)
    dest[key] = (dest[key] or 0) + amount
end

-- One line can name several weapons. Edgemaster's is axes, swords, and daggers.
-- Two-handed phrases are cleared before the short word, and crossbow before bow,
-- so a two-hand axe is not also counted as a one-hand axe.
local function SkillKinds(line)
    local kinds = {}
    local seen = {}
    local rest = line
    local function take(pattern, key)
        local cleared, n = rest:gsub(pattern, " ")
        if n > 0 and not seen[key] then
            seen[key] = true
            kinds[#kinds + 1] = key
        end
        rest = cleared
    end
    take("two%-handed swords?", "sword2h")
    take("two handed swords?", "sword2h")
    take("two%-handed axes?", "axe2h")
    take("two handed axes?", "axe2h")
    take("two%-handed maces?", "mace2h")
    take("two handed maces?", "mace2h")
    take("crossbows?", "crossbow")
    take("swords?", "sword1h")
    take("axes?", "axe1h")
    take("maces?", "mace1h")
    take("daggers?", "dagger")
    take("fist weapons?", "fist")
    take("fists?", "fist")
    take("polearms?", "polearm")
    take("staves", "staff")
    take("staffs?", "staff")
    take("bows?", "bow")
    take("guns?", "gun")
    take("thrown", "thrown")
    take("wands?", "wand")
    return kinds
end

local function IsSetLine(lower)
    if lower:match("%(%d+/%d+%)") then
        return true
    end
    if lower:match("^set:") or lower:match("^%(%d+%)%s*set:") then
        return true
    end
    return false
end

local function IsProcLine(lower)
    if Has(lower, "chance on") or Has(lower, "when struck") or Has(lower, "chance to proc") then
        return true
    end
    if Has(lower, "a chance to") or Has(lower, "has a chance") then
        return true
    end
    return false
end

local function ParseLine(text, found, weapon, flags)
    local original = text
    local lower = original:lower()

    if flags.skipRest then
        return
    end

    local retrieving = _G.RETRIEVING_ITEM_INFO
    if (type(retrieving) == "string" and original == retrieving) or Has(lower, "retrieving item information") then
        flags.retrieving = true
        return
    end
    if IsSetLine(lower) then
        flags.hasSet = true
        flags.skipRest = true
        return
    end
    if IsProcLine(lower) then
        flags.hasProc = true
        return
    end
    if lower:match("^use:") then
        flags.hasUse = true
        return
    end

    -- Empty sockets and the socket bonus are not normal stat lines.
    -- A filled gem already shows up as its own stat. The bonus counts only
    -- once every socket on the item is filled.
    if not flags._inSocket and Has(lower, "socket") and not Has(lower, "bonus") then
        flags.emptySockets = (flags.emptySockets or 0) + 1
        return
    end
    if not flags._inSocket and Has(lower, "socket bonus") then
        local rest = original:gsub("^.-[Bb]onus:%s*", "")
        if rest ~= "" and rest ~= original then
            flags.socketStats = flags.socketStats or {}
            flags._inSocket = true
            local lowerRest = rest:lower()
            local startAt = 1
            while startAt <= #rest do
                local at = lowerRest:find(" and ", startAt, true)
                local piece
                if at then
                    piece = rest:sub(startAt, at - 1)
                    startAt = at + 5
                else
                    piece = rest:sub(startAt)
                    startAt = #rest + 1
                end
                if piece ~= "" then
                    ParseLine(piece, flags.socketStats, {}, flags)
                end
            end
            flags._inSocket = nil
        end
        return
    end

    if original:find("^%a[%a%s']+:%s+") then
        text = original:gsub("^%a[%a%s']+:%s+", "")
        lower = text:lower()
        if IsSetLine(lower) then
            flags.hasSet = true
            flags.skipRest = true
            return
        end
        if IsProcLine(lower) then
            flags.hasProc = true
            return
        end
        if lower:match("^use:") then
            flags.hasUse = true
            return
        end
    end

    if Has(lower, "durability") or Has(lower, "classes:") or Has(lower, "requires") or Has(lower, "item level") or Has(lower, "sell price") then
        return
    end

    local weaponLine = false
    local dps = text:match("%((%d+%.?%d*)")
    if dps and (Has(lower, "damage per second") or Has(lower, "dps")) then
        weapon.dps = tonumber(dps)
        weaponLine = true
    end
    local speed = text:match("[Ss]peed%s+(%d+%.?%d*)")
    if speed and Has(lower, "speed") and not Has(lower, "attack speed") and not Has(lower, "haste") then
        weapon.speed = tonumber(speed)
        weaponLine = true
    end
    local minD, maxD = text:match("(%d+)%s*%-%s*(%d+)")
    if minD and Has(lower, "damage") and not Has(lower, "spell") and not Has(lower, "healing") then
        weapon.min = tonumber(minD)
        weapon.max = tonumber(maxD)
        weaponLine = true
    end
    if weaponLine then
        return
    end

    if armorWord then
        local word = Escape(armorWord)
        local armorN = lower:match("^(%d+)%s+" .. word .. "$")
        if armorN then
            found.armor = tonumber(armorN)
            return
        end
        local plusArmor = lower:match("^%+(%d+)%s+" .. word .. "$")
        if plusArmor then
            AddNumber(found, "armor", tonumber(plusArmor))
            return
        end
    end

    if not Has(lower, "%%") and not Has(lower, "chance") then
        local blockN = lower:match("^%+?(%d+)%s+block$")
        if blockN then
            AddNumber(found, "blockValue", tonumber(blockN))
            return
        end
    end

    local function StoreNamed(key, raw)
        local amount = tonumber(raw)
        if not amount then
            return
        end
        if ns.FromRating then
            amount = ns.FromRating(key, amount)
        end
        AddNumber(found, key, amount)
    end

    local num, rest = text:match("^%+?(%d+%.?%d*)%s+(.+)$")
    if num and rest then
        local key = statNames[rest:lower()]
        if key then
            StoreNamed(key, num)
            return
        end
    end
    rest, num = text:match("^(.-)%s+%+(%d+%.?%d*)$")
    if num and rest and rest ~= "" then
        local key = statNames[rest:lower()]
        if key then
            StoreNamed(key, num)
            return
        end
    end

    local pct = tonumber(text:match("(%d+%.?%d*)%%"))
    if pct then
        if Has(lower, "expertise") or (Has(lower, "dodged") and Has(lower, "parried")) then
            AddNumber(found, "expertise", pct)
            return
        end
        if Has(lower, "critical") or Has(lower, "crit") then
            AddNumber(found, Has(lower, "spell") and "spellCrit" or "crit", pct)
            return
        end
        if Has(lower, "hit") then
            AddNumber(found, Has(lower, "spell") and "spellHit" or "hit", pct)
            return
        end
        if Has(lower, "dodge") then
            AddNumber(found, "dodge", pct)
            return
        end
        if Has(lower, "parry") then
            AddNumber(found, "parry", pct)
            return
        end
        if Has(lower, "block") then
            AddNumber(found, "block", pct)
            return
        end
        if Has(lower, "haste") then
            AddNumber(found, "haste", pct)
            return
        end
    end

    if not Has(lower, "%%") and (Has(lower, "skill") or Has(lower, "increased")) then
        local skillN = tonumber(lower:match("(%d+%.?%d*)"))
        local kinds = SkillKinds(lower)
        if skillN and skillN > 0 and skillN <= 20 and #kinds > 0 then
            for i = 1, #kinds do
                AddNumber(found, "skill_" .. kinds[i], skillN)
            end
            return
        end
    end

    if not Has(lower, "%%") then
        local function take(key)
            local value = tonumber(lower:match("(%d+%.?%d*)"))
            if not value then
                return false
            end
            if ns.FromRating then
                value = ns.FromRating(key, value)
            end
            AddNumber(found, key, value)
            return true
        end
        if Has(lower, "expertise") or (Has(lower, "dodged") and Has(lower, "parried")) then
            if take("expertise") then return end
        end
        if Has(lower, "critical") or Has(lower, "crit") then
            if take(Has(lower, "spell") and "spellCrit" or "crit") then return end
        end
        if Has(lower, "hit") then
            if take(Has(lower, "spell") and "spellHit" or "hit") then return end
        end
        if Has(lower, "dodge") and not Has(lower, "dodged") then
            if take("dodge") then return end
        end
        if Has(lower, "parry") and not Has(lower, "parried") then
            if take("parry") then return end
        end
    end

    local n = tonumber(text:match("(%d+%.?%d*)"))
    if not n then
        return
    end
    if Has(lower, "resistance") then
        if Has(lower, "fire") then AddNumber(found, "resFire", n)
        elseif Has(lower, "frost") then AddNumber(found, "resFrost", n)
        elseif Has(lower, "nature") then AddNumber(found, "resNature", n)
        elseif Has(lower, "shadow") then AddNumber(found, "resShadow", n)
        elseif Has(lower, "arcane") then AddNumber(found, "resArcane", n)
        end
        return
    end
    if Has(lower, "block value") then
        AddNumber(found, "blockValue", n)
        return
    end
    if Has(lower, "defense") then
        AddNumber(found, "def", n)
        return
    end
    if Has(lower, "attack power") then
        if Has(lower, "ranged") then
            AddNumber(found, "rap", n)
        elseif Has(lower, "cat") or Has(lower, "feral") or Has(lower, "moonkin") then
            AddNumber(found, "fap", n)
        else
            AddNumber(found, "ap", n)
        end
        return
    end
    if Has(lower, "mana") and Has(lower, "5") then
        AddNumber(found, "mp5", n)
        return
    end
    if Has(lower, "health") and Has(lower, "5") then
        AddNumber(found, "hp5", n)
        return
    end

    local healN, damageN = lower:match("healing.-(%d+%.?%d*).-damage.-(%d+%.?%d*)")
    if healN and damageN then
        AddNumber(found, "heal", tonumber(healN))
        AddNumber(found, "sp", tonumber(damageN))
        return
    end
    damageN, healN = lower:match("damage.-(%d+%.?%d*).-healing.-(%d+%.?%d*)")
    if damageN and healN then
        AddNumber(found, "sp", tonumber(damageN))
        AddNumber(found, "heal", tonumber(healN))
        return
    end

    local school = nil
    if Has(lower, "fire") then school = "fire"
    elseif Has(lower, "frost") then school = "frost"
    elseif Has(lower, "arcane") then school = "arcane"
    elseif Has(lower, "nature") then school = "nature"
    elseif Has(lower, "shadow") then school = "shadow"
    elseif Has(lower, "holy") then school = "holyDmg"
    end
    local healing = Has(lower, "healing")
    local damage = Has(lower, "damage") or Has(lower, "spell power") or Has(lower, "spell damage")
    if school and damage and not healing then
        AddNumber(found, school, n)
        return
    end
    if healing and damage then
        AddNumber(found, "sp", n)
        return
    end
    if healing then
        AddNumber(found, "heal", n)
        return
    end
    if damage and (Has(lower, "spell") or Has(lower, "magical")) then
        AddNumber(found, "sp", n)
    end
end

local PERCENT_KEY = {
    hit = true, crit = true, spellHit = true, spellCrit = true,
    dodge = true, parry = true, block = true, haste = true, expertise = true,
}

local function MarkRedRequirement(text, flags)
    if type(text) ~= "string" then
        return
    end
    local lower = text:lower()
    local dualWieldLine = Has(lower, "dual wield") or Has(lower, "dual-wield")
    local classLine = Has(lower, "classes:") or Has(lower, "class:")
    local metDualWield = dualWieldLine and CanDualWield(ns.ClassFile())
    if not metDualWield and (classLine or Has(lower, "requires") or Has(lower, "cannot")) then
        flags.cannot = true
        flags.reason = classLine and "Your class cannot equip this." or "You do not meet a requirement on this item."
    end
end

local function ScanItemLines(link, found, weapon, flags)
    if not CreateFrame or not UIParent then
        return false
    end
    local tip = ns.scanTip
    if not tip then
        tip = CreateFrame("GameTooltip", "ForeverUpgradeScanTooltip", nil, "GameTooltipTemplate")
        ns.scanTip = tip
    end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    local ok = pcall(tip.SetHyperlink, tip, link)
    if not ok then
        tip:Hide()
        return false
    end
    local name = tip:GetName()
    local count = tip:NumLines()
    if type(count) ~= "number" or count <= 0 then
        tip:Hide()
        return false
    end
    for i = 1, count do
        local left = _G[name .. "TextLeft" .. i]
        local right = _G[name .. "TextRight" .. i]
        local text = left and left.GetText and left:GetText()
        if type(text) == "string" and text ~= "" then
            if right and right.GetText then
                local rightText = right:GetText()
                if type(rightText) == "string" and rightText ~= "" then
                    text = text .. " " .. rightText
                end
            end
            if left.GetTextColor then
                local r, g, b = left:GetTextColor()
                if type(r) == "number" and r > 0.8 and type(g) == "number" and g < 0.25 and type(b) == "number" and b < 0.25 then
                    MarkRedRequirement(text, flags)
                end
            end
            ParseLine(text, found, weapon, flags)
        end
    end
    tip:Hide()
    return true
end

function ns.ParseItem(link)
    local cached = ns.parseCache[link]
    if cached then
        return cached
    end
    BuildNames()
    local found = {}
    local weapon = {}
    local flags = {
        complete = false, cannot = false, hasProc = false, hasSet = false, hasUse = false,
        emptySockets = 0, socketStats = {},
    }
    local hadApi = false
    local hadTip = false

    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if getStats then
        local ok, raw = pcall(getStats, link)
        if ok and type(raw) == "table" then
            hadApi = true
            for key, value in pairs(raw) do
                if type(value) == "number" and not ns.Secret(value) then
                    local stat = API_STAT[key]
                    if stat == "dps" then
                        weapon.dps = value
                    elseif stat then
                        if ns.FromRating then
                            value = ns.FromRating(stat, value)
                        end
                        AddNumber(found, stat, value)
                    end
                end
            end
        end
    end

    local tipFound = {}
    local tipWeapon = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, tip = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and type(tip) == "table" and type(tip.lines) == "table" then
            hadTip = true
            for i = 1, #tip.lines do
                local line = tip.lines[i]
                if type(line) == "table" then
                    local text = LineText(line)
                    if text then
                        if ColorRed(line) then
                            local lower = text:lower()
                            local e = Enum and Enum.TooltipDataLineType
                            local typed = e and (line.type == e.UsageRequirement or line.type == e.ErrorLine or line.type == e.DisabledLine)
                            local dualWieldLine = Has(lower, "dual wield") or Has(lower, "dual-wield")
                            local classLine = Has(lower, "classes:") or Has(lower, "class:")
                            local metDualWield = dualWieldLine and CanDualWield(ns.ClassFile())
                            if not metDualWield and (typed or classLine or Has(lower, "requires") or Has(lower, "cannot")) then
                                flags.cannot = true
                                flags.reason = classLine and "Your class cannot equip this." or "You do not meet a requirement on this item."
                            end
                        end
                        ParseLine(text, tipFound, tipWeapon, flags)
                    end
                end
            end
        end
    end

    -- Classic Era has no C_TooltipInfo. A hidden tooltip still has the lines.
    if not hadTip then
        hadTip = ScanItemLines(link, tipFound, tipWeapon, flags)
    end

    if flags.retrieving then
        hadTip = false
        flags.complete = false
    end

    for key, value in pairs(tipFound) do
        if PERCENT_KEY[key] or key == "armor" or key == "blockValue" or found[key] == nil then
            found[key] = value
        end
    end
    if tipWeapon.dps then
        weapon.dps = tipWeapon.dps
    end
    if tipWeapon.speed then
        weapon.speed = tipWeapon.speed
    end
    if not weapon.dps and tipWeapon.min and tipWeapon.max and weapon.speed and weapon.speed > 0 then
        weapon.dps = (tipWeapon.min + tipWeapon.max) / 2 / weapon.speed
    end
    if weapon.dps then
        found.dps = weapon.dps
    end
    if weapon.speed then
        found.speed = weapon.speed
    end

    local bonus = flags.socketStats
    local hasBonus = false
    if type(bonus) == "table" then
        for _, amount in pairs(bonus) do
            if type(amount) == "number" and amount ~= 0 then
                hasBonus = true
                break
            end
        end
    end
    if hasBonus and (flags.emptySockets or 0) > 0 then
        flags.socketIdle = true
    elseif hasBonus then
        for key, amount in pairs(bonus) do
            if type(amount) == "number" then
                AddNumber(found, key, amount)
            end
        end
    end

    if (hadApi or hadTip) and not flags.retrieving then
        flags.complete = true
    end
    flags.hasProc = flags.hasProc or false
    flags.hasSet = flags.hasSet or false
    flags.hasUse = flags.hasUse or false

    local record = { stats = found, flags = flags }
    if flags.complete then
        ns.parseCache[link] = record
    end
    return record
end

function ns.IsFishingPole(meta)
    return meta and IsWeaponClass(meta.classID) and WeaponKey(meta.subclassID) == "fishing"
end

local function RelicReject(class, subclassID)
    local id = AsNumber(subclassID)
    if not id then
        return nil
    end
    local e = Enum and Enum.ItemArmorSubclass
    local owner, name
    if id == EnumID(e, "Libram", 7) then
        owner, name = "PALADIN", "librams"
    elseif id == EnumID(e, "Idol", 8) then
        owner, name = "DRUID", "idols"
    elseif id == EnumID(e, "Totem", 9) then
        owner, name = "SHAMAN", "totems"
    elseif id == EnumID(e, "Sigil", 10) then
        owner, name = nil, "sigils"
    else
        return nil
    end
    if owner ~= class then
        return "Your class cannot use " .. name .. "."
    end
    return nil
end

function ns.HardReject(class, meta)
    if not class or not meta then
        return nil
    end
    local level = ns.PlayerLevel()
    if meta.reqLevel and level and meta.reqLevel > level then
        return "Requires a higher level."
    end
    if IsWeaponClass(meta.classID) then
        local key = WeaponKey(meta.subclassID)
        if key == "fishing" then
            return nil
        end
        if key and not (WEAPON_OK[class] and WEAPON_OK[class][key]) then
            return "Your class cannot use this weapon."
        end
    end
    if IsArmorClass(meta.classID) then
        local relic = RelicReject(class, meta.subclassID)
        if relic then
            return relic
        end
        local kind = ArmorKind(meta.subclassID)
        if kind == "shield" and not SHIELD_OK[class] then
            return "Your class cannot use shields."
        end
        if kind == "plate" then
            if class ~= "WARRIOR" and class ~= "PALADIN" then
                return "Your class cannot wear plate."
            end
            if level and level < 40 then
                return "Plate is trained at level 40."
            end
        elseif kind == "mail" then
            if class ~= "WARRIOR" and class ~= "PALADIN" and class ~= "HUNTER" and class ~= "SHAMAN" then
                return "Your class cannot wear mail."
            end
            if level and level < 40 and (class == "HUNTER" or class == "SHAMAN") then
                return "Mail is trained at level 40."
            end
        elseif kind == "leather" then
            if class == "MAGE" or class == "PRIEST" or class == "WARLOCK" then
                return "Your class cannot wear leather."
            end
        end
    end
    return nil
end

local function SinglePlan(slot, name)
    return { mode = "slot", slots = { slot }, names = { name }, kind = nil }
end

function ns.Plan(meta)
    local slot = ns.Slots()
    local loc = meta.equipLoc
    if loc == "INVTYPE_FINGER" then
        return { mode = "multi", slots = { slot.FINGER1, slot.FINGER2 }, names = { "ring 1", "ring 2" }, kind = nil }
    end
    if loc == "INVTYPE_TRINKET" then
        return { mode = "multi", slots = { slot.TRINKET1, slot.TRINKET2 }, names = { "trinket 1", "trinket 2" }, kind = nil }
    end
    if loc == "INVTYPE_2HWEAPON" then
        return { mode = "2h", kind = "2h" }
    end
    if loc == "INVTYPE_WEAPON" then
        return { mode = "weapon1h", kind = "mh" }
    end
    if loc == "INVTYPE_WEAPONMAINHAND" then
        return { mode = "mh", kind = "mh" }
    end
    if loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
        return { mode = "oh", kind = "oh" }
    end
    if loc == "INVTYPE_RANGED" or loc == "INVTYPE_RANGEDRIGHT" or loc == "INVTYPE_THROWN" or loc == "INVTYPE_RELIC" then
        local kind = IsWeaponClass(meta.classID) and "ranged" or nil
        return { mode = "slot", slots = { slot.RANGED }, names = { "ranged" }, kind = kind }
    end
    if loc == "INVTYPE_HEAD" then return SinglePlan(slot.HEAD, "head") end
    if loc == "INVTYPE_NECK" then return SinglePlan(slot.NECK, "neck") end
    if loc == "INVTYPE_SHOULDER" then return SinglePlan(slot.SHOULDER, "shoulder") end
    if loc == "INVTYPE_CHEST" or loc == "INVTYPE_ROBE" then return SinglePlan(slot.CHEST, "chest") end
    if loc == "INVTYPE_WAIST" then return SinglePlan(slot.WAIST, "waist") end
    if loc == "INVTYPE_LEGS" then return SinglePlan(slot.LEGS, "legs") end
    if loc == "INVTYPE_FEET" then return SinglePlan(slot.FEET, "feet") end
    if loc == "INVTYPE_WRIST" then return SinglePlan(slot.WRIST, "wrist") end
    if loc == "INVTYPE_HAND" then return SinglePlan(slot.HAND, "hands") end
    if loc == "INVTYPE_CLOAK" then return SinglePlan(slot.BACK, "back") end
    return nil
end

local function ItemBody(link)
    if type(link) ~= "string" then
        return nil
    end
    return link:match("item:[%d:%-]+")
end

local function SameItem(link, guid, slot)
    local equippedGuid = ns.EquippedGUID(slot)
    if guid and equippedGuid then
        return guid == equippedGuid
    end
    local equipped = ns.EquippedLink(slot)
    if not equipped then
        return false
    end
    if equipped == link then
        return true
    end
    local left = ItemBody(equipped)
    local right = ItemBody(link)
    return left ~= nil and left == right
end

local function KindFor(link, slot)
    local meta = ns.ItemMeta(link)
    local slots = ns.Slots()
    if not meta then
        return nil
    end
    if meta.equipLoc == "INVTYPE_2HWEAPON" then
        return "2h"
    end
    if slot == slots.MAINHAND then
        return "mh"
    end
    if slot == slots.OFFHAND then
        return "oh"
    end
    if slot == slots.RANGED and IsWeaponClass(meta.classID) then
        return "ranged"
    end
    return nil
end

local function WearingTwoHand()
    local link = ns.EquippedLink(ns.Slots().MAINHAND)
    if not link then
        return false, nil
    end
    local meta = ns.ItemMeta(link)
    if meta and meta.equipLoc == "INVTYPE_2HWEAPON" then
        return true, link
    end
    return false, link
end

local function ItemName(link, meta)
    if meta and type(meta.name) == "string" and meta.name ~= "" then
        return meta.name
    end
    if type(link) == "string" then
        local bracket = link:match("%[(.-)%]")
        if bracket and bracket ~= "" then
            return bracket
        end
    end
    return "that item"
end

-- A two-hander cannot share a set with a shield, so it is never a partner.
local function PartnerRole(meta)
    if not meta then
        return nil
    end
    local loc = meta.equipLoc
    if loc == "INVTYPE_WEAPONMAINHAND" then
        return "mh"
    end
    if loc == "INVTYPE_WEAPON" then
        return "weapon1h"
    end
    if loc == "INVTYPE_WEAPONOFFHAND" or loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" then
        return "oh"
    end
    return nil
end

local function WantedHand(candidate, hand, class)
    if candidate.role == hand then
        return true
    end
    if candidate.role ~= "weapon1h" then
        return false
    end
    if hand == "mh" then
        return true
    end
    return CanDualWield(class)
end

local function BagLimit()
    local n = NUM_BAG_SLOTS
    if type(n) == "number" and not ns.Secret(n) and n >= 0 then
        return n
    end
    return 4
end

local function BagSize(bag)
    local fn = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if type(fn) ~= "function" then
        return 0
    end
    local ok, n = pcall(fn, bag)
    if not ok or type(n) ~= "number" or ns.Secret(n) or n < 0 then
        return 0
    end
    return n
end

local function BagGUID(bag, slot)
    if not ItemLocation or not ItemLocation.CreateFromBagAndSlot or not C_Item or not C_Item.GetItemGUID then
        return nil
    end
    local created, loc = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, bag, slot)
    if not created or not loc or not loc.IsValid then
        return nil
    end
    local checked, isValid = pcall(loc.IsValid, loc)
    if not checked or ns.Secret(isValid) or isValid ~= true then
        return nil
    end
    local got, guid = pcall(C_Item.GetItemGUID, loc)
    if not got or type(guid) ~= "string" or ns.Secret(guid) then
        return nil
    end
    return guid
end

local function BagItem(bag, slot)
    local link, guid = nil, nil
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            if type(info.hyperlink) == "string" and not ns.Secret(info.hyperlink) then
                link = info.hyperlink
            end
            if type(info.itemGUID) == "string" and not ns.Secret(info.itemGUID) then
                guid = info.itemGUID
            end
        end
    end
    if not link then
        local fn = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
        if type(fn) == "function" then
            local ok, found = pcall(fn, bag, slot)
            if ok and type(found) == "string" and not ns.Secret(found) then
                link = found
            end
        end
    end
    if link and not guid then
        guid = BagGUID(bag, slot)
    end
    return link, guid
end

local function CollectPartners()
    local list = {}
    local function add(link, guid, equipped)
        if type(link) ~= "string" then
            return
        end
        local meta = ns.ItemMeta(link)
        local role = PartnerRole(meta)
        if not role or ns.IsFishingPole(meta) then
            return
        end
        list[#list + 1] = {
            link = link,
            guid = guid,
            id = meta.id or ns.LinkID(link),
            role = role,
            name = ItemName(link, meta),
            equipped = equipped and true or false,
            meta = meta,
        }
    end
    local slots = ns.Slots()
    add(ns.EquippedLink(slots.MAINHAND), ns.EquippedGUID(slots.MAINHAND), true)
    add(ns.EquippedLink(slots.OFFHAND), ns.EquippedGUID(slots.OFFHAND), true)
    local bags = BagLimit()
    for bag = 0, bags do
        local n = BagSize(bag)
        for slot = 1, n do
            local link, guid = BagItem(bag, slot)
            add(link, guid, false)
        end
    end
    return list
end

-- The hovered piece is not its own partner. The same item id pairs only when
-- a second copy is in bags or equipped, so two of one dagger can fill both hands.
local function SamePiece(candidate, guid, id, copies)
    if guid and candidate.guid and candidate.guid == guid then
        return true
    end
    if id and candidate.id == id and (copies[id] or 0) < 2 then
        return true
    end
    return false
end

local function PartnerScore(candidate, class, weights, kind)
    if candidate.id and failedLoads[candidate.id] then
        return nil, false
    end
    if not candidate.meta.loaded then
        ns.RequestItem(candidate.id)
    end
    if ns.HardReject(class, candidate.meta) then
        return nil, false
    end
    local item = ns.ParseItem(candidate.link)
    if not item.flags.complete then
        ns.RequestItem(candidate.id)
        return nil, true
    end
    if item.flags.cannot then
        return nil, false
    end
    -- Stats can score before the item record arrives. The load event refreshes
    -- the line, and HardReject then drops anything over level or unusable.
    local total = ns.Score(item.stats, weights, kind, ns.WeaponType(candidate.meta))
    return total, false
end

-- hand is "mh" or "oh". Returns partner, pending.
local function BestPartner(hand, link, guid, class, weights)
    local list = CollectPartners()
    local hoveredId = ns.LinkID(link)
    local copies = {}
    for i = 1, #list do
        local candidate = list[i]
        if WantedHand(candidate, hand, class) and candidate.id then
            copies[candidate.id] = (copies[candidate.id] or 0) + 1
        end
    end
    local kind = (hand == "mh") and "mh" or "oh"
    local best = nil
    local pending = false
    for i = 1, #list do
        local candidate = list[i]
        if WantedHand(candidate, hand, class) and not SamePiece(candidate, guid, hoveredId, copies) then
            local total, waiting = PartnerScore(candidate, class, weights, kind)
            if waiting then
                pending = true
            elseif type(total) == "number" then
                local better = not best or total > best.score
                local tie = best and total == best.score and candidate.equipped and not best.equipped
                if better or tie then
                    best = {
                        link = candidate.link,
                        guid = candidate.guid,
                        name = candidate.name,
                        score = total,
                        equipped = candidate.equipped,
                    }
                end
            end
        end
    end
    -- Wait only while every candidate is still loading. A scored partner shows
    -- immediately; a later load refreshes the line if something better arrives.
    if pending and (not best or best.score <= 0) then
        return nil, true
    end
    -- An empty hand scores 0. Keep it when nothing in the bags beats that.
    if not best or best.score <= 0 then
        return nil, false
    end
    return best, false
end

local function WithPartner(parts, partner)
    local copy = {}
    if parts then
        for i = 1, #parts do
            copy[i] = parts[i]
        end
    end
    copy[#copy + 1] = {
        text = partner.name .. " " .. ns.FormatScore(partner.score or 0),
        contrib = partner.score or 0,
    }
    table.sort(copy, function(a, b)
        return math.abs(a.contrib) > math.abs(b.contrib)
    end)
    return copy
end

local function PartnerNote(partner, handName, replacesTwoHand, equippedSlot)
    local text = "Paired with " .. partner.name .. " in the " .. handName .. "."
    if replacesTwoHand then
        return text .. " Replaces your two-hander."
    end
    local worn = ns.EquippedLink(equippedSlot)
    if worn and not SameItem(partner.link, partner.guid, equippedSlot) then
        return text .. " Replaces your main hand and off hand."
    end
    return text
end

local function FamilyFor(plan, meta)
    local mode = plan and plan.mode
    if mode == "mh" or mode == "weapon1h" or mode == "2h" or mode == "oh" then
        return "weapon"
    end
    local loc = meta and meta.equipLoc
    if loc == "INVTYPE_ROBE" then
        return "INVTYPE_CHEST"
    end
    return loc
end

function ns.InvalidateScores()
    ns.evalStamp = (ns.evalStamp or 0) + 1
    ns.evalCache = {}
end

local EvaluateItem

function ns.Evaluate(link, guid, specOverride)
    if not ns.ready or type(link) ~= "string" then
        return { verdict = "ignore" }
    end
    local stamp = (ns.evalStamp or 0) .. "|" .. tostring(ns.cacheGen or 0)
    local cacheKey = stamp .. "|" .. link .. "|" .. tostring(guid or "") .. "|" .. tostring(specOverride or "")
    local cached = ns.evalCache and ns.evalCache[cacheKey]
    if cached then
        return cached
    end
    local result = EvaluateItem(link, guid, specOverride)
    ns.scoreSpec = nil
    if result.verdict ~= "pending" then
        if not ns.evalCache then
            ns.evalCache = {}
        end
        ns.evalCache[cacheKey] = result
    end
    return result
end

EvaluateItem = function(link, guid, specOverride)
    local meta = ns.ItemMeta(link)
    if (not meta.equipLoc or meta.equipLoc == "") and not meta.instant and not meta.loaded then
        ns.RequestItem(meta.id)
        return { verdict = "pending" }
    end
    if not meta.equipLoc or meta.equipLoc == "" or IGNORE_LOC[meta.equipLoc] or ns.IsFishingPole(meta) then
        return { verdict = "ignore" }
    end

    local class = ns.ClassFile()
    local reject = ns.HardReject(class, meta)
    if reject then
        return { verdict = "cannot", reason = reject }
    end

    local parsed = ns.ParseItem(link)
    if not parsed.flags.complete then
        ns.RequestItem(meta.id)
        return { verdict = "pending" }
    end
    if parsed.flags.cannot then
        return { verdict = "cannot", reason = parsed.flags.reason or "You cannot equip this." }
    end

    local plan = ns.Plan(meta)
    if not plan then
        return { verdict = "ignore" }
    end

    local info = ns.GetSpecInfo()
    local spec = info.spec
    if type(specOverride) == "string" and ns.SpecAllowed(class, specOverride) then
        spec = specOverride
    end
    ns.scoreSpec = spec
    local weights = ns.MergedWeights(class, spec)
    local base = {
        spec = spec,
        specLabel = specOverride and (ns.SPEC_LABEL[spec] or spec) or info.label,
        custom = ns.UsingCustom(class, spec),
        lowConfidence = specOverride and false or info.lowConfidence,
        hasProc = parsed.flags.hasProc,
        hasSet = parsed.flags.hasSet,
        hasUse = parsed.flags.hasUse,
        socketIdle = parsed.flags.socketIdle and true or false,
        family = FamilyFor(plan, meta),
        equipLoc = meta.equipLoc,
        name = ItemName(link, meta),
        link = link,
    }

    local function scoreLink(itemLink, kind)
        if not itemLink then
            return 0, false, nil
        end
        local item = ns.ParseItem(itemLink)
        if not item.flags.complete then
            ns.RequestItem(ns.LinkID(itemLink))
            return nil, true, nil
        end
        local total, parts = ns.Score(item.stats, weights, kind, ns.WeaponType(ns.ItemMeta(itemLink)))
        if not kind and ns.WeaponSkillValue then
            local slots = ns.Slots()
            local hands = {
                { slot = slots.MAINHAND },
                { slot = slots.OFFHAND },
                { slot = slots.RANGED },
            }
            for i = 1, #hands do
                local wornLink = ns.EquippedLink(hands[i].slot)
                local wornMeta = wornLink and ns.ItemMeta(wornLink)
                local wornKey = wornMeta and ns.WeaponType(wornMeta)
                local amount = wornKey and item.stats["skill_" .. wornKey]
                if type(amount) == "number" and amount > 0 then
                    local wornKind = "mh"
                    if hands[i].slot == slots.RANGED then
                        wornKind = "ranged"
                    elseif wornMeta.equipLoc == "INVTYPE_2HWEAPON" then
                        wornKind = "2h"
                    elseif hands[i].slot == slots.OFFHAND then
                        wornKind = "oh"
                    end
                    local worn = ns.ParseItem(wornLink)
                    local contrib = ns.WeaponSkillValue(weights, wornKind, worn.stats and worn.stats.dps, amount)
                    if type(contrib) == "number" and math.abs(contrib) >= 0.05 then
                        total = (total or 0) + contrib
                        parts = parts or {}
                        local label = wornKey:gsub("1h$", ""):gsub("2h$", "")
                        parts[#parts + 1] = { text = "+" .. ns.FormatNum(amount) .. " " .. label .. " skill", contrib = contrib }
                    end
                end
            end
        end
        return total, false, parts
    end

    local score, pending, parts = scoreLink(link, plan.kind)
    if pending then
        return { verdict = "pending" }
    end
    base.score = score
    base.parts = parts

    local function finish(verdict, delta, equippedScore, slotText, note)
        base.verdict = verdict
        base.delta = delta
        base.equippedScore = equippedScore
        base.slotText = slotText
        base.note = note
        return base
    end

    -- Any higher score is an upgrade. A low-level armor jump can be a fraction
    -- of a point and still be the whole reason to equip the item. An empty
    -- slot is an upgrade when the piece is not worse than wearing nothing.
    local function verdictFor(delta, slotEmpty, itemScore, equippedScore)
        local verdict = "similar"
        if type(delta) == "number" and delta > 0 then
            verdict = "upgrade"
        elseif type(delta) == "number" and delta < 0 then
            verdict = "downgrade"
        end
        if slotEmpty and type(delta) == "number" and delta >= 0 then
            verdict = "upgrade"
        end
        return verdict
    end

    if plan.mode == "slot" or plan.mode == "multi" then
        for i = 1, #plan.slots do
            if SameItem(link, guid, plan.slots[i]) then
                return finish("equipped", nil, score, plan.names[i], nil)
            end
        end
        local bestIndex = 1
        local bestScore = nil
        local bestEmpty = false
        for i = 1, #plan.slots do
            local equipped = ns.EquippedLink(plan.slots[i])
            local equippedScore, equippedPending = scoreLink(equipped, plan.kind)
            if equippedPending then
                return { verdict = "pending" }
            end
            local empty = not equipped
            local lower = not bestScore or equippedScore < bestScore
            if not lower and bestScore == equippedScore and empty and not bestEmpty then
                lower = true
            end
            if lower then
                bestScore = equippedScore
                bestIndex = i
                bestEmpty = empty
            end
        end
        local delta = score - bestScore
        return finish(verdictFor(delta, bestEmpty, score, bestScore), delta, bestScore, plan.names[bestIndex], nil)
    end

    local slots = ns.Slots()
    local twoHand, mainLink = WearingTwoHand()

    -- The equipped side of the line: a two-hander, or main hand plus off hand.
    local function CurrentWeaponScore()
        if twoHand then
            local equippedScore, equippedPending = scoreLink(mainLink, "2h")
            if equippedPending then
                return nil, true
            end
            return equippedScore or 0, false, "two-hand"
        end
        local mhScore, mhPending = scoreLink(mainLink, "mh")
        if mhPending then
            return nil, true
        end
        local ohLink = ns.EquippedLink(slots.OFFHAND)
        local ohScore, ohPending = scoreLink(ohLink, "oh")
        if ohPending then
            return nil, true
        end
        local total = (mhScore or 0) + (ohScore or 0)
        local slotText = ohLink and "main hand + off hand" or "main hand"
        return total, false, slotText
    end

    if plan.mode == "oh" then
        if SameItem(link, guid, slots.OFFHAND) then
            return finish("equipped", nil, score, "off hand", nil)
        end
        -- A shield pairs with the highest-scoring one-hand main hand you own.
        local partner, partnerPending = BestPartner("mh", link, guid, class, weights)
        if partnerPending then
            return { verdict = "pending" }
        end
        if not partner then
            if twoHand then
                return finish("info", nil, nil, "off hand", "Your two-hander uses both hands, so this off-hand is not compared.")
            end
            local equippedLink = ns.EquippedLink(slots.OFFHAND)
            local equippedScore, equippedPending = scoreLink(equippedLink, "oh")
            if equippedPending then
                return { verdict = "pending" }
            end
            local delta = score - equippedScore
            return finish(verdictFor(delta, not equippedLink, score, equippedScore), delta, equippedScore, "off hand", nil)
        end
        local equippedScore, equippedPending, slotText = CurrentWeaponScore()
        if equippedPending then
            return { verdict = "pending" }
        end
        local shown = (score or 0) + partner.score
        base.score = shown
        base.parts = WithPartner(parts, partner)
        local delta = shown - (equippedScore or 0)
        local note = PartnerNote(partner, "main hand", twoHand, slots.MAINHAND)
        local offEmpty = not twoHand and not ns.EquippedLink(slots.OFFHAND)
        return finish(verdictFor(delta, offEmpty, shown, equippedScore or 0), delta, equippedScore or 0, slotText, note)
    end

    if plan.mode == "2h" then
        if SameItem(link, guid, slots.MAINHAND) then
            return finish("equipped", nil, score, "two-hand", nil)
        end
        if twoHand then
            local equippedScore, equippedPending = scoreLink(mainLink, "2h")
            if equippedPending then
                return { verdict = "pending" }
            end
            local delta = score - equippedScore
            return finish(verdictFor(delta, false, score, equippedScore), delta, equippedScore, "two-hand", "Replaces your two-hander.")
        end
        local mhScore, mhPending = scoreLink(mainLink, "mh")
        if mhPending then
            return { verdict = "pending" }
        end
        local ohLink = ns.EquippedLink(slots.OFFHAND)
        local ohScore, ohPending = scoreLink(ohLink, "oh")
        if ohPending then
            return { verdict = "pending" }
        end
        local equippedScore = (mhScore or 0) + (ohScore or 0)
        local delta = score - equippedScore
        local note = mainLink and "Replaces main hand and off hand." or nil
        local handsEmpty = not mainLink and not ohLink
        return finish(verdictFor(delta, handsEmpty, score, equippedScore), delta, equippedScore, mainLink and "main hand + off hand" or "main hand", note)
    end

    -- One-hand main-hand, or a one-hand weapon that can go in either hand.
    if SameItem(link, guid, slots.MAINHAND) then
        local equippedScore, equippedPending, equippedParts = scoreLink(link, "mh")
        if equippedPending then
            return { verdict = "pending" }
        end
        base.score = equippedScore
        base.parts = equippedParts
        return finish("equipped", nil, equippedScore, "main hand", nil)
    end
    if not twoHand and SameItem(link, guid, slots.OFFHAND) then
        local equippedScore, equippedPending, equippedParts = scoreLink(link, "oh")
        if equippedPending then
            return { verdict = "pending" }
        end
        base.score = equippedScore
        base.parts = equippedParts
        return finish("equipped", nil, equippedScore, "off hand", nil)
    end

    local function compareMain()
        local itemScore, itemPending, itemParts = scoreLink(link, "mh")
        if itemPending then
            return nil
        end
        -- Always add the best off-hand in bags or the off-hand slot, even
        -- while a main hand is already worn. No partner keeps the old line.
        local partner, partnerPending = BestPartner("oh", link, guid, class, weights)
        if partnerPending then
            return nil
        end
        if partner then
            local equippedScore, equippedPending, slotText = CurrentWeaponScore()
            if equippedPending then
                return nil
            end
            local shown = itemScore + partner.score
            local note = PartnerNote(partner, "off hand", twoHand, slots.OFFHAND)
            return {
                delta = shown - (equippedScore or 0),
                equipped = equippedScore or 0,
                score = shown,
                parts = WithPartner(itemParts, partner),
                slotText = slotText,
                note = note,
                empty = not twoHand and not mainLink,
            }
        end
        local equippedKind = twoHand and "2h" or "mh"
        local equippedScore, equippedPending = scoreLink(mainLink, equippedKind)
        if equippedPending then
            return nil
        end
        local delta = itemScore - (equippedScore or 0)
        local note = twoHand and "Replaces your two-hander and leaves the off hand empty." or nil
        local slotText = twoHand and "two-hand" or "main hand"
        return {
            delta = delta,
            equipped = equippedScore or 0,
            score = itemScore,
            parts = itemParts,
            slotText = slotText,
            note = note,
            empty = not mainLink,
        }
    end

    local best = compareMain()
    if not best then
        return { verdict = "pending" }
    end

    if plan.mode == "weapon1h" and CanDualWield(class) and not twoHand then
        local ohScore, ohPending, ohParts = scoreLink(link, "oh")
        if ohPending then
            return { verdict = "pending" }
        end
        local ohLink = ns.EquippedLink(slots.OFFHAND)
        local equippedOh, ohEquipPending = scoreLink(ohLink, "oh")
        if ohEquipPending then
            return { verdict = "pending" }
        end
        local delta = ohScore - (equippedOh or 0)
        if delta > best.delta then
            best = {
                delta = delta,
                equipped = equippedOh or 0,
                score = ohScore,
                parts = ohParts,
                slotText = "off hand",
                note = nil,
                empty = not ohLink,
            }
        end
    end

    base.score = best.score
    base.parts = best.parts
    return finish(verdictFor(best.delta, best.empty, best.score, best.equipped), best.delta, best.equipped, best.slotText, best.note)
end

local function ItemDataLoaded(itemID, success)
    if type(itemID) ~= "number" then
        return
    end
    if not ns.Secret(success) and success == false then
        failedLoads[itemID] = true
    elseif not ns.Secret(success) and success then
        failedLoads[itemID] = nil
    end
    local care = pendingIDs[itemID] == true
    pendingIDs[itemID] = nil
    for link in pairs(ns.parseCache) do
        if ns.LinkID(link) == itemID then
            ns.parseCache[link] = nil
            care = true
        end
    end
    if care then
        if ns.InvalidateScores then
            ns.InvalidateScores()
        end
        if ns.RefreshTooltip then
            ns.RefreshTooltip()
        end
    end
end

ns.On("ITEM_DATA_LOAD_RESULT", ItemDataLoaded)
ns.On("GET_ITEM_INFO_RECEIVED", ItemDataLoaded)

local function RefreshOpenTooltip()
    if ns.InvalidateScores then
        ns.InvalidateScores()
    end
    if ns.RefreshTooltip then
        ns.RefreshTooltip()
    end
end

ns.On("PLAYER_EQUIPMENT_CHANGED", RefreshOpenTooltip)
ns.On("BAG_UPDATE_DELAYED", RefreshOpenTooltip)
