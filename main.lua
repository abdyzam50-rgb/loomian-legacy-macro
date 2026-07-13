-- main.lua
-- Entry point for the Loomian Legacy macro.
-- Paste this entire file into your executor, or loadstring it from the raw GitHub URL:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/abdyzam50-rgb/loomian-legacy-macro/main/main.lua"))()

local BRANCH = "main"
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

local Movement   = loadModule("movement")
local Dialogue   = loadModule("dialogue")
local Battle     = loadModule("battle")
local Heal       = loadModule("heal")
local Objectives = loadModule("objectives")
local Utils      = loadModule("utils")
-- local Mom  = loadModule("mom")   -- wire in when ready
-- local Shop = loadModule("shop")  -- uncomment once shopId/itemId values are known

-- Let the movement module know how to check dialogue state for cave nudge detection.
Movement.setDialogueCheck(function() return Dialogue.isChatting() end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Start background monitors (run for the entire session)
-- ─────────────────────────────────────────────────────────────────────────────

Dialogue.start()    -- auto-skips NPC dialogue
Heal.start()        -- auto-heals when HP is low
Battle.start()      -- auto-battles with best-move + auto-swap
Objectives.start()  -- reacts to objective text → teleports through story waypoints

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: wait for dialogue to start then fully finish
-- ─────────────────────────────────────────────────────────────────────────────

local function waitForDialogue(startTimeout, endTimeout)
    local started = Dialogue.waitForStart(startTimeout or 10)
    if not started then
        warn("[Main] No dialogue detected within timeout — continuing anyway.")
        return
    end
    Dialogue.waitForEnd(endTimeout or 60)
    task.wait(0.5)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Story sequence
-- ─────────────────────────────────────────────────────────────────────────────

print("\n[Main] ── Starting story sequence ──\n")

-- STEP 1: Cave entrance — nudges until the cutscene trigger fires, then waits for it to end
print("[Main] Step 1: Teleporting to Cave entrance")
Movement.teleportToCave()
waitForDialogue(8, 90)

-- STEP 4: Lab door — cutscene starts, dialogue skipper handles it
print("[Main] Step 4: Teleporting to Lab")
Movement.teleportToLab()
waitForDialogue(8, 60)

-- Starter is given automatically through the lab cutscene dialogue.
print("[Main] Waiting for starter dialogue / pick sequence...")
waitForDialogue(15, 90)

-- STEP 5: Post-lab battle (dialogue skipper + auto-battler handle this)
print("[Main] Step 5: Waiting for post-lab battle to finish...")
Battle.waitForEnd(180)

print("[Main] Battle done. Waiting for any post-battle dialogue...")
waitForDialogue(5, 30)

print("\n[Main] ── Initial sequence complete! ──")
print("[Main] Heal, Dialogue, Battle, and Objectives monitors remain active.")
print("[Main] Add further waypoints below as CFrames become available.\n")

-- ─────────────────────────────────────────────────────────────────────────────
-- Add further steps here once CFrames / triggers are confirmed in-game:
--
-- Movement.teleportToRoute1Gate()
-- waitForDialogue(5, 30)
-- Battle.waitForEnd(120)
-- ...
-- ─────────────────────────────────────────────────────────────────────────────
