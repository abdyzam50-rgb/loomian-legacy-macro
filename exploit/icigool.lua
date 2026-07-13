-- Executor Object Selector & Auto-Farmer (Fixed Keybind Edition)
-- Enhanced with raid-cave navigation, invisible teleports, and improved battle flee
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- =============================================================================
-- USER CONFIG — edit encounter / chart strings and other settings here
-- =============================================================================

-- Your Loomian in the battle packet (wild data is read from the other index)
local PLAYER_LOOMIAN_NAME = "Wresolen-f"
local ENCOUNTER_DATA_MAX_AGE = 20

-- Strings searched anywhere in the encounter data chart / packet
local CHART_GLEAM_STRING = "gleam"              -- Gleam variant (must appear in chart data)
local CHART_GAMMA_STRING = "wisp"               -- Gamma variant (wisp marker in chart)
local CHART_WISP_STRING = "gamma"               -- Wisp rare-stop (gamma marker in chart)
-- Kyeggo / Kyeggo-pattern names are species forms, not variant markers — do not edit for variants

-- Auto-flee these variants instead of stopping the bot for a rare
local VARIANT_FLEE_BLACKLIST = {
    Gleam = true,
    Gamma = true,
}

-- Mount verify after geo-hop (object name under Workspace, or any child within range)
local MOUNT_VERIFY_NAME = "Trumbull"
local MOUNT_VERIFY_DISTANCE = 15  -- rider HRP can sit well above mount parts; 2 was too strict
local MOUNT_VERIFY_WAIT = 2.5
local MOUNT_ACTIVATE_DELAY = 3
local MOUNT_MAX_ATTEMPTS = 10
local MOUNT_ON_MACRO_START = true
local MOUNT_START_DELAY = 0.5

local BATTLE_FLEE_MAX_ATTEMPTS = 5
local BATTLE_END_DEBOUNCE = 0.85

local SHOW_DEV_OFFSET_PANEL = false  -- O key toggles hidden dev offset panel
local SHOW_DEV_TEST_BUTTON = false

local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1417475203126132747/6oKwkZAcV0TIUCPtPezaA4GuWZXKrv4MUrm7zM3Un-Cerp7xm0MJC2JVZkbCk62E4E7T"

local SAFETY_LOGOFF_ENABLED = true
local SAFETY_LOGOFF_MIN_HOURS = 5
local SAFETY_LOGOFF_MAX_HOURS = 7

-- Egg token sweep (integrated from egg100hookv2)
local EGG_TOKEN_SWEEP_ENABLED = true
local EGG_ENCOUNTER_TYPE = 1           -- eggRainLand [5] value for encounter eggs
local EGG_TOKEN_SWEEP_MAX_TRIES = 25
local EGG_TOKEN_SWEEP_MAX_AGE = 90
local EGG_TOKEN_SWEEP_MAX_CACHE = 120
local EGG_TOKEN_MATCH_RADIUS = 60      -- studs to match a world egg to a cached token
local EGG_ENCOUNTER_ONLY_DEFAULT = false  -- startup default; runtime toggle via setEncounterOnly()
local EGG_TOKEN_FRESH_MAX_AGE = 20     -- seconds; cached token valid window after eggRainLand
local EGG_TOKEN_POSITION_DEDUP = 8     -- studs; new eggRainLand at same spot replaces old token

-- Runtime egg mode (hooks + main loop read EggCfg — toggle without re-run):
--   getgenv().LoomianAuto.setEncounterOnly(false)
--   getgenv().LoomianAuto.setEncounterOnly(true)
_G.LoomianAuto = _G.LoomianAuto or {}
_G.LoomianAuto.EggConfig = _G.LoomianAuto.EggConfig or {}
local EggCfg = _G.LoomianAuto.EggConfig
EggCfg.encounterOnly = EGG_ENCOUNTER_ONLY_DEFAULT

local function eggEncounterOnly()
    return EggCfg.encounterOnly == true
end

function _G.LoomianAuto.setEncounterOnly(state)
    EggCfg.encounterOnly = state == true
    print("[LoomianAuto] Encounter-only:", EggCfg.encounterOnly and "ON" or "OFF")
    return EggCfg.encounterOnly
end

function _G.LoomianAuto.isEncounterOnly()
    return eggEncounterOnly()
end

-- =============================================================================
-- END USER CONFIG
-- =============================================================================

local function sendDiscordLog(title, lines, color)
    if not DISCORD_WEBHOOK_URL or DISCORD_WEBHOOK_URL == "" then return end

    local description = table.concat(lines, "\n")
    local payload = {
        username = "LoomianAuto",
        embeds = {{
            title = title,
            description = description,
            color = color or 5793266,
            timestamp = DateTime.now():ToIsoDate(),
        }},
    }

    task.spawn(function()
        local body = HttpService:JSONEncode(payload)
        local ok, err = pcall(function()
            if typeof(request) == "function" then
                request({
                    Url = DISCORD_WEBHOOK_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body,
                })
            elseif syn and typeof(syn.request) == "function" then
                syn.request({
                    Url = DISCORD_WEBHOOK_URL,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = body,
                })
            else
                HttpService:PostAsync(
                    DISCORD_WEBHOOK_URL,
                    body,
                    Enum.HttpContentType.ApplicationJson,
                    false
                )
            end
        end)
        if not ok then
            warn("[Discord]", err)
        end
    end)
end

local lastDiscordEncounterKey = ""
local lastDiscordEncounterTime = 0
local discordBattleFleeSent = false

local function notifyDiscordEncounter(name, variant, statsLine)
    local key = (name or "?") .. "|" .. (variant or "Normal")
    local now = tick()
    if key == lastDiscordEncounterKey and (now - lastDiscordEncounterTime) < 8 then
        return
    end
    lastDiscordEncounterKey = key
    lastDiscordEncounterTime = now

    local lines = {
        "**Target:** " .. tostring(name),
        "**Variant:** " .. tostring(variant or "Normal"),
    }
    if statsLine and statsLine ~= "" then
        table.insert(lines, "**Stats:** `" .. tostring(statsLine) .. "`")
    end
    table.insert(lines, "**Runtime:** " .. (startTime and formatTime(tick() - startTime) or "n/a"))

    sendDiscordLog("Encounter Detected", lines, 3447003)
end

local function notifyDiscordGeoHop(locationName, gateName, mountResult)
    local lines = {
        "**Destination:** " .. tostring(locationName),
    }
    if gateName and gateName ~= "" then
        table.insert(lines, "**Gate:** " .. tostring(gateName))
    end
    mountResult = mountResult or lastMountResult
    if mountResult then
        local dist = tostring(MOUNT_VERIFY_DISTANCE or 2)
        local att = tostring(mountResult.attempt or "?")
        local maxAtt = tostring(mountResult.maxAttempts or MOUNT_MAX_ATTEMPTS or "?")
        local mountLine = mountResult.success
            and ("OK (within " .. dist .. " studs on attempt " .. att .. "/" .. maxAtt .. ")")
            or ("FAILED after " .. att .. "/" .. maxAtt .. " attempt(s)")
        table.insert(lines, "**Mount (Q):** " .. mountLine)
    end
    if formatTime and startTime then
        table.insert(lines, "**Runtime:** " .. formatTime(tick() - startTime))
    end
    sendDiscordLog("Geo-Hop Success", lines, 3066993)
end

local function notifyDiscordFlee(name, variant, blacklisted)
    local lines = {
        "**Target:** " .. tostring(name),
        "**Variant:** " .. tostring(variant or "Normal"),
        "**Action:** Ran / fled",
    }
    if blacklisted then
        table.insert(lines, "**Note:** Blacklisted variant (auto-flee)")
    end
    if formatTime and startTime then
        table.insert(lines, "**Runtime:** " .. formatTime(tick() - startTime))
    end
    sendDiscordLog("Battle Flee", lines, 15105570)
end

local function notifyDiscordRareStop(name, variant)
    local lines = {
        "**Target:** " .. tostring(name),
        "**Variant:** " .. tostring(variant or "Unknown"),
        "**Action:** Auto mode stopped (rare found)",
    }
    if formatTime and startTime then
        table.insert(lines, "**Runtime:** " .. formatTime(tick() - startTime))
    end
    sendDiscordLog("Rare Found - Bot Stopped", lines, 15158332)
end

local function notifyDiscordSafetyLogoff(sessionRuntime)
    local lines = {
        "**Reason:** Safety log off",
        "**Action:** Auto mode stopped (scheduled safety timer)",
    }
    if sessionRuntime then
        table.insert(lines, "**Session runtime:** " .. tostring(sessionRuntime))
    end
    if formatTime and startTime then
        table.insert(lines, "**Total runtime:** " .. formatTime(tick() - startTime))
    end
    table.insert(lines, "**Boxes:** " .. tostring(boxCount or 0))
    sendDiscordLog("Safety Log Off", lines, 15158332)
end

local lastMountResult = nil

local function notifyDiscordMount(attempt, maxAttempts, success, exhausted)
    local verifyName = tostring(MOUNT_VERIFY_NAME or "Trumbull")
    local verifyDist = tostring(MOUNT_VERIFY_DISTANCE or 2)
    local attemptStr = tostring(attempt or "?")
    local maxStr = tostring(maxAttempts or MOUNT_MAX_ATTEMPTS or "?")
    local verifyPath = "game.Workspace." .. verifyName
    local lines = {
        "**Verify path:** `" .. verifyPath .. "`",
        "**Attempt:** " .. attemptStr .. "/" .. maxStr,
    }
    if success then
        table.insert(lines, "**Result:** Mount OK (within " .. verifyDist .. " studs of " .. verifyName .. ")")
    elseif exhausted then
        table.insert(lines, "**Result:** Mount FAILED (nothing within " .. verifyDist .. " studs after all attempts)")
    else
        table.insert(lines, "**Result:** Mount FAILED (not within " .. verifyDist .. " studs, retrying Q)")
    end
    table.insert(lines, "**Runtime:** " .. (startTime and formatTime and formatTime(tick() - startTime) or "n/a"))
    sendDiscordLog("Mount (Q)", lines, success and 3066993 or 15158332)
end

local player = Players.LocalPlayer
local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)

if not playerGui then
    error("Could not find PlayerGui!")
end

if playerGui:FindFirstChild("LoomianAuto_V12_Debug") then
    playerGui.LoomianAuto_V12_Debug:Destroy()
end
if playerGui:FindFirstChild("LoomianAuto") then
    playerGui.LoomianAuto:Destroy()
end

local SCRIPT_VERSION = "v14.13.0"
_G.LoomianAuto = _G.LoomianAuto or {}

if _G.LoomianAuto.encounterConnections then
    for _, conn in ipairs(_G.LoomianAuto.encounterConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
end
_G.LoomianAuto.encounterConnections = {}

if _G.LoomianAuto.descendantAddedConn then
    pcall(function()
        _G.LoomianAuto.descendantAddedConn:Disconnect()
    end)
end

if _G.LoomianAuto.eggSweepRestore then
    pcall(_G.LoomianAuto.eggSweepRestore)
end

print("========================================")
print("[LoomianAuto " .. SCRIPT_VERSION .. "] Loaded")
print("[LoomianAuto] Egg mode:", eggEncounterOnly() and "ENCOUNTER ONLY" or "NORMAL")
print("========================================")
if playerGui:FindFirstChild("LoomianClickHighlights") then
    playerGui.LoomianClickHighlights:Destroy()
end

-- Click offset config (adjustable in GUI, defaults = center 0.5)
local MAX_CLICK_OFFSET = 6

local GEOHOP_Y_BASE = 58

local DEFAULT_CLICK_OFFSETS = {
    tabX = 0.5,
    tabY = 2.0,
    geoHopX = 0,
    geoHopY = 0,
    runX = 0,
    runY = 15,
    showHighlights = true,
}

local clickOffsets = {
    tabX = DEFAULT_CLICK_OFFSETS.tabX,
    tabY = DEFAULT_CLICK_OFFSETS.tabY,
    geoHopX = DEFAULT_CLICK_OFFSETS.geoHopX,
    geoHopY = DEFAULT_CLICK_OFFSETS.geoHopY,
    runX = DEFAULT_CLICK_OFFSETS.runX,
    runY = DEFAULT_CLICK_OFFSETS.runY,
    showHighlights = DEFAULT_CLICK_OFFSETS.showHighlights,
}

local highlightGui = Instance.new("ScreenGui")
highlightGui.Name = "LoomianClickHighlights"
highlightGui.ResetOnSpawn = false
highlightGui.DisplayOrder = 100
highlightGui.IgnoreGuiInset = true
highlightGui.Parent = playerGui

local offsetDisplayLabels = {}
local offsetPanel

local function updateOffsetDisplays()
    if offsetDisplayLabels.tabX then
        offsetDisplayLabels.tabX.Text = string.format("%.2f", clickOffsets.tabX)
    end
    if offsetDisplayLabels.tabY then
        offsetDisplayLabels.tabY.Text = string.format("%.2f", clickOffsets.tabY)
    end
    if offsetDisplayLabels.geoHopX then
        offsetDisplayLabels.geoHopX.Text = tostring(math.floor(clickOffsets.geoHopX + 0.5))
    end
    if offsetDisplayLabels.geoHopY then
        offsetDisplayLabels.geoHopY.Text = tostring(math.floor(clickOffsets.geoHopY + 0.5))
    end
    if offsetDisplayLabels.runX then
        offsetDisplayLabels.runX.Text = tostring(math.floor(clickOffsets.runX + 0.5))
    end
    if offsetDisplayLabels.runY then
        offsetDisplayLabels.runY.Text = tostring(math.floor(clickOffsets.runY + 0.5))
    end
    if offsetDisplayLabels.highlightToggle then
        offsetDisplayLabels.highlightToggle.Text = clickOffsets.showHighlights and "ON" or "OFF"
        offsetDisplayLabels.highlightToggle.TextColor3 = clickOffsets.showHighlights
            and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 100, 100)
    end
