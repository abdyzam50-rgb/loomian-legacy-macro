-- battle.lua
-- Drives story/trainer battles automatically: sets battle.fastForward = true
-- (skips all animations), fires move slot 1 every turn via the game's own
-- InputChosen signal, and skips in-battle NPC dialogue via NPCChat methods.
-- Uses the same _G._p registry scan as dialogue.lua.

local Battle = {}

local RunService = game:GetService("RunService")

-- ─────────────────────────────────────────────────────────────────────────────
-- Registry scan — finds the internal module table that holds Battle/BattleClient
-- and NPCChat. Backs off 5 s on failure so we don't hammer the GC.
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then
        return nil
    end
    for _, fn in pairs(debug.getregistry()) do
        if type(fn) == "function" then
            for _, upvalue in pairs(debug.getupvalues(fn)) do
                local ok, result = pcall(function()
                    return upvalue.NPCChat
                end)
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
    if type(_p) ~= "table" then
        _p = findP()
    end
    return _p
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function safeGet(obj, key)
    if type(obj) ~= "table" then return nil end
    local ok, v = pcall(function() return obj[key] end)
    return ok and v or nil
end

local function safeSet(obj, key, val)
    if type(obj) ~= "table" then return end
    pcall(function() obj[key] = val end)
end

-- Returns the active battle object from _G._p.Battle or _G._p.BattleClient.
local function getCurrentBattle()
    local p = getP()
    if type(p) ~= "table" then return nil end

    for _, name in ipairs({ "Battle", "BattleClient" }) do
        local container = safeGet(p, name)
        local battle    = safeGet(container, "currentBattle")
        if type(battle) == "table" then
            return battle
        end
    end
    return nil
end

-- Skips in-battle NPC/trainer text (intro lines, move announcements, etc.).
local function skipBattleText()
    local p    = getP()
    local chat = type(p) == "table" and safeGet(p, "NPCChat") or nil
    if type(chat) ~= "table" then return end

    pcall(function()
        chat.fastForward        = true
        chat.skipping           = true
        chat.TextSpeedMultiplier = 100
    end)

    for _, name in ipairs({
        "manualAdvance", "ManualAdvance",
        "advance",       "Advance",
        "next",          "Next",
        "skip",          "Skip",
        "finish",        "Finish",
        "continue",      "Continue",
    }) do
        local m = type(chat) == "table" and rawget(chat, name) or nil
        if type(m) == "function" then pcall(m, chat) end
    end

    pcall(function()
        if type(chat.isChatting) == "function" and chat:isChatting()
            and type(chat.clear) == "function"
        then
            chat:clear()
        end
    end)
end

-- Fires move slot `slot` (1-4) via the game's own InputChosen signal.
local function fireMove(battle, slot)
    local signal = safeGet(battle, "InputChosen")
    if type(signal) ~= "table" or type(signal.Fire) ~= "function" then
        return false
    end
    local ok = pcall(function()
        signal:Fire("move " .. tostring(slot))
    end)
    return ok
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running       = false
local monitorThread = nil
local MOVE_SLOT     = 1       -- always use move 1 for story battles
local TICK_RATE     = 0.08    -- seconds between loop iterations

function Battle.start()
    if running then return end
    running = true

    getP()  -- warm up registry scan immediately

    monitorThread = task.spawn(function()
        print("[Battle] Auto-battle started (move slot " .. MOVE_SLOT .. ").")

        local lastFireAt = 0

        while running do
            local battle = getCurrentBattle()

            if type(battle) == "table" then
                -- Keep fast-forward asserted every tick.
                safeSet(battle, "fastForward", true)

                -- Skip any in-battle NPC/trainer text.
                skipBattleText()

                -- Fire a move when it's our turn and enough time has passed.
                local state = safeGet(battle, "state")
                if state == "input" and os.clock() - lastFireAt > 0.35 then
                    if fireMove(battle, MOVE_SLOT) then
                        lastFireAt = os.clock()
                        print("[Battle] Fired move " .. MOVE_SLOT .. ".")
                    end
                end
            end

            task.wait(TICK_RATE)
        end

        print("[Battle] Auto-battle stopped.")
    end)
end

function Battle.stop()
    running = false
    print("[Battle] Stopped.")
end

-- Blocks until no battle is active or timeout (seconds) is reached.
-- Returns true if battle ended cleanly, false on timeout.
function Battle.waitForEnd(timeout)
    timeout = timeout or 120
    local deadline = tick() + timeout

    while tick() < deadline do
        if not getCurrentBattle() then
            return true
        end
        RunService.Heartbeat:Wait()
    end

    warn("[Battle] waitForEnd timed out after " .. timeout .. "s.")
    return false
end

-- One-shot: start auto-battle, block until finished, then stop.
-- Useful for scripted story battles where the caller just needs to wait.
function Battle.runAndWait(timeout)
    Battle.start()
    local ok = Battle.waitForEnd(timeout or 120)
    Battle.stop()
    return ok
end

return Battle
