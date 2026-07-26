local CombatProtocolDefs = require("kei/protocols/combat")
local LifeProtocolDefs = require("kei/protocols/life")
local PetProtocolDefs = require("kei/protocols/pet")
local PetData = require("kei/protocols/pet/data")

local COMMON_ITEM_ATLAS = "images/inventoryimages/kei_items.xml"
local COMMON_ITEM_BUILD = "kei_items"

local ITEM_VISUALS = {
    analysis_cd = {
        bank = COMMON_ITEM_BUILD,
        build = COMMON_ITEM_BUILD,
        anim = "kei_analysis_cd_ground",
        atlas = COMMON_ITEM_ATLAS,
        image = "kei_analysis_cd",
        scale = 1.5,
    },
    analysis_tool = {
        bank = COMMON_ITEM_BUILD,
        build = COMMON_ITEM_BUILD,
        anim = "kei_analysis_tool_ground",
        atlas = COMMON_ITEM_ATLAS,
        image = "kei_analysis_tool",
        scale = 1.5,
    },
    blank_cd = {
        bank = COMMON_ITEM_BUILD,
        build = COMMON_ITEM_BUILD,
        anim = "kei_blank_cd_ground",
        atlas = COMMON_ITEM_ATLAS,
        image = "kei_blank_cd",
        scale = 1.5,
    },
    combat_cd = {
        bank = COMMON_ITEM_BUILD,
        build = COMMON_ITEM_BUILD,
        anim = "kei_combat_cd_purple_ground",
        atlas = COMMON_ITEM_ATLAS,
        image = "kei_combat_cd_purple",
        scale = 1.5,
    },
    life_cd = {
        bank = "kei_life_cd",
        build = "kei_life_cd",
        anim = "kei_life_cd_ground",
        atlas = "images/inventoryimages/kei_life_cd_item.xml",
        image = "kei_life_cd",
        scale = 1.5,
    },
    battery = {
        bank = COMMON_ITEM_BUILD,
        build = COMMON_ITEM_BUILD,
        anim = "kei_battery_ground",
        atlas = COMMON_ITEM_ATLAS,
        image = "kei_battery",
        scale = 1.5,
    },
    repair_tool = {
        bank = COMMON_ITEM_BUILD,
        build = COMMON_ITEM_BUILD,
        anim = "kei_repair_tool_ground",
        atlas = COMMON_ITEM_ATLAS,
        image = "kei_repair_tool",
        scale = 1.5,
    },
}

local function AssetImagePath(visual)
    if visual == nil then
        return nil
    end
    if visual.tex ~= nil then
        return visual.tex
    end
    if visual.atlas ~= nil then
        return visual.atlas:gsub("%.xml$", ".tex")
    end
    return visual.image ~= nil and "images/inventoryimages/" .. visual.image .. ".tex" or nil
end

local function SetWorldScale(inst, scale)
    scale = scale or 1
    inst.Transform:SetScale(scale, scale, scale)
end

local function ConsumeOne(inst)
    if inst.components.stackable ~= nil then
        inst.components.stackable:Get():Remove()
    else
        inst:Remove()
    end
end

local function MakeKeiDeviceEdible(inst)
    inst:AddTag("quickeat")

    inst:AddComponent("edible")
    inst.components.edible.foodtype = FOODTYPE.KEI_DEVICE
    inst.components.edible.healthvalue = 0
    inst.components.edible.hungervalue = 0
    inst.components.edible.sanityvalue = 0
end

