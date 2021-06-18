local STATUS_NAME = {
  [defines.entity_status.working] = "entity-status.working",
  [defines.entity_status.disabled] = "entity-status.disabled",
  [defines.entity_status.marked_for_deconstruction] = "entity-status.marked-for-deconstruction",
}
local STATUS_SPRITE = {
  [defines.entity_status.working] = "utility/status_working",
  [defines.entity_status.disabled] = "utility/status_not_working",
  [defines.entity_status.marked_for_deconstruction] = "utility/status_not_working",
}

function on_built_scanner(entity, event)
  local scanner = {
    x = 0,
    y = 0,
    width = 64,
    height = 64,
  }
  local tags = event.tags
  if event.source and event.source.valid then
    -- Copy settings from clone
    tags = util.table.deepcopy(global.scanners[event.source.unit_number])
  end
  if tags then
    -- Copy settings from blueprint tags
    scanner.x = tags.x
    scanner.x_signal = tags.x_signal
    scanner.y = tags.y
    scanner.y_signal = tags.y_signal
    scanner.width = tags.width
    scanner.width_signal = tags.width_signal
    scanner.height = tags.height
    scanner.height_signal = tags.height_signal
  end
  scanner.entity = entity
  global.scanners[entity.unit_number] = scanner
  script.register_on_entity_destroyed(entity)
  scan_resources(scanner)
end

function destroy_gui(gui)
  -- Destroy dependent gui
  local screen = gui.gui.screen
  if gui.name == "recursive-blueprints-scanner" and screen["recursive-blueprints-signal"] then
    screen["recursive-blueprints-signal"].destroy()
  end
  -- Destroy gui
  gui.destroy()
  reset_scanner_gui_style(screen)
end

-- Turn off highlighted scanner button
function reset_scanner_gui_style(screen)
  local gui = screen["recursive-blueprints-scanner"]
  if not gui then return end
  local input_flow = gui.children[2].children[3].children[1].children[2]
  for i = 1, 4 do
    input_flow.children[i].children[2].style = "recursive-blueprints-slot"
  end
end

-- Add a titlebar with a drag area and close [X] button
function add_titlebar(gui, caption, close_button_name, close_button_tooltip)
  local titlebar = gui.add{type = "flow"}
  titlebar.drag_target = gui
  titlebar.add{
    type = "label",
    style = "frame_title",
    caption = caption,
    ignored_by_interaction = true,
  }
  local filler = titlebar.add{
    type = "empty-widget",
    style = "draggable_space",
    ignored_by_interaction = true,
  }
  filler.style.height = 24
  filler.style.horizontally_stretchable = true
  if close_button_name then
    titlebar.add{
      type = "sprite-button",
      name = close_button_name,
      style = "frame_action_button",
      sprite = "utility/close_white",
      hovered_sprite = "utility/close_black",
      clicked_sprite = "utility/close_black",
      tooltip = close_button_tooltip,
    }
  end
end

