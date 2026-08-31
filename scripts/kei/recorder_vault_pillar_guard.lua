local RecorderBoss = require("kei/recorder_boss")

local RecorderVaultPillarGuard = {}

local ROOT_HEALTH = 10000
local MAX_SPLIT_GENERATION = 3
local SPLIT_SCALES = { 1, 0.8, 0.6, 0.4 }
local SPLIT_DELAY = 32 * FRAMES
local SPLIT_LAUNCH_SPEED = 4
local SPLIT_LAUNCH_HEIGHT = 8
local SPLIT_LAUNCH_BRAIN_LOCK_TIME = 0.8
local COMPLETION_DELAY = 2.5

local function RegisterSupport(source, entity)
    if source == nil or entity == nil then
        return
    end

    source.kei_target_support_entities = source.kei_target_support_entities or {}
    table.insert(source.kei_target_support_entities, entity)
end

local function GetLootAtHalfQuantity(loot)
    local counts = {}
    for _, prefab in ipairs(loot or {}) do
        counts[prefab] = (counts[prefab] or 0) + 1
    end

    local remaining = {}
    for prefab, count in pairs(counts) do
        remaining[prefab] = math.floor(count * 0.5)
    end

    local result = {}
    for _, prefab in ipairs(loot or {}) do
        if remaining[prefab] ~= nil and remaining[prefab] > 0 then
            table.insert(result, prefab)
            remaining[prefab] = remaining[prefab] - 1
        end
    end
    return result
end

local function DropRecorderLoot(inst)
    if inst.kei_recorder_vault_generation ~= MAX_SPLIT_GENERATION
        or inst.kei_recorder_cleanup
        or inst.components.lootdropper == nil
    then
        return
    end

    inst:SetDeathLootLevel(1)
    local lootdropper = inst.components.lootdropper
    local loot = GetLootAtHalfQuantity(lootdropper:GenerateLoot())
    if inst.components.health ~= nil and inst.components.health.is_corpsing then
        if inst.components.deathloothandler ~= nil then
            inst.components.deathloothandler:StoreLoot(loot)
        end
    else
        lootdropper:DropLoot(inst:GetPosition(), loot)
    end
end

local function SetRecorderScale(inst, scale)
    inst.kei_recorder_vault_scale = scale
    inst.Transform:SetScale(scale, scale, scale)

    if inst.DynamicShadow ~= nil then
        inst.DynamicShadow:SetSize(6 * scale, 3.5 * math.min(1, scale))
    end

    if inst.Physics ~= nil then
        local base_radius = inst.kei_recorder_vault_base_physics_radius or 1.6
        inst:SetPhysicsRadiusOverride(base_radius * scale)
        inst.Physics:SetCapsule(inst.physicsradiusoverride, 1)
    end

    if inst.components.combat ~= nil then
        local base_range = inst.kei_recorder_vault_base_attack_range or 5
        inst.components.combat:SetRange(base_range * scale)
    end
end

local function IsRecorderVaultAlly(inst, target)
    return target ~= nil
        and target ~= inst
        and target:IsValid()
        and target:HasTag("kei_recorder_vault_pillar_guard")
        and target.kei_recorder_source ~= nil
        and target.kei_recorder_source == inst.kei_recorder_source
end

local function InstallRecorderAllyRules(inst)
    local combat = inst.components.combat
    if combat == nil then
        return
    end

    -- The vanilla combat component uses a shared follower leader to identify
    -- allies. All entities in one recorder challenge use the recorder as that
    -- shared leader, without making the recorder itself a combatant.
    if inst.components.follower == nil then
        inst:AddComponent("follower")
    end
    inst.components.follower:SetLeader(inst.kei_recorder_source)

    local old_is_ally = combat.IsAlly
    local old_can_be_ally = combat.CanBeAlly
    local old_can_target = combat.CanTarget
    local old_can_be_attacked = combat.CanBeAttacked
    local old_get_attacked = combat.GetAttacked
    local old_set_target = combat.SetTarget

    combat.IsAlly = function(self, target)
        if IsRecorderVaultAlly(inst, target) then
            return true
        end
        return old_is_ally(self, target)
    end

    combat.CanBeAlly = function(self, target)
        if IsRecorderVaultAlly(inst, target) then
            return true
        end
        return old_can_be_ally(self, target)
    end

    combat.CanTarget = function(self, target)
        if IsRecorderVaultAlly(inst, target) then
            return false
        end
        return old_can_target(self, target)
    end

    combat.CanBeAttacked = function(self, attacker)
        if IsRecorderVaultAlly(inst, attacker) then
            return false
        end
        return old_can_be_attacked(self, attacker)
    end

    combat.GetAttacked = function(self, attacker, ...)
        if IsRecorderVaultAlly(inst, attacker) then
            return true
        end
        return old_get_attacked(self, attacker, ...)
    end

    combat.SetTarget = function(self, target)
        if IsRecorderVaultAlly(inst, target) then
            if self.target == target then
                self:DropTarget()
            end
            return
        end
        return old_set_target(self, target)
    end
