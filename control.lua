-- TODO: do not allow mixing of ores
-- TODO: extract pole range from prototype
-- TODO: extract drill size from prototype
-- TODO: split code, refactor into something beautiful


drill_step = 3
max_area_size = 150
electric_pole_step = 4

drill_half_step = (drill_step - 1) / 2

function get_drill_to_use(player)
  return player.gui.left.settings_frame.settings_drill.elem_value
end

function get_belt_to_use(player)
  return player.gui.left.settings_frame.settings_belt.elem_value
end

function get_pole_to_use(player)
  return player.gui.left.settings_frame.settings_pole.elem_value
end

function try_build(table)
  if game.surfaces[1].can_place_entity(table) then
    game.surfaces[1].create_entity(table)
  end
end

function get_cursor(player)
  if player.selected then
    return player.selected.position
  else
    return nil
  end
end

function is_drill_useful(resource_name, position)
  resources = game.surfaces[1].find_entities_filtered{
    area={
      {position[1] - drill_half_step, position[2] - drill_half_step},
      {position[1] + drill_half_step, position[2] + drill_half_step}
    },
    name=resource_name
  }
  for _, _ in pairs(resources) do
    return true
  end
  return false
end

function build_drill_lane(chosen_drill, resource_name, moving_coordinate_min, moving_coordinate_max, fixed_coordinate, direction, output_direction)
  local total = 0
  local start_pos = nil
  for moving_coordinate = moving_coordinate_min, moving_coordinate_max, drill_step do
    if output_direction == defines.direction.north or output_direction == defines.direction.south then
      position={fixed_coordinate, moving_coordinate}
    else
      position={moving_coordinate, fixed_coordinate}
    end
    if is_drill_useful(resource_name, position) then
      if start_pos == nil then
        start_pos = moving_coordinate
      end
      try_build{
        name = "entity-ghost",
        inner_name = chosen_drill,
        position=position,
        direction=direction,
        force=game.forces.player
      }
      total = total + 1
    end
  end
  if start_pos == nil then
    start_pos = moving_coordinate_max
  end
  return {total=total, start=start_pos}
end

function build_belt_lane(chosen_belt, moving_coordinate_min, moving_coordinate_max, fixed_coordinate, output_direction)
  local position = nil
  for moving_coordinate = moving_coordinate_min, moving_coordinate_max, 1 do
    if output_direction == defines.direction.north or output_direction == defines.direction.south then
      position={fixed_coordinate, moving_coordinate}
    else
      position={moving_coordinate, fixed_coordinate}
    end
    try_build{
      name = "entity-ghost",
      inner_name=chosen_belt,
      position=position,
      direction=output_direction,
      force=game.forces.player
    }
  end
end

function build_electric_pole_lane(chosen_pole, moving_coordinate_min, moving_coordinate_max, fixed_coordinate, output_direction)
  for moving_coordinate = moving_coordinate_min, moving_coordinate_max, electric_pole_step do
    if output_direction == defines.direction.north or output_direction == defines.direction.south then
      position={fixed_coordinate, moving_coordinate}
    else
      position={moving_coordinate, fixed_coordinate}
    end
    try_build{
      name = "entity-ghost",
      inner_name = chosen_pole,
      position=position,
      force=game.forces.player
    }
  end
end

function build_area(player, resource_name, top_left, bottom_right, output_direction)
  local chosen_drill = get_drill_to_use(player)
  local chosen_belt = get_belt_to_use(player)
  local chosen_pole = get_pole_to_use(player)

  local total = 0
  -- set initial direction for drills
  local direction = nil
  local moving_coordinate_min = nil
  local moving_coordinate_max = nil
  local fixed_coordinate_range = nil
  if output_direction == defines.direction.north or output_direction == defines.direction.south then
    direction = defines.direction.east
    moving_coordinate_min = top_left.y
    moving_coordinate_max = bottom_right.y
    fixed_coordinate_range = {top_left.x, bottom_right.x}
  else
    direction = defines.direction.south
    moving_coordinate_min = top_left.x
    moving_coordinate_max = bottom_right.x
    fixed_coordinate_range = {top_left.y, bottom_right.y}
  end
  local start_positions = {}
  local index = 0
  -- build drills and poles
  for fixed_coordinate = fixed_coordinate_range[1], fixed_coordinate_range[2], (drill_step + 1) do
      local current = build_drill_lane(
        chosen_drill,
        resource_name,
        moving_coordinate_min,
        moving_coordinate_max,
        fixed_coordinate + drill_half_step,
        direction,
        output_direction
      )
      total = total + current.total
      start_positions[index] = current.start
      index = index + 1

      -- first line of poles
      if (direction == defines.direction.south or direction == defines.direction.east) and fixed_coordinate == fixed_coordinate_range[1] then
        build_electric_pole_lane(chosen_pole, moving_coordinate_min, moving_coordinate_max, fixed_coordinate - 1, output_direction)
      end
      -- other lane(under drill)
      if (direction == defines.direction.north or direction == defines.direction.west) then
        build_electric_pole_lane(chosen_pole, moving_coordinate_min, moving_coordinate_max, fixed_coordinate + drill_step, output_direction)
      end

      -- swap drill direction for next row
      if direction == defines.direction.north then
        direction = defines.direction.south
      elseif direction == defines.direction.west then
        direction = defines.direction.east
      elseif direction == defines.direction.south then
        direction = defines.direction.north
      else -- east
        direction = defines.direction.west
      end
  end
  -- build belts
  index = 0
  for fixed_coordinate = fixed_coordinate_range[1], fixed_coordinate_range[2], 2 * (drill_step + 1) do
    local current_start = start_positions[index]
    if start_positions[index + 1] ~= nil then
      current_start = math.min(current_start, start_positions[index + 1])
    end
    if current_start ~= nil then
      build_belt_lane(chosen_belt,
        current_start, moving_coordinate_max, fixed_coordinate + drill_step, output_direction)
    end
    index = index + 2
  end
  return total
