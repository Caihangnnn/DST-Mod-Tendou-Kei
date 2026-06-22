-- 蜂后协议：被攻击时触发恐惧威压（嘶吼领域 / 反制攻击者）。

local BEEQUEEN_SCARE_MUST_TAGS = { "_combat", "_health" }
local BEEQUEEN_SCARE_EXCLUDE_TAGS = { "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost", "epic" }

local function IsValidBeequeenScareTarget(owner, target)
    return owner ~= nil
        and owner:IsValid()
        and target ~= nil
        and target:IsValid()
        and target ~= owner
        and target.entity:IsVisible()
        and not target:IsInLimbo()
        and not target:HasTag("player")
        and not target:HasTag("playerghost")
        and not target:HasTag("epic")
        and target.components.health ~= nil
        and not target.components.health:IsDead()
end

local function ScareBeequeenTarget(owner, target, duration)
    if not IsValidBeequeenScareTarget(owner, target) then
        return
    end

    target:PushEvent("epicscare", { scarer = owner, duration = duration })

    if target.components.hauntable ~= nil and target.components.hauntable.panicable then
        target.components.hauntable:Panic(duration)
    end

    if target.components.combat ~= nil and target.components.combat:TargetIs(owner) then
        target.components.combat:SetTarget(nil)
    end
end

local function SpawnBeequeenScreechFx(inst)
    local fx = SpawnPrefab("battlesong_instant_panic_fx")
    if fx ~= nil then
        fx.Transform:SetNoFaced()
        inst:AddChild(fx)
    end

    if inst.SoundEmitter ~= nil then
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/bee_queen/taunt")
    end
    ShakeAllCameras(CAMERASHAKE.FULL, 1, .015, .3, inst, 30)
end

local BeequeenEffect = {}

function BeequeenEffect.OnAttacked(slots, inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if TUNING.KEI_BEEQUEEN_PRESTIGE_MODE == "retaliate" then
        ScareBeequeenTarget(inst, attacker, TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5)
        return
    end

    -- area mode
    if not IsValidBeequeenScareTarget(inst, attacker) then
        return
    end

    local now = GetTime()
    if slots._kei_beequeen_panic_ready_time ~= nil and now < slots._kei_beequeen_panic_ready_time then
        return
    end

    slots._kei_beequeen_panic_ready_time = now + (TUNING.KEI_BEEQUEEN_PANIC_COOLDOWN or 3)

    local duration = TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(
        x, y, z,
        TUNING.KEI_BEEQUEEN_PANIC_RADIUS or 8,
        BEEQUEEN_SCARE_MUST_TAGS,
        BEEQUEEN_SCARE_EXCLUDE_TAGS
    )

    SpawnBeequeenScreechFx(inst)
    for _, ent in ipairs(ents) do
        ScareBeequeenTarget(inst, ent, duration)
    end
end

return BeequeenEffect
