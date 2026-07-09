-- 水獭掠夺者协议（otter）：潮湿度越高，攻击倍率越高。

local OtterEffect = {}

local DAMAGE_MODIFIER = "kei_otter_moisture_damage"

local function GetMoisture(inst)
    return inst.components.moisture ~= nil and inst.components.moisture:GetMoisture() or 0
end

local function RemoveDamageMultiplier(inst)
    if inst.components.combat ~= nil then
        inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, DAMAGE_MODIFIER)
    end
end

-- 按当前潮湿度刷新攻击倍率：潮湿度 20 提供 20% 增伤，最终倍率为 1.2。
local function RefreshDamageMultiplier(slots, inst)
    if inst.components.combat == nil then
        return
    end

    local moisture = GetMoisture(inst)
    if moisture > 0 then
        inst.components.combat.externaldamagemultipliers:SetModifier(
            inst,
            1 + moisture / 100,
            DAMAGE_MODIFIER
        )
    else
        RemoveDamageMultiplier(inst)
    end
end

-- 启用潮湿增伤，并监听潮湿度变化即时刷新。
function OtterEffect.Enable(slots, inst)
    if slots == nil or inst == nil then
        return
    end

    RefreshDamageMultiplier(slots, inst)

    if slots._kei_otter_moisture_delta_fn == nil then
        slots._kei_otter_moisture_delta_fn = function()
            RefreshDamageMultiplier(slots, inst)
        end
        inst:ListenForEvent("moisturedelta", slots._kei_otter_moisture_delta_fn)
    end
end

-- 移除协议时恢复攻击倍率。
function OtterEffect.Disable(slots, inst)
    if slots == nil or inst == nil then
        return
    end

    if slots._kei_otter_moisture_delta_fn ~= nil then
        inst:RemoveEventCallback("moisturedelta", slots._kei_otter_moisture_delta_fn)
        slots._kei_otter_moisture_delta_fn = nil
    end
    RemoveDamageMultiplier(inst)
end

return OtterEffect