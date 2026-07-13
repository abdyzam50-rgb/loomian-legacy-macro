-- ts file was generated at discord.gg/25ms

local u1 = 'Loomian Legacy - 306964494'

warn('\n=>=>=>  ' .. u1 .. ' Script Loading...  <=<=<=\n')

local v2 = MrJackTable

if v2 then
    if type(MrJackTable.VenyxLibrary) ~= 'function' then
        v2 = false
    else
        v2 = MrJackTable.VenyxLibrary()
    end
end
if not IrisNotificationMrJack then
    loadstring(game:HttpGet('https://raw.githubusercontent.com/thedragonslayer2/hey/main/Misc./iris%20notification%20function'))()
end
if not v2 or v2.MrJack ~= 'MrJackIsCool' then
    return loadstring(game:HttpGet('https://thedragonslayer2.github.io'))()
end
if not (getgc or debug.getregistry) then
    if IrisNotificationUserMrJack then
        IrisNotificationUserMrJack.ClearAllNotifications()
    end

    return IrisNotificationMrJack(2, 'Executor not Supported! D:', 'A Function is Missing!\n\nPlease Download a better Executor!', 10)
end

local u3 = pcall(function()
    return game:GetService('CoreGui')['keonelibbary/gui']
end)
local u4 = {}
local u5 = nil
local u6 = nil
local u7 = nil
local u8 = nil
local u9 = nil
local v10 = {}
local u11 = {}
local u12 = nil
local v13 = false

if v13 then
    v13 = CreateHookMetaMethod:Index() or CreateHookMetaMethod.Indexes
end

local u14 = false

pcall(function()
    u4 = GetSavedSettings('MrJack Settings/' .. u1 .. '.json', tostring(client.UserId))
end)

local function u21()
    pcall(function()
        ForLooP(getgc(true), function(_, p15)
            if typeof(p15) == 'table' and rawget(p15, 'Utilities') and not (u5 and u5.Battle) then
                u5 = p15
            end
        end)
    end)

    if not u5 then
        pcall(function()
            ForLooP(debug.getregistry(), function(_, p16)
                if typeof(p16) == 'function' and not (u5 and u5.Battle) then
                    pcall(function()
                        local v17 = next
                        local v18, v19 = getupvalues(p16)

                        while true do
                            local u20

                            v19, u20 = v17(v18, v19)

                            if v19 == nil then
                                break
                            end
                            if typeof(u20) == 'table' and not (u5 and u5.Battle) then
                                pcall(function()
                                    if u20.Utilities then
                                        u5 = u20
                                    end
                                end)
                            end
                        end
                    end)
                end
            end)
        end)
    end
end

pcall(function()
    while not u5 do
        u21()

        if u5 and not u3 then
            return
        end
        if not u6 then
            u6 = AbstractPooNotif():notify({
                Title = 'Notification',
                Description = 'Waiting for Game to Load...',
                Length = 9000000000,
            })
        end
        if u3 then
            while task.wait() do end
        end

        task.wait(7.5)
    end
end)

if u6 then
    u6()
end

wait(0.5)

local function u22()
    return u5.Battle.currentBattle
end
local function u23()
    return u22().yourSide.active[1]
end
local function u25()
    local v24

    if u4['Auto Heal'] then
        if u9 then
            v24 = false
        else
            v24 = u5.Network:get('PDS', 'areFullHealth')
        end
    else
        v24 = true
    end

    return v24
end
local function u28()
    local v26 = u23()
    local v27

    if v26.shiny == u5.Constants.CORRUPT_GLEAM_NUM then
        v27 = false
    else
        v27 = v26.shiny
    end

    return v27
end
local function u29()
    return table.find(u4['Auto Hunt'].Loomians, tostring(u23().name):lower())
end
local function u33()
    local v30 = u22()
    local _AutoHunt = u4['Auto Hunt']

    if v30 and (v30.kind == 'wild' and not u23().corrupt) then
        local v32 = u28()

        return v32 == 1 and _AutoHunt.Gleam or v32 == 2 and _AutoHunt.Gamma or (not u23().owned and _AutoHunt.NotOwned or u29())
    end
end
local function u37(p34)
    local _BattleGui = u5.BattleGui

    if u22().state == 'input' and not u7 then
        if not _BattleGui.onMoveClicked then
            _BattleGui:mainButtonClicked(1)
        end

        local v36 = _BattleGui.moves[p34]

        if v36.energy and _BattleGui.activeMonster.energy < v36.energy and not _BattleGui.activeMonster.bypassEnergy then
            _BattleGui.fightSelectionGroup:LoseFocus()
            _BattleGui.inputEvent:fire('rest 0')
            _BattleGui:exitButtonsMoveChosen()
        elseif not v36.disabled then
            _BattleGui:onMoveClicked(p34)
        end
    end
end
local function v39()
    local v38 = u22()

    if v38 and (v38.CanRun ~= false and u8) then
        u5.BattleGui.IdleCameraController:quit(v38)

        v38.ended = true

        v38.BattleEnded:Fire()
    end
end

local u40 = setthreadcontext

if u40 then
    u40 = u5.Battle.setupScene
end

local u41 = setthreadcontext or function(_) end

if u40 then
    function u5.Battle.setupScene(...)
        u41(2)

        return u40(...)
    end

    local _loadModule = u5.DataManager.loadModule

    function u5.DataManager.loadModule(...)
        u41(2)

        return _loadModule(...)
    end

    local _loadChunk = u5.DataManager.loadChunk

    function u5.DataManager.loadChunk(...)
        u41(2)

        return _loadChunk(...)
    end
end

LooP(function()
    local v44 = next
    local v45 = u11
    local v46 = nil

    while true do
        local v47

        v46, v47 = v44(v45, v46)

        if v46 == nil then
            break
        end

        local v48

        if u5.Menu.shop.shopId then
            v48 = false
        else
            v48 = u5.Network:get('PDS', 'getShop', v47.ShopId)
        end
        if not v48 then
            return
        end

        local v49 = next
        local v50 = nil

        while true do
            local v51

            v50, v51 = v49(v48, v50)

            if v50 == nil then
                break
            end

            v47.Func(v51)
        end

        if v47.CanAutoBuy() then
            for _ = 1, 10 do
                local v52 = next
                local _Enabled = v47.Enabled
                local v54 = nil

                while true do
                    local v55

                    v54, v55 = v52(_Enabled, v54)

                    if v54 == nil then
                        break
                    end

                    u5.Network:get('PDS', 'buyItem', v54, 1)
                end
            end
        end
    end
end)
LooP(function()
    if u22() and client.PlayerGui.MainGui:FindFirstChild('BattleGui', true) then
        task.wait(3)

        u8 = true

        repeat
            wait()
        until not u22()
    else
        u8 = false
    end
end)

