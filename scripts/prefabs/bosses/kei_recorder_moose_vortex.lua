local RecorderBoss = require("kei/recorder/boss")

local assets = {
    Asset("ANIM", "anim/whirlbigportal.zip"),
    Asset("SOUND", "sound/rifts6.fsb"),
}

local VORTEX_UPDATE_PERIOD = TUNING.KEI_RECORDER_MOOSE_VORTEX_UPDATE_PERIOD or 0.2
local VORTEX_RADIUS = TUNING.KEI_RECORDER_MOOSE_VORTEX_RADIUS or 8
local VORTEX_SCALE = TUNING.KEI_RECORDER_MOOSE_VORTEX_SCALE or 0.9
local PULL_SPEED = TUNING.KEI_RECORDER_MOOSE_VORTEX_PULL_SPEED or 1.2
local SPIRAL_SPEED = TUNING.KEI_RECORDER_MOOSE_VORTEX_SPIRAL_SPEED or 1.5
local CENTER_RADIUS = VORTEX_RADIUS
    * (TUNING.KEI_RECORDER_MOOSE_VORTEX_CENTER_RADIUS_PERCENT or 0.2)
local CENTER_DAMAGE = TUNING.KEI_RECORDER_MOOSE_VORTEX_CENTER_DAMAGE or 2
local CENTER_DAMAGE_INTERVAL = TUNING.KEI_RECORDER_MOOSE_VORTEX_CENTER_DAMAGE_INTERVAL or 0.5
local LIFETIME = TUNING.KEI_RECORDER_MOOSE_VORTEX_LIFETIME or 40

local function RemoveVelocitySource(inst, player)
    if player ~= nil
        and player:IsValid()
        and player.components ~= nil
        and player.components.physicsmodifiedexternally ~= nil
    then
        player.components.physicsmodifiedexternally:RemoveSource(inst)
    end
end

local function ClearVelocitySources(inst)
    for player in pairs(inst.kei_recorder_moose_vortex_players or {}) do
        RemoveVelocitySource(inst, player)
    end
    inst.kei_recorder_moose_vortex_players = {}
end

local function UpdateVortex(inst)
    if inst.kei_recorder_moose_vortex_expiring then
        return
    end

    local source = inst.kei_recorder_source
    if source == nil or not source:IsValid() then
        inst:Remove()
        return
    end

    local x, _, z = inst.Transform:GetWorldPosition()
    local current = {}
    local now = GetTime()
    inst.kei_recorder_moose_vortex_next_damage = inst.kei_recorder_moose_vortex_next_damage or {}
    for _, player in ipairs(RecorderBoss.GetArenaPlayers(source)) do
        local px, _, pz = player.Transform:GetWorldPosition()
        local dx, dz = x - px, z - pz
        local distance_sq = dx * dx + dz * dz
        if distance_sq <= VORTEX_RADIUS * VORTEX_RADIUS then
            local distance = math.sqrt(distance_sq)
            current[player] = true

            if player.components.moisture ~= nil then
                player.components.moisture:DoDelta(1, true)
            end

            if player.components.physicsmodifiedexternally == nil then
                player:AddComponent("physicsmodifiedexternally")
            end
            local physics = player.components.physicsmodifiedexternally
            if physics ~= nil then
                physics:AddSource(inst)
                if distance > 0.05 then
                    local nx, nz = dx / distance, dz / distance
                    local tangent_x, tangent_z = -nz, nx
                    local distance_factor = math.min(1, distance / VORTEX_RADIUS)
                    local inward = PULL_SPEED * (0.35 + 0.65 * distance_factor)
                    local vx = nx * inward + tangent_x * SPIRAL_SPEED
                    local vz = nz * inward + tangent_z * SPIRAL_SPEED
                    physics:SetVelocityForSource(inst, vx, vz)
                else
                    physics:SetVelocityForSource(inst, 0, 0)
                end
            end

            if distance <= CENTER_RADIUS
                and player.components.health ~= nil
                and not player.components.health:IsDead()
                and now >= (inst.kei_recorder_moose_vortex_next_damage[player] or 0)
            then
                player.components.health:DoDelta(
                    -CENTER_DAMAGE,
                    true,
                    "kei_recorder_moose_vortex",
                    false,
                    inst
                )
                inst.kei_recorder_moose_vortex_next_damage[player] = now + CENTER_DAMAGE_INTERVAL
            end
        end
    end

    for player in pairs(inst.kei_recorder_moose_vortex_players or {}) do
        if not current[player] then
            RemoveVelocitySource(inst, player)
            inst.kei_recorder_moose_vortex_next_damage[player] = nil
        end
    end
    inst.kei_recorder_moose_vortex_players = current
end

local function ExpireVortex(inst)
    if not inst:IsValid() or inst.kei_recorder_moose_vortex_expiring then
        return
    end

    inst.kei_recorder_moose_vortex_expiring = true
    if inst.kei_recorder_moose_vortex_task ~= nil then
        inst.kei_recorder_moose_vortex_task:Cancel()
        inst.kei_recorder_moose_vortex_task = nil
    end
    ClearVelocitySources(inst)
    inst.AnimState:PlayAnimation("open_pst", false)
    inst:DoTaskInTime(1, function(vortex)
        if vortex:IsValid() then
            vortex:Remove()
        end
    end)
end

local function OnOpenAnimationOver(inst)
    inst:RemoveEventCallback("animover", OnOpenAnimationOver)
    if inst:IsValid() and not inst.kei_recorder_moose_vortex_expiring then
        inst.SoundEmitter:PlaySound("rifts6/whirlpool/whirlpool_LP", "kei_recorder_moose_vortex_loop")
    end
end

local function OnRemoveEntity(inst)
    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:KillSound("kei_recorder_moose_vortex_loop")
    end
    ClearVelocitySources(inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("NOBLOCK")
    inst.persists = false
    inst.Transform:SetScale(VORTEX_SCALE, VORTEX_SCALE, VORTEX_SCALE)

    inst.AnimState:SetBuild("whirlbigportal")
    inst.AnimState:SetBank("whirlbigportal")
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(ANIM_SORT_ORDER.OCEAN_WHIRLPORTAL)
    inst.AnimState:SetFinalOffset(2)
    inst.AnimState:PlayAnimation("open_pre")
    inst.AnimState:PushAnimation("open_loop", true)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then
        return inst
    end

    inst.SoundEmitter:PlaySound("rifts6/whirlpool/whirlpool_pre")
    inst:ListenForEvent("animover", OnOpenAnimationOver)
    inst.kei_recorder_moose_vortex_players = {}
    inst.kei_recorder_moose_vortex_next_damage = {}
    inst.OnRemoveEntity = OnRemoveEntity
    inst.kei_recorder_moose_vortex_task = inst:DoPeriodicTask(VORTEX_UPDATE_PERIOD, UpdateVortex)
    inst.kei_recorder_moose_vortex_lifetime_task = inst:DoTaskInTime(LIFETIME, ExpireVortex)
    return inst
end

return Prefab("kei_recorder_moose_vortex", fn, assets)
