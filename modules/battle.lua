-- battle.lua
-- Drives story/trainer battles automatically using the game's own BattleGui API.
-- Exact move-selection logic from MrJack decompiled source (u37 function):
--   1. BattleGui:mainButtonClicked(1) → opens fight menu if not already open
--   2. BattleGui.moves[slot] → inspect move
--   3. If insufficient energy: fightSelectionGroup:LoseFocus(),
--      inputEvent:fire('rest 0'), exitButtonsMoveChosen()
--   4. Else if not disabled: BattleGui:onMoveClicked(slot)
-- Also skips in-battle NPC text via NPCChat flags (same as MrJack).

local Battle = {}

local RunService = game:GetService("RunService")

-- ─────────────────────────────────────────────────────────────────────────────
-- _p scan — exact MrJack pattern: rawget(v,"Utilities") via getgc first,
-- then debug.getregistry fallback.
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then return nil end

    if getgc then
        pcall(function()
            for _, v in pairs(getgc(true)) do
                if typeof(v) == "table" and rawget(v, "Utilities") and not (_p and _p.Battle) then
                    _p = v
                end
            end
        end)
    end

    if _p then _findPFailedAt = nil; return _p end

    if debug and debug.getregistry then
        pcall(function()
            for _, fn in pairs(debug.getregistry()) do
                if typeof(fn) == "function" and not (_p and _p.Battle) then
                    pcall(function()
                        local upvals = getupvalues and getupvalues(fn) or debug.getupvalues(fn)
                        for _, uv in pairs(upvals) do
                            if typeof(uv) == "table" and rawget(uv, "Utilities") then
                                _p = uv
                            end
                        end
                    end)
                end
            end
        end)
    end

    if _p then _findPFailedAt = nil else _findPFailedAt = os.clock() end
    return _p
end

local function getP()
    if type(_p) ~= "table" or not rawget(_p, "Utilities") then
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

local function getCurrentBattle()
    local p = getP()
    if type(p) ~= "table" then return nil end
    -- MrJack uses u5.Battle.currentBattle directly
    local battleModule = safeGet(p, "Battle")
    local battle = safeGet(battleModule, "currentBattle")
    if type(battle) == "table" then return battle end
    -- Fallback: BattleClient
    local clientModule = safeGet(p, "BattleClient")
    return safeGet(clientModule, "currentBattle")
end

-- Skips in-battle NPC/trainer text (NPCChat flags + advance methods).
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
        local m = rawget(chat, name)
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Exact MrJack u37: fire move slot via BattleGui with energy/rest logic.
-- switchingBlocked mirrors MrJack's u7 flag (set during monster switch anim).
-- ─────────────────────────────────────────────────────────────────────────────

local switchingBlocked = false

local function fireMove(slot)
    local p = getP()
    if type(p) ~= "table" then return end

    local battle    = getCurrentBattle()
    local battleGui = safeGet(p, "BattleGui")
    if type(battle) ~= "table" or type(battleGui) ~= "table" then return end

    local state = safeGet(battle, "state")
    if state ~= "input" or switchingBlocked then return end

    -- Open fight menu if not already open (mainButtonClicked(1))
    if not safeGet(battleGui, "onMoveClicked") then
        pcall(function() battleGui:mainButtonClicked(1) end)
    end

    -- Inspect the move at this slot
    local moves = safeGet(battleGui, "moves")
    local move  = type(moves) == "table" and moves[slot] or nil
    if type(move) ~= "table" then return end

    local activeMonster = safeGet(battleGui, "activeMonster")
    local energy        = activeMonster and safeGet(activeMonster, "energy") or math.huge
    local bypassEnergy  = activeMonster and safeGet(activeMonster, "bypassEnergy") or false
    local moveEnergy    = safeGet(move, "energy")
    local disabled      = safeGet(move, "disabled")

    if moveEnergy and energy < moveEnergy and not bypassEnergy then
        -- Not enough energy → rest instead (exact MrJack path)
        pcall(function()
            local fsg = safeGet(battleGui, "fightSelectionGroup")
            if fsg then fsg:LoseFocus() end
            local ev = safeGet(battleGui, "inputEvent")
            if ev then ev:fire("rest 0") end
            battleGui:exitButtonsMoveChosen()
        end)
    elseif not disabled then
        pcall(function()
            battleGui:onMoveClicked(slot)
        end)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running       = false
local monitorThread = nil
local MOVE_SLOT     = 1      -- always use move slot 1 for story battles
local TICK_RATE     = 0.08   -- seconds between loop iterations
local FIRE_COOLDOWN = 0.35   -- minimum seconds between move fires

function Battle.start()
    if running then return end
    running = true

    getP()

    monitorThread = task.spawn(function()
        print("[Battle] Auto-battle started (move slot " .. MOVE_SLOT .. ").")

        local lastFireAt = 0

        while running do
            local battle = getCurrentBattle()

            if type(battle) == "table" then
                skipBattleText()

                if os.clock() - lastFireAt > FIRE_COOLDOWN then
                    fireMove(MOVE_SLOT)
                    lastFireAt = os.clock()
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
function Battle.runAndWait(timeout)
    Battle.start()
    local ok = Battle.waitForEnd(timeout or 120)
    Battle.stop()
    return ok
end

-- Override which move slot to use (1-4).
function Battle.setMoveSlot(slot)
    MOVE_SLOT = slot or 1
end

return Battle
