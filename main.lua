require "grid"
HiScore = require 'hiscore'

-- GFX Globals
local instructions = "Click to collect and lay bombs. Rid this earth of its filth."
local gSquareW = 32
local gFullColor = { 1.0, 1.0, 1.0, 1.0 }
local gCellBombColorExploding = { 0.8, 0.4, 0.15, 1.0 }

--------------------
-- Game Constants
--------------------
local gGridSize = 16
local gGameStarted = false
local gGameOver = false
local gBombDurUntilExplode = 0.17
local gBombExplosionDur = 0.28
local gDurUntilStuffVanquished = gBombExplosionDur

-- Phases + Upgrades
local gCurrPhase = 1
local gTrashNeededToLevelUp = 128
local gNumAutobombsPerRound = 0
local gDurBetweenAutobombRounds = 5 -- seconds
local gTimeSinceLastRoundOfAutobombs = 0 -- seconds
MAX_NUM_AUTOBOMBS = 1
TRASH_NEEDED_TO_LVL_UP_FACTOR = 1.73 -- how much trash each level is vs previous

-- num squares bomb will explode on each axis,
-- including the square on which it is laid
local gCurrBombSpread = 3 --gGridSize * 2 + 1 -- odd numbers only
local gChainReactionFactor = 4 -- recursive depth along each neighbor exploded
local gCurrBombSupply = 0

local gMousehoverCellX = 0
local gMousehoverCellY = 0

local gBombToCollectSpawnProbability = 0.04 -- probability of a bomb spawning adjacent rather than trash

local gTimeSinceLastDifficultyIncrease = 0
local gDurOfEachDifficultyLvl = 1 -- interval after which it gets a little harder
local gTimesDifficultyIncreased = 0

local gTimeSinceLastTrashNewClusterSpawn = 0
local gTimeSinceLastAdjacentSpawn = 0

local gTrashCleanedCount = 0

local gTotalElapsedTime = 0
local gElapsedTimeCurrGame = 0

-- torture people
TIME_OF_ENVIRONMENT = 45 -- seconds in

-- Use a square grid of tables, each table has a type "t".
-- Each type has unique table data associated with it
-- Types:
-- "-" is empty space
-- "X" is trash
-- "B" is a bomb
G = grid.Grid(gGridSize, gGridSize, { t = "-" })

gLitBombs = {}
gStuff = {} -- a stuff item is either a Trash or BombToCollect

INITIAL_NEW_SPREAD_FACTOR = 0.02
INITIAL_ADJACENT_SPREAD_FACTOR = 0.5

-- todo: set these just right
gAdjacentSpreadFactorMax = 10.0
gNewSpreadFactorMax = 0.5

function love.load()
  math.randomseed(os.time())

  HiScore:load()

  -- font
  gTheFont = love.graphics.newFont("8bitwonder.TTF", 18)

  -- images
  gImgTitleScreen1 = love.graphics.newImage("title_screen_1.png")
  gImgTitleScreen2 = love.graphics.newImage("title_screen_2.png")
  gImgCurrTitleScreen = gImgTitleScreen1
  gImgFloor = love.graphics.newImage("sand.png")
  gImgTrash = love.graphics.newImage("trash.png")
  gImgBombToCollect = love.graphics.newImage("bomb_to_collect.png")
  gImgBombLit3 = love.graphics.newImage("bomb_lit_3.png")
  gImgBombLit2 = love.graphics.newImage("bomb_lit_2.png")
  gImgBombLit1 = love.graphics.newImage("bomb_lit_1.png")
  gImgTrashExplode1 = love.graphics.newImage("trash_explode_1.png")
  gImgTrashExplode2 = love.graphics.newImage("trash_explode_2.png")
  gImgTrashExplode3 = love.graphics.newImage("trash_explode_3.png")
  gImgTrashExplode4 = love.graphics.newImage("trash_explode_4.png")
  gImgBombExplode1 = love.graphics.newImage("bomb_explode_1.png")
  gImgBombExplode2 = love.graphics.newImage("bomb_explode_2.png")
  gImgBombExplode3 = love.graphics.newImage("bomb_explode_3.png")
  gImgBombExplode4 = love.graphics.newImage("bomb_explode_4.png")

  -- sounds
  gSndCollect = love.audio.newSource("collect.mp3", "static")
  gSndExplode = love.audio.newSource("explode.mp3", "static")
  gSndLayBomb = love.audio.newSource("lay_bomb.mp3", "static")
  gSndTrashSpawn = love.audio.newSource("trash_spawn.mp3", "static")
  gSndTrashSimulator = love.audio.newSource("trash_simulator.mp3", "static")
  gSndTheEnvironment = love.audio.newSource("the_environment.mp3", "static")
  gSndLevelUp = love.audio.newSource("level_up.mp3", "static")
  gSndTrashSpawn:setVolume(0.03)
  gSndLayBomb:setVolume(0.5)
  gSndCollect:setVolume(0.7)
  gSndTrashSimulator:play()
