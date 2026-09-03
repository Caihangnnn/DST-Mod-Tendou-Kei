-- Entities and world conditions handled by the rotor survey beam.

local RotorSurveyTargets = {
    {
        id = "moonbase_fullmoon",
        prefabs = { "moonbase" },
        protocol = "fullmoon_recipe",
        condition = function()
            return TheWorld ~= nil
                and TheWorld.state ~= nil
                and TheWorld.state.moonphase == "full"
        end,
    },
    {
        id = "shadow_triad_newmoon",
        prefabs = {
            "sculpture_knightbody",
            "sculpture_bishopbody",
            "sculpture_rookbody",
        },
        protocol = "newmoon_recipe",
        condition = function()
            return TheWorld ~= nil
                and TheWorld.state ~= nil
                and TheWorld.state.moonphase == "new"
        end,
    },
    {
        id = "oasislake_weather",
        prefabs = { "oasislake" },
        protocol = "weather",
        condition = function()
            local state = TheWorld ~= nil and TheWorld.state or nil
            return state ~= nil
                and (state.israining == true
                    or state.issnowing == true
                    or state.precipitation == "rain"
                    or state.precipitation == "snow")
        end,
    },
    {
        id = "crabking_water_walk",
        prefabs = { "crabking" },
        protocol = "water_walk",
    },
    {
        id = "watertree_pillar_growth",
        prefabs = { "watertree_pillar" },
        protocol = "growth_acceleration",
        condition = function()
            return TheWorld ~= nil
                and TheWorld.state ~= nil
                and TheWorld.state.isday == true
        end,
    },
    {
        id = "monkeyqueen_ripen",
        prefabs = { "monkeyqueen" },
        protocol = "ripen",
    },
}

local function MatchesPrefab(def, target)
    if target == nil or target.prefab == nil then
        return false
    end

    for _, prefab in ipairs(def.prefabs or {}) do
        if target.prefab == prefab then
            return true
        end
    end
    return false
end

function RotorSurveyTargets.Find(target, owner)
    for _, def in ipairs(RotorSurveyTargets) do
        if MatchesPrefab(def, target)
            and (def.condition == nil or def.condition(target, owner))
        then
            return def
        end
    end
end

return RotorSurveyTargets
