--[[
    ModMenu - Single-file SLua Menu for PUBG Mobile
    ===============================================
    Menu for FINEL ESP (finelv2.lua). Creates a floating "MENU" button;
    tapping it opens the menu. Feature toggles read/write the live config
    of finelv2 (_G.AimbotConfig, _G.MemoryConfig, _G.PlayerMapMarker).

    Load finelv2.lua first, then this file. Auto-creates the MENU button.
--]]

-- =============================================================================
-- SLua HELPERS
-- =============================================================================

local LOG_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/menulogs.txt"

local function Log(msg)
    local line = "[ModMenu] " .. tostring(msg)
    pcall(function() print(line) end)
    pcall(function()
        local f = io.open(LOG_PATH, "a")
        if f then
            f:write(os.date("%H:%M:%S") .. " " .. line .. "\n")
            f:close()
        end
    end)
end

local function LogReset()
    pcall(function()
        local f = io.open(LOG_PATH, "w")
        if f then f:write("--- ModMenu log ---\n") f:close() end
    end)
end

local function GetGameInstance()
    if slua_GameFrontendHUD then
        local gi = slua_GameFrontendHUD:GetGameInstance()
        if gi and slua.isValid(gi) then return gi end
    end
    if slua_GameFrontendHUD and slua.isValid(slua_GameFrontendHUD) then
        return slua_GameFrontendHUD
    end
    local UIUtil = nil
    pcall(function()
        local U = require("client.common.ui_util")
        if U and U.GetGameInstance then UIUtil = U.GetGameInstance() end
    end)
    if UIUtil and slua.isValid(UIUtil) then return UIUtil end
    return nil
end

local function Construct(classPath, outer)
    if CGame and CGame.NewObjectFromPath then
        local w = CGame:NewObjectFromPath(classPath, outer or GetGameInstance())
        if w and slua.isValid(w) then return w end
    end
    return nil
end

local function Vis(name)
    if UEnums and UEnums.ESlateVisibility then
        local v = UEnums.ESlateVisibility[name]
        if v then return v end
    end
    return 0
end

local function Plain(txt)
    if txt == nil then return "" end
    if type(txt) == "string" then return txt end
    local ok, s = pcall(function() return txt:ToString() end)
    if ok and s then return s end
    ok, s = pcall(function() return tostring(txt) end)
    return s or ""
end

local function SetText(tb, str)
    if not tb then return end
    pcall(function() tb:SetText(tostring(str)) end)
end

local function StyleText(tb, size, color)
    if not tb then return end
    color = color or { R = 0.93, G = 0.93, B = 0.97, A = 1 }
    pcall(function()
        local f = tb.Font
        if f then
            f.Size = size
            f.IsBold = true
            tb:SetFont(f)
        end
    end)
    pcall(function() tb:SetColorAndOpacity(FSlateColor(color)) end)
end

local function Brush(w, color)
    if not w then return end
    pcall(function() w:SetBrushColor(color) end)
end

local function ConfigCanvasSlot(slot, x0, y0, x1, y1, z)
    if not slot then return end
    pcall(function() slot:SetAnchors(FAnchors(x0, y0, x1, y1)) end)
    pcall(function() slot:SetOffsets(FMargin(0, 0, 0, 0)) end)
    pcall(function() slot:SetAlignment(FVector2D(0, 0)) end)
    if z then pcall(function() slot:SetZOrder(z) end) end
end

local function BindEvent(control, eventName, cb)
    if not control then return false end
    local bound = false
    pcall(function()
        local DC = require("common.delegate_container")
        if DC then
            local host = DC()
            if host and host.AddControlEvent then
                host:AddControlEvent(control, eventName, function(...) pcall(cb, ...) end)
                bound = true
            end
        end
    end)
    if not bound then
        pcall(function()
            local ev = control[eventName]
            if ev then
                if ev.Add then
                    ev:Add(function(...) pcall(cb, ...) end)
                    bound = true
                elseif ev.Bind then
                    ev:Bind(function(...) pcall(cb, ...) end)
                    bound = true
                end
            end
        end)
    end
    return bound
end

local function BindClick(control, cb)
    return BindEvent(control, "OnClicked", cb)
end

local function Once(delay, cb)
    if not cb then return end
    if _G.SetTimer then
        pcall(function() _G.SetTimer(delay, cb) end)
        return
    end
    local ok = false
    pcall(function()
        local tk = _G.Mytimer_ticker
        if not tk then tk = require("common.time_ticker") end
        if tk and tk.AddTimer then tk.AddTimer(delay, cb) ok = true end
    end)
    if not ok then
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and pc.AddGameTimer then pc:AddGameTimer(delay, false, cb) end
        end)
    end
end

local function Loop(delay, cb)
    if not cb then return end
    local ok = false
    pcall(function()
        local tk = _G.Mytimer_ticker
        if not tk then tk = require("common.time_ticker") end
        if tk and tk.AddTimerLoop then tk.AddTimerLoop(delay, cb, -1, delay) ok = true end
    end)
    if not ok then
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pc and pc.AddGameTimer then pc:AddGameTimer(delay, true, cb) end
        end)
    end
end

local function AddToContainer(widget, z)
    if not widget then return false end
    local added = false
    pcall(function()
        local gfh = require("game_frontend_hud")
        if gfh and gfh.AddToContainer and UIContainers then
            gfh.AddToContainer(UIContainers.Top, widget, z)
            added = true
        end
    end)
    if not added then
        pcall(function()
            if slua_GameFrontendHUD and slua_GameFrontendHUD.AddToContainer and UIContainers then
                slua_GameFrontendHUD:AddToContainer(UIContainers.Top, widget, z)
            end
        end)
    end
    return added
end

-- =============================================================================
-- MENU STATE
-- =============================================================================

local State = {
    cfg = {
        title       = "FINEL MENU",
        dock        = "right",
        widthFrac   = 0.62,
        fontSize    = 20,
        fontSmall   = 16,
        fontTitle   = 26,
        zMenu       = 9600,
        zButton     = 9000,
        textWidth   = 220,
        accent      = { R = 0.30, G = 0.72, B = 1.0,  A = 1.0 },
        headerBg    = { R = 0.05, G = 0.05, B = 0.07, A = 1.0 },
        rowBg       = { R = 0.03, G = 0.03, B = 0.045, A = 1.0 },
        panelBg     = { R = 0.01, G = 0.012, B = 0.02, A = 0.98 },
        textColor   = { R = 0.95, G = 0.95, B = 0.98, A = 1.0 },
        onColor     = { R = 0.14, G = 0.80, B = 0.42, A = 1.0 },
        offColor    = { R = 0.42, G = 0.44, B = 0.50, A = 1.0 },
        sectionTitleColor = { R = 0.55, G = 0.82, B = 1.0, A = 1.0 },
    },
    sections  = {},
    live      = {},
    index     = {},
    created   = false,
    open      = false,
    root      = nil,
    canvas    = nil,
    panel     = nil,
    content   = nil,
    btn       = nil,
    btnReady  = false,
}

local function DockRect()
    local cfg = State.cfg
    local f = cfg.widthFrac or 0.62
    local dock = cfg.dock or "right"
    if dock == "left" then
        return 0.015, 0.04, f - 0.015, 0.96
    elseif dock == "center" then
        return 0.05, 0.05, 0.95, 0.95
    elseif dock == "full" then
        return 0, 0, 1, 1
    end
    return 1 - f + 0.015, 0.04, 0.985, 0.96
end

-- =============================================================================
-- MENU BUTTON
-- =============================================================================

local BUTTON_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP_C"
local BUTTON_BP2 = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"

local function IsMetro()
    local ok, r = pcall(function()
        local X = require("client.slua.logic.TxMission.logic_xmission_main")
        return X and X.IsInXMission and X.IsInXMission(false)
    end)
    return ok and r == true
end