end

local function resetClickOffsets()
    clickOffsets.tabX = DEFAULT_CLICK_OFFSETS.tabX
    clickOffsets.tabY = DEFAULT_CLICK_OFFSETS.tabY
    clickOffsets.geoHopX = DEFAULT_CLICK_OFFSETS.geoHopX
    clickOffsets.geoHopY = DEFAULT_CLICK_OFFSETS.geoHopY
    clickOffsets.runX = DEFAULT_CLICK_OFFSETS.runX
    clickOffsets.runY = DEFAULT_CLICK_OFFSETS.runY
    clickOffsets.showHighlights = DEFAULT_CLICK_OFFSETS.showHighlights
    updateOffsetDisplays()
end

local function showClickHighlight(x, y, label)
    if not clickOffsets.showHighlights then return end

    local dot = Instance.new("Frame")
    dot.Name = "ClickMarker"
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = UDim2.new(0, x - 7, 0, y - 7)
    dot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    dot.BackgroundTransparency = 0.15
    dot.BorderSizePixel = 0
    dot.ZIndex = 100
    dot.Parent = highlightGui

    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", dot)
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 2

    local ring = Instance.new("Frame")
    ring.Size = UDim2.new(0, 28, 0, 28)
    ring.Position = UDim2.new(0, x - 14, 0, y - 14)
    ring.BackgroundTransparency = 1
    ring.BorderSizePixel = 0
    ring.ZIndex = 99
    ring.Parent = highlightGui
    local ringStroke = Instance.new("UIStroke", ring)
    ringStroke.Color = Color3.fromRGB(255, 200, 50)
    ringStroke.Thickness = 2
    ringStroke.Transparency = 0.2

    if label then
        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.new(0, 120, 0, 16)
        tag.Position = UDim2.new(0, x + 10, 0, y - 8)
        tag.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        tag.BackgroundTransparency = 0.3
        tag.Text = label
        tag.TextColor3 = Color3.new(1, 1, 1)
        tag.Font = Enum.Font.GothamBold
        tag.TextSize = 10
        tag.TextXAlignment = Enum.TextXAlignment.Left
        tag.ZIndex = 101
        tag.Parent = highlightGui
        Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 4)
        task.delay(0.8, function()
            if tag.Parent then tag:Destroy() end
        end)
    end

    task.spawn(function()
        for i = 1, 15 do
            if not dot.Parent then break end
            ring.Size = UDim2.new(0, 28 + i * 3, 0, 28 + i * 3)
            ring.Position = UDim2.new(0, x - 14 - i * 1.5, 0, y - 14 - i * 1.5)
            ringStroke.Transparency = 0.2 + (i / 15) * 0.8
            dot.BackgroundTransparency = 0.15 + (i / 15) * 0.85
            task.wait(0.03)
        end
        dot:Destroy()
        ring:Destroy()
    end)

    print(string.format("[Click Highlight] %s @ (%d, %d)", label or "click", x, y))
end

-- State configuration
local autoMode = false
local macroStartMounting = false
local used = {}
local safetyLogoffAt = nil
local autoModeStartedAt = nil
local safetyLogoffTriggered = false
local loomianData = { enemy = "None", enemyType = "Normal", lastUpdate = 0, statsLine = "" }
local enemyLabel, typeLabel
local encounterFiring = false
local lastRaidNavAttempt = 0
local RAID_NAV_COOLDOWN = 2
local raidNavRunning = false

local equivalency = {
    ["Route 6"] = { location = "Rally Ranch" },
    ["Route 3"] = { location = "Silvent City", gate = "Route 3" },
    ["Route 4"] = { location = "Silvent City", gate = "Route 4" },
    ["Sepharite Junkyard"] = { location = "Sepharite City", gate = "Route 7" },
    ["Cheshma Town"] = { location = "Cheshma Town" },
    ["Sepharite City"] = { location = "Sepharite City" },
    ["Silvent City"] = { location = "Silvent City" },
    ["Heiwa Village"] = { location = "Heiwa Village" },
    ["Route 8"] = { location = "POLUT Underwater Mining Lab" },
}

-- Stats & Time Tracking
local startTime = tick()
local boxCount = 0
local battleCount = 0
local lastBattleState = false
local battleEndDebounceUntil = 0
local currentHighlight = nil

local char, hrp
local function bindCharacter(c)
    char = c
    hrp = c:WaitForChild("HumanoidRootPart")
end
if player.Character then
    bindCharacter(player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

local function formatTime(s)
    local hours = math.floor(s / 3600)
    local mins = math.floor((s % 3600) / 60)
    local secs = math.floor(s % 60)
    return string.format("%02d:%02d:%02d", hours, mins, secs)
end

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function getRootPart()
    local character = player.Character
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

local function teleportCharacterTo(destinationCFrame)
    local character = getCharacter()
    local rootPart = getRootPart()

    if rootPart then
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
        rootPart.CFrame = destinationCFrame
    end

    if character and character.PivotTo then
        character:PivotTo(destinationCFrame)
    end
end

-- Invisible teleport using game physics (from message 7)
local function invisibleTeleportTo(cf)
    if not char or not hrp or not hrp.Parent then
        bindCharacter(getCharacter())
    end
    if not hrp then return end

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    hrp.Parent = nil
    hrp.CFrame = cf
    RunService.Heartbeat:Wait()
    hrp.Parent = char
end

local function tapKey(keyCode)
    VIM:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, keyCode, false, game)
end

local function pressKey(keyCode)
    VIM:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.08)
    VIM:SendKeyEvent(false, keyCode, false, game)
    task.wait(0.25)
end

local function clickVim(button, xOffset, yOffset, label)
    if not button or not button.Visible then return false end

    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    if absSize.X <= 0 or absSize.Y <= 0 then return false end

    local x = math.floor(absPos.X + absSize.X * xOffset + 0.5)
    local y = math.floor(absPos.Y + absSize.Y * yOffset + 0.5)

    showClickHighlight(x, y, label or string.format("%.2f, %.2f", xOffset, yOffset))

    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function clickGui(gui, xOffset, yOffset, label)
    if not gui then return false end
    xOffset = xOffset or 0.5
    yOffset = yOffset or 0.5

    local function getClickCoords()
        if not gui.Visible then return nil end
        local absPos = gui.AbsolutePosition
        local absSize = gui.AbsoluteSize
        if absSize.X <= 0 or absSize.Y <= 0 then return nil end
        local x = math.floor(absPos.X + absSize.X * xOffset + 0.5)
        local y = math.floor(absPos.Y + absSize.Y * yOffset + 0.5)
        return x, y
    end

    local function flashHighlight()
        local x, y = getClickCoords()
        if x and y then
            showClickHighlight(x, y, label or "Click")
        end
    end

    flashHighlight()

    local ok = pcall(function()
        if typeof(firesignal) == "function" and gui:IsA("GuiButton") then
            firesignal(gui.MouseButton1Down)
            firesignal(gui.MouseButton1Click)
            firesignal(gui.MouseButton1Up)
        elseif gui.Activate then
            gui:Activate()
        else
            error("no gui click method")
        end
    end)

    if ok then return true end

    local x, y = getClickCoords()
    if not x or not y then return false end

    flashHighlight()
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function clickBattleButton(gui, label)
    if not gui or not gui.Visible then return false end

    local ap = gui.AbsolutePosition
    local as = gui.AbsoluteSize
    if as.X <= 0 or as.Y <= 0 then return false end

    local clickX = math.floor(ap.X + (as.X / 2) + clickOffsets.runX + 0.5)
    local clickY = math.floor(ap.Y + (as.Y / 2) + clickOffsets.runY + 0.5)

    showClickHighlight(clickX, clickY, label or "Run")

    pcall(function()
        if typeof(firesignal) == "function" and gui:IsA("GuiButton") then
            firesignal(gui.MouseButton1Down)
            firesignal(gui.MouseButton1Click)
            firesignal(gui.MouseButton1Up)
        elseif gui.Activate then
            gui:Activate()
        end
    end)

    VIM:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
    return true
end

local function click(button, xOffset, yOffset, label)
    return clickVim(button, xOffset, yOffset, label)
end

local function clickTab(tab)
    click(tab, clickOffsets.tabX, clickOffsets.tabY, "Tab")
end

local function triggerEscapeSequence(reasonText)
    if reasonText then
        warn(reasonText)
    end

    tapKey(Enum.KeyCode.Escape)
    task.wait(1)
    tapKey(Enum.KeyCode.L)
    task.wait(0.2)
    tapKey(Enum.KeyCode.Return)
end

local function scheduleSafetyLogoff()
    if not SAFETY_LOGOFF_ENABLED then
        safetyLogoffAt = nil
        autoModeStartedAt = nil
        return
    end
    autoModeStartedAt = tick()
    local minSec = SAFETY_LOGOFF_MIN_HOURS * 3600
    local maxSec = SAFETY_LOGOFF_MAX_HOURS * 3600
    safetyLogoffAt = autoModeStartedAt + math.random(minSec, maxSec)
    safetyLogoffTriggered = false
    print(string.format(
        "[Safety] Log off scheduled in %s (between %d-%d hours)",
        formatTime(safetyLogoffAt - autoModeStartedAt),
        SAFETY_LOGOFF_MIN_HOURS,
        SAFETY_LOGOFF_MAX_HOURS
    ))
end

local function clearSafetyLogoff()
    safetyLogoffAt = nil
    autoModeStartedAt = nil
    safetyLogoffTriggered = false
end

local function triggerSafetyLogoff()
    if safetyLogoffTriggered then
        return
    end
    safetyLogoffTriggered = true

    local sessionRuntime = autoModeStartedAt and formatTime(tick() - autoModeStartedAt) or "n/a"
    notifyDiscordSafetyLogoff(sessionRuntime)
    triggerEscapeSequence(string.format(
        "--- SAFETY LOG OFF ---\nScheduled safety stop after %s on this session.\n\nTotal runtime: %s\nBoxes: %d",
        sessionRuntime,
        formatTime(tick() - startTime),
        boxCount
    ))

    autoMode = false
    clearSafetyLogoff()
    if statusLabel then
        statusLabel.Text = "STATUS: OFF (SAFETY LOG OFF)"
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    end
end

--------------------------------------------------
-- DYNAMIC GUI FINDERS
--------------------------------------------------
local function getBattleGui()
    local main = player.PlayerGui:FindFirstChild("MainGui")
    if not main then return nil end

    local direct = main:FindFirstChild("BattleGui")
    if direct then return direct end

    local frame = main:FindFirstChild("Frame")
    return frame and frame:FindFirstChild("BattleGui")
end

local function getRunButton()
    local bGui = getBattleGui()
    if bGui then
        return bGui:FindFirstChild("Run", true) or bGui:FindFirstChild("Escape", true)
    end
    return nil
end

local function hasBattleGui()
    local bGui = getBattleGui()
    return bGui ~= nil and bGui.Visible ~= false
end

local function isBattleActive()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "BuiltInBattleScenes" and v:FindFirstChild("Model") then
            return true
        end
    end
    return false
end

local function isEncounterStarting()
    return encounterFiring or hasBattleGui() or isBattleActive()
end

local function getMainModule()
    if typeof(getgc) ~= "function" then return nil end
    for _, v in pairs(getgc(true)) do
        if typeof(v) == "table" and rawget(v, "DataManager") and rawget(v, "Battle") then
            return v
        end
    end
    return nil
end

local function tryEndBattle()
    return pcall(function()
        local Main = getMainModule()
        local battle = Main and Main.Battle and Main.Battle.currentBattle
        if battle and battle.BattleEnded then
            battle.BattleEnded:Fire()
        end
    end)
end

local function isBattleSceneActive()
    return hasBattleGui() or isBattleActive()
end

local function isInBattle()
    return isBattleSceneActive() or encounterFiring
end

local function isBattleConfirmedEnded()
    if isBattleSceneActive() then
        battleEndDebounceUntil = 0
        return false
    end
    if battleEndDebounceUntil == 0 then
        battleEndDebounceUntil = tick() + BATTLE_END_DEBOUNCE
    end
    return tick() >= battleEndDebounceUntil
