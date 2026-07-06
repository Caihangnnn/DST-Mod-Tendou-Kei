local MalbatrossCommon = require("kei/protocols/combat/effects/_malbatross_common")

local MalbatrossEffect = {}
local SOURCE = "malbatross"

function MalbatrossEffect.Enable(slots, inst)
    MalbatrossCommon.Enable(slots, inst, SOURCE, true)
end

function MalbatrossEffect.Disable(slots, inst)
    MalbatrossCommon.Disable(slots, inst, SOURCE)
end

return MalbatrossEffect