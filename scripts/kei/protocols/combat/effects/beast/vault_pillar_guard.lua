-- 远古戍卫塔高级协议：旋转攻击与攻速强化。
local VaultPillarGuardCommon = require("kei/protocols/combat/effects/beast/_vault_pillar_guard_common")

local VaultPillarGuardEffect = {}
local SOURCE = "vault_pillar_guard"

-- 启用协议效果，并注册该协议提供的持续能力。
function VaultPillarGuardEffect.Enable(slots, inst)
    VaultPillarGuardCommon.EnableSpinAttack(slots, inst, SOURCE)
    VaultPillarGuardCommon.EnableAttackSpeed(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function VaultPillarGuardEffect.Disable(slots, inst)
    VaultPillarGuardCommon.DisableSpinAttack(slots, inst, SOURCE)
    VaultPillarGuardCommon.DisableAttackSpeed(slots, inst, SOURCE)
end

return VaultPillarGuardEffect
