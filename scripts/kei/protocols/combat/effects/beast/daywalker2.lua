-- 拾荒疯猪高级协议：控制免疫、盾牌特效与强化吸收。
local Daywalker2Common = require("kei/protocols/combat/effects/beast/_daywalker2_common")

local Daywalker2Effect = {}
local SOURCE = "daywalker2"

-- 启用协议效果，并注册该协议提供的持续能力。
function Daywalker2Effect.Enable(slots, inst)
    Daywalker2Common.EnableImmunity(slots, inst, SOURCE)
    Daywalker2Common.SetAbsorb(slots, inst, TUNING.KEI_DAYWALKER2_ABSORB or 0.25)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function Daywalker2Effect.Disable(slots, inst)
    Daywalker2Common.DisableImmunity(slots, inst, SOURCE)
    Daywalker2Common.ClearAbsorb(slots, inst)
end

return Daywalker2Effect
