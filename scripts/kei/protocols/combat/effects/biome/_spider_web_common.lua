-- 蜘蛛群系协议公共实现：管理蜘蛛网移动修正。

local SpiderWebCommon = {}

local SPIDER_WEB_SPEED_KEY = "kei_spider_web_speed"

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

local function HasFasterSource(sources)
    if sources == nil then
        return false
    end
    for _, data in pairs(sources) do
        if data ~= nil and data.faster == true then
            return true
        end
    end
    return false
end

local function IsOnRealSpiderWeb(inst)
    if inst == nil or TheWorld == nil or TheWorld.GroundCreep == nil then
        return false
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    return TheWorld.GroundCreep:OnCreep(x, y, z)
end

local function IsInVirtualSpiderWeb(slots)
    return slots ~= nil
        and slots.HasCombatProtocol ~= nil
        and slots:HasCombatProtocol("spiderqueen")
end

-- 判断角色当前是否处于真实蜘蛛网或被协议视为蜘蛛网的区域。
function SpiderWebCommon.IsInSpiderWebArea(slots, inst)
    return IsOnRealSpiderWeb(inst) or IsInVirtualSpiderWeb(slots)
end

-- 按当前位置刷新黄蜘蛛协议提供的 25% 蜘蛛网加速。
local function RefreshSpeedBonus(slots, inst)
    local locomotor = inst.components.locomotor
    if locomotor == nil then
        return
    end

    if HasFasterSource(slots._kei_spider_web_sources)
        and SpiderWebCommon.IsInSpiderWebArea(slots, inst)
    then
        locomotor:SetExternalSpeedMultiplier(inst, SPIDER_WEB_SPEED_KEY, TUNING.KEI_SPIDER_WARRIOR_WEB_SPEED_MULT or 1.25)
    else
        locomotor:RemoveExternalSpeedMultiplier(inst, SPIDER_WEB_SPEED_KEY)
    end
end

local function StopSpeedTask(slots, inst)
    if slots._kei_spider_web_speed_task ~= nil then
        slots._kei_spider_web_speed_task:Cancel()
        slots._kei_spider_web_speed_task = nil
    end
    if inst.components.locomotor ~= nil then
        inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, SPIDER_WEB_SPEED_KEY)
    end
end

local function EnsureSpeedTask(slots, inst)
    if HasFasterSource(slots._kei_spider_web_sources) then
        RefreshSpeedBonus(slots, inst)
        if slots._kei_spider_web_speed_task == nil then
            slots._kei_spider_web_speed_task = inst:DoPeriodicTask(
                TUNING.KEI_SPIDER_WEB_SPEED_UPDATE_PERIOD or 0.1,
                function() RefreshSpeedBonus(slots, inst) end
            )
        end
    else
        StopSpeedTask(slots, inst)
    end
end

-- 根据当前来源表刷新 locomotor 的蜘蛛网移动状态。
local function ApplyLocomotorState(slots, inst)
    local locomotor = inst.components.locomotor
    if locomotor == nil then
        return
    end

    local sources = slots._kei_spider_web_sources
    if not HasAnySource(sources) then
        StopSpeedTask(slots, inst)
        if slots._kei_spider_web_old_triggerscreep ~= nil then
            locomotor:SetTriggersCreep(slots._kei_spider_web_old_triggerscreep)
        end
        if slots._kei_spider_web_old_fasteroncreep ~= nil then
            locomotor:SetFasterOnCreep(slots._kei_spider_web_old_fasteroncreep)
        end
        slots._kei_spider_web_old_triggerscreep = nil
        slots._kei_spider_web_old_fasteroncreep = nil
        slots._kei_spider_web_sources = nil
        return
    end

    locomotor:SetTriggersCreep(false)
    locomotor:SetFasterOnCreep(false)
    EnsureSpeedTask(slots, inst)
end

-- 添加蜘蛛网移动来源；faster 为 true 时在蜘蛛网上获得 25% 外部移速加成。
function SpiderWebCommon.EnableWebMovement(slots, inst, source, faster)
    if slots == nil or inst == nil or inst.components.locomotor == nil then
        return
    end

    source = source or "spider_web"
    slots._kei_spider_web_sources = slots._kei_spider_web_sources or {}

    if not HasAnySource(slots._kei_spider_web_sources) then
        slots._kei_spider_web_old_triggerscreep = inst.components.locomotor.triggerscreep
        slots._kei_spider_web_old_fasteroncreep = inst.components.locomotor.fasteroncreep
    end

    slots._kei_spider_web_sources[source] = { faster = faster == true }
    ApplyLocomotorState(slots, inst)
end

-- 移除蜘蛛网移动来源；无来源时恢复协议启用前的 locomotor 状态。
function SpiderWebCommon.DisableWebMovement(slots, inst, source)
    if slots == nil or inst == nil or inst.components.locomotor == nil then
        return
    end

    source = source or "spider_web"
    if slots._kei_spider_web_sources ~= nil then
        slots._kei_spider_web_sources[source] = nil
    end
    ApplyLocomotorState(slots, inst)
end

return SpiderWebCommon