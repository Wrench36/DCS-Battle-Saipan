--[[ 
assert(loadfile(lfs.writedir() .. "Missions/Huey/PersistentCampaign/patrolLiftPersistence.lua"))()
Groups spawned from the units file that are copies of a previous units copy don't get routes

to save script values from other script to a file, use the following syntax.
saveStatics.addValue({"scriptClass","variable"},scriptvaluesFile)
For example, this will work with
saveStatics.addValue({"patrolLift","freq"},scriptvaluesFile)
and save it as ['patrolLift.freq'] = 30,

]]

local myLog = mist.Logger:new('patrolLiftPersistence')
if not Wrench then Wrench = {} end
if not Wrench.spawnedGroupsRoutes then Wrench.spawnedGroupsRoutes = {} end

saveStatics = {}
SaveBlueUnits={}
blueUnits = {}
saveStatics.valsToGet = {}
saveStatics.scriptVals = {}
saveStatics.spawnedGroupsNum = 0

if not ctld then
	ctld = {}
	ctld['spawnedCratesBLUE'] = {}
	ctld.nextGroupId = 1
	ctld.nextUnitId = 1
else
	trigger.action.outText("persistence must be loaded BEFORE ctld." , 10 , false)
end

function saveStatics.tableSerializer(tab,recurseBool)
	if type(tab) == 'table' then
		local thisString = ''
		for k,v in pairs(tab) do
			thisString = thisString .. "\n\t['" .. k .. "'] = "
			local typeV = type(v)
			if typeV == 'table' then
				recurseString = saveStatics.tableSerializer(v,true)
				thisString = thisString .. '{' .. recurseString .. '\n},'
			elseif type(v) == 'string' then
				thisString = thisString .. "'" .. v .. "',"
			else
				thisString = thisString .. tostring(v) .. ","
			end
		end
		if not recurseBool then 
			--if not name then name = "mysteryTable" end
			--thisString = name .. ' = {' .. thisString .. '\n}' 
			thisString = 'tab = {' .. thisString .. '\n} \nreturn tab' 
		end
		return thisString
	else
		return tab
	end
end

function saveStatics.file_exists(name) --check if the file already exists for writing
	if lfs.attributes(name) then
		return true
	else
		return false
	end 
end

function saveStatics.writeFile(data, file)--Function for saving to file (commonly found)
	local outputFile = io.open(file, "w")
	if type(data) == "table" then
		data = saveStatics.tableSerializer(data)
	end
	outputFile:write(data)
	outputFile:close()
end


function saveStatics.getStaticInfo(objTab)
	local staticObj = {}
	staticObj["country"] = objTab["country"]
	if type(staticObj["country"]) == "number" then
		staticObj["country"] = country.name[staticObj["country"]]
	end
	staticObj["Coutry_ID"] = objTab["Country"]
	staticObj["heading"] =objTab["heading"]
	--staticObj["groupId"] = objTab["data"]["groupId"]
	staticObj["shape_name"] = mist.DBs.const.shapeNames[objTab["type"]]
	staticObj["type"] = objTab["type"]
	staticObj["unitId"] = objTab["obj"]["id_"]
	staticObj["rate"] = 100
	staticObj["name"] = objTab["name"]
	staticObj["category"] = objTab["cat"]
	staticObj["y"] = objTab["pos"].z
	staticObj["x"] = objTab["pos"].x
	staticObj["dead"] = false
	if objTab["cat"] == 6 then
		staticObj["canCargo"] = true
		staticObj["mass"] = 680.388555
	end
	return staticObj
end







SaveStatics={}
allStatics = {}

