-- 旋翼调查仪光束的服务器端效果。
local KeiTimeScale = require("kei/time_scale")
local MiniAlice = require("kei/mini_alice")
local LifeProtocolDefs = require("kei/protocols/life")
local RotorSurveyTargets = require("kei/rotor_survey_targets")

local KeiRotorBeam = Class(function(self, inst)
    self.inst = inst
    self.beam_name = nil
    self.drone = nil
    self.owner = nil
    self.task = nil
    self.players = {}
    self.enemies = {}
    self.teleport_portal = nil
    self.teleport_portal_follow_task = nil
    self.survey_targets = {}
    self.revive_target = nil
    self.revive_elapsed = 0
    self.heal_elapsed = 0
    self.friendly_elapsed = TUNING.KEI_ROTOR_FRIENDLY_CLEAR_PERIOD or 5
end)

local PLAYER_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost", "notarget" }
local GHOST_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "notarget" }
local ENEMY_CANT_TAGS = {
    "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost",
    "companion", "flight", "invisible", "notarget", "noattack",
}
local COLLECT_CANT_TAGS = {
    "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost",
}
local FISHING_CANT_TAGS = {
    -- Keep this separate from the combat exclusion list so ocean fish are
    -- not filtered by tags that are unrelated to fishing.
    "INLIMBO", "FX", "DECOR", "player", "playerghost",
}
-- Survey targets may be non-clickable or decorative world entities (for
-- example the oasis lake), so do not exclude NOCLICK/DECOR here.
local SURVEY_CANT_TAGS = { "INLIMBO", "FX" }
local NATURE_CROP_MUST_TAGS = { "farm_plant" }
local FRIENDLY_PLAYER_MUST_TAGS = { "player" }

local STRENGTHEN_DAMAGE_KEY = "kei_rotor_strengthen"
local CONFINEMENT_SPEED_KEY = "kei_rotor_confinement"

local function IsValid(inst)
    return inst ~= nil and inst:IsValid() and not inst:IsInLimbo()
end

local function IsValidShieldSource(inst)
    -- The controller is normally held in an inventory slot and may be in
    -- limbo while it is still the active source of the beam.
    return inst ~= nil and inst:IsValid()
end

local function IsInRange(origin, target, radius)
    if not IsValid(origin) or not IsValid(target) then
        return false
    end

    local x, y, z = origin.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    local target_radius = target.GetPhysicsRadius ~= nil and target:GetPhysicsRadius(0) or 0
    local distance = radius + math.max(0, target_radius)
    return math2d.DistSq(x, z, tx, tz) <= distance * distance
end

local function RemovePlayerModifiers(source, target)
    if not IsValid(target) then
        return
    end

    if target.components.combat ~= nil then
        target.components.combat.externaldamagemultipliers:RemoveModifier(source, STRENGTHEN_DAMAGE_KEY)
    end
    if target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(source, CONFINEMENT_SPEED_KEY)
    end
end

local function ApplyConfinement(source, target)
    local multiplier = TUNING.KEI_ROTOR_CONFINEMENT_ANIM_MULT
        or TUNING.KEI_ROTOR_CONFINEMENT_SPEED_MULT
        or 0.5

    if target.components.locomotor ~= nil then
        target.components.locomotor:SetExternalSpeedMultiplier(
            source,
            CONFINEMENT_SPEED_KEY,
            TUNING.KEI_ROTOR_CONFINEMENT_SPEED_MULT or 0.5
        )
    end

    KeiTimeScale.Add(target, source, multiplier)
end

local function RemoveConfinement(source, target)
    if target == nil then
        return
    end

    if target.components ~= nil and target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(source, CONFINEMENT_SPEED_KEY)
    end

    KeiTimeScale.Remove(target, source)
end

local function IsRecentAttacker(attacker, target)
    local combat = attacker ~= nil and attacker.components ~= nil and attacker.components.combat or nil
    if combat == nil or combat.lastattacker ~= target or combat.lastwasattackedtime == nil then
        return false
    end

    return GetTime() - combat.lastwasattackedtime
        <= (TUNING.KEI_ROTOR_FRIENDLY_RETALIATION_WINDOW or 1)
end

local function InstallFriendlySource(source, target)
    local combat = target.components ~= nil and target.components.combat or nil
    if combat == nil then
        return
    end

    local sources = target._kei_rotor_friendly_sources
    if sources == nil then
        sources = {}
        target._kei_rotor_friendly_sources = sources
        target._kei_rotor_friendly_old_shouldavoidaggrofn = combat.shouldavoidaggrofn
        target._kei_rotor_friendly_shouldavoidaggrofn = function(attacker, player)
            local oldfn = target._kei_rotor_friendly_old_shouldavoidaggrofn
            local old_allowed = oldfn == nil or oldfn(attacker, player) ~= false
            return old_allowed and IsRecentAttacker(attacker, player)
        end
        combat.shouldavoidaggrofn = target._kei_rotor_friendly_shouldavoidaggrofn
    end
    sources[source] = true
end

