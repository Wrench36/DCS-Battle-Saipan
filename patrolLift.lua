local myLog = mist.Logger:new('patrolLift')
--[[    reqrite freq handling and radio tranmission. will need to copy from template.
Made for specific mission of the same name. Could be used for others, but would have to be manually set up.

assert(loadfile(lfs.writedir() .. "Missions/Huey/PersistentCampaign/patrolLift.lua"))()

TODO
change pathfinder marker table to save them by name, add markremove to remove them from the list.
]]
if not Wrench then 
    trigger.action.outText("WrenchFunctions.lua Required for PatrolLift!!" , 10 , false)
    return false
end
if not Wrench.spawnedGroupsRoutes then
    Wrench.spawnedGroupsRoutes = {}
end


if not patrolLift then
    patrolLift = {}
end

patrolLift.debug = false

patrolLift.Commands = {}
patrolLift.maxEnemyGroups = 30
patrolLift.spawnedEnemyGroups = {}
if not patrolLift.numDeadEnemyGroups then
    patrolLift.numDeadEnemyGroups = 0
end
patrolLift.deadEnemyGroupNames = {}
--patrolLift.playAreaZones = {"play_area-1","play_area-2","play_area-3","play_area-4","play_area-5","play_area-6","play_area-7","play_area-8"}
patrolLift.playAreaZones = {}
patrolLift.excludededZones = {}
patrolLift.marknum = 1
patrolLift.assignedGroups = {}
patrolLift.wpDist = 1500 --1500
patrolLift.freq = 30
patrolLift.groupsInContact = {}
patrolLift.redPoints = 0
patrolLift.pointsPerAC = 4
patrolLift.AaPoints = 0
patrolLift.pointsPerManpads = 20
patrolLift.phonetic = {
    ['A'] = 'ALPHA',
    ['B'] = 'BRAVO',
    ['C'] = 'CHARLIE',
    ['D'] = 'DELTA',
    ['E'] = 'ECHO',
    ['F'] = 'FOXTROT',
    ['G'] = 'GOLF',
    ['H'] = 'HOTEL',
    ['J'] = 'JULIET',
    ['K'] = 'KILO',
    ['L'] = 'LIMA',
    ['M'] = 'MIKE',
    ['N'] = 'NOVEMBER',
    ['O'] = 'OSCAR',
    ['P'] = 'PAPA',
    ['Q'] = 'QUEBEC',
    ['R'] = 'ROMEO',
    ['S'] = 'SIERRA',
    ['T'] = 'TANGO',
    ['U'] = 'UNIFORM',
    ['V'] = 'VICTOR',
    ['W'] = 'WHISKEY',
    ['X'] = 'X-RAY',
    ['Y'] = 'YANKEE',
    ['Z'] = 'ZULU',
    
}
patrolLift.numSpawnedGrunts = 1

function string:split( inSplitPattern, outResults )
    if not outResults then
        outResults = { }
    end
    local theStart = 1
    local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
    while theSplitStart do
        table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
        theStart = theSplitEnd + 1
        theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
    end
    table.insert( outResults, string.sub( self, theStart ) )
    return outResults
end

function patrolLift.loop()
    myLog:msg("loop")
    local blueGroups = coalition.getGroups(2)
    patrolLift.scanForBluePatrols(blueGroups)
    patrolLift.clearDropZone()
    patrolLift.checkContact()
    patrolLift.checkDeadReds()
    if patrolLift.freq > 70 then
        trigger.action.outText("beacons are being reset to 30" , 10 , false)
        patrolLift.freq = 30
        if STTS then
            STTS.TextToSpeech("beacons are being reset to 30","116","AM","1.0","SRS",2,nil,-1,"male")
        end
    end
    myLog:msg("loop done")
end

function patrolLift.scanForBluePatrols(blueGroups)
    local unitNames = {}
    for i=1,#blueGroups do
        local thisGrp = blueGroups[i]
        if thisGrp then
            local name = Group.getName(thisGrp)
            local units = Group.getUnits(blueGroups[i])
            for j=1,#units do
                local unitName = units[j]:getName()
                table.insert(unitNames,unitName)
            end
        end
    end
    local zoneUnits = mist.getUnitsInZones(unitNames ,patrolLift.playAreaZones)
    local Groupnames = {}
    for i=1,#zoneUnits do
        local groupName = zoneUnits[i]:getGroup():getName()
        if not Groupnames[groupName] then
            Groupnames[groupName] = groupName
        end
    end
    for k,v in pairs(Groupnames) do
        if not patrolLift.assignedGroups[v] then
            if string.find(v,"pathfinder") then
                pathfinder.route2(v)
                patrolLift.assignedGroups[v] = v
            elseif string.find(v,"patrolExclude") then
            else
                local group = Group.getByName(v)
                patrolLift.patrolBlue(group)
                patrolLift.assignedGroups[v] = v
            end
        end
    end
end

function patrolLift.checkDeadReds()
    for k,v in pairs(patrolLift.spawnedEnemyGroups) do
        if mist.groupIsDead(k) and not patrolLift.deadEnemyGroupNames[k] then
            patrolLift.numDeadEnemyGroups = patrolLift.numDeadEnemyGroups + 1
            patrolLift.deadEnemyGroupNames[k] = v
        end
    end
