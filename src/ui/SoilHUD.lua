-- =========================================================
-- FS25 Realistic Soil & Fertilizer (version 1.0.7.1)
-- =========================================================
-- Soil HUD Overlay - legend/reference display (toggle with J key)
-- =========================================================
-- Author: TisonK
-- =========================================================
---@class SoilHUD

SoilHUD = {}
local SoilHUD_mt = Class(SoilHUD)

function SoilHUD.new(soilSystem, settings)
    local self = setmetatable({}, SoilHUD_mt)

    self.soilSystem = soilSystem
    self.settings = settings
    self.initialized = false
    self.backgroundOverlay = nil
    self.visible = true  -- Runtime visibility toggle (J key)

    -- Panel dimensions from constants
    self.panelWidth = SoilConstants.HUD.PANEL_WIDTH
    self.panelHeight = SoilConstants.HUD.PANEL_HEIGHT

    -- Position will be set based on hudPosition setting
    local defaultPos = SoilConstants.HUD.POSITIONS[1]
    self.panelX = defaultPos.x
    self.panelY = defaultPos.y
    self.lastHudPosition = nil  -- Track position changes

    return self
end

-- Calculate HUD position based on preset setting
function SoilHUD:updatePosition()
    local position = self.settings.hudPosition or 1

    -- Get position from constants (1=Top Right, 2=Top Left, 3=Bottom Right, 4=Bottom Left, 5=Center Right)
    local pos = SoilConstants.HUD.POSITIONS[position]
    if pos then
        self.panelX = pos.x
        self.panelY = pos.y
    end

    -- Update overlay position if it exists
    if self.backgroundOverlay and self.backgroundOverlay.setPosition then
        self.backgroundOverlay:setPosition(self.panelX, self.panelY)
    end
end

