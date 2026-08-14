local TaskBook = require("kei/task_book")

local KeiTaskBook = Class(function(self, inst)
    self.inst = inst
    self.records = {}
    self.implanted = {}
    self:SyncNetValues()
end)

function KeiTaskBook:SyncNetValues()
    if self.inst._kei_taskbook_records ~= nil then self.inst._kei_taskbook_records:set(TaskBook.EncodeRecords(self.records)) end
    if self.inst._kei_taskbook_implanted ~= nil then self.inst._kei_taskbook_implanted:set(TaskBook.EncodeRecords(self.implanted)) end
end

function KeiTaskBook:RecordProtocolData(data, prefab)
    local entry = TaskBook.NormalizeProtocolData(data, prefab)
    if entry == nil or entry.kind == "analysis" or self.records[entry.id] then return false end
    self.records[entry.id] = true
    self:SyncNetValues()
    self.inst:PushEvent("kei_taskbook_changed", { id = entry.id })
    return true
end

function KeiTaskBook:RecordProtocolItem(item)
    return item ~= nil and item:HasTag("kei_protocol_cd") and self:RecordProtocolData(item.kei_protocol_data, item.prefab) or false
end

function KeiTaskBook:MarkImplanted(data, prefab)
    local entry = TaskBook.NormalizeProtocolData(data, prefab)
    if entry == nil or entry.kind == "analysis" then return false end
    local changed = not self.records[entry.id] or not self.implanted[entry.id]
    self.records[entry.id] = true
    self.implanted[entry.id] = true
    if changed then
        self:SyncNetValues()
        self.inst:PushEvent("kei_taskbook_changed", { id = entry.id, implanted = true })
    end
    return changed
end

function KeiTaskBook:OnSave()
    return { records = self.records, implanted = self.implanted }
end

function KeiTaskBook:OnLoad(data)
    self.records, self.implanted = {}, {}
    for id, value in pairs(data ~= nil and data.records or {}) do
        local kind = TaskBook.ParseId(id)
        if value and kind ~= "analysis" then self.records[id] = true end
    end
    for id, value in pairs(data ~= nil and data.implanted or {}) do
        local kind = TaskBook.ParseId(id)
        if value and kind ~= "analysis" then self.records[id], self.implanted[id] = true, true end
    end
    self:SyncNetValues()
end

return KeiTaskBook
