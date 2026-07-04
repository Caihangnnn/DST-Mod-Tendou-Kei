local VaultPillarGuardEffect = {}

function VaultPillarGuardEffect.Enable(slots, inst)
    inst:AddTag("kei_vault_pillar_guard_spin")
end

function VaultPillarGuardEffect.Disable(slots, inst)
    inst:RemoveTag("kei_vault_pillar_guard_spin")
end

return VaultPillarGuardEffect
