local _, ns = ...

-- Starter level-60 weights. One point of the main stat is about 1.
-- Hit and crit weights are per 1%. Classic Era gear says 1%. Forever's
-- launch client says 10 hit or 14 crit for that same 1%, and parsing
-- converts those points before the weight is applied.
-- Weapon DPS is per point of DPS. Weapon speed is per second above 2.0,
-- so a negative off-hand speed weight favors a fast off-hand.
-- Agility is priced from the crit and dodge weights already in that row.
-- At 60, 20 agility is 1% crit for a warrior, paladin, shaman or druid,
-- and 53 agility is 1% for a hunter. Hunters also get 2 ranged AP per agility.
-- Checked against The Forever Era class tables (October 2026), Warcraft
-- Tavern's Forever stat guide, Wowhead's phase-1 cat weights, and ForeverDB's
-- level-30 arms sim. The 15 October 2026 beta notes change three rows.
-- Arcane intellect is 0.85 because Arcane Blast grants 15% of intellect as
-- spell damage per stack, and Arcane Wrath adds spell power equal to 5% of
-- maximum mana. Flat mana keeps its own weight, because it does not get the
-- Arcane Blast conversion. Retribution intellect is 0.10 after Champion of
-- the Light was cut in half. Protection paladin spell power and holy damage
-- are 0.25 after Consecration's coefficient dropped. These rows are not a
-- full simulation.

