-- Kei backup body: a temporary, owner-bound ghost resurrection point.

local PlayerCommonExtensions = require("prefabs/player_common_extensions")

local BackupBody = {}

local SHADER_CUTOFF_HEIGHT = -0.125
local BACKUP_BODY_PREFAB = "kei_backupbody"

local FACE_SYMBOLS = { "face", "swap_face", "cheeks" }

local function IsValid(inst)
    return inst ~= nil and inst:IsValid()
end

local function GetExperience(inst)
    return inst ~= nil
        and inst.components ~= nil
        and inst.components.kei_experience ~= nil
        and inst.components.kei_experience
        or nil
end

local function HasEnoughReviveExperience(inst)
    local experience = GetExperience(inst)
    return experience ~= nil
        and (experience.current or 0) >= (TUNING.KEI_BACKUP_BODY_REVIVE_EXPERIENCE or 500)
end

local function HideFaceSymbols(inst)
    for _, symbol in ipairs(FACE_SYMBOLS) do
        inst.AnimState:HideSymbol(symbol)
    end
end

local function SetBackupBodyPose(inst)
    PlayerCommonExtensions.SetupBaseSymbolVisibility(inst)
    inst.AnimState:SetBank("wilson")
    -- Use Kei's own body build, then apply the same chassis override as the
    -- real dormant state. This keeps the final pose different from WX-78's.
    inst.AnimState:SetBuild("kei")
    inst.AnimState:AddOverrideBuild("wx_chassis")
    inst.AnimState:PlayAnimation("wx_chassis_poweroff")
    inst.AnimState:SetPercent("wx_chassis_poweroff", 1)
    inst.AnimState:Pause()
    HideFaceSymbols(inst)
end

local function ClearOwnerLink(inst)
    local owner = inst._kei_backup_owner
    if owner ~= nil then
        if owner.kei_backupbody == inst then
            owner.kei_backupbody = nil
        end
        if owner.kei_backupbody_pending == inst then
            owner.kei_backupbody_pending = nil
        end
    end
    inst._kei_backup_owner = nil
end

local function RemoveBackupBody(inst)
    if not IsValid(inst) or inst._kei_backupbody_removing then
        return
    end

    inst._kei_backupbody_removing = true
    if inst._kei_backupbody_dissolve_task ~= nil then
        inst._kei_backupbody_dissolve_task:Cancel()
        inst._kei_backupbody_dissolve_task = nil
    end
    inst:Remove()
end

local function StartBackupBodyDissolve(inst)
    if not IsValid(inst) or inst.AnimState == nil then
        return
    end

    local duration = math.max(0, TUNING.KEI_BACKUP_BODY_LIFETIME or 30)
    if duration <= 0 then
        RemoveBackupBody(inst)
        return
    end

    local tick_time = math.max(TheSim:GetTickTime(), FRAMES)
    local elapsed = 0
    inst.AnimState:SetErosionParams(0, SHADER_CUTOFF_HEIGHT, -1.0)
    inst._kei_backupbody_dissolve_task = inst:DoPeriodicTask(tick_time, function(body)
        if not IsValid(body) then
            return
        end

        elapsed = elapsed + tick_time
        local amount = math.min(1, elapsed / duration)
        body.AnimState:SetErosionParams(amount, SHADER_CUTOFF_HEIGHT, -1.0)
        if amount >= 1 then
            if body._kei_backupbody_dissolve_task ~= nil then
                body._kei_backupbody_dissolve_task:Cancel()
                body._kei_backupbody_dissolve_task = nil
            end
            body._kei_backupbody_removing = true
            body:Remove()
        end
    end)
end

local function RestoreSkeletonPrefab(inst)
    if not inst.kei_backupbody_skeleton_saved then
        return
    end

    inst.skeleton_prefab = inst.kei_backupbody_skeleton_prefab
    inst.kei_backupbody_skeleton_prefab = nil
    inst.kei_backupbody_skeleton_saved = nil
end

local function OnBackupBodyRemoved(inst)
    if inst._kei_backupbody_dissolve_task ~= nil then
        inst._kei_backupbody_dissolve_task:Cancel()
        inst._kei_backupbody_dissolve_task = nil
    end
    ClearOwnerLink(inst)
end

local function OnBackupBodyHaunt(inst, doer)
    if inst._kei_backupbody_removing or inst._kei_backupbody_revive_pending then
        return false
    end
    if doer == nil
        or not doer:HasTag("playerghost")
        or doer.prefab ~= "kei"
        or inst._kei_backup_owner_userid == nil
        or doer.userid ~= inst._kei_backup_owner_userid
        or not HasEnoughReviveExperience(doer)
    then
        return false
    end

    -- 复用原版玩家复活流程的意识传输动画；这里只临时伪装复活来源，
    -- 不参与 WX-78 的备份体生成、数量和电量逻辑。
    inst._kei_backupbody_revive_pending = true
    doer.kei_backupbody_pending = inst
    inst._kei_backupbody_original_prefab = inst.prefab
    inst.prefab = "wx78_backupbody"
    return true
end

