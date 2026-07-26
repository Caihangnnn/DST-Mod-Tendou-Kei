-- 宠物基础属性：捕捉时生成属性快照，并在每次出战时应用到宠物实体。
local PetPersonality = require("kei/protocols/pet/personality")

local PetStats = {}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function NonNegative(value, fallback)
    return math.max(0, tonumber(value) or fallback or 0)
end

function PetStats.Copy(stats)
    local result = {}
    for key, value in pairs(stats or {}) do
        result[key] = value
    end
    return result
end

-- 攻击速度以攻击间隔（秒）记录；间隔越短，攻击越快。
function PetStats.Normalize(stats)
    stats = stats or {}
    local min_size = TUNING.KEI_PET_MIN_SIZE_SCALE or 0.2
    local max_size = TUNING.KEI_PET_MAX_SIZE_SCALE or 5
    local result = {
        max_health = NonNegative(stats.max_health),
        attack_damage = NonNegative(stats.attack_damage),
        experience_growth_rate = NonNegative(
            stats.experience_growth_rate,
            TUNING.KEI_PET_DEFAULT_EXPERIENCE_GROWTH_RATE or 1
        ),
        movement_speed = NonNegative(stats.movement_speed),
        walk_speed = NonNegative(stats.walk_speed),
        run_speed = NonNegative(stats.run_speed),
        defense = Clamp(stats.defense or 0, 0, 1),
        damage_reduction = Clamp(stats.damage_reduction or 0, 0, 1),
        size_scale = Clamp(stats.size_scale or 1, min_size, max_size),
    }

    if stats.attack_interval ~= nil then
        result.attack_interval = math.max(
            TUNING.KEI_PET_MIN_ATTACK_INTERVAL or 0.1,
            tonumber(stats.attack_interval) or 0
        )
    end
    return result
end

local function ApplyPersonality(stats, personality_id)
    local modifiers = PetPersonality.Get(personality_id).modifiers
    stats.max_health = stats.max_health * modifiers.max_health_multiplier
    stats.attack_damage = stats.attack_damage * modifiers.attack_damage_multiplier
    if stats.attack_interval ~= nil then
        stats.attack_interval = stats.attack_interval + modifiers.attack_interval_delta
    end
    stats.experience_growth_rate = stats.experience_growth_rate * modifiers.experience_growth_multiplier
    stats.movement_speed = stats.movement_speed * modifiers.movement_speed_multiplier
    stats.walk_speed = stats.walk_speed * modifiers.movement_speed_multiplier
    stats.run_speed = stats.run_speed * modifiers.movement_speed_multiplier
    stats.defense = stats.defense + modifiers.defense_delta
    stats.damage_reduction = stats.damage_reduction + modifiers.damage_reduction_delta
    stats.size_scale = stats.size_scale * modifiers.size_scale_multiplier
    return PetStats.Normalize(stats)
end

function PetStats.Capture(target, personality_id)
    local health = target ~= nil and target.components.health or nil
    local combat = target ~= nil and target.components.combat or nil
    local locomotor = target ~= nil and target.components.locomotor or nil
    local walk_speed = locomotor ~= nil and locomotor.walkspeed or 0
    local run_speed = locomotor ~= nil and locomotor.runspeed or 0
    local stats = {
        max_health = health ~= nil and health.maxhealth or 0,
        attack_damage = combat ~= nil and combat.defaultdamage or 0,
        attack_interval = combat ~= nil and combat.min_attack_period or nil,
        experience_growth_rate = TUNING.KEI_PET_DEFAULT_EXPERIENCE_GROWTH_RATE or 1,
        movement_speed = math.max(walk_speed or 0, run_speed or 0),
        walk_speed = walk_speed,
        run_speed = run_speed,
        defense = 0,
        damage_reduction = 0,
        size_scale = 1,
    }
    return ApplyPersonality(stats, PetPersonality.NormalizeId(personality_id))
end

-- 防御力使用生命组件的吸收率；免伤率使用独立的受伤倍率层。
function PetStats.ApplyToPet(pet, stats)
    stats = PetStats.Normalize(stats)
    local health = pet.components.health
    if health ~= nil then
        if stats.max_health > 0 then
            health:SetMaxHealth(stats.max_health)
        end
        health.externalabsorbmodifiers:SetModifier(pet, stats.defense, "kei_pet_defense")
    end

    local combat = pet.components.combat
    if combat ~= nil then
        combat:SetDefaultDamage(stats.attack_damage)
        if stats.attack_interval ~= nil then
            combat:SetAttackPeriod(stats.attack_interval)
        end
        combat.externaldamagetakenmultipliers:SetModifier(
            pet,
            1 - stats.damage_reduction,
            "kei_pet_damage_reduction"
        )
    end

    local locomotor = pet.components.locomotor
    if locomotor ~= nil then
        locomotor.walkspeed = stats.walk_speed
        locomotor.runspeed = stats.run_speed
    end

    if stats.size_scale ~= 1 then
        local sx, sy, sz = pet.Transform:GetScale()
        pet.Transform:SetScale(sx * stats.size_scale, sy * stats.size_scale, sz * stats.size_scale)
    end
end

return PetStats
