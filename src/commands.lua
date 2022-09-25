local log = require "log"
local capabilities = require "st.capabilities"
local config = require ("config")
local discovery = require("discovery")

local command_handlers = {}

local function get_shade_state(level)
    local states = { [100] = {state = 'open'}, [0] = {state = 'closed'} }
    local state = states[level]
    if not state then
        state = {state = 'partially_open'}
    end
    return state
end

function command_handlers.handle_added(driver, device)
    local scene_model = discovery.get_model('scene')
    if device.model == scene_model then
      device:emit_event(capabilities.switch.switch.off())        
    end
end

function command_handlers.do_scene(driver, device, command)
    log.info("Sending exec command to "..device.label)
    local hub = assert(driver.hub)
    local success = false
    if hub then
        local id = discovery.extract_id(device.device_network_id)
        success = hub:execute_scene(id)
    end
    if success then
        device:emit_event(capabilities.switch.switch.on())
        device:emit_event(capabilities.switch.switch.off())
    end
    return success
end

function command_handlers.do_shade(driver, device, command)
    log.info("Sending "..command.command.." command to "..device.label)
    local hub = assert(driver.hub)
    local success = false
    local level = nil
    if command.command == 'open' then
        level = 100
    end         
    if command.command == 'close' then
        level = 0
    end
    if command.command == 'setShadeLevel' then
        level = command.args.shadeLevel
    end
    local state = get_shade_state(level)
    if hub then
        local id = discovery.extract_id(device.device_network_id)
        success = hub:move_shade(id, level)
    end
    if success then   
            device:emit_event(capabilities.windowShade.windowShade[state.state]())
            device:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
    else
        log.error("command "..type.." failed")
    end
end

local function retry_enabled_command(name, driver, device, command)
    local retry = config[name:upper()..'_RETRY_DELAY'] 
    if retry then
        local num_retries = config[name:upper()..'_NUM_RETRIES'] or 1
        for i=1,num_retries,1 do
            --log.info("setting up retry of "..name.." command after "..tostring(retry*i).." seconds...")
            --device.thread:call_with_delay(retry*i, function() command_handlers["do_"..name](driver, device, command) end)
        end
    end
    log.info("trying command .. "..name)
    return command_handlers["do_"..name](driver, device, command)
end

function command_handlers.handle_scene_command(driver, device, command)
    log.info("in scene command")
    return retry_enabled_command('scene', driver, device, command)
end

function command_handlers.handle_shade_command(driver, device, command)
    log.info("in shade command")
    return retry_enabled_command('shade', driver, device, command)
end

function command_handlers.handle_refresh(driver)
    log.info("Refreshing shades...")
    local shade_model = discovery.get_model('shade')

    local hub = assert(driver.hub)
    local shades, rooms, scenes = hub:update()
    if shades and next(shades) ~= nil then
        local devices = driver:get_devices()
        for _, each in ipairs(devices) do
            if shade_model == each.model then
                local id = discovery.extract_id(each.device_network_id)
                local level = assert(shades[id]).position
                local state = get_shade_state(level)
                if(each:get_latest_state('main', 'windowShade', 'windowShade') ~= state.state) then
                    each:emit_event(capabilities.windowShade.windowShade[state.state]())
                end
                if(each:get_latest_state('main', 'windowShadeLevel', 'shadeLevel') ~= level) then
                    each:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
                end        
            end
        end
    end
end

return command_handlers