end

local function resetBattleTracking()
    lastBattleState = false
    encounterFiring = false
    battleEndDebounceUntil = 0
    discordBattleFleeSent = false
    loomianData.enemy = "None"
    loomianData.enemyType = "Normal"
    loomianData.statsLine = ""
    loomianData.lastUpdate = 0
    if enemyLabel then
        enemyLabel.Text = "TARGET: WAITING..."
    end
    if typeLabel then
        typeLabel.Text = "VARIANT: NORMAL"
    end
end

local function tryFleeBattleOnce()
    local runBtn = getRunButton()
    if runBtn and runBtn.Visible then
        clickBattleButton(runBtn, "Run")
        return true
    end

    local bGui = getBattleGui()
    if bGui then
        for _, desc in bGui:GetDescendants() do
            local text
            if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                text = string.lower(tostring(desc.Text))
            elseif desc:IsA("ImageButton") then
                text = string.lower(desc.Name)
            end
            if text and (text:find("run") or text:find("flee")) then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and btn.Visible then
                    local label = text:find("flee") and "Flee" or "Run"
                    clickBattleButton(btn, label)
                    return true
                end
            end
        end
    end

    return false
end

local function tryFleeBattle()
    local clicked = false
    for attempt = 1, BATTLE_FLEE_MAX_ATTEMPTS do
        if not isBattleSceneActive() then
            return true
        end
        if tryFleeBattleOnce() then
            clicked = true
            task.wait(0.2)
            if not isBattleSceneActive() then
                return true
            end
        else
            task.wait(0.12)
        end
    end

    if clicked then
        return true
    end
    return tryEndBattle()
end

local function handleBattleFlee()
    if macroStartMounting then
        return
    end
    encounterFiring = true
    battleEndDebounceUntil = 0
    invisibleTeleportTo(CFrame.new(0, 10000, 0))
    tryFleeBattle()
    tryEndBattle()
end

--------------------------------------------------
-- DETECTION HOOK (RARE MONITORING)
-- Index [4] / [5] = encounter arrays (game swaps which is player vs wild)
-- Chart strings: see USER CONFIG at top of file
--------------------------------------------------

local function idx(t, i)
    if type(t) ~= "table" then return nil end
    return t[i] or t[tostring(i)]
end

local function trimName(raw)
    if type(raw) ~= "string" then return nil end
    return raw:gsub("^%s+", ""):gsub("%s+$", "")
end

local function valueContainsLoomianName(value, loomianName)
    if not value or not loomianName or loomianName == "" then return false end
    local needle = loomianName:lower()

    if type(value) == "string" then
        return value:lower():find(needle, 1, true) ~= nil
    end

    if type(value) == "table" then
        for _, nested in pairs(value) do
            if type(nested) == "string" and nested:lower():find(needle, 1, true) then
                return true
            end
            if type(nested) == "table" and valueContainsLoomianName(nested, loomianName) then
                return true
            end
        end
    end

    return false
end

local function isStartOnlyPacket(value)
    if type(value) == "table" then
        local first = idx(value, 1)
        if first == "start" and idx(value, 2) == nil and idx(value, 3) == nil then
            return true
        end
    end
    if type(value) == "string" then
        return value:find('"start"', 1, true) ~= nil
            and not value:lower():find(PLAYER_LOOMIAN_NAME:lower(), 1, true)
            and not value:find("switch", 1, true)
    end
    return false
end

local function selectEncounterPacket(arg)
    local part4 = arg[4]
    local part5 = arg[5]
    local playerIn4 = valueContainsLoomianName(part4, PLAYER_LOOMIAN_NAME)
    local playerIn5 = valueContainsLoomianName(part5, PLAYER_LOOMIAN_NAME)

    if playerIn4 and not playerIn5 then
        return part5, 5
    end
    if playerIn5 and not playerIn4 then
        return part4, 4
    end

    if part5 and not isStartOnlyPacket(part5) and not playerIn5 then
        return part5, 5
    end
    if part4 and not isStartOnlyPacket(part4) and not playerIn4 then
        return part4, 4
    end

    if part5 and not playerIn5 then
        return part5, 5
    end
    if part4 and not playerIn4 then
        return part4, 4
    end

    return nil, nil
end

local function isPlayerLoomianName(name)
    if not name or PLAYER_LOOMIAN_NAME == "" then return false end
    return name:lower():find(PLAYER_LOOMIAN_NAME:lower(), 1, true) ~= nil
end

local function isKyeggoSpeciesString(value)
    if type(value) ~= "string" then return false end
    local lower = value:lower()
    if lower:match("^kyeggo%-pattern%d+$") then return true end
    if lower:match("^kyeggo$") then return true end
    if lower:match("^kyeggo,") then return true end
    if lower:find(": kyeggo", 1, true) then return true end
    return false
end

local function scanTableForVariant(value)
    local hints = {
        gleam = false,
        wisp = false,
        gammaLiteral = false,
    }

    local function scan(entry)
        if type(entry) == "string" then
            if isKyeggoSpeciesString(entry) then
                return
            end
            local lower = entry:lower()
            if CHART_GLEAM_STRING ~= "" and lower:find(CHART_GLEAM_STRING:lower(), 1, true) then
                hints.gleam = true
            end
            if CHART_GAMMA_STRING ~= "" and lower:find(CHART_GAMMA_STRING:lower(), 1, true) then
                hints.wisp = true
            end
            if CHART_WISP_STRING ~= "" and lower:find(CHART_WISP_STRING:lower(), 1, true) then
                hints.gammaLiteral = true
            end
        elseif type(entry) == "table" then
            for _, nested in pairs(entry) do
                scan(nested)
            end
        end
    end

    scan(value)

    if hints.gleam then
        return "Gleam"
    end
    if hints.wisp then
        return "Gamma"
    end
    if hints.gammaLiteral then
        return "Wisp"
    end
    return nil
end

local function isRareVariant(variant)
    return variant == "Wisp" or variant == "Gleam" or variant == "Gamma"
end

local function isVariantBlacklisted(variant)
    return variant and VARIANT_FLEE_BLACKLIST[variant] == true
end

local function findModelNameInTable(value)
    if type(value) ~= "table" then return nil end
    if type(value.model) == "table" and type(value.model.name) == "string" then
        return trimName(value.model.name)
    end
    for _, nested in pairs(value) do
        if type(nested) == "table" then
            local found = findModelNameInTable(nested)
            if found then return found end
        end
    end
    return nil
end

local function extractQuotedStrings(raw)
    local parts = {}
    for part in raw:gmatch('"([^"]*)"') do
        table.insert(parts, part)
    end
    return parts
end

-- Index [5] is often a JSON string, not a Lua table (prints like an array but type is "string")
local function normalizeIndex5(value)
    if type(value) == "table" then
        return value, nil
    end
    if type(value) ~= "string" then
        return nil, nil
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(value)
    end)
    if ok and type(decoded) == "table" then
        return decoded, value
    end

    local quoted = extractQuotedStrings(value)
    if #quoted >= 3 then
        return {
            [1] = quoted[1],
            [2] = quoted[2],
            [3] = quoted[3],
        }, value
    end

    return nil, value
end

local function parseEncounterFromRawString(raw)
    if type(raw) ~= "string" then return nil end

    local name = trimName(raw:match('"name"%s*:%s*"([^"]+)"'))
    local variant = scanTableForVariant(raw) or "Normal"

    local quoted = extractQuotedStrings(raw)
    if not name and quoted[3] then
        name = trimName(quoted[3]:match("^([^,]+)"))
    end
    if not name and quoted[2] then
        name = trimName(quoted[2]:match(":%s*(.+)$"))
    end

    if not name then return nil end
    return name, variant
end

local function parseEncounterFromIndex5(data)
    local rawString = type(data) == "string" and data or nil
    local tableData, decodedFrom = normalizeIndex5(data)

    if type(tableData) == "table" then
        local name = findModelNameInTable(tableData)

        if not name and type(idx(tableData, 3)) == "string" then
            name = trimName(idx(tableData, 3):match("^([^,]+)"))
        end

        if not name and type(idx(tableData, 2)) == "string" then
            name = trimName(idx(tableData, 2):match(":%s*(.+)$"))
        end

        if not name and decodedFrom then
            name = select(1, parseEncounterFromRawString(decodedFrom))
        end

        if not name then return nil end

        local variant = scanTableForVariant(tableData)
            or (decodedFrom and scanTableForVariant(decodedFrom))
            or "Normal"
        return name, variant, tableData
    end

    if rawString or decodedFrom then
        local name, variant = parseEncounterFromRawString(rawString or decodedFrom)
        if name then
            return name, variant, nil
        end
    end

    return nil
end

local function applyEncounterDisplay(name, variant)
    loomianData.enemy = name
    loomianData.enemyType = variant or "Normal"
    loomianData.lastUpdate = tick()

    if enemyLabel and enemyLabel.Parent then
        enemyLabel.Text = "TARGET: " .. string.upper(name)
    end
    if typeLabel and typeLabel.Parent then
        typeLabel.Text = "VARIANT: " .. string.upper(variant or "Normal")
    end

    print("[Encounter]", name, variant or "Normal")
    notifyDiscordEncounter(name, variant, loomianData.statsLine)
end

local function isEncounterDataFresh()
    return loomianData.enemy ~= "None"
        and loomianData.enemy ~= ""
        and loomianData.lastUpdate > 0
        and (tick() - loomianData.lastUpdate) <= ENCOUNTER_DATA_MAX_AGE
end

local function hookRemote(remote)
    local conn = remote.OnClientEvent:Connect(function(...)
        local args = { ... }

        if _G.LoomianAuto and _G.LoomianAuto.cacheEggRainLand then
            if args[1] == "eggRainLand" then
                _G.LoomianAuto.cacheEggRainLand(args)
            else
                for _, arg in ipairs(args) do
                    if type(arg) == "table" and arg[1] == "eggRainLand" then
                        _G.LoomianAuto.cacheEggRainLand(arg)
                        break
                    end
                end
            end
        end

        for _, arg in ipairs(args) do
            if type(arg) == "table" and (arg[4] or arg[5]) then
                local encounterRaw, encounterIndex = selectEncounterPacket(arg)
                if encounterRaw then
            local encounterData, encounterString = normalizeIndex5(encounterRaw)
            local rawForScan = encounterString or (type(encounterRaw) == "string" and encounterRaw or nil)

            print("--- ENCOUNTER DATA DETECTED (" .. SCRIPT_VERSION .. ") ---")
            print("Raw Table Data:", arg)
            print("Index 4:", arg[4])
            print("Index 5:", arg[5])
            print("Using Index", encounterIndex, "(skipped", PLAYER_LOOMIAN_NAME, "if present in other slot)")
            print("Encounter Packet:", encounterRaw)

            warn(">>> INDEX " .. tostring(encounterIndex) .. " SPLIT (" .. SCRIPT_VERSION .. ") <<<")
            warn("  type: " .. type(encounterRaw) .. " -> parsed as: " .. type(encounterData))

            local ok, err = pcall(function()
                warn("  [" .. encounterIndex .. "][1] Action     : " .. tostring(idx(encounterData, 1)))
                warn("  [" .. encounterIndex .. "][2] Slot/Name  : " .. tostring(idx(encounterData, 2)))

                local statsLine = idx(encounterData, 3)
                warn("  [" .. encounterIndex .. "][3] Stats Line : " .. tostring(statsLine))

                local modelBlock = idx(encounterData, 4)
                warn("  [" .. encounterIndex .. "][4] Model Block: " .. tostring(modelBlock))

                if type(statsLine) == "string" then
                    local namePart, levelPart, genderPart = statsLine:match("^([^,]+),%s*(L%d+),%s*([^;]+)")
                    warn("  [" .. encounterIndex .. "][3] Split (comma):")
                    warn("    Name   : " .. tostring(namePart or "N/A"))
                    warn("    Level  : " .. tostring(levelPart or "N/A"))
                    warn("    Gender : " .. tostring(genderPart or "N/A"))

                    local hpPart, flagPart, energyPart = statsLine:match(";([^;]+);([^;]+);([^;]+)$")
                    warn("  [" .. encounterIndex .. "][3] Split (semicolon):")
                    warn("    HP     : " .. tostring(hpPart or "N/A"))
                    warn("    Flag   : " .. tostring(flagPart or "N/A"))
                    warn("    Energy : " .. tostring(energyPart or "N/A"))
                end

                if type(modelBlock) == "table" then
                    local model = modelBlock.model or idx(modelBlock, "model")
                    if type(model) == "table" then
                        warn("  [" .. encounterIndex .. "][4] Model Name : " .. tostring(model.name or idx(model, "name")))
                        warn("  [" .. encounterIndex .. "][4] Model Scale: " .. tostring(model.scale or idx(model, "scale")))
                    end
                    local icon = modelBlock.icon or idx(modelBlock, "icon")
                    if type(icon) == "table" then
                        warn("  [" .. encounterIndex .. "][4] Icon X     : " .. tostring(idx(icon, 1)))
                        warn("  [" .. encounterIndex .. "][4] Icon Y     : " .. tostring(idx(icon, 2)))
                    end
                elseif rawForScan then
                    warn("  [" .. encounterIndex .. "][4] Model Name : " .. tostring(rawForScan:match('"name"%s*:%s*"([^"]+)"') or "N/A"))
                    local iconX, iconY = rawForScan:match('"icon"%s*:%s*%[(%d+)%s*,%s*(%d+)%]')
                    warn("  [" .. encounterIndex .. "][4] Icon X     : " .. tostring(iconX or "N/A"))
                    warn("  [" .. encounterIndex .. "][4] Icon Y     : " .. tostring(iconY or "N/A"))
                end
            end)

            if not ok then
                warn("[Encounter Split Error] " .. tostring(err))
            end

            print("-------------------------------")

            local name, variant, tableData = parseEncounterFromIndex5(encounterRaw)
            if name and isPlayerLoomianName(name) then
                warn("[Encounter] Skipped own Loomian:", name)
            elseif name then
                if type(tableData) == "table" then
                    local statsLine = idx(tableData, 3)
                    loomianData.statsLine = type(statsLine) == "string" and statsLine or ""
                end
                applyEncounterDisplay(name, variant)
            else
                warn("[Encounter] Could not parse enemy from index " .. tostring(encounterIndex))
            end
                end
            end
        end
    end)

    table.insert(_G.LoomianAuto.encounterConnections, conn)
