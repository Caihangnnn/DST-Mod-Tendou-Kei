local RecorderBoss = require("kei/recorder_boss")
require("prefabs/veggies")

local WEED_PREFABS = {
    "weed_forgetmelots",
    "weed_tillweed",
    "weed_firenettle",
    "weed_ivy",
}

local WEED_PERIOD = 10
local WEED_LIFETIME = 30
local MINION_SCAN_PERIOD = 1
local FORGETMELOTS_BEE_PERIOD = 10
local FORGETMELOTS_BEE_COUNT = 3
local KILLER_BEE_LIFETIME = 30
local TILLWEED_PERIOD = 10
local TILLWEED_DAMAGE = 20
local CROP_LIFETIME = 30

local RecorderLordfruitfly = {}

local function IsValid(inst)
    return inst ~= nil and inst:IsValid() and not inst:IsInLimbo()
end

local function IsLivingPlayer(player)
    return IsValid(player)
        and player:HasTag("player")
        and not player:HasTag("playerghost")
        and player.components ~= nil
        and player.components.health ~= nil
        and not player.components.health:IsDead()
end

local function IsArenaPlayer(source, player)
    if not IsLivingPlayer(player) then
        return false
    end

    for _, arena_player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        if arena_player == player then
            return true
        end
    end
    return false
end

local function FindStage(growable, name)
    if growable == nil or growable.stages == nil then
        return nil
    end

    for index, stage in ipairs(growable.stages) do
        if stage.name == name then
            return index
        end
    end
    return nil
end

local function MatureWeed(weed)
    local growable = weed ~= nil and weed.components ~= nil and weed.components.growable or nil
    local stage = FindStage(growable, "bolting") or FindStage(growable, "full")
    if growable ~= nil and stage ~= nil then
        growable:SetStage(stage)
        growable:StopGrowing()
    end
end

local function PickCropPrefab()
    local choices = {}
    for veggie in pairs(VEGGIES or {}) do
        table.insert(choices, "farm_plant_" .. veggie)
    end
    return #choices > 0 and choices[math.random(#choices)] or "farm_plant_carrot"
end

local AttachMinion

local function SpawnFruitflyFromCrop(crop)
    if not IsValid(crop) then
        return
    end

    local owner = crop.kei_recorder_lordfruitfly_owner
    local x, y, z = crop.Transform:GetWorldPosition()
    crop:Remove()

    if not IsValid(owner) then
        return
    end

    local minion = SpawnPrefab("fruitfly")
    if minion ~= nil then
        minion.Transform:SetPosition(x, y, z)
        if minion.components ~= nil and minion.components.follower ~= nil then
            minion.components.follower:SetLeader(owner)
            AttachMinion(owner, minion)
        else
            minion:Remove()
        end
    end
end

local function SpawnRottenCrop(target, player)
    if not IsArenaPlayer(target.kei_recorder_source, player) then
        return
    end

    local x, _, z = player.Transform:GetWorldPosition()
    local crop = SpawnPrefab(PickCropPrefab())
    if crop == nil then
        return
    end

    crop.kei_recorder_lordfruitfly_owner = target
    target.kei_recorder_lordfruitfly_crops = target.kei_recorder_lordfruitfly_crops or {}
    table.insert(target.kei_recorder_lordfruitfly_crops, crop)
    crop.force_oversized = true
    crop.no_oversized = false
    crop.Transform:SetPosition(x, 0, z)

    local growable = crop.components ~= nil and crop.components.growable or nil
    local full_stage = FindStage(growable, "full")
    local rotten_stage = FindStage(growable, "rotten")
    if growable ~= nil and full_stage ~= nil then
        crop.is_oversized = true
        growable:SetStage(full_stage)
        growable:StopGrowing()
    end

    if player.components.combat ~= nil then
        player.components.combat:GetAttacked(crop, TILLWEED_DAMAGE)
    end
    player:PushEvent("knockback", {
        knocker = crop,
        radius = 2.5,
        strengthmult = 1.5,
        forcelanded = false,
    })

    if rotten_stage ~= nil then
        crop:DoTaskInTime(0.15, function(inst)
            if IsValid(inst) and inst.components.growable ~= nil then
                inst.components.growable:SetStage(rotten_stage)
                inst.components.growable:StopGrowing()
            end
        end)
    end

    crop.kei_recorder_lordfruitfly_lifetime_task = crop:DoTaskInTime(
        CROP_LIFETIME,
        SpawnFruitflyFromCrop
    )