end

function patrolLift.populate(num)
    myLog:msg("populate")
    if not num then
        num = patrolLift.maxEnemyGroups - patrolLift.numDeadEnemyGroups
    end
    for i=1, num do
        local rand = mist.random(1,#patrolLift.playAreaZones)
        local vec2 = patrolLift.findValidPointInZone(patrolLift.playAreaZones[rand])
        local height = land.getHeight(vec2)
        local vec3 = mist.utils.makeVec3(vec2 , height)
        local grpRoute = patrolLift.patrol(vec3)
        if patrolLift.debug then
            myLog:msg(grpRoute)
        end
        local vars = {
            groupName = "template_red",
            point = vec3,
            action = 'clone',
            route = grpRoute,
        }
        local spawnGroup = mist.teleportToPoint(vars)
        local name = spawnGroup["name"]
        if patrolLift.debug then
            myLog:msg(spawnGroup)
        end
        local spawnGroupClass = Group.getByName(name)
        patrolLift.spawnedEnemyGroups[name] = spawnGroupClass
    end
end

function patrolLift.isPointInZone(zoneName,point)
    Wrench.logIt(zoneName)
    local zone = trigger.misc.getZone(zoneName)
    local radius = zone.radius
    local pointDist = mist.utils.get2DDist(point, zone.point)
    if pointDist < radius then
        Wrench.logIt("The point is in "..zoneName)
        return true
    else
        return false
    end
end


function patrolLift.findValidPointInZone(zone)
    local pos =  mist.getRandomPointInZone(zone)
    local exclude = false
    for i=1,#patrolLift.excludededZones do
        if patrolLift.isPointInZone(patrolLift.excludededZones[i],pos) then
            exclude = true
        end
    end
    local valid = mist.isTerrainValid(pos, { [1] = "LAND", [2] = "ROAD", })
    if valid and not exclude then
        return pos
    else
        myLog:msg("finding alternate point")
        return patrolLift.findValidPointInZone(zone)
    end
end

function true50()
    local rand = math.random(1,2)
    if rand < 2 then
        return true
    else
        return false
    end
end

function patrolLift.patrol(pos)
    local points = {}
    for i=1,5 do
        points[i] = patrolLift.plusMinusDist(pos)
    end
    if patrolLift.debug then
        trigger.action.markToAll(patrolLift.marknum, "0", pos, false, "")
        patrolLift.marknum = patrolLift.marknum + 1
        for i=1,#points do
            trigger.action.markToAll(patrolLift.marknum, i, points[i], false, "")
            patrolLift.marknum = patrolLift.marknum + 1
        end
    end
    local route = {}
    for i=1,#points do
        route[i] = mist.ground.buildWP(points[i] , "Custom" ,40)
        route[i]["action"] = "Custom"
    end
    route[5]["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
            ["tasks"] = {
                [1] = {
                    ["number"] = 1,
                    ["auto"] = false,
                    ["id"] = "GoToWaypoint",
                    ["enabled"] = true,
                    ["params"] = {
                        ["nWaypointIndx"] = 1,
                        ["fromWaypointIndex"] = 4,
                    },
                },
            },
        },
    }
    return route
end

function patrolLift.patrolBlue(group)
    local name = group:getName()
    local Units = mist.makeUnitTable({"[g]" .. name})
    local pos = mist.getAvgPos(Units)
    local points = {}
    points[1] = pos
    for i=2,8 do
        table.insert(points,patrolLift.plusMinusDist(pos))
    end
    if patrolLift.debug then
        trigger.action.markToAll(patrolLift.marknum, name .. " 0", pos, false, "")
        patrolLift.marknum = patrolLift.marknum + 1
        for i=1,#points do
            trigger.action.markToAll(patrolLift.marknum, name .. " " .. i, points[i], false, "")
            patrolLift.marknum = patrolLift.marknum + 1
        end
    end
    local route = {}
    for i=1,#points do
        route[i] = mist.ground.buildWP(points[i] , "Custom" ,40)
        route[i]["action"] = "Custom"
    end
    
    route[#route] = patrolLift.addRouteToWp(route[#route],name,pos)
    
    if patrolLift.debug then
        myLog:msg(route)
    end
    mist.scheduleFunction(mist.goRoute, {group,route}, timer.getTime() + 1, 900, timer.getTime() + 10)
end


function patrolLift.addRouteToWp(wp,name,pos)
    local posString = string.format("{['x'] = %s, ['y'] = %s, ['z'] = %s}",pos['x'],pos['y'],pos['z'])
    local commandString = string.format("patrolLift.embRoute(%s,'%s')",posString,name)
    wp["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
            ["tasks"] = {
                [1] = {
                    ["number"] = 1,
                    ["auto"] = false,
                    ["id"] = "WrappedAction",
                    ["enabled"] = true,
                    ["params"] = {
                        ["action"] = {
                            ["id"] = "Script",
                            ["params"] = {
                                ["command"] = commandString,
                            },
                        },
                    },
                },
            },
        },
    }
    return wp
