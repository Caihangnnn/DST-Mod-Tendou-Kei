-- 果蝇王初级协议：降低协议额外消耗。
local LordfruitflyCommon = require("kei/protocols/combat/effects/beast/_lordfruitfly_common")

local LordfruitflyBasicEffect = {}
local SOURCE = "lordfruitfly_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function LordfruitflyBasicEffect.Enable(slots, inst)
    if LordfruitflyCommon.HasAdvanced(slots) then
        return
    end
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function LordfruitflyBasicEffect.Disable(slots, inst)
end

return LordfruitflyBasicEffect
