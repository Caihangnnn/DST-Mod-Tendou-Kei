local CombatProtocolDefs = require("kei/protocols/combat")

local COMBAT_PROTOCOLS = CombatProtocolDefs.COMBAT_PROTOCOLS

local RECIPE_PREFIX = "kei_wanderingtradershop_combat_"
local PRODUCT_PREFIX = "kei_combat_data_cd_"
local STOCK_LIMIT = 3
local REFRESH_INTERVAL_DAYS = 5
local REFRESH_DELAY = 15
local REFRESH_ANNOUNCEMENT = "流浪商人：CD商品更新了！"

local RANDOM_UNCOMMON_ODDS = TUNING.WANDERINGTRADER_SHOP_RANDOM_UNCOMMON_ODDS or 0
local RANDOM_RARE_ODDS = TUNING.WANDERINGTRADER_SHOP_RANDOM_RARE_ODDS or 0

local LUNARRIFT_UNCOMMON = {
    "mutateddeerclops",
    "mutatedwarg",
    "mutatedbearger",
}

local LUNARRIFT_RARE = {
    "wagboss_robot",
    "alterguardian_phase4_lunarrift",
}

local RANDOM_UNCOMMON = {
    "eyeofterror",
    "daywalker",
    "daywalker2",
    "lordfruitfly",
    "malbatross",
}

local RANDOM_RARE = {
    "dragonfly",
    "minotaur",
    "vault_pillar_guard",
    "klaus",
    "toadstool",
    "beequeen",
}

local SEASONAL_ALWAYS = {
    spring = "moose",
    summer = "antlion",
    autumn = "bearger",
    winter = "deerclops",
}

local PROTOCOL_DISPLAY_NAMES = {
    deerclops = "独眼巨鹿",
    mutateddeerclops = "独眼晶体巨鹿",
    mutatedwarg = "附身座狼",
    mutatedbearger = "装甲熊獾",
    bearger = "熊獾",
    dragonfly = "龙蝇",
    moose = "麋鹿鹅",
    eyeofterror = "克眼",
    daywalker = "梦魇疯猪",
    daywalker2 = "拾荒疯猪",
    lordfruitfly = "果蝇王",
    minotaur = "远古守护者",
    vault_pillar_guard = "远古戍卫塔",
    wagboss_robot = "战争瓦器人",
    malbatross = "邪天翁",
    klaus = "克劳斯",
    toadstool = "蟾蜍",
    antlion = "蚁狮",
    beequeen = "蜂后",
    stalker_atrium = "织影者",
    alterguardian = "天体英雄",
    alterguardian_phase4_lunarrift = "天体后裔",
}

local function RecipeName(protocol)
    return RECIPE_PREFIX .. protocol
end

local function ProductName(protocol)
    return PRODUCT_PREFIX .. protocol
end

local function TradeDisplayName(protocol)
    local name = PROTOCOL_DISPLAY_NAMES[protocol]
        or (COMBAT_PROTOCOLS[protocol] ~= nil and COMBAT_PROTOCOLS[protocol].display_name)
        or protocol
    return name .. "战斗协议"
end

local function SetTradeStrings(protocol)
    local recipe_key = string.upper(RecipeName(protocol))
    STRINGS.NAMES[recipe_key] = TradeDisplayName(protocol)
    STRINGS.RECIPE_DESC[recipe_key] = "消耗空白数据记录 CD，换取该战斗协议。"
end

local function MakeWare(protocol)
    return {
        recipe = RecipeName(protocol),
        min = STOCK_LIMIT,
        max = STOCK_LIMIT,
        limit = STOCK_LIMIT,
    }
end

local function MakeWareGroup(protocol)
    local product = ProductName(protocol)
    return {
        [product] = MakeWare(protocol),
    }
end

local function AddRecipeForProtocol(protocol)
    if COMBAT_PROTOCOLS[protocol] == nil then
        return
    end

    SetTradeStrings(protocol)

    AddRecipe2(
        RecipeName(protocol),
        { Ingredient("kei_blank_cd", 1) },
        TECH.LOST,
        {
            limitedamount = true,
            nounlock = true,
            actionstr = "WANDERINGTRADERSHOP",
            sg_state = "give",
            product = ProductName(protocol),
            nameoverride = RecipeName(protocol),
            description = RecipeName(protocol),
            atlas = "images/inventoryimages/kei_combat_cd.xml",
            image = "kei_combat_cd.tex",
        }
    )
end

local function AddRecipeList(protocols)
    for _, protocol in ipairs(protocols) do
        AddRecipeForProtocol(protocol)
    end
end

AddRecipeList(LUNARRIFT_UNCOMMON)
AddRecipeList(LUNARRIFT_RARE)
AddRecipeList(RANDOM_UNCOMMON)
AddRecipeList(RANDOM_RARE)
AddRecipeForProtocol("alterguardian")
AddRecipeForProtocol("stalker_atrium")
for _, protocol in pairs(SEASONAL_ALWAYS) do
    AddRecipeForProtocol(protocol)
