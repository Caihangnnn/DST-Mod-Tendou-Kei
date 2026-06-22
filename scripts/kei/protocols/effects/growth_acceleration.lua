-- 生活协议：加速周围植物/作物/树苗的生长。

local GROWTH_TIMER_PREFAB_WHITELIST = {
    rock_avocado_fruit_sprout_sapling = true,
}

local GrowthAcceleration = {}

--- 由 kei_protocolslots 的周期任务调用。
---@param slots table  KeiProtocolSlots 实例
---@param inst  Entity 角色实体
---@param stacks number 该协议的当前叠加层数
function GrowthAcceleration.Apply(slots, inst, stacks)
    if stacks <= 0 or TheSim == nil then
        return
    end

    local period = TUNING.KEI_LIFE_GROWTH_ACCELERATION_PERIOD or 1
    local speed_multiplier = stacks * (TUNING.KEI_LIFE_GROWTH_ACCELERATION_PER_STACK or 2)
    local extra_elapsed_time = math.max(0, speed_multiplier - 1) * period
    if extra_elapsed_time <= 0 then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local radius = TUNING.KEI_LIFE_GROWTH_ACCELERATION_RADIUS or 12
    for _, target in ipairs(TheSim:FindEntities(x, y, z, radius)) do
        local growable = target.components.growable
        if growable ~= nil
            and growable:IsGrowing()
            and growable.stages ~= nil
        then
            -- Preserve the original stage time roll and only advance its remaining time.
            growable:ExtendGrowTime(-extra_elapsed_time)
        end

        local timer = target.components.timer
        if ((target.growprefab ~= nil and target.StartGrowing ~= nil)
                or GROWTH_TIMER_PREFAB_WHITELIST[target.prefab])
            and timer ~= nil
            and timer:TimerExists("grow")
        then
            -- Planted tree saplings use the named "grow" timer instead of growable.
            timer:SetTimeLeft("grow", (timer:GetTimeLeft("grow") or 0) - extra_elapsed_time)
        end

        local pickable = target.components.pickable
        if growable == nil and pickable ~= nil then
            -- Let pickable retain its own pause, wither, and external-timer rules.
            pickable:LongUpdate(extra_elapsed_time)
        end
    end
end

return GrowthAcceleration
