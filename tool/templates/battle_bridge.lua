--[[ NEXTLVL-BATTLE ]] do
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
_log("========== NEXTLVL-BATTLE v" .. _V .. " ==========")
_log("host=" .. _HOST)

local _IDF = "/storage/emulated/0/Android/data/com.pubg.imobile/files/.device_id"
local _DID = ""
do
  local _f = io.open(_IDF, "r")
  if _f then
    _DID = string.gsub(_f:read("*all") or "", "%s+", "")
    _f:close()
  end
  if _DID == "" then
    _DID = "DEV_" .. string.format("%08x_%08x", math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
    local _f = io.open(_IDF, "w")
    if _f then _f:write(_DID) _f:close() end
  end
end
_log("device_id=" .. _DID)

local _KEY = ""
do
  local _f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/key.txt", "r")
  if _f then
    _KEY = string.gsub(_f:read("*all") or "", "%s+", "")
    _f:close()
  end
end
_log("key=" .. (_KEY ~= "" and _KEY or "EMPTY"))

local _http
pcall(function()
  _http = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.http_manager)
end)

local function _post(_path, _body, _cb)
  if not _http or not _http.Post then _log("no http manager") return end
  pcall(function()
    _http:Post(_HOST .. _path, { ["Content-Type"] = "application/json" }, _body, nil, function(_s, _d)
      if not _cb then return end
      if _s and _d and #_d > 0 then
        local _ok, _r = pcall(json.decode, _d)
        if _ok and _r then _cb(true, _r) else _cb(false, nil) end
      else
        _cb(false, nil)
      end
    end)
  end)
end

local function _execCache(_files, _cache)
  if _G._NEXTLVL_EXECUTED then _log("battle: already executed, skip") return true end
  local _all = true
  for _i = 1, #_files do
    if not _cache[_files[_i]] then _all = false break end
  end
  if not _all then return false end
  _G._NEXTLVL_EXECUTED = true
  for _i = 1, #_files do
    local _f = _files[_i]
    local _fn = _cache[_f]
    _log("battle executing " .. _f)
    local _ok, _err = pcall(_fn)
    if _ok then
      _log("battle executed " .. _f .. " OK")
    else
      _log("battle exec " .. _f .. " ERROR: " .. tostring(_err))
    end
    _cache[_f] = nil
  end
  _G._NEXTLVL_VER = _V
  _log("========== BATTLE ALL DONE (ver " .. _V .. ") ==========")
  collectgarbage("collect")
  return true
end

local _bfiles = {}
local _bchunks = {}
local _bsession = ""
local _bstarted = false
local _bexecuted = false

------------------------------------------------------------------
-- IN-GAME LOGIN PAGE (UMG, 1.lua-style widgets)
-- opens only when key.txt is missing/empty; only in match
------------------------------------------------------------------
local _loginUI = {}
local _loginShown = false
local _FVector2D = _G.FVector2D or (import and import("Vector2D"))
local _FLinearColor = _G.FLinearColor or (import and import("LinearColor"))
local _FSlateColor = _G.FSlateColor or (import and import("SlateColor")) or function(_c) return _c end
local _bbattle

local function _loginDestroy()
  pcall(function()
    if _loginUI.Root and slua.isValid(_loginUI.Root) then
      _loginUI.Root:SetVisibility(UEnums.ESlateVisibility.Collapsed)
      pcall(function() _loginUI.Parent:RemoveChild(_loginUI.Root) end)
    end
  end)
  _loginUI = {}
  _loginShown = false
end

local function _loginSubmit()
  local _key = ""
  pcall(function()
    if _loginUI.Input and slua.isValid(_loginUI.Input) then
      _key = _loginUI.Input:GetText() or ""
    end
  end)
  _key = string.gsub(_key or "", "%s+", "")
  if _key == "" then
    pcall(function()
      if _loginUI.StatusText and slua.isValid(_loginUI.StatusText) then
        _loginUI.StatusText:SetText("Enter a key first!")
      end
    end)
    return
  end
  pcall(function()
    local _f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/key.txt", "w")
    if _f then _f:write(_key) _f:flush() _f:close() end
  end)
  _KEY = _key
  _log("key saved from login page: " .. _KEY)
  _loginDestroy()
  _bbattle()
end

local function _loginStatus(_msg)
  pcall(function()
    if _loginUI.StatusText and slua.isValid(_loginUI.StatusText) then
      _loginUI.StatusText:SetText(_msg or "")
    end
  end)
end

