-- battle.lua
-- Auto-battle driver using BattleGui GUI detection.
-- Watches for BattleGui to appear in MainGui, then loops:
--   1. Find the red Fight button by color → click it
--   2. Find Move1.Button → click it
-- Repeats every 0.3s until BattleGui is removed.
-- Also skips in-battle NPC text via NPCChat flags.

local Battle = {}

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- GUI helpers (inline so battle.lua has no dependency on utils.lua)
-- ─────────────────────────────────────────────────────────────────────────────

local GuiService          = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local function click(button, xOffset, yOffset)
    if not (button and button.Visible) then return end
    xOffset = xOffset or 0.5
    yOffset = yOffset or 0.5
    local inset = GuiService:GetGuiInset()
    local x = math.floor(button.AbsolutePosition.X + button.AbsoluteSize.X * xOffset + inset.X + 0.5)
    local y = math.floor(button.AbsolutePosition.Y + button.AbsoluteSize.Y * yOffset + inset.Y + 0.5)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function findButton(container, options)
    for _, obj in ipairs(container:GetDescendants()) do
        if not options.className
            or obj.ClassName == options.className
            or obj.Name == options.className
        then
            local isMatch = true

            if options.text then
                local found = false
                for _, child in ipairs(obj:GetChildren()) do
                    if (child:IsA("TextLabel") or child:IsA("TextButton"))
                        and child.Text:find(options.text) then
                        found = true; break
                    end
                end
                isMatch = isMatch and found
            end

            if options.color then
                if obj:IsA("ImageLabel") then
                    isMatch = isMatch and (obj.ImageColor3 == options.color)
                elseif obj:IsA("GuiObject") then
                    isMatch = isMatch and (obj.BackgroundColor3 == options.color)
                else
                    isMatch = false
                end
            end

            if options.childName then
                isMatch = isMatch and (obj:FindFirstChild(options.childName) ~= nil)
            end

            if isMatch then return obj end
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- NPCChat fast-forward (skips in-battle trainer/move text)
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

local function skipBattleText()
    local p = _p or findP()
    if type(p) ~= "table" then return end
    local chat = rawget(p, "NPCChat")
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
-- Core battle loop — fires when BattleGui appears in MainGui
-- ─────────────────────────────────────────────────────────────────────────────

local FIGHT_BUTTON_COLOR = Color3.fromRGB(255, 102, 102)

local function runBattleLoop(battleGui)
    local mainGui = playerGui:FindFirstChild("MainGui")
    print("[Battle] BattleGui detected — auto-battle started.")

    while mainGui and mainGui:FindFirstChild("BattleGui") do
        skipBattleText()

        -- Click the red Fight button to open the move list
        local fightButton = findButton(battleGui, { color = FIGHT_BUTTON_COLOR })
        if fightButton then
            click(fightButton, 0.5, 0.5)
        end

        task.wait(0.3)

        -- Click Move1's button
        local move1Container = battleGui:FindFirstChild("Move1")
        if move1Container then
            local move1Button = move1Container:FindFirstChild("Button")
            if move1Button then
                click(move1Button, 0.5, 0.5)
            end
        end

        task.wait(0.3)
    end

    print("[Battle] BattleGui gone — battle ended.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running        = false
local watcherThread  = nil

function Battle.start()
    if running then return end
    running = true
    findP()

    local mainGui = playerGui:WaitForChild("MainGui", 30)
    if not mainGui then
        warn("[Battle] MainGui not found — auto-battle not started.")
        return
    end

    watcherThread = task.spawn(function()
        print("[Battle] Watching for BattleGui...")

        -- Wire up the DescendantAdded listener (exact pattern from source)
        mainGui.DescendantAdded:Connect(function(child)
            if child.Name == "BattleGui" and running then
                task.spawn(runBattleLoop, child)
            end
        end)

        -- Also handle a BattleGui that's already present when start() is called
        local existing = mainGui:FindFirstChild("BattleGui")
        if existing then
            task.spawn(runBattleLoop, existing)
        end
    end)
end

function Battle.stop()
    running = false
    print("[Battle] Stopped.")
end

-- Blocks until BattleGui is gone from MainGui, or timeout is reached.
function Battle.waitForEnd(timeout)
    timeout = timeout or 120
    local deadline = tick() + timeout
    local mainGui  = playerGui:FindFirstChild("MainGui")

    while tick() < deadline do
        if not (mainGui and mainGui:FindFirstChild("BattleGui")) then
            return true
        end
        RunService.Heartbeat:Wait()
    end

    warn("[Battle] waitForEnd timed out after " .. timeout .. "s.")
    return false
end

-- One-shot: start, wait for battle to end, stop.
function Battle.runAndWait(timeout)
    Battle.start()
    local ok = Battle.waitForEnd(timeout or 120)
    Battle.stop()
    return ok
end

return Battle
