local require = require
local import = import
local isValid = slua.isValid

local function FindPath(...)
    for _, p in ipairs({ ... }) do
        local f = io.open(p, "r")
        if f then f:close(); return p end
    end
    return nil
end
local INI_PATH = FindPath(
    "/data/data/com.termux/files/home/newluas/SKINS.ini",
    "/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini"
) or "/storage/emulated/0/Android/data/com.pubg.imobile/files/SKINS.ini"
local DUMP_PATH = FindPath(
    "/data/data/com.termux/files/home/newluas/dump_full.txt",
    "/storage/emulated/0/Android/data/com.pubg.imobile/files/dump_full.txt"
) or "/storage/emulated/0/Android/data/com.pubg.imobile/files/dump_full.txt"

_G._Suk = _G._Suk or {}
local S = _G._Suk

local SP = "/storage/emulated/0/Android/data/com.pubg.imobile/files/CHETAN_MODS/sukuna_settings.cfg"
local function Save()
    pcall(function()
        local f = io.open(SP, "w")
        if not f then return end
        for k, v in pairs(S) do f:write(k .. "=" .. tostring(v) .. "\n") end
        f:close()
    end)
end
local function Load()
    pcall(function()
        local f = io.open(SP, "r")
        if not f then return end
        for l in (f:read("*a") or ""):gmatch("[^\n]+") do
            local k, v = l:match("([^=]+)=(.+)")
            if k and v then
                if v == "true" then S[k] = true
                elseif v == "false" then S[k] = false
                else S[k] = tonumber(v) or v end
            end
        end
        f:close()
    end)
end
Load()
local function Set(k, v) S[k] = v; Save() end

