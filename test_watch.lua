-- test_watch.lua
-- Handles the Watch naming UI after Mom dialogue.
-- Exact paths confirmed from in-game scan:
--   TextBox:  MainGui.WatchContainer.Frame.Frame[3].TextBox
--   Yes btn:  MainGui.WatchContainer.Frame.TextButton[2]

local Players             = game:GetService("Players")
local GuiService          = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- Returns the Nth child with the given name inside parent.
local function getNthNamed(parent, name, n)
    local count = 0
    for _, child in ipairs(parent:GetChildren()) do
        if child.Name == name then
            count = count + 1
            if count == n then return child end
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Wait for WatchContainer inside MainGui (up to 30s)
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Waiting for WatchContainer...")

local mainGui        = playerGui:WaitForChild("MainGui", 30)
local watchContainer = mainGui and mainGui:WaitForChild("WatchContainer", 30)

if not watchContainer then
    warn("[Watch] WatchContainer not found — make sure the naming UI is open.")
    return
end

print("[Watch] WatchContainer found.")
task.wait(0.3)  -- let UI finish animating in

-- ─────────────────────────────────────────────────────────────────────────────
-- Navigate to elements using confirmed paths
-- ─────────────────────────────────────────────────────────────────────────────

local outerFrame = watchContainer:WaitForChild("Frame", 5)
if not outerFrame then warn("[Watch] WatchContainer.Frame not found.") return end

-- Frame[3] = 3rd child named "Frame" inside outerFrame
local innerFrame3 = getNthNamed(outerFrame, "Frame", 3)
if not innerFrame3 then warn("[Watch] Frame[3] not found inside WatchContainer.Frame.") return end

local textBox = innerFrame3:FindFirstChildOfClass("TextBox")
if not textBox then warn("[Watch] TextBox not found inside Frame[3].") return end

-- TextButton[2] = 2nd child named "TextButton" inside outerFrame (Yes button)
local yesButton = getNthNamed(outerFrame, "TextButton", 2)
if not yesButton then warn("[Watch] TextButton[2] (Yes) not found.") return end

print("[Watch] All elements located. Running sequence...")

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1: Focus the TextBox and set text to "X"
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Step 1: Clicking TextBox")
local inset = GuiService:GetGuiInset()
local boxCenter = textBox.AbsolutePosition + textBox.AbsoluteSize / 2

VirtualInputManager:SendMouseButtonEvent(
    boxCenter.X + inset.X, boxCenter.Y + inset.Y, 0, true, game, 1)
task.wait(0.05)
VirtualInputManager:SendMouseButtonEvent(
    boxCenter.X + inset.X, boxCenter.Y + inset.Y, 0, false, game, 1)
task.wait(0.3)

print("[Watch] Step 1: Setting text to 'X'")
textBox.Text = "X"
task.wait(1.0)  -- let the game register the text before submitting

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2: Submit — fire FocusLost(enterPressed=true) on the TextBox.
-- This is what actually happens when the player presses Enter in a TextBox;
-- the game listens to FocusLost to validate input and activate the Yes button.
-- Raw key events (SendKeyEvent) bypass this and the game ignores them.
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Step 2: Firing FocusLost (enterPressed=true)")
if firesignal then
    pcall(function()
        firesignal(textBox.FocusLost, true, nil)
    end)
else
    -- Fallback: fire via the Instance's own signal table
    pcall(function()
        textBox.FocusLost:Fire(true, nil)
    end)
end
task.wait(1.5)  -- wait for game to process submission and activate Yes button

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3: Click Yes (TextButton[2])
-- firesignal → Activate → VIM fallback
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Step 3: Clicking Yes button")

local fired = false

if firesignal then
    pcall(function()
        firesignal(yesButton.MouseButton1Click)
        fired = true
    end)
end

if not fired then
    pcall(function()
        yesButton:Activate()
        fired = true
    end)
end

if not fired then
    local btnCenter = yesButton.AbsolutePosition + yesButton.AbsoluteSize / 2
    VirtualInputManager:SendMouseButtonEvent(
        btnCenter.X + inset.X, btnCenter.Y + inset.Y, 0, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(
        btnCenter.X + inset.X, btnCenter.Y + inset.Y, 0, false, game, 1)
end

task.wait(0.3)
print("[Watch] Done.")
