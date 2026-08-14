local assets = {
    Asset("ANIM", "anim/cookbook.zip"),
}

local function OnReadBook(inst, doer)
    if doer ~= nil then doer:ShowPopUp(POPUPS.KEI_TASK_BOOK, true) end
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("cookbook")
    inst.AnimState:SetBuild("cookbook")
    inst.AnimState:PlayAnimation("idle")
    inst.Transform:SetScale(1.2, 1.2, 1.2)
    MakeInventoryFloatable(inst, "med", nil, .75)
    inst:AddTag("simplebook")
    inst:AddTag("kei_task_book")
    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end
    inst:AddComponent("inspectable")
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.atlasname = "images/inventoryimages1.xml"
    inst.components.inventoryitem:ChangeImageName("cookbook")
    inst:AddComponent("simplebook")
    inst.components.simplebook.onreadfn = OnReadBook
    MakeHauntableLaunch(inst)
    return inst
end

return Prefab("kei_task_book", fn, assets)
