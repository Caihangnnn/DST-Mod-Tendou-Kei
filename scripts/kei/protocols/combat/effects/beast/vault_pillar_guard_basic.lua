-- 远古戍卫塔初级协议：旋转攻击。
local VaultPillarGuardCommon = require("kei/protocols/combat/effects/beast/_vault_pillar_guard_common")

local VaultPillarGuardBasicEffect = {}
local SOURCE = "vault_pillar_guard_basic"

-- 启用协议效果，并注册该协议提供的持续能力。
function VaultPillarGuardBasicEffect.Enable(slots, inst)
    if VaultPillarGuardCommon.HasAdvanced(slots) then
        VaultPillarGuardCommon.DisableSpinAttack(slots, inst, SOURCE)
        return
    end
    VaultPillarGuardCommon.EnableSpinAttack(slots, inst, SOURCE)
end

-- 关闭协议效果，并清理启用时注册的持续能力。
function VaultPillarGuardBasicEffect.Disable(slots, inst)
    VaultPillarGuardCommon.DisableSpinAttack(slots, inst, SOURCE)
end

return VaultPillarGuardBasicEffect
