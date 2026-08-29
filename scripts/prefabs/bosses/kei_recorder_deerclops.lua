local assets = {
    Asset("ANIM", "anim/deerclops_basic.zip"),
    Asset("ANIM", "anim/deerclops_actions.zip"),
    Asset("ANIM", "anim/deerclops_build.zip"),
    Asset("ANIM", "anim/deerclops_yule.zip"),
    Asset("SOUND", "sound/deerclops.fsb"),
}

local prefabs = {
    "meat",
    "deerclops_eyeball",
    "chesspiece_deerclops_sketch",
    "deerclops_icespike_fx",
    "deerclops_laser",
    "deerclops_laserempty",
    "winter_ornament_light1",
    "deerclopscorpse",
    "kei_recorder_deerclops_icespike",
    "crab_king_icefx",
    "crabking_ring_fx",
}

local function fn(sim)
    local original = Prefabs["deerclops"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_deerclops")
    inst:SetPrefabNameOverride("deerclops")
    inst:AddTag("kei_recorder_deerclops")
    inst.persists = false

    if TheWorld.ismastersim then
        if inst.components.timer == nil then
            inst:AddComponent("timer")
        end
        inst:SetStateGraph("SGkei_recorder_deerclops")
        inst:DoPeriodicTask(0.25, function(deerclops)
            if deerclops:IsValid() then
                deerclops:PushEvent("kei_recorder_freeze_roar_check")
            end
        end)
    end

    return inst
end

return Prefab("kei_recorder_deerclops", fn, assets, prefabs)
