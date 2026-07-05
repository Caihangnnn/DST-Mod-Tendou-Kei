local LordfruitflyCommon = require("kei/protocols/combat/effects/_lordfruitfly_common")

local LordfruitflyBasicEffect = {}
local SOURCE = "lordfruitfly_basic"

function LordfruitflyBasicEffect.Enable(slots, inst)
    if LordfruitflyCommon.HasAdvanced(slots) then
        return
    end
end

function LordfruitflyBasicEffect.Disable(slots, inst)
end

return LordfruitflyBasicEffect