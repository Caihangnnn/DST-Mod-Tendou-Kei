local RegisterKeiSkin = require("kei/skins/registry")

local assets = {
    Asset("ANIM", "anim/kei.zip"),
    Asset("ANIM", "anim/ghost_kei_build.zip"),
}

local skin = CreatePrefabSkin("kei_none", {
    base_prefab = "kei",
    type = "base",
    skins = {
        normal_skin = "kei",
        ghost_skin = "ghost_kei_build",
    },
    assets = assets,
    skin_tags = { "BASE", "KEI", "CHARACTER" },
    build_name_override = "kei",
    share_bigportrait_name = "kei_none",
    rarity = "Character",
})

STRINGS.SKIN_NAMES = STRINGS.SKIN_NAMES or {}
STRINGS.SKIN_DESCRIPTIONS = STRINGS.SKIN_DESCRIPTIONS or {}
STRINGS.SKIN_QUOTES = STRINGS.SKIN_QUOTES or {}
STRINGS.SKIN_NAMES.kei_none = "天童 柯伊"
STRINGS.SKIN_DESCRIPTIONS.kei_none = ""
STRINGS.SKIN_QUOTES.kei_none = ""

RegisterKeiSkin("kei_none")
return skin
