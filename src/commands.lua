local log = require "log"
local capabilities = require "st.capabilities"
local PlatinumGateway = require("hdplatinum")
local discovery = require("discovery")

local command_handlers = {}

function command_handlers.get_hub(driver, device)
    local hub = device:get_field("hub")
    if not hub then
        log.info("initializing hub device "..device.label)
        hub = PlatinumGateway()
        local hub_ip = hub:discover()            
        if hub_ip then
            local devices = driver:get_devices()
            for i, each in ipairs(devices) do
                each:set_field("hub", hub)
            end
        else
            hub = nil
            log.error("unable to initialize hub")
        end
    end
    return hub
end

local function get_shade_state(level)
    local states = { [100] = {state = 'open'}, [0] = {state = 'closed'} }
    local state = states[level]
    if not state then
        state = {state = 'partially_open'}
    end
    return state
end

function command_handlers.handle_scene_command(driver, device, command)
    log.info("Sending exec command to "..device.label)
    local hub = assert(command_handlers.get_hub(driver, device))
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

function command_handlers.handle_shade_command(driver, device, command)
    log.info("Sending "..command.command.." command to "..device.label)
    local hub = assert(command_handlers.get_hub(driver, device))
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

function command_handlers.handle_refresh(driver, device)
    log.info("Sending refresh command to "..device.label)
    local shade_model = discovery.get_model('shade')
    local scene_model = discovery.get_model('scene')

    if(shade_model == device.model) then
        local hub = assert(command_handlers.get_hub(driver, device))
        if not hub:should_update() then
            log.info("Update not needed right now...")
            return
        end
        local shades, rooms, scenes = hub:update()
        if shades then
            local devices = driver:get_devices()
            for _, each in ipairs(devices) do
                if shade_model == each.model then
                    local id = discovery.extract_id(each.device_network_id)
                    log.info("shade id is "..(id or "nil").." for network id "..each.device_network_id)
                    local level = assert(shades[id]).position
                    local state = get_shade_state(level)
                    each:emit_event(capabilities.windowShade.windowShade[state.state]())
                    each:emit_event(capabilities.windowShadeLevel.shadeLevel(level))
                end
            end
        else
            log.error("refresh failed")
        end
    else
        -- scene device
        assert(device.model == scene_model)
        device:emit_event(capabilities.switch.switch.off())
    end
end

return command_handlers