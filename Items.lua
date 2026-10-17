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
-- Forever teaches Dual Wield to hunters as well as warriors and rogues.
local DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }

local function CanDualWield(class)
    if DUAL_WIELD[class] then
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

function ns.RequestItem(itemID)
    if itemID and C_Item and C_Item.RequestLoadItemDataByID then
        pendingIDs[itemID] = true
        pcall(C_Item.RequestLoadItemDataByID, itemID)
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

function ns.ItemMeta(link)
    local meta = { link = link, id = ns.LinkID(link) }
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
        meta.equipLoc = equipLoc
        meta.classID = classID
        meta.subclassID = subclassID
        if equipLoc or classID then
            meta.instant = true
        end
    end
    if C_Item and C_Item.GetItemInfo then
        local name, _, _, _, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = C_Item.GetItemInfo(link)
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

    local num, rest = text:match("^%+?(%d+%.?%d*)%s+(.+)$")
    if num and rest then
        local key = statNames[rest:lower()]
        if key then
            AddNumber(found, key, tonumber(num))
            return
        end
    end
    rest, num = text:match("^(.-)%s+%+(%d+%.?%d*)$")
    if num and rest and rest ~= "" then
        local key = statNames[rest:lower()]
        if key then
            AddNumber(found, key, tonumber(num))
            return
        end
    end

    local pct = tonumber(text:match("(%d+%.?%d*)%%"))
    if pct then
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
    dodge = true, parry = true, block = true, haste = true,
}

function ns.ParseItem(link)
    local cached = ns.parseCache[link]
    if cached then
        return cached
    end
    BuildNames()
    local found = {}
    local weapon = {}
    local flags = { complete = false, cannot = false, hasProc = false, hasSet = false, hasUse = false }
    local hadApi = false
    local hadTip = false

    if C_Item and C_Item.GetItemStats then
        local ok, raw = pcall(C_Item.GetItemStats, link)
        if ok and type(raw) == "table" then
            hadApi = true
            for key, value in pairs(raw) do
                if type(value) == "number" and not ns.Secret(value) then
                    local stat = API_STAT[key]
                    if stat == "dps" then
                        weapon.dps = value
                    elseif stat then
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

function ns.Evaluate(link, guid)
    if not ns.ready or type(link) ~= "string" then
        return { verdict = "ignore" }
    end
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
    local weights = ns.MergedWeights(class, info.spec)
    local base = {
        specLabel = info.label,
        custom = info.custom,
        lowConfidence = info.lowConfidence,
        hasProc = parsed.flags.hasProc,
        hasSet = parsed.flags.hasSet,
        hasUse = parsed.flags.hasUse,
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
        local total, parts = ns.Score(item.stats, weights, kind)
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

    local function verdictFor(delta)
        local margin = (ns.char and ns.char.margin) or 0.5
        if math.abs(delta) <= margin then
            return "similar"
        end
        if delta > 0 then
            return "upgrade"
        end
        return "downgrade"
    end

    if plan.mode == "slot" or plan.mode == "multi" then
        for i = 1, #plan.slots do
            if SameItem(link, guid, plan.slots[i]) then
                return finish("equipped", nil, score, plan.names[i], nil)
            end
        end
        local bestIndex = 1
        local bestScore = nil
        for i = 1, #plan.slots do
            local equipped = ns.EquippedLink(plan.slots[i])
            local equippedScore, equippedPending = scoreLink(equipped, plan.kind)
            if equippedPending then
                return { verdict = "pending" }
            end
            if not bestScore or equippedScore < bestScore then
                bestScore = equippedScore
                bestIndex = i
            end
        end
        local delta = score - bestScore
        return finish(verdictFor(delta), delta, bestScore, plan.names[bestIndex], nil)
    end

    local slots = ns.Slots()
    local twoHand, mainLink = WearingTwoHand()

    if plan.mode == "oh" then
        if twoHand then
            return finish("info", nil, nil, "off hand", "Your two-hander uses both hands. This scores " .. ns.FormatScore(score) .. " as an off-hand.")
        end
        if SameItem(link, guid, slots.OFFHAND) then
            return finish("equipped", nil, score, "off hand", nil)
        end
        local equippedScore, equippedPending = scoreLink(ns.EquippedLink(slots.OFFHAND), "oh")
        if equippedPending then
            return { verdict = "pending" }
        end
        local delta = score - equippedScore
        return finish(verdictFor(delta), delta, equippedScore, "off hand", nil)
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
            return finish(verdictFor(delta), delta, equippedScore, "two-hand", "Replaces your two-hander.")
        end
        local mhScore, mhPending = scoreLink(mainLink, "mh")
        if mhPending then
            return { verdict = "pending" }
        end
        local ohScore, ohPending = scoreLink(ns.EquippedLink(slots.OFFHAND), "oh")
        if ohPending then
            return { verdict = "pending" }
        end
        local equippedScore = (mhScore or 0) + (ohScore or 0)
        local delta = score - equippedScore
        local note = mainLink and "Replaces main hand and off hand." or nil
        return finish(verdictFor(delta), delta, equippedScore, mainLink and "main hand + off hand" or "main hand", note)
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
        local equippedKind = twoHand and "2h" or "mh"
        local equippedScore, equippedPending = scoreLink(mainLink, equippedKind)
        if equippedPending then
            return nil
        end
        local itemScore, itemPending, itemParts = scoreLink(link, "mh")
        if itemPending then
            return nil
        end
        local delta = itemScore - (equippedScore or 0)
        local note = twoHand and "Replaces your two-hander and leaves the off hand empty." or nil
        local slotText = twoHand and "two-hand" or "main hand"
        return { delta = delta, equipped = equippedScore or 0, score = itemScore, parts = itemParts, slotText = slotText, note = note }
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
        local equippedOh, ohEquipPending = scoreLink(ns.EquippedLink(slots.OFFHAND), "oh")
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
            }
        end
    end

    base.score = best.score
    base.parts = best.parts
    return finish(verdictFor(best.delta), best.delta, best.equipped, best.slotText, best.note)
end

ns.On("ITEM_DATA_LOAD_RESULT", function(itemID)
    if type(itemID) ~= "number" then
        return
    end
    local care = pendingIDs[itemID] == true
    pendingIDs[itemID] = nil
    for link in pairs(ns.parseCache) do
        if ns.LinkID(link) == itemID then
            ns.parseCache[link] = nil
            care = true
        end
    end
    if care and ns.RefreshTooltip then
        ns.RefreshTooltip()
    end
end)

ns.On("PLAYER_EQUIPMENT_CHANGED", function()
    if ns.RefreshTooltip then
        ns.RefreshTooltip()
    end
end)
