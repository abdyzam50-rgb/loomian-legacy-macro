-- objectives.lua
-- Reactive story-progression driver.
-- Hooks every TextLabel inside BackGui; when the game's objective text
-- changes to match a known entry in ObjectiveConfig, it auto-teleports
-- through the configured waypoint sequence.
-- Level data is sourced from _G.StarterLevel, written by battle.lua's EVT hooks.

local Objectives = {}

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- Objective config
-- Each entry:
--   match    — case-insensitive substring of the objective TextLabel text
--   minLevel — (optional) skip and toggle auto-hunt if level is below this
--   sequence — ordered list of waypoints; each waypoint:
--     { type = "workspaceName", name = "PartName" }
--     { type = "idValue",       id = "SomeId", childName = "Main" }
--     { type = "path",          path = {"Folder","Sub","Part"} }
--     { type = "gateMarquee",   text = "DestinationName" }
--     Any waypoint can also carry: delay = N  (seconds before next waypoint)
-- ─────────────────────────────────────────────────────────────────────────────

local ObjectiveConfig = {
    {
        match = "at the Dig Site",
        sequence = {
            { type = "workspaceName", name = "TriggerCaveCutscene" },
        },
    },
    {
        match = "at the Laboratory",
        sequence = {
            { type = "idValue", id = "Laboratory", childName = "Main" },
        },
    },
    {
        match = "Gale Forest",
        sequence = {
            { type = "workspaceName", name = "Exit" },
            { type = "gateMarquee",   text = "Cheshma Town" },
            { type = "workspaceName", name = "SchoolSceneTrigger" },
        },
    },
    {
        match = "behind Duskit",
        minLevel = 13,
        sequence = {
            { type = "workspaceName", name = "DuskitCutsceneTrigger" },
        },
    },
    {
        match = "Silvent City Battle",
        minLevel = 13,
        sequence = {
            { type = "gateMarquee", text = "Route 3" },
        },
    },
}

local DEFAULT_WAYPOINT_DELAY = 5

-- Level is tracked by battle.lua via EVT packet hooks and written to _G.StarterLevel.
local function currentLevel()
    return _G.StarterLevel or 5
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function containsSubstring(haystack, needle)
    if not haystack or not needle then return false end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

