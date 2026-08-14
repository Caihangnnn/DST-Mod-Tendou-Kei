local AnalysisArmorUpgrade = {
    RECIPE = "kei_analysis_armor_upgrade",
    MAX_LEVEL = 5,
    EXPERIENCE_PER_LEVEL = 1000,
}

function AnalysisArmorUpgrade.ClampLevel(value)
    return math.max(
        0,
        math.min(AnalysisArmorUpgrade.MAX_LEVEL, math.floor(tonumber(value) or 0))
    )
end

function AnalysisArmorUpgrade.GetLevel(inst)
    if inst == nil then
        return 0
    end

    local slots = inst.components ~= nil and inst.components.kei_protocolslots or nil
    if slots ~= nil then
        return AnalysisArmorUpgrade.ClampLevel(slots.analysis_armor_upgrade_level)
    end

    local netvar = inst._kei_analysis_armor_upgrade_level
    return netvar ~= nil and AnalysisArmorUpgrade.ClampLevel(netvar:value()) or 0
end

function AnalysisArmorUpgrade.GetAbsorbScale(inst)
    return AnalysisArmorUpgrade.GetLevel(inst) / AnalysisArmorUpgrade.MAX_LEVEL
end

function AnalysisArmorUpgrade.GetExperienceCost(inst)
    return (AnalysisArmorUpgrade.GetLevel(inst) + 1)
        * AnalysisArmorUpgrade.EXPERIENCE_PER_LEVEL
end

function AnalysisArmorUpgrade.IsRecipe(recname)
    return recname == AnalysisArmorUpgrade.RECIPE
end

return AnalysisArmorUpgrade
