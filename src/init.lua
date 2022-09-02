local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"

local discovery = require('discovery')
local commands = require('commands')
local lifecycles = require('lifecycles')

local driver = Driver("Hunter Douglas Platinum Shades", {
    discovery = discovery.start,
    lifecycle_handlers = lifecycles,
    supported_capabilities = {
        capabilities.switch,
        capabilities.windowShade,
        capabilities.windowShadeLevel,
        capabilities.refresh
    },    
    capability_handlers = {
      [capabilities.windowShade.ID] = {
        [capabilities.windowShade.commands.open.NAME] = commands.handle_shade_command,
        [capabilities.windowShade.commands.close.NAME] = commands.handle_shade_command,
      },
      [capabilities.windowShadeLevel.ID] = {
        [capabilities.windowShadeLevel.commands.setShadeLevel.NAME] = commands.handle_shade_command,
      },
      [capabilities.switch.ID] = {
        [capabilities.switch.commands.on.NAME] = commands.handle_scene_command,
        [capabilities.switch.commands.off.NAME] = commands.handle_scene_command,
      },
      [capabilities.refresh.ID] = {
        [capabilities.refresh.commands.refresh.NAME] = commands.handle_refresh,
      }
    }
  })


--------------------
-- Initialize Driver
driver:run()