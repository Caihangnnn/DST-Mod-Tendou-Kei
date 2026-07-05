-- 果蝇王协议功能实现

local LordfruitflyCommon = {}

function LordfruitflyCommon.HasBasic(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.lordfruitfly_basic == true
end

function LordfruitflyCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.lordfruitfly == true
end

return LordfruitflyCommon