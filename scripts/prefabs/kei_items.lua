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
local function MakeSimpleInventoryItem(name, build, bank, anim, tags, image, postmaster)
    local assets = {
        Asset("ANIM", "anim/" .. build .. ".zip"),
    }

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

local function SetBoundTarget(inst, target)
    -- 空白 CD 记录一次绑定目标；GUID 用于同一局内追踪实体。
    inst.kei_bound_prefab = target ~= nil and target.prefab or nil
    inst.kei_bound_guid = target ~= nil and target.GUID or nil
    inst.kei_bound_target = target
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

local function MakeBlankCD()
    local assets = {
        Asset("ANIM", "anim/records.zip"),
        Asset("INV_IMAGE", "record"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("records")
        inst.AnimState:SetBuild("records")
        inst.AnimState:PlayAnimation("idle")

        inst:AddTag("kei_blank_cd")
        inst:AddTag("kei_data_cd")

        MakeInventoryFloatable(inst, "med", 0.02, 0.7)

        inst.entity:SetPristine()

        if not TheWorld.ismastersim then
            return inst
        end

        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:ChangeImageName("record")

        inst.SetBoundTarget = SetBoundTarget
        -- 空白 CD 的绑定状态需要跨存档保留。
        inst.OnSave = BlankCDOnSave
        inst.OnLoad = BlankCDOnLoad

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_blank_cd", fn, assets)
end

local COMBAT_PROTOCOLS = {
    deerclops = {
        kind = "combat",
        protocol = "deerclops",
        description = "独眼巨鹿数据：攻击附带冰冻，并免疫冻结与过冷。",
    },
    bearger = {
        kind = "combat",
        protocol = "bearger",
        description = "熊獾数据：攻击会扩散冲击，造成群体伤害。",
    },
    dragonfly = {
        kind = "combat",
        protocol = "dragonfly",
        description = "龙蝇数据：攻击会点燃目标，并免疫过热与火焰伤害。",
    },
    moose = {
        kind = "combat",
        protocol = "moose",
        display_name = "麋鹿鹅",
        description = "麋鹿鹅数据：获得带电攻击，并免疫潮湿。",
    },
    eyeofterror = {
        kind = "combat",
        protocol = "eyeofterror",
        display_name = "恐怖之眼",
        description = "恐怖之眼数据：右键冲锋到鼠标指定位置。",
    },
}

local function GetPrefabDisplayName(prefab)
    return prefab ~= nil and (STRINGS.NAMES[string.upper(prefab)] or prefab) or nil
end

local function SetNamedName(inst, name)
    if name ~= nil and inst.components.named ~= nil then
        inst.components.named:SetName(name)
    end
end

local DEFAULT_ANALYSIS_VISUAL = {
    bank = "wagstaff_personal_items",
    build = "wagstaff_personal_items",
    anim = "clipboard",
    image = "wagstaff_item_2",
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
    bank = bank or DEFAULT_ANALYSIS_VISUAL.bank
    build = build or DEFAULT_ANALYSIS_VISUAL.build
    anim = anim or DEFAULT_ANALYSIS_VISUAL.anim

    local success = pcall(function()
        inst.AnimState:SetBank(bank)
        inst.AnimState:SetBuild(build)
        inst.AnimState:PlayAnimation(anim)
    end)

    if not success and bank ~= DEFAULT_ANALYSIS_VISUAL.bank then
        inst.AnimState:SetBank(DEFAULT_ANALYSIS_VISUAL.bank)
        inst.AnimState:SetBuild(DEFAULT_ANALYSIS_VISUAL.build)
        inst.AnimState:PlayAnimation(DEFAULT_ANALYSIS_VISUAL.anim)
    end
end

local function ApplyAnalysisAppearance(inst, data, icon_image)
    if UseEquipmentVisual() and data.source ~= nil then
        SetInventoryImage(inst, icon_image, data.icon_atlas, DEFAULT_ANALYSIS_VISUAL.image)
        SetAnalysisWorldAnimation(inst, data.visual_bank, data.visual_build, data.visual_anim)
    else
        SetInventoryImage(inst, DEFAULT_ANALYSIS_VISUAL.image)
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

local function MakeCombatCD()
    local assets = {
        Asset("ANIM", "anim/records.zip"),
        Asset("INV_IMAGE", "record"),
    }

    local function fn()
        local inst = CreateEntity()

        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("records")
        inst.AnimState:SetBuild("records")
        inst.AnimState:PlayAnimation("idle")

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
        inst.components.inventoryitem:ChangeImageName("record")
        inst.components.inventoryitem.keepondeath = true

        inst.SetCombatData = SetCombatData
        inst.OnSave = CombatCDOnSave
        inst.OnLoad = CombatCDOnLoad
        -- 默认值保证直接生成的测试物品也能被协议槽识别。
        inst:SetCombatData("deerclops")

        MakeHauntableLaunch(inst)

        return inst
    end

    return Prefab("kei_combat_data_cd", fn, assets, { "buff_electricattack" })
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
        absorb = data.absorb or 0,
        damage_bonus = damage_bonus or 0,
        speed_mult = data.speed_mult or 1,
        planar_bonus = data.planar_bonus or 0,
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
    local assets = {
        Asset("ANIM", "anim/wagstaff_personal_items.zip"),
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
        inst.components.inventoryitem:ChangeImageName("wagstaff_item_2")
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
    return MakeSimpleInventoryItem(
        name,
        "wx_chips",
        "chips",
        "stacksize",
        { "kei_protocol_unlocker", "kei_protocol_mk" .. tostring(tier) },
        "wx78module_stacksize",
        function(inst)
            inst.kei_unlock_tier = tier
        end
    )
end

-- 这些道具未指定贴图的部分，统一使用设计要求的 wagstaff_item_2 或原版近似图标占位。
return MakeSimpleInventoryItem("kei_battery", "transistor", "transistor", "idle", { "kei_battery" }, "transistor", MakeKeiDeviceEdible),
    MakeSimpleInventoryItem("kei_repair_tool", "sewing_tape", "tape", "idle", { "kei_repair_tool" }, "sewing_tape", MakeKeiDeviceEdible),
    MakeSimpleInventoryItem("kei_analysis_tool", "wagstaff_tools", "wagstaff_tools_all", "radio", { "kei_analysis_tool" }, "wagstaff_tool_5"),
    MakeBlankCD(),
    MakeCombatCD(),
    MakeAnalysisCD(),
    MakeProtocolUnlocker("kei_protocol_mk1", 1),
    MakeProtocolUnlocker("kei_protocol_mk2", 2),
    MakeProtocolUnlocker("kei_protocol_mk3", 3)