end

local function SpawnKillerBees(weed)
    local owner = weed ~= nil and weed.kei_recorder_lordfruitfly_owner or nil
    if not IsValid(owner) or not IsValid(weed) then
        return
    end

    local players = RecorderBoss.GetArenaPlayers(owner.kei_recorder_source)
    if #players == 0 then
        return
    end

    owner.kei_recorder_lordfruitfly_bees = owner.kei_recorder_lordfruitfly_bees or {}
    local x, _, z = weed.Transform:GetWorldPosition()
    for i = 1, FORGETMELOTS_BEE_COUNT do
        local angle = math.random() * TWOPI
        local bee = SpawnPrefab("killerbee")
        if bee ~= nil then
            if bee.components.lootdropper ~= nil then
                bee.components.lootdropper:SetLoot(nil)
            end
            bee.Transform:SetPosition(x + math.cos(angle), 1, z + math.sin(angle))
            bee.kei_recorder_lordfruitfly_owner = owner
            bee.components.combat:SetTarget(players[((i - 1) % #players) + 1])
            bee.kei_recorder_lordfruitfly_lifetime_task = bee:DoTaskInTime(
                KILLER_BEE_LIFETIME,
                function(bee_inst)
                    bee_inst.kei_recorder_lordfruitfly_lifetime_task = nil
                    if not IsValid(bee_inst) then
                        return
                    end

                    if bee_inst.components.health ~= nil and not bee_inst.components.health:IsDead() then
                        bee_inst.components.health:Kill()
                    else
                        bee_inst:Remove()
                    end
                end
            )
            table.insert(owner.kei_recorder_lordfruitfly_bees, bee)
        end
    end
end

local function AttachWeed(weed, owner)
    weed.kei_recorder_lordfruitfly_owner = owner
    weed.kei_recorder_lordfruitfly_lifetime_task = weed:DoTaskInTime(
        WEED_LIFETIME,
        function(weed_inst)
            weed_inst.kei_recorder_lordfruitfly_lifetime_task = nil
            if IsValid(weed_inst) then
                weed_inst:Remove()
            end
        end
    )
    if weed.prefab == "weed_forgetmelots" then
        weed.kei_recorder_lordfruitfly_task = weed:DoPeriodicTask(
            FORGETMELOTS_BEE_PERIOD,
            SpawnKillerBees,
            FORGETMELOTS_BEE_PERIOD
        )
    elseif weed.prefab == "weed_tillweed" then
        weed.kei_recorder_lordfruitfly_task = weed:DoPeriodicTask(
            TILLWEED_PERIOD,
            function(weed_inst)
                local source = owner.kei_recorder_source
                local players = RecorderBoss.GetArenaPlayers(source)
                if #players > 0 then
                    SpawnRottenCrop(owner, players[math.random(#players)])
                end
            end,
            TILLWEED_PERIOD
        )
    end
end

local function SpawnRandomWeed(owner, planter)
    if not IsValid(owner) or not IsValid(planter) then
        return
    end

    local weed = SpawnPrefab(WEED_PREFABS[math.random(#WEED_PREFABS)])
    if weed == nil then
        return
    end

    local x, _, z = planter.Transform:GetWorldPosition()
    weed.Transform:SetPosition(x, 0, z)
    MatureWeed(weed)
    owner.kei_recorder_lordfruitfly_weeds = owner.kei_recorder_lordfruitfly_weeds or {}
    table.insert(owner.kei_recorder_lordfruitfly_weeds, weed)
    AttachWeed(weed, owner)
end

AttachMinion = function(owner, minion)
    if not IsValid(minion) or minion.kei_recorder_lordfruitfly_owner ~= nil then
        return
    end

    minion.kei_recorder_lordfruitfly_owner = owner
    owner.kei_recorder_lordfruitfly_minions = owner.kei_recorder_lordfruitfly_minions or {}
    table.insert(owner.kei_recorder_lordfruitfly_minions, minion)
    minion.kei_recorder_lordfruitfly_weed_task = minion:DoPeriodicTask(
        WEED_PERIOD,
        function(minion_inst)
            SpawnRandomWeed(owner, minion_inst)
        end,
        WEED_PERIOD
    )
end

local function ScanMinions(owner)
    if not IsValid(owner) then
        return
    end

    local x, _, z = owner.Transform:GetWorldPosition()
    local minions = TheSim:FindEntities(
        x,
        0,
        z,
        math.max(60, TUNING.KEI_RECORDER_RANGE or 35),
        { "fruitfly" },
        { "INLIMBO" }
    )
    for _, minion in ipairs(minions) do
        if minion ~= owner
            and minion.prefab == "fruitfly"
            and minion.components ~= nil
            and minion.components.follower ~= nil
            and minion.components.follower:GetLeader() == owner
        then
            AttachMinion(owner, minion)
        end
    end
end

local function OnOwnerAttacked(owner, data)
    local attacker = data ~= nil and data.attacker or nil
    if not IsArenaPlayer(owner.kei_recorder_source, attacker) then
        return
    end

    for _, weed in ipairs(owner.kei_recorder_lordfruitfly_weeds or {}) do
        if IsValid(weed) and weed.prefab == "weed_ivy" then
            weed:PushEvent("defend_farm_plant", { source = weed, target = attacker })
        end
    end
end

local function CleanupEntities(entities)
    for _, entity in ipairs(entities or {}) do
        if IsValid(entity) then
            if entity.kei_recorder_lordfruitfly_task ~= nil then
                entity.kei_recorder_lordfruitfly_task:Cancel()
                entity.kei_recorder_lordfruitfly_task = nil
            end
            if entity.kei_recorder_lordfruitfly_weed_task ~= nil then
                entity.kei_recorder_lordfruitfly_weed_task:Cancel()
                entity.kei_recorder_lordfruitfly_weed_task = nil
            end
            if entity.kei_recorder_lordfruitfly_lifetime_task ~= nil then
                entity.kei_recorder_lordfruitfly_lifetime_task:Cancel()
                entity.kei_recorder_lordfruitfly_lifetime_task = nil
            end
            entity:Remove()
        end
    end
end

function RecorderLordfruitfly.Apply(inst)
    if not IsValid(inst) then
        return false
    end

    RecorderLordfruitfly.Remove(inst)
    inst.kei_recorder_lordfruitfly_weeds = {}
    inst.kei_recorder_lordfruitfly_bees = {}
    inst.kei_recorder_lordfruitfly_minions = {}
    inst.kei_recorder_lordfruitfly_crops = {}
    inst.kei_recorder_lordfruitfly_weed_task = inst:DoPeriodicTask(
        WEED_PERIOD,
        function(owner)
            SpawnRandomWeed(owner, owner)
        end,
        WEED_PERIOD
    )
    inst.kei_recorder_lordfruitfly_minion_scan_task = inst:DoPeriodicTask(
        MINION_SCAN_PERIOD,
        ScanMinions,
        0
    )
    inst:ListenForEvent("attacked", OnOwnerAttacked)
    inst.kei_recorder_lordfruitfly_attacked_fn = OnOwnerAttacked
    return true
end

function RecorderLordfruitfly.Remove(inst)
    if inst == nil then
        return
    end

    if inst.kei_recorder_lordfruitfly_weed_task ~= nil then
        inst.kei_recorder_lordfruitfly_weed_task:Cancel()
        inst.kei_recorder_lordfruitfly_weed_task = nil
    end
    if inst.kei_recorder_lordfruitfly_minion_scan_task ~= nil then
        inst.kei_recorder_lordfruitfly_minion_scan_task:Cancel()
        inst.kei_recorder_lordfruitfly_minion_scan_task = nil
    end
    if inst.kei_recorder_lordfruitfly_attacked_fn ~= nil then
        inst:RemoveEventCallback("attacked", inst.kei_recorder_lordfruitfly_attacked_fn)
        inst.kei_recorder_lordfruitfly_attacked_fn = nil
    end

    CleanupEntities(inst.kei_recorder_lordfruitfly_weeds)
    CleanupEntities(inst.kei_recorder_lordfruitfly_bees)
    CleanupEntities(inst.kei_recorder_lordfruitfly_minions)
    CleanupEntities(inst.kei_recorder_lordfruitfly_crops)
    inst.kei_recorder_lordfruitfly_weeds = nil
    inst.kei_recorder_lordfruitfly_bees = nil
    inst.kei_recorder_lordfruitfly_minions = nil
    inst.kei_recorder_lordfruitfly_crops = nil
end

return RecorderLordfruitfly
