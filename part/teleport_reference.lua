local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local backGui = playerGui:WaitForChild("BackGui")
local GuiService = game:GetService("GuiService")
local DEBUG = true
local function dprint(...)
    if DEBUG then print("[TPDebug]", ...) end
end

local VIM = game:GetService("VirtualInputManager")

local mainGui = playerGui:WaitForChild("MainGui")
-- ============================================================
-- HELPER: case-insensitive substring check
-- Used everywhere instead of `==` so casing differences in
-- label text / MText / id values don't break matching.
-- The `true` arg to :find() forces a PLAIN search (no Lua
-- pattern special chars like %, -, ( ) being interpreted).
-- ============================================================
local function containsSubstring(haystack, needle)
    if not haystack or not needle then return false end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

function click(button, xOffset, yOffset)
        if button and button.Visible then
            local absPos = button.AbsolutePosition
            local absSize = button.AbsoluteSize

            local x = math.floor(absPos.X + absSize.X * xOffset + 0.5)
            local y = math.floor(absPos.Y + absSize.Y * yOffset + 0.5)

            print("Clicking at:", x, y)

            -- Mouse down
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.05)
            -- Mouse up
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end
    end

function findButton(container, options)
    for _, obj in ipairs(container:GetDescendants()) do
        if not options.className or obj.ClassName == options.className or obj.Name == options.className then
            local isMatch = true

            if options.text then
                local textMatch = false
                for _, child in ipairs(obj:GetChildren()) do
                    if (child:IsA("TextLabel") or child:IsA("TextButton")) and string.find(child.Text, options.text) then
                        textMatch = true
                        break
                    end
                end
                isMatch = isMatch and textMatch
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
                isMatch = isMatch and obj:FindFirstChild(options.childName) ~= nil
            end

            if isMatch then
                return obj
            end
        end
    end

    return nil
end

local autoHunting = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getButton(name, papa)
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == name and (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
            local current = desc.Parent
            while current do
                if current.Name == papa then return desc end
                current = current.Parent
            end
        end
    end
    return nil
end

local function jackFunction(name, papa) 
    local button = getButton(name, papa)
    if button then
        if firesignal then
            firesignal(button.Activated)
            firesignal(button.MouseButton1Click)
            print("Bypassed visibility constraints via firesignal.")
        elseif getconnections then
            for _, connection in ipairs(getconnections(button.Activated)) do connection:Fire() end
            for _, connection in ipairs(getconnections(button.MouseButton1Click)) do connection:Fire() end
            print("Bypassed visibility constraints via getconnections.")
        else
            warn("Executor does not support direct connection firing.")
        end
    end

end

local function pressKey(keyCode)
    VIM:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, keyCode, false, game)
    task.wait(0.3)
end

local function selectClick(button)
	GuiService.SelectedObject = button
	wait(0.1)
	pressKey(Enum.KeyCode.Return)
end

-- ============================================================
-- OBJECTIVE CONFIG
-- Each entry: { match = "<substring>", sequence = { ...waypoints } }
-- Waypoint resolver types:
--   { type = "workspaceName", name = "PartOrModelName" }
--   { type = "idValue", id = "SomeId", childName = "Main" }
--   { type = "path", path = {"Folder", "SubFolder", "PartName"} }
--   { type = "gateMarquee", text = "DestinationName" } -- always resolves Gate.Door.Main
-- ============================================================
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
            { type = "gateMarquee", text = "Cheshma Town" },
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
    -- example of a multi-part sequence (teleports through each waypoint in order)
    -- {
    --     match = "at the Volcano",
    --     sequence = {
    --         { type = "workspaceName", name = "VolcanoEntrance" },
    --         { type = "workspaceName", name = "VolcanoInner" },
    --     },
    -- },
}

--------------------------------------------------
-- SERVICES
--------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Define global state baseline
_G.StarterLevel = 5 

