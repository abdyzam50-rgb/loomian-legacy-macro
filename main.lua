-- main.lua
-- Entry point. Paste this file into your executor.
-- Each module is fetched from the GitHub raw URL and loaded at runtime.

local BRANCH = "claude/modest-heisenberg-c8a4e2"
local REPO   = "https://raw.githubusercontent.com/abdyzam50-rgb/loomian-legacy-macro/" .. BRANCH

local function loadModule(name)
    local url = REPO .. "/modules/" .. name .. ".lua"
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if not ok or type(result) ~= "table" then
        error("[Main] Failed to load module '" .. name .. "': " .. tostring(result))
    end
    print("[Main] Loaded: " .. name)
    return result
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Load modules
-- ─────────────────────────────────────────────────────────────────────────────

local Movement = loadModule("movement")
local Dialogue = loadModule("dialogue")
local Battle   = loadModule("battle")
local Heal     = loadModule("heal")
-- local Shop = loadModule("shop")  -- uncomment when shopId/itemId values are known

-- ─────────────────────────────────────────────────────────────────────────────
-- Story sequence
-- ─────────────────────────────────────────────────────────────────────────────

-- Start auto-systems that should stay on for the whole run.
Dialogue.start()
Heal.start()
Battle.start()

print("\n[Main] ── Starting story sequence ──\n")

-- STEP 1: Go downstairs to Floor 1
print("[Main] Step 1: Floor 2 → Floor 1")
Movement.teleportFloor2Exit("Exit")
task.wait(1)

-- STEP 2: Walk to Mom and let dialogue skip handle the conversation
print("[Main] Step 2: Teleport to Mom")
Movement.teleportToMom()
task.wait(5)   -- give dialogue time to trigger and auto-skip

-- STEP 3: Exit the house to the overworld
print("[Main] Step 3: Exit house")
Movement.teleportFloor1Exit()
task.wait(1)

-- STEP 4: Go to the Cave entrance — cutscene starts automatically
print("[Main] Step 4: Teleport to Cave entrance")
Movement.teleportToCave()
task.wait(8)   -- wait for cave cutscene + dialogue to fully auto-skip

-- STEP 5: Go to the Lab — cutscene starts, dialogue skips automatically
print("[Main] Step 5: Teleport to Lab")
Movement.teleportToLab()
task.wait(5)   -- wait for lab cutscene intro

-- ── MANUAL PAUSE ─────────────────────────────────────────────────────────────
-- The script halts here so you can manually choose your starter Loomian.
-- After picking, open the executor console and run:
--   _G.StarterPicked = true
-- ─────────────────────────────────────────────────────────────────────────────

print("\n[Main] ══ PAUSED: Choose your starter Loomian now! ══")
print("[Main]    When done, run this in the console:  _G.StarterPicked = true\n")

_G.StarterPicked = false
repeat task.wait(0.5) until _G.StarterPicked == true

print("[Main] Starter picked. Resuming...")
task.wait(1)

-- STEP 6: Post-lab battle — dialogue + battle are already running
print("[Main] Step 6: Waiting for post-lab battle to finish...")
local battleDone = Battle.waitForEnd(180)
if not battleDone then
    warn("[Main] Post-lab battle timed out — continuing anyway.")
end

print("\n[Main] ── Initial sequence complete! ──")
print("[Main] Heal and Dialogue monitors remain active.")
print("[Main] Add more steps below for Route 1 Gate and beyond.")

-- ─────────────────────────────────────────────────────────────────────────────
-- NEXT STEPS (to be added as CFrames are provided):
--
-- Movement.teleportToRoute1Gate()   -- (CFrame TBD)
-- task.wait(...)
-- ...
-- ─────────────────────────────────────────────────────────────────────────────
