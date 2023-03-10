local json = require("json")

local spawnPos = vector3(-1587.612, -3032.406, 14)
RegisterNetEvent("OnReceivedChatMessage")
RegisterNetEvent('onPropHuntStart')
RegisterNetEvent('onPropHuntAfterWarmup')
RegisterNetEvent('OnGameEnded')
RegisterNetEvent('OnUpdateRanks')
RegisterNetEvent('OnClearRanks')
RegisterNetEvent('OnUpdateHunterRanks')
RegisterNetEvent('OnClearHunterRanks')
RegisterNetEvent('OnUpdateHiderRanks')
RegisterNetEvent('OnClearHiderRanks')

local function has_value(tab, val)
    for index, value in ipairs(tab) do if value == val then return true end end

    return false
end

local warmupTime = 5
local ourTeamType = ''
local startTime = 0
local totalLife = 0
local gameStarted = false
local shouldNotifyAboutDeath = true
local hunters = {}
local hiders = {}
local hunterPed = 0
local afkTime = 0
local isMarkedAfk = false
local respawnCooldown = 0
local changePropCooldown = 0
local currentSpawnConfig = {name = 'None', hunterSpawnVec = vector3(0,0,0), hunterSpawnRot = 0, hiderSpawnVec = vector3(0,0,0), hiderSpawnRot = 0, propHashes = {}}
local selectedSpawn = nil
local showScoreboard = false
local selectedEndPoint = nil
local totalPlayers = 0
local currentRank = -1
local scoreToBeat = {}
local timeRemainingOnFoot = 60
local timeDead = 0
local forceDriverBlipVisible = {}
local needsResetHealth = false
local createdBlipForRadius = false
local forceHunterBlipVisible = {}
local hunterBlip = {}
local currentScore = 0
local extractionBlip = nil
local possibleHunterWeapons = { {model = 'minigun', ammo = 300, equip = false}, {model = 'microsmg', ammo = 48, equip = false} , {model = 'bat', ammo = 1, equip = true} , {model = 'fireextinguisher', ammo = 50, equip = false} }
local weaponHash = nil
local lastProp = nil
local isInvisible = false
local hasWarmedUp = false
local hasRespawned = false

local isOutsideBoundary = false
local outOfBoundsTimer = 10

local function count_array(tab)
    count = 0
    for index, value in ipairs(tab) do count = count + 1 end

    return count
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        local speedinKMH = GetEntitySpeed(GetPlayerPed(-1)) * 3.6
        local currentVehicleId = GetVehiclePedIsIn(GetPlayerPed(-1), false)
        if speedinKMH < 1.0 and GetEntityHealth(GetPlayerPed(-1)) > 0 and currentVehicleId ~= 0 then
            afkTime = afkTime + 1.0
            if afkTime > 35 and isMarkedAfk == false and ourTeamType ~= 'hunter' then
                TriggerServerEvent('OnMarkedAFK', true)
                isMarkedAfk = true
            end
        else
            afkTime = 0.0
            if isMarkedAfk == true then
                isMarkedAfk = false
                TriggerServerEvent('OnMarkedAFK', false)
                if not gameStarted then
                    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
                end
            end
        end
    end

