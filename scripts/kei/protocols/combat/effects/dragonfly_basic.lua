local DragonflyCommon = require("kei/protocols/combat/effects/_dragonfly_common")

local DragonflyBasicEffect = {}
local SOURCE = "dragonfly_basic"

function DragonflyBasicEffect.Enable(slots, inst)
    if DragonflyCommon.HasAdvanced(slots) then
        DragonflyCommon.DisableFireImmunity(slots, inst, SOURCE)
        return
    end
    DragonflyCommon.EnableFireImmunity(slots, inst, SOURCE)
end

function DragonflyBasicEffect.Disable(slots, inst)
    DragonflyCommon.DisableFireImmunity(slots, inst, SOURCE)
end

return DragonflyBasicEffect