-- 协议槽数量与三维成长的统一计算入口。

local PowerStat = require("kei/stats/power")
local StabilityStat = require("kei/stats/stability")
local IntegrityStat = require("kei/stats/integrity")

local ProtocolSlotUnlocks = {}

function ProtocolSlotUnlocks.GetMaxSlots()
    return TUNING.KEI_PROTOCOL_SLOT_MAX or 7
end

function ProtocolSlotUnlocks.GetHardMaxSlots()
    return TUNING.KEI_PROTOCOL_SLOT_HARD_MAX or 7
end

function ProtocolSlotUnlocks.GetBaseInitialSlots()
    return TUNING.KEI_PROTOCOL_SLOT_BASE_INITIAL or 1
end

function ProtocolSlotUnlocks.GetInitialSlots()
    return TUNING.KEI_PROTOCOL_SLOT_INITIAL or ProtocolSlotUnlocks.GetBaseInitialSlots()
end

function ProtocolSlotUnlocks.GetStatBonus(unlocked_slots)
    local extra_slots = math.max(0, unlocked_slots - ProtocolSlotUnlocks.GetBaseInitialSlots())
    return extra_slots * (TUNING.KEI_PROTOCOL_STAT_BONUS_PER_SLOT or TUNING.KEI_PROTOCOL_STAT_BONUS or 10)
end

function ProtocolSlotUnlocks.GetStatMaximums(unlocked_slots)
    local base_initial_slots = ProtocolSlotUnlocks.GetBaseInitialSlots()
    return {
        integrity = IntegrityStat.GetMaxForSlots(unlocked_slots, base_initial_slots),
        power = PowerStat.GetMaxForSlots(unlocked_slots, base_initial_slots),
        stability = StabilityStat.GetMaxForSlots(unlocked_slots, base_initial_slots),
    }
end

function ProtocolSlotUnlocks.ClampUnlockedSlots(unlocked_slots)
    return math.clamp(
        math.floor(tonumber(unlocked_slots) or ProtocolSlotUnlocks.GetInitialSlots()),
        ProtocolSlotUnlocks.GetInitialSlots(),
        ProtocolSlotUnlocks.GetMaxSlots()
    )
end

function ProtocolSlotUnlocks.GetUnlockedSlots(builder)
    if builder == nil then
        return 0
    elseif builder.components ~= nil and builder.components.kei_protocolslots ~= nil then
        return builder.components.kei_protocolslots.unlocked_slots or ProtocolSlotUnlocks.GetInitialSlots()
    elseif builder._kei_unlocked_protocol_slots ~= nil then
        return builder._kei_unlocked_protocol_slots:value()
    end
    return ProtocolSlotUnlocks.GetInitialSlots()
end

return ProtocolSlotUnlocks
