local function NewPlannedLifeEffect(protocol, note)
    local Effect = {}
    Effect.protocol = protocol
    Effect.planned = true
    Effect.note = note

    function Effect.Apply(slots, inst, stacks)
        -- Planned life protocol hook. Periodic or refresh-driven behavior can be added here later.
    end

    return Effect
end

return NewPlannedLifeEffect
