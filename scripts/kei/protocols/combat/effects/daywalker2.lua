local Daywalker2Common = require("kei/protocols/combat/effects/_daywalker2_common")

local Daywalker2Effect = {}
local SOURCE = "daywalker2"

function Daywalker2Effect.Enable(slots, inst)
    Daywalker2Common.EnableImmunity(slots, inst, SOURCE)
    Daywalker2Common.SetAbsorb(inst, TUNING.KEI_DAYWALKER2_ABSORB or 0.25)
end

function Daywalker2Effect.Disable(slots, inst)
    Daywalker2Common.DisableImmunity(slots, inst, SOURCE)
    Daywalker2Common.ClearAbsorb(inst)
end

return Daywalker2Effect