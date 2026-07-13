-- shop.lua
-- Auto-buyer using the game's internal Network:get("PDS","buyItem") API.
-- Uses LLSPLOIT's maxBuy pattern: query server for max purchasable qty first,
-- then buy that amount in one call — no hardcoded loop count needed.

local Shop = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Default shopping list
-- Each entry: { items = { "itemId1", ... }, minStock = M }
--   items    — item IDs to buy via maxBuy → buyItem
--   minStock — only buy when inventory count falls below this
-- ─────────────────────────────────────────────────────────────────────────────

local DEFAULT_LIST = {
    { items = { "Potion" }, minStock = 10 },
}

local CHECK_INTERVAL = 30

-- ─────────────────────────────────────────────────────────────────────────────
-- _p scan — exact MrJack pattern: rawget(v,"Utilities") via getgc first
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then return nil end

    -- Primary: getgc scan (matches MrJack's ForLooP over getgc(true))
    if getgc then
        pcall(function()
            for _, v in pairs(getgc(true)) do
                if typeof(v) == "table" and rawget(v, "Utilities") and not (_p and _p.Battle) then
                    _p = v
                end
            end
        end)
    end

    if _p then
        _findPFailedAt = nil
        return _p
    end

    -- Fallback: debug.getregistry upvalue scan
    if debug and debug.getregistry then
        pcall(function()
            for _, fn in pairs(debug.getregistry()) do
                if typeof(fn) == "function" and not (_p and _p.Battle) then
                    pcall(function()
                        local upvals = getupvalues and getupvalues(fn) or debug.getupvalues(fn)
                        for _, uv in pairs(upvals) do
                            if typeof(uv) == "table" and rawget(uv, "Utilities") then
                                _p = uv
                            end
                        end
                    end)
                end
            end
        end)
    end

    if _p then
        _findPFailedAt = nil
    else
        _findPFailedAt = os.clock()
    end
    return _p
end

local function getP()
    if type(_p) == "table" and rawget(_p, "Utilities") then return _p end
    if type(_G.MacroP) == "table" and rawget(_G.MacroP, "Utilities") then
        _p = _G.MacroP; return _p
    end
    _p = findP()
    if _p then _G.MacroP = _p end
    return _p
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Inventory count via Network:get("PDS","getBagPouch")
-- Returns the total count of a given itemId/name across the bag.
-- ─────────────────────────────────────────────────────────────────────────────

local function getItemCount(itemId)
    local p = getP()
    if type(p) ~= "table" then return 0 end
    local network = rawget(p, "Network")
    if type(network) ~= "table" or type(network.get) ~= "function" then return 0 end

    local count = 0
    pcall(function()
        local bag = network:get("PDS", "getBagPouch")
        if type(bag) ~= "table" then return end
        for _, section in ipairs(bag) do
            if type(section) == "table" then
                for _, item in ipairs(section) do
                    if type(item) == "table" then
                        local id   = rawget(item, "id") or rawget(item, "name")
                        local qty  = rawget(item, "qty") or 0
                        if tostring(id) == tostring(itemId) then
                            count = count + qty
                        end
                    end
                end
            end
        end
    end)
    return count
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Core buy — LLSPLOIT maxBuy pattern:
--   1. Network:get("PDS", "maxBuy", itemId) → server returns max purchasable qty
--   2. Network:get("PDS", "buyItem", itemId, qty) → buy that amount in one call
-- ─────────────────────────────────────────────────────────────────────────────

local function buyMaxOfItem(network, itemId)
    local qty = nil
    pcall(function()
        local result = network:get("PDS", "maxBuy", itemId)
        if type(result) == "number" then
            qty = result
        elseif result == true then
            qty = 1
        end
    end)

    if not qty or qty <= 0 then
        warn("[Shop] maxBuy returned nothing for: " .. tostring(itemId))
        return
    end

    pcall(function()
        network:get("PDS", "buyItem", itemId, qty)
    end)
    print(string.format("[Shop] Bought %dx %s.", qty, tostring(itemId)))
end

local function performBuyTrip(entry)
    local p = getP()
    if type(p) ~= "table" then warn("[Shop] _p not available.") return end

    local network = rawget(p, "Network")
    if type(network) ~= "table" or type(network.get) ~= "function" then
        warn("[Shop] Network not available.")
        return
    end

    for _, itemId in ipairs(entry.items or {}) do
        buyMaxOfItem(network, itemId)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running      = false
local shoppingList = {}

local function shouldBuy(entry)
    if not entry.minStock then return true end
    for _, itemId in ipairs(entry.items or {}) do
        if getItemCount(itemId) < entry.minStock then
            return true
        end
    end
    return false
end

function Shop.start(options)
    if running then return end
    options      = options or {}
    shoppingList = options.list or DEFAULT_LIST
    local interval = options.interval or CHECK_INTERVAL
    running      = true
    getP()

    task.spawn(function()
        print("[Shop] Monitor started (" .. #shoppingList .. " shop(s) on list).")
        while running do
            for _, entry in ipairs(shoppingList) do
                if not running then break end
                if shouldBuy(entry) then
                    pcall(performBuyTrip, entry)
                end
            end
            task.wait(interval)
        end
        print("[Shop] Monitor stopped.")
    end)
end

function Shop.stop()
    running = false
    print("[Shop] Stopped.")
end

-- One-shot max buy of a single item, bypassing stock check.
function Shop.buyNow(itemId)
    local p = getP()
    if type(p) ~= "table" then warn("[Shop] _p not found.") return end
    local network = rawget(p, "Network")
    if type(network) ~= "table" then warn("[Shop] Network not found.") return end
    buyMaxOfItem(network, itemId)
end

-- Full shopping trip right now against a given list.
function Shop.runTrip(list)
    list = list or shoppingList
    for _, entry in ipairs(list) do
        if shouldBuy(entry) then
            pcall(performBuyTrip, entry)
        end
    end
    print("[Shop] Trip complete.")
end

function Shop.setList(list)
    shoppingList = list or {}
    print("[Shop] Shopping list updated (" .. #shoppingList .. " shop(s)).")
end

return Shop