function saveStatics.getAllStatics(staticFile)
	myLog:msg("getting all statics")
	SaveStatics={}
	blueStatics = coalition.getStaticObjects(2)
	for i=1,#blueStatics do
		status, error = pcall(function()
			local name = blueStatics[i]:getName()
			local dead = false
			local sataticPos = blueStatics[i]:getPosition().p
			local objType = blueStatics[i]:getTypeName()
			--local groupid = getGroup(blueStatics[i])
			local cat = blueStatics[i]:getCategory()
			--local data = mist.getGroupData(name)
			--local heading = mist.getHeading(StaticObject.getByName("name"), true)
			local pos3 = blueStatics[i]:getPosition()
			local heading = math.atan2(pos3.x.z, pos3.x.x)
			if StaticObject.getLife(blueStatics[i]) < 1 then
				dead = true
			end
			allStatics[name] = {}
			allStatics[name]["name"] = name
			allStatics[name]["dead"] = dead
			allStatics[name]["obj"] = blueStatics[i]
			allStatics[name]["pos"] = sataticPos
			allStatics[name]["type"] = objType
			allStatics[name]["heading"] = heading
			--allStatics[name]["groupId"] = groupid
			allStatics[name]["cat"] = cat
			--allStatics[name]["data"] = data
			allStatics[name]["Country"] = blueStatics[i]:getCountry()
		end)
		if not status then
			myLog:msg(error)
		end
	end
	redStatics = coalition.getStaticObjects(2)
	for i=1,#redStatics do
		status, error = pcall(function()
			local name = redStatics[i]:getName()
			local dead = false
			local sataticPos = redStatics[i]:getPosition().p
			local objType = redStatics[i]:getTypeName()
			--local groupid = getGroup(redStatics[i])
			local cat = redStatics[i]:getCategory()
			--local data = mist.getGroupData(name)
			--local heading = mist.getHeading(StaticObject.getByName("name"), true)
			local pos3 = redStatics[i]:getPosition()
			local heading = math.atan2(pos3.x.z, pos3.x.x)

			if StaticObject.getLife(redStatics[i]) < 1 then
				dead = true
			end
			allStatics[name] = {}
			allStatics[name]["name"] = name
			allStatics[name]["dead"] = dead
			allStatics[name]["obj"] = redStatics[i]
			allStatics[name]["pos"] = sataticPos
			allStatics[name]["type"] = objType
			allStatics[name]["heading"] = heading
			--allStatics[name]["groupId"] = groupid
			allStatics[name]["cat"] = cat
			--allStatics[name]["data"] = data
			allStatics[name]["Country"] = redStatics[i]:getCountry()
		end)
		if not status then
			myLog:msg(error)
		end
	end
	staticString = saveStatics.tableSerializer(allStatics,recurseBool)
	saveStatics.writeFile(staticString, staticFile)
	myLog:msg("getAllStatics done")
end

function saveStatics.fileExistStatic(staticFile)
	if saveStatics.file_exists(staticFile) then
		myLog:msg("Script loading existing Statics database")
		SaveStatics = dofile(staticFile)
		
		for k,v in pairs(SaveStatics) do
			local static = StaticObject.getByName(SaveStatics[k]["name"])
			if static then
				static:destroy()
			end
		end
		timer.scheduleFunction(spawnStatics,nil, timer.getTime() + 2)
	else
		myLog:msg('no statics file found, reading from mission.')
		saveStatics.getAllStatics(staticFile)
	end
end

function spawnStatics()
	for k,v in pairs(SaveStatics) do
		local static = StaticObject.getByName(SaveStatics[k]["name"])
		if not SaveStatics[k]["dead"] then
			local spnData = saveStatics.getStaticInfo(SaveStatics[k])
			local name = spnData["name"]
			
			if string.find(name,"Deployed FOB") then
				myLog:msg("found FOB!")
				saveStatics.buildFOB(name) 
				--[[	
			elseif string.find(name,"FOB") and ctld then
				--name = name .. "_p"
				--found fob crate
				ctld['spawnedCratesBLUE'][name] = {
					['unit'] = 'FOB-SMALL',
					['desc'] = 'FOB Crate - Small',
					['weight'] = 400,
				}
				]]
			end
			mist.scheduleFunction(coalition.addStaticObject ,{spnData["Coutry_ID"], spnData} ,timer.getTime() + 2 , 10 ,timer.getTime() + 5 )
		end
	end
	
end

function saveStatics.buildFOB(name) 
	local class = StaticObject.getByName(name)
	local pos = class:getPosition().p
	local _unitId = StaticObject.getID(class)
	table.insert(ctld.logisticUnits, name)
	ctld.beaconCount = ctld.beaconCount + 1
	local _radioBeaconName = "FOB Beacon #" .. ctld.beaconCount
	local _radioBeaconDetails = ctld.createRadioBeacon(pos, "GEORGIA", 2, _radioBeaconName, nil, true)
	ctld.fobBeacons[name] = { vhf = _radioBeaconDetails.vhf, uhf = _radioBeaconDetails.uhf, fm = _radioBeaconDetails.fm }
	if ctld.troopPickupAtFOB == true then
		table.insert(ctld.builtFOBS, name)
	end
end

function saveStatics.addValue(val,file)
	local class = val[1]
	local value = val[2]
	table.insert(saveStatics.valsToGet,{class,value})
	myLog:msg(saveStatics.valsToGet)
end

