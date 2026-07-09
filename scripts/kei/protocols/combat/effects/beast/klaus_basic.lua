-- 克劳斯初级协议：攻击命中时概率抽取灵魂并治疗周围。

local KlausCommon = require("kei/protocols/combat/effects/beast/_klaus_common")

local KlausBasicEffect = {}

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function KlausBasicEffect.OnHitOther(slots, inst, data)
    if KlausCommon.HasAdvanced(slots) then
        return
    end
    KlausCommon.TryExtractSoul(slots, inst, data, false)
end

return KlausBasicEffect