end

for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") then hookRemote(obj) end
end
_G.LoomianAuto.descendantAddedConn = ReplicatedStorage.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") then hookRemote(obj) end
end)

-- Battle hook (pre-empt wild encounters)
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer" and self:IsA("RemoteFunction") then
            local args = { ... }
            if args[2] == "BattleFunction" and args[3] == "new" then
                task.spawn(handleBattleFlee)
            end
        end
        return oldNamecall(self, ...)
    end)
end)

--------------------------------------------------
-- EGG TOKEN SWEEP (encounter eggs first, then others)
--------------------------------------------------
local eggSweep = {
    tokens = {},
    used = {},
    wrappedHandlers = setmetatable({}, { __mode = "k" }),
    hookedInvoke = nil,
    invokeInside = false,
    evtConnectRestore = nil,
    REQ = nil,
    lastAuth = nil,
    botCollecting = false,
}

local function eggSweepPack(...)
    local t = {...}
    t.n = select("#", ...)
    return t
end

local function eggSweepShort(v)
    if type(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do
            table.insert(parts, tostring(k) .. "=" .. tostring(val))
        end
        return "table{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function isEncounterEggType(eggType)
    return eggType == EGG_ENCOUNTER_TYPE
        or eggType == "1"
        or tonumber(eggType) == EGG_ENCOUNTER_TYPE
end

local function isRealEggEncounter(result)
    return type(result) == "table"
        and result[1] == 1
        and type(result[2]) == "table"
        and result[2].id ~= nil
end

local function normalizeEggPos(pos)
    if typeof(pos) == "Vector3" then
        return pos
    end
    if type(pos) == "table" then
        local x = pos.X or pos.x or pos[1]
        local y = pos.Y or pos.y or pos[2]
        local z = pos.Z or pos.z or pos[3]
        if x and y and z then
            return Vector3.new(x, y, z)
        end
    end
    return nil
end

local function getEffectiveTokenMaxAge()
    return eggEncounterOnly() and math.min(EGG_TOKEN_SWEEP_MAX_AGE, EGG_TOKEN_FRESH_MAX_AGE) or EGG_TOKEN_SWEEP_MAX_AGE
end

local function isFreshCachedToken(data)
    return data ~= nil and (os.clock() - (data.time or 0)) <= getEffectiveTokenMaxAge()
end

local function eggSweepAddToken(chunk, pos, token, eggType)
    if type(token) ~= "string" or token == "" then return end
    if eggSweep.used[token] then return end

    pos = normalizeEggPos(pos)

    -- Server can re-roll token/type at the same landing spot after each collect.
    if pos then
        local kept = {}
        for _, data in ipairs(eggSweep.tokens) do
            local dataPos = normalizeEggPos(data.pos)
            if data.token == token then
                table.insert(kept, data)
            elseif not dataPos or (dataPos - pos).Magnitude > EGG_TOKEN_POSITION_DEDUP then
                table.insert(kept, data)
            end
        end
        eggSweep.tokens = kept
    end

    for _, data in ipairs(eggSweep.tokens) do
        if data.token == token then
            data.time = os.clock()
            data.chunk = chunk or data.chunk
            data.pos = pos or data.pos
            data.eggType = eggType or data.eggType
            return
        end
    end

    table.insert(eggSweep.tokens, {
        chunk = chunk,
        pos = pos,
        token = token,
        eggType = eggType,
        time = os.clock(),
    })

    if #eggSweep.tokens > EGG_TOKEN_SWEEP_MAX_CACHE then
        table.remove(eggSweep.tokens, 1)
    end

    print("[EggSweep] Cached", token, "type:", eggType,
        isEncounterEggType(eggType) and "(encounter at land)" or "(other at land)",
        eggEncounterOnly() and "[type may re-roll on collect]" or "")
end

local function eggSweepCleanTokens()
    local now = os.clock()
    local maxAge = getEffectiveTokenMaxAge()
    local fresh = {}

    for _, data in ipairs(eggSweep.tokens) do
        if not eggSweep.used[data.token]
            and now - data.time <= maxAge then
            table.insert(fresh, data)
        end
    end

    eggSweep.tokens = fresh
end

local function countFreshTokens()
    local n = 0
    for _, data in ipairs(eggSweep.tokens) do
        if isFreshCachedToken(data) and not eggSweep.used[data.token] then
            if not eggEncounterOnly() or isEncounterEggType(data.eggType) then
                n += 1
            end
        end
    end
    return n
end

local function shouldProcessEggRainLand(args)
    if not args or args[1] ~= "eggRainLand" then
        return false
    end
    if eggEncounterOnly() and not isEncounterEggType(args[5]) then
        return false
    end
    return true
end

local function eggSweepCacheRainLand(args)
    if shouldProcessEggRainLand(args) then
        eggSweepAddToken(args[2], args[3], args[4], args[5])
    end
end

local function eggSweepOnRainLand(args)
    eggSweepCacheRainLand(args)
end

_G.LoomianAuto.cacheEggRainLand = eggSweepCacheRainLand

local function countEncounterTokens()
    local n = 0
    for _, data in ipairs(eggSweep.tokens) do
        if isEncounterEggType(data.eggType) then
            n += 1
        end
    end
    return n
end

local function eggSweepWrapHandler(fn)
    if typeof(fn) ~= "function" then return fn end
    if eggSweep.wrappedHandlers[fn] then
        return eggSweep.wrappedHandlers[fn]
    end

    local old = fn
    local wrapped = newcclosure(function(...)
        local args = eggSweepPack(...)
        if shouldProcessEggRainLand(args) then
            eggSweepCacheRainLand(args)
            return old(table.unpack(args, 1, args.n))
        end
        if args[1] == "eggRainLand" and eggEncounterOnly() then
            return
        end
        return old(table.unpack(args, 1, args.n))
    end)

    eggSweep.wrappedHandlers[fn] = wrapped
    return wrapped
end

local function getTokenDataByToken(token)
    if type(token) ~= "string" then return nil end
    for _, data in ipairs(eggSweep.tokens) do
        if data.token == token then
            return data
        end
    end
    return nil
end

local function getEggMatchRadius()
    return eggEncounterOnly() and math.min(EGG_TOKEN_MATCH_RADIUS, 30) or EGG_TOKEN_MATCH_RADIUS
end

local function eggSweepBuildTryOrder(originalToken, preferredChunk)
    eggSweepCleanTokens()

    local root = getRootPart()
    local playerPos = root and root.Position or nil
    local now = os.clock()
    local candidates = {}

    for _, data in ipairs(eggSweep.tokens) do
        local token = data.token
        if token ~= originalToken and not eggSweep.used[token] and isFreshCachedToken(data) then
            if eggEncounterOnly() and not isEncounterEggType(data.eggType) then
                continue
            end
            local score = 0
            if eggEncounterOnly() then
                score += (now - data.time) * 100
            elseif isEncounterEggType(data.eggType) then
                score -= 10000
            else
                score += 5000
            end
            if preferredChunk and data.chunk == preferredChunk then
                score -= 1000
            end
            if playerPos and data.pos then
                local tokenPos = normalizeEggPos(data.pos)
                if tokenPos then
                    score += (playerPos - tokenPos).Magnitude
                end
            end
            table.insert(candidates, { data = data, score = score })
        end
    end

    table.sort(candidates, function(a, b)
        return a.score < b.score
    end)

    local ordered = {}
    for _, item in ipairs(candidates) do
        table.insert(ordered, item.data)
    end
    return ordered
end

local function getCachedTokenForEgg(eggPart)
    if not eggPart or not eggPart:IsA("BasePart") then return nil end
    local eggPos = eggPart.Position
    local best, bestDist, bestAge = nil, getEggMatchRadius(), math.huge

    for _, data in ipairs(eggSweep.tokens) do
        if not isFreshCachedToken(data) or eggSweep.used[data.token] then
            continue
        end
        if eggEncounterOnly() and not isEncounterEggType(data.eggType) then
            continue
        end
        local tokenPos = normalizeEggPos(data.pos)
        if tokenPos then
            local dist = (eggPos - tokenPos).Magnitude
            local age = os.clock() - data.time
            if dist < bestDist or (dist == bestDist and age < bestAge) then
                bestDist = dist
                bestAge = age
                best = data
            end
        end
    end

    return best
end

local function isChunkEgg(obj)
    local parent = obj.Parent
    return obj:IsA("BasePart")
        and obj.Name == "Egg"
        and parent
        and string.find(parent.Name, "^chunk%d+") ~= nil
end

local function isCameraEgg(obj)
    local camera = Workspace.CurrentCamera
    return obj and camera and obj:IsDescendantOf(camera)
end

local function isCollectableWorldEgg(obj)
    if not obj or not obj:IsA("BasePart") or obj.Name ~= "Egg" then
        return false
    end
    if isCameraEgg(obj) or used[obj] then
        return false
    end
    if isChunkEgg(obj) then
        return true
    end
    -- Raid / cave eggs (not under chunk#, not camera)
    local parent = obj.Parent
    return parent ~= nil and parent:IsDescendantOf(Workspace)
end

local function isEncounterEggPart(obj)
    if not isCollectableWorldEgg(obj) then
        return false
    end
    local cached = getCachedTokenForEgg(obj)
    return cached ~= nil and isEncounterEggType(cached.eggType)
end

local function isCollectableForMode(obj, inRaid)
    if not isCollectableWorldEgg(obj) then
        return false
    end
    if eggEncounterOnly() then
        return isEncounterEggPart(obj)
    end
    if isEncounterEggPart(obj) or isChunkEgg(obj) then
        return true
    end
    return inRaid and not isChunkEgg(obj)
end

local function sortEggsByEncounterPriority(eggs)
    local root = getRootPart()
    local playerPos = root and root.Position or nil
    local ranked = {}

    for _, egg in ipairs(eggs) do
        local score = 2000
        local cached = getCachedTokenForEgg(egg)
        if cached then
            if isEncounterEggType(cached.eggType) then
                score = 0
            else
                score = 1000
            end
        end
        if playerPos then
            score += (playerPos - egg.Position).Magnitude * 0.01
        end
        table.insert(ranked, { egg = egg, score = score })
    end

    table.sort(ranked, function(a, b)
        return a.score < b.score
    end)

    local ordered = {}
    for _, item in ipairs(ranked) do
        table.insert(ordered, item.egg)
    end
    return ordered
end

local function splitWorldEggsForCollection(descendants, inRaid)
    local encounterEggs = {}
    local normalChunkEggs = {}
    local normalRaidEggs = {}

    for i = 1, #descendants do
        local obj = descendants[i]
        if not isCollectableWorldEgg(obj) then
            continue
        end
        if isEncounterEggPart(obj) then
            table.insert(encounterEggs, obj)
        elseif not eggEncounterOnly() then
            if isChunkEgg(obj) then
                table.insert(normalChunkEggs, obj)
            elseif inRaid then
                table.insert(normalRaidEggs, obj)
            end
        end
    end

    return encounterEggs, normalChunkEggs, normalRaidEggs
end

local function getUnlinkedCollectibleTokens(linkedTokens)
    local tokenTargets = {}
    for _, data in ipairs(eggSweep.tokens) do
        local typeOk = not eggEncounterOnly() or isEncounterEggType(data.eggType)
        if typeOk
            and isFreshCachedToken(data)
            and not eggSweep.used[data.token]
            and normalizeEggPos(data.pos)
            and not (linkedTokens and linkedTokens[data.token]) then
            table.insert(tokenTargets, data)
        end
    end
    table.sort(tokenTargets, function(a, b)
        return a.time > b.time
    end)
    return tokenTargets
end

local function getUnlinkedEncounterTokens(linkedTokens)
    return getUnlinkedCollectibleTokens(linkedTokens)
end

local function getNearestCollectibleEncounterToken(linkedTokens)
    local root = getRootPart()
    local playerPos = root and root.Position or nil
    local tokens = getUnlinkedEncounterTokens(linkedTokens)
    if #tokens == 0 then return nil end
    if not playerPos then return tokens[1] end

    local best, bestScore = tokens[1], math.huge
    for _, data in ipairs(tokens) do
        local pos = normalizeEggPos(data.pos)
        local score = pos and (playerPos - pos).Magnitude or math.huge
        score -= (os.clock() - data.time) * 0.1
        if score < bestScore then
            bestScore = score
            best = data
        end
    end
    return best
end

local function performEncounterTokenCollect(tokenData)
    if not tokenData or not tokenData.token then
        return false
    end
    if not eggSweep.REQ then
        warn("[EggSweep] REQ not ready")
        return false
    end
    if not eggSweep.lastAuth then
        warn("[EggSweep] No PDS auth yet — walk around until the game sends a remote")
        return false
    end

    local pos = normalizeEggPos(tokenData.pos)
    if pos then
        local destination = CFrame.new(pos + Vector3.new(0, 5, 0))
        local teleportDeadline = tick() + 2
        repeat
            teleportCharacterTo(destination)
            task.wait(0.08)
        until (getRootPart() and (getRootPart().Position - destination.Position).Magnitude < 8)
            or tick() > teleportDeadline
        task.wait(0.25)
    end

    print("[EggSweep] Bot collect token:", tokenData.token, "chunk:", tokenData.chunk)

    eggSweep.botCollecting = true
    local ok, result = pcall(function()
        return eggSweep.REQ:InvokeServer(
            eggSweep.lastAuth,
            "PDS",
            "collectFallenEgg",
            tokenData.token
        )
    end)
    eggSweep.botCollecting = false

    if not ok then
        warn("[EggSweep] Token collect failed:", result)
        return false
    end

    local gotEncounter = isRealEggEncounter(result) or getBattleGui() ~= nil
    if gotEncounter then
        print("[EggSweep] Encounter confirmed for token:", tokenData.token)
    else
        print("[EggSweep] Token was not an encounter:", tokenData.token)
        eggSweep.used[tokenData.token] = true
    end
    return gotEncounter
end

local function pickNearestEgg(eggs)
    if #eggs == 0 then return nil end
    return sortEggsByEncounterPriority(eggs)[1]
end

local function performEggCollectionAt(destinationCFrame, markPart)
    local teleportDeadline = tick() + 2
    repeat
        teleportCharacterTo(destinationCFrame)
        task.wait(0.08)
    until (getRootPart() and (getRootPart().Position - destinationCFrame.Position).Magnitude < 6)
        or tick() > teleportDeadline

    task.wait(0.3)

    local v = Workspace.CurrentCamera.ViewportSize
    local iStart = tick()

    repeat
        VIM:SendMouseButtonEvent(v.X / 2, v.Y / 2, 0, true, game, 1)
        VIM:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(v.X / 2, v.Y / 2, 0, false, game, 1)
        VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        task.wait(0.1)
    until getBattleGui() or (tick() - iStart > 2.5)

    if eggEncounterOnly() then
        local gotEncounter = getBattleGui() ~= nil
        if gotEncounter and markPart and markPart:IsA("BasePart") then
            used[markPart] = true
        end
        return gotEncounter
    end

    if markPart and markPart:IsA("BasePart") then
        if eggEncounterOnly() and not isEncounterEggPart(markPart) then
            return false
        end
        local collected = (not getBattleGui()) and (not markPart:IsDescendantOf(Workspace))
        if collected then
            boxCount += 1
            boxCounterLabel.Text = "EGGS COLLECTED: " .. boxCount
            used[markPart] = true
        end
        return collected
    end

    return getBattleGui() ~= nil
end

local function installEggTokenSweep()
    if not EGG_TOKEN_SWEEP_ENABLED then
        print("[EggSweep] Disabled in USER CONFIG")
        return false
    end

    if not hookfunction or not newcclosure or not getconnections then
        warn("[EggSweep] Need hookfunction + newcclosure + getconnections — sweep disabled")
        return false
    end

    local remoteFolder = ReplicatedStorage:WaitForChild("Remote", 15)
    if not remoteFolder then
        warn("[EggSweep] Remote folder not found")
        return false
    end

    local EVT = remoteFolder:WaitForChild("EVT", 15)
    local REQ = remoteFolder:WaitForChild("REQ", 15)
    if not EVT or not REQ then
        warn("[EggSweep] EVT/REQ not found")
        return false
    end
    eggSweep.REQ = REQ

    local hookedCount = 0
    for _, conn in ipairs(getconnections(EVT.OnClientEvent)) do
        local fn = conn.Function
        if typeof(fn) == "function" and not eggSweep.wrappedHandlers[fn] then
            hookfunction(fn, eggSweepWrapHandler(fn))
            hookedCount += 1
        end
    end

    local event = EVT.OnClientEvent
    local oldConnect = event.Connect
    event.Connect = newcclosure(function(_, handler)
        return oldConnect(event, eggSweepWrapHandler(handler))
    end)
    eggSweep.evtConnectRestore = function()
        event.Connect = oldConnect
    end

    local temp = Instance.new("RemoteFunction")
    local invokeServerFn = temp.InvokeServer
    temp:Destroy()

    eggSweep.hookedInvoke = hookfunction(invokeServerFn, newcclosure(function(self, ...)
        local args = eggSweepPack(...)

        if eggSweep.invokeInside then
            return eggSweep.hookedInvoke(self, ...)
        end

        if self == REQ and args[2] == "PDS" and args[1] then
            eggSweep.lastAuth = args[1]
        end

        if eggEncounterOnly()
            and not eggSweep.botCollecting
            and self == REQ
            and args[2] == "PDS"
            and args[3] == "collectFallenEgg" then
            print("[EggSweep] Blocked manual/proximity collect — bot token-only mode")
            return 0
        end

        if EGG_TOKEN_SWEEP_ENABLED
            and self == REQ
            and args[2] == "PDS"
            and args[3] == "collectFallenEgg" then

            local auth = args[1]
            local originalToken = args[4]
            local originalData = getTokenDataByToken(originalToken)

            if type(originalToken) == "string" and originalToken ~= "" then
                eggSweep.used[originalToken] = true
            end

            eggSweep.invokeInside = true
            local result = eggSweepPack(eggSweep.hookedInvoke(self, table.unpack(args, 1, args.n)))
            eggSweep.invokeInside = false

            if isRealEggEncounter(result) then
                print("[EggSweep] Encounter from collected egg:", result[2].id)
                return table.unpack(result, 1, result.n)
            end

            local preferredChunk = originalData and originalData.chunk
            if not preferredChunk then
                for _, data in ipairs(eggSweep.tokens) do
                    if data.token == originalToken then
                        preferredChunk = data.chunk
                        break
                    end
                end
            end

            local tryOrder = eggSweepBuildTryOrder(originalToken, preferredChunk)
            local tries = 0

            for _, data in ipairs(tryOrder) do
                if tries >= EGG_TOKEN_SWEEP_MAX_TRIES then break end

                local token = data.token
                tries += 1
                eggSweep.used[token] = true

                print("[EggSweep] Trying", tries, token,
                    isEncounterEggType(data.eggType) and "(cached encounter)" or "(cached other/fresh)")

                eggSweep.invokeInside = true
                local r = eggSweepPack(eggSweep.hookedInvoke(self, auth, "PDS", "collectFallenEgg", token))
                eggSweep.invokeInside = false

                if isRealEggEncounter(r) then
                    print("[EggSweep] Encounter from sweep:", r[2].id)
                    return table.unpack(r, 1, r.n)
                end
            end

            if eggEncounterOnly() then
                print("[EggSweep] No real encounter — cached types may have re-rolled; rejecting collect")
                eggSweepCleanTokens()
                return 0
            end

            return table.unpack(result, 1, result.n)
        end

        return eggSweep.hookedInvoke(self, ...)
    end))

    _G.LoomianAuto.eggSweepRestore = function()
        EGG_TOKEN_SWEEP_ENABLED = false
        if eggSweep.evtConnectRestore then
            pcall(eggSweep.evtConnectRestore)
            eggSweep.evtConnectRestore = nil
        end
        print("[EggSweep] Disabled — rejoin to fully remove InvokeServer hook")
    end

    print("[EggSweep] Active —",
        eggEncounterOnly() and "ENCOUNTER ONLY — spawn filter + bot token collects" or "encounter tokens first, then others",
        "(hooked", hookedCount, "EVT handler(s))")
    return true
end

pcall(installEggTokenSweep)

--------------------------------------------------
-- RAID CAVE / WEATHER NAVIGATION (from message 7)
--------------------------------------------------
local statusLabel
local raidLabel
local setRaidStatus

setRaidStatus = function(msg)
    if raidLabel then
        raidLabel.Text = "RAID: " .. msg
    end
    if statusLabel then
        statusLabel.Text = "STATUS: " .. msg
    end
    print("[Raid Nav]", msg)
end

local function getTabButtons(mapMenu)
    local buttons = {}
    for _, child in ipairs(mapMenu:GetChildren()) do
        if child:IsA("ImageButton") then
            table.insert(buttons, child)
        end
    end
    table.sort(buttons, function(a, b)
        return a.AbsolutePosition.X < b.AbsolutePosition.X
    end)
    return buttons
end

local function matchEquivalencyKey(text)
    if not text or text == "" then return nil end

    if equivalency[text] then
        return text
    end

    local keys = {}
    for key in pairs(equivalency) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b)
        return #a > #b
    end)

    for _, key in ipairs(keys) do
        if text:find(key, 1, true) then
            return key
        end
    end

    local route = text:match("(Route %d+)")
    if route and equivalency[route] then
        return route
    end

    return nil
