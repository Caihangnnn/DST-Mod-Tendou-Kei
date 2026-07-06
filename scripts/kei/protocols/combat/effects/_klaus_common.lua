-- 克劳斯协议公共实现：攻击抽魂治疗，并为高级协议追加伤害。

local WortoxSoulCommon = require("prefabs/wortox_soul_common")

local KlausCommon = {}

local function IsValidSoulTarget(target)
    return target ~= nil
        and target:IsValid()
        and target.entity:IsVisible()
        and target.components.health ~= nil
        and not target.components.health:IsDead()
        and WortoxSoulCommon.HasSoul(target)
end

local function SpawnHealingSoul(target)
    local soul = SpawnPrefab("wortox_soul")
    if soul == nil then
        return false
    end

    local x, y, z = target.Transform:GetWorldPosition()
    soul.Transform:SetPosition(x, y, z)
    soul.persists = false
    soul.soulhealfinishing = true

    if soul._task ~= nil then
        soul._task:Cancel()
        soul._task = nil
    end
    if soul.components.inventoryitem ~= nil then
        soul.components.inventoryitem.canbepickedup = false
    end

    WortoxSoulCommon.DoHeal(soul)
    if soul.AnimState ~= nil then
        soul.AnimState:PlayAnimation("idle_pst")
    end
    if soul.SoundEmitter ~= nil then
        soul.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    end
    soul:ListenForEvent("animover", soul.Remove)
    return true
end

local function GetTargetMaxHealth(target)
    return target ~= nil
        and target.components.health ~= nil
        and target.components.health.maxhealth
        or 0
end

local function DoAdvancedDamage(slots, inst, target)
    if slots._kei_klaus_doing_extra_damage then
        return
    end

    local health = target.components.health
    local max_health = GetTargetMaxHealth(target)
    if health == nil or max_health <= 0 then
        return
    end

    slots._kei_klaus_doing_extra_damage = true
    if health:GetPercent() < (TUNING.KEI_KLAUS_ADVANCED_EXECUTE_HEALTH_PERCENT or 0.05) then
        health:DoDelta(-max_health, nil, "kei_klaus_execute", nil, inst, true)
    else
        local damage = max_health * (TUNING.KEI_KLAUS_ADVANCED_MAX_HEALTH_DAMAGE_PERCENT or 0.01)
        if damage > 0 then
            health:DoDelta(-damage, nil, "kei_klaus_soul", nil, inst, true)
        end
    end
    slots._kei_klaus_doing_extra_damage = nil
end

function KlausCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.klaus == true
end

function KlausCommon.IsAdvancedDamage(slots)
    return slots ~= nil and slots._kei_klaus_doing_extra_damage == true
end

function KlausCommon.CooldownReady(slots)
    if slots == nil then
        return false
    end
    return slots._kei_klaus_soul_ready_time == nil or GetTime() >= slots._kei_klaus_soul_ready_time
end

function KlausCommon.StartCooldown(slots)
    if slots ~= nil then
        slots._kei_klaus_soul_ready_time = GetTime() + (TUNING.KEI_KLAUS_ADVANCED_SOUL_COOLDOWN or 0.5)
    end
end

function KlausCommon.TryExtractSoul(slots, inst, data, advanced)
    if KlausCommon.IsAdvancedDamage(slots) then
        return false
    end

    local target = data ~= nil and data.target or nil
    if advanced and not KlausCommon.CooldownReady(slots) then
        return false
    end
    if math.random() >= (TUNING.KEI_KLAUS_SOUL_CHANCE or 0.20)
        or not IsValidSoulTarget(target)
    then
        return false
    end

    if advanced then
        KlausCommon.StartCooldown(slots)
    end

    SpawnHealingSoul(target)

    if advanced and target:IsValid() and target.components.health ~= nil and not target.components.health:IsDead() then
        DoAdvancedDamage(slots, inst, target)
    end
    return true
end

return KlausCommon