local function RemoveFriendlySource(source, target)
    local sources = target ~= nil and target._kei_rotor_friendly_sources or nil
    if sources == nil then
        return
    end

    sources[source] = nil
    if next(sources) ~= nil then
        return
    end

    local combat = target.components ~= nil and target.components.combat or nil
    if combat ~= nil
        and combat.shouldavoidaggrofn == target._kei_rotor_friendly_shouldavoidaggrofn
    then
        combat.shouldavoidaggrofn = target._kei_rotor_friendly_old_shouldavoidaggrofn
    end
    target._kei_rotor_friendly_sources = nil
    target._kei_rotor_friendly_old_shouldavoidaggrofn = nil
    target._kei_rotor_friendly_shouldavoidaggrofn = nil
end

local function SpawnShieldPulse(target)
    if not IsValid(target) then
        return
    end

    local fx = SpawnPrefab("kei_rook_shield_pulse_fx")
    if fx == nil then
        return
    end

    -- Parent the pulse to the protected player so the complete animation
    -- follows movement instead of remaining at the hit position.
    fx.entity:SetParent(target.entity)
    fx.Transform:SetPosition(0, 1.5, 0)
    fx.Transform:SetRotation(0)
end

local function ConsumeShield(sources, target)
    for shield_source, state in pairs(sources) do
        -- The source is the controller entity. It can be in an inventory
        -- container/limbo while the beam remains active, so the active beam
        -- state is authoritative here. Stop() removes stale sources.
        if state.charged then
            state.charged = false
            state.ready_at = GetTime() + (TUNING.KEI_ROTOR_STRENGTHEN_SHIELD_COOLDOWN or 5)
            SpawnShieldPulse(target)
            return true
        end
    end
    return false
end

local function RemoveShieldSource(source, target)
    local sources = target ~= nil and target._kei_rotor_beam_shield_sources or nil
    if sources == nil then
        return
    end

    sources[source] = nil
    if next(sources) ~= nil then
        return
    end

    local health = target.components ~= nil and target.components.health or nil
    if health ~= nil
        and target._kei_rotor_beam_shield_hook ~= nil
        and health.deltamodifierfn == target._kei_rotor_beam_shield_hook
    then
        health.deltamodifierfn = target._kei_rotor_beam_shield_oldfn
    end
    if health ~= nil
        and target._kei_rotor_beam_shield_dodelta_hook ~= nil
        and health.DoDelta == target._kei_rotor_beam_shield_dodelta_hook
    then
        health.DoDelta = target._kei_rotor_beam_shield_old_dodelta
    end
    local combat = target.components ~= nil and target.components.combat or nil
    if combat ~= nil
        and target._kei_rotor_beam_shield_combat_hook ~= nil
        and combat.GetAttacked == target._kei_rotor_beam_shield_combat_hook
    then
        combat.GetAttacked = target._kei_rotor_beam_shield_old_combat_getattacked
    end
    target._kei_rotor_beam_shield_sources = nil
    target._kei_rotor_beam_shield_hook = nil
    target._kei_rotor_beam_shield_oldfn = nil
    target._kei_rotor_beam_shield_dodelta_hook = nil
    target._kei_rotor_beam_shield_old_dodelta = nil
    target._kei_rotor_beam_shield_combat_hook = nil
    target._kei_rotor_beam_shield_old_combat_getattacked = nil
end