end

local function getWeatherFromFrame(frame)
    for _, child in ipairs(frame:GetChildren()) do
        if child.Name == "Frame" then
            for _, sub in ipairs(child:GetDescendants()) do
                if sub:IsA("TextLabel") and sub.Text ~= "" then
                    local key = matchEquivalencyKey(sub.Text)
                    if key then return key end
                end
            end
            if #child:GetChildren() == 2 then
                local textLabel = child:FindFirstChildOfClass("TextLabel")
                if textLabel then
                    local key = matchEquivalencyKey(textLabel.Text)
                    if key then return key end
                end
            end
        end
    end

    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text ~= "" then
            local key = matchEquivalencyKey(desc.Text)
            if key then return key end
        end
    end

    return nil
end

local function getCurrentWeatherLocation(mapMenu)
    local forecastContainer = mapMenu:FindFirstChild("ForecastContainer")
    if not forecastContainer then return nil end

    local timelineVertical = forecastContainer:FindFirstChild("TimelineVertical")
    if timelineVertical then
        local frames = {}
        for _, child in ipairs(timelineVertical.Parent:GetChildren()) do
            if child.Name == "Frame" then
                table.insert(frames, child)
            end
        end
        table.sort(frames, function(a, b)
            return a.AbsolutePosition.Y < b.AbsolutePosition.Y
        end)

        for _, frame in ipairs(frames) do
            local key = getWeatherFromFrame(frame)
            if key then return key end
        end
    end

    for _, desc in ipairs(forecastContainer:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text ~= "" then
            local key = matchEquivalencyKey(desc.Text)
            if key then return key end
        end
    end

    return nil
end

local function openWatch()
    local mainGui = player.PlayerGui:FindFirstChild("MainGui")
    if not mainGui then return false, "MainGui missing" end

    local watchContainer = mainGui:FindFirstChild("WatchContainer")
    if not watchContainer then return false, "WatchContainer missing" end

    for attempt = 1, 8 do
        local mapMenu = watchContainer:FindFirstChild("MapMenu")
        if mapMenu and mapMenu.Visible ~= false then
            return true
        end

        setRaidStatus("Opening watch... (" .. attempt .. "/8)")
        pressKey(Enum.KeyCode.Three)
        task.wait(0.6)

        mapMenu = watchContainer:WaitForChild("MapMenu", 2)
        if mapMenu then
            task.wait(0.4)
            if mapMenu.Visible ~= false then
                return true
            end
        end
    end

    return false, "Could not open watch (press 3 manually once)"
end

local SCROLL_EXTRA_DOWN = 80
local SCROLL_VIEW_TARGET = 0.38

local function clampScrollCanvas(scrollingFrame)
    local maxY = math.max(0, scrollingFrame.AbsoluteCanvasSize.Y - scrollingFrame.AbsoluteSize.Y)
    local pos = scrollingFrame.CanvasPosition
    scrollingFrame.CanvasPosition = Vector2.new(pos.X, math.clamp(pos.Y, 0, maxY))
end

local function isElementInScrollView(scrollingFrame, element)
    if not scrollingFrame or not element then return false end
    local ey, eh = element.AbsolutePosition.Y, element.AbsoluteSize.Y
    local fy, fh = scrollingFrame.AbsolutePosition.Y, scrollingFrame.AbsoluteSize.Y
    if eh <= 0 or fh <= 0 then return false end

    local elementCenter = ey + eh / 2
    local viewTarget = fy + fh * SCROLL_VIEW_TARGET
    local topOk = ey >= fy - 8
    local bottomOk = (ey + eh) <= fy + fh + 8
    local centerOk = math.abs(elementCenter - viewTarget) <= 20

    return topOk and bottomOk and centerOk
end

local function scrollElementIntoView(scrollingFrame, element)
    if not scrollingFrame or not element then return false end

    clampScrollCanvas(scrollingFrame)
    RunService.Heartbeat:Wait()

    for _ = 1, 25 do
        clampScrollCanvas(scrollingFrame)

        local ey = element.AbsolutePosition.Y
        local eh = element.AbsoluteSize.Y
        local fy = scrollingFrame.AbsolutePosition.Y
        local fh = scrollingFrame.AbsoluteSize.Y
        local canvas = scrollingFrame.CanvasPosition

        if eh <= 0 or fh <= 0 then
            task.wait(0.1)
            continue
        end

        local elementCenter = ey + eh / 2
        local viewTarget = fy + fh * SCROLL_VIEW_TARGET
        local topGap = ey - fy
        local bottomGap = (ey + eh) - (fy + fh)
        local alignDelta = elementCenter - viewTarget

        if topGap >= -8 and bottomGap <= 8 and math.abs(alignDelta) <= 15 then
            break
        end

        local scrollDelta
        if bottomGap > 0 then
            scrollDelta = math.max(bottomGap + SCROLL_EXTRA_DOWN, alignDelta, 50)
        elseif topGap < 0 then
            scrollDelta = math.min(topGap - 40, alignDelta, -40)
        else
            scrollDelta = alignDelta
        end

        scrollingFrame.CanvasPosition = Vector2.new(canvas.X, canvas.Y + scrollDelta)
        task.wait(0.1)
        RunService.Heartbeat:Wait()
    end

    -- Nudge further down so geo-hop click spot (below center) stays on screen
    local canvas = scrollingFrame.CanvasPosition
    scrollingFrame.CanvasPosition = Vector2.new(canvas.X, canvas.Y + 30)
    clampScrollCanvas(scrollingFrame)
    task.wait(0.2)
    RunService.Heartbeat:Wait()

    return isElementInScrollView(scrollingFrame, element)
end

local function getMapLocationList(mapMenu)
    local menuListContainer = mapMenu:FindFirstChildOfClass("ScrollingFrame")
    if not menuListContainer then
        for _, desc in ipairs(mapMenu:GetDescendants()) do
            if desc:IsA("ScrollingFrame") then
                return desc
            end
        end
    end
    return menuListContainer
end

local function findGeoHopForLocation(locationsScrollingFrame, locationName)
    for _, itemBlock in ipairs(locationsScrollingFrame:GetDescendants()) do
        if itemBlock:IsA("ImageButton") or (itemBlock:IsA("Frame") and itemBlock.Name == "Frame") then
            local geoHopElement = nil
            local matchedTitleText = nil

            for _, innerChild in ipairs(itemBlock:GetDescendants()) do
                if innerChild:IsA("TextLabel") then
                    if innerChild.Text == "Geo Hop" then
                        geoHopElement = innerChild:FindFirstAncestorOfClass("ImageButton") or innerChild
                    elseif innerChild.Text ~= "" and innerChild.Text ~= " " and not string.find(innerChild.Text, " studs") then
                        matchedTitleText = innerChild.Text
                    end
                end
            end

            if geoHopElement and matchedTitleText == locationName then
                return geoHopElement, itemBlock
            end
        end
    end
    return nil
end

local function triggerGeoHopClick(geoHopElement)
    if not geoHopElement then return false end

    local ap = geoHopElement.AbsolutePosition
    local as = geoHopElement.AbsoluteSize
    if as.X <= 0 or as.Y <= 0 then return false end

    -- Same click math as geohop detection.lua
    local clickX = ap.X + (as.X / 2) + clickOffsets.geoHopX
    local clickY = ap.Y + (as.Y / 2) + (clickOffsets.geoHopY + GEOHOP_Y_BASE)

    showClickHighlight(math.floor(clickX + 0.5), math.floor(clickY + 0.5), "GeoHop")

    VIM:SendMouseButtonEvent(clickX, clickY, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(clickX, clickY, 0, false, game, 0)
    return true
end

local function clickGeoHop(locationName, locationsScrollingFrame)
    if not locationName or not locationsScrollingFrame then return false end

    local geoHopElement, itemBlock = findGeoHopForLocation(locationsScrollingFrame, locationName)
    if not geoHopElement then return false end

    setRaidStatus("Scrolling to location...")
    scrollElementIntoView(locationsScrollingFrame, itemBlock)
    task.wait(0.25)

    return triggerGeoHopClick(geoHopElement)
end

local function waitForTeleport(timeout)
    local root = getRootPart()
    if not root then return false end

    local startPos = root.Position
    local elapsed = 0
    timeout = timeout or 10
    while elapsed < timeout do
        if not autoMode then return false end
        task.wait(0.5)
        elapsed += 0.5
        local newRoot = getRootPart()
        if newRoot then
            local dist = (newRoot.Position - startPos).Magnitude
            if dist > 100 then
                task.wait(1)
                return true
            end
            if elapsed >= 1.5 then
                return false
            end
        end
    end
    return false
end

local function getInstancePosition(inst)
    if inst:IsA("BasePart") then
        return inst.Position
    end
    if inst:IsA("Model") then
        if inst.PrimaryPart then
            return inst.PrimaryPart.Position
        end
        local part = inst:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.Position
        end
        local ok, pivot = pcall(function()
            return inst:GetPivot().Position
        end)
        if ok and pivot then
            return pivot
        end
    end
    return nil
end

local function isNearMountPart(playerPos, inst, maxDist)
    local pos = getInstancePosition(inst)
    return pos and (pos - playerPos).Magnitude <= maxDist
end

local function isMountActive()
    local root = getRootPart()
    if not root then
        return false
    end

    local playerPos = root.Position
    local maxDist = MOUNT_VERIFY_DISTANCE
    local character = player.Character

    -- When mounted, the loomian model is usually parented under the character.
    if character then
        local mountOnCharacter = character:FindFirstChild(MOUNT_VERIFY_NAME, true)
        if mountOnCharacter then
            return true
        end
    end

    local mountRoot = Workspace:FindFirstChild(MOUNT_VERIFY_NAME)
    if not mountRoot then
        return false
    end

    if isNearMountPart(playerPos, mountRoot, maxDist) then
        return true
    end

    for _, desc in ipairs(mountRoot:GetDescendants()) do
        if isNearMountPart(playerPos, desc, maxDist) then
            return true
        end
    end

    return false
end

local function waitForMountActive(timeout)
    local deadline = tick() + (timeout or MOUNT_VERIFY_WAIT)
    while tick() < deadline do
        if isMountActive() then
            return true
        end
        if not autoMode then
            return false
        end
        task.wait(0.15)
    end
    return isMountActive()
end

local function activateMount(contextLabel, options)
    options = options or {}
    contextLabel = contextLabel or "Mount"
    local startDelay = options.delay
    if startDelay == nil then
        startDelay = MOUNT_ACTIVATE_DELAY
    end

    if startDelay > 0 then
        setRaidStatus(contextLabel .. " - waiting " .. tostring(startDelay) .. "s before mount (Q)...")
        task.wait(startDelay)
    else
        setRaidStatus(contextLabel .. " - activating mount (Q)...")
    end
    if not autoMode then
        lastMountResult = { success = false, attempt = 0, maxAttempts = MOUNT_MAX_ATTEMPTS }
        return false
    end

    if isMountActive() then
        setRaidStatus("Mount already active")
        lastMountResult = { success = true, attempt = 0, maxAttempts = MOUNT_MAX_ATTEMPTS }
        return true
    end

    lastMountResult = nil

    for attempt = 1, MOUNT_MAX_ATTEMPTS do
        if not autoMode then
            lastMountResult = { success = false, attempt = attempt - 1, maxAttempts = MOUNT_MAX_ATTEMPTS }
            return false
        end

        -- Q toggles mount — never press it if we're already mounted.
        if isMountActive() then
            setRaidStatus("Mount active (within " .. tostring(MOUNT_VERIFY_DISTANCE) .. " studs)")
            lastMountResult = { success = true, attempt = attempt, maxAttempts = MOUNT_MAX_ATTEMPTS }
            pcall(function()
                notifyDiscordMount(attempt, MOUNT_MAX_ATTEMPTS, true, false)
            end)
            return true
        end

        setRaidStatus("Activating mount (Q) " .. attempt .. "/" .. MOUNT_MAX_ATTEMPTS)
        pressKey(Enum.KeyCode.Q)

        if waitForMountActive(MOUNT_VERIFY_WAIT) then
            setRaidStatus("Mount active (within " .. tostring(MOUNT_VERIFY_DISTANCE) .. " studs)")
            lastMountResult = { success = true, attempt = attempt, maxAttempts = MOUNT_MAX_ATTEMPTS }
            pcall(function()
                notifyDiscordMount(attempt, MOUNT_MAX_ATTEMPTS, true, false)
            end)
            return true
        end

        local exhausted = attempt >= MOUNT_MAX_ATTEMPTS
        setRaidStatus(exhausted and "Mount failed - not within range" or "Mount failed - retrying Q")
        pcall(function()
            notifyDiscordMount(attempt, MOUNT_MAX_ATTEMPTS, false, exhausted)
        end)
        lastMountResult = { success = false, attempt = attempt, maxAttempts = MOUNT_MAX_ATTEMPTS }

        if not exhausted then
            task.wait(0.5)
        end
    end

    return false
end

local function clickGeoHopWithRetry(locationName, locationsScrollingFrame, maxAttempts)
    maxAttempts = maxAttempts or 3
    for attempt = 1, maxAttempts do
        setRaidStatus("Geo-hop attempt " .. attempt .. "/" .. maxAttempts)
        if clickGeoHop(locationName, locationsScrollingFrame) then
            task.wait(0.5)
            setRaidStatus("Checking geo-hop teleport...")
            if waitForTeleport(10) then
                setRaidStatus("Geo-hop teleport ok")
            else
                setRaidStatus("No teleport detected (may already be at destination)")
            end
            return true
        end
        task.wait(0.5)
    end
    return false
end

local function waitForGate(destination, timeout)
    local elapsed = 0
    while elapsed < timeout do
        if not autoMode then return nil end
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "Gate" then
                local marquee = obj:FindFirstChild("Marquee")
                if marquee then
                    local mtext = marquee:FindFirstChild("MText")
                    if mtext and mtext.Value == destination then
                        return marquee
                    end
                end
            end
        end
        task.wait(0.5)
        elapsed += 0.5
    end
    return nil
end

local function teleportToGate(destination)
    local marquee = waitForGate(destination, 10)
    if not marquee then return false end

    local targetCFrame = CFrame.new(marquee.Position - Vector3.new(0, 10, 0))
    for _ = 1, 30 do
        if not autoMode then return false end
        teleportCharacterTo(targetCFrame)
        task.wait(0.1)
    end
    return true
end

local function raidCaveExists()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "RaidCaveModel" then
            return true
        end
    end
    return false
end

local function waitForRaidCave(timeout)
    local elapsed = 0
    while elapsed < timeout do
        if not autoMode then return false end
        if raidCaveExists() then
            return true
        end
        task.wait(1)
        elapsed += 1
    end
    return false
end

local function closeWatch()
    pressKey(Enum.KeyCode.Three)
    task.wait(0.4)
end

local function navigateToRaidViaWeather()
    if not autoMode then return false end

    setRaidStatus("Opening watch...")
    local opened, err = openWatch()
    if not opened then
        setRaidStatus("Failed - " .. tostring(err))
        return false
    end

    local watchContainer = player.PlayerGui.MainGui.WatchContainer
    local mapMenu = watchContainer:FindFirstChild("MapMenu")
    if not mapMenu then
        setRaidStatus("Failed - MapMenu missing")
        return false
    end

    local tabs = getTabButtons(mapMenu)
    if #tabs < 3 then
        setRaidStatus("Failed - map tabs missing")
        return false
    end

    setRaidStatus("Reading weather...")
    clickTab(tabs[3])
    task.wait(0.6)

    local weather = getCurrentWeatherLocation(mapMenu)
    if not weather then
        setRaidStatus("Failed - could not read weather")
        closeWatch()
        return false
    end

    print("[Raid Nav] Detected location:", weather)

    local locationData = equivalency[weather]
    if not locationData then
        setRaidStatus("Unknown location: " .. weather)
        closeWatch()
        return false
    end

    setRaidStatus("Teleporting to " .. locationData.location)
    clickTab(tabs[1])
    task.wait(0.6)

    local locationsScrollingFrame = getMapLocationList(mapMenu)
    if not locationsScrollingFrame then
        setRaidStatus("Failed - location list missing")
        closeWatch()
        return false
    end

    if not clickGeoHopWithRetry(locationData.location, locationsScrollingFrame, 3) then
        setRaidStatus("Failed - geo-hop")
        closeWatch()
        return false
    end

    local gateReached = nil
    if locationData.gate then
        setRaidStatus("Moving to gate: " .. locationData.gate)
        if teleportToGate(locationData.gate) then
            gateReached = locationData.gate
        else
            setRaidStatus("Gate not found: " .. locationData.gate)
            closeWatch()
            return false
        end
    end

    closeWatch()

    if not activateMount("Route complete") then
        setRaidStatus("Mount failed after route (continuing to raid cave...)")
    end

    notifyDiscordGeoHop(locationData.location, gateReached)

    setRaidStatus("Waiting for raid cave...")
    if waitForRaidCave(8) then
        setRaidStatus("Cave found - collecting")
        return true
    end

    setRaidStatus("Raid cave not found, retrying...")
    return false
end

local function startRaidNavigation()
    if raidNavRunning or not autoMode then return end
    raidNavRunning = true
    lastRaidNavAttempt = tick()

    task.spawn(function()
        setRaidStatus("Starting weather nav...")

        local ok, err = pcall(function()
            local success = navigateToRaidViaWeather()
            if not success and autoMode and not raidCaveExists() then
                task.wait(2)
                setRaidStatus("Retrying weather nav...")
                navigateToRaidViaWeather()
            end
        end)

        if not ok then
            setRaidStatus("Error: " .. tostring(err))
            warn("[Raid Nav]", err)
            task.wait(3)
        elseif raidCaveExists() then
            setRaidStatus("Cave found - collecting")
        else
            setRaidStatus("Nav done - scanning")
        end

        raidNavRunning = false
    end)
end

-- =============================================================================
-- SYSTEM GUI SETUP
-- Named refs: _G.LoomianAuto.GuiRefs  |  Dev offset panel: hidden, press O
-- =============================================================================
local GuiRefs = {}
_G.LoomianAuto.GuiRefs = GuiRefs

local gui = Instance.new("ScreenGui")
gui.Name = "LoomianAuto"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
GuiRefs.ScreenGui = gui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 280, 0, 268)
mainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Parent = gui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(45, 45, 55)
GuiRefs.MainFrame = mainFrame

local header = Instance.new("TextLabel", mainFrame)
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 32)
header.Text = "LOOMIAN AUTO  " .. SCRIPT_VERSION
header.TextColor3 = Color3.fromRGB(200, 200, 210)
header.Font = Enum.Font.GothamBold
header.TextSize = 11
header.BackgroundTransparency = 0.92
header.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
GuiRefs.Header = header