--------------------------------------------------
-- LEVEL TRACKER FUNCTION
--------------------------------------------------
local function parseLevelFromTable(tbl, targetName)
    if type(tbl) ~= "table" then return end
    targetName = targetName or "Eaglit"

    for _, val in pairs(tbl) do
        if type(val) == "string" then
            -- Scan the raw string text directly for "switch" and your Loomian's name
            if string.find(val, '"switch"') and string.find(val, targetName) then
                -- Extract the digits following the 'L' directly out of the text row
                local levelMatch = string.match(val, "L(%d+)")
                if levelMatch then
                    _G.StarterLevel = tonumber(levelMatch)
                    print("[SYSTEM LOG] Live Level Extracted:", _G.StarterLevel)
                    return true
                end
            end
        elseif type(val) == "table" then
            -- Deep scan if the strings are wrapped inside another layer
            if parseLevelFromTable(val, targetName) then
                return true
            end
        end
    end
end

--------------------------------------------------
-- REMOTE HOOKING
--------------------------------------------------
local hooked = {}
local function hook(remote)
    if not remote:IsA("RemoteEvent") or hooked[remote] then return end
    hooked[remote] = true

    remote.OnClientEvent:Connect(function(...)
        for _, arg in ipairs({...}) do
            if type(arg) == "table" then
                parseLevelFromTable(arg, "Eaglit")
            end
        end
    end)
end

for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    hook(obj)
end

ReplicatedStorage.DescendantAdded:Connect(hook)