end

local function AddWareFromProtocol(inst, protocol)
    if inst.AddWares ~= nil and COMBAT_PROTOCOLS[protocol] ~= nil then
        inst:AddWares(MakeWareGroup(protocol))
    end
end

local function AddRandomWareFromList(inst, protocols)
    if #protocols > 0 then
        AddWareFromProtocol(inst, protocols[math.random(#protocols)])
    end
end

local function HasLunarRiftPortal()
    for _, ent in pairs(Ents) do
        if ent.prefab == "lunarrift_portal" and ent:IsValid() then
            return true
        end
    end
    return false
end

local function AddConditionalWares(inst)
    if TheWorld.state.moonphase == "full" then
        AddWareFromProtocol(inst, "alterguardian")
    end
    if TheWorld.state.moonphase == "new" then
        AddWareFromProtocol(inst, "stalker_atrium")
    end

    local seasonal_protocol = SEASONAL_ALWAYS[TheWorld.state.season]
    if seasonal_protocol ~= nil then
        AddWareFromProtocol(inst, seasonal_protocol)
    end

    if HasLunarRiftPortal() then
        if math.random() < RANDOM_UNCOMMON_ODDS then
            AddRandomWareFromList(inst, LUNARRIFT_UNCOMMON)
        end
        if math.random() < RANDOM_RARE_ODDS then
            AddRandomWareFromList(inst, LUNARRIFT_RARE)
        end
    end
end

local function ClearKeiWares(inst)
    local craftingstation = inst.components ~= nil and inst.components.craftingstation or nil
    if craftingstation == nil then
        return
    end

    for protocol in pairs(COMBAT_PROTOCOLS) do
        craftingstation:ForgetRecipe(RecipeName(protocol))
    end
end

local function IsKeiRefreshCycle(cycles)
    return (cycles or 0) % REFRESH_INTERVAL_DAYS == 0
end

local function AnnounceKeiRefresh()
    if TheNet ~= nil then
        TheNet:Announce(REFRESH_ANNOUNCEMENT)
    end
end

local function RefreshKeiWares(inst, force)
    local cycles = TheWorld.state.cycles or 0
    if not force and inst.kei_wanderingtrader_last_refresh_cycle == cycles then
        return
    end

    ClearKeiWares(inst)
    AddConditionalWares(inst)

    if math.random() < RANDOM_UNCOMMON_ODDS then
        AddRandomWareFromList(inst, RANDOM_UNCOMMON)
    end
    if math.random() < RANDOM_RARE_ODDS then
        AddRandomWareFromList(inst, RANDOM_RARE)
    end

    inst.kei_wanderingtrader_last_refresh_cycle = cycles
    AnnounceKeiRefresh()
end

local function CancelKeiRefreshTask(inst)
    if inst.kei_wanderingtrader_refresh_task ~= nil then
        inst.kei_wanderingtrader_refresh_task:Cancel()
        inst.kei_wanderingtrader_refresh_task = nil
    end
end

local function DoScheduledKeiRefresh(inst)
    inst.kei_wanderingtrader_refresh_task = nil
    if IsKeiRefreshCycle(TheWorld.state.cycles) then
        RefreshKeiWares(inst)
    end
end

local function ScheduleKeiRefresh(inst)
    CancelKeiRefreshTask(inst)

    local cycles = TheWorld.state.cycles or 0
    if not IsKeiRefreshCycle(cycles) then
        return
    end

    local elapsed = (TheWorld.state.time or 0) * TUNING.TOTAL_DAY_TIME
    local delay = REFRESH_DELAY - elapsed
    if delay <= 0 then
        inst.kei_wanderingtrader_refresh_task = inst:DoTaskInTime(0, DoScheduledKeiRefresh)
    else
        inst.kei_wanderingtrader_refresh_task = inst:DoTaskInTime(delay, DoScheduledKeiRefresh)
    end
end

local function OnCyclesChanged(inst)
    ScheduleKeiRefresh(inst)
end

AddPrefabPostInit("wanderingtrader", function(inst)
    if not TheWorld.ismastersim then
        return
    end

    local old_OnSave = inst.OnSave
    inst.OnSave = function(inst, data)
        if old_OnSave ~= nil then
            old_OnSave(inst, data)
        end
        data.kei_wanderingtrader_last_refresh_cycle = inst.kei_wanderingtrader_last_refresh_cycle
    end

    local old_OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
        if old_OnLoad ~= nil then
            old_OnLoad(inst, data)
        end
        inst.kei_wanderingtrader_last_refresh_cycle = data ~= nil and data.kei_wanderingtrader_last_refresh_cycle or nil
    end

    inst:WatchWorldState("cycles", OnCyclesChanged)
    inst:DoTaskInTime(0, ScheduleKeiRefresh)
    inst:ListenForEvent("onremove", CancelKeiRefreshTask)
end)
