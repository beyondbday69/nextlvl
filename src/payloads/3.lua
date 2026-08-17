--[[
    OPTISKI - Performance-Optimized Skin System
    ==============================================
    Drop-in replacement for skin.lua, designed for low-end Android.
    Same global API (get_skin_id, get_vehicle_skin_id, equip_character_avatar,
    ApplyWeaponSkins, ApplyVehicleSkins, HandlePetLogic, ReadConfigFile, etc.)
    so it can be used standalone or alongside the original skin.lua.

    KEY OPTIMIZATIONS vs skin.lua
    -----------------------------
    1. Multi-rate tickers instead of one 0.1s loop
         - Fast apply  (0.4s) : weapon + outfit skin apply
         - Slow scan   (2.0s) : deadbox scan (was every 0.1s = 20x more)
         - Slow hooks  (5.0s) : kill-counter UI hook (mostly one-shot anyway)
    2. INI file is reparsed only when its mtime changes (was every 0.1s)
    3. AlreadyChangedSet converted to a hash set (O(1) lookup, was O(n))
    4. equip_character_avatar only calls OnRep_BodySlotStateChanged() when
       something actually changed (was called every tick on every slot)
    5. ApplyVehicleSkins no longer calls EnableHighTireLight / UpdateParticle /
       ChangeParticles / ReActivateExhaustParticle every tick. They only run
       when the (vehicle, skin) pair changes.
    6. import("BackpackUtils") cached on first use (was re-imported every tick)
    7. DeadBox_TemperRequest throttled to 2.0s and short-circuits if no kills
       are possible (player dead / not in match)
    8. Kill-counter UI hook check throttled to 5.0s; once installed it
       becomes a no-op
    9. Glider slot pre-add work is now a one-shot per slotSyncData lifetime
   10. Dead-box linear scan of _G.DeadBoxSkins capped at last 32 entries
]]

-- ===================================================================
-- SECTION 1: PER-MATCH GUARD
-- ===================================================================
do
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if pc then
        if _G._AKSKIN_LOADED and _G._AKSKIN_PC == pc then return end
        _G._AKSKIN_PC = pc
        _G._AKSKIN_LOADED = true
        _G.AKSkinLoopStarted = false
    else
        _G._AKSKIN_LOADED = false
    end
end

-- ===================================================================
-- SECTION 2: CONFIG FILE PATH
-- ===================================================================
_G.ConfigFilePath = '/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini'

-- ===================================================================
-- SECTION 3: BASE SKIN ID DEFINITIONS
-- ===================================================================
_G.BaseSkinIDs = {
    Weapons = {
        101001, 101002, 101003, 101004, 101005, 101006, 101007, 101008,
        101009, 101010, 101012, 101101, 101100, 101102, 102001, 102002,
        102003, 102004, 102005, 102007, 102105, 103001, 103002, 103003,
        103004, 103005, 103006, 103007, 103009, 103010, 103100, 103012,
        103102, 103013, 104003, 104004, 104001, 104002, 105001, 105002,
        105010, 108004, 108001, 108002, 108003,
    },
    Outfits = {
        Suit     = 403003,
        Bag      = 501001,
        Helmet   = 502001,
        Parachut = 703001,
        Pet      = 50000,
        Shirt    = 0,
        Hat      = 401003,
        Mask     = 0,
        Glasses  = 0,
        Pants    = 0,
        Shoes    = 0,
        Armor    = 0,
    }
}

_G.OutfitSkins = {
    Suit     = { _G.BaseSkinIDs.Outfits.Suit },
    Bag      = { _G.BaseSkinIDs.Outfits.Bag },
    Helmet   = { _G.BaseSkinIDs.Outfits.Helmet },
    Parachut = { _G.BaseSkinIDs.Outfits.Parachut },
    Pet      = { _G.BaseSkinIDs.Outfits.Pet },
    Shirt    = { _G.BaseSkinIDs.Outfits.Shirt },
    Hat      = { _G.BaseSkinIDs.Outfits.Hat },
    Mask     = { _G.BaseSkinIDs.Outfits.Mask },
    Glasses  = { _G.BaseSkinIDs.Outfits.Glasses },
    Pants    = { _G.BaseSkinIDs.Outfits.Pants },
    Shoes    = { _G.BaseSkinIDs.Outfits.Shoes },
    Armor    = { _G.BaseSkinIDs.Outfits.Armor },
}

-- ===================================================================
-- SECTION 4: WEAPON SKIN MAPPING TABLE
-- ===================================================================
_G.skinIdMappings = {}
for _, id in ipairs(_G.BaseSkinIDs.Weapons) do
    _G.skinIdMappings[id] = { id }
end

-- ===================================================================
-- SECTION 5: VEHICLE DEFINITIONS
-- ===================================================================
_G.VehicleMapDict = {
    UAZ = 1908001,
    Dacia = 1903001,
    Buggy = 1907001,
    Motor = 1901001,
    CoupeRB = 1961001,

    MiradoOpenTop = 1915001,
    MiradoOpenTopB = 1915002,
    MiradoOpenTopC = 1915003,
    MiradoOpenTopD = 1915004,

    MiradoClosedTop = 1914001,
    MiradoClosedTopB = 1914002,
    MiradoClosedTopC = 1914003,
    MiradoClosedTopD = 1914004,
}
_G.VehicleSkinsList = {}
_G.VehicleSkinIndex = {}

-- ===================================================================
-- SECTION 6: EQUIPMENT SLOT TYPES
-- ===================================================================
_G.CustSlotType = {
    ClothesEquipemtSlot   = 5,
    BackpackEquipemtSlot  = 8,
    HelmetEquipemtSlot    = 9,
    ParachuteEquipemtSlot = 11,
    GlideEquipemtSlot     = 15,
    HatEquipemtSlot       = 0,
    MaskEquipemtSlot      = 1,
    GlassesEquipemtSlot   = 2,
    ShirtEquipemtSlot     = 3,
    PantsEquipemtSlot     = 4,
    ShoesEquipemtSlot     = 6,
    ArmorEquipemtSlot     = 14,
    HairEquipemtSlot      = 7,  -- <-- ADD THIS LINE
}


-- ===================================================================
-- SECTION 7: RUNTIME STATE
-- ===================================================================
_G.WeaponSkinIndex       = _G.WeaponSkinIndex or {}
_G.SuitSkin              = 0
_G.BagSkin               = 0
_G.HelmetSkin            = 0
_G.ParachuteSkin         = 0
_G.GliderSkin            = 0
_G.PetSkin               = 0
_G.ShirtSkin             = 0
_G.HatSkin               = 0
_G.MaskSkin              = 0
_G.GlassesSkin           = 0
_G.PantsSkin             = 0
_G.ShoesSkin             = 0
_G.ArmorSkin             = 0
_G.LastBackApplyValue    = 0
_G.LastHelmetApplyValue  = 0
_G.skinIdCache           = {}
_G.skinIdCache2          = {}

-- _G.OutfitMap -- single mirror of all outfit skin IDs, used by the
-- logic.lua-style apply in equip_character_avatar.
_G.OutfitMap             = _G.OutfitMap or {
    Suit = 0, Bag = 0, Helmet = 0, Parachute = 0, Pet = 0,
    Shirt = 0, Hat = 0, Mask = 0, Glasses = 0, Pants = 0, Shoes = 0, Armor = 0,
}
-- Last-applied extra-outfit cache (Hat / Mask / Glasses / Pants / Shoes / Armor / Parachute)
_G.LastEquippedOutfits   = _G.LastEquippedOutfits or {}

-- Cached resolved lookup (weaponID -> resolved skinID), rebuilt only on INI change
_G._ResolvedWeaponSkins  = {}
_G._ResolvedVehicleSkins = {}
_G._SkinDataVersion      = 0

-- Local change-detection cache (for INI selected indices)
local changeDetectionCache = {}

-- Cached import handles
local _BackpackUtils = nil
local _BackpackUtilsTried = false
local function getBackpackUtils()
    if _BackpackUtils then return _BackpackUtils end
    if _BackpackUtilsTried then return nil end
    _BackpackUtilsTried = true
    local ok, mod = pcall(import, "BackpackUtils")
    if ok and mod then _BackpackUtils = mod end
    return _BackpackUtils
end

-- ===================================================================
-- SECTION 8: ASSET DOWNLOAD HELPER
-- ===================================================================
local function downloadSkinAsset(id)
    local pufferManager = require('client.slua.logic.download.puffer.puffer_manager')
    local pufferConst   = require('client.slua.logic.download.puffer_const')
    if pufferManager and pufferConst then
        local currentState = pufferManager.GetState(pufferConst.ENUM_DownloadType.ODPAK, {id})
        if currentState ~= pufferConst.ENUM_DownloadState.Done then
            pufferManager.Download(pufferConst.ENUM_DownloadType.ODPAK, {id})
        end
    end
end
_G.download_item = downloadSkinAsset

-- ===================================================================
-- SECTION 9: SKIN ID RESOLVERS
-- Use the resolved cache so a hot path is one table lookup.
-- ===================================================================
_G.get_skin_id = function(weaponID)
    if not weaponID then return nil end
    local resolved = _G._ResolvedWeaponSkins[weaponID]
    if resolved == nil then
        local selectedIndex = _G.WeaponSkinIndex[weaponID] or 1
        local skinList = _G.skinIdMappings[weaponID]
        if not skinList or not skinList[selectedIndex] then
            resolved = weaponID
        else
            resolved = skinList[selectedIndex]
        end
        _G._ResolvedWeaponSkins[weaponID] = resolved
    end
    if resolved and resolved ~= weaponID then
        if not _G.skinIdCache2[resolved] then
            pcall(_G.download_item, resolved)
            _G.skinIdCache2[resolved] = true
        end
    end
    return resolved
end

_G.get_vehicle_skin_id = function(vehicleID)
    if not vehicleID or vehicleID == 0 then return vehicleID end
    local resolved = _G._ResolvedVehicleSkins[vehicleID]
    if resolved == nil then
        local vehicleStr = tostring(vehicleID)
        local basePrefix = string.sub(vehicleStr, 1, 4)
        local baseTypeID = tonumber(basePrefix .. "001")

        local skinList = _G.VehicleSkinsList[baseTypeID]
        if skinList then
            local idx = _G.VehicleSkinIndex[baseTypeID] or 1
            if idx < 1 then idx = 1 end
            if idx > #skinList then idx = #skinList end
            local skinID = skinList[idx]
            if skinID and skinID > 0 then
                resolved = skinID
            else
                resolved = vehicleID
            end
        else
            resolved = vehicleID
        end
        _G._ResolvedVehicleSkins[vehicleID] = resolved
    end
    if resolved and resolved ~= vehicleID then
        if not _G.skinIdCache2[resolved] then
            if _G.download_item then pcall(_G.download_item, resolved) end
            _G.skinIdCache2[resolved] = true
        end
    end
    return resolved
end

-- Force the resolver caches to be rebuilt (called on INI change).
local function rebuildResolverCaches()
    _G._ResolvedWeaponSkins  = {}
    _G._ResolvedVehicleSkins = {}
end

-- ===================================================================
-- SECTION 10: INI FILE PARSERS  (content-aware, only reparse on change)
-- ===================================================================
local _iniContent    = nil
local _iniEverLoaded = false

_G.LoadSkinDataFromINI = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    local inSkinSection = false
    for line in file:lines() do
        if line:match('%[SKIN_LIST%]') then
            inSkinSection = true
        elseif line:match('%[SELECTED%]') then
            inSkinSection = false
        end
        if inSkinSection and not line:match('^%s*%[') and not line:match('^%s*[#]') then
            local key, valueStr = line:match('([^=]+)=(.+)')
            if key and valueStr then
                key = key:match("^%s*(.-)%s*$")
                local values = {}
                for val in valueStr:gmatch('([^,]+)') do
                    local num = tonumber(val:match("^%s*(.-)%s*$"))
                    if num then table.insert(values, num) end
                end
                if #values > 0 then
                    if _G.OutfitSkins[key] ~= nil then
                        _G.OutfitSkins[key] = values
                    elseif _G.VehicleMapDict[key] ~= nil then
                        local vehicleBaseID = _G.VehicleMapDict[key]
                        _G.VehicleSkinsList[vehicleBaseID] = values
                    elseif tonumber(key) then
                        _G.skinIdMappings[tonumber(key)] = values
                    end
                end
            end
        end
    end
    file:close()
    _G.SuitSkinsMap     = _G.OutfitSkins.Suit
    _G.BagSkinsMap      = _G.OutfitSkins.Bag
    _G.HelmetSkinsMap   = _G.OutfitSkins.Helmet
    _G.ParachutSkinsMap = _G.OutfitSkins.Parachut
    _G.PetSkinsMap      = _G.OutfitSkins.Pet
    _G.ShirtSkinsMap    = _G.OutfitSkins.Shirt
    _G.HatSkinsMap      = _G.OutfitSkins.Hat
    _G.MaskSkinsMap     = _G.OutfitSkins.Mask
    _G.GlassesSkinsMap  = _G.OutfitSkins.Glasses
    _G.PantsSkinsMap    = _G.OutfitSkins.Pants
    _G.ShoesSkinsMap    = _G.OutfitSkins.Shoes
    _G.ArmorSkinsMap    = _G.OutfitSkins.Armor
end
pcall(_G.LoadSkinDataFromINI)

