-- 发条战车协议（rook）：参考 Legion 盾反的护甲结算入口，成功格挡时免疫本次伤害。

local RookEffect = {}
local KnightEffect = require("kei/protocols/combat/effects/biome/knight")
local Daywalker2Common = require("kei/protocols/combat/effects/beast/_daywalker2_common")

local ROOK_PROTOCOL = "rook"
local KNIGHT_PROTOCOL = "knight"
local COOLDOWN_DIRTY_EVENT = "kei_rook_guard_cd_dirty"
local DEFAULT_GUARD_HIT_SOUND = "WX_rework/shield/hit"

local function SetCooldownFlag(inst, enabled)
    inst.kei_rook_guard_on_cooldown = enabled == true or nil
    if inst._kei_rook_guard_on_cooldown ~= nil then
        inst._kei_rook_guard_on_cooldown:set(enabled == true)
    end
end

local function ClearCooldown(inst)
    if inst._kei_rook_guard_cd_task ~= nil then
        inst._kei_rook_guard_cd_task:Cancel()
        inst._kei_rook_guard_cd_task = nil
    end
    SetCooldownFlag(inst, false)
end

local function GetSlots(inst)
    return inst ~= nil and inst.components ~= nil and inst.components.kei_protocolslots or nil
end

-- 正常情况下发条战车总是通过 kei_protocolslots 管理共享霸体来源。
-- 保留无组件回退时的所有权标记，避免回退路径误删其它 Mod 提供的同名标签。
local function EnableFallbackImmunity(inst)
    if not inst:HasTag("kei_stagger_immune") then
        inst:AddTag("kei_stagger_immune")
        inst._kei_rook_stagger_added_tag = true
    end
    if not inst:HasTag("kei_control_immune") then
        inst:AddTag("kei_control_immune")
        inst._kei_rook_control_added_tag = true
    end
end

local function DisableFallbackImmunity(inst)
    if inst._kei_rook_stagger_added_tag then
        inst:RemoveTag("kei_stagger_immune")
    end
    if inst._kei_rook_control_added_tag then
        inst:RemoveTag("kei_control_immune")
    end
    inst._kei_rook_stagger_added_tag = nil
    inst._kei_rook_control_added_tag = nil
end

function RookEffect.HasProtocol(inst)
    local slots = GetSlots(inst)
    if slots ~= nil then
        return slots:HasCombatProtocol(ROOK_PROTOCOL)
    end
    return inst ~= nil
        and inst._kei_rook_protocol_active ~= nil
        and inst._kei_rook_protocol_active:value()
end

function RookEffect.IsReady(inst)
    if inst == nil or inst:HasTag("playerghost") or inst:HasTag("kei_dormant") then
        return false
    end
    if inst.kei_rook_guarding == true or inst.kei_rook_guard_on_cooldown == true then
        return false
    end
    return not (inst._kei_rook_guard_on_cooldown ~= nil and inst._kei_rook_guard_on_cooldown:value())
end

local function PlayGuardHitSound(inst)
    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound(TUNING.KEI_ROOK_GUARD_HIT_SOUND or DEFAULT_GUARD_HIT_SOUND)
    end
end
function RookEffect.SpawnPulse(inst)
    if inst == nil or not inst:IsValid() then
        return
    end

    local fx = SpawnPrefab("kei_rook_shield_pulse_fx")
    if fx == nil then
        return
    end

    local x, y, z = inst.Transform:GetWorldPosition()
    fx.Transform:SetPosition(x, y + 1.5, z)
    fx.Transform:SetRotation(0)
end

local function MarkGuardSuccess(slots, inst, attacker)
    if inst == nil or not inst:IsValid() then
        return
    end

    inst.kei_rook_guard_blocked = true
    inst.kei_rook_guard_success = true
    if inst.sg ~= nil then
        inst.sg:AddStateTag("nointerrupt")
        inst.sg:AddStateTag("nosleep")
        inst.sg:AddStateTag("nofreeze")
    end
    PlayGuardHitSound(inst)
    RookEffect.SpawnPulse(inst)
    if slots ~= nil and slots:HasCombatProtocol(KNIGHT_PROTOCOL) then
        KnightEffect.ReleaseShock(slots, inst, attacker)
    end
