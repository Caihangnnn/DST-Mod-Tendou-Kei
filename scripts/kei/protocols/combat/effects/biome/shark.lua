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

-- 参考沃特技能树：在护甲结算前，将部分受到的攻击伤害转为潮湿度消耗。
local function RedirectDamageToMoisture(inst, amount, attacker)
    if type(amount) ~= "number" or amount <= 0 or attacker == nil then
        return amount
    end

    local moisture = inst.components.moisture
    if moisture == nil then
        return amount
    end

    local current = moisture:GetMoisture()
    if current <= 0 then
        return amount
    end

    local rate = math.max(TUNING.KEI_SHARK_MOISTURE_DAMAGE_RATE or 2, 0.1)
    local absorbed_damage = math.min(amount, current / rate)
    if absorbed_damage <= 0 then
        return amount
    end

    moisture:DoDelta(-absorbed_damage * rate, true)

    local max_moisture = moisture.GetMaxMoisture ~= nil and moisture:GetMaxMoisture() or TUNING.MAX_WETNESS or current
    SpawnSplashFx(inst, absorbed_damage, max_moisture / rate)

    return amount - absorbed_damage
end

-- 启用潮湿装甲，并保留进入协议前已有的生命变化修正函数。
function SharkEffect.Enable(slots, inst)
    if slots == nil or inst == nil or inst.components.health == nil then
        return
    end
    if slots._kei_shark_pre_armor_damagefn ~= nil then
        return
    end

    EnsureMoisture(inst)

    slots._kei_shark_old_pre_armor_damagefn = slots._kei_pre_armor_damagefn
    slots._kei_shark_pre_armor_damagefn = function(attacker, amount, weapon, stimuli, spdamage)
        if slots._kei_shark_old_pre_armor_damagefn ~= nil then
            amount = slots._kei_shark_old_pre_armor_damagefn(attacker, amount, weapon, stimuli, spdamage)
        end
        return RedirectDamageToMoisture(inst, amount, attacker)
    end
    slots._kei_pre_armor_damagefn = slots._kei_shark_pre_armor_damagefn
end

-- 协议移除时，只在当前函数仍属于本协议时恢复旧函数。
function SharkEffect.Disable(slots, inst)
    if slots == nil or inst == nil or inst.components.health == nil then
        return
    end

    if slots._kei_pre_armor_damagefn == slots._kei_shark_pre_armor_damagefn then
        slots._kei_pre_armor_damagefn = slots._kei_shark_old_pre_armor_damagefn
    end
    slots._kei_shark_pre_armor_damagefn = nil
    slots._kei_shark_old_pre_armor_damagefn = nil
end

return SharkEffect
