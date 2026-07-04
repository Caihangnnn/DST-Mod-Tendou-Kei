local Stability = {}

-- 基础最大稳定值（san值）
function Stability.GetBaseMax()
    return TUNING.KEI_MAX_STABILITY or 120
end

-- 槽位属性加成
local function GetSlotBonus(unlocked_slots, initial_slots)
    local extra_slots = math.max(0, (unlocked_slots or initial_slots or 1) - (initial_slots or TUNING.KEI_PROTOCOL_SLOT_INITIAL or 1))
    return extra_slots * (TUNING.KEI_PROTOCOL_STAT_BONUS_PER_SLOT or TUNING.KEI_PROTOCOL_STAT_BONUS or 10)
end

-- 计算最大稳定值（san值）
function Stability.GetMaxForSlots(unlocked_slots, initial_slots)
    return Stability.GetBaseMax() + GetSlotBonus(unlocked_slots, initial_slots)
end

-- 配置稳定值（san值）
function Stability.Configure(inst)
    local sanity = inst.components.sanity
    if sanity == nil then
        return
    end

    sanity:SetMax(Stability.GetBaseMax())
    -- 稳定值不受外界影响
    sanity.rate_modifier = 0
    sanity.no_moisture_penalty = true
    sanity:SetFullAuraImmunity(true)
    sanity:SetNegativeAuraImmunity(true)
    sanity:SetPlayerGhostImmunity(true)
    sanity:SetLightDrainImmune(true)
end

return Stability