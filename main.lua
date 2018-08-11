require "grid"

-- GFX Globals
local instructions = "Click to lay bombs. Remove the clutter!"
local gSquareW = 32
local gCellEmptyColor = { 0.1, 0.1, 0.1, 1.0 }
local gCellClutterColor = { 0.5, 0.5, 0.5, 1.0 }
local gCellBombColorNormal = { 0.8, 0.3, 0.3, 1.0 }
local gCellBombColorExploding = { 0.8, 0.4, 0.15, 1.0 }

-- Game Logic
local gGridSize = 16
local gCurrLevel = 0
local gGameStarted = false
local gCurrBombSupply = 3
local gBombDurUntilExplode = 3
local gBombExplosionDur = 1.0

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

-- love callbacks
function love.load()
  -- nik says if i pull ghost master (and build w xcode),
  -- print will work
  print('RAAAAABLE')
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

function updateGame(dt)
  -- update every spot in the grid
  for x = 1, G.size_x do
    for y = 1, G.size_y do
      local cell_data = G:get_cell(x, y)
      if cell_data.t == "-" then
        -- todo
      elseif cell_data.t == "X" then
        -- todo
      elseif cell_data.t == "B" then
        updateBomb(cell_data, dt)
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

function drawBomb(x, y, b)
  if b.time_until_explode > 2 then
    col = deepCopy(gCellBombColorNormal)
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_until_explode > 1 then
    col = deepCopy(gCellBombColorNormal)
    col[4] = 0.75
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_until_explode > 0 then
    col = deepCopy(gCellBombColorNormal)
    col[4] = 0.5
    love.graphics.setColor(col)
    love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
  elseif b.time_since_exploded > 0 then
    col = deepCopy(gCellBombColorExploding)
    col[4] = col[4] - (col[4] * (1.0 - (b.time_since_exploded / gBombExplosionDur)))
    love.graphics.setColor(col)
    --for x_candidate = (x - ((gCurrBombSpread - 1) / 2)), 6 do
    for x_candidate = -2, 2 do
      if (G:is_valid(x + x_candidate, y)) then
        love.graphics.rectangle("fill", (x + x_candidate) * gSquareW, y * gSquareW, gSquareW, gSquareW)
      end
    end

  end
end

function drawEmpty(x, y, cell_data)
  love.graphics.setColor(gCellEmptyColor)
  love.graphics.rectangle("fill", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
end

function drawClutter(x, y, cell_data)
  love.graphics.setColor(gCellClutterColor)
  love.graphics.rectangle("line", x * gSquareW, y * gSquareW, gSquareW, gSquareW)
end

function love.draw()
  if not gGameStarted then
    love.graphics.print(instructions, 50, 50)
  else
    for x = 1, G.size_x do
      for y = 1, G.size_y do
        local cell_data = G:get_cell(x, y)
          drawEmpty(x-1, y-1, cell_data)
        if cell_data.t == "-" then

        elseif cell_data.t == "X" then
          drawClutter(x-1, y-1, cell_data)
        elseif cell_data.t == "B" then
          drawBomb(x-1, y-1, cell_data)
        end

        -- outline cells as mouse hovers over them
        if x == gMousehoverCellX and y == gMousehoverCellY then
          love.graphics.setColor(0.4, 1.0, 0.4, 1.0)
          love.graphics.rectangle("line", (x-1) * gSquareW, (y-1) * gSquareW, gSquareW, gSquareW)
        end
      end
    end
  end
end

function advanceOneLevel()
  gCurrLevel = gCurrLevel + 1

  -- todo: algorithm for clutter laying each new level
  G:set_cell(4, 4, { t = "X" })
  G:set_cell(12, 7, { t = "X" })
  G:set_cell(3, 11, { t = "X" })

  gCurrBombSupply = 3
end

function love.mousepressed(x, y, button)
  if not gGameStarted then
    gCurrPhase = 0
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
  tryToSetBomb(cell_x, cell_y)
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

function tryToSetBomb(x, y)
  isSpaceEmpty = G:get_cell(cell_x, cell_y).t == "-"
  playerHasBombsLeft = gCurrBombSupply > 0
  if isSpaceEmpty and playerHasBombsLeft then
    G:set_cell(cell_x, cell_y, { t = "B", time_until_explode = gBombDurUntilExplode, time_since_exploded = gBombExplosionDur })
    gCurrBombSupply = gCurrBombSupply - 1
  end
end

function setLevelForNextPhase()
  -- todo
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