end

local function WrapInventoryApplyDamage(slots, inst)
    if slots == nil or inst.components == nil or inst.components.inventory == nil then
        return
    end
    if slots._kei_rook_apply_damage_wrapper ~= nil then
        return
    end

    local inventory = inst.components.inventory
    local old_apply_damage = inventory.ApplyDamage
    slots._kei_rook_old_apply_damage = old_apply_damage
    slots._kei_rook_apply_damage_wrapper = function(self, damage, attacker, weapon, spdamage, ...)
        if inst.kei_rook_guarding == true then
            local regular_damage = damage or 0
            if regular_damage > 0 or spdamage ~= nil then
                MarkGuardSuccess(slots, inst, attacker)
                return 0, nil
            end
        end
        return old_apply_damage(self, damage, attacker, weapon, spdamage, ...)
    end
    inventory.ApplyDamage = slots._kei_rook_apply_damage_wrapper
end

local function RestoreInventoryApplyDamage(slots, inst)
    if slots == nil or inst.components == nil or inst.components.inventory == nil then
        return
    end

    local inventory = inst.components.inventory
    if slots._kei_rook_apply_damage_wrapper ~= nil and inventory.ApplyDamage == slots._kei_rook_apply_damage_wrapper then
        inventory.ApplyDamage = slots._kei_rook_old_apply_damage
    end
    slots._kei_rook_old_apply_damage = nil
    slots._kei_rook_apply_damage_wrapper = nil
end

local function StartCooldown(inst, seconds)
    if inst == nil or not inst:IsValid() then
        return
    end

    ClearCooldown(inst)
    SetCooldownFlag(inst, true)
    inst:PushEvent(COOLDOWN_DIRTY_EVENT)
    inst._kei_rook_guard_cd_task = inst:DoTaskInTime(seconds, function(owner)
        owner._kei_rook_guard_cd_task = nil
        SetCooldownFlag(owner, false)
        owner:PushEvent(COOLDOWN_DIRTY_EVENT)
    end)
end

-- 格挡窗口开始：临时接管护甲结算入口，并添加受击动作/击退免疫标签。
function RookEffect.BeginGuard(inst)
    if not TheWorld.ismastersim or not RookEffect.HasProtocol(inst) or not RookEffect.IsReady(inst) then
        return false
    end

    local slots = GetSlots(inst)
    inst.kei_rook_guarding = true
    inst.kei_rook_guard_blocked = nil
    inst.kei_rook_guard_success = nil
    if slots ~= nil then
        Daywalker2Common.EnableSharedImmunity(slots, inst, "rook")
    else
        EnableFallbackImmunity(inst)
    end
    WrapInventoryApplyDamage(slots, inst)
    return true
end

-- 格挡窗口结束：根据是否挡到攻击进入不同冷却。
function RookEffect.FinishGuard(inst)
    if not TheWorld.ismastersim or inst == nil then
        return
    end

    local was_guarding = inst.kei_rook_guarding == true
    local blocked = inst.kei_rook_guard_blocked == true
    RookEffect.CancelGuard(inst, true)
    if was_guarding then
        StartCooldown(inst, blocked and (TUNING.KEI_ROOK_GUARD_SUCCESS_COOLDOWN or 1.5) or (TUNING.KEI_ROOK_GUARD_FAIL_COOLDOWN or 6))
    end
end

function RookEffect.CancelGuard(inst, keep_cooldown)
    if inst == nil then
        return
    end

    local slots = GetSlots(inst)
    RestoreInventoryApplyDamage(slots, inst)
    inst.kei_rook_guarding = nil
    inst.kei_rook_guard_blocked = nil
    inst.kei_rook_guard_success = nil
    if slots ~= nil then
        Daywalker2Common.DisableSharedImmunity(slots, inst, "rook")
    else
        DisableFallbackImmunity(inst)
    end
    if keep_cooldown ~= true then
        ClearCooldown(inst)
    end
end

function RookEffect.Disable(slots, inst)
    RookEffect.CancelGuard(inst, false)
end

return RookEffect
