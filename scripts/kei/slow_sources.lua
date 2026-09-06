-- Per-target slow ownership. Different slow types may coexist, while the
-- same type is applied by at most one source at a time.

local KeiTimeScale = require("kei/time_scale")

local SlowSources = {}

local function GetClaims(target)
    target._kei_slow_source_claims = target._kei_slow_source_claims or {}
    return target._kei_slow_source_claims
end

local function InstallOwnerListener(target, source_kind, claim)
    claim.onownerremove = function()
        local current_claims = target._kei_slow_source_claims
        if current_claims ~= nil and current_claims[source_kind] == claim then
            SlowSources.Release(target, source_kind, claim.owner)
        end
    end
    target:ListenForEvent("onremove", claim.onownerremove, claim.owner)
end

local function ClearClaimEffect(target, source_kind, claim)
    target:RemoveEventCallback("onremove", claim.onownerremove, claim.owner)
    if target.components ~= nil and target.components.locomotor ~= nil then
        target.components.locomotor:RemoveExternalSpeedMultiplier(claim.owner, source_kind)
    end
    KeiTimeScale.Remove(target, claim.token)
end

function SlowSources.TryApply(target, source_kind, owner, speed_multiplier, time_multiplier, allow_transfer)
    if target == nil or source_kind == nil or owner == nil then
        return false
    end

    local locomotor = target.components ~= nil and target.components.locomotor or nil
    if locomotor == nil and time_multiplier == nil then
        return false
    end

    local claims = GetClaims(target)
    local claim = claims[source_kind]
    if claim ~= nil and claim.owner ~= owner then
        if not allow_transfer then
            return false
        end

        ClearClaimEffect(target, source_kind, claim)
        claim.owner = owner
        claim.token = {}
        InstallOwnerListener(target, source_kind, claim)
    end

    if claim == nil then
        claim = {
            owner = owner,
            token = {},
        }
        claims[source_kind] = claim
        InstallOwnerListener(target, source_kind, claim)
    end

    if locomotor ~= nil and speed_multiplier ~= nil then
        locomotor:SetExternalSpeedMultiplier(owner, source_kind, speed_multiplier)
    end
    if time_multiplier ~= nil then
        KeiTimeScale.Add(target, claim.token, time_multiplier)
    end
    return true
end

function SlowSources.Release(target, source_kind, owner)
    if target == nil or source_kind == nil or owner == nil then
        return false
    end

    local claims = target._kei_slow_source_claims
    local claim = claims ~= nil and claims[source_kind] or nil
    if claim == nil or claim.owner ~= owner then
        return false
    end

    ClearClaimEffect(target, source_kind, claim)

    claims[source_kind] = nil
    if next(claims) == nil then
        target._kei_slow_source_claims = nil
    end
    return true
end

return SlowSources