function SoilHUD:initialize()
    if self.initialized then return true end

    -- Set position based on user preference
    self:updatePosition()

    -- Create background overlay with a 1x1 white pixel (we'll color it black)
    -- Using g_baseUIFilename which is a tiny white texture built into FS25
    self.backgroundOverlay = Overlay.new(g_baseUIFilename, self.panelX, self.panelY, self.panelWidth, self.panelHeight)
    self.backgroundOverlay:setUVs(g_colorBgUVs)
    self.backgroundOverlay:setColor(0, 0, 0, 0.7)

    -- Sprayer rate panel: pre-create background + one overlay per rate step
    local rateH   = self:py(28)
    local rateBgW = self.panelWidth
    local rateBgH = rateH + self:py(18)  -- buttons + label row
    self.ratePanelBg = Overlay.new(g_baseUIFilename, self.panelX, 0, rateBgW, rateBgH)
    self.ratePanelBg:setUVs(g_colorBgUVs)
    self.ratePanelBg:setColor(0, 0, 0, 0.7)

    local steps = SoilConstants.SPRAYER_RATE.STEPS
    self.rateButtonOverlays = {}
    for i = 1, #steps do
        local ov = Overlay.new(g_baseUIFilename, 0, 0, 0, 0)
        ov:setUVs(g_colorBgUVs)
        table.insert(self.rateButtonOverlays, ov)
    end

    self.initialized = true
    SoilLogger.info("Soil HUD overlay initialized at position %d (%0.3f, %0.3f)",
        self.settings.hudPosition or 1, self.panelX, self.panelY)

    return true
end

function SoilHUD:delete()
    if self.backgroundOverlay then
        self.backgroundOverlay:delete()
        self.backgroundOverlay = nil
    end

    if self.ratePanelBg then
        self.ratePanelBg:delete()
        self.ratePanelBg = nil
    end

    for _, ov in ipairs(self.rateButtonOverlays or {}) do
        ov:delete()
    end
    self.rateButtonOverlays = {}

    self.initialized = false
    SoilLogger.info("Soil HUD overlay deleted")
end

-- Update HUD (called every frame)
function SoilHUD:update(dt)
    -- Check if position setting changed and update if needed
    local currentPosition = self.settings.hudPosition or 1
    if self.lastHudPosition ~= currentPosition then
        self:updatePosition()
        self.lastHudPosition = currentPosition
        SoilLogger.info("HUD position changed to preset %d", currentPosition)
    end
end

-- Toggle HUD visibility (called by J key)
function SoilHUD:toggleVisibility()
    self.visible = not self.visible
    local message = self.visible and "Soil HUD shown" or "Soil HUD hidden"
    SoilLogger.info(message)

    -- Show in-game notification so user sees the toggle
    if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
        g_currentMission.hud:showBlinkingWarning(message, 2000)
    end
end

--- Draw HUD (called every frame from main update loop)
---@return nil
function SoilHUD:draw()
    if not self.initialized then return end
    if not self.settings.enabled then return end
    if not self.settings.showHUD then return end
    if not self.visible then return end
    if not g_currentMission then return end

    -- Don't draw over menus or dialogs
    if g_gui and (g_gui:getIsGuiVisible() or g_gui:getIsDialogVisible()) then
        return
    end

    -- Don't draw over the fullscreen map
    if g_currentMission.hud and g_currentMission.hud.ingameMap then
        if g_currentMission.hud.ingameMap.state == IngameMap.STATE_LARGE_MAP then
            return
        end
    end

    self:drawPanel()
    self:drawSprayerRatePanel()
end

--- Draw the static legend/reference panel.
--- Shows key bindings (J/K) and nutrient status thresholds color-coded by status.
--- Thresholds match SoilConstants.STATUS_THRESHOLDS (Good = N>=50/P>=45/K>=40, etc.)
function SoilHUD:drawPanel()
    local colorTheme   = self.settings.hudColorTheme or 1
    local fontSize     = self.settings.hudFontSize or 2
    local transparency = self.settings.hudTransparency or 3
    local compactMode  = self.settings.hudCompactMode or false

    -- Clamp to valid range
    if colorTheme < 1 or colorTheme > 4 then
        colorTheme = math.max(1, math.min(4, colorTheme))
    end

    -- Render background
    if self.backgroundOverlay then
        local alpha = SoilConstants.HUD.TRANSPARENCY_LEVELS[transparency]
        self.backgroundOverlay:setColor(0, 0, 0, alpha)
        self.backgroundOverlay:render()
    end

    local theme    = SoilConstants.HUD.COLOR_THEMES[colorTheme]
    local themeR   = theme.r
    local themeG   = theme.g
    local themeB   = theme.b
    local fontMult = SoilConstants.HUD.FONT_SIZE_MULTIPLIERS[fontSize]
    local lineH    = compactMode and SoilConstants.HUD.COMPACT_LINE_HEIGHT or SoilConstants.HUD.NORMAL_LINE_HEIGHT
    local needsShadow = transparency <= 2

    if needsShadow then setTextShadow(true) end

    local x = self.panelX + 0.005
    local y = self.panelY + self.panelHeight - 0.018

    -- Title
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1.0, 1.0, 1.0, 1.0)
    renderText(x, y, 0.014 * fontMult, "SOIL LEGEND")
    y = y - lineH * 1.4
    setTextBold(false)

    -- Key bindings
    setTextColor(themeR, themeG, themeB, 1.0)
    renderText(x, y, 0.011 * fontMult, "J = Toggle HUD")
    y = y - lineH
    renderText(x, y, 0.011 * fontMult, "K = Soil Report")
    y = y - lineH * 1.3

    -- Nutrient status legend — color matches the in-game status colors
    -- Good  = value >= fair threshold (50 / 45 / 40)
    -- Fair  = value >= poor threshold (30 / 25 / 20)
    -- Poor  = value below poor threshold
    setTextColor(0.3, 0.9, 0.3, 1.0)
    renderText(x, y, 0.011 * fontMult, "Good: N>50, P>45, K>40")
    y = y - lineH

    setTextColor(0.9, 0.9, 0.2, 1.0)
    renderText(x, y, 0.011 * fontMult, "Fair: N>30, P>25, K>20")
    y = y - lineH

    setTextColor(0.9, 0.3, 0.3, 1.0)
    renderText(x, y, 0.011 * fontMult, "Poor: needs fertilizer")
    y = y - lineH * 1.3

    -- pH reference
    setTextColor(themeR, themeG, themeB, 0.75)
    renderText(x, y, 0.010 * fontMult, "pH ideal: 6.5 - 7.0")

    -- Reset text state
    if needsShadow then setTextShadow(false) end
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end

