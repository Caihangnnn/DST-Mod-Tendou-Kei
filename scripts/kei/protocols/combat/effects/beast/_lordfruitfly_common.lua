-- 果蝇王协议公共实现：协议消耗减免状态判断。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local LordfruitflyCommon = {}

function LordfruitflyCommon.HasBasic(slots)
    return BeastCommon.HasProtocol(slots, "lordfruitfly_basic")
end

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function LordfruitflyCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "lordfruitfly")
end

return LordfruitflyCommon
