require "grid"

-- GFX Globals
local instructions = "Click to collect and lay bombs."
local gSquareW = 32
local gFullColor = { 1.0, 1.0, 1.0, 1.0 }
local gCellBombColorLaid = { 0.8, 0.3, 0.3, 1.0 }
local gCellBombColorExploding = { 0.8, 0.4, 0.15, 1.0 }

-- Game Constants
local gGridSize = 16
local gGameStarted = false
local gGameOver = false
local gBombDurUntilExplode = 0.7
local gBombExplosionDur = 0.6
local gDurUntilStuffVanquished = gBombExplosionDur

-- num squares bomb will explode on each axis,
-- including the square on which it is laid
local gCurrBombSpread = 3--gGridSize * 2 + 1 -- odd numbers only
local gCurrBombSupply = 0

local gMousehoverCellX = 0
local gMousehoverCellY = 0

local gBombToCollectSpawnProbability = 0.05 -- probability of a bomb spawning adjacent rather than trash

local gElapsedTimeThisLevel = 0
local gTimeSinceLastDifficultyIncrease = 0
local gDurOfEachDifficultyLvl = .4 -- interval after which it gets a little harder
local gTimesDifficultyIncreased = 0

local gTimeSinceLastTrashNewClusterSpawn = 0
local gTimeSinceLastAdjacentSpawn = 0

local gStuffCleanedCount = 0

-- Use a square grid of tables, each table has a type "t".
-- Each type has unique table data associated with it
-- Types:
-- "-" is empty space
-- "X" is trash
-- "B" is a bomb
G = grid.Grid(gGridSize, gGridSize, { t = "-" })

gLitBombs = {}
gStuff = {} -- a stuff item is either a Trash or BombToCollect

gNewSpreadFactor = 0
gAdjacentSpreadFactor = 0

function startGame()
  gNewSpreadFactor = 0.001
  gAdjacentSpreadFactor = 0.02

  -- one bomb in the center
  spawnBombToCollect(gGridSize / 2, gGridSize / 2)

  gCurrBombSupply = 0
end

