local assets = {
    Asset("ANIM", "anim/eyeofterror_action.zip"),
    Asset("ANIM", "anim/eyeofterror_basic.zip"),
    Asset("ANIM", "anim/eyeofterror_twin1_build.zip"),
    Asset("ANIM", "anim/eyeofterror_twin2_build.zip"),
}

local prefabs = {
    "boat_leak",
    "chesspiece_eyeofterror_sketch",
    "eyemaskhat",
    "eyeofterror_arrive_fx",
    "eyeofterror_mini_projectile",
    "boss_ripple_fx",
    "eyeofterror_sinkhole",
    "milkywhites",
    "slide_puff",
    "eyeofterrorcorpse",
}

local function fn(sim)
    local original = Prefabs["eyeofterror"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst ~= nil then
        inst:SetPrefabName("kei_recorder_eyeofterror")
        inst:SetPrefabNameOverride("eyeofterror")
        inst:AddTag("kei_recorder_eyeofterror")
    end
    return inst
end

return Prefab("kei_recorder_eyeofterror", fn, assets, prefabs)
