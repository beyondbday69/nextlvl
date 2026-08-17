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
return game_frontend_hud


-- By @YargiIDE | Chanel @YARGI_LEAKS