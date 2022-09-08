local config = {}
-- device info
-- NOTE: In the future this information
-- may be submitted through the Developer
-- Workspace to avoid hardcoded values.
config.SHADE_PROFILE='HDPlatinum.Shade.v1'
config.SCENE_PROFILE='HDPlatinum.Scene.v1'
config.DEVICE_TYPE='LAN'
config.SCHEDULE_PERIOD=15
config.KEEP_ALIVE_PERIOD=300
config.MANUFACTURER='Hunter Douglas' 
config.MODEL='Platinum'
config.MAX_ID=10000
config.UPDATE_MAX_FREQUENCY = 10
config.SCENE_RETRY_DELAY = 5
config.SCENE_FILTER = ''
config.SHADE_FILTER = ''
return config