local MalbatrossCommon = require("kei/protocols/combat/effects/_malbatross_common")

local MalbatrossBasicEffect = {}
local SOURCE = "malbatross_basic"

function MalbatrossBasicEffect.Enable(slots, inst)
    if MalbatrossCommon.HasAdvanced(slots) then
        MalbatrossCommon.Disable(slots, inst, SOURCE)
        return
    end
    MalbatrossCommon.Enable(slots, inst, SOURCE, false)
end

function MalbatrossBasicEffect.Disable(slots, inst)
    MalbatrossCommon.Disable(slots, inst, SOURCE)
end

return MalbatrossBasicEffect