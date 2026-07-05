local ToadstoolCommon = require("kei/protocols/combat/effects/_toadstool_common")

local ToadstoolBasicEffect = {}
local SOURCE = "toadstool_basic"

function ToadstoolBasicEffect.Enable(slots, inst)
    if ToadstoolCommon.HasAdvanced(slots) then
        ToadstoolCommon.DisableSleepImmunity(slots, inst, SOURCE)
        return
    end
    ToadstoolCommon.EnableSleepImmunity(slots, inst, SOURCE)
end

function ToadstoolBasicEffect.Disable(slots, inst)
    ToadstoolCommon.DisableSleepImmunity(slots, inst, SOURCE)
end

return ToadstoolBasicEffect