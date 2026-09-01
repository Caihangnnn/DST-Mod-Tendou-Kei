local RegisterKeiSkin = require("kei/skins/registry")

local assets = {
    Asset("ANIM", "anim/kei_skin_decagrammaton.zip"),
}

local skin = CreatePrefabSkin("kei_skin_decagrammaton", {
    base_prefab = "kei",
    type = "base",
    skins = {
        normal_skin = "kei_skin_decagrammaton",
        ghost_skin = "ghost_kei_build",
    },
    assets = assets,
    skin_tags = { "NORMAL", "KEI", "CHARACTER" },
    build_name_override = "kei_skin_decagrammaton",
    share_bigportrait_name = "kei_none",
    rarity = "Character",
})

STRINGS.SKIN_NAMES = STRINGS.SKIN_NAMES or {}
STRINGS.SKIN_DESCRIPTIONS = STRINGS.SKIN_DESCRIPTIONS or {}
STRINGS.SKIN_QUOTES = STRINGS.SKIN_QUOTES or {}
STRINGS.SKIN_NAMES.kei_skin_decagrammaton = "十字神名"
STRINGS.SKIN_DESCRIPTIONS.kei_skin_decagrammaton = ""
STRINGS.SKIN_QUOTES.kei_skin_decagrammaton = ""

RegisterKeiSkin("kei_skin_decagrammaton")
return skin
