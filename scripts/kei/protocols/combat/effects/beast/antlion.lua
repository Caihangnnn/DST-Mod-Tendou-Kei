-- 蚁狮高级协议：免疫风暴并攻击概率生成沙刺。
local AntlionCommon = require("kei/protocols/combat/effects/beast/_antlion_common")

local AntlionEffect = {}
local SOURCE = "antlion"

-- 启用协议效果，并注册该协议提供的持续能力。
function AntlionEffect.Enable(slots, inst)
    AntlionCommon.EnableStormImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function AntlionEffect.Disable(slots, inst)
    AntlionCommon.DisableStormImmunity(slots, inst, SOURCE)
end

-- 处理攻击命中事件，根据协议等级触发附加战斗效果。
function AntlionEffect.OnHitOther(slots, inst, data)
    AntlionCommon.TrySpawnSandSpikes(slots, inst, data)
end

return AntlionEffect
