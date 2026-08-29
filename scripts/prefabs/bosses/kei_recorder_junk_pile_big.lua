local assets = {
    Asset("ANIM", "anim/scrappile.zip"),
    Asset("MINIMAP_IMAGE", "junk_pile_big"),
}

local prefabs = {
    "junk_pile_side",
    "junk_pile_blueprint",
    "junkball_fx",
    "junk_break_fx",
    "daywalker2",
}

local function fn(sim)
    local original = Prefabs["junk_pile_big"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    -- This is a recorder-only support object. The vanilla junk pile remains
    -- untouched and can still participate in the normal world systems.
    inst:SetPrefabName("kei_recorder_junk_pile_big")
    inst:SetPrefabNameOverride("junk_pile_big")
    inst:AddTag("kei_recorder_junk_pile_big")
    inst.persists = false

    return inst
end

return Prefab("kei_recorder_junk_pile_big", fn, assets, prefabs)