function handleSpawning(dt)
  -- get all spaces neighboring spaces where there is currently trash
  local adjacentEmptySpaces = {}
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "X" then
        for xn = -1, 1 do
          for yn = -1, 1 do
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

  if math.random() < (gAdjacentSpreadFactor * gTimeSinceLastAdjacentSpawn) then
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
  local allEmptySpaces = {}
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" or cell_data.t == "BC" then
        allEmptySpaces[#allEmptySpaces + 1] = { xpos = x, ypos = y }
      end
    end
  end

  -- rarely, spawn random new trash spots
  if math.random() < (gNewSpreadFactor * gTimeSinceLastTrashNewClusterSpawn) then
    local spawnSpot = allEmptySpaces[math.random(#allEmptySpaces)]
    if spawnSpot ~= nil then
      spawnTrash(spawnSpot.xpos, spawnSpot.ypos)
      gTimeSinceLastTrashNewClusterSpawn = 0
    else
      gTimeSinceLastTrashNewClusterSpawn = gTimeSinceLastTrashNewClusterSpawn + dt
    end
  else
    gTimeSinceLastTrashNewClusterSpawn = gTimeSinceLastTrashNewClusterSpawn + dt
  end

  -- make it a little harder every so often
  if (gTimeSinceLastDifficultyIncrease > gDurOfEachDifficultyLvl) then
    gNewSpreadFactor = gNewSpreadFactor + (gNewSpreadFactor / 32)
    gAdjacentSpreadFactor = gAdjacentSpreadFactor + (gAdjacentSpreadFactor / 8)
    gTimeSinceLastDifficultyIncrease = 0
    gTimesDifficultyIncreased = gTimesDifficultyIncreased + 1
  else
    gTimeSinceLastDifficultyIncrease = gTimeSinceLastDifficultyIncrease + dt
  end
end

function love.load()
  math.randomseed(os.time())
  gImgFloor = love.graphics.newImage("sand.png")
  gImgTrash = love.graphics.newImage("trash.png")
  gImgBombToCollect = love.graphics.newImage("bomb_to_collect.png")
  gImgBombLit = love.graphics.newImage("bomb_lit.png")
end

function love.update(dt)
  if not gGameStarted then
    updateTitleScreen(dt)
  else
    updateGame(dt)
  end
end

function updateTitleScreen(dt)
  -- todo
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

  -- update every spot in the grid
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" then
        -- nothing on empty spots...
      elseif cell_data.t == "B" then
        updateBomb(cell_data, dt)
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

  gElapsedTimeThisLevel = gElapsedTimeThisLevel + dt
end

function tryToMarkCollision(bk, ck)
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
        gStuff[ck].hit = true
        markNeighborsAsHitRecursively(gStuff[ck], 0)
        return
      end
    end
  end

  for y_to_check = (bomb_y - ((gCurrBombSpread - 1) / 2)), (bomb_y + ((gCurrBombSpread - 1) / 2)) do
    if G:is_valid(bomb_x, y_to_check) then
      if bomb_x == stuff_x and y_to_check == stuff_y then
        gStuff[ck].hit = true
        markNeighborsAsHitRecursively(gStuff[ck], 0)
        return
      end
    end
  end
end

-- todo: consider doing breadth first, not depth first,
-- if we want to limit the total blast radius of the bombs
function markNeighborsAsHitRecursively(cell, numSoFar)

  if numSoFar > 3 then
    return
  end

  manhattan_neighbors = getManhattanNeighbors(cell)
  for k,v in pairs(manhattan_neighbors) do
    if v.t == "X" and v.hit == false then
      v.hit = true
      markNeighborsAsHitRecursively(v, numSoFar + 1)
    end
    --todo: consider recursing only on trash
    if v.t == "BC" and v.hit == false then
      v.hit = true
      markNeighborsAsHitRecursively(v, numSoFar + 1)
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

function updateBomb(b, dt)
  if b.time_until_explode > 0 then
    b.time_until_explode = b.time_until_explode - dt
  elseif b.time_since_exploded > 0 then
    b.time_since_exploded = b.time_since_exploded - dt
    if not b.exploded then
      b.exploded = true
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
  local col = deepCopy(gCellBombColorLaid)
  if b.time_until_explode > (2/3) * gBombDurUntilExplode then
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_until_explode > (1/3) * gBombDurUntilExplode then
    col[4] = 0.75
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_until_explode > 0 then
    col[4] = 0.5
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_since_exploded > 0 then
    col = deepCopy(gCellBombColorExploding)
    col[4] = col[4] - (col[4] * (1.0 - (b.time_since_exploded / gBombExplosionDur)))
    love.graphics.setColor(col)
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
  end
end

function drawTrash(x, y, c)
  local col = deepCopy(gFullColor)
  if c.hit and c.time_until_vanquished < gDurUntilStuffVanquished then
    col[4] = col[4] - (col[4] * (1.0 - (c.time_until_vanquished / gDurUntilStuffVanquished)))
  end
  love.graphics.setColor(col)
  love.graphics.draw(gImgTrash, x * gSquareW, y * gSquareW)
end

function drawBg()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      drawFloor(x-1, y-1, cell_data)
    end
  end
end

-- todo: clean this up, don't need for loops
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

-- todo: clean this up, don't need for loops
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
  love.graphics.setColor(0.4, 1.0, 0.4, 1.0)
  love.graphics.rectangle("line", (gMousehoverCellX-1) * gSquareW, (gMousehoverCellY-1) * gSquareW, gSquareW, gSquareW)
end

function love.draw()
  if not gGameStarted then
    love.graphics.print(instructions, 50, 50)
  else
    drawBg()
    drawAllTrash()
    drawBombsToCollect()
    drawLitBombs()
    drawCursor()
    love.graphics.print(gCurrBombSupply, gGridSize * gSquareW + 20, gSquareW / 2 - 5)
    love.graphics.print("Trash cleaned: "..gStuffCleanedCount, gGridSize * gSquareW + 20, 2 * (gSquareW / 2) - 5)
  end
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

  end
end

function checkGameOver()
  local allSpotsTrash = true

  -- Fail iff any trash present
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t ~= "X" then
        allSpotsTrash = false
        break
      end
    end
    if not allSpotsTrash then
      break
    end
  end

  if allSpotsTrash then
    -- todo: write out high score
    G:reset_all()
    gGameStarted = false
  end
end

function love.mousepressed(x, y, button)
  if not gGameStarted then
    startGame()
    gGameStarted = true
    return
  end

  -- check if mouse out of bounds
  local numPixelsInGridWidth = (gGridSize * gSquareW)
  if x > numPixelsInGridWidth or y > numPixelsInGridWidth then
    return
  end

  cell_x, cell_y = getCellAtPoint(x, y)
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

  gMousehoverCellX, gMousehoverCellY = getCellAtPoint(x, y)
end

-- For key names, see: https://love2d.org/wiki/KeyConstant
function love.keypressed(key, scancode, isrepeat)
  if key == "e" then
    G:reset_all()
    gGameStarted = false
  end
end

function tryToCollectBomb(x, y)
  local cell = G:get_cell(x, y)
  if cell.t == "BC" then
    gCurrBombSupply = gCurrBombSupply + 1
    cell.t = "-"
    return true
  else
    return false
  end
end

function tryToLayBomb(x, y)
  isSpaceEmpty = G:get_cell(x, y).t == "-"
  playerHasBombsLeft = gCurrBombSupply > 0
  if isSpaceEmpty and playerHasBombsLeft then
    G:set_cell(x, y, { t = "B", xpos = x, ypos = y, exploded = false, time_until_explode = gBombDurUntilExplode, time_since_exploded = gBombExplosionDur })
    gCurrBombSupply = gCurrBombSupply - 1
  end
end

function spawnTrash(x, y)
  G:set_cell(x, y, { t = "X", xpos = x, ypos = y, hit = false, time_until_vanquished = gDurUntilStuffVanquished })
  checkGameOver()
end

function spawnBombToCollect(x, y)
  G:set_cell(x, y, { t = "BC", xpos = x, ypos = y, hit = false, time_until_vanquished = gDurUntilStuffVanquished })
end

function getCellAtPoint(mouse_x, mouse_y)
  -- lua doesn't do interger division, it just gives the accurate value, so we floor
  cell_x = math.floor(mouse_x / gSquareW) + 1 -- grid is 1-indexed
  cell_y = math.floor(mouse_y / gSquareW) + 1 -- grid is 1-indexed
  return cell_x, cell_y
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
