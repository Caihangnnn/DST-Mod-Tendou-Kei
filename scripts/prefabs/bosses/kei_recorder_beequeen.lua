local assets = {
    Asset("ANIM", "anim/bee_queen_basic.zip"),
    Asset("ANIM", "anim/bee_queen_actions.zip"),
    Asset("ANIM", "anim/bee_queen_build.zip"),
}

local prefabs = {
    "beequeen",
    "kei_recorder_beeguard",
}

local function fn(sim)
    local original = Prefabs["beequeen"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst ~= nil then
        inst:SetPrefabName("kei_recorder_beequeen")
        inst:SetPrefabNameOverride("beequeen")
        inst:AddTag("kei_recorder_beequeen")
        inst.persists = false

        if TheWorld.ismastersim then
            inst:SetStateGraph("SGkei_recorder_beequeen")
        end
    end
    return inst
end

return Prefab("kei_recorder_beequeen", fn, assets, prefabs)