end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if ourTeamType == 'hunter' and IsPedShooting(PlayerPedId()) then
            ApplyDamageToPed(PlayerPedId(), 1, true)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        local playerPed = GetPlayerPed(-1)
        hunterPed = playerPed

        SetCanAttackFriendly(playerPed, true, true)
        NetworkSetFriendlyFireOption(true)

        if GetEntityHealth(playerPed) <= 0 then
            respawnCooldown = 5
            timeDead = timeDead + 0.1 
            if gameStarted and totalLife > 0 and shouldNotifyAboutDeath then
                shouldNotifyAboutDeath = false
                TriggerServerEvent('OnNotifyKilled', GetPlayerName(PlayerId()), totalLife)
            end

            if timeDead > 10 then
                TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
            end
        else
            timeDead = 0
        end

        if ourTeamType == 'hunter' then
            local weapons = possibleHunterWeapons
            for _, weapon in pairs(weapons) do
                weaponHash = GetHashKey("WEAPON_".. weapon.model)
                if not HasPedGotWeapon(playerPed, weaponHash, false) then
                    GiveWeaponToPed(playerPed, weaponHash, weapon.ammo, false, weapon.equip)
                end
            end
        else
            RemoveAllPedWeapons(playerPed)
        end

        local playerName = GetPlayerName(PlayerId())
        
        local coords = GetEntityCoords(PlayerPedId())
    
        if forceHunterBlipVisible[playerName] and ourTeamType == 'hunter' then
            TriggerEvent('OnNotifyHuntersBlipVisible', GetPlayerName(PlayerId()), false)
            TriggerServerEvent('OnNotifyHunterBlipVisible', GetPlayerName(PlayerId()),  false) 
        end  
        if ourTeamType == 'hunter' and not createdBlipForRadius then
            createdBlipForRadius = true

            TriggerServerEvent('OnNotifyHunterBlipArea', playerName, true, coords.x, coords.y, coords.z)
        end
        
        SetEntityInvincible(GetPlayerPed(-1), false)
            
        if not forceHunterBlipVisible[playerName] and ourTeamType == 'hunter' then
            TriggerEvent('OnNotifyHuntersBlipVisible', playerName, true)
            TriggerServerEvent('OnNotifyHunterBlipVisible', playerName, true) 
        end   

        if createdBlipForRadius then
            createdBlipForRadius = false             
            TriggerServerEvent('OnNotifyHunterBlipArea', playerName, false, 0, 0, 0)
        end

        timeRemainingOnFoot = math.clamp(timeRemainingOnFoot + 0.1, 0, 60)

        SetEntityInvincible(GetPlayerPed(-1), false)
       
        SetPoliceRadarBlips(false)
        if respawnCooldown > 0 then
            respawnCooldown = respawnCooldown - 0.1
        end

        if changePropCooldown > 0 then
            changePropCooldown = changePropCooldown - 0.1
        end

        Citizen.Wait(100)
    end

end)

Citizen.CreateThread(function()

    timestart = GetGameTimer()
    tick = GetGameTimer()
    while true do
        delta_time = (GetGameTimer() - tick) / 1000
        tick = GetGameTimer()
        Citizen.Wait(100) -- check all 15 seconds
        if (GetGameTimer() - startTime) / 1000 > warmupTime then
            totalLife =  totalLife + delta_time
        end
        timestart = GetGameTimer()
        
        if(gameStarted) then
            local scoreMultiplier = isInvisible and 5 or 1
            currentScore = currentScore + (1 * scoreMultiplier) -- totalLife * (totalPlayers * 1.68 - 1) * scoreMultiplier
        end
    end
end)