-- Build the scanner gui
function create_scanner_gui(player, entity)
  local scanner = global.scanners[entity.unit_number]

  -- Destroy any old versions
  if player.gui.screen["recursive-blueprints-scanner"] then
    player.gui.screen["recursive-blueprints-scanner"].destroy()
  end

  -- Heading
  local gui = player.gui.screen.add{
    type = "frame",
    name = "recursive-blueprints-scanner",
    direction = "vertical",
    tags = {["recursive-blueprints-id"] = entity.unit_number}
  }
  gui.auto_center = true
  add_titlebar(gui, entity.localised_name, "recursive-blueprints-close", {"gui.close-instruction"})
  local inner_frame = gui.add{
    type = "frame",
    style = "entity_frame",
    direction = "vertical",
  }

  -- Status indicator
  local status_flow = inner_frame.add{
    type = "flow",
    style = "status_flow",
  }
  status_flow.style.vertical_align = "center"
  status_flow.add{
    type = "sprite",
    style = "status_image",
    sprite = STATUS_SPRITE[entity.status],
  }
  status_flow.add{
    type = "label",
    caption = {STATUS_NAME[entity.status]},
  }
  local preview_frame = inner_frame.add{
    type = "frame",
    style = "entity_button_frame",
  }
  local preview = preview_frame.add{
    type = "entity-preview",
  }
  preview.entity = entity
  preview.style.height = 148
  preview.style.horizontally_stretchable = true

  -- Scan area
  local main_flow = inner_frame.add{
    type = "flow",
  }
  local left_flow = main_flow.add{
    type = "flow",
    direction = "vertical",
  }
  left_flow.style.right_margin = 8
  left_flow.add{
    type = "label",
    style = "heading_3_label",
    caption = {"description.scan-area"},
  }
  local input_flow = left_flow.add{
    type = "flow",
    direction = "vertical",
  }
  input_flow.style.horizontal_align = "right"

  -- X button and label
  local x_flow = input_flow.add{
    type = "flow",
  }
  x_flow.style.vertical_align = "center"
  x_flow.add{
    type = "label",
    caption = {"", {"description.x-offset"}, ":"}
  }
  x_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-x"
  }

  -- Y button and label
  local y_flow = input_flow.add{
    type = "flow",
  }
  y_flow.style.vertical_align = "center"
  y_flow.add{
    type = "label",
    caption = {"", {"description.y-offset"}, ":"}
  }
  y_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-y"
  }

  -- Width button and label
  local width_flow = input_flow.add{
    type = "flow",
  }
  width_flow.style.vertical_align = "center"
  width_flow.add{
    type = "label",
    caption = {"", {"gui-map-generator.map-width"}, ":"}
  }
  width_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-width"
  }

  -- Height button and label
  local height_flow = input_flow.add{
    type = "flow",
  }
  height_flow.style.vertical_align = "center"
  height_flow.add{
    type = "label",
    caption = {"", {"gui-map-generator.map-height"}, ":"}
  }
  height_flow.add{
    type = "sprite-button",
    style = "recursive-blueprints-slot",
    name = "recursive-blueprints-scanner-height"
  }

  -- Minimap
  local minimap_frame = main_flow.add{
    type = "frame",
    style = "entity_button_frame",
  }
  minimap_frame.style.size = 256
  minimap_frame.style.vertical_align = "center"
  minimap_frame.style.horizontal_align = "center"
  local minimap = minimap_frame.add{
    type = "minimap",
    surface_index = entity.surface.index,
    force = entity.force.name,
    position = entity.position,
  }
  minimap.style.minimal_width = 16
  minimap.style.minimal_height = 16
  minimap.style.maximal_width = 256
  minimap.style.maximal_height = 256

  inner_frame.add{type = "line"}

  -- Output signals
  inner_frame.add{
    type = "label",
    style = "heading_3_label",
    caption = {"description.output-signals"},
  }
  local scroll_pane = inner_frame.add{
    type = "scroll-pane",
    style = "recursive-blueprints-scroll",
    direction = "vertical",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto",
  }
  scroll_pane.style.maximal_height = 164
  local scroll_frame = scroll_pane.add{
    type = "frame",
    style = "recursive-blueprints-scroll-frame",
    direction = "vertical",
  }
  local slots = scanner.entity.prototype.item_slot_count
  for i = 1, slots, 10 do
    local row = scroll_frame.add{
      type = "flow",
      style = "packed_horizontal_flow",
    }
    for j = 0, 9 do
      if i+j <= slots then
        row.add{
          type = "sprite-button",
          style = "recursive-blueprints-output",
        }
      end
    end
  end

  -- Display current values
  update_scanner_gui(gui)
  return gui
end