end

function patrolLift.addEmbarkToWp(wp,name)
    local pos = {['x'] = wp.x, ['y'] = wp.y, ['z'] = wp.z}
    local height = land.getHeight(pos)
    pos = mist.utils.makeVec3(pos,height)
    local posString = tostring("{ ['x'] = " .. pos["x"] .. "," .. "['y'] = " .. pos["y"] .. "," .. "['z'] = " .. pos["z"].. "}")
    local commandString = string.format("patrolLift.activateBeacon('%s',%s)",name,posString)
    
    wp["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
            ["tasks"] = {
                [1] = {
                    ["number"] = 1,
                    ["auto"] = false,
                    ["id"] = "WrappedAction",
                    ["enabled"] = true,
                    ["params"] = {
                        ["action"] = {
                            ["id"] = "Script",
                            ["params"] = {
                                ["command"] = commandString,
                            },
                        },
                    },
                },
                [2] = 
                {
                    ["enabled"] = true,
                    ["auto"] = false,
                    ["id"] = "EmbarkToTransport",
                    ["number"] = 2,
                    ["params"] =
                    {
                        ["y"] = wp["y"],
                        ["x"] = wp["x"],
                        ["zoneRadius"] = 200,
                    }, -- end of ["params"]
                },
            },
        },
    }
    return wp
end

function patrolLift.activateBeacon(gpName,pos,contact)
    myLog:msg("patrolLift.activateBeacon")
    local grp = Group.getByName(gpName)
    local con = grp:getController()
    local SetFrequency = { 
        id = 'SetFrequency', 
        params = { 
            frequency = patrolLift.freq * 1000000, 
            modulation = 1, 
        },
    }
    con:setCommand(SetFrequency)
    local TransmitMessage = { 
        id = 'TransmitMessage', 
        params = {
            duration = 5,
            --subtitle = subtitle,
            loop = true,
            file = 'ResKey_advancedFile_29',
        },
    }
    con:setCommand(TransmitMessage)
    
    if pos then
        local msg = ""
        
        if contact then
            msg = "A patrol has troops in contact at "
            local enemy = patrolLift.groupsInContact[gpName]['enemy']
            local enemypos = Unit.getPosition(enemy).p
            local smokepos = enemypos
            local xrand = math.random(-50,50)
            local zrand = math.random(-50,50)
            smokepos.x = enemypos.x + xrand
            smokepos.z = enemypos.z + zrand
            trigger.action.smoke(smokepos , 1)
        else
            msg = "A patrol is ready for pickup at "
            trigger.action.smoke(pos , 4)
        end
        local lat, lon, alt = coord.LOtoLL(pos)
        local mgrs = coord.LLtoMGRS(lat , lon )
        local mgrsString = string.format("%s %s %3.0f %3.0f",mgrs.UTMZone, mgrs.MGRSDigraph, mgrs.Easting/100-1, mgrs.Northing/100-1 )
        local outtextString = msg .. mgrsString .. " on " .. patrolLift.freq .. " FM"
        trigger.action.markToAll(patrolLift.marknum, outtextString, pos, false, "")
        patrolLift.marknum = patrolLift.marknum + 1
        
        if STTS then
            local utmZone = mgrs.UTMZone
            local utmNum = string.sub(utmZone,1,2)
            local utmLetter = string.sub(utmZone,string.len(utmZone),-1)
            local digraph = mgrs.MGRSDigraph
            local digraph1 = string.sub(digraph,1,1)
            local digraph2 = string.sub(digraph,2,-1)
            local easting = string.format("%3.0f",mgrs.Easting/100-1)
            local Northing = string.format("%3.0f",mgrs.Northing/100-1)
            utmLetter = patrolLift.phonetic[utmLetter]
            digraph1 = patrolLift.phonetic[digraph1]
            digraph2 = patrolLift.phonetic[digraph2]
            easting = easting:gsub(".", "%1 "):sub(1,-2)
            Northing = Northing:gsub(".", "%1 "):sub(1,-2)
            sttsMgrsString = string.format("%s%s ... %s%s ... %s ... %s",utmNum,utmLetter,digraph1,digraph2,easting,Northing)
            sstsString = string.format("%s%s ... on %s FM",msg,sttsMgrsString,patrolLift.freq)
            myLog:msg(sstsString)
            STTS.TextToSpeech(sstsString,"116","AM","1.0",gpName,2,nil,-1,"male")
        end
    end
    
    
    patrolLift.freq = patrolLift.freq + 1
end

function patrolLift.stopBeacon(gpName)
    myLog:msg("stop beacon for " .. gpName)
    grp = Group.getByName(gpName)
    local con = grp:getController()
    local SetFrequency = { 
        id = 'SetFrequency', 
        params = { 
            frequency = 29 * 1000000, 
            modulation = 1, 
        },
    }
    con:setCommand(SetFrequency)
    local stopTransmission = { 
        id = 'stopTransmission', 
        params = {
            
        },
    }
    con:setCommand(stopTransmission)
    return true
end

