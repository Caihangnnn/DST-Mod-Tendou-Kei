local TaskSummon = {}
local RecorderDaywalker2 = require("kei/recorder/bosses/recorder_daywalker2")

local TASK_REFUSAL_TARGET_CHECK_INTERVAL = .25
local TASK_REFUSAL_TARGET_LOST_TIMEOUT = 5

local function IsTaskRefusalOwnerAvailable(owner)
    return owner ~= nil and owner:IsValid()
        and not owner:IsInLimbo()
        and not owner:HasTag("playerghost")
        and (owner.components == nil
            or owner.components.health == nil
            or not owner.components.health:IsDead())
end

local function SpawnTaskRefusalFX(target)
    if target == nil or not target:IsValid() or target.Transform == nil then
        return
    end
    local fx = SpawnPrefab("spawn_fx_medium_static")
    if fx ~= nil then
        fx.Transform:SetPosition(target.Transform:GetWorldPosition())
    end
end

function TaskSummon.PlayTaskRefusalSpawnFX(target)
    SpawnTaskRefusalFX(target)
end

function TaskSummon.DespawnTaskRefusalTarget(target)
    if target == nil or not target:IsValid() then
        return
    end

    -- A killed target already has its normal death presentation. The portal
    -- effect is for the special disappearance caused by lost aggro.
    local health = target.components ~= nil and target.components.health or nil
    if health == nil or not health:IsDead() then
        SpawnTaskRefusalFX(target)
    end
    target:Remove()
end

-- These bosses normally assume a world-spawned encounter. Keep their
-- instance-specific setup in one place so task and recorder summons agree.
function TaskSummon.PrepareSpecialTarget(target, doer, support_owner)
    if target == nil or not target:IsValid() then
        return
    end

    if target.prefab == "moose" or target.prefab == "kei_recorder_moose" then
        if target.StopAllWatchingWorldStates ~= nil then
            target:StopAllWatchingWorldStates()
        end
        target.shouldGoAway = false
    elseif target.prefab == "malbatross" or target.prefab == "kei_recorder_malbatross" then
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
    elseif target.prefab == "kei_recorder_daywalker2" then
        RecorderDaywalker2.Apply(target, support_owner)
    elseif target.prefab == "daywalker2" then
        -- Vanilla/task summons keep using the vanilla junk pile.
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
    elseif target.prefab == "stalker_atrium" or target.prefab == "kei_recorder_stalker" then
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
    elseif (target.prefab == "alterguardian_phase3"
        or target.prefab == "kei_recorder_alterguardian")
        and target.sg ~= nil
    then
        target.sg:GoToState("spawn")
    end
end

function TaskSummon.CleanupSpecialTarget(target)
    if target ~= nil and target.kei_task_refusal_attack_task ~= nil then
        target.kei_task_refusal_attack_task:Cancel()
        target.kei_task_refusal_attack_task = nil
    end
    if target ~= nil and target.kei_task_refusal_target_check_task ~= nil then
        target.kei_task_refusal_target_check_task:Cancel()
        target.kei_task_refusal_target_check_task = nil
    end
    if target ~= nil and target.kei_task_refusal_target_lost_task ~= nil then
        target.kei_task_refusal_target_lost_task:Cancel()
        target.kei_task_refusal_target_lost_task = nil
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
    if target == nil or not target:IsValid() or doer == nil then
        return
    end

    target.kei_task_refusal_owner = doer
    local combat = target.components ~= nil and target.components.combat or nil
    if combat ~= nil then
        -- Refusal summons are not allowed to keep another player as a target.
        -- Losing this target starts the delayed disappearance check below.
        combat:SetKeepTargetFunction(function(inst, current_target)
            local owner = inst.kei_task_refusal_owner
            return current_target == owner and IsTaskRefusalOwnerAvailable(owner)
        end)
        combat:SetTarget(doer)
    end

    local function HasOwnerTarget(inst)
        local owner = inst.kei_task_refusal_owner
        if not IsTaskRefusalOwnerAvailable(owner) then
            return false
        end
        local current_combat = inst.components ~= nil and inst.components.combat or nil
        return current_combat == nil or current_combat.target == owner
    end

    local function CancelLostTargetTimer(inst)
        if inst.kei_task_refusal_target_lost_task ~= nil then
            inst.kei_task_refusal_target_lost_task:Cancel()
            inst.kei_task_refusal_target_lost_task = nil
        end
    end

    local function StartLostTargetTimer(inst)
        if inst.kei_task_refusal_target_lost_task ~= nil then
            return
        end

        inst.kei_task_refusal_target_lost_task = inst:DoTaskInTime(
            TASK_REFUSAL_TARGET_LOST_TIMEOUT,
            function(summon)
                summon.kei_task_refusal_target_lost_task = nil
                if not HasOwnerTarget(summon) then
                    TaskSummon.DespawnTaskRefusalTarget(summon)
                end
            end
        )
    end

    target.kei_task_refusal_target_check_task = target:DoPeriodicTask(
        TASK_REFUSAL_TARGET_CHECK_INTERVAL,
        function(inst)
            local owner = inst.kei_task_refusal_owner
            if HasOwnerTarget(inst) then
                CancelLostTargetTimer(inst)
            else
                StartLostTargetTimer(inst)
            end
        end,
        0
    )

    -- Passive creatures have no combat component, so keep their existing
    -- close-range retaliation behavior while the target monitor handles exit.
    if combat == nil then
        target.kei_task_refusal_attack_task = target:DoPeriodicTask(1.5, function(inst)
            local owner = inst.kei_task_refusal_owner
            if not IsTaskRefusalOwnerAvailable(owner) then
                return
            end

            local ix, _, iz = inst.Transform:GetWorldPosition()
            local ox, _, oz = owner.Transform:GetWorldPosition()
            local dx, dz = ox - ix, oz - iz
            if dx * dx + dz * dz <= 9 then
                local owner_combat = owner.components ~= nil and owner.components.combat or nil
                if owner_combat ~= nil then
                    owner_combat:GetAttacked(inst, 10)
                end
            elseif inst.components.locomotor ~= nil then
                inst.components.locomotor:GoToPoint(Vector3(ox, 0, oz))
            end
        end)
    end
end

return TaskSummon