local content = Instance.new("Frame", mainFrame)
content.Name = "Content"
content.Size = UDim2.new(1, -24, 0, 136)
content.Position = UDim2.new(0, 12, 0, 38)
content.BackgroundTransparency = 1
GuiRefs.Content = content

local contentLayout = Instance.new("UIListLayout", content)
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 3)

local function createStatLabel(name, text, color)
    local lbl = Instance.new("TextLabel", content)
    lbl.Name = name
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(160, 160, 170)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    GuiRefs[name] = lbl
    return lbl
end

statusLabel = createStatLabel("StatusLabel", "STATUS: IDLE (PRESS R)", Color3.new(1, 1, 1))
raidLabel = createStatLabel("RaidLabel", "RAID: SCANNING...", Color3.fromRGB(120, 180, 255))
local timeLabel = createStatLabel("RuntimeLabel", "RUNTIME: 00:00:00")
enemyLabel = createStatLabel("TargetLabel", "TARGET: WAITING...")
typeLabel = createStatLabel("VariantLabel", "VARIANT: NORMAL")
local boxCounterLabel = createStatLabel("EggsCollectedLabel", "EGGS COLLECTED: 0", Color3.fromRGB(0, 200, 255))
local battleCounterLabel = createStatLabel("BattlesEscapedLabel", "BATTLES ESCAPED: " .. battleCount, Color3.fromRGB(255, 100, 0))