local function PlaceButton(widget, w, h)
    if not widget or not slua.isValid(widget) then return end
    pcall(function()
        local WLL = import("WidgetLayoutLibrary")
        local slot = WLL.SlotAsCanvasSlot(widget)
        if slot then
            slot:SetAnchors(FAnchors(1, 0.35, 1, 0.35))
            slot:SetAlignment(FVector2D(1, 0.5))
            slot:SetPosition(FVector2D(-14, 0))
            slot:SetSize(FVector2D(w or 110, h or 42))
            if slot.SetZOrder then slot:SetZOrder(State.cfg.zButton) end
        end
    end)
    pcall(function()
        if widget.SetWidgetVisibility and UEnums then
            widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end
    end)
end

local function CreateButton()
    if State.btn and slua.isValid(State.btn) then return true end
    if _G._ModMenuBtnCreated == true then
        Log("CreateButton skipped (already created once)")
        return true
    end

    Log("CreateButton: attempting load " .. BUTTON_BP)
    local widget = nil
    pcall(function() widget = slua.loadUI(BUTTON_BP) end)
    if not widget or not slua.isValid(widget) then
        Log("CreateButton: loadUI failed, trying STExtraBP")
        pcall(function()
            local STExtraBP = import("STExtraBlueprintFunctionLibrary")
            if STExtraBP and STExtraBP.CreateWidgetByPathName then
                widget = STExtraBP.CreateWidgetByPathName(BUTTON_BP, GetGameInstance())
            end
        end)
    end
    if not widget or not slua.isValid(widget) then
        Log("CreateButton: STExtraBP failed, trying BP2")
        pcall(function() widget = slua.loadUI(BUTTON_BP2) end)
    end
    if not widget or not slua.isValid(widget) then
        Log("CreateButton FAILED: all load methods failed")
        return false
    end
    Log("CreateButton: widget loaded OK")

    local added = AddToContainer(widget, State.cfg.zButton)
    Log("CreateButton: AddToContainer -> " .. tostring(added))
    PlaceButton(widget, 110, 42)

    pcall(function()
        if widget.RichText_Content then
            widget.RichText_Content:SetText("MENU")
            local f = widget.RichText_Content.Font
            if f then
                f.Size = 18
                f.IsBold = true
                widget.RichText_Content:SetFont(f)
            end
        end
        if widget.TextBlock then
            widget.TextBlock:SetText("MENU")
            local f = widget.TextBlock.Font
            if f then
                f.Size = 18
                f.IsBold = true
                widget.TextBlock:SetFont(f)
            end
        end
    end)

    local Target = widget.Button_Temp or widget
    local bound = BindClick(Target, function()
        ModMenu.Toggle()
    end)
    if not bound then
        pcall(function()
            if widget.OnClicked then
                widget.OnClicked:Add(function() ModMenu.Toggle() end)
            end
        end)
    end

    State.btn = widget
    State.btnReady = true
    _G._ModMenuBtnCreated = true
    Log("MENU button created (single)")
    return true
end

local function EnsureButton()
    if IsMetro() then return end
    if _G._ModMenuBtnCreated == true and State.btn and slua.isValid(State.btn) then
        return
    end
    CreateButton()
end

-- =============================================================================
-- ROOT (MASK) LOADING
-- =============================================================================

local function LoadRoot()
    local gi = GetGameInstance()
    if not gi then
        Log("LoadRoot FAILED: no GameInstance")
        return nil, nil
    end

    local Canvas = Construct("/Script/UMG.CanvasPanel", gi)
    if not Canvas then
        Log("LoadRoot FAILED: could not construct CanvasPanel")
        return nil, nil
    end
    pcall(function() Canvas:SetWidgetVisibility(Vis("Visible")) end)
    pcall(function() Canvas:SetRenderOpacity(1) end)

    local added = AddToContainer(Canvas, State.cfg.zMenu)
    Log("LoadRoot: canvas constructed, AddToContainer -> " .. tostring(added))

    return Canvas, Canvas
end

-- =============================================================================
-- PANEL BUILD
-- =============================================================================

