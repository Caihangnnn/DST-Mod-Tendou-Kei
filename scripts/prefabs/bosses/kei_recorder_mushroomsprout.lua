local assets = {
    Asset("ANIM", "anim/mushroomsprout.zip"),
    Asset("ANIM", "anim/toadstool_upg_build.zip"),
}

local prefabs = {
    "kei_recorder_sporecloud",
}

local SPROUT_LIFETIME = 30

local function RegisterSupport(owner, entity)
    if owner == nil or entity == nil then
        return
    end
    owner.kei_target_support_entities = owner.kei_target_support_entities or {}
    table.insert(owner.kei_target_support_entities, entity)
end

local function RemoveAttachedCloud(inst)
    local cloud = inst.kei_recorder_sporecloud
    inst.kei_recorder_sporecloud = nil
    if cloud ~= nil and cloud:IsValid() then
        local cleanup = inst.kei_recorder_cleanup == true
        cloud.kei_recorder_cleanup = cleanup
        if cloud.BeginDisperse ~= nil then
            if not cleanup then
                -- Detach first so removing the sprout does not remove the
                -- cloud before its own dissipate animation can play.
                local x, y, z = cloud.Transform:GetWorldPosition()
                cloud.entity:SetParent(nil)
                cloud.Transform:SetPosition(x, y, z)
            end
            cloud:BeginDisperse(cleanup)
        else
            cloud:Remove()
        end
    end
end

local function SpawnAttachedCloud(inst, source)
    if inst.kei_recorder_sporecloud ~= nil
        and inst.kei_recorder_sporecloud:IsValid()
    then
        return
    end

    local cloud = SpawnPrefab("kei_recorder_sporecloud")
    if cloud ~= nil then
        cloud.kei_recorder_source = source
        cloud.entity:SetParent(inst.entity)
        cloud.Transform:SetPosition(0, 0, 0)
        inst.kei_recorder_sporecloud = cloud
        RegisterSupport(source, cloud)
    end
end

local function LinkToRecorder(inst, toadstool)
    local source = toadstool ~= nil and toadstool.kei_recorder_source or nil
    if source ~= nil and source:IsValid() then
        -- The vanilla sprout's private UpdateBuild function derives the
        -- upgrade build from inst.prefab. Restore its resource key before
        -- every linked level update, otherwise the trunk becomes invisible.
        inst.prefab = "mushroomsprout"
        inst.kei_recorder_source = source
        RegisterSupport(source, inst)
        SpawnAttachedCloud(inst, source)
    end
end

local function fn(sim)
    local original = Prefabs["mushroomsprout"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    -- Keep inst.prefab as "mushroomsprout": vanilla UpdateBuild uses it to
    -- locate mushroomsprout_upg_build.zip. The custom prefab and tag still
    -- keep this entity separate from trees spawned by the base game.
    inst.prefab = "mushroomsprout"
    inst:AddTag("kei_recorder_mushroomsprout")
    inst.persists = false

    if TheWorld.ismastersim and inst.components.workable ~= nil then
        local workable = inst.components.workable
        local original_onfinish = workable.onfinish
        workable:SetWorkLeft(1)
        workable:SetOnFinishCallback(function(tree, worker)
            -- Vanilla chop_down_tree intentionally ignores non-persistent
            -- sprouts. Allow its fall animation for this one callback, then
            -- let the vanilla callback set persists back to false.
            tree.persists = true
            if original_onfinish ~= nil then
                original_onfinish(tree, worker)
            end
        end)

        inst.kei_recorder_lifetime_task = inst:DoTaskInTime(SPROUT_LIFETIME, function(tree)
            tree.kei_recorder_lifetime_task = nil
            if not tree:IsValid() or tree.kei_recorder_cleanup then
                return
            end

            if tree.components.workable:CanBeWorked() then
                tree.components.workable:Destroy(tree)
            elseif tree:IsValid() then
                tree:Remove()
            end
        end)
    end

    inst:ListenForEvent("linktoadstool", LinkToRecorder)
    inst:ListenForEvent("onremove", RemoveAttachedCloud)

    return inst
end

return Prefab("kei_recorder_mushroomsprout", fn, assets, prefabs)
