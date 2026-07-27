-- 种地高手：扩大与植物对话时的植物生效范围。

local function GetExperienceTotal(inst)
    if inst == nil then
        return 0
    end

    local experience = inst.components ~= nil and inst.components.kei_experience or nil
    if experience ~= nil then
        return tonumber(experience.total) or 0
    end

    -- 客户端没有主机组件，使用角色同步的累计经验值进行动作预测。
    if inst._kei_experience_total ~= nil then
        return tonumber(inst._kei_experience_total:value()) or 0
    end

    return 0
end

local function GetFarmingMasterRange(inst)
    local step = tonumber(TUNING.KEI_FARMING_MASTER_EXPERIENCE_STEP) or 500
    local max_range = tonumber(TUNING.KEI_FARMING_MASTER_MAX_RANGE) or 12
    if step <= 0 or max_range <= 0 then
        return 0
    end

    return math.min(max_range, math.floor(GetExperienceTotal(inst) / step))
end

local function IsFarmPlant(inst)
    return inst ~= nil
        and inst:IsValid()
        and inst:HasTag("farm_plant")
        and inst.components ~= nil
        and inst.components.farmplanttendable ~= nil
end

local function TendNearbyPlants(doer, original_target)
    local radius = GetFarmingMasterRange(doer)
    if radius <= 0 or TheSim == nil or doer == nil or not doer:IsValid() then
        return
    end

    local x, y, z = doer.Transform:GetWorldPosition()
    local plants = TheSim:FindEntities(x, y, z, radius, { "farm_plant" })
    for _, plant in ipairs(plants) do
        if plant ~= original_target and IsFarmPlant(plant) then
            -- TendTo 保留原版的可对话判断和具体植物效果。
            plant.components.farmplanttendable:TendTo(doer)
        end
    end
end

local function AddFarmingMasterToInteractAction()
    if ACTIONS == nil
        or ACTIONS.INTERACT_WITH == nil
        or ACTIONS.INTERACT_WITH.fn == nil
    then
        return
    end

    local action = ACTIONS.INTERACT_WITH
    if action._kei_farming_master_wrapped then
        return
    end

    local old_fn = action.fn
    action._kei_farming_master_wrapped = true
    action.fn = function(act, ...)
        local result = old_fn(act, ...)
        if result
            and TheWorld ~= nil
            and TheWorld.ismastersim
            and act ~= nil
            and act.doer ~= nil
            and act.doer:HasTag("kei")
            and IsFarmPlant(act.target)
        then
            TendNearbyPlants(act.doer, act.target)
        end
        return result
    end
end

AddFarmingMasterToInteractAction()

