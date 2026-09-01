local brain = require("brains/recorder/kei_recorder_klaus_minionbrain")

local assets = {
    Asset("ANIM", "anim/waxwell_shadow_mod.zip"),
    Asset("ANIM", "anim/waxwell_minion_spawn.zip"),
    Asset("ANIM", "anim/waxwell_minion_appear.zip"),
    Asset("ANIM", "anim/waxwell_minion_idle.zip"),
    Asset("ANIM", "anim/lavaarena_shadow_lunge.zip"),
    Asset("SOUND", "sound/maxwell.fsb"),
}

local prefabs = {
    "shadow_despawn",
    "shadow_glob_fx",
    "statue_transition_2",
    "nightmarefuel",
    "ocean_splash_med1",
    "ocean_splash_med2",
    "ocean_splash_small1",
    "ocean_splash_small2",
    "shadowstrike_slash_fx",
    "shadowstrike_slash2_fx",
}

local FIXED_DAMAGE_KEY = "kei_recorder_klaus_minion_damage"

local function DisplayNameFn(inst)
    local playername = inst.kei_recorder_klaus_playername_net ~= nil
        and inst.kei_recorder_klaus_playername_net:value()
        or nil
    if playername == nil or playername == "" then
        return STRINGS.NAMES.SHADOW_PROTECTOR or inst.name
    end

    local is_enemy = inst.kei_recorder_klaus_enemy_net ~= nil
        and inst.kei_recorder_klaus_enemy_net:value()
    return (is_enemy and "邪恶的" or "善良的") .. playername
end

local function IsValidArenaTarget(inst, target)
    if target == nil or not target:IsValid()
        or target.components == nil
        or target.components.health == nil
        or target.components.health:IsDead()
    then
        return false
    end

    local source = inst.kei_recorder_source
    return source ~= nil
        and source:IsValid()
        and source:IsNear(target, (TUNING.KEI_RECORDER_RANGE or 35) * 1.5)
end

local function FindFriendlyTarget(inst)
    local leader = inst.components.follower:GetLeader()
    if leader == nil or not leader:IsValid() then
        return nil
    end

    local leader_combat = leader.components.combat
    if leader_combat ~= nil then
        local target = leader_combat.target
        if IsValidArenaTarget(inst, target)
            and not target:HasTag("player")
            and inst.components.combat:CanTarget(target)
        then
            return target
        end
    end

    return FindEntity(
        leader,
        TUNING.KEI_RECORDER_RANGE or 35,
        function(target)
            return IsValidArenaTarget(inst, target)
                and not target:HasTag("player")
                and target.components.combat ~= nil
                and (target.components.combat.target == leader
                    or target.components.combat.target == inst)
                and inst.components.combat:CanTarget(target)
        end,
        { "_combat" },
        { "INLIMBO", "player", "companion" }
    )
end

local function KeepFriendlyTarget(inst, target)
    return IsValidArenaTarget(inst, target)
        and not target:HasTag("player")
        and inst.components.combat:CanTarget(target)
        and inst.components.follower:GetLeader() ~= nil
end

local function FindEnemyTarget(inst)
    local target = inst.kei_recorder_klaus_player
    return IsValidArenaTarget(inst, target)
        and inst.components.combat:CanTarget(target)
        and target
        or nil
end

local function KeepEnemyTarget(inst, target)
    return target == inst.kei_recorder_klaus_player and IsValidArenaTarget(inst, target)
end

