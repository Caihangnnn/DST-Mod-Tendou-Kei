local Recovery = {}

local function ClampRecoveryAmount(amount)
    return math.max(0, tonumber(amount) or 0)
end

local function RestoreHealthMax(health, amount)
    if health == nil
        or health.maxhealth == nil
        or health.maxhealth <= 0
        or (health.penalty or 0) <= 0
        or health.DeltaPenalty == nil
    then
        return
    end

    health:DeltaPenalty(-math.min(health.penalty, amount / health.maxhealth))
end

local function RestoreHungerMax(hunger, amount)
    local penalty = hunger ~= nil and (hunger.penalty2hm or hunger.penalty) or 0
    local reduce = hunger ~= nil and (hunger.DeltaPenalty2hm or hunger.DeltaPenalty) or nil
    local max_value = hunger ~= nil and hunger.max or nil
    if max_value == nil or max_value <= 0 or penalty <= 0 or reduce == nil then
        return
    end

    reduce(hunger, -math.min(penalty, amount / max_value))
end

local function RestoreSanityMax(sanity, amount)
    if sanity == nil or sanity.max == nil or sanity.max <= 0 or (sanity.penalty or 0) <= 0 then
        return
    end

    local reduction = math.min(sanity.penalty, amount / sanity.max)
    if reduction <= 0 then
        return
    end

    -- Sanity penalties are keyed by their owners. Reduce the existing sources
    -- proportionally so other mods can continue to manage their own keys.
    local penalties = sanity.sanity_penalties
    if type(penalties) == "table" and sanity.AddSanityPenalty ~= nil then
        local total = 0
        for _, value in pairs(penalties) do
            if type(value) == "number" and value > 0 then
                total = total + value
            end
        end

        if total > 0 then
            for key, value in pairs(penalties) do
                if type(value) == "number" and value > 0 then
                    local share = reduction * value / total
                    sanity:AddSanityPenalty(key, math.max(0, value - share))
                end
            end
            return
        end
    end

    if sanity.DeltaPenalty ~= nil then
        sanity:DeltaPenalty(-reduction)
    elseif sanity.SetPenalty ~= nil then
        sanity:SetPenalty(math.max(0, sanity.penalty - reduction))
    end
end

function Recovery.RestoreHungerMax(inst, amount)
    if inst ~= nil and inst.components ~= nil then
        RestoreHungerMax(inst.components.hunger, ClampRecoveryAmount(amount))
    end
end

function Recovery.RestoreSanityMax(inst, amount)
    if inst ~= nil and inst.components ~= nil then
        RestoreSanityMax(inst.components.sanity, ClampRecoveryAmount(amount))
    end
end

function Recovery.RestoreHealthMax(inst, amount)
    if inst ~= nil and inst.components ~= nil then
        RestoreHealthMax(inst.components.health, ClampRecoveryAmount(amount))
    end
end

function Recovery.ApplyHungerDelta(inst, amount, ...)
    local hunger = inst ~= nil and inst.components ~= nil and inst.components.hunger or nil
    if hunger == nil then
        return
    end

    amount = tonumber(amount) or 0
    if amount > 0 then
        RestoreHungerMax(hunger, amount)
    end
    return hunger:DoDelta(amount, ...)
end

function Recovery.ApplySanityDelta(inst, amount, ...)
    local sanity = inst ~= nil and inst.components ~= nil and inst.components.sanity or nil
    if sanity == nil then
        return
    end

    amount = tonumber(amount) or 0
    if amount > 0 then
        RestoreSanityMax(sanity, amount)
    end
    return sanity:DoDelta(amount, ...)
end

function Recovery.ApplyHealthDelta(inst, amount, ...)
    local health = inst ~= nil and inst.components ~= nil and inst.components.health or nil
    if health == nil then
        return
    end

    amount = tonumber(amount) or 0
    if amount > 0 then
        RestoreHealthMax(health, amount)
    end
    return health:DoDelta(amount, ...)
end

return Recovery
