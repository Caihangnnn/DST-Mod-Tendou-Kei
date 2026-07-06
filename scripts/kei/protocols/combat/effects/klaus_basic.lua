-- 克劳斯初级协议：攻击命中时概率抽取灵魂并治疗周围。

local KlausCommon = require("kei/protocols/combat/effects/_klaus_common")

local KlausBasicEffect = {}

function KlausBasicEffect.OnHitOther(slots, inst, data)
    if KlausCommon.HasAdvanced(slots) then
        return
    end
    KlausCommon.TryExtractSoul(slots, inst, data, false)
end

return KlausBasicEffect
