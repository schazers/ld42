require "grid"

-- GFX Globals
local instructions = "Click to lay bombs. Remove the clutter!"
local gSquareW = 32
local gCellEmptyColor = { 0.1, 0.1, 0.1, 1.0 }
local gCellClutterColor = { 0.5, 0.5, 0.5, 1.0 }
local gCellBombColorLaid = { 0.8, 0.3, 0.3, 1.0 }
local gCellBombColorExploding = { 0.8, 0.4, 0.15, 1.0 }

-- Game Constants
local gGridSize = 16
local gCurrLevel = 0
local gGameStarted = false
local gCurrBombSupply = 3
local gBombDurUntilExplode = 3
local gBombExplosionDur = 1.0
local gDurUntilClutterVanquished = 1.0

-- num squares bomb will explode on each axis,
-- including the square on which it is laid
local gCurrBombSpread = 5

local gMousehoverCellX = 0
local gMousehoverCellY = 0

-- Use a square grid of tables, each table has a type "t".
-- Each type has unique table data associated with it
-- Types:
-- "-" is empty space
-- "X" is clutter
-- "B" is a bomb
G = grid.Grid(gGridSize, gGridSize, { t = "-" })

gBombs = {}
gClutters = {}

-- love callbacks
function love.load()

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
  -- clear arrays to prepare for collision detection
  clearTable(gBombs)
  clearTable(gClutters)

  -- update every spot in the grid
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" then
        -- nothing on empty spots...
      elseif cell_data.t == "B" then
        updateBomb(cell_data, dt)
        gBombs[#gBombs + 1] = cell_data
      elseif cell_data.t == "X" then
        updateClutter(cell_data, dt)
        gClutters[#gClutters + 1] = cell_data
      end
    end
  end

  -- collisions
  for ck,cv in pairs(gClutters) do
    for bk, bv in pairs(gBombs) do
      tryToMarkCollision(bk, ck)
    end
  end
end

function tryToMarkCollision(bk, ck)
  bombHasExploded = (gBombs[bk].time_until_explode <= 0 and gBombs[bk].time_since_exploded > 0)

  if not bombHasExploded then
    return
  end

  local bomb_x = gBombs[bk].xpos
  local bomb_y = gBombs[bk].ypos
  local clutter_x = gClutters[ck].xpos
  local clutter_y = gClutters[ck].ypos

  for x_to_check = (bomb_x - ((gCurrBombSpread - 1) / 2)), (bomb_x + ((gCurrBombSpread - 1) / 2)) do
    if G:is_valid(x_to_check, bomb_y) then
      if x_to_check == clutter_x and bomb_y == clutter_y then
        gClutters[ck].hit = true
        return
      end
    end
  end

  for y_to_check = (bomb_y - ((gCurrBombSpread - 1) / 2)), (bomb_y + ((gCurrBombSpread - 1) / 2)) do
    if G:is_valid(bomb_x, y_to_check) then
      if bomb_x == clutter_x and y_to_check == clutter_y then
        gClutters[ck].hit = true
        return
      end
    end
  end
end

function updateBomb(b, dt)
  if b.time_until_explode > 0 then
    b.time_until_explode = b.time_until_explode - dt
  elseif b.time_since_exploded > 0 then
    b.time_since_exploded = b.time_since_exploded - dt
  else
    b.t = "-"
    gCurrBombSupply = gCurrBombSupply + 1
  end
end

function updateClutter(c, dt)
  if c.hit and (c.time_until_vanquished > 0) then
    c.time_until_vanquished = c.time_until_vanquished - dt
  elseif c.hit and (c.time_until_vanquished <= 0) then
    c.t = "-"
    checkLevelCompleted()
  end
end

function drawEmpty(x, y, e)
  love.graphics.setColor(gCellEmptyColor)
  love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
end

function drawBomb(x, y, b)
  if b.time_until_explode > 2 then
    col = deepCopy(gCellBombColorLaid)
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_until_explode > 1 then
    col = deepCopy(gCellBombColorLaid)
    col[4] = 0.75
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_until_explode > 0 then
    col = deepCopy(gCellBombColorLaid)
    col[4] = 0.5
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_since_exploded > 0 then
    col = deepCopy(gCellBombColorExploding)
    col[4] = col[4] - (col[4] * (1.0 - (b.time_since_exploded / gBombExplosionDur)))
    love.graphics.setColor(col)
    for x_candidate = (x - ((gCurrBombSpread - 1) / 2)), (x + ((gCurrBombSpread - 1) / 2)) do
      if G:is_valid(x_candidate, y) then
        love.graphics.rectangle("fill", x_candidate * gSquareW, y * gSquareW, gSquareW, gSquareW)
      end
    end
    for y_candidate = (y - ((gCurrBombSpread - 1) / 2)), (y + ((gCurrBombSpread - 1) / 2)) do
      if y_candidate == y then
        -- do nothing, we already drew this on horizontal pass
      elseif G:is_valid(y_candidate, y) then
        love.graphics.rectangle("fill", x * gSquareW, y_candidate * gSquareW, gSquareW, gSquareW)
      end
    end
  end
end

function drawClutter(x, y, c)
  local col = deepCopy(gCellClutterColor)
  if c.hit and c.time_until_vanquished < gDurUntilClutterVanquished then
    col[4] = col[4] - (col[4] * (1.0 - (c.time_until_vanquished / gDurUntilClutterVanquished)))
  end
  love.graphics.setColor(col)
  love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
end

function drawBg()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
        drawEmpty(x-1, y-1, cell_data)
    end
  end
end

-- todo: clean this up, don't need for loops
function drawAllClutters()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "X" then
        drawClutter(x-1, y-1, cell_data)
      end
    end
  end
end

-- todo: clean this up, don't need for loops
function drawBombs()
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "B" then
        drawBomb(x-1, y-1, cell_data)
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
    drawAllClutters()
    drawBombs()
    drawCursor()
  end
end

function checkLevelCompleted()
  local completed = true

  -- Fail iff any clutter present
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
    advanceOneLevel()
  end
end

function advanceOneLevel()
  gCurrLevel = gCurrLevel + 1

  -- todo: algorithm for clutter laying each new level
  spawnClutter(1, 1)
  spawnClutter(16, 16)
  spawnClutter(16, 1)
  spawnClutter(1, 16)

  gCurrBombSupply = 3
end

function love.mousepressed(x, y, button)
  if not gGameStarted then
    advanceOneLevel()
    gGameStarted = true
    return
  end

  -- check if mouse out of bounds
  local numPixelsInGridWidth = (gGridSize * gSquareW)
  if x > numPixelsInGridWidth or y > numPixelsInGridWidth then
    return
  end

  cell_x, cell_y = getCellAtPoint(x, y)
  tryToLayBomb(cell_x, cell_y)
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

function tryToLayBomb(x, y)
  isSpaceEmpty = G:get_cell(x, y).t == "-"
  playerHasBombsLeft = gCurrBombSupply > 0
  if isSpaceEmpty and playerHasBombsLeft then
    G:set_cell(x, y, { t = "B", xpos = x, ypos = y, time_until_explode = gBombDurUntilExplode, time_since_exploded = gBombExplosionDur })
    gCurrBombSupply = gCurrBombSupply - 1
  end
end

function spawnClutter(x, y)
  G:set_cell(x, y, { t = "X", xpos = x, ypos = y, hit = false, time_until_vanquished = gDurUntilClutterVanquished })
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