function patrolLift.plusMinusDist(pos)
    local wpDistMinus = patrolLift.wpDist / -1
    local pos2 = {}
    local randx = math.random(wpDistMinus,patrolLift.wpDist)
    local randz = math.random(wpDistMinus,patrolLift.wpDist)
    
    pos2.x = pos.x + randx
    pos2.z = pos.z + randz
    pos2.y = pos.y
    local valid = mist.isTerrainValid(pos2, { [1] = "LAND", [2] = "ROAD", })
    if valid then
        return pos2
    else
        myLog:msg("finding alternate point on route")
        return patrolLift.plusMinusDist(pos)
    end
end

function patrolLift.checkContact()
myLog:msg("patrolLift.checkContact")
    for k,v in pairs(patrolLift.assignedGroups) do
        if not patrolLift.groupsInContact[v] then
            local grpClass = Group.getByName(v)
            local con = grpClass:getController()
            local targets = con:getDetectedTargets()
            if targets[1] then
                local nameString = string.format("[g]%s",v)
                local fUnits = mist.makeUnitTable({nameString})
                local fPos = mist.getAvgPos(fUnits)
                local ePos = Unit.getPosition(targets[1]['object']).p
                local dist = mist.utils.get2DDist(fPos ,ePos)
                if dist < 700 then
                    patrolLift.groupsInContact[v] = {["friendly"] = grpClass, ['enemy'] = targets[1]['object']}
                    patrolLift.contactMessage(v)

                    -- route --
                    local enemy = patrolLift.groupsInContact[gpName]['enemy']
                    local enemypos = Unit.getPosition(enemy).p
                    local Units = mist.makeUnitTable({"[g]" .. v})
                    local pos = mist.getAvgPos(Units)
                    local points = {}
                    points[1] = pos
                    points[2] = enemypos
                    local route = {}
                    for i=1,#points do
                        route[i] = mist.ground.buildWP(points[i] , "Custom" ,40)
                        route[i]["action"] = "Custom"
                    end
                    mist.scheduleFunction(mist.goRoute, {group,route}, timer.getTime() + 1, 900, timer.getTime() + 10)
                    --end route --
                end
            end
        end
    end
    for k,v in pairs (patrolLift.groupsInContact) do
        local con = v["friendly"]:getController()
        local targets = con:getDetectedTargets()
        if not targets[1] then
            patrolLift.groupsInContact[k] = nil
            status, err = pcall(function()
                patrolLift.stopBeacon(k)
                patrolLift.patrolBlue(grpClass)
            end)
            if not status then 
                myLog:msg(err)
                trigger.action.outText(err , 10 , false)
            end
        end
    end
end

function patrolLift.contactMessage(grpName)
myLog:msg("patrolLift.contactMessage")
    local grpClass = Group.getByName(grpName)
    local route = {}
    local freq = patrolLift.freq
    local pos = {}
    local units = Group.getUnits(grpClass)
    for i=1,#units do
        if units[i]:isExist() then
            pos = units[i]:getPosition().p
        end
    end
    
    patrolLift.activateBeacon(grpName,pos,true)
end

function patrolLift.clearDropZone()
    local unitNames = {}
    local blueGroups = coalition.getGroups(2,2)
    for i=1,#blueGroups do
        --blueGroups[i] = blueGroups[i]:getName()
        local units = Group.getUnits(blueGroups[i])
        for j=1,#units do
            local unitName = units[j]:getName()
            table.insert(unitNames,unitName)
        end
    end
    local zoneUnits = mist.getUnitsInZones(unitNames ,{'dropZone'})
    for i=1,#zoneUnits do
        local znUnit = zoneUnits[i]
        znUnit:destroy()
    end
end

function patrolLift.clearPickZone()
    local unitNames = {}
    local blueGroups = coalition.getGroups(2,2)
    for i=1,#blueGroups do
        local name = blueGroups[i]:getName()
        if string.find(name,"patrolExclude") then
            do break end
        end
        local units = Group.getUnits(blueGroups[i])
        for j=1,#units do
            local unitName = units[j]:getName()
            table.insert(unitNames,unitName)
        end
    end
    local zoneUnits = mist.getUnitsInZones(unitNames ,{'pickzone3'})
    for i=1,#zoneUnits do
        local znUnit = zoneUnits[i]
        znUnit:destroy()
    end
end

