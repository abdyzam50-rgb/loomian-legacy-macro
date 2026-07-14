-- trainer.lua
-- Auto-trainer using the game's own BattleClient:doTrainerBattle() API.
-- Reads trainer data from the current map chunk's battles table, finds the
-- NPC model, and calls doTrainerBattle directly — no NPC interaction needed.
-- Two loops: slow (battle initiator) + fast (switch prompt + fast-forward).

local Trainer = {}

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- ─────────────────────────────────────────────────────────────────────────────
-- Shared _p (same pattern as all other modules)
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then return nil end

    if getgc then
        pcall(function()
            for _, v in pairs(getgc(true)) do
                if typeof(v) == "table" and rawget(v, "Utilities") then
                    _p = v
                end
            end
        end)
    end

    if _p then _findPFailedAt = nil; return _p end

    if debug and debug.getregistry then
        pcall(function()
            for _, fn in pairs(debug.getregistry()) do
                if typeof(fn) == "function" then
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
    if type(_p) == "table" and rawget(_p, "Utilities") then return _p end
    if type(_G.MacroP) == "table" and rawget(_G.MacroP, "Utilities") then
        _p = _G.MacroP; return _p
    end
    _p = findP()
    if _p then _G.MacroP = _p end
    return _p
end

local function safeGet(obj, key)
    if type(obj) ~= "table" then return nil end
    local ok, v = pcall(function() return obj[key] end)
    return ok and v or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function getCurrentBattle()
    local p = getP()
    if type(p) ~= "table" then return nil end
    local b = safeGet(safeGet(p, "Battle"), "currentBattle")
    if type(b) == "table" then return b end
    return safeGet(safeGet(p, "BattleClient"), "currentBattle")
end

local function getBattleClient()
    local p = getP()
    if type(p) ~= "table" then return nil end
    return safeGet(p, "BattleClient") or safeGet(p, "Battle")
end

local function skipNpcText()
    local p = getP()
    local chat = type(p) == "table" and safeGet(p, "NPCChat") or nil
    if type(chat) ~= "table" then return end
    pcall(function() chat.fastForward = true end)
    pcall(function() chat.skipping    = true end)
    for _, m in ipairs({ "manualAdvance", "advance", "next", "skip", "finish", "continue", "clear" }) do
        local fn = rawget(chat, m)
        if type(fn) == "function" then pcall(fn, chat) end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Switch prompt dismissal — fires "No" on the mid-battle swap dialog
-- ─────────────────────────────────────────────────────────────────────────────

local lastSwitchDismissAt = 0
local SWITCH_DISMISS_COOLDOWN = 0.35

local function dismissSwitchPrompt()
    if os.clock() - lastSwitchDismissAt < SWITCH_DISMISS_COOLDOWN then return end

    local p = getP()
    if type(p) ~= "table" then return end

    local battle = getCurrentBattle()
    if type(battle) ~= "table" then return end
    if safeGet(battle, "kind") ~= "trainer" then return end

    local battleGui = safeGet(p, "BattleGui")
    if type(battleGui) ~= "table" then return end

    -- Try firing the internal yesNo signal with false (= No)
    local fired = false
    pcall(function()
        local yesNo = safeGet(battleGui, "yesNoSignal")
            or safeGet(battleGui, "switchPromptSignal")
            or safeGet(battleGui, "promptSignal")
        if yesNo and type(yesNo.Fire) == "function" then
            yesNo:Fire(false)
            fired = true
        end
    end)

    -- Fallback: find and click the No button in the GUI
    if not fired then
        pcall(function()
            local playerGui = localPlayer:FindFirstChild("PlayerGui")
            if not playerGui then return end
            for _, desc in ipairs(playerGui:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and desc.Visible then
                    local t = (desc.Text or ""):lower()
                    if t == "no" or t == "cancel" then
                        if firesignal then
                            firesignal(desc.MouseButton1Click)
                        elseif getconnections then
                            for _, c in ipairs(getconnections(desc.MouseButton1Click)) do
                                pcall(function() c:Fire() end)
                            end
                        else
                            pcall(function() desc:Activate() end)
                        end
                        fired = true
                        break
                    end
                end
            end
        end)
    end

    if fired then lastSwitchDismissAt = os.clock() end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Core: start a trainer battle by trainer ID
-- Reads chunk.battles[id], finds the NPC model, calls doTrainerBattle
-- ─────────────────────────────────────────────────────────────────────────────

local function startBattle(trainerId)
    local p = getP()
    if type(p) ~= "table" then return false, "no _p" end

    if getCurrentBattle() then return false, "Battle already active." end

    local dataManager = safeGet(p, "DataManager")
    local chunk = dataManager and safeGet(dataManager, "currentChunk")
    if type(chunk) ~= "table" then return false, "no currentChunk" end

    -- Resolve trainer data from chunk battles table
    local battles = safeGet(chunk, "battles")
    local trainerData = type(battles) == "table" and battles[trainerId] or nil
    if not trainerData then
        return false, "trainer id " .. tostring(trainerId) .. " not found in chunk"
    end

    -- Find the matching NPC model
    local opponentNPC = nil
    pcall(function()
        local npcs = chunk:GetNPCs()
        if type(npcs) ~= "table" then return end
        for _, npc in pairs(npcs) do
            local battleNum = safeGet(safeGet(npc, "battle"), "num")
            if not battleNum then
                local iv = type(npc) == "table" and safeGet(npc, "#Battle")
                    or (typeof(npc) == "Instance" and npc:FindFirstChild("#Battle") or nil)
                battleNum = iv and safeGet(iv, "Value")
            end
            if tonumber(battleNum) == tonumber(trainerId) then
                opponentNPC = npc
                break
            end
        end
    end)

    if not opponentNPC then
        return false, "NPC model not found for trainer " .. tostring(trainerId)
    end

    local battleClient = getBattleClient()
    if type(battleClient) ~= "table" then return false, "no BattleClient" end

    skipNpcText()
    pcall(function()
        battleClient:doTrainerBattle({
            trainer        = trainerData,
            opponentBaseNPC = opponentNPC,
            skipStartAnim  = true,
        })
    end)

    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running   = false
local trainerId = 69     -- default; override with Trainer.setId()
local delay     = 1.5    -- seconds between battle attempts

function Trainer.start(id)
    if running then return end
    if id then trainerId = id end
    running = true
    getP()

    -- Slow loop: re-trigger battles
    task.spawn(function()
        print("[Trainer] Auto-trainer started (id=" .. tostring(trainerId) .. ").")
        local lastWarnAt = 0
        while running do
            skipNpcText()
            local battle = getCurrentBattle()
            if battle then
                -- Mid-battle: keep fast-forward on and handle switch prompt
                local p = getP()
                local battleGui = type(p) == "table" and safeGet(p, "BattleGui") or nil
                if type(battleGui) == "table" then
                    pcall(function() battleGui:setFastForward(true) end)
                    pcall(function() battleGui.fastForward = true end)
                end
                dismissSwitchPrompt()
            else
                local ok, err = startBattle(trainerId)
                if not ok and err ~= "Battle already active." then
                    if os.clock() - lastWarnAt > 4 then
                        warn("[Trainer] " .. tostring(err))
                        lastWarnAt = os.clock()
                    end
                end
            end
            task.wait(delay)
        end
        print("[Trainer] Auto-trainer stopped.")
    end)

    -- Fast loop: mid-battle handling at 0.08s ticks
    task.spawn(function()
        while running do
            skipNpcText()
            if getCurrentBattle() then
                dismissSwitchPrompt()
            end
            task.wait(0.08)
        end
    end)
end

function Trainer.stop()
    running = false
    print("[Trainer] Stopped.")
end

function Trainer.setId(id)
    trainerId = id
    print("[Trainer] Trainer ID set to: " .. tostring(id))
end

function Trainer.setDelay(d)
    delay = d
    print("[Trainer] Delay set to: " .. tostring(d) .. "s")
end

-- Fire one battle immediately (no loop)
function Trainer.fightNow(id)
    local ok, err = startBattle(id or trainerId)
    if not ok then warn("[Trainer] fightNow failed: " .. tostring(err)) end
    return ok
end

return Trainer