--- Returns the sprayer vehicle the local player is currently operating, or nil.
---@return table|nil vehicle
function SoilHUD:getCurrentSprayer()
    local player = g_localPlayer
    if player == nil then return nil end
    if type(player.getIsInVehicle) ~= "function" then return nil end
    if not player:getIsInVehicle() then return nil end
    local vehicle = player:getCurrentVehicle()
    if vehicle and vehicle.spec_sprayer then
        return vehicle
    end
    return nil
end

--- Draw the application rate selector panel below the legend when player is in a sprayer.
--- Highlights the active step; shows a burn warning for rates above the risk threshold.
function SoilHUD:drawSprayerRatePanel()
    if not self.ratePanelBg or not self.rateButtonOverlays then return end

    local sprayer = self:getCurrentSprayer()
    if sprayer == nil then return end

    local rm = g_SoilFertilityManager and g_SoilFertilityManager.sprayerRateManager
    if rm == nil then return end

    local steps      = SoilConstants.SPRAYER_RATE.STEPS
    local currentIdx = rm:getIndex(sprayer.id)
    local fontMult   = SoilConstants.HUD.FONT_SIZE_MULTIPLIERS[self.settings.hudFontSize or 2]

    -- Panel sits directly below the legend panel with a small gap
    local gap    = self:py(6)
    local rateH  = self:py(24)
    local labelH = self:py(14)
    local panelX = self.panelX
    local panelY = self.panelY - gap - rateH - labelH - self:py(4)
    local panelW = self.panelWidth

    -- Background
    self.ratePanelBg:setPosition(panelX, panelY)
    self.ratePanelBg:setDimension(panelW, rateH + labelH + self:py(8))
    self.ratePanelBg:setColor(0, 0, 0, 0.72)
    self.ratePanelBg:render()

    -- Label row
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(1, 1, 1, 0.85)
    renderText(panelX + panelW * 0.5, panelY + rateH + self:py(4), 0.010 * fontMult, "APP. RATE  ( [ / ] )")
    setTextBold(false)

    -- Step button colors: cool→green→warm→hot
    local COLORS = {
        { 0.35, 0.55, 0.95 },  -- 50%  blue
        { 0.25, 0.75, 0.90 },  -- 75%  cyan
        { 0.20, 0.82, 0.35 },  -- 100% green
        { 0.92, 0.82, 0.12 },  -- 125% yellow
        { 0.95, 0.50, 0.10 },  -- 150% orange
        { 0.95, 0.18, 0.18 },  -- 200% red
    }
    local LABELS = { "50%", "75%", "100%", "125%", "150%", "200%" }

    local pad  = self:px(3)
    local btnW = (panelW - pad * (#steps + 1)) / #steps
    local btnY = panelY + self:py(2)

    for i, _ in ipairs(steps) do
        local btnX  = panelX + pad + (i - 1) * (btnW + pad)
        local col   = COLORS[i]
        local alpha = (i == currentIdx) and 0.95 or 0.28

        local ov = self.rateButtonOverlays[i]
        ov:setPosition(btnX, btnY)
        ov:setDimension(btnW, rateH)
        ov:setColor(col[1], col[2], col[3], alpha)
        ov:render()

        local textAlpha = (i == currentIdx) and 1.0 or 0.55
        setTextColor(1, 1, 1, textAlpha)
        if i == currentIdx then setTextBold(true) end
        renderText(btnX + btnW * 0.5, btnY + self:py(7), 0.010 * fontMult, LABELS[i])
        if i == currentIdx then setTextBold(false) end
    end

    -- Burn warning below buttons
    local curRate = steps[currentIdx]
    local warnY   = panelY - self:py(14)
    if curRate >= SoilConstants.SPRAYER_RATE.BURN_GUARANTEED_THRESHOLD then
        setTextColor(1.0, 0.15, 0.15, 1.0)
        renderText(panelX + panelW * 0.5, warnY, 0.010 * fontMult, "BURN RISK: GUARANTEED")
    elseif curRate > SoilConstants.SPRAYER_RATE.BURN_RISK_THRESHOLD then
        setTextColor(0.95, 0.65, 0.10, 1.0)
        renderText(panelX + panelW * 0.5, warnY, 0.010 * fontMult, "BURN RISK: POSSIBLE")
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

--- Normalised pixel helpers so button sizes are resolution-independent.
--- FS25 uses 0.0–1.0 screen-space coords; these convert from logical pixels.
function SoilHUD:px(pixels)
    return pixels / 1920
end

function SoilHUD:py(pixels)
    return pixels / 1080
end
