--[[
  Battle Move Macro v6 - standalone
  Paste this ENTIRE file into your executor and run once.
  Does not use readfile or writefile.

  Stop:   getgenv().BattleMoveMacro.stop()
  Reload: stop, then execute this script again

  (Edits: battle_move_macro/runtime.lua then run build_macro.ps1)
]]
local SCRIPT_VERSION = "battle-move-macro-6.2.3"

-- Party: 7 slots total — slot 1 is active lead; only slots 2-5 can be switched in during battle
local TEAM_SLOT_TOTAL = 7
local BATTLE_SWITCH_SLOT_MIN = 2
local BATTLE_SWITCH_SLOTS = 5
local PARTY_MENU_CHAIN = { "WatchContainer", "PartyMenu", "PartyMain" }
local PARTY_MENU_ROOT_CHAIN = { "WatchContainer", "PartyMenu" }
local PARTY_SLOT_COUNT = 7

-- Hidden until Loomians is clicked — macro finds the battle button that opens this tree
local PARTY_MENU_TARGET = {
    rootChain = PARTY_MENU_ROOT_CHAIN,
    mainName = "PartyMain",
    slotPrefix = "Slot",
    slotCount = PARTY_SLOT_COUNT,
    path = "MainGui.WatchContainer.PartyMenu.PartyMain",
}

-- Inspector rbxids change every session — use GUI structure + screen position instead.
-- Multiple ImageLabel siblings share paths like BattleGui.ImageLabel.Button;
-- FindFirstChild only returns the first — we enumerate all panels instead.

-- Step 1 menu opener: direct Button on the fight panel (ImageLabel with nested submenu)
local MENU_BUTTON = {
    chain = { "ImageLabel", "Button" },
    path = "BattleGui.[FightPanel].Button",
    role = "menu",
}

local EXEC_STALE_SEC = 45
local BATTLE_GUI_WAIT = 2.5
local GUI_READY_WAIT = 4
local GUI_READY_POLL = 0.1
local VIM_DOWN_UP_GAP = 0.05
local STEP_WAIT = 0.25
local TEAM_SWITCH_STEP_WAIT = 0.55
local PARTY_MENU_OPEN_WAIT = 4
local LOOMIANS_FIND_WAIT = 5
local HIGHLIGHT_PREVIEW_SEC = 0.8
local PANEL_CLICK_DELAY = 0.2

-- Extra px on top of GuiInset for VIM clicks (tune in-game if needed)
local clickOffsets = { x = 0, y = 0 }
-- Overlay uses IgnoreGuiInset — shift highlights down to match VIM click position
local highlightOffsets = { x = 0, y = 58 }
-- VIM coord mode: "highlight" = click where yellow circles show | "raw" = icigool-style | "inset" = +GuiInset
local clickMode = "highlight"
local MAX_CLICK_STEPS = 12
local UI_MIN_BUTTON_SIZE = 10

local fallbackPoints = {
    { x = 1336, y = 431, name = "Fallback A" },
    { x = 822, y = 385, name = "Fallback B" },
}

-- Miscellaneous battle actions (not in the 4 move slots)
-- Wiki: Wait = +1/3 energy, no penalty | Rest = +2/3 energy, -1 Melee/Ranged Def this turn
-- Both resolve before normal move priority in PvP
local MISC_ACTIONS = {
    wait = {
        label = "Wait",
        displayName = "Wait",
        rowSlot = 1,
        role = "wait",
        probeChain = { "ImageLabel", "ImageLabel", "Button" },
        probePath = "BattleGui.[FightPanel].ImageLabel.ImageLabel.Button",
        energyFraction = 1 / 3,
        summary = "+33% energy, no penalty",
        detail = "Recovers ⅓ max Energy. Goes first (outside move priority).",
        textColor = Color3.fromRGB(120, 200, 255),
        bgColor = Color3.fromRGB(22, 32, 42),
    },
    rest = {
        label = "Rest",
        displayName = "Rest",
        rowSlot = 2,
        role = "rest",
        probeChain = { "ImageLabel", "Button" },
        probePath = "BattleGui.[FightPanel].Button (submenu open)",
        energyFraction = 2 / 3,
        summary = "+66% energy, -1 DEF",
        detail = "Recovers ⅔ max Energy. Lowers Melee & Ranged Defense 1 stage this turn.",
        textColor = Color3.fromRGB(220, 170, 255),
        bgColor = Color3.fromRGB(32, 24, 42),
    },
}

-- Team menu actions — loomians: direct click only (skip menu Button step)
local TEAM_ACTIONS = {
    loomians = {
        label = "Loomians",
        displayName = "Loomians",
        skipMenuStep = true,
        role = "loomians",
        sidePanelPick = "rightmost",
        probeChain = { "ImageLabel", "Button" },
        probePath = "BattleGui.[FlatSidePanel].Button → WatchContainer.PartyMenu.PartyMain",
        summary = "Switch Loomian",
        detail = "Open team menu — pick a party slot once probed.",
        textColor = Color3.fromRGB(255, 200, 120),
        bgColor = Color3.fromRGB(42, 32, 22),
    },
}

-- Party slot targets under PartyMenu.PartyMain.SlotN.ImageButton
local TEAM_SLOTS = {}

local function initTeamSlotDefaults()
    for i = 1, TEAM_SLOT_TOTAL do
        TEAM_SLOTS[i] = TEAM_SLOTS[i] or {}
        local cfg = TEAM_SLOTS[i]
        cfg.slotName = cfg.slotName or ("Slot" .. i)
        cfg.probePath = cfg.probePath
            or ("MainGui.WatchContainer.PartyMenu.PartyMain.Slot" .. i .. ".ImageButton")
        cfg.battleUsable = i >= BATTLE_SWITCH_SLOT_MIN and i <= BATTLE_SWITCH_SLOTS
    end
end
initTeamSlotDefaults()

-- FrontGui confirm after picking a Loomian in PartyMenu (path-stable; rbxid optional)
local SWITCH_CONFIRM = {
    path = "FrontGui.SwitchButton",
}

-- ===========================================================================
-- §2 Lifecycle — single source of truth; must run before any handlers
-- ===========================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VIM = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local G = getgenv and getgenv() or _G

local function disconnectAllMacroConnections()
    local bucket = G.__BattleMoveMacroConnections
    if type(bucket) ~= "table" then return end
    for i = #bucket, 1, -1 do
        local conn = bucket[i]
        pcall(function() conn:Disconnect() end)
        bucket[i] = nil
    end
end

