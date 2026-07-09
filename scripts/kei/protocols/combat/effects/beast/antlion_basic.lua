-- 蚁狮初级协议：免疫沙尘暴和月亮风暴。
local AntlionCommon = require("kei/protocols/combat/effects/beast/_antlion_common")

local AntlionBasicEffect = {}
local SOURCE = "antlion_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function AntlionBasicEffect.Enable(slots, inst)
    if AntlionCommon.HasAdvanced(slots) then
        AntlionCommon.DisableStormImmunity(slots, inst, SOURCE)
        return
    end
    AntlionCommon.EnableStormImmunity(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function AntlionBasicEffect.Disable(slots, inst)
    AntlionCommon.DisableStormImmunity(slots, inst, SOURCE)
end

return AntlionBasicEffect
