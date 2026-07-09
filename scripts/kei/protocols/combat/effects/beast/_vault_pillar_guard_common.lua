-- 远古戍卫塔协议公共实现：旋转攻击标记、攻速标记的 source 追踪

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local VaultPillarGuardCommon = {}

local TAG_SPIN = "kei_vault_pillar_guard_spin"
local TAG_SPEED = "kei_vault_pillar_guard_speed"

-- 判断高级协议是否激活，用于压制初级协议的同类能力。
function VaultPillarGuardCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "vault_pillar_guard")
end

--- 旋转攻击标记 (n_spin) 的 source 追踪

function VaultPillarGuardCommon.EnableSpinAttack(slots, inst, source)
    source = source or "vault_pillar_guard"
    slots._kei_vpg_spin_sources = slots._kei_vpg_spin_sources or {}
    if slots._kei_vpg_spin_sources[source] then
        return
    end
    if not BeastCommon.HasAnySource(slots._kei_vpg_spin_sources) then
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
    if BeastCommon.HasAnySource(sources) then
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
    if not BeastCommon.HasAnySource(slots._kei_vpg_speed_sources) then
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
    if BeastCommon.HasAnySource(sources) then
        return
    end
    inst:RemoveTag(TAG_SPEED)
    slots._kei_vpg_speed_sources = nil
end

return VaultPillarGuardCommon
