local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

local discovery = require('discovery')
local lifecycles = require('lifecycles')
local PlatinumGateway = require("hdplatinum")
local config = require('config')
local commands = require('commands')

local function setup_timer(driver)
  local success = false
  if not driver.driver_state.timer then
    local timer = driver:call_on_schedule(
      config.COMMAND_TICK,
      function ()
        return commands.exec_queued_command(driver)
        --return commands.handle_refresh_command(driver)
      end,
      'exec schedule')
    if(driver.driver_state.timer) then -- someone else got there first
      driver:cancel_timer(timer)
    elseif timer then 
      driver.driver_state.timer = timer
      success = true
    end
  end
  return success
end

local function clear_timer(driver)
  if driver.driver_state.timer then
    driver:cancel_timer(driver.driver_state.timer)
    driver.driver_state.timer = nil
  end
end

local function driver_lifecycle(driver, event)
  if 'shutdown' == event then
    driver:clear_timer()
  end
end

local driver = Driver("Hunter Douglas Platinum Shades", {
    driver_state = {},
    mq = {},
    hub = PlatinumGateway(),
    setup_timer = setup_timer,
    clear_timer = clear_timer,
    discovery = discovery.start,
    driver_lifecycle = driver_lifecycle,
    lifecycle_handlers = lifecycles,
    supported_capabilities = {
        capabilities.switch,
        capabilities.windowShade,
        capabilities.windowShadeLevel,
        capabilities.refresh
    },    
    capability_handlers = {
      [capabilities.windowShade.ID] = {
        [capabilities.windowShade.commands.open.NAME] = commands.add_shade_command,
        [capabilities.windowShade.commands.close.NAME] = commands.add_shade_command,
      },
      [capabilities.windowShadeLevel.ID] = {
        [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = commands.add_shade_command,
      },
      [capabilities.switch.ID] = {
        [capabilities.switch.commands.on.NAME] = commands.add_scene_command,
        [capabilities.switch.commands.off.NAME] = commands.add_scene_command,
      },
      [capabilities.refresh.ID] = {
        [capabilities.refresh.commands.refresh.NAME] = commands.add_refresh_command,
      }
    }
  })

--driver:custom_startup()
--------------------
-- Initialize Driver
driver:run()