Citizen.CreateThread(function()
    local NumberCharset = {}
    local Charset = {}
    
    for i = 48, 57 do table.insert(NumberCharset, string.char(i)) end
    
    for i = 65, 90 do table.insert(Charset, string.char(i)) end
    for i = 97, 122 do table.insert(Charset, string.char(i)) end
    
    function GeneratePlate()
        local generatedPlate
        local doBreak = false
        
        while true do
            Citizen.Wait(2)
            math.randomseed(GetGameTimer())
            if vehicleShopConfig.PlateUseSpace then
                generatedPlate = string.upper(GetRandomLetter(vehicleShopConfig.PlateLetters) .. ' ' .. GetRandomNumber(vehicleShopConfig.PlateNumbers))
            else
                generatedPlate = string.upper(GetRandomLetter(vehicleShopConfig.PlateLetters) .. GetRandomNumber(vehicleShopConfig.PlateNumbers))
            end
            
            ESX.TriggerServerCallback('esx_vehicleshop:isPlateTaken', function(isPlateTaken)
                if not isPlateTaken then
                    doBreak = true
                end
            end, generatedPlate)
            
            if doBreak then
                break
            end
        end
        
        return generatedPlate
    end

    exports("GeneratePlate", function()
        local generatedPlate
                local doBreak = false
        
                while true do
                    Citizen.Wait(2)
                    math.randomseed(GetGameTimer())
                    if vehicleShopConfig.PlateUseSpace then
                        generatedPlate = string.upper(GetRandomLetter(vehicleShopConfig.PlateLetters) .. ' ' .. GetRandomNumber(vehicleShopConfig.PlateNumbers))
                    else
                        generatedPlate = string.upper(GetRandomLetter(vehicleShopConfig.PlateLetters) .. GetRandomNumber(vehicleShopConfig.PlateNumbers))
                    end
        
                    ESX.TriggerServerCallback('esx_vehicleshop:isPlateTaken', function(isPlateTaken)
                        if not isPlateTaken then
                            doBreak = true
                        end
                    end, generatedPlate)
        
                    if doBreak then
                        break
                    end
                end
        
                return generatedPlate
        end)
    
    -- mixing async with sync tasks
    function IsPlateTaken(plate)
        local callback = 'waiting'
        
        ESX.TriggerServerCallback('esx_vehicleshop:isPlateTaken', function(isPlateTaken)
            callback = isPlateTaken
        end, plate)
        
        while type(callback) == 'string' do
            Citizen.Wait(0)
        end
        
        return callback
    end
    
    function GetRandomNumber(length)
        Citizen.Wait(0)
        math.randomseed(GetGameTimer())
        if length > 0 then
            return GetRandomNumber(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
        else
            return ''
        end
    end
    
    function GetRandomLetter(length)
        Citizen.Wait(0)
        math.randomseed(GetGameTimer())
        if length > 0 then
            return GetRandomLetter(length - 1) .. Charset[math.random(1, #Charset)]
        else
            return ''
        end
    end
    
    local HasAlreadyEnteredMarker = false
    local LastZone
    local CurrentAction
    local CurrentActionMsg = ''
    local CurrentActionData = {}
    local IsInShopMenu = false
    local Categories = {}
    local Vehicles = {}
    local LastVehicles = {}
    local CurrentVehicleData
    
    ESX = nil
    
    Citizen.CreateThread(function()
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj)ESX = obj end)
            Citizen.Wait(0)
        end
        
        Citizen.Wait(10000)
        
        ESX.TriggerServerCallback('esx_vehicleshop:getCategories', function(categories)
            Categories = categories
        end)
        
        ESX.TriggerServerCallback('esx_vehicleshop:getVehicles', function(vehicles)
            Vehicles = vehicles
        end)
    
    end)
    
    RegisterNetEvent('esx_vehicleshop:sendCategories')
    AddEventHandler('esx_vehicleshop:sendCategories', function(categories)
        Categories = categories
    end)
    
    RegisterNetEvent('esx_vehicleshop:sendVehicles')
    AddEventHandler('esx_vehicleshop:sendVehicles', function(vehicles)
        Vehicles = vehicles
    end)
    
    function DeleteShopInsideVehicles()
        while #LastVehicles > 0 do
            local vehicle = LastVehicles[1]
            
            ESX.Game.DeleteVehicle(vehicle)
            table.remove(LastVehicles, 1)
        end
    end
    
    function StartShopRestriction()
        Citizen.CreateThread(function()
            while IsInShopMenu do
                Citizen.Wait(0)
                
                DisableControlAction(0, 75, true)-- Disable exit vehicle
                DisableControlAction(27, 75, true)-- Disable exit vehicle
            end
        end)
    end
    
    function OpenVehicleShopMenu()
        IsInShopMenu = true
        
        StartShopRestriction()
        ESX.UI.Menu.CloseAll()
        
        local playerPed = PlayerPedId()
        
        FreezeEntityPosition(playerPed, true)
        SetEntityVisible(playerPed, false)
        SetEntityCoords(playerPed, vehicleShopConfig.Zones.ShopInside.Pos)
        
        local vehiclesByCategory = {}
        local elements = {}
        local firstVehicleData = nil
        
        for i = 1, #Categories, 1 do
            vehiclesByCategory[Categories[i].name] = {}
        end
        
        for i = 1, #Vehicles, 1 do
            if IsModelInCdimage(GetHashKey(Vehicles[i].model)) then
                table.insert(vehiclesByCategory[Vehicles[i].category], Vehicles[i])
            else
                print(('esx_vehicleshop: vehicle "%s" does not exist'):format(Vehicles[i].model))
            end
        end
        
        for i = 1, #Categories, 1 do
            local category = Categories[i]
            local categoryVehicles = vehiclesByCategory[category.name]
            local options = {}
            
            for j = 1, #categoryVehicles, 1 do
                local vehicle = categoryVehicles[j]
                
                if i == 1 and j == 1 then
                    firstVehicleData = vehicle
                end
                
                table.insert(options, ('%s <span style="color:green;">%s</span>'):format(vehicle.name, _U("vehicleShop:" .. 'generic_shopitem', ESX.Math.GroupDigits(vehicle.price))))
            end
            
            table.insert(elements, {
                name = category.name,
                label = category.label,
                value = 0,
                type = 'slider',
                max = #Categories[i],
                options = options
            })
        end
        
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_shop', {
            css = 'Factures',
            title = _U("vehicleShop:" .. 'car_dealer'),
            align = 'top-right',
            elements = elements
        }, function(data, menu)
            local vehicleData = vehiclesByCategory[data.current.name][data.current.value + 1]
            
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_confirm', {
                css = 'Factures',
                title = _U("vehicleShop:" .. 'buy_vehicle_shop', vehicleData.name, ESX.Math.GroupDigits(vehicleData.price)),
                align = 'top-right',
                elements = {
                    {label = _U("vehicleShop:" .. 'no'), value = 'no'},
                    {label = _U("vehicleShop:" .. 'yes'), value = 'yes'}
                }}, function(data2, menu2)
                if data2.current.value == 'yes' then
                    if vehicleData.category == 'donor' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getDonorAccess', function(isVIP)
                            if isVIP then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You are not a donator. If you would like access to the donor cars, please visit the official Menace RP discord for more information.")
                            end
                        end, GetPlayerServerId(PlayerId()), '1')
                    elseif vehicleData.category == 'one' and vehicleData.model == 'patty' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getSteamHex', function(steamhex)
                            if steamhex == 'steam:110000135735ac9' then --waze
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'db11' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'com' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'silvia3' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'gdk' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'variszupra' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'element' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == '610DTM' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'sg' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'mbbs20' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'thewoo' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'tampax' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'venom' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'lw458s' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'cartel' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'hachurac' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'bd' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'vulcan' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'gb' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'armordillo' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'thf' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'rmodm4' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGang', function(gang)
                            if gang == 'nf' then
                                ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                    if hasEnoughMoney then
                                        IsInShopMenu = false
                                        menu2.close()
                                        menu.close()
                                        DeleteShopInsideVehicles()
                                        
                                        ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                            
                                            local newPlate = GeneratePlate()
                                            local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                            vehicleProps.plate = newPlate
                                            SetVehicleNumberPlateText(vehicle, newPlate)
                                            
                                            TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                            
                                            ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                        end)
                                        
                                        FreezeEntityPosition(playerPed, false)
                                        SetEntityVisible(playerPed, true)
                                    else
                                        ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                    end
                                end, vehicleData.model)
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    elseif vehicleData.category == 'gang' and vehicleData.model == 'armordillo' then
                        ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGangRank', function(gang)
                            if gang == 'dg' or gang == 'sins' or gang == 'nine' or gang == 'ba' or gang == 'nbk' then
                                ESX.TriggerServerCallback('esx_vehicleshop:getPlayerGangRank', function(rank)
                                    if rank == 3 then
                                        ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                                            if hasEnoughMoney then
                                                IsInShopMenu = false
                                                menu2.close()
                                                menu.close()
                                                DeleteShopInsideVehicles()
                                                
                                                ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                                    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                                    
                                                    local newPlate = GeneratePlate()
                                                    local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                                    vehicleProps.plate = newPlate
                                                    SetVehicleNumberPlateText(vehicle, newPlate)
                                                    
                                                    TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                                    
                                                    ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                                end)
                                                
                                                FreezeEntityPosition(playerPed, false)
                                                SetEntityVisible(playerPed, true)
                                            else
                                                ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                                            end
                                        end, vehicleData.model)
                                    else
                                        ESX.ShowNotification("You are not a gang leader.")
                                    end
                                end, GetPlayerServerId(PlayerId()))
                            else
                                ESX.ShowNotification("You do not have permission to buy this vehicle.")
                            end
                        end, GetPlayerServerId(PlayerId()))
                    else
                        ESX.TriggerServerCallback('esx_vehicleshop:buyVehicle', function(hasEnoughMoney)
                            if hasEnoughMoney then
                                IsInShopMenu = false
                                menu2.close()
                                menu.close()
                                DeleteShopInsideVehicles()
                                
                                ESX.Game.SpawnVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopOutside.Pos, vehicleShopConfig.Zones.ShopOutside.Heading, function(vehicle)
                                    TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                                    
                                    local newPlate = GeneratePlate()
                                    local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
                                    vehicleProps.plate = newPlate
                                    SetVehicleNumberPlateText(vehicle, newPlate)
                                    
                                    TriggerServerEvent('esx_vehicleshop:setVehicleOwned', vehicleProps)
                                    
                                    ESX.ShowNotification(_U("vehicleShop:" .. 'vehicle_purchased'))
                                end)
                                
                                FreezeEntityPosition(playerPed, false)
                                SetEntityVisible(playerPed, true)
                            else
                                ESX.ShowNotification(_U("vehicleShop:" .. 'not_enough_money'))
                            end
                        end, vehicleData.model)
                    end
                end
                end, function(data2, menu2)
                    menu2.close()
                end)
        end, function(data, menu)
            menu.close()
            DeleteShopInsideVehicles()
            local playerPed = PlayerPedId()
            
            CurrentAction = 'shop_menu'
            CurrentActionMsg = _U("vehicleShop:" .. 'shop_menu')
            CurrentActionData = {}
            
            FreezeEntityPosition(playerPed, false)
            SetEntityVisible(playerPed, true)
            SetEntityCoords(playerPed, vehicleShopConfig.Zones.ShopEntering.Pos)
            
            IsInShopMenu = false
        end, function(data, menu)
            local vehicleData = vehiclesByCategory[data.current.name][data.current.value + 1]
            local playerPed = PlayerPedId()
            
            DeleteShopInsideVehicles()
            WaitForVehicleToLoad(vehicleData.model)
            
            ESX.Game.SpawnLocalVehicle(vehicleData.model, vehicleShopConfig.Zones.ShopInside.Pos, vehicleShopConfig.Zones.ShopInside.Heading, function(vehicle)
                table.insert(LastVehicles, vehicle)
                TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
                FreezeEntityPosition(vehicle, true)
                SetModelAsNoLongerNeeded(vehicleData.model)
            end)
        end)
        
        DeleteShopInsideVehicles()
        WaitForVehicleToLoad(firstVehicleData.model)
        
        ESX.Game.SpawnLocalVehicle(firstVehicleData.model, vehicleShopConfig.Zones.ShopInside.Pos, vehicleShopConfig.Zones.ShopInside.Heading, function(vehicle)
            table.insert(LastVehicles, vehicle)
            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
            FreezeEntityPosition(vehicle, true)
            SetModelAsNoLongerNeeded(firstVehicleData.model)
        end)
    end
    
    function WaitForVehicleToLoad(modelHash)
        modelHash = (type(modelHash) == 'number' and modelHash or GetHashKey(modelHash))
        
        if not HasModelLoaded(modelHash) then
            RequestModel(modelHash)
            
            BeginTextCommandBusyString('STRING')
            AddTextComponentSubstringPlayerName(_U("vehicleShop:" .. 'shop_awaiting_model'))
            EndTextCommandBusyString(4)
            
            while not HasModelLoaded(modelHash) do
                Citizen.Wait(0)
                DisableAllControlActions(0)
            end
            
            RemoveLoadingPrompt()
        end
    end
    
    AddEventHandler('esx_vehicleshop:hasEnteredMarker', function(zone)
        if zone == 'ShopEntering' then
            CurrentAction = 'shop_menu'
            CurrentActionMsg = _U("vehicleShop:" .. 'shop_menu')
            CurrentActionData = {}
        end
    end)
    
    AddEventHandler('esx_vehicleshop:hasExitedMarker', function(zone)
        if not IsInShopMenu then
            ESX.UI.Menu.CloseAll()
        end
        
        CurrentAction = nil
    end)
    
    AddEventHandler('onResourceStop', function(resource)
        if resource == GetCurrentResourceName() then
            if IsInShopMenu then
                ESX.UI.Menu.CloseAll()
                
                DeleteShopInsideVehicles()
                local playerPed = PlayerPedId()
                
                FreezeEntityPosition(playerPed, false)
                SetEntityVisible(playerPed, true)
                SetEntityCoords(playerPed, vehicleShopConfig.Zones.ShopEntering.Pos)
            end
        end
    end)
    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            local playerCoords = GetEntityCoords(PlayerPedId())
            local isInMarker, letSleep, currentZone = false, true
            
            for k, v in pairs(vehicleShopConfig.Zones) do
                local distance = #(playerCoords - v.Pos)
                
                if distance < vehicleShopConfig.DrawDistance then
                    letSleep = false
                    
                    if v.Type ~= -1 then
                        DrawMarker(v.Type, v.Pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, vehicleShopConfig.MarkerColor.r, vehicleShopConfig.MarkerColor.g, vehicleShopConfig.MarkerColor.b, 100, false, true, 2, true, nil, nil, false)
                    end
                    
                    if distance < v.Size.x then
                        isInMarker, currentZone = true, k
                    end
                end
            end
            
            if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
                HasAlreadyEnteredMarker, LastZone = true, currentZone
                LastZone = currentZone
                TriggerEvent('esx_vehicleshop:hasEnteredMarker', currentZone)
            end
            
            if not isInMarker and HasAlreadyEnteredMarker then
                HasAlreadyEnteredMarker = false
                TriggerEvent('esx_vehicleshop:hasExitedMarker', LastZone)
            end
            
            if letSleep then
                Citizen.Wait(500)
            end
        end
    end)
    
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            
            if CurrentAction then
                ESX.ShowHelpNotification(CurrentActionMsg)
                
                if IsControlJustReleased(0, 38) then
                    if CurrentAction == 'shop_menu' then
                        OpenVehicleShopMenu()
                    end
                    
                    CurrentAction = nil
                end
            else
                Citizen.Wait(500)
            end
        end
    end)
    
    Citizen.CreateThread(function()
        RequestIpl('shr_int')
        local interiorID = 7170
        LoadInterior(interiorID)
        EnableInteriorProp(interiorID, 'csr_beforeMission')
        RefreshInterior(interiorID)
    end)
end)
