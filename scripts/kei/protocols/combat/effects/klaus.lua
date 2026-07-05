-- 克劳斯协议：攻击命中时概率抽取灵魂并治疗周围。

local WortoxSoulCommon = require("prefabs/wortox_soul_common")

local KlausEffect = {}

function KlausEffect.OnHitOther(slots, inst, data)
    local target = data and data.target
    if math.random() >= (TUNING.KEI_KLAUS_SOUL_CHANCE or 0.20)
        or target == nil
        or not target:IsValid()
        or not WortoxSoulCommon.HasSoul(target)
    then
        return
    end

    local soul = SpawnPrefab("wortox_soul")
    if soul == nil then
        return
    end

    local x, y, z = target.Transform:GetWorldPosition()
    soul.Transform:SetPosition(x, y, z)
    soul.persists = false
    soul.soulhealfinishing = true

    if soul._task ~= nil then
        soul._task:Cancel()
        soul._task = nil
    end
    if soul.components.inventoryitem ~= nil then
        soul.components.inventoryitem.canbepickedup = false
    end

    WortoxSoulCommon.DoHeal(soul)
    soul.AnimState:PlayAnimation("idle_pst")
    soul.SoundEmitter:PlaySound("dontstarve/characters/wortox/soul/spawn", nil, .5)
    soul:ListenForEvent("animover", soul.Remove)
end

return KlausEffect
