local MakeKeiCharacterSkin = require("kei/skin_api")

local assets = {
    Asset("ANIM", "anim/kei_skin_decagrammaton.zip"),
}

return MakeKeiCharacterSkin("kei_skin_decagrammaton", {
    name = "十字神名",
    description = "",
    quote = "",
    skins = {
        normal_skin = "kei_skin_decagrammaton",
        ghost_skin = "ghost_kei_build",
    },
    assets = assets,
    skin_tags = { "NORMAL", "KEI", "CHARACTER" },
    build_name_override = "kei_skin_decagrammaton",
    share_bigportrait_name = "kei_none",
    requires_unlock = true,
    rarity = "Character",
})
