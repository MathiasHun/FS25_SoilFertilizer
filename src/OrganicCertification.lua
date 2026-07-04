-- =========================================================
-- OrganicCertification.lua
-- =========================================================
-- Per-field organic certification as a thin state layer over the existing
-- soil substrate (OM, N/P/K, the input hooks). A field moves:
--
--   conventional  --(player opts in)-->  in_transition  --(enough days)-->  certified
--
-- Rules (design locked 2026-07-03):
--   - Entry is EXPLICIT OPT-IN only. Fields never auto-transition.
--   - Transition length is difficulty-scaled in in-game days (SoilConstants.ORGANIC.TRANSITION_DAYS).
--   - Applying any synthetic (non-approved) input to a transitioning OR certified
--     field is a breach: FULL RESET to conventional.
--
-- State lives on soilSystem.fieldData[fieldId].organic and is saved/loaded with
-- the rest of the per-field record. This module owns the LOGIC only.
--
-- SF owns this core; market premium / organic livestock / FarmTablet display are
-- downstream consumers in their own repos and only READ getFieldOrganicState().
-- =========================================================

OrganicCertification = {}
local OrganicCertification_mt = Class(OrganicCertification)

--- Constructor
-- @param soilSystem  SoilFertilitySystem (owns fieldData)
function OrganicCertification.new(soilSystem)
    local self = setmetatable({}, OrganicCertification_mt)
    self.soilSystem = soilSystem
    self.lastProcessedDay = nil
    return self
end

-- ---------------------------------------------------------
-- State helpers
-- ---------------------------------------------------------

--- Ensure a field record has an organic sub-table, defaulting to conventional.
-- @param field  fieldData entry
function OrganicCertification:ensureState(field)
    if not field then return end
    if not field.organic then
        field.organic = {
            state       = SoilConstants.ORGANIC.STATE_CONVENTIONAL,
            startDay    = 0,   -- monotonic day the transition began
            certifiedDay = 0,  -- monotonic day certification was reached
            breaches    = 0,   -- lifetime count of synthetic-input breaches
        }
    end
    return field.organic
end

--- Current monotonic in-game day (safe). Monotonic so day arithmetic is valid.
function OrganicCertification:getCurrentDay()
    if g_currentMission and g_currentMission.environment then
        return g_currentMission.environment.currentMonotonicDay
            or g_currentMission.environment.currentDay or 0
    end
    return 0
end

--- Active difficulty (1 Simple / 2 Realistic / 3 Hardcore), defaulting to 2.
function OrganicCertification:getDifficulty()
    local d
    if g_SoilFertilityManager and g_SoilFertilityManager.settings then
        d = g_SoilFertilityManager.settings.difficulty
    end
    if type(d) ~= "number" or d < 1 or d > 3 then d = 2 end
    return d
end

--- In-game days required to complete the transition at the current difficulty.
function OrganicCertification:getTransitionDays()
    local list = SoilConstants.ORGANIC.TRANSITION_DAYS
    return list[self:getDifficulty()] or list[2] or 120
end

--- Is a fill type name allowed under organic rules?
-- @param fillTypeName  upper-case fill type name (e.g. "MANURE", "UREA")
-- @return boolean
function OrganicCertification:isApprovedInput(fillTypeName)
    if not fillTypeName then return true end
    return SoilConstants.ORGANIC.APPROVED_INPUTS[fillTypeName] == true
end

-- ---------------------------------------------------------
-- Read API (consumed by market / livestock / tablet, other repos)
-- ---------------------------------------------------------

--- Snapshot of a field's organic status.
-- @param fieldId  field id
-- @return table|nil  { state, daysAccrued, transitionDaysNeeded, certified, breaches }
function OrganicCertification:getFieldOrganicState(fieldId)
    local field = self.soilSystem and self.soilSystem.fieldData and self.soilSystem.fieldData[fieldId]
    if not field then return nil end
    self:ensureState(field)
    local o = field.organic
    local needed = self:getTransitionDays()
    local accrued = 0
    if o.state == SoilConstants.ORGANIC.STATE_TRANSITION then
        accrued = math.max(0, self:getCurrentDay() - (o.startDay or 0))
    end
    return {
        state = o.state,
        daysAccrued = accrued,
        transitionDaysNeeded = needed,
        certified = (o.state == SoilConstants.ORGANIC.STATE_CERTIFIED),
        breaches = o.breaches or 0,
    }
