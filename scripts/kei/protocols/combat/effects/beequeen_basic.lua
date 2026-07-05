local BeequeenCommon = require("kei/protocols/combat/effects/_beequeen_common")

local BeequeenBasicEffect = {}

function BeequeenBasicEffect.OnAttacked(slots, inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if not BeequeenCommon.IsValidScareTarget(inst, attacker) then
        return
    end
    if not BeequeenCommon.CooldownReady(slots) then
        return
    end

    BeequeenCommon.StartCooldown(slots)
    BeequeenCommon.ScareTarget(inst, attacker, TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5)
end

return BeequeenBasicEffect