local MooseCommon = require("kei/protocols/combat/effects/_moose_common")

local MooseBasicEffect = {}
local SOURCE = "moose_basic"

function MooseBasicEffect.Enable(slots, inst)
    if slots.active_combat ~= nil and slots.active_combat.moose == true then
        MooseCommon.DisableMoistureImmunity(slots, inst, SOURCE)
        return
    end
    MooseCommon.EnableMoistureImmunity(slots, inst, SOURCE)
end

function MooseBasicEffect.Disable(slots, inst)
    MooseCommon.DisableMoistureImmunity(slots, inst, SOURCE)
end

return MooseBasicEffect