function patrolLift.spawnGroupWithName(gp,taskDel)
   if not type(gp) == 'string' then
    gp = Group.getName(gp)
   end
   gpData = mist.utils.deepCopy(mist.getGroupData(gp, true))
   local name = string.gsub(gp,"name","")
   thisGrp = {}
    thisGrp.country = gpData.country
    thisGrp.category = gpData.category
    --thisGrp.route = mist.utils.deepCopy(gpData.route)
    thisGrp.hidden = false
    thisGrp.visible = true
    thisGrp.name = name .. "spawn" .. patrolLift.numSpawnedGrunts
    thisGrp["units"] = {}

    if thisGrp.route then
        for key,val in pairs(thisGrp["route"]) do
            local keyNum = tonumber(key)
            thisGrp["route"][keyNum] = val
            thisGrp["route"][key] = nil	
        end
    end

    for key,val in pairs(gpData.units) do
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
        --thisGrp["units"][keyNum]['name']  = thisGrp.name .. keyNum
        if ctld then
            ctld.nextUnitId = ctld.nextUnitId + 1
        end
    end

    if thisGrp["country"] then else
        thisGrp["country"] = thisGrp["units"][1]["country"]
    end
    if thisGrp.country then else
        myLog:msg(k .. " still has no country!")
    end

    --thisGrp.route = mist.utils.deepCopy(gpData.route)
    local spawnGroup = mist.dynAdd(thisGrp)
    spawnedGroup = mist.dynAdd(thisGrp)
    mist.scheduleFunction(mist.goRoute, {thisGrp.name, gpData.route}, timer.getTime() + taskDel)
    
    patrolLift.numSpawnedGrunts = patrolLift.numSpawnedGrunts + 1
    return spawnedGroup
end

function patrolLift.spawnGrunts()
    --[[
    local spawnGroup = mist.cloneGroup("chaulk-1" , 1)
    spawnGroup = mist.cloneGroup("chaulk-2" , 2)
    spawnGroup =  mist.cloneGroup("chaulk-3" , 3)
    spawnGroup =  mist.cloneGroup("chaulk-4" , 4)
    spawnGroup =  mist.cloneGroup("pathfinder-1" , 4)
    spawnGroup =  mist.cloneGroup("pathfinder-2" , 4)
    spawnGroup =  mist.cloneGroup("pathfinder-3" , 4)
    ]]
    
    spawnGroup = patrolLift.spawnGroupWithName("chaulk-1",3)
    spawnGroup = patrolLift.spawnGroupWithName("chaulk-2",4)
    spawnGroup = patrolLift.spawnGroupWithName("chaulk-3",5)
    spawnGroup = patrolLift.spawnGroupWithName("chaulk-4",6)
    spawnGroup = patrolLift.spawnGroupWithName("pathfinder-1",3.5)
    spawnGroup = patrolLift.spawnGroupWithName("pathfinder-2",4.5)
    spawnGroup = patrolLift.spawnGroupWithName("pathfinder-3",5.5)
    
end

--S_EVENT_KILL = {id = 28,time = Time,initiator = Unit,weapon = Weapon,target = Unit,weapon_name = string,}
patrolLift.dead = {}
function patrolLift.dead:onEvent(event)
    if event.id == world.event.S_EVENT_UNIT_LOST then
        return true
    end
    if event.id == world.event.S_EVENT_KILL then
        myLog:msg("event dead")
        local status, err = pcall(function()
            patrolLift.deadHandler(event)
        end)
        if not status then 
            myLog:msg(err)
            trigger.action.outText(err , 10 , false)
            return true
        end
        myLog:msg("event done.")
    end
    return true
end
world.addEventHandler(patrolLift.dead)

function patrolLift.deadHandler(event)
    local deadU = event.target
    if not deadU:getCategory() == 1 then
        return false
    end
    local deadC = ""
    status, error = pcall(function()
        deadC = deadU:getCoalition()
        local points = 1
        if deadC == 2 then -- deadC == 2 dead blue unit
            if Unit.hasAttribute(deadU , "Planes") or Unit.hasAttribute(deadU , "Helicopters") then
                points = 1 * patrolLift.pointsPerAC
            end
            patrolLift.redPoints = patrolLift.redPoints + points
            patrolLift.spawnFromPoints()
        else -- dead red unit
            local killer = event.initiator
            if Unit.hasAttribute(killer , "Planes") or Unit.hasAttribute(killer , "Helicopters") then
                patrolLift.AaPoints = patrolLift.AaPoints + 1
                patrolLift.spawnFromPoints()

            end
        end
    end)
    if not status then
        return false
    end

end

function patrolLift.spawnFromPoints()
    if patrolLift.redPoints > 7 then
        patrolLift.redPoints = patrolLift.redPoints - 8
        patrolLift.numDeadEnemyGroups = patrolLift.numDeadEnemyGroups - 1
        local rand = math.random(1,3)
        if rand == 1 then
            myLog:msg("adding normal group")
            patrolLift.populate(1)
        elseif rand == 2 then
            myLog:msg("adding mortar_red")
            mist.cloneInZone("mortar_red", patrolLift.playAreaZones)
        elseif rand == 3 then
            myLog:msg("adding rpg")
            mist.cloneInZone("template_red_rpg", patrolLift.playAreaZones)
        end
    end
    if patrolLift.AaPoints >= patrolLift.pointsPerManpads then
        local manpad = true50
        if manpad then
            myLog:msg("adding manpad_red")
            mist.cloneInZone("manpad_red", patrolLift.playAreaZones)
        else
            myLog:msg("adding dshk")
            mist.cloneInZone("DsHK", patrolLift.playAreaZones)
        end
        patrolLift.AaPoints = patrolLift.AaPoints - patrolLift.pointsPerManpads
    end
end

