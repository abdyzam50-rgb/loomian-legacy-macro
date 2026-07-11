-- scan_gui.lua
-- Run this WHILE the Watch UI is on screen.
-- It prints the full path + class of every GuiObject in PlayerGui
-- so we can find the real element names.

local Players    = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

print("\n========== PlayerGui Scan ==========")

local function scanGui(obj, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    local extra = ""

    if obj:IsA("TextBox") then
        extra = '  [TEXT: "' .. obj.Text .. '"]'
    elseif obj:IsA("TextButton") then
        extra = '  [BTN: "' .. obj.Text .. '"]'
    elseif obj:IsA("TextLabel") then
        extra = '  [LABEL: "' .. obj.Text .. '"]'
    end

    print(indent .. obj.ClassName .. ' "' .. obj.Name .. '"' .. extra)

    for _, child in ipairs(obj:GetChildren()) do
        scanGui(child, depth + 1)
    end
end

for _, gui in ipairs(playerGui:GetChildren()) do
    -- Skip default Roblox guis and our own macro guis
    if not gui.Name:find("Roblox") and gui.Name ~= "SpecificDetectorGui"
       and gui.Name ~= "MacroStatusGui" and gui.Name ~= "UIHighlightGui" then
        print("\n--- " .. gui.Name .. " ---")
        scanGui(gui, 1)
    end
end

print("\n========== Scan Complete ==========")
print("Look above for TextBox and TextButton entries near the Watch/naming UI.")
