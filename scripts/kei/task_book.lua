local CombatProtocols = require("kei/protocols/combat")
local LifeProtocols = require("kei/protocols/life")
local BasicAttributeProtocols = require("kei/protocols/basic_attributes")

local TaskBook = {}

TaskBook.RARITY_ORDER = { white = 1, blue = 2, gold = 3, purple = 4 }

function TaskBook.MakeId(kind, protocol)
    return kind ~= nil and protocol ~= nil and tostring(kind) .. ":" .. tostring(protocol) or nil
end

function TaskBook.ParseId(id)
    if type(id) ~= "string" then
        return nil, nil
    end
    return id:match("^([^:]+):(.+)$")
end

local function GetCombatVisual(protocol)
    return CombatProtocols.GetProtocolVisual ~= nil and CombatProtocols.GetProtocolVisual(protocol) or nil
end

function TaskBook.GetRarity(kind, protocol)
    if kind == "combat" then
        local visual = GetCombatVisual(protocol)
        local atlas = visual ~= nil and visual.atlas or nil
        if atlas == "images/inventoryimages/kei_beast_golden_cd_item.xml" then return "gold" end
        if atlas == "images/inventoryimages/kei_beast_purple_cd_item.xml" then return "purple" end
        if atlas == "images/inventoryimages/kei_biome_cd_item.xml" then return "blue" end
    end
    return "white"
end

function TaskBook.GetDefinition(kind, protocol, prefab)
    local def = kind == "combat" and CombatProtocols.COMBAT_PROTOCOLS[protocol]
        or kind == "life" and LifeProtocols.LIFE_PROTOCOLS[protocol]
        or kind == "basic_attribute" and BasicAttributeProtocols.BASIC_ATTRIBUTE_PROTOCOLS[protocol]
    local visual = kind == "combat" and GetCombatVisual(protocol)
        or kind == "life" and { atlas = "images/inventoryimages/kei_life_cd_item.xml", image = "kei_life_cd" }
        or kind == "basic_attribute" and { atlas = "images/inventoryimages/kei_items.xml", image = "kei_blank_cd" }
        or { atlas = "images/inventoryimages/kei_items.xml", image = "kei_analysis_cd" }

    -- Analysis protocols are generated from arbitrary equipment, so they do
    -- not have an entry in the static combat/life/attribute definition tables.
    if type(def) ~= "table" then
        def = nil
    end
    if type(visual) ~= "table" then
        visual = { atlas = "images/inventoryimages/kei_items.xml", image = "kei_analysis_cd" }
    end

    return {
        id = TaskBook.MakeId(kind, protocol), kind = kind, protocol = protocol,
        prefab = prefab or (def ~= nil and def.prefab) or "kei_analysis_cd",
        name = def ~= nil and def.display_name or protocol or prefab or "unknown",
        rarity = TaskBook.GetRarity(kind, protocol), atlas = visual.atlas, image = visual.image,
    }
end

function TaskBook.NormalizeProtocolData(data, prefab)
    if type(data) ~= "table" then return nil end
    local kind = data.kind or "analysis"
    local protocol = data.protocol or (kind == "analysis" and (data.source_prefab or data.source or data.prefab or prefab))
    return protocol ~= nil and TaskBook.GetDefinition(kind, protocol, prefab) or nil
end

function TaskBook.EncodeRecords(records)
    local ids = {}
    for id in pairs(records or {}) do table.insert(ids, id) end
    table.sort(ids)
    return table.concat(ids, ",")
end

function TaskBook.DecodeRecords(encoded)
    local records = {}
    if type(encoded) == "string" then
        for id in encoded:gmatch("[^,]+") do records[id] = true end
    end
    return records
end

function TaskBook.GetEntries(inst)
    local records = TaskBook.DecodeRecords(inst ~= nil and inst._kei_taskbook_records ~= nil and inst._kei_taskbook_records:value() or "")
    local implanted = TaskBook.DecodeRecords(inst ~= nil and inst._kei_taskbook_implanted ~= nil and inst._kei_taskbook_implanted:value() or "")
    local entries = {}
    for id in pairs(records) do
        local kind, protocol = TaskBook.ParseId(id)
        if kind ~= nil and kind ~= "analysis" then
            local entry = TaskBook.GetDefinition(kind, protocol)
            entry.implanted = implanted[id] == true
            table.insert(entries, entry)
        end
    end
    return entries
end

return TaskBook
