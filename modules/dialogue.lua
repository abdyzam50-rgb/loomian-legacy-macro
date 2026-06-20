-- dialogue.lua
-- Detects NPC speech bubbles (FrontGui.ChatBox.Frame) and spam-clicks them
-- at frame rate until they disappear. Shows a green highlight overlay while active.

local Dialogue = {}

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

local BORDER_COLOR = Color3.fromRGB(0, 255, 0)
local THICKNESS    = 4
local FLASH_SPEED  = 8
local Y_OFFSET     = 58

local monitorThread = nil
local running       = false

local function isUiVisuallyActive(frame)
    if not frame or not frame.Parent then return false end
    if not frame.Visible or frame.AbsoluteSize.X <= 50 or frame.AbsoluteTransparency >= 1 then
        return false
    end

    local current = frame.Parent
    while current and not current:IsA("ScreenGui") do
        if current:IsA("GuiObject") and (not current.Visible or current.AbsoluteTransparency >= 1) then
            return false
        end
        current = current.Parent
    end

    return true
end

local function applyAutomation(targetFrame)
    if playerGui:FindFirstChild("AutomationTrackerScreen") then return end

    local highlightScreen = Instance.new("ScreenGui")
    highlightScreen.Name = "AutomationTrackerScreen"
    highlightScreen.IgnoreGuiInset = true
    highlightScreen.ResetOnSpawn = false
    highlightScreen.Parent = playerGui

    local highlightFrame = Instance.new("Frame")
    highlightFrame.Name = "HighlightFrame"
    highlightFrame.BackgroundTransparency = 0.8
    highlightFrame.BackgroundColor3 = BORDER_COLOR
    highlightFrame.BorderSizePixel = 0
    highlightFrame.Parent = highlightScreen

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = BORDER_COLOR
    uiStroke.Thickness = THICKNESS
    uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    uiStroke.Parent = highlightFrame

    local parentCorner = targetFrame:FindFirstChildOfClass("UICorner")
    if parentCorner then
        local uiCorner = Instance.new("UICorner")
        uiCorner.CornerRadius = parentCorner.CornerRadius
        uiCorner.Parent = highlightFrame
    end

    task.spawn(function()
        while running do
            if not isUiVisuallyActive(targetFrame) then break end

            local alpha = (math.sin(os.clock() * FLASH_SPEED) + 1) / 2
            uiStroke.Transparency = math.clamp(alpha * 0.3, 0, 0.3)
            highlightFrame.BackgroundTransparency = 0.75 + (alpha * 0.05)

            local pos  = targetFrame.AbsolutePosition
            local size = targetFrame.AbsoluteSize

            highlightFrame.Position = UDim2.new(0, pos.X, 0, pos.Y + Y_OFFSET)
            highlightFrame.Size     = UDim2.new(0, size.X, 0, size.Y)

            local clickX = pos.X + (size.X / 2)
            local clickY = (pos.Y + Y_OFFSET) + (size.Y / 2)

            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, true, game, 1)
                VirtualInputManager:SendMouseButtonEvent(clickX, clickY, 0, false, game, 1)
            end)

            RunService.RenderStepped:Wait()
        end

        if highlightScreen then highlightScreen:Destroy() end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

function Dialogue.start()
    if running then return end
    running = true

    monitorThread = task.spawn(function()
        print("[Dialogue] Monitoring for NPC speech bubbles...")

        while running do
            local frontGui  = playerGui:FindFirstChild("FrontGui")
            local chatBox   = frontGui and frontGui:FindFirstChild("ChatBox")
            local target    = chatBox and chatBox:FindFirstChild("Frame")

            if isUiVisuallyActive(target) then
                applyAutomation(target)
            else
                local overlay = playerGui:FindFirstChild("AutomationTrackerScreen")
                if overlay then overlay:Destroy() end
            end

            task.wait(0.1)
        end

        print("[Dialogue] Monitor stopped.")
    end)
end

function Dialogue.stop()
    running = false
    local overlay = playerGui:FindFirstChild("AutomationTrackerScreen")
    if overlay then overlay:Destroy() end
    print("[Dialogue] Stopped.")
end

return Dialogue