-- Build the "select a signal or constant" gui
function create_signal_gui(element)
  local screen = element.gui.screen
  local primary_gui = element.parent.parent.parent.parent.parent.parent
  local id = primary_gui.tags["recursive-blueprints-id"]
  local scanner = global.scanners[id]
  local field = element.name:sub(30)
  local target = scanner[field.."signal"] or {}

  -- Highlight the button that opened the gui
  element.style = "recursive-blueprints-slot-selected"

  -- Destroy any old version
  if screen["recursive-blueprints-signal"] then
    screen["recursive-blueprints-signal"].destroy()
  end

  -- Heading
  local gui = screen.add{
    type = "frame",
    name = "recursive-blueprints-signal",
    direction = "vertical",
    tags = {
      ["recursive-blueprints-id"] = id,
      ["recursive-blueprints-field"] = field,
    }
  }
  gui.auto_center = true
  add_titlebar(gui, {"gui.select-signal"}, "recursive-blueprints-close")
  local inner_frame = gui.add{
    type = "frame",
    style = "inside_shallow_frame",
    direction = "vertical",
  }

  -- Add tab bar, but don't add tabs until we know which one is selected
  local scroll_pane = inner_frame.add{
    type = "scroll-pane",
    style = "naked_scroll_pane",
    direction = "vertical",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto",
  }
  scroll_pane.style.maximal_height = 132
  local tab_bar = scroll_pane.add{
    type = "frame",
    style = "recursive-blueprints-scroll-frame2",
    direction = "vertical",
  }

  -- Open the signals tab if nothing is selected
  local selected_tab = 1
  for i = 1, #global.groups do
    if global.groups[i].name == "signals" then
      selected_tab = i
    end
  end

  -- Signals are stored in a tabbed pane
  local tabbed_pane = inner_frame.add{
    type = "tabbed-pane",
    style = "recursive-blueprints-tabbed-pane",
  }
  tabbed_pane.style.bottom_margin = 4
  for _, group in pairs(global.groups) do
    -- We can't display images in tabbed-pane tabs,
    -- so make them invisible and use fake image tabs instead.
    local tab = tabbed_pane.add{
      type = "tab",
      style = "recursive-blueprints-invisible-tab",
    }
    -- Add scrollbars in case there are too many signals
    local scroll_pane = tabbed_pane.add{
      type = "scroll-pane",
      style = "recursive-blueprints-scroll",
      direction = "vertical",
      horizontal_scroll_policy = "never",
      vertical_scroll_policy = "auto",
    }
    scroll_pane.style.height = 364
    local scroll_frame = scroll_pane.add{
      type = "frame",
      style = "recursive-blueprints-scroll-frame",
      direction = "vertical",
    }
    -- Add signals
    for i = 1, #group.subgroups do
      for j = 1, #group.subgroups[i], 10 do
        local row = scroll_frame.add{
          type = "flow",
          style = "packed_horizontal_flow",
        }
        for k = 0, 9 do
          if j+k <= #group.subgroups[i] then
            local signal = group.subgroups[i][j+k]
            local button = row.add{
              type = "sprite-button",
              style = "recursive-blueprints-filter",
              sprite = get_signal_sprite(signal),
              tooltip = {"",
                "[font=default-bold][color=255,230,192]",
                get_localised_name(signal),
                "[/color][/font]",
              }
            }
            if signal.type == target.type and signal.name == target.name then
              -- This is the selected signal!
              selected_tab = i
              button.style = "recursive-blueprints-filter-selected"
              scroll_pane.scroll_to_element(button)
            end
          end
        end
      end
    end
    -- Add the invisible tabs and visible signals to the tabbed-pane
    tabbed_pane.add_tab(tab, scroll_pane)
  end
  if #tabbed_pane.tabs >= 1 then
    tabbed_pane.selected_tab_index = selected_tab
  end

  -- Fake tab buttons with images
  for i = 1, #global.groups, 6 do
    local row = tab_bar.add{
      type = "flow",
      style = "packed_horizontal_flow",
    }
    for j = 0, 5 do
      if i+j <= #global.groups then
        local name = global.groups[i+j].name
        local button = row.add{
          type = "sprite-button",
          style = "recursive-blueprints-tab-button",
          name = "recursive-blueprints-tab-button-" .. (i+j),
          tooltip = {"item-group-name." .. name},
        }
        if game.is_valid_sprite_path("item-group/" .. name) then
          button.sprite = "item-group/" .. name
        else
          button.caption = {"item-group-name." .. name}
        end
        -- Highlight selected tab
        if i+j == selected_tab then
          if j == 0 then
            button.style = "recursive-blueprints-tab-button-left"
          elseif j == 5 then
            button.style = "recursive-blueprints-tab-button-right"
          else
            button.style = "recursive-blueprints-tab-button-selected"
          end
          button.parent.parent.parent.scroll_to_element(button)
        end
      end
    end
  end

  -- Set a constant
  add_titlebar(gui, {"gui.or-set-a-constant"})
  local inner_frame = gui.add{
    type = "frame",
    style = "entity_frame",
    direction = "horizontal",
  }
  inner_frame.style.vertical_align = center
  local textfield = inner_frame.add{
    type = "textfield",
    name = "recursive-blueprints-constant",
    numeric = true,
    allow_negative = (field == "x" or field == "y"),
  }
  textfield.style.width = 83
  textfield.style.right_margin = 30
  textfield.style.horizontal_align = "center"
  if not scanner[field.."_signal"] then
    textfield.text = tostring(scanner[field])
  end
  inner_frame.add{
    type = "button",
    style = "recursive-blueprints-set-button",
    name = "recursive-blueprints-set-constant",
    caption = {"gui.set"},
  }

  return gui