local eggSectionHeader = Instance.new("TextLabel", mainFrame)
eggSectionHeader.Name = "EggSectionHeader"
eggSectionHeader.Size = UDim2.new(1, -24, 0, 16)
eggSectionHeader.Position = UDim2.new(0, 12, 0, 178)
eggSectionHeader.BackgroundTransparency = 1
eggSectionHeader.Text = "FARM STATUS"
eggSectionHeader.TextColor3 = Color3.fromRGB(120, 120, 130)
eggSectionHeader.Font = Enum.Font.GothamBold
eggSectionHeader.TextSize = 9
eggSectionHeader.TextXAlignment = Enum.TextXAlignment.Left
GuiRefs.EggSectionHeader = eggSectionHeader

-- Dev-only offset panel (hidden; press O to toggle)
offsetPanel = Instance.new("Frame")
offsetPanel.Name = "OffsetPanel"
offsetPanel.Size = UDim2.new(0, 260, 0, 144)
offsetPanel.Position = UDim2.new(0.05, 0, 0.1, 290)
offsetPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
offsetPanel.BackgroundTransparency = 0.05
offsetPanel.BorderSizePixel = 0
offsetPanel.Visible = SHOW_DEV_OFFSET_PANEL
offsetPanel.Parent = gui
Instance.new("UICorner", offsetPanel).CornerRadius = UDim.new(0, 6)
GuiRefs.OffsetPanel = offsetPanel

local offsetTitle = Instance.new("TextLabel", offsetPanel)
offsetTitle.Size = UDim2.new(1, -10, 0, 18)
offsetTitle.Position = UDim2.new(0, 5, 0, 4)
offsetTitle.BackgroundTransparency = 1
offsetTitle.Text = "DEV · CLICK OFFSETS [O]"
offsetTitle.Font = Enum.Font.GothamBold
offsetTitle.TextSize = 9
offsetTitle.TextColor3 = Color3.fromRGB(255, 200, 80)
offsetTitle.TextXAlignment = Enum.TextXAlignment.Left

local function createOffsetRow(yPos, name, key, step, isToggle)
    local row = Instance.new("Frame", offsetPanel)
    row.Size = UDim2.new(1, -10, 0, 18)
    row.Position = UDim2.new(0, 5, 0, yPos)
    row.BackgroundTransparency = 1

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(0, 52, 1, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = name
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 9
    nameLbl.TextColor3 = Color3.fromRGB(160, 160, 170)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    if isToggle then
        local toggleBtn = Instance.new("TextButton", row)
        toggleBtn.Size = UDim2.new(0, 36, 0, 16)
        toggleBtn.Position = UDim2.new(0, 56, 0, 1)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 9
        toggleBtn.Text = "ON"
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)
        offsetDisplayLabels[key] = toggleBtn
        toggleBtn.MouseButton1Click:Connect(function()
            clickOffsets.showHighlights = not clickOffsets.showHighlights
            updateOffsetDisplays()
        end)
        return
    end

    local minusBtn = Instance.new("TextButton", row)
    minusBtn.Size = UDim2.new(0, 18, 0, 16)
    minusBtn.Position = UDim2.new(0, 56, 0, 1)
    minusBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 40)
    minusBtn.Text = "-"
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.TextSize = 11
    minusBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 3)

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(0, 36, 0, 16)
    valLbl.Position = UDim2.new(0, 76, 0, 1)
    valLbl.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 9
    valLbl.TextColor3 = Color3.fromRGB(100, 220, 255)
    valLbl.Text = "0.00"
    Instance.new("UICorner", valLbl).CornerRadius = UDim.new(0, 3)
    offsetDisplayLabels[key] = valLbl

    local plusBtn = Instance.new("TextButton", row)
    plusBtn.Size = UDim2.new(0, 18, 0, 16)
    plusBtn.Position = UDim2.new(0, 114, 0, 1)
    plusBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 40)
    plusBtn.Text = "+"
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.TextSize = 11
    plusBtn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 3)

    local function adjust(delta)
        if key == "tabX" then
            clickOffsets.tabX = math.clamp(clickOffsets.tabX + delta, 0, MAX_CLICK_OFFSET)
        elseif key == "tabY" then
            clickOffsets.tabY = math.clamp(clickOffsets.tabY + delta, 0, MAX_CLICK_OFFSET)
        elseif key == "geoHopX" then
            clickOffsets.geoHopX = math.clamp(clickOffsets.geoHopX + delta, -200, 200)
        elseif key == "geoHopY" then
            clickOffsets.geoHopY = math.clamp(clickOffsets.geoHopY + delta, -200, 200)
        elseif key == "runX" then
            clickOffsets.runX = math.clamp(clickOffsets.runX + delta, -200, 200)
        elseif key == "runY" then
            clickOffsets.runY = math.clamp(clickOffsets.runY + delta, -200, 200)
        end
        updateOffsetDisplays()
    end

    minusBtn.MouseButton1Click:Connect(function() adjust(-step) end)
    plusBtn.MouseButton1Click:Connect(function() adjust(step) end)
end

createOffsetRow(22, "Tab X", "tabX", 0.05)
createOffsetRow(40, "Tab Y", "tabY", 0.05)
createOffsetRow(58, "Geo X px", "geoHopX", 1)
createOffsetRow(76, "Geo Y px", "geoHopY", 1)
createOffsetRow(94, "Run X px", "runX", 1)
createOffsetRow(112, "Run Y px", "runY", 1)
createOffsetRow(130, "Highlight", "highlightToggle", 0, true)

local resetOffsetBtn = Instance.new("TextButton", offsetPanel)
resetOffsetBtn.Size = UDim2.new(0, 50, 0, 16)
resetOffsetBtn.Position = UDim2.new(1, -55, 0, 4)
resetOffsetBtn.BackgroundColor3 = Color3.fromRGB(55, 45, 35)
resetOffsetBtn.Text = "Reset"
resetOffsetBtn.Font = Enum.Font.GothamBold
resetOffsetBtn.TextSize = 8
resetOffsetBtn.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", resetOffsetBtn).CornerRadius = UDim.new(0, 4)
resetOffsetBtn.MouseButton1Click:Connect(resetClickOffsets)

updateOffsetDisplays()

local ObjectList = Instance.new("ScrollingFrame", mainFrame)
ObjectList.Name = "ObjectList"
ObjectList.Size = UDim2.new(1, -24, 0, 32)
ObjectList.Position = UDim2.new(0, 12, 0, 196)
ObjectList.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
ObjectList.BackgroundTransparency = 0.2
ObjectList.BorderSizePixel = 0
ObjectList.CanvasSize = UDim2.new(0, 0, 0, 0)
ObjectList.ScrollBarThickness = 3
GuiRefs.ObjectList = ObjectList
Instance.new("UICorner", ObjectList).CornerRadius = UDim.new(0, 6)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.Parent = ObjectList

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ObjectList.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end)

local footer = Instance.new("TextLabel", mainFrame)
footer.Name = "Footer"
footer.Size = UDim2.new(1, -24, 0, 16)
footer.Position = UDim2.new(0, 12, 1, -20)
footer.BackgroundTransparency = 1
footer.Text = "R · Start/Stop    Insert · Hide UI"
footer.TextColor3 = Color3.fromRGB(90, 90, 100)
footer.Font = Enum.Font.Gotham
footer.TextSize = 9
footer.TextXAlignment = Enum.TextXAlignment.Center
GuiRefs.Footer = footer

local testKickBtn = Instance.new("TextButton")
testKickBtn.Name = "TestKickButton"
testKickBtn.Size = UDim2.new(0, 260, 0, 28)
testKickBtn.Position = UDim2.new(0.05, 0, 0.1, 440)
testKickBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
testKickBtn.Text = "TEST ESCAPE (DEV)"
testKickBtn.TextColor3 = Color3.new(1, 1, 1)
testKickBtn.Font = Enum.Font.GothamBold
testKickBtn.TextSize = 10
testKickBtn.Visible = SHOW_DEV_TEST_BUTTON
testKickBtn.Parent = gui
Instance.new("UICorner", testKickBtn).CornerRadius = UDim.new(0, 6)
GuiRefs.TestKickButton = testKickBtn

local function hasEncounterRaidEggsNearby()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if isCollectableWorldEgg(v) and not isChunkEgg(v) then
            if eggEncounterOnly() then
                if isEncounterEggPart(v) then
                    return true
                end
            else
                return true
            end
        end
    end
    return false
end

