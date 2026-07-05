local DeerclopsCommon = require("kei/protocols/combat/effects/_deerclops_common")

local DeerclopsBasicEffect = {}
local SOURCE = "deerclops_basic"

function DeerclopsBasicEffect.Enable(slots, inst)
    if slots.active_combat ~= nil and slots.active_combat.deerclops == true then
        DeerclopsCommon.DisableFreezeImmunity(slots, inst, SOURCE)
        return
    end
    DeerclopsCommon.EnableFreezeImmunity(slots, inst, SOURCE)
end

function DeerclopsBasicEffect.Disable(slots, inst)
    DeerclopsCommon.DisableFreezeImmunity(slots, inst, SOURCE)
end

return DeerclopsBasicEffect