end

local function FindNearestArenaPlayer(inst)
    local source = inst.kei_recorder_source
    local players = source ~= nil and RecorderBoss.GetArenaPlayers(source) or {}
    local closest
    local closest_dist = math.huge
    local x, y, z = inst.Transform:GetWorldPosition()

    for _, player in ipairs(players) do
        local px, py, pz = player.Transform:GetWorldPosition()
        local dx, dz = px - x, pz - z
        local distance = dx * dx + dz * dz
        if distance < closest_dist then
            closest = player
            closest_dist = distance
        end
    end
    return closest
end

local function IsArenaPlayerTarget(inst, target)
    if target == nil
        or not target:IsValid()
        or not target:HasTag("player")
        or target:HasTag("playerghost")
        or target.components == nil
        or target.components.health == nil
        or target.components.health:IsDead()
    then
        return false
    end

    for _, player in ipairs(RecorderBoss.GetArenaPlayers(inst.kei_recorder_source)) do
        if player == target then
            return true
        end
    end
    return false
end

local function RecorderRetargetFn(inst)
    local target = inst.components.combat.target
    if IsArenaPlayerTarget(inst, target) then
        return target
    end
    return FindNearestArenaPlayer(inst)
end

local function RecorderKeepTargetFn(inst, target)
    return IsArenaPlayerTarget(inst, target)
end

local function SetRecorderPlayerTarget(inst)
    if inst.components.combat == nil then
        return
    end

    local target = FindNearestArenaPlayer(inst)
    if target ~= nil then
        inst.components.combat:SetTarget(target)
    elseif inst.kei_recorder_source ~= nil
        and inst.kei_recorder_source.kei_recording_owner ~= nil
        and inst.components.combat:CanTarget(inst.kei_recorder_source.kei_recording_owner)
    then
        inst.components.combat:SetTarget(inst.kei_recorder_source.kei_recording_owner)
    end
end

local function IsStateActive(state)
    return state ~= nil
        and not state.cleanup
        and state.source ~= nil
        and state.source:IsValid()
        and state.source.kei_state == "recording"
end

local SpawnSplitChildren

local function ScheduleCompletion(state)
    if state.completion_task ~= nil or state.completed then
        return
    end

    state.completion_task = state.source:DoTaskInTime(COMPLETION_DELAY, function(source)
        state.completion_task = nil
        if state.completed or not IsStateActive(state) or state.final_count ~= 0 then
            return
        end

        state.completed = true
        if source.kei_target_complete_fn ~= nil then
            source.kei_target_complete_fn()
        end
    end)
end

local function OnFinalDeath(inst)
    if inst.kei_recorder_vault_counted_death
        or inst.kei_recorder_cleanup
    then
        return
    end

    inst.kei_recorder_vault_counted_death = true
    local state = inst.kei_recorder_vault_state
    if not IsStateActive(state) or state.final_count <= 0 then
        return
    end

    state.final_count = state.final_count - 1
    if state.final_count == 0 then
        ScheduleCompletion(state)
    end
end

local function BeginSplit(inst)
    if inst.kei_recorder_vault_split_started
        or inst.kei_recorder_cleanup
        or inst.kei_recorder_vault_generation >= MAX_SPLIT_GENERATION
    then
        return
    end

    inst.kei_recorder_vault_split_started = true
    if inst.components.health ~= nil then
        inst.components.health:SetInvincible(true)
        inst.components.health:SetMinHealth(1)
    end

    if inst.components.combat ~= nil then
        inst.components.combat:DropTarget()
    end

    inst.sg:GoToState("death")
    inst.kei_recorder_vault_split_task = inst:DoTaskInTime(SPLIT_DELAY, function(parent)
        inst.kei_recorder_vault_split_task = nil
        if parent:IsValid() and not parent.kei_recorder_cleanup then
            SpawnSplitChildren(parent)
        end
    end)
end

local function WrapHalfHealthTrigger(inst)
    local healthtrigger = inst.components.healthtrigger
    if healthtrigger == nil or healthtrigger.triggers == nil then
        return
    end

    local original_trigger = healthtrigger.triggers[0.5]
    healthtrigger.triggers[0.5] = function(entity)
        if original_trigger ~= nil then
            original_trigger(entity)
        end
        BeginSplit(entity)
    end
end

