--assert(loadfile(lfs.writedir() .. "Missions/Huey/PersistentCampaign/buildAWall.lua"))()
local myLog = mist.Logger:new('buildAWall')
buildWall = {}
buildWall.len = 3
buildWall.type = ""
buildWall.numBuilt = 0
function buildWall.build(groupName)
    myLog:msg("buildWall.build")
    local points = {}
    local pointsPlus = {}
    local route = mist.getGroupRoute(groupName, false)
    for i=1,#route do
        points[i] = {}
        points[i]["x"] = route[i]["x"]
        points[i]["y"] = route[i]["y"]       
    end
    for i=1,#points do
        if points[i+1] then
            local numBetween = findNumBetween(points[i],points[i+1])
            points[i]["heading"] = mist.utils.getHeadingPoints(points[i] ,points[i+1])
            local lastPos = points[i]
            for j=1,numBetween do
                if points[i]["heading"] then
                    local nextPos = findNextPos(lastPos,points[i]["heading"])
                    nextPos["heading"] = points[i]["heading"]
                    table.insert(pointsPlus,nextPos)
                    lastPos = nextPos
                end
            end
        end
    end

    for i=1,#pointsPlus do
            --points[i]["heading"] = mist.utils.getHeadingPoints(points[i] ,points[i+1] , true)
            local staticObj = {
                ["canCargo"] = false,
                ["hidden"] = true,
                ["heading"] = pointsPlus[i]["heading"],
                ["type"] = "f_bar_cargo",
                ["name"] = "Building " .. buildWall.numBuilt,
                ["y"] = pointsPlus[i]["y"],
                ["x"] = pointsPlus[i]["x"],
                ["dead"] = false,
            }
            
            coalition.addStaticObject(country.id.USA, staticObj)
            buildWall.numBuilt = buildWall.numBuilt + 1
        end
end

function findNumBetween(pos1,pos2)
    local dist = mist.utils.get2DDist(pos1, pos2)
    local num = math.floor(dist / buildWall.len)
    return num
end

function findNextPos(pos,dir)
    local pos2 = {x = ((math.cos(dir) * buildWall.len) + pos.x), y = ((math.sin(dir) * buildWall.len) + pos.y)}
    return pos2
end

function buildWall.getTemplate(objectName)
    local obj = StaticObject.getByName(objectName)
    local desc = obj:getDesc()
    myLog:msg(desc)
    
end

function buildWall.init()
    buildWall.getTemplate("Static Container 20ft-1-1")
    buildWall.build("wall")
end

--buildWall.init()