local function InstallShieldSource(source, target)
    local health = target.components ~= nil and target.components.health or nil
    if health == nil then
        return
    end

    local sources = target._kei_rotor_beam_shield_sources
    if sources == nil then
        sources = {}
        target._kei_rotor_beam_shield_sources = sources
        target._kei_rotor_beam_shield_oldfn = health.deltamodifierfn
        target._kei_rotor_beam_shield_hook = function(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
            local oldfn = target._kei_rotor_beam_shield_oldfn
            if oldfn ~= nil then
                amount = oldfn(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
            end

            if type(amount) == "number"
                and amount < 0
                and not ignore_absorb
                and afflicter ~= nil
            then
                if ConsumeShield(sources, target) then
                    return 0
                end
            end
            return amount
        end
        health.deltamodifierfn = target._kei_rotor_beam_shield_hook

        -- Most attacks eventually call Health:DoDelta, but some creatures
        -- bypass Combat:GetAttacked and damage health directly. Keep a
        -- second entry point so the one-shot shield covers both paths.
        target._kei_rotor_beam_shield_old_dodelta = health.DoDelta
        target._kei_rotor_beam_shield_dodelta_hook = function(component, amount, ...)
            local args = { ... }
            local overtime = args[1]
            local ignore_invincible = args[3]
            local afflicter = args[4]
            local ignore_absorb = args[5]
            if type(amount) == "number"
                and amount < 0
                and not overtime
                and afflicter ~= nil
                and not ignore_absorb
                and ConsumeShield(sources, target)
            then
                return 0
            end
            return target._kei_rotor_beam_shield_old_dodelta(component, amount, ...)
        end
        health.DoDelta = target._kei_rotor_beam_shield_dodelta_hook

        local combat = target.components ~= nil and target.components.combat or nil
        if combat ~= nil then
            target._kei_rotor_beam_shield_old_combat_getattacked = combat.GetAttacked
            target._kei_rotor_beam_shield_combat_hook = function(component, attacker, damage, weapon, stimuli, spdamage, ...)
                local has_damage = type(damage) == "number" and damage > 0
                local has_special_damage = spdamage ~= nil
                if (has_damage or has_special_damage)
                    and ConsumeShield(sources, target)
                then
                    return 0
                end

                return target._kei_rotor_beam_shield_old_combat_getattacked(
                    component,
                    attacker,
                    damage,
                    weapon,
                    stimuli,
                    spdamage,
                    ...
                )
            end
            combat.GetAttacked = target._kei_rotor_beam_shield_combat_hook
        end
    end

    -- Refresh the outer combat hook if another system rebuilt GetAttacked
    -- while the beam remained active.
    local combat = target.components ~= nil and target.components.combat or nil
    if combat ~= nil
        and target._kei_rotor_beam_shield_combat_hook ~= nil
        and combat.GetAttacked ~= target._kei_rotor_beam_shield_combat_hook
    then
        target._kei_rotor_beam_shield_old_combat_getattacked = combat.GetAttacked
        combat.GetAttacked = target._kei_rotor_beam_shield_combat_hook
    end

    -- Refresh the direct health hook as well. Other components may restore
    -- DoDelta while the beam is still active.
    if health.DoDelta ~= target._kei_rotor_beam_shield_dodelta_hook then
        target._kei_rotor_beam_shield_old_dodelta = health.DoDelta
        health.DoDelta = target._kei_rotor_beam_shield_dodelta_hook
    end

    local state = sources[source]
    if state == nil then
        state = { charged = true, ready_at = nil }
        sources[source] = state
    elseif not state.charged
        and state.ready_at ~= nil
        and GetTime() >= state.ready_at
    then
        state.charged = true
        state.ready_at = nil
    end
end

local function IsEnemyForOwner(owner, target)
    if target == nil
        or target.components == nil
        or target.components.health == nil
        or target.components.health:IsDead()
        or target.components.combat == nil
        or target:HasTag("player")
        or target:HasTag("playerghost")
    then
        return false
    end

    if owner ~= nil and owner.components ~= nil and owner.components.combat ~= nil then
        return owner.components.combat:CanTarget(target)
            and not owner.components.combat:IsAlly(target)
    end
    return true
end

local function FindEntitiesInRange(origin, radius, must_tags, cant_tags)
    if not IsValid(origin) then
        return {}
    end

    local x, y, z = origin.Transform:GetWorldPosition()
    return TheSim:FindEntities(x, y, z, radius + 3, must_tags, cant_tags)
end

local function GiveLifeProtocolCD(owner, protocol)
    local def = LifeProtocolDefs.LIFE_PROTOCOLS[protocol]
    if owner == nil
        or def == nil
        or def.implemented ~= true
        or LifeProtocolDefs.GetProtocolPrefab == nil
    then
        return false
    end

    local inventory = owner.components ~= nil and owner.components.inventory or nil
    local prefab = LifeProtocolDefs.GetProtocolPrefab(protocol)
    local cd = prefab ~= nil and SpawnPrefab(prefab) or nil
    if cd == nil then
        return false
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local position = Vector3(x, y, z)
    if inventory ~= nil and inventory:GiveItem(cd, nil, position) then
        return true
    end

    -- Keep the reward if all eligible containers are full. GiveItem may have
    -- rejected the item without changing its owner, so it is still safe to
    -- turn it into a ground drop here.
    if cd.components ~= nil and cd.components.inventoryitem ~= nil then
        cd.Transform:SetPosition(x, y, z)
        cd.components.inventoryitem:OnDropped(true)
        return true
    end

    if cd:IsValid() then
        cd:Remove()
    end
    return false
end

function KeiRotorBeam:_UpdateSurvey(dt)
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local skills = self.owner ~= nil
        and self.owner.components ~= nil
        and self.owner.components.kei_rotor_skills
        or nil
    local found = {}

    if skills == nil then
        self.survey_targets = found
        return
    end

    for _, target in ipairs(FindEntitiesInRange(self.drone, radius, nil, SURVEY_CANT_TAGS)) do
        if IsInRange(self.drone, target, radius) then
            local definition = RotorSurveyTargets.Find(target, self.owner)
            if definition ~= nil
                and skills:CanSurvey(definition.protocol)
            then
                local progress = self.survey_targets[target]
                if progress == nil or progress.id ~= definition.id then
                    progress = {
                        id = definition.id,
                        elapsed = 0,
                    }
                    self.survey_targets[target] = progress
                end

                found[target] = true
                progress.elapsed = progress.elapsed + (dt or 0)
                if progress.elapsed >= (TUNING.KEI_ROTOR_SURVEY_DURATION or 3) then
                    if GiveLifeProtocolCD(self.owner, definition.protocol) then
                        skills:StartSurveyCooldown(
                            definition.protocol,
                            TUNING.KEI_ROTOR_SURVEY_PROTOCOL_COOLDOWN or 40 * 60
                        )
                        if self.owner.components.talker ~= nil then
                            self.owner.components.talker:Say(
                                STRINGS.CHARACTERS.KEI.ANNOUNCE_KEI_ROTOR_SURVEY_COMPLETE
                                    or "Survey complete."
                            )
                        end
                    end
                    self.survey_targets[target] = nil
                end
            end
        end
    end

    for target in pairs(self.survey_targets) do
        if not found[target] then
            self.survey_targets[target] = nil
        end
    end
end

local function ClearFriendlyTargets(drone, players, radius)
    for _, target in ipairs(FindEntitiesInRange(drone, radius, { "_combat" }, ENEMY_CANT_TAGS)) do
        local combat = target.components ~= nil and target.components.combat or nil
        if combat ~= nil
            and combat.target ~= nil
            and players[combat.target]
        then
            combat:DropTarget()
        end
    end
end

local function SpawnCollectEffect(x, y, z)
    local fx = SpawnPrefab("sand_puff")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
    end
end

local function IsGroundItem(item)
    if not IsValid(item)
        or item.components == nil
        or item.components.inventoryitem == nil
    then
        return false
    end

    local inventoryitem = item.components.inventoryitem
    return inventoryitem.owner == nil
        and inventoryitem.cangoincontainer
end

local function AddLootCount(counts, prefab)
    if type(prefab) == "string" and prefab ~= "" then
        counts[prefab] = (counts[prefab] or 0) + 1
    end
end

local function GetAccessibleAliceSlotLimit(container, owner)
    if container == nil or owner == nil or container.GetNumSlots == nil then
        return 0
    end
    return math.min(
        container:GetNumSlots(),
        MiniAlice.GetAccessibleSlotCount(owner)
    )
end

local function GiveItemToMiniAlice(container, item, owner, src_pos)
    if container == nil or item == nil or not item:IsValid() then
        return false
    end

    local slot_limit = GetAccessibleAliceSlotLimit(container, owner)
    if slot_limit <= 0 then
        return false
    end

    local collected = false
    while item:IsValid() do
        local stackable = item.components ~= nil and item.components.stackable or nil
        local stack_slot = nil
        local stack_room = 0

        if stackable ~= nil then
            for slot = 1, slot_limit do
                local stored = container:GetItemInSlot(slot)
                if stored ~= nil
                    and stored.components ~= nil
                    and stored.components.stackable ~= nil
                    and stored.components.stackable:CanStackWith(item)
                    and not stored.components.stackable:IsFull()
                then
                    stack_slot = slot
                    stack_room = stored.components.stackable:RoomLeft()
                    break
                end
            end
        end

        if stack_slot ~= nil and stack_room > 0 then
            local item_count = stackable:StackSize()
            local put_count = math.min(item_count, math.floor(stack_room))
            local put_item = item
            local split_item = nil
            if put_count < item_count then
                split_item = stackable:Get(put_count)
                put_item = split_item
            end

            if container:GiveItem(put_item, stack_slot, src_pos, false) then
                collected = true
            else
                if split_item ~= nil and split_item:IsValid() then
                    split_item:Remove()
                    stackable:SetStackSize(stackable:StackSize() + put_count)
                end
                return collected
            end
        else
            local empty_slot = nil
            for slot = 1, slot_limit do
                if container:GetItemInSlot(slot) == nil
                    and container:CanTakeItemInSlot(item, slot)
                then
                    empty_slot = slot
                    break
                end
            end

            if empty_slot == nil then
                return collected
            end

            if container:GiveItem(item, empty_slot, src_pos, false) then
                return true
            end
            return collected
        end
    end

    return collected
end

local function GetOversizedLootCounts(item)
    local lootdropper = item.components ~= nil and item.components.lootdropper or nil
    if lootdropper == nil or lootdropper.GenerateLoot == nil then
        return nil
    end

    local counts = {}
    for _, prefab in ipairs(lootdropper:GenerateLoot() or {}) do
        AddLootCount(counts, prefab)
    end
    return next(counts) ~= nil and counts or nil
end

local function CanReceiveCollectedLoot(container, counts, owner)
    if container == nil or counts == nil or container.CanTakeItemInSlot == nil then
        return false
    end

    local slot_limit = GetAccessibleAliceSlotLimit(container, owner)
    local reserved_slots = {}
    for prefab, count in pairs(counts) do
        local preview = SpawnPrefab(prefab)
        if preview == nil or preview.components == nil or preview.components.inventoryitem == nil then
            if preview ~= nil and preview:IsValid() then
                preview:Remove()
            end
            return false
        end

        if preview.components.stackable == nil and count > 1 then
            preview:Remove()
            return false
        end

        local remaining = count
        if preview.components.stackable ~= nil then
            for slot = 1, slot_limit do
                local stored = container:GetItemInSlot(slot)
                if stored ~= nil
                    and stored.components ~= nil
                    and stored.components.stackable ~= nil
                    and stored.components.stackable:CanStackWith(preview)
                then
                    remaining = remaining - stored.components.stackable:RoomLeft()
                    if remaining <= 0 then
                        break
                    end
                end
            end
        end

        if remaining > 0 then
            local found_slot = nil
            for slot = 1, slot_limit do
                if not reserved_slots[slot]
                    and container:GetItemInSlot(slot) == nil
                    and container:CanTakeItemInSlot(preview, slot)
                then
                    found_slot = slot
                    break
                end
            end
            if found_slot == nil then
                preview:Remove()
                return false
            end
            reserved_slots[found_slot] = true
        end

        preview:Remove()
    end
    return true
end

local function PutCollectedLoot(container, counts, owner, x, y, z)
    for prefab, count in pairs(counts) do
        local loot = SpawnPrefab(prefab)
        if loot == nil then
            return false
        end

        if loot.components ~= nil and loot.components.stackable ~= nil then
            loot.components.stackable:SetStackSize(count)
        elseif count > 1 then
            loot:Remove()
            return false
        end

        if not GiveItemToMiniAlice(container, loot, owner, Vector3(x, y, z)) then
            -- This is only a defensive fallback for a container hook changing
            -- between the capacity check and insertion. Do not lose the loot.
            loot.Transform:SetPosition(x, y, z)
            if loot.components ~= nil and loot.components.inventoryitem ~= nil then
                loot.components.inventoryitem:OnDropped(true)
            end
            return false
        end
    end
    return true
end

local function IsCollectibleOversized(item)
    local workable = item ~= nil and item.components ~= nil and item.components.workable or nil
    return IsValid(item)
        and item:HasTag("oversized_veggie")
        and item.components.inventoryitem ~= nil
        and item.components.inventoryitem.owner == nil
        and workable ~= nil
        and workable:GetWorkAction() == ACTIONS.HAMMER
        and workable:CanBeWorked()
end

local function CollectOversizedVeggie(container, item, owner)
    local counts = GetOversizedLootCounts(item)
    if counts == nil then
        return false
    end

    local x, y, z = item.Transform:GetWorldPosition()
    if not CanReceiveCollectedLoot(container, counts, owner) then
        return false
    end

    -- Use the vanilla lootdropper table, but skip WorkedBy/DropLoot so no
    -- intermediate loot entities are created on the ground.
    item:Remove()
    PutCollectedLoot(container, counts, owner, x, y, z)
    SpawnCollectEffect(x, y, z)
    return true
end

local function CollectGroundItem(container, item, owner)
    if not IsGroundItem(item) or IsCollectibleOversized(item) then
        return false
    end

    local x, y, z = item.Transform:GetWorldPosition()
    local stacksize = item.components.stackable ~= nil
        and item.components.stackable:StackSize()
        or 1
    local success = GiveItemToMiniAlice(container, item, owner, Vector3(x, y, z))
    local collected = success
        or not item:IsValid()
        or item.components.inventoryitem.owner == container.inst
        or (item.components.stackable ~= nil
            and item.components.stackable:StackSize() < stacksize)
    if collected then
        SpawnCollectEffect(x, y, z)
    end
    return collected
end

function KeiRotorBeam:_UpdateCollect()
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local container = MiniAlice.GetContainer(self.owner)
    if container == nil then
        return
    end

    for _, item in ipairs(FindEntitiesInRange(self.drone, radius, nil, COLLECT_CANT_TAGS)) do
        if IsInRange(self.drone, item, radius) then
            if IsCollectibleOversized(item) then
                CollectOversizedVeggie(container, item, self.owner)
            else
                CollectGroundItem(container, item, self.owner)
            end
        end
    end
end

local function IsOceanTarget(target)
    return IsValid(target)
        and target.IsOnOcean ~= nil
        and target:IsOnOcean(false)
end

local function LaunchFishAtOwner(target, owner)
    local oceanfishable = target.components ~= nil and target.components.oceanfishable or nil
    if oceanfishable == nil
        or not target:HasTag("oceanfish")
        or target:HasTag("activeprojectile")
        or target.components.complexprojectile ~= nil
        or not IsOceanTarget(target)
    then
        return false
    end

    if target.components.weighable ~= nil then
        target.components.weighable:SetPlayerAsOwner(owner)
    end

    local projectile = oceanfishable:MakeProjectile()
    local complexprojectile = projectile ~= nil
        and projectile.components ~= nil
        and projectile.components.complexprojectile
        or nil
    if complexprojectile == nil then
        return false
    end

    complexprojectile:SetHorizontalSpeed(16)
    complexprojectile:SetGravity(-30)
    complexprojectile:SetLaunchOffset(Vector3(0, 0.5, 0))
    complexprojectile:SetTargetOffset(Vector3(0, 0.5, 0))
    complexprojectile:Launch(owner:GetPosition(), projectile, complexprojectile.owningweapon)
    return true
end

function KeiRotorBeam:_UpdateFishing()
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    if not IsValid(self.owner) then
        return
    end

    for _, target in ipairs(FindEntitiesInRange(self.drone, radius, nil, FISHING_CANT_TAGS)) do
        if IsInRange(self.drone, target, radius) then
            if target.components ~= nil and target.components.oceanfishable ~= nil then
                LaunchFishAtOwner(target, self.owner)
            end
        end
    end
end

local function IsFarmCrop(target)
    -- Restrict this beam to crops created by the modern farm planting
    -- system. A generic growable is not enough: trees and wild plants also
    -- use that component.
    return IsValid(target)
        and target:HasTag("farm_plant")
        and target.components ~= nil
        and target.components.farmplanttendable ~= nil
        and target.components.growable ~= nil
end

local function AccelerateFarmCrop(target)
    if not IsFarmCrop(target) then
        return
    end

    local growable = target.components.growable
    local remaining = growable.pausedremaining
    if remaining == nil and growable.targettime ~= nil then
        remaining = growable.targettime - GetTime()
    end

    local desired = TUNING.KEI_ROTOR_NATURE_GROW_REMAINING_TIME or 15
    if remaining ~= nil and remaining > desired then
        growable:ExtendGrowTime(desired - remaining)
    end
end

local function RestoreFarmSoil(x, y, z, radius)
    if TheWorld == nil
        or TheWorld.Map == nil
        or TheWorld.components == nil
        or TheWorld.components.farming_manager == nil
    then
        return
    end

    local farming_manager = TheWorld.components.farming_manager
    local min_tile_x, min_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x - radius, 0, z - radius)
    local max_tile_x, max_tile_z = TheWorld.Map:GetTileCoordsAtPoint(x + radius, 0, z + radius)

    -- Iterate map tiles instead of sampling every world unit. This updates
    -- each farm tile once per scan while keeping the beam circular.
    for tile_x = min_tile_x, max_tile_x do
        for tile_z = min_tile_z, max_tile_z do
            local tile_world_x, tile_world_y, tile_world_z =
                TheWorld.Map:GetTileCenterPoint(tile_x, tile_z)
            local dx = tile_world_x - x
            local dz = tile_world_z - z
            if dx * dx + dz * dz <= radius * radius
                and TheWorld.Map:GetTileAtPoint(tile_world_x, tile_world_y, tile_world_z)
                    == WORLD_TILES.FARMING_SOIL
            then
                farming_manager:SetTileNutrients(tile_x, tile_z, 100, 100, 100)
                farming_manager:AddSoilMoistureAtPoint(
                    tile_world_x,
                    tile_world_y,
                    tile_world_z,
                    100
                )
            end
        end
    end
end

function KeiRotorBeam:_UpdateNature()
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local x, y, z = self.drone.Transform:GetWorldPosition()

    RestoreFarmSoil(x, y, z, radius)

    for _, crop in ipairs(FindEntitiesInRange(self.drone, radius, NATURE_CROP_MUST_TAGS, nil)) do
        if IsInRange(self.drone, crop, radius) then
            AccelerateFarmCrop(crop)
        end
    end
end

function KeiRotorBeam:_UpdateFriendly(dt)
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local found = {}

    for _, target in ipairs(FindEntitiesInRange(self.drone, radius, FRIENDLY_PLAYER_MUST_TAGS, PLAYER_CANT_TAGS)) do
        if IsInRange(self.drone, target, radius)
            and target.components ~= nil
            and target.components.health ~= nil
            and not target.components.health:IsDead()
        then
            found[target] = true
            InstallFriendlySource(self.inst, target)
        end
    end

    local old_players = {}
    for target in pairs(self.players) do
        old_players[#old_players + 1] = target
    end
    for _, target in ipairs(old_players) do
        if not found[target] then
            self:_ClearPlayer(target)
        end
    end
    self.players = found

    self.friendly_elapsed = self.friendly_elapsed + (dt or 0)
    local clear_period = TUNING.KEI_ROTOR_FRIENDLY_CLEAR_PERIOD or 5
    if self.friendly_elapsed >= clear_period then
        self.friendly_elapsed = 0
        ClearFriendlyTargets(self.drone, found, radius)
    end
end

local function IsShadowCreature(target)
    if target:HasTag("shadowcreature")
        or target:HasTag("shadow")
        or target:HasTag("stalker")
        or target:HasTag("stalker_minion")
    then
        return true
    end

    return target.prefab == "nightmarebeak"
        or target.prefab == "crawlinghorror"
        or target.prefab == "terrorbeak"
        or target.prefab == "stalker"
        or target.prefab == "stalker_minion"
        or target.prefab == "shadowthrall_horns"
        or target.prefab == "shadowthrall_wings"
        or target.prefab == "shadowthrall_hand"
end

function KeiRotorBeam:_ClearPlayer(target)
    RemovePlayerModifiers(self.inst, target)
    RemoveShieldSource(self.inst, target)
    RemoveFriendlySource(self.inst, target)
    self.players[target] = nil
end

function KeiRotorBeam:_ClearEnemy(target)
    RemoveConfinement(self.inst, target)
    self.enemies[target] = nil
end

function KeiRotorBeam:_EnsureTeleportPortal()
    if self.teleport_portal ~= nil and self.teleport_portal:IsValid() then
        if self.teleport_portal_follow_task == nil then
            self.teleport_portal_follow_task = self.inst:DoPeriodicTask(FRAMES, function()
                self:_UpdateTeleportPortalPosition()
            end)
        end
        return self.teleport_portal
    end

    if self.teleport_portal_follow_task ~= nil then
        self.teleport_portal_follow_task:Cancel()
        self.teleport_portal_follow_task = nil
    end
    self.teleport_portal = nil
    if not IsValid(self.drone) or not IsValid(self.owner) or TheShard == nil then
        return nil
    end

    local portal = SpawnPrefab("pocketwatch_portal_entrance")
    if portal == nil
        or portal.components == nil
        or portal.components.teleporter == nil
    then
        if portal ~= nil and portal:IsValid() then
            portal:Remove()
        end
        return nil
    end

    local x, _, z = self.drone.Transform:GetWorldPosition()
    local owner_x, _, owner_z = self.owner.Transform:GetWorldPosition()
    portal.Transform:SetPosition(x, 0, z)
    portal:SpawnExit(TheShard:GetShardId(), owner_x, 0, owner_z)
    self.teleport_portal = portal

    -- The beam's range scan runs at a lower frequency. Keep the portal's
    -- visual/teleport position independent from that scan so it follows a
    -- moving drone without visible stepping.
    if self.teleport_portal_follow_task == nil then
        self.teleport_portal_follow_task = self.inst:DoPeriodicTask(FRAMES, function()
            self:_UpdateTeleportPortalPosition()
        end)
    end

    return portal
end

function KeiRotorBeam:_UpdateTeleportPortalPosition()
    local portal = self.teleport_portal
    if portal == nil
        or not portal:IsValid()
        or not IsValid(self.drone)
    then
        if self.teleport_portal_follow_task ~= nil then
            self.teleport_portal_follow_task:Cancel()
            self.teleport_portal_follow_task = nil
        end
        return false
    end

    local x, _, z = self.drone.Transform:GetWorldPosition()
    portal.Transform:SetPosition(x, 0, z)
    return true
end

function KeiRotorBeam:_RefreshTeleportPortal()
    local portal = self.teleport_portal
    if portal == nil
        or not portal:IsValid()
        or not IsValid(self.drone)
        or not IsValid(self.owner)
    then
        return false
    end

    self:_UpdateTeleportPortalPosition()

    local teleporter = portal.components ~= nil and portal.components.teleporter or nil
    local exit = teleporter ~= nil and teleporter.targetTeleporter or nil
    if exit ~= nil and exit:IsValid() then
        local owner_x, _, owner_z = self.owner.Transform:GetWorldPosition()
        exit.Transform:SetPosition(owner_x, 0, owner_z)
    end

    -- The vanilla entrance has a ten-second safety timer. Keep it alive while
    -- the beam still detects players, without replacing its close animation.
    local timer = portal.components ~= nil and portal.components.timer or nil
    if timer ~= nil and timer:TimerExists("closeportal") then
        timer:SetTimeLeft("closeportal", 10)
    end
    return true
end

function KeiRotorBeam:_CloseTeleportPortal()
    local portal = self.teleport_portal
    self.teleport_portal = nil

    if self.teleport_portal_follow_task ~= nil then
        self.teleport_portal_follow_task:Cancel()
        self.teleport_portal_follow_task = nil
    end

    if portal == nil or not portal:IsValid() then
        return
    end

    local timer = portal.components ~= nil and portal.components.timer or nil
    if timer ~= nil then
        if timer:TimerExists("closeportal") then
            timer:SetTimeLeft("closeportal", 0)
        else
            timer:StartTimer("closeportal", 0)
        end
    else
        portal:Remove()
    end
end

function KeiRotorBeam:_ClearEffects()
    local players = {}
    for target in pairs(self.players) do
        players[#players + 1] = target
    end
    for _, target in ipairs(players) do
        self:_ClearPlayer(target)
    end
    local enemies = {}
    for target in pairs(self.enemies) do
        enemies[#enemies + 1] = target
    end
    for _, target in ipairs(enemies) do
        self:_ClearEnemy(target)
    end
    self:_CloseTeleportPortal()
    self.survey_targets = {}
    self.revive_target = nil
    self.revive_elapsed = 0
    self.heal_elapsed = 0
    self.friendly_elapsed = TUNING.KEI_ROTOR_FRIENDLY_CLEAR_PERIOD or 5
end

function KeiRotorBeam:_UpdateTeleport()
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local found = {}

    for _, target in ipairs(FindEntitiesInRange(self.drone, radius, { "player" }, PLAYER_CANT_TAGS)) do
        if IsInRange(self.drone, target, radius)
            and target ~= self.owner
            and target.components ~= nil
            and target.components.health ~= nil
            and not target.components.health:IsDead()
        then
            found[target] = true
        end
    end

    if next(found) ~= nil then
        if self:_EnsureTeleportPortal() ~= nil then
            self:_RefreshTeleportPortal()
        end
    else
        self:_CloseTeleportPortal()
    end

end

function KeiRotorBeam:_UpdatePlayers(dt)
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local found = {}
    for _, target in ipairs(FindEntitiesInRange(self.drone, radius, { "player" }, PLAYER_CANT_TAGS)) do
        if IsInRange(self.drone, target, radius)
            and target.components.health ~= nil
            and not target.components.health:IsDead()
        then
            found[target] = true
            if self.beam_name == "strengthen" then
                if target.components.combat ~= nil then
                    target.components.combat.externaldamagemultipliers:SetModifier(
                        self.inst,
                        TUNING.KEI_ROTOR_STRENGTHEN_DAMAGE_MULT or 1.5,
                        STRENGTHEN_DAMAGE_KEY
                    )
                end
                InstallShieldSource(self.inst, target)
            elseif self.beam_name == "heal" then
                if self.heal_elapsed >= 1 then
                    target.components.health:DoDelta(
                        TUNING.KEI_ROTOR_HEAL_AMOUNT or 1,
                        true,
                        "kei_rotor_heal"
                    )
                    if target.components.sanity ~= nil then
                        target.components.sanity:DoDelta(
                            TUNING.KEI_ROTOR_HEAL_AMOUNT or 1,
                            true,
                            "kei_rotor_heal"
                        )
                    end
                end
            end
        end
    end

    local old_players = {}
    for target in pairs(self.players) do
        old_players[#old_players + 1] = target
    end
    for _, target in ipairs(old_players) do
        if not found[target] then
            self:_ClearPlayer(target)
        end
    end
    self.players = found

    if self.beam_name == "strengthen" then
        for target in pairs(found) do
            InstallShieldSource(self.inst, target)
        end
    end
end

function KeiRotorBeam:_UpdateEnemies()
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local found = {}
    for _, target in ipairs(FindEntitiesInRange(self.drone, radius, { "_combat" }, ENEMY_CANT_TAGS)) do
        if IsInRange(self.drone, target, radius) and IsEnemyForOwner(self.owner, target) then
            found[target] = true
            if self.beam_name == "confinement" then
                ApplyConfinement(self.inst, target)
            elseif self.beam_name == "dead" then
                if IsShadowCreature(target) then
                    target.components.health:Kill()
                else
                    target.components.health:DoDelta(
                        -1,
                        true,
                        "kei_rotor_dead",
                        true,
                        self.owner,
                        true
                    )
                end
            end
        end
    end

    local old_enemies = {}
    for target in pairs(self.enemies) do
        old_enemies[#old_enemies + 1] = target
    end
    for _, target in ipairs(old_enemies) do
        if not found[target] then
            self:_ClearEnemy(target)
        end
    end
    self.enemies = found
end

function KeiRotorBeam:_UpdateResurrection(dt)
    local radius = TUNING.KEI_ROTOR_BEAM_RADIUS or 8
    local target = self.revive_target
    if target == nil or not IsInRange(self.drone, target, radius) then
        target = nil
        for _, candidate in ipairs(FindEntitiesInRange(self.drone, radius, { "playerghost" }, GHOST_CANT_TAGS)) do
            if IsInRange(self.drone, candidate, radius) then
                target = candidate
                break
            end
        end
        self.revive_target = target
        self.revive_elapsed = 0
    end

    if target == nil then
        return
    end

    self.revive_elapsed = self.revive_elapsed + dt
    if self.revive_elapsed < (TUNING.KEI_ROTOR_RESURRECTION_DELAY or 5) then
        return
    end

    local power = self.inst.components ~= nil and self.inst.components.kei_rotor_power or nil
    local cost = TUNING.KEI_ROTOR_RESURRECTION_POWER_COST or 120
    local source = self.drone
    if power ~= nil and power:Consume(cost) then
        target:PushEvent("respawnfromghost", { source = source })
    end
    self.revive_target = nil
    self.revive_elapsed = 0
end

function KeiRotorBeam:_OnUpdate(dt)
    if self.drone == nil or not IsValid(self.drone) then
        self:Stop()
        return
    end

    if self.beam_name == "heal" or self.beam_name == "strengthen" then
        self.heal_elapsed = self.heal_elapsed + dt
    end

    if self.beam_name == "survey" then
        self:_UpdateSurvey(dt)
    elseif self.beam_name == "resurrection" then
        self:_UpdateResurrection(dt)
    elseif self.beam_name == "teleport" then
        self:_UpdateTeleport()
    elseif self.beam_name == "collect" then
        self:_UpdateCollect()
    elseif self.beam_name == "fishing" then
        self:_UpdateFishing()
    elseif self.beam_name == "nature" then
        self:_UpdateNature()
    elseif self.beam_name == "friendly" then
        self:_UpdateFriendly(dt)
    else
        self:_UpdatePlayers(dt)
        if self.beam_name == "confinement" or self.beam_name == "dead" then
            self:_UpdateEnemies()
        else
            local enemies = {}
            for target in pairs(self.enemies) do
                enemies[#enemies + 1] = target
            end
            for _, target in ipairs(enemies) do
                self:_ClearEnemy(target)
            end
        end
    end

    if self.beam_name == "heal" and self.heal_elapsed >= 1 then
        self.heal_elapsed = self.heal_elapsed - 1
    end
end

function KeiRotorBeam:Start(beam_name, drone, owner)
    self:Stop()
    if beam_name == nil or drone == nil or not IsValid(drone) then
        return false
    end

    self.beam_name = beam_name
    self.drone = drone
    self.owner = owner
    drone._kei_rotor_beam_controller = self.inst

    local power = self.inst.components ~= nil and self.inst.components.kei_rotor_power or nil
    local drain = (beam_name == "heal"
        or beam_name == "strengthen"
        or beam_name == "confinement"
        or beam_name == "dead"
        or beam_name == "teleport"
        or beam_name == "collect"
        or beam_name == "fishing"
        or beam_name == "nature"
        or beam_name == "friendly")
        and (TUNING.KEI_ROTOR_BEAM_DRAIN_RATE or 2)
        or 0
    if power ~= nil then
        power:SetSkillDrain(drain)
    end

    self.task = self.inst:DoPeriodicTask(TUNING.KEI_ROTOR_BEAM_UPDATE_PERIOD or 0.2, function(inst, dt)
        self:_OnUpdate(tonumber(dt) or (TUNING.KEI_ROTOR_BEAM_UPDATE_PERIOD or 0.2))
    end)
    -- Apply the first scan immediately. This prevents the short interval
    -- between selecting the skill and the first periodic tick from leaving
    -- players inside the visible beam without the strengthen shield.
    self:_OnUpdate(0)
    return true
end

function KeiRotorBeam:Stop()
    local drone = self.drone

    if self.task ~= nil then
        self.task:Cancel()
        self.task = nil
    end

    self:_ClearEffects()
    if drone ~= nil and drone:IsValid() then
        -- Stop can be called by the power component, so clear the replicated
        -- visual state here instead of relying on the spell callback.
        if drone.SetSkillBeam ~= nil then
            drone:SetSkillBeam(nil)
        end
        if drone._kei_rotor_beam_controller == self.inst then
            drone._kei_rotor_beam_controller = nil
        end
    end

    local power = self.inst.components ~= nil and self.inst.components.kei_rotor_power or nil
    if power ~= nil then
        power:SetSkillDrain(0)
    end
    self.beam_name = nil
    self.drone = nil
    self.owner = nil
end

function KeiRotorBeam:OnRemoveFromEntity()
    self:Stop()
end

return KeiRotorBeam
