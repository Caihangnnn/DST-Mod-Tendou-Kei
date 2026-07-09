-- 克劳斯高级协议：攻击抽魂治疗，并追加目标最大生命值伤害。

local KlausCommon = require("kei/protocols/combat/effects/beast/_klaus_common")

local KlausEffect = {}

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function KlausEffect.OnHitOther(slots, inst, data)
    KlausCommon.TryExtractSoul(slots, inst, data, true)
end

return KlausEffect
