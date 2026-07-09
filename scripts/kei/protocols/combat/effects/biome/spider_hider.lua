-- 洞穴蜘蛛协议（spider_hider）：在蜘蛛网区域获得 50% 减伤。

local SpiderWebCommon = require('kei/protocols/combat/effects/biome/_spider_web_common')

local SpiderHiderEffect = {}
local ABSORB_MODIFIER = 'kei_spider_hider_web_absorb'

local function RemoveAbsorbModifier(inst)
    if inst.components.health ~= nil then
        inst.components.health.externalabsorbmodifiers:RemoveModifier(inst, ABSORB_MODIFIER)
    end
end

-- 根据当前位置刷新蜘蛛网区域减伤。
local function RefreshAbsorbModifier(slots, inst)
    if inst.components.health == nil then
        return
    end

    if SpiderWebCommon.IsInSpiderWebArea(slots, inst) then
        inst.components.health.externalabsorbmodifiers:SetModifier(
            inst,
            TUNING.KEI_SPIDER_HIDER_WEB_ABSORB or 0.5,
            ABSORB_MODIFIER
        )
    else
        RemoveAbsorbModifier(inst)
    end
end

-- 启用洞穴蜘蛛协议，周期检测是否处于蜘蛛网区域。
function SpiderHiderEffect.Enable(slots, inst)
    RefreshAbsorbModifier(slots, inst)
    if slots._kei_spider_hider_absorb_task == nil then
        slots._kei_spider_hider_absorb_task = inst:DoPeriodicTask(
            TUNING.KEI_SPIDER_WEB_ABSORB_UPDATE_PERIOD or 0.1,
            function() RefreshAbsorbModifier(slots, inst) end
        )
    end
end

-- 移除洞穴蜘蛛协议提供的减伤。
function SpiderHiderEffect.Disable(slots, inst)
    if slots._kei_spider_hider_absorb_task ~= nil then
        slots._kei_spider_hider_absorb_task:Cancel()
        slots._kei_spider_hider_absorb_task = nil
    end
    RemoveAbsorbModifier(inst)
end

return SpiderHiderEffect