local function SpawnBackupBody(owner)
    local body = SpawnPrefab(BACKUP_BODY_PREFAB)
    if body == nil then
        return nil
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    body.Transform:SetPosition(x, y, z)
    body.Transform:SetRotation(owner.Transform:GetRotation())
    body._kei_backup_owner = owner
    body._kei_backup_owner_userid = owner.userid

    if body.components.skinner ~= nil and owner.components.skinner ~= nil then
        body.components.skinner:CopySkinsFromPlayer(owner, true)
        SetBackupBodyPose(body)
    end

    owner.kei_backupbody = body
    -- 备份体在死亡动画结束后才出现，溶解也从出现这一刻开始播放。
    StartBackupBodyDissolve(body)
    return body
end

function BackupBody.OnPlayerDeath(inst)
    if inst:HasTag("playerghost") then
        return
    end

    if not BackupBody.CanSpawnBackupBody(inst) or inst.kei_backupbody_pending then
        return
    end

    -- 备份体由死亡动画结束时的 makeplayerghost/playerdied 事件生成。
    -- 提前清空 skeleton_prefab，使原版死亡产物流程不会生成骨架。
    inst.kei_backupbody_pending = true
    inst.kei_backupbody_skeleton_prefab = inst.skeleton_prefab
    inst.kei_backupbody_skeleton_saved = true
    inst.skeleton_prefab = nil
end

function BackupBody.CanSpawnBackupBody(inst)
    local experience = GetExperience(inst)
    return experience ~= nil
        and (experience.total or 0) >= (TUNING.KEI_BACKUP_BODY_TOTAL_EXPERIENCE or 1000)
        and not IsValid(inst.kei_backupbody)
        and not inst.kei_backupbody_pending
end

function BackupBody.OnPlayerRespawned(inst)
    local body = inst.kei_backupbody_pending or inst.kei_backupbody
    if not IsValid(body) then
        inst.kei_backupbody_pending = nil
        inst.kei_backupbody = nil
        RestoreSkeletonPrefab(inst)
        return
    end

    local revived_from_backup = body._kei_backupbody_revive_pending == true
    if revived_from_backup then
        local experience = GetExperience(inst)
        local cost = TUNING.KEI_BACKUP_BODY_REVIVE_EXPERIENCE or 500
        if experience ~= nil and (experience.current or 0) >= cost then
            experience:DoDelta(-cost)
        end
    end

    if body._kei_backupbody_original_prefab ~= nil then
        body.prefab = body._kei_backupbody_original_prefab
    end
    inst.kei_backupbody_pending = nil
    inst.kei_backupbody = nil
    RestoreSkeletonPrefab(inst)
    RemoveBackupBody(body)

    -- 复活流程会先进入原版 WX 电源启动状态，随后切换到 Kei 可操作实体的
    -- 唤醒状态，保持 Kei 自己的复活动画与休眠系统一致。
    if revived_from_backup and inst.sg ~= nil then
        inst.sg:GoToState("wx_poweron", false)
    end
end

function BackupBody.OnPlayerRemoved(inst)
    if IsValid(inst.kei_backupbody) then
        RemoveBackupBody(inst.kei_backupbody)
    end
    inst.kei_backupbody = nil
    inst.kei_backupbody_pending = nil
    RestoreSkeletonPrefab(inst)
end

function BackupBody.ConfigureCommon(inst)
    local function OnDeathFinished(player)
        if not player.kei_backupbody_pending then
            return
        end

        player.kei_backupbody_pending = nil
        if BackupBody.CanSpawnBackupBody(player) then
            SpawnBackupBody(player)
        end

        -- 仅在当前死亡产物事件处理完后恢复，避免原版回调看到 skeleton_prefab。
        player:DoTaskInTime(0, RestoreSkeletonPrefab)
    end

    inst:ListenForEvent("makeplayerghost", OnDeathFinished)
    inst:ListenForEvent("playerdied", OnDeathFinished)
end

function BackupBody.ConfigurePlayer(inst)
    inst.CanSpawnBackupBody = BackupBody.CanSpawnBackupBody
    inst:ListenForEvent("death", BackupBody.OnPlayerDeath)
    inst:ListenForEvent("ms_respawnedfromghost", BackupBody.OnPlayerRespawned)
    inst:ListenForEvent("onremove", BackupBody.OnPlayerRemoved)
end

function BackupBody.MakePrefab()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddDynamicShadow()
    local physics = inst.entity:AddPhysics()
    inst.entity:AddNetwork()

    inst:AddTag("kei_backupbody")
    inst.Transform:SetNoFaced()
    SetBackupBodyPose(inst)
    inst.DynamicShadow:SetSize(1.3, 0.6)

    -- Keep a click target for the ghost action without making the body block
    -- characters, items, or terrain.
    physics:SetMass(0)
    physics:SetCollisionGroup(COLLISION.CHARACTERS)
    physics:SetCollisionMask(0)
    physics:SetSphere(0.5)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    local skinner = inst:AddComponent("skinner")
    skinner:SetupNonPlayerData()
    skinner.useskintypeonload = true

    local hauntable = inst:AddComponent("hauntable")
    hauntable:SetHauntValue(TUNING.HAUNT_INSTANT_REZ)
    hauntable:SetOnHauntFn(OnBackupBodyHaunt)
    hauntable:SetAnimStateGetterFn(function(body)
        return body.AnimState
    end)

    inst:ListenForEvent("onremove", OnBackupBodyRemoved)
    return inst
end

return BackupBody
