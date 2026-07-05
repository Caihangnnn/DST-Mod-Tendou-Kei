local VaultPillarGuardCommon = require("kei/protocols/combat/effects/_vault_pillar_guard_common")

local VaultPillarGuardBasicEffect = {}
local SOURCE = "vault_pillar_guard_basic"

function VaultPillarGuardBasicEffect.Enable(slots, inst)
    if VaultPillarGuardCommon.HasAdvanced(slots) then
        VaultPillarGuardCommon.DisableSpinAttack(slots, inst, SOURCE)
        return
    end
    VaultPillarGuardCommon.EnableSpinAttack(slots, inst, SOURCE)
end

function VaultPillarGuardBasicEffect.Disable(slots, inst)
    VaultPillarGuardCommon.DisableSpinAttack(slots, inst, SOURCE)
end

return VaultPillarGuardBasicEffect