local MooseCommon = require("kei/protocols/combat/effects/_moose_common")

local MooseEffect = {}
local SOURCE = "moose"

function MooseEffect.Enable(slots, inst)
    MooseCommon.EnableMoistureImmunity(slots, inst, SOURCE)
end

function MooseEffect.Disable(slots, inst)
    MooseCommon.DisableMoistureImmunity(slots, inst, SOURCE)
end

function MooseEffect.OnHitOther(slots, inst, data)
    MooseCommon.TrySpawnTornado(slots, inst, data)
end

return MooseEffect