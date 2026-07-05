-- 克眼协议功能实现

local EyeOfTerrorCommon = {}

function EyeOfTerrorCommon.HasBasic(slots)
    return slots.active_combat ~= nil and slots.active_combat.eyeofterror_basic == true
end

function EyeOfTerrorCommon.HasAdvanced(slots)
    return slots.active_combat ~= nil and slots.active_combat.eyeofterror == true
end

function EyeOfTerrorCommon.HasDash(slots)
    return EyeOfTerrorCommon.HasAdvanced(slots) or EyeOfTerrorCommon.HasBasic(slots)
end

return EyeOfTerrorCommon