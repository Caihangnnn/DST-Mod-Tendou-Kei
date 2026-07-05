local MutatedBeargerEffect = {}

function MutatedBeargerEffect.Enable(slots, inst)
    inst:AddTag("kei_attack_speed_boost")
end

function MutatedBeargerEffect.Disable(slots, inst)
    inst:RemoveTag("kei_attack_speed_boost")
end

return MutatedBeargerEffect