end

-- ---------------------------------------------------------
-- Transitions
-- ---------------------------------------------------------

--- Opt a field into the organic transition (conventional -> in_transition).
-- @param fieldId  field id
-- @return boolean success, string message
function OrganicCertification:optIn(fieldId)
    local field = self.soilSystem and self.soilSystem.fieldData and self.soilSystem.fieldData[fieldId]
    if not field then return false, string.format("Field %s is not tracked yet", tostring(fieldId)) end
    local o = self:ensureState(field)

    if o.state == SoilConstants.ORGANIC.STATE_CERTIFIED then
        return false, string.format("Field %d is already certified organic", fieldId)
    end
    if o.state == SoilConstants.ORGANIC.STATE_TRANSITION then
        return false, string.format("Field %d is already in transition", fieldId)
    end

    o.state = SoilConstants.ORGANIC.STATE_TRANSITION
    o.startDay = self:getCurrentDay()
    o.certifiedDay = 0
    return true, string.format("Field %d entered organic transition (%d days at current difficulty). Use only approved inputs.",
        fieldId, self:getTransitionDays())
end

--- Opt a field back out to conventional (loses transition/certification).
-- @param fieldId  field id
-- @return boolean success, string message
function OrganicCertification:optOut(fieldId)
    local field = self.soilSystem and self.soilSystem.fieldData and self.soilSystem.fieldData[fieldId]
    if not field then return false, string.format("Field %s is not tracked yet", tostring(fieldId)) end
    local o = self:ensureState(field)

    if o.state == SoilConstants.ORGANIC.STATE_CONVENTIONAL then
        return false, string.format("Field %d is already conventional", fieldId)
    end
    o.state = SoilConstants.ORGANIC.STATE_CONVENTIONAL
    o.startDay = 0
    o.certifiedDay = 0
    return true, string.format("Field %d reverted to conventional", fieldId)
end

--- Compliance check on every input application. Called from onFertilizerApplied.
-- A synthetic (non-approved) input on a transitioning or certified field is a
-- breach and resets the field to conventional.
-- @param fieldId       field id
-- @param fillTypeName  upper-case fill type name of the applied input
-- @return boolean breached
function OrganicCertification:onInputApplied(fieldId, fillTypeName)
    local field = self.soilSystem and self.soilSystem.fieldData and self.soilSystem.fieldData[fieldId]
    if not field or not field.organic then return false end
    local o = field.organic

    if o.state == SoilConstants.ORGANIC.STATE_CONVENTIONAL then
        return false  -- nothing to protect
    end
    if self:isApprovedInput(fillTypeName) then
        return false  -- allowed, no breach
    end

    -- Synthetic input on a protected field: full reset.
    o.breaches = (o.breaches or 0) + 1
    o.state = SoilConstants.ORGANIC.STATE_CONVENTIONAL
    o.startDay = 0
    o.certifiedDay = 0

    if SoilLogger then
        SoilLogger.info("Organic: field %d reset to conventional (synthetic input '%s' applied)",
            fieldId, tostring(fillTypeName))
    end
    self:notify(string.format("Field %d lost organic status: %s is not approved",
        fieldId, tostring(fillTypeName)))
    return true
end

--- Daily tick: promote transitioning fields that have served their time.
-- Uses the monotonic day for arithmetic (the caller only needs to trigger it
-- once per day-change; the actual day math must be monotonic).
function OrganicCertification:onDayChanged()
    local currentDay = self:getCurrentDay()
    if self.lastProcessedDay == currentDay then return end
    self.lastProcessedDay = currentDay

    local fieldData = self.soilSystem and self.soilSystem.fieldData
    if not fieldData then return end

    local needed = self:getTransitionDays()
    for fieldId, field in pairs(fieldData) do
        if type(field) == "table" and field.organic
            and field.organic.state == SoilConstants.ORGANIC.STATE_TRANSITION then
            local accrued = currentDay - (field.organic.startDay or currentDay)
            if accrued >= needed then
                field.organic.state = SoilConstants.ORGANIC.STATE_CERTIFIED
                field.organic.certifiedDay = currentDay
                if SoilLogger then
                    SoilLogger.info("Organic: field %d is now CERTIFIED organic", fieldId)
                end
                self:notify(string.format("Field %d is now certified organic!", fieldId))
            end
        end
    end