_G.ReadConfigFile = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    local config = {}
    
    for line in file:lines() do
        if line:match('%[SKIN_LIST%]') then break end
        if not line:match('^%s*%[') and not line:match('^%s*[#]') then
            local key, val = line:match('([%w_]+)%s*=%s*([%w]+)')
            if key and val and not line:match(',') then
                if val:lower() == "off" then
                    config[key] = -1
                else
                    config[key] = tonumber(val)
                end
            end
        end
    end
    file:close()

    local function applyOutfitSelection(key, skinMap, globalVarName)
        if config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G[globalVarName] = skinMap and skinMap[config[key] + 1] or 0
            changeDetectionCache[key] = config[key]
        end
    end
    applyOutfitSelection('Suit',     _G.SuitSkinsMap,     'SuitSkin')
    applyOutfitSelection('Bag',      _G.BagSkinsMap,      'BagSkin')
    applyOutfitSelection('Helmet',   _G.HelmetSkinsMap,   'HelmetSkin')
    applyOutfitSelection('Parachute', _G.ParachutSkinsMap, 'ParachuteSkin')
    applyOutfitSelection('Pet',      _G.PetSkinsMap,      'PetSkin')
    applyOutfitSelection('Shirt',    _G.ShirtSkinsMap,    'ShirtSkin')
    applyOutfitSelection('Hat',      _G.HatSkinsMap,      'HatSkin')
    applyOutfitSelection('Mask',     _G.MaskSkinsMap,     'MaskSkin')
    applyOutfitSelection('Glasses',  _G.GlassesSkinsMap,  'GlassesSkin')
    applyOutfitSelection('Pants',    _G.PantsSkinsMap,    'PantsSkin')
    applyOutfitSelection('Shoes',    _G.ShoesSkinsMap,    'ShoesSkin')
    applyOutfitSelection('Armor',    _G.ArmorSkinsMap,    'ArmorSkin')

    -- Mirror every *_Skin into _G.OutfitMap so the logic.lua-style
    -- apply in equip_character_avatar reads a single source of truth.
    _G.OutfitMap.Suit     = _G.SuitSkin
    _G.OutfitMap.Bag      = _G.BagSkin
    _G.OutfitMap.Helmet   = _G.HelmetSkin
    _G.OutfitMap.Parachute = _G.ParachuteSkin
    _G.OutfitMap.Pet      = _G.PetSkin
    _G.OutfitMap.Shirt    = _G.ShirtSkin
    _G.OutfitMap.Hat      = _G.HatSkin
    _G.OutfitMap.Mask     = _G.MaskSkin
    _G.OutfitMap.Glasses  = _G.GlassesSkin
    _G.OutfitMap.Pants    = _G.PantsSkin
    _G.OutfitMap.Shoes    = _G.ShoesSkin
    _G.OutfitMap.Armor    = _G.ArmorSkin

    local function applyWeaponSelection(key, weaponID)
        if config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G.WeaponSkinIndex[weaponID] = config[key] + 1
            changeDetectionCache[key] = config[key]
        end
    end
    
    local exhaustiveWeapons = {
        AKM = 101001, M16A4 = 101002, SCAR = 101003, M416 = 101004,
        GROZA = 101005, AUG = 101006, QBZ = 101007, M762 = 101008,
        MK47 = 101009, G36C = 101010, HoneyBadger = 101012, ASM = 101101, FAMAS = 101100, ACE32 = 101102,
        UZI = 102001, UMP = 102002, Vector = 102003, Thompson = 102004, Bizon = 102005, MP5K = 102007, P90 = 102105,
        Kar98 = 103001, M24 = 103002, AWM = 103003, SKS = 103004, VSS = 103005,
        Mini14 = 103006, MK14 = 103007, SLR = 103009, QBU = 103010, MK12 = 103100, AMR = 103012, DSR = 103102, Mosin = 103013,
        S12K = 104003, DBS = 104004, S1897 = 104001, S686 = 104002,
        M249 = 105001, DP28 = 105002, MG3 = 105010,
        Pan = 108004, Machete = 108001, Crowbar = 108002, Sickle = 108003,
    }
    for wName, wID in pairs(exhaustiveWeapons) do
        applyWeaponSelection(wName, wID)
    end
    -- Fallbacks for old names
    applyWeaponSelection('Kar98k', 103001)
    applyWeaponSelection('Shotgun', 104004)

    local function applyVehicleSelection(key)
        local vehicleBaseID = _G.VehicleMapDict[key]
        if vehicleBaseID and config[key] ~= nil and config[key] ~= changeDetectionCache[key] then
            _G.VehicleSkinIndex[vehicleBaseID] = config[key] + 1
            changeDetectionCache[key] = config[key]
        end
    end
    applyVehicleSelection('UAZ')
    applyVehicleSelection('Dacia')
    applyVehicleSelection('Buggy')
    applyVehicleSelection('Motor')
    applyVehicleSelection('CoupeRB')
end

-- Content-aware: only re-parse when the file content actually changed
_G.RefreshConfigIfChanged = function(force)
    local f = io.open(_G.ConfigFilePath, 'r')
    if not f then return end
    local content = f:read('*a')
    f:close()
    if not content then
        if not _iniEverLoaded then return end
        content = ''
    end
    if force or content ~= _iniContent or not _iniEverLoaded then
        _iniContent = content
        _iniEverLoaded = true
        rebuildResolverCaches()
        pcall(_G.LoadSkinDataFromINI)
        pcall(_G.ReadConfigFile)
    end
end

-- ===================================================================
-- SECTION 11: ATTACHMENT SKIN SYSTEM
-- ===================================================================
_G.BaseAttachToIndex = {
    [201010] = 1, [201005] = 1, [201004] = 1,
    [201009] = 2, [201003] = 2, [201002] = 2,
    [201011] = 3, [201007] = 3, [201006] = 3,
    [204012] = 4, [204005] = 4, [204008] = 4,
    [204011] = 5, [204004] = 5, [204007] = 5,
    [204013] = 6, [204006] = 6, [204009] = 6,
    [203001] = 7,  [203002] = 8,  [203003] = 9,
    [203014] = 10, [203004] = 11, [203015] = 12, [203005] = 13,
    [202002] = 14, [202001] = 15, [202004] = 16,
    [202005] = 17, [202007] = 18, [202006] = 19,
    [205002] = 20, [205003] = 20, [205001] = 20,
    [203018] = 21, [204014] = 22,
}

_G.VIP_Attachments  = {}
_G.VipAttachToIndex = {}

_G.LoadAttachmentsFromINI = function()
    local file = io.open(_G.ConfigFilePath, 'r')
    if not file then return end
    _G.VIP_Attachments  = {}
    _G.VipAttachToIndex = {}
    local inAttachSection = false
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line == '[ATTACHMENTS]' then
            inAttachSection = true
        elseif line:match('^%[') then
            inAttachSection = false
        end
        if inAttachSection and not line:match('^%[') and line ~= '' and not line:match('^#') then
            local skinIDStr, valuesStr = line:match('^(%d+)=(.+)$')
            if skinIDStr and valuesStr then
                local skinID = tonumber(skinIDStr)
                local attachments = {}
                local slotIndex = 1
                for val in valuesStr:gmatch('([^,]+)') do
                    local attachID = tonumber(val) or 0
                    table.insert(attachments, attachID)
                    if attachID > 0 then
                        _G.VipAttachToIndex[attachID] = slotIndex
                    end
                    slotIndex = slotIndex + 1
                end
                _G.VIP_Attachments[skinID] = attachments
            end
        end
    end
    file:close()
end
pcall(_G.LoadAttachmentsFromINI)

-- Track whether attachments file changed
local _attachContent   = nil
local _attachEverLoaded = false
_G.RefreshAttachmentsIfChanged = function(force)
    -- Stop hitting the disk twice! Just reuse the text we just read in RefreshConfigIfChanged
    local content = _iniContent
    if not content then return end
    if not content then
        if not _attachEverLoaded then return end
        content = ''
    end
    if force or content ~= _attachContent or not _attachEverLoaded then
        _attachContent = content
        _attachEverLoaded = true
        pcall(_G.LoadAttachmentsFromINI)
    end
end

-- ===================================================================
-- SECTION 12: ORGSKIN-STYLE ATTACHMENT RESOLUTION
-- Reads attachments.txt + ItemUpgradeSystem + AvatarUtils fallback.
-- ===================================================================
_G.g_parts = _G.g_parts or {}
_G.skinAttachCache = _G.skinAttachCache or {}
_G.ItemUpgradeSystem = _G.ItemUpgradeSystem or nil

local _AttachFilePath = string.match(_G.ConfigFilePath, '^(.*/)') .. 'attachments.txt'

local _AttachSystemInit = false
local function initAttachSystem()
    if _AttachSystemInit then return end
    _AttachSystemInit = true
    pcall(function()
        local MM = require("client.module_framework.ModuleManager")
        local IUS = MM.GetModule(MM.CommonModuleConfig.ItemUpgradeManager)
        if IUS then
            IUS:DefineAndResetData(); IUS:OnInitialize()
            _G.ItemUpgradeSystem = IUS
        end
    end)
end

_G.get_group_id = function(itemId)
    if not _G.ItemUpgradeSystem or not itemId then return nil end
    local cfg = _G.ItemUpgradeSystem:GetUpgradeCfg(itemId)
    return cfg and cfg.GroupID or nil
end

_G.InitParts = function(groupId, itemId)
    if not itemId then return _G.g_parts end
    if _G.g_parts[itemId] and next(_G.g_parts[itemId]) then return _G.g_parts end
    _G.g_parts[itemId] = {}
    if not _G.ItemUpgradeSystem then return _G.g_parts end
    if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
        groupId = _G.ItemUpgradeSystem:GetNormalGroupID(groupId or _G.get_group_id(itemId))
    else
        groupId = groupId or _G.get_group_id(itemId)
    end
    if not groupId then return _G.g_parts end
    local cfg = CDataTable.GetTableByFilter("ItemUpgradeUnLockConfig", "GroupID", groupId)
    if cfg then
        for _, info in pairs(cfg) do
            local partId = info.PartId
            if _G.ItemUpgradeSystem:IsWeaponIsRefit(itemId) then
                local switched = _G.ItemUpgradeSystem:PartIDSwitch(partId, true)
                if switched and switched ~= partId then partId = switched end
            end
            local item = CDataTable.GetTableData("Item", partId)
            if item and item.ItemName then _G.g_parts[itemId][item.ItemName] = partId end
        end
    end
    return _G.g_parts
end

_G.muzzles = { id_flash_hider = {201010,201005,201004}, id_compensator = {201009,201003,201002}, id_suppressor = {201011,201006,201007} }
_G.foregrips = { id_Angledforegrip=202001, id_thumb_grip=202006, id_vertical_grip=202002, id_light_grip=202004, id_half_grip=202005, id_ergonomic_grip=205051, id_laser_sight=202007 }
_G.magazines = { id_expanded_mag={204011,204007,204004}, id_quick_mag={204012,204008,204005}, id_expanded_quick_mag={204013,204009,204006} }
_G.scopes = { id_reddot=203001, id_holo=203002, id_2x=203003, id_3x=203014, id_4x=203004, id_6x=203015, id_8x=203005 }
_G.stock = { id_microStock=205001, id_tactical=205002, id_bulletloop=204014, id_CheekPad=205003 }

_G.GetRawAttachMap = function(skinid)
    if not skinid or skinid <= 0 then return {} end
    if _G.skinAttachCache[skinid] then return _G.skinAttachCache[skinid] end
    local UAvatarUtils = import("AvatarUtils")
    if not UAvatarUtils then return {} end
    local list = UAvatarUtils.GetWeaponAvatarDefaultAttachmentSkin(skinid, {}, false) or {}
    _G.skinAttachCache[skinid] = list
    return list
end

_G.GetSlotFromSkinID = function(skinid, slot)
    if not skinid or not slot then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local tmap = {
        [1] = {291004,291102,291001,291006,291005,291002,293003,293004,293009,293007,293005,293006,295001,295002,291007,291003,292002,292003,291011,291008},
        [2] = {205005,205102,205007,205009,205006},
        [3] = {203008,203009,203006,203022,203010}
    }
    local targetIDs = tmap[slot]
    if not targetIDs then return 0 end
    for _, targetID in ipairs(targetIDs) do
        for attachID, attachSkinID in pairs(list) do
            if attachID == targetID then return attachSkinID end
        end
    end
    return 0
end

_G.AutoDetectAttach = function(skinid, base_id)
    if not skinid or not base_id then return 0 end
    local list = _G.GetRawAttachMap(skinid)
    local v = list[base_id]
    return (v and v > 0) and v or 0
end