local function ConfigureEntity(inst, state, generation, scale)
    inst.kei_recorder_vault_state = state
    inst.kei_recorder_vault_generation = generation
    inst.kei_recorder_vault_split_started = false
    inst.kei_recorder_source = state.source
    inst.kei_recorder_spawned = true
    inst.persists = false
    inst.kei_recorder_vault_base_physics_radius = inst.physicsradiusoverride or 1.6
    inst.kei_recorder_vault_base_attack_range = TUNING.VAULT_PILLAR_GUARD_ATTACK_RANGE or 5

    if inst.components.health ~= nil then
        local max_health = ROOT_HEALTH / (2 ^ generation)
        inst.components.health:SetMaxHealth(max_health)
        inst.components.health:SetMinHealth(generation < MAX_SPLIT_GENERATION and 1 or 0)
        inst.components.health:SetInvincible(false)
    end

    SetRecorderScale(inst, scale)
    RecorderBoss.Apply(inst, state.source)
    InstallRecorderAllyRules(inst)

    if inst.components.combat ~= nil then
        inst.components.combat:SetRetargetFunction(1, RecorderRetargetFn)
        inst.components.combat:SetKeepTargetFunction(RecorderKeepTargetFn)
        SetRecorderPlayerTarget(inst)
    end

    if generation < MAX_SPLIT_GENERATION then
        WrapHalfHealthTrigger(inst)
    else
        state.final_count = state.final_count + 1
        inst:ListenForEvent("death", OnFinalDeath)
    end

    inst:ListenForEvent("onremove", function(entity)
        if entity.kei_recorder_vault_split_task ~= nil then
            entity.kei_recorder_vault_split_task:Cancel()
            entity.kei_recorder_vault_split_task = nil
        end
    end)
end

SpawnSplitChildren = function(parent)
    local state = parent.kei_recorder_vault_state
    if not IsStateActive(state) then
        return
    end

    local generation = parent.kei_recorder_vault_generation + 1
    local scale = SPLIT_SCALES[generation + 1]
    local x, y, z = parent.Transform:GetWorldPosition()
    local base_angle = math.random() * TWOPI

    for i = 1, 2 do
        local child = SpawnPrefab("kei_recorder_vault_pillar_guard")
        if child ~= nil then
            ConfigureEntity(child, state, generation, scale)
            RegisterSupport(state.source, child)

            local angle = base_angle + (i == 1 and 0 or PI)
            if child.Physics ~= nil then
                child:StopBrain("kei_recorder_vault_pillar_launch")
                child.Physics:Teleport(x, 0.1, z)
                Launch2(
                    child,
                    parent,
                    SPLIT_LAUNCH_SPEED,
                    0,
                    0.1,
                    0,
                    SPLIT_LAUNCH_HEIGHT,
                    angle / DEGREES
                )
                child.kei_recorder_vault_launch_task = child:DoTaskInTime(
                    SPLIT_LAUNCH_BRAIN_LOCK_TIME,
                    function(launched)
                        launched.kei_recorder_vault_launch_task = nil
                        if launched:IsValid() then
                            launched:RestartBrain("kei_recorder_vault_pillar_launch")
                        end
                    end
                )
            else
                child.Transform:SetPosition(x, 0, z)
            end
        end
    end

    -- The parent only exists to play the split death animation. Once the
    -- children have been launched it must be removed explicitly; the vanilla
    -- death state is not a reliable cleanup boundary for this custom flow.
    if parent:IsValid() then
        parent.kei_recorder_cleanup = true
        parent:Remove()
    end
end

function RecorderVaultPillarGuard.Apply(inst, source)
    local state = {
        source = source,
        root = inst,
        final_count = 0,
        completed = false,
        cleanup = false,
    }
    source.kei_recorder_vault_pillar_guard_state = state
    ConfigureEntity(inst, state, 0, 1)
end

function RecorderVaultPillarGuard.Remove(inst)
    if inst == nil then
        return
    end

    local state = inst.kei_recorder_vault_state
    if state ~= nil then
        state.cleanup = true
        if state.completion_task ~= nil then
            state.completion_task:Cancel()
            state.completion_task = nil
        end
        if state.source ~= nil
            and state.source.kei_recorder_vault_pillar_guard_state == state
        then
            state.source.kei_recorder_vault_pillar_guard_state = nil
        end
    end

    if inst.kei_recorder_vault_split_task ~= nil then
        inst.kei_recorder_vault_split_task:Cancel()
        inst.kei_recorder_vault_split_task = nil
    end
end

function RecorderVaultPillarGuard.Initialize(inst)
    -- Reuse the vanilla death state for visuals while controlling its loot.
    inst.DropDeathLoot = DropRecorderLoot
end

return RecorderVaultPillarGuard