Citizen.CreateThread(function()
    while true do
        Wait(0)
        SetTextFont(0)
        SetTextProportional(0)
        SetTextScale(0.0, 0.5)
        SetTextColour(0, 128, 0, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 500)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        if gameStarted then
            if startTime > warmupTime then

                local visibilityText = ''
                if ourTeamType == 'hunter' then
                    
                    AddTextComponentString(
                        ("~g~%.1f ~s~Seconds\n ~g~%.0f ~s~Score\n~y~%s Hunters\n~y~%s Hiders"):format(totalLife,
                                                                    currentScore, #hunters, #hiders))

                    DrawText(0.8, 0.1)   
                else
                    if not isInvisible then
                        visibilityText = '~r~Visible '
                    else
                        visibilityText  = '~g~Hidden '
                    end
                    
                    AddTextComponentString(
                        ("~g~%.1f ~s~Seconds\n ~g~%.0f ~s~Score\n%s\n~y~%s Hunters\n~y~%s Hiders"):format(totalLife,
                                                                    currentScore, visibilityText, #hunters, #hiders))

                    DrawText(0.8, 0.1)   
                end
                                                              
            end
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 0.65)
            SetTextColour(0, 128, 0, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            if (GetGameTimer() - startTime) / 1000 < warmupTime and ourTeamType ==
                'hunter' and showScoreboard == false and not hasRespawned then
                AddTextComponentString(("~y~The game is starting!\n Kill all the props as fast as possible!!\n%.1f"):format(
                                           warmupTime - (GetGameTimer() - startTime) /
                                               1000))
                DrawText(0.5, 0.2)
                hasWarmedUp = false
                isOutsideBoundary = false
            elseif (GetGameTimer() - startTime) / 1000 < warmupTime and ourTeamType ==
            'hunter' and showScoreboard == false and hasRespawned then
                AddTextComponentString("~y~You joined as a hunter!\n Kill all the props as fast as possible!\n")
                DrawText(0.5, 0.2)
            end
            if warmupTime - (GetGameTimer() - startTime) / 1000 > 0 and totalLife < warmupTime and
                ourTeamType ~= 'hunter' and showScoreboard == false then
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.0, 0.65)
                SetTextColour(255, 0, 0, 255)
                SetTextDropshadow(0, 0, 0, 0, 255)
                SetTextEdge(2, 0, 0, 0, 150)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")
                SetTextCentre(1)
                AddTextComponentString(
                    ("~y~Find a spot to hide and pick a prop with F3!\n%.1f"):format(warmupTime -
                                                            (GetGameTimer() -
                                                                startTime) /
                                                            1000))
                DrawText(0.5, 0.4)
            end
        else
            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 0.5)
            SetTextColour(255, 165, 0, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            if totalPlayers <= 1 then
                AddTextComponentString("Waiting For Players\n Game will commence when 2 Players are ready!")
            else
                AddTextComponentString("Get Ready!\n Game will begin shortly")
            end
            DrawText(0.5, 0.4)
        end
    end
end)

RegisterNetEvent("baseevents:onPlayerKilled")
AddEventHandler('baseevents:onPlayerKilled', function(killer, reason)
    TriggerEvent('OnReceivedChatMessage', 'Killer: ' .. killer .. ' Reason: ' .. reason)
   
end)

AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        local inModels = {'g_m_m_chicold_01'}
        if ourTeamType ~= 'hunter' then
            inModels = { 'g_m_m_chicold_01', 's_m_m_movspace_01', 's_m_y_robber_01', 's_m_y_prisoner_01', 's_m_y_prismuscl_01', 's_m_y_factory_01', 'a_f_y_hippie_01', 's_m_y_dealer_01', 'u_m_y_mani' }
        else
            inModels = { 's_m_y_cop_01', 's_m_y_hwaycop_01', 's_m_y_sheriff_01', 's_m_y_ranger_01', 's_m_m_fibsec_01' }
        end

        selectedModel = inModels[math.random(1, #inModels)]
        print('spawning as model ' .. selectedModel)
        exports.spawnmanager:spawnPlayer({
            x = spawnPos.x,
            y = spawnPos.y,
            z = spawnPos.z,
            model = selectedModel ,
            skipFade = true
        }, function()
            TriggerEvent('chat:addMessage', {
                args = {
                    '^5MOTD: ^12 Players minimum ^5required to start the game. ^2If you are blown up/disabled then you can use ^1F1^2 to respawn.'
                }
            })
            
        end)
    end)

    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
    ShutdownLoadingScreen()
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))
    TriggerServerEvent('OnPlayerSpawned')
end)

RegisterCommand('areas', function(source, args)
    -- tell the player
    TriggerEvent('chat:addMessage',
                 {args = {'Possible Maps are \nairport\nairport_north\ndock'}})
end, false)


RegisterCommand('start', function(source, args)
    TriggerServerEvent('OnRequestedStart')
end, false)

RegisterCommand('coord', function(source, args)
    local pos = GetEntityCoords(PlayerPedId()) -- get the position of the local player ped
    local rot = GetEntityHeading(PlayerPedId())
    -- tell the player
    TriggerEvent('chat:addMessage', {args = {'Pos: ' .. pos .. ' Rot: ' .. rot}})
end, false)

RegisterCommand('setspawn', function(source, args)
    local pos = GetEntityCoords(PlayerPedId())
    local rot = GetEntityHeading(PlayerPedId())
    print(args, count_array(args))
    local spawnName = args[1]
    currentSpawnConfig.name = spawnName
    local teamName = args[2]
    if args[2] == 'hunter' then
        currentSpawnConfig.hunterSpawnVec = pos
        currentSpawnConfig.hunterSpawnRot = rot
        TriggerEvent('OnReceivedChatMessage', 'Set Hunter Data for ' .. spawnName .. ' to ' .. pos .. ' / ' .. rot)
    elseif args[2] == 'hider' then
        currentSpawnConfig.hiderSpawnVec = pos
        currentSpawnConfig.hiderSpawnRot = rot
        TriggerEvent('OnReceivedChatMessage', 'Set Hider Data for ' .. spawnName .. ' to ' .. pos .. ' / ' .. rot)
    end
end, false)

RegisterCommand('uploadspawn', function(source, args)
    local pos = GetEntityCoords(PlayerPedId())
    local rot = GetEntityHeading(PlayerPedId())
    if currentSpawnConfig.name == "None" then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn no name set for spawn data')
        --return
    end
    if currentSpawnConfig.hunterSpawnVec == vector3(0,0,0) then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn driver data set (Position/Rotation)')
        --return
    end
    if currentSpawnConfig.hiderSpawnVec == vector3(0,0,0) then
        TriggerEvent('OnReceivedChatMessage', 'Unable to upload spawn attacker data set (Position/Rotation)')
        --return
    end

    TriggerEvent('OnReceivedChatMessage', 'Sent Spawn Data to the server')
    TriggerServerEvent('OnUploadSpawnPoint', currentSpawnConfig)
end, false)

AddEventHandler('OnReceivedChatMessage', function(text)
    TriggerEvent('chat:addMessage', {args = {text}})
end)

AddEventHandler('OnGameEnded', function() gameStarted = false end)

RegisterNetEvent('OnUpdateTotalPlayers')
AddEventHandler('OnUpdateTotalPlayers',
                function(inTotalPlayers) totalPlayers = inTotalPlayers end)

AddEventHandler('onPropHuntAfterWarmup', function() 
    hasWarmedUp = false
end)

AddEventHandler('onPropHuntStart',
                function(teamtype, spawnPos, spawnRot, inHunters, inSelectedSpawn, isGameStarted, inHiders)
    print("Client_onPropHuntStart", teamtype, spawnPos, spawnRot, inHunters, inSelectedSpawn, isGameStarted, inHiders)
    -- account for the argument not being passed
    totalLife = 0
    timeBelowSpeed = 0
    timeRemainingOnFoot = 60
    currentScore = 0
    shouldNotifyAboutDeath = true
    hunters = inHunters
    hiders = inHiders

    currentRank = {}
    scoreToBeat = {}
    selectedSpawn = inSelectedSpawn
    respawnCooldown = 5
    changePropCooldown = 0
    lifeStart = GetGameTimer()

    if isGameStarted then
        print('game started')
        gameStarted = true
    else
        print('game stopped')
        gameStarted = false
    end
    ourTeamType = teamtype
    DoScreenFadeOut(0)
    exports.spawnmanager:forceRespawn()    
    Wait(1000)
    if GetEntityHealth(GetPlayerPed(-1)) <= 0 then
        ClearPedTasksImmediately(GetPlayerPed(-1))
    end
    startTime = GetGameTimer()

    if ourTeamType == 'hunter' then
        SetPedArmour(GetPlayerPed(-1), 100)
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    else
        SetPedArmour(GetPlayerPed(-1), 0)
        -- SetPedMaxHealth(GetPlayerPed(-1), 200)
        -- SetEntityHealth(GetPlayerPed(-1), 105)
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
    end

    RemoveAllPedWeapons(GetPlayerPed(-1), true)  

    startLocation = spawnPos
    SetEntityCoords(GetPlayerPed(-1), spawnPos.x, spawnPos.y, spawnPos.z)
    Wait(500)
    DoScreenFadeIn(500)

end)

function GetPlayers()
    local players = {}

    for i = 0, 31 do
        if NetworkIsPlayerActive(i) then table.insert(players, i) end
    end

    return players
end

Citizen.CreateThread(function()
    local blips = {}
    local gamerTags = {}
    local currentPlayer = PlayerId()
   
    while true do
        Wait(100)
        local players = GetPlayers()
        local localScoreToBeat = 0
        if (scoreToBeat[GetPlayerName(PlayerId())] ~= nil) then
            localScoreToBeat = scoreToBeat[GetPlayerName(PlayerId())]
        end
        local shouldCreateExtraction = (currentScore > localScoreToBeat or ourTeamType ~= 'hunter') and selectedEndPoint ~= nil

        SetGpsActive(false)
        SetGpsMultiRouteRender(false)
        RemoveBlip(extractionBlip)
        extractionBlip = nil

        local localPlayerName =  GetPlayerName(PlayerId())

        for player = 0, 64 do
            if player ~= currentPlayer and NetworkIsPlayerActive(player) then
                local playerPed = GetPlayerPed(player)
                local playerName = GetPlayerName(player)

                
                RemoveBlip(blips[player])
                local shouldCreateBlip = true
                if not has_value(hunters, playerName) and not has_value(hunters, localPlayerName) then
                    if not forceDriverBlipVisible[playerName] then
                        shouldCreateBlip = false
                    end
                end

                if not has_value(hunters, playerName) and has_value(hunters, localPlayerName) then
                    shouldCreateBlip = false
                end


                gamerTag = Citizen.InvokeNative(0xBFEFE3321A3F5015, playerPed,
                playerName, false, false, '',
                false)
                gamerTags[player] = gamerTag

               
                
                if shouldCreateBlip then
                    local new_blip = AddBlipForEntity(playerPed)

                    -- Add player name to blip
                    SetBlipNameToPlayerName(new_blip, player)

                    -- Make blip white
                    if has_value(hunters, playerName) and not has_value(hunters,  localPlayerName) then
                        SetBlipColour(new_blip, 1)
                        SetBlipCategory(new_blip, 380)
                        SetMpGamerTagColour(gamerTag, 0, 208)
                    else
                        SetBlipColour(new_blip, 2)
                        SetBlipCategory(new_blip, 56)
                        SetMpGamerTagColour(gamerTag, 0, 18)
                    end

                    -- Set the blip to shrink when not on the minimap
                    -- Citizen.InvokeNative(0x2B6D467DAB714E8D, new_blip, true)

                    -- Shrink player blips slightly
                    SetBlipScale(new_blip, 0.9)

                    -- Record blip so we don't keep recreating it
                    blips[player] = new_blip

                    -- Add nametags above head
                    if (has_value(hunters, playerName) or has_value(hunters, localPlayerName)) then
                        SetMpGamerTagVisibility(gamerTag, 0, true)
                    else
                        SetMpGamerTagVisibility(gamerTag, 0, false)
                    end                    
                    
                else
                    SetMpGamerTagVisibility(gamerTag, 0, false)
                end
            end
        end
    end

end)

RegisterNetEvent("OnUpdateHunters")
AddEventHandler('OnUpdateHunters', function(inHunters)
   hunters = inHunters
end)

RegisterNetEvent("OnUpdateHiders")
AddEventHandler('OnUpdateHiders', function(inHiders)
   hiders = inHiders
end)

ranks = {
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
}
hunterRanks = {
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
}
hiderRanks = {
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
}

AddEventHandler('OnClearRanks', function()
    ranks = {
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
    }
end)

AddEventHandler('OnUpdateRanks', function(name, lifetime, players, rank)
    scoreToBeat[name] = lifetime * (players * 1.68 - 1)
    currentRank[name] = rank
    for _, player in pairs(ranks) do
        if lifetime * (players * 1.68 - 1) > player.points *
            (player.players * 1.68 - 1) then
            ranks[_].points = lifetime
            ranks[_].name = name
            ranks[_].players = players
            break
        end
    end
end)


AddEventHandler('OnClearHunterRanks', function()
    hunterRanks = {
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
    }
end)

AddEventHandler('OnUpdateHunterRanks', function(name, lifetime, players, rank)
    scoreToBeat[name] = lifetime * (players * 1.68 - 1)
    currentRank[name] = rank
    for _, player in pairs(hunterRanks) do
        if lifetime * (players * 1.68 - 1) > player.points *
            (player.players * 1.68 - 1) then
            hunterRanks[_].points = lifetime
            hunterRanks[_].name = name
            hunterRanks[_].players = players
            break
        end
    end
end)



AddEventHandler('OnClearHiderRanks', function()
    hiderRanks = {
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
    }
end)

AddEventHandler('OnUpdateHiderRanks', function(name, lifetime, players, rank)
    scoreToBeat[name] = lifetime * (players * 1.68 - 1)
    currentRank[name] = rank
    for _, player in pairs(hiderRanks) do
        if lifetime * (players * 1.68 - 1) > player.points *
            (player.players * 1.68 - 1) then
            hiderRanks[_].points = lifetime
            hiderRanks[_].name = name
            hiderRanks[_].players = players
            break
        end
    end
end)


Citizen.CreateThread(function()
    while true do
        Wait(0)
        if warmupTime - (GetGameTimer() - startTime) / 1000 <= 0 and ourTeamType == 'hunter' and not hasWarmedUp then
            hasWarmedUp = true
            SetEntityCoords(PlayerPedId(), selectedSpawn.hiderSpawnVec.x, selectedSpawn.hiderSpawnVec.y, selectedSpawn.hiderSpawnVec.z)
            Wait(500)
            DoScreenFadeIn(500)
        end
    end
end)

function DrawPlayers()
    for _, player in pairs(ranks) do
        if player.points ~= 0 then
            local Yoffset = 0.04
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.3)
            if player.rank == 1 then
                SetTextColour(255, 215, 0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(player.name)
            DrawText(0.35, 0.2 + Yoffset * player.rank)
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.25)
            if player.rank == 1 then
                SetTextColour(255, 215, 0, 255)
            elseif player.rank == 2 then 
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("%.0f Seconds\n%i Hiders"):format(
                                       player.points, player.players - 1))
            DrawText(0.50, 0.2 + Yoffset * player.rank)
            SetTextFont(0)
            SetTextProportional(0)
            SetTextScale(0.0, 0.3)
            if player.rank == 1 then
                SetTextColour(255, 215, 0, 255)
            elseif player.rank == 2 then
                SetTextColour(192, 192, 192, 255)
            elseif player.rank == 3 then
                SetTextColour(205, 127, 50, 255)
            else
                SetTextColour(255, 255, 255, 255)
            end
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("%0.0f Score"):format(player.points *
                                                              (player.players *
                                                                  1.68 - 1)))
            DrawText(0.65, 0.2 + Yoffset * player.rank)
        end
    end