function saveStatics.getScriptVals(file)
	myLog:msg("getScriptVals")
	saveStatics.scriptVals = {}
	for k,v in pairs(saveStatics.valsToGet) do
		status, error = pcall(function()
			local class = v[1]
			local val = v[2]
			local key = tostring(class) .. "." .. tostring(val)
			myLog:msg(key)
			if _G[class] then
				local Gval = _G[class][val]
				if not saveStatics.scriptVals[class] then
					saveStatics.scriptVals[class] = {}
				end
				saveStatics.scriptVals[class][val] = Gval
			end
		end)
		if not status then
			myLog:msg(error)
		end
	end
	saveStatics.writeFile(saveStatics.scriptVals,file)
	myLog:msg("getScriptVals done.")
end

function saveStatics.fileExistScripts(file)
	if saveStatics.file_exists(file) then
		myLog:msg("Script loading existing script values")
		local returns = dofile(file)
		if type(returns) == 'table' then
			for k,v in pairs(returns) do
				_G[k] = {}
				_G[k] = v
			end
		end
	else
		myLog:msg("No Scripts file, reading from mission")
		saveStatics.getScriptVals(file)
	end
end








function saveStatics.getBlueGroups(unitFile)
	myLog:msg("saveStatics.getBlueGroups")
	SaveBlueUnits = {}
	bluegroups = coalition.getGroups(2 , 2)
	for i=1, #bluegroups do
		local name = bluegroups[i]:getName()
		if mist.groupIsDead(name) then 
			do break end
		end
		if string.find(name,"patrolExclude") then
			do break end
		end
		blueUnits[name] = {}
		blueUnits[name]["name"] = name
		blueUnits[name]["data"] = mist.getCurrentGroupData(name)
		if blueUnits[name]["data"]["units"][1] then
			blueUnits[name]["data"]["country"] = blueUnits[name]["data"]["units"][1]["country"]
			if not blueUnits[name]["data"]["country"] then
				myLog:msg(name .. " stil has no country, assigning georgia")
				blueUnits[name]["data"]["country"] = "GEORGIA"
			end
			if Wrench.spawnedGroupsRoutes then
				if Wrench.spawnedGroupsRoutes[name] then
					blueUnits[name]["data"]["route"] = Wrench.spawnedGroupsRoutes[name]["route"]
				end
			end
		else
			myLog:msg(name .. " has no units, removing from database.")
			blueUnits[name] = nil
		end
	end
	
	unitString = saveStatics.tableSerializer(blueUnits)
	saveStatics.writeFile(unitString, unitFile)
	myLog:msg("saveStatics.getBlueGroups done.")
end

function saveStatics.fileExistUnits(unitFile)
	if saveStatics.file_exists(unitFile) then
		myLog:msg("Script loading existing Units database")
		
		local blueGroups = coalition.getGroups(2,2)
		for i=1,#blueGroups do
			local name = blueGroups[i]:getName()
			if string.find(name,"patrolExclude") then
				do break end
			end
			local units = blueGroups[i]:getUnits()
			for j=1,#units do
				units[j]:destroy()
			end
		end
		
		SaveBlueUnits = dofile(unitFile)
		for k,v in pairs(SaveBlueUnits) do
			local groupName = SaveBlueUnits[k]["name"]
			local gpNum = string.match(groupName, '%S+$')
			gnum = tonumber(gpNum)
			s2 = ""
			for m in string.gmatch(groupName, "%d") do
				s2 = s2 .. m
			end
			groupName = string.gsub(groupName,s2,"")
			groupName = string.gsub(groupName,"spawn","")
			if not gnum then gnum = 1 end
			if ctld then
				ctld.nextGroupId = ctld.nextGroupId + 1
			end
			if Group.getByName(SaveBlueUnits[k]["name"]) then
				local grp = Group.getByName(SaveBlueUnits[k]["name"])
				grp:destroy()
			end
			thisGrp = {}
			thisGrp.country = v.data.country
			thisGrp.category = v.data.category
			thisGrp.route = v["data"]["route"]
			thisGrp.hidden = false
			thisGrp.visible = true
			thisGrp.name = groupName .. "spawn" .. gnum + 1
			thisGrp["units"] = {}
			
			if thisGrp.route then
				for key,val in pairs(thisGrp["route"]) do
					local keyNum = tonumber(key)
					thisGrp["route"][keyNum] = val
					thisGrp["route"][key] = nil	
				end
			end
			
			for key,val in pairs(v.data.units) do
				local keyNum = tonumber(key)
				
				thisGrp["units"][keyNum] = {}
				thisGrp["units"][keyNum]['alt'] = val["alt"]
				thisGrp["units"][keyNum]['point'] = {}
				thisGrp["units"][keyNum]['point'] = val["point"]
				thisGrp["units"][keyNum]['coalitionId'] = val["coalitionId"]
				thisGrp["units"][keyNum]['skill'] = val["skill"]
				thisGrp["units"][keyNum]['category'] = val["category"]
				thisGrp["units"][keyNum]['type'] = val["type"]
				thisGrp["units"][keyNum]['countryId'] = val["countryId"]
				thisGrp["units"][keyNum]['x'] = val["x"]
				thisGrp["units"][keyNum]['y'] = val["y"]
				thisGrp["units"][keyNum]['heading'] = val["heading"]
				thisGrp["units"][keyNum]['country'] = val["country"]
				thisGrp["units"][keyNum]['livery_id']  = val['livery_id']
				thisGrp["units"][keyNum]['name']  = groupName .. keyNum
				if ctld then
					ctld.nextUnitId = ctld.nextUnitId + 1
				end
			end
			
			if not thisGrp["units"][1] then
				myLog:msg(SaveBlueUnits[k]["name"] .. " has no units!")
				do break end
			end
			
			if thisGrp["country"] then else
				thisGrp["country"] = thisGrp["units"][1]["country"]
			end
			if thisGrp.country then else
				myLog:msg(k .. " still has no country!")
			end
			
			local spawnGroup = mist.dynAdd(thisGrp)
			--mist.DBs.groupsByName[spawnGroup["name"]] = mist.utils.deepCopy(spawnGroup)
			--mist.DBs.groupsByName[spawnGroup["name"]]["groupName"] =  mist.utils.deepCopy(spawnGroup["name"])
			--mist.DBs.MEgroupsByName[spawnGroup["name"]] = mist.utils.deepCopy(spawnGroup)
			--saveStatics.fixDB(spawnGroup)
		end
		
		
	else --Save File does not exist we start a fresh table
		myLog:msg('no units file found')
		SaveBlueUnits={}
		saveStatics.getBlueGroups(unitFile)
	end
