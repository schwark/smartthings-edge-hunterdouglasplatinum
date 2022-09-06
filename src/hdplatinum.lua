local cosock = require "cosock"
local socket = cosock.socket
--local socket = require "socket"
local utils = require("st.utils")
local log = require "log"
local math = require ('math')
local config = require('config')

local commands = { 
    update = {{ command = "$dat", sentinel = "upd01-"}},
    move = {{ command = "$pss%(id)s-%(feature)s-%(level)03d%", sentinel = "done"}, {command = "$rls", sentinel = "act00-00-"}},
    exec = {{ command = "$inm%(id)s-", sentinel = "act00-00-"}},
    ping = {{ command = "$dmy", sentinel = "ack"}}
}


local function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

local function interp(s, tab)
    return (s:gsub('%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])',
              function(k, fmt) return tab[k] and ("%"..fmt):format(tab[k]) or
                  '%('..k..')'..fmt end))
end
getmetatable("").__mod = interp

local M = {}; M.__index = M

M.FEATURES = {
    shade = '04'
}

local function constructor(self,o)
    o = o or {}
    o.ip = o.ip or "127.0.0.1"
    o.port = o.port or 522
    o.tcp = socket.tcp()
    o.connected = false
    o.commands = commands
    o.last_refresh = nil
    o.in_command = false
    setmetatable(o, M)
    return o
end
setmetatable(M, {__call = constructor})

local function netbios_encode(name, type)
    local result = ""
    name = string.format("%-15s", name:upper()) .. type
    result = string.char(#name * 2) .. name:gsub(".", function(c) 
        return string.char((string.byte(c)>>4)+string.byte('A')) .. string.char((string.byte(c)&0xF)+string.byte('A'))
    end) .. "\00"
    return result
end

local function netbios_decode(name)
    local result = ""
    for i = 1, #name, 2 do
        local c = name:sub(i,i)
        local d = name:sub(i+1, i+1)
        result = result .. string.char(((string.byte(c)-string.byte('A'))<<4) + ((string.byte(d)-string.byte('A'))&0xF))
    end
    return result
end

local function netbios_lookup(name)
    local WORKSTATION_SERVICE = "\x00"
    local SERVER_SERVICE = "\x20"
    local transaction_id = "\x00\x01"
    local broadcast_header = "\x01\x10"
    local rest_header = "\x00\x01\x00\x00\x00\x00\x00\x00"
    local nbns_prefix = transaction_id .. broadcast_header .. rest_header
    local nbns_suffix = "\x00\x20\x00\x01"
    local broadcast_addr = "255.255.255.255"
    local nbns_port = 137
    local ip = nil
    local response, port
    local udp = socket.udp()
    udp:setoption("broadcast", true)
    udp:setsockname("*",0)
    udp:settimeout(2)
    --udp:setpeername(broadcast_addr, nbns_port)
    local query = nbns_prefix .. netbios_encode(name, SERVER_SERVICE) .. nbns_suffix
    udp:sendto(query, broadcast_addr, nbns_port)
    --udp:send(query)
    response, ip, port = udp:receivefrom()
    if "timeout" ~= ip and "closed" ~= ip then
        log.info("NetBios response received from "..ip)
    else
        ip = nil
    end
    udp:close()
    return ip
end

function M:connect()
    local result = nil
    local err = nil
    if not self.connected then
        log.info("connecting to hub...")
        self.tcp:connect(self.ip, self.port) 
        self.tcp:settimeout(0.001)
        result, err = self:read_till("Shade Controller")
        if not err then
            log.info("connected to hub...")
            self.connected = true
        end
    end
    return self.connected
end

function M:close()
    if self.tcp and self.tcp.close then
        self.tcp:close() 
    end
    self.connected = false
end

function M:discover()
    if self.ip and self.connected then
        return true
    end
    local bridge_name = "PLATLINK-PDBU"
    local hub_ip = netbios_lookup(bridge_name)
    if nil ~= hub_ip then
        log.info("found hub at "..hub_ip)
        if hub_ip ~= self.ip then
            self.connected = false
        end
        self.ip = hub_ip
        self:connect()
        return true
    end
    return false
end

function M:drain()
    if self.connected then
        local s, status, partial
        repeat
            s, status, partial = self.tcp:receive()
            log.info("draining "..(s or "nil"))
        until status
        self.tcp:settimeout(nil)
    end