local function getCFrameFromInstance(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.CFrame
    elseif inst:IsA("Model") then return inst:GetPivot() end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Waypoint resolvers
-- ─────────────────────────────────────────────────────────────────────────────

local Resolvers = {}

Resolvers.workspaceName = function(wp)
    local inst = Workspace:FindFirstChild(wp.name, true)
    if not inst then warn("[Objectives] workspaceName: not found:", wp.name) return nil end
    return getCFrameFromInstance(inst)
end

Resolvers.idValue = function(wp)
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("StringValue") and desc.Name == "id" and containsSubstring(desc.Value, wp.id) then
            local target = desc.Parent and desc.Parent:FindFirstChild(wp.childName)
            if target then return getCFrameFromInstance(target) end
            warn("[Objectives] idValue: id found but no child:", wp.childName)
            return nil
        end
    end
    warn("[Objectives] idValue: no StringValue 'id' containing:", wp.id)
    return nil
end

Resolvers.gateMarquee = function(wp)
    for _, marquee in ipairs(Workspace:GetDescendants()) do
        if marquee.Name == "Marquee" then
            local mText = marquee:FindFirstChild("MText")
            if mText and mText:IsA("StringValue") and containsSubstring(mText.Value, wp.text) then
                if not marquee:IsA("BasePart") then
                    warn("[Objectives] gateMarquee: Marquee is not a BasePart:", marquee:GetFullName())
                    return nil
                end
                return CFrame.new(marquee.Position - Vector3.new(0, 10, 0))
            end
        end
    end
    warn("[Objectives] gateMarquee: no Marquee with MText containing:", wp.text)
    return nil
end

local function resolveWaypoint(wp)
    local resolver = Resolvers[wp.type]
    if not resolver then warn("[Objectives] No resolver for type:", wp.type) return nil end
    return resolver(wp)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Teleport
-- ─────────────────────────────────────────────────────────────────────────────

local function teleportToCFrame(cf, label)
    if not cf then warn("[Objectives] nil CFrame for:", label) return false end
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")
    hrp.CFrame = cf + Vector3.new(0, 3, 0)
    print("[Objectives] Teleported to:", label)
    return true
end

local function runSequence(sequence, matchText)
    print("[Objectives] Running sequence for:", matchText, "(" .. #sequence .. " waypoint(s))")
    for i, wp in ipairs(sequence) do
        local label = matchText .. " [" .. i .. "/" .. #sequence .. "]"
        local ok = teleportToCFrame(resolveWaypoint(wp), label)
        if not ok then
            warn("[Objectives] Sequence aborted at waypoint", i)
            return
        end
        if i < #sequence then
            task.wait(wp.delay or DEFAULT_WAYPOINT_DELAY)
        end
    end
    print("[Objectives] Sequence complete:", matchText)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- BackGui TextLabel watcher
-- ─────────────────────────────────────────────────────────────────────────────

local lastTriggeredMatch = nil
local autoHunting        = false   -- tracks whether Auto Hunt is currently active

-- Toggles the Auto Hunt button in the game's UI (jackFunction pattern from source).
local function toggleAutoHunt()
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "Toggle" and (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
            local cur = desc.Parent
            while cur do
                if cur.Name == "Auto Hunt" then
                    if firesignal then
                        pcall(function() firesignal(desc.Activated) end)
                        pcall(function() firesignal(desc.MouseButton1Click) end)
                    elseif getconnections then
                        for _, c in ipairs(getconnections(desc.Activated))        do pcall(function() c:Fire() end) end
                        for _, c in ipairs(getconnections(desc.MouseButton1Click)) do pcall(function() c:Fire() end) end
                    end
                    autoHunting = not autoHunting
                    print("[Objectives] Auto Hunt toggled →", autoHunting)
                    return
                end
                cur = cur.Parent
            end
        end
    end
end

local function checkText(text)
    for _, objective in ipairs(ObjectiveConfig) do
        if containsSubstring(text, objective.match) then
            -- Level guard: if too low, enable auto-hunt and skip teleport
            if objective.minLevel and currentLevel() < objective.minLevel then
                print("[Objectives] Level too low (" .. currentLevel() .. " < " .. objective.minLevel .. ") for:", objective.match)
                if not autoHunting then toggleAutoHunt() end
                return
            end
            -- If we were auto-hunting and now level is sufficient, stop it
            if autoHunting then toggleAutoHunt() end

            if lastTriggeredMatch == objective.match then return end
            lastTriggeredMatch = objective.match
            print("[Objectives] Matched:", objective.match)
            task.spawn(runSequence, objective.sequence, objective.match)
            return
        end
    end
end

local function hookLabel(label)
    checkText(label.Text)
    label:GetPropertyChangedSignal("Text"):Connect(function()
        checkText(label.Text)
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running = false

function Objectives.start()
    if running then return end
    running = true

    local backGui = playerGui:WaitForChild("BackGui", 30)
    if not backGui then
        warn("[Objectives] BackGui not found — objective watcher not started.")
        return
    end

    local count = 0
    for _, obj in ipairs(backGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            hookLabel(obj)
            count += 1
        end
    end
    print("[Objectives] Hooked " .. count .. " TextLabel(s) in BackGui.")

    backGui.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") then hookLabel(obj) end
    end)
end

function Objectives.stop()
    running = false
    print("[Objectives] Stopped.")
end

-- Add or overwrite an objective entry at runtime.
function Objectives.addObjective(config)
    table.insert(ObjectiveConfig, config)
    print("[Objectives] Added objective:", config.match)
end

-- Reset the debounce so the same objective can retrigger.
function Objectives.resetMatch()
    lastTriggeredMatch = nil
end

function Objectives.getLevel()
    return currentLevel()
end

return Objectives
