-- 邪天翁初级协议：持续增加潮湿度，水面增加量翻倍。
local MalbatrossCommon = require("kei/protocols/combat/effects/beast/_malbatross_common")

local MalbatrossBasicEffect = {}
local SOURCE = "malbatross_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function MalbatrossBasicEffect.Enable(slots, inst)
    if MalbatrossCommon.HasAdvanced(slots) then
        MalbatrossCommon.Disable(slots, inst, SOURCE)
        return
    end
    MalbatrossCommon.Enable(slots, inst, SOURCE, false)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function MalbatrossBasicEffect.Disable(slots, inst)
    MalbatrossCommon.Disable(slots, inst, SOURCE)
end

return MalbatrossBasicEffect
