-- 拾荒疯猪初级协议：控制免疫与基础吸收。
local Daywalker2Common = require("kei/protocols/combat/effects/beast/_daywalker2_common")

local Daywalker2BasicEffect = {}
local SOURCE = "daywalker2_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function Daywalker2BasicEffect.Enable(slots, inst)
    if Daywalker2Common.HasAdvanced(slots) then
        Daywalker2Common.DisableImmunity(slots, inst, SOURCE)
        return
    end
    Daywalker2Common.EnableImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function Daywalker2BasicEffect.Disable(slots, inst)
    Daywalker2Common.DisableImmunity(slots, inst, SOURCE)
end

return Daywalker2BasicEffect
