-- 蜂后高级协议：受击触发强化恐慌效果。
local BeequeenCommon = require("kei/protocols/combat/effects/beast/_beequeen_common")

local BEEQUEEN_SCARE_MUST_TAGS = { "_combat", "_health" }

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

-- 处理受击事件，根据协议等级触发附加防御效果。
function BeequeenEffect.OnAttacked(slots, inst, data)
    local attacker = data ~= nil and data.attacker or nil
    if TUNING.KEI_BEEQUEEN_PRESTIGE_MODE == "retaliate" then
        BeequeenCommon.ScareTarget(inst, attacker, TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5)
        return
    end

    -- area mode
    if not BeequeenCommon.IsValidScareTarget(inst, attacker) then
        return
    end
    if not BeequeenCommon.CooldownReady(slots) then
        return
    end

    BeequeenCommon.StartCooldown(slots, TUNING.KEI_BEEQUEEN_PANIC_COOLDOWN or 3)

    local duration = TUNING.KEI_BEEQUEEN_PANIC_DURATION or 5
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(
        x, y, z,
        TUNING.KEI_BEEQUEEN_PANIC_RADIUS or 8,
        BEEQUEEN_SCARE_MUST_TAGS,
        { "INLIMBO", "FX", "NOCLICK", "DECOR", "player", "playerghost", "epic" }
    )

    SpawnBeequeenScreechFx(inst)
    for _, ent in ipairs(ents) do
        BeequeenCommon.ScareTarget(inst, ent, duration)
    end
end

return BeequeenEffect
