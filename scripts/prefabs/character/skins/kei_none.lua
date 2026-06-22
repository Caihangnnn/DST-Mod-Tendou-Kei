local MakeKeiCharacterSkin = require("kei/skin_api")

local assets = {
    Asset("ANIM", "anim/kei.zip"),
    Asset("ANIM", "anim/ghost_kei_build.zip"),
}

return MakeKeiCharacterSkin("kei_none", {
    name = "天童 柯伊",
    description = "",
    quote = "",
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