local function BuildPanel()
    local cfg = State.cfg
    local gi = GetGameInstance()
    if not gi then return false end

    local panel = Construct("/Script/UMG.Border", gi)
    if not panel then return false end
    Brush(panel, cfg.panelBg)
    pcall(function() panel:SetWidgetVisibility(Vis("Visible")) end)
    pcall(function() panel:SetRenderOpacity(1) end)

    local slot = State.canvas:AddChildToCanvas(panel)
    if slot then
        local dx0, dy0, dx1, dy1 = DockRect()
        ConfigCanvasSlot(slot, dx0, dy0, dx1, dy1, cfg.zMenu)
    end

    local vbox = Construct("/Script/UMG.VerticalBox", gi)
    if not vbox then return false end
    pcall(function() panel:SetContent(vbox) end)

    -- Header
    local header = Construct("/Script/UMG.HorizontalBox", gi)
    if header then
        local hslot = vbox:AddChildToVerticalBox(header)
        if hslot then pcall(function() hslot:SetPadding(FMargin(12, 10, 12, 6)) end) end

        local title = Construct("/Script/UMG.TextBlock", gi)
        if title then
            StyleText(title, cfg.fontTitle, cfg.accent)
            SetText(title, cfg.title or "MENU")
            local tslot = header:AddChildToHorizontalBox(title)
            if tslot then
                pcall(function() tslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                pcall(function() tslot:SetVerticalAlignment(4) end)
            end
        end

        local hint = Construct("/Script/UMG.TextBlock", gi)
        if hint then
            StyleText(hint, 13, { R = 0.6, G = 0.62, B = 0.7, A = 1 })
            SetText(hint, "tap ✕ to close")
            pcall(function() header:AddChildToHorizontalBox(hint) end)
        end

        local close = Construct("/Script/UMG.Button", gi)
        if close then
            pcall(function() close:SetBackgroundColor({ R = 0.55, G = 0.12, B = 0.12, A = 1 }) end)
            local ctb = Construct("/Script/UMG.TextBlock", gi)
            if ctb then
                StyleText(ctb, cfg.fontTitle, { R = 1, G = 1, B = 1, A = 1 })
                SetText(ctb, "✕")
                pcall(function() close:SetContent(ctb) end)
            end
            local cslot = header:AddChildToHorizontalBox(close)
            if cslot then
                pcall(function() cslot:SetPadding(FMargin(8, 0, 0, 0)) end)
                pcall(function() cslot:SetVerticalAlignment(4) end)
            end
            BindClick(close, function() ModMenu.Close() end)
        end
    end

    local sep = Construct("/Script/UMG.Border", gi)
    if sep then
        Brush(sep, { R = 0.25, G = 0.28, B = 0.34, A = 0.6 })
        pcall(function() sep:SetDesiredSizeOverride(FVector2D(1, 2)) end)
        pcall(function() vbox:AddChildToVerticalBox(sep) end)
    end

    local tabBar = Construct("/Script/UMG.HorizontalBox", gi)
    if tabBar then
        local tslot = vbox:AddChildToVerticalBox(tabBar)
        if tslot then pcall(function() tslot:SetPadding(FMargin(8, 6, 8, 2)) end) end
    end
    State.tabBar = tabBar

    local scroll = Construct("/Script/UMG.ScrollBox", gi)
    if not scroll then return false end
    pcall(function() scroll:SetWidgetVisibility(Vis("Visible")) end)
    local sslot = vbox:AddChildToVerticalBox(scroll)
    if sslot then
        pcall(function() sslot:SetSize({ Value = 1, SizeRule = 1 }) end)
        pcall(function() sslot:SetPadding(FMargin(0, 6, 0, 0)) end)
    end

    local content = Construct("/Script/UMG.VerticalBox", gi)
    if content then pcall(function() scroll:AddChild(content) end) end

    State.panel = panel
    State.content = content
    return true
end

-- =============================================================================
-- ITEM BUILDERS
-- =============================================================================

local function BuildSeparator(ctx, item)
    local sep = Construct("/Script/UMG.Border", ctx.contentBox)
    if sep then
        Brush(sep, { R = 0.25, G = 0.28, B = 0.34, A = 0.55 })
        pcall(function() sep:SetDesiredSizeOverride(FVector2D(1, 3)) end)
        local slot = ctx.contentBox:AddChildToVerticalBox(sep)
        if slot then pcall(function() slot:SetPadding(FMargin(8, 6, 8, 6)) end) end
    end
    local ctrl = { kind = "separator", sectionId = ctx.sectionId, item = item, widget = sep, enabled = true }
    table.insert(ctx.live, ctrl)
    return ctrl
end

local function BuildLabel(ctx, item)
    local cfg = State.cfg
    local tb = Construct("/Script/UMG.TextBlock", ctx.contentBox)
    if tb then
        StyleText(tb, item.size or cfg.fontSize, item.color or cfg.sectionTitleColor)
        SetText(tb, item.label or "")
        local slot = ctx.contentBox:AddChildToVerticalBox(tb)
        if slot then pcall(function() slot:SetPadding(FMargin(10, 10, 10, 2)) end) end
    end
    local ctrl = {
        kind = "label", sectionId = ctx.sectionId, item = item, widget = tb,
        labelWidget = tb, enabled = true,
        SetLabel = function(_, str) SetText(tb, str) end,
    }
    table.insert(ctx.live, ctrl)
    return ctrl
end

local function BuildButton(ctx, item)
    local cfg = State.cfg
    local gi = ctx.gi
    local btn = Construct("/Script/UMG.Button", gi)
    local tb = nil
    if btn then
        tb = Construct("/Script/UMG.TextBlock", gi)
        if tb then
            StyleText(tb, cfg.fontSize, { R = 1, G = 1, B = 1, A = 1 })
            SetText(tb, item.label or "BUTTON")
            pcall(function() btn:SetContent(tb) end)
        end
        pcall(function() btn:SetBackgroundColor(item.bg or cfg.accent) end)
        pcall(function() btn:SetIsEnabled(item.enabled ~= false) end)
        local slot = ctx.contentBox:AddChildToVerticalBox(btn)
        if slot then pcall(function() slot:SetPadding(FMargin(10, 6, 10, 6)) end) end
    end
    local ctrl = {
        kind = "button", sectionId = ctx.sectionId, item = item, widget = btn,
        labelWidget = tb, enabled = item.enabled ~= false, value = false,
    }
    local function OnClick()
        if not ctrl.enabled then return end
        ctrl.value = true
        ctx.SafeCall(ctrl.item.onClick)
    end
    BindClick(btn, OnClick)
    ctrl.SetButtonLabel = function(_, str) SetText(tb, str) end
    ctrl.SetLabel = function(_, str) SetText(tb, str) end
    ctrl.SetEnabled = function(_, b)
        ctrl.enabled = b == true
        pcall(function() btn:SetIsEnabled(ctrl.enabled) end)
    end
    table.insert(ctx.live, ctrl)
    return ctrl
end

local function BuildCheckbox(ctx, item)
    local cfg = State.cfg
    local gi = ctx.gi
    local valueKey = ctx.valueKey
    local initial = item.default ~= false
    local TRACK_W, TRACK_H, HALF = 64, 30, 32

    local row = Construct("/Script/UMG.Border", gi)
    local hbox, label, switchSize, switchBtn, knob, knobSlot = nil, nil, nil, nil, nil, nil
    if row then
        Brush(row, cfg.rowBg)
        pcall(function() row:SetWidgetVisibility(Vis("Visible")) end)
        local rbox = ctx.contentBox:AddChildToVerticalBox(row)
        if rbox then pcall(function() rbox:SetPadding(FMargin(10, 4, 10, 4)) end) end

        hbox = Construct("/Script/UMG.HorizontalBox", gi)
        if hbox then
            pcall(function() row:SetContent(hbox) end)

            label = Construct("/Script/UMG.TextBlock", gi)
            if label then
                StyleText(label, cfg.fontSize, cfg.textColor)
                SetText(label, item.label or "")
                local lslot = hbox:AddChildToHorizontalBox(label)
                if lslot then
                    pcall(function() lslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                    pcall(function() lslot:SetVerticalAlignment(4) end)
                end
            end

            switchSize = Construct("/Script/UMG.SizeBox", gi)
            if switchSize then
                pcall(function() switchSize:SetWidthOverride(TRACK_W) end)
                pcall(function() switchSize:SetHeightOverride(TRACK_H) end)
                switchBtn = Construct("/Script/UMG.Button", gi)
                if switchBtn then
                    pcall(function() switchBtn:SetBackgroundColor({ R = 0.01, G = 0.012, B = 0.02, A = 1 }) end)
                    pcall(function() switchBtn:SetWidgetVisibility(Vis("Visible")) end)
                    pcall(function() switchSize:SetContent(switchBtn) end)

                    local canvas = Construct("/Script/UMG.CanvasPanel", gi)
                    if canvas then
                        pcall(function() switchBtn:SetContent(canvas) end)

                        local function AddHalf(x, color)
                            local seg = Construct("/Script/UMG.Border", gi)
                            if not seg then return end
                            Brush(seg, color)
                            local slot = canvas:AddChildToCanvas(seg)
                            if slot then
                                pcall(function() slot:SetAnchors(FAnchors(0, 0, 0, 0)) end)
                                pcall(function() slot:SetAlignment(FVector2D(0, 0)) end)
                                pcall(function() slot:SetSize(FVector2D(HALF - 2, TRACK_H - 4)) end)
                                pcall(function() slot:SetPosition(FVector2D(x, 2)) end)
                            end
                        end
                        AddHalf(1, cfg.offColor)
                        AddHalf(HALF + 1, cfg.onColor)

                        knob = Construct("/Script/UMG.Border", gi)
                        if knob then
                            Brush(knob, { R = 0.32, G = 0.35, B = 0.40, A = 1 })
                            local knobInner = Construct("/Script/UMG.Border", gi)
                            if knobInner then
                                Brush(knobInner, { R = 0.97, G = 0.97, B = 0.98, A = 1 })
                                pcall(function() knob:SetContent(knobInner) end)
                            end
                            knobSlot = canvas:AddChildToCanvas(knob)
                            if knobSlot then
                                pcall(function() knobSlot:SetAnchors(FAnchors(0, 0, 0, 0)) end)
                                pcall(function() knobSlot:SetAlignment(FVector2D(0, 0)) end)
                                pcall(function() knobSlot:SetSize(FVector2D(HALF - 4, TRACK_H - 6)) end)
                                pcall(function() knobSlot:SetPosition(FVector2D(initial and 3 or HALF + 1, 3)) end)
                            end
                        end
                    end

                    local cslot = hbox:AddChildToHorizontalBox(switchSize)
                    if cslot then
                        pcall(function() cslot:SetSize({ Value = 0, SizeRule = 0 }) end)
                        pcall(function() cslot:SetPadding(FMargin(8, 0, 0, 0)) end)
                        pcall(function() cslot:SetVerticalAlignment(4) end)
                    end
                end
            end
        end
    end

    local ctrl = {
        kind = "checkbox", sectionId = ctx.sectionId, item = item,
        widget = row, labelWidget = label, checkWidget = switchBtn,
        knobWidget = knob, knobSlotWidget = knobSlot, valueKey = valueKey,
        value = initial, enabled = item.enabled ~= false,
    }

    local function SetValue(v, silent)
        v = v == true
        ctrl.value = v
        ctx.values[valueKey] = v
        if knobSlot then
            pcall(function() knobSlot:SetPosition(FVector2D(v and 3 or HALF + 1, 3)) end)
        end
        if not silent then ctx.SafeCall(ctrl.item.onChange, v) end
    end
    ctrl.SetValue = SetValue

    BindClick(switchBtn, function()
        SetValue(not ctrl.value)
    end)

    ctrl.SetEnabled = function(_, b)
        ctrl.enabled = b == true
        pcall(function() switchBtn:SetIsEnabled(ctrl.enabled) end)
    end
    ctrl.SetLabel = function(_, str)
        SetText(label, str)
        ctrl.item.label = str
    end

    table.insert(ctx.live, ctrl)
    ctx.values[valueKey] = initial
    return ctrl
end

local function BuildNumber(ctx, item, isText)
    local cfg = State.cfg
    local gi = ctx.gi
    local valueKey = ctx.valueKey
    local min = tonumber(item.min) or 0
    local max = tonumber(item.max) or 999999
    local def = item.default

    local row = Construct("/Script/UMG.Border", gi)
    local hbox, label, edit = nil, nil, nil
    if row then
        Brush(row, cfg.rowBg)
        local rbox = ctx.contentBox:AddChildToVerticalBox(row)
        if rbox then pcall(function() rbox:SetPadding(FMargin(10, 4, 10, 4)) end) end

        hbox = Construct("/Script/UMG.HorizontalBox", gi)
        if hbox then
            pcall(function() row:SetContent(hbox) end)
            label = Construct("/Script/UMG.TextBlock", gi)
            if label then
                StyleText(label, cfg.fontSize, cfg.textColor)
                SetText(label, item.label or "")
                local lslot = hbox:AddChildToHorizontalBox(label)
                if lslot then
                    pcall(function() lslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                    pcall(function() lslot:SetVerticalAlignment(4) end)
                end
            end
            edit = Construct("/Script/UMG.EditableTextBox", gi)
            if edit then
                local sb = Construct("/Script/UMG.SizeBox", gi)
                if sb then
                    pcall(function() sb:SetWidthOverride(item.fieldWidth or cfg.textWidth) end)
                    pcall(function() sb:SetHeightOverride(46) end)
                    pcall(function() sb:AddChild(edit) end)
                    local eslot = hbox:AddChildToHorizontalBox(sb)
                    if eslot then pcall(function() eslot:SetVerticalAlignment(4) end) end
                end
                if def ~= nil then pcall(function() edit:SetText(tostring(def)) end) end
            end
        end
    end

    local ctrl = {
        kind = isText and "textinput" or "number",
        sectionId = ctx.sectionId, item = item,
        widget = row, labelWidget = label, editWidget = edit, valueKey = valueKey,
        value = def, enabled = item.enabled ~= false, lastText = "",
        _gen = 0, _applied = false,
    }

    local function ApplyText(txt)
        txt = Plain(txt)
        ctrl.lastText = txt
        local v
        if isText then
            v = txt
            if item.maxLength and #v > item.maxLength then
                v = v:sub(1, item.maxLength)
                if edit then pcall(function() edit:SetText(v) end) end
            end
        else
            v = tonumber(txt)
            if v == nil then v = ctrl.value end
            v = math.floor(v * 1000 + 0.5) / 1000
            if v < min then v = min end
            if v > max then v = max end
            if item.integer then v = math.floor(v + 0.5) end
        end
        ctrl.value = v
        ctx.values[valueKey] = v
        if not isText and v ~= nil and tostring(v) ~= txt then
            if edit then pcall(function() edit:SetText(tostring(v)) end) end
        end
        if not ctrl._applied then
            ctrl._applied = true
            ctx.SafeCall(ctrl.item.onChange, v)
        end
    end

    BindEvent(edit, "OnTextChanged", function(txt)
        if ctrl._syncing then return end
        ctrl._gen = ctrl._gen + 1
        local gen = ctrl._gen
        local ms = item.debounceMs or 500
        if ms <= 0 then
            ApplyText(txt)
        else
            Once(ms / 1000, function()
                if ctrl._gen == gen then ApplyText(txt) end
            end)
        end
    end)

    BindEvent(edit, "OnTextCommitted", function(txt)
        if ctrl._syncing then return end
        ctrl._gen = ctrl._gen + 1
        ApplyText(txt)
    end)

    ctrl.SetValue = function(_, v)
        ctrl._syncing = true
        ctrl.value = v
        ctx.values[valueKey] = v
        if edit then pcall(function() edit:SetText(tostring(v)) end) end
        ctrl._syncing = false
    end
    ctrl.SetLabel = function(_, str) SetText(label, str) end
    ctrl.SetEnabled = function(_, b)
        ctrl.enabled = b == true
        pcall(function() if edit then edit:SetIsEnabled(ctrl.enabled) end end)
    end

    table.insert(ctx.live, ctrl)
    ctx.values[valueKey] = def
    return ctrl
end

local function BuildTextInput(ctx, item)
    return BuildNumber(ctx, item, true)
end

local function BuildSlider(ctx, item)
    local cfg = State.cfg
    local gi = ctx.gi
    local valueKey = ctx.valueKey
    local min = tonumber(item.min) or 0
    local max = tonumber(item.max) or 100
    local def = tonumber(item.default)
    if def == nil or def < min then def = min end
    if def > max then def = max end

    local row = Construct("/Script/UMG.Border", gi)
    local hbox, label, slider, valueTB = nil, nil, nil, nil
    if row then
        Brush(row, cfg.rowBg)
        local rbox = ctx.contentBox:AddChildToVerticalBox(row)
        if rbox then pcall(function() rbox:SetPadding(FMargin(10, 4, 10, 4)) end) end

        hbox = Construct("/Script/UMG.HorizontalBox", gi)
        if hbox then
            pcall(function() row:SetContent(hbox) end)

            label = Construct("/Script/UMG.TextBlock", gi)
            if label then
                StyleText(label, cfg.fontSize, cfg.textColor)
                SetText(label, item.label or "")
                local lslot = hbox:AddChildToHorizontalBox(label)
                if lslot then
                    pcall(function() lslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                    pcall(function() lslot:SetVerticalAlignment(4) end)
                end
            end

            slider = Construct("/Script/UMG.Slider", gi)
            if slider then
                pcall(function() slider:SetStepSize(0.01) end)
                pcall(function() slider:SetValue((def - min) / (max - min)) end)
                local sslot = hbox:AddChildToHorizontalBox(slider)
                if sslot then
                    pcall(function() sslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                    pcall(function() sslot:SetVerticalAlignment(4) end)
                end
            end

            valueTB = Construct("/Script/UMG.TextBlock", gi)
            if valueTB then
                StyleText(valueTB, cfg.fontSmall, cfg.onColor)
                SetText(valueTB, tostring(def))
                local vs = hbox:AddChildToHorizontalBox(valueTB)
                if vs then
                    pcall(function() vs:SetPadding(FMargin(8, 0, 4, 0)) end)
                    pcall(function() vs:SetVerticalAlignment(4) end)
                end
            end
        end
    end

    local ctrl = {
        kind = "slider", sectionId = ctx.sectionId, item = item,
        widget = row, labelWidget = label, sliderWidget = slider,
        valueWidget = valueTB, valueKey = valueKey,
        value = def, enabled = item.enabled ~= false,
        _gen = 0,
    }

    local function Norm(v) return (v - min) / (max - min) end

    local function Format(v)
        if item.decimal then
            return string.format("%." .. tostring(item.decimal) .. "f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    local function ApplyValue(raw)
        local v = min + (raw or 0) * (max - min)
        if v < min then v = min end
        if v > max then v = max end
        ctrl.value = v
        ctx.values[valueKey] = v
        SetText(valueTB, Format(v))
        ctrl._gen = ctrl._gen + 1
        local gen = ctrl._gen
        local ms = item.debounceMs or 300
        if ms <= 0 then
            ctx.SafeCall(ctrl.item.onChange, v)
        else
            Once(ms / 1000, function()
                if ctrl._gen == gen then ctx.SafeCall(ctrl.item.onChange, v) end
            end)
        end
    end

    BindEvent(slider, "OnValueChanged", function(raw)
        if ctrl._syncing then return end
        ApplyValue(raw)
    end)

    ctrl.SetValue = function(_, v)
        ctrl._syncing = true
        ctrl.value = v
        ctx.values[valueKey] = v
        SetText(valueTB, Format(v))
        pcall(function() slider:SetValue(Norm(v)) end)
        ctrl._syncing = false
    end
    ctrl.SetLabel = function(_, str) SetText(label, str) end
    ctrl.SetEnabled = function(_, b)
        ctrl.enabled = b == true
        pcall(function() slider:SetIsEnabled(ctrl.enabled) end)
    end

    table.insert(ctx.live, ctrl)
    ctx.values[valueKey] = def
    return ctrl
end

local function BuildDropdown(ctx, item)
    local cfg = State.cfg
    local gi = ctx.gi
    local valueKey = ctx.valueKey
    local opts = {}
    for _, o in ipairs(item.options or {}) do
        if type(o) == "table" then
            opts[#opts + 1] = { value = o.value, label = o.label or tostring(o.value) }
        else
            opts[#opts + 1] = { value = o, label = tostring(o) }
        end
    end
    local function FindLabel(v)
        for _, o in ipairs(opts) do
            if o.value == v then return o.label end
        end
        return tostring(v)
    end
    local initial = item.default
    if initial == nil and #opts > 0 then initial = opts[1].value end

    local row = Construct("/Script/UMG.Border", gi)
    local vbox, hbox, label, header, valueTB, listBox, listInner = nil, nil, nil, nil, nil, nil, nil
    local optionRows = {}

    if row then
        Brush(row, cfg.rowBg)
        local rbox = ctx.contentBox:AddChildToVerticalBox(row)
        if rbox then pcall(function() rbox:SetPadding(FMargin(10, 4, 10, 4)) end) end

        vbox = Construct("/Script/UMG.VerticalBox", gi)
        if vbox then
            pcall(function() row:SetContent(vbox) end)

            hbox = Construct("/Script/UMG.HorizontalBox", gi)
            if hbox then
                local hslot = vbox:AddChildToVerticalBox(hbox)
                if hslot then pcall(function() hslot:SetPadding(FMargin(0, 2, 0, 2)) end) end

                label = Construct("/Script/UMG.TextBlock", gi)
                if label then
                    StyleText(label, cfg.fontSize, cfg.textColor)
                    SetText(label, item.label or "")
                    local lslot = hbox:AddChildToHorizontalBox(label)
                    if lslot then
                        pcall(function() lslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                        pcall(function() lslot:SetVerticalAlignment(4) end)
                    end
                end

                header = Construct("/Script/UMG.Button", gi)
                if header then
                    pcall(function() header:SetBackgroundColor({ R = 0.11, G = 0.13, B = 0.17, A = 1 }) end)
                    local hh = Construct("/Script/UMG.HorizontalBox", gi)
                    if hh then
                        pcall(function() header:SetContent(hh) end)
                        valueTB = Construct("/Script/UMG.TextBlock", gi)
                        if valueTB then
                            StyleText(valueTB, cfg.fontSmall, cfg.textColor)
                            SetText(valueTB, FindLabel(initial))
                            local vs = hh:AddChildToHorizontalBox(valueTB)
                            if vs then
                                pcall(function() vs:SetSize({ Value = 1, SizeRule = 1 }) end)
                                pcall(function() vs:SetPadding(FMargin(10, 0, 10, 0)) end)
                            end
                        end
                        local arrow = Construct("/Script/UMG.TextBlock", gi)
                        if arrow then
                            StyleText(arrow, cfg.fontSmall, cfg.onColor)
                            SetText(arrow, "▾")
                            pcall(function() hh:AddChildToHorizontalBox(arrow) end)
                        end
                    end
                    local hs = hbox:AddChildToHorizontalBox(header)
                    if hs then pcall(function() hs:SetVerticalAlignment(4) end) end
                end
            end

            listBox = Construct("/Script/UMG.SizeBox", gi)
            if listBox then
                local listH = math.max(90, math.min(#opts * 40, 240))
                pcall(function() listBox:SetHeightOverride(listH) end)
                pcall(function() listBox:SetWidthOverride(280) end)
                pcall(function() listBox:SetWidgetVisibility(Vis("Collapsed")) end)
                listInner = Construct("/Script/UMG.ScrollBox", gi)
                if listInner then
                    pcall(function() listInner:SetWidgetVisibility(Vis("Visible")) end)
                    pcall(function() listInner:SetScrollbarVisibility(Vis("Visible")) end)
                    pcall(function() listInner:SetAlwaysShowScrollbar(true) end)
                    pcall(function() listBox:AddChild(listInner) end)
                end
                local lslot = vbox:AddChildToVerticalBox(listBox)
                if lslot then pcall(function() lslot:SetPadding(FMargin(0, 2, 0, 0)) end) end
            end
        end
    end

    local ctrl = {
        kind = "dropdown", sectionId = ctx.sectionId, item = item,
        widget = row, labelWidget = label, headerWidget = header,
        valueWidget = valueTB, listWidget = listBox, valueKey = valueKey,
        value = initial, enabled = item.enabled ~= false, expanded = false,
    }

    local function RebuildOptions()
        if not listInner then return end
        for _, r in ipairs(optionRows) do pcall(function() r:RemoveFromParent() end) end
        optionRows = {}
        local shown = 0
        for _, o in ipairs(opts) do
            if shown >= 6 then break end
            shown = shown + 1
            local ob = Construct("/Script/UMG.Button", gi)
            if ob then
                pcall(function() ob:SetBackgroundColor({ R = 0.10, G = 0.11, B = 0.14, A = 1 }) end)
                local otb = Construct("/Script/UMG.TextBlock", gi)
                if otb then
                    StyleText(otb, cfg.fontSmall, o.value == ctrl.value and cfg.onColor or cfg.textColor)
                    SetText(otb, o.label)
                    pcall(function() ob:SetContent(otb) end)
                end
                local added = ob
                local obSize = Construct("/Script/UMG.SizeBox", gi)
                if obSize then
                    pcall(function() obSize:SetHeightOverride(40) end)
                    pcall(function() obSize:AddChild(ob) end)
                    added = obSize
                    pcall(function() listInner:AddChild(obSize) end)
                else
                    pcall(function() listInner:AddChild(ob) end)
                end
                BindClick(ob, function()
                    ctrl.value = o.value
                    ctx.values[valueKey] = o.value
                    SetText(valueTB, FindLabel(o.value))
                    pcall(function() listBox:SetWidgetVisibility(Vis("Collapsed")) end)
                    ctrl.expanded = false
                    ctx.SafeCall(ctrl.item.onChange, o.value)
                    RebuildOptions()
                end)
                optionRows[#optionRows + 1] = added
            end
        end
    end

    BindClick(header, function()
        if not ctrl.enabled then return end
        ctrl.expanded = not ctrl.expanded
        pcall(function()
            listBox:SetWidgetVisibility(ctrl.expanded and Vis("Visible") or Vis("Collapsed"))
        end)
        if ctrl.expanded then RebuildOptions() end
    end)

    ctrl.SetValue = function(_, v)
        ctrl._syncing = true
        ctrl.value = v
        ctx.values[valueKey] = v
        SetText(valueTB, FindLabel(v))
        ctrl._syncing = false
    end
    ctrl.SetLabel = function(_, str) SetText(label, str) end
    ctrl.SetEnabled = function(_, b)
        ctrl.enabled = b == true
        pcall(function() header:SetIsEnabled(ctrl.enabled) end)
    end

    table.insert(ctx.live, ctrl)
    ctx.values[valueKey] = initial
    return ctrl
end

local function BuildRow(ctx, item)
    local cfg = State.cfg
    local gi = ctx.gi
    local row = Construct("/Script/UMG.Border", gi)
    local hbox = nil
    if row then
        Brush(row, cfg.rowBg)
        local rbox = ctx.contentBox:AddChildToVerticalBox(row)
        if rbox then pcall(function() rbox:SetPadding(FMargin(10, 4, 10, 4)) end) end
        hbox = Construct("/Script/UMG.HorizontalBox", gi)
        if hbox then pcall(function() row:SetContent(hbox) end) end
    end

    local ctrl = {
        kind = "row", sectionId = ctx.sectionId, item = item, widget = row,
        enabled = item.enabled ~= false, value = nil, children = {},
    }

    for i, child in ipairs(item.children or {}) do
        local childCtx = {
            contentBox = hbox, gi = gi, sectionId = ctx.sectionId, live = ctx.live,
            values = ctx.values, valueKey = ctx.valueKey .. ".c" .. i,
            SafeCall = ctx.SafeCall,
        }
        local builder
        if child.type == "button" then builder = BuildButton
        elseif child.type == "checkbox" then builder = BuildCheckbox
        elseif child.type == "number" then builder = BuildNumber
        elseif child.type == "textinput" then builder = BuildTextInput
        else builder = BuildLabel end
        ctrl.children[i] = builder(childCtx, child)
    end

    table.insert(ctx.live, ctrl)
    return ctrl
end

-- =============================================================================
-- BUILD CONTENT
-- =============================================================================

local function BuildContent()
    if not State.content then return end
    local cfg = State.cfg
    local content = State.content
    local gi = GetGameInstance()

    pcall(function()
        local n = content:GetChildrenCount()
        for i = n - 1, 0, -1 do content:RemoveChildAt(i) end
    end)

    local ctx = {
        gi = gi,
        sectionId = nil,
        valueKey = nil,
        live = State.live,
        values = {},
        SafeCall = function(fn, ...)
            if type(fn) ~= "function" then return nil end
            local ok, a = pcall(fn, ...)
            if not ok then
                pcall(function() print("[ModMenu] item error: " .. tostring(a)) end)
            end
            return a
        end,
    }

    State.sectionBoxes = State.sectionBoxes or {}
    State.tabButtons = State.tabButtons or {}
    State.activeTab = State.activeTab or (State.sections[1] and State.sections[1].id)

    local function SelectTab(id)
        State.activeTab = id
        for sid, box in pairs(State.sectionBoxes) do
            local show = (sid == id)
            pcall(function() box:SetWidgetVisibility(show and Vis("Visible") or Vis("Collapsed")) end)
            local tb = State.tabButtons[sid]
            if tb then
                pcall(function() tb:SetBackgroundColor(show and cfg.accent or cfg.headerBg) end)
            end
        end
    end

    if State.tabBar then
        for _, section in ipairs(State.sections) do
            local tb = Construct("/Script/UMG.Button", gi)
            if tb then
                local tbt = Construct("/Script/UMG.TextBlock", gi)
                if tbt then
                    StyleText(tbt, cfg.fontSmall, cfg.textColor)
                    SetText(tbt, section.title or section.id)
                    pcall(function() tb:SetContent(tbt) end)
                end
                pcall(function() tb:SetBackgroundColor(cfg.headerBg) end)
                local tslot = State.tabBar:AddChildToHorizontalBox(tb)
                if tslot then
                    pcall(function() tslot:SetSize({ Value = 1, SizeRule = 1 }) end)
                    pcall(function() tslot:SetPadding(FMargin(2, 0, 2, 0)) end)
                end
                State.tabButtons[section.id] = tb
                BindClick(tb, function() SelectTab(section.id) end)
            end
        end
    end

    for _, section in ipairs(State.sections) do
        local secBox = Construct("/Script/UMG.VerticalBox", gi)
        if secBox then
            pcall(function() content:AddChild(secBox) end)
            State.sectionBoxes[section.id] = secBox
        end

        local sectx = {
            gi = gi,
            sectionId = section.id,
            valueKey = nil,
            live = State.live,
            values = ctx.values,
            SafeCall = ctx.SafeCall,
            contentBox = secBox,
        }

        local sHead = Construct("/Script/UMG.Border", gi)
        if sHead then
            Brush(sHead, cfg.headerBg)
            local hb = Construct("/Script/UMG.HorizontalBox", gi)
            if hb then
                pcall(function() sHead:SetContent(hb) end)
                local ht = Construct("/Script/UMG.TextBlock", gi)
                if ht then
                    StyleText(ht, cfg.fontSize + 2, cfg.sectionTitleColor)
                    SetText(ht, section.title or section.id)
                    pcall(function() hb:AddChildToHorizontalBox(ht) end)
                end
            end
            local hs = secBox:AddChildToVerticalBox(sHead)
            if hs then pcall(function() hs:SetPadding(FMargin(10, 14, 10, 4)) end) end
        end

        for _, item in ipairs(section.items) do
            sectx.valueKey = section.id .. "." .. item.id
            local builder
            if item.type == "checkbox" then builder = BuildCheckbox
            elseif item.type == "button" then builder = BuildButton
            elseif item.type == "dropdown" then builder = BuildDropdown
            elseif item.type == "number" then builder = BuildNumber
            elseif item.type == "textinput" then builder = BuildTextInput
            elseif item.type == "slider" then builder = BuildSlider
            elseif item.type == "row" then builder = BuildRow
            elseif item.type == "label" then builder = BuildLabel
            else builder = BuildSeparator end
            pcall(builder, sectx, item)
        end
    end

    SelectTab(State.activeTab)
end

-- =============================================================================
-- SHELL
-- =============================================================================

local ModMenu = {}
_G.ModMenu = ModMenu

function ModMenu.Init(cfg)
    cfg = cfg or {}
    for k, v in pairs(cfg) do State.cfg[k] = v end
end

function ModMenu.Register(section)
    if not section or not section.id then return end
    local def = { id = section.id, title = section.title or section.id, items = section.items or {} }
    for i, s in ipairs(State.sections) do
        if s.id == section.id then
            State.sections[i] = def
            return
        end
    end
    State.sections[#State.sections + 1] = def
end

function ModMenu.Get(sectionId, itemId)
    return State.index[sectionId] and State.index[sectionId][itemId]
end

function ModMenu.Set(sectionId, itemId, value)
    local ctrl = ModMenu.Get(sectionId, itemId)
    if ctrl and ctrl.SetValue then ctrl:SetValue(value) end
end

function ModMenu.SetLabel(sectionId, itemId, str)
    local ctrl = ModMenu.Get(sectionId, itemId)
    if ctrl and ctrl.SetLabel then ctrl:SetLabel(str) end
end

function ModMenu.SetButtonLabel(sectionId, itemId, str)
    local ctrl = ModMenu.Get(sectionId, itemId)
    if ctrl and ctrl.SetButtonLabel then ctrl:SetButtonLabel(str) end
end

function ModMenu.SetEnabled(sectionId, itemId, enabled)
    local ctrl = ModMenu.Get(sectionId, itemId)
    if ctrl and ctrl.SetEnabled then ctrl:SetEnabled(enabled) end
end

function ModMenu.SetDock(dock)
    State.cfg.dock = dock
    if State.panel then
        local slot = nil
        pcall(function()
            local WLL = import("WidgetLayoutLibrary")
            if WLL then slot = WLL.SlotAsCanvasSlot(State.panel) end
        end)
        local dx0, dy0, dx1, dy1 = DockRect()
        if slot then ConfigCanvasSlot(slot, dx0, dy0, dx1, dy1, State.cfg.zMenu) end
    end
end

function ModMenu.IsOpen()
    return State.open
end

function ModMenu.Rebuild()
    if not State.content then return end
    State.live = {}
    if State.tabBar then
        pcall(function()
            local n = State.tabBar:GetChildrenCount()
            for i = n - 1, 0, -1 do State.tabBar:RemoveChildAt(i) end
        end)
    end
    BuildContent()
    State.index = {}
    for _, ctrl in ipairs(State.live) do
        if ctrl.item and ctrl.item.id and ctrl.sectionId then
            State.index[ctrl.sectionId] = State.index[ctrl.sectionId] or {}
            if not State.index[ctrl.sectionId][ctrl.item.id] then
                State.index[ctrl.sectionId][ctrl.item.id] = ctrl
            end
        end
    end
end

function ModMenu.Open()
    if State.open then return true end
    Log("Open() called")

    if not State.created then
        local root, canvas = LoadRoot()
        if not root or not canvas then
            Log("Open FAILED: LoadRoot gave nil")
            return false
        end
        State.root = root
        State.canvas = canvas
        if not BuildPanel() then
            Log("Open FAILED: BuildPanel returned false")
            return false
        end
        BuildContent()
        State.created = true
        Log("Open: panel built")
    end

    if State.root and slua.isValid(State.root) then
        pcall(function() State.root:SetWidgetVisibility(Vis("Visible")) end)
        State.open = true
        State.index = {}
        for _, ctrl in ipairs(State.live) do
            if ctrl.item and ctrl.item.id and ctrl.sectionId then
                State.index[ctrl.sectionId] = State.index[ctrl.sectionId] or {}
                if not State.index[ctrl.sectionId][ctrl.item.id] then
                    State.index[ctrl.sectionId][ctrl.item.id] = ctrl
                end
            end
        end
        return true
    end
    return false
end

function ModMenu.Close()
    if not State.open then return end
    Log("Close() called")
    if State.root and slua.isValid(State.root) then
        pcall(function() State.root:SetWidgetVisibility(Vis("Collapsed")) end)
        pcall(function() State.root:SetRenderOpacity(0) end)
    end
    State.open = false
    SaveMenuCfg()
end

State._toggleLock = 0

function ModMenu.Toggle()
    local now = os.clock()
    if State._toggleLock and now - State._toggleLock < 0.3 then
        Log("Toggle() ignored (lock)")
        return
    end
    State._toggleLock = now
    Log("Toggle() called, open=" .. tostring(State.open))
    if State.open then
        ModMenu.Close()
    else
        ModMenu.Open()
    end
end

function ModMenu.Shutdown()
    ModMenu.Close()
    State.created = false
end

_G.ModMenuToggle = function() ModMenu.Toggle() end
_G.ModMenuOpen = function() ModMenu.Open() end
_G.ModMenuClose = function() ModMenu.Close() end

-- =============================================================================
-- FINEL MENU (wired to finelv2 config)
-- =============================================================================

ModMenu.Init({ title = "FINEL MENU" })

local function PM(k, def)
    local m = _G.PlayerMapMarker
    if m == nil or m[k] == nil then return def end
    return m[k]
end

local function AC(k, def)
    local a = _G.AimbotConfig
    if a == nil or a[k] == nil then return def end
    return a[k]
end

local function MC(k, def)
    local m = _G.MemoryConfig
    if m == nil or m[k] == nil then return def end
    return m[k]
end

-- =============================================================================
-- PERSIST toggle values / data to sukuna_settings.cfg (MENU_ prefix)
-- =============================================================================

local MENU_SAVE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/CHETAN_MODS/sukuna_settings.cfg"

local MENU_KEYS = {
    { "AimbotConfig", { "Enable", "Bone", "Speed", "FOV", "Distance", "Smooth", "VisCheck", "IgnoreKnock", "IgnoreBot", "Condition", "RecoilComp", "BurstAim", "Prediction", "BulletSpeed" } },
    { "MemoryConfig", { "RemoveGrass", "RemoveTrees", "RemoveFog", "BlackSky", "UnlockFPS", "IpadView", "IpadFOV", "SmallCrosshair" } },
    { "PlayerMapMarker", { "bUseScreenESP", "bUseSnapLines", "bUseLineVisCheck", "bShowDistance", "bIncludeAI", "bIncludeMe", "bUseRedBox" } },
    { "RedBoxOverlay", { "Red", "Green", "Blue", "LayerAlpha", "NumLayers", "Width", "Height", "FontSize" } },
}

local function LoadMenuCfg()
    local f = io.open(MENU_SAVE, "r")
    if not f then return end
    local data = f:read("*a"); f:close()
    for line in (data or ""):gmatch("[^\r\n]+") do
        local k, v = line:match("^MENU_([%w_.]+)=(.+)$")
        if k then
            local n
            if v == "true" then n = true
            elseif v == "false" then n = false
            else n = tonumber(v) end
            if n ~= nil then
                for _, grp in ipairs(MENU_KEYS) do
                    local tbl = _G[grp[1]]
                    if tbl then
                        for _, key in ipairs(grp[2]) do
                            if k == grp[1] .. "." .. key then
                                tbl[key] = n
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

local function SaveMenuCfg()
    pcall(function()
        local lines = {}
        local f = io.open(MENU_SAVE, "r")
        if f then
            for line in (f:read("*a") or ""):gmatch("[^\r\n]+") do
                if not line:match("^MENU_") then lines[#lines + 1] = line end
            end
            f:close()
        end
        for _, grp in ipairs(MENU_KEYS) do
            local tbl = _G[grp[1]]
            if tbl then
                for _, key in ipairs(grp[2]) do
                    local v = tbl[key]
                    if v ~= nil and (type(v) == "boolean" or type(v) == "number") then
                        lines[#lines + 1] = "MENU_" .. grp[1] .. "." .. key .. "=" .. tostring(v)
                    end
                end
            end
        end
        f = io.open(MENU_SAVE, "w")
        if f then f:write(table.concat(lines, "\n")); f:close() end
    end)
end

LoadMenuCfg()

-- ESP / VISUAL
ModMenu.Register({
    id = "visual", title = "VISUAL", items = {
        { type = "checkbox", id = "espOn", label = "ESP",
          default = PM("bUseScreenESP", true),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if not m then return end
              m.bUseScreenESP = v == true
              if not v then
                  for _, d in pairs(m.ESPWidgets or {}) do
                      local c = d.Widget and (d.Widget.Container or d.Widget)
                      if c then pcall(function() c:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end) end
                  end
              end
          end },
        { type = "checkbox", id = "espLine", label = "ESP Line",
          default = PM("bUseSnapLines", true),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if not m then return end
              m.bUseSnapLines = v == true
              if not v and m.ClearAllSnapLines then m.ClearAllSnapLines() end
          end },
        { type = "checkbox", id = "lineVis", label = "Line Vis Check",
          default = PM("bUseLineVisCheck", true),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if m then m.bUseLineVisCheck = v == true end
          end },
        { type = "checkbox", id = "espDist", label = "ESP Distance",
          default = PM("bShowDistance", true),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if m then m.bShowDistance = v == true end
          end },
        { type = "checkbox", id = "incAI", label = "Include AI",
          default = PM("bIncludeAI", true),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if m then m.bIncludeAI = v == true end
          end },
        { type = "checkbox", id = "incMe", label = "Include Me",
          default = PM("bIncludeMe", false),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if m then m.bIncludeMe = v == true end
          end },
    },
})

-- AIMBOT
ModMenu.Register({
    id = "aimbot", title = "AIMBOT", items = {
        { type = "checkbox", id = "aimOn", label = "Aimbot",
          default = AC("Enable", true),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Enable = v == true end
          end },
        { type = "dropdown", id = "aimBone", label = "Aim Bone",
          default = AC("Bone", 2),
          options = { { value = 1, label = "Head" }, { value = 2, label = "Chest" }, { value = 3, label = "Waist" } },
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Bone = v end
          end },
        { type = "slider", id = "aimFov", label = "Aim FOV",
          default = AC("FOV", 30), min = 5, max = 300, integer = true,
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.FOV = v end
          end },
        { type = "slider", id = "aimDist", label = "Aim Distance",
          default = AC("Distance", 250), min = 20, max = 500, integer = true,
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Distance = v end
          end },
        { type = "slider", id = "aimSpd", label = "Aim Speed",
          default = AC("Speed", 50), min = 1, max = 100, integer = true,
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Speed = v end
          end },
        { type = "slider", id = "aimRecoil", label = "Recoil Comp",
          default = AC("RecoilComp", 0), min = 0, max = 100, integer = true,
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.RecoilComp = v end
          end },
        { type = "checkbox", id = "aimBurst", label = "Burst Aim (Auto Recoil)",
          default = AC("BurstAim", false),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.BurstAim = v == true end
          end },
        { type = "checkbox", id = "aimPred", label = "Prediction (Lead + Drop)",
          default = AC("Prediction", true),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Prediction = v == true end
          end },
        { type = "slider", id = "aimBspd", label = "Bullet Speed (0=Auto)",
          default = AC("BulletSpeed", 0), min = 0, max = 1500, integer = true,
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.BulletSpeed = v end
          end },
        { type = "dropdown", id = "aimCond", label = "Aim Condition",
          default = AC("Condition", 1),
          options = { { value = 1, label = "While Firing" }, { value = 2, label = "Always" } },
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Condition = v end
          end },
        { type = "checkbox", id = "aimSmooth", label = "Smooth",
          default = AC("Smooth", true),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.Smooth = v == true end
          end },
        { type = "checkbox", id = "aimVis", label = "Vis Check",
          default = AC("VisCheck", true),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.VisCheck = v == true end
          end },
        { type = "checkbox", id = "aimKnock", label = "Ignore Knocked",
          default = AC("IgnoreKnock", false),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.IgnoreKnock = v == true end
          end },
        { type = "checkbox", id = "aimBot", label = "Ignore Bots",
          default = AC("IgnoreBot", false),
          onChange = function(v)
              local a = _G.AimbotConfig
              if a then a.IgnoreBot = v == true end
          end },
    },
})

-- MEMORY
ModMenu.Register({
    id = "memory", title = "MEMORY", items = {
        { type = "checkbox", id = "memGrass", label = "Remove Grass",
          default = MC("RemoveGrass", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if not m then return end
              m.RemoveGrass = v == true
              if _G.ApplyMemoryFeatures then _G.ApplyMemoryFeatures() end
          end },
        { type = "checkbox", id = "memTrees", label = "Remove Trees",
          default = MC("RemoveTrees", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if not m then return end
              m.RemoveTrees = v == true
              if _G.ApplyMemoryFeatures then _G.ApplyMemoryFeatures() end
          end },
        { type = "checkbox", id = "memFog", label = "Remove Fog",
          default = MC("RemoveFog", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if not m then return end
              m.RemoveFog = v == true
              if _G.ApplyMemoryFeatures then _G.ApplyMemoryFeatures() end
          end },
        { type = "checkbox", id = "memSky", label = "Black Sky",
          default = MC("BlackSky", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if not m then return end
              m.BlackSky = v == true
              if _G.ApplyMemoryFeatures then _G.ApplyMemoryFeatures() end
          end },
        { type = "checkbox", id = "memFps", label = "Unlock 165 FPS",
          default = MC("UnlockFPS", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if not m then return end
              m.UnlockFPS = v == true
              if _G.ApplyMemoryFeatures then _G.ApplyMemoryFeatures() end
          end },
        { type = "checkbox", id = "memIpad", label = "iPad View",
          default = MC("IpadView", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if m then m.IpadView = v == true end
          end },
        { type = "slider", id = "memIpadFov", label = "iPad FOV",
          default = MC("IpadFOV", 120), min = 60, max = 160, integer = true,
          onChange = function(v)
              local m = _G.MemoryConfig
              if m then m.IpadFOV = v end
          end },
        { type = "checkbox", id = "memCross", label = "Small Crosshair",
          default = MC("SmallCrosshair", false),
          onChange = function(v)
              local m = _G.MemoryConfig
              if m then m.SmallCrosshair = v == true end
          end },
    },
})

-- RED BOX
local RB_COLORS = {
    { value = 1, label = "Red", color = { R = 1, G = 0.05, B = 0.05 } },
    { value = 2, label = "Green", color = { R = 0.05, G = 1, B = 0.05 } },
    { value = 3, label = "Blue", color = { R = 0.05, G = 0.4, B = 1 } },
    { value = 4, label = "Cyan", color = { R = 0, G = 1, B = 1 } },
    { value = 5, label = "Yellow", color = { R = 1, G = 1, B = 0 } },
    { value = 6, label = "Magenta", color = { R = 1, G = 0, B = 1 } },
    { value = 7, label = "White", color = { R = 1, G = 1, B = 1 } },
}

local function RB(k, def)
    local r = _G.RedBoxOverlay
    if r == nil or r[k] == nil then return def end
    return r[k]
end

local function RebuildRedBox(mutator)
    local r = _G.RedBoxOverlay
    if r == nil then return end
    if mutator then
        local ok, err = pcall(mutator)
        if not ok then
            pcall(function() print("[ModMenu] redbox error: " .. tostring(err)) end)
        end
    end
    local wasActive = r.bActive == true
    pcall(function() r.Stop() end)
    if wasActive or PlayerMapMarker.bUseRedBox ~= false then
        pcall(function() r.Start() end)
    end
end

ModMenu.Register({
    id = "redbox", title = "RED BOX", items = {
        { type = "checkbox", id = "rbOn", label = "Red Box",
          default = PM("bUseRedBox", true),
          onChange = function(v)
              local m = _G.PlayerMapMarker
              if m then m.bUseRedBox = v == true end
              RebuildRedBox(nil)
          end },
        { type = "dropdown", id = "rbColor", label = "Box Color",
          default = 1,
          options = RB_COLORS,
          onChange = function(v)
              for _, o in ipairs(RB_COLORS) do
                  if o.value == v then
                      RebuildRedBox(function()
                          local r = _G.RedBoxOverlay
                          r.Red = o.color.R
                          r.Green = o.color.G
                          r.Blue = o.color.B
                      end)
                      break
                  end
              end
          end },
        { type = "slider", id = "rbAlpha", label = "Layer Alpha",
          default = RB("LayerAlpha", 0.038), min = 0.005, max = 0.2, decimal = 3, debounceMs = 100,
          onChange = function(v)
              RebuildRedBox(function() _G.RedBoxOverlay.LayerAlpha = v end)
          end },
        { type = "slider", id = "rbLayers", label = "Layers",
          default = RB("NumLayers", 50), min = 10, max = 200, integer = true, debounceMs = 100,
          onChange = function(v)
              RebuildRedBox(function() _G.RedBoxOverlay.NumLayers = v end)
          end },
        { type = "slider", id = "rbWidth", label = "Width",
          default = RB("Width", 300), min = 100, max = 600, integer = true, debounceMs = 100,
          onChange = function(v)
              RebuildRedBox(function() _G.RedBoxOverlay.Width = v end)
          end },
        { type = "slider", id = "rbHeight", label = "Height",
          default = RB("Height", 28), min = 10, max = 80, integer = true, debounceMs = 100,
          onChange = function(v)
              RebuildRedBox(function() _G.RedBoxOverlay.Height = v end)
          end },
        { type = "slider", id = "rbFont", label = "Font Size",
          default = RB("FontSize", 16), min = 8, max = 40, integer = true, debounceMs = 100,
          onChange = function(v)
              RebuildRedBox(function() _G.RedBoxOverlay.FontSize = v end)
          end },
    },
})

-- =============================================================================
-- STARTUP
-- =============================================================================

pcall(LogReset)

-- Start a watcher loop to keep the MENU button on screen
Loop(2, function()
    EnsureButton()
    SaveMenuCfg()
end)

-- Immediate first attempt (short delay so the game settles)
Once(0.8, function()
    EnsureButton()
end)