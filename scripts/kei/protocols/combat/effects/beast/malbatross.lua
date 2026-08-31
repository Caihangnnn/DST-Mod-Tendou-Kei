-- 邪天翁高级协议：持续增加潮湿度，水面增加量翻倍，并获得水面战斗强化。
local MalbatrossCommon = require("kei/protocols/combat/effects/beast/_malbatross_common")

local MalbatrossEffect = {}
local SOURCE = "malbatross"

-- 启用协议效果，并注册该协议提供的持续能力。
function MalbatrossEffect.Enable(slots, inst)
    MalbatrossCommon.Enable(slots, inst, SOURCE, true)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MalbatrossEffect.Disable(slots, inst)
    MalbatrossCommon.Disable(slots, inst, SOURCE)
end

return MalbatrossEffect