end

-- Copy constant value from signal gui to scanner gui
function set_scanner_value(player_index, element)
  local screen = element.gui.screen
  local gui = screen["recursive-blueprints-scanner"]
  if not gui then return end
  reset_scanner_gui_style(screen)
  local scanner = global.scanners[gui.tags["recursive-blueprints-id"]]
  local key = element.parent.parent.tags["recursive-blueprints-field"]
  local value = tonumber(element.parent.children[1].text) or 0

  -- Out of bounds check
  if value > 2000000 then value = 2000000 end
  if value < -2000000 then value = -2000000 end

  -- Limit width/height to 999 for better performance
  if key == "width" or key == "height" then
    if value < 0 then value = 0 end
    if value > 999 then value = 999 end
  end

  -- Run a scan if the area has changed
  if scanner[key] ~= value then
    scanner[key] = value
    scan_resources(scanner)
  end

  -- The user might have changed a signal without changing the area,
  -- so always refresh the gui.
  update_scanner_gui(gui)

  -- Close signal gui
  element.parent.parent.destroy()
end

-- Switch tabs
function set_signal_gui_tab(element, index)
  local tab_bar = element.parent.parent
  -- Un-highlight old tab button
  for i = 1, #tab_bar.children do
    for j = 1, #tab_bar.children[i].children do
      tab_bar.children[i].children[j].style = "recursive-blueprints-tab-button"
    end
  end
  -- Highlight new tab button
  local column = index % 6
  if column == 1 then
    element.style = "recursive-blueprints-tab-button-left"
  elseif column == 0 then
    element.style = "recursive-blueprints-tab-button-right"
  else
    element.style = "recursive-blueprints-tab-button-selected"
  end
  -- Show new tab content
  tab_bar.parent.parent.children[2].selected_tab_index = index
end

-- Populate gui with the latest data
function update_scanner_gui(gui)
  local scanner = global.scanners[gui.tags["recursive-blueprints-id"]]
  if not scanner then return end
  if not scanner.entity.valid then return end

  -- Update area dimensions
  local input_flow = gui.children[2].children[3].children[1].children[2]
  set_slot_button(input_flow.children[1].children[2], scanner.x, scanner.x_signal)
  set_slot_button(input_flow.children[2].children[2], scanner.y, scanner.y_signal)
  set_slot_button(input_flow.children[3].children[2], scanner.width, scanner.width_signal)
  set_slot_button(input_flow.children[4].children[2], scanner.height, scanner.height_signal)

  -- Update minimap
  local x = scanner.x
  local y = scanner.y
  if settings.global["recursive-blueprints-area"].value == "corner" then
    -- Convert from top left corner to center
    x = x + math.floor(scanner.width/2)
    y = y + math.floor(scanner.width/2)
  end
  local minimap = gui.children[2].children[3].children[2].children[1]
  minimap.position = {
    scanner.entity.position.x + x,
    scanner.entity.position.y + y,
  }
  local largest = math.max(scanner.width, scanner.height)
  if largest == 0 then
    largest = 32
  end
  minimap.zoom = 256 / largest
  minimap.style.natural_width = scanner.width / largest * 256
  minimap.style.natural_height = scanner.height / largest * 256

  update_scanner_output(gui.children[2].children[6].children[1], scanner.entity)