end

function startGame()
  gGridSize = 16
  gCurrPhase = 1
  gCurrBombSpread = 3
  gNumAutobombsPerRound = 0
  gTrashNeededToLevelUp = 128
  gNewTrashSpreadFactor = INITIAL_NEW_SPREAD_FACTOR
  gAdjacentTrashSpreadFactor = INITIAL_ADJACENT_SPREAD_FACTOR
  gTrashCleanedCount = 0
  gCurrBombSupply = 0
  gElapsedTimeCurrGame = 0
  gBombToCollectSpawnProbability = 0.04

  gAdjacentSpreadFactorMax = 10.0
  gNewSpreadFactorMax = 0.5

  -- set up grid data structure
  fillGridWithEmptySpots()

  -- start with 9 bombs in center
  for i = 7, 9 do
    for j = 7, 9 do
      spawnBombToCollect(i,j)
    end
  end

  -- fill the perimeter
  for i = 1, gGridSize do spawnTrash(1, i) end
  for i = 1, gGridSize do spawnTrash(i, 1) end
  for i = 1, gGridSize do spawnTrash(gGridSize, i) end
  for i = 1, gGridSize do spawnTrash(i, gGridSize) end

  -- spawn some random "tendrils" from 1 in from perimeter
  local penultimatePerimSpawnChance = 0.4
  for i = 2, gGridSize - 1 do
    if math.random() < penultimatePerimSpawnChance then
      spawnTrash(2, i)
    end
  end
  for i = 2, gGridSize - 1 do
    if math.random() < penultimatePerimSpawnChance then
      spawnTrash(i, 2)
    end
  end
  for i = 2, gGridSize - 1 do
    if math.random() < penultimatePerimSpawnChance then
      spawnTrash(gGridSize - 1, i)
    end
  end
  for i = 2, gGridSize - 1 do
    if math.random() < penultimatePerimSpawnChance then
      spawnTrash(i, gGridSize - 1)
    end
  end

  -- sound
  if gSndTrashSimulator:isPlaying() then
    gSndTrashSimulator:stop()
  end

  gGameStarted = true
end