local _showProgressUpdate = u5.Menu.mastery.showProgressUpdate

function u5.Menu.mastery.showProgressUpdate(...)
    if not u4.MiscSettings.NoProgress then
        return _showProgressUpdate(...)
    end
end

local v57 = next
local _badgeId = u5.Assets.badgeId
local v59 = nil

while true do
    local u60, v61 = v57(_badgeId, v59)

    if u60 == nil then
        break
    end

    v59 = u60

    if typeof(v61) == 'number' and (u60:sub(1, 5) == 'Medal' and u60:sub(7, 7) == '') and v61 ~= 0 then
        task.spawn(function()
            while task.wait() do
                local v62 = u5.DataManager:getModule('BattleTheatre' .. u60:sub(6, 6))

                if v62 then
                    function v62.EnablePuzzleControls()
                        return true
                    end
                    function v62.enablePuzzleControls()
                        return true
                    end
                end
            end
        end)
    end
end

task.spawn(function()
    local v63 = nil

    while task.wait() and not v63 do
        v63 = u5.DataManager:getModule('Mining')
    end

    function v63.DecrementBattery() end
    function v63.SetBattery() end

    local _Model = Instance.new('Model', workspace)

    Instance.new('Highlight', _Model)

    while task.wait() do
        local v65 = next
        local _MinePoints = v63.MinePoints
        local v67 = nil

        while true do
            local v68

            v67, v68 = v65(_MinePoints, v67)

            if v67 == nil then
                break
            end
            if task.wait() and v68.Part and not v68.Part:GetAttribute('OnlyOnce') and not v68.Part:SetAttribute('OnlyOnce', true) then
                v68.Part.Parent = _Model
            end
        end
    end
end)

function u5.Menu.options.resetLastUnstuckTick() end

LooP(function()
    if u5.MasterControl.WalkEnabled and not u22() then
        workspace.Camera.FieldOfView = 70
    end
end)

local _switchMonster = u5.BattleGui.switchMonster

function u5.BattleGui.switchMonster(...)
    u41(2)

    local v70 = ({...})[3] == false

    if v70 then
        u7 = true
    end

    local v71 = {
        _switchMonster(...),
    }

    if v70 then
        u7 = nil
    end

    return unpack(v71)
end

local v72 = next
local v73, v74 = u5.Menu.map.getAvailableTravelLocationInfo()

while true do
    local v75

    v74, v75 = v72(v73, v74)

    if v74 == nil then
        break
    end

    table.insert(v10, v75.name)
end

local _doTrainerBattle = u5.Battle.doTrainerBattle

function u5.Battle.doTrainerBattle(...)
    while not u25() do
        task.wait()
    end

    u41(2)

    return _doTrainerBattle(...)
end

local u77 = v2.new(u1:split(' - ')[1])

u77:toggle()

local _addPage = u77.addPage

function u77.addPage(...)
    task.wait(0.5)

    return _addPage(...)
end

local _Main = u77:addPage('Main')
local _Main2 = _Main:addSection('Main')

_Main2:addToggle('Auto Heal[Outdoor Only]', u4['Auto Heal'], function(p81)
    u4['Auto Heal'] = p81
end)
LooP(function()
    xpcall(function()
        local _currentChunk = u5.DataManager.currentChunk

        if u4['Auto Heal'] and (u5.MasterControl.WalkEnabled and u5.Menu.enabled) and not (_currentChunk.indoors or u22() or u5.ObjectiveManager.disabledBy.LoomianCare) and not u5.Network:get('PDS', 'areFullHealth') then
            if _currentChunk.data.HasOutsideHealers then
                u5.Network:get('heal', nil, 'HealMachine1')
            else
                local v83 = _currentChunk.regionData and _currentChunk.regionData.BlackOutTo or _currentChunk.data.blackOutTo
                local _id = _currentChunk.id
                local _CFrame = client.character.PrimaryPart.CFrame

                if v83 then
                    local _MasterControl = u5.MasterControl

                    u9 = true
                    _MasterControl.WalkEnabled = false

                    u5.Menu:disable()
                    u5.Menu:fastClose(3)
                    u5.Utilities.FadeOut(1)
                    task.spawn(function()
                        u5.NPCChat:Say('[ma][MrJack]Auto healing...')
                    end)
                    u5.Utilities.TeleportToSpawnBox()
                    _currentChunk:unbindIndoorCam()
                    _currentChunk:destroy()
                    u41(2)

                    _currentChunk = u5.DataManager:loadChunk(v83)
                end

                local _HealthCenter = _currentChunk:getRoom('HealthCenter', _currentChunk:getDoor('HealthCenter'), 1)
                local _Network = u5.Network
                local _get = _Network.get
                local v90 = task.wait()
                local v91 = _get(_Network, 'getHealer', v90 and 'HealthCenter' or v90)

                if v91 then
                    u5.Network:get('heal', 'HealthCenter', v91)
                end

                _HealthCenter:Destroy()

                if v83 then
                    _currentChunk:destroy()
                    u5.DataManager:loadChunk(_id)
                    u5.Utilities.Teleport(_CFrame)
                    u5.Menu:enable()
                    u5.NPCChat:manualAdvance()
                    u5.Utilities.FadeIn(1)

                    local _MasterControl2 = u5.MasterControl

                    u9 = nil
                    _MasterControl2.WalkEnabled = true
                end
            end
        end
    end, function(...)
        warn('Main | Auto Heal -', ...)
    end)
end, 0.1)
_Main2:addToggle('Active Repellent', u4['Infinite Repel'], function(p93)
    u4['Infinite Repel'] = p93
end)
LooP(function()
    if u5.Repel.steps < 10 or (not u4['Infinite Repel'] or u12) then
        u5.Repel.steps = (u12 or not u4['Infinite Repel']) and 0 or (100 or 0)
    end
end)

if u14 then
    local u94 = {}

    _Main2:addToggle('Ignore NPC Battle', u4['Ignore NPC Battle'], function(p95)
        u4['Ignore NPC Battle'] = p95
    end)

    local _GetBit = u5.BitBuffer.GetBit

    function u5.BitBuffer.GetBit(...)
        local v97 = {...}

        if not (table.find(u94, u5.DataManager.currentChunk.map) or table.clear(u94)) then
            table.insert(u94, u5.DataManager.currentChunk.map)
        end
        if v97[1] == u5.PlayerData.defeatedTrainers and v97[2] then
            if u4['Ignore NPC Battle'] and table.find(u94, v97[2]) then
                return true
            end
            if not table.find(u94, v97[2]) then
                table.insert(u94, v97[2])
            end
        end

        u41(2)

        return _GetBit(...)
    end