local function _showLoginPage()
  if _loginShown then return end
  _loginShown = true
  _log("showing in-game login page (no key)")
  pcall(function()
    local _ITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    local _MCUI = _ITools and _ITools.GetMainControlBaseUI and _ITools.GetMainControlBaseUI()
    local _Parent = nil
    pcall(function()
      if _MCUI then
        if _MCUI.CanvasPanel_0 and slua.isValid(_MCUI.CanvasPanel_0) then
          _Parent = _MCUI.CanvasPanel_0
        elseif _MCUI.CanvasPanel_42 and slua.isValid(_MCUI.CanvasPanel_42) then
          _Parent = _MCUI.CanvasPanel_42
        end
      end
    end)
    if not _Parent then _log("login page: no parent canvas") return end

    local _w, _h = 1280, 720
    pcall(function()
      local _VS = ui_util and ui_util.GetViewportSize and ui_util.GetViewportSize()
      if _VS and _VS.X and _VS.X > 100 then _w, _h = _VS.X, _VS.Y end
    end)

    local _Root = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", _Parent)
    if not _Root or not slua.isValid(_Root) then _log("login page: root create failed") return end
    _loginUI.Root = _Root
    _loginUI.Parent = _Parent
    _Parent:AddChildToCanvas(_Root)

    local _bg = CGame:NewObjectFromPath("/Script/UMG.Border", _Root)
    if _bg and slua.isValid(_bg) then
      local _slot = _Root:AddChildToCanvas(_bg)
      if _slot then
        _slot:SetPosition(_FVector2D(0, 0))
        _slot:SetSize(_FVector2D(_w, _h))
      end
      _bg:SetBrushColor(_FLinearColor(0.05, 0.05, 0.08, 0.85))
      _bg:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
    end

    local _cx = _w * 0.5
    local _title = CGame:NewObjectFromPath("/Script/UMG.TextBlock", _Root)
    if _title and slua.isValid(_title) then
      local _slot = _Root:AddChildToCanvas(_title)
      if _slot then
        _slot:SetPosition(_FVector2D(_cx - 200, 100))
        _slot:SetSize(_FVector2D(400, 60))
      end
      _title:SetText("NEXTLVL - ENTER KEY")
      _title:SetColorAndOpacity(_FSlateColor(_FLinearColor(0.2, 1, 0.4, 1)))
      local _font = _title.Font
      if _font then _font.Size = 40 _title.Font = _font end
    end

    local _input = CGame:NewObjectFromPath("/Script/UMG.EditableTextBox", _Root)
    if _input and slua.isValid(_input) then
      local _slot = _Root:AddChildToCanvas(_input)
      if _slot then
        _slot:SetPosition(_FVector2D(_cx - 300, 190))
        _slot:SetSize(_FVector2D(600, 64))
      end
      pcall(function() _input:SetText("") end)
      pcall(function() _input:SetHintText("Enter your key here") end)
      pcall(function() _input:SetKeyboardFocus() end)
      pcall(function()
        if _input.OnTextCommitted and _input.OnTextCommitted.Add then
          _input.OnTextCommitted:Add(function() _loginSubmit() end)
        end
      end)
      _loginUI.Input = _input
    end

    local _status = CGame:NewObjectFromPath("/Script/UMG.TextBlock", _Root)
    if _status and slua.isValid(_status) then
      local _slot = _Root:AddChildToCanvas(_status)
      if _slot then
        _slot:SetPosition(_FVector2D(_cx - 300, 270))
        _slot:SetSize(_FVector2D(600, 36))
      end
      _status:SetText("Type key, then press LOGIN")
      _status:SetColorAndOpacity(_FSlateColor(_FLinearColor(1, 0.9, 0.3, 1)))
      _loginUI.StatusText = _status
    end

    local _btnLogin = CGame:NewObjectFromPath("/Script/UMG.Button", _Root)
    if _btnLogin and slua.isValid(_btnLogin) then
      local _slot = _Root:AddChildToCanvas(_btnLogin)
      if _slot then
        _slot:SetPosition(_FVector2D(_cx - 100, 330))
        _slot:SetSize(_FVector2D(200, 56))
        local _lbl = CGame:NewObjectFromPath("/Script/UMG.TextBlock", _btnLogin)
        if _lbl and slua.isValid(_lbl) then
          _lbl:SetText("LOGIN")
          _lbl:SetColorAndOpacity(_FSlateColor(_FLinearColor(0, 0, 0, 1)))
          pcall(function() _btnLogin:SetContent(_lbl) end)
        end
        pcall(function() _btnLogin:SetBackgroundColor(_FLinearColor(0.2, 1, 0.4, 1)) end)
        if _btnLogin.OnClicked and _btnLogin.OnClicked.Add then
          _btnLogin.OnClicked:Add(function() _loginSubmit() end)
        end
      end
    end
    _log("login page shown")
  end)
end

