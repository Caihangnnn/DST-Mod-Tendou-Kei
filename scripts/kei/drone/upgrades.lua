-- Shared definitions and calculations for the rotor surveyor upgrades.

local RotorUpgrades = {
    UPGRADE_ORDER = {
        "signal",
        "mobility",
        "battery",
        "power_reduction",
    },
    DEFINITIONS = {
        signal = {
            recipe = "kei_rotor_upgrade_signal",
            max_level = 3,
        },
        mobility = {
            recipe = "kei_rotor_upgrade_mobility",
            max_level = 5,
        },
        battery = {
            recipe = "kei_rotor_upgrade_battery",
            max_level = 10,
        },
        power_reduction = {
            recipe = "kei_rotor_upgrade_power_reduction",
            max_level = 1,
        },
    },
}

-- Snapshot Kei's own flight parameters after config.lua has loaded. Do not
-- read TUNING.SKILLS.WX78: other mods commonly change that table for WX-78.
local BASE_CONTROL_RANGE = tonumber(TUNING.KEI_ROTOR_SURVEYOR_RANGE) or 500
local MAX_CONTROL_RANGE = tonumber(TUNING.KEI_ROTOR_SIGNAL_RANGE_MAX) or 1500
local BASE_DRONE_SPEED = tonumber(TUNING.KEI_ROTOR_SURVEYOR_SPEED) or 3
local MOBILITY_SPEED_MULT = tonumber(TUNING.KEI_ROTOR_MOBILITY_SPEED_MULT_PER_LEVEL) or 1

local UPGRADE_BY_RECIPE = {}
for upgrade, definition in pairs(RotorUpgrades.DEFINITIONS) do
    UPGRADE_BY_RECIPE[definition.recipe] = upgrade
end

local function GetDefinition(upgrade)
    return RotorUpgrades.DEFINITIONS[upgrade]
end

function RotorUpgrades.GetUpgradeForRecipe(recname)
    return UPGRADE_BY_RECIPE[recname]
end

function RotorUpgrades.IsUpgradeRecipe(recname)
    return RotorUpgrades.GetUpgradeForRecipe(recname) ~= nil
end

function RotorUpgrades.GetLevel(inst, upgrade)
    local definition = GetDefinition(upgrade)
    if inst == nil or definition == nil then
        return 0
    end

    if inst.components ~= nil and inst.components["drone/upgrades"] ~= nil then
        return inst.components["drone/upgrades"]:GetLevel(upgrade)
    end

    local netvar = inst["_kei_rotor_upgrade_" .. upgrade]
    return netvar ~= nil and netvar:value() or 0
end

function RotorUpgrades.GetMaxLevel(upgrade)
    local definition = GetDefinition(upgrade)
    return definition ~= nil and definition.max_level or 0
end

function RotorUpgrades.GetControlRange(owner)
    local level = RotorUpgrades.GetLevel(owner, "signal")
    return math.min(BASE_CONTROL_RANGE * (1 + level), MAX_CONTROL_RANGE)
end

function RotorUpgrades.GetDroneSpeed(owner)
    local level = RotorUpgrades.GetLevel(owner, "mobility")
    return BASE_DRONE_SPEED * (1 + level * MOBILITY_SPEED_MULT)
end

function RotorUpgrades.GetControllerMaxPower(owner)
    local base = TUNING.KEI_ROTOR_CONTROLLER_MAX_POWER or 240
    local level = RotorUpgrades.GetLevel(owner, "battery")
    local per_level = TUNING.KEI_ROTOR_BATTERY_POWER_MULT_PER_LEVEL or 1
    return base * (1 + level * per_level)
end

function RotorUpgrades.GetControllerDrainReduction(owner)
    local level = RotorUpgrades.GetLevel(owner, "power_reduction")
    local per_level = TUNING.KEI_ROTOR_POWER_DRAIN_REDUCTION_PER_LEVEL or 1
    return level * per_level
end

return RotorUpgrades
