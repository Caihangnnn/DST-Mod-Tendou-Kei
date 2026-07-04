local function NewPlannedCombatEffect(protocol, note)
    local Effect = {}
    Effect.protocol = protocol
    Effect.planned = true
    Effect.note = note

    function Effect.Enable(slots, inst)
        -- Planned protocol hook. Fill this file with concrete enable logic when implementing the effect.
    end

    function Effect.Disable(slots, inst)
        -- Planned protocol hook. Fill this file with concrete cleanup logic when implementing the effect.
    end

    function Effect.OnHitOther(slots, inst, data)
        -- Optional combat event hook.
    end

    function Effect.OnAttacked(slots, inst, data)
        -- Optional attacked event hook.
    end

    return Effect
end

return NewPlannedCombatEffect
