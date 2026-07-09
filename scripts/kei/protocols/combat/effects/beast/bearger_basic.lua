-- 熊獾初级协议：攻击命中触发弱化范围震击。
local BeargerCommon = require("kei/protocols/combat/effects/beast/_bearger_common")

local BeargerBasicEffect = {}

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function BeargerBasicEffect.OnHitOther(slots, inst, data)
    if BeargerCommon.HasAdvanced(slots) then
        return
    end
    BeargerCommon.DoAreaDamage(slots, inst, data, TUNING.KEI_BEARGER_BASIC_AOE_MULTIPLIER or 0.35)
end

return BeargerBasicEffect
