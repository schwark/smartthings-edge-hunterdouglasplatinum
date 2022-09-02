local log = require "log"
local config = require("config")
local socket = require('socket')
local PlatinumGateway = require("hdplatinum")
local utils = require('st.utils')
local discovery = {}

function discovery.get_model(type)
  return config.MODEL..' '..utils.pascal_case(type)
end

function discovery.get_network_id(type, id)
  return utils.screaming_snake_case(discovery.get_model(type)..' '..id)
end

function discovery.extract_id(network_id)
  return network_id:match('%s(%d+)$')
end

local function create_device(driver, device)
  log.info('===== Creating device for '..device.type..' '..device.name..'...')

  local model = discovery.get_model(device.type)
  local network_id = discovery.get_network_id(device.type, device.id)
  -- device metadata table
  local metadata = {
    type = config.DEVICE_TYPE,
    device_network_id = network_id,
    label = device.name,
    profile = config[device.type:upper()..'_PROFILE'],
    manufacturer = config.MANUFACTURER,
    model = model,
    vendor_provided_label = network_id
  }
  return driver:try_create_device(metadata)
end

function discovery.start(driver, opts, cons)
  local hub = PlatinumGateway()
 if(hub:discover()) then
      log.info('===== Platinum Gateway found at: '..hub.ip)
      local shades, rooms, scenes = hub:update()
      if shades then
        for id, shade in pairs(shades) do
          local meta = {id = id, name = shade.name, type = 'Shade'}
          create_device(driver, meta)
          break
        end
      end
      if scenes then
        for id, scene in pairs(scenes) do
          local meta = {id = id, name = scene.name, type = 'Scene'}
          create_device(driver, meta)
          break
        end
      end
      hub:close()
    else
      log.error('===== Platinum Gateway not found')
    end
end

return discovery