local ATTACH_NAME_MAP = {
    ["Red Dot Sight"]="RedDot",["Holographic Sight"]="Holo",["2x Scope"]="Scope2x",
    ["3x Scope"]="Scope3x",["4x Scope"]="Scope4x",["6x Scope"]="Scope6x",["8x Scope"]="Scope8x",
    ["Canted Sight"]="CantedSight",["Flash Hider"]="FlashHider",["Compensator"]="Compensator",
    ["Suppressor"]="Suppressor",["Extended Mag"]="ExtMag",["Quickdraw Mag"]="QuickMag",
    ["Extended Quickdraw Mag"]="ExtQuickMag",["Angled Foregrip"]="AngledGrip",
    ["Vertical Foregrip"]="VerticalGrip",["Thumb Grip"]="ThumbGrip",["Half Grip"]="HalfGrip",
    ["Light Grip"]="LightGrip",["Laser Sight"]="LaserSight",["Tactical Stock"]="TactStock",
    ["Stock"]="MicroStock",["Cheek Pad"]="CheekPad",
}
local _attachFileCache
local function parseAttachmentsFile()
    local result = {}
    pcall(function()
        local f = io.open(_AttachFilePath, "r")
        if not f then return end
        local content = f:read("*all"); f:close()
        local curSkin
        for line in content:gmatch("[^\r\n]+") do
            local firstNum = line:match("^(%d+)%s*|")
            if firstNum then
                local num = tonumber(firstNum)
                if num and num > 1100000000 then curSkin = num; result[curSkin] = result[curSkin] or {}
                elseif num and curSkin then
                    local an = line:match("^%d+%s*|%s*%x+%s*|%s*(.-)%s*$")
                    if not an then an = line:match("^%d+%s*|%s*(.-)%s*$") end
                    if an and an ~= "" then
                        local key = ATTACH_NAME_MAP[an]
                        if key then result[curSkin][key] = num end
                    end
                end
            elseif line:find("^#%-%-%-%-") and line:find("skin") then curSkin = nil end
        end
    end)
    return result
end
_G.GetAttachForSkin = function(skinId, key)
    if not skinId or skinId == 0 or not key then return nil end
    if not _attachFileCache then _attachFileCache = parseAttachmentsFile() end
    local t = _attachFileCache[skinId]
    if not t then return nil end
    local v = t[key]
    return (v and v > 0) and v or nil
end

_G.get_muzzleid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t)
        for _, id in ipairs(_G.muzzles[t]) do if current_id == id then return true end end
        return false
    end
    if is_in("id_flash_hider") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "FlashHider") or (p and p["Flash Hider"]) or (auto>0 and auto) or current_id
    elseif is_in("id_compensator") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Compensator") or (p and p["Compensator"]) or (auto>0 and auto) or current_id
    elseif is_in("id_suppressor") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "Suppressor") or (p and p["Suppressor"]) or (auto>0 and auto) or current_id
    end
    return current_id, (initial_id ~= current_id)
end
_G.get_forgripid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or (auto>0 and auto) or current_id end
    if current_id == _G.foregrips.id_Angledforegrip then current_id = lookup("AngledGrip","Angled Foregrip")
    elseif current_id == _G.foregrips.id_thumb_grip then current_id = lookup("ThumbGrip","Thumb Grip")
    elseif current_id == _G.foregrips.id_vertical_grip then current_id = lookup("VerticalGrip","Vertical Foregrip")
    elseif current_id == _G.foregrips.id_light_grip then current_id = lookup("LightGrip","Light Grip")
    elseif current_id == _G.foregrips.id_half_grip then current_id = lookup("HalfGrip","Half Grip")
    elseif current_id == _G.foregrips.id_ergonomic_grip then current_id = (p and p["Ergonomic Grip"]) or (auto>0 and auto) or current_id
    elseif current_id == _G.foregrips.id_laser_sight then current_id = lookup("LaserSight","Laser Sight") end
    return current_id, (initial_id ~= current_id)