function patrolLift.getPlayAreaZones()
    for i=1,#_G.env.mission.triggers.zones do
        local zone = _G.env.mission.triggers.zones[i]
        if string.find(zone['name'],"play_area") then
            table.insert(patrolLift.playAreaZones,zone['name'])
        end
    end
end

function patrolLift.getExcludedZones()
    for i=1,#_G.env.mission.triggers.zones do
        local zone = _G.env.mission.triggers.zones[i]
        if string.find(zone['name'],"FSB") or string.find(zone['name'],"pick") then
            table.insert(patrolLift.excludededZones,zone['name'])
        end
    end
end

function patrolLift.init()
    patrolLift.getPlayAreaZones()
    patrolLift.getExcludedZones()
    patrolLift.populate()
    patrolLift.loopFunc = mist.scheduleFunction(patrolLift.loop, {}, timer.getTime() + 5, 15, 1/0)
    patrolLift.spawnGrunts()
    missionCommands.addCommand("Spawn Grunts", nil, function()
        patrolLift.spawnGrunts()
    end, nil)
    missionCommands.addCommand("clear pickup zone", nil, function()
        patrolLift.clearPickZone()
    end, nil)
    missionCommands.addCommand("clear Pathfinder Zones (on join)", nil, function()
        pathfinder.iterateZones()
    end, nil)
    trigger.action.outText("patrolLift init done." , 10 , false)
    if STTS then
        STTS.TextToSpeech("Pick up troops from the pier and drop them off on Saipan. See the briefing for more info.","116","AM","1.0","SRS",2,nil,-1,"male")
    end
end
function getFmThing()
    groupData = mist.getGroupData("fm-test", true)
    myLog:msg(groupData)
end

--S_EVENT_MARK REMOVE = { id = S_EVENT_MARK_REMOVE, idx = idxMark(IDMark), time = Time, initiator = Unit, coalition = -1 (or RED/BLUE), groupID = -1 (or ID), text = markText, pos = vec3}
patrolLift.markRemove = {}
function patrolLift.markRemove:onEvent(event)
    if event.id and event.id == 27 then
        myLog:msg("event mark removed")
        local commandString = event.text
        local commandStrings = commandString:split(",")
        if string.find(commandString, 'extract') then
            if commandStrings[2] then
                status, error = pcall(function()
                    patrolLift.Commands.embGroup(event.pos,commandStrings[2])
                end)
            else
                status, error = pcall(function()
                    patrolLift.Commands.emb(event.pos)
                end)
            end
        end
        if string.find(commandString,"patrol") then
            status, error = pcall(function()
                patrolLift.Commands.patrolGroup(commandStrings[2])
            end)
        end
        if string.find(commandString,"beaconoff") then
            status, error = pcall(function()
                patrolLift.stopBeacon(commandStrings[2])
            end)
        end
        if string.find(commandString,"beaconon") then
            status, error = pcall(function()
                patrolLift.activateBeacon(commandStrings[2])
                if not commandStrings[3] then commandStrings[3] = "" end
                commandStrings[3] = commandStrings[3] .. patrolLift.freq * 1000000 .. " FM"
            end)
        end
        
        if error then
            local text = error or "unknown error"
            myLog:msg(text)
        end
        if status then
            commandStrings = commandString:split(",")
            trigger.action.outText("done!", 10 , false)
        end
    end
end

world.addEventHandler(patrolLift.markRemove)

function patrolLift.Commands.emb(pos)
    local blueGroups = coalition.getGroups(2,2)
    local dists = {}
    local pos2 = {}
    for i=1,#blueGroups do
        local name = blueGroups[i]:getName()
        local units = blueGroups[i]:getUnits()
        for j=1,#units do
            if units[j]:getPosition().p then pos2 = units[j]:getPosition().p end
        end
        dists[name] = mist.utils.get3DDist(pos ,pos2)
    end
    local closestName = Wrench.returnSmallest(dists)
    local gC = Group.getByName(closestName)
    patrolLift.embRoute(pos,gC)
    return true
end

function patrolLift.Commands.embGroup(pos,groupName)
    local gC = Group.getByName(groupName)
    patrolLift.embRoute(pos,gC)
    return true
end

function patrolLift.embRoute(pos,gc)
    if type(gc) == 'string' then
        gc = Group.getByName(gc)
    end
    local route = {}
    local name = gc:getName()
    route[1] = mist.ground.buildWP(pos , "Custom" ,40)
    route[1]["action"] = "Custom"
    
    route[2] = mist.ground.buildWP(pos , "Custom" ,40)
    route[2]["action"] = "Custom"
    route[2]["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
            ["tasks"] = {
                [1] = 
                {
                    ["enabled"] = true,
                    ["auto"] = false,
                    ["id"] = "EmbarkToTransport",
                    ["number"] = 1,
                    ["params"] = 
                    {
                        ["y"] = route[1]["y"],
                        ["x"] = route[1]["x"],
                        ["zoneRadius"] = 200,
                    }, -- end of ["params"]
                },
            },
        },
    }
    patrolLift.activateBeacon(name,pos,false)
    mist.scheduleFunction(mist.goRoute, {gc,route}, timer.getTime() + 1, 900, timer.getTime() + 10)
end

