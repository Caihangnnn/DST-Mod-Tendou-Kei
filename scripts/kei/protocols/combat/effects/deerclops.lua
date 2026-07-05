local DeerclopsCommon = require("kei/protocols/combat/effects/_deerclops_common")

local DeerclopsEffect = {}
local SOURCE = "deerclops"

function DeerclopsEffect.Enable(slots, inst)
    DeerclopsCommon.EnableFreezeImmunity(slots, inst, SOURCE)
end

function DeerclopsEffect.Disable(slots, inst)
    DeerclopsCommon.DisableFreezeImmunity(slots, inst, SOURCE)
end

function DeerclopsEffect.OnHitOther(slots, inst, data)
    DeerclopsCommon.AddColdnessOnHit(data, 1)
end

return DeerclopsEffect