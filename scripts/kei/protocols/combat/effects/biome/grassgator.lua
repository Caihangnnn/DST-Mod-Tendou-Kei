-- 草鳄鱼协议（grassgator）：潮湿时周期性恢复机体完整度。

local GrassgatorEffect = {}

local function GetMoisture(inst)
    return inst.components.moisture ~= nil and inst.components.moisture:GetMoisture() or 0
end

local function GetHealPeriod()
    return math.max(TUNING.KEI_GRASSGATOR_HEAL_PERIOD or 3, FRAMES)
end

local function GetCheckPeriod()
    return math.min(GetHealPeriod(), 1)
end

local function HealIntegrity(inst)
    if inst.components.health == nil or inst.components.health:IsDead() then
        return
    end

    local amount = TUNING.KEI_GRASSGATOR_HEAL_AMOUNT or 1
    if amount > 0 then
        inst.components.health:DoDelta(amount, true, "kei_grassgator")
    end
end

local function StopHealTask(slots)
    if slots._kei_grassgator_heal_task ~= nil then
        slots._kei_grassgator_heal_task:Cancel()
        slots._kei_grassgator_heal_task = nil
    end
end

-- 协议存在期间持续检查潮湿度，避免依赖潮湿度事件是否触发。
local function UpdateHeal(slots, inst)
    if inst.components.health == nil then
        return
    end

    local now = GetTime()
    local period = GetHealPeriod()
    if GetMoisture(inst) <= 0 then
        slots._kei_grassgator_next_heal_time = nil
        return
    end

    if slots._kei_grassgator_next_heal_time == nil then
        slots._kei_grassgator_next_heal_time = now + period
        return
    end

    if now >= slots._kei_grassgator_next_heal_time then
        HealIntegrity(inst)
        slots._kei_grassgator_next_heal_time = now + period
    end
end

-- 启用潮湿自愈；任务本身只做轻量检测，真正恢复仍按配置周期发生。
function GrassgatorEffect.Enable(slots, inst)
    if slots == nil or inst == nil then
        return
    end

    if slots._kei_grassgator_heal_task == nil then
        slots._kei_grassgator_heal_task = inst:DoPeriodicTask(GetCheckPeriod(), function()
            UpdateHeal(slots, inst)
        end, 0)
    end
end

-- 移除协议时停止自愈。
function GrassgatorEffect.Disable(slots, inst)
    if slots == nil then
        return
    end

    StopHealTask(slots)
    slots._kei_grassgator_next_heal_time = nil
end

return GrassgatorEffect