end

function M:handle_error(err)
    local result = false
    if err and (err == "closed") then
        log.info("handling error "..err)
        self:close()
        log.info("closed socket "..err)
        self:connect()
        log.info("reconnected socket "..err)
        self:drain()
        result = true
        log.info("handled error "..err)
    end
    return result
end

function M:read_till (sentinel)
    local result = ''
    local err = nil
    sentinel = sentinel .. "\n"
    repeat
        --log.info("receiving back...")
            local ok, s, status, partial = pcall(function (tcp)
                return tcp:receive()
            end, self.tcp)
            if ok then
                if status == "closed" then
                    log.info("connxn closed...")
                    err = status 
                else
                    local txt = s or partial
                    if txt then
                        if ("$ctb" ~= txt:sub(3,6)) then
                            --log.info("received "..tostring(txt))
                            result = result .. txt .. "\n"                            
                        end
                    end
                end
            else
                log.error("error in receive "..s)
            end
    until err or ends_with(result, sentinel)
    return result, err
end

function M:send_cmd(command, sentinel)
    log.info("sending "..command)
    local result = nil
    local err = nil
    for i=1,2,1 do
        result, err = self.tcp:send(command)
        log.info("command send error is "..(err or "nil"))
        if not err then
            result, err = self:read_till(sentinel)
            log.info("command read error is "..(err or "nil"))
            if not err then
                break
            end
        end
        if err then
            self:handle_error(err)
        end
    end
    return result, err
end

function M:get_ticket()
    if self.in_command then
        log.info("Waiting for my turn...")
        while self.in_command do
            socket.sleep(0.01)
        end            
        log.info("Got my turn...")
    end
    self.in_command = true
end

function M:close_ticket()
    self.in_command = false
end

function M:cmd(command, params)
    self:get_ticket()
    log.info("platinum cmd sending "..command)
    params = params or {}
    command = self.commands[command] or {}
    if next(command) == nil then
        return
    end
    local result = ""
    for index, value in ipairs(command) do
        local msg = value.command % params
        log.info("here we go - send_cmd "..msg)
        local response, err = self:send_cmd(msg, value.sentinel)
        log.info("send_cmd err is "..(err or "nil"))
        result = result .. (response or "")
    end
    self:close_ticket()
    return result ~= '', result
end

function M:ping()
    return self:cmd("ping")
end

function M:should_update()
    if self.last_refresh and (os.time() - self.last_refresh < config.REFRESH_MAX_FREQUENCY) then
        return false
    end
    return true
end

function M:update()
    local shades = {}
    local rooms = {}
    local scenes = {}
    local parsers = {
        r = function(line)
            local id = line:sub(6,7)
            local name = line:match('-([%w ]+)$')
            rooms[id] = {name = name}
        end,
        m = function(line)
            local id = line:sub(6,7)
            local name = line:match('-([%w ]+)$')
            scenes[id] = {name = name}
        end,
        s = function(line)
            local id = line:sub(6,7)
            local name = line:match('-([%w ]+)$')
            local room_id = line:match('-([%d]+)-')
            if not shades[id] then
                shades[id] = {}
            end
            shades[id].name = name
            shades[id].room = room_id
        end,
        p = function(line)
            local id = line:sub(6,7)
            local feature = line:sub(9,10)
            local state = tonumber(line:sub(-4,-2))
            if not shades[id] then
                shades[id] = {}
            end
            shades[id].position = math.floor(state*100/255+0.5) -- stored as percent
        end
    }

    local success, response = self:cmd("update")
    if response then
        self.last_refresh = os.time()
        for s in response:gmatch("[^\r\n]+") do
            local kind = s:match('^%d $c([rmsp])')
            if(kind) then parsers[kind](s) end
        end
        log.info("finished update...")
    end 

    --log.info(utils.stringify_table(shades, "shades"))
    --log.info(utils.stringify_table(rooms, "rooms"))
    --log.info(utils.stringify_table(scenes, "scenes"))

    return shades, rooms, scenes
end

function M:execute_scene(id)
    return self:cmd("exec", {id = id})
end

function M:move_shade(id, percent, feature)
    log.info("moving shade "..id)
    local feature = feature or self.FEATURES.shade
    local level = math.floor(2.55*tonumber(percent) + 0.5)
    return self:cmd("move", {id = id, level = level, feature = feature})
end

return M