end

--- Fire an in-game notification if the mission HUD is available.
function OrganicCertification:notify(text)
    if g_currentMission and g_currentMission.hud and g_currentMission.hud.showBlinkingWarning then
        pcall(function() g_currentMission.hud:showBlinkingWarning("[Organic] " .. text, 4000) end)
    end
end

-- ---------------------------------------------------------
-- Save / load (called from SoilFertilitySystem field loop)
-- ---------------------------------------------------------

function OrganicCertification:saveFieldState(xmlFile, fieldKey, field)
    if not field or not field.organic then return end
    local o = field.organic
    setXMLString(xmlFile, fieldKey .. "#organicState", o.state or SoilConstants.ORGANIC.STATE_CONVENTIONAL)
    setXMLInt(xmlFile, fieldKey .. "#organicStartDay", o.startDay or 0)
    setXMLInt(xmlFile, fieldKey .. "#organicCertifiedDay", o.certifiedDay or 0)
    setXMLInt(xmlFile, fieldKey .. "#organicBreaches", o.breaches or 0)
end

function OrganicCertification:loadFieldState(xmlFile, fieldKey, field)
    if not field then return end
    local state = getXMLString(xmlFile, fieldKey .. "#organicState")
    if state == nil or state == "" then return end  -- default conventional, no sub-table needed
    field.organic = {
        state        = state,
        startDay     = getXMLInt(xmlFile, fieldKey .. "#organicStartDay") or 0,
        certifiedDay = getXMLInt(xmlFile, fieldKey .. "#organicCertifiedDay") or 0,
        breaches     = getXMLInt(xmlFile, fieldKey .. "#organicBreaches") or 0,
    }
end

-- ---------------------------------------------------------
-- Console commands
-- ---------------------------------------------------------

--- Resolve a field id from a console arg, falling back to the HUD's current field.
function OrganicCertification:resolveFieldId(arg)
    local id = tonumber(arg)
    if id then return id end
    if g_SoilFertilityManager and g_SoilFertilityManager.soilHUD then
        return g_SoilFertilityManager.soilHUD.cachedFieldId
    end
    return nil
end

function OrganicCertification:registerConsoleCommands()
    addConsoleCommand("SoilOrganicStatus", "Show a field's organic certification status", "consoleOrganicStatus", self)
    addConsoleCommand("SoilOrganicOptIn", "Start organic transition on a field", "consoleOrganicOptIn", self)
    addConsoleCommand("SoilOrganicOptOut", "Revert a field to conventional", "consoleOrganicOptOut", self)
end

function OrganicCertification:consoleOrganicStatus(arg)
    local fieldId = self:resolveFieldId(arg)
    if not fieldId then return "Usage: SoilOrganicStatus <fieldId> (or stand on a field)" end
    local s = self:getFieldOrganicState(fieldId)
    if not s then return string.format("Field %d is not tracked", fieldId) end
    if s.state == SoilConstants.ORGANIC.STATE_TRANSITION then
        return string.format("Field %d: IN TRANSITION - %d / %d days (breaches: %d)",
            fieldId, s.daysAccrued, s.transitionDaysNeeded, s.breaches)
    elseif s.state == SoilConstants.ORGANIC.STATE_CERTIFIED then
        return string.format("Field %d: CERTIFIED ORGANIC (breaches: %d)", fieldId, s.breaches)
    end
    return string.format("Field %d: conventional (breaches: %d)", fieldId, s.breaches)
end

function OrganicCertification:consoleOrganicOptIn(arg)
    local fieldId = self:resolveFieldId(arg)
    if not fieldId then return "Usage: SoilOrganicOptIn <fieldId> (or stand on a field)" end
    local _, msg = self:optIn(fieldId)
    return msg
end

function OrganicCertification:consoleOrganicOptOut(arg)
    local fieldId = self:resolveFieldId(arg)
    if not fieldId then return "Usage: SoilOrganicOptOut <fieldId> (or stand on a field)" end
    local _, msg = self:optOut(fieldId)
    return msg
end
