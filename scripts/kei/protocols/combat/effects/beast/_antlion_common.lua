-- 蚁狮协议公共实现：风暴免疫与攻击生成沙刺。

local BeastCommon = require("kei/protocols/combat/effects/beast/_beast_common")
local AntlionCommon = {}

-- 判断来源表中是否还存在任意一个有效来源，用于决定是否保留沙尘暴免疫状态
-- 刷新 stormwatcher 组件，让沙尘暴等级与当前免疫状态立即重新计算
local function RefreshStormWatcher(inst)
    if inst.components ~= nil and inst.components.stormwatcher ~= nil then
        inst.components.stormwatcher:UpdateStormLevel()
    end
end

-- 为角色添加一层沙尘暴免疫来源
-- 使用来源表而不是单一开关，便于多个协议或效果同时共享这项免疫能力
function AntlionCommon.EnableStormImmunity(slots, inst, source)
    source = source or "antlion"
    inst._kei_antlion_storm_immunity_sources = inst._kei_antlion_storm_immunity_sources or {}
    if inst._kei_antlion_storm_immunity_sources[source] then
        RefreshStormWatcher(inst)
        return
    end

    inst._kei_antlion_storm_immunity_sources[source] = true
    RefreshStormWatcher(inst)
end

-- 刷新 miasmawatcher，让瘴气移速惩罚立即重新计算。
local function RefreshMiasmaWatcher(inst)
    if inst.components ~= nil and inst.components.miasmawatcher ~= nil then
        inst.components.miasmawatcher:UpdateMiasmaWalkSpeed()
    end
end

-- 为角色添加一层瘴气减速免疫来源。
-- 这里只处理移速惩罚，不会阻止 miasmadebuff 的持续伤害。
function AntlionCommon.EnableMiasmaImmunity(slots, inst, source)
    source = source or "antlion"
    inst._kei_antlion_miasma_immunity_sources = inst._kei_antlion_miasma_immunity_sources or {}
    if inst._kei_antlion_miasma_immunity_sources[source] then
        RefreshMiasmaWatcher(inst)
        return
    end

    inst._kei_antlion_miasma_immunity_sources[source] = true
    RefreshMiasmaWatcher(inst)
end

-- 移除指定来源提供的瘴气减速免疫。
function AntlionCommon.DisableMiasmaImmunity(slots, inst, source)
    source = source or "antlion"
    local sources = inst._kei_antlion_miasma_immunity_sources
    if sources ~= nil then
        sources[source] = nil
        if not BeastCommon.HasAnySource(sources) then
            inst._kei_antlion_miasma_immunity_sources = nil
        end
    end
    RefreshMiasmaWatcher(inst)
end

-- 移除指定来源提供的沙尘暴免疫
-- 只有当所有来源都清空后，角色才真正失去这项免疫效果
function AntlionCommon.DisableStormImmunity(slots, inst, source)
    source = source or "antlion"
    local sources = inst._kei_antlion_storm_immunity_sources
    if sources ~= nil then
        sources[source] = nil
        if not BeastCommon.HasAnySource(sources) then
            inst._kei_antlion_storm_immunity_sources = nil
        end
    end
    RefreshStormWatcher(inst)
end

-- 判断当前是否激活了高级蚁狮战斗协议
function AntlionCommon.HasAdvanced(slots)
    return BeastCommon.HasProtocol(slots, "antlion")
end

-- 校验目标是否仍然可以作为沙刺攻击对象
-- 会同时检查施法者、目标可见性、生命状态和 combat 的合法攻击关系
local function IsValidTarget(owner, target)
    return BeastCommon.IsValidCombatTarget(owner, target)
end

-- 在沙刺实体附近对目标结算一次伤害
-- 只有当目标仍在命中半径内时才会生效，避免目标提前离开时仍被击中
local function DoSandSpikeDamage(inst, owner, target, damage)
    if IsValidTarget(owner, target)
        and inst:IsValid()
        and target:GetDistanceSqToInst(inst) <= (TUNING.KEI_ANTLION_SANDSPIKE_DAMAGE_RADIUS or 1.1) ^ 2
    then
        target.components.combat:GetAttacked(owner, damage)
    end
end

-- 延迟武装沙刺伤害，使伤害时机与沙刺破土动画同步
local function ArmSandSpikeDamage(inst, owner, target, damage)
    inst:DoTaskInTime(2 * FRAMES, DoSandSpikeDamage, owner, target, damage)
end

-- 生成一个沙刺实体，并接管其伤害逻辑
-- 原版沙刺的 combat 伤害会被置零，实际伤害改为在动画结束后按自定义逻辑结算
function AntlionCommon.SpawnSandSpike(slots, inst, pt, target, prefab, damage)
    local spike = SpawnPrefab(prefab or "sandspike_tall")
    if spike == nil then
        return nil
    end

    damage = damage or TUNING.SANDSPIKE.DAMAGE.TALL
    spike.Transform:SetPosition(pt.x, 0, pt.z)
    if spike.components.combat ~= nil then
        spike.components.combat:SetDefaultDamage(0)
        spike.components.combat.playerdamagepercent = 0
    end
    spike:ListenForEvent("animover", function(s)
        if not s._kei_antlion_damage_armed then
            s._kei_antlion_damage_armed = true
            ArmSandSpikeDamage(s, inst, target, damage)
        end
    end)

    return spike
end

-- 以目标点为中心生成三角形分布的短沙刺，用于形成追加包围打击
function AntlionCommon.SpawnSandSpikeTriangle(slots, inst, center, target)
    local radius = TUNING.KEI_ANTLION_SANDSPIKE_TRIANGLE_RADIUS or 1.6
    local theta = math.random() * TWOPI
    for i = 0, 2 do
        local angle = theta + i * TWOPI / 3
        AntlionCommon.SpawnSandSpike(slots, inst,
            Vector3(center.x + math.cos(angle) * radius, 0, center.z + math.sin(angle) * radius),
            target,
            "sandspike_short",
            TUNING.KEI_ANTLION_SANDSPIKE_SHORT_DAMAGE or TUNING.SANDSPIKE.DAMAGE.SHORT
        )
    end
end

-- 在命中事件中尝试触发蚁狮沙刺效果
-- 需要满足冷却、概率和目标合法性条件，成功后会先生成中心高沙刺，再延迟生成外围三角沙刺
function AntlionCommon.TrySpawnSandSpikes(slots, inst, data)
    local target = data ~= nil and data.target or nil
    local now = GetTime()
    if (slots._kei_antlion_sandspike_ready_time or 0) > now
        or math.random() >= (TUNING.KEI_ANTLION_SANDSPIKE_CHANCE or 0.30)
        or not IsValidTarget(inst, target)
    then
        return
    end

    local center = target:GetPosition()
    if AntlionCommon.SpawnSandSpike(slots, inst, center, target,
        "sandspike_tall",
        TUNING.KEI_ANTLION_SANDSPIKE_TALL_DAMAGE or TUNING.SANDSPIKE.DAMAGE.TALL
    ) == nil then
        return
    end

    slots._kei_antlion_sandspike_ready_time = now + (TUNING.KEI_ANTLION_SANDSPIKE_COOLDOWN or 0.5)
    inst:DoTaskInTime(TUNING.KEI_ANTLION_SANDSPIKE_VERTEX_DELAY or 8 * FRAMES, function()
        if IsValidTarget(inst, target) then
            AntlionCommon.SpawnSandSpikeTriangle(slots, inst, center, target)
        end
    end)
end

return AntlionCommon
