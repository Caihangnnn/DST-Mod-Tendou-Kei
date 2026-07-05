local EyeOfTerrorCommon = require("kei/protocols/combat/effects/_eyeofterror_common")

local EyeOfTerrorEffect = {}

function EyeOfTerrorEffect.Enable(slots, inst)
    return EyeOfTerrorCommon.HasAdvanced(slots)
end

return EyeOfTerrorEffect