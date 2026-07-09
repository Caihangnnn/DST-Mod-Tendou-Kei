-- 岩石大白鲨协议（shark）：受伤时优先用潮湿度抵扣最终伤害。

local SharkEffect = {}

local NUM_SPLASH_FX = 3

local function Clamp(value, min_value, max_value)
    return math.min(math.max(value, min_value), max_value)
end

local function EnsureMoisture(inst)
    if inst.components.moisture == nil and inst.AddComponent ~= nil then
        inst:AddComponent("moisture")
    end
    return inst.components.moisture
end

local function RunOldDeltaModifier(slots, inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    local old = slots._kei_shark_old_deltamodifierfn
    if old ~= nil then
        return old(inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end
    return amount
end

local function SpawnSplashFx(inst, absorbed_damage, max_absorbed_damage)
    if absorbed_damage <= 0 or max_absorbed_damage <= 0 then
        return
    end

    local fx_size = math.ceil(Lerp(0, NUM_SPLASH_FX, absorbed_damage / max_absorbed_damage))
    fx_size = Clamp(fx_size, 1, NUM_SPLASH_FX)

    local fx = SpawnPrefab("wurt_water_splash_" .. tostring(fx_size))
    if fx ~= nil then
        inst:AddChild(fx)
    end
end

-- 参考沃特技能树：护甲/减伤结算后，真正扣血前，将负伤害转为潮湿度消耗。
local function RedirectDamageToMoisture(slots, inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    if ignore_absorb or amount >= 0 or overtime or afflicter == nil then
        return RunOldDeltaModifier(slots, inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end

    local moisture = inst.components.moisture
    if moisture == nil then
        return RunOldDeltaModifier(slots, inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end

    local current = moisture:GetMoisture()
    if current <= 0 then
        return RunOldDeltaModifier(slots, inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end

    local rate = math.max(TUNING.KEI_SHARK_MOISTURE_DAMAGE_RATE or 2, 0.1)
    local absorbed_damage = math.min(-amount, current / rate)
    if absorbed_damage <= 0 then
        return RunOldDeltaModifier(slots, inst, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end

    moisture:DoDelta(-absorbed_damage * rate, true)

    local max_moisture = moisture.GetMaxMoisture ~= nil and moisture:GetMaxMoisture() or TUNING.MAX_WETNESS or current
    SpawnSplashFx(inst, absorbed_damage, max_moisture / rate)

    return RunOldDeltaModifier(slots, inst, amount + absorbed_damage, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
end

-- 启用潮湿装甲，并保留进入协议前已有的生命变化修正函数。
function SharkEffect.Enable(slots, inst)
    if slots == nil or inst == nil or inst.components.health == nil then
        return
    end
    if slots._kei_shark_deltamodifierfn ~= nil then
        return
    end

    EnsureMoisture(inst)

    slots._kei_shark_old_deltamodifierfn = inst.components.health.deltamodifierfn
    slots._kei_shark_deltamodifierfn = function(owner, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        return RedirectDamageToMoisture(slots, owner, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
    end
    inst.components.health.deltamodifierfn = slots._kei_shark_deltamodifierfn
end

-- 协议移除时，只在当前函数仍属于本协议时恢复旧函数。
function SharkEffect.Disable(slots, inst)
    if slots == nil or inst == nil or inst.components.health == nil then
        return
    end

    if inst.components.health.deltamodifierfn == slots._kei_shark_deltamodifierfn then
        inst.components.health.deltamodifierfn = slots._kei_shark_old_deltamodifierfn
    end
    slots._kei_shark_deltamodifierfn = nil
    slots._kei_shark_old_deltamodifierfn = nil
end

return SharkEffect