-- Each content category owns a compact manifest. This entrypoint preserves
-- every value returned by multi-prefab files before handing them to DST.
local CATEGORY_MANIFESTS = {
    "character",
    "items",
    "fx",
    "structures",
}

local prefabs = {}

local function AppendPrefabFile(path)
    local chunk, err = loadfile(path)
    if chunk == nil then
        print("[Tendou-Kei] Failed to load prefab file: " .. tostring(path) .. "\n" .. tostring(err))
        return
    end

    local loaded = { chunk() }
    for _, prefab in ipairs(loaded) do
        if prefab ~= nil then
            table.insert(prefabs, prefab)
        end
    end
end

for _, folder in ipairs(CATEGORY_MANIFESTS) do
    local paths = require("prefabs/" .. folder .. "/__prefabs_list")
    for _, path in ipairs(paths) do
        AppendPrefabFile(path)
    end
end

return unpack(prefabs)
