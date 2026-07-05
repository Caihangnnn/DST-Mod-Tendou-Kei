local BeargerCommon = require("kei/protocols/combat/effects/_bearger_common")

local BeargerBasicEffect = {}

function BeargerBasicEffect.OnHitOther(slots, inst, data)
    if BeargerCommon.HasAdvanced(slots) then
        return
    end
    BeargerCommon.DoAreaDamage(slots, inst, data, TUNING.KEI_BEARGER_BASIC_AOE_MULTIPLIER or 0.35)
end

return BeargerBasicEffect