-- gets all spaces neighboring spaces where there is currently trash
function getAdjacentEmptySpaces()
  local adjacentEmptySpaces = {}
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "X" and not cell_data.hit then
        for xn = -1, 1 do
          for yn = -1, 1 do
            if xn == 0 or yn == 0 then -- spread to manhattan spots only
              local cand_x = x + xn
              local cand_y = y + yn
              if cand_x == 0 and cand_y == 0 then
                -- ignore original block!
              elseif G:is_valid(cand_x, cand_y) then
                local cell = G:get_cell(cand_x, cand_y)
                if cell.t == "-"  or cell_data.t == "BC" then
                  adjacentEmptySpaces[#adjacentEmptySpaces + 1] = { xpos = cand_x, ypos = cand_y }
                end
              end
            end
          end
        end
      end
    end
  end
  return adjacentEmptySpaces
end

function getAllEmptySpaces()
  local allEmptySpaces = {}
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" or cell_data.t == "BC" then
        allEmptySpaces[#allEmptySpaces + 1] = { xpos = x, ypos = y }
      end
    end
  end
  return allEmptySpaces
end

function handleSpawning(dt)
  -- get all spaces neighboring spaces where there is currently trash
  local adjacentEmptySpaces = getAdjacentEmptySpaces()

  -- spawn trash or bombsToCollect randomly near existing trash
  if math.random() < (gAdjacentTrashSpreadFactor * gTimeSinceLastAdjacentSpawn) then
    local spawnSpot = adjacentEmptySpaces[math.random(#adjacentEmptySpaces)]
    if spawnSpot ~= nil then

      if math.random() < gBombToCollectSpawnProbability then
        spawnBombToCollect(spawnSpot.xpos, spawnSpot.ypos)
      else
        spawnTrash(spawnSpot.xpos, spawnSpot.ypos)
      end

      gTimeSinceLastAdjacentSpawn = 0
    else
      gTimeSinceLastAdjacentSpawn = gTimeSinceLastAdjacentSpawn + dt
    end
  else
    gTimeSinceLastAdjacentSpawn = gTimeSinceLastAdjacentSpawn + dt
  end

  -- just generate all spaces them every frame right now
  -- can optimize later by doing just when state changes
  local allEmptySpaces = getAllEmptySpaces()

  -- find empty spaces near centers of walls along perimeter
  local emptyCentralPerimeterSpaces = {}
  for k,v in pairs(allEmptySpaces) do
    local leftDenom = 2.66666
    local rightDenom = 1.5
    -- left/right walls
    if v.xpos == 1 or v.xpos == gGridSize then
      if v.ypos > math.floor(gGridSize/leftDenom) and v.ypos < math.floor(gGridSize/rightDenom) then
        emptyCentralPerimeterSpaces[#emptyCentralPerimeterSpaces + 1] = { xpos = v.xpos, ypos = v.ypos }
      end
    end

    -- top/bottom walls
    if v.ypos == 1 or v.ypos == gGridSize then
      if v.xpos > math.floor(gGridSize/leftDenom) and v.xpos < math.floor(gGridSize/rightDenom) then
        emptyCentralPerimeterSpaces[#emptyCentralPerimeterSpaces + 1] = { xpos = v.xpos, ypos = v.ypos }
      end
    end
  end

  -- rarely, spawn new trash in spots not adjacent to existing trash
  -- and also only along central areas of the grid's perimeter
  if math.random() < (gNewTrashSpreadFactor * gTimeSinceLastTrashNewClusterSpawn) then
    local spawnSpot = emptyCentralPerimeterSpaces[math.random(#emptyCentralPerimeterSpaces)]
    if spawnSpot ~= nil then
      spawnTrash(spawnSpot.xpos, spawnSpot.ypos)
      gTimeSinceLastTrashNewClusterSpawn = 0
    else
      gTimeSinceLastTrashNewClusterSpawn = gTimeSinceLastTrashNewClusterSpawn + dt
    end
  else
    gTimeSinceLastTrashNewClusterSpawn = gTimeSinceLastTrashNewClusterSpawn + dt
  end

  -- spawn autobombs
  if gTimeSinceLastRoundOfAutobombs > gDurBetweenAutobombRounds and gNumAutobombsPerRound > 0 then
    for i = 1, gNumAutobombsPerRound do
      -- re-query adjacent empty spots in case stuff spawned there already
      adjacentEmptySpaces = getAdjacentEmptySpaces()
      local spawnSpot = adjacentEmptySpaces[math.random(#adjacentEmptySpaces)]
      if spawnSpot ~= nil then
          spawnLitBomb(spawnSpot.xpos, spawnSpot.ypos)
      end
    end

    gTimeSinceLastRoundOfAutobombs = 0
  else
    gTimeSinceLastRoundOfAutobombs = gTimeSinceLastRoundOfAutobombs + dt
  end

  -- make it a little harder / different over time
  -- adjacent rises, new spawn slows
  if (gTimeSinceLastDifficultyIncrease > gDurOfEachDifficultyLvl) then
    gNewTrashSpreadFactor = gNewTrashSpreadFactor + (gNewTrashSpreadFactor / 32)

    if gNewTrashSpreadFactor > gNewSpreadFactorMax then
      gNewTrashSpreadFactor = gNewSpreadFactorMax
    end

    gAdjacentTrashSpreadFactor = gAdjacentTrashSpreadFactor + (gAdjacentTrashSpreadFactor / 8)

    if gAdjacentTrashSpreadFactor > gAdjacentSpreadFactorMax then
      gAdjacentTrashSpreadFactor = gAdjacentSpreadFactorMax
    end

    gTimeSinceLastDifficultyIncrease = 0
    gTimesDifficultyIncreased = gTimesDifficultyIncreased + 1
  else
    gTimeSinceLastDifficultyIncrease = gTimeSinceLastDifficultyIncrease + dt
  end
end

function love.update(dt)
  if not gGameStarted then
    updateTitleScreen(dt)
  else
    updateGame(dt)
  end
  gTotalElapsedTime = gTotalElapsedTime + dt
end

function updateTitleScreen(dt)
  if (math.floor(gTotalElapsedTime * 2) % 2 == 0) then
    gImgCurrTitleScreen = gImgTitleScreen1
  else
    gImgCurrTitleScreen = gImgTitleScreen2
  end
end

function clearTable(t)
  for k in pairs(t) do
    t[k] = nil
  end
end

function updateGame(dt)
  handleSpawning(dt)

  -- clear arrays to prepare for collision detection
  -- todo: these tables is dumb extra state, should ideally read as a computed property
  clearTable(gLitBombs)
  clearTable(gStuff)

  if gElapsedTimeCurrGame > TIME_OF_ENVIRONMENT and gElapsedTimeCurrGame < TIME_OF_ENVIRONMENT + 0.2 then
    if not gSndTheEnvironment:isPlaying() then
      gSndTheEnvironment:play()
    end
  end

  -- update every spot in the grid
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" then
        -- nothing on empty spots...
      elseif cell_data.t == "B" then
        updateLitBomb(cell_data, dt)
        gLitBombs[#gLitBombs + 1] = cell_data
      elseif cell_data.t == "X" then
        updateTrash(cell_data, dt)
        gStuff[#gStuff + 1] = cell_data
      elseif cell_data.t == "BC" then
        updateBombToCollect(cell_data, dt)
        gStuff[#gStuff + 1] = cell_data
      end
    end
  end

  -- collisions
  for ck,cv in pairs(gStuff) do
    for bk, bv in pairs(gLitBombs) do
      tryToMarkCollision(bk, ck)
    end
  end

  removeAnyOrphanTrash()

  gElapsedTimeCurrGame = gElapsedTimeCurrGame + dt
end

-- removes all trash which does not have any
-- trash-manhattan-neighbor path to the perimeter
function removeAnyOrphanTrash()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell = G:get_cell(x, y)
      if cell.t == "X" and cell.hit == false then
        visited = {}
        if not hasPathToPerimeter(cell, visited) then
          -- 1000 is large for recurse as long as needed
          destroyTrashAndItsPile(cell, 1000, true)
        end
      end
    end
  end
end

function hasPathToPerimeter(cell, visited)
  if isAdjacentToWall(cell) then
    return true
  else
    visited[#visited + 1] = cell
    manhattan_neighbors = getManhattanNeighbors(cell)
    for k,v in pairs(manhattan_neighbors) do
      if v.t == "X" and not tableContainsCellAtLocation(visited, v.xpos, v.ypos) then
        if hasPathToPerimeter(v, visited) then
          return true
        end
      end
    end
    return false
  end
end

function tableContainsCellAtLocation(theTable, x, y)
  for k,v in pairs(theTable) do
    if v.xpos == x and v.ypos == y then
      return true
    end
  end
  return false
end

function isAdjacentToWall(cell)
  x = cell.xpos
  y = cell.ypos
  return x == 1 or y == 1 or x == gGridSize or y == gGridSize
end

function tryToMarkCollision(bk, ck)

  if gStuff[ck].hit == true then
    return
  end

  bombHasExploded = (gLitBombs[bk].time_until_explode <= 0 and gLitBombs[bk].time_since_exploded > 0)

  if not bombHasExploded then
    return
  end

  local bomb_x = gLitBombs[bk].xpos
  local bomb_y = gLitBombs[bk].ypos
  local stuff_x = gStuff[ck].xpos
  local stuff_y = gStuff[ck].ypos

  for x_to_check = (bomb_x - ((gCurrBombSpread - 1) / 2)), (bomb_x + ((gCurrBombSpread - 1) / 2)) do
    if G:is_valid(x_to_check, bomb_y) then
      if x_to_check == stuff_x and bomb_y == stuff_y then
        destroyTrashAndItsPile(gStuff[ck], gChainReactionFactor, false)
        return
      end
    end
  end

  for y_to_check = (bomb_y - ((gCurrBombSpread - 1) / 2)), (bomb_y + ((gCurrBombSpread - 1) / 2)) do
    if G:is_valid(bomb_x, y_to_check) then
      if bomb_x == stuff_x and y_to_check == stuff_y then
        destroyTrashAndItsPile(gStuff[ck], gChainReactionFactor, false)
        return
      end
    end
  end
end

function destroyTrashAndItsPile(startingTrash, chainReactionFactor, wasOrphanTrash)
  destroySingleTrash(startingTrash)
  destroyManhattanNeighboringStuffRecursively(startingTrash, 0, chainReactionFactor)
  if wasOrphanTrash then
    -- todo: play a sound?
  end
end

function destroySingleTrash(trash)
  trash.hit = true
  gTrashCleanedCount = gTrashCleanedCount + 1
  tryToAdvanceOnePhase()
end

function tryToAdvanceOnePhase()
  -- todo: each phase, increase the rate of trash generation by a bit?
  local shouldAdvance = false
  if gCurrPhase == 1 and gTrashCleanedCount >= gTrashNeededToLevelUp then
    gNumAutobombsPerRound = 0
    increaseGridSize(1)
    shouldAdvance = true
  elseif gCurrPhase == 2 and gTrashCleanedCount >= gTrashNeededToLevelUp then
    gNumAutobombsPerRound = 0
    increaseGridSize(1)
    shouldAdvance = true
  elseif gCurrPhase >= 3 and gTrashCleanedCount >= gTrashNeededToLevelUp then
    gNumAutobombsPerRound = gNumAutobombsPerRound + 1
    if gNumAutobombsPerRound > MAX_NUM_AUTOBOMBS then
      gNumAutobombsPerRound = MAX_NUM_AUTOBOMBS
    end
    increaseGridSize(1)
    shouldAdvance = true
  end

  if shouldAdvance then
    gTrashNeededToLevelUp = gTrashNeededToLevelUp * TRASH_NEEDED_TO_LVL_UP_FACTOR
    gCurrPhase = gCurrPhase + 1
    gBombToCollectSpawnProbability = gBombToCollectSpawnProbability * 0.98

    -- make it bit harder
    gAdjacentSpreadFactorMax = gAdjacentSpreadFactorMax * 2
    gNewSpreadFactorMax = gNewSpreadFactorMax * 2
    gDurOfEachDifficultyLvl = gDurOfEachDifficultyLvl * 0.8

    gSndLevelUp:play()
  end
end

-- todo: do this later
function increaseGridSize(increaseAmt)
  -- gGridSize = gGridSize + increaseAmt
  -- todo: resize not working? not sure why. could even be bug in grid class?
  --G:resize(gGridSize, gGridSize)

  -- spawn trash fully along new edges (as if to say, it was already there)
  --for i = 1, gGridSize do spawnTrash(i, gGridSize) end
  --for i = 1, gGridSize do spawnTrash(gGridSize, i) end
end

-- todo: consider doing breadth first, not depth first,
-- if we want to limit the total blast radius of the bombs
function destroyManhattanNeighboringStuffRecursively(cell, numSoFar, maxDepth)
  if numSoFar > maxDepth then
    return
  end

  manhattan_neighbors = getManhattanNeighbors(cell)
  for k,v in pairs(manhattan_neighbors) do
    if v.t == "X" and v.hit == false then
      destroySingleTrash(v)
      destroyManhattanNeighboringStuffRecursively(v, numSoFar + 1, gChainReactionFactor)
    elseif v.t == "BC" and v.hit == false then
      v.hit = true
      destroyManhattanNeighboringStuffRecursively(v, numSoFar + 1, gChainReactionFactor)
    end
  end
end

function getManhattanNeighbors(cell)
  manhattan_neighbors = {}

  candidates = {}
  candidates[#candidates + 1] = G:get_cell(cell.xpos, cell.ypos - 1)
  candidates[#candidates + 1] = G:get_cell(cell.xpos - 1, cell.ypos)
  candidates[#candidates + 1] = G:get_cell(cell.xpos + 1, cell.ypos)
  candidates[#candidates + 1] = G:get_cell(cell.xpos, cell.ypos + 1)

  for k,v in pairs(candidates) do
    if G:is_valid(v.xpos, v.ypos) then
      manhattan_neighbors[#manhattan_neighbors + 1] = v
    end
  end

  return manhattan_neighbors
end

function allSpotsEmpty()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t ~= "-" then
        return false
      end
    end
  end
  return true
end

function updateLitBomb(b, dt)
  if b.time_until_explode > 0 then
    b.time_until_explode = b.time_until_explode - dt
  elseif b.time_since_exploded > 0 then
    b.time_since_exploded = b.time_since_exploded - dt
    if not b.exploded then
      b.exploded = true
      if gSndExplode:isPlaying() then
        gSndExplode:stop()
      end
      gSndExplode:play()
    end
  else
    b.t = "-"
  end
end

function updateTrash(c, dt)
  if c.hit and (c.time_until_vanquished > 0) then
    c.time_until_vanquished = c.time_until_vanquished - dt
  elseif c.hit and (c.time_until_vanquished <= 0) then
    c.t = "-"
    checkRoomFullyCleaned()
  end
end

function updateBombToCollect(bc, dt)
  if bc.hit and (bc.time_until_vanquished > 0) then
    bc.time_until_vanquished = bc.time_until_vanquished - dt
  elseif bc.hit and (bc.time_until_vanquished <= 0) then
    bc.t = "-"
  end
end

function drawFloor(x, y, e)
  love.graphics.draw(gImgFloor, x * gSquareW, y * gSquareW)
end

function drawLitBomb(x, y, b)
  local col = deepCopy(gFullColor)
  love.graphics.setColor(col)
  if b.time_until_explode > (2/3) * gBombDurUntilExplode then
    love.graphics.draw(gImgBombLit3, x * gSquareW, y * gSquareW)
  elseif b.time_until_explode > (1/3) * gBombDurUntilExplode then
    love.graphics.draw(gImgBombLit2, x * gSquareW, y * gSquareW)
  elseif b.time_until_explode > 0 then
    love.graphics.draw(gImgBombLit1, x * gSquareW, y * gSquareW)
  elseif b.time_since_exploded > 0 then
    love.graphics.setColor(gFullColor)
    if b.time_since_exploded > (3/4) * gBombExplosionDur then
      love.graphics.draw(gImgBombExplode1, x * gSquareW, y * gSquareW)
    elseif b.time_since_exploded > (2/4) * gBombExplosionDur then
      love.graphics.draw(gImgBombExplode2, x * gSquareW, y * gSquareW)
    elseif b.time_since_exploded > (1/4) * gBombExplosionDur then
      love.graphics.draw(gImgBombExplode3, x * gSquareW, y * gSquareW)
    elseif b.time_since_exploded > gBombExplosionDur then
      love.graphics.draw(gImgBombExplode4, x * gSquareW, y * gSquareW)
    end
    -- unused
    --[[
    -- draw spread
    for x_candidate = (x - ((gCurrBombSpread - 1) / 2)), (x + ((gCurrBombSpread - 1) / 2)) do
      if G:is_valid(x_candidate + 1, y + 1) then
        love.graphics.rectangle("fill", x_candidate * gSquareW, y * gSquareW, gSquareW, gSquareW)
      end
    end
    for y_candidate = (y - ((gCurrBombSpread - 1) / 2)), (y + ((gCurrBombSpread - 1) / 2)) do
      if y_candidate == y then
        -- don't draw center
      elseif G:is_valid(y_candidate + 1, y + 1) then
        love.graphics.rectangle("fill", x * gSquareW, y_candidate * gSquareW, gSquareW, gSquareW)
      end
    end
    ]]--
  end
end

function drawTrash(x, y, c)
  local col = deepCopy(gFullColor)
  love.graphics.setColor(col)
  if c.hit then
    if c.time_until_vanquished > (3/4) * gDurUntilStuffVanquished then
      love.graphics.draw(gImgTrashExplode1, x * gSquareW, y * gSquareW)
    elseif c.time_until_vanquished > (2/4) * gDurUntilStuffVanquished then
      love.graphics.draw(gImgTrashExplode2, x * gSquareW, y * gSquareW)
    elseif c.time_until_vanquished > (1/4) * gDurUntilStuffVanquished then
      love.graphics.draw(gImgTrashExplode3, x * gSquareW, y * gSquareW)
    elseif c.time_until_vanquished > gDurUntilStuffVanquished then
      love.graphics.draw(gImgTrashExplode4, x * gSquareW, y * gSquareW)
    end
  else
    love.graphics.draw(gImgTrash, x * gSquareW, y * gSquareW)
  end
end

function drawBg()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      drawFloor(x-1, y-1, cell_data)
    end
  end
end

-- todo: clean this up, don't need loops
function drawAllTrash()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "X" then
        drawTrash(x-1, y-1, cell_data)
      end
    end
  end
end

-- todo: clean this up, don't need loops
function drawLitBombs()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "B" then
        drawLitBomb(x-1, y-1, cell_data)
      end
    end
  end
end

function drawBombToCollect(x, y, bc)
  local col = deepCopy(gFullColor)
  if bc.hit and bc.time_until_vanquished < gDurUntilStuffVanquished then
    col[4] = col[4] - (col[4] * (1.0 - (bc.time_until_vanquished / gDurUntilStuffVanquished)))
  end
  love.graphics.setColor(col)
  love.graphics.draw(gImgBombToCollect, x * gSquareW, y * gSquareW)
end

function drawBombsToCollect()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "BC" then
        drawBombToCollect(x-1, y-1, cell_data)
      end
    end
  end
end

function drawCursor()

  if not G:is_valid(gMousehoverCellX, gMousehoverCellY) then
    return
  end

  cell = G:get_cell(gMousehoverCellX, gMousehoverCellY)

  if cell.t == "-" and gCurrBombSupply > 0 then
    love.graphics.setColor(1.0, 0.4, 0.4, 0.5)
    love.graphics.circle("fill", (gMousehoverCellX-1) * gSquareW + (0.5 * gSquareW),
                                 (gMousehoverCellY-1) * gSquareW + (0.5 * gSquareW),
                                 gSquareW / 2)
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.print(gCurrBombSupply,
                       (gMousehoverCellX-1) * gSquareW + (0.5 * gSquareW)-10,
                       (gMousehoverCellY-1) * gSquareW + (0.5 * gSquareW)-25)
  elseif cell.t == "BC" then
    love.graphics.setColor(0.4, 1.0, 0.4, 1.0)
    love.graphics.circle("line", (gMousehoverCellX-1) * gSquareW + (0.5 * gSquareW),
                                 (gMousehoverCellY-1) * gSquareW + (0.5 * gSquareW),
                                 gSquareW / 2)
  else
    love.graphics.setColor(0.4, 0.4, 0.4, 0.25)
    love.graphics.rectangle("fill", (gMousehoverCellX-1) * gSquareW, (gMousehoverCellY-1) * gSquareW, gSquareW, gSquareW)
  end
end

function love.draw()
  -- center game within castle window
  love.graphics.push()
  gTranslateScreenToCenterDx = 0.5 * (love.graphics.getWidth() - gGridSize*gSquareW)
  gTranslateScreenToCenterDy = 0.5 * (love.graphics.getHeight() - gGridSize*gSquareW)
  love.graphics.translate(gTranslateScreenToCenterDx, gTranslateScreenToCenterDy)
  
  -- call setFont only inside .draw or it will set Ghost's font
  love.graphics.setFont(gTheFont)
  if not gGameStarted then
    love.graphics.draw(gImgCurrTitleScreen, 0, 0)
    love.graphics.setColor(167.0/255.0, 131.0/255.0, 95.0/255.0, 1.0)
    if HiScore:get() > 0 then
      love.graphics.print("High Score  "..HiScore:get(), 10, (gGridSize * gSquareW) + 10)
    end
  else
    drawBg()
    drawAllTrash()
    drawBombsToCollect()
    drawLitBombs()
    drawCursor()
    drawHUD()
  end
  
  love.graphics.pop()
end

function drawHUD()
  -- progress bar
  love.graphics.setColor(1.0, 0.4, 0.4, 1.0)
  love.graphics.rectangle("fill",
                          0, (gGridSize * gSquareW), -- x, y
                          (trashSoFarThisLevel() / trashGoalNeededWithinCurrLevel()) * (gGridSize * gSquareW), -- width
                          gSquareW / 3) -- height
  -- Text
  love.graphics.setColor(167.0/255.0, 131.0/255.0, 95.0/255.0, 1.0)
  love.graphics.print("Trash      "..gTrashCleanedCount, 10, (gGridSize * gSquareW) + (gSquareW / 3) + 10)
  if gNumAutobombsPerRound > 0 then
    love.graphics.print("Autobombs  "..gNumAutobombsPerRound, 10, (gGridSize * gSquareW) + (gSquareW / 3) + 10 + 24)
  end
end

function totalTrashThroughPrevLevel()
  local totalTrashThroughPrevLevel = (gTrashNeededToLevelUp / TRASH_NEEDED_TO_LVL_UP_FACTOR)
  if gCurrPhase == 1 then
    totalTrashThroughPrevLevel = 0
  end
  return totalTrashThroughPrevLevel
end

function trashSoFarThisLevel()
  return gTrashCleanedCount - totalTrashThroughPrevLevel()
end

function trashGoalNeededWithinCurrLevel()
  return gTrashNeededToLevelUp - totalTrashThroughPrevLevel()
end

function checkRoomFullyCleaned()
  local completed = true

  -- Fail iff any trash present
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "X" then
        completed = false
        break
      end
    end
    if not completed then
      break
    end
  end

  if completed then
    -- todo: give fully clean bonus
    -- or just display a temporary message of congrats... hrmf
  end
end

function checkGameOver()
  local allSpotsTaken = true

  -- Fail iff any trash present
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" or cell_data.t == "B" then
        allSpotsTaken = false
        break
      end
    end
    if not allSpotsTaken then
      break
    end
  end

  if allSpotsTaken then
    HiScore:maybeSave(gTrashCleanedCount)
    G:reset_all()
    gSndTrashSimulator:play()
    gGameStarted = false
  end
end

function love.mousepressed(x, y, button)
  -- disallow clicks out of bounds
  if x > gGridSize * gSquareW or y > gGridSize * gSquareW then
    return
  end

  if not gGameStarted then
    startGame()
    return
  end

  -- check if mouse out of bounds
  local numPixelsInGridWidth = (gGridSize * gSquareW)
  if (x - gTranslateScreenToCenterDx) > numPixelsInGridWidth or (y - gTranslateScreenToCenterDy) > numPixelsInGridWidth then
    return
  end

  cell_x, cell_y = getCellAtPoint(x - gTranslateScreenToCenterDx, y - gTranslateScreenToCenterDy)
  if button == 1 then
    if not tryToCollectBomb(cell_x, cell_y) then
      tryToLayBomb(cell_x, cell_y)
    end
  end
end

function love.mousemoved(x, y, dx, dy, istouch)
  if not gGameStarted then
    return
  end

  gMousehoverCellX, gMousehoverCellY = getCellAtPoint(x - gTranslateScreenToCenterDx, y - gTranslateScreenToCenterDy)
end

-- For key names, see: https://love2d.org/wiki/KeyConstant
function love.keypressed(key, scancode, isrepeat)
end

function tryToCollectBomb(x, y)
  local cell = G:get_cell(x, y)

  -- without this hack, the game can crash when clicking on
  -- the exact right edge of the window. todo: find out exactly
  -- why that's possible
  if cell == nil then
    return
  end

  if cell.t == "BC" then
    gCurrBombSupply = gCurrBombSupply + 1
    cell.t = "-"
    if gSndCollect:isPlaying() then
      gSndCollect:stop()
    end
    gSndCollect:play()
    return true
  else
    return false
  end
end

function tryToLayBomb(x, y)
  cell = G:get_cell(x, y)

  -- without this hack, the game can crash when clicking on
  -- the exact right edge of the window. todo: find out exactly
  -- why that's possible
  if cell == nil then
    return
  end

  isSpaceEmpty = cell.t == "-"
  playerHasBombsLeft = gCurrBombSupply > 0
  if isSpaceEmpty and playerHasBombsLeft then
    G:set_cell(x, y, { t = "B", xpos = x, ypos = y, exploded = false, time_until_explode = gBombDurUntilExplode, time_since_exploded = gBombExplosionDur })
    gCurrBombSupply = gCurrBombSupply - 1
    if gSndLayBomb:isPlaying() then
      gSndLayBomb:stop()
    end
    gSndLayBomb:play()
  end
end

function spawnTrash(x, y)
  G:set_cell(x, y, { t = "X", xpos = x, ypos = y, hit = false, time_until_vanquished = gDurUntilStuffVanquished })
  if gSndTrashSpawn:isPlaying() then
    gSndTrashSpawn:stop()
  end
  gSndTrashSpawn:play()
  checkGameOver()
end

function spawnBombToCollect(x, y)
  G:set_cell(x, y, { t = "BC", xpos = x, ypos = y, hit = false, time_until_vanquished = gDurUntilStuffVanquished })
end

function spawnLitBomb(x, y)
  G:set_cell(x, y, { t = "B", xpos = x, ypos = y, exploded = false, time_until_explode = gBombDurUntilExplode, time_since_exploded = gBombExplosionDur })
  if gSndLayBomb:isPlaying() then
    gSndLayBomb:stop()
  end
  gSndLayBomb:play()
end

function getCellAtPoint(mouse_x, mouse_y)
  -- lua doesn't do interger division, it just gives the accurate value, so we floor
  cell_x = math.floor(mouse_x / gSquareW) + 1 -- grid is 1-indexed
  cell_y = math.floor(mouse_y / gSquareW) + 1 -- grid is 1-indexed
  return cell_x, cell_y
end

function fillGridWithEmptySpots()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      G:set_cell( { t = "-", xpos = x, ypos = y } )
    end
  end
end

-- makes a recurisve deep copy of a table and its metatables
-- https://forums.coronalabs.com/topic/27482-copy-not-direct-reference-of-table/
function deepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end