end
if getthreadcontext then
    getthreadcontext()
end

_Main2:addToggle('Skip Dialogue', u4['Skip Dialogue'], function(p98)
    u4['Skip Dialogue'] = p98
end)

local function u106(_, ...)
    local v99 = {...}
    local v100 = {}
    local v101 = nil

    if typeof(v99[2]) == 'string' then
        if v99[2]:sub(1, 8) == '[NoSkip]' then
            return {
                v99[1],
                v99[2]:sub(9),
            }, true
        end
        if v99[2]:sub(1, 5):lower() == '[y/n]' then
            if u4.MiscSettings.NoSwitch and v99[2]:find('Will you switch Loomians') then
                v99[2] = 'Auto Deny Swicth Question Enabled!'
            elseif u4.MiscSettings.NoNick and v99[2]:find('Give a nickname to the') then
                v99[2] = 'Auto Deny Nickname Enabled!'
            elseif u4.MiscSettings.NoNewMoves then
                if v99[2]:find('reassign its moves') then
                    v99[2] = 'Auto Deny Reassign Move Enabled!'
                elseif v99[2]:find(' to give up on learning ') then
                    return 'Y/N', true
                end
            end
        end
    end
    if u4['Skip Dialogue'] then
        local v102 = next
        local v103 = nil

        while true do
            local v104

            v103, v104 = v102(v99, v103)

            if v103 == nil then
                break
            end
            if typeof(v104) ~= 'string' then
                v100[#v100 + 1] = v104
            else
                local v105

                if v104:sub(1, 5):lower() ~= '[y/n]' then
                    if v104:sub(1, 9):lower() ~= '[gamepad]' then
                        v105 = v104
                    else
                        v105 = v104:sub(10)
                    end
                else
                    v100[#v100 + 1] = v104
                    v105 = v104:sub(6)
                    v101 = true
                end
                if v105:sub(1, 4):lower() == '[ma]' or v105:sub(1, 5) == '[pma]' then
                    v100[#v100 + 1] = v104
                    v101 = true
                end
            end
        end
    else
        v100 = v99
        v101 = true
    end

    return v100, v101
end
local function v112(p107, p108)
    local u109 = p107[p108]

    p107[p108] = function(...)
        local v110, v111 = u106(p108, ...)

        if v110 == 'Y/N' then
            return v111
        end
        if v111 then
            u41(2)

            local _ = unpack
        end
    end
end

v112(u5.BattleGui, 'message')
v112(u5.NPCChat, 'Say')
v112(u5.NPCChat, 'say')
_Main2:addToggle('Fast Battle', u4['Fast Battle'], function(p113)
    u4['Fast Battle'] = p113
end)

local v114 = next
local v115 = {
    [u5.BattleClientSprite] = {
        animFaint = 1,
        animSummon = 1,
        animUnsummon = 1,
        monsterIn = 1,
        monsterOut = 1,
        animEmulate = 1,
        animScapegoat = 1,
        animScapegoatFade = 1,
        animRecolor = 1,
    },
    [u5.BattleClientSide] = {
        switchOut = 1,
        faint = 1,
        swapTo = 1,
        dragIn = 1,
    },
}
local v116 = nil

local function v123(p117, p118, p119)
    local u120 = p118[p117]

    if u120 then
        p118[p117] = function(...)
            u41(2)

            local v121 = {...}

            v121[p119].battle.fastForward = u4['Fast Battle']

            local v122 = {
                u120(unpack(v121)),
            }

            v121[p119].battle.fastForward = false

            return unpack(v122)
        end
    end
end

while true do
    local v124

    v116, v124 = v114(v115, v116)

    if v116 == nil then
        break
    end

    local v125 = next
    local v126 = v116
    local v127 = nil

    while true do
        local v128

        v127, v128 = v125(v124, v127)

        if v127 == nil then
            break
        end

        v123(v127, v126, v128)
    end
end

local v129 = next
local v130 = {
    [u5.BattleGui] = {
        'animWeather',
        'animStatus',
        'animAbility',
        'animBoost',
        'animHit',
        'animMove',
    },
}
local v131 = nil

local function v135(p132, p133)
    local u134 = p133[p132]

    if u134 then
        p133[p132] = function(...)
            u41(2)

            local _ = u4['Fast Battle']
        end
    end
end

while true do
    local v136

    v131, v136 = v129(v130, v131)

    if v131 == nil then
        break
    end

    local v137 = next
    local v138 = v131
    local v139 = nil

    while true do
        local v140

        v139, v140 = v137(v136, v139)

        if v139 == nil then
            break
        end

        v135(v140, v138)
    end
end

local _setCameraIfLookingAway = u5.BattleGui.setCameraIfLookingAway

function u5.BattleGui.setCameraIfLookingAway(p142, p143)
    p143.fastForward = u4['Fast Battle']

    local v144 = {
        _setCameraIfLookingAway(p142, p143),
    }

    p143.fastForward = false

    return unpack(v144)
end

local _setFillbarRatio = u5.RoundedFrame.setFillbarRatio

function u5.RoundedFrame.setFillbarRatio(...)
    local v146 = {...}

    if u4['Fast Battle'] and u22() then
        v146[3] = false
    end

    return _setFillbarRatio(unpack(v146))
end

if u14 then
    _Main2:addButton('End Battle', v39)
end
if v13 then
    v13.WalkSpeed = v13.WalkSpeed or {}

    table.insert(v13.WalkSpeed, function(_, p147)
        local v148 = p147[1]
        local _Character = client.Character

        if _Character then
            _Character = client.Character:FindFirstChild('Humanoid')
        end
        if v148 == _Character then
            return true, 16
        end
    end)
    _Main2:addSlider('WalkSpeed', u4.WalkSpeed or 16, 0, 250, 0.1, function(p150)
        u4.WalkSpeed = p150
    end)
    LooP(function()
        if u4.WalkSpeed and u4.WalkSpeed ~= 0 then
            client.Character.Humanoid.WalkSpeed = u4.WalkSpeed or 16
        elseif u4.WalkSpeed == 0 then
            local _Humanoid = client.Character.Humanoid

            u4.WalkSpeed = nil
            _Humanoid.WalkSpeed = 16
        end
    end)
end

local _GUIs = _Main:addSection('GUIs')

_GUIs:addButton('Open Rally Team', function()
    u5.Menu:disable()
    u5.Menu.rally:openRallyTeamMenu()
    u5.Menu:enable()
end)
_GUIs:addButton('Open Rallied', function()
    pcall(function()
        if u5.Network:get('PDS', 'ranchStatus').rallied > 0 then
            u5.Menu:disable()
            u5.Menu.rally:openRalliedMonstersMenu()
            u5.Menu:enable()
        end
    end)
end)
_GUIs:addButton('Open PC', function()
    u5.Menu.pc:bootUp()
end)
_GUIs:addButton('Open Shop', function()
    u5.Menu:disable()
    u5.Menu.shop:open()
    u5.Menu:enable()
end)
_GUIs:addButton('Junk 4 Junk', function()
    u5.Menu:disable()
    u5.Menu.shop:open('fishtrash')
    u5.Menu:enable()
end)

local _Misc = u77:addPage('Misc')

if not u4.MiscSettings then
    u4.MiscSettings = {}
end

local _MiscSettings = _Misc:addSection('Misc Settings')
local _MiscSettings2 = u4.MiscSettings

local function v159(p156, p157)
    _MiscSettings:addToggle(p156, _MiscSettings2[p157], function(p158)
        _MiscSettings2[p157] = p158
    end)
end

v159('Deny Reassign Move', 'NoNewMoves')
v159('Deny Switch Request', 'NoSwitch')
v159('Deny Nickname Request', 'NoNick')
v159('Disable Show Progress', 'NoProgress')

local _AutoFish = _Misc:addSection('Auto Fish')

_AutoFish:addToggle(u40 and 'Enabled' or 'Enabled(will only get items)', u4.AutoFish, function(p161)
    u4.AutoFish = p161
end)

if u40 then
    _AutoFish:addToggle('Items Only', u4.AutoFish, function(p162)
        u4.AutoFishOnlyItems = p162
    end)
end

local _OnWaterClicked = u5.Fishing.OnWaterClicked
local u164 = nil

LooP(function()
    pcall(function()
        if u164 and not u164:IsDescendantOf(workspace) then
            u164 = nil
        end

        ForLooP(u5.DataManager.currentChunk.map:GetChildren(), function(_, p165)
            if p165.Name ~= 'Water' or not p165 then
                p165 = p165:FindFirstChild('Water')
            end
            if task.wait() and p165 and p165:FindFirstChild('Mesh') then
                u164 = p165
            end
        end)
    end)
end)

function u5.Fishing.FishMiniGame(p166, _, _, p167, p168)
    local _Fishing = u5.DataManager.currentChunk.regionData.Fishing
    local v170 = next
    local _regionData = u5.DataManager.currentChunk.regionData
    local v172 = nil

    while true do
        local v173

        v172, v173 = v170(_regionData, v172)

        if v172 == nil then
            break
        end
        if not _Fishing and typeof(v173) == 'table' and v172 == 'Fishing' then
            if v173.id then
                _Fishing = v173
            end
        end
    end

    local v174 = next
    local _regions = u5.DataManager.currentChunk.data.regions
    local v176 = nil

    while true do
        local v177

        v176, v177 = v174(_regions, v176)

        if v176 == nil then
            break
        end

        local v178 = next
        local v179 = nil

        while true do
            local v180

            v179, v180 = v178(v177, v179)

            if v179 == nil then
                break
            end
            if not _Fishing and typeof(v180) == 'table' and v179 == 'Fishing' then
                if v180.id then
                    _Fishing = v180
                end
            end
        end
    end

    local v181

    if _Fishing then
        v181 = _Fishing.id
    else
        v181 = _Fishing
    end
    if u164 and v181 then
        local _rod = u5.Fishing.rod
        local v183

        if p166 == 'MrJack' then
            local v184 = u164.Position + Vector3.new(0, u164.Size.Y - 5, 0)
            local v185 = nil
            local v186 = RaycastParams.new()

            v186.FilterDescendantsInstances = {
                workspace.Terrain,
            }
            v186.IgnoreWater = false
            v186.FilterType = Enum.RaycastFilterType.Whitelist

            local v187 = workspace:Raycast(v184 + Vector3.new(0, 3, 0), Vector3.new(0.001, -10, 0.001), v186)

            if v187 and v187.Material == Enum.Material.Water then
                v184 = v187.Position
            end
            if _rod then
                _rod.postPoseUpdates = true
            else
                local v188

                v188, v185 = u5.Network:get('PDS', 'fish', v184, v181)
                _rod = v188 and {
                    model = v188,
                    bobberMain = v188.Bobber.Main,
                    string = v188.Bobber.Main.String,
                } or _rod
                u5.Fishing.rod = _rod
            end

            v183 = not v185 and select(2, u5.Network:get('PDS', 'fish', v184, v181))

            if v183 then
                u5.Fishing.rod.postPoseUpdates = v183.rep
            end
            if _rod and _rod.model then
                _rod.model.Parent = nil
            end
        else
            v183 = {
                id = p168,
                delay = true,
            }
        end
        if v183 and v183.delay then
            return 0.9, u5.Network:get('PDS', 'fshchi', p167 or v183.id), _Fishing
        else
            return false
        end
    else
        return false
    end
end
function u5.Fishing.OnWaterClicked(...)
    if u5.MasterControl.WalkEnabled then
        if u4.AutoFish then
            return IrisNotificationMrJack(1, 'Notification', 'Please Turn Off Auto Fish.', 2)
        end

        u41(2)

        return _OnWaterClicked(...)
    end
end

LooP(function()
    pcall(function()
        if u4.AutoFish and u5.PlayerData.completedEvents.mabelRt8 then
            local _MrJack, v190, v191 = u5.Fishing.FishMiniGame('MrJack')

            if _MrJack and u4.AutoFish then
                if v190 == true and u40 and not u4.AutoFishOnlyItems then
                    u5.Battle:doWildBattle(v191, {
                        dontExclaim = true,
                        fshPct = _MrJack,
                    })
                else
                    u5.Network:post('PDS', 'reelIn')
                end

                task.wait(0.5)
            end

            u5.Fishing:DisableRodModel(v190 ~= true and true or nil)
        end
    end)
end)

local _AutoDiscDrop, u193 = _Misc:addSection('Auto Disc Drop')

_AutoDiscDrop:addToggle('Enabled', nil, function(p194)
    u193 = p194
end)
_AutoDiscDrop:addToggle('Fast Mode', u4.FastDiscDrop, function(p195)
    u4.FastDiscDrop = p195
end)
task.spawn(function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/thedragonslayer2/MrJack-Game-List/main/Functions/Loomian%20Legacy%20-%20306964494/Disc%20Drop.lua'))()

    local u196, u197 = getgenv().LoomianLegacyAutoDisDrop(u4, u5)

    LooP(function()
        pcall(function()
            if u193 and (u5.ArcadeController.playing and u197()) and u197().gui.GridFrame:IsDescendantOf(client.PlayerGui) then
                if u197().gameEnded then
                    u197():CleanUp()
                    u197():new()
                else
                    u196()
                end
            end
        end)
    end)
end)

if not u4['Auto Hunt'] then
    u4['Auto Hunt'] = {}
end

local _AutoHunt2 = u77:addPage('Auto Hunt')
local _AutoHunt3 = u4['Auto Hunt']
local _AutoHunt4 = _AutoHunt2:addSection('Auto Hunt')
local v201 = debug.getinfo or getgenv().getinfo
local v202, v203, v204 = pairs(getupvalues(u5.WalkEvents.beginLoop))
local u205 = nil
local u206 = nil
local u207 = {}
local u208 = {}
local u209 = {}
local u210 = nil

while true do
    local v211

    v204, v211 = v202(v203, v204)

    if v204 == nil then
        break
    end
    if typeof(v211) == 'function' and v201 then
        if v201(v211).name == 'onStepTaken' then
            u205 = v211
        end
    end
end

_AutoHunt4:addToggle('Auto Encounter', nil, function(p212)
    u12 = p212
end)
LooP(function()
    pcall(function()
        if u5.MasterControl.WalkEnabled and (u12 and u5.Menu.enabled) and (not u22() and u5.PlayerData.completedEvents.ChooseBeginner and u25()) then
            u205(true)
        end
    end)
end)

local v213

if u14 then
    v213 = nil
else
    v213 = _AutoHunt3.Disc or nil
end

_AutoHunt3.Disc = v213

local u214

if u14 then
    u214 = _AutoHunt4:addDropdown(_AutoHunt3.Disc or 'Select Disc', u207, function(p215)
        _AutoHunt3.Disc = p215
    end)
else
    u214 = u14
end

LooP(function()
    pcall(function()
        local _PDS = u5.Network:get('PDS', 'getBagPouch', 3)
        local v217 = next
        local v218 = nil
        local v219 = {}
        local v220 = nil
        local v221 = nil

        while true do
            local v222

            v218, v222 = v217(_PDS, v218)

            if v218 == nil then
                break
            end
            if not table.find(u207, v222.name) then
                table.insert(u207, v222.name)

                u208[v222.name] = v222.id
                v220 = true
            end

            v221 = _AutoHunt3.Disc and v222.name == _AutoHunt3.Disc and true or v221

            if not u209[v222.name] then
                local v223 = u210

                u209[v222.name] = v223:addButton('')
            end

            u210:updateButton(u209[v222.name], v222.name .. ': ' .. v222.qty)
            table.insert(v219, v222.name)
        end

        local v224 = next
        local v225 = u207
        local v226 = nil

        while true do
            local v227

            v226, v227 = v224(v225, v226)

            if v226 == nil then
                break
            end
            if not table.find(v219, v227) then
                u210:updateButton(u209[v227], v227 .. ': 0')

                return table.remove(u207, v226)
            end
        end

        if v220 or not v221 then
            if not v221 then
                _AutoHunt3.Disc = nil
            end
            if u14 then
                _AutoHunt4:updateDropdown(u214, _AutoHunt3.Disc or 'Select Disc', u207, function(p228)
                    _AutoHunt3.Disc = p228
                end, true)
            end
        end
    end)
end)

if u14 then
    task.wait(0.1)

    local function v232(p229, p230)
        _AutoHunt4:addToggle(p229, _AutoHunt3[p230], function(p231)
            _AutoHunt3[p230] = p231
        end)
    end

    v232('Use Spare', 'Spare')
    v232('Catch Not Owned', 'NotOwned')
    v232('Catch Normal Gleam', 'Gleam')
    v232('Catch Gamma Gleam', 'Gamma')

    if not _AutoHunt3.Loomians then
        _AutoHunt3.Loomians = {}
    end

    local _CatchListedLoomians = _AutoHunt2:addSection('Catch Listed Loomians')
    local _Loomians = _AutoHunt3.Loomians
    local u235 = nil

    local function u237(p236)
        table.remove(_Loomians, table.find(_Loomians, p236))
        task.delay(0.25, function()
            _CatchListedLoomians:updateDropdown(u235, 'List', _Loomians, u237, true)
        end)
    end

    local v238 = _CatchListedLoomians

    u235 = _CatchListedLoomians.addDropdown(v238, 'List', _Loomians, u237)

    local v239 = _CatchListedLoomians

    _CatchListedLoomians.addTextbox(v239, 'Add Loomian', 'Name', function(p240, p241)
        if p241 then
            if not table.find(_Loomians, p240:lower()) then
                table.insert(_Loomians, p240:lower())
            end

            _CatchListedLoomians:updateDropdown(u235, 'List', _Loomians, u237, true)
        end
    end)
    task.wait(0.1)

    local _DefeatCorrupt = _AutoHunt2:addSection('Defeat Corrupt')
    local v243 = {
        'Disabled',
    }

    for v244 = 1, 4 do
        table.insert(v243, 'Move ' .. v244)
    end

    if not _AutoHunt3.CorruptMove then
        _AutoHunt3.CorruptMove = 'Disabled'
    end

    _DefeatCorrupt:addDropdown(_AutoHunt3.CorruptMove, v243, function(p245)
        _AutoHunt3.CorruptMove = p245
    end)

    local _Mode = _AutoHunt2:addSection('Mode')
    local v247 = {
        'Disabled',
        'Run',
    }

    for v248 = 1, 4 do
        table.insert(v247, 'Move ' .. v248)
    end

    _Mode:addDropdown('Disabled', v247, function(p249)
        u206 = p249
    end)
end

local _AutoBuyDisc = _AutoHunt2:addSection('Auto Buy Disc')
local u251 = {}
local u253 = {
    CanAutoBuy = function()
        return true
    end,
    Enabled = {},
    Func = function(p252)
        if p252.name and p252.id and (p252.id:sub(#p252.id - 3, #p252.id) == 'disc' and typeof(p252.price) == 'number' and not u251[p252.name]) then
            u251[p252.name] = p252
        end
    end,
}

LooP(function()
    local v254 = next
    local v255 = u251
    local v256 = nil

    while true do
        local u257

        v256, u257 = v254(v255, v256)

        if v256 == nil then
            break
        end
        if typeof(u257) ~= 'Instance' then
            local v258 = _AutoBuyDisc

            u251[u257.name] = v258:addToggle(u257.name, nil, function(p259)
                u253.Enabled[u257.id] = p259 or nil
            end)
        end
    end
end)
table.insert(u11, u253)
LooP(function()
    pcall(function()
        if u22().state == 'input' and (u12 and u14) then
            local v260 = u23()

            if u33() then
                local v261 = next
                local _moves = u5.BattleGui.moves
                local v263 = nil

                while true do
                    local v264

                    v263, v264 = v261(_moves, v263)

                    if v263 == nil then
                        break
                    end
                    if v264.move == 'Spare' and _AutoHunt3.Spare and v260.hp / v260.maxhp > 0.2 then
                        return u37(v263)
                    end
                end

                if u7 or not u208[_AutoHunt3.Disc] then
                    return
                end

                u5.BattleGui:exitButtonsMain()
                u5.BattleGui.inputEvent:fire('useitem ' .. u208[_AutoHunt3.Disc])
            elseif v260.corrupt and _AutoHunt3.Corrupt ~= 'Disabled' then
                u37(tonumber(_AutoHunt3.CorruptMove:split(' ')[2]))
            elseif u206 and u206 ~= 'Disabled' then
                if u206 ~= 'Run' then
                    local v265 = u206

                    u37(tonumber(v265:split(' ')[2]))
                elseif u22() and u22().CanRun ~= false and u8 then
                    u5.BattleGui:mainButtonClicked(4)
                end
            end
        end
    end)
end)

local _ = _AutoHunt2:addSection('Discs Counter')

if u14 then
    if not u4.AutoRally then
        u4.AutoRally = {}
    end

    local _AutoRally = u77:addPage('Auto Rally'):addSection('Auto Rally')

    _AutoRally:addToggle('Enabled', u4.AutoRally.Enabled, function(p267)
        u4.AutoRally.Enabled = p267
    end)
    _AutoRally:addToggle('Keep All', u4.AutoRally.All, function(p268)
        u4.AutoRally.All = p268
    end)
    _AutoRally:addToggle('Keep Gleaming', u4.AutoRally.Gleaming, function(p269)
        u4.AutoRally.Gleaming = p269
    end)
    _AutoRally:addToggle('Keep Hidden Ability', u4.AutoRally['Hidden Ability'], function(p270)
        u4.AutoRally['Hidden Ability'] = p270
    end)
    _AutoRally:addDropdown(u4.AutoRally.x40Tab or 'x40 keep Disabled', {
        'x40 keep Disabled',
        '3x40 and Higher',
        '4x40 and Higher',
        '5x40 and Higher',
        '6x40 and Higher',
        '7x40 Only',
    }, function(p271)
        u4.AutoRally.x40Tab = p271

        local v272 = p271 == 'x40 keep Disabled' and 8 or p271:sub(1, 1)

        u4.AutoRally.x40 = tonumber(v272)
    end)
    LooP(function()
        pcall(function()
            if u4.AutoRally.Enabled then
                local _PDS2 = u5.Network:get('PDS', 'getRallied')
                local u274 = {}
                local u275 = {}
                local _monsters = _PDS2.monsters

                if _monsters and _monsters[1] then
                    local v277 = next
                    local v278 = nil

                    while true do
                        local v279, v280 = v277(_monsters, v278)

                        if v279 == nil then
                            break
                        end

                        local v281 = next
                        local _ivr = v280.summ.ivr

                        v278 = v279

                        local v283 = nil
                        local v284 = 0

                        while true do
                            local v285

                            v283, v285 = v281(_ivr, v283)

                            if v283 == nil then
                                break
                            end
                            if v285 == 6 then
                                v284 = v284 + 1
                            end
                        end

                        if u4.AutoRally.All or v280.gl and u4.AutoRally.Gleaming then
                            u275[v279] = 2
                        elseif v280.sa and u4.AutoRally['Hidden Ability'] then
                            u275[v279] = 2
                        elseif u4.AutoRally.x40 and u4.AutoRally.x40 <= v284 then
                            u275[v279] = 2
                        else
                            u275[v279] = 1
                        end
                    end

                    local v287 = {
                        function()
                            u5.DataManager:setLoading(u274, true)

                            local _PDS3 = u5.Network:get('PDS', 'handleRallied', u275)

                            u5.DataManager:setLoading(u274, false)

                            if _PDS3 then
                                u5.Menu.rally.ralliedCount = _PDS3

                                if u5.Menu.rally.updateNPCBubble then
                                    u5.Menu.rally.updateNPCBubble(_PDS3)
                                end
                            end
                        end,
                        function()
                            if _PDS2.mastery then
                                u5.Menu.mastery:showProgressUpdate(_PDS2.mastery, false)
                            end
                        end,
                    }

                    u5.Utilities.Sync(v287)
                end
            end
        end)
    end)
end

local _AutoBattle = u77:addPage('Auto Battle')

if not u4.AutoBattle then
    u4.AutoBattle = {}
end

local _AutoMove = _AutoBattle:addSection('Auto Move')

u4.Move = 'Disabled'

local v290 = {
    'Disabled',
}

for v291 = 1, 4 do
    table.insert(v290, 'Move ' .. v291)
end

_AutoMove:addDropdown('Disabled', v290, function(p292)
    u4.Move = p292
end)
LooP(function()
    pcall(function()
        if client.PlayerGui.MainGui:FindFirstChild('BattleGui', true) and (string.find(u4.Move, 'Move') and u22().kind ~= 'wild') then
            u37(tonumber(u4.Move:split(' ')[2]))
        end
    end)
end)

local _AutoBattle2 = _AutoBattle:addSection('Auto Battle')
local u294 = 'Disabled'
local u295 = {
    'Disabled',
}
local u296 = {}
local u297 = {}
local u298 = {}

local function u312(_, p299)
    pcall(function()
        local _battles = u5.DataManager.currentChunk.battles
        local v301 = p299.model:FindFirstChild('#Battle') and p299.model['#Battle'].Value or 'Mrjack'
        local v302 = not _battles or _battles[tostring(v301)] or _battles[v301]

        if task.wait() and v302 and v302.RematchQuestion then
            local v303 = next
            local v304 = nil
            local v305 = {}

            while true do
                local v306

                v304, v306 = v303(_battles, v304)

                if v304 == nil then
                    break
                end

                table.insert(v305, v306.Name)
            end

            local v307 = next
            local v308 = u295
            local v309 = nil

            while true do
                local v310

                v309, v310 = v307(v308, v309)

                if v309 == nil then
                    break
                end
                if v310 ~= 'Disabled' and not table.find(v305, v310) then
                    table.remove(u295, v309)
                end
            end

            u298[v302.Name] = tostring(v301)

            local v311 = {
                opponentBaseNPC = p299,
                trainer = v302,
            }

            u296[v302.Name] = v311

            if not table.find(u295, v302.Name) and (u40 or not u5.DataManager.currentChunk.regionData.BattleScene) then
                table.insert(u295, v302.Name)
            end
        end
    end)
end

local v313 = _AutoBattle2
local u315 = _AutoBattle2.addDropdown(v313, u297[1], u297, function(p314)
    u294 = p314
end)

LooP(function()
    ForLooP(u5.CollectionManager:GetNPCs(), u312)
end)
LooP(function()
    pcall(function()
        local v316 = #u295 ~= #u297
        local v317 = next
        local v318 = u297
        local v319 = nil
        local v320 = true

        while true do
            local v321

            v319, v321 = v317(v318, v319)

            if v319 == nil then
                break
            end
            if not table.find(u295, v321) then
                v316 = true
            end
        end

        local v322 = next
        local _battles2 = u5.DataManager.currentChunk.battles
        local v324 = nil

        while true do
            local v325

            v324, v325 = v322(_battles2, v324)

            if v324 == nil then
                break
            end

            v320 = false
        end

        if v320 and (#u295 ~= 1 or not table.find(u295, 'Disabled')) and not table.clear(u295) then
            table.insert(u295, 'Disabled')
        elseif v316 and not table.clear(u297) then
            local v326 = next
            local v327 = u295
            local v328 = nil

            while true do
                local v329

                v328, v329 = v326(v327, v328)

                if v328 == nil then
                    break
                end

                table.insert(u297, v329)
            end

            _AutoBattle2:updateDropdown(u315)
            _AutoBattle2:updateDropdown(u315, 'Disabled', u295, function(p330)
                u294 = p330
            end, true)
        elseif u294 ~= 'Disabled' then
            local v331 = u296[u294]
            local v332 = u298[u294]

            if v331 and v331.opponentBaseNPC.model and (v331.opponentBaseNPC.model:IsDescendantOf(workspace) and u5.DataManager.currentChunk.battles[v332]) then
                if u5.MasterControl.WalkEnabled and not u22() and (table.find(u295, u294) and u5.PlayerData.completedEvents.ChooseBeginner) and u25() then
                    if v331.trainer.Name == 'Tamyra' and u5.DataManager.currentChunk.id == 'chunk20' then
                        v331.fshPct = 0.9
                    end

                    u5.Battle:doTrainerBattle(v331)
                end
            else
                table.remove(u295, u294)
            end
        end
    end, 0.1)
end)

if table.find(v10, 'Uhnne Fair') then
    u4.Event = u4.Event or {}
    u4.Event['Uhnne Fair'] = u4.Event['Uhnne Fair'] or {}

    local _Event = u77:addPage('Event')
    local _UhnneFair = u4.Event['Uhnne Fair']
    local u335 = {}
    local u336 = nil
    local _Main3 = _Event:addSection('Main')

    _Main3:addToggle('Disable Traps', _UhnneFair.DisableTraps, function(p338)
        _UhnneFair.DisableTraps = p338
    end)
    _Main3:addButton('Fix Camera', function()
        client.CameraMode = 'Classic'
    end)
    _Main3:addSlider('Brightness', 0, 0, 50, 0.1, function(p339)
        game.Lighting.Brightness = p339
    end)

    local _ESP = _Event:addSection('ESP')

    _ESP:addToggle('Nevermare', _UhnneFair.NevermareESP, function(p341)
        _UhnneFair.NevermareESP = p341
    end)
    _ESP:addToggle('Key', _UhnneFair.KeyESP, function(p342)
        _UhnneFair.KeyESP = p342
    end)
    _ESP:addToggle('Potion', _UhnneFair.PotionESP, function(p343)
        _UhnneFair.PotionESP = p343
    end)
    _ESP:addToggle('Candy', _UhnneFair.CandyESP, function(p344)
        _UhnneFair.CandyESP = p344
    end)
    _ESP:addToggle('Safe House', _UhnneFair.SafeHouseESP, function(p345)
        _UhnneFair.SafeHouseESP = p345
    end)

    if game.PlaceId == tonumber('8284266336') then
        local u346 = {}
        local u347 = {}
        local u348 = {}
        local _SetupTraps = u5.CMazeGameClient.SetupTraps

        function u5.CMazeGameClient.SetupTraps(p350, p351)
            u347 = p351

            u41(2)

            return _SetupTraps(p350, p351)
        end

        local _SetupLasers = u5.CMazeGameClient.SetupLasers

        function u5.CMazeGameClient.SetupLasers(p353, p354, p355)
            u335 = p355
            u348 = p354

            task.spawn(function()
                repeat
                    task.wait()
                until u5.CMazeGameClient.removeMazeFolder

                task.wait(0.5)

                u346 = {}

                local v356 = next
                local v357 = u335
                local v358 = nil

                while true do
                    local v359

                    v358, v359 = v356(v357, v358)

                    if v358 == nil then
                        break
                    end
                    if v359:FindFirstChild('SafeHouse') then
                        table.insert(u346, v359.SafeHouse)
                    end
                end
            end)
            u41(2)

            return _SetupLasers(p353, p354, p355)
        end

        LooP(function()
            u336 = u5.CMazeGameClient.mazeFolder

            pcall(function()
                local v360 = next
                local v361 = u348
                local v362 = nil

                while true do
                    local v363

                    v362, v363 = v360(v361, v362)

                    if v362 == nil then
                        break
                    end

                    v363.Model.CanTouch = not _UhnneFair.DisableTraps
                end
            end)
            pcall(function()
                local v364 = next
                local v365 = u347
                local v366 = nil

                while true do
                    local v367

                    v366, v367 = v364(v365, v366)

                    if v366 == nil then
                        break
                    end

                    v367.Trigger.CanTouch = not _UhnneFair.DisableTraps
                end
            end)
        end)

        local _Folder = Instance.new('Folder', workspace)
        local _Model2 = Instance.new('Model', _Folder)
        local _Model3 = Instance.new('Model', _Folder)
        local _Model4 = Instance.new('Model', _Folder)

        local function u380(p372, p373, p374)
            local v375 = p372:FindFirstChild('BillboardGui') or Instance.new('BillboardGui', p372)
            local v376 = UDim2.new(1, 200, 1, 30)

            v375.Adornee = p372
            v375.AlwaysOnTop = true
            v375.Size = v376

            local v377 = v375:FindFirstChild('TextLabel') or Instance.new('TextLabel', v375)
            local v378 = Vector2.new(0.5, 0.5)
            local v379 = UDim2.new(0.5, 0, 0.5, 0)

            v377.Visible = p374
            v377.Position = v379
            v377.AnchorPoint = v378
            v377.Size = UDim2.new(1, 0, 1.5, 0)
            v377.Font = 'SourceSansBold'
            v377.TextScaled = true
            v377.TextYAlignment = 'Top'
            v377.TextStrokeTransparency = 1
            v377.TextTransparency = 0
            v377.TextSize = 100
            v377.Text = '.'
            v377.BackgroundTransparency = 1
            v377.TextColor3 = p373
        end

        LooP(function()
            local v381 = next
            local v382 = u5.CMazeGameClient.cleanupInstances or {}
            local v383 = nil

            while true do
                local v384

                v383, v384 = v381(v382, v383)

                if v383 == nil then
                    break
                end

                local _model = v384.model

                if _model and task.wait() then
                    pcall(function()
                        if _model:IsDescendantOf(client.Character) then
                            if _model.Main:FindFirstChild('BillboardGui') then
                                _model.Main.BillboardGui:Destroy()
                            end
                        else
                            local v386 = _Model4
                            local v387 = Color3.fromRGB(100, 0, 250)
                            local _PotionESP = _UhnneFair.PotionESP

                            if _model.Name ~= 'Key' then
                                if _model.Name == 'Candy' then
                                    v386 = _Model3
                                    v387 = Color3.fromRGB(250, 140, 5)
                                    _PotionESP = _UhnneFair.CandyESP
                                end
                            else
                                v386 = _Model2
                                v387 = Color3.fromRGB(102, 255, 255)
                                _PotionESP = _UhnneFair.KeyESP
                            end

                            u380(_model.Main, v387, _PotionESP)

                            _model.Parent = v386
                        end
                    end)
                end
            end

            pcall(function()
                local v389 = next
                local v390 = u346
                local v391 = nil

                while true do
                    local v392

                    v391, v392 = v389(v390, v391)

                    if v391 == nil then
                        break
                    end

                    local _EnterSafeHouseTrigger = v392:FindFirstChild('EnterSafeHouseTrigger')

                    if _EnterSafeHouseTrigger then
                        v392.Parent = _Folder

                        local v394 = u380
                        local v395 = Color3.fromRGB(80, 255, 0)
                        local v396 = u336

                        if v396 then
                            v396 = _UhnneFair.SafeHouseESP
                        end

                        v394(_EnterSafeHouseTrigger, v395, v396)
                    end
                end
            end)
            pcall(function()
                local _Nevermare = workspace:FindFirstChild('Nevermare')

                if _Nevermare then
                    local _RootPart = _Nevermare:FindFirstChild('RootPart')

                    if _Nevermare:FindFirstChild('BB') then
                        _Nevermare.Name = 'Nevrmare'
                    elseif _RootPart then
                        u380(_RootPart, Color3.fromRGB(255, 0, 0), _UhnneFair.NevermareESP)
                    end
                end
            end)
        end)
    end
end

local v399 = Color3.fromHSV(tick() % math.random(5) / math.random(5), 1, 1)
local _Colors = u77:addPage('GUI Theme'):addSection('Colors')
local v401 = u4.Theme or {}
local v402 = {
    Background = Color3.fromRGB(24, 24, 24),
    Glow = v399,
    Accent = Color3.fromRGB(10, 10, 10),
    LightContrast = Color3.fromRGB(20, 20, 20),
    DarkContrast = Color3.fromRGB(14, 14, 14),
    TextColor = v399,
}

u4.Theme = v401

local v403 = next
local u404 = v402
local v405 = nil
local u406 = {}

local function v408(p407)
    return math.clamp(math.ceil(p407.R * 255), 0, 255), math.clamp(math.ceil(p407.G * 255), 0, 255), math.clamp(math.ceil(p407.B * 255), 0, 255)
end

while true do
    local u409, v410 = v403(v402, v405)

    if u409 == nil then
        break
    end

    v405 = u409

    local v411 = u4.Theme[u409]

    if v411 then
        v411 = Color3.fromRGB(v408(Color3.new(unpack(u4.Theme[u409]:split(', ')))))
    end

    u406[u409] = _Colors:addColorPicker(u409, v411 or v410, function(p412)
        u77:setTheme(u409, p412)

        u4.Theme[u409] = tostring(p412)
    end)
end

_Colors:addButton('Reset Theme', function()
    local v413 = next
    local v414 = u404
    local v415 = nil

    while true do
        local v416

        v415, v416 = v413(v414, v415)

        if v415 == nil then
            break
        end

        u77:setTheme(v415, v416)
        _Colors:updateColorPicker(u406[v415], v415, v416)
    end

    u4.Theme = {}
end)

local _Other = u77:addPage('Other')
local _BuiltInFeatures = _Other:addSection('Built In Features')

_BuiltInFeatures:addButton('Skip Battle Theater Puzzles')
_BuiltInFeatures:addButton('No Unstuck CoolDown')
_BuiltInFeatures:addButton('Skip Fish MiniGame')
_BuiltInFeatures:addButton('Infinite UMV Energy')

local _Teleport = _Other:addSection('Teleport')

_Teleport:addButton('Rejoin', function()
    game:GetService('TeleportService'):TeleportToPlaceInstance(game.PlaceId, game.JobId)
end)
_Teleport:addButton('Switch Server', function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/thedragonslayer2/Misc/main/Server%20Hop'))()
end)
_Teleport:addButton('Find Most Empty Server', function()
    loadstring(game:HttpGet('https://raw.githubusercontent.com/thedragonslayer2/hey/main/Misc./Find%20the%20most%20empty%20server%20script'))()
end)

local _Other2 = _Other:addSection('Other')

_Other2:addButton('Copy Discord Invite', function()
    setclipboard(DiscordInvite)
    IrisNotificationMrJack(1, 'Notification', 'Discord Link Copied!', 3)
end)

if IrisNotificationUserMrJack then
    IrisNotificationUserMrJack.ClearAllNotifications()
end
if not passlolbruh then
    return IrisNotificationMrJack(2, 'Ui Library Variable Did Not Load!', 'Something went wrong,\nPlease Execute again!', 7)
end

_Other2:addKeybind('Hide/Show Gui', Enum.KeyCode.RightAlt, function()
    u77:toggle()
end)

local v421 = next
local v422 = nil

while true do
    local v423, v424 = v421(u404, v422)

    if v423 == nil then
        break
    end

    v422 = v423

    local v425 = u4.Theme[v423]

    if v425 then
        v425 = Color3.fromRGB(v408(Color3.new(unpack(u4.Theme[v423]:split(', ')))))
    end

    u77:setTheme(v423, v425 or v424)
end

u77:toggle()
u77:SelectPage(u77.pages[1], true)
