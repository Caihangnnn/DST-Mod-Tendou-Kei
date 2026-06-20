local CombatProtocolDefs = require("kei_combat_protocol_defs")
local LifeProtocolDefs = require("kei_life_protocol_defs")

local ITEM_VISUALS = {
    analysis_cd = {
        bank = "kei_analysis_cd",
        build = "kei_analysis_cd",
        anim = "idle",
        atlas = "images/kei_analysis_cd.xml",
        image = "kei_analysis_cd",
        scale = 1.5,
    },
    analysis_tool = {
        bank = "kei_analysis_tool",
        build = "kei_analysis_tool",
        anim = "idle",
        atlas = "images/kei_analysis_tool.xml",
        image = "kei_analysis_tool",
        scale = 1.5,
    },
    blank_cd = {
        bank = "kei_blank_cd",
        build = "kei_blank_cd",
        anim = "idle",
        atlas = "images/kei_blank_cd.xml",
        image = "kei_blank_cd",
        scale = 1.5,
    },
    combat_cd = {
        bank = "kei_combat_cd",
        build = "kei_combat_cd",
        anim = "idle",
        atlas = "images/kei_combat_cd.xml",
        image = "kei_combat_cd",
        scale = 1.5,
    },
    life_cd = {
        bank = "kei_life_cd",
        build = "kei_life_cd",
        anim = "idle",
        atlas = "images/kei_life_cd.xml",
        image = "kei_life_cd",
        scale = 1.5,
    },
}

local function AssetImagePath(visual)
    return visual ~= nil and visual.image ~= nil and "images/" .. visual.image .. ".tex" or nil
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

