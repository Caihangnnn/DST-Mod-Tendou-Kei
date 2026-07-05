local Daywalker2Common = require("kei/protocols/combat/effects/_daywalker2_common")

local Daywalker2BasicEffect = {}
local SOURCE = "daywalker2_basic"

function Daywalker2BasicEffect.Enable(slots, inst)
    if Daywalker2Common.HasAdvanced(slots) then
        Daywalker2Common.DisableImmunity(slots, inst, SOURCE)
        return
    end
    Daywalker2Common.EnableImmunity(slots, inst, SOURCE)
end

function Daywalker2BasicEffect.Disable(slots, inst)
    Daywalker2Common.DisableImmunity(slots, inst, SOURCE)
end

return Daywalker2BasicEffect