function patrolLift.Commands.patrolGroup(groupName)
    local gC = Group.getByName(groupName)
    patrolLift.patrolBlue(gC)
end

-- S_EVENT_MARK CHANGE = {id = 26, idx = number markId, time = Abs time, initiator = Unit, coalition = number coalitionId, groupID = number groupId, text = string markText, pos = vec3}
patrolLift.markAdd = {}
function patrolLift.markAdd:onEvent(event)
    if event.id and event.id == 26 then
        myLog:msg("event mark add")
        trigger.action.outText("MARK CHANGED" , 10 , false)
        local commandString = event.text
        if string.find(commandString, 'pathfinder') then
            marker = {}
            marker['idx'] = event.idx
            marker['pos'] = event.pos
            marker['text'] = event.text
            table.insert(pathfinder.markers,marker)
        end
    end
end
world.addEventHandler(patrolLift.markAdd)

trigger.action.outText("patrolLift loaded." , 10 , false)
patrolLift.init()


-----------------------pathfinder------------------------
if not pathfinder then pathfinder = {} end
pathfinder.assignedGroups = {}
pathfinder.debug = false
pathfinder.marknum = 1
pathfinder.markers = {}
if not pathfinder.zones then pathfinder.zones = {} end
function pathfinder.add_zone(name, x, y, radius)
    if trigger.misc.getZone(name) then return trigger.misc.getZone(name) end
    return trigger.misc.addZone
    {
        ["name"] = name,
        ["y"] = y,
        ["x"] = x,
        ["radius"] = radius,
        ["properties"] =
        {
            [1] =
            {
                ["key"] = name,
                ["value"] = "",
            },
        },
        ["color"] = {0,0,0,1},
        ["hidden"] = false,
    }
