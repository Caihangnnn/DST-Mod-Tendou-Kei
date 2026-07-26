-- 宠物战斗成长：Boss 死亡时，为附近出战宠物直接提升等级。
local PetData = require("kei/protocols/pet/data")

local BOSS_BLACKLIST = {
    leif = true,
    leif_sparse = true,
    spiderqueen = true,
}

local function OnBossDeath(boss)
    if boss == nil or BOSS_BLACKLIST[boss.prefab] then
        return
    end

    local x, y, z = boss.Transform:GetWorldPosition()
    local pets = TheSim:FindEntities(
        x,
        y,
        z,
        TUNING.KEI_PET_BOSS_GROWTH_RADIUS or 24,
        { "kei_protocol_pet" },
        { "INLIMBO" }
    )
    local rewarded = {}

    for _, pet in ipairs(pets) do
        local health = pet.components.health
        local cd = pet.kei_pet_cd
        if (health == nil or not health:IsDead())
            and cd ~= nil
            and cd:IsValid()
            and not rewarded[cd]
        then
            rewarded[cd] = true
            PetData.AddLevels(cd, TUNING.KEI_PET_BOSS_LEVEL_GAIN or 1)
        end
    end
end

AddComponentPostInit("health", function(health)
    local inst = health.inst
    if inst ~= nil and inst:HasTag("epic") and not BOSS_BLACKLIST[inst.prefab] then
        inst:ListenForEvent("death", OnBossDeath)
    end
end)