-- ============================================================
-- WAYPOINT RESOLVERS
-- ============================================================
local function getCFrameFromInstance(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return inst.CFrame
    elseif inst:IsA("Model") then
        return inst:GetPivot()
    end
    return nil
end

local Resolvers = {}

Resolvers.workspaceName = function(waypoint)
    local inst = Workspace:FindFirstChild(waypoint.name, true)
    if not inst then
        warn("[TPDebug] workspaceName resolver: could not find", waypoint.name)
        return nil
    end
    dprint("workspaceName resolver found:", inst:GetFullName())
    return getCFrameFromInstance(inst)
end

Resolvers.idValue = function(waypoint)
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("StringValue") and descendant.Name == "id" and containsSubstring(descendant.Value, waypoint.id) then
            local target = descendant.Parent and descendant.Parent:FindFirstChild(waypoint.childName)
            if target then
                dprint("idValue resolver found:", target:GetFullName())
                return getCFrameFromInstance(target)
            else
                warn("[TPDebug] idValue resolver: id '" .. waypoint.id .. "' found but no child '" .. waypoint.childName .. "'")
                return nil
            end
        end
    end
    warn("[TPDebug] idValue resolver: no StringValue 'id' containing", waypoint.id)
    return nil
end

Resolvers.path = function(waypoint)
    local current = Workspace
    for _, segment in ipairs(waypoint.path) do
        current = current and current:FindFirstChild(segment)
        if not current then
            warn("[TPDebug] path resolver: failed at segment '" .. segment .. "'")
            return nil
        end
    end
    dprint("path resolver found:", current:GetFullName())
    return getCFrameFromInstance(current)
end

Resolvers.gateMarquee = function(waypoint)
    for _, marquee in ipairs(Workspace:GetDescendants()) do
        if marquee.Name == "Marquee" then
            local mText = marquee:FindFirstChild("MText")
            if mText and mText:IsA("StringValue") and containsSubstring(mText.Value, waypoint.text) then
                dprint("gateMarquee resolver matched Marquee:", marquee:GetFullName(), "MText:", mText.Value)

                if not marquee:IsA("BasePart") then
                    warn("[TPDebug] gateMarquee resolver: Marquee '" .. marquee:GetFullName() .. "' is not a BasePart, can't read .Position")
                    return nil
                end

                local targetCFrame = CFrame.new(marquee.Position - Vector3.new(0, 10, 0))
                dprint("gateMarquee resolver computed CFrame from Marquee position:", targetCFrame.Position)
                return targetCFrame
            end
        end
    end

    warn("[TPDebug] gateMarquee resolver: no Marquee found with MText containing", waypoint.text)
    return nil
end

local function resolveWaypoint(waypoint)
    local resolver = Resolvers[waypoint.type]
    if not resolver then
        warn("[TPDebug] No resolver for waypoint type:", waypoint.type)
        return nil
    end
    return resolver(waypoint)
end

-- ============================================================
-- TELEPORT LOGIC
-- ============================================================
local function getCharacterAndHRP()
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    return character, hrp
end

local function teleportToCFrame(targetCFrame, label)
    if not targetCFrame then
        warn("[TPDebug] teleportToCFrame: nil CFrame for", label)
        return false
    end
    local _, hrp = getCharacterAndHRP()
    local destination = targetCFrame + Vector3.new(0, 3, 0)
    dprint("Teleporting to", label, "->", destination.Position)
    hrp.CFrame = destination
    return true
end




-- ============================================================
-- DEFAULT DELAY BETWEEN SEQUENCE WAYPOINTS (seconds)
-- Override per-waypoint with `delay = X` in that waypoint's table
-- ============================================================
local DEFAULT_WAYPOINT_DELAY = 5

local function runSequence(sequence, objectiveMatch)
    dprint("Running sequence for objective:", objectiveMatch, "(" .. #sequence .. " waypoint(s))")
	if autoHunting then
		jackFunction("Toggle", "Auto Hunt")
	end
    for i, waypoint in ipairs(sequence) do
        local label = objectiveMatch .. " [waypoint " .. i .. "/" .. #sequence .. "]"
        local cframe = resolveWaypoint(waypoint)
        local ok = teleportToCFrame(cframe, label)
        if not ok then
            warn("[TPDebug] Sequence aborted at waypoint", i, "for objective:", objectiveMatch)
            return
        end
        if i < #sequence then
            local delay = waypoint.delay or DEFAULT_WAYPOINT_DELAY
            dprint("Waiting", delay, "seconds before next waypoint...")
            task.wait(delay)
            dprint("Done waiting, moving to waypoint", i + 1)
        end
    end
    dprint("Sequence complete for objective:", objectiveMatch)
end

-- ============================================================
-- DEBOUNCE so the same objective doesn't refire every text update
-- ============================================================
local lastTriggeredMatch = nil

local function checkLabel(text, sourceLabel)
    dprint("checkLabel on", sourceLabel and sourceLabel:GetFullName() or "?", "Text =", text)

    for _, objective in ipairs(ObjectiveConfig) do
        if containsSubstring(text, objective.match) then
			if objective.minLevel and levelData then
                if levelData.level < objective.minLevel then
                    dprint("[Level Denied] Current level:", levelData.level, "| Required level:", objective.minLevel, "for objective:", objective.match)
					if not autoHunting then
						jackFunction("Toggle", "Auto Hunt")
					end
                    return -- Stop right here! Do not teleport.
                end
            end

            if lastTriggeredMatch == objective.match then
                dprint("Objective already triggered, skipping:", objective.match)
                return
            end
            dprint("Matched objective:", objective.match)
            lastTriggeredMatch = objective.match
            task.spawn(runSequence, objective.sequence, objective.match)
            return
        end
    end

    dprint("No objective matched this text")
end

-- ============================================================
-- HOOK ALL TEXTLABELS UNDER BackGui
-- ============================================================
local function hookLabel(obj)
    dprint("Hooking TextLabel:", obj:GetFullName())
    checkLabel(obj.Text, obj)
    obj:GetPropertyChangedSignal("Text"):Connect(function()
        checkLabel(obj.Text, obj)
    end)
end

local function hookAllTextLabels()
    local count = 0
    for _, obj in ipairs(backGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            count += 1
            hookLabel(obj)
        end
    end
    dprint("Hooked", count, "TextLabel(s) under BackGui")
end

hookAllTextLabels()

backGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("TextLabel") then
        dprint("New TextLabel added:", obj:GetFullName())
        hookLabel(obj)
    end
end)



mainGui.DescendantAdded:Connect(function(child)
    if child.Name == "BattleGui" then
        while mainGui:FindFirstChild("BattleGui") do
			wait(0.3)
			local fightButton = findButton(child, {color = Color3.fromRGB(255, 102, 102)})
			click(fightButton, 0.5, 2)

			task.wait(0.3)
			if child:FindFirstChild("Move1") then
				local Move1 = child.Move1.Button
				click(Move1, 0.5, 2)
			end
			
		end

    end
end)

mainGui.DescendantRemoving:Connect(function(child)
    if child.Name == "BattleGui" then
        --
    end
end)


