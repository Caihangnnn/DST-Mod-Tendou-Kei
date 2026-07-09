-- 蟾蜍初级协议：免疫催眠。
local ToadstoolCommon = require("kei/protocols/combat/effects/beast/_toadstool_common")

local ToadstoolBasicEffect = {}
local SOURCE = "toadstool_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function ToadstoolBasicEffect.Enable(slots, inst)
    if ToadstoolCommon.HasAdvanced(slots) then
        ToadstoolCommon.DisableSleepImmunity(slots, inst, SOURCE)
        return
    end
    ToadstoolCommon.EnableSleepImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function ToadstoolBasicEffect.Disable(slots, inst)
    ToadstoolCommon.DisableSleepImmunity(slots, inst, SOURCE)
end

return ToadstoolBasicEffect