end

RegisterCommand('respawngroundbtn', function(source, args, rawcommand)

    if ourTeamType == 'hunter' then
        TriggerEvent('chat:addMessage',
                     {args = {'Unable to respawn.... you are a hunter!'}})
        return
    end
    if respawnCooldown > 0 then
        TriggerEvent('chat:addMessage', {
            args = {
                'You must wait ' .. respawnCooldown ..
                    ' seconds until respawn is available'
            }
        })
        return
    end

    hasRespawned = true
    respawnCooldown = 5
    print('Requesting Start for ' .. GetPlayerName(PlayerId()) .. ' in progress')
    local currentCoords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('OnRequestJoinInProgress', GetPlayerServerId(PlayerId()))

end, false)

RegisterNetEvent('OnNotifyHunterBlipVisible')
AddEventHandler('OnNotifyHunterBlipVisible', function(hunterName, isVisible)
    forceHunterBlipVisible[hunterName] = isVisible
end)

RegisterNetEvent('OnNotifyHunterBlipArea')
AddEventHandler('OnNotifyHunterBlipArea', function(hunterName, enabled, posX, posY, posZ)
    if enabled then
        RemoveBlip(hunterBlip[hunterName])
        hunterBlip[hunterName] = AddBlipForRadius(posX, posY, posZ, 50.0)
        SetBlipColour(hunterBlip[hunterName], 1)
        SetBlipAlpha(hunterBlip[hunterName], 128)
    else
        RemoveBlip(hunterBlip[hunterName])
    end
end)


