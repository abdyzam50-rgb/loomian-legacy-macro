-- heal.lua
-- Auto-healer reverse-engineered from the MrJack LL decompiled source.
--
-- Two heal paths (exact MrJack logic):
--   A) HasOutsideHealers → Network:get('heal', nil, 'HealMachine1')  (simple, no travel)
--   B) else → full blackout sequence: save pos, load blackOutTo chunk,
--              getRoom/getHealer, Network:get('heal','HealthCenter',healer),
--              reload original chunk, teleport back.

local Heal = {}

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local CHECK_INTERVAL = 0.1   -- matches MrJack's LooP interval

-- ─────────────────────────────────────────────────────────────────────────────
-- Find _p: table with 'Utilities' + 'Battle' keys (MrJack's exact scan)
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then return nil end

    -- Primary: getgc scan (fastest)
    if getgc then
        for _, v in pairs(getgc(true)) do
            if typeof(v) == "table" and rawget(v, "Utilities") and rawget(v, "Battle") then
                _findPFailedAt = nil
                return v
            end
        end
    end

    -- Fallback: debug.getregistry upvalue scan
    if debug and debug.getregistry then
        for _, fn in pairs(debug.getregistry()) do
            if typeof(fn) == "function" then
                local ok, upvals = pcall(getupvalues or debug.getupvalues, fn)
                if ok and type(upvals) == "table" then
                    for _, uv in pairs(upvals) do
                        if typeof(uv) == "table" and rawget(uv, "Utilities") and rawget(uv, "Battle") then
                            _findPFailedAt = nil
                            return uv
                        end
                    end
                end
            end
        end
    end

    _findPFailedAt = os.clock()
    return nil
end

local function getP()
    if type(_p) ~= "table" or not rawget(_p, "Utilities") then
        _p = findP()
    end
    return _p
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────────────

local function getCurrentBattle()
    local p = getP()
    return p and p.Battle and p.Battle.currentBattle or nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- isFullHealth — Network:get('PDS','areFullHealth') exact from MrJack
-- ─────────────────────────────────────────────────────────────────────────────

local function isFullHealth()
    local p = getP()
    if type(p) ~= "table" then return true end

    local network = p.Network
    if type(network) == "table" and type(network.get) == "function" then
        local ok, result = pcall(function()
            return network:get("PDS", "areFullHealth")
        end)
        if ok then return result == true end
    end
    return true
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Core heal — exact MrJack implementation
-- ─────────────────────────────────────────────────────────────────────────────

local healing = false

local function performHeal()
    local p = getP()
    if type(p) ~= "table" then
        warn("[Heal] Module table not found.")
        return
    end

    local network     = p.Network
    local dataManager = p.DataManager
    local masterCtrl  = p.MasterControl
    local menu        = p.Menu
    local utilities   = p.Utilities
    local chat        = p.NPCChat

    if type(network) ~= "table" then
        warn("[Heal] Network not available.")
        return
    end

    local currentChunk = dataManager and dataManager.currentChunk
    if type(currentChunk) ~= "table" then
        warn("[Heal] currentChunk not available.")
        return
    end

    -- PATH A: outdoor healer present in this chunk (simple)
    local data = rawget(currentChunk, "data") or {}
    if data.HasOutsideHealers then
        print("[Heal] Using outdoor HealMachine1.")
        pcall(function()
            network:get("heal", nil, "HealMachine1")
        end)
        return
    end

    -- PATH B: must travel to blackout location
    local regionData  = rawget(currentChunk, "regionData") or {}
    local blackOutTo  = regionData.BlackOutTo or data.blackOutTo
    local origChunkId = rawget(currentChunk, "id")
    local origCFrame  = nil

    pcall(function()
        origCFrame = localPlayer.character.PrimaryPart.CFrame
    end)

    if blackOutTo then
        print("[Heal] Travelling to blackout chunk: " .. tostring(blackOutTo))

        -- Disable walking + menus
        if type(masterCtrl) == "table" then
            pcall(function() masterCtrl.WalkEnabled = false end)
        end
        if type(menu) == "table" then
            pcall(function() menu:disable() end)
            pcall(function() menu:fastClose(3) end)
        end

        -- Fade out + announce
        if type(utilities) == "table" then
            pcall(function() utilities.FadeOut(1) end)
        end
        task.spawn(function()
            if type(chat) == "table" and type(chat.Say) == "function" then
                pcall(function() chat:Say("[ma][Macro]Auto healing...") end)
            end
        end)

        -- Teleport to spawn box and unload current chunk
        if type(utilities) == "table" then
            pcall(function() utilities.TeleportToSpawnBox() end)
        end
        pcall(function() currentChunk:unbindIndoorCam() end)
        pcall(function() currentChunk:destroy() end)

        -- Load blackout chunk
        pcall(function()
            currentChunk = dataManager:loadChunk(blackOutTo)
        end)
    end

    -- Get HealthCenter room and healer
    local healthCenter = nil
    local healer = nil

    pcall(function()
        local door = currentChunk:getDoor("HealthCenter")
        healthCenter = currentChunk:getRoom("HealthCenter", door, 1)
    end)

    task.wait()  -- brief yield (matches MrJack's task.wait() before getHealer)

    pcall(function()
        healer = network:get("getHealer", "HealthCenter")
    end)

    -- Heal
    if healer then
        pcall(function()
            network:get("heal", "HealthCenter", healer)
        end)
        print("[Heal] Heal fired.")
    else
        warn("[Heal] Healer not found.")
    end

    -- Destroy the HealthCenter room
    if healthCenter then
        pcall(function() healthCenter:Destroy() end)
    end

    -- PATH B cleanup: return to original location
    if blackOutTo then
        pcall(function() currentChunk:destroy() end)
        pcall(function() dataManager:loadChunk(origChunkId) end)

        if origCFrame and type(utilities) == "table" then
            pcall(function() utilities.Teleport(origCFrame) end)
        end

        if type(menu) == "table" then
            pcall(function() menu:enable() end)
        end
        if type(chat) == "table" and type(chat.manualAdvance) == "function" then
            pcall(function() chat:manualAdvance() end)
        end
        if type(utilities) == "table" then
            pcall(function() utilities.FadeIn(1) end)
        end
        if type(masterCtrl) == "table" then
            pcall(function() masterCtrl.WalkEnabled = true end)
        end
    end

    print("[Heal] Heal sequence complete.")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- shouldHeal — preconditions from MrJack (exact conditions)
-- ─────────────────────────────────────────────────────────────────────────────

local function shouldHeal()
    local p = getP()
    if type(p) ~= "table" then return false end

    local masterCtrl  = p.MasterControl
    local menu        = p.Menu
    local dataManager = p.DataManager
    local objManager  = p.ObjectiveManager

    local chunk = dataManager and dataManager.currentChunk
    if type(chunk) ~= "table" then return false end

    -- Must be walking, menu open, not indoors, no active battle, LoomianCare not blocking
    if not (type(masterCtrl) == "table" and masterCtrl.WalkEnabled) then return false end
    if not (type(menu) == "table" and menu.enabled) then return false end
    if rawget(chunk, "indoors") then return false end
    if getCurrentBattle() then return false end
    if type(objManager) == "table" then
        local disabledBy = rawget(objManager, "disabledBy") or {}
        if disabledBy.LoomianCare then return false end
    end

    -- Not already at full health
    return not isFullHealth()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running = false

function Heal.start()
    if running then return end
    running = true
    healing = false
    getP()

    task.spawn(function()
        print("[Heal] Auto-heal monitor started.")
        while running do
            if not healing and shouldHeal() then
                healing = true
                xpcall(performHeal, function(err)
                    warn("[Heal] Error:", err)
                end)
                healing = false
            end
            task.wait(CHECK_INTERVAL)
        end
        print("[Heal] Monitor stopped.")
    end)
end

function Heal.stop()
    running = false
    print("[Heal] Stopped.")
end

function Heal.isHealing()
    return healing
end

function Heal.waitIfHealing()
    while healing do RunService.Heartbeat:Wait() end
end

-- Force a heal right now regardless of conditions. Blocks until done.
function Heal.forceHeal()
    healing = true
    xpcall(performHeal, function(err) warn("[Heal] forceHeal error:", err) end)
    healing = false
end

return Heal
