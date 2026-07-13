-- main.lua
-- Paste this entire file into your executor, or run:
--   loadstring(game:HttpGet("RAW_URL_TO_THIS_FILE"))()

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

local Movement   = loadModule("movement")
local Dialogue   = loadModule("dialogue")
local Battle     = loadModule("battle")
local Heal       = loadModule("heal")
local Objectives = loadModule("objectives")
local Utils      = loadModule("utils")    -- shared GUI helpers
-- local Mom   = loadModule("mom")    -- placeholder: wire in when ready
-- local Shop  = loadModule("shop")   -- uncomment when shopId/itemId values known

-- Give movement module access to dialogue state for cave nudge detection.
Movement.setDialogueCheck(function() return Dialogue.isChatting() end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Start background monitors (run for the entire sequence)
-- ─────────────────────────────────────────────────────────────────────────────

Dialogue.start()
Heal.start()
Battle.start()
Objectives.start()   -- hooks BackGui objective text + level tracker

-- ─────────────────────────────────────────────────────────────────────────────
-- Helper: wait for dialogue to start then fully finish.
-- ─────────────────────────────────────────────────────────────────────────────
local function waitForDialogue(startTimeout, endTimeout)
    local started = Dialogue.waitForStart(startTimeout or 10)
    if not started then
        warn("[Main] No dialogue detected within timeout — continuing anyway.")
        return
    end
    Dialogue.waitForEnd(endTimeout or 60)
    task.wait(0.5)  -- small buffer after dialogue closes
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Story sequence
-- ─────────────────────────────────────────────────────────────────────────────

print("\n[Main] ── Starting story sequence ──\n")

-- STEP 1: Floor 2 → Floor 1 (fires exit touch, waits for fade)
print("[Main] Step 1: Floor 2 Exit")
Movement.teleportFloor2Exit("Exit")

-- STEP 2: Teleport to Mom (waits for Floor 1 to load, then moves next to her)
-- TODO: replace body of this step with Mom module when it's ready:
--   Mom.start()
--   Mom.waitForComplete()
print("[Main] Step 2: Teleporting to Mom")
Movement.teleportToMom()
waitForDialogue(10, 60)   -- wait for Mom dialogue to start and fully finish

-- STEP 3: Cave entrance — nudges until cutscene trigger fires, then waits for it to end
print("[Main] Step 3: Teleporting to Cave entrance")
Movement.teleportToCave()
waitForDialogue(8, 90)    -- cave cutscene can be long

-- STEP 4: Lab door — cutscene starts, dialogue skipper handles it
print("[Main] Step 4: Teleporting to Lab")
Movement.teleportToLab()
waitForDialogue(8, 60)    -- lab intro cutscene

-- ── MANUAL PAUSE ─────────────────────────────────────────────────────────────
print("\n[Main] ══ PAUSED: Choose your starter Loomian now! ══")
print("[Main]    When done, run in console:  _G.StarterPicked = true\n")

_G.StarterPicked = false
repeat task.wait(0.5) until _G.StarterPicked == true

print("[Main] Starter picked. Waiting for post-pick dialogue...")
waitForDialogue(10, 60)   -- dialogue after picking starter

-- STEP 5: Post-lab battle
print("[Main] Step 5: Waiting for post-lab battle...")
Battle.waitForEnd(180)

print("[Main] Battle done. Waiting for any post-battle dialogue...")
waitForDialogue(5, 30)

print("\n[Main] ── Initial sequence complete! ──")
print("[Main] Heal, Dialogue, and Battle monitors remain active.")
print("[Main] Add Route 1 Gate and beyond below when CFrames are ready.")

-- ─────────────────────────────────────────────────────────────────────────────
-- NEXT STEPS (add CFrames as you provide them):
--
-- Movement.teleportToRoute1Gate()
-- waitForDialogue(5, 30)
-- ...
-- ─────────────────────────────────────────────────────────────────────────────