end

-- Display all constant-combinator output signals in the gui
function update_scanner_output(output_flow, entity)
  local behavior = entity.get_control_behavior()
  for i = 1, entity.prototype.item_slot_count do
    -- 10 signals per row
    local row = math.ceil(i / 10)
    local col = (i-1) % 10 + 1
    local button = output_flow.children[row].children[col]
    local signal = behavior.get_signal(i)
    if signal and signal.signal and signal.signal.name then
      -- Display signal and value
      button.number = signal.count
      button.sprite = get_signal_sprite(signal.signal)
      button.tooltip = {"",
       "[font=default-bold][color=255,230,192]",
       {signal.signal.type .. "-name." .. signal.signal.name},
       ":[/color][/font] ",
       util.format_number(signal.count),
      }
    else
      -- Display empty slot
      button.number = nil
      button.sprite = nil
      button.tooltip = ""
    end
  end
end

-- Format data for the signal-or-number button
function set_slot_button(button, value, signal)
  if signal then
    button.caption = ""
    button.style.natural_width = 40
    button.sprite = get_signal_sprite(signal)
    button.tooltip = {"",
      "[font=default-bold][color=255,230,192]",
      get_localised_name(signal),
      "[/color][/font]",
    }
  else
    button.caption = format_amount(value)
    button.style.natural_width = button.caption:len() * 12 + 4
    button.sprite = nil
    button.tooltip = {"gui.constant-number"}
  end
end

-- Scan the area for resources
function scan_resources(scanner)
  if not scanner then return end
  if not scanner.entity.valid then return end
  local resources = {item = {}, fluid = {}}
  local p = scanner.entity.position
  local force = scanner.entity.force
  local surface = scanner.entity.surface
  local x = scanner.x
  local y = scanner.y
  local blacklist = {}

  -- Align to grid
  if scanner.width % 2 ~= 0 then x = x + 0.5 end
  if scanner.height % 2 ~= 0 then y = y + 0.5 end

  if settings.global["recursive-blueprints-area"].value == "corner" then
    -- Convert from top left corner to center
    x = x + math.floor(scanner.width/2)
    y = y + math.floor(scanner.width/2)
  end

  -- Subtract 1 pixel from the edges to avoid tile overlap
  local x1 = p.x + x - scanner.width/2 + 1/256
  local x2 = p.x + x + scanner.width/2 - 1/256
  local y1 = p.y + y - scanner.height/2 - 1/256
  local y2 = p.y + y + scanner.height/2 - 1/256

  -- Search one chunk at a time
  for x = x1, math.ceil(x2 / 32) * 32, 32 do
    for y = y1, math.ceil(y2 / 32) * 32, 32 do
      local chunk_x = math.floor(x / 32)
      local chunk_y = math.floor(y / 32)
      -- Chunk must be visible
      if force.is_chunk_charted(surface, {chunk_x, chunk_y}) then
        local left = chunk_x * 32
        local right = left + 32
        local top = chunk_y * 32
        local bottom = top + 32
        if left < x1 then left = x1 end
        if right > x2 then right = x2 end
        if top < y1 then top = y1 end
        if bottom > y2 then bottom = y2 end
        local area = {{left, top}, {right, bottom}}
        count_resources(surface, area, resources, blacklist)
      end
    end
  end

  -- Copy resources to combinator output
  local behavior = scanner.entity.get_control_behavior()
  local index = 1
  for type, resource in pairs(resources) do
    for name, count in pairs(resource) do
      -- Avoid int32 overflow
      if count > 2147483647 then count = 2147483647 end
      if count ~= 0 then
        behavior.set_signal(index, {signal={type=type, name=name}, count=count})
        index = index + 1
      end
    end
  end
  -- Set the remaining output slots to nil
  local max = scanner.entity.prototype.item_slot_count
  while index <= max do
    behavior.set_signal(index, nil)
    index = index + 1
  end
