local original = require("stategraphs/SGbeequeen")

local function SpawnRecorderGuards(inst)
    inst.sg.mem.wantstospawnguards = nil
    if inst.spawnguards_chain < inst.spawnguards_maxchain then
        inst.spawnguards_chain = inst.spawnguards_chain + 1
    else
        inst.spawnguards_chain = 0
        inst.components.timer:StartTimer("spawnguards_cd", inst.spawnguards_cd)
    end

    local oldnum = inst.components.commander:GetNumSoldiers()
    local x, y, z = inst.Transform:GetWorldPosition()
    local rot = inst.Transform:GetRotation()
    local num = math.random(TUNING.BEEQUEEN_MIN_GUARDS_PER_SPAWN, TUNING.BEEQUEEN_MAX_GUARDS_PER_SPAWN)
    if num + oldnum > TUNING.BEEQUEEN_TOTAL_GUARDS then
        num = math.max(TUNING.BEEQUEEN_MIN_GUARDS_PER_SPAWN, TUNING.BEEQUEEN_TOTAL_GUARDS - oldnum)
    end
    local drot = 360 / num
    for i = 1, num do
        local minion = SpawnPrefab("kei_recorder_beeguard")
        minion.kei_recorder_source = inst.kei_recorder_source
        local source = minion.kei_recorder_source
        if source ~= nil and source:IsValid() then
            source.kei_recorder_beeguards = source.kei_recorder_beeguards or {}
            table.insert(source.kei_recorder_beeguards, minion)
        end
        local angle = rot + i * drot
        local radius = minion:GetPhysicsRadius(0)
        minion.Transform:SetRotation(angle)
        angle = -angle * DEGREES
        minion.Transform:SetPosition(x + radius * math.cos(angle), 0, z + radius * math.sin(angle))
        minion:OnSpawnedGuard(inst)
    end

    if oldnum > 0 then
        local soldiers = inst.components.commander:GetAllSoldiers()
        num = #soldiers
        drot = 360 / num
        for i = 1, num do
            local angle = -(rot + i * drot) * DEGREES
            local xoffs = TUNING.BEEGUARD_GUARD_RANGE * math.cos(angle)
            local zoffs = TUNING.BEEGUARD_GUARD_RANGE * math.sin(angle)
            local mindistsq = math.huge
            local closest = 1
            for i2, v in ipairs(soldiers) do
                local offset = v.components.knownlocations:GetLocation("queenoffset")
                if offset ~= nil then
                    local distance_sq = distsq(xoffs, zoffs, offset.x, offset.z)
                    if distance_sq < mindistsq then
                        mindistsq = distance_sq
                        closest = i2
                    end
                end
            end
            table.remove(soldiers, closest).components.knownlocations:RememberLocation(
                "queenoffset",
                Vector3(xoffs, 0, zoffs),
                false
            )
        end
    end
end

local function CloneState(state)
    local tags = {}
    for tag in pairs(state.tags) do
        table.insert(tags, tag)
    end

    local events = {}
    for name, event in pairs(state.events) do
        events[name] = EventHandler(name, event.fn)
    end

    local timeline = {}
    for _, event in ipairs(state.timeline) do
        if state.name == "spawnguards" and event.time == 16 * FRAMES then
            table.insert(timeline, TimeEvent(event.time, SpawnRecorderGuards))
        else
            table.insert(timeline, TimeEvent(event.time, event.fn))
        end
    end

    local cloned = State{
        name = state.name,
        tags = tags,
        events = events,
        timeline = timeline,
        onenter = state.onenter,
        onexit = state.onexit,
        onupdate = state.onupdate,
        ontimeout = state.ontimeout,
        no_predict_fastforward = state.no_predict_fastforward,
    }
    if state.server_states ~= nil then
        cloned.server_states = state.server_states
        cloned.forward_server_states = state.forward_server_states
    end
    return cloned
end

local states = {}
for name, state in pairs(original.states) do
    table.insert(states, CloneState(state))
end

local events = {}
for _, event in pairs(original.events) do
    table.insert(events, EventHandler(event.name, event.fn))
end

local actionhandlers = {}
for _, actionhandler in pairs(original.actionhandlers) do
    table.insert(actionhandlers, actionhandler)
end

return StateGraph(
    "kei_recorder_beequeen",
    states,
    events,
    original.defaultstate,
    actionhandlers
)