ns.TREE_ORDER = {
    WARRIOR = { "arms", "fury", "protection" },
    PALADIN = { "holy", "protection", "retribution" },
    HUNTER = { "beastmastery", "marksmanship", "survival" },
    ROGUE = { "assassination", "combat", "subtlety" },
    PRIEST = { "discipline", "holy", "shadow" },
    SHAMAN = { "elemental", "enhancement", "restoration" },
    MAGE = { "arcane", "fire", "frost" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    DRUID = { "balance", "feral", "restoration" },
}

ns.LEVELING = {
    WARRIOR = "arms",
    PALADIN = "retribution",
    HUNTER = "beastmastery",
    ROGUE = "combat",
    PRIEST = "shadow",
    SHAMAN = "enhancement",
    MAGE = "frost",
    WARLOCK = "affliction",
    DRUID = "feral",
}

ns.SPEC_LABEL = {
    arms = "Arms",
    fury = "Fury",
    protection = "Protection",
    holy = "Holy",
    retribution = "Retribution",
    beastmastery = "Beast Mastery",
    marksmanship = "Marksmanship",
    survival = "Survival",
    assassination = "Assassination",
    combat = "Combat",
    subtlety = "Subtlety",
    discipline = "Discipline",
    shadow = "Shadow",
    elemental = "Elemental",
    enhancement = "Enhancement",
    restoration = "Restoration",
    arcane = "Arcane",
    fire = "Fire",
    frost = "Frost",
    affliction = "Affliction",
    demonology = "Demonology",
    destruction = "Destruction",
    balance = "Balance",
    feral = "Feral",
    feraltank = "Feral Bear",
}

ns.SPEC_ALIAS = {
    arms = "arms",
    fury = "fury",
    prot = "protection",
    protection = "protection",
    holy = "holy",
    ret = "retribution",
    retribution = "retribution",
    bm = "beastmastery",
    beast = "beastmastery",
    beastmastery = "beastmastery",
    ["beast mastery"] = "beastmastery",
    mm = "marksmanship",
    marks = "marksmanship",
    marksmanship = "marksmanship",
    survival = "survival",
    surv = "survival",
    assassination = "assassination",
    assassin = "assassination",
    combat = "combat",
    subtlety = "subtlety",
    sub = "subtlety",
    disc = "discipline",
    discipline = "discipline",
    shadow = "shadow",
    elemental = "elemental",
    ele = "elemental",
    ["elemental combat"] = "elemental",
    enhancement = "enhancement",
    enh = "enhancement",
    resto = "restoration",
    restoration = "restoration",
    arcane = "arcane",
    fire = "fire",
    frost = "frost",
    affliction = "affliction",
    aff = "affliction",
    demonology = "demonology",
    demo = "demonology",
    destruction = "destruction",
    destro = "destruction",
    balance = "balance",
    boomkin = "balance",
    feral = "feral",
    cat = "feral",
    ["feral combat"] = "feral",
    bear = "feraltank",
    feraltank = "feraltank",
    ["feral tank"] = "feraltank",
    ["feral bear"] = "feraltank",
    guardian = "feraltank",
}

ns.WEIGHTS = {
    WARRIOR = {
        arms = {
            hit = 14, crit = 12, dps2h = 6.5, speed2h = 8,
            dpsMH = 3, dpsOH = 1.2, str = 1, agi = 0.6, ap = 0.5,
            sta = 0.35, hp5 = 0.1, armor = 0.004,
        },
        fury = {
            hit = 16, crit = 14, dps2h = 6.5, dpsMH = 4, dpsOH = 2.2,
            speedMH = 3, speedOH = -3, str = 1, agi = 0.7, ap = 0.5, sta = 0.35,
        },
        protection = {
            dodge = 12, parry = 10, hit = 6, block = 5, crit = 4,
            dpsMH = 2, dps2h = 1.5, def = 1.3, sta = 1, agi = 0.8,
            str = 0.45, blockValue = 0.4, hp5 = 0.3, ap = 0.25, armor = 0.008,
        },
    },
    PALADIN = {
        holy = {
            crit = 8, mp5 = 2.5, heal = 1, sp = 1, holyDmg = 0.8,
            int = 0.55, spi = 0.25, sta = 0.25, dpsMH = 0.1, dps2h = 0.1,
        },
        protection = {
            dodge = 12, parry = 10, block = 6, hit = 4, crit = 3,
            dpsMH = 1.5, def = 1.2, sta = 1, mp5 = 0.8, blockValue = 0.5,
            agi = 0.75, str = 0.4, sp = 0.25, holyDmg = 0.25, int = 0.3,
            ap = 0.2, armor = 0.008,
        },
        retribution = {
            hit = 14, crit = 12, dps2h = 6, speed2h = 10, dpsMH = 2,
            str = 1, ap = 0.5, agi = 0.6, sta = 0.3, sp = 0.25,
            holyDmg = 0.25, int = 0.1,
        },
    },
    HUNTER = {
        beastmastery = {
            hit = 14, crit = 12, dpsRanged = 7, speedRanged = 5, agi = 1.25,
            mp5 = 0.6, rap = 0.5, ap = 0.5, dps2h = 0.5, int = 0.3,
            sta = 0.3, dpsMH = 0.3, dpsOH = 0.2, spi = 0.1, str = 0.1,
        },
        marksmanship = {
            hit = 14, crit = 13, dpsRanged = 7.5, speedRanged = 6, agi = 1.25,
            mp5 = 0.6, rap = 0.5, ap = 0.5, dps2h = 0.5, int = 0.3,
            dpsMH = 0.3, sta = 0.25, dpsOH = 0.2, spi = 0.1, str = 0.1,
        },
        survival = {
            hit = 14, crit = 12, dpsRanged = 7, speedRanged = 4, agi = 1.25,
            mp5 = 0.6, dps2h = 0.6, rap = 0.5, ap = 0.5, dpsMH = 0.35,
            int = 0.3, sta = 0.3, dpsOH = 0.2, str = 0.15, spi = 0.1,
        },
    },
    ROGUE = {
        assassination = {
            hit = 16, crit = 14, dpsMH = 4.5, dpsOH = 2, speedMH = 5, speedOH = -4,
            agi = 1, str = 0.6, ap = 0.5, sta = 0.3, dpsRanged = 0.2,
        },
        combat = {
            hit = 16, crit = 12, dpsMH = 4, dpsOH = 2.5, speedMH = 4, speedOH = -3,
            agi = 1, str = 0.6, ap = 0.5, sta = 0.3, dpsRanged = 0.2,
        },
        subtlety = {
            hit = 15, crit = 14, dpsMH = 4, dpsOH = 2, speedMH = 5, speedOH = -2,
            agi = 1.05, str = 0.55, ap = 0.5, sta = 0.3, dpsRanged = 0.2,
        },
    },
    PRIEST = {
        discipline = {
            crit = 6, mp5 = 2.8, dpsRanged = 1.5, heal = 1, sp = 1,
            holyDmg = 0.4, int = 0.6, spi = 0.55, sta = 0.25,
        },
        holy = {
            crit = 7, mp5 = 3, dpsRanged = 1.5, heal = 1, sp = 1,
            holyDmg = 0.35, int = 0.5, spi = 0.65, sta = 0.2,
        },
        shadow = {
            hit = 12, crit = 8, dpsRanged = 2.5, sp = 1, shadow = 1,
            mp5 = 1, int = 0.35, spi = 0.35, sta = 0.3,
        },
    },
    SHAMAN = {
        elemental = {
            mp5 = 1.5, sp = 1, nature = 0.9, fire = 0.5, int = 0.45,
            sta = 0.25, spi = 0.1, hit = 12, crit = 10, armor = 0.002, dpsMH = 0.4,
        },
        enhancement = {
            str = 1, agi = 0.8, ap = 0.5, hit = 14, crit = 14, int = 0.25,
            sp = 0.2, nature = 0.15, sta = 0.35, dps2h = 6.5, dpsMH = 4,
            speed2h = 10, armor = 0.003,
        },
        restoration = {
            heal = 1, sp = 1, mp5 = 3, int = 0.5, spi = 0.3,
            crit = 5, sta = 0.25, nature = 0.15,
        },
    },
    MAGE = {
        arcane = {
            hit = 12, crit = 9, dpsRanged = 2, mp5 = 1.5, sp = 1,
            arcane = 0.9, frost = 0.5, int = 0.85, mana = 0.03,
            sta = 0.2, spi = 0.1,
        },
        fire = {
            hit = 13, crit = 11, dpsRanged = 2, sp = 1, fire = 0.95,
            mp5 = 0.8, int = 0.35, sta = 0.2, spi = 0.1,
        },
        frost = {
            hit = 12, crit = 10, dpsRanged = 2, sp = 1, frost = 0.95,
            mp5 = 0.8, int = 0.35, sta = 0.25, spi = 0.1,
        },
    },
    WARLOCK = {
        affliction = {
            sp = 1, shadow = 0.95, hit = 13, crit = 6, mp5 = 1.3,
            int = 0.4, spi = 0.25, sta = 0.35, dpsRanged = 1.5,
        },
        demonology = {
            sp = 1, shadow = 0.8, fire = 0.35, hit = 12, crit = 8,
            mp5 = 1, int = 0.4, sta = 0.5, spi = 0.15, dpsRanged = 1.2,
        },
        destruction = {
            sp = 1, fire = 0.9, shadow = 0.65, hit = 13, crit = 11,
            mp5 = 0.8, int = 0.35, sta = 0.2, spi = 0.1, dpsRanged = 2,
        },
    },
    DRUID = {
        balance = {
            hit = 12, crit = 9, mp5 = 1.5, sp = 1, arcane = 0.7,
            nature = 0.7, int = 0.4, spi = 0.25, sta = 0.25,
        },
        feral = {
            hit = 14, crit = 12, agi = 1, str = 1, ap = 0.5, fap = 0.5,
            sta = 0.3, int = 0.1, dps2h = 5, dpsMH = 5,
        },
        feraltank = {
            dodge = 12, hit = 5, crit = 4, sta = 1.1, def = 1, agi = 1.15,
            str = 0.55, ap = 0.35, fap = 0.35, int = 0.05, armor = 0.012,
            dps2h = 1.2, dpsMH = 1.2,
        },
        restoration = {
            crit = 4, mp5 = 3, heal = 1, sp = 1, spi = 0.6, int = 0.5, sta = 0.2,
        },
    },
}

ns.STAT_GROUPS = {
    {
        title = "Attributes",
        stats = {
            { key = "str", label = "Strength", short = "Str" },
            { key = "agi", label = "Agility", short = "Agi" },
            { key = "sta", label = "Stamina", short = "Sta" },
            { key = "int", label = "Intellect", short = "Int" },
            { key = "spi", label = "Spirit", short = "Spi" },
            { key = "health", label = "Health (else Stamina / 10)", short = "Health" },
            { key = "mana", label = "Mana (else Intellect / 15)", short = "Mana" },
        },
    },
    {
        title = "Offense",
        stats = {
            { key = "ap", label = "Attack power", short = "AP" },
            { key = "rap", label = "Ranged attack power (else AP)", short = "RAP" },
            { key = "fap", label = "Feral attack power (else AP)", short = "FAP" },
            { key = "sp", label = "Spell power", short = "SP" },
            { key = "heal", label = "Healing", short = "Heal" },
            { key = "fire", label = "Fire damage", short = "Fire" },
            { key = "frost", label = "Frost damage", short = "Frost" },
            { key = "arcane", label = "Arcane damage", short = "Arcane" },
            { key = "nature", label = "Nature damage", short = "Nature" },
            { key = "shadow", label = "Shadow damage", short = "Shadow" },
            { key = "holyDmg", label = "Holy damage", short = "Holy" },
            { key = "hit", label = "Hit per 1%", short = "Hit" },
            { key = "expertise", label = "Expertise per 1% (else hit)", short = "Expertise" },
            { key = "crit", label = "Critical strike per 1%", short = "Crit" },
            { key = "spellHit", label = "Spell hit per 1% (else hit)", short = "Spell hit" },
            { key = "spellCrit", label = "Spell crit per 1% (else crit)", short = "Spell crit" },
            { key = "haste", label = "Haste per 1%", short = "Haste" },
            { key = "mp5", label = "Mana per 5 sec", short = "Mp5" },
            { key = "hp5", label = "Health per 5 sec", short = "Hp5" },
        },
    },
    {
        title = "Defense",
        stats = {
            { key = "armor", label = "Armor", short = "Armor" },
            { key = "def", label = "Defense", short = "Def" },
            { key = "dodge", label = "Dodge per 1%", short = "Dodge" },
            { key = "parry", label = "Parry per 1%", short = "Parry" },
            { key = "block", label = "Block chance per 1%", short = "Block" },
            { key = "blockValue", label = "Block value", short = "Block value" },
        },
    },
    {
        title = "Weapon",
        stats = {
            { key = "dps2h", label = "Two-hand DPS", short = "2H DPS" },
            { key = "dpsMH", label = "Main-hand DPS", short = "MH DPS" },
            { key = "dpsOH", label = "Off-hand DPS", short = "OH DPS" },
            { key = "dpsRanged", label = "Ranged DPS", short = "Ranged DPS" },
            { key = "speed2h", label = "Two-hand speed above 2.0", short = "2H speed" },
            { key = "speedMH", label = "Main-hand speed above 2.0", short = "MH speed" },
            { key = "speedOH", label = "Off-hand speed above 2.0", short = "OH speed" },
            { key = "speedRanged", label = "Ranged speed above 2.0", short = "Ranged speed" },
        },
    },
    {
        title = "Resistance",
        stats = {
            { key = "resFire", label = "Fire resistance", short = "Fire res" },
            { key = "resFrost", label = "Frost resistance", short = "Frost res" },
            { key = "resNature", label = "Nature resistance", short = "Nature res" },
            { key = "resShadow", label = "Shadow resistance", short = "Shadow res" },
            { key = "resArcane", label = "Arcane resistance", short = "Arcane res" },
        },
    },
}

ns.STAT_LABEL = {}
ns.STAT_INDEX = {}
for g = 1, #ns.STAT_GROUPS do
    local group = ns.STAT_GROUPS[g]
    for r = 1, #group.stats do
        local stat = group.stats[r]
        ns.STAT_LABEL[stat.key] = stat.short
        ns.STAT_INDEX[stat.key:lower()] = stat.key
    end
end

ns.STAT_ALIAS = {
    strength = "str",
    agility = "agi",
    stamina = "sta",
    intellect = "int",
    spirit = "spi",
    health = "health",
    mana = "mana",
    attackpower = "ap",
    ap = "ap",
    rap = "rap",
    fap = "fap",
    spellpower = "sp",
    sp = "sp",
    healing = "heal",
    heal = "heal",
    hit = "hit",
    crit = "crit",
    expertise = "expertise",
    spellhit = "spellHit",
    spellcrit = "spellCrit",
    haste = "haste",
    mp5 = "mp5",
    hp5 = "hp5",
    armor = "armor",
    defence = "def",
    defense = "def",
    dodge = "dodge",
    parry = "parry",
    block = "block",
    blockvalue = "blockValue",
    dps2h = "dps2h",
    dpsmh = "dpsMH",
    dpsoh = "dpsOH",
    dpsranged = "dpsRanged",
    speed2h = "speed2h",
    speedmh = "speedMH",
    speedoh = "speedOH",
    speedranged = "speedRanged",
    fire = "fire",
    frost = "frost",
    arcane = "arcane",
    nature = "nature",
    shadow = "shadow",
    holydmg = "holyDmg",
    holy = "holyDmg",
    resfire = "resFire",
    resfrost = "resFrost",
    resnature = "resNature",
    resshadow = "resShadow",
    resarcane = "resArcane",
}

function ns.CanonStat(name)
    if type(name) ~= "string" then
        return nil
    end
    local lower = name:lower()
    if ns.STAT_ALIAS[lower] then
        return ns.STAT_ALIAS[lower]
    end
    return ns.STAT_INDEX[lower]
end

function ns.DefaultWeights(class, spec)
    local byClass = class and ns.WEIGHTS[class]
    if not byClass then
        return {}
    end
    if spec and byClass[spec] then
        return byClass[spec]
    end
    local leveling = ns.LEVELING[class]
    if leveling and byClass[leveling] then
        return byClass[leveling]
    end
    return {}
end

function ns.ResolveWeight(weights, key)
    if not weights then
        return nil
    end
    if weights[key] ~= nil then
        return weights[key]
    end
    if key == "rap" or key == "fap" then
        return weights.ap
    end
    if key == "spellHit" then
        return weights.hit
    end
    if key == "spellCrit" then
        return weights.crit
    end
    if key == "expertise" then
        local physical = (type(weights.str) == "number" and weights.str >= 0.4)
            or (type(weights.agi) == "number" and weights.agi >= 0.5)
        if physical then
            return weights.hit
        end
        return 0
    end
    if key == "health" and weights.sta then
        return weights.sta / 10
    end
    if key == "mana" and weights.int then
        return weights.int / 15
    end
    -- Every spec wants some armor. Tanks set their own, higher, value.
    -- 0.005 keeps a cloth-to-leather jump visible without beating a real stat.
    if key == "armor" then
        return 0.005
    end
    return nil
end

function ns.UsingCustom(class, spec)
    local char = ns.char
    if not char or not class or not spec then
        return false
    end
    local byClass = char.customOn and char.customOn[class]
    return byClass and byClass[spec] and true or false
end

-- Forever-only talent prices. Classic Era keeps the older values.
local ERA_PATCH = {
    MAGE = { arcane = { int = 0.35, mana = false } },
    PALADIN = {
        retribution = { int = 0.05 },
        protection = { sp = 0.35, holyDmg = 0.35 },
    },
}

function ns.MergedWeights(class, spec)
    class = class or ns.ClassFile()
    spec = spec or (ns.GetSpec and ns.GetSpec())
    local merged = ns.Copy(ns.DefaultWeights(class, spec))
    if ns.ClientKind and ns.ClientKind() == "era" then
        local patch = ERA_PATCH[class] and spec and ERA_PATCH[class][spec]
        if patch then
            for key, value in pairs(patch) do
                if value == false then
                    merged[key] = nil
                else
                    merged[key] = value
                end
            end
        end
    end
    if class and spec and ns.UsingCustom(class, spec) then
        local custom = ns.char.custom[class] and ns.char.custom[class][spec]
        if custom then
            for key, value in pairs(custom) do
                if type(value) == "number" then
                    merged[key] = value
                end
            end
        end
    end
    return merged
end

function ns.EnsureCustom()
    local class = ns.ClassFile()
    local spec = ns.GetSpec and ns.GetSpec()
    if not class or not spec or not ns.char then
        return
    end
    ns.char.custom[class] = ns.char.custom[class] or {}
    ns.char.customOn[class] = ns.char.customOn[class] or {}
    if not ns.char.custom[class][spec] then
        ns.char.custom[class][spec] = ns.Copy(ns.DefaultWeights(class, spec))
    end
    ns.char.customOn[class][spec] = true
end

function ns.SetWeight(key, value, quiet)
    ns.EnsureCustom()
    local class = ns.ClassFile()
    local spec = ns.GetSpec()
    if not class or not spec then
        return
    end
    ns.char.custom[class][spec][key] = value
    if quiet then
        return
    end
    if ns.InvalidateSpec then
        ns.InvalidateSpec()
    end
    ns.Changed()
end

function ns.SetCustomEnabled(enabled)
    local class = ns.ClassFile()
    local spec = ns.GetSpec and ns.GetSpec()
    if not class or not spec or not ns.char then
        return
    end
    if enabled then
        ns.EnsureCustom()
    else
        ns.char.customOn[class] = ns.char.customOn[class] or {}
        ns.char.customOn[class][spec] = false
    end
    ns.InvalidateSpec()
    ns.Changed()
end

function ns.ResetCustom()
    local class = ns.ClassFile()
    local spec = ns.GetSpec and ns.GetSpec()
    if not class or not spec or not ns.char then
        return
    end
    if ns.char.custom[class] then
        ns.char.custom[class][spec] = nil
    end
    if ns.char.customOn[class] then
        ns.char.customOn[class][spec] = nil
    end
    ns.InvalidateSpec()
    ns.Changed()
end

function ns.ExportWeights()
    local weights = ns.MergedWeights()
    local bits = {}
    for g = 1, #ns.STAT_GROUPS do
        local group = ns.STAT_GROUPS[g]
        for r = 1, #group.stats do
            local stat = group.stats[r]
            local value = weights[stat.key]
            if type(value) ~= "number" then
                value = ns.ResolveWeight(weights, stat.key) or 0
            end
            if value ~= 0 then
                bits[#bits + 1] = stat.key .. "=" .. ns.FormatNum(value)
            end
        end
    end
    if #bits == 0 then
        return "No non-zero weights for this spec."
    end
    return table.concat(bits, ",")
end

function ns.ImportWeights(text)
    local count = 0
    local skipped = 0
    if type(text) ~= "string" or text == "" then
        return 0, 0
    end
    for key, numberText in text:gmatch("([%w]+)%s*=%s*([%+%-]?%d+%.?%d*)") do
        local canon = ns.CanonStat(key)
        local number = tonumber(numberText)
        if canon and number then
            ns.SetWeight(canon, number, true)
            count = count + 1
        else
            skipped = skipped + 1
        end
    end
    if count > 0 then
        if ns.InvalidateSpec then
            ns.InvalidateSpec()
        end
        ns.Changed()
    end
    return count, skipped
end

local PERCENT = {
    hit = true, crit = true, spellHit = true, spellCrit = true,
    dodge = true, parry = true, block = true, haste = true, expertise = true,
}

-- Forever launch client 1.60.1.70707 (rechecked 2 Nov 2026) rewrote Classic
-- Era percentages as points: 10 hit, 14 crit, 12 dodge, 15 parry, and 10
-- expertise for 1%. Blizzard's notes through 27 Oct did not change this, and
-- the character sheet formula is still unpublished. The ratio is the same
-- from low item levels through 78, so it is not the old rating curve.
-- Classic Era items are already percents.
local FOREVER_POINTS = {
    hit = 10, spellHit = 10,
    crit = 14, spellCrit = 14,
    dodge = 12, parry = 15, expertise = 10,
}

function ns.FromRating(key, amount)
    if type(amount) ~= "number" then
        return amount
    end
    if not ns.ClientKind or ns.ClientKind() ~= "forever" then
        return amount
    end
    local per = FOREVER_POINTS[key]
    if not per then
        return amount
    end
    return amount / per
end

function ns.Score(stats, weights, kind, weaponKey)
    local total = 0
    local parts = {}

    local function add(key, amount, text)
        if type(amount) ~= "number" or amount == 0 then
            return
        end
        local weight = ns.ResolveWeight(weights, key)
        if type(weight) ~= "number" or weight == 0 then
            return
        end
        local factor
        if ns.RacialFactor then
            factor = ns.RacialFactor(key)
            if type(factor) == "number" and factor ~= 1 then
                weight = weight * factor
                local pct = math.floor(factor * 100 + 0.5) - 100
                text = text .. " +" .. tostring(pct) .. "% racial"
            end
        end
        local contrib = amount * weight
        total = total + contrib
        if math.abs(contrib) >= 0.05 then
            local part = { text = text, contrib = contrib }
            if type(factor) == "number" and factor ~= 1 then
                part.racial = true
            end
            parts[#parts + 1] = part
        end
    end

    for key, amount in pairs(stats) do
        -- Weapon skill is priced later, against the weapon it actually helps.
        if key ~= "dps" and key ~= "speed" and type(amount) == "number" and not key:match("^skill_") then
            local label = ns.STAT_LABEL[key] or key
            local shown
            if PERCENT[key] then
                shown = ns.FormatNum(amount) .. "% " .. label
            else
                shown = ns.FormatNum(amount) .. " " .. label
            end
            add(key, amount, shown)
        end
    end

    local dps = stats.dps
    local speed = stats.speed
    if kind == "2h" then
        add("dps2h", dps, ns.FormatNum(dps or 0) .. " 2H DPS")
        if speed then
            add("speed2h", speed - 2, ns.FormatNum(speed) .. " speed")
        end
    elseif kind == "mh" then
        add("dpsMH", dps, ns.FormatNum(dps or 0) .. " MH DPS")
        if speed then
            add("speedMH", speed - 2, ns.FormatNum(speed) .. " speed")
        end
    elseif kind == "oh" then
        add("dpsOH", dps, ns.FormatNum(dps or 0) .. " OH DPS")
        if speed then
            add("speedOH", speed - 2, ns.FormatNum(speed) .. " speed")
        end
    elseif kind == "ranged" then
        add("dpsRanged", dps, ns.FormatNum(dps or 0) .. " ranged DPS")
        if speed then
            add("speedRanged", speed - 2, ns.FormatNum(speed) .. " speed")
        end
    end

    if ns.RacialWeaponBonus then
        local racial = ns.RacialWeaponBonus(weights, kind, weaponKey, dps)
        if racial and type(racial.contrib) == "number" and math.abs(racial.contrib) >= 0.05 then
            total = total + racial.contrib
            parts[#parts + 1] = { text = racial.text, contrib = racial.contrib, racial = true }
        end
    end
    if weaponKey and ns.WeaponSkillValue then
        local amount = stats["skill_" .. weaponKey]
        if type(amount) == "number" and amount > 0 then
            local contrib = ns.WeaponSkillValue(weights, kind, dps, amount)
            if type(contrib) == "number" and math.abs(contrib) >= 0.05 then
                total = total + contrib
                local label = weaponKey:gsub("1h$", ""):gsub("2h$", "")
                parts[#parts + 1] = { text = "+" .. ns.FormatNum(amount) .. " " .. label .. " skill", contrib = contrib }
            end
        end
    end

    table.sort(parts, function(a, b)
        return math.abs(a.contrib) > math.abs(b.contrib)
    end)
    return total, parts
end
