-- 麋鹿鹅高级协议：免疫潮湿并攻击概率生成旋风。
local MooseCommon = require("kei/protocols/combat/effects/beast/_moose_common")

local MooseEffect = {}
local SOURCE = "moose"

-- 启用协议效果，并注册该协议提供的持续能力。
function MooseEffect.Enable(slots, inst)
    MooseCommon.EnableMoistureImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MooseEffect.Disable(slots, inst)
    MooseCommon.DisableMoistureImmunity(slots, inst, SOURCE)
end

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function MooseEffect.OnHitOther(slots, inst, data)
    MooseCommon.TrySpawnTornado(slots, inst, data)
end

return MooseEffect