local function collectRaidEggs()
    local encounterEggs = {}
    local otherEggs = {}

    for _, v in ipairs(Workspace:GetDescendants()) do
        if not isCollectableWorldEgg(v) then
            continue
        end
        if isEncounterEggPart(v) then
            table.insert(encounterEggs, v)
        else
            table.insert(otherEggs, v)
        end
    end

    if #encounterEggs == 0 then
        setRaidStatus(eggEncounterOnly() and "No encounter eggs — waiting..." or "Collecting other raid eggs...")
        if eggEncounterOnly() then
            return false
        end
    end

    local collectingEncounters = #encounterEggs > 0
    local batch
    if collectingEncounters then
        batch = sortEggsByEncounterPriority(encounterEggs)
        setRaidStatus("Collecting encounter raid eggs...")
    elseif not eggEncounterOnly() then
        batch = sortEggsByEncounterPriority(otherEggs)
        setRaidStatus("Collecting other raid eggs...")
    else
        return false
    end

    for _, egg in ipairs(batch) do
        if not autoMode or isEncounterStarting() then break end
        invisibleTeleportTo(egg.CFrame + Vector3.new(0, 2, 0))
        task.wait(0.8)
        if eggEncounterOnly() then
            if getBattleGui() then
                break
            end
        elseif not egg:IsDescendantOf(Workspace) then
            boxCount += 1
            boxCounterLabel.Text = "EGGS COLLECTED: " .. boxCount
        end
    end

    return #batch > 0
end

-- =============================================================================
-- FIXED UI DRAGGING SYSTEM
-- =============================================================================
local dragging = false
local dragStart = nil
local startPos = nil

mainFrame.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = i.Position
        startPos = mainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- =============================================================================
-- RE-ENGINEERED UNCONDITIONAL KEYBIND SYSTEM
-- =============================================================================
UserInputService.InputBegan:Connect(function(input, _)
    if input.KeyCode == Enum.KeyCode.R then
        autoMode = not autoMode

        if autoMode then
            statusLabel.Text = "STATUS: INITIALIZING..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            scheduleSafetyLogoff()
            if MOUNT_ON_MACRO_START then
                task.spawn(function()
                    if not autoMode then return end
                    if isMountActive() then
                        setRaidStatus("Mount already active")
                        statusLabel.Text = "STATUS: RUNNING"
                    else
                        macroStartMounting = true
                        statusLabel.Text = "STATUS: ACTIVATING MOUNT (Q)..."
                        local ok, err = pcall(function()
                            activateMount("Macro start", { delay = MOUNT_START_DELAY })
                        end)
                        macroStartMounting = false
                        if not ok then
                            warn("[Mount]", err)
                        end
                        if autoMode then
                            statusLabel.Text = isMountActive() and "STATUS: RUNNING" or "STATUS: RUNNING (MOUNT FAILED)"
                        end
                    end
                end)
            end
        else
            macroStartMounting = false
            statusLabel.Text = "STATUS: OFF"
            statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            clearSafetyLogoff()
        end
    end

    if input.KeyCode == Enum.KeyCode.Insert then
        mainFrame.Visible = not mainFrame.Visible
    end

    if input.KeyCode == Enum.KeyCode.O and offsetPanel then
        offsetPanel.Visible = not offsetPanel.Visible
    end
end)

-- BattleGui watcher
task.spawn(function()
    local wasInBattle = false
    local battleClearDeadline = 0
    while true do
        local inBattle = isBattleSceneActive()
        if inBattle then
            encounterFiring = true
            battleClearDeadline = 0
            if not wasInBattle then
                handleBattleFlee()
            end
            wasInBattle = true
        elseif wasInBattle then
            if battleClearDeadline == 0 then
                battleClearDeadline = tick() + BATTLE_END_DEBOUNCE
            elseif tick() >= battleClearDeadline then
                encounterFiring = false
                wasInBattle = false
                battleClearDeadline = 0
            end
        end
        task.wait(0.25)
    end
end)

-- =============================================================================
-- EGG SUMMARY (collectable count only — Camera.Egg is rain anim, not farmed)
-- =============================================================================
local function createEggSummaryLabel(collectableCount)
    local label = Instance.new("TextLabel")
    label.Name = "EggSummary"
    label.Size = UDim2.new(1, 0, 0, 28)
    label.Text = "Collectable eggs: " .. tostring(collectableCount)
    label.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    label.TextColor3 = Color3.fromRGB(180, 230, 180)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BorderSizePixel = 0
    label.Parent = ObjectList
    Instance.new("UICorner", label).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new("UIPadding", label)
    pad.PaddingLeft = UDim.new(0, 8)
end

local function countCollectableTargets(descendants, inRaid, linkedTokens)
    local worldCount = 0
    for i = 1, #descendants do
        local obj = descendants[i]
        if isCollectableForMode(obj, inRaid) then
            worldCount += 1
            local cached = getCachedTokenForEgg(obj)
            if cached then
                linkedTokens[cached.token] = true
            end
        end
    end
    local tokenCount = #getUnlinkedCollectibleTokens(linkedTokens)
    return worldCount + tokenCount, worldCount, tokenCount
end

-- =============================================================================
-- MAIN INTEGRATED AUTOMATION LOOP
-- =============================================================================
task.spawn(function()
    player.PlayerGui:WaitForChild("MainGui", 120)
    task.wait(2)

    while true do
        task.wait(eggEncounterOnly() and 0.35 or 0.15)

        for _, child in ipairs(ObjectList:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local target = nil
        local tokenTarget = nil
        local targetIsEncounter = false
        local listedTokens = {}
        local inRaid = raidCaveExists()
        local descendants = Workspace:GetDescendants()

        local collectableCount = countCollectableTargets(descendants, inRaid, listedTokens)
        createEggSummaryLabel(collectableCount)

        local encounterEggs, normalChunkEggs = splitWorldEggsForCollection(descendants, inRaid)

        local tokenOnlyTargets = getUnlinkedCollectibleTokens(listedTokens)
        local encounterTokenTarget = eggEncounterOnly() and getNearestCollectibleEncounterToken(listedTokens) or nil
        if eggEncounterOnly() then
            target = nil
            tokenTarget = encounterTokenTarget
            targetIsEncounter = tokenTarget ~= nil
        elseif #encounterEggs > 0 then
            target = pickNearestEgg(encounterEggs)
            targetIsEncounter = true
        elseif #tokenOnlyTargets > 0 then
            tokenTarget = tokenOnlyTargets[1]
            targetIsEncounter = isEncounterEggType(tokenTarget.eggType)
        elseif #normalChunkEggs > 0 then
            target = pickNearestEgg(normalChunkEggs)
        end

        if inRaid then
            raidLabel.Text = "RAID: ACTIVE - COLLECTING"
            raidLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
        elseif not raidNavRunning then
            raidLabel.Text = "RAID: NONE - READY"
            raidLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
        end

        if not autoMode then
            if statusLabel.Text ~= "STATUS: OFF" then
                statusLabel.Text = "STATUS: OFF"
                statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            end
            if lastBattleState or encounterFiring then
                resetBattleTracking()
            end
            continue
        end

        if SAFETY_LOGOFF_ENABLED and safetyLogoffAt and tick() >= safetyLogoffAt then
            triggerSafetyLogoff()
            break
        end

        if macroStartMounting then
            statusLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
            statusLabel.Text = "STATUS: ACTIVATING MOUNT (Q)..."
            continue
        end

        if isBattleSceneActive() then
            encounterFiring = true
            battleEndDebounceUntil = 0
            local bGui = getBattleGui()
            local bGuiVisible = bGui and bGui.Visible

            statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            statusLabel.Text = bGuiVisible and "STATUS: VERIFYING ENCOUNTER..." or "STATUS: IN BATTLE — RETRYING RUN..."

            if bGuiVisible then
                local deadline = tick() + 3
                while not isEncounterDataFresh() and tick() < deadline do
                    task.wait(0.05)
                end

                local encounterReady = isEncounterDataFresh()
                if encounterReady then
                    enemyLabel.Text = "TARGET: " .. loomianData.enemy:upper()
                    typeLabel.Text = "VARIANT: " .. loomianData.enemyType:upper()
                else
                    enemyLabel.Text = "TARGET: UNKNOWN"
                    typeLabel.Text = "VARIANT: UNKNOWN"
                end

                if encounterReady and isRareVariant(loomianData.enemyType) and not isVariantBlacklisted(loomianData.enemyType) then
                    notifyDiscordRareStop(loomianData.enemy, loomianData.enemyType)
                    triggerEscapeSequence(string.format(
                        "--- RARE DETECTED ---\nLoomian: %s\nVariant: %s\n\nRuntime: %s\nBoxes: %d",
                        loomianData.enemy,
                        loomianData.enemyType,
                        formatTime(tick() - startTime),
                        boxCount
                    ))
                    autoMode = false
                    statusLabel.Text = "STATUS: OFF (RARE FOUND)"
                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
                    break
                end

                if encounterReady and isVariantBlacklisted(loomianData.enemyType) then
                    statusLabel.Text = "STATUS: FLEEING " .. loomianData.enemyType:upper() .. " (BLACKLIST)"
                end

                if encounterReady and not discordBattleFleeSent then
                    notifyDiscordFlee(
                        loomianData.enemy,
                        loomianData.enemyType,
                        isVariantBlacklisted(loomianData.enemyType)
                    )
                    discordBattleFleeSent = true
                end
            end

            if not lastBattleState then
                battleCount += 1
                battleCounterLabel.Text = "BATTLES ESCAPED: " .. battleCount
                lastBattleState = true
                invisibleTeleportTo(CFrame.new(0, 10000, 0))
            end

            tryFleeBattle()
            continue
        end

        if lastBattleState or encounterFiring then
            if not isBattleConfirmedEnded() then
                statusLabel.Text = "STATUS: LEAVING BATTLE..."
                tryFleeBattle()
                continue
            end
            resetBattleTracking()
        end

        -- RAID CAVE MODE: invisible teleport egg farming
        if inRaid and not raidNavRunning then
            if eggEncounterOnly() then
                statusLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
                statusLabel.Text = "STATUS: ENCOUNTER-ONLY — waiting for egg rain tokens"
                task.wait(0.5)
                continue
            end
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            statusLabel.Text = "STATUS: RAID EGG COLLECT"

            local ok, err = pcall(function()
                if not collectRaidEggs() then
                    statusLabel.Text = "STATUS: RAID - NO EGGS FOUND"
                end
            end)
            if not ok then
                statusLabel.Text = "STATUS: ERROR - " .. tostring(err)
                warn("[Raid Bot]", err)
                task.wait(3)
            end
            continue
        end

        -- Also collect raid-area eggs even if RaidCaveModel hasn't loaded yet
        local raidEggsNearby = eggEncounterOnly() and hasEncounterRaidEggsNearby()
            or (function()
                for _, v in ipairs(Workspace:GetDescendants()) do
                    if isCollectableWorldEgg(v) and not isChunkEgg(v) then
                        return true
                    end
                end
                return false
            end)()

        if raidEggsNearby and not raidNavRunning then
            if eggEncounterOnly() then
                statusLabel.TextColor3 = Color3.fromRGB(180, 220, 255)
                statusLabel.Text = "STATUS: ENCOUNTER-ONLY — skipping raid egg pickup"
                task.wait(0.5)
                continue
            end
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            statusLabel.Text = "STATUS: RAID EGG COLLECT"
            setRaidStatus("EGGS FOUND - COLLECTING")
            collectRaidEggs()
            continue
        end

        -- No raid cave: kick off weather navigation (runs all steps async)
        if not raidNavRunning and tick() - lastRaidNavAttempt >= RAID_NAV_COOLDOWN then
            startRaidNavigation()
            continue
        end

        if raidNavRunning then
            continue
        end

        -- CHUNK EGG MODE
        if eggEncounterOnly() and tokenTarget then
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 160)
            statusLabel.Text = "STATUS: BOT TOKEN COLLECT (encounter-only)"
            performEncounterTokenCollect(tokenTarget)
        elseif eggEncounterOnly() then
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            statusLabel.Text = eggSweep.lastAuth
                and "STATUS: WAITING FOR ENCOUNTER EGG RAIN..."
                or "STATUS: NEED PDS AUTH — move around briefly"
            task.wait(0.35)
        elseif target then
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            statusLabel.Text = targetIsEncounter and "STATUS: COLLECTING ENCOUNTER EGG" or "STATUS: COLLECTING EGG"
            performEggCollectionAt(target.CFrame + Vector3.new(0, 5, 0), target)
        elseif tokenTarget then
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 160)
            statusLabel.Text = "STATUS: COLLECTING ENCOUNTER (TOKEN POS)"
            local pos = normalizeEggPos(tokenTarget.pos)
            if pos then
                performEggCollectionAt(CFrame.new(pos + Vector3.new(0, 5, 0)), nil)
            end
        else
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            statusLabel.Text = "STATUS: SCANNING FOR EGGS..."
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        timeLabel.Text = "RUNTIME: " .. formatTime(tick() - startTime)
    end
end)

testKickBtn.MouseButton1Click:Connect(function()
    triggerEscapeSequence(string.format(
        "--- TEST ESCAPE ---\nRuntime: %s\nBoxes: %d",
        formatTime(tick() - startTime),
        boxCount
    ))
end)
