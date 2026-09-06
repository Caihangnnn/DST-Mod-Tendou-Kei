local Recovery = require("kei/stats/recovery")

local Power = {}

-- 基础电量最大值（饱食度）
function Power.GetBaseMax()
    return TUNING.KEI_MAX_POWER or 120
end

-- 槽位属性加成（饱食度）
local function GetSlotBonus(unlocked_slots, initial_slots)
    local extra_slots = math.max(0, (unlocked_slots or initial_slots or 1) - (initial_slots or TUNING.KEI_PROTOCOL_SLOT_INITIAL or 1))
    return extra_slots * (TUNING.KEI_PROTOCOL_STAT_BONUS_PER_SLOT or TUNING.KEI_PROTOCOL_STAT_BONUS or 10)
end

-- 计算最大电量（饱食度）
function Power.GetMaxForSlots(unlocked_slots, initial_slots)
    return Power.GetBaseMax() + GetSlotBonus(unlocked_slots, initial_slots)
end

-- 配置电量（饱食度）
function Power.Configure(inst)
    if inst.components.hunger ~= nil then
        inst.components.hunger:SetMax(Power.GetBaseMax())
    end
end

-- 计算便携电池应回复的电量，参数为目标的最大电量。
function Power.GetBatteryRestoreAmount(max_power)
    local percent = math.max(0, tonumber(TUNING.KEI_BATTERY_RESTORE_PERCENT) or 0.33)
    return math.max(0, tonumber(max_power) or Power.GetBaseMax()) * percent
end

-- 食用电池回复电量（饱食度）
function Power.ApplyBattery(inst)
    if inst.components.hunger ~= nil then
        Recovery.ApplyHungerDelta(
            inst,
            Power.GetBatteryRestoreAmount(inst.components.hunger.max)
        )
    end
end

function Power.UpdateNoPowerState(inst, has_power_override)
    if inst.components.health == nil or inst.components.hunger == nil or inst.components.locomotor == nil then
        return
    end

    if inst.components.hunger.current <= 0 and not has_power_override then
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kei_no_power", 0.1)
        if inst.sg ~= nil and inst.sg:HasStateTag("moving") then
            local damage = (TUNING.KEI_LOW_POWER_DAMAGE or 3) * (TUNING.KEI_SELF_REPAIR_PERIOD or 3)
            inst.components.health:DoDelta(-damage, true, "kei_no_power")
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kei_no_power")
    end
end

return Power
