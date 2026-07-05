local AntlionCommon = require("kei/protocols/combat/effects/_antlion_common")

local AntlionBasicEffect = {}
local SOURCE = "antlion_basic"

function AntlionBasicEffect.Enable(slots, inst)
    if AntlionCommon.HasAdvanced(slots) then
        AntlionCommon.DisableStormImmunity(slots, inst, SOURCE)
        return
    end
    AntlionCommon.EnableStormImmunity(slots, inst, SOURCE)
end

function AntlionBasicEffect.Disable(slots, inst)
    AntlionCommon.DisableStormImmunity(slots, inst, SOURCE)
end

return AntlionBasicEffect