end
function pathfinder.removeTrees(unitNameOrPos,radius)
    local num = 5
    local dirEach = 2*math.pi/num
    local points = {}
    if type(unitNameOrPos) == "string" then
        unitNameOrPos = Unit.getByName(unitNameOrPos):getPosition().p
    end
    for i=1,num do
        local rand = math.random(10,75)
        local pos1 =  {
            x = ((math.cos(i*dirEach) * rand) + unitNameOrPos.x),
            z = ((math.sin(i*dirEach) * rand) + unitNameOrPos.z),
            y = 0
        }
        pos1.y = land.getHeight({['x']=pos1.x,['y']=pos1.z})
        table.insert(points,pos1)
    end
    if pathfinder.debug then
        for i=1,#points do
            trigger.action.markToAll(pathfinder.marknum, i, points[i], false, "")
            pathfinder.marknum = pathfinder.marknum + 1
        end
    end
    for i=1,#points do
        mist.scheduleFunction(trigger.action.explosion, {points[i],1}, timer.getTime() + 1 + (i/10))
        --trigger.action.explosion(points[i],1)
    end

    local new_zone = pathfinder.add_zone("pathfinder"..#pathfinder.zones+1, unitNameOrPos.x, unitNameOrPos.z, radius)
    local addZone = trigger.misc.getZone(new_zone.name)
    for k,v in pairs(addZone) do
        new_zone[k] = v
    end
    table.insert(pathfinder.zones,new_zone)
    local command = [[a_remove_scene_objects(]] .. new_zone['zoneId'] .. [[, 1)]]
    --net.dostring_in('mission',command)
    mist.scheduleFunction(net.dostring_in, {'mission',command}, timer.getTime() + 1.4)
end

function pathfinder.iterateZones()
    for k,v in pairs(pathfinder.zones) do
        local zoneExists = false
        for j=1, #_G.env.mission.triggers.zones do
            local zone = _G.env.mission.triggers.zones[j]
            if string.find(zone.zoneId,v.zoneId) then
                zoneExists = true
            end
        end
        if not zoneExists then
           local new_zone = pathfinder.add_zone(v.name,v.point.x,v.point.z,v.radius)
           local addZone = trigger.misc.getZone(new_zone.name)
            for k,v in pairs(addZone) do
                new_zone[k] = v
            end
           pathfinder.zones[k] = new_zone
        end
    end
    for k,v in pairs(pathfinder.zones) do
        local command = [[a_remove_scene_objects(]] .. v['zoneId'] .. [[, 1)]]
        net.dostring_in('mission',command)
    end
end

function pathfinder.route(group)
    if type(group) == "string" then
        group = Group.getByName(group)
    end
    local name = group:getName()
    local lead = group:getUnit(1)
    pos = lead:getPosition().p
    local points = {}
    points[1] = pos
    local numWp = 3
    local dirEach = 2*math.pi/numWp
    
    for i=1,numWp do
        local pos1 =  {
            x = ((math.cos(i*dirEach) * 300) + pos.x),
            z = ((math.sin(i*dirEach) * 300) + pos.z),
            y = 0
        }
        table.insert(points,pos1)
    end
    local safePos = {}
    safePos.x = pos.x + 500
    safePos.y = pos.y
    safePos.z = pos.z
    table.insert(points,safePos)
    table.insert(points,pos)
    
    if pathfinder.debug then
        trigger.action.markToAll(pathfinder.marknum, "0", pos, false, "")
        pathfinder.marknum = pathfinder.marknum + 1
        for i=1,#points do
            trigger.action.markToAll(pathfinder.marknum, i, points[i], false, "")
            pathfinder.marknum = pathfinder.marknum + 1
        end
    end
    local route = {}
    for i=1,#points do
        route[i] = mist.ground.buildWP(points[i] , "Custom" ,40)
        route[i]["action"] = "Custom"
        route[i]['type'] = "Fly Over Point"
    end
    local posString = string.format("{['x'] = %s, ['y'] = %s, ['z'] = %s}",pos['x'],pos['y'],pos['z'])
    --local commandString = string.format("pathfinder.removeTrees(%s,'%s')",posString,"200")
    commandString = string.format("local pos = %s;mist.scheduleFunction(pathfinder.removeTrees, {pos, %s}, timer.getTime() + 30, 900, timer.getTime() + 70)",posString,"50")
   -- commandString = commandString .. ';mist.scheduleFunction(STTS.TextToSpeech, {"FIRE IN THE HOLE!","116","AM","1.0","SRS",2,nil,-1,"male"}, timer.getTime() + 20, 900, timer.getTime() + 30)'
    route[#route-1]["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
            ["tasks"] = {
                [1] = {
                    ["number"] = 1,
                    ["auto"] = false,
                    ["id"] = "WrappedAction",
                    ["enabled"] = true,
                    ["params"] = {
                        ["action"] = {
                            ["id"] = "Script",
                            ["params"] = {
                                ["command"] = commandString,
                            },
                        },
                    },
                },
            },
        },
    }
    route[#route] = patrolLift.addEmbarkToWp(route[#route],name)
    mist.scheduleFunction(mist.goRoute, {group,route}, timer.getTime() + 1, 900, timer.getTime() + 10)
    if STTS then
        STTS.TextToSpeech("PATHFINDER SETTING CHARGES!","116","AM","1.0","SRS",2,nil,-1,"male")
    end
    return route
end

function pathfinder.route2(group)
    if type(group) == "string" then
        group = Group.getByName(group)
    end
    local name = group:getName()
    local lead = group:getUnit(1)
    pos = lead:getPosition().p

    wpPos = false
    nearest = {}
    nearestDist = 1000
    for k,v in pairs (pathfinder.markers) do
        local markerPos = v['pos']
        local dist = mist.utils.get2DDist(pos, markerPos)
        if dist < nearestDist then
            nearest = v
            wpPos = v['pos']
        end
    end

    local points = {}
    points[1] = pos
    lastPos = points[1]
    if wpPos then
        points[2] = wpPos
        lastPos = wpPos
    end

    local numWp = 3
    local dirEach = 2*math.pi/numWp

    for i=1,numWp do
        local pos1 =  {
            x = ((math.cos(i*dirEach) * 300) + lastPos.x),
            z = ((math.sin(i*dirEach) * 300) + lastPos.z),
            y = 0
        }
        table.insert(points,pos1)
    end
    local safePos = {}
    safePos.x = lastPos.x + 500
    safePos.y = lastPos.y
    safePos.z = lastPos.z
    table.insert(points,safePos)
    table.insert(points,lastPos)

    if pathfinder.debug then
        trigger.action.markToAll(pathfinder.marknum, "0", lastPos, false, "")
        pathfinder.marknum = pathfinder.marknum + 1
        for i=1,#points do
            trigger.action.markToAll(pathfinder.marknum, i, points[i], false, "")
            pathfinder.marknum = pathfinder.marknum + 1
        end
    end
    local route = {}
    for i=1,#points do
        route[i] = mist.ground.buildWP(points[i] , "Custom" ,40)
        route[i]["action"] = "Custom"
        route[i]['type'] = "Fly Over Point"
    end
    local posString = string.format("{['x'] = %s, ['y'] = %s, ['z'] = %s}",lastPos['x'],lastPos['y'],lastPos['z'])
    commandString = string.format("local lastPos = %s;mist.scheduleFunction(pathfinder.removeTrees, {lastPos, %s}, timer.getTime() + 30, 900, timer.getTime() + 70)",posString,"50")
    route[#route-1]["task"] = {
        ["id"] = "ComboTask",
        ["params"] = {
            ["tasks"] = {
                [1] = {
                    ["number"] = 1,
                    ["auto"] = false,
                    ["id"] = "WrappedAction",
                    ["enabled"] = true,
                    ["params"] = {
                        ["action"] = {
                            ["id"] = "Script",
                            ["params"] = {
                                ["command"] = commandString,
                            },
                        },
                    },
                },
            },
        },
    }
    route[#route] = patrolLift.addEmbarkToWp(route[#route],name)
    mist.scheduleFunction(mist.goRoute, {group,route}, timer.getTime() + 1, 900, timer.getTime() + 10)
    if STTS then
        STTS.TextToSpeech("PATHFINDER SETTING CHARGES!","116","AM","1.0","SRS",2,nil,-1,"male")
    end
    return route
end


function pathfinder.init()
    pathfinder.iterateZones()
end
pathfinder.init()
