local PET_PROTOCOL_LIST = {
    {
        protocol = "pet",
        prefab = "kei_pet_cd",
        display_name = "宠物协议",
        description = "绑定一个可养成宠物；插入协议时召唤宠物出战。",
        implemented = true,
        capture_item = "kei_pet_capture_ball",
        growth = {
            friendship = true,
            book_exp = true,
            combat_exp = true,
        },
        personality = {
            fixed = true,
            random = true,
        },
        talent = {
            normal = true,
            advanced = true,
            rerollable = true,
        },
        affix = {
            normal = true,
            rare = true,
            removable = true,
        },
    },
}

local PET_PROTOCOLS = {}
local PET_PROTOCOL_PREFABS = {}

for _, def in ipairs(PET_PROTOCOL_LIST) do
    def.kind = "pet"
    PET_PROTOCOLS[def.protocol] = def
    PET_PROTOCOL_PREFABS[def.prefab] = def.protocol
end

local function GetProtocolPrefab(protocol)
    local def = protocol ~= nil and PET_PROTOCOLS[protocol] or nil
    return def ~= nil and def.prefab or nil
end

return {
    PET_PROTOCOLS = PET_PROTOCOLS,
    PET_PROTOCOL_LIST = PET_PROTOCOL_LIST,
    PET_PROTOCOL_PREFABS = PET_PROTOCOL_PREFABS,
    GetProtocolPrefab = GetProtocolPrefab,
}