local function ParseINI()
    local f = io.open(INI_PATH, "r")
    if not f then return {} end
    local content = f:read("*a"); f:close()
    local matched = {}
    local selected = {}
    local skinList = {}
    local section = ""
    local lastComment = ""
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$") or ""
        local h = line:match("^%[(.+)%]$")
        if h then
            section = h; lastComment = ""
            local norm = (h:gsub("%s", ""):gsub("_", "")):upper()
            if norm:match("SELECTED") then section = "SELECTED"
            elseif norm:match("SKIN") then section = "SKIN_LIST"
            else section = norm end
        elseif section == "SELECTED" then
            local n, i = line:match("^([^=]+)=(%d+)$")
            if n and i then selected[n:match("^%s*(.-)%s*$")] = tonumber(i) end
        elseif section == "SKIN_LIST" then
            local c = line:match("^#%s*(.+)$")
            if c then
                local cu = c:upper()
                if not c:match("===") and not c:match("%-%-%-") and not cu:match("^(QUẦN ÁO|BALO|MŨ|DÙ|SÚNG|VŨ KHÍ|XE|DÒNG|SMG|SNIPER|LMG|PHỤ KIỆN|THÊM TỪ|QUY TẮC)") then
                    lastComment = c
                end
            else
                local key, vals = line:match("^([^=]+)=(.+)$")
                if key and vals then
                    key = key:match("^%s*(.-)%s*$")
                    local ids = {}
                    local count = 0
                    for v in vals:gmatch("[^,]+") do
                        if v ~= "" then count = count + 1; ids[count] = v end
                    end
                    if count > 0 then
                        local name = nil
                        if key:match("^%d+$") then name = lastComment; lastComment = ""
                        else name = key end
                        if name then
                            if not skinList[name] then skinList[name] = {} end
                            for i = 1, count do skinList[name][i] = ids[i] end
                        end
                    end
                end
            end
        end
    end
    for name, idx in pairs(selected) do
        local entry = skinList[name]
        if entry then
            matched[name] = { index = idx, skinIDs = entry }
        end
    end
    for name, idx in pairs(selected) do
        if not matched[name] then
            if name:match("^%d+$") then
                for sname, entry in pairs(skinList) do
                    for _, sid in ipairs(entry) do
                        if sid == name then
                            matched[sname] = { index = idx, skinIDs = entry }
                            break
                        end
                    end
                    if matched[sname] then break end
                end
            end
        end
    end
    for name, idx in pairs(selected) do
        if not matched[name] then
            local nl = name:lower()
            for sname, entry in pairs(skinList) do
                local sl = sname:lower()
                if nl == sl or nl == sl:gsub("%s", "") or sl == nl:gsub("%s", "") or
                   sl:match("^" .. nl:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")) then
                    matched[name] = { index = idx, skinIDs = entry }
                    break
                end
            end
        end
    end
    return matched
end

local function LoadDump()
    local dump = {}
    pcall(function()
        local f = io.open(DUMP_PATH, "r")
        if not f then return end
        for l in (f:read("*a") or ""):gmatch("[^\r\n]+") do
            local id, nm = l:match("^(%d+)%s*|%s*[^|]+%s*|%s*(.+)$")
            if id and nm and nm ~= "" then
                nm = nm:match("^%s*(.-)%s*$") or nm
                dump[id] = nm
            end
        end
        f:close()
    end)
    return dump
end

local function WriteSelected(selName, value)
    pcall(function()
        local f = io.open(INI_PATH, "r")
        if not f then return end
        local content = f:read("*a"); f:close()
        local inSec = false
        local lines = {}
        for line in content:gmatch("[^\r\n]+") do
            local h = line:match("^%[")
            if h then inSec = line:match("^%[(SELECTED)%]") ~= nil; table.insert(lines, line)
            elseif inSec then
                local k, _ = line:match("^([^=]+)=(%d+)$")
                if k then k = k:match("^%s*(.-)%s*$") end
                if k == selName then table.insert(lines, selName .. "=" .. tostring(value))
                else table.insert(lines, line) end
            else table.insert(lines, line) end
        end
        f = io.open(INI_PATH, "w")
        if f then f:write(table.concat(lines, "\n")); f:close() end
    end)
end

local _lastSig = nil
local _registered = false

local function BuildSkinSection()
    local ModMenu = _G.ModMenu
    if not ModMenu or type(ModMenu.Register) ~= "function" then return end

    local matched = ParseINI()
    local matchedCount = 0
    for _ in pairs(matched) do matchedCount = matchedCount + 1 end
    if not next(matched) then
        pcall(function() print("[SKINMGR] ParseINI empty, no dropdowns") end)
        return
    end
    local dump = LoadDump()

    local groups = {
        Cosmetics = {}, XSuits = {}, AR = {}, SMG = {}, SR = {}, DMR = {},
        Shotgun = {}, LMG = {}, Throwable = {}, Melee = {}, Vehicles = {}, Other = {},
    }
    local groupTitles = {
        Cosmetics = "Skns", XSuits = "X-Suit", AR = "AR", SMG = "SMG", SR = "SR",
        DMR = "DMR", Shotgun = "Shotgun", LMG = "LMG", Throwable = "Throwable",
        Melee = "Mel", Vehicles = "Veh", Other = "Oth",
    }
    local arSet = { M416 = true, AKM = true, SCAR = true, M762 = true, GROZA = true, AUG = true, ACE32 = true, QBZ = true, G36C = true, ASM = true, HoneyBadger = true, M16A4 = true, MK47 = true, FAMAS = true }
    local smgSet = { UMP = true, Vector = true, UZI = true, Bizon = true, P90 = true, MP5K = true, Thompson = true }
    local srSet = { Kar98 = true, M24 = true, AWM = true, AMR = true, Mosin = true, DSR = true }
    local dmrSet = { MK14 = true, Mini14 = true, QBU = true, MK12 = true, VSS = true, SLR = true, SKS = true }
    local sgSet = { S686 = true, S1897 = true, S12K = true, NS2000 = true, DBS = true }
    local lmgSet = { DP28 = true, M249 = true, MG3 = true }
    local thrSet = { Grenade = true }
    local meleeSet = { Pan = true, Machete = true, Crowbar = true, Sickle = true }
    local vehSet = { Motor = true, Sidecar = true, Dacia = true, MiniBus = true, Pickup = true, PickupClosed = true, Buggy = true, UAZ = true, UAZClosed = true, UAZOpen = true, PG117 = true, JetSki = true, Mirado = true, MiradoOpen = true, Rony = true, Scooter = true, Snowmobile = true, Tukshai = true, MonsterTruck = true, MotorGlider = true, CoupeRB = true, Tank = true, MountainBike = true, UTV = true, Bike = true, Horse = true, Hovercraft = true }

    local categorized = {}
    for name, entry in pairs(matched) do
        if #entry.skinIDs > 1 then
            local g = "Other"
            if arSet[name] then g = "AR"
            elseif smgSet[name] then g = "SMG"
            elseif srSet[name] then g = "SR"
            elseif dmrSet[name] then g = "DMR"
            elseif sgSet[name] then g = "Shotgun"
            elseif lmgSet[name] then g = "LMG"
            elseif thrSet[name] then g = "Throwable"
            elseif meleeSet[name] then g = "Melee"
            elseif vehSet[name] then g = "Vehicles"
            elseif name:lower():match("^x[%-_]?suit") then g = "XSuits"
            elseif name == "Suit" or name == "Bag" or name == "Helmet" or name == "Parachute" or name == "Pet" or name == "Hat" or name == "Mask" or name == "Pants" or name == "Shoes" or name == "Glasses" or name == "Armor" then g = "Cosmetics"
            end
            categorized[name] = g
        end
    end
    if not next(categorized) then return end

    local items = {}
    local order = { "Cosmetics", "XSuits", "AR", "SMG", "SR", "DMR", "Shotgun", "LMG", "Throwable", "Melee", "Vehicles", "Other" }
    for _, g in ipairs(order) do
        local names = {}
        for name, grp in pairs(categorized) do
            if grp == g then names[#names + 1] = name end
        end
        if #names > 0 then
            table.sort(names)
            items[#items + 1] = { type = "label", id = "h_" .. g, label = groupTitles[g] or g }
            for _, name in ipairs(names) do
                local entry = matched[name]
                local key = "SKIN_" .. name
                if S[key] == nil then S[key] = math.min(entry.index, #entry.skinIDs - 1) end
                local opts = {}
                for i, sid in ipairs(entry.skinIDs) do
                    opts[#opts + 1] = { value = i - 1, label = dump[sid] or ("Skin " .. i) }
                end
                items[#items + 1] = {
                    type = "dropdown", id = key, label = name,
                    default = S[key], options = opts,
                    onChange = function(v)
                        Set(key, v)
                        WriteSelected(name, v)
                    end,
                }
            end
        end
    end

    ModMenu.Register({ id = "skins", title = "SKINS", items = items })
    _registered = true
    pcall(function() print("[SKINMGR] registered " .. #items .. " items (" .. matchedCount .. " skins)") end)
    ModMenu.Rebuild()
end

pcall(BuildSkinSection)

local _sigTimer = nil
local function CheckReload()
    local f = io.open(INI_PATH, "r")
    if not f then return end
    local data = f:read("*a"); f:close()
    local sig = tostring(#data) .. ":" .. tostring(data:len() > 0 and data:sub(#data - 40) or data)
    if _lastSig and _lastSig ~= sig then
        _lastSig = sig
        pcall(BuildSkinSection)
    else
        _lastSig = _lastSig or sig
    end
end

if _sigTimer then pcall(function() Game:ClearTimer(_sigTimer) end) end
_sigTimer = Game:SetTimer(2, true, CheckReload)

pcall(function()
    local ok, U = pcall(require, "GameLua.Util.UIUtils")
    if ok and U and U.ShowNotice then U:ShowNotice("[SKINMGR]LOADED") end
end)