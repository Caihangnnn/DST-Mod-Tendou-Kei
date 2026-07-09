-- 果蝇王高级协议：取消协议额外消耗。
local LordfruitflyCommon = require("kei/protocols/combat/effects/beast/_lordfruitfly_common")

local LordfruitflyEffect = {}
local SOURCE = "lordfruitfly"

-- 启用协议效果，并注册该协议提供的持续能力。
function LordfruitflyEffect.Enable(slots, inst)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function LordfruitflyEffect.Disable(slots, inst)
end

return LordfruitflyEffect