end

function saveStatics.fixDB(gpData)
	local name = gpData["name"]
	local grp = Group.getByName(name)
	local unit1 = grp:getUnit(1)
	local countyId = unit1:getCountry()
	local countryName = country.name[countyId] 
	--mist.DBs.groupsByName[name]['country'] = mist.utils.deepCopy(countryName)
	local n = #gpData["units"]
	for i=1, n do
		local uniName = gpData["units"][i]["name"]
		local point = {}
		point.x = gpData["units"][i]["x"]
		point.y = gpData["units"][i]["y"]
		--mist.DBs.groupsByName[name]["units"][i]["point"] = point
		--mist.DBs.groupsByName[name]["units"][i]["country"] = countryName
		--mist.DBs.unitsByName[uniName] = gpData["units"][i]
	end
end

-----------------start-------------------
function saveStatics.start(staticFile,scriptvaluesFile)
	if scriptvaluesFile then
		saveStatics.fileExistScripts(scriptvaluesFile)
		mist.scheduleFunction(saveStatics.getScriptVals ,{scriptvaluesFile} ,timer.getTime() + 5 , 10 ,1/0 )
	end
	saveStatics.fileExistStatic(staticFile)
	mist.scheduleFunction(saveStatics.getAllStatics ,{staticFile} ,timer.getTime() + 2 , 10 ,1/0 )
	
	saveStatics.fileExistUnits(unitFile)
	mist.scheduleFunction(saveStatics.getBlueGroups ,{unitFile} ,timer.getTime() + 3 , 10 ,1/0 )
end

--[[
assert(loadfile(lfs.writedir() .. "Missions/Huey/PersistentCampaign/patrolLiftPersistence.lua"))()

staticFile = lfs.writedir() .. "missions/Huey/PersistentCampaign/save - statics.lua"
unitFile = lfs.writedir() .. "missions/Huey/PersistentCampaign/save - blueUnits.lua"
scriptvaluesFile = lfs.writedir() .. "missions/Huey/PersistentCampaign/save - scriptValues.lua"
saveStatics.addValue({"patrolLift","numDeadEnemyGroups"},scriptvaluesFile)
saveStatics.addValue({"ctld","nextUnitId"},scriptvaluesFile)
saveStatics.addValue({"ctld","nextGroupId"},scriptvaluesFile)
saveStatics.addValue({"ctld","spawnedCratesBLUE"},scriptvaluesFile)
saveStatics.addValue({"Wrench","spawnedGroupsRoutes"},scriptvaluesFile)
saveStatics.start(staticFile,scriptvaluesFile)
]]
