local AntlionCommon = require("kei/protocols/combat/effects/_antlion_common")

local AntlionEffect = {}
local SOURCE = "antlion"

function AntlionEffect.Enable(slots, inst)
    AntlionCommon.EnableStormImmunity(slots, inst, SOURCE)
end

function AntlionEffect.Disable(slots, inst)
    AntlionCommon.DisableStormImmunity(slots, inst, SOURCE)
end

function AntlionEffect.OnHitOther(slots, inst, data)
    AntlionCommon.TrySpawnSandSpikes(slots, inst, data)
end

return AntlionEffect