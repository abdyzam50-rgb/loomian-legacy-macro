-- shop.lua
-- Auto-buyer: maintains a configured shopping list and purchases items when
-- stock runs low. The actual buy action is a stub (see HOOK below) to be
-- wired up later with the MrJack implementation.

local Shop = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Default shopping list
-- Each entry: { item = "ItemName", quantity = N, minStock = M }
--   item      — display/internal name of the item to buy
--   quantity  — how many to buy per shopping trip
--   minStock  — trigger a trip when inventory count drops below this
-- Leave minStock nil to always buy on every trip.
-- ─────────────────────────────────────────────────────────────────────────────

local DEFAULT_LIST = {
    -- { item = "Potion",      quantity = 10, minStock = 5 },
    -- { item = "Escape Rope", quantity = 5,  minStock = 2 },
    -- Add your items here or pass a list to Shop.start()
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Registry scan — same _G._p pattern used across all modules
-- ─────────────────────────────────────────────────────────────────────────────

local _p = nil
local _findPFailedAt = nil

local function findP()
    if _findPFailedAt and os.clock() - _findPFailedAt < 5 then return nil end
    for _, fn in pairs(debug.getregistry()) do
        if type(fn) == "function" then
            for _, upvalue in pairs(debug.getupvalues(fn)) do
                local ok, result = pcall(function() return upvalue.NPCChat end)
                if ok and type(result) == "table" then
                    _findPFailedAt = nil
                    return upvalue
                end
            end
        end
    end
    _findPFailedAt = os.clock()
    return nil
end

local function getP()
    if type(_p) ~= "table" then _p = findP() end
    return _p
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Inventory reader
-- Attempts to read item counts from _G._p internals.
-- Returns a table keyed by item name → count.
-- ─────────────────────────────────────────────────────────────────────────────

local function getInventory()
    local inv = {}
    local p = getP()
    if type(p) ~= "table" then return inv end

    -- Try common key names for the inventory/bag module
    for _, key in ipairs({ "Inventory", "inventory", "Bag", "bag", "Items", "items" }) do
        local container = p[key]
        if type(container) == "table" then
            -- Try container.items or iterate directly
            local items = type(container.items) == "table" and container.items or container
            for itemName, count in pairs(items) do
                if type(itemName) == "string" and type(count) == "number" then
                    inv[itemName] = count
                end
            end
            break
        end
    end

    return inv
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HOOK: performBuy(item, quantity)
-- Replace the body of this function with the MrJack shop implementation.
-- It should block until the purchase is complete before returning.
-- `item`     — string name of the item to buy
-- `quantity` — number of units to purchase
-- ─────────────────────────────────────────────────────────────────────────────

local function performBuy(item, quantity)
    -- ┌─────────────────────────────────────────────────────────────────────┐
    -- │  TODO: plug in MrJack auto-buy logic here                           │
    -- │  Expected behaviour:                                                 │
    -- │    1. Teleport to / interact with the shop NPC                      │
    -- │    2. Navigate to the correct item in the shop UI                   │
    -- │    3. Purchase `quantity` units of `item`                           │
    -- │    4. Close shop UI and return                                       │
    -- └─────────────────────────────────────────────────────────────────────┘
    warn(string.format("[Shop] performBuy() stub called — item='%s' qty=%d. Wire up MrJack here.", tostring(item), quantity))
    task.wait(1)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- shouldBuy: checks if an item's stock is below minStock
-- ─────────────────────────────────────────────────────────────────────────────

local function shouldBuy(entry, inv)
    if not entry.minStock then return true end
    local current = inv[entry.item] or 0
    return current < entry.minStock
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

local running      = false
local shoppingList = {}
local CHECK_INTERVAL = 30   -- seconds between inventory checks

-- Start the background shop monitor.
-- `options.list`     — array of { item, quantity, minStock } entries
-- `options.interval` — override check interval in seconds
function Shop.start(options)
    if running then return end
    options      = options or {}
    shoppingList = options.list or DEFAULT_LIST
    local interval = options.interval or CHECK_INTERVAL
    running      = true

    getP()

    task.spawn(function()
        print("[Shop] Monitor started (" .. #shoppingList .. " item(s) on list).")

        while running do
            local inv = getInventory()

            for _, entry in ipairs(shoppingList) do
                if not running then break end

                if shouldBuy(entry, inv) then
                    print(string.format("[Shop] Buying %dx %s...", entry.quantity, entry.item))
                    pcall(performBuy, entry.item, entry.quantity)
                    -- Refresh inventory after purchase
                    inv = getInventory()
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

-- One-shot: buy a specific item right now regardless of stock.
-- Blocks until complete.
function Shop.buyNow(item, quantity)
    print(string.format("[Shop] Immediate buy: %dx %s", quantity, item))
    pcall(performBuy, item, quantity)
end

-- Run a full shopping trip against the configured list right now.
-- Blocks until all purchases are complete.
function Shop.runTrip(list)
    list = list or shoppingList
    local inv = getInventory()
    for _, entry in ipairs(list) do
        if shouldBuy(entry, inv) then
            print(string.format("[Shop] Trip: buying %dx %s...", entry.quantity, entry.item))
            pcall(performBuy, entry.item, entry.quantity)
            inv = getInventory()
        end
    end
    print("[Shop] Trip complete.")
end

-- Set the shopping list at runtime without restarting.
function Shop.setList(list)
    shoppingList = list or {}
    print("[Shop] Shopping list updated (" .. #shoppingList .. " item(s)).")
end

-- Expose hook so the MrJack implementation can be injected at runtime:
--   Shop.setPerformBuy(function(item, qty) ... end)
function Shop.setPerformBuy(fn)
    if type(fn) == "function" then
        performBuy = fn
        print("[Shop] performBuy() implementation registered.")
    end
end

return Shop
