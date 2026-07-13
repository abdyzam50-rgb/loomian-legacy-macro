-- utils.lua
-- Shared GUI interaction helpers used across modules.

local Utils = {}

local GuiService          = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Players             = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- click(button, xOffset, yOffset)
-- Clicks a GuiObject at a fractional offset within its bounds.
-- xOffset/yOffset = 0.5, 0.5 hits the centre.
-- ─────────────────────────────────────────────────────────────────────────────
function Utils.click(button, xOffset, yOffset)
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

-- ─────────────────────────────────────────────────────────────────────────────
-- findButton(container, options)
-- Searches container's descendants for a GuiObject matching all options:
--   className  — ClassName or Name string
--   text       — substring found in a TextLabel/TextButton child
--   color      — BackgroundColor3 or ImageColor3 match
--   childName  — must have a child with this name
-- ─────────────────────────────────────────────────────────────────────────────
function Utils.findButton(container, options)
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
                        and child.Text:find(options.text)
                    then
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
                isMatch = isMatch and obj:FindFirstChild(options.childName) ~= nil
            end

            if isMatch then return obj end
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- jackFunction(name, papa)
-- Fires a button's Activated and MouseButton1Click signals directly,
-- bypassing visibility constraints. Searches all of PlayerGui.
-- ─────────────────────────────────────────────────────────────────────────────
function Utils.jackFunction(name, papa)
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == name and (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
            local current = desc.Parent
            while current do
                if current.Name == papa then
                    if firesignal then
                        pcall(function() firesignal(desc.Activated) end)
                        pcall(function() firesignal(desc.MouseButton1Click) end)
                    elseif getconnections then
                        for _, c in ipairs(getconnections(desc.Activated))       do pcall(function() c:Fire() end) end
                        for _, c in ipairs(getconnections(desc.MouseButton1Click)) do pcall(function() c:Fire() end) end
                    else
                        warn("[Utils] jackFunction: executor has no firesignal or getconnections.")
                    end
                    return
                end
                current = current.Parent
            end
        end
    end
    warn("[Utils] jackFunction: button '" .. name .. "' inside '" .. papa .. "' not found.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- pressKey(keyCode)
-- ─────────────────────────────────────────────────────────────────────────────
function Utils.pressKey(keyCode)
    VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    task.wait(0.3)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- selectClick(button)
-- Selects a button via GuiService then presses Enter — works for
-- buttons that require Gamepad-style selection.
-- ─────────────────────────────────────────────────────────────────────────────
function Utils.selectClick(button)
    GuiService.SelectedObject = button
    task.wait(0.1)
    Utils.pressKey(Enum.KeyCode.Return)
end

return Utils