end

-- Count the resources in a chunk
function count_resources(surface, area, resources, blacklist)
  local result = surface.find_entities_filtered{
    area = area,
    force = "neutral",
  }
  for _, resource in pairs(result) do
    local hash = pos_hash(resource, 0, 0)
    local prototype = resource.prototype
    if blacklist[hash] then
      -- We already counted this
    elseif resource.type == "cliff" and global.cliff_explosives then
      -- Cliff explosives
      resources.item["cliff-explosives"] = (resources.item["cliff-explosives"] or 0) - 1
    elseif resource.type == "resource" then
      -- Mining drill resources
      local type = prototype.mineable_properties.products[1].type
      local name = prototype.mineable_properties.products[1].name
      local amount = resource.amount
      if prototype.infinite_resource then
        amount = 1
      end
      resources[type][name] = (resources[type][name] or 0) + amount
    elseif (resource.type == "tree" or resource.type == "fish" or prototype.count_as_rock_for_filtered_deconstruction)
    and prototype.mineable_properties.minable
    and prototype.mineable_properties.products then
      -- Trees, fish, rocks
      for _, product in pairs(prototype.mineable_properties.products) do
        local amount = product.amount
        if product.amount_min and product.amount_max then
          amount = (product.amount_min + product.amount_max) / 2
          amount = amount * product.probability
        end
        resources[product.type][product.name] = (resources[product.type][product.name] or 0) + amount
      end
    end
    -- Mark as counted
    blacklist[hash] = true
  end
  -- Water
  resources.fluid["water"] = (resources.fluid["water"] or 0) + surface.count_tiles_filtered{
    area = area,
    collision_mask = "water-tile",
  }
end

function get_signal_sprite(signal)
  if not signal.name then return end
  if signal.type == "item" and game.item_prototypes[signal.name] then
    return "item/" .. signal.name
  elseif signal.type == "fluid" and game.fluid_prototypes[signal.name] then
    return "fluid/" .. signal.name
  elseif signal.type == "virtual" and game.virtual_signal_prototypes[signal.name] then
    return "virtual-signal/" .. signal.name
  else
    return "virtual-signal/signal-unknown"
  end
end

function get_localised_name(signal)
  if not signal.type or not signal.name then return "" end
  if signal.type == "item" then
    if game.item_prototypes[signal.name] then
      return game.item_prototypes[signal.name].localised_name
    else
      return {"item-name." .. signal.name}
    end
  elseif signal.type == "fluid" then
    if game.fluid_prototypes[signal.name] then
      return game.fluid_prototypes[signal.name].localised_name
    else
      return {"fluid-name." .. signal.name}
    end
  elseif signal.type == "virtual" then
    if game.virtual_signal_prototypes[signal.name] then
      return game.virtual_signal_prototypes[signal.name].localised_name
    else
      return {"virtual-signal-name." .. signal.name}
    end
  end
  return ""
end

function format_amount(amount)
  if amount >= 1000000000 then
    return math.floor(amount / 1000000000) .. "G"
  elseif amount >= 1000000 then
    return math.floor(amount / 1000000) .. "M"
  elseif amount >= 1000 then
    return math.floor(amount / 1000) .. "k"
  elseif amount > -1000 then
    return amount
  elseif amount > -1000000 then
    return math.ceil(amount / 1000) .. "k"
  elseif amount > -1000000000 then
    return math.ceil(amount / 1000000) .. "M"
  else
    return math.ceil(amount / 1000000000) .. "G"
  end
end