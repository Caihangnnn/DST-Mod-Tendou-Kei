-- 蜘蛛协议（spider）：在蜘蛛网区域免疫减速。

local SpiderWebCommon = require('kei/protocols/combat/effects/biome/_spider_web_common')

local SpiderEffect = {}
local SOURCE = 'spider'

-- 启用蜘蛛网移动修正，仅免疫蜘蛛网减速，不获得蜘蛛阵营互动标签。
function SpiderEffect.Enable(slots, inst)
    SpiderWebCommon.EnableWebMovement(slots, inst, SOURCE, false)
end

-- 移除蜘蛛协议提供的蜘蛛网移动修正。
function SpiderEffect.Disable(slots, inst)
    SpiderWebCommon.DisableWebMovement(slots, inst, SOURCE)
end

return SpiderEffect