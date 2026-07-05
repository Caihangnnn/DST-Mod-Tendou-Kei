local BeargerCommon = require("kei/protocols/combat/effects/_bearger_common")

local BeargerEffect = {}

function BeargerEffect.OnHitOther(slots, inst, data)
    BeargerCommon.DoAreaDamage(slots, inst, data, TUNING.KEI_BEARGER_ADVANCED_AOE_MULTIPLIER or 1)
end

return BeargerEffect