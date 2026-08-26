local TaskSummon = {}

-- These bosses normally assume a world-spawned encounter. Keep their
-- instance-specific setup in one place so task and recorder summons agree.
function TaskSummon.PrepareSpecialTarget(target, doer, support_owner)
    if target == nil or not target:IsValid() then
        return
    end

    if target.prefab == "moose" then
        if target.StopAllWatchingWorldStates ~= nil then
            target:StopAllWatchingWorldStates()
        end
        target.shouldGoAway = false
    elseif target.prefab == "malbatross" then
        if target.components.locomotor ~= nil then
            target.components.locomotor.pathcaps = {
                allowocean = true,
                ignoreLand = true,
            }
        end
        target.landtimer = math.huge
        target.kei_special_summon_land_task = target:DoPeriodicTask(0.25, function(inst)
            if inst:IsValid() then
                inst.landtimer = math.huge
            end
        end)
    elseif target.prefab == "antlion" then
        -- Antlion only initializes combat while persistent during StartCombat.
        target.persists = true
        if target.StartCombat ~= nil then
            target:StartCombat(doer, "kei_task")
        end
        target.persists = false
    elseif target.prefab == "daywalker2" then
        -- Daywalker's attack logic needs a bound junk pile.
        local junk = SpawnPrefab("junk_pile_big")
        if junk ~= nil then
            local x, y, z = target.Transform:GetWorldPosition()
            junk.persists = false
            junk.daywalker_side = 1
            junk.Transform:SetPosition(x, y, z)
            if junk.CanBuryDaywalker ~= nil
                and junk:CanBuryDaywalker(target)
                and junk.TryBuryDaywalker ~= nil
            then
                junk:TryBuryDaywalker(target)
                if junk.TryReleaseDaywalker ~= nil then
                    junk:TryReleaseDaywalker(target)
                end
            end
            support_owner = support_owner or target
            support_owner.kei_target_support_entities = { junk }
        end
    elseif target.prefab == "stalker_atrium" then
        target.IsNearAtrium = function() return true end
        target.OnLostAtrium = function() end
        target.IsAtriumDecay = function() return false end
        target.OnEntitySleep = function(inst)
            if inst.sleeptask ~= nil then
                inst.sleeptask:Cancel()
                inst.sleeptask = nil
            end
        end
        if target.sleeptask ~= nil then
            target.sleeptask:Cancel()
            target.sleeptask = nil
        end
    elseif target.prefab == "alterguardian_phase3" and target.sg ~= nil then
        target.sg:GoToState("spawn")
    end
end

function TaskSummon.CleanupSpecialTarget(target)
    if target ~= nil and target.kei_task_refusal_attack_task ~= nil then
        target.kei_task_refusal_attack_task:Cancel()
        target.kei_task_refusal_attack_task = nil
    end
    if target ~= nil and target.kei_special_summon_land_task ~= nil then
        target.kei_special_summon_land_task:Cancel()
        target.kei_special_summon_land_task = nil
    end

    if target ~= nil and target.kei_target_support_entities ~= nil then
        for _, support in ipairs(target.kei_target_support_entities) do
            if support ~= nil and support:IsValid() then
                support:Remove()
            end
        end
        target.kei_target_support_entities = nil
    end
end

function TaskSummon.AggroTarget(target, doer)
    if target ~= nil and target:IsValid()
        and target.components.combat ~= nil
        and doer ~= nil and doer:IsValid()
    then
        target.components.combat:SuggestTarget(doer)
    end
end

-- Some task targets are passive creatures and have no combat component at
-- all. A normal SuggestTarget is a no-op for them, so refusal summons receive
-- a lightweight, instance-only close-range retaliation loop.
function TaskSummon.StartTaskAggression(target, doer)
    TaskSummon.AggroTarget(target, doer)
    if target == nil or not target:IsValid()
        or (target.components ~= nil and target.components.combat ~= nil)
        or doer == nil or not doer:IsValid()
    then
        return
    end

    target.kei_task_refusal_attack_task = target:DoPeriodicTask(1.5, function(inst)
        local owner = inst.kei_task_refusal_owner
        if owner == nil or not owner:IsValid()
            or owner.components.health == nil or owner.components.health:IsDead()
        then
            return
        end

        local ix, _, iz = inst.Transform:GetWorldPosition()
        local ox, _, oz = owner.Transform:GetWorldPosition()
        local dx, dz = ox - ix, oz - iz
        if dx * dx + dz * dz <= 9 then
            local combat = owner.components.combat
            if combat ~= nil then
                combat:GetAttacked(inst, 10)
            end
        elseif inst.components.locomotor ~= nil then
            inst.components.locomotor:GoToPoint(Vector3(ox, 0, oz))
        end
    end)
end

return TaskSummon
