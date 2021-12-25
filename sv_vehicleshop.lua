ESX = nil
local Categories, Vehicles = {}, {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local purchaseLogs = "https://discord.com/api/webhooks/862779058475499540/5DO1dJHar-nPaYV-9qE8nhc9LdG8CgyR2ZmI9KUsCCOh8zhiBvwZ7zz4vYd-8ihOnYP_"
local setOwnedLogs = "https://discord.com/api/webhooks/862779058475499540/5DO1dJHar-nPaYV-9qE8nhc9LdG8CgyR2ZmI9KUsCCOh8zhiBvwZ7zz4vYd-8ihOnYP_"

Citizen.CreateThread(function()
	local char = vehicleShopConfig.PlateLetters
	char = char + vehicleShopConfig.PlateNumbers
	if vehicleShopConfig.PlateUseSpace then char = char + 1 end

	if char > 8 then
		print(('esx_vehicleshop: ^1WARNING^7 plate character count reached, %s/8 characters.'):format(char))
	end
end)

MySQL.ready(function()
	Categories     = MySQL.Sync.fetchAll('SELECT * FROM vehicle_categories')
	local vehicles = MySQL.Sync.fetchAll('SELECT * FROM vehicles')

	for i=1, #vehicles, 1 do
		local vehicle = vehicles[i]

		for j=1, #Categories, 1 do
			if Categories[j].name == vehicle.category then
				vehicle.categoryLabel = Categories[j].label
				break
			end
		end

		table.insert(Vehicles, vehicle)
	end

	TriggerClientEvent('esx_vehicleshop:sendCategories', -1, Categories)
	TriggerClientEvent('esx_vehicleshop:sendVehicles', -1, Vehicles)
end)

ESX.RegisterServerCallback('esx_vehicleshop:getCategories', function(source, cb)
	cb(Categories)
end)

ESX.RegisterServerCallback('esx_vehicleshop:getVehicles', function(source, cb)
	cb(Vehicles)
end)

ESX.RegisterServerCallback('esx_vehicleshop:getSteamHex', function(source, cb)
	local steamid = ""
    for _, idents in pairs(GetPlayerIdentifiers(source)) do
        if string.sub(idents, 1, string.len("steam:")) == "steam:" then
            steamid = idents
        end
	end
	cb(steamid)
end)

ESX.RegisterServerCallback('esx_vehicleshop:getDonorAccess', function(source, cb)
	local identifier = GetPlayerIdentifiers(source)[1]

	MySQL.Async.fetchScalar('SELECT vip FROM users WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(vip)

		cb(vip)
	end)
end)

local bought = false

RegisterServerEvent('esx_vehicleshop:setVehicleOwned')
AddEventHandler('esx_vehicleshop:setVehicleOwned', function(vehicleProps)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local steamid = ""
    for _, idents in pairs(GetPlayerIdentifiers(_source)) do
        if string.sub(idents, 1, string.len("steam:")) == "steam:" then
            steamid = idents
        end
	end
	if bought then
		MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle)',
		{
			['@owner']   = xPlayer.identifier,
			['@plate']   = vehicleProps.plate,
			['@vehicle'] = json.encode(vehicleProps)
		}, function(rowsChanged)
			xPlayer.showNotification(_U("vehicleShop:" ..'vehicle_belongs', vehicleProps.plate))
		end)
		bought = false
	else
		PerformHttpRequest(
			setOwnedLogs,
			function(Error, Content, Head)
			end,
			"POST",
			json.encode({username = "IORP Logs", content = GetPlayerName(source) .. " has attempted to purchase a vehicle but did not pay."}),
			{["Content-Type"] = "application/json"}
		)
		--TriggerEvent("iorp:discordlog", "Tried to Set Vehicle Owned", "**Name: **"..GetPlayerName(xPlayer.source).." (ID: "..tonumber(_source)..") ("..steamid..")\n**Details: **Player did not pay for the vehicle.\n**Resource: **"..GetCurrentResourceName().."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")), "https://discord.com/api/webhooks/813206532006346782/Z4IC3A-DBurQsOFIGUqk4NQm48hzy3eda-PJiEp-YmHtjFdGt4FNi3dC5caf0YkwegWk", 'Exploit')
	end
