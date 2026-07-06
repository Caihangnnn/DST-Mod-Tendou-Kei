-- 克劳斯高级协议：攻击抽魂治疗，并追加目标最大生命值伤害。

local KlausCommon = require("kei/protocols/combat/effects/_klaus_common")

local KlausEffect = {}

function KlausEffect.OnHitOther(slots, inst, data)
    KlausCommon.TryExtractSoul(slots, inst, data, true)
end

return KlausEffect