local function ConfigureDamage(inst)
    local health = inst.components.health
    local old_deltamodifierfn = health.deltamodifierfn
    inst.kei_recorder_klaus_old_deltamodifierfn = old_deltamodifierfn
    health.deltamodifierfn = function(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
        if old_deltamodifierfn ~= nil then
            local modified = old_deltamodifierfn(component, amount, overtime, cause, ignore_invincible, afflicter, ignore_absorb)
            if modified ~= nil then
                amount = modified
            end
        end
        return amount < 0 and -(TUNING.KEI_RECORDER_KLAUS_MINION_DAMAGE or 10) or amount
    end

    health:SetMaxHealth(TUNING.KEI_RECORDER_KLAUS_MINION_MAX_HEALTH or 50)
    -- Keep this numeric because the vanilla protector's health-clamp task
    -- reads it with math.abs(). The modifier above still enforces exactly 10
    -- damage per hit.
    health:SetMaxDamageTakenPerHit(TUNING.KEI_RECORDER_KLAUS_MINION_DAMAGE or 10)
    health.nofadeout = true
    inst.components.combat:SetDefaultDamage(0)
    inst.components.combat:SetAttackPeriod(TUNING.SHADOWWAXWELL_PROTECTOR_ATTACK_PERIOD or 2)
    inst.components.combat.playerdamagepercent = 1
    inst.components.combat.externaldamagemultipliers:RemoveModifier(inst, FIXED_DAMAGE_KEY)
end

local function fn(sim)
    local original = Prefabs["shadowprotector"]
    if original == nil or original.fn == nil then
        return nil
    end

    local inst = original.fn(sim)
    if inst == nil then
        return nil
    end

    inst:SetPrefabName("kei_recorder_klaus_minion")
    inst:SetPrefabNameOverride("shadowprotector")
    inst:AddTag("kei_recorder_klaus_minion")
    inst:AddTag("kei_recorder_klaus_soul_healable")
    inst.kei_recorder_klaus_playername_net = net_string(
        inst.GUID,
        "kei_recorder_klaus_minion.playername"
    )
    inst.kei_recorder_klaus_enemy_net = net_bool(
        inst.GUID,
        "kei_recorder_klaus_minion.enemy"
    )
    inst.displaynamefn = DisplayNameFn
    inst.entity:SetPristine()
    inst.persists = false

    if not TheWorld.ismastersim then
        return inst
    end

    if inst.components.timer ~= nil then
        inst.components.timer:StopTimer("obliviate")
    end
    -- Recorder minions are owned by the recorder. Do not inherit the vanilla
    -- protector's idle/hibernate removal timer; RecorderKlaus.Remove handles
    -- their lifetime when recording ends.
    inst.OnEntitySleep = function(self)
        if self._obliviatetask ~= nil then
            self._obliviatetask:Cancel()
            self._obliviatetask = nil
        end
    end
    inst.OnEntityWake = function(self)
        if self._obliviatetask ~= nil then
            self._obliviatetask:Cancel()
            self._obliviatetask = nil
        end
    end
    inst.isprotector = true
    inst.despawnpetloot = false
    inst:SetBrain(brain)
    ConfigureDamage(inst)

    inst.ConfigureRecorderKlausMinion = function(self, player, friendly, damage)
        self.kei_recorder_klaus_player = player
        self.kei_recorder_klaus_enemy = not friendly
        if self.kei_recorder_klaus_playername_net ~= nil then
            local playername = player ~= nil and player.name or nil
            if (playername == nil or playername == "")
                and player ~= nil
                and player.userid ~= nil
                and TheNet ~= nil
                and TheNet.GetClientTableForUser ~= nil
            then
                local client = TheNet:GetClientTableForUser(player.userid)
                playername = client ~= nil and client.name or nil
            end
            if playername == nil or playername == "" then
                playername = player ~= nil and player:GetDisplayName() or ""
            end
            self.kei_recorder_klaus_playername_net:set(playername or "")
        end
        if self.kei_recorder_klaus_enemy_net ~= nil then
            self.kei_recorder_klaus_enemy_net:set(not friendly)
        end
        self.components.health:SetPercent(1)
        self.components.skinner:CopySkinsFromPlayer(player, true)
        self.components.combat:SetDefaultDamage(
            TUNING.KEI_RECORDER_KLAUS_MINION_ATTACK_DAMAGE or 100
        )

        if friendly then
            self.AnimState:SetMultColour(1, 1, 1, 1)
            self.AnimState:SetAddColour(0, 0, 0, 0)
            self:RemoveTag("hostile")
            self:RemoveTag("monster")
            self.components.follower:SetLeader(player)
            self.components.combat:SetRetargetFunction(.5, FindFriendlyTarget)
            self.components.combat:SetKeepTargetFunction(KeepFriendlyTarget)
        else
            self:AddTag("hostile")
            self:AddTag("monster")
            self.components.follower:SetLeader(nil)
            self.components.combat:SetRetargetFunction(.5, FindEnemyTarget)
            self.components.combat:SetKeepTargetFunction(KeepEnemyTarget)
            self.AnimState:SetMultColour(0, 0, 0, 1)
            self.AnimState:SetAddColour(0, 0, 0, 0)
            self.components.combat:SetTarget(player)
            self:ListenForEvent("attacked", function(inst2)
                if inst2:IsValid() and inst2.components.combat ~= nil then
                    inst2.components.combat:SetTarget(inst2.kei_recorder_klaus_player)
                end
            end)
        end

        if self.SaveSpawnPoint ~= nil then
            self:SaveSpawnPoint()
        end
        if self.sg ~= nil then
            self.sg:GoToState("spawn")
        end
    end

    return inst
end

return Prefab("kei_recorder_klaus_minion", fn, assets, prefabs)
