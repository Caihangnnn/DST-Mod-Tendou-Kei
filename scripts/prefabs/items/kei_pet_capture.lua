-- 友友球与宠物经验书：暂用战斗记录器部署包外观捕捉宠物，并提供三档成长道具。
local PetCapture = require("kei/protocols/pet/capture")

local assets = {
    Asset("ANIM", "anim/kei_items.zip"),
    Asset("ATLAS", "images/inventoryimages/kei_items.xml"),
    Asset("IMAGE", "images/inventoryimages/kei_items.tex"),
}

local EXP_BOOK_DEFS = {
    { prefab = "kei_pet_exp1", anim = "kei_pet_exp1", value_key = "KEI_PET_EXP_BOOK_1" },
    { prefab = "kei_pet_exp2", anim = "kei_pet_exp2", value_key = "KEI_PET_EXP_BOOK_2" },
    { prefab = "kei_pet_exp3", anim = "kei_pet_exp3", value_key = "KEI_PET_EXP_BOOK_3" },
}

local function LaunchCapture(inst, doer, target)
    if doer == nil or target == nil or not PetCapture.IsPotentialTarget(target) then
        return false
    end
    local projectile = SpawnPrefab("kei_pet_capture_projectile")
    if projectile == nil or projectile.LaunchCapture == nil then
        return false
    end
    projectile.Transform:SetPosition(doer.Transform:GetWorldPosition())
    projectile:LaunchCapture(doer, target)
    return true
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("kei_items")
    inst.AnimState:SetBuild("kei_items")
    inst.AnimState:PlayAnimation("kei_data_recorder_item_ground")
    inst.Transform:SetScale(0.8, 0.8, 0.8)
    inst:AddTag("kei_pet_capture_tool")
    inst:AddTag("weapon")
    MakeInventoryFloatable(inst, "small", nil, 0.8)
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages/kei_items.xml"
    inst.components.inventoryitem:ChangeImageName("kei_data_recorder_item")
    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HANDS
    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(TUNING.KEI_PET_CAPTURE_DAMAGE or 0)
    inst.components.weapon:SetRange(TUNING.KEI_PET_CAPTURE_RANGE or 12)
    inst.LaunchCapture = LaunchCapture
    MakeHauntableLaunch(inst)
    return inst
end

local function OnProjectileHit(inst, attacker, target)
    PetCapture.TryCapture(inst.kei_capture_doer or attacker, target or inst.kei_capture_target)
    inst:Remove()
end

local function LaunchProjectile(inst, doer, target)
    inst.kei_capture_doer = doer
    inst.kei_capture_target = target
    inst.components.projectile:Throw(doer, target, nil)
end

local function projectile_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    MakeProjectilePhysics(inst)
    inst.AnimState:SetBank("kei_items")
    inst.AnimState:SetBuild("kei_items")
    inst.AnimState:PlayAnimation("kei_data_recorder_item_ground", true)
    inst.Transform:SetScale(0.65, 0.65, 0.65)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst:AddComponent("projectile")
    inst.components.projectile:SetSpeed(TUNING.KEI_PET_CAPTURE_PROJECTILE_SPEED or 30)
    inst.components.projectile:SetHoming(true)
    inst.components.projectile:SetHitDist(0.5)
    inst.components.projectile:SetOnHitFn(OnProjectileHit)
    inst.components.projectile:SetOnMissFn(inst.Remove)
    inst.LaunchCapture = LaunchProjectile
    return inst
end

local function MakeExpBook(def)
    local function exp_book_fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("kei_items")
        inst.AnimState:SetBuild("kei_items")
        inst.AnimState:PlayAnimation(def.anim)
        inst.Transform:SetScale(1.5, 1.5, 1.5)
        inst:AddTag("kei_pet_exp_book")
        MakeInventoryFloatable(inst, "small", nil, 0.8)
        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = "images/inventoryimages/kei_items.xml"
        inst.components.inventoryitem:ChangeImageName(def.prefab)
        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.KEI_PET_EXP_BOOK_STACK_SIZE or 20
        inst.kei_pet_exp_value = TUNING[def.value_key] or 0
        MakeHauntableLaunch(inst)
        return inst
    end

    return Prefab(def.prefab, exp_book_fn, assets)
end

local prefabs = {
    Prefab("kei_pet_capture_ball", fn, assets, { "kei_pet_capture_projectile", "kei_pet_cd" }),
    Prefab("kei_pet_capture_projectile", projectile_fn, assets),
}

for _, def in ipairs(EXP_BOOK_DEFS) do
    table.insert(prefabs, MakeExpBook(def))
end

return unpack(prefabs)
