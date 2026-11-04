local _, ns = ...

-- Passive racials that change an item comparison.
-- Flat crit, hit, and haste are the same on every piece, so they are left out.
-- On-use racials are left out too.
-- Forever removed weapon skill. Classic Era still has it.

local FACTOR = {
    era = {
        Human = { spi = 1.05 },
        Gnome = { int = 1.05 },
        Tauren = { sta = 1.05, health = 1.05 },
    },
    forever = {
        Human = { spi = 1.10 },
        Tauren = { sta = 1.05, health = 1.05 },
    },
}

-- +5 skill. Daggers, fist weapons, polearms, staves, and crossbows are not covered.
local WEAPON_SKILL = {
    Human = {
        sword1h = "sword", sword2h = "sword",
        mace1h = "mace", mace2h = "mace",
    },
    Orc = { axe1h = "axe", axe2h = "axe" },
    Dwarf = { gun = "gun" },
    Troll = { bow = "bow", thrown = "thrown" },
}

-- Hit on these rows is physical. Caster rows use the same key for spell hit.
local MELEE = {
    WARRIOR = { arms = true, fury = true, protection = true },
    PALADIN = { protection = true, retribution = true },
    ROGUE = { assassination = true, combat = true, subtlety = true },
    SHAMAN = { enhancement = true },
    DRUID = { feral = true, feraltank = true },
}

local HUNTER = {
    beastmastery = true, marksmanship = true, survival = true,
}

-- Against a mob 3 levels up, with weapon skill at the level cap:
-- miss falls from 8% to 6% and the extra 1% hit suppression drops, so the
-- hit cap falls by 3%. Melee dodge falls from 6.5% to 6%. Ranged is not dodged.
-- Glancing stays 40% of white swings, and those swings go from 65% damage to 85%.
-- Skill above the level cap does not add crit against a higher-level mob.
-- The connect percents are priced with the level-60 hit weight, then multiplied
-- by level/60. That weight is 1% of a level-60 character's damage, so a level-8
-- sword must not collect the full price. Glancing is already 8% of this weapon.
local MELEE_CONNECT = 3.5
local RANGED_HIT = 3
local GLANCE = 0.08

local function LevelScale()
    local level = ns.PlayerLevel and ns.PlayerLevel()
    if type(level) ~= "number" then
        return 1
    end
    if level >= 60 then
        return 1
    end
    if level < 1 then
        return 0
    end
    return level / 60
end

local function InterfaceVersion()
    if type(GetBuildInfo) ~= "function" then
        return nil
    end
    local interface = select(4, GetBuildInfo())
    if ns.Secret(interface) then
        return nil
    end
    return tonumber(interface)
end

function ns.ClientKind()
    local interface = InterfaceVersion()
    if interface and interface > 16000 and interface < 20000 then
        return "forever"
    end
    if type(WOW_PROJECT_ID) == "number"
        and type(WOW_PROJECT_CLASSIC) == "number"
        and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return "era"
    end
    return nil
end

function ns.RaceFile()
    if type(UnitRace) ~= "function" then
        return nil
    end
    local _, race = UnitRace("player")
    if type(race) ~= "string" or ns.Secret(race) then
        return nil
    end
    return race
end

function ns.RacialFactor(key)
    if type(key) ~= "string" then
        return nil
    end
    local kind = ns.ClientKind()
    local race = ns.RaceFile()
    local row = kind and race and FACTOR[kind] and FACTOR[kind][race]
    local factor = row and row[key]
    if type(factor) ~= "number" or factor == 1 then
        return nil
    end
    return factor
end

local function WeightOf(weights, key)
    local value = ns.ResolveWeight(weights, key)
    if type(value) ~= "number" then
        return 0
    end
    return value
end

-- Value of `amount` weapon skill against a mob 3 levels up. +5 is the
-- Classic Era racial. A +2 weapon is two fifths of that, which matches
-- Forever's smaller skill bonuses. Casters get nothing: their hit is spells.
function ns.WeaponSkillValue(weights, kind, dps, amount)
    if type(amount) ~= "number" or amount == 0 or type(kind) ~= "string" then
        return 0
    end
    local class = ns.ClassFile()
    local spec = ns.scoreSpec or (ns.GetSpec and ns.GetSpec())
    if not class or not spec then
        return 0
    end
    local weaponDps = type(dps) == "number" and dps or 0
    local scale = LevelScale()
    local perFive = 0
    if kind == "ranged" then
        if class ~= "HUNTER" or not HUNTER[spec] then
            return 0
        end
        perFive = RANGED_HIT * WeightOf(weights, "hit") * scale
    elseif kind == "mh" or kind == "2h" or kind == "oh" then
        local melee = MELEE[class]
        if not melee or not melee[spec] then
            return 0
        end
        local dpsKey = "dpsMH"
        if kind == "2h" then
            dpsKey = "dps2h"
        elseif kind == "oh" then
            dpsKey = "dpsOH"
        end
        local dpsWeight = WeightOf(weights, dpsKey)
        if kind == "oh" then
            perFive = weaponDps * dpsWeight * (MELEE_CONNECT / 100 + GLANCE)
        else
            perFive = MELEE_CONNECT * WeightOf(weights, "hit") * scale
            if class ~= "DRUID" then
                perFive = perFive + weaponDps * dpsWeight * GLANCE
            end
        end
    else
        return 0
    end
    return perFive * (amount / 5)
end

function ns.RacialWeaponBonus(weights, kind, weaponKey, dps)
    if ns.ClientKind() ~= "era" then
        return nil
    end
    if type(kind) ~= "string" or type(weaponKey) ~= "string" then
        return nil
    end
    local names = WEAPON_SKILL[ns.RaceFile() or ""]
    local skillName = names and names[weaponKey]
    if not skillName then
        return nil
    end
    local contrib = ns.WeaponSkillValue(weights, kind, dps, 5)
    if contrib == 0 then
        return nil
    end
    return { contrib = contrib, text = "+5 " .. skillName .. " skill" }
end