local function trackMacroConnection(conn)
    G.__BattleMoveMacroConnections = G.__BattleMoveMacroConnections or {}
    G.__BattleMoveMacroConnections[#G.__BattleMoveMacroConnections + 1] = conn
    return conn
end

-- Kill every prior load's remote handlers (loadstring leaves stale closures alive)
G.__BattleMoveMacroActiveInstance = nil
disconnectAllMacroConnections()
G.__BattleMoveMacroHookedRemotes = {}

if G.BattleMoveMacro and G.BattleMoveMacro.stop then
    pcall(G.BattleMoveMacro.stop)
end

local MACRO_INSTANCE_ID = tostring(tick()) .. "-" .. tostring(math.random(100000, 999999))
G.__BattleMoveMacroActiveInstance = MACRO_INSTANCE_ID

pcall(function()
    local inset = GuiService:GetGuiInset()
    if inset.Y > 0 then
        highlightOffsets.y = inset.Y
    end
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state = {
    connections = {},
    lastRqid = nil,
    pendingSlot = nil,
    pendingAction = nil,
    pendingMoveName = nil,
    pendingAt = 0,
    executing = false,
    enemyName = nil,
    enemyHpBefore = nil,
    enemyMaxHp = nil,
    lead = {
        name = "?",
        types = {},
        health = 0,
        maxHealth = 0,
        energy = 0,
        maxEnergy = 0,
        moves = {},
    },
    party = {},
    partySize = 0,
    activePartySlot = nil,
    lastResult = {
        move = nil,
        effectiveness = nil,
        damage = nil,
        enemyHpAfter = nil,
        text = "Waiting for battle...",
    },
    lastError = nil,
    errorLog = {},
}

G.__BattleMoveMacroState = state

local guiRefs = {}
local overlayRefs = { markers = {}, conn = nil }

local function getState()
    return G.__BattleMoveMacroState or state
end

local function isActiveInstance()
    return G.__BattleMoveMacroActiveInstance == MACRO_INSTANCE_ID
end

-- Forward refs filled in later sections (prevents Luau forward-reference bugs)
local refreshGui, createGui, setStatus
local executeMoveSlot, executePanelAction, executeTeamSlot
local onRemoteEvent, handleMoveRequest, handleSideUpdatePacket, processChartArg4
local buildClickSpots, showHighlights, clearHighlights, runTeamSwitchClickSequence, isOnScreen, guiCenterOf, getSpotCoords, clickGuiButton, clickSpot, getBattleGui, waitForBattleGui, isMoveSubmenuOpen, waitForMoveSubmenu, isSwitchConfirmVisible, isGuiReadyForClick, waitForGuiReady, waitForSpotReady, waitForButtonFinder, getRbxId, shortRbxId, findMoveButton, findMoveButtonByName, getPartyMenuStructure, partyMenuTargetExists, resolveLoomiansPanelButton, resolvePanelButtonByRole, listBattlePanelLayout, probePanelButtonFromMouse, findPartyMenuMain, isPartyMenuOpen, resolveTeamSlotButton, waitForTeamSlotButton, getMiscExpectedPath, resolveLoomiansButton, findLoomiansBattleButton, waitForLoomiansButton, waitForPartyMenuOpen, clickLoomiansButton, resolveSwitchConfirmButton, waitForSwitchConfirmButton, resolveMiscActionButton, waitForMiscActionButton, findMiscActionMenuRow, resolveMiscActionRow, findBattleButtonByLabel, findMiscActionPair, findMiscActionNode, miscFindDebug, resolveBattleMenuButton, waitForBattleMenuButton, findBattleMenuButton, clickVerifiedMenuButton, findMiscActionButton, listBattleMenuButtons, clickMiscSpotVerified, buildMiscClickSpots
local copyPartyFromPacket, applyPlayerSwitchByName, updateLeadFromRequest
local wireMoveButtons, wireMiscButtons, wireTeamButtons

-- ===========================================================================
-- §2.5 Error codes & handler
-- ===========================================================================

local Err = {}

Err.codes = {
    INIT_FAILED = "E001",
    STALE_INSTANCE = "E002",
    BATTLE_GUI_MISSING = "E100",
    BUTTON_NOT_FOUND = "E101",
    PARTY_MENU_MISSING = "E102",
    PARTY_MENU_TIMEOUT = "E103",
    SUBMENU_NOT_OPEN = "E104",
    CLICK_COORDS_MISSING = "E200",
    CLICK_HELPER_NIL = "E201",
    CLICK_FAILED = "E202",
    SPOTS_EMPTY = "E203",
    EXEC_BUSY = "E300",
    NO_MOVE_DATA = "E301",
    MOVE_DISABLED = "E302",
    NO_ENERGY = "E303",
    SWITCH_LEAD = "E400",
    SWITCH_BENCH = "E401",
    SWITCH_FAINTED = "E402",
    SWITCH_SEQUENCE = "E403",
    REMOTE_HANDLER = "E500",
}

function Err.make(code, message, context)
    return {
        code = code,
        message = message or "?",
        context = context or {},
        when = tick(),
        version = SCRIPT_VERSION,
    }
end

function Err.format(err)
    if type(err) == "string" then return err end
    if type(err) ~= "table" then return tostring(err) end
    local parts = {}
    for k, v in pairs(err.context or {}) do
        parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
    end
    table.sort(parts)
    local ctx = #parts > 0 and (" | " .. table.concat(parts, ", ")) or ""
    return string.format("[%s] %s%s", tostring(err.code or "E???"), tostring(err.message or "?"), ctx)
end

function Err.push(err)
    state.lastError = err
    state.errorLog = state.errorLog or {}
    state.errorLog[#state.errorLog + 1] = err
    if #state.errorLog > 40 then
        table.remove(state.errorLog, 1)
    end
end

function Err.report(err, opts)
    opts = opts or {}
    if type(err) == "string" then
        err = Err.make("E000", err)
    end
    Err.push(err)
    local text = Err.format(err)
    warn("[BattleMoveMacro] " .. text)
    if opts.status ~= false and setStatus then
        setStatus(text)
    end
    if opts.refresh ~= false and refreshGui then
        refreshGui()
    end
    return text
end

function Err.checkHelper(name, fn)
    if type(fn) == "function" then return true end
    Err.report(Err.make(Err.codes.CLICK_HELPER_NIL, "Internal helper missing (reload script)", {
        helper = name,
    }))
    return false
end

function Err.run(where, fn, opts)
    local ok, result = pcall(fn)
    if ok then return true, result end
    Err.report(Err.make(Err.codes.REMOTE_HANDLER, tostring(result), { where = where }), opts)
    return false, result
end

local function normalizeLabel(text)
    return string.lower(string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
end

local function isActiveLeadSlot(slot)
    if slot == 1 then return true end
    local s = getState()
    if type(s) ~= "table" then return false end
    if s.activePartySlot and slot == s.activePartySlot then return true end
    local mon = s.party and s.party[slot]
    return mon and mon.active == true
end

local function isBattleSwitchSlot(slot)
    return type(slot) == "number"
        and slot >= BATTLE_SWITCH_SLOT_MIN
        and slot <= BATTLE_SWITCH_SLOTS
end

local function getPanelActionConfig(actionKey)
    return MISC_ACTIONS[actionKey] or TEAM_ACTIONS[actionKey]
end

local function isPanelActionKey(actionKey)
    return getPanelActionConfig(actionKey) ~= nil
end

-- ===========================================================================
-- §3 Core utilities
-- ===========================================================================

local function idx(t, i)
    if type(t) ~= "table" then return nil end
    return t[i] or t[tostring(i)]
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        if na then return true end
        if nb then return false end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function tryDecodeChartLine(raw)
    if type(raw) == "table" then return raw end
    if type(raw) ~= "string" then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(decoded) == "table" then return decoded end
    return nil
end

local function parseHpFromStatsLine(statsLine)
    if type(statsLine) ~= "string" then return nil, nil end
    local hpPart = statsLine:match("^(%d+/%d+)") or statsLine:match(";(%d+/%d+)")
    if not hpPart then return nil, nil end
    local cur, max = hpPart:match("^(%d+)/(%d+)$")
    return tonumber(cur), tonumber(max)
end

local function parseStatsLineFull(statsLine)
    if type(statsLine) ~= "string" then return nil end
    local name, level, gender = statsLine:match("^([^,]+),%s*(L%d+),%s*([^;]+)")
    local hpCur, hpMax = statsLine:match(";(%d+)/(%d+)")
    return {
        name = name,
        level = level,
        gender = gender,
        hp = tonumber(hpCur),
        maxHp = tonumber(hpMax),
    }
end

local function copyMovesFromTable(moves)
    local out = {}
    if type(moves) ~= "table" then return out end
    for i = 1, 4 do out[i] = idx(moves, i) end
    return out
end

local function movesTableHasData(moves)
    for i = 1, 4 do
        if type(idx(moves, i)) == "table" then return true end
    end
    return false
end

local function getActiveMon(packet)
    if type(packet.active) ~= "table" then return nil end
    return idx(packet.active, 1)
end

local function getPartyLead(packet)
    local side = packet.side
    if type(side) ~= "table" then return nil end
    local party = side.party or side.Party
    if type(party) ~= "table" then return nil end
    return idx(party, 1)
end

local function normalizePartyMon(mon, slotIndex, activeMon)
    local entry = {
        index = tonumber(mon.index) or slotIndex,
        name = mon.name or mon.species or mon.nickname or ("Slot " .. slotIndex),
        active = mon.active == true,
        fainted = mon.fainted == true,
        icon = mon.icon,
        ident = mon.ident,
        health = nil,
        maxHealth = nil,
        healthFrac = nil,
        energy = nil,
        maxEnergy = nil,
        energyFrac = nil,
    }

    if entry.active and type(activeMon) == "table" then
        entry.health = activeMon.health
        entry.maxHealth = activeMon.maxHealth
        entry.energy = activeMon.energy
        entry.maxEnergy = activeMon.maxEnergy
        if activeMon.name then entry.name = activeMon.name end
        if activeMon.maxHealth and activeMon.maxHealth > 0 then
            entry.healthFrac = (activeMon.health or 0) / activeMon.maxHealth
        end
        entry.fainted = activeMon.fainted == true
            or (type(activeMon.health) == "number" and activeMon.health <= 0)
    else
        local hp = mon.health or mon.hp or mon.HP
        local maxHp = mon.maxHealth or mon.maxhp or mon.maxHP

        if type(hp) == "number" then
            if hp <= 1 and (not maxHp or maxHp <= 1) then
                entry.healthFrac = hp
                entry.fainted = entry.fainted or hp <= 0
            else
                entry.health = hp
                entry.maxHealth = maxHp
                if maxHp and maxHp > 0 then
                    entry.healthFrac = hp / maxHp
                end
                entry.fainted = entry.fainted or hp <= 0
            end
        end

        local en = mon.energy
        if type(en) == "number" then
            if en <= 1 then
                entry.energyFrac = en
            else
                entry.energy = en
            end
        end
    end

    if entry.healthFrac and entry.healthFrac <= 0 then
        entry.fainted = true
    end

    return entry
end

-- ===========================================================================
-- §4 Party & lead sync
-- ===========================================================================

local function namesMatch(a, b)
    if not a or not b then return false end
    local na = string.lower(string.gsub(tostring(a or ""), "^%s*(.-)%s*$", "%1"))
    local nb = string.lower(string.gsub(tostring(b or ""), "^%s*(.-)%s*$", "%1"))
    return na == nb
end

local function parseIdentName(ident)
    if type(ident) ~= "string" then return nil end
    local name = ident:match(":%s*(.+)$") or ident
    return string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
end

local function resolveActivePartySlot(activeMon, party)
    if not activeMon or not party then return nil end

    local activeIndex = tonumber(activeMon.index) or tonumber(activeMon.slot)
    if activeIndex and party[activeIndex] then
        return activeIndex
    end

    if activeMon.ident then
        for slot, mon in pairs(party) do
            if mon and mon.ident == activeMon.ident then
                return slot
            end
        end
    end

    if activeMon.name then
        for slot, mon in pairs(party) do
            if mon and namesMatch(mon.name, activeMon.name) then
                return slot
            end
        end
    end

    return nil
end

local function applyActiveMonStatsToEntry(entry, activeMon)
    if not entry or not activeMon then return end
    entry.active = true
    entry.health = activeMon.health
    entry.maxHealth = activeMon.maxHealth
    entry.energy = activeMon.energy
    entry.maxEnergy = activeMon.maxEnergy
    if activeMon.name then entry.name = activeMon.name end
    if activeMon.ident then entry.ident = activeMon.ident end
    if activeMon.maxHealth and activeMon.maxHealth > 0 then
        entry.healthFrac = (activeMon.health or 0) / activeMon.maxHealth
    end
    entry.fainted = activeMon.fainted == true
        or (type(activeMon.health) == "number" and activeMon.health <= 0)
end

local function syncPartyActiveFromBattler(party, activeMon)
    if type(party) ~= "table" then return end

    for slot, mon in pairs(party) do
        if mon then mon.active = false end
    end

    if not activeMon then return end

    local activeSlot = resolveActivePartySlot(activeMon, party)
    if activeSlot and party[activeSlot] then
        applyActiveMonStatsToEntry(party[activeSlot], activeMon)
        return activeSlot
    end

    return nil
end

copyPartyFromPacket = function(packet)
    local side = packet and packet.side
    if type(side) ~= "table" then return end
    local party = side.party or side.Party
    if type(party) ~= "table" then return end

    local activeMon = getActiveMon(packet)
    local out = {}
    local count = 0

    for _, key in ipairs(sortedKeys(party)) do
        local mon = idx(party, key)
        if type(mon) == "table" then
            local slotIndex = tonumber(mon.index) or tonumber(key)
            if slotIndex and slotIndex >= 1 and slotIndex <= TEAM_SLOT_TOTAL then
                out[slotIndex] = normalizePartyMon(mon, slotIndex, activeMon)
                count = count + 1
            end
        end
    end

    syncPartyActiveFromBattler(out, activeMon)

    state.party = out
    state.partySize = count
    state.activePartySlot = resolveActivePartySlot(activeMon, out)
end

applyPlayerSwitchByName = function(name, stats)
    if not name then return end
    for slot, mon in pairs(state.party) do
        if mon then
            mon.active = namesMatch(mon.name, name)
        end
    end
    local activeSlot = nil
    for slot, mon in pairs(state.party) do
        if mon and mon.active then
            activeSlot = slot
            break
        end
    end
    if not activeSlot then
        for slot, mon in pairs(state.party) do
            if mon and namesMatch(mon.name, name) then
                mon.active = true
                activeSlot = slot
                break
            end
        end
    end
    state.activePartySlot = activeSlot
    state.lead.name = name
    if stats then
        if stats.hp then state.lead.health = stats.hp end
        if stats.maxHp then state.lead.maxHealth = stats.maxHp end
    end
    if activeSlot and state.party[activeSlot] and stats then
        local mon = state.party[activeSlot]
        if stats.hp then mon.health = stats.hp end
        if stats.maxHp then mon.maxHealth = stats.maxHp end
        if stats.maxHp and stats.maxHp > 0 then
            mon.healthFrac = (stats.hp or 0) / stats.maxHp
        end
    end
end

local function formatPartyHp(mon)
    if not mon then return "" end
    if mon.health and mon.maxHealth then
        return string.format(" %d/%d", mon.health, mon.maxHealth)
    end
    if mon.healthFrac then
        return string.format(" %d%%", math.floor(mon.healthFrac * 100 + 0.5))
    end
    return ""
end

-- ===========================================================================
-- §5 Move scoring & effectiveness
-- ===========================================================================

local function inferLeadTypes(moves)
    local types, seen = {}, {}
    for i = 1, 4 do
        local mv = idx(moves, i)
        if type(mv) == "table" and type(mv.type) == "string" and not seen[mv.type] then
            seen[mv.type] = true
            types[#types + 1] = mv.type
        end
    end
    return types
end

local function getMoveEffectiveness(mv)
    if type(mv) == "table" and type(mv.effective) == "table" then
        return tonumber(idx(mv.effective, 1)) or 1
    end
    return 1
end

local function effectivenessShort(value)
    local n = tonumber(value) or 1
    if n >= 2 then return string.format("%.1fx SUPER", n) end
    if n <= 0 then return "0x IMMUNE" end
    if n <= 0.5 then return string.format("%.1fx WEAK", n) end
    return string.format("%.1fx", n)
end

local function effectivenessLong(value)
    local n = tonumber(value)
    if not n then return "?" end
    if n >= 2 then return string.format("%.1fx super effective", n) end
    if n <= 0 then return "0x immune" end
    if n <= 0.5 then return string.format("%.1fx not very effective", n) end
    return string.format("%.1fx neutral", n)
end

local function effectivenessColor(value)
    local n = tonumber(value) or 1
    if n >= 2 then return Color3.fromRGB(70, 220, 110) end
    if n <= 0 then return Color3.fromRGB(220, 70, 70) end
    if n <= 0.5 then return Color3.fromRGB(240, 170, 70) end
    return Color3.fromRGB(190, 200, 220)
end

local function selectBestMoveSlot(moves, currentEnergy)
    local bestSlot, bestScore, bestEnergy = nil, -1, math.huge
    for i = 1, 4 do
        local mv = idx(moves, i)
        if type(mv) == "table" and not mv.disabled then
            local cost = mv.energy or 0
            if currentEnergy >= cost then
                local score = getMoveEffectiveness(mv) * (mv.basePower or 0)
                if score > bestScore or (score == bestScore and cost < bestEnergy) then
                    bestScore, bestEnergy, bestSlot = score, cost, i
                end
            end
        end
    end
    return bestSlot, bestScore
end

local function projectedEnergyGain(actionKey, maxEnergy)
    local cfg = getPanelActionConfig(actionKey)
    if not cfg or not cfg.energyFraction or not maxEnergy then return 0 end
    return math.floor(maxEnergy * cfg.energyFraction + 0.5)
end

local function miscResultText(actionKey)
    local cfg = getPanelActionConfig(actionKey)
    if not cfg then return "?" end
    return cfg.summary
end

-- ===========================================================================
-- §6 Macro panel GUI
-- ===========================================================================

setStatus = function(text)
    state.lastResult.text = text
    if guiRefs.status then guiRefs.status.Text = text end
end

refreshGui = function()
    if not isActiveInstance() then return end
    if not guiRefs.panel or not guiRefs.panel.Parent then return end

    local lead = state.lead
    local typeStr = #lead.types > 0 and table.concat(lead.types, " / ") or "?"
    local bestSlot = selectBestMoveSlot(lead.moves, lead.energy or 0)

    if guiRefs.leadLine then
        local slotHint = state.activePartySlot and (" (slot " .. state.activePartySlot .. ")") or ""
        guiRefs.leadLine.Text = string.format("Lead%s: %s  |  %s  |  HP %d/%d  |  Energy %d/%d",
            slotHint, lead.name, typeStr, lead.health or 0, lead.maxHealth or 0, lead.energy or 0, lead.maxEnergy or 0)
    end

    for i = 1, 4 do
        local btn = guiRefs.moveButtons[i]
        if btn then
            local mv = idx(lead.moves, i)
            if type(mv) == "table" then
                local eff = getMoveEffectiveness(mv)
                local canUse = not mv.disabled and (lead.energy or 0) >= (mv.energy or 0)
                local tag = bestSlot == i and "★ " or ""
                btn.Text = string.format("%s[%d] %s  |  %s  |  %s  |  BP %d  |  E %d%s",
                    tag, i, mv.move or "?", mv.type or "?", effectivenessShort(eff),
                    mv.basePower or 0, mv.energy or 0,
                    mv.disabled and "  [DISABLED]" or "")
                btn.TextColor3 = canUse and effectivenessColor(eff) or Color3.fromRGB(100, 100, 110)
                btn.BackgroundColor3 = state.pendingSlot == i
                    and Color3.fromRGB(45, 55, 90)
                    or (bestSlot == i and Color3.fromRGB(28, 38, 32) or Color3.fromRGB(22, 24, 34))
                btn.AutoButtonColor = canUse and not state.executing
                btn.Active = canUse and not state.executing
            else
                btn.Text = string.format("[%d] (empty)", i)
                btn.TextColor3 = Color3.fromRGB(90, 90, 100)
                btn.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
                btn.Active = false
            end
        end
    end

    for actionKey, cfg in pairs(MISC_ACTIONS) do
        local btn = guiRefs.miscButtons and guiRefs.miscButtons[actionKey]
        if btn then
            local gain = projectedEnergyGain(actionKey, lead.maxEnergy or 0)
            local after = math.min((lead.energy or 0) + gain, lead.maxEnergy or 0)
            btn.Text = string.format("%s  |  %s  |  +%d E → %d/%d",
                cfg.label, cfg.summary, gain, after, lead.maxEnergy or 0)
            btn.TextColor3 = cfg.textColor
            btn.BackgroundColor3 = state.pendingAction == actionKey and Color3.fromRGB(45, 55, 90) or cfg.bgColor
            btn.AutoButtonColor = not state.executing
            btn.Active = not state.executing
        end
    end

    local loomBtn = guiRefs.teamButtons and guiRefs.teamButtons.loomians
    if loomBtn then
        local loomCfg = TEAM_ACTIONS.loomians
        local partyCount = state.partySize or 0
        loomBtn.Text = string.format("%s  |  %s  |  team %d (switch slots %d-%d)",
            loomCfg.label, loomCfg.summary, partyCount, BATTLE_SWITCH_SLOT_MIN, BATTLE_SWITCH_SLOTS)
        loomBtn.TextColor3 = loomCfg.textColor
        loomBtn.BackgroundColor3 = state.pendingAction == "loomians"
            and Color3.fromRGB(45, 55, 90) or loomCfg.bgColor
        loomBtn.AutoButtonColor = not state.executing
        loomBtn.Active = not state.executing
    end

    for i = 1, TEAM_SLOT_TOTAL do
        local slotBtn = guiRefs.teamButtons and guiRefs.teamButtons[i]
        local mon = state.party[i]
        if slotBtn then
            local benched = not isBattleSwitchSlot(i)
            local isLead = (i == 1) or (state.activePartySlot == i) or (mon and mon.active)
            if mon then
                local tag = mon.fainted and " [FAINT]"
                    or (isLead and " [LEAD]" or "")
                tag = tag .. (benched and " [BENCH]" or "")
                slotBtn.Text = string.format("[%d] %s%s%s", i, mon.name, formatPartyHp(mon), tag)
                slotBtn.TextColor3 = benched and Color3.fromRGB(90, 90, 100)
                    or (mon.fainted and Color3.fromRGB(140, 90, 90)
                    or (isLead and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(180, 190, 210)))
            else
                slotBtn.Text = string.format("[%d] %s", i, benched and "bench" or (i == 1 and "lead" or "---"))
                slotBtn.TextColor3 = benched and Color3.fromRGB(80, 80, 90) or Color3.fromRGB(100, 100, 110)
            end
            local canSwitch = isBattleSwitchSlot(i) and not isActiveLeadSlot(i) and not state.executing
                and mon and not mon.fainted
            slotBtn.Active = canSwitch
            slotBtn.AutoButtonColor = canSwitch
            slotBtn.BackgroundColor3 = state.pendingSlot == i and Color3.fromRGB(45, 55, 90)
                or (benched and Color3.fromRGB(18, 18, 24) or Color3.fromRGB(24, 26, 36))
        end
    end

    if guiRefs.resultLine then
        local r = state.lastResult
        if r.move and r.effectiveness then
            if r.move == "Wait" or r.move == "Rest" then
                guiRefs.resultLine.Text = string.format("In-game: %s → %s", r.move, r.effectiveness)
            else
                guiRefs.resultLine.Text = string.format("In-game: %s → %s%s",
                    r.move, r.effectiveness,
                    r.damage and (" | " .. r.damage .. " dmg") or "")
            end
        else
            guiRefs.resultLine.Text = r.text or "Click a move, Wait, Rest, or Loomians on your turn"
        end
    end
end

createGui = function()
    local existing = playerGui:FindFirstChild("BattleMoveMacroGui")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BattleMoveMacroGui"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 50
    sg.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.new(0, 480, 0, 432)
    panel.Position = UDim2.new(1, -492, 0, 12)
    panel.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
    panel.BorderSizePixel = 0
    panel.Parent = sg
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 22)
    title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(240, 240, 250)
    title.Text = "Battle Panel (" .. SCRIPT_VERSION .. ") — moves, Wait, Rest, Loomians"
    title.Parent = panel

    guiRefs.leadLine = Instance.new("TextLabel")
    guiRefs.leadLine.Size = UDim2.new(1, -10, 0, 34)
    guiRefs.leadLine.Position = UDim2.new(0, 8, 0, 30)
    guiRefs.leadLine.BackgroundTransparency = 1
    guiRefs.leadLine.Font = Enum.Font.Gotham
    guiRefs.leadLine.TextSize = 11
    guiRefs.leadLine.TextXAlignment = Enum.TextXAlignment.Left
    guiRefs.leadLine.TextYAlignment = Enum.TextYAlignment.Top
    guiRefs.leadLine.TextWrapped = true
    guiRefs.leadLine.TextColor3 = Color3.fromRGB(200, 210, 230)
    guiRefs.leadLine.Text = "Lead: waiting..."
    guiRefs.leadLine.Parent = panel

    guiRefs.moveButtons = {}
    for i = 1, 4 do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -16, 0, 36)
        btn.Position = UDim2.new(0, 8, 0, 68 + (i - 1) * 40)
        btn.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Code
        btn.TextSize = 11
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = Color3.fromRGB(180, 190, 210)
        btn.Text = string.format("[%d] ---", i)
        btn.AutoButtonColor = true
        btn.Parent = panel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local pad = Instance.new("UIPadding", btn)
        pad.PaddingLeft = UDim.new(0, 8)
        guiRefs.moveButtons[i] = btn
    end

    guiRefs.miscButtons = {}
    local miscKeys = { "wait", "rest" }
    for i, actionKey in ipairs(miscKeys) do
        local cfg = MISC_ACTIONS[actionKey]
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.5, -12, 0, 34)
        btn.Position = UDim2.new((i - 1) * 0.5, 8, 0, 232)
        btn.BackgroundColor3 = cfg.bgColor
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextColor3 = cfg.textColor
        btn.Text = cfg.label
        btn.AutoButtonColor = true
        btn.Parent = panel
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        local pad = Instance.new("UIPadding", btn)
        pad.PaddingLeft = UDim.new(0, 8)
        guiRefs.miscButtons[actionKey] = btn
    end

    guiRefs.teamButtons = {}
    local loomCfg = TEAM_ACTIONS.loomians
    local loomBtn = Instance.new("TextButton")
    loomBtn.Size = UDim2.new(1, -16, 0, 34)
    loomBtn.Position = UDim2.new(0, 8, 0, 272)
    loomBtn.BackgroundColor3 = loomCfg.bgColor
    loomBtn.BorderSizePixel = 0
    loomBtn.Font = Enum.Font.GothamBold
    loomBtn.TextSize = 10
    loomBtn.TextXAlignment = Enum.TextXAlignment.Left
    loomBtn.TextColor3 = loomCfg.textColor
    loomBtn.Text = loomCfg.label .. "  |  " .. loomCfg.summary
    loomBtn.AutoButtonColor = true
    loomBtn.Parent = panel
    Instance.new("UICorner", loomBtn).CornerRadius = UDim.new(0, 6)
    local loomPad = Instance.new("UIPadding", loomBtn)
    loomPad.PaddingLeft = UDim.new(0, 8)
    guiRefs.teamButtons.loomians = loomBtn

    local battleRow = Instance.new("TextLabel")
    battleRow.Size = UDim2.new(1, -16, 0, 14)
    battleRow.Position = UDim2.new(0, 8, 0, 310)
    battleRow.BackgroundTransparency = 1
    battleRow.Font = Enum.Font.Gotham
    battleRow.TextSize = 9
    battleRow.TextXAlignment = Enum.TextXAlignment.Left
    battleRow.TextColor3 = Color3.fromRGB(140, 150, 170)
    battleRow.Text = string.format("Battle switch (slots %d-%d — slot 1 is lead):",
        BATTLE_SWITCH_SLOT_MIN, BATTLE_SWITCH_SLOTS)
    battleRow.Parent = panel

    for i = 1, BATTLE_SWITCH_SLOTS do
        local slotBtn = Instance.new("TextButton")
        slotBtn.Size = UDim2.new(1 / BATTLE_SWITCH_SLOTS, -10, 0, 28)
        slotBtn.Position = UDim2.new((i - 1) / BATTLE_SWITCH_SLOTS, 8 + (i - 1) * 2, 0, 326)
        slotBtn.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
        slotBtn.BorderSizePixel = 0
        slotBtn.Font = Enum.Font.Code
        slotBtn.TextSize = 9
        slotBtn.TextColor3 = Color3.fromRGB(120, 120, 130)
        slotBtn.Text = string.format("[%d] ---", i)
        slotBtn.AutoButtonColor = false
        slotBtn.Active = false
        slotBtn.Parent = panel
        Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 4)
        guiRefs.teamButtons[i] = slotBtn
    end

    local benchRow = Instance.new("TextLabel")
    benchRow.Size = UDim2.new(1, -16, 0, 14)
    benchRow.Position = UDim2.new(0, 8, 0, 358)
    benchRow.BackgroundTransparency = 1
    benchRow.Font = Enum.Font.Gotham
    benchRow.TextSize = 9
    benchRow.TextXAlignment = Enum.TextXAlignment.Left
    benchRow.TextColor3 = Color3.fromRGB(100, 100, 110)
    benchRow.Text = string.format("Benched (slots %d-%d, not switchable in battle):",
        BATTLE_SWITCH_SLOTS + 1, TEAM_SLOT_TOTAL)
    benchRow.Parent = panel

    for i = BATTLE_SWITCH_SLOTS + 1, TEAM_SLOT_TOTAL do
        local slotBtn = Instance.new("TextButton")
        local benchIndex = i - BATTLE_SWITCH_SLOTS
        local benchTotal = TEAM_SLOT_TOTAL - BATTLE_SWITCH_SLOTS
        slotBtn.Size = UDim2.new(1 / benchTotal, -10, 0, 24)
        slotBtn.Position = UDim2.new((benchIndex - 1) / benchTotal, 8 + (benchIndex - 1) * 2, 0, 374)
        slotBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        slotBtn.BorderSizePixel = 0
        slotBtn.Font = Enum.Font.Code
        slotBtn.TextSize = 9
        slotBtn.TextColor3 = Color3.fromRGB(80, 80, 90)
        slotBtn.Text = string.format("[%d] bench", i)
        slotBtn.AutoButtonColor = false
        slotBtn.Active = false
        slotBtn.Parent = panel
        Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 4)
        guiRefs.teamButtons[i] = slotBtn
    end

    guiRefs.status = Instance.new("TextLabel")
    guiRefs.status.Size = UDim2.new(1, -10, 0, 44)
    guiRefs.status.Position = UDim2.new(0, 8, 1, -52)
    guiRefs.status.BackgroundTransparency = 1
    guiRefs.status.Font = Enum.Font.GothamBold
    guiRefs.status.TextSize = 11
    guiRefs.status.TextXAlignment = Enum.TextXAlignment.Left
    guiRefs.status.TextYAlignment = Enum.TextYAlignment.Top
    guiRefs.status.TextWrapped = true
    guiRefs.status.TextColor3 = Color3.fromRGB(255, 210, 120)
    guiRefs.status.Text = "Waiting..."
    guiRefs.status.Parent = panel
    guiRefs.resultLine = guiRefs.status

    guiRefs.panel = panel
    guiRefs.screenGui = sg
    refreshGui()
