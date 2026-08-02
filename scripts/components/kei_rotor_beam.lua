-- 旋翼调查仪光束的服务器端效果。

local KeiRotorBeam = Class(function(self, inst)
    self.inst = inst
    self.beam_name = nil
    self.drone = nil
    self.owner = nil
    self.task = nil
    self.players = {}
    self.enemies = {}
    self.revive_target = nil
    self.revive_elapsed = 0
    self.heal_elapsed = 0
end)

local PLAYER_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "playerghost", "notarget" }
local GHOST_CANT_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "notarget" }
local ENEMY_CANT_TAGS = {
    "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost",
    "companion", "flight", "invisible", "notarget", "noattack",
}

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

    if target.AnimState ~= nil then
        target._kei_rotor_confinement_sources = target._kei_rotor_confinement_sources or {}
        target._kei_rotor_confinement_sources[source] = true
        target.AnimState:SetDeltaTimeMultiplier(multiplier)
    end
end

local function RemoveConfinement(source, target)
    if target == nil then
        return
    end

    if target.components ~= nil and target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(source, CONFINEMENT_SPEED_KEY)
    end

    local sources = target._kei_rotor_confinement_sources
    if sources ~= nil then
        sources[source] = nil
        if next(sources) == nil then
            target._kei_rotor_confinement_sources = nil
            if target.AnimState ~= nil then
                target.AnimState:SetDeltaTimeMultiplier(1)
            end
        end
    end
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
    self.players[target] = nil
end

function KeiRotorBeam:_ClearEnemy(target)
    RemoveConfinement(self.inst, target)
    self.enemies[target] = nil
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
    self.revive_target = nil
    self.revive_elapsed = 0
    self.heal_elapsed = 0
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

    if self.beam_name == "resurrection" then
        self:_UpdateResurrection(dt)
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
        or beam_name == "dead")
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
