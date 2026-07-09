-- 蜂后初级协议：受击触发基础恐慌效果。
local BeequeenCommon = require("kei/protocols/combat/effects/beast/_beequeen_common")

local BASIC_COOLDOWN_KEY = "_kei_beequeen_basic_panic_ready_time"

local BeequeenBasicEffect = {}

-- 处理受击事件，根据协议等级触发附加防御效果。
function BeequeenBasicEffect.OnAttacked(slots, inst, data)
    if BeequeenCommon.HasAdvanced(slots) then
        return
    end

    local attacker = data ~= nil and data.attacker or nil
    if not BeequeenCommon.IsValidScareTarget(inst, attacker) then
        return
    end
    if not BeequeenCommon.CooldownReady(slots, BASIC_COOLDOWN_KEY) then
        return
    end

    BeequeenCommon.StartCooldown(slots, TUNING.KEI_BEEQUEEN_BASIC_PANIC_COOLDOWN or 0.5, BASIC_COOLDOWN_KEY)
    BeequeenCommon.ScareTarget(inst, attacker, TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5)
end

return BeequeenBasicEffect