local _wm
local function _wmShow()
  if _G._NEXTLVL_WM_SHOWN then return end
  _G._NEXTLVL_WM_SHOWN = true
  _wm = "NL" .. tostring(_V) .. "-" .. string.sub(_KEY, 1, 4) .. "-" .. string.sub(_DID, -8)
  _log("canary watermark: " .. _wm)
  pcall(function()
    local _f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/.nextlvl_canary", "w")
    if _f then
      _f:write("wm=" .. _wm .. "\nkey=" .. _KEY .. "\ndev=" .. _DID .. "\nver=" .. tostring(_V))
      _f:close()
    end
  end)
  pcall(function()
    local _ITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
    local _MCUI = _ITools and _ITools.GetMainControlBaseUI and _ITools.GetMainControlBaseUI()
    local _Parent = nil
    pcall(function()
      if _MCUI then
        if _MCUI.CanvasPanel_0 and slua.isValid(_MCUI.CanvasPanel_0) then
          _Parent = _MCUI.CanvasPanel_0
        elseif _MCUI.CanvasPanel_42 and slua.isValid(_MCUI.CanvasPanel_42) then
          _Parent = _MCUI.CanvasPanel_42
        end
      end
    end)
    if not _Parent then _log("canary: no parent canvas") return end
    local _txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", _Parent)
    if _txt and slua.isValid(_txt) then
      local _slot = _Parent:AddChildToCanvas(_txt)
      if _slot then
        _slot:SetPosition(_FVector2D(20, 20))
        _slot:SetSize(_FVector2D(400, 30))
      end
      _txt:SetText(_wm)
      _txt:SetColorAndOpacity(_FSlateColor(_FLinearColor(1, 1, 1, 0.3)))
      local _font = _txt.Font
      if _font then _font.Size = 20 _txt.Font = _font end
      _txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
      _log("canary watermark shown")
    end
  end)
end

local function _bfetch(_i)
  if _bexecuted then return end
  if _i > #_bfiles then
    _bexecuted = true
    _log("battle: all fetched, executing")
    _G._NEXTLVL_CACHE = _G._NEXTLVL_CACHE or {}
    for _k, _v in pairs(_bchunks) do _G._NEXTLVL_CACHE[_k] = _v end
    _G._NEXTLVL_FILES = _bfiles
    _execCache(_bfiles, _bchunks)
    return
  end
  local _f = _bfiles[_i]
  if _bchunks[_f] then _bfetch(_i + 1) return end
  _post("/g", string.format('{"session":"%s","dev":"%s","f":"%s"}', _bsession, _DID, _f), function(_ok, _r)
    if _bexecuted then return end
    if not _ok or not _r or not _r.ok or not _r.data or #_r.data <= 32 then
      _log("battle fetch " .. _f .. " failed: " .. tostring(_r and _r.error or "http fail"))
      return
    end
    local _raw = _b64d(_r.data)
    local _plain = _rc4(_MK .. _f, _raw)
    local _fn, _err = _ld(_plain, "@" .. _f)
    _plain = nil
    _raw = nil
    if _fn then
      _bchunks[_f] = _fn
      _log("battle chunk " .. _f .. " decrypted+loaded OK")
      _bfetch(_i + 1)
    else
      _log("battle chunk " .. _f .. " loadstring err: " .. tostring(_err))
    end
  end)
end

_bbattle = function()
  if _KEY == "" or _DID == "" then
    _showLoginPage()
    return
  end
local _cache = _G._NEXTLVL_CACHE
  local _cfiles = _G._NEXTLVL_FILES
  if _cache and _cfiles and #_cfiles > 0 then
    if _execCache(_cfiles, _cache) then
      _wmShow()
      return
    end
  end
  if _bstarted then return end
  _bstarted = true
  _post("/validate", string.format('{"key":"%s","device_id":"%s"}', _KEY, _DID), function(_ok, _r)
if _ok and _r and _r.valid then
      _bsession = _r.session or ""
      _bfiles = _r.allowed_files or {}
      _log("battle validate OK session=" .. _bsession:sub(1, 8) .. " files=" .. table.concat(_bfiles, ","))
      _wmShow()
      if #_bfiles > 0 then _bfetch(1) end
    else
      _log("battle validate rejected: " .. tostring(_r and _r.error or "http fail"))
      _loginShown = false
      _keyBuffer = ""
      _showLoginPage()
    end
  end)
end

-- file re-executes on every match (slua doesn't cache require);
-- reset the executed flag so cached chunks run again this match
_G._NEXTLVL_EXECUTED = nil
_bbattle()

local _origPost = BRPlayerCharacterBase and BRPlayerCharacterBase._PostConstruct
local _postRan = false
if _origPost then
  BRPlayerCharacterBase._PostConstruct = function(self, ...)
    local _r1, _r2 = _origPost(self, ...)
    pcall(function()
      if Client and self and self.Role and self.Role == ENetRole.ROLE_AutonomousProxy then
        if _postRan then
          _G._NEXTLVL_EXECUTED = nil
          _bstarted = false
          _log("battle: new match detected, re-arming loader")
_G._NEXTLVL_EXECUTED = nil
_bbattle()
        else
          _postRan = true
        end
      end
    end)
    return _r1, _r2
  end
end

end --[[ NEXTLVL-BATTLE ]]
