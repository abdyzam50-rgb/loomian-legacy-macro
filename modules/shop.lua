-- shop.lua
-- Auto-buyer using the game's internal Network:get("PDS","buyItem") API.
-- Exact buy pattern from MrJack decompiled source:
--   1. Network:get("PDS","getShop", shopId) → enumerate shop items
--   2. entry.Func(item) called per item (populates entry.Enabled)
--   3. if entry.CanAutoBuy() → loop 10x buying each enabled item via
--      Network:get("PDS","buyItem", itemId, 1)
--
-- Our simplified API maps directly onto this: each list entry specifies the
-- shopId and itemIds to buy; CanAutoBuy / Func are wired in start().

local Shop = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Default shopping list
-- Each entry: { shopId = "...", items = { "itemId1", "itemId2", ... }, minStock = M }
--   shopId   — passed to Network:get("PDS","getShop",shopId)
--   items    — list of item IDs to buy (matched against shop data via Func)
--   minStock — only buy when total inventory count falls below this (nil = always)
-- ─────────────────────────────────────────────────────────────────────────────

local DEFAULT_LIST = {
    -- { shopId = "PotionShop",  items = { "Potion" },        minStock = 5 },
    -- { shopId = "DiscShop",    items = { "StandardDisc" },  minStock = 5 },
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
-- Core buy trip — exact MrJack pattern
-- ─────────────────────────────────────────────────────────────────────────────

local function performBuyTrip(entry)
    local p = getP()
    if type(p) ~= "table" then
        warn("[Shop] _p not available — skipping trip.")
        return
    end

    local network = rawget(p, "Network")
    if type(network) ~= "table" or type(network.get) ~= "function" then
        warn("[Shop] Network not available.")
        return
    end

    -- Check shop is open (menu.shop.shopId must be nil, matching MrJack guard)
    local menu = rawget(p, "Menu")
    local shopMenu = type(menu) == "table" and rawget(menu, "shop") or nil
    if shopMenu and rawget(shopMenu, "shopId") then
        warn("[Shop] Shop menu already open — skipping.")
        return
    end

    -- Step 1: get shop object and enumerate items (mirrors MrJack's getShop + Func loop)
    local shopData = nil
    pcall(function()
        shopData = network:get("PDS", "getShop", entry.shopId)
    end)
    if type(shopData) ~= "table" then
        warn(string.format("[Shop] getShop('%s') returned nothing.", tostring(entry.shopId)))
        return
    end

    -- Build the enabled-items set from the entry's items list and the shop's item table.
    -- Func equivalent: mark each matching item as enabled.
    local enabled = {}
    for _, itemId in ipairs(entry.items or {}) do
        enabled[tostring(itemId)] = true
    end

    -- Step 2: if shop has its own item table, cross-reference to confirm items exist
    -- (mirrors iterating v48 and calling v47.Func(v51) per shop item)
    local confirmedEnabled = {}
    local hasAny = false
    for shopItemId, _ in pairs(shopData) do
        local key = tostring(shopItemId)
        if enabled[key] then
            confirmedEnabled[key] = true
            hasAny = true
        end
    end

    -- Fallback: if shopData isn't keyed by itemId, trust entry.items directly
    if not hasAny then
        confirmedEnabled = enabled
    end

    -- Step 3: buy loop — exact MrJack: 10 iterations, one unit each
    for _ = 1, 10 do
        for itemId, _ in pairs(confirmedEnabled) do
            pcall(function()
                network:get("PDS", "buyItem", itemId, 1)
            end)
        end
    end

    print(string.format("[Shop] Bought 10x each from shop '%s'.", tostring(entry.shopId)))
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
                    print(string.format("[Shop] Buying from shop '%s'...", tostring(entry.shopId)))
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

-- One-shot immediate buy: 10x of a single item, bypassing stock check.
function Shop.buyNow(shopId, itemId, count)
    count = count or 10
    local p = getP()
    if type(p) ~= "table" then warn("[Shop] _p not found.") return end
    local network = rawget(p, "Network")
    if type(network) ~= "table" then warn("[Shop] Network not found.") return end
    print(string.format("[Shop] Immediate buy: %dx %s from %s", count, itemId, shopId))
    for _ = 1, count do
        pcall(function()
            network:get("PDS", "buyItem", tostring(itemId), 1)
        end)
    end
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
