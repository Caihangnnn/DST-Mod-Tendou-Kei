-- 穴居悬蛛协议（spider_dropper）：在蜘蛛网区域获得 50% 攻击倍率加成。

local SpiderWebCommon = require('kei/protocols/combat/effects/biome/_spider_web_common')

local SpiderDropperEffect = {}
local DAMAGE_MODIFIER = 'kei_spider_dropper_web_damage'

-- 根据当前位置刷新蜘蛛网区域攻击倍率。
local function RefreshDamageMultiplier(slots, inst)
    if slots == nil or inst.components.combat == nil then
        return
    end

    if SpiderWebCommon.IsInSpiderWebArea(slots, inst) then
        slots:SetCombatDamageMultiplier(
            DAMAGE_MODIFIER,
            TUNING.KEI_SPIDER_DROPPER_WEB_DAMAGE_MULT or 1.5
        )
    else
        slots:SetCombatDamageMultiplier(DAMAGE_MODIFIER, nil)
    end
end

-- 启用穴居悬蛛协议，周期检测是否处于蜘蛛网区域。
function SpiderDropperEffect.Enable(slots, inst)
    RefreshDamageMultiplier(slots, inst)
    if slots._kei_spider_dropper_damage_task == nil then
        slots._kei_spider_dropper_damage_task = inst:DoPeriodicTask(
            TUNING.KEI_SPIDER_WEB_DAMAGE_UPDATE_PERIOD or 0.1,
            function() RefreshDamageMultiplier(slots, inst) end
        )
    end
end

-- 移除穴居悬蛛协议提供的攻击倍率。
function SpiderDropperEffect.Disable(slots, inst)
    if slots._kei_spider_dropper_damage_task ~= nil then
        slots._kei_spider_dropper_damage_task:Cancel()
        slots._kei_spider_dropper_damage_task = nil
    end
    slots:SetCombatDamageMultiplier(DAMAGE_MODIFIER, nil)
end

return SpiderDropperEffect
