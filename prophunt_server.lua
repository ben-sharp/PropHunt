local spawnedPlayers = {}
local hunters = {}
local hiders = {}
local afkplayers = {}
local timerCountdown = 30
local gameStarted = false
local selectedSpawn = nil
local respawnRot = 0
local defaultLocation =
    'resources\\PropHunt\\config\\'
local respawnPoint = vector3(0, 0, 0)
local totalLife = 0
local hasStarted = false

local function has_value(tab, val)
    for index, value in ipairs(tab) do if value == val then return true end end

    return false
end

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do count = count + 1 end

    return count
end

function GetSpawnedPlayers() return spawnedPlayers end

RegisterNetEvent("OnPlayerSpawned")
AddEventHandler('OnPlayerSpawned', function()
    print('Added spawned playerIdx to table: ' .. source)
    spawnedPlayers[#spawnedPlayers + 1] = source
end)

function shuffle(tbl)
    for i = #tbl, 2, -1 do
      local j = math.random(i)
      tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
  end

AddEventHandler('playerDropped', function(reason)
    print(
        'Player ' .. GetPlayerName(source) .. ' dropped (Reason: ' .. reason ..
            ')')
    droppedIdx = -1
    droppedPlayerId = -1
    for Idx, playerId in ipairs(GetSpawnedPlayers()) do
        if playerId == source then
            droppedIdx = Idx
            droppedPlayerId = playerId
        end
    end
    print('DroppedIdx: ' .. droppedIdx .. ' DroppedPlayerId ' .. droppedPlayerId)
    if  has_value(hiders, GetPlayerName(source)) then
        outHiderIdx = -1
        for Idx, v in ipairs(hiders) do
            if v == GetPlayerName(source) then
            outHiderIdx = Idx
            end
        end
        if outHiderIdx ~= -1 then
            table.remove(hiders, outHiderIdx)
        end
        TriggerClientEvent('OnUpdateHiders', -1, hiders)
    end
    if  has_value(hunters, GetPlayerName(source)) then
        outHunterIdx = -1
        for Idx, v in ipairs(hunters) do
            if v == GetPlayerName(source) then
            outHunterIdx = Idx
            end
        end
        if outHunterIdx ~= -1 then
            table.remove(hunters, outHunterIdx)
        end
        TriggerClientEvent('OnUpdateHunters', -1, hunters)
    end
    if spawnedPlayers[droppedIdx] ~= nil then
        table.remove(spawnedPlayers, droppedIdx)
    end
end)

function saveTable(t, filename)

    -- Path for the file to write
    local path = defaultLocation .. filename

    -- Open the file handle
    local file, errorString = io.open(path, "w")

    if not file then
        -- Error occurred; output the cause
        print("File error (Save): " .. errorString)
        return false
    else
        -- Write encoded JSON data to file
        file:write(json.encode(t))
        -- Close the file handle
        io.close(file)
        print('Saved Table At ' .. path)
        return true
    end
end

function loadTable(filename)

    -- Path for the file to read
    local path = defaultLocation .. filename

    -- Open the file handle
    local file, errorString = io.open(path, "r")

    if not file then
        -- Error occurred; output the cause
        print("File error(load): " .. errorString)
        if string.find(filename, 'ranks') then
            saveTable({
                {rank = 1, name = 'None', points = 0, players = 0},
                {rank = 2, name = 'None', points = 0, players = 0},
                {rank = 3, name = 'None', points = 0, players = 0},
                {rank = 4, name = 'None', points = 0, players = 0},
                {rank = 5, name = 'None', points = 0, players = 0},
                {rank = 6, name = 'None', points = 0, players = 0},
                {rank = 7, name = 'None', points = 0, players = 0},
                {rank = 8, name = 'None', points = 0, players = 0},
                {rank = 9, name = 'None', points = 0, players = 0},
                {rank = 10, name = 'None', points = 0, players = 0}

            }, 'ranks' .. selectedSpawn.name .. '.json')
            return loadTable('ranks' .. selectedSpawn.name .. '.json')
        end
    else
        -- Read data from file
        local contents = file:read("*a")
        -- Decode JSON data into Lua table
        local t = json.decode(contents)
        -- Close the file handle
        io.close(file)
        -- Return table
        return t
    end
end


local ranks = loadTable('ranks.json')
local spawns = loadTable('spawns.json')
total_spawns = count_array(spawns)
selectedSpawn = spawns[math.random(1, total_spawns)]

local function send_global_message(text)
    print('Sending Global Message ' .. text)
    for _, playerId in ipairs(GetPlayers()) do
        local name = GetPlayerName(playerId)
        TriggerClientEvent('OnReceivedChatMessage', playerId, text)
    end
end

RegisterNetEvent("OnRequestedStart")
AddEventHandler('OnRequestedStart', function()
    print("Received Start Event")

    timeBelowSpeed = 0
    spawnedPlayers = GetSpawnedPlayers()
    total_players = count_array(spawnedPlayers)
    print(("Selecting Teams (Total Players %i)"):format(total_players))
    gameStarted = true
    exports.vSync:RT()
    exports.vSync:RW()
    respawnPoint = vector3(0, 0, 0)
    total_spawns = count_array(spawns)
    selectedSpawn = spawns[math.random(1, total_spawns)]
    print('Spawning at ' .. selectedSpawn.name)
    ranks = loadTable('ranks' .. selectedSpawn.name .. '.json')

    local hunterIdxs = {}
    local totalhunters = 1 -- set lower hunter to begin with then as each hider dies they become a hunter
    if total_players >= 5 then
        totalhunters = 2
    end
    
    local forceHider = true -- debug set to true to force players to be hiders
    if forceHider then totalhunters = 0 end

    while #hunterIdxs < totalhunters do
        local hunterIdx = math.random(1, total_players)
        if not has_value(hunterIdxs, hunterIdx) then
            hunterIdxs[#hunterIdxs + 1] = hunterIdx
        end
    end

    hunters = {}
    hiders = {}
    hunterName = ''
    for i, playerId in ipairs(spawnedPlayers) do

        local name = GetPlayerName(playerId)
        if has_value(hunterIdxs, i) then
            hunters[#hunters + 1] = name
        else
            hiders[#hiders + 1] = name
        end
    end

    hunters = shuffle(hunters)
    for i, playerId in ipairs(spawnedPlayers) do
        local name = GetPlayerName(playerId)
        if has_value(hunterIdxs, i) then
            hunterName = name
            send_global_message(
                ('^1%s was selected as a hunter!'):format(name))
            TriggerClientEvent('onPropHuntStart', playerId, 'hunter', selectedSpawn.hunterSpawnVec, selectedSpawn.hunterSpawnRot, hunters, selectedSpawn, true, hiders)
            if not hasStarted then
                TriggerClientEvent('onPropHuntAfterWarmup', playerId)
                hasStarted = true
            end
            send_global_message('^3' .. total_players .. ' players in game.')
        end
    end
    
    local hiderSpawn = vector3(selectedSpawn.hiderSpawnVec.x, selectedSpawn.hiderSpawnVec.y, selectedSpawn.hiderSpawnVec.z)
    for i, playerId in ipairs(spawnedPlayers) do
        local name = GetPlayerName(playerId)
        if not has_value(hunterIdxs, i) then
            TriggerClientEvent('onPropHuntStart', playerId, 'hiders',
                                hiderSpawn +
                                    vector3(math.random(-10, 10),
                                            math.random(-10, 10), 0),
                                selectedSpawn.hiderSpawnRot, hunters, selectedSpawn, true, hiders)
            print('Spawning ' .. name .. ' as a hider')
        end
    end
    
    print("Finished Selecting Teams!... Preparing spawning")
end)

RegisterNetEvent("OnNotifyHunterBlipVisible")
AddEventHandler('OnNotifyHunterBlipVisible', function(hunterName, isVisible)
    TriggerClientEvent('OnNotifyHunterBlipVisible', -1, hunterName, isVisible)
end)

RegisterNetEvent("OnMarkedAFK")
AddEventHandler('OnMarkedAFK', function(isAfk)
    if isAfk then
        send_global_message(GetPlayerName(source) ..
                                " is now marked as Away From Keyboard")
        afkIdx = -1
        for Idx, playerId in ipairs(spawnedPlayers) do
            if playerId == source then afkIdx = Idx end
        end
        if afkIdx ~= -1 then table.remove(spawnedPlayers, afkIdx) end
    else
        send_global_message(GetPlayerName(source) .. " has rejoined the chaos!")
        spawnedPlayers[#spawnedPlayers + 1] = source
    end
end)

RegisterNetEvent("OnUploadSpawnPoint")
AddEventHandler('OnUploadSpawnPoint', function(spawnData)
    print('Recevied new spawn data ->' .. spawnData.name)
    if spawns == nil then
        spawns = {}
    end
    table.insert(spawns, spawnData)
    saveTable(spawns, 'spawns.json')
end)

RegisterNetEvent("OnRequestJoinInProgress")
AddEventHandler('OnRequestJoinInProgress', function(playerId)
    if playerId ~= -1 then
        outHunterIdx = -1
        for Idx, v in ipairs(hunters) do
            if v == GetPlayerName(playerId) then
            outHunterIdx = Idx
            end
        end

        if outHunterIdx == -1 then
            local hiderSpawn = vector3(selectedSpawn.hiderSpawnVec.x, selectedSpawn.hiderSpawnVec.y, selectedSpawn.hiderSpawnVec.z)
            print('Starting ' .. GetPlayerName(playerId) .. ' in progress as hunter')
            TriggerClientEvent('onPropHuntStart', playerId, 'hunter',
                hiderSpawn +
                                vector3(math.random(-10, 10),
                                        math.random(-10, 10), 0),
                            respawnRot, hunters, selectedSpawn, gameStarted, hiders)
        end
    end
end)

function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

RegisterNetEvent('OnNotifyHighScore')
AddEventHandler('OnNotifyHighScore', function(Name, LifeTime)

    if not gameStarted then
        return
    end

    outHunterIdx = -1
    for Idx, v in ipairs(hunters) do
        if v == GetPlayerName(source) then
        outHunterIdx = Idx
        end
    end

    outHiderIdx = -1
    for Idx, v in ipairs(hiders) do
        if v == GetPlayerName(source) then
            outHiderIdx = Idx
        end
    end

    if outHunterIdx ~= -1 then
        table.remove(hunters, outHunterIdx)
    end

    if outHiderIdx ~= -1 then
        table.remove(hiders, outHiderIdx)
    end

    for d in ipairs(hunters) do
        print('Hunter: ' .. d .. ' remaining')
    end

    for d in ipairs(hiders) do
        print('Hider: ' .. d .. ' remaining')
    end
    
    TriggerClientEvent('OnUpdateHunters', -1, hunters)
    TriggerClientEvent('OnUpdateHiders', -1, hiders)

    if #hunters == 0 or #hiders == 0 then
        gameStarted = false
        timerCountdown = 15
        for _, playerId in ipairs(GetSpawnedPlayers()) do
            TriggerClientEvent('OnGameEnded', playerId)
        end      
    end


end)

RegisterNetEvent('OnNotifyDriverBlipArea')
AddEventHandler('OnNotifyDriverBlipArea', function(enabled, posX, posY, posZ)
    TriggerClientEvent('OnNotifyDriverBlipArea', -1, enabled, posX, posY, posZ)
end)

RegisterNetEvent('OnNotifyKilled')
AddEventHandler('OnNotifyKilled', function(Name, LifeTime)

    if not gameStarted then
       return
    end    
   
    outHunterIdx = -1
    for Idx, v in ipairs(hunters) do
        if v == GetPlayerName(source) then
        outHunterIdx = Idx
        end
    end

    outHiderIdx = -1
    for Idx, v in ipairs(hiders) do
        if v == GetPlayerName(source) then
        outHiderIdx = Idx
        end
    end

    if outHunterIdx ~= -1 then
        table.remove(hunters, outHunterIdx)
    
        send_global_message(GetPlayerName(source) .. ' has been killed! Total Life: ' .. LifeTime ..
        ' Seconds\nHunters Remaining: ' .. #hunters)
    
    end

    if outHiderIdx ~= -1 then
        table.remove(hiders, outHiderIdx)
    
        send_global_message(GetPlayerName(source) .. ' has been killed! Total Life: ' .. LifeTime ..
        ' Seconds\nHiders Remaining: ' .. #hiders)
    
    end

    for i, d in ipairs(hunters) do
        print('Hunter: ' .. d .. ' remaining')
    end

    for i, d in ipairs(hiders) do
        print('Hider: ' .. d .. ' remaining')
    end


    TriggerClientEvent('OnUpdateHunters', -1, hunters)
    TriggerClientEvent('OnUpdateHiders', -1, hiders)

    if #hunters == 0 or #hiders == 0 then
        gameStarted = false
        timerCountdown = 15
        newhighScoreIdx = -1
        for _, playerId in ipairs(GetSpawnedPlayers()) do
            TriggerClientEvent('OnGameEnded', playerId)
        end
    end

    newhighScoreIdx = -1

    send_global_message('^6' .. Name .. ' has ended the game!')
   

    local isOnLeaderboard = false
    local hasHigherScoreOnLeaderboard = false
    local previousRankIdx = -1
    oldRanks = deepcopy(ranks)
    total_players = count_array(GetSpawnedPlayers())
    for i, player in pairs(ranks) do
        if LifeTime * (total_players * 1.68 - 1) < player.points *
            (player.players * 1.68 - 1) and Name == player.name then
            send_global_message(Name ..
                                    ' score was lower than their previous score on the leaderboard. Score will not be counted.')
            hasHigherScoreOnLeaderboard = true
        end
        if Name == player.name then
            table.remove(ranks, i)
            isOnLeaderboard = true
            previousRankIdx = i
            break
        end
    end

    local replacedPlayerScore = nil

    if hasHigherScoreOnLeaderboard == false then
        for i, player in pairs(ranks) do
            if LifeTime * (total_players * 1.68 - 1) > player.points *
                (player.players * 1.68 - 1) then
                local rank = {name = Name, points = LifeTime, players = total_players}
                print(rank.points)
                table.insert(ranks, i, rank)
                newhighScoreIdx = i
                send_global_message(Name ..
                                        ' just received a new high score! Rank: ' ..
                                        i .. ' Life: ' .. LifeTime)
                break
            end
        end

        for i, player in pairs(ranks) do
            if i > newhighScoreIdx and newhighScoreIdx ~= -1 and Name == ranks[i].name then
                table.remove(ranks, i)
                i = i - 1
            end
        end

        saveTable(ranks, 'ranks' .. selectedSpawn.name .. '.json')
    end
end)

local function save_score(name, score) file = io.open('scores.txt') end

Citizen.CreateThread(function()
    while true do
        total_players = count_array(GetSpawnedPlayers())
        TriggerClientEvent('OnUpdateTotalPlayers', -1, total_players)
        if total_players < 1 and gameStarted then
            timerCountdown = 30
            gameStarted = false
        end
        if total_players >= 2 and not gameStarted then
            if timerCountdown > 10 then
                timerCountdown = timerCountdown - 5
            else
                timerCountdown = timerCountdown - 1
            end
            send_global_message('^1' .. timerCountdown ..
                                    " seconds until game starts!")
            if timerCountdown < 0 then
                gameStarted = true
                TriggerEvent('OnRequestedStart')
                
            end
        end
        if timerCountdown > 10 then
            Citizen.Wait(5000)
        else
            Citizen.Wait(1000)
        end
    end

end)



Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if selectedSpawn ~= nil then
            ranks =
                loadTable('ranks' .. selectedSpawn.name .. '.json')
            for _, playerId in ipairs(GetSpawnedPlayers()) do
                TriggerClientEvent('OnClearRanks', playerId)
                for _, player in pairs(ranks) do
                    TriggerClientEvent('OnUpdateRanks', playerId, player.name,
                                    player.points, player.players, _)
                end
            end
        end
    end
end)