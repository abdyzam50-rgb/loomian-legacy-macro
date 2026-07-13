local vim = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = game.Players.LocalPlayer
local pGui = player:WaitForChild("PlayerGui")

local running = true
local spamStep = 1 -- Alternates between point 1 and 2

-- Defined fallback points
local fallbackPoints = {
    {x = 1336, y = 431},
    {x = 822, y = 385}
}

-- Permanent Visualizer
local visualizer = Instance.new("ScreenGui")
visualizer.Name = "ClickVisualizer"
visualizer.IgnoreGuiInset = true
visualizer.ResetOnSpawn = false
visualizer.Parent = pGui

-- Create permanent markers for both points
for i, pt in ipairs(fallbackPoints) do
    local dot = Instance.new("Frame")
    dot.Name = "FallbackPoint_" .. i
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(0, pt.x - 4, 0, pt.y - 4)
    dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    dot.BackgroundTransparency = 0.6
    dot.ZIndex = 10000
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    dot.Parent = visualizer
end

-- Kill switch
UIS.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.X then
        running = false
        visualizer:Destroy()
        print("!!! SCRIPT STOPPED !!!")
    end
end)

local function flashClick(x, y, color)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 15, 0, 15)
    dot.Position = UDim2.new(0, x - 7.5, 0, y - 7.5)
    dot.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
    dot.ZIndex = 10001
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    dot.Parent = visualizer
    task.delay(0.1, function() dot:Destroy() end)
end

local function isEffectivelyVisible(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if not obj.Visible then return false end
    
    local current = obj.Parent
    while current and current:IsA("GuiObject") do
        if not current.Visible then return false end
        current = current.Parent
    end
    
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    return sg and sg.Enabled
end

local function vimClick(button, color)
    if not button or not isEffectivelyVisible(button) then return false end
    
    local pos = button.AbsolutePosition
    local size = button.AbsoluteSize
    if pos.X <= 0 and pos.Y <= 0 then return false end
    
    local centerX = pos.X + (size.X / 2)
    local centerY = pos.Y + (size.Y / 2)
    
    local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
    if screenGui and not screenGui.IgnoreGuiInset then
        centerY = centerY + GuiService:GetGuiInset().Y
    end
    
    flashClick(centerX, centerY, color)
    vim:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
    task.wait(0.01)
    vim:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
    return true
end

local function spamFallbacks()
    local target = fallbackPoints[spamStep]
    
    flashClick(target.x, target.y, Color3.fromRGB(255, 0, 0))
    
    vim:SendMouseButtonEvent(target.x, target.y, 0, true, game, 0)
    task.wait(0.01)
    vim:SendMouseButtonEvent(target.x, target.y, 0, false, game, 0)
    
    -- Cycle to the next point
    spamStep = (spamStep % #fallbackPoints) + 1
end

print("Points Set: Alternate Spam Active.")

while running do
    local clickedAny = false

    -- 1. High Priority Scan (Moves)
    local mainGui = pGui:FindFirstChild("MainGui")
    if mainGui then
        for _, name in pairs({"Move1", "Move3", "Button"}) do
            local found = mainGui:FindFirstChild(name, true)
            if found and (found:IsA("GuiButton") or found:FindFirstChildWhichIsA("GuiButton")) then
                local target = found:IsA("GuiButton") and found or found:FindFirstChildWhichIsA("GuiButton")
                if vimClick(target, Color3.fromRGB(0, 255, 100)) then
                    clickedAny = true
                    break
                end
            end
        end
    end

    -- 2. FrontGui Scan
    if not clickedAny then
        local frontGui = pGui:FindFirstChild("FrontGui")
        if frontGui and frontGui.Enabled then
            for _, obj in pairs(frontGui:GetDescendants()) do
                if (obj:IsA("ImageButton") or obj:IsA("TextButton")) and isEffectivelyVisible(obj) then
                    if vimClick(obj, Color3.fromRGB(0, 170, 255)) then
                        clickedAny = true
                        break
                    end
                end
            end
        end
    end

    -- 3. Point Fallback
    if not clickedAny then
        spamFallbacks()
        task.wait(0.05)
    else
        task.wait(0.2)
    end
end