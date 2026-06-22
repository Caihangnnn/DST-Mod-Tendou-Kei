local KEI_CONTROL_IMMUNE_EVENTS = {
    suspended = true,
    knockback = true,
}

local function AddKeiStaggerImmunityToStategraph(sg)
    if sg.events == nil or sg.events.attacked == nil then
        return
    end

    local old_attacked_fn = sg.events.attacked.fn
    sg.events.attacked.fn = function(inst, data)
        if inst:HasTag("kei_stagger_immune") then
            return
        end
        return old_attacked_fn ~= nil and old_attacked_fn(inst, data) or nil
    end
end

AddStategraphPostInit("wilson", AddKeiStaggerImmunityToStategraph)
AddStategraphPostInit("wilson_client", AddKeiStaggerImmunityToStategraph)

local function AddKeiControlImmunityToStategraph(sg)
    if sg.events == nil then
        return
    end

    for eventname in pairs(KEI_CONTROL_IMMUNE_EVENTS) do
        local event = sg.events[eventname]
        if event ~= nil and event.fn ~= nil then
            local old_fn = event.fn
            event.fn = function(inst, ...)
                if inst:HasTag("kei_control_immune") then
                    return
                end
                return old_fn(inst, ...)
            end
        end
    end
end

AddStategraphPostInit("wilson", AddKeiControlImmunityToStategraph)
AddStategraphPostInit("wilson_client", AddKeiControlImmunityToStategraph)

local function GetKeiAttackSpeedMult(inst)
    if inst == nil then
        return 1
    end

    local mult = 1
    if inst:HasTag("kei_attack_speed_boost") then
        mult = mult * (TUNING.KEI_MUTATEDBEARGER_ATTACK_SPEED_MULT or 1)
    end
    if inst:HasTag("kei_vault_pillar_guard_spin") then
        mult = mult * (TUNING.KEI_VAULT_PILLAR_GUARD_ATTACK_SPEED_MULT or 1)
    end
    return mult > 1 and mult or 1
end

local function ApplyKeiAttackSpeedToAttackState(inst, state)
    if inst.sg == nil or inst.sg.currentstate ~= state then
        return
    end

    local mult = GetKeiAttackSpeedMult(inst)
    if mult <= 1 then
        return
    end

    inst.sg.statemem.kei_attack_speed_mult = mult

    local combat = inst.components ~= nil and inst.components.combat or nil
    if combat ~= nil and combat.laststartattacktime ~= nil then
        local period = combat.min_attack_period or 0
        if period > 0 then
            combat.laststartattacktime = combat.laststartattacktime - period * (1 - 1 / mult)
        end
    end

    if inst.AnimState ~= nil then
        inst.AnimState:SetDeltaTimeMultiplier(mult)
    end

    if type(inst.sg.timeout) == "number" and inst.sg.timeout > 0 then
        inst.sg:SetTimeout(inst.sg.timeout / mult)
    end
end

local function ClearKeiAttackSpeedFromAttackState(inst)
    if inst.sg ~= nil
        and inst.sg.statemem ~= nil
        and inst.sg.statemem.kei_attack_speed_mult ~= nil
        and inst.AnimState ~= nil then
        inst.AnimState:SetDeltaTimeMultiplier(1)
    end
end

local function GetKeiEquippedHandItem(inst)
    if inst.components ~= nil
        and inst.components.inventory ~= nil then
        return inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
    if inst.replica ~= nil
        and inst.replica.inventory ~= nil then
        return inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
    end
    return nil
end

local function GetWeaponAttackRange(item)
    if item == nil then
        return nil
    end
    if item.components ~= nil
        and item.components.weapon ~= nil then
        return item.components.weapon.attackrange or 0
    end
    if item.replica ~= nil
        and item.replica.inventoryitem ~= nil
        and item.replica.inventoryitem.IsWeapon ~= nil
        and item.replica.inventoryitem:IsWeapon() then
        return item.replica.inventoryitem:AttackRange() or 0
    end
    return nil
end

local function IsKeiRiding(inst)
    if inst.components ~= nil
        and inst.components.rider ~= nil then
        return inst.components.rider:IsRiding()
    end
    if inst.replica ~= nil
        and inst.replica.rider ~= nil then
        return inst.replica.rider:IsRiding()
    end
    return false
end