local function MakeBattery()
    local assets = {
        Asset("ANIM", "anim/kei_battery.zip"),
        Asset("ATLAS", "images/kei_battery.xml"),
        Asset("IMAGE", "images/kei_battery.tex"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.Transform:SetScale(1.5, 1.5, 1.5)
        inst.AnimState:SetBank("kei_battery")
        inst.AnimState:SetBuild("kei_battery")
        inst.AnimState:PlayAnimation("idle")

        inst:AddTag("kei_battery")

        MakeInventoryFloatable(inst, "small", nil, 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = "images/kei_battery.xml"
        inst.components.inventoryitem:ChangeImageName("kei_battery")

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        MakeKeiDeviceEdible(inst)
        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_battery", fn, assets)
end

local function MakeRepairTool()
    local assets = {
        Asset("ANIM", "anim/kei_repair_tool.zip"),
        Asset("ATLAS", "images/kei_repair_tool.xml"),
        Asset("IMAGE", "images/kei_repair_tool.tex"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.Transform:SetScale(1.5, 1.5, 1.5)
        inst.AnimState:SetBank("kei_repair_tool")
        inst.AnimState:SetBuild("kei_repair_tool")
        inst.AnimState:PlayAnimation("idle")

        inst:AddTag("kei_repair_tool")

        MakeInventoryFloatable(inst, "small", nil, 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = "images/kei_repair_tool.xml"
        inst.components.inventoryitem:ChangeImageName("kei_repair_tool")

        inst:AddComponent("stackable")
        inst.components.stackable.maxsize = TUNING.STACK_SIZE_SMALLITEM

        MakeKeiDeviceEdible(inst)
        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_repair_tool", fn, assets)
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

local function SetCombatData(inst, protocol)
    -- 协议数据统一挂在 kei_protocol_data 上，供协议槽组件读取。
    protocol = COMBAT_PROTOCOLS[protocol] ~= nil and protocol or "deerclops"
    inst.kei_combat_protocol = protocol
    inst.kei_protocol_data = {
        kind = "combat",
        protocol = protocol,
        source = protocol,
    }
    SetNamedName(inst, (COMBAT_PROTOCOLS[protocol].display_name or GetPrefabDisplayName(protocol) or protocol) .. "战斗数据")
end

local function CombatCDDescriptionFn(inst)
    local protocol = inst.kei_combat_protocol
    return protocol ~= nil and COMBAT_PROTOCOLS[protocol] ~= nil and COMBAT_PROTOCOLS[protocol].description or nil
end

local function CombatCDOnSave(inst, data)
    data.protocol = inst.kei_combat_protocol
end

local function CombatCDOnLoad(inst, data)
    inst:SetCombatData(data ~= nil and data.protocol or nil)
end

local function MakeCombatCD(prefabname, default_protocol)
    prefabname = prefabname or "kei_combat_data_cd"
    default_protocol = default_protocol or "deerclops"

    local visual = ITEM_VISUALS.combat_cd
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
        inst:AddTag("kei_combat_protocol")
        inst:AddTag("kei_data_cd")

        MakeInventoryFloatable(inst, "med", 0.02, 0.7)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst.components.inspectable.descriptionfn = CombatCDDescriptionFn
        inst:AddComponent("named")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = visual.atlas
        inst.components.inventoryitem:ChangeImageName(visual.image)
        inst.components.inventoryitem.keepondeath = true

        inst.SetCombatData = SetCombatData
        inst.OnSave = CombatCDOnSave
        inst.OnLoad = CombatCDOnLoad
        -- 默认值保证直接生成的测试物品也能被协议槽识别。
        inst:SetCombatData(default_protocol)

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab(prefabname, fn, assets, { "buff_electricattack" })
end

local function MakeCombatShopCDs()
    local prefabs = {}
    for protocol in pairs(COMBAT_PROTOCOLS) do
        table.insert(prefabs, MakeCombatCD("kei_combat_data_cd_" .. protocol, protocol))
    end
    return prefabs
end

local function SetLifeData(inst, protocol)
    protocol = LIFE_PROTOCOLS[protocol] ~= nil and protocol or "map_teleport"
    inst.kei_life_protocol = protocol
    inst.kei_protocol_data = {
        kind = "life",
        protocol = protocol,
    }
    SetNamedName(inst, (LIFE_PROTOCOLS[protocol].display_name or protocol) .. "生活协议")
end

local function LifeCDDescriptionFn(inst)
    local protocol = inst.kei_life_protocol
    return protocol ~= nil and LIFE_PROTOCOLS[protocol] ~= nil and LIFE_PROTOCOLS[protocol].description or nil
end

local function LifeCDOnSave(inst, data)
    data.protocol = inst.kei_life_protocol
end

local function LifeCDOnLoad(inst, data)
    inst:SetLifeData(data ~= nil and data.protocol or nil)
end

local function MakeLifeCD()
    local visual = ITEM_VISUALS.life_cd
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
        inst:AddTag("kei_life_protocol")

        MakeInventoryFloatable(inst, "small", nil, 0.8)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst.components.inspectable.descriptionfn = LifeCDDescriptionFn
        inst:AddComponent("named")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = visual.atlas
        inst.components.inventoryitem:ChangeImageName(visual.image)
        inst.components.inventoryitem.keepondeath = true

        inst.SetLifeData = SetLifeData
        inst.OnSave = LifeCDOnSave
        inst.OnLoad = LifeCDOnLoad
        inst:SetLifeData("map_teleport")

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_life_cd", fn, assets)
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

local function MakeProtocolUnlocker(name, tier)
    -- 解锁模块只靠 tier 区分 Mk1/Mk2/Mk3，动作逻辑会读取这个字段。
    local mk_images = { "kei_mk1", "kei_mk2", "kei_mk3" }
    local mk_atlases = { "images/kei_mk1.xml", "images/kei_mk2.xml", "images/kei_mk3.xml" }
    local prefab = MakeSimpleInventoryItem(
        name,
        "wx_chips",
        "chips",
        "stacksize",
        { "kei_protocol_unlocker", "kei_protocol_mk" .. tostring(tier) },
        nil,
        function(inst)
            inst.kei_unlock_tier = tier
            -- 设置自定义图片和 atlas
            if inst.components.inventoryitem ~= nil then
                inst.components.inventoryitem.atlasname = mk_atlases[tier]
                inst.components.inventoryitem:ChangeImageName(mk_images[tier])
            end
        end
    )
    -- 添加自定义 atlas 资源
    table.insert(prefab.assets, Asset("ATLAS", mk_atlases[tier]))
    return prefab
end

-- 核心协议道具统一使用 ITEM_VISUALS 中登记的专用贴图和地面动画。
local prefabs = {
    MakeBattery(),
    MakeRepairTool(),
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
    MakeCombatCD(),
    MakeAnalysisCD(),
    MakeLifeCD(),
    MakeProtocolUnlocker("kei_protocol_mk1", 1),
    MakeProtocolUnlocker("kei_protocol_mk2", 2),
    MakeProtocolUnlocker("kei_protocol_mk3", 3),
}

for _, prefab in ipairs(MakeCombatShopCDs()) do
    table.insert(prefabs, prefab)
end

return unpack(prefabs)