end
_G.get_magazinesid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local function is_in(t) for _, id in ipairs(_G.magazines[t]) do if current_id == id then return true end end; return false end
    if is_in("id_expanded_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtMag") or (p and p["Extended Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    elseif is_in("id_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "QuickMag") or (p and p["Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    elseif is_in("id_expanded_quick_mag") then
        local auto = _G.AutoDetectAttach(avatarid, current_id)
        current_id = _G.GetAttachForSkin(avatarid, "ExtQuickMag") or (p and p["Extended Quickdraw Mag"]) or _G.GetSlotFromSkinID(avatarid,1) or (auto>0 and auto) or current_id
    else local fb = _G.GetSlotFromSkinID(avatarid,1); if fb and fb>0 then current_id = fb end end
    return current_id, (initial_id ~= current_id)
end
_G.get_scopeid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or (auto>0 and auto) or current_id end
    if current_id == _G.scopes.id_reddot then current_id = lookup("RedDot","Red Dot Sight")
    elseif current_id == _G.scopes.id_holo then current_id = lookup("Holo","Holographic Sight")
    elseif current_id == _G.scopes.id_2x then current_id = lookup("Scope2x","2x Scope")
    elseif current_id == _G.scopes.id_3x then current_id = lookup("Scope3x","3x Scope")
    elseif current_id == _G.scopes.id_4x then current_id = lookup("Scope4x","4x Scope")
    elseif current_id == _G.scopes.id_6x then current_id = lookup("Scope6x","6x Scope")
    elseif current_id == _G.scopes.id_8x then current_id = lookup("Scope8x","8x Scope")
    end
    return current_id, (initial_id ~= current_id)
end
_G.get_stockid = function(current_id, avatarid)
    local initial_id = current_id
    _G.InitParts(_G.get_group_id(avatarid), avatarid)
    local p = _G.g_parts[avatarid]
    local auto = _G.AutoDetectAttach(avatarid, current_id)
    local function lookup(key1, key2) return _G.GetAttachForSkin(avatarid, key1) or (p and p[key2]) or _G.GetSlotFromSkinID(avatarid,2) or (auto>0 and auto) or current_id end
    if current_id == _G.stock.id_microStock then current_id = lookup("MicroStock","Stock")
    elseif current_id == _G.stock.id_tactical then current_id = lookup("TactStock","Tactical Stock")
    elseif current_id == _G.stock.id_bulletloop then current_id = (p and p["Bullet Loop"]) or _G.GetSlotFromSkinID(avatarid,2) or (auto>0 and auto) or current_id
    elseif current_id == _G.stock.id_CheekPad then current_id = lookup("CheekPad","Cheek Pad")
    else local fb = _G.GetSlotFromSkinID(avatarid,2); if fb and fb>0 then current_id = fb end end
    return current_id, (initial_id ~= current_id)
end

_G.apply_attachment = function(CurWeapon, avatarid)
    if not slua.isValid(CurWeapon) or not avatarid then return end
    local array = CurWeapon.synData
    if not slua.isValid(array) then return end
    local changed = false
    for AttachIdx = 0, 3 do
        local Data = array:Get(AttachIdx)
        local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
        if itemid and itemid > 0 and itemid < 10000000 then
            local isrefresh = false
            if AttachIdx == 0 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_muzzleid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 1 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_forgripid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 2 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_magazinesid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            elseif AttachIdx == 3 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_stockid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            end
            if isrefresh then changed = true end
        end
    end
    do
        local AttachIdx = 4
        local Data = array:Get(AttachIdx)
        if Data then
            local itemid = slua.IndexReference(Data, "defineID").TypeSpecificID
            local isrefresh = false
            if itemid and itemid > 0 and itemid < 10000000 then
                Data.defineID.TypeSpecificID, isrefresh = _G.get_scopeid(itemid, avatarid)
                array:Set(AttachIdx, Data)
            end
            if isrefresh then changed = true end
        end
    end
    if changed then
        local savedScopeID
        local scopeData = array:Get(4)
        if scopeData then
            local sid = slua.IndexReference(scopeData, "defineID").TypeSpecificID
            if sid and sid > 0 and sid < 10000000 then
                savedScopeID = sid
            end
        end

        _G.download_item(avatarid)
        if CurWeapon.DelayHandleAvatarMeshChanged then
            pcall(function() CurWeapon:DelayHandleAvatarMeshChanged() end)
        end
        if CurWeapon.OnRep_synData then
            pcall(function() CurWeapon:OnRep_synData() end)
        end
        if CurWeapon.UpdateWeaponAttachment then
            pcall(function() CurWeapon:UpdateWeaponAttachment() end)
        end

        if savedScopeID then
            local newData = array:Get(4)
            if newData then
                local newID = slua.IndexReference(newData, "defineID").TypeSpecificID
                if newID ~= savedScopeID then
                    newData.defineID.TypeSpecificID = savedScopeID
                    array:Set(4, newData)
                end
            end
        end
    end
end

-- ===================================================================
-- SECTION 13: CHARACTER AVATAR (OUTFIT) SKIN APPLICATION
-- Now O(changed slots) not O(all slots * all skins).
-- ===================================================================
_G.equip_character_avatar = function(playerChar)
    if not playerChar or not slua.isValid(playerChar) or not playerChar.AvatarComponent2 then return end

    local ac = playerChar.AvatarComponent2
    if not ac or not slua.isValid(ac) or not ac.NetAvatarData then return end

    local slotSyncData = ac.NetAvatarData.SlotSyncData
    if not slotSyncData or not slua.isValid(slotSyncData) then return end

    local BackpackUtils = getBackpackUtils()

    -- 1. ROBUST NEW MATCH DETECTION
    -- By combining the playerChar pointer and the SlotSyncData array pointer, 
    -- we create a unique fingerprint. When you join Match 2, SlotSyncData is re-created, 
    -- breaking the cache and forcing the script to re-apply your skins.
    local matchTrackerId = tostring(playerChar) .. "_" .. tostring(slotSyncData)
    if _G._CurrentMatchTracker ~= matchTrackerId then
        _G._CurrentMatchTracker = matchTrackerId
        _G.LastEquippedOutfits = {} -- Bust the cache so skins re-apply
        for _, key in ipairs({"Shirt","Hat","Mask","Glasses","Pants","Shoes","Armor","Parachute"}) do
            local id = _G.OutfitMap[key]
            if id and id > 0 then _G.skinIdCache[id] = nil end
        end
    end

    -- One-shot glider slot pre-add
    if not _G._GliderSlotEnsuredFor then _G._GliderSlotEnsuredFor = {} end
    if not _G._GliderSlotEnsuredFor[matchTrackerId] then
        local hasGliderSlot = false
        local preNum = slotSyncData:Num()
        for i = 0, preNum - 1 do
            local slotData = slotSyncData:Get(i)
            if slotData and slotData.SlotID == _G.CustSlotType.GlideEquipemtSlot then
                hasGliderSlot = true
                break
            end
        end
        if not hasGliderSlot then
            slotSyncData:Add({ SlotID = _G.CustSlotType.GlideEquipemtSlot, ItemId = 0 })
        end
        _G._GliderSlotEnsuredFor[matchTrackerId] = true
    end

    -- 2. READ NATIVE ITEMS AND APPLY SUIT/BAG/HELMET
    local ref = false
    local num = slotSyncData:Num()
    local nativeSlotItems = {} -- We will save the native IDs here to remove them later

    for i = 0, num - 1 do
        local eq = slotSyncData:Get(i)
        if eq and eq.ItemId ~= 0 then
            -- Save what the server originally equipped so we can take it off if needed
            nativeSlotItems[eq.SlotID] = eq.ItemId 

            local target = 0
            local slotID = eq.SlotID
            if slotID == _G.CustSlotType.ClothesEquipemtSlot
                and _G.OutfitMap.Suit and _G.OutfitMap.Suit ~= 0
            then
                target = _G.OutfitMap.Suit
            elseif slotID == _G.CustSlotType.BackpackEquipemtSlot
                and _G.OutfitMap.Bag and _G.OutfitMap.Bag ~= 0
                and _G.OutfitMap.Bag ~= 501001
                and BackpackUtils
            then
                local level = (BackpackUtils.GetEquipmentBagLevel
                    and BackpackUtils.GetEquipmentBagLevel(eq.AdditionalItemID)) or 1
                target = _G.OutfitMap.Bag + (level - 1) * 1000
            elseif slotID == _G.CustSlotType.HelmetEquipemtSlot
                and _G.OutfitMap.Helmet and _G.OutfitMap.Helmet ~= 0
                and _G.OutfitMap.Helmet ~= 502001
                and BackpackUtils
            then
                local level = (BackpackUtils.GetEquipmentHelmetLevel
                    and BackpackUtils.GetEquipmentHelmetLevel(eq.AdditionalItemID)) or 1
                target = _G.OutfitMap.Helmet + (level - 1) * 1000
            end

            if target and target ~= 0 and eq.ItemId ~= target then
                if not _G.skinIdCache[target] then
                    pcall(_G.download_item, target)
                    _G.skinIdCache[target] = true
                end
                eq.ItemId = target
                slotSyncData:Set(i, eq)
                ref = true
            end
        end
    end
    
    if ref and ac.OnRep_BodySlotStateChanged then
        ac:OnRep_BodySlotStateChanged()
    end

    -- 3. REMOVE NATIVE OUTFITS THEN APPLY CUSTOM OUTFITS
    -- Map string keys to the game's actual Slot IDs
    local extraSlotsMap = {
        Hat = _G.CustSlotType.HatEquipemtSlot,
        Mask = _G.CustSlotType.MaskEquipemtSlot,
        Glasses = _G.CustSlotType.GlassesEquipemtSlot,
        Shirt = _G.CustSlotType.ShirtEquipemtSlot,
        Pants = _G.CustSlotType.PantsEquipemtSlot,
        Shoes = _G.CustSlotType.ShoesEquipemtSlot,
        Armor = _G.CustSlotType.ArmorEquipemtSlot,
        Parachute = _G.CustSlotType.ParachuteEquipemtSlot
    }

    local extra_keys = {"Shirt","Hat","Mask","Glasses","Pants","Shoes","Armor","Parachute"}
    for _, key in ipairs(extra_keys) do
        local customID = _G.OutfitMap[key]
        
        -- Only execute if the skin ID changed or the match tracker reset
        if customID and customID > 0 and _G.LastEquippedOutfits[key] ~= customID then
            pcall(function()
                -- STEP A: Remove the original native item in this slot 
                local slotTypeID = extraSlotsMap[key]
                if slotTypeID then
                    local nativeID = nativeSlotItems[slotTypeID]
                    if nativeID and nativeID ~= 0 and ac.TakeOffCustomEquipmentByID then
                        ac:TakeOffCustomEquipmentByID(nativeID)
                    end
                end

                -- STEP B: Download and Apply the custom item
                if not _G.skinIdCache[customID] then
                    pcall(_G.download_item, customID)
                    _G.skinIdCache[customID] = true
                end
                
                if ac.PutOnCustomEquipmentByID then
                    ac:PutOnCustomEquipmentByID(customID, {})
                end
            end)
            _G.LastEquippedOutfits[key] = customID
        end
    end
end


-- ===================================================================
-- SECTION 14: WEAPON SKIN APPLICATION
-- Skip DelayHandleAvatarMeshChanged/OnRep_synData when nothing changed.
-- ===================================================================
_G.ApplyWeaponSkins = function(playerChar)
    pcall(function()
        initAttachSystem()
        local weaponManager = playerChar:GetWeaponManager()
        if not slua.isValid(weaponManager) then return end

        for slot = 1, 3 do
            local weapon = weaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(weapon) and slua.isValid(weapon.synData) then
                local weaponID = weapon:GetWeaponID()
                local targetSkinID = _G.get_skin_id(weaponID) or weaponID
                local wasModified = false

                local avatarData = weapon.synData:Get(7)
                if avatarData and avatarData.defineID and avatarData.defineID.TypeSpecificID ~= targetSkinID then
                    avatarData.defineID.TypeSpecificID = targetSkinID
                    weapon.synData:Set(7, avatarData)
                    if weapon.SetWeaponAvatarID then
                        pcall(function() weapon:SetWeaponAvatarID(targetSkinID) end)
                    end
                    if not _G.skinIdCache[targetSkinID] then
                        _G.download_item(targetSkinID)
                        _G.skinIdCache[targetSkinID] = true
                    end
                    wasModified = true
                end

                pcall(_G.apply_attachment, weapon, targetSkinID)
                -- Master attachment map (from CDataTable)
                if _G.ApplyMasterAttachmentSkins and weapon.synData then
                    local masterChanged = false
                    pcall(function() masterChanged = _G.ApplyMasterAttachmentSkins(weapon.synData, targetSkinID) end)
                    if masterChanged then wasModified = true end
                end
                if targetSkinID >= 10000000 and _G.VIP_Attachments and _G.VIP_Attachments[targetSkinID] then
                    local attachSet = _G.VIP_Attachments[targetSkinID]
                    for attachIdx = 0, 5 do
                        local attachData = weapon.synData:Get(attachIdx)
                        if attachData then
                            local defineRef = slua.IndexReference(attachData, "defineID")
                            if defineRef then
                                local currentAttachID = defineRef.TypeSpecificID
                                if currentAttachID and currentAttachID > 0 then
                                    local slotIndex = _G.BaseAttachToIndex[currentAttachID]
                                                or _G.VipAttachToIndex[currentAttachID]
                                    local newAttachID = slotIndex and attachSet[slotIndex] or 0
                                    if newAttachID and newAttachID > 0 and newAttachID ~= currentAttachID then
                                        attachData.defineID.TypeSpecificID = newAttachID
                                        weapon.synData:Set(attachIdx, attachData)
                                        if not _G.skinIdCache2[newAttachID] then
                                            if _G.download_item then pcall(_G.download_item, newAttachID) end
                                            _G.skinIdCache2[newAttachID] = true
                                        end
                                        wasModified = true
                                    end
                                end
                            end
                        end
                    end
                end

                if wasModified then
                    if weapon.DelayHandleAvatarMeshChanged then
                        pcall(function() weapon:DelayHandleAvatarMeshChanged() end)
                    end
                    if weapon.OnRep_synData then
                        pcall(function() weapon:OnRep_synData() end)
                    end
                end
            end
        end
    end)
end

-- ===================================================================
-- SECTION 15: VEHICLE SKIN APPLICATION
-- Only re-trigger expensive particle / light / plate updates when
-- the (vehicle, target skin) pair actually changes.
-- ===================================================================
--[[ _G.ApplyVehicleSkins = function(playerChar)
    pcall(function()
        local vehicle = playerChar:GetCurrentVehicle()
        if not slua.isValid(vehicle) then
            _G.LastVehicleEntity = nil
            _G._LastVehicleSkinKey = nil
            return
        end
        if not Game:IsDriver(playerChar.Object) then return end

        local avatarComp = vehicle.VehicleAvatarComponent_BP or vehicle:GetAvatarComponent()
        if not slua.isValid(avatarComp) then return end

        local baseTypeID = 0
        if vehicle.AvatarDefaultCfg then
            baseTypeID = vehicle.AvatarDefaultCfg.TypeSpecificID
        end
        if baseTypeID == 0
            and avatarComp.VehicleNetAvatarData
            and avatarComp.VehicleNetAvatarData.ItemDefineID
        then
            baseTypeID = avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID
        end
        if baseTypeID == 0 then return end

        local targetSkinID = _G.get_vehicle_skin_id(baseTypeID)
        local currentAvatarID = avatarComp:GetCurItemAvatarID()
        if not targetSkinID or targetSkinID == 0 or currentAvatarID == targetSkinID then
            _G.LastVehicleEntity = vehicle
            _G.CurrentEquipVehicleID = targetSkinID
            return
        end

        if not _G.skinIdCache[targetSkinID] then
            if _G.download_item then pcall(_G.download_item, targetSkinID) end
            _G.skinIdCache[targetSkinID] = true
        end

        if avatarComp.VehicleNetAvatarData and avatarComp.VehicleNetAvatarData.ItemDefineID then
            avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID = targetSkinID
            avatarComp.VehicleNetAvatarData.SkinOwnerUID = playerChar.PlayerUID
        end

        local comboKey = tostring(vehicle) .. ":" .. tostring(targetSkinID)
        local firstTimeForCombo = (_G._LastVehicleSkinKey ~= comboKey)
            or (_G.LastVehicleEntity ~= vehicle)
            or (_G.CurrentEquipVehicleID ~= targetSkinID)

        if firstTimeForCombo then
            _G.LastVehicleEntity       = vehicle
            _G.CurrentEquipVehicleID   = targetSkinID
            _G._LastVehicleSkinKey     = comboKey

            pcall(function()
                avatarComp.lastEquipedAvatarId = currentAvatarID
                if avatarComp.ShowVehicleSwitchEffect then
                    avatarComp:ShowVehicleSwitchEffect()
                end
                avatarComp.ClientUsedAvatarID = targetSkinID
                vehicle.ClientUsedAvatarID = targetSkinID
                if avatarComp.ChangeItemAvatar then
                    avatarComp:ChangeItemAvatar(targetSkinID, false)
                end
            end)
        else
            if avatarComp.ChangeItemAvatar then
                avatarComp:ChangeItemAvatar(targetSkinID, false)
            end
        end

        -- Only run these heavy ops on combo change (was every tick)
        if firstTimeForCombo then
            if avatarComp.EnableHighTireLight then
                avatarComp:EnableHighTireLight(true, targetSkinID)
            end
            if vehicle.UpdateParticle then
                pcall(function() vehicle:UpdateParticle(targetSkinID) end)
            end
            if vehicle.ChangeParticles then
                pcall(function() vehicle:ChangeParticles(targetSkinID) end)
            end
            if vehicle.ReActivateExhaustParticle then
                pcall(function() vehicle:ReActivateExhaustParticle() end)
            end

            local LicensePlateComp = import("VehicleLicenseNumberComponent")
            local plateComp = vehicle:GetComponentByClass(LicensePlateComp)
            if slua.isValid(plateComp) then
                if plateComp.LicensePlate then
                    plateComp.LicensePlate.ItemID = targetSkinID
                    plateComp.LicensePlate.ChassisLightId = targetSkinID + 1000
                end
                if plateComp.PreChangeEffect then plateComp:PreChangeEffect() end
                if plateComp.PreChangeChassisLight then plateComp:PreChangeChassisLight() end
            end
        end

        if vehicle.SetVehicleMusicPlayState then
            vehicle:SetVehicleMusicPlayState(true)
        end
    end)
end
]]
-- ===================================================================
-- SECTION 16: PET SKIN APPLICATION
-- ===================================================================
_G.HandlePetLogic = function()
    pcall(function()
        if not _G.PetSkin or _G.PetSkin == 0 or _G.PetSkin == 50000
            or _G.PetSkin == _G.LastAppliedPet
        then
            return
        end
        if not _G.skinIdCache[_G.PetSkin] then
            _G.download_item(_G.PetSkin)
            _G.skinIdCache[_G.PetSkin] = true
        end
        local ModuleManager = require("client.module_framework.ModuleManager")
        if ModuleManager then
            local petModule = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_pet)
            if petModule then
                if petModule.SetCurPetID then petModule:SetCurPetID(_G.PetSkin) end
                if petModule.EquipPet then petModule:EquipPet(_G.PetSkin) end
            end
        end
        _G.LastAppliedPet = _G.PetSkin
    end)
end

-- ===================================================================
-- SECTION 17: KILL COUNTER / KILL MESSAGE SYSTEM
-- Real-time kill tracking with proper UI push on every event.
-- ===================================================================
_G.AKFakeKillCounts = _G.AKFakeKillCounts or setmetatable({}, { __index = function() return 4292 end })

local _KCHooked = false
local _KCModuleManager = nil
local _KCUIManager = nil

local function getKCModuleManager()
    if not _KCModuleManager then
        local ok, mod = pcall(require, "client.module_framework.ModuleManager")
        if ok and mod then _KCModuleManager = mod end
    end
    return _KCModuleManager
end

local function getKCUIManager()
    if not _KCUIManager then
        local ok, mod = pcall(require, "client.slua_ui_framework.manager")
        if ok and mod then _KCUIManager = mod end
    end
    return _KCUIManager
end

local function pushKillCounterUpdate(weaponID, skinID, killCount)
    pcall(function()
        local UIManager = getKCUIManager()
        if not UIManager then return end
        local killCounterUI = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if not killCounterUI or not killCounterUI.UpdateWeaponID then return end
        local avatarSkinID = skinID or weaponID
        killCounterUI:UpdateWeaponID(weaponID, avatarSkinID)
        local ModuleManager = getKCModuleManager()
        if ModuleManager then
            local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if kcLogic and kcLogic.GetEquipedKillCounterId then
                local equippedKCId = kcLogic:GetEquipedKillCounterId(0, avatarSkinID)
                if killCounterUI.SetKillCounterItemShowWithNum then
                    killCounterUI:SetKillCounterItemShowWithNum(equippedKCId, killCount, avatarSkinID)
                end
            end
        end
    end)
end

local function safeRequire(name)
    local loaded = package.loaded[name]
    if loaded then return loaded end
    local ok, mod = pcall(require, name)
    if ok then return mod end
    return nil
end

local function installKillCounterHooks()
    if _KCHooked then return end
    local anyHooked = false
    pcall(function()
        local KillCounterUI = safeRequire("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
        if KillCounterUI and KillCounterUI.__inner_impl then
            local impl = KillCounterUI.__inner_impl
            impl.CheckSupportKCUI = function() return true end
            impl.CheckNeedMainKillCounterUI = function(self, weapon, PlayerID)
                if slua.isValid(weapon) then
                    local weaponID = weapon:GetWeaponID()
                    local skinID = _G.get_skin_id(weaponID) or weaponID
                    self:UpdateMainKillCounterUI(true, weaponID, skinID)
                    pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID] or 0)
                else
                    self:UpdateMainKillCounterUI(false)
                end
            end
            local origUpdate = impl.UpdateMainKillCounterUI
            impl.UpdateMainKillCounterUI = function(self, bShow, weaponID, AvatarID)
                if bShow then
                    AvatarID = _G.get_skin_id(weaponID) or AvatarID
                    if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                    pushKillCounterUpdate(weaponID, AvatarID, _G.AKFakeKillCounts[weaponID] or 0)
                else
                    if origUpdate then origUpdate(self, bShow, weaponID, AvatarID) end
                end
            end
            anyHooked = true
        end

        local ModuleManager = getKCModuleManager()
        if ModuleManager then
            local kcLogic = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            if kcLogic then
                kcLogic.CheckSupportKC = function() return true end
                kcLogic.CheckSupportKillCounterAvatar = function() return true end
                kcLogic.CheckHasWeaponKillCounter = function() return true end
                kcLogic.GetBaseKillCounterIdByWeaponId = function() return 2100004 end
                kcLogic.GetEquipedKillCounterId = function() return 2100004 end
                kcLogic.GetMyEquipedKillCounterId = function() return 2100004 end
                kcLogic.GetOneWeaponKillCountInBattle = function(self, uid, weaponId)
                    return _G.AKFakeKillCounts[weaponId] or 0
                end
                kcLogic.GetWeaponKillCountByUid = function(self, uid, weaponId)
                    return _G.AKFakeKillCounts[weaponId] or 0
                end
                anyHooked = true
            end
        end

        local KillInfo = safeRequire("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
        if KillInfo and KillInfo.__inner_impl then
            local origFileItem = KillInfo.__inner_impl.FileItem
            KillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
                pcall(function()
                    local playerChar = safeRequire("GameLua.GameCore.Data.GameplayData").GetPlayerCharacter()
                    if not slua.isValid(playerChar) then return end
                    if DamageRecordData.Causer ~= playerChar:GetPlayerNameSafety() then return end
                    local currentWeapon = playerChar:GetCurrentWeapon()
                    if not slua.isValid(currentWeapon) then return end
                    local weaponID = currentWeapon:GetWeaponID()
                    local skinID = _G.get_skin_id(weaponID)
                    if skinID then DamageRecordData.CauserWeaponAvatarID = skinID end
                    if _G.SuitSkin ~= 0 then DamageRecordData.CauserClothAvatarID = _G.SuitSkin end
                    DamageRecordData.IsUseColor = true
                    DamageRecordData.UseColor = import("LinearColor")(1.0, 0.8, 0.0, 1.0)
                    if DamageRecordData.ResultHealthStatus == 2 then
                        _G.AKFakeKillCounts[weaponID] = (_G.AKFakeKillCounts[weaponID] or 0) + 1
                        pushKillCounterUpdate(weaponID, skinID, _G.AKFakeKillCounts[weaponID])
                    end
                end)
                if origFileItem then return origFileItem(self, DamageRecordData) end
            end
            anyHooked = true
        end

        local SlotMode2 = safeRequire("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
        if SlotMode2 and SlotMode2.__inner_impl then
            local origCheck = SlotMode2.__inner_impl.CheckShowKCIcon
            SlotMode2.__inner_impl.CheckShowKCIcon = function(self)
                if self.KillCounterImg and slua.isValid(self.KillCounterImg) then
                    self.KillCounterImg:SetVisibility(import("ESlateVisibility").SelfHitTestInvisible)
                end
                if origCheck then return origCheck(self) end
            end
            local origShow = SlotMode2.__inner_impl.ShowKCIcon
            if origShow then
                SlotMode2.__inner_impl.ShowKCIcon = function(self, weaponID, skinID)
                    local cnt = _G.AKFakeKillCounts[weaponID] or 0
                    if origShow then origShow(self, weaponID, skinID) end
                    if cnt > 0 then
                        pcall(function()
                            if self.KillCounterImg and self.KillCounterImg.SetKillCount then
                                self.KillCounterImg:SetKillCount(cnt)
                            end
                        end)
                    end
                end
            end
            anyHooked = true
        end
    end)
    if anyHooked then _KCHooked = true end
end

-- Immediately push kill counter for current weapon on call
_G.ForceEnableKillCounterUI = function()
    installKillCounterHooks()
    _G.RefreshKillCounterUI()
end

-- Per-tick refresh: keeps KC UI visible and count accurate
_G.RefreshKillCounterUI = function()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if not pc then return end
        local lp = pc:GetPlayerCharacterSafety()
        if not slua.isValid(lp) then return end
        local cw = lp:GetCurrentWeapon()
        if not slua.isValid(cw) then return end
        local wID = cw:GetWeaponID()
        if not wID or wID == 0 then return end
        local sid = _G.get_skin_id(wID)
        if not sid then
            local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
            if KCUI and KCUI.__inner_impl then
                KCUI.__inner_impl:UpdateMainKillCounterUI(false)
            end
            return
        end
        local KCUI = package.loaded["GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem"]
        if KCUI and KCUI.__inner_impl then
            KCUI.__inner_impl:UpdateMainKillCounterUI(true, wID, sid)
        end
        pushKillCounterUpdate(wID, sid, _G.AKFakeKillCounts[wID] or 0)
    end)
end

-- ===================================================================
-- SECTION 18: DEAD BOX SKIN APPLICATION
-- Set-based membership (O(1)) + capped location cache + 2.0s throttle.
-- ===================================================================
_G.DeadBoxSkins      = _G.DeadBoxSkins or {}
_G.AlreadyChangedSet = _G.AlreadyChangedSet or {}
-- Force AlreadyChangedSet to act as a hash set
do
    if getmetatable(_G.AlreadyChangedSet) == nil then
        -- we keep the original array semantics for older code, but
        -- tableContainsSet below uses the SAME table as a hash by
        -- writing truthy markers (a sentinel) for set lookups.
    end
end

-- Hash-set membership helpers using _G.AlreadyChangedSet as both array
-- and hash (entries can be either deadbox refs or {__setKey=ref}).
local _DBSetKeys = _G._DBSetKeys or {}
_G._DBSetKeys = _DBSetKeys

local function dbContains(ref)
    if _DBSetKeys[ref] then return true end
    -- legacy path: check if the array contains the ref directly
    for i = 1, #_G.AlreadyChangedSet do
        if _G.AlreadyChangedSet[i] == ref then
            _DBSetKeys[ref] = true
            return true
        end
    end
    return false
end

local function dbAdd(ref)
    if _DBSetKeys[ref] then return end
    _G.AlreadyChangedSet[#_G.AlreadyChangedSet + 1] = ref
    _DBSetKeys[ref] = true
end

local function dbReset()
    -- clear both array and hash, keep tables allocated
    for k in pairs(_DBSetKeys) do _DBSetKeys[k] = nil end
    for i = #_G.AlreadyChangedSet, 1, -1 do _G.AlreadyChangedSet[i] = nil end
end
_G.DeadBox_ResetChangedSet = dbReset

local function isNearLocation(loc1, loc2, tolerance)
    local dx = loc1.X - loc2.X
    local dy = loc1.Y - loc2.Y
    local dz = loc1.Z - loc2.Z
    return dx * dx + dy * dy + dz * dz < tolerance * tolerance
end

local _GameplayStatics = nil
local _GameplayStaticsTried = false
local function getGameplayStatics()
    if _GameplayStatics then return _GameplayStatics end
    if _GameplayStaticsTried then return nil end
    _GameplayStaticsTried = true
    local ok, mod = pcall(import, "GameplayStatics")
    if ok and mod then _GameplayStatics = mod end
    return _GameplayStatics
end

local _ActorClass = nil
local _ActorTried = false
local function getActorClass()
    if _ActorClass then return _ActorClass end
    if _ActorTried then return nil end
    _ActorTried = true
    local ok, mod = pcall(import, "Actor")
    if ok and mod then _ActorClass = mod end
    return _ActorClass
end

local _UIUtil = nil
local _UIUtilTried = false
local function getUIUtil()
    if _UIUtil then return _UIUtil end
    if _UIUtilTried then return nil end
    _UIUtilTried = true
    local ok, mod = pcall(require, "client.common.ui_util")
    if ok and mod then _UIUtil = mod end
    return _UIUtil
end

local _PlayerTombBox = nil
local _PlayerTombBoxTried = false
local function getPlayerTombBox()
    if _PlayerTombBox then return _PlayerTombBox end
    if _PlayerTombBoxTried then return nil end
    _PlayerTombBoxTried = true
    local ok, mod = pcall(import, "PlayerTombBox")
    if ok and mod then _PlayerTombBox = mod end
    return _PlayerTombBox
end

_G.DeadBox_TemperRequest = function(playerController)
    local playerChar = playerController:GetPlayerCharacterSafety()
    if not playerChar then return end

    local GameplayStatics = getGameplayStatics()
    local Actor          = getActorClass()
    local uiUtil         = getUIUtil()
    local PlayerTombBox  = getPlayerTombBox()
    if not (GameplayStatics and Actor and uiUtil and PlayerTombBox) then return end

    local gameInstance = uiUtil.GetGameInstance()
    if not gameInstance then return end

    local allDeadBoxes = GameplayStatics.GetAllActorsOfClass(
        gameInstance, PlayerTombBox, slua.Array(UEnums.EPropertyClass.Object, Actor)
    )

    -- Capped linear scan: keep at most 32 cached location entries
    local skinCacheCount = #_G.DeadBoxSkins
    local scanLimit = skinCacheCount > 32 and (skinCacheCount - 32) or 0

    for _, deadBox in pairs(allDeadBoxes) do
        if slua.isValid(deadBox) then
            local damageCauser = deadBox.DamageCauser
            if damageCauser and damageCauser.Playerkey == playerController.Playerkey then
                local avatarComp = deadBox.DeadBoxAvatarComponent_BP
                if avatarComp and not dbContains(deadBox) then
                    local boxLocation = deadBox:K2_GetActorLocation()
                    local skinApplied = false

                    -- Capped location scan
                    for idx = scanLimit + 1, skinCacheCount do
                        local entry = _G.DeadBoxSkins[idx]
                        if entry and isNearLocation(entry.location, boxLocation, 1.0) then
                            if not _G.skinIdCache[entry.SkinID] then
                                if _G.download_item then pcall(_G.download_item, entry.SkinID) end
                                _G.skinIdCache[entry.SkinID] = true
                            end
                            if avatarComp.ChangeItemAvatar then
                                pcall(function() avatarComp:ChangeItemAvatar(entry.SkinID, false) end)
                            else
                                avatarComp:ResetItemAvatar()
                                avatarComp:PreChangeItemAvatar(entry.SkinID)
                                avatarComp:SyncChangeItemAvatar(entry.SkinID)
                            end
                            dbAdd(deadBox)
                            skinApplied = true
                            break
                        end
                    end

                    if not skinApplied then
                        local skinID = 0
                        local currentVehicle = playerChar.CurrentVehicle
                        if currentVehicle and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
                            skinID = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
                        else
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if currentWeapon then
                                local weaponAvatarData = currentWeapon.synData
                                    and currentWeapon.synData:Get(7)
                                if weaponAvatarData and weaponAvatarData.defineID then
                                    skinID = weaponAvatarData.defineID.TypeSpecificID
                                end
                            end
                        end

                        if skinID ~= 0 then
                            if not _G.skinIdCache[skinID] then
                                if _G.download_item then pcall(_G.download_item, skinID) end
                                _G.skinIdCache[skinID] = true
                            end
                            if avatarComp.ChangeItemAvatar then
                                pcall(function() avatarComp:ChangeItemAvatar(skinID, false) end)
                            else
                                avatarComp:ResetItemAvatar()
                                avatarComp:PreChangeItemAvatar(skinID)
                                avatarComp:SyncChangeItemAvatar(skinID)
                            end
                            _G.DeadBoxSkins[#_G.DeadBoxSkins + 1] = { location = boxLocation, SkinID = skinID }
                            skinCacheCount = #_G.DeadBoxSkins
                            dbAdd(deadBox)
                        end
                    end
                end
            end
        end
    end
end

-- ===================================================================
-- SECTION 19: SKIN ANTI-CHEAT BYPASS
-- ===================================================================
_G.InitializeSkinBypass = function()
    pcall(function()
        local pufferTlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if pufferTlog then
            pufferTlog.ReportEvent         = function() end
            pufferTlog.ReportDownloadResult = function() end
            pufferTlog.ReportODPAKError    = function() end
        end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then
            AvatarUtils.CheckIsWeaponInBlackList = function() return false end
            AvatarUtils.IsValidAvatar            = function() return true end
        end
        local FileCheckSubsystem = require(
            "GameLua.GameCore.Module.Subsystem.SubsystemMgr"
        ):Get("FileCheckSubsystem")
        if FileCheckSubsystem then
            FileCheckSubsystem.StartCheck        = function() end
            FileCheckSubsystem.ReportAbnormalFile = function() end
        end
        local equipReport = package.loaded[
            "client.slua.logic.report.EquipmentExceptionReport"
        ]
        if equipReport then
            equipReport.Report = function() end
        end
    end)
end

-- ===================================================================
-- SECTION 20: LOBBY / WEAPON-SLOT-UI / VEHICLE-EFFECT HOOKS
-- All one-shot. Identical semantics to skin.lua, just installed once.
-- ===================================================================
function _G.InitializeSkinModSystem()
    -- Hook 1: Lobby Avatar Equipment
    pcall(function()
        local LobbyAvatar = package.loaded["client.logic.avatar.LobbyAvatar"]
                        or require("client.logic.avatar.LobbyAvatar")
        if LobbyAvatar and not _G.LobbyBypassHacked then
            local originalPuton = LobbyAvatar.PutonEquipment
            LobbyAvatar.PutonEquipment = function(self, itemID, tAvatarCustom, tExtraData)
                local slotIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[itemID]
                if slotIndex then
                    local currentWeaponSkin = self.GetCurHoldingWeaponSkinID
                        and self:GetCurHoldingWeaponSkinID()
                    if currentWeaponSkin and currentWeaponSkin >= 10000000
                        and _G.VIP_Attachments and _G.VIP_Attachments[currentWeaponSkin]
                    then
                        local replacementID = _G.VIP_Attachments[currentWeaponSkin][slotIndex]
                        if replacementID and replacementID > 0 then
                            if self.HandleDownload then
                                self:HandleDownload(replacementID, nil, nil, false)
                            end
                            itemID = replacementID
                        end
                    end
                end
                if originalPuton then
                    return originalPuton(self, itemID, tAvatarCustom, tExtraData)
                end
            end

            local originalEquipWeapon = LobbyAvatar.CharEquipWeaponByResId
            LobbyAvatar.CharEquipWeaponByResId = function(self, resID, isUse, isAsync, SocketName)
                local result
                if originalEquipWeapon then
                    result = originalEquipWeapon(self, resID, isUse, isAsync, SocketName)
                end
                if isUse and self.GetEquipments then
                    local equipments = self:GetEquipments()
                    for _, equip in ipairs(equipments) do
                        if _G.BaseAttachToIndex and _G.BaseAttachToIndex[equip.itemID] then
                            self:PutonEquipment(equip.itemID, equip.CustomInfo, {bIsUse = false})
                        end
                    end
                end
                return result
            end
            _G.LobbyBypassHacked = true
        end
    end)

    -- Hook 2: Weapon Slot UI Icons
    pcall(function()
        local CommonItemsUIBP = package.loaded[
            "client.slua.component.item.ItemChildren.Common_Items_UIBP"
        ] or require("client.slua.component.item.ItemChildren.Common_Items_UIBP")
        if CommonItemsUIBP and not _G.IconBaloHacked then
            local originalInitView = CommonItemsUIBP.InitView
            CommonItemsUIBP.InitView = function(self, nItemId, nCount, nValidTime, tExtraData)
                tExtraData = tExtraData or {}
                local displaySkinID = nil
                if _G.get_skin_id then
                    local skinID = _G.get_skin_id(nItemId)
                    if skinID and skinID ~= nItemId then
                        displaySkinID = skinID
                    end
                end
                local slotIndex = _G.BaseAttachToIndex and _G.BaseAttachToIndex[nItemId]
                if not displaySkinID and slotIndex then
                    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                    if GameplayData then
                        local playerChar = GameplayData.GetPlayerCharacter()
                        if playerChar and slua.isValid(playerChar) then
                            local currentWeapon = playerChar:GetCurrentWeapon()
                            if slua.isValid(currentWeapon) then
                                local weaponID = currentWeapon:GetWeaponID()
                                local weaponSkinID = _G.get_skin_id(weaponID) or weaponID
                                if weaponSkinID >= 10000000
                                    and _G.VIP_Attachments
                                    and _G.VIP_Attachments[weaponSkinID]
                                then
                                    local replacement = _G.VIP_Attachments[weaponSkinID][slotIndex]
                                    if replacement and replacement > 0 then
                                        displaySkinID = replacement
                                    end
                                end
                            end
                        end
                    end
                end
                if displaySkinID then
                    tExtraData.displayResId = displaySkinID
                    if not _G.skinIdCache2[displaySkinID] then
                        if _G.download_item then pcall(_G.download_item, displaySkinID) end
                        _G.skinIdCache2[displaySkinID] = true
                    end
                end
                if originalInitView then
                    return originalInitView(self, nItemId, nCount, nValidTime, tExtraData)
                end
            end
            _G.IconBaloHacked = true
        end
    end)

    -- Hook 3: Vehicle Effects & Lobby Vehicle
    pcall(function()
        local VehiclePlateLicenseUtil = package.loaded[
            "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil"
        ] or require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if VehiclePlateLicenseUtil and not _G.VehicleEffectHacked then
            VehiclePlateLicenseUtil.CheckIsBetterVehicle  = function() return true end
            VehiclePlateLicenseUtil.CheckHasUnLockFeature  = function() return true end
            VehiclePlateLicenseUtil.NeedOpenHighTire       = function() return true end
            local originalGetEffects = VehiclePlateLicenseUtil.GetUpgradeEffectList
            VehiclePlateLicenseUtil.GetUpgradeEffectList = function(UID)
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                local playerChar = GameplayData.GetPlayerCharacter()
                if slua.isValid(playerChar) and playerChar:GetCurrentVehicle() then
                    local vehicle = playerChar:GetCurrentVehicle()
                    local avatarComp = vehicle.VehicleAvatarComponent_BP
                                    or vehicle:GetAvatarComponent()
                    if slua.isValid(avatarComp) then
                        local avatarID = avatarComp.VehicleNetAvatarData
                            and avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID
                            or avatarComp:GetCurItemAvatarID()
                        local effectData = CDataTable.GetTableData("BetterVehicleEffect", avatarID)
                        if effectData and effectData.EffectIDList then
                            local result = slua.Array(UEnums.EPropertyClass.Int)
                            for i = 0, effectData.EffectIDList:Num() - 1 do
                                result:Add(effectData.EffectIDList:Get(i))
                            end
                            return result
                        end
                    end
                end
                if originalGetEffects then return originalGetEffects(UID) end
                return nil
            end
            _G.VehicleEffectHacked = true
        end

        local VehicleAvatarComponent = package.loaded[
            "GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent"
        ] or require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        if VehicleAvatarComponent and VehicleAvatarComponent.__inner_impl
            and not _G.VehicleAvatarSwitchHacked
        then
            local impl = VehicleAvatarComponent.__inner_impl
            impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
                return true
            end
            impl.ShowVehicleSwitchEffect = function(self)
                if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                    self.curSwitchEffectId = 7303001
                end
                local owner = self:GetOwner()
                if not slua.isValid(owner) then return false end
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    self.uSwitchEffectActor:K2_DestroyActor()
                    self.uSwitchEffectActor = nil
                end
                if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                    self.lastEquipedAvatarId = owner.ClientUsedAvatarID
                        or owner:GetDefaultAvatarID() or 0
                end
                local newAvatarID = owner.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
                local isLobby = self:IsLobbyActor()
                local world = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
                if not world then return false end
                local VehicleUtil = require(
                    "GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil"
                )
                local actorPath = VehicleUtil.GetSwitchEffectActorPath()
                local actorClass = import(actorPath)
                self.uSwitchEffectActor = world:SpawnActor(actorClass, nil, nil, nil)
                if not slua.isValid(self.uSwitchEffectActor) then
                    self.uSwitchEffectActor = nil
                    return false
                end
                self.uSwitchEffectActor:K2_AttachToActor(owner, "None", 1, 1, 1, false)
                self.uSwitchEffectActor:K2_SetActorRelativeLocation(
                    FVector(0, 0, 0), false, nil, false
                )
                self.uSwitchEffectActor:K2_SetActorRelativeRotation(
                    FRotator(0, 0, 0), false, nil, false
                )
                self:ChangeFakeSwitchVehicleAvatar(
                    self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId
                )
                self.uSwitchEffectActor:SetAnimInsAndAnimState(
                    self.uOldVehicleMeshAnimClass, owner
                )
                self.uSwitchEffectActor:StartVehicleSwitchEffect(
                    owner, self.curSwitchEffectId,
                    self.lastEquipedAvatarId, newAvatarID, isLobby
                )
                self.uOldVehicleMeshAnimClass = nil
                return true
            end
            impl.ResetAnimationState = function(self)
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    self.uSwitchEffectActor:K2_DestroyActor()
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                self.curSwitchEffectId = 7303001
            end
            local originalBeginPlay = impl.ReceiveBeginPlay
            impl.ReceiveBeginPlay = function(self)
                if originalBeginPlay then originalBeginPlay(self) end
                self:ResetAnimationState()
            end
            _G.VehicleAvatarSwitchHacked = true
        end

        local LobbyVehicle = package.loaded["client.lobby_ue_object.Actor.LobbyVehicle"]
                          or require("client.lobby_ue_object.Actor.LobbyVehicle")
        if LobbyVehicle and not _G.LobbyVehicleHacked then
            local originalPreChange = LobbyVehicle.PreChangeVehicleAvatar
            LobbyVehicle.PreChangeVehicleAvatar = function(self, InAvatarID, InAdvanceAvatarID)
                local skinID = _G.get_vehicle_skin_id(InAvatarID)
                if skinID and skinID ~= InAvatarID and skinID ~= 0 then
                    if not _G.skinIdCache[skinID] then
                        if _G.download_item then pcall(_G.download_item, skinID) end
                        _G.skinIdCache[skinID] = true
                    end
                    InAvatarID = skinID
                end
                local result = false
                if originalPreChange then
                    result = originalPreChange(self, InAvatarID, InAdvanceAvatarID)
                end
                pcall(function()
                    self.ClientUsedAvatarID = InAvatarID
                    if self.PlayStartUpEffect then self:PlayStartUpEffect() end
                    if self.PlayAccelerateEffect then self:PlayAccelerateEffect() end
                end)
                return result
            end
            _G.LobbyVehicleHacked = true
        end
    end)

    -- ===================================================================
    -- MAIN SKIN APPLICATION LOOP  --  MULTI-RATE
    -- ===================================================================
    if not _G.AKSkinLoopStarted then
        _G.AKSkinLoopStarted = true
        local timeTicker = require("common.time_ticker")

        local _tickerErrorLogged = false

        -- Fast apply ticker (0.4s)
        local function fastApplyLoop()
            pcall(_G.ForceEnableKillCounterUI)
            pcall(_G.RefreshKillCounterUI)
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                if GameplayData then
                    local playerChar = GameplayData.GetPlayerCharacter()
                    if slua.isValid(playerChar) then
                        _G.equip_character_avatar(playerChar)
                        _G.ApplyWeaponSkins(playerChar)
                        _G.ApplyVehicleSkins(playerChar)
                        _G.HandlePetLogic()
                    end
                end
            end)
            if timeTicker and timeTicker.AddTimerOnce then
                timeTicker.AddTimerOnce(0.4, fastApplyLoop)
            elseif not _tickerErrorLogged then
                _tickerErrorLogged = true
            end
        end

        -- Slow scan ticker (2.0s)  --  INI refresh + deadbox scan
        local function slowScanLoop()
            pcall(function()
                local GameplayData = require("GameLua.GameCore.Data.GameplayData")
                if GameplayData then
                    local playerChar = GameplayData.GetPlayerCharacter()
                    if slua.isValid(playerChar) then
                        _G.RefreshConfigIfChanged(false)
                        _G.RefreshAttachmentsIfChanged(false)
                        -- Removed forced retry of BuildMasterAttachmentMaps to prevent 5ms lag spikes
                        if _G.BuildMasterAttachmentMaps and not _G._MasterAttachMapsBuilt then
                            pcall(_G.BuildMasterAttachmentMaps)
                        end
                        local PC = GameplayData.GetPlayerController()
                        if slua.isValid(PC) then
                            _G.DeadBox_TemperRequest(PC)
                        end
                    end
                end
            end)
            if timeTicker and timeTicker.AddTimerOnce then
                timeTicker.AddTimerOnce(2.0, slowScanLoop)
            end
        end

        -- Slow hook ticker (5.0s)  --  kill counter UI
        local function slowHookLoop()
            pcall(_G.ForceEnableKillCounterUI)
            if timeTicker and timeTicker.AddTimerOnce then
                timeTicker.AddTimerOnce(5.0, slowHookLoop)
            end
        end

        fastApplyLoop()
        slowScanLoop()
        slowHookLoop()
    end
end

-- ===================================================================
-- SECTION 21: INITIALIZATION ENTRY POINT
-- ===================================================================
local function initializeSkinSystem()
    pcall(function()
        if _G.InitializeSkinBypass then _G.InitializeSkinBypass() end
        if _G.InitializeSkinModSystem then _G.InitializeSkinModSystem() end
    end)
end

pcall(function()
    local timeTicker = require("common.time_ticker")
    if timeTicker and timeTicker.AddTimerOnce then
        timeTicker.AddTimerOnce(1.5, initializeSkinSystem)
    else
        initializeSkinSystem()
    end
end)

-- ===================================================================
-- SECTION 22: BATTLE KILL BROADCAST SUBSYSTEM HOOK
-- Injects weapon avatar IDs and vehicle skin IDs into kill messages
-- so that the correct skin is shown in the kill feed.
-- ===================================================================
_G._BKBHooked = _G._BKBHooked or false
local function installBattleKillBroadcastHook()
    if _G._BKBHooked then return end
    pcall(function()
        local BattleKillBroadcastSubSystem = require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem")
        if BattleKillBroadcastSubSystem then
            local O_CopyKillOrPutDownMessageDataUserDataToLuaTable = BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable
            BattleKillBroadcastSubSystem.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
                local msgData = O_CopyKillOrPutDownMessageDataUserDataToLuaTable(self, messageData)
                if msgData and msgData.bIamCauser then
                    local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
                    if uCharacter and slua.isValid(uCharacter) then
                        if msgData.DamageType == UEnums.DamageType.VehicleDamage then
                            local carSkinID = _G.CurrentEquipVehicleID
                            if carSkinID ~= 0 then
                                local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                ExpandData.CauserVehicleSkinID = carSkinID
                                ExpandData.CauserWeaponAvatarID = carSkinID
                                msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        else
                            local currWeapon = uCharacter:GetCurrentWeapon()
                            if currWeapon and slua.isValid(currWeapon) then
                                local synData = currWeapon.synData
                                if synData and slua.isValid(synData) then
                                    local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                    if weaponDefineID and slua.isValid(weaponDefineID) then
                                        local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, msgData.ExpandDataContent) or {}
                                        ExpandData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        msgData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                                    end
                                end
                            end
                        end
                    end
                end
                return msgData
            end
            _G._BKBHooked = true
        end
    end)
end

-- ===================================================================
-- SECTION 23: MASTER ATTACHMENT MAP BUILDER (ENHANCED)
-- Builds weapon-skin -> attachment-skin maps from ItemUpgradeConfig
-- and ItemUpgradeUnLockConfig (ported from masterrrr.lua).
-- Each skin carries its own dedicated attachments.
-- Includes debug logging and force-rebuild support.
-- ===================================================================
_G._MasterAttachMaps = nil
_G._MasterAttachMapsBuilt = false
_G._MasterAttachDebug = {}

local function _masterNameToString(name)
    if name == nil then return "" end
    if type(name) == "string" then return name end
    if type(name) == "userdata" then
        local s = nil
        pcall(function() if name.ToString then s = name:ToString() end end)
        if s and type(s) == "string" then return s end
        pcall(function() if name.ToWString then s = name:ToWString() end end)
        if s and type(s) == "string" then return s end
    end
    if type(name) == "table" and name.SourceString then
        return name.SourceString
    end
    return tostring(name)
end

local _MASTER_WEAPON_CLASS_SUFFIXES = {
    { keywords = { "kar98", "awm", "m24", "amr", "mosin", "win94", "mk14" },
      suffixes = { "(Snipers)", "(Sniper Rifles)" } },
    { keywords = { "m249", "mg3", "dp-28", "dp28" },
      suffixes = { "(Machine Guns)" } },
    { keywords = { "ump", "p90", "vector", "bizon", "uzi", "thompson",
                    "mp5", "mp5k", "tommy" },
      suffixes = { "(SMG)", "(SMG, Pistols)", "(Rifles, SMG)" } },
    { keywords = { "p1911", "p92", "p18c", "deagle", "r1895", "r45",
                    "skorpion", "g18" },
      suffixes = { "(Pistols)", "(SMG, Pistols)" } },
    { keywords = { "akm", "m762", "scar", "famas", "m16a4", "aug",
                    "groza", "qbz", "m416", "mk47", "g36c", "ace32",
                    "k2", "m4" },
      suffixes = { "(AR)", "(Rifles, SMG)" } },
}

local function _masterClassSuffixesFromSkinName(skinName)
    if type(skinName) ~= "string" or skinName == "" then return {} end
    local low = string.lower(skinName)
    for _, entry in ipairs(_MASTER_WEAPON_CLASS_SUFFIXES) do
        for _, kw in ipairs(entry.keywords) do
            if string.find(low, kw, 1, true) then return entry.suffixes end
        end
    end
    return {}
end

_G.BuildMasterAttachmentMaps = function(force)
    -- Allow force rebuild or skip if already built with data
    if _G._MasterAttachMaps and not force then
        -- If we already have skin attachments, return cached
        if next(_G._MasterAttachMaps.skinAttachments) then
            return _G._MasterAttachMaps
        end
        -- If empty but already built once, still return (avoid infinite rebuilds)
        if _G._MasterAttachMapsBuilt and not force then
            return _G._MasterAttachMaps
        end
    end

    _G._MasterAttachMaps = {
        skinAttachments  = {},  -- weaponSkinId -> { partSkinId1, partSkinId2, ... }
        skinBases        = {},  -- weaponSkinId -> { baseId1, baseId2, ... }
        attachToSkin     = {},  -- partSkinId   -> { weaponSkinId, baseId }
        skinToBaseWeapon = {},  -- weaponSkinId -> baseWeaponID
    }
    _G._MasterAttachDebug = {}

    if not CDataTable then
        _G._MasterAttachDebug.error = "CDataTable not available"
        _G._MasterAttachMapsBuilt = true
        return _G._MasterAttachMaps
    end

    -- Try both GetTable and GetTableByFilter
    local function safeGetTable(name)
        -- Method 1: GetTable
        if CDataTable.GetTable then
            local ok, tbl = pcall(CDataTable.GetTable, name)
            if ok and tbl then return tbl end
        end
        -- Method 2: GetTableByFilter with nil filter (get all)
        if CDataTable.GetTableByFilter then
            local ok, tbl = pcall(CDataTable.GetTableByFilter, name, nil, nil)
            if ok and tbl then return tbl end
        end
        return nil
    end

    local function safeGetTableData(name, id)
        if CDataTable.GetTableData then
            local ok, row = pcall(CDataTable.GetTableData, name, id)
            if ok then return row end
        end
        return nil
    end

    -- 1) GroupID -> [PartIds] from ItemUpgradeUnLockConfig
    local groupToParts = {}
    pcall(function()
        local unlockTbl = safeGetTable("ItemUpgradeUnLockConfig")
        if not unlockTbl then
            _G._MasterAttachDebug.unlockTable = "nil"
            return
        end
        _G._MasterAttachDebug.unlockTableType = type(unlockTbl)
        local count = 0
        for _, row in pairs(unlockTbl) do
            local gid  = tonumber(row.GroupID)
            local part = tonumber(row.PartId or row.PartID)
            if gid and part then
                if not groupToParts[gid] then groupToParts[gid] = {} end
                groupToParts[gid][#groupToParts[gid] + 1] = part
                count = count + 1
            end
        end
        _G._MasterAttachDebug.unlockRows = count
    end)

    -- 2) weaponSkinId -> GroupID + skinToBaseWeapon from ItemUpgradeConfig
    local skinToGroup = {}
    pcall(function()
        local upTbl = safeGetTable("ItemUpgradeConfig")
        if not upTbl then
            _G._MasterAttachDebug.upgradeTable = "nil"
            return
        end
        _G._MasterAttachDebug.upgradeTableType = type(upTbl)
        local count = 0
        for _, row in pairs(upTbl) do
            local gid = tonumber(row.GroupID)
            local itm = tonumber(row.ItemID)
            if gid and itm and itm >= 1000000000 then
                skinToGroup[itm] = gid
                local baseWeaponID = math.floor(itm / 1000) % 1000000
                if baseWeaponID >= 100000 and baseWeaponID <= 999999 then
                    _G._MasterAttachMaps.skinToBaseWeapon[itm] = baseWeaponID
                end
                count = count + 1
            end
        end
        _G._MasterAttachDebug.upgradeRows = count
    end)

    -- 3) Base name -> [ids] index from Item table (vanilla attachments only)
    local baseNameToIds = {}
    pcall(function()
        local itemTbl = safeGetTable("Item")
        if not itemTbl then
            _G._MasterAttachDebug.itemTable = "nil"
            return
        end
        _G._MasterAttachDebug.itemTableType = type(itemTbl)
        local count = 0
        for k, row in pairs(itemTbl) do
            local id = tonumber(k) or tonumber(row and row.ItemID)
            if id and id >= 1000 and id < 10000000 then
                local nm = row and row.ItemName
                if type(nm) ~= "string" then nm = _masterNameToString(nm) end
                if type(nm) == "string" and nm ~= "" then
                    if not baseNameToIds[nm] then baseNameToIds[nm] = {} end
                    baseNameToIds[nm][#baseNameToIds[nm] + 1] = id
                    count = count + 1
                end
            end
        end
        _G._MasterAttachDebug.itemRows = count
    end)

    -- 4) For each weapon skin, resolve its attachments' base IDs
    local resolvedCount = 0
    for weaponSkinId, gid in pairs(skinToGroup) do
        local parts = groupToParts[gid]
        if parts and #parts > 0 then
            local bases = {}
            local wc = safeGetTableData("Item", weaponSkinId)
            local weaponSkinName = ""
            if wc then
                local nm = wc.ItemName
                if type(nm) ~= "string" then nm = _masterNameToString(nm) end
                weaponSkinName = nm or ""
            end
            local suffixes = _masterClassSuffixesFromSkinName(weaponSkinName)

            for _, partId in ipairs(parts) do
                local baseId = 0
                local partRow = safeGetTableData("Item", partId)
                if partRow then
                    local nm = partRow.ItemName
                    if type(nm) ~= "string" then nm = _masterNameToString(nm) end
                    if type(nm) == "string" and nm ~= "" then
                        local list = baseNameToIds[nm]
                        if type(list) == "table" and #list >= 1 then
                            baseId = list[1]
                            for _, v in ipairs(list) do
                                if v < baseId then baseId = v end
                            end
                        end
                        if baseId == 0 then
                            for _, suf in ipairs(suffixes) do
                                local trial = nm .. " " .. suf
                                local lst = baseNameToIds[trial]
                                if type(lst) == "table" and #lst >= 1 then
                                    baseId = lst[1]
                                    for _, v in ipairs(lst) do
                                        if v < baseId then baseId = v end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                bases[#bases + 1] = baseId
                _G._MasterAttachMaps.attachToSkin[partId] = { weaponSkinId, baseId }
            end
            _G._MasterAttachMaps.skinAttachments[weaponSkinId] = parts
            _G._MasterAttachMaps.skinBases[weaponSkinId] = bases
            resolvedCount = resolvedCount + 1
        end
    end

    _G._MasterAttachDebug.resolvedSkins = resolvedCount
    _G._MasterAttachDebug.totalAttachEntries = 0
    for _ in pairs(_G._MasterAttachMaps.attachToSkin) do
        _G._MasterAttachDebug.totalAttachEntries = _G._MasterAttachDebug.totalAttachEntries + 1
    end
    _G._MasterAttachMapsBuilt = true

    return _G._MasterAttachMaps
end

_G.ApplyMasterAttachmentSkins = function(AttachmentArray, selectedSkinID)
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end
    selectedSkinID = tonumber(selectedSkinID) or 0
    if selectedSkinID == 0 then return false end

    local maps = _G.BuildMasterAttachmentMaps()
    local attachments = maps.skinAttachments[selectedSkinID]
    local bases = maps.skinBases[selectedSkinID]

    local numSlots = 0
    pcall(function() numSlots = AttachmentArray:Num() end)
    if numSlots <= 0 then return false end

    local changed = false

    -- If selected skin has no attachments in the map, revert any
    -- part-skins found on attachment slots back to their base IDs.
    if not attachments or #attachments == 0 then
        for slotIdx = 0, numSlots - 1 do
            local slotData = AttachmentArray:Get(slotIdx)
            if slotData then
                local curID = 0
                pcall(function()
                    curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
                end)
                curID = tonumber(curID) or 0
                if curID > 0 then
                    local rIt = maps.attachToSkin[curID]
                    if rIt then
                        local baseId = rIt[2]
                        if baseId ~= 0 and baseId ~= curID then
                            pcall(function()
                                local defRef = slua.IndexReference(slotData, "defineID")
                                defRef.TypeSpecificID = baseId
                                slotData.operationType = 0
                                AttachmentArray:Set(slotIdx, slotData)
                            end)
                            changed = true
                        end
                    end
                end
            end
        end
        return changed
    end

    -- Build a set of valid attachment skin IDs for this weapon skin
    local validSkinIds = {}
    for _, id in ipairs(attachments) do
        validSkinIds[tonumber(id) or 0] = true
    end

    -- Normal case: for each attachment slot, find the matching
    -- attachment skin by baseId and swap to the selected skin's version.
    for slotIdx = 0, numSlots - 1 do
        local slotData = AttachmentArray:Get(slotIdx)
        if slotData then
            local curID = 0
            pcall(function()
                curID = slua.IndexReference(slotData, "defineID").TypeSpecificID or 0
            end)
            curID = tonumber(curID) or 0
            if curID > 0 then
                -- Protection: if current attachment is already the correct skin, skip
                if validSkinIds[curID] then
                    -- Already the correct skinned attachment, don't change
                else
                    local baseId = 0
                    local rIt = maps.attachToSkin[curID]
                    if rIt then
                        baseId = rIt[2]
                    elseif curID < 10000000 then
                        baseId = curID
                    else
                        -- Unknown skinned attachment from different skin, skip
                        baseId = 0
                    end
                    if baseId ~= 0 then
                        local srcIdx = 0
                        for k, b in ipairs(bases) do
                            if b ~= 0 and b == baseId then
                                local candidate = tonumber(attachments[k]) or 0
                                if candidate ~= 0 and candidate ~= curID then
                                    srcIdx = k
                                    break
                                end
                            end
                        end
                        if srcIdx > 0 and srcIdx <= #attachments then
                            local newID = tonumber(attachments[srcIdx]) or 0
                            if newID ~= 0 and newID ~= curID then
                                pcall(function()
                                    local defRef = slua.IndexReference(slotData, "defineID")
                                    defRef.TypeSpecificID = newID
                                    slotData.operationType = 0
                                    AttachmentArray:Set(slotIdx, slotData)
                                end)
                                changed = true
                            end
                        end
                    end
                end
            end
        end
    end
    return changed
end

-- ===================================================================
-- DEBUG: Master Attachment Map Diagnostic
-- ===================================================================
_G.DebugMasterAttachMaps = function()
    local info = {}
    info.built = _G._MasterAttachMapsBuilt
    info.debug = _G._MasterAttachDebug
    if _G._MasterAttachMaps then
        local ma = _G._MasterAttachMaps
        info.skinsWithAttachments = 0
        for _ in pairs(ma.skinAttachments) do info.skinsWithAttachments = info.skinsWithAttachments + 1 end
        info.attachToSkinEntries = 0
        for _ in pairs(ma.attachToSkin) do info.attachToSkinEntries = info.attachToSkinEntries + 1 end
        info.skinToBaseWeaponEntries = 0
        for _ in pairs(ma.skinToBaseWeapon) do info.skinToBaseWeaponEntries = info.skinToBaseWeaponEntries + 1 end
    else
        info.error = "_MasterAttachMaps is nil"
    end
    return info
end

-- ===================================================================
-- PATCH InitializeSkinModSystem to also install new hooks
-- ===================================================================
local _origInitSkinMod = _G.InitializeSkinModSystem
_G.InitializeSkinModSystem = function()
    if _origInitSkinMod then _origInitSkinMod() end
    pcall(installBattleKillBroadcastHook)
    pcall(function() _G.BuildMasterAttachmentMaps() end)
end

-- ===================================================================
-- SECTION 24: WEAPON INSPECTION ANIMATION
-- ===================================================================
-- 基于 WeaponCheckSkill 配置自动播放武器专属动画
-- 需要在游戏中手持支持该功能的武器（如部分升级枪械）

if not _G.WeaponAnimationModule then
    _G.WeaponAnimationModule = {}
    
    local WAM = _G.WeaponAnimationModule
    
    -- ========== 配置 ==========
    WAM.LOOP = true           -- 是否循环播放
    WAM.TOTAL_SEC = 60        -- 总播放时长（秒），LOOP=true时生效
    WAM.AUTO_START = true     -- 是否自动启动（进入游戏后自动尝试播放）
    WAM.DEBUG = false         -- 调试日志
    
    -- ========== 新增：配置文件开关支持 ==========
    -- 从配置文件读取开关状态 (WEAPON_ANIM=1开启 / 0关闭)
    local function IsWeaponAnimEnabled()
        local configValue = nil
        if _G.YDMH_Config and _G.YDMH_Config.Get then
            configValue = _G.YDMH_Config.Get("WEAPON_ANIM", nil)
        end
        -- 如果配置中有值，使用配置；否则使用默认的 AUTO_START
        if configValue ~= nil then
            return configValue == 1
        end
        return WAM.AUTO_START
    end
    
    -- 更新开关状态
    WAM._enabled = IsWeaponAnimEnabled()
    
    -- 外部控制函数
    function WAM.SetEnabled(enabled)
        WAM._enabled = enabled == true
        WAM.AUTO_START = WAM._enabled
        if not WAM._enabled then
            WAM.Stop()
        else
            WAM.Start()
        end
        -- 保存到配置文件
        if _G.YDMH_Config and _G.YDMH_Config.Set then
            _G.YDMH_Config.Set("WEAPON_ANIM", WAM._enabled and 1 or 0)
        end
        print("[WeaponAnim] 开关状态: " .. tostring(WAM._enabled))
    end
    
    function WAM.IsEnabled()
        return WAM._enabled
    end
    
    -- ========== 原代码继续 ==========
    
    -- 内部变量
    WAM._running = false
    WAM._lastSeqActor = nil
    WAM._timer = nil
    WAM._currentChar = nil
    WAM._seqPath = nil
    WAM._actorPath = nil
    WAM._duration = 0
    WAM._origLoc = nil
    WAM._origRot = nil
    
    -- 默认序列Actor路径（备选）
    local DEFAULT_ACTOR = "/Game/Mod/EvoBase/BluePrints/Actor/BP_CharacterLevelSequenceActor.BP_CharacterLevelSequenceActor_C"
    
    -- 日志函数
    local function log(msg)
        if WAM.DEBUG then
            print("[WeaponAnim] " .. tostring(msg))
        end
    end
    
    -- 获取当前角色
    function WAM.GetCharacter()
        local ok, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
        if not ok or not GameplayData then return nil end
        return GameplayData.GetPlayerCharacter()
    end
    
    -- 检查角色是否站立且可用
    function WAM.IsCharacterReady(char)
        if not char or not slua.isValid(char) then return false end
        local ok, EP = pcall(import, "EPawnState")
        if not ok then return false end
        
        local isStanding = (char.CurrentStates == (1 << EP.Stand))
        if isStanding and char.IsHandleInFold and char:IsHandleInFold() then
            isStanding = false
        end
        
        local inVehicle = char:HasState(EP.InVehicle) or char:HasState(EP.DriveVehicle)
        local isDead = char:HasState(EP.Save) or char:HasState(EP.Pick)
        
        return isStanding and not inVehicle and not isDead
    end
    
    -- 获取武器Avatar组件
    function WAM.GetWeaponAvatarComponent(char)
        if not char or not slua.isValid(char) then return nil end
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if slua.isValid(weapon) and slua.isValid(weapon.WeaponAvatarComponent) then
            return weapon.WeaponAvatarComponent
        end
        return nil
    end
    
    -- 软对象转路径
    local function softToString(softObj)
        local result = nil
        pcall(function()
            if not softObj then return end
            if softObj.ToSoftObjectPath then
                local sp = softObj:ToSoftObjectPath()
                if sp and sp.ToString then result = sp:ToString() end
                if (not result) and sp and sp.GetAssetPathString then
                    result = sp:GetAssetPathString()
                end
            end
            if (not result) and softObj.ToString then
                result = softObj:ToString()
            end
        end)
        return result
    end
    
    -- 解析武器的检视动画配置
    function WAM.ResolveAnimationConfig(char)
        local seqPath, actorPath, duration = nil, nil, 0
        
        pcall(function()
            local wac = WAM.GetWeaponAvatarComponent(char)
            if not wac then return end
            
            local ES = import("EWeaponAttachmentSocketType")
            local ET = import("ECharSpecialLevelSequenceType")
            local handle = wac:GetEquippedHandle(ES.MasterGun)
            
            if handle and slua.isValid(handle) and handle.WeaponSpecialLevelSequenceList then
                for _, seq in pairs(handle.WeaponSpecialLevelSequenceList) do
                    if seq.LevelSequenceType == ET.ECharSpecLvSeq_WeaponCheck and seq.LevelSequenceConfig then
                        local cfg = seq.LevelSequenceConfig
                        seqPath = softToString(cfg.LevelSequence)
                        actorPath = softToString(cfg.SequenceActorTemplate)
                        duration = cfg.LevelSequenceDuration or 0
                        break
                    end
                end
            end
            
            if not actorPath or actorPath == "" then
                local AU = import("AvatarUtils")
                local ES2 = import("EWeaponAttachmentSocketType")
                local skinID = wac:GetEquippedItemDefineID(ES2.MasterGun).TypeSpecificID
                if skinID <= 0 then
                    local weapon = char:GetCurrentWeapon()
                    if weapon then
                        skinID = weapon:GetItemDefineID().TypeSpecificID
                    end
                end
                local base = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinID), false)
                local data = CDataTable.GetTableData("WeaponCheckSkill", base)
                if data and data.SequenceActorPath and data.SequenceActorPath ~= "" then
                    actorPath = data.SequenceActorPath
                end
            end
        end)
        
        if not actorPath or actorPath == "" then
            actorPath = DEFAULT_ACTOR
        end
        
        return seqPath, actorPath, duration
    end
    
    -- 播放一次检视动画
    function WAM.PlayOnce(char)
        if not WAM._seqPath or WAM._seqPath == "" then
            log("No sequence path available")
            return false
        end
        
        local ok = false
        pcall(function()
            local UKismetMathLibrary = import("KismetMathLibrary")
            local transform = UKismetMathLibrary.MakeTransform(
                WAM._origLoc or char:K2_GetActorLocation(),
                WAM._origRot or char:K2_GetActorRotation(),
                FVector(1, 1, 1)
            )
            
            local seqActor = Game:PlayLevelSequence(
                char, WAM._seqPath, transform, 
                WAM._actorPath or DEFAULT_ACTOR, 
                false, nil, char
            )
            
            if slua.isValid(seqActor) then
                if seqActor.SetCharacterAndPlay then
                    seqActor:SetCharacterAndPlay(char)
                end
                char.CurrentLevelSequence = seqActor
                WAM._lastSeqActor = seqActor
                ok = true
                log("Sequence played successfully")
            end
        end)
        
        return ok
    end
    
    -- 检查序列是否存活
    function WAM.IsSequenceAlive()
        return WAM._lastSeqActor and slua.isValid(WAM._lastSeqActor)
    end
    
    -- 停止动画
    function WAM.Stop()
        if WAM._timer and WAM._currentChar and slua.isValid(WAM._currentChar) then
            pcall(function() WAM._currentChar:RemoveGameTimer(WAM._timer) end)
        end
        WAM._running = false
        WAM._timer = nil
        WAM._lastSeqActor = nil
        log("Animation stopped")
    end
    
    -- 启动动画
    function WAM.Start()
        -- ========== 开关检查 ==========
        if not WAM._enabled then
            log("Disabled by config")
            return false
        end
        -- =============================
        
        if WAM._running then
            log("Already running")
            return false
        end
        
        local char = WAM.GetCharacter()
        if not char or not slua.isValid(char) then
            log("No valid character")
            return false
        end
        
        if not WAM.IsCharacterReady(char) then
            log("Character not ready (not standing, in vehicle, or dead)")
            return false
        end
        
        WAM._seqPath, WAM._actorPath, WAM._duration = WAM.ResolveAnimationConfig(char)
        
        if not WAM._seqPath or WAM._seqPath == "" then
            log("No weapon check animation for current weapon")
            return false
        end
        
        if WAM._duration <= 0 then
            WAM._duration = 9
        end
        
        WAM._running = true
        WAM._currentChar = char
        WAM._origLoc = char:K2_GetActorLocation()
        WAM._origRot = char:K2_GetActorRotation()
        
        local firstSuccess = WAM.PlayOnce(char)
        if not firstSuccess then
            WAM._running = false
            log("Failed to play initial sequence")
            return false
        end
        
        local elapsed = 0
        local sinceReplay = 0
        local started = false
        
        pcall(function()
            WAM._timer = char:AddGameTimer(0.2, true, function()
                elapsed = elapsed + 0.2
                sinceReplay = sinceReplay + 0.2
                
                local cur = WAM.GetCharacter()
                if not cur or not slua.isValid(cur) then
                    WAM.Stop()
                    return
                end
                
                if not WAM.IsCharacterReady(cur) then
                    log("Character state changed, stopping")
                    WAM.Stop()
                    return
                end
                
                if WAM.IsSequenceAlive() then
                    started = true
                end
                
                if WAM.LOOP then
                    if (not WAM.IsSequenceAlive()) or sinceReplay >= (WAM._duration - 0.3) then
                        sinceReplay = 0
                        -- 再次检查开关（防止运行时被关闭）
                        if WAM._enabled then
                            WAM.PlayOnce(cur)
                        else
                            WAM.Stop()
                        end
                    end
                    
                    if elapsed >= WAM.TOTAL_SEC then
                        log("Total time elapsed, stopping")
                        WAM.Stop()
                    end
                else
                    if (started and not WAM.IsSequenceAlive()) or elapsed >= (WAM._duration + 1) then
                        log("Sequence completed, stopping")
                        WAM.Stop()
                    end
                end
            end)
        end)
        
        log("Animation started, duration=" .. tostring(WAM._duration) .. "s, loop=" .. tostring(WAM.LOOP))
        return true
    end
    
    -- 重新启动（用于换武器后）
    function WAM.Restart()
        WAM.Stop()
        return WAM.Start()
    end
    
    -- 绑定到武器切换事件
    function WAM.BindToWeaponSwitch()
        if not WAM._originalOnWeaponChanged and _G.WeaponEvents and _G.WeaponEvents.onWeaponChanged then
            WAM._originalOnWeaponChanged = _G.WeaponEvents.onWeaponChanged
            _G.WeaponEvents.onWeaponChanged = function(weaponId)
                if WAM._originalOnWeaponChanged then
                    WAM._originalOnWeaponChanged(weaponId)
                end
                if WAM._enabled then
                    pcall(function() WAM.Restart() end)
                end
            end
            log("Bound to weapon switch event")
        end
    end
    
    -- 自动启动循环 (OPTISKI native timeTicker implementation)
    function WAM.AutoStartLoop()
        if not WAM._enabled then return end
        
        local timeTicker = nil
        pcall(function() timeTicker = require("common.time_ticker") end)
        
        if timeTicker and timeTicker.AddTimerOnce then
            local function wamTick()
                pcall(function()
                    if not WAM._running and WAM._enabled then
                        local char = WAM.GetCharacter()
                        if char and slua.isValid(char) and WAM.IsCharacterReady(char) then
                            local seqPath, _, _ = WAM.ResolveAnimationConfig(char)
                            if seqPath and seqPath ~= "" then
                                WAM.Start()
                            end
                        end
                    end
                end)
                timeTicker.AddTimerOnce(3.0, wamTick)
            end
            timeTicker.AddTimerOnce(3.0, wamTick)
        elseif _G.Mytimer_ticker then
            -- Fallback
            _G.Mytimer_ticker.AddTimerLoop(3, function()
                pcall(function()
                    if not WAM._running and WAM._enabled then
                        local char = WAM.GetCharacter()
                        if char and slua.isValid(char) and WAM.IsCharacterReady(char) then
                            local seqPath, _, _ = WAM.ResolveAnimationConfig(char)
                            if seqPath and seqPath ~= "" then
                                WAM.Start()
                            end
                        end
                    end
                end)
            end, -1, 1)
        end
        
        pcall(function() WAM.Start() end)
    end
    
    -- 导出全局函数
    _G.StartWeaponAnimation = WAM.Start
    _G.StopWeaponAnimation = WAM.Stop
    _G.RestartWeaponAnimation = WAM.Restart
    _G.SetWeaponAnimation = WAM.SetEnabled  -- 新增：开关控制
    
    -- 初始化
    WAM.BindToWeaponSwitch()
    WAM.AutoStartLoop()
    
    log("Weapon Animation Module loaded, enabled=" .. tostring(WAM._enabled))
end