RegisterCommand('scoreboard', function(source, args, rawcommand)
    if showScoreboard then
        showScoreboard = false
    else
        showScoreboard = true
    end
  
end, false)


-- SetEntityRotation

RegisterCommand("triggerChangeRotationMenu", function()
    if ourTeamType == 'hunter' then
        TriggerEvent('chat:addMessage',
                     {args = {'Unable to affect props.... you are a hunter!'}})
        return
    end

    TriggerEvent("nh-context:changeRotationMenu")
end)

RegisterNetEvent('rotate', function(amount)

    if not amount then
        amount = 10
    end

    if lastProp then
        local currentRotation = GetEntityRotation(lastProp, 2)
        SetEntityRotation(lastProp, currentRotation.x, currentRotation.y, currentRotation.z+amount)
        TriggerEvent("nh-context:changeRotationMenu")
    end

end)

RegisterNetEvent('closeMenu', function(amount)

--   rly be doin nothin tho

end)

RegisterNetEvent("nh-context:changeRotationMenu", function()

    local menu = {
        {
            header = "Rotate Object",
            context = "click to close",
            event = "closeMenu",
        },
        {
            header = "Rotate Left",
            context = "",
            event = "rotate",
            args = {10}
        },
        {
            header = "Rotate Right",
            context = "",
            event = "rotate",
            args = {-10}
        }
    }
    TriggerEvent("nh-context:createMenu", menu)
end)