-- 多个简单道具都只需要动画、背包、堆叠和标签，因此抽成一个 prefab 工厂。
local function MakeSimpleInventoryItem(name, build, bank, anim, tags, image, postmaster, atlasname, scale)
    local assets = {
        Asset("ANIM", "anim/" .. build .. ".zip"),
    }
    if atlasname ~= nil then
        table.insert(assets, Asset("ATLAS", atlasname))
        table.insert(assets, Asset("IMAGE", atlasname:gsub("%.xml$", ".tex")))
    end

    local function fn()
        local inst = CreateEntity()

        -- 客户端和服务器都需要的网络实体基础组件。
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(bank or build)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim or "idle")
        SetWorldScale(inst, scale)

        if tags ~= nil then
            for _, tag in ipairs(tags) do
                inst:AddTag(tag)
            end
        end

        MakeInventoryFloatable(inst, "small", nil, 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            -- 客户端只负责表现，具体组件和状态只在主机端创建。
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        if image ~= nil then
            inst.components.inventoryitem.atlasname = atlasname
            inst.components.inventoryitem:ChangeImageName(image)
        end

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        if postmaster ~= nil then
            postmaster(inst)
        end

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(name, fn, assets)
end

local function ClearBoundTarget(inst)
    if inst.kei_bound_target ~= nil and inst.kei_bound_clear_fn ~= nil then
        inst:RemoveEventCallback("death", inst.kei_bound_clear_fn, inst.kei_bound_target)
        inst:RemoveEventCallback("onremove", inst.kei_bound_clear_fn, inst.kei_bound_target)
    end

    inst.kei_bound_prefab = nil
    inst.kei_bound_guid = nil
    inst.kei_bound_target = nil
    inst.kei_bound_clear_fn = nil
end

local function SetBoundTarget(inst, target)
    -- 空白 CD 记录一次绑定目标；目标死亡或移除后自动回到可重新绑定状态。
    ClearBoundTarget(inst)

    if target == nil then
        return
    end

    inst.kei_bound_prefab = target.prefab
    inst.kei_bound_guid = target.GUID
    inst.kei_bound_target = target
    inst.kei_bound_clear_fn = function(target_inst)
        if inst:IsValid() and inst.kei_bound_guid == target_inst.GUID then
            ClearBoundTarget(inst)
        end
    end
    inst:ListenForEvent("death", inst.kei_bound_clear_fn, target)
    inst:ListenForEvent("onremove", inst.kei_bound_clear_fn, target)
end

local function BlankCDOnSave(inst, data)
    -- 存档只保留 prefab 类型，避免把运行时实体引用写进存档。
    data.bound_prefab = inst.kei_bound_prefab
end

local function BlankCDOnLoad(inst, data)
    if data ~= nil then
        inst.kei_bound_prefab = data.bound_prefab
    end
end

local function MakeDeviceItem(name, visual_key, tags, max_stack_size, on_eaten)
    local visual = ITEM_VISUALS[visual_key]
    local assets = {
        Asset("ANIM", "anim/" .. visual.build .. ".zip"),
        Asset("ATLAS", visual.atlas),
        Asset("IMAGE", AssetImagePath(visual)),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        SetWorldScale(inst, visual.scale)
        inst.AnimState:SetBank(visual.bank)
        inst.AnimState:SetBuild(visual.build)
        inst.AnimState:PlayAnimation(visual.anim)

        if tags ~= nil then
            for _, tag in ipairs(tags) do
                inst:AddTag(tag)
            end
        end

        MakeInventoryFloatable(inst, "small", nil, 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = visual.atlas
        inst.components.inventoryitem:ChangeImageName(visual.image)

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = max_stack_size or TUNING.STACK_SIZE_SMALLITEM

        MakeKeiDeviceEdible(inst)
        if on_eaten ~= nil then
            inst.components.edible:SetOnEatenFn(on_eaten)
        end
        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(name, fn, assets)
end

local function MakeBattery()
    return MakeDeviceItem("kei_battery", "battery", { "kei_battery" })
end

local function MakeRepairTool()
    return MakeDeviceItem("kei_repair_tool", "repair_tool", { "kei_repair_tool" })
end

local function ExperiencePackOnEaten(inst, eater)
    local experience = eater ~= nil
        and eater.components ~= nil
        and eater.components.kei_experience
        or nil
    if experience ~= nil then
        experience:DoDelta(TUNING.KEI_EXPERIENCE_PACK_AMOUNT or 1000)
    end
end

local function MakeExperiencePack()
    return MakeDeviceItem(
        "kei_experience_pack",
        "analysis_cd",
        { "kei_experience_pack" },
        40,
        ExperiencePackOnEaten
    )
end

local function MakeBlankCD()
    local visual = ITEM_VISUALS.blank_cd
    local assets = {
        Asset("ANIM", "anim/" .. visual.build .. ".zip"),
        Asset("ATLAS", visual.atlas),
        Asset("IMAGE", AssetImagePath(visual)),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        SetWorldScale(inst, visual.scale)
        inst.AnimState:SetBank(visual.bank)
        inst.AnimState:SetBuild(visual.build)
        inst.AnimState:PlayAnimation(visual.anim)

        inst:AddTag("kei_blank_cd")
        inst:AddTag("kei_data_cd")

        MakeInventoryFloatable(inst, "med", 0.02, 0.7)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = visual.atlas
        inst.components.inventoryitem:ChangeImageName(visual.image)

        inst.SetBoundTarget = SetBoundTarget
        inst.ClearBoundTarget = ClearBoundTarget
        -- 空白 CD 的绑定状态需要跨存档保留。
        inst.OnSave = BlankCDOnSave
        inst.OnLoad = BlankCDOnLoad
        inst:ListenForEvent("onremove", ClearBoundTarget)

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_blank_cd", fn, assets)
end

local COMBAT_PROTOCOLS = CombatProtocolDefs.COMBAT_PROTOCOLS
local LIFE_PROTOCOLS = LifeProtocolDefs.LIFE_PROTOCOLS
local PET_PROTOCOLS = PetProtocolDefs.PET_PROTOCOLS

local function GetPrefabDisplayName(prefab)
    return prefab ~= nil and (STRINGS.NAMES[string.upper(prefab)] or prefab) or nil
end

local function SetNamedName(inst, name)
    if name ~= nil and inst.components.named ~= nil then
        inst.components.named:SetName(name)
    end
end

local DEFAULT_ANALYSIS_VISUAL = {
    bank = ITEM_VISUALS.analysis_cd.bank,
    build = ITEM_VISUALS.analysis_cd.build,
    anim = ITEM_VISUALS.analysis_cd.anim,
    atlas = ITEM_VISUALS.analysis_cd.atlas,
    image = ITEM_VISUALS.analysis_cd.image,
    scale = ITEM_VISUALS.analysis_cd.scale,
}

local function UseEquipmentVisual()
    return TUNING.KEI_ANALYSIS_USE_EQUIPMENT_VISUAL == true
end

local function SetInventoryImage(inst, imagename, atlasname, fallback)
    if inst.components.inventoryitem == nil then
        return
    end
    inst.components.inventoryitem.atlasname = atlasname
    inst.components.inventoryitem:ChangeImageName(imagename or fallback or "wagstaff_item_2")
end

local function SetAnalysisWorldAnimation(inst, bank, build, anim)
    local use_default_visual = bank == nil and build == nil and anim == nil
    bank = bank or DEFAULT_ANALYSIS_VISUAL.bank
    build = build or DEFAULT_ANALYSIS_VISUAL.build
    anim = anim or DEFAULT_ANALYSIS_VISUAL.anim

    local success = pcall(function()
        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)
        SetWorldScale(inst, use_default_visual and DEFAULT_ANALYSIS_VISUAL.scale or nil)
    end)

    if not success and bank ~= DEFAULT_ANALYSIS_VISUAL.bank then
        inst.AnimState:SetBank(DEFAULT_ANALYSIS_VISUAL.bank)
        inst.AnimState:SetBuild(DEFAULT_ANALYSIS_VISUAL.build)
        inst.AnimState:PlayAnimation(DEFAULT_ANALYSIS_VISUAL.anim)
        SetWorldScale(inst, DEFAULT_ANALYSIS_VISUAL.scale)
    end
end

local WORLD_ANIM_CANDIDATES = {
    "anim",
    "idle",
    "idle_loop",
    "idle1",
    "idle2",
    "idle3",
    "idle4",
}

local function GetCurrentOrFallbackAnim(source, fallback)
    if source ~= nil and source.AnimState ~= nil then
        for _, anim in ipairs(WORLD_ANIM_CANDIDATES) do
            if source.AnimState:IsCurrentAnimation(anim) then
                return anim
            end
        end
    end
    return fallback or "anim"
end

local function GetSkinBuild(source)
    if source == nil or source.GetSkinBuild == nil then
        return nil
    end
    local success, skin_build = pcall(source.GetSkinBuild, source)
    return success and skin_build or nil
end

local function GetAnalysisVisualFromSource(data)
    if data == nil or data.source == nil then
        return nil
    end

    local success, source = pcall(SpawnPrefab, data.source, data.skin_name)
    if not success then
        source = nil
    end
    if source == nil then
        return nil
    end

    source:AddTag("INLIMBO")
    if source.Hide ~= nil then
        source:Hide()
    elseif source.entity ~= nil and source.entity.Hide ~= nil then
        source.entity:Hide()
    end
    if source.components.inventoryitem ~= nil and source.components.inventoryitem.Hide ~= nil then
        source.components.inventoryitem:Hide()
    end

    local visual = nil
    if source.AnimState ~= nil then
        local visual_success, visual_data = pcall(function()
            return {
                bank = source.AnimState:GetBankHash(),
                build = data.skin_build or GetSkinBuild(source) or source.AnimState:GetBuild(),
                anim = GetCurrentOrFallbackAnim(source, data.visual_anim),
            }
        end)
        visual = visual_success and visual_data or nil
    end

    if source.Remove ~= nil then
        source:Remove()
    end
    return visual
end

local function ApplyAnalysisAppearance(inst, data, icon_image)
    if UseEquipmentVisual() and data.source ~= nil then
        SetInventoryImage(inst, icon_image, data.icon_atlas, DEFAULT_ANALYSIS_VISUAL.image)
        local visual = GetAnalysisVisualFromSource(data)
        SetAnalysisWorldAnimation(
            inst,
            (visual ~= nil and visual.bank or nil) or data.visual_bank,
            (visual ~= nil and visual.build or nil) or data.skin_build or data.visual_build,
            (visual ~= nil and visual.anim or nil) or data.visual_anim
        )
    else
        SetInventoryImage(inst, DEFAULT_ANALYSIS_VISUAL.image, DEFAULT_ANALYSIS_VISUAL.atlas)
        SetAnalysisWorldAnimation(inst)
    end
end

local function ApplyFixedProtocolData(inst, def, kind)
    inst.kei_protocol_definition = def
    inst.kei_protocol_data = {
        kind = kind,
        protocol = def.protocol,
        source = def.source_protocol or def.protocol,
        category = def.category,
        tier = def.tier,
        display_name = def.display_name,
        implemented = def.implemented == true,
    }

    if kind == "combat" then
        inst.kei_combat_protocol = def.protocol
        SetNamedName(inst, (def.display_name or def.protocol) .. "战斗协议")
    elseif kind == "life" then
        inst.kei_life_protocol = def.protocol
        SetNamedName(inst, def.display_name or def.protocol)
    elseif kind == "pet" then
        inst.kei_pet_protocol = def.protocol
        SetNamedName(inst, def.display_name or def.protocol)
    end
end

local function FixedProtocolDescriptionFn(inst)
    local def = inst.kei_protocol_definition
    return def ~= nil and def.description or nil
end

local function MakeFixedProtocolCD(def, kind, visual_key, tags, deps)
    local visual = ITEM_VISUALS[visual_key]
    if kind == "combat" and CombatProtocolDefs.GetProtocolVisual ~= nil then
        visual = CombatProtocolDefs.GetProtocolVisual(def.protocol) or visual
    end
    local assets = {
        Asset("ANIM", "anim/" .. visual.build .. ".zip"),
        Asset("ATLAS", visual.atlas),
        Asset("IMAGE", AssetImagePath(visual)),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        SetWorldScale(inst, visual.scale)
        inst.AnimState:SetBank(visual.bank)
        inst.AnimState:SetBuild(visual.build)
        inst.AnimState:PlayAnimation(visual.anim)

        inst:AddTag("kei_protocol_cd")
        if tags ~= nil then
            for _, tag in ipairs(tags) do
                inst:AddTag(tag)
            end
        end

        MakeInventoryFloatable(inst, kind == "combat" and "med" or "small", kind == "combat" and 0.02 or nil, kind == "combat" and 0.7 or 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst.components.inspectable.descriptionfn = FixedProtocolDescriptionFn
        inst:AddComponent("named")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = visual.atlas
        inst.components.inventoryitem:ChangeImageName(visual.image)
        inst.components.inventoryitem.keepondeath = true

        if kind == "pet" then
            inst:AddComponent("timer")
            PetData.Initialize(inst, def)
            inst.SetCapturedPet = function(cd, data)
                PetData.SetCapturedPet(cd, data)
            end
            inst.OnSave = PetData.OnSave
            inst.OnLoad = PetData.OnLoad
        else
            ApplyFixedProtocolData(inst, def, kind)
        end
        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(def.prefab, fn, assets, deps)
end

local function MakeCombatProtocolCDs()
    local prefabs = {}
    for _, def in ipairs(CombatProtocolDefs.COMBAT_PROTOCOL_LIST) do
        table.insert(prefabs, MakeFixedProtocolCD(def, "combat", "combat_cd", { "kei_combat_protocol", "kei_data_cd" }, { "buff_electricattack", "electrichitsparks", "electrichitsparks_electricimmune", "shock_arc_fx", "electricchargedfx", "kei_rook_shield_pulse_fx" }))
    end
    return prefabs
end

local function MakeLifeProtocolCDs()
    local prefabs = {}
    for _, def in ipairs(LifeProtocolDefs.LIFE_PROTOCOL_LIST) do
        table.insert(prefabs, MakeFixedProtocolCD(def, "life", "life_cd", { "kei_life_protocol" }))
    end
    return prefabs
end

local function MakePetProtocolCDs()
    local prefabs = {}
    for _, def in ipairs(PetProtocolDefs.PET_PROTOCOL_LIST) do
        table.insert(prefabs, MakeFixedProtocolCD(def, "pet", "combat_cd", { "kei_pet_protocol", "kei_data_cd" }))
    end
    return prefabs
end
local function SetAnalysisData(inst, data)
    -- 解析 CD 保存装备解析结果，字段由 kei_actions.lua 的 AnalyzeEquipment 生成。
    data = data or {}
    local source_name = data.display_name or GetPrefabDisplayName(data.source)
    local icon_image = data.icon_image or data.source
    local damage_bonus = data.damage_bonus
    if damage_bonus == nil and data.damage_mult ~= nil and data.damage_mult > 1 then
        damage_bonus = data.damage_mult * TUNING.UNARMED_DAMAGE
    end
    inst.kei_protocol_data = {
        kind = "analysis",
        slot = data.slot or "hands",
        source = data.source,
        display_name = source_name,
        icon_image = icon_image,
        icon_atlas = data.icon_atlas,
        visual_bank = data.visual_bank,
        visual_build = data.visual_build,
        visual_anim = data.visual_anim,
        skin_name = data.skin_name,
        skin_build = data.skin_build,
        full_equipment = data.full_equipment == true,
        absorb = data.absorb or 0,
        damage_bonus = damage_bonus or 0,
        speed_mult = data.speed_mult or 1,
        planar_bonus = data.planar_bonus or 0,
        tool_actions = data.tool_actions,
        tool_tough = data.tool_tough or nil,
    }
    ApplyAnalysisAppearance(inst, data, icon_image)
    SetNamedName(inst, source_name ~= nil and ("数据化的 " .. source_name) or nil)
end

local function AnalysisCDOnSave(inst, data)
    data.protocol = inst.kei_protocol_data
end

local function AnalysisCDOnLoad(inst, data)
    inst:SetAnalysisData(data ~= nil and data.protocol or nil)
end

local function MakeAnalysisCD()
    local visual = ITEM_VISUALS.analysis_cd
    local assets = {
        Asset("ANIM", "anim/" .. visual.build .. ".zip"),
        Asset("ATLAS", visual.atlas),
        Asset("IMAGE", AssetImagePath(visual)),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        SetAnalysisWorldAnimation(inst)

        inst:AddTag("kei_protocol_cd")
        inst:AddTag("kei_analysis_protocol")

        MakeInventoryFloatable(inst, "small", nil, 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("named")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = visual.atlas
        inst.components.inventoryitem:ChangeImageName(visual.image)
        inst.components.inventoryitem.keepondeath = true

        inst.SetAnalysisData = SetAnalysisData
        inst.OnSave = AnalysisCDOnSave
        inst.OnLoad = AnalysisCDOnLoad
        -- 没有数据时给出安全默认值，避免 nil 字段影响协议槽刷新。
        inst:SetAnalysisData()

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_analysis_cd", fn, assets)
end

-- 核心协议道具统一使用 ITEM_VISUALS 中登记的专用贴图和地面动画。
local prefabs = {
    MakeBattery(),
    MakeRepairTool(),
    MakeExperiencePack(),
    MakeSimpleInventoryItem(
        "kei_analysis_tool",
        ITEM_VISUALS.analysis_tool.build,
        ITEM_VISUALS.analysis_tool.bank,
        ITEM_VISUALS.analysis_tool.anim,
        { "kei_analysis_tool" },
        ITEM_VISUALS.analysis_tool.image,
        nil,
        ITEM_VISUALS.analysis_tool.atlas,
        ITEM_VISUALS.analysis_tool.scale
    ),
    MakeBlankCD(),
    MakeAnalysisCD(),
}


for _, prefab in ipairs(MakeCombatProtocolCDs()) do
    table.insert(prefabs, prefab)
end
for _, prefab in ipairs(MakeLifeProtocolCDs()) do
    table.insert(prefabs, prefab)
end
for _, prefab in ipairs(MakePetProtocolCDs()) do
    table.insert(prefabs, prefab)
end

return unpack(prefabs)