local function ShouldUseKeiVaultPillarGuardSpinAttack(inst)
    if inst == nil
        or not inst:HasTag("kei_vault_pillar_guard_spin")
        or inst:HasTag("playerghost")
        or inst:HasTag("kei_dormant")
        or IsKeiRiding(inst)
    then
        return false
    end

    local equip = GetKeiEquippedHandItem(inst)
    if equip == nil
        or equip:HasTag("punch")
        or equip:HasTag("projectile")
        or equip:HasTag("rangedweapon")
    then
        return false
    end

    local range = GetWeaponAttackRange(equip)
    return range ~= nil and range <= 1
end

local function ApplyKeiVaultPillarGuardSpinAttack(inst, state)
    if inst.sg == nil
        or inst.sg.currentstate ~= state
        or not ShouldUseKeiVaultPillarGuardSpinAttack(inst)
    then
        return
    end

    inst.sg.statemem.kei_vault_pillar_guard_spin = true
    inst.AnimState:PlayAnimation("wx_spin_attack_loop_slow")
    inst.AnimState:PushAnimation("wx_spin_attack_pst", false)
end

local KEI_VAULT_PILLAR_GUARD_SPIN_MUST_TAGS = { "_combat" }
local KEI_VAULT_PILLAR_GUARD_SPIN_CANT_TAGS = {
    "INLIMBO",
    "NOCLICK",
    "FX",
    "decor",
    "companion",
    "flight",
    "invisible",
    "notarget",
    "noattack",
    "playerghost",
}

local function DoKeiVaultPillarGuardSpinAOE(inst)
    if TheWorld == nil
        or not TheWorld.ismastersim
        or inst.sg == nil
        or inst.sg.statemem == nil
        or not inst.sg.statemem.kei_vault_pillar_guard_spin
        or inst.components == nil
        or inst.components.combat == nil
    then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    local attacktarget = inst.sg.statemem.attacktarget
    local radius = TUNING.WX78_SPIN_RADIUS or 2.1
    for _, target in ipairs(TheSim:FindEntities(
        x, y, z,
        radius + 3,
        KEI_VAULT_PILLAR_GUARD_SPIN_MUST_TAGS,
        KEI_VAULT_PILLAR_GUARD_SPIN_CANT_TAGS
    )) do
        if target ~= inst
            and target ~= attacktarget
            and target:IsValid()
            and target.entity:IsVisible()
            and target.components.health ~= nil
            and not target.components.health:IsDead()
            and inst.components.combat:CanTarget(target)
            and not inst.components.combat:IsAlly(target)
        then
            local range = radius + target:GetPhysicsRadius(0)
            if target:GetDistanceSqToPoint(x, y, z) < range * range then
                inst.components.combat:DoAttack(target)
            end
        end
    end
end

local function InsertStateTimelineEvent(timeline, event)
    if timeline == nil then
        return
    end
    local insert_index = #timeline + 1
    for index, timeline_event in ipairs(timeline) do
        if timeline_event.time > event.time then
            insert_index = index
            break
        end
    end
    table.insert(timeline, insert_index, event)
end

local function AddKeiAttackStateOverridesToStategraph(sg)
    local state = sg.states ~= nil and sg.states.attack or nil
    if state == nil then
        return
    end

    local old_onenter = state.onenter
    state.onenter = function(inst, ...)
        if old_onenter ~= nil then
            old_onenter(inst, ...)
        end
        ApplyKeiVaultPillarGuardSpinAttack(inst, state)
        ApplyKeiAttackSpeedToAttackState(inst, state)
    end

    local old_onexit = state.onexit
    state.onexit = function(inst, ...)
        if old_onexit ~= nil then
            old_onexit(inst, ...)
        end
        ClearKeiAttackSpeedFromAttackState(inst)
    end

    InsertStateTimelineEvent(state.timeline, TimeEvent(8 * FRAMES, DoKeiVaultPillarGuardSpinAOE))
end

AddStategraphPostInit("wilson", AddKeiAttackStateOverridesToStategraph)
AddStategraphPostInit("wilson_client", AddKeiAttackStateOverridesToStategraph)

if StateGraphInstance ~= nil and StateGraphInstance.UpdateState ~= nil then
    local old_StateGraphInstance_UpdateState = StateGraphInstance.UpdateState
    function StateGraphInstance:UpdateState(dt)
        if self.inst ~= nil and self.inst:HasTag("kei_mutateddeerclops_sg_slow") then
            dt = dt * (TUNING.KEI_MUTATEDDEERCLOPS_AURA_SLOW_MULT or 0.5)
        end
        return old_StateGraphInstance_UpdateState(self, dt)
    end
end

