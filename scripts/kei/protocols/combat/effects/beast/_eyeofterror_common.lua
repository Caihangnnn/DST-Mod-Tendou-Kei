-- 克眼协议功能实现

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local EyeOfTerrorCommon = {}

function EyeOfTerrorCommon.HasBasic(slots)
    return BeastCommon.HasProtocol(slots, "eyeofterror_basic")
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function EyeOfTerrorCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "eyeofterror")
end

function EyeOfTerrorCommon.HasDash(slots)
    return EyeOfTerrorCommon.HasAdvanced(slots) or EyeOfTerrorCommon.HasBasic(slots)
end

return EyeOfTerrorCommon
