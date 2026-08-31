local assets = {
    Asset("ANIM", "anim/goosemoose_build.zip"),
    Asset("ANIM", "anim/goosemoose_basic.zip"),
    Asset("ANIM", "anim/goosemoose_actions.zip"),
    Asset("ANIM", "anim/goosemoose_yule_build.zip"),
    Asset("SOUND", "sound/goosemoose.fsb"),
}

local prefabs = {
    "moose",
    "mooseegg",
    "moose_nesting_ground",
    "mossling",
    "goose_feather",
    "drumstick",
    "chesspiece_moosegoose_sketch",
    "moosecorpse",
    "kei_recorder_moose_vortex",
}

local function fn(sim)
    local original = Prefabs["moose"]
    if original == nil or original.fn == nil then
        return nil
    end

    -- Reuse the vanilla components, brain and SG while giving the recorder
    -- challenge a separate prefab identity.
    local inst = original.fn(sim)
    if inst ~= nil then
        inst:SetPrefabName("kei_recorder_moose")
        inst:SetPrefabNameOverride("moose")
        inst:AddTag("kei_recorder_moose")
        inst.persists = false
    end
    return inst
end

return Prefab("kei_recorder_moose", fn, assets, prefabs)
