-- 远古戍卫塔协议公共实现：旋转攻击标记、攻速标记的 source 追踪

local VaultPillarGuardCommon = {}

local TAG_SPIN = "kei_vault_pillar_guard_spin"
local TAG_SPEED = "kei_vault_pillar_guard_speed"

local function HasAnySource(sources)
    if sources == nil then
        return false
    end
    for _ in pairs(sources) do
        return true
    end
    return false
end

function VaultPillarGuardCommon.HasAdvanced(slots)
    return slots ~= nil
        and slots.active_combat ~= nil
        and slots.active_combat.vault_pillar_guard == true
end

--- 旋转攻击标记 (n_spin) 的 source 追踪

function VaultPillarGuardCommon.EnableSpinAttack(slots, inst, source)
    source = source or "vault_pillar_guard"
    slots._kei_vpg_spin_sources = slots._kei_vpg_spin_sources or {}
    if slots._kei_vpg_spin_sources[source] then
        return
    end
    if not HasAnySource(slots._kei_vpg_spin_sources) then
        inst:AddTag(TAG_SPIN)
    end
    slots._kei_vpg_spin_sources[source] = true
end

function VaultPillarGuardCommon.DisableSpinAttack(slots, inst, source)
    source = source or "vault_pillar_guard"
    local sources = slots._kei_vpg_spin_sources
    if sources ~= nil then
        sources[source] = nil
    end
    if HasAnySource(sources) then
        return
    end
    inst:RemoveTag(TAG_SPIN)
    slots._kei_vpg_spin_sources = nil
end

--- 攻击速度标记 (n_speed) 的 source 追踪

function VaultPillarGuardCommon.EnableAttackSpeed(slots, inst, source)
    source = source or "vault_pillar_guard"
    slots._kei_vpg_speed_sources = slots._kei_vpg_speed_sources or {}
    if slots._kei_vpg_speed_sources[source] then
        return
    end
    if not HasAnySource(slots._kei_vpg_speed_sources) then
        inst:AddTag(TAG_SPEED)
    end
    slots._kei_vpg_speed_sources[source] = true
end

function VaultPillarGuardCommon.DisableAttackSpeed(slots, inst, source)
    source = source or "vault_pillar_guard"
    local sources = slots._kei_vpg_speed_sources
    if sources ~= nil then
        sources[source] = nil
    end
    if HasAnySource(sources) then
        return
    end
    inst:RemoveTag(TAG_SPEED)
    slots._kei_vpg_speed_sources = nil
end

return VaultPillarGuardCommon