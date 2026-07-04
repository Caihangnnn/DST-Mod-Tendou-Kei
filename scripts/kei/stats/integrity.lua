local Integrity = {}

-- 基础最大完整度（生命值）
function Integrity.GetBaseMax()
    return TUNING.KEI_MAX_INTEGRITY or 120
end

-- 槽位属性加成
local function GetSlotBonus(unlocked_slots, initial_slots)
    local extra_slots = math.max(0, (unlocked_slots or initial_slots or 1) - (initial_slots or TUNING.KEI_PROTOCOL_SLOT_INITIAL or 1))
    return extra_slots * (TUNING.KEI_PROTOCOL_STAT_BONUS_PER_SLOT or TUNING.KEI_PROTOCOL_STAT_BONUS or 10)
end

-- 计算最大完整度（生命值）
function Integrity.GetMaxForSlots(unlocked_slots, initial_slots)
    return Integrity.GetBaseMax() + GetSlotBonus(unlocked_slots, initial_slots)
end

-- 配置完整度（生命值）
function Integrity.Configure(inst)
    if inst.components.health ~= nil then
        inst.components.health:SetMaxHealth(Integrity.GetBaseMax())
    end
end

-- 修理工具修复（生命值）
function Integrity.ApplyRepair(inst)
    if inst.components.health ~= nil and not inst.components.health:IsDead() then
        inst.components.health:DoDelta(TUNING.KEI_REPAIR_VALUE or 30, nil, "kei_repair_tool")
    end
end

-- 更新完整度（生命值）
function Integrity.UpdateState(inst)
    if inst.components.health == nil or inst.components.locomotor == nil then
        return
    end

    local health = inst.components.health
    local current_integrity = health.currenthealth or health.maxhealth or 0
    local max_integrity = health.maxhealth or Integrity.GetBaseMax()

    local low_threshold = max_integrity / 6
    -- 低完整度时，速度减半、移动扣血、缓慢扣血
    if current_integrity <= low_threshold then
        inst.components.locomotor:SetExternalSpeedMultiplier(inst, "kei_low_integrity", 0.5)
        health:DoDelta(-1, true, "kei_low_integrity")
        if inst.components.talker ~= nil
            and (inst._kei_low_integrity_say_time == nil or GetTime() - inst._kei_low_integrity_say_time > 12)
        then
            inst.components.talker:Say(STRINGS.CHARACTERS.KEI.ANNOUNCE_LOW_INTEGRITY)
            inst._kei_low_integrity_say_time = GetTime()
        end
    else
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "kei_low_integrity")
    end

    -- 高完整度时，自我修复
    if current_integrity > max_integrity * 5 / 6 and current_integrity < max_integrity then
        health:DoDelta(1, true, "kei_self_repair")
    end
end

return Integrity