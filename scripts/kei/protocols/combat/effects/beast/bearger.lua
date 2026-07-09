-- 熊獾高级协议：攻击命中触发完整范围震击。
local BeargerCommon = require("kei/protocols/combat/effects/beast/_bearger_common")

local BeargerEffect = {}

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function BeargerEffect.OnHitOther(slots, inst, data)
    BeargerCommon.DoAreaDamage(slots, inst, data, TUNING.KEI_BEARGER_ADVANCED_AOE_MULTIPLIER or 1)
end

return BeargerEffect
