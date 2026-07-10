-- heal.lua
-- Monitors party HP and triggers healing when any member falls below the
-- configured threshold. The actual healing action is a stub (see HOOK below)
-- to be wired up later with the MrJack implementation.

local Heal = {}

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────────────────────
-- Config
-- ─────────────────────────────────────────────────────────────────────────────

local DEFAULT_THRESHOLD = 0.5   -- heal when any party member is below 50% HP
local CHECK_INTERVAL    = 2     -- seconds between HP polls

-- ─────────────────────────────────────────────────────────────────────────────
-- Registry scan — same _G._p pattern as dialogue/battle modules
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then return nil end
    for _, fn in pairs(debug.getregistry()) do
        if type(fn) == "function" then
            for _, upvalue in pairs(debug.getupvalues(fn)) do
                local ok, result = pcall(function() return upvalue.NPCChat end)
                if ok and type(result) == "table" then
                    _findPFailedAt = nil
                    return upvalue
                end
            end
        end
    end
    _findPFailedAt = os.clock()
    return nil
end

local function getP()
    if type(_p) ~= "table" then _p = findP() end
    return _p
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Party HP reader
-- Reads HP fractions for all active party slots via _G._p internals.
-- Returns a list of { name, hp, maxHp, fraction } for each living member.
-- ─────────────────────────────────────────────────────────────────────────────

local function getPartyHP()
    local members = {}
    local p = getP()
    if type(p) ~= "table" then return members end

    -- Try _G._p.Party or _G._p.PartyManager
    local party = nil
    for _, key in ipairs({ "Party", "PartyManager", "party" }) do
        local candidate = p[key]
        if type(candidate) == "table" then
            party = candidate
            break
        end
    end

    if not party then return members end

    -- Slots are typically party.slots or party[1..6]
    local slots = type(party.slots) == "table" and party.slots or party

    for i = 1, 6 do
        local slot = slots[i]
        if type(slot) == "table" then
            local ok, hp    = pcall(function() return slot.health or slot.hp or slot.HP or 0 end)
            local ok2, max  = pcall(function() return slot.maxHealth or slot.maxHp or slot.maxHP or 1 end)
            local ok3, name = pcall(function() return slot.name or slot.species or ("Slot "..i) end)
            if ok and ok2 and max > 0 then
                table.insert(members, {
                    name     = ok3 and name or ("Slot "..i),
                    hp       = hp,
                    maxHp    = max,
                    fraction = hp / max,
                })
            end
        end
    end

    return members
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HOOK: performHeal()
-- Replace the body of this function with the MrJack healing implementation.
-- It should block until healing is complete before returning.
-- ─────────────────────────────────────────────────────────────────────────────

local function performHeal()
    -- ┌─────────────────────────────────────────────────────────────────────┐
    -- │  TODO: plug in MrJack auto-heal logic here                          │
    -- │  Expected behaviour:                                                 │
    -- │    1. Teleport to / interact with healing station                   │
    -- │    2. Confirm the healing dialogue / UI                              │
    -- │    3. Wait until party HP is fully restored                         │
    -- │    4. Return (caller will resume the macro)                          │
    -- └─────────────────────────────────────────────────────────────────────┘
    warn("[Heal] performHeal() stub called — wire up MrJack implementation here.")
    task.wait(1)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- needsHeal: true when any party member is at or below the threshold
-- ─────────────────────────────────────────────────────────────────────────────

local function needsHeal(threshold)
    local members = getPartyHP()

    -- If we can't read HP data, assume no heal needed (safe default).
    if #members == 0 then return false end

    for _, m in ipairs(members) do
        if m.fraction <= threshold then
            print(string.format("[Heal] %s at %.0f%% HP — heal needed.", m.name, m.fraction * 100))
            return true
        end
    end
    return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running    = false
local healing    = false
local threshold  = DEFAULT_THRESHOLD

-- Start the background HP monitor.
-- `options.threshold` (0–1) overrides the default heal-at fraction.
function Heal.start(options)
    if running then return end
    options   = options or {}
    threshold = options.threshold or DEFAULT_THRESHOLD
    running   = true
    healing   = false

    getP()

    task.spawn(function()
        print(string.format("[Heal] Monitor started (threshold %.0f%%).", threshold * 100))

        while running do
            if not healing and needsHeal(threshold) then
                healing = true
                print("[Heal] Triggering heal...")
                pcall(performHeal)
                healing = false
                print("[Heal] Heal complete.")
            end
            task.wait(CHECK_INTERVAL)
        end

        print("[Heal] Monitor stopped.")
    end)
end

function Heal.stop()
    running = false
    print("[Heal] Stopped.")
end

-- Returns true if a heal is currently in progress.
function Heal.isHealing()
    return healing
end

-- One-shot: check right now and heal if needed. Blocks until done.
function Heal.checkAndHeal(customThreshold)
    local t = customThreshold or threshold or DEFAULT_THRESHOLD
    if needsHeal(t) then
        healing = true
        pcall(performHeal)
        healing = false
    end
end

-- Expose hook so the MrJack implementation can be injected at runtime:
--   Heal.setPerformHeal(function() ... end)
function Heal.setPerformHeal(fn)
    if type(fn) == "function" then
        performHeal = fn
        print("[Heal] performHeal() implementation registered.")
    end
end

return Heal