RegisterCommand("triggerChangePropMenu", function()
    if ourTeamType == 'hunter' then
        TriggerEvent('chat:addMessage',
                     {args = {'Unable to show props.... you are a hunter!'}})
        return
    end

    TriggerEvent("nh-context:changePropMenu")
end)

RegisterNetEvent("nh-context:changePropMenu", function()

    local menu = {
        {
            header = "Props List",
            context = "click to close",
            event = "closeMenu",
        },
        {
            header = "UNFREEZE!",
            context = "Pick a new prop and hiding spot!",
            event = "unfreeze",
        }
    }
    
    for k, v in pairs(selectedSpawn.propHashes) do
        table.insert(menu,  {
            header = v.header,
            context = v.context,
            event = "changeProp",
            args = {k}
        })
    end

    TriggerEvent("nh-context:createMenu", menu)
end)

RegisterNetEvent('changeProp', function(propIndex)
    local modelHash = selectedSpawn.propHashes[propIndex].model -- The ` return the jenkins hash of a string. see more at: https://cookbook.fivem.net/2019/06/23/lua-support-for-compile-time-jenkins-hashes/
    local modelOffset = selectedSpawn.propHashes[propIndex].offset
    if not HasModelLoaded(modelHash) then
        -- If the model isnt loaded we request the loading of the model and wait that the model is loaded
        RequestModel(modelHash)

        while not HasModelLoaded(modelHash) do
            Citizen.Wait(1)
        end
    end

    local coords = GetEntityCoords(PlayerPedId())
    -- At this moment the model its loaded, so now we can create the object
    DeleteObject(lastProp)
    lastProp = CreateObject(modelHash, vector3(coords.x+modelOffset.x, coords.y+modelOffset.y, coords.z+modelOffset.z), true)

    SetEntityVisible(PlayerPedId(), false, 0)
    FreezeEntityPosition(PlayerPedId(), true)
    isInvisible = true
    DisableCamCollisionForObject(lastProp)
    DisableCamCollisionForEntity(PlayerPedId())
    SetPedMaxHealth(GetPlayerPed(-1), 200)
    SetEntityHealth(GetPlayerPed(-1), 105)
end)

RegisterNetEvent('unfreeze', function()
    DeleteObject(lastProp)
    SetEntityVisible(PlayerPedId(), true, 0)
    FreezeEntityPosition(PlayerPedId(), false)
    isInvisible = false
    SetFollowPedCamViewMode(2)
    SetPedMaxHealth(GetPlayerPed(-1), 200)
    SetEntityHealth(GetPlayerPed(-1), 200)
end)


RegisterKeyMapping('triggerChangePropMenu', 'Props Menu', "keyboard", "F3")
RegisterKeyMapping('triggerChangeRotationMenu', 'Rotation Menu', "keyboard", "F4")

local BikerZone = PolyZone:Create({
    vector2(114.54899597168, 3575.7958984375),
    vector2(2.8394038677216, 3607.1860351563),
    vector2(-30.212800979614, 3727.9226074219),
    vector2(53.68452835083, 3770.6591796875),
    vector2(106.63172912598, 3769.7277832031),
    vector2(129.77914428711, 3745.66796875),
    vector2(143.52568054199, 3701.1713867188)
  }, {
    name="BikerZone",
    debugPoly=true,
    debugColors={
        walls = {255, 0, 0},
        outline = {255, 0, 0}
    }
  })  

BikerZone:onPlayerInOut(function(isPointInside, point)
    if gameStarted and hasWarmedUp and selectedSpawn.name == 'biker' and not isPointInside then
        isOutsideBoundary = true
    else
        isOutsideBoundary = false
        outOfBoundsTimer = 10
    end
end)

--Name: ConstructionZone | 2022-12-30T08:35:48Z
local ConstructionZone = PolyZone:Create({
    vector2(118.92674255371, -462.50555419922),
    vector2(95.110092163086, -465.68246459961),
    vector2(81.165557861328, -466.64953613281),
    vector2(62.993534088135, -466.52542114258),
    vector2(49.983062744141, -465.68301391602),
    vector2(36.495502471924, -464.38055419922),
    vector2(-12.329765319824, -454.49566650391),
    vector2(-0.12427294254303, -420.29681396484),
    vector2(10.720978736877, -379.21878051758),
    vector2(29.277744293213, -336.7353515625),
    vector2(42.225563049316, -306.73675537109),
    vector2(162.58502197266, -350.50848388672)
  }, {
    name="ConstructionZone",
    debugPoly=true,
    debugColors={
        walls = {255, 0, 0},
        outline = {255, 0, 0}
    }
  })
  
  ConstructionZone:onPlayerInOut(function(isPointInside, point)
    if gameStarted and hasWarmedUp and selectedSpawn.name == 'construction' and not isPointInside then
        isOutsideBoundary = true
    else
        isOutsideBoundary = false
        outOfBoundsTimer = 10
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if isOutsideBoundary then
            outOfBoundsTimer = outOfBoundsTimer - 0.01

            SetTextFont(0)
            SetTextProportional(1)
            SetTextScale(0.0, 0.5)
            SetTextColour(255, 0, 0, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(2, 0, 0, 0, 150)
            SetTextDropShadow()
            SetTextOutline()
            SetTextEntry("STRING")
            SetTextCentre(1)
            AddTextComponentString(("Get back into the play area! \n%.1f"):format(outOfBoundsTimer))
            DrawText(0.5, 0.4)

            if outOfBoundsTimer <= 0 then
                SetEntityCoords(GetPlayerPed(-1), selectedSpawn.hiderSpawnVec.x, selectedSpawn.hiderSpawnVec.y, selectedSpawn.hiderSpawnVec.z)
                isOutsideBoundary = false
                outOfBoundsTimer = 10
                Wait(500)
                DoScreenFadeIn(500)
            end
        end
    end
end)

Citizen.CreateThread(
	function()
		while true do
			Citizen.Wait(0)
			local playerPed = GetPlayerPed(-1)
			local playerId = PlayerId()
			local pos = GetEntityCoords(playerPed)
			RemoveVehiclesFromGeneratorsInArea(
				pos['x'] - 750.0,
				pos['y'] - 750.0,
				pos['z'] - 750.0,
				pos['x'] + 750.0,
				pos['y'] + 750.0,
				pos['z'] + 750.0
			)
			for i = 1, 12 do
				EnableDispatchService(i, false)
			end
			SetPlayerWantedLevel(playerId, 0, false)
			SetPlayerWantedLevelNow(playerId, false)
			SetPlayerWantedLevelNoDrop(playerId, 0, false)
			SetPedPopulationBudget(0)
			SetPedDensityMultiplierThisFrame(0)
			SetScenarioPedDensityMultiplierThisFrame(0, 0)
			SetPedPopulationBudget(0)
			SetVehicleDensityMultiplierThisFrame(0)
			SetRandomVehicleDensityMultiplierThisFrame(0)
			SetParkedVehicleDensityMultiplierThisFrame(0)
			SetPoliceIgnorePlayer(playerPed, true)
			SetDispatchCopsForPlayer(playerPed, false)
		end
	end
)