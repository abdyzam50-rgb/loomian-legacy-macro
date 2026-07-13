-- battle.lua
-- Drives battles using the game's own BattleGui internal API.
-- Exact move-selection logic from MrJack decompiled source (u37 function):
--   1. BattleGui:mainButtonClicked(1) → opens fight menu if not already open
--   2. BattleGui.moves[slot] → inspect move for energy/disabled state
--   3. Low energy: fightSelectionGroup:LoseFocus(),
--      inputEvent:fire('rest 0'), exitButtonsMoveChosen()
--   4. Else: BattleGui:onMoveClicked(slot)
-- Best-move selection: score = effectiveness * basePower (from battle_move_macro.lua v6.2.3)
-- Also skips in-battle NPC text via NPCChat flags.

local Battle = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- _p scan — getgc first, registry fallback
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
                            if typeof(uv) == "table" and rawget(uv, "Utilities") then _p = uv end
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
    if type(_p) ~= "table" or not rawget(_p, "Utilities") then _p = findP() end
    return _p
end

local function safeGet(obj, key)
    if type(obj) ~= "table" then return nil end
    local ok, v = pcall(function() return obj[key] end)
    return ok and v or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NPCChat fast-forward — skips in-battle trainer/move text
-- ─────────────────────────────────────────────────────────────────────────────

local function skipBattleText()
    local p = getP()
    local chat = type(p) == "table" and safeGet(p, "NPCChat") or nil
    if type(chat) ~= "table" then return end
    pcall(function()
        chat.fastForward        = true
        chat.skipping           = true
        chat.TextSpeedMultiplier = 100
    end)
    for _, name in ipairs({ "manualAdvance", "advance", "next", "skip", "finish", "continue" }) do
        local m = rawget(chat, name)
        if type(m) == "function" then pcall(m, chat) end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- getCurrentBattle — checks Battle then BattleClient
-- ─────────────────────────────────────────────────────────────────────────────

local function getCurrentBattle()
    local p = getP()
    if type(p) ~= "table" then return nil end
    local b = safeGet(safeGet(p, "Battle"), "currentBattle")
    if type(b) == "table" then return b end
    return safeGet(safeGet(p, "BattleClient"), "currentBattle")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Best-move selection (battle_move_macro.lua v6.2.3)
-- ─────────────────────────────────────────────────────────────────────────────

local function getMoveEffectiveness(mv)
    if type(mv) == "table" and type(mv.effective) == "table" then
        return tonumber(mv.effective[1]) or 1
    end
    return 1
end

-- Returns bestSlot (1-4) and bestScore, or nil if no move is usable.
local function selectBestMoveSlot(moves, currentEnergy)
    local bestSlot, bestScore, bestEnergy = nil, -1, math.huge
    for i = 1, 4 do
        local mv = type(moves) == "table" and moves[i] or nil
        if type(mv) == "table" and not safeGet(mv, "disabled") then
            local cost = safeGet(mv, "energy") or 0
            if currentEnergy >= cost then
                local score = getMoveEffectiveness(mv) * (safeGet(mv, "basePower") or 0)
                if score > bestScore or (score == bestScore and cost < bestEnergy) then
                    bestScore  = score
                    bestEnergy = cost
                    bestSlot   = i
                end
            end
        end
    end
    return bestSlot, bestScore
end

-- ─────────────────────────────────────────────────────────────────────────────
-- fireMove — MrJack u37 logic + dynamic best-move selection
-- ─────────────────────────────────────────────────────────────────────────────

local switchingBlocked = false

local function fireMove()
    local p = getP()
    if type(p) ~= "table" then return end

    local battle    = getCurrentBattle()
    local battleGui = safeGet(p, "BattleGui")
    if type(battle) ~= "table" or type(battleGui) ~= "table" then return end
    if safeGet(battle, "state") ~= "input" or switchingBlocked then return end

    -- Open fight menu if not already showing moves
    if not safeGet(battleGui, "onMoveClicked") then
        pcall(function() battleGui:mainButtonClicked(1) end)
    end

    local moves         = safeGet(battleGui, "moves")
    local activeMonster = safeGet(battleGui, "activeMonster")
    local energy        = activeMonster and safeGet(activeMonster, "energy") or 0
    local bypassEnergy  = activeMonster and safeGet(activeMonster, "bypassEnergy") or false

    -- When bypassEnergy, treat energy as effectively infinite for scoring
    local effectiveEnergy = bypassEnergy and math.huge or energy

    local slot, score = selectBestMoveSlot(moves, effectiveEnergy)

    if slot then
        pcall(function() battleGui:onMoveClicked(slot) end)
    else
        -- No move has enough energy — rest
        pcall(function()
            local fsg = safeGet(battleGui, "fightSelectionGroup")
            if fsg then fsg:LoseFocus() end
            local ev = safeGet(battleGui, "inputEvent")
            if ev then ev:fire("rest 0") end
            battleGui:exitButtonsMoveChosen()
        end)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running       = false
local TICK_RATE     = 0.08
local FIRE_COOLDOWN = 0.35

function Battle.start()
    if running then return end
    running = true
    getP()

    task.spawn(function()
        print("[Battle] Auto-battle started (best-move mode).")
        local lastFireAt = 0

        while running do
            local battle = getCurrentBattle()
            if type(battle) == "table" then
                skipBattleText()
                if os.clock() - lastFireAt > FIRE_COOLDOWN then
                    fireMove()
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

-- Blocks until no active battle, or timeout.
function Battle.waitForEnd(timeout)
    timeout = timeout or 120
    local deadline = tick() + timeout
    while tick() < deadline do
        if not getCurrentBattle() then return true end
        RunService.Heartbeat:Wait()
    end
    warn("[Battle] waitForEnd timed out after " .. timeout .. "s.")
    return false
end

function Battle.runAndWait(timeout)
    Battle.start()
    local ok = Battle.waitForEnd(timeout or 120)
    Battle.stop()
    return ok
end

return Battle