end

-- ===========================================================================
-- §7 Game GUI click helpers
-- ===========================================================================

do -- §7-§8 isolated scope (Luau 200 local register limit)
local isEffectivelyVisible, isButtonClickable, safeGuiText, guiButtonHasLabel, isFromMacroGui, isLooselyVisible, isClickableGui, getClickableGuiObject, isSpotReadyForClick, resolveLoomiansClickTarget, isTopLevelBattlePanelChild, panelMatchesLoomians, panelIsOtherBattleSideButton, filterFlatSidePanelsForLoomians, absoluteGuiPoint, toVimCoords, toHighlightCoords, vimCenterOf, screenToVimCoords, vimCenterOfTarget, invokeGuiClick, clickAtCoords, isValidClickTarget, clickGuiTarget, rbxIdsMatch, getBattleMenuImageLabel, findMainGuiButtonByName, findVisibleBattleButton, resolveGuiButton, getBattleActionMenuRoot, buttonMatchesAction, findNodeByChain, isInnerWaitProbedButton, isOuterBattleMenuButton, getGuiImageAssetId, isFightSubmenuOpen, isFightLikePanel, getFightPanelImageLabel, getTopLevelImageLabelPanels, pickPanelEntry, getFlatSidePanels, resolveWaitButton, isProbedPanelButton, optionalRbxNote, hasConflictingLabel, guiObjectMatchesAction, resolveProbedActionButton, getFrontGui, waitForMiscActionRow, findMiscLabelTarget, waitForMiscActionPair, waitForMiscActionNode, getMiscRowSlotCenter, buildPairFromRow, findBattleMenuAction, findFightButton, appendCommonClickSpots, miscSpotFromRow, miscSpotFromLabel, buildMiscSpot, clickMiscNumberedButton, buildMiscActionSpots
isEffectivelyVisible = function(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if not obj.Visible then return false end
    local current = obj.Parent
    while current and current:IsA("GuiObject") do
        if not current.Visible then return false end
        current = current.Parent
    end
    local screenGui = obj:FindFirstAncestorOfClass("ScreenGui")
    return screenGui and screenGui.Enabled
end

isButtonClickable = function(btn)
    if not btn or not isEffectivelyVisible(btn) then return false end
    local size = btn.AbsoluteSize
    if size.X < UI_MIN_BUTTON_SIZE or size.Y < UI_MIN_BUTTON_SIZE then return false end
    local pos = btn.AbsolutePosition
    if pos.X <= 0 and pos.Y <= 0 then return false end
    return true
end

safeGuiText = function(obj)
    if not obj then return "" end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return tostring(obj.Text or "")
    end

    local best = ""
    for _, desc in obj:GetDescendants() do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local t = tostring(desc.Text or "")
            local n = normalizeLabel(t)
            if n == "i" or n == "?" or n == "" then
                -- skip info icon labels
            elseif #t > #best then
                best = t
            end
        end
    end
    if best ~= "" then return best end

    local label = obj:FindFirstChildWhichIsA("TextLabel", true)
    if label then return tostring(label.Text or "") end
    return ""
end

guiButtonHasLabel = function(btn, wantedLabel)
    if not btn then return false end
    wantedLabel = normalizeLabel(wantedLabel)
    if wantedLabel == "" then return false end
    if normalizeLabel(btn.Name) == wantedLabel then return true end
    if normalizeLabel(safeGuiText(btn)) == wantedLabel then return true end
    for _, desc in btn:GetDescendants() do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            if normalizeLabel(desc.Text) == wantedLabel then return true end
        end
    end
    return false
end

isFromMacroGui = function(obj)
    local sg = obj and obj:FindFirstAncestorOfClass("ScreenGui")
    return sg and sg.Name == "BattleMoveMacroGui"
end

isLooselyVisible = function(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if not obj.Visible then return false end
    local size = obj.AbsoluteSize
    return size.X >= 2 and size.Y >= 2
end

-- Visible on screen — do NOT require AbsoluteSize (ImageLabel .2/.4 often reports 0 until layout)
isOnScreen = function(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if not obj.Visible then return false end
    if not obj.Parent then return false end
    local sg = obj:FindFirstAncestorOfClass("ScreenGui")
    if sg and not sg.Enabled then return false end
    return true
end

isClickableGui = function(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if isFromMacroGui(obj) then return false end
    return isOnScreen(obj)
end

getClickableGuiObject = function(obj)
    if not obj then return nil end
    local current = obj
    for _ = 1, 8 do
        if not current or not current:IsA("GuiObject") then break end
        local s = current.AbsoluteSize
        if s.X >= 4 and s.Y >= 4 then return current end
        current = current.Parent
    end
    return obj:IsA("GuiObject") and obj or nil
end

resolveLoomiansClickTarget = function(panelEntry)
    if not panelEntry then return nil end
    if panelEntry.button and isOnScreen(panelEntry.button) then
        return panelEntry.button
    end
    local panel = panelEntry.panel
    if panel and isOnScreen(panel) then
        return resolveGuiButton(panel) or panel
    end
    return nil
end

-- Loomians side panels often fail strict ready checks (zero-size Button, layout lag)
isSpotReadyForClick = function(spot)
    if type(spot) ~= "table" then return false end
    if spot.kind == "point" or (spot.x and spot.y and not spot.button) then return true end
    if spot.screenX and spot.screenY then return true end
    if not spot.button or not spot.button.Parent then return false end

    local relaxed = spot.kind == "loomians"
    if relaxed then
        return isClickableGui(spot.button) and getSpotCoords(spot, true) ~= nil
    end
    return isGuiReadyForClick(spot.button) and getSpotCoords(spot, true) ~= nil
end

-- Stricter than isOnScreen — ancestor chain visible, ScreenGui enabled, valid click coords
isGuiReadyForClick = function(obj)
    if not obj or not obj:IsA("GuiObject") then return false end
    if isFromMacroGui(obj) then return false end
    if not isEffectivelyVisible(obj) then return false end
    if not isOnScreen(obj) then return false end

    local clickObj = getClickableGuiObject(obj) or obj
    if not clickObj or not clickObj.Parent then return false end
    if clickObj:IsA("GuiButton") and clickObj.Active == false then return false end

    local gx, gy = absoluteGuiPoint(clickObj, 0.5, 0.5)
    if not gx or not gy then return false end

    local pos = clickObj.AbsolutePosition
    if pos.X <= 0 and pos.Y <= 0 and gx <= 1 and gy <= 1 then return false end

    local vimX, vimY = toVimCoords(gx, gy, clickObj)
    return vimX ~= nil and vimY ~= nil
end

waitForGuiReady = function(obj, timeoutSec)
    if not obj then return false end
    timeoutSec = timeoutSec or GUI_READY_WAIT
    local deadline = tick() + timeoutSec
    while tick() < deadline do
        if isGuiReadyForClick(obj) then return true end
        task.wait(GUI_READY_POLL)
    end
    return isGuiReadyForClick(obj)
end

waitForSpotReady = function(spot, timeoutSec)
    if type(spot) ~= "table" then return false end
    if spot.kind == "point" or (spot.x and spot.y and not spot.button) then
        return true
    end

    timeoutSec = timeoutSec or GUI_READY_WAIT
    local deadline = tick() + timeoutSec
    while tick() < deadline do
        if isSpotReadyForClick(spot) then return true end
        task.wait(GUI_READY_POLL)
    end
    return isSpotReadyForClick(spot)
end

waitForButtonFinder = function(findFn, timeoutSec, relaxReady)
    if type(findFn) ~= "function" then return nil end
    timeoutSec = timeoutSec or GUI_READY_WAIT
    local deadline = tick() + timeoutSec
    local lastBtn = nil
    while tick() < deadline do
        local btn = findFn()
        if btn then
            lastBtn = btn
            if relaxReady or isGuiReadyForClick(btn) then return btn end
            if relaxReady and isClickableGui(btn) then return btn end
        end
        task.wait(GUI_READY_POLL)
    end
    if lastBtn and (relaxReady or isGuiReadyForClick(lastBtn)) then return lastBtn end
    if lastBtn and relaxReady and isClickableGui(lastBtn) then return lastBtn end
    return lastBtn
end

guiCenterOf = function(btn)
    local pos = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    return math.floor(pos.X + size.X / 2 + 0.5),
        math.floor(pos.Y + size.Y / 2 + 0.5),
        size.X, size.Y
end

absoluteGuiPoint = function(obj, relX, relY)
    obj = getClickableGuiObject(obj) or obj
    if not obj or not obj:IsA("GuiObject") then return nil, nil end
    relX = relX or 0.5
    relY = relY or 0.5
    local pos = obj.AbsolutePosition
    local size = obj.AbsoluteSize
    return pos.X + size.X * relX, pos.Y + size.Y * relY
end

-- Convert GUI absolute point → VIM screen pixels (must match yellow highlight circles)
toVimCoords = function(guiX, guiY, refObj)
    if clickMode == "raw" then
        return math.floor(guiX + clickOffsets.x + 0.5), math.floor(guiY + clickOffsets.y + 0.5)
    end
    if clickMode == "inset" then
        local cx, cy = guiX, guiY
        local screenGui = refObj and refObj:FindFirstAncestorOfClass("ScreenGui")
        if screenGui and not screenGui.IgnoreGuiInset then
            local inset = GuiService:GetGuiInset()
            cx = cx + inset.X
            cy = cy + inset.Y
        end
        return math.floor(cx + clickOffsets.x + 0.5), math.floor(cy + clickOffsets.y + 0.5)
    end
    -- highlight mode (default): same math as overlay markers
    return math.floor(guiX + highlightOffsets.x + clickOffsets.x + 0.5),
        math.floor(guiY + highlightOffsets.y + clickOffsets.y + 0.5)
end

toHighlightCoords = function(guiX, guiY)
    return math.floor(guiX + highlightOffsets.x + 0.5),
        math.floor(guiY + highlightOffsets.y + 0.5)
end

-- VIM uses full-screen coords — add GuiInset when the button's ScreenGui doesn't ignore it
vimCenterOf = function(btn)
    local cx, cy, sx, sy = guiCenterOf(btn)
    return toVimCoords(cx, cy, btn)[1], toVimCoords(cx, cy, btn)[2], sx, sy
end

screenToVimCoords = function(sx, sy, refObj)
    return toVimCoords(sx, sy, refObj)
end

vimCenterOfTarget = function(obj, relX, relY)
    local gx, gy = absoluteGuiPoint(obj, relX, relY)
    if not gx then return nil, nil, 1, 1 end
    local cx, cy = toVimCoords(gx, gy, obj)
    local size = (getClickableGuiObject(obj) or obj).AbsoluteSize
    return cx, cy, math.max(size.X, 1), math.max(size.Y, 1)
end

getSpotCoords = function(spot, forVim)
    if spot.screenX and spot.screenY then
        if forVim then
            return screenToVimCoords(spot.screenX, spot.screenY, spot.button)
        end
        return toHighlightCoords(spot.screenX, spot.screenY)
    end
    if spot.button and spot.button.Parent and isOnScreen(spot.button) then
        local relX = spot.relX or 0.5
        local relY = spot.relY or 0.5
        local clickObj = getClickableGuiObject(spot.button) or spot.button
        local gx, gy = absoluteGuiPoint(clickObj, relX, relY)
        if not gx then return nil, nil end
        if forVim then
            return toVimCoords(gx, gy, clickObj)
        end
        return toHighlightCoords(gx, gy)
    end
    if spot.x and spot.y then
        if forVim then
            return toVimCoords(spot.x, spot.y, nil)
        end
        return toHighlightCoords(spot.x, spot.y)
    end
    return nil, nil
end

invokeGuiClick = function(clickObj)
    if not clickObj or not clickObj.Parent or not clickObj:IsA("GuiObject") then return false end
    if isFromMacroGui(clickObj) then return false end
    local clickBtn = clickObj:IsA("GuiButton") and clickObj or clickObj:FindFirstAncestorWhichIsA("GuiButton")
    if not clickBtn and clickObj:IsA("ImageButton") then
        clickBtn = clickObj
    end
    if not clickBtn then
        clickBtn = clickObj:FindFirstChildWhichIsA("GuiButton", true)
    end
    if not clickBtn or not clickBtn.Parent or not isOnScreen(clickBtn) then return false end

    local fired = false
    pcall(function()
        if typeof(firesignal) == "function" then
            firesignal(clickBtn.MouseButton1Down)
            firesignal(clickBtn.MouseButton1Click)
            firesignal(clickBtn.MouseButton1Up)
            fired = true
        end
    end)
    pcall(function()
        if not fired and typeof(clickBtn.Activate) == "function" then
            clickBtn:Activate()
            fired = true
        end
    end)
    pcall(function()
        if not fired and typeof(getconnections) == "function" then
            for _, conn in ipairs(getconnections(clickBtn.MouseButton1Click)) do
                conn:Fire()
                fired = true
            end
        end
    end)
    return fired
end

clickAtCoords = function(x, y)
    x = math.floor((x or 0) + 0.5)
    y = math.floor((y or 0) + 0.5)

    -- VIM is primary — icigool-style; always run (don't bail after mouse1click)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(VIM_DOWN_UP_GAP)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    pcall(function()
        if typeof(mouse1click) == "function" then
            mouse1click(x, y)
        end
    end)

    pcall(function()
        if typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
            mouse1press(x, y)
            task.wait(VIM_DOWN_UP_GAP)
            mouse1release(x, y)
        end
    end)
end

isValidClickTarget = function(obj)
    if not isClickableGui(obj) then return false end
    local clickObj = getClickableGuiObject(obj) or obj
    return isClickableGui(clickObj)
end

clickGuiTarget = function(obj, relX, relY)
    if not isClickableGui(obj) then
        return false
    end

    local cx, cy = vimCenterOfTarget(obj, relX, relY)
    local clickObj = getClickableGuiObject(obj) or obj
    local signaled = invokeGuiClick(clickObj)
    clickAtCoords(cx, cy)
    return signaled or (cx and cy)
end

clickGuiButton = function(btn)
    return clickGuiTarget(btn, 0.5, 0.5)
end

clickSpot = function(spot)
    if type(spot) ~= "table" then
        Err.report(Err.make(Err.codes.CLICK_FAILED, "clickSpot called with invalid spot", {}))
        return false
    end
    if not Err.checkHelper("getSpotCoords", getSpotCoords) then return false end
    if not Err.checkHelper("isClickableGui", isClickableGui) then return false end
    if not Err.checkHelper("invokeGuiClick", invokeGuiClick) then return false end
    if not Err.checkHelper("clickAtCoords", clickAtCoords) then return false end

    if not waitForSpotReady(spot, GUI_READY_WAIT) then
        Err.report(Err.make(Err.codes.CLICK_FAILED, "Spot not visible yet — skipped click", {
            spot = spot.name or "?",
            kind = spot.kind or "?",
        }), { refresh = false })
        return false
    end

    local x, y = getSpotCoords(spot, true)
    if not x or not y then
        Err.report(Err.make(Err.codes.CLICK_COORDS_MISSING, "No click coordinates for spot", {
            spot = spot.name or "?",
            kind = spot.kind or "?",
            mode = clickMode,
        }), { refresh = false })
        return false
    end

    local canSignal = spot.button and (
        isGuiReadyForClick(spot.button)
        or (spot.kind == "loomians" and isClickableGui(spot.button))
    )
    if canSignal then
        local clickObj = getClickableGuiObject(spot.button) or spot.button
        invokeGuiClick(clickObj)
    end

    task.wait(0.03)
    clickAtCoords(x, y)
    return true
end

getBattleGui = function()
    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        local direct = mainGui:FindFirstChild("BattleGui")
        if direct then return direct end
        local frame = mainGui:FindFirstChild("Frame")
        if frame then
            direct = frame:FindFirstChild("BattleGui")
            if direct then return direct end
        end
        direct = mainGui:FindFirstChild("BattleGui", true)
        if direct then return direct end
    end
    return playerGui:FindFirstChild("BattleGui", true)
end

waitForBattleGui = function(timeoutSec)
    timeoutSec = timeoutSec or BATTLE_GUI_WAIT
    local deadline = tick() + timeoutSec
    local bGui = getBattleGui()
    while not bGui and tick() < deadline do
        task.wait(0.08)
        bGui = getBattleGui()
    end
    return bGui
end

getRbxId = function(obj)
    if typeof(obj) ~= "Instance" then return "?" end
    local ok, debugId = pcall(function() return obj:GetDebugId() end)
    if ok and debugId and tostring(debugId) ~= "" then return tostring(debugId) end
    if typeof(gethiddenproperty) == "function" then
        ok, debugId = pcall(function() return gethiddenproperty(obj, "DebugId") end)
        if ok and debugId and tostring(debugId) ~= "" then return tostring(debugId) end
    end
    local hex = tostring(obj):match("(0x[%x]+)")
    if hex then return hex end
    return tostring(obj)
end

rbxIdsMatch = function(obj, expectedId)
    if not obj or not expectedId or expectedId == "" then return false end
    local actual = getRbxId(obj)
    if actual == expectedId then return true end
    local aSuffix = actual:match("_(%d+)$") or actual:match("(%d+)$")
    local eSuffix = expectedId:match("_(%d+)$") or expectedId:match("(%d+)$")
    if aSuffix and eSuffix and aSuffix == eSuffix then return true end
    return actual:find(expectedId, 1, true) ~= nil or expectedId:find(actual, 1, true) ~= nil
end

shortRbxId = function(rbxid)
    rbxid = tostring(rbxid or "?")
    if #rbxid > 12 then return rbxid:sub(-10) end
    return rbxid
end

getBattleMenuImageLabel = function()
    local bGui = getBattleGui()
    if not bGui then return nil end
    local outer = bGui:FindFirstChild("ImageLabel", false)
    if outer then
        local inner = outer:FindFirstChild("ImageLabel")
        if inner then return inner end
    end
    return bGui:FindFirstChild("ImageLabel", true)
end

findMainGuiButtonByName = function(name)
    local mainGui = playerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end
    local found = mainGui:FindFirstChild(name, true)
    if not found then return nil end
    if found:IsA("GuiButton") then return found end
    return found:FindFirstChildWhichIsA("GuiButton", true)
end

findVisibleBattleButton = function(matchFn)
    for _, root in ipairs({ getBattleGui(), playerGui:FindFirstChild("MainGui") }) do
        if root then
            for _, desc in root:GetDescendants() do
                if not isFromMacroGui(desc) and desc:IsA("GuiButton")
                    and (isLooselyVisible(desc) or isOnScreen(desc)) then
                    local ok, matched = pcall(matchFn, desc)
                    if ok and matched then return desc end
                end
            end
        end
    end
    return nil
end

findMoveButton = function(slot)
    local names = { "Move" .. slot, "move" .. slot }
    local bGui = getBattleGui()

    if bGui then
        local fightPanel = getFightPanelImageLabel(bGui)
        if fightPanel then
            for _, name in ipairs(names) do
                local node = fightPanel:FindFirstChild(name, true)
                if node and isClickableGui(node) then
                    return resolveGuiButton(node) or node
                end
            end
        end
        for _, name in ipairs(names) do
            local node = bGui:FindFirstChild(name, true)
            if node and isClickableGui(node) then
                return resolveGuiButton(node) or node
            end
        end
    end

    for _, name in ipairs(names) do
        local btn = findMainGuiButtonByName(name)
        if btn and isClickableGui(btn) then return btn end
        btn = findVisibleBattleButton(function(d) return d.Name == name end)
        if btn then return btn end
    end
    return nil
end

findMoveButtonByName = function(moveName, moveId)
    if not moveName and not moveId then return nil end
    local needleA = moveName and string.lower(moveName) or nil
    local needleB = moveId and string.lower(moveId) or nil
    return findVisibleBattleButton(function(d)
        local n = string.lower(d.Name)
        local t = string.lower(safeGuiText(d))
        if needleA and (n:find(needleA, 1, true) or t:find(needleA, 1, true)) then return true end
        if needleB and (n:find(needleB, 1, true) or t:find(needleB, 1, true)) then return true end
        return false
    end)
end

resolveGuiButton = function(node)
    if not node then return nil end
    if node:IsA("GuiButton") then return node end
    if node:IsA("GuiObject") then
        local direct = node:FindFirstChildWhichIsA("GuiButton", false)
        if direct then return direct end
        local deep = node:FindFirstChildWhichIsA("GuiButton", true)
        if deep then return deep end
        if isClickableGui(node) then return node end
    end
    return nil
end

getBattleActionMenuRoot = function()
    local inner = getBattleMenuImageLabel()
    if inner then return inner end

    local bGui = getBattleGui()
    if not bGui then return nil end

    local buttonNode = bGui:FindFirstChild("Button", true)
    local btn = resolveGuiButton(buttonNode)
    if btn and btn.Parent then return btn.Parent end

    return bGui
end

buttonMatchesAction = function(btn, needles, exactNames)
    if not btn then return false end
    local n = string.lower(btn.Name)
    local t = string.lower(safeGuiText(btn))
    for _, exact in ipairs(exactNames or {}) do
        local e = string.lower(exact)
        if n == e or t == e then return true end
    end
    for _, needle in ipairs(needles or {}) do
        if n:find(needle, 1, true) or t:find(needle, 1, true) then return true end
    end
    return false
end

local BATTLE_MENU_LOOKUP = {
    fight = {
        label = "Fight",
        exactNames = { "Button", "Fight", "Fight1", "Fight2", "Fight3" },
        needles = { "fight" },
    },
    wait = {
        label = "Wait",
        exactNames = { "Wait", "Wait1", "Wait2", "Wait3" },
        needles = { "wait" },
    },
    rest = {
        label = "Rest",
        exactNames = { "Rest", "Rest1", "Rest2", "Rest3" },
        needles = { "rest" },
    },
    loomians = {
        label = "Loomians",
        exactNames = { "Loomians", "Loomian", "Switch", "Switch1", "Pokemon" },
        needles = { "loomian", "switch", "team" },
    },
}

-- Side panels that are NOT Loomians (Fight | Items | Run | Loomians left-to-right)
local LOOMIANS_SIDE_EXCLUDE = {
    "fight", "items", "item", "bag", "run", "flee", "escape", "wait", "rest",
}

-- Row under ImageLabel (skip unreliable leaf nodes .4 / .2 — click row slots instead)
--   Wait = slot 1 (left), Rest = slot 2 (right) on Frame.Frame.Frame
local MISC_ROW_CHAIN = { "Frame", "Frame", "Frame" }
local MISC_SLOT_NUMBER = { wait = 1, rest = 2 }

isTopLevelBattlePanelChild = function(child)
    if not child or not child:IsA("GuiObject") then return false end
    if child.Name == "ImageLabel" then return true end
    if child:IsA("ImageButton") or child:IsA("TextButton") then return true end
    for _, name in ipairs({ "Fight", "Items", "Item", "Bag", "Run", "Loomians", "Loomian", "Switch" }) do
        if child.Name == name then return true end
    end
    return false
end

panelMatchesLoomians = function(panel)
    if not panel then return false end
    local lookup = BATTLE_MENU_LOOKUP.loomians
    if not lookup then return false end

    if normalizeLabel(panel.Name) == "loomians" or normalizeLabel(panel.Name) == "loomian" then
        return true
    end

    for _, desc in panel:GetDescendants() do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local t = normalizeLabel(desc.Text)
            for _, name in ipairs(lookup.exactNames) do
                if t == normalizeLabel(name) then return true end
            end
            for _, needle in ipairs(lookup.needles) do
                if t:find(needle, 1, true) then return true end
            end
        end
        if desc:IsA("GuiObject") then
            local n = normalizeLabel(desc.Name)
            for _, name in ipairs(lookup.exactNames) do
                if n == normalizeLabel(name) then return true end
            end
        end
    end
    return false
end

panelIsOtherBattleSideButton = function(panel)
    if not panel then return false end
    if panelMatchesLoomians(panel) then return false end

    for _, desc in panel:GetDescendants() do
        local bits = {
            normalizeLabel(desc.Name),
            normalizeLabel(safeGuiText(desc)),
        }
        for _, bit in ipairs(bits) do
            if bit ~= "" then
                for _, ex in ipairs(LOOMIANS_SIDE_EXCLUDE) do
                    if bit == ex or bit:find(ex, 1, true) then return true end
                end
            end
        end
    end

    local n = normalizeLabel(panel.Name)
    for _, ex in ipairs(LOOMIANS_SIDE_EXCLUDE) do
        if n == ex or n:find(ex, 1, true) then return true end
    end
    return false
end

filterFlatSidePanelsForLoomians = function(flatSide)
    local filtered = {}
    for _, p in ipairs(flatSide or {}) do
        if p.panel and panelMatchesLoomians(p.panel) then
            filtered[#filtered + 1] = p
        end
    end
    if #filtered > 0 then return filtered end

    for _, p in ipairs(flatSide or {}) do
        if p.panel and not panelIsOtherBattleSideButton(p.panel) then
            filtered[#filtered + 1] = p
        end
    end
    if #filtered > 0 then return filtered end

    return flatSide or {}
end

findNodeByChain = function(root, chain)
    local node = root
    for _, name in ipairs(chain) do
        node = node and node:FindFirstChild(name)
    end
    return node
end

isInnerWaitProbedButton = function(btn)
    if not btn then return false end
    local p = btn.Parent
    local gp = p and p.Parent
    local ggp = gp and gp.Parent
    return p and p.Name == "ImageLabel"
        and gp and gp.Name == "ImageLabel"
        and ggp and (ggp.Name == "BattleGui" or ggp.Name == "ImageLabel")
end

isOuterBattleMenuButton = function(btn)
    if not btn or btn.Name ~= "Button" then return false end
    local p = btn.Parent
    local gp = p and p.Parent
    return p and p.Name == "ImageLabel" and gp and gp.Name == "BattleGui"
end

-- ===========================================================================
-- §8 Battle panel discovery & probes
-- ===========================================================================

getGuiImageAssetId = function(obj)
    if not obj then return nil end
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        local img = obj.Image
        if img and img ~= "" then return tostring(img) end
    end
    for _, desc in obj:GetDescendants() do
        if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
            local img = desc.Image
            if img and img ~= "" then return tostring(img) end
        end
    end
    return nil
end

isFightSubmenuOpen = function(fightPanel)
    if not fightPanel then return false end
    local waitBtn = findNodeByChain(fightPanel, { "ImageLabel", "ImageLabel", "Button" })
    if waitBtn and isOnScreen(waitBtn) then return true end
    local inner = fightPanel:FindFirstChild("ImageLabel")
    return inner and inner:IsA("GuiObject") and inner.Visible and isOnScreen(inner)
end

isFightLikePanel = function(panel)
    if not panel then return false end
    if panel:FindFirstChild("Move1", true) or panel:FindFirstChild("Move2", true) then return true end
    if isFightSubmenuOpen(panel) then return true end
    local actionBtn = findNodeByChain(panel, { "ImageLabel", "ImageLabel", "Button" })
    return actionBtn ~= nil and isOnScreen(actionBtn)
end

getPartyMenuStructure = function()
    local mainGui = playerGui:FindFirstChild("MainGui")
    if not mainGui then return nil end

    local partyMenu = findNodeByChain(mainGui, PARTY_MENU_TARGET.rootChain)
    if not partyMenu then return nil end

    local partyMain = partyMenu:FindFirstChild(PARTY_MENU_TARGET.mainName)
    if not partyMain then return nil end

    local slots, slotCount = {}, 0
    for i = 1, PARTY_MENU_TARGET.slotCount do
        local slot = partyMain:FindFirstChild(PARTY_MENU_TARGET.slotPrefix .. i)
        if slot then
            slots[i] = slot
            slotCount = slotCount + 1
        end
    end
    if slotCount < 1 then return nil end

    return {
        partyMenu = partyMenu,
        partyMain = partyMain,
        slots = slots,
        slotCount = slotCount,
        path = partyMain:GetFullName(),
        visible = partyMain.Visible and isOnScreen(partyMain),
    }
end

partyMenuTargetExists = function()
    return getPartyMenuStructure() ~= nil
end

getFightPanelImageLabel = function(bGui)
    bGui = bGui or getBattleGui()
    if not bGui then return nil end

    local candidates = {}
    for _, child in ipairs(bGui:GetChildren()) do
        if child:IsA("GuiObject") and child.Name == "ImageLabel" and isOnScreen(child) then
            candidates[#candidates + 1] = child
        end
    end
    if #candidates == 0 then
        for _, child in ipairs(bGui:GetChildren()) do
            if child:IsA("GuiObject") and child.Name == "ImageLabel" then
                candidates[#candidates + 1] = child
            end
        end
    end
    if #candidates == 0 then return nil end

    for _, child in ipairs(candidates) do
        if child:FindFirstChild("Move1", true) or child:FindFirstChild("Move2", true) then
            return child
        end
    end

    for _, child in ipairs(candidates) do
        if isFightSubmenuOpen(child) then return child end
    end

    for _, child in ipairs(candidates) do
        if isFightLikePanel(child) then return child end
    end

    table.sort(candidates, function(a, b)
        return a.AbsolutePosition.X < b.AbsolutePosition.X
    end)
    return candidates[1]
end

-- Move buttons only exist after the fight/menu button opens the submenu
isMoveSubmenuOpen = function()
    local bGui = getBattleGui()
    if not bGui then return false end
    local fightPanel = getFightPanelImageLabel(bGui)
    return fightPanel ~= nil and isFightSubmenuOpen(fightPanel)
end

waitForMoveSubmenu = function(timeoutSec)
    timeoutSec = timeoutSec or GUI_READY_WAIT
    local deadline = tick() + timeoutSec
    while tick() < deadline do
        if isMoveSubmenuOpen() then return true end
        task.wait(GUI_READY_POLL)
    end
    return isMoveSubmenuOpen()
end

getTopLevelImageLabelPanels = function(bGui)
    bGui = bGui or getBattleGui()
    if not bGui then return {} end

    local fightPanel = getFightPanelImageLabel(bGui)
    local partyTarget = getPartyMenuStructure()
    local out = {}

    for i, child in ipairs(bGui:GetChildren()) do
        if isTopLevelBattlePanelChild(child) and isOnScreen(child) then
            local btn = resolveGuiButton(child:FindFirstChild("Button")) or resolveGuiButton(child)
            if not btn and isClickableGui(child) then btn = child end
            local cx, cy = 0, 0
            if btn and isOnScreen(btn) then
                cx, cy = guiCenterOf(btn)
            else
                cx = child.AbsolutePosition.X + child.AbsoluteSize.X * 0.5
                cy = child.AbsolutePosition.Y + child.AbsoluteSize.Y * 0.5
            end
            local fightLike = fightPanel ~= nil and child == fightPanel
            local flatSide = not fightLike
            out[#out + 1] = {
                panel = child,
                button = btn,
                childIndex = i,
                isFightPanel = fightLike,
                isFlatSidePanel = flatSide,
                opensPartyMenu = flatSide and partyTarget ~= nil,
                cx = cx,
                cy = cy,
                imageId = getGuiImageAssetId(child),
            }
        end
    end

    table.sort(out, function(a, b)
        if a.cx ~= b.cx then return a.cx < b.cx end
        return a.childIndex < b.childIndex
    end)

    for rank, entry in ipairs(out) do
        entry.screenRank = rank
    end
    return out
end

pickPanelEntry = function(panels, cfg)
    if not panels or #panels == 0 then return nil end
    if not cfg then return panels[1] end

    if cfg.role == "menu" or cfg.role == "rest" then
        for _, p in ipairs(panels) do
            if p.isFightPanel and p.button and isOnScreen(p.button) then
                return p
            end
        end
    end

    if cfg.role == "loomians" then
        return nil
    end

    if cfg.screenRank then
        for _, p in ipairs(panels) do
            if p.screenRank == cfg.screenRank and p.button and isOnScreen(p.button) then
                return p
            end
        end
    end

    if cfg.probeImageId then
        for _, p in ipairs(panels) do
            if p.imageId == cfg.probeImageId and p.button and isOnScreen(p.button) then
                return p
            end
        end
    end

    if cfg.probeScreenX and cfg.probeScreenY then
        local best, bestDist = nil, math.huge
        for _, p in ipairs(panels) do
            if p.button and isOnScreen(p.button) then
                local dx = p.cx - cfg.probeScreenX
                local dy = p.cy - cfg.probeScreenY
                local dist = dx * dx + dy * dy
                if dist < bestDist then
                    bestDist = dist
                    best = p
                end
            end
        end
        if best and bestDist < 120 * 120 then return best end
    end

    return nil
end

getFlatSidePanels = function(panels)
    local out = {}
    for _, p in ipairs(panels or {}) do
        if p.isFlatSidePanel and p.panel and isOnScreen(p.panel) then
            local target = resolveLoomiansClickTarget(p)
            if target then
                p.button = target
                out[#out + 1] = p
            end
        end
    end
    return out
end

-- Loomians: flat BattleGui panel (non-fight ImageLabel sibling) opens PartyMenu
resolveLoomiansPanelButton = function(bGui, cfg)
    cfg = cfg or TEAM_ACTIONS.loomians
    bGui = bGui or getBattleGui()
    if not bGui then return nil, nil, nil, "BattleGui missing" end

    local partyTarget = getPartyMenuStructure()

    local panels = getTopLevelImageLabelPanels(bGui)
    local flatSide = filterFlatSidePanelsForLoomians(getFlatSidePanels(panels))
    if #flatSide == 0 then
        return nil, nil, nil, "No flat side panels on BattleGui (non-fight ImageLabel)"
    end

    local pick = nil
    local pickMode = cfg.sidePanelPick or "rightmost"

    for _, p in ipairs(flatSide) do
        if p.panel and panelMatchesLoomians(p.panel) then
            pick = p
            break
        end
    end

    if cfg.probeScreenX and cfg.probeScreenY then
        local best, bestDist = nil, math.huge
        for _, p in ipairs(flatSide) do
            local dx = p.cx - cfg.probeScreenX
            local dy = p.cy - cfg.probeScreenY
            local dist = dx * dx + dy * dy
            if dist < bestDist then
                bestDist = dist
                best = p
            end
        end
        if best and bestDist < 120 * 120 then pick = best end
    end

    if not pick and cfg.screenRank then
        table.sort(flatSide, function(a, b)
            if a.cx ~= b.cx then return a.cx < b.cx end
            return a.childIndex < b.childIndex
        end)
        pick = flatSide[math.clamp(cfg.screenRank, 1, #flatSide)]
    end

    if not pick then
        if pickMode == "leftmost" then
            table.sort(flatSide, function(a, b) return a.cx < b.cx end)
        elseif pickMode == "bottommost" then
            table.sort(flatSide, function(a, b) return a.cy > b.cy end)
        else
            table.sort(flatSide, function(a, b) return a.cx > b.cx end)
        end
        pick = flatSide[1]
    end

    if not pick then
        return nil, nil, nil, "Loomians flat panel not resolved"
    end

    local target = resolveLoomiansClickTarget(pick)
    if not target then
        return nil, nil, nil, "Loomians flat panel has no click target"
    end

    local note
    if partyTarget then
        note = string.format("flat panel → %s (%d slots, %s)",
            partyTarget.path,
            partyTarget.slotCount,
            partyTarget.visible and "PartyMenu open" or "PartyMenu hidden until click")
    else
        note = "flat panel → PartyMenu tree not pre-scanned (will verify after click)"
    end
    return target, target:GetFullName(), getRbxId(target), note
end

resolveWaitButton = function(bGui)
    bGui = bGui or getBattleGui()
    if not bGui then return nil, nil, nil, "BattleGui missing" end

    local fightPanel = getFightPanelImageLabel(bGui)
    if fightPanel then
        local btn = resolveGuiButton(findNodeByChain(fightPanel, { "ImageLabel", "ImageLabel", "Button" }))
        if btn and isOnScreen(btn) then
            return btn, btn:GetFullName(), getRbxId(btn), nil
        end
    end

    for _, desc in bGui:GetDescendants() do
        if desc:IsA("GuiButton") and isOnScreen(desc) and isInnerWaitProbedButton(desc) then
            return desc, desc:GetFullName(), getRbxId(desc), nil
        end
    end

    return nil, nil, nil, "Wait submenu button not found"
end

resolvePanelButtonByRole = function(actionKey)
    local cfg = getPanelActionConfig(actionKey)
    if actionKey == "menu" then cfg = MENU_BUTTON end
    if not cfg then return nil, nil, nil, "unknown action " .. tostring(actionKey) end

    local bGui = getBattleGui()
    if not bGui then return nil, nil, nil, "BattleGui missing" end

    if cfg.role == "wait" or actionKey == "wait" then
        return resolveWaitButton(bGui)
    end

    if cfg.role == "loomians" or actionKey == "loomians" then
        return resolveLoomiansPanelButton(bGui, cfg)
    end

    if cfg.role == "rest" or actionKey == "rest" then
        if not isFightSubmenuOpen(getFightPanelImageLabel(bGui)) then
            return nil, nil, nil, "Fight submenu not open — click menu button first"
        end
    end

    if cfg.role == "menu" or actionKey == "menu" then
        if isFightSubmenuOpen(getFightPanelImageLabel(bGui)) then
            return nil, nil, nil, "Fight submenu already open"
        end
    end

    local panels = getTopLevelImageLabelPanels(bGui)
    local entry = pickPanelEntry(panels, cfg)

    if entry and entry.button and isOnScreen(entry.button) then
        if cfg.role == "menu" and isInnerWaitProbedButton(entry.button) then
            entry = nil
        end
    else
        entry = nil
    end

    if entry and entry.button then
        local note = string.format("panel rank %d%s",
            entry.screenRank or 0,
            entry.isFightPanel and " (fight)" or " (side)")
        return entry.button, entry.button:GetFullName(), getRbxId(entry.button), note
    end

    -- Optional same-session rbxid hint
    if cfg.probeRbxId and cfg.probeRbxId ~= "" then
        for _, desc in bGui:GetDescendants() do
            if rbxIdsMatch(desc, cfg.probeRbxId) and isOnScreen(desc) then
                local btn = resolveGuiButton(desc) or desc
                if btn and isOnScreen(btn) then
                    return btn, btn:GetFullName(), getRbxId(desc), "rbxid hint"
                end
            end
        end
    end

    local layoutHint = ""
    if #panels > 0 then
        local bits = {}
        for _, p in ipairs(panels) do
            bits[#bits + 1] = string.format("#%d%s", p.screenRank, p.isFightPanel and " fight" or " side")
        end
        layoutHint = " — visible panels: " .. table.concat(bits, ", ")
    end

    return nil, nil, nil, (cfg.probePath or actionKey) .. " not found" .. layoutHint
end

listBattlePanelLayout = function()
    local bGui = getBattleGui()
    if not bGui then return {} end
    local panels = getTopLevelImageLabelPanels(bGui)
    local out = {}
    for _, p in ipairs(panels) do
        out[#out + 1] = {
            screenRank = p.screenRank,
            isFightPanel = p.isFightPanel,
            isFlatSidePanel = p.isFlatSidePanel,
            opensPartyMenu = p.opensPartyMenu,
            childIndex = p.childIndex,
            path = p.button and p.button:GetFullName() or p.panel:GetFullName(),
            cx = math.floor(p.cx + 0.5),
            cy = math.floor(p.cy + 0.5),
            imageId = p.imageId,
            rbxid = p.button and getRbxId(p.button) or nil,
        }
    end
    return out
end

probePanelButtonFromMouse = function(actionKey)
    local insp = G.BattleGuiInspector
    if not insp or not insp.getHit then return false, "BattleGuiInspector not loaded" end

    local hit = insp.getHit(1)
    if not hit then return false, "Press X on target button first (BattleGuiInspector)" end

    local bGui = getBattleGui()
    if not bGui or not hit:IsDescendantOf(bGui) then
        return false, "Last probe was not under BattleGui"
    end

    local btn = resolveGuiButton(hit) or (hit:IsA("GuiButton") and hit)
    if not btn then return false, "Probe hit has no clickable button" end

    local panels = getTopLevelImageLabelPanels(bGui)
    for _, p in ipairs(panels) do
        if p.button == btn or p.panel == btn or p.panel:IsAncestorOf(btn) then
            local cfg = getPanelActionConfig(actionKey)
            if cfg then
                cfg.screenRank = p.screenRank
                cfg.probeScreenX = p.cx
                cfg.probeScreenY = p.cy
                cfg.probeImageId = p.imageId
                cfg.probeRbxId = getRbxId(btn)
            end
            if actionKey == "menu" then
                MENU_BUTTON.screenRank = p.screenRank
                MENU_BUTTON.probeScreenX = p.cx
                MENU_BUTTON.probeScreenY = p.cy
                MENU_BUTTON.probeImageId = p.imageId
            end
            return true, string.format("saved rank %d at %.0f,%.0f", p.screenRank, p.cx, p.cy)
        end
    end

    local cfg = getPanelActionConfig(actionKey)
    if cfg then
        local cx, cy = guiCenterOf(btn)
        cfg.probeScreenX = cx
        cfg.probeScreenY = cy
        cfg.probeRbxId = getRbxId(btn)
    end
    return true, "saved screen position (non top-level panel)"
end

findPartyMenuMain = function()
    local struct = getPartyMenuStructure()
    return struct and struct.partyMain or nil
end

isPartyMenuOpen = function()
    local partyMain = findPartyMenuMain()
    return partyMain ~= nil and partyMain.Visible
end

resolveTeamSlotButton = function(slot)
    if not isBattleSwitchSlot(slot) then
        return nil, nil, nil,
            string.format("slot %d not switchable — use slots %d-%d (slot 1 is lead)",
                slot, BATTLE_SWITCH_SLOT_MIN, BATTLE_SWITCH_SLOTS)
    end

    local slotCfg = TEAM_SLOTS[slot] or {}
    local slotName = slotCfg.slotName or ("Slot" .. slot)
    local partyMain = findPartyMenuMain()
    if not partyMain then
        return nil, nil, nil, "PartyMenu not open — click Loomians first"
    end

    local expectedRbx = slotCfg.probeRbxId

    local slotNode = partyMain:FindFirstChild(slotName)
    if not slotNode then
        return nil, nil, nil, slotName .. " missing under PartyMain"
    end

    local btn = resolveGuiButton(slotNode:FindFirstChild("ImageButton") or slotNode)
    if btn and isOnScreen(btn) then
        local rbx = getRbxId(btn)
        local note = (not expectedRbx or expectedRbx == "" or rbxIdsMatch(btn, expectedRbx)) and nil
            or ("rbxid " .. shortRbxId(rbx) .. " (hint " .. shortRbxId(expectedRbx) .. ", changes each session)")
        return btn, btn:GetFullName(), rbx, note
    end

    if expectedRbx and expectedRbx ~= "" then
        for _, desc in partyMain:GetDescendants() do
            if desc:IsA("GuiButton") and desc.Name == "ImageButton"
                and desc.Parent and desc.Parent.Name == slotName
                and rbxIdsMatch(desc, expectedRbx) and isOnScreen(desc) then
                return desc, desc:GetFullName(), getRbxId(desc), "rbxid hint match"
            end
        end
    end

    if btn and not isOnScreen(btn) then
        return nil, nil, nil, btn:GetFullName() .. " not visible"
    end

    return nil, nil, nil, slotName .. ".ImageButton not found"
end

waitForTeamSlotButton = function(slot, timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    local lastErr = "slot " .. slot .. " not found"
    while tick() < deadline do
        local btn, path, rbx, err = resolveTeamSlotButton(slot)
        if btn and isGuiReadyForClick(btn) then return btn, path, rbx, err end
        lastErr = err or lastErr
        task.wait(GUI_READY_POLL)
    end
    local btn, path, rbx, err = resolveTeamSlotButton(slot)
    if btn and isGuiReadyForClick(btn) then return btn, path, rbx, err end
    return nil, nil, nil, lastErr
end

getMiscExpectedPath = function(actionKey)
    local cfg = getPanelActionConfig(actionKey)
    return cfg and cfg.probePath or "?"
end

isProbedPanelButton = function(obj)
    if not obj then return false end
    for _, store in ipairs({ MISC_ACTIONS, TEAM_ACTIONS }) do
        for _, cfg in pairs(store) do
            if cfg.probeRbxId and rbxIdsMatch(obj, cfg.probeRbxId) then
                return true
            end
        end
    end
    return false
end

optionalRbxNote = function(btn, expectedRbx)
    if not btn or not expectedRbx or expectedRbx == "" then return nil end
    if rbxIdsMatch(btn, expectedRbx) then return nil end
    return "rbxid " .. shortRbxId(getRbxId(btn)) .. " (hint " .. shortRbxId(expectedRbx) .. ", changes each session)"
end

local CONFLICT_LABELS = {
    loomians = { "wait", "rest", "fight", "bag", "run" },
    rest = { "wait", "loomian", "fight" },
    wait = { "rest", "loomian", "fight" },
}

hasConflictingLabel = function(obj, actionKey)
    local conflicts = CONFLICT_LABELS[actionKey]
    if not conflicts or not obj then return false end
    local text = normalizeLabel(safeGuiText(obj))
    for _, ex in ipairs(conflicts) do
        if text:find(ex, 1, true) then return true end
    end
    return false
end

guiObjectMatchesAction = function(obj, actionKey)
    local cfg = getPanelActionConfig(actionKey)
    local lookup = BATTLE_MENU_LOOKUP[actionKey]
    if cfg and cfg.label and normalizeLabel(safeGuiText(obj)) == normalizeLabel(cfg.label) then
        return true
    end
    if lookup and buttonMatchesAction(obj, lookup.needles, lookup.exactNames) then
        return true
    end
    return false
end

-- Path + label first; probeRbxId is optional same-session hint only
resolveProbedActionButton = function(actionKey)
    return resolvePanelButtonByRole(actionKey)
end

resolveLoomiansButton = function()
    local bGui = getBattleGui()
    if not bGui then
        return nil, nil, nil, "BattleGui missing"
    end

    local btn = findLoomiansBattleButton()
    if btn and isOnScreen(btn) then
        return btn, btn:GetFullName(), getRbxId(btn), "name/label match"
    end

    local path, rbx, err
    btn, path, rbx, err = resolveLoomiansPanelButton(bGui, TEAM_ACTIONS.loomians)
    if btn then return btn, path, rbx, err end

    local partyErr = not partyMenuTargetExists()
        and (PARTY_MENU_TARGET.path .. " not found — party slots may not resolve after click")
        or nil
    return nil, nil, nil, err or partyErr or "Loomians button not found"
end

findLoomiansBattleButton = function()
    local bGui = getBattleGui()
    if not bGui then return nil end

    local lookup = BATTLE_MENU_LOOKUP.loomians
    if not lookup then return nil end

    -- icigool-style: instance names under BattleGui (e.g. Run, Loomians)
    for _, name in ipairs(lookup.exactNames) do
        local node = bGui:FindFirstChild(name, true)
        if node and not isFromMacroGui(node) then
            local btn = resolveGuiButton(node) or node
            if btn and isOnScreen(btn) then
                return btn
            end
        end
    end

    local byLabel = findBattleButtonByLabel("Loomians")
    if byLabel and isOnScreen(byLabel) then return byLabel end

    local byAction = findBattleMenuAction("loomians")
    if byAction and isOnScreen(byAction) then return byAction end

    local panels = filterFlatSidePanelsForLoomians(getFlatSidePanels(getTopLevelImageLabelPanels(bGui)))
    for _, p in ipairs(panels) do
        if p.panel and panelMatchesLoomians(p.panel) then
            local target = resolveLoomiansClickTarget(p)
            if target then return target end
        end
    end

    return nil
end

waitForLoomiansButton = function(timeoutSec)
    timeoutSec = timeoutSec or LOOMIANS_FIND_WAIT
    local deadline = tick() + timeoutSec
    local lastBtn, lastPath, lastRbx, lastErr = nil, nil, nil, "Loomians button not found"
    while tick() < deadline do
        local btn, path, rbx, err = resolveLoomiansButton()
        if btn then
            lastBtn, lastPath, lastRbx, lastErr = btn, path, rbx, err
            if isSpotReadyForClick({ button = btn, kind = "loomians" }) then
                return btn, path, rbx, err
            end
        else
            lastErr = err or lastErr
        end
        task.wait(GUI_READY_POLL)
    end
    if lastBtn then return lastBtn, lastPath, lastRbx, lastErr end
    return nil, nil, nil, lastErr
end

waitForPartyMenuOpen = function(timeoutSec)
    timeoutSec = timeoutSec or PARTY_MENU_OPEN_WAIT
    local deadline = tick() + timeoutSec
    while tick() < deadline do
        if isPartyMenuOpen() then return true end
        task.wait(0.1)
    end
    return isPartyMenuOpen()
end

clickLoomiansButton = function()
    waitForBattleGui(BATTLE_GUI_WAIT)
    local btn, path, rbx, err = waitForLoomiansButton(LOOMIANS_FIND_WAIT)
    if not btn then
        setStatus("Loomians: " .. (err or "not found"))
        refreshGui()
        return false
    end
    local spot = { button = btn, name = "Loomians", kind = "loomians" }
    showHighlights({ spot })
    task.wait(HIGHLIGHT_PREVIEW_SEC)
    setStatus(string.format("Loomians — %s rbx=%s", path, shortRbxId(rbx)))
    refreshGui()
    local ok = clickSpot(spot)
    clearHighlights()
    return ok
end

getFrontGui = function()
    local frontGui = playerGui:FindFirstChild("FrontGui")
    if frontGui and frontGui.Enabled then return frontGui end
    return nil
end

resolveSwitchConfirmButton = function()
    local frontGui = getFrontGui()
    if not frontGui then return nil, nil, nil, "FrontGui not enabled" end

    local switchRoot = frontGui:FindFirstChild("SwitchButton")
    if not switchRoot then return nil, nil, nil, "SwitchButton missing" end

    local bg = switchRoot:FindFirstChild("BackgroundTall")
    if bg and isOnScreen(bg) then
        return bg, bg:GetFullName(), getRbxId(bg), nil
    end

    local btn = resolveGuiButton(switchRoot)
    if btn and isOnScreen(btn) then
        return btn, btn:GetFullName(), getRbxId(btn), nil
    end

    if SWITCH_CONFIRM.rbxid and SWITCH_CONFIRM.rbxid ~= "" then
        for _, desc in switchRoot:GetDescendants() do
            if rbxIdsMatch(desc, SWITCH_CONFIRM.rbxid) and isOnScreen(desc) then
                local target = resolveGuiButton(desc) or bg or switchRoot
                if target and isOnScreen(target) then
                    return target, target:GetFullName(), getRbxId(desc), "rbxid hint match"
                end
            end
        end
    end

    if switchRoot:IsA("GuiObject") and isOnScreen(switchRoot) then
        return switchRoot, switchRoot:GetFullName(), getRbxId(switchRoot), "SwitchButton root"
    end

    return nil, nil, nil, SWITCH_CONFIRM.path .. " not visible"
end

isSwitchConfirmVisible = function()
    local btn = select(1, resolveSwitchConfirmButton())
    return btn ~= nil and isGuiReadyForClick(btn)
end

waitForSwitchConfirmButton = function(timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    local lastErr = SWITCH_CONFIRM.path .. " not found"
    while tick() < deadline do
        local btn, path, rbx, err = resolveSwitchConfirmButton()
        if btn then return btn, path, rbx, err end
        lastErr = err or lastErr
        task.wait(0.1)
    end
    local btn, path, rbx, err = resolveSwitchConfirmButton()
    if btn then return btn, path, rbx, err end
    return nil, nil, nil, lastErr
end

-- Direct probed panel buttons (path + label; optional rbxid hint)
resolveMiscActionButton = function(actionKey)
    return resolveProbedActionButton(actionKey)
end

waitForMiscActionButton = function(actionKey, timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    local lastErr = getMiscExpectedPath(actionKey) .. " not found"
    while tick() < deadline do
        local btn, path, rbx, err = resolveMiscActionButton(actionKey)
        if btn then return btn, path, rbx, err end
        lastErr = err or lastErr
        task.wait(0.1)
    end
    local btn, path, rbx, err = resolveMiscActionButton(actionKey)
    if btn then return btn, path, rbx, err end
    return nil, nil, nil, lastErr
end

findMiscActionMenuRow = function()
    local menuRoot = getBattleMenuImageLabel()
    if not menuRoot then return nil end
    return findNodeByChain(menuRoot, MISC_ROW_CHAIN)
end

-- Row-based target — does NOT require .4 / .2 leaf nodes
resolveMiscActionRow = function(actionKey)
    local cfg = MISC_ACTIONS[actionKey]
    if not cfg then return nil, "unknown action" end

    local expected = getMiscExpectedPath(actionKey)
    local row = findMiscActionMenuRow()
    if not row then return nil, expected .. " — row missing" end
    if not row.Visible then return nil, row:GetFullName() .. " — Visible=false" end

    local sg = row:FindFirstAncestorOfClass("ScreenGui")
    if sg and not sg.Enabled then return nil, row:GetFullName() .. " — ScreenGui disabled" end

    local pSize = row.AbsoluteSize
    if pSize.X < 8 or pSize.Y < 4 then
        return nil, row:GetFullName() .. string.format(" — row size %dx%d too small", pSize.X, pSize.Y)
    end

    return row, row:GetFullName() .. " slot " .. (cfg.rowSlot or MISC_SLOT_NUMBER[actionKey] or "?")
end

waitForMiscActionRow = function(actionKey, timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    local lastErr = getMiscExpectedPath(actionKey) .. " — not ready"
    while tick() < deadline do
        local row, pathOrErr = resolveMiscActionRow(actionKey)
        if row then return row, pathOrErr end
        lastErr = pathOrErr or lastErr
        task.wait(0.1)
    end
    return nil, lastErr
end

findBattleButtonByLabel = function(labelText)
    local bGui = getBattleGui()
    if not bGui then return nil end

    local wanted = normalizeLabel(labelText)

    for _, desc in bGui:GetDescendants() do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and normalizeLabel(desc.Text) == wanted then
            if not isFromMacroGui(desc) then
                local btn = desc:IsA("GuiButton") and desc or desc:FindFirstAncestorWhichIsA("GuiButton")
                if btn and not isFromMacroGui(btn) and (isLooselyVisible(btn) or isOnScreen(btn)) then
                    return btn
                end
                local host = desc:IsA("GuiObject") and desc or desc:FindFirstAncestorWhichIsA("GuiObject")
                if host and not isFromMacroGui(host) and isOnScreen(host) then
                    return resolveGuiButton(host) or host
                end
            end
        end
    end

    return nil
end

findMiscLabelTarget = function(actionKey)
    local cfg = MISC_ACTIONS[actionKey]
    if not cfg then return nil end

    local bGui = getBattleGui()
    if not bGui then return nil end

    local wanted = normalizeLabel(cfg.label)
    local row = findMiscActionMenuRow()

    for _, desc in bGui:GetDescendants() do
        if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and normalizeLabel(desc.Text) == wanted then
            if not isFromMacroGui(desc) then
                local host = desc:IsA("GuiObject") and desc or desc:FindFirstAncestorWhichIsA("GuiObject")
                if host and host.Visible then
                    if not row or host:IsDescendantOf(row) or host:FindFirstAncestorWhichIsA("GuiObject") == row then
                        return host
                    end
                    if row and row:IsAncestorOf(host) then return host end
                    -- label anywhere in BattleGui is ok as fallback
                    if row == nil or host:IsDescendantOf(bGui) then return host end
                end
            end
        end
    end

    return findBattleButtonByLabel(cfg.label)
end

-- Find Wait + Rest via row + text labels (no .4 / .2 leaves)
findMiscActionPair = function()
    local row = findMiscActionMenuRow()
    if not row then return nil end

    local waitNode = findMiscLabelTarget("wait")
    local restNode = findMiscLabelTarget("rest")

    local pair = {
        row = row,
        wait = waitNode,
        rest = restNode,
        slots = {},
    }

    if pair.wait then
        pair.slots[#pair.slots + 1] = { key = "wait", node = pair.wait, slot = 1 }
    end
    if pair.rest then
        pair.slots[#pair.slots + 1] = { key = "rest", node = pair.rest, slot = 2 }
    end

    return pair
end

findMiscActionNode = function(actionKey)
    return resolveMiscActionButton(actionKey)
end

waitForMiscActionPair = function(timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    while tick() < deadline do
        local pair = findMiscActionPair()
        if pair and (pair.wait or pair.rest) then return pair end
        task.wait(0.1)
    end
    return findMiscActionPair()
end

waitForMiscActionNode = function(actionKey, timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    while tick() < deadline do
        local node = findMiscActionNode(actionKey)
        if node then return node end
        task.wait(0.1)
    end
    return findMiscActionNode(actionKey)
end

miscFindDebug = function(actionKey)
    local btn, path, rbx, err = resolveMiscActionButton(actionKey)
    if not btn then return err or "button not found" end
    local s = btn.AbsoluteSize
    return string.format("ok size=%dx%d rbx=%s — %s", s.X, s.Y, shortRbxId(rbx), path)
end

getMiscRowSlotCenter = function(actionKey, row)
    row = row or findMiscActionMenuRow()
    if not row then return nil, nil end

    local cfg = MISC_ACTIONS[actionKey]
    local slotNum = (cfg and cfg.rowSlot) or MISC_SLOT_NUMBER[actionKey]
    if not slotNum then return nil, nil end

    local pPos = row.AbsolutePosition
    local pSize = row.AbsoluteSize
    if pSize.X < 8 or pSize.Y < 4 then return nil, nil end

    local slotW = pSize.X / 2
    local cx = pPos.X + slotW * (slotNum - 0.5)
    local cy = pPos.Y + pSize.Y * 0.5
    return cx, cy
end

buildPairFromRow = function(actionKey, row)
    return {
        row = row,
        wait = actionKey == "wait" and findMiscLabelTarget("wait") or nil,
        rest = actionKey == "rest" and findMiscLabelTarget("rest") or nil,
    }
end

findBattleMenuAction = function(actionKey)
    local lookup = BATTLE_MENU_LOOKUP[actionKey]
    if not lookup then return nil end

    -- 0) Structural panel resolver (generic names / duplicate paths)
    if isPanelActionKey(actionKey) then
        local probed, _, _, _ = resolvePanelButtonByRole(actionKey)
        if probed then return probed end
    end

    -- 1) Match visible on-screen label text inside BattleGui
    local byLabel = findBattleButtonByLabel(lookup.label)
    if byLabel then return byLabel end

    local root = getBattleActionMenuRoot()

    -- 2) Search under ImageLabel menu root (same area as Fight/Button)
    if root then
        for _, name in ipairs(lookup.exactNames) do
            local node = root:FindFirstChild(name, false) or root:FindFirstChild(name, true)
            local btn = resolveGuiButton(node)
            if btn and isLooselyVisible(btn) then return btn end
        end

        for _, desc in root:GetDescendants() do
            if desc:IsA("GuiButton") and isLooselyVisible(desc)
                and buttonMatchesAction(desc, lookup.needles, lookup.exactNames) then
                return desc
            end
        end
    end

    -- 3) Deep search under BattleGui
    local bGui = getBattleGui()
    if bGui then
        for _, name in ipairs(lookup.exactNames) do
            local node = bGui:FindFirstChild(name, true)
            local btn = resolveGuiButton(node)
            if btn and isLooselyVisible(btn) then return btn end
        end

        for _, desc in bGui:GetDescendants() do
            if desc:IsA("GuiButton") and isLooselyVisible(desc)
                and buttonMatchesAction(desc, lookup.needles, lookup.exactNames) then
                return desc
            end
        end
    end

    -- 4) Full MainGui fallback
    for _, name in ipairs(lookup.exactNames) do
        local btn = findMainGuiButtonByName(name)
        if btn and isLooselyVisible(btn) then return btn end
    end

    return findVisibleBattleButton(function(d)
        return buttonMatchesAction(d, lookup.needles, lookup.exactNames)
    end)
end

resolveBattleMenuButton = function()
    return resolvePanelButtonByRole("menu")
end

waitForBattleMenuButton = function(timeoutSec)
    timeoutSec = timeoutSec or 3
    local deadline = tick() + timeoutSec
    local lastErr = MENU_BUTTON.path .. " not found"
    while tick() < deadline do
        local btn = findBattleMenuButton()
        if btn then return btn, btn:GetFullName(), getRbxId(btn), nil end
        local _, _, _, err = resolveBattleMenuButton()
        lastErr = err or lastErr
        task.wait(0.1)
    end
    local btn = findBattleMenuButton()
    if btn then return btn, btn:GetFullName(), getRbxId(btn), nil end
    return nil, nil, nil, lastErr
end

findBattleMenuButton = function()
    local btn = resolveBattleMenuButton()
    if btn then return btn end
    btn = findBattleMenuAction("fight")
    if btn then return btn end
    return findVisibleBattleButton(function(d)
        local n = string.lower(d.Name)
        local t = string.lower(safeGuiText(d))
        return n:find("fight", 1, true) or t:find("fight", 1, true) or n == "button"
    end)
end

clickVerifiedMenuButton = function()
    local btn, path, rbx, err = waitForBattleMenuButton(GUI_READY_WAIT)
    if not btn then
        setStatus("Menu Button: " .. (err or "not found"))
        refreshGui()
        return false
    end
    if not waitForGuiReady(btn, GUI_READY_WAIT) then
        setStatus("Menu Button: visible but not ready")
        refreshGui()
        return false
    end
    setStatus(string.format("Button (step 1) — %s rbx=%s", path or "?", shortRbxId(rbx)))
    refreshGui()
    return clickSpot({ button = btn, name = "Button (step 1)", kind = "menu" })
end

findFightButton = function()
    return findBattleMenuButton()
end

findMiscActionButton = function(actionKey)
    return findBattleMenuAction(actionKey)
end

listBattleMenuButtons = function()
    local out = {}
    local bGui = getBattleGui()
    if not bGui then return out end
    for _, desc in bGui:GetDescendants() do
        if desc:IsA("GuiButton") and not isFromMacroGui(desc) then
            out[#out + 1] = {
                name = desc.Name,
                text = safeGuiText(desc),
                path = desc:GetFullName(),
                visible = isLooselyVisible(desc),
                strictVisible = isEffectivelyVisible(desc),
            }
        end
    end
    return out
end

appendCommonClickSpots = function(spots, seen, addSpot, addPoint)
    local frontGui = playerGui:FindFirstChild("FrontGui")
    if frontGui and frontGui.Enabled then
        local n = 0
        for _, obj in frontGui:GetDescendants() do
            if (obj:IsA("ImageButton") or obj:IsA("TextButton")) and isEffectivelyVisible(obj) then
                n = n + 1
                addSpot(obj, "FrontGui" .. n, "front")
            end
        end
    end
    for _, pt in ipairs(fallbackPoints) do
        addPoint(pt.x, pt.y, pt.name)
    end
end

buildClickSpots = function(slot, mv)
    local spots = {}
    local seen = {}

    local function addSpot(btn, name, kind)
        if not btn or seen[btn] then return end
        seen[btn] = true
        spots[#spots + 1] = { button = btn, name = name, kind = kind or "gui" }
    end

    local function addPoint(x, y, name)
        spots[#spots + 1] = { x = x, y = y, name = name, kind = "point", w = 36, h = 36 }
    end

    local bGui = waitForBattleGui()
    local submenuOpen = isMoveSubmenuOpen()

    if not submenuOpen then
        addSpot(waitForButtonFinder(findBattleMenuButton, GUI_READY_WAIT), "Button (step 1)", "menu")
    end

    -- Move slots only render after fight menu is opened — don't wait for them yet
    if submenuOpen then
        local moveBtn = findMoveButton(slot)
        if not moveBtn and mv then
            moveBtn = findMoveButtonByName(mv.move, mv.id)
        end
        if not moveBtn then
            moveBtn = waitForButtonFinder(function()
                return findMoveButton(slot)
            end, GUI_READY_WAIT)
        end
        if not moveBtn and mv then
            moveBtn = waitForButtonFinder(function()
                return findMoveButtonByName(mv.move, mv.id)
            end, GUI_READY_WAIT)
        end
        addSpot(moveBtn, (mv and mv.move) or ("Move" .. slot), "move")
    end

    if #spots == 0 then
        addSpot(findBattleMenuButton(), "Button (fallback)", "menu")
    end

    if #spots == 0 then
        appendCommonClickSpots(spots, seen, addSpot, addPoint)
    end

    return spots
end

miscSpotFromRow = function(actionKey, cfg, row)
    if not row or not cfg then return nil end
    local sx, sy = getMiscRowSlotCenter(actionKey, row)
    if not sx or not sy then return nil end
    local slot = cfg.rowSlot or MISC_SLOT_NUMBER[actionKey] or "?"
    return {
        button = row,
        name = string.format("%s (row slot %s)", cfg.displayName, slot),
        kind = actionKey,
        screenX = sx,
        screenY = sy,
    }
end

miscSpotFromLabel = function(actionKey, cfg, labelNode)
    if not labelNode or not cfg then return nil end
    local pos = labelNode.AbsolutePosition
    local size = labelNode.AbsoluteSize
    local sx = pos.X + math.max(size.X, 24) * 0.5
    local sy = pos.Y + math.max(size.Y, 24) * 0.5
    return {
        button = labelNode,
        name = cfg.displayName .. " (label)",
        kind = actionKey,
        screenX = sx,
        screenY = sy,
    }
end

buildMiscSpot = function(actionKey, cfg, row)
    row = row or findMiscActionMenuRow()
    local spot = row and miscSpotFromRow(actionKey, cfg, row) or nil
    if spot then return spot end

    local labelNode = findMiscLabelTarget(actionKey)
    if labelNode then return miscSpotFromLabel(actionKey, cfg, labelNode) end

    return nil
end

clickMiscSpotVerified = function(actionKey)
    local cfg = getPanelActionConfig(actionKey)
    if not cfg then return false end

    local btn = waitForButtonFinder(function()
        local found = resolveMiscActionButton(actionKey)
        return found
    end, GUI_READY_WAIT)
    local path, rbx, err
    if btn then
        path = btn:GetFullName()
        rbx = getRbxId(btn)
    else
        _, path, rbx, err = resolveMiscActionButton(actionKey)
    end
    if not btn then
        setStatus(string.format("%s — %s", cfg.displayName, err or "button not found"))
        refreshGui()
        return false
    end

    setStatus(string.format("Clicking %s — %s rbx=%s", cfg.displayName, path, shortRbxId(rbx)))
    refreshGui()
    return clickSpot({
        button = btn,
        name = cfg.displayName,
        kind = actionKey,
    })
end

clickMiscNumberedButton = function(actionKey, cfg)
    return clickMiscSpotVerified(actionKey)
end

buildMiscClickSpots = function(actionKey)
    local cfg = getPanelActionConfig(actionKey)
    if not cfg then return {} end

    local spots = {}

    if cfg.skipMenuStep then
        local btn = waitForButtonFinder(function()
            return select(1, resolveLoomiansButton())
        end, LOOMIANS_FIND_WAIT, true)
        if not btn then
            btn = select(1, resolveLoomiansButton())
        end
        if btn then
            spots[#spots + 1] = {
                button = btn,
                name = cfg.displayName,
                kind = actionKey == "loomians" and "loomians" or actionKey,
            }
        end
        return spots
    end

    if not isMoveSubmenuOpen() then
        local menuBtn = waitForButtonFinder(findBattleMenuButton, GUI_READY_WAIT)
        if menuBtn then
            spots[#spots + 1] = {
                button = menuBtn,
                name = "Button (step 1)",
                kind = "menu",
            }
        end
        return spots
    end

    local menuBtn = findBattleMenuButton()
    if menuBtn then
        spots[#spots + 1] = {
            button = menuBtn,
            name = "Button (step 1)",
            kind = "menu",
        }
    end

    local btn = waitForButtonFinder(function()
        return select(1, resolveMiscActionButton(actionKey)) or findMiscActionButton(actionKey)
    end, GUI_READY_WAIT)
    if btn then
        spots[#spots + 1] = {
            button = btn,
            name = cfg.displayName .. " (step 2)",
            kind = actionKey,
        }
    end

    return spots
end

buildMiscActionSpots = function(actionKey)
    local cfg = MISC_ACTIONS[actionKey]
    if not cfg then return {} end

    local spots = {}
    local seen = {}

    local function addSpot(btn, name, kind)
        if not btn or seen[btn] then return end
        seen[btn] = true
        spots[#spots + 1] = { button = btn, name = name, kind = kind or actionKey }
    end

    local function addPoint(x, y, name)
        spots[#spots + 1] = { x = x, y = y, name = name, kind = "point", w = 36, h = 36 }
    end

    addSpot(findMiscActionNode(actionKey), cfg.displayName .. " (row/label)", actionKey)
    addSpot(findMiscActionButton(actionKey), cfg.displayName, actionKey)
    addSpot(findBattleButtonByLabel(cfg.displayName), cfg.displayName .. " (label)", actionKey)

    local menuRoot = getBattleActionMenuRoot()
    if menuRoot then
        local row = findNodeByChain(menuRoot, MISC_ROW_CHAIN)
        if row then addSpot(row, table.concat(MISC_ROW_CHAIN, "."), actionKey) end
        local lookup = BATTLE_MENU_LOOKUP[actionKey]
        if lookup then
            for _, name in ipairs(lookup.exactNames) do
                addSpot(resolveGuiButton(menuRoot:FindFirstChild(name, true)), name, actionKey)
            end
            for _, desc in menuRoot:GetDescendants() do
                if desc:IsA("GuiButton") and buttonMatchesAction(desc, lookup.needles, lookup.exactNames) then
                    addSpot(desc, safeGuiText(desc) ~= "" and safeGuiText(desc) or desc.Name, actionKey)
                end
            end
        end
    end

    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        for _, name in ipairs({ cfg.displayName, cfg.displayName .. "1", "Button" }) do
            local found = mainGui:FindFirstChild(name, true)
            addSpot(resolveGuiButton(found), name, name == cfg.displayName and actionKey or "menu")
        end
    end

    appendCommonClickSpots(spots, seen, addSpot, addPoint)
    addSpot(findMiscActionButton(actionKey), cfg.displayName .. " (final)", actionKey)

    return spots
end

end -- §7-§8

-- ===========================================================================
-- §9 Click highlights overlay
-- ===========================================================================

clearHighlights = function()
    if overlayRefs.conn then
        overlayRefs.conn:Disconnect()
        overlayRefs.conn = nil
    end
    if overlayRefs.screenGui then
        pcall(function() overlayRefs.screenGui:Destroy() end)
        overlayRefs.screenGui = nil
    end
    overlayRefs.markers = {}
end

local function updateMarkerPosition(marker, spot)
    local w, h = 44, 44
    local cx, cy = getSpotCoords(spot, false)

    if not cx then
        marker.Visible = false
        return
    end

    if spot.button and spot.button.Parent then
        local _, _, bw, bh = guiCenterOf(spot.button)
        w = math.max(bw + 8, 36)
        h = math.max(bh + 8, 36)
    elseif spot.w and spot.h then
        w, h = spot.w, spot.h
    end

    marker.Visible = true
    marker.Size = UDim2.fromOffset(w, h)
    marker.Position = UDim2.fromOffset(cx - w / 2, cy - h / 2)
end

local function setMarkerActive(marker, active)
    local stroke = marker:FindFirstChildOfClass("UIStroke")
    if active then
        marker.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
        marker.BackgroundTransparency = 0.15
        if stroke then
            stroke.Color = Color3.fromRGB(255, 255, 255)
            stroke.Thickness = 3
        end
    else
        marker.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        marker.BackgroundTransparency = 0.35
        if stroke then
            stroke.Color = Color3.fromRGB(255, 220, 80)
            stroke.Thickness = 2
        end
    end
end

showHighlights = function(spots)
    clearHighlights()

    local sg = Instance.new("ScreenGui")
    sg.Name = "BattleMoveClickOverlay"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 9999
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = playerGui
    overlayRefs.screenGui = sg

    for i, spot in ipairs(spots) do
        local marker = Instance.new("Frame")
        marker.Name = "Spot" .. i
        marker.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        marker.BackgroundTransparency = 0.35
        marker.BorderSizePixel = 0
        marker.ZIndex = 10
        marker.Parent = sg

        local corner = Instance.new("UICorner", marker)
        corner.CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke", marker)
        stroke.Color = Color3.fromRGB(255, 220, 80)
        stroke.Thickness = 2

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Position = UDim2.new(0, 0, 1, 2)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0.4
        lbl.Text = i .. ". " .. (spot.name or "?")
        lbl.ZIndex = 11
        lbl.Parent = marker

        overlayRefs.markers[i] = { frame = marker, spot = spot, label = lbl, index = i }
        updateMarkerPosition(marker, spot)
        lbl.Text = i .. ". " .. (spot.name or "?")
    end

    overlayRefs.conn = RunService.RenderStepped:Connect(function()
        for _, entry in ipairs(overlayRefs.markers) do
            updateMarkerPosition(entry.frame, entry.spot)
            entry.label.Text = entry.index .. ". " .. (entry.spot.name or "?")
        end
    end)

    return sg
end

local function pulseMarker(index)
    local entry = overlayRefs.markers[index]
    if entry then setMarkerActive(entry.frame, true) end
end

local function unpulseAll()
    for _, entry in ipairs(overlayRefs.markers) do
        setMarkerActive(entry.frame, false)
    end
end

-- ===========================================================================
-- §10 Action execution
-- ===========================================================================

local function clickMenuButtonStep()
    return clickVerifiedMenuButton()
end

local function shouldWaitForSpotNow(spot)
    if type(spot) ~= "table" then return false end
    if spot.kind == "move" then return isMoveSubmenuOpen() end
    if spot.kind == "menu" then return not isMoveSubmenuOpen() end
    if spot.kind == "loomians" then return true end
    if spot.kind == "team" then return isPartyMenuOpen() end
    if spot.kind == "switch" then return isSwitchConfirmVisible() end
    if isPanelActionKey(spot.kind) then
        local cfg = getPanelActionConfig(spot.kind)
        if cfg and cfg.skipMenuStep then return true end
        return isMoveSubmenuOpen()
    end
    return true
end

local function waitForSpotsReadyNow(spotList)
    for _, spot in ipairs(spotList) do
        if shouldWaitForSpotNow(spot) then
            waitForSpotReady(spot, GUI_READY_WAIT)
        end
    end
end

local function findMoveSpotIn(spotList)
    for _, spot in ipairs(spotList) do
        if spot.kind == "move" then return spot end
    end
    return nil
end

local function runHighlightedClickSequence(spots, label, finalClickFn, rebuildSpotsFn)
    local function currentSpots()
        return (rebuildSpotsFn and rebuildSpotsFn()) or spots
    end

    local previewSpots = currentSpots()
    waitForSpotsReadyNow(previewSpots)
    showHighlights(previewSpots)
    task.wait(HIGHLIGHT_PREVIEW_SEC)

    setStatus(string.format("Clicking for %s...", label))
    refreshGui()

    local success = false
    local clicksDone = 0
    for attempt = 1, 6 do
        setStatus(string.format("Click pass %d/6 for %s...", attempt, label))
        refreshGui()

        local attemptSpots = currentSpots()
        local hasMenuStep = false
        for _, spot in ipairs(attemptSpots) do
            if spot.kind == "menu" then
                hasMenuStep = true
                break
            end
        end

        -- Step 1: open fight menu so move buttons can appear
        if hasMenuStep and not isMoveSubmenuOpen() then
            unpulseAll()
            pulseMarker(1)
            if clickMenuButtonStep() then
                clicksDone = clicksDone + 1
                waitForMoveSubmenu(GUI_READY_WAIT)
                task.wait(STEP_WAIT + 0.15)
                attemptSpots = currentSpots()
                waitForSpotsReadyNow(attemptSpots)
                showHighlights(attemptSpots)
            end
        elseif #attemptSpots > 0 then
            waitForSpotsReadyNow(attemptSpots)
            showHighlights(attemptSpots)
        end

        local moveClicked = false
        for step = 1, #attemptSpots do
            local spot = attemptSpots[step]
            if spot.kind == "menu" then
                -- Opened above when submenu was closed
            elseif spot.kind == "loomians" or spot.kind == "team" or spot.kind == "switch" then
                unpulseAll()
                pulseMarker(step)
                if waitForSpotReady(spot, GUI_READY_WAIT) and clickSpot(spot) then
                    clicksDone = clicksDone + 1
                end
                task.wait(STEP_WAIT)
            elseif isPanelActionKey(spot.kind) then
                if shouldWaitForSpotNow(spot) then
                    unpulseAll()
                    pulseMarker(step)
                    waitForMiscActionButton(spot.kind, GUI_READY_WAIT)
                    if clickMiscSpotVerified(spot.kind) then clicksDone = clicksDone + 1 end
                    task.wait(STEP_WAIT)
                end
            elseif spot.kind == "move" then
                if not moveClicked then
                    unpulseAll()
                    pulseMarker(step)
                    local moveSpot = findMoveSpotIn(currentSpots()) or spot
                    if waitForSpotReady(moveSpot, GUI_READY_WAIT) and clickSpot(moveSpot) then
                        clicksDone = clicksDone + 1
                    end
                    moveClicked = true
                    task.wait(STEP_WAIT)
                end
            else
                unpulseAll()
                pulseMarker(step)
                if waitForSpotReady(spot, GUI_READY_WAIT) and clickSpot(spot) then
                    clicksDone = clicksDone + 1
                end
                task.wait(STEP_WAIT)
            end
        end

        if finalClickFn and finalClickFn() then
            success = true
            break
        elseif clicksDone > 0 and #attemptSpots > 0 then
            success = true
            break
        end
    end

    task.wait(0.5)
    clearHighlights()
    return success
end

executeMoveSlot = function(slot)
    if state.executing then
        if tick() - (state.pendingAt or 0) >= EXEC_STALE_SEC then
            state.executing = false
            clearHighlights()
        else
            Err.report(Err.make(Err.codes.EXEC_BUSY, "Already executing another action", {}), { refresh = false })
            return
        end
    end

    local mv = idx(state.lead.moves, slot)
    if type(mv) ~= "table" then
        Err.report(Err.make(Err.codes.NO_MOVE_DATA, "No move in slot " .. tostring(slot), { slot = slot }))
        return
    end
    if mv.disabled then
        Err.report(Err.make(Err.codes.MOVE_DISABLED, (mv.move or "?") .. " is disabled", { slot = slot }))
        return
    end
    if (state.lead.energy or 0) < (mv.energy or 0) then
        Err.report(Err.make(Err.codes.NO_ENERGY, "Not enough energy for " .. (mv.move or "?"), {
            slot = slot, need = mv.energy, have = state.lead.energy,
        }))
        return
    end

    state.executing = true
    state.pendingSlot = slot
    state.pendingAction = nil
    state.pendingMoveName = mv.move or ("Move" .. slot)
    state.pendingAt = tick()
    state.lastResult.move = nil
    state.lastResult.effectiveness = nil
    state.lastResult.damage = nil

    local eff = getMoveEffectiveness(mv)
    setStatus(string.format("Move %d: %s (%s) — showing click spots...",
        slot, mv.move or "?", effectivenessShort(eff)))
    refreshGui()

    local ok, crashErr = pcall(function()
        setStatus("Waiting for battle GUI...")
        refreshGui()
        waitForBattleGui(BATTLE_GUI_WAIT)

        local spots = buildClickSpots(slot, mv)
        if #spots == 0 then
            local bGui = getBattleGui()
            local mainGui = playerGui:FindFirstChild("MainGui")
            Err.report(Err.make(Err.codes.SPOTS_EMPTY, "No click targets built for move", {
                slot = slot,
                battleGui = bGui and "yes" or "no",
                mainGui = mainGui and "yes" or "no",
                moveBtn = findMoveButton(slot) and "found" or "missing",
                menuBtn = findBattleMenuButton() and "found" or "missing",
                move = mv.move,
                hint = "Wait for your turn — macro reads moves from network, not the live UI",
            }))
            return
        end

        local seqOk = runHighlightedClickSequence(spots, mv.move or ("Move" .. slot), function()
            if not isMoveSubmenuOpen() then
                waitForMoveSubmenu(GUI_READY_WAIT)
            end
            local moveBtn = waitForButtonFinder(function()
                return findMoveButton(slot)
            end, GUI_READY_WAIT)
            if moveBtn and isGuiReadyForClick(moveBtn) then
                unpulseAll()
                clickGuiButton(moveBtn)
                return true
            end
            if mv then
                local byName = waitForButtonFinder(function()
                    return findMoveButtonByName(mv.move, mv.id)
                end, GUI_READY_WAIT)
                if byName and isGuiReadyForClick(byName) then
                    clickGuiButton(byName)
                    return true
                end
            end
            return false
        end, function()
            return buildClickSpots(slot, mv)
        end)

        if seqOk then
            setStatus(string.format("Sent %s — waiting for in-game result...", mv.move or "?"))
        else
            Err.report(Err.make(Err.codes.CLICK_FAILED, "Move click sequence failed", {
                slot = slot,
                move = mv.move,
                battleGui = getBattleGui() and "yes" or "no",
                moveBtn = findMoveButton(slot) and "found" or "missing",
                spots = #spots,
            }))
        end
    end)

    state.executing = false
    if not ok then
        Err.report(Err.make(Err.codes.REMOTE_HANDLER, "Move action crashed: " .. tostring(crashErr), { slot = slot }))
        clearHighlights()
    end
    refreshGui()
end

local function runMiscClickSequence(actionKey, cfg)
    cfg = cfg or getPanelActionConfig(actionKey)
    if not cfg then return false end

    if cfg.skipMenuStep then
        setStatus(string.format("Clicking %s (%s)...", cfg.displayName, cfg.probePath))
    else
        setStatus(string.format("Button → %s (%s)...", cfg.displayName, cfg.probePath))
    end
    refreshGui()

    return runHighlightedClickSequence(
        buildMiscClickSpots(actionKey),
        cfg.displayName,
        function()
            if actionKey == "loomians" then
                local btn = select(1, waitForLoomiansButton(LOOMIANS_FIND_WAIT))
                if not btn then return false end
                unpulseAll()
                return clickSpot({ button = btn, name = "Loomians", kind = "loomians" })
            end
            local btn = resolveMiscActionButton(actionKey)
            if not btn then return false end
            unpulseAll()
            clickMiscSpotVerified(actionKey)
            return true
        end,
        function()
            return buildMiscClickSpots(actionKey)
        end
    )
end

local function ensureMoveMenuOpen()
    local row = findMiscActionMenuRow()
    return row ~= nil and row.Visible
end

executePanelAction = function(actionKey)
    if state.executing then
        if tick() - (state.pendingAt or 0) >= EXEC_STALE_SEC then
            state.executing = false
            clearHighlights()
        else
            return
        end
    end

    local cfg = getPanelActionConfig(actionKey)
    if not cfg then return end

    state.executing = true
    state.pendingSlot = nil
    state.pendingAction = actionKey
    state.pendingMoveName = cfg.displayName
    state.pendingAt = tick()
    state.lastResult.move = nil
    state.lastResult.effectiveness = nil
    state.lastResult.damage = nil

    if cfg.skipMenuStep then
        setStatus(string.format("Finding %s...", cfg.displayName))
    elseif cfg.energyFraction then
        local gain = projectedEnergyGain(actionKey, state.lead.maxEnergy or 0)
        setStatus(string.format("%s — %s (+~%d energy) — finding button...",
            cfg.displayName, cfg.summary, gain))
    else
        setStatus(string.format("%s — %s — finding button...", cfg.displayName, cfg.summary))
    end
    refreshGui()

    if not cfg.skipMenuStep then
        setStatus(string.format("Button → %s...", cfg.displayName))
        refreshGui()
    end

    local ok, crashErr = pcall(function()
        local seqOk = runMiscClickSequence(actionKey, cfg)
        if seqOk then
            if cfg.energyFraction then
                setStatus(string.format("Sent %s — waiting for energy update...", cfg.displayName))
            else
                setStatus(string.format("Opened %s — pick a party slot when probes are ready", cfg.displayName))
            end
        else
            local spots = buildMiscClickSpots(actionKey)
            Err.report(Err.make(Err.codes.BUTTON_NOT_FOUND, "Could not click " .. cfg.displayName, {
                action = actionKey,
                battleGui = getBattleGui() and "yes" or "no",
                spots = #spots,
                detail = miscFindDebug(actionKey),
            }))
        end
    end)

    state.executing = false
    state.pendingAction = nil
    if not ok then
        Err.report(Err.make(Err.codes.REMOTE_HANDLER, "Panel action crashed: " .. tostring(crashErr), {
            action = actionKey,
        }))
        clearHighlights()
    end
    refreshGui()
end

local function executeMiscAction(actionKey)
    executePanelAction(actionKey)
end

local function rebuildTeamSwitchSpots(slot)
    local spots = {}

    local partyOpen = isPartyMenuOpen()
    local switchReady = isSwitchConfirmVisible()

    if not partyOpen then
        local loomBtn = waitForButtonFinder(function()
            return select(1, resolveLoomiansButton())
        end, GUI_READY_WAIT, true) or select(1, resolveLoomiansButton())
        if loomBtn then
            spots[#spots + 1] = {
                button = loomBtn,
                name = string.format("Loomians (step 1) rbx=%s", shortRbxId(getRbxId(loomBtn))),
                kind = "loomians",
            }
        end
    elseif not switchReady then
        local slotBtn, _, slotRbx = resolveTeamSlotButton(slot)
        if slotBtn then
            spots[#spots + 1] = {
                button = slotBtn,
                name = string.format("Slot %d (step 2) rbx=%s", slot, shortRbxId(slotRbx)),
                kind = "team",
            }
        end
    else
        local switchBtn, _, switchRbx = resolveSwitchConfirmButton()
        if switchBtn then
            spots[#spots + 1] = {
                button = switchBtn,
                name = string.format("Switch confirm (step 3) rbx=%s", shortRbxId(switchRbx)),
                kind = "switch",
            }
        end
    end

    return spots
end

local function clickTeamSwitchSpot(btn, name, kind)
    if not btn then return false end
    if kind == "loomians" then
        local spot = { button = btn, name = name, kind = kind }
        if not isSpotReadyForClick(spot) and not waitForSpotReady(spot, GUI_READY_WAIT) then
            return false
        end
        return clickSpot(spot)
    end
    if not waitForGuiReady(btn, GUI_READY_WAIT) then return false end
    return clickSpot({ button = btn, name = name, kind = kind })
end

runTeamSwitchClickSequence = function(slot)
    local lastErr = "switch sequence failed"

    local preview = rebuildTeamSwitchSpots(slot)
    waitForSpotsReadyNow(preview)
    showHighlights(preview)
    task.wait(HIGHLIGHT_PREVIEW_SEC)

    for attempt = 1, 6 do
        setStatus(string.format("Switch slot %d — pass %d/6", slot, attempt))
        refreshGui()

        if not isPartyMenuOpen() then
            setStatus(string.format("Switch slot %d — step 1/3: Loomians...", slot))
            refreshGui()
            local stepSpots = rebuildTeamSwitchSpots(slot)
            waitForSpotsReadyNow(stepSpots)
            showHighlights(stepSpots)
            unpulseAll()
            pulseMarker(1)

            local loomBtn, loomPath, _, loomErr = waitForLoomiansButton(LOOMIANS_FIND_WAIT)
            if not loomBtn then
                lastErr = loomErr or "Loomians button not found"
                task.wait(TEAM_SWITCH_STEP_WAIT)
            elseif clickTeamSwitchSpot(loomBtn, "Loomians (step 1)", "loomians") then
                task.wait(TEAM_SWITCH_STEP_WAIT)
                if not waitForPartyMenuOpen(PARTY_MENU_OPEN_WAIT) then
                    lastErr = "PartyMenu did not open after Loomians click"
                    task.wait(TEAM_SWITCH_STEP_WAIT)
                end
            end
        end

        if isPartyMenuOpen() and not isSwitchConfirmVisible() then
            setStatus(string.format("Switch slot %d — step 2/3: pick slot...", slot))
            refreshGui()
            local stepSpots = rebuildTeamSwitchSpots(slot)
            waitForSpotsReadyNow(stepSpots)
            showHighlights(stepSpots)
            unpulseAll()
            pulseMarker(1)

            local slotBtn, _, _, slotErr = waitForTeamSlotButton(slot, GUI_READY_WAIT)
            if not slotBtn then
                lastErr = slotErr or ("Slot" .. slot .. " not found")
                task.wait(TEAM_SWITCH_STEP_WAIT)
            elseif clickTeamSwitchSpot(slotBtn, string.format("Slot %d (step 2)", slot), "team") then
                task.wait(TEAM_SWITCH_STEP_WAIT)
            end
        end

        setStatus(string.format("Switch slot %d — step 3/3: confirm...", slot))
        refreshGui()
        local switchBtnPreview = select(1, resolveSwitchConfirmButton())
        if switchBtnPreview then
            local stepSpots = {
                {
                    button = switchBtnPreview,
                    name = "Switch confirm (step 3)",
                    kind = "switch",
                },
            }
            waitForSpotsReadyNow(stepSpots)
            showHighlights(stepSpots)
        end
        unpulseAll()
        pulseMarker(1)

        local switchBtn, _, _, switchErr = waitForSwitchConfirmButton(GUI_READY_WAIT)
        if switchBtn and clickTeamSwitchSpot(switchBtn, "Switch confirm (step 3)", "switch") then
            task.wait(TEAM_SWITCH_STEP_WAIT)
            clearHighlights()
            return true, nil
        end
        lastErr = switchErr or "SwitchButton not found"
        task.wait(TEAM_SWITCH_STEP_WAIT)
    end

    clearHighlights()
    return false, lastErr
end

executeTeamSlot = function(slot)
    if state.executing then
        if tick() - (state.pendingAt or 0) >= EXEC_STALE_SEC then
            state.executing = false
            clearHighlights()
        else
            return
        end
    end

    if slot == 1 or isActiveLeadSlot(slot) then
        setStatus(string.format(
            "Slot %d is the active lead — pick slots %d-%d to switch",
            slot, BATTLE_SWITCH_SLOT_MIN, BATTLE_SWITCH_SLOTS))
        refreshGui()
        return
    end

    if not isBattleSwitchSlot(slot) then
        setStatus(string.format(
            "Slot %d is benched — only slots %d-%d can switch during battle",
            slot, BATTLE_SWITCH_SLOT_MIN, BATTLE_SWITCH_SLOTS))
        refreshGui()
        return
    end

    local mon = state.party[slot]
    if mon and mon.fainted then
        setStatus(string.format("Slot %d (%s) is fainted", slot, mon.name or "?"))
        refreshGui()
        return
    end

    state.executing = true
    state.pendingSlot = slot
    state.pendingAction = "switch"
    state.pendingMoveName = mon and mon.name or ("Slot" .. slot)
    state.pendingAt = tick()

    setStatus(string.format("Switching to slot %d (Loomians → slot → confirm)...", slot))
    refreshGui()

    local ok, crashErr = pcall(function()
        local seqOk, lastErr = runTeamSwitchClickSequence(slot)
        if seqOk then
            applyPlayerSwitchByName(state.party[slot] and state.party[slot].name, nil)
            setStatus(string.format("Sent switch to slot %d — waiting for result...", slot))
        else
            setStatus(string.format("Could not switch slot %d — %s", slot, lastErr or "not found"))
        end
    end)

    state.executing = false
    state.pendingAction = nil
    state.pendingSlot = nil
    if not ok then
        Err.report(Err.make(Err.codes.REMOTE_HANDLER, "Switch action crashed: " .. tostring(crashErr), {
            slot = slot,
        }))
        clearHighlights()
    end
    refreshGui()
end

wireMoveButtons = function()
    for i = 1, 4 do
        local btn = guiRefs.moveButtons[i]
        if btn then
            trackMacroConnection(btn.MouseButton1Click:Connect(function()
                if not btn.Active then return end
                if type(idx(state.lead.moves, i)) ~= "table" then return end
                task.spawn(function()
                    task.wait(PANEL_CLICK_DELAY)
                    executeMoveSlot(i)
                end)
            end))
        end
    end
end

wireMiscButtons = function()
    for actionKey in pairs(MISC_ACTIONS) do
        local btn = guiRefs.miscButtons and guiRefs.miscButtons[actionKey]
        if btn then
            trackMacroConnection(btn.MouseButton1Click:Connect(function()
                task.spawn(function()
                    task.wait(PANEL_CLICK_DELAY)
                    executePanelAction(actionKey)
                end)
            end))
        end
    end
end

wireTeamButtons = function()
    local loomBtn = guiRefs.teamButtons and guiRefs.teamButtons.loomians
    if loomBtn then
        trackMacroConnection(loomBtn.MouseButton1Click:Connect(function()
            task.spawn(function()
                task.wait(PANEL_CLICK_DELAY)
                executePanelAction("loomians")
            end)
        end))
    end

    for i = 1, TEAM_SLOT_TOTAL do
        local slotBtn = guiRefs.teamButtons and guiRefs.teamButtons[i]
        if slotBtn then
            trackMacroConnection(slotBtn.MouseButton1Click:Connect(function()
                task.spawn(function()
                    task.wait(PANEL_CLICK_DELAY)
                    executeTeamSlot(i)
                end)
            end))
        end
    end
end

-- ===========================================================================
-- §11 Remote sniffing
-- ===========================================================================

updateLeadFromRequest = function(packet)
    local activeMon = getActiveMon(packet)
    if not activeMon then return false end

    if activeMon.name then
        state.lead.name = activeMon.name
    else
        local partyLead = getPartyLead(packet)
        if partyLead and partyLead.name then state.lead.name = partyLead.name end
    end

    local moves = copyMovesFromTable(activeMon.moves)
    if movesTableHasData(moves) then
        state.lead.moves = moves
        state.lead.types = inferLeadTypes(moves)
    end

    if activeMon.health then state.lead.health = activeMon.health end
    if activeMon.maxHealth then state.lead.maxHealth = activeMon.maxHealth end
    if activeMon.energy then state.lead.energy = activeMon.energy end
    if activeMon.maxEnergy then state.lead.maxEnergy = activeMon.maxEnergy end
    copyPartyFromPacket(packet)
    state.activePartySlot = resolveActivePartySlot(activeMon, state.party)
    return movesTableHasData(moves)
end

handleSideUpdatePacket = function(packet)
    if type(packet) ~= "table" then return end
    local side = packet.side
    if type(side) ~= "table" then return end
    local party = side.party or side.Party
    if type(party) ~= "table" then return end

    copyPartyFromPacket(packet)

    local activeMon = getActiveMon(packet)
    if activeMon then
        if activeMon.name then state.lead.name = activeMon.name end
        if activeMon.health then state.lead.health = activeMon.health end
        if activeMon.maxHealth then state.lead.maxHealth = activeMon.maxHealth end
        if activeMon.energy then state.lead.energy = activeMon.energy end
        if activeMon.maxEnergy then state.lead.maxEnergy = activeMon.maxEnergy end
        local moves = copyMovesFromTable(activeMon.moves)
        if movesTableHasData(moves) then
            state.lead.moves = moves
            state.lead.types = inferLeadTypes(moves)
        end
        state.activePartySlot = resolveActivePartySlot(activeMon, state.party)
    end

    refreshGui()
end

local function formatBattleTeamLine()
    local parts = {}
    for i = 1, BATTLE_SWITCH_SLOTS do
        local mon = state.party[i]
        if mon then
            parts[#parts + 1] = string.format("%d:%s%s", i, mon.name, mon.active and "*" or "")
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

handleMoveRequest = function(packet)
    if type(packet) ~= "table" or packet.requestType ~= "move" then return end
    local activeMon = getActiveMon(packet)
    if not activeMon or not movesTableHasData(activeMon.moves) then return end

    local rqid = packet.rqid
    if rqid ~= nil and rqid == state.lastRqid then return end

    updateLeadFromRequest(packet)
    state.lastRqid = rqid
    state.pendingSlot = nil
    state.pendingAction = nil

    local bestSlot = selectBestMoveSlot(activeMon.moves, activeMon.energy or 0)
    local waitGain = projectedEnergyGain("wait", activeMon.maxEnergy or state.lead.maxEnergy or 0)
    local restGain = projectedEnergyGain("rest", activeMon.maxEnergy or state.lead.maxEnergy or 0)
    local teamLine = formatBattleTeamLine()
    if bestSlot then
        local best = idx(activeMon.moves, bestSlot)
        setStatus(string.format("Your turn — ★ [%d] %s (%s) | Wait +%d E | Rest +%d E%s",
            bestSlot, best and best.move or "?", best and effectivenessShort(getMoveEffectiveness(best)) or "?",
            waitGain, restGain,
            teamLine and (" | Team: " .. teamLine) or ""))
    else
        setStatus(string.format("Your turn — low energy? Wait +%d E | Rest +%d E%s",
            waitGain, restGain, teamLine and (" | Team: " .. teamLine) or ""))
    end
    refreshGui()
end

local function slotFromIdent(ident)
    if type(ident) ~= "string" then return nil end
    if ident:find("1p2", 1, true) then return "enemy" end
    if ident:find("1p1", 1, true) then return "player" end
    return nil
end

processChartArg4 = function(arg4)
    if type(arg4) ~= "table" then return end

    for _, k in ipairs(sortedKeys(arg4)) do
        local line = tryDecodeChartLine(arg4[k])
        if type(line) == "table" then
            local event = tostring(idx(line, 1))

            if event == "switch" or event == "-switch" or event == "drag" then
                local side = slotFromIdent(line[2])
                local stats = parseStatsLineFull(line[3])
                if side == "player" then
                    local name = parseIdentName(line[2])
                    if stats and stats.name then name = stats.name end
                    applyPlayerSwitchByName(name, stats)
                    setStatus(string.format("Switched to %s (slot %s)",
                        name or "?", tostring(state.activePartySlot or "?")))
                    refreshGui()
                elseif side == "enemy" and stats then
                    state.enemyName = stats.name or line[2]
                    state.enemyHpBefore = stats.hp
                    state.enemyMaxHp = stats.maxHp
                end
            end

            if event == "move" then
                local actor = slotFromIdent(line[2])
                if actor == "player" then
                    local moveInfo = line[3]
                    local moveName = type(moveInfo) == "table" and moveInfo.name or nil
                    if moveName then
                        state.pendingMoveName = moveName
                    end
                    if moveName == "Wait" or moveName == "Rest" then
                        local maxE = state.lead.maxEnergy or 0
                        local expected = moveName == "Wait"
                            and projectedEnergyGain("wait", maxE)
                            or projectedEnergyGain("rest", maxE)
                        state.lastResult.move = moveName
                        state.lastResult.effectiveness = miscResultText(string.lower(moveName))
                        state.lastResult.damage = nil
                        setStatus(string.format("In-game: %s → %s (+%d energy est.)",
                            moveName, state.lastResult.effectiveness, expected))
                        state.pendingAction = nil
                        refreshGui()
                    end
                end
            end

            if event == "-boost" or event == "boost" then
                local side = slotFromIdent(line[2])
                if side == "player" and state.pendingMoveName == "Rest" then
                    setStatus("In-game: Rest → defense dropped 1 stage this turn")
                    refreshGui()
                end
            end

            if event == "unboost" then
                local side = slotFromIdent(line[2])
                if side == "player" and state.pendingMoveName == "Rest" then
                    setStatus("In-game: Rest → defense dropped 1 stage this turn")
                    refreshGui()
                end
            end

            if event == "-damage" then
                local target = line[2]
                local statsLine = line[3]
                local meta = line[4]
                local side = slotFromIdent(target)
                local hpCur, hpMax = parseHpFromStatsLine(statsLine)
                local seffective = type(meta) == "table" and (meta.seffective or idx(meta, "seffective"))

                if side == "enemy" and hpCur and state.pendingMoveName and tick() - state.pendingAt < 30 then
                    local before = state.enemyHpBefore
                    local damage = before and math.max(0, before - hpCur) or nil

                    state.lastResult.move = state.pendingMoveName
                    state.lastResult.effectiveness = effectivenessLong(seffective)
                    state.lastResult.damage = damage
                    state.lastResult.enemyHpAfter = string.format("%d/%d", hpCur, hpMax or hpCur)
                    state.enemyHpBefore = hpCur

                    setStatus(string.format("In-game: %s → %s%s",
                        state.pendingMoveName,
                        state.lastResult.effectiveness,
                        damage and (" | " .. damage .. " dmg") or ""))
                    state.pendingSlot = nil
                    refreshGui()
                elseif side == "player" and hpCur then
                    state.lead.health = hpCur
                    state.lead.maxHealth = hpMax or state.lead.maxHealth
                    refreshGui()
                end
            end

            if event == "-heal" or event == "heal" then
                local side = slotFromIdent(line[2])
                local hpCur, hpMax = parseHpFromStatsLine(line[3])
                if side == "enemy" and hpCur then
                    state.enemyHpBefore = hpCur
                    state.enemyMaxHp = hpMax or state.enemyMaxHp
                end
            end
        end
    end
end

local function looksLikeChartPacket(arg)
    if type(arg) ~= "table" or arg.requestType then return false end
    if arg[4] or arg[1] == "|" then return true end
    if tryDecodeChartLine(arg[3]) then return true end
    return false
end

onRemoteEvent = function(...)
    if not isActiveInstance() then return end
    local incoming = table.pack(...)
    Err.run("onRemoteEvent", function()
        for i = 1, incoming.n do
            local arg = incoming[i]
            if type(arg) == "table" then
                if arg.requestType == "move" and arg.active then
                    handleMoveRequest(arg)
                elseif arg.side and (arg.side.party or arg.side.Party) then
                    handleSideUpdatePacket(arg)
                elseif looksLikeChartPacket(arg) then
                    processChartArg4(arg)
                end
            end
        end
    end, { status = false })
end

local function installRemoteEventHooks()
    local hookedRemotes = G.__BattleMoveMacroHookedRemotes

    local function hookRemoteEvent(remote)
        if hookedRemotes[remote] then return end
        hookedRemotes[remote] = true
        local conn = remote.OnClientEvent:Connect(onRemoteEvent)
        trackMacroConnection(conn)
        state.connections[#state.connections + 1] = conn
    end

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "EVT" then hookRemoteEvent(obj) end
    end

    trackMacroConnection(ReplicatedStorage.DescendantAdded:Connect(function(obj)
        if obj:IsA("RemoteEvent") and obj.Name == "EVT" then hookRemoteEvent(obj) end
    end))
end

installRemoteEventHooks()

-- ===========================================================================
-- §12 Init & public API
-- ===========================================================================

if type(state) ~= "table" or type(state.party) ~= "table" then
    error("[BattleMoveMacro] state table missing — stop old script and reload battle_move_macro.lua")
end
if type(normalizeLabel) ~= "function" then
    error("[BattleMoveMacro] normalizeLabel missing — reload battle_move_macro.lua")
end
if not namesMatch("Twittle", "twittle") then
    error("[BattleMoveMacro] namesMatch broken — reload battle_move_macro.lua")
end
if not isActiveLeadSlot(1) then
    error("[BattleMoveMacro] " .. Err.format(Err.make(Err.codes.INIT_FAILED, "isActiveLeadSlot broken")))
end
if type(waitForBattleGui) ~= "function" or type(waitForSpotReady) ~= "function" then
    error("[BattleMoveMacro] GUI wait helpers missing — reload battle_move_macro.lua")
end
if type(isMoveSubmenuOpen) ~= "function" or type(waitForMoveSubmenu) ~= "function" then
    error("[BattleMoveMacro] Move submenu helpers missing — reload battle_move_macro.lua")
end
if type(isSwitchConfirmVisible) ~= "function" then
    error("[BattleMoveMacro] Switch confirm helper missing — reload battle_move_macro.lua")
end

createGui()
wireMoveButtons()
wireMiscButtons()
wireTeamButtons()

G.BattleMoveMacro = {
    version = SCRIPT_VERSION,
    instanceId = MACRO_INSTANCE_ID,
    getState = getState,
    isActiveInstance = isActiveInstance,
    Err = Err,
    errorCodes = Err.codes,
    getLastError = function() return state.lastError end,
    listErrors = function() return state.errorLog end,
    clearErrors = function()
        state.lastError = nil
        state.errorLog = {}
    end,
    formatError = Err.format,
    state = state,
    config = {
        clickOffsetX = clickOffsets.x,
        clickOffsetY = clickOffsets.y,
        highlightOffsetX = highlightOffsets.x,
        highlightOffsetY = highlightOffsets.y,
        setClickOffset = function(x, y)
            clickOffsets.x = x or 0
            clickOffsets.y = y or 0
        end,
        setHighlightOffset = function(x, y)
            highlightOffsets.x = x or 0
            highlightOffsets.y = y or 0
        end,
        setClickMode = function(mode)
            if mode == "raw" or mode == "inset" or mode == "highlight" then
                clickMode = mode
            end
        end,
        getClickMode = function() return clickMode end,
        guiReadyWait = GUI_READY_WAIT,
        setGuiReadyWait = function(sec)
            if type(sec) == "number" and sec >= 0 then
                GUI_READY_WAIT = sec
            end
        end,
        getGuiReadyWait = function() return GUI_READY_WAIT end,
        menuButtonRbxId = MENU_BUTTON.rbxid,
        setMenuButtonRbxId = function(id)
            MENU_BUTTON.rbxid = id and tostring(id) or nil
        end,
        setMiscButtonRbxId = function(actionKey, id)
            local cfg = getPanelActionConfig(actionKey)
            if cfg then cfg.probeRbxId = id and tostring(id) or nil end
        end,
        setTeamSlotProbe = function(slot, probe)
            if type(slot) ~= "number" then return end
            TEAM_SLOTS[slot] = TEAM_SLOTS[slot] or {}
            for k, v in pairs(probe or {}) do
                TEAM_SLOTS[slot][k] = v
            end
        end,
        setSwitchConfirmRbxId = function(id)
            SWITCH_CONFIRM.rbxid = id and tostring(id) or nil
        end,
        setPanelButtonScreenRank = function(actionKey, rank)
            local cfg = actionKey == "menu" and MENU_BUTTON or getPanelActionConfig(actionKey)
            if cfg then cfg.screenRank = tonumber(rank) end
        end,
        probePanelButton = function(actionKey)
            return probePanelButtonFromMouse(actionKey)
        end,
        listPanelLayout = listBattlePanelLayout,
        partyMenuTarget = PARTY_MENU_TARGET,
        setLoomiansSidePanelPick = function(mode)
            if TEAM_ACTIONS.loomians then
                TEAM_ACTIONS.loomians.sidePanelPick = mode or "rightmost"
            end
        end,
        SWITCH_CONFIRM = SWITCH_CONFIRM,
        TEAM_SLOTS = TEAM_SLOTS,
        TEAM_ACTIONS = TEAM_ACTIONS,
        TEAM_SLOT_TOTAL = TEAM_SLOT_TOTAL,
        BATTLE_SWITCH_SLOT_MIN = BATTLE_SWITCH_SLOT_MIN,
        BATTLE_SWITCH_SLOTS = BATTLE_SWITCH_SLOTS,
        TEAM_SWITCH_STEP_WAIT = TEAM_SWITCH_STEP_WAIT,
    },
    refreshGui = refreshGui,
    executeMoveSlot = executeMoveSlot,
    executeMiscAction = executeMiscAction,
    executePanelAction = executePanelAction,
    executeTeamSlot = executeTeamSlot,
    resolveTeamSlotButton = resolveTeamSlotButton,
    resolvePanelButtonByRole = resolvePanelButtonByRole,
    listBattlePanelLayout = listBattlePanelLayout,
    probePanelButtonFromMouse = probePanelButtonFromMouse,
    resolveLoomiansButton = resolveLoomiansButton,
    findLoomiansBattleButton = findLoomiansBattleButton,
    resolveLoomiansPanelButton = resolveLoomiansPanelButton,
    getPartyMenuStructure = getPartyMenuStructure,
    partyMenuTargetExists = partyMenuTargetExists,
    resolveSwitchConfirmButton = resolveSwitchConfirmButton,
    clickLoomiansButton = clickLoomiansButton,
    findPartyMenuMain = findPartyMenuMain,
    isBattleSwitchSlot = isBattleSwitchSlot,
    isActiveLeadSlot = isActiveLeadSlot,
    rebuildTeamSwitchSpots = rebuildTeamSwitchSpots,
    runTeamSwitchClickSequence = runTeamSwitchClickSequence,
    findMiscActionButton = findMiscActionButton,
    findMiscActionNode = findMiscActionNode,
    findMiscActionPair = findMiscActionPair,
    resolveMiscActionRow = resolveMiscActionRow,
    getMiscExpectedPath = getMiscExpectedPath,
    resolveMiscActionButton = resolveMiscActionButton,
    resolveBattleMenuButton = resolveBattleMenuButton,
    waitForBattleMenuButton = waitForBattleMenuButton,
    getRbxId = getRbxId,
    findBattleMenuButton = findBattleMenuButton,
    findBattleButtonByLabel = findBattleButtonByLabel,
    listBattleMenuButtons = listBattleMenuButtons,
    showHighlights = function(slot)
        showHighlights(buildClickSpots(slot, idx(state.lead.moves, slot)))
    end,
    clearHighlights = clearHighlights,
    stop = nil,
}

G.BattleMoveMacro.stop = function()
    if G.__BattleMoveMacroActiveInstance == MACRO_INSTANCE_ID then
        G.__BattleMoveMacroActiveInstance = nil
    end
    clearHighlights()
    disconnectAllMacroConnections()
    G.__BattleMoveMacroHookedRemotes = {}
    state.connections = {}
    if guiRefs.screenGui then pcall(function() guiRefs.screenGui:Destroy() end) end
    for k in pairs(guiRefs) do
        guiRefs[k] = nil
    end
    print("[BattleMoveMacro] Stopped")
end

print("[BattleMoveMacro] Ready (" .. SCRIPT_VERSION .. ") instance=" .. MACRO_INSTANCE_ID:sub(-8))
print("[BattleMoveMacro] Click mode: highlight (VIM = yellow circle) | config.setClickMode('raw'|'inset')")
print("[BattleMoveMacro] Click a move, Wait, Rest, or Loomians on the panel")
print("[BattleMoveMacro] Loomians = flat side panel → WatchContainer.PartyMenu.PartyMain (Slot1-7)")
print("[BattleMoveMacro] Fight = nested submenu panel | Loomians = label/name match, else rightmost non-Items/Run panel")
print("[BattleMoveMacro] Override: config.probePanelButton('loomians') or config.setLoomiansSidePanelPick('leftmost')")
print("[BattleMoveMacro] Stop: getgenv().BattleMoveMacro.stop()")