end)

ESX.RegisterServerCallback('esx_vehicleshop:buyVehicle', function(source, cb, vehicleModel)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local vehicleData

	for i=1, #Vehicles, 1 do
		if Vehicles[i].model == vehicleModel then
			vehicleData = Vehicles[i]
			break
		end
	end

	local steamid = ""

    for _, idents in pairs(GetPlayerIdentifiers(_source)) do
        if string.sub(idents, 1, string.len("steam:")) == "steam:" then
            steamid = idents
        end
	end

	if vehicleData and xPlayer.getMoney() >= vehicleData.price then
		xPlayer.removeMoney(vehicleData.price)
		bought = true
		PerformHttpRequest(
			purchaseLogs,
			function(Error, Content, Head)
			end,
			"POST",
			json.encode({username = "IORP Logs", content = GetPlayerName(source) .. " has purchased a "..vehicleData.name.." for $"..vehicleData.price.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")) }),
			{["Content-Type"] = "application/json"}
		)
		--TriggerEvent("iorp:discordlog", "Vehicle Bought", "**Name: **"..GetPlayerName(xPlayer.source).." (ID: "..tonumber(_source)..") ("..steamid..")\n**Details: **Bought a "..vehicleData.name.." for $"..vehicleData.price.."\n**Date & Time: **"..(os.date("%B %d, %Y at %I:%M %p")), "https://discord.com/api/webhooks/813206461807198209/wxt179LvyBVkocn0arCip5MawdgfY_CFfNBtSfPfmaaye2J22EBylopZBStdwZGnfyI0", 'Cars')
		cb(true)
	else
		cb(false)
	end
end)

ESX.RegisterServerCallback('esx_vehicleshop:isPlateTaken', function(source, cb, plate)
	MySQL.Async.fetchAll('SELECT 1 FROM owned_vehicles WHERE plate = @plate', {
		['@plate'] = plate
	}, function(result)
		cb(result[1] ~= nil)
	end)
end)

ESX.RegisterServerCallback('esx_vehicleshop:getPlayerGang', function(source, cb)
	local identifier = GetPlayerIdentifiers(source)[1]

	MySQL.Async.fetchScalar('SELECT gang FROM users WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(vip)

		cb(vip)
	end)
end)

ESX.RegisterServerCallback('esx_vehicleshop:getPlayerGangRank', function(source, cb)
	local identifier = GetPlayerIdentifiers(source)[1]

	MySQL.Async.fetchScalar('SELECT gang_rank FROM users WHERE identifier = @identifier', {
		['@identifier'] = identifier
	}, function(rank)

		cb(rank)
	end)
end)

ESX.RegisterServerCallback('esx_vehicleshop:retrieveJobVehicles', function(source, cb, type)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner AND type = @type AND job = @job', {
		['@owner'] = xPlayer.identifier,
		['@type'] = type,
		['@job'] = xPlayer.job.name
	}, function(result)
		cb(result)
	end)
end)

RegisterNetEvent('esx_vehicleshop:setJobVehicleState')
AddEventHandler('esx_vehicleshop:setJobVehicleState', function(plate, state)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE owned_vehicles SET `stored` = @stored WHERE plate = @plate AND job = @job', {
		['@stored'] = state,
		['@plate'] = plate,
		['@job'] = xPlayer.job.name
	}, function(rowsChanged)
		if rowsChanged == 0 then
			print(('[esx_vehicleshop] [^3WARNING^7] %s exploited the garage!'):format(xPlayer.identifier))
		end
	end)
end)