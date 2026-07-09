-- 蜘蛛战士协议（spider_warrior）：在蜘蛛网区域免疫减速，并获得 25% 移速加成。

local SpiderWebCommon = require('kei/protocols/combat/effects/biome/_spider_web_common')

local SpiderWarriorEffect = {}
local SOURCE = 'spider_warrior'

-- 启用蜘蛛网移动修正：免疫蜘蛛网减速，并在蜘蛛网区域加速。
function SpiderWarriorEffect.Enable(slots, inst)
    SpiderWebCommon.EnableWebMovement(slots, inst, SOURCE, true)
end

-- 移除蜘蛛战士协议提供的蜘蛛网移动修正。
function SpiderWarriorEffect.Disable(slots, inst)
    SpiderWebCommon.DisableWebMovement(slots, inst, SOURCE)
end

return SpiderWarriorEffect