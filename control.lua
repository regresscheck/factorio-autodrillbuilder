-- TODO: do not allow mixing of ores
-- TODO: extract pole range from prototype
-- TODO: extract drill size from prototype
-- TODO: split code, refactor into something beautiful
-- TODO: support multiple directions


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

function is_drill_useful(resource_name, x, y)
  resources = game.surfaces[1].find_entities_filtered{
    area={
      {x - drill_half_step, y - drill_half_step},
      {x + drill_half_step, y + drill_half_step}
    },
    name=resource_name
  }
  for _, _ in pairs(resources) do
    return true
  end
  return false
end

function build_drill_lane(chosen_drill, resource_name, left_x, right_x, y, direction)
  local total = 0
  local start_pos = nil
  for x = left_x, right_x, drill_step do
    if is_drill_useful(resource_name, x, y) then
      if start_pos == nil then
        start_pos = x
      end
      try_build{
        name = "entity-ghost",
        inner_name = chosen_drill,
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

function build_belt_lane(chosen_belt, left_x, right_x, y, direction)
  for x = left_x, right_x, 1 do
    try_build{
      name = "entity-ghost",
      inner_name=chosen_belt,
      position={x, y},
      direction=direction,
      force=game.forces.player
    }
  end
end

function build_electric_pole_lane(chosen_pole, left_x, right_x, y)
  for x = left_x, right_x, electric_pole_step do
    try_build{
      name = "entity-ghost",
      inner_name = chosen_pole,
      position={x, y},
      force=game.forces.player
    }
  end
end

function build_area(player, resource_name, top_left, bottom_right)
  local chosen_drill = get_drill_to_use(player)
  local chosen_belt = get_belt_to_use(player)
  local chosen_pole = get_pole_to_use(player)

  local total = 0
  local direction = defines.direction.south
  local start_positions = {}
  local index = 0
  -- build drills and poles
  for y = top_left.y, bottom_right.y, (drill_step + 1) do
      local current = build_drill_lane(
        chosen_drill,
        resource_name,
        top_left.x,
        bottom_right.x,
        y + drill_half_step,
        direction
      )
      total = total + current.total
      start_positions[index] = current.start
      index = index + 1

      -- first line of poles
      if direction == defines.direction.south and y == top_left.y then
        build_electric_pole_lane(chosen_pole, top_left.x, bottom_right.x, y - 1)
      end
      -- other lane(under drill)
      if direction == defines.direction.north then
        build_electric_pole_lane(chosen_pole,
          top_left.x, bottom_right.x, y + drill_step)
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
    local current_start = start_positions[index]
    if start_positions[index + 1] ~= nil then
      current_start = math.min(current_start, start_positions[index + 1])
    end
    if current_start ~= nil then
      build_belt_lane(chosen_belt,
        current_start, bottom_right.x, y + drill_step, defines.direction.east)
    end
    index = index + 2
  end
  return total
end

function process_position(player, position)
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

  build_area(player, resource_name, top_left, bottom_right)
end

function toggle_mod_settings(player)
  player.gui.left.settings_frame.style.visible =
    not player.gui.left.settings_frame.style.visible
end

script.on_event(
  "drill-build-event",
  function(event)
    local player = game.players[event.player_index]
    cursor = get_cursor(player)
    if cursor then
      process_position(player, cursor)
    end
  end
)

script.on_event(
  defines.events.on_player_created,
  function(event)
    local player = game.players[event.player_index]
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
)

script.on_event(
  defines.events.on_gui_click,
  function(event)
    if event.element.name == "settings_button" then
      toggle_mod_settings(game.players[event.player_index])
    end
  end
)