end

function process_position(player, position, direction)
  local selected_table = game.surfaces[1].find_entities_filtered{
    position=position,
    type="resource"
  }
  local resource_name = nil
  for _, selected in pairs(selected_table) do
    resource_name = selected.name
  end
  area_size = 1
  local previous_count = 0
  local different = true
  while different and area_size < max_area_size do
    current_count = game.surfaces[1].count_entities_filtered{
      area={{position.x - area_size, position.y - area_size},
            {position.x + area_size, position.y + area_size}},
      name=resource_name
    }
    if previous_count == current_count then
      different = false
    end
    previous_count = current_count
    area_size = area_size + 1
  end
  local resources = game.surfaces[1].find_entities_filtered{
    area={{position.x - area_size, position.y - area_size},
          {position.x + area_size, position.y + area_size}},
    name=resource_name
  }
  local top_left = {x = position.x, y = position.y}
  local bottom_right = {x = position.x, y = position.y}
  for i, resource in pairs(resources) do
    top_left.x = math.min(top_left.x, resource.position.x)
    top_left.y = math.min(top_left.y, resource.position.y)
    bottom_right.x = math.max(bottom_right.x, resource.position.x)
    bottom_right.y = math.max(bottom_right.y, resource.position.y)
  end

  build_area(player, resource_name, top_left, bottom_right, direction)
end

script.on_event(
  "drill-build-event-north",
  function(event)
    local player = game.players[event.player_index]
    cursor = get_cursor(player)
    if cursor then
      process_position(player, cursor, defines.direction.north)
    end
  end
)

script.on_event(
  "drill-build-event-south",
  function(event)
    local player = game.players[event.player_index]
    cursor = get_cursor(player)
    if cursor then
      process_position(player, cursor, defines.direction.south)
    end
  end
)

script.on_event(
  "drill-build-event-west",
  function(event)
    local player = game.players[event.player_index]
    cursor = get_cursor(player)
    if cursor then
      process_position(player, cursor, defines.direction.west)
    end
  end
)

script.on_event(
  "drill-build-event-east",
  function(event)
    local player = game.players[event.player_index]
    cursor = get_cursor(player)
    if cursor then
      process_position(player, cursor, defines.direction.east)
    end
  end
)

function create_ui(player)
  player.gui.top.add{
    type="sprite-button",
    name="settings_button",
    sprite="item/electric-mining-drill",
    tooltip="Autobuilder settings",
  }
  player.gui.left.add{
    type="frame",
    name="settings_frame",
  }
  player.gui.left.settings_frame.style.visible=false
  player.gui.left.settings_frame.add{
    type="label",
    name="settings_label",
    caption="Autobuilder settings",
  }
  player.gui.left.settings_frame.add{
    type="choose-elem-button",
    name="settings_drill",
    caption="Drill",
    elem_type="entity",
    entity="electric-mining-drill",
    tooltip="Drill to use",
  }
  player.gui.left.settings_frame.add{
    type="choose-elem-button",
    name="settings_pole",
    caption="Pole",
    elem_type="entity",
    entity="small-electric-pole",
    tooltip="Pole to use",
  }
  player.gui.left.settings_frame.add{
    type="choose-elem-button",
    name="settings_belt",
    caption="Belt",
    elem_type="entity",
    entity="transport-belt",
    tooltip="Belt to use",
  }
end

-- when creating a new game, initialize UI for player
script.on_init(
  function(event)
    for _, player in pairs(game.players) do
      create_ui(player)
    end
  end
)

-- when a player is joining, create the UI for them
script.on_event(
  defines.events.on_player_created,
  function(event)
    local player = game.players[event.player_index]
    create_ui(player)
  end
)

-- open setting UI
function toggle_mod_settings(player)
  player.gui.left.settings_frame.style.visible =
    not player.gui.left.settings_frame.style.visible
end
script.on_event(
  defines.events.on_gui_click,
  function(event)
    if event.element.name == "settings_button" then
      toggle_mod_settings(game.players[event.player_index])
    end
  end
)
