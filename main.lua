-- main.lua
-- Entry point for the Loomian Legacy macro.
-- Paste this entire file into your executor, or loadstring it from the raw GitHub URL:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/abdyzam50-rgb/2317402bska/main/main.lua"))()

local BRANCH = "main"
local REPO   = "https://raw.githubusercontent.com/abdyzam50-rgb/2317402bska/" .. BRANCH

local function loadModule(name)
    local url = REPO .. "/modules/" .. name .. ".lua"
    local src = game:HttpGet(url)
    local chunk, compileErr = loadstring(src)
    if not chunk then
        error("[Main] Compile error in '" .. name .. "': " .. tostring(compileErr))
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        error("[Main] Runtime error in '" .. name .. "': " .. tostring(result))
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
local Shop       = loadModule("shop")
local Trainer    = loadModule("trainer")
local Objectives = loadModule("objectives")

Movement.setDialogueCheck(function() return Dialogue.isChatting() end)
Objectives.setDialogueModule(Dialogue)

-- ─────────────────────────────────────────────────────────────────────────────
-- Start background monitors (run for the entire session)
-- ─────────────────────────────────────────────────────────────────────────────

Dialogue.start()    -- auto-skips NPC dialogue
Heal.start()        -- auto-heals when HP is low
Shop.start()        -- auto-buys potions when stock is low
Battle.start()      -- auto-battles with best-move + auto-swap
Objectives.start()  -- reacts to objective text → teleports through story waypoints

print("\n[Main] ── All monitors active. Objectives module is driving story progression. ──\n")
