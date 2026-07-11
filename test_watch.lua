-- test_watch.lua
-- Handles the Watch/nickname UI that appears after Mom dialogue.
-- Run this standalone in your executor to test before making it a module.
--
-- What it does:
--   1. Waits for WatchContainer to appear in PlayerGui
--   2. Finds the TextBox and the two TextButtons inside it
--   3. Sets TextBox text to "X", fires submission, clicks the Yes button

local Players         = game:GetService("Players")
local GuiService      = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────────────────
-- Wait for WatchContainer to appear (up to 30s)
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Waiting for WatchContainer UI...")
local watchContainer = nil
local deadline = tick() + 30

while tick() < deadline do
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc.Name == "WatchContainer" then
            watchContainer = desc
            break
        end
    end
    if watchContainer then break end
    task.wait(0.2)
end

if not watchContainer then
    warn("[Watch] WatchContainer did not appear within 30s — is the dialogue done?")
    return
end

print("[Watch] WatchContainer found: " .. watchContainer:GetFullName())
task.wait(0.3)  -- let the UI finish animating in

-- ─────────────────────────────────────────────────────────────────────────────
-- Find the TextBox and two TextButtons inside WatchContainer
-- ─────────────────────────────────────────────────────────────────────────────

local textBox = nil
local buttons = {}

for _, element in ipairs(watchContainer:GetDescendants()) do
    if element:IsA("TextBox") and element.Name == "TextBox" then
        textBox = element
    elseif element:IsA("TextButton") and element.Name == "TextButton" then
        table.insert(buttons, element)
    end
end

local yesButton = buttons[2]  -- second TextButton is "Yes" / confirm

if not textBox then
    warn("[Watch] TextBox not found inside WatchContainer.")
    return
end
if not yesButton then
    warn("[Watch] Yes button (TextButton[2]) not found inside WatchContainer.")
    return
end

print("[Watch] TextBox and Yes button located.")

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 1: Fill the TextBox with "X"
-- Direct .Text assignment is the most reliable approach in executor context.
-- Also fires a VIM click on the box to give it focus in case the game checks it.
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Step 1: Filling TextBox with 'X'")

-- Give focus via VIM click (screen coords = AbsolutePosition + GuiInset)
local inset = GuiService:GetGuiInset()
local boxCenter = textBox.AbsolutePosition + textBox.AbsoluteSize / 2
local screenX = boxCenter.X + inset.X
local screenY = boxCenter.Y + inset.Y

VirtualInputManager:SendMouseButtonEvent(screenX, screenY, 0, true,  game, 1)
task.wait(0.05)
VirtualInputManager:SendMouseButtonEvent(screenX, screenY, 0, false, game, 1)
task.wait(0.3)

-- Set text directly (bypasses per-keystroke delays)
textBox.Text = "X"
task.wait(0.2)

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 2: Submit with Enter key
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Step 2: Pressing Enter to submit")
VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
task.wait(0.05)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
task.wait(0.5)

-- ─────────────────────────────────────────────────────────────────────────────
-- Step 3: Click the Yes/confirm button
-- Try Activate() first (no coordinate math), fall back to VIM.
-- ─────────────────────────────────────────────────────────────────────────────

print("[Watch] Step 3: Clicking Yes button")

-- Primary: fire the button's click signal directly
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

-- Fallback: VIM click at the button's screen position
if not fired then
    local btnCenter = yesButton.AbsolutePosition + yesButton.AbsoluteSize / 2
    local bx = btnCenter.X + inset.X
    local by = btnCenter.Y + inset.Y
    VirtualInputManager:SendMouseButtonEvent(bx, by, 0, true,  game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(bx, by, 0, false, game, 1)
end

task.wait(0.3)
print("[Watch] Sequence complete.")
