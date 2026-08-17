-- Full simulation of the injected game_frontend_hud.lua in stock Lua 5.1
local INJECTED = arg[1] or "../dist_test/game_frontend_hud.lua"
local CHUNK_FILE = arg[2] or "../dist_test/chunks/c01.lua"
local VERBOSE = arg[3] == "--verbose"

local pass, fail = 0, 0
local function check(name, cond, extra)
  if cond then pass = pass + 1; print("  [PASS] " .. name)
  else fail = fail + 1; print("  [FAIL] " .. name .. " " .. tostring(extra)) end
end

------------------------------------------------------------------
-- fake game environment
------------------------------------------------------------------
local tickFn = nil

_G.slua = {
  isValid = function() return true end,
  setTickFunction = function(f) tickFn = f end,
}

-- advance fake clock on every os.time call (1 poll per tick)
local fakeTime = 0
os.time = function() fakeTime = fakeTime + 1; return fakeTime end

-- stub io.open: key.txt returns a fake key, everything else real
local realOpen = io.open
io.open = function(p, m)
  if type(p) == "string" and p:match("key%.txt$") then
    return {
      read = function() return "testkey123" end,
      write = function() return true end,
      flush = function() return true end,
      close = function() return true end,
    }
  end
  return realOpen(p, m)
end

-- minimal pure-Lua JSON parser for the harness stubs
local function jsonDecode(s)
  local pos, len = 1, #s
  local function skipWs()
    while pos <= len and string.find(" \t\r\n", string.sub(s, pos, pos), 1, true) do pos = pos + 1 end
  end
  local function parseValue()
    skipWs()
    local c = string.sub(s, pos, pos)
    if c == "{" then
      pos = pos + 1
      local t = {}
      skipWs()
      if string.sub(s, pos, pos) == "}" then pos = pos + 1 return t end
      while true do
        skipWs()
        if string.sub(s, pos, pos) ~= '"' then return nil end
        pos = pos + 1
        local key = ""
        while pos <= len and string.sub(s, pos, pos) ~= '"' do
          key = key .. string.sub(s, pos, pos)
          pos = pos + 1
        end
        pos = pos + 1
        skipWs()
        if string.sub(s, pos, pos) ~= ":" then return nil end
        pos = pos + 1
        local v = parseValue()
        if v == nil then return nil end
        t[key] = v
        skipWs()
        local sep = string.sub(s, pos, pos)
        pos = pos + 1
        if sep == "}" then return t end
        if sep ~= "," then return nil end
      end
    elseif c == "[" then
      pos = pos + 1
      local t = {}
      skipWs()
      if string.sub(s, pos, pos) == "]" then pos = pos + 1 return t end
      local n = 0
      while true do
        n = n + 1
        local v = parseValue()
        if v == nil then return nil end
        t[n] = v
        skipWs()
        local sep = string.sub(s, pos, pos)
        pos = pos + 1
        if sep == "]" then return t end
        if sep ~= "," then return nil end
      end
    elseif c == '"' then
      pos = pos + 1
      local parts = {}
      while pos <= len and string.sub(s, pos, pos) ~= '"' do
        local ch = string.sub(s, pos, pos)
        if ch == "\\" then
          pos = pos + 1
          local esc = string.sub(s, pos, pos)
          if esc == "n" then ch = "\n" elseif esc == "t" then ch = "\t" elseif esc == "r" then ch = "\r" else ch = esc end
        end
        parts[#parts + 1] = ch
        pos = pos + 1
      end
      pos = pos + 1
      return table.concat(parts)
    elseif c == "t" then pos = pos + 4 return true
    elseif c == "f" then pos = pos + 5 return false
    elseif c == "n" then pos = pos + 4 return nil
    else
      local num = ""
      while pos <= len and string.find("0123456789.-+eE", string.sub(s, pos, pos), 1, true) do
        num = num .. string.sub(s, pos, pos)
        pos = pos + 1
      end
      return tonumber(num)
    end
  end
  return parseValue()
end

_G.json = { decode = jsonDecode, encode = function() return "" end }

-- fake http manager: validates + serves chunk from disk
local chunkB64 = ""
do
  local f = io.open(CHUNK_FILE, "r")
  if f then chunkB64 = f:read("*all"); f:close() end
end

local httpModule = {
  Post = function(self, url, headers, body, a, cb, t)
    if VERBOSE then print("  [http] " .. url .. " " .. body) end
    if string.find(url, "/validate", 1, true) then
      local resp = '{"valid":true,"session":"sess-test123","allowed_files":["c01.lua"],"expiry":"2099-01-01T00:00:00Z"}'
      cb(true, resp)
    elseif string.find(url, "/g", 1, true) then
      local parsed = jsonDecode(body)
      local fname = parsed and parsed.f or "c01.lua"
      local resp = string.format('{"ok":true,"f":"%s","data":"%s"}', fname, chunkB64)
      if VERBOSE then print("  [http] serving chunk " .. fname .. " (" .. #chunkB64 .. " b64 chars)") end
      cb(true, resp)
    else
      cb(false, nil)
    end
  end,
}

_G.ModuleManager = {
  GetModule = function() return httpModule end,
  CommonModuleConfig = { http_manager = "http" },
}

_G.import = function() return nil end

-- require: modules become ready after 3 attempts (simulates match start)
local gpCalls = 0
local function fakeRequire(name)
  if name == "GameLua.GameCore.Data.GameplayData"
  or name == "GameLua.GameCore.Framework.CharacterBase"
  or name == "combine_class" then
    gpCalls = gpCalls + 1
    if gpCalls >= 3 then return {} end
    return nil
  end
  return nil
end
_G.require = fakeRequire
_G.package = { loaded = {} }

-- GameStatus: "Battle" only once modules are ready (tests the in-match gate)
_G.GameStatus = {
  Battle = 1,
  GetGameStatus = function()
    if gpCalls >= 3 then return 1 end
    return 0
  end,
}

------------------------------------------------------------------
-- load the injected file
------------------------------------------------------------------
local mod
local ok = pcall(function() mod = dofile(INJECTED) end)
check("injected file loads without error", ok)
if not ok then
  print(pass .. " passed, " .. fail .. " failed")
  os.exit(1)
end

local game_frontend_hud = mod
check("module returned", type(game_frontend_hud) == "table")
check("tick function registered by original file", type(tickFn) == "function")

-- anti-dump prelude checks
check("string.dump nuked", rawget(string, "dump") == nil)
local okHook = pcall(function() debug.sethook(function() end, "l") end)
check("debug.sethook blocked", okHook == false)

------------------------------------------------------------------
-- simulate ticks until the payload executes
------------------------------------------------------------------
local function executed()
  return (_G.TEST_LOADED ~= nil) or (_G.AimbotConfig ~= nil) or (_G._NEXTLVL_VER ~= nil)
end

for i = 1, 120 do
  if tickFn then tickFn(0.016) end
  if executed() then break end
end

check("payload executed (marker set)", executed(), "TEST_LOADED=" .. tostring(_G.TEST_LOADED) .. " AimbotConfig=" .. tostring(_G.AimbotConfig))
check("version marker set", _G._NEXTLVL_VER ~= nil, tostring(_G._NEXTLVL_VER))

print("")
print(pass .. " passed, " .. fail .. " failed")
os.exit(fail > 0 and 1 or 0)