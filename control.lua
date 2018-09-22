drill_step = 3
area_size = 50
electric_pole_step = 4

function get_cursor()
  cursor = nil
  for _, player in pairs(game.players) do
      if player.selected then
        cursor = player.selected.position
      end
  end
  return cursor
end

function is_drill_useful(resource_name, x, y)
  drill_half_step = (drill_step - 1) / 2
  resources = game.surfaces[1].find_entities_filtered{
    area={
      {x - drill_half_step, y - drill_half_step},
      {x + drill_half_step, y + drill_half_step}
    },
    name=name
  }
  for _, _ in pairs(resources) do
    return true
  end
  return false
end

function build_drill_lane(resource_name, left_x, right_x, y, direction)
  total = 0
  start_pos = nil
  for x = left_x, right_x, drill_step do
    if is_drill_useful(resource_name, x, y) then
      if start_pos == nil then
        start_pos = x
      end
      game.surfaces[1].create_entity{
        name = "electric-mining-drill",
        position={x, y},
        direction=direction,
        force=game.forces.player
      }
      total = total + 1
    end
  end
  if start_pos == nil then
    start_pos = right_x
  end
  return {total=total, start=start_pos}
end

function build_belt_lane(left_x, right_x, y, direction)
  for x = left_x, right_x, 1 do
    game.surfaces[1].create_entity{
      name = "transport-belt",
      position={x, y},
      direction=direction,
      force=game.forces.player
    }
    total = total + 1
  end
end

function build_electric_pole_lane(left_x, right_x, y)
  for x = left_x, right_x, electric_pole_step do
    game.surfaces[1].create_entity{
      name = "small-electric-pole",
      position={x, y},
      force=game.forces.player
    }
    total = total + 1
  end
end

function build_area(resource_name, top_left, bottom_right)
  total = 0
  direction = defines.direction.south
  start_positions = {}
  index = 0
  -- build drills and poles
  for y = top_left.y, bottom_right.y, (drill_step + 1) do
      current = build_drill_lane(
        resource_name,
        top_left.x,
        bottom_right.x,
        y + (drill_step - 1) / 2,
        direction
      )
      total = total + current.total
      start_positions[index] = current.start
      index = index + 1
      if direction == defines.direction.south then
        build_electric_pole_lane(top_left.x, bottom_right.x, y - 1)
      end

      if direction == defines.direction.north then
        direction = defines.direction.south
      else
        direction = defines.direction.north
      end
  end
  -- build belts
  index = 0
  for y = top_left.y, bottom_right.y, 2 * (drill_step + 1) do
    current_start = start_positions[index]
    if start_positions[index + 1] ~= nil then
      current_start = math.min(current_start, start_positions[index + 1])
    end
    if current_start ~= nil then
      build_belt_lane(current_start, bottom_right.x, y + drill_step, defines.direction.east)
    end
    index = index + 2
  end
  game.print("Constructed " .. tostring(total))
  return total
end

function process_position(position)
  selected_table = game.surfaces[1].find_entities_filtered{
    position=position,
    type="resource"
  }
  resource_name = nil
  for _, selected in pairs(selected_table) do
    resource_name = selected.name
  end
  resources = game.surfaces[1].find_entities_filtered{
    area={{position.x - area_size, position.y - area_size},
          {position.x + area_size, position.y + area_size}},
    name=resource_name
  }
  top_left = {x = position.x, y = position.y}
  bottom_right = {x = position.x, y = position.y}
  for i, resource in pairs(resources) do
    top_left.x = math.min(top_left.x, resource.position.x)
    top_left.y = math.min(top_left.y, resource.position.y)
    bottom_right.x = math.max(bottom_right.x, resource.position.x)
    bottom_right.y = math.max(bottom_right.y, resource.position.y)
  end

  build_area(resource_name, top_left, bottom_right)
end


script.on_event(
  "my-custom-input",
  function(event)
    game.print("YO")
    cursor = get_cursor()
    if cursor then
      process_position(cursor)
    end
  end
)
