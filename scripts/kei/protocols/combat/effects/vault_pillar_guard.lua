local VaultPillarGuardCommon = require("kei/protocols/combat/effects/_vault_pillar_guard_common")

local VaultPillarGuardEffect = {}
local SOURCE = "vault_pillar_guard"

function VaultPillarGuardEffect.Enable(slots, inst)
    VaultPillarGuardCommon.EnableSpinAttack(slots, inst, SOURCE)
    VaultPillarGuardCommon.EnableAttackSpeed(slots, inst, SOURCE)
end

function VaultPillarGuardEffect.Disable(slots, inst)
    VaultPillarGuardCommon.DisableSpinAttack(slots, inst, SOURCE)
    VaultPillarGuardCommon.DisableAttackSpeed(slots, inst, SOURCE)
end

return VaultPillarGuardEffect