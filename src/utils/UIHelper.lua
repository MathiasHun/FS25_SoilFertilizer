-- =========================================================
-- FS25 Realistic Soil & Fertilizer (version 1.0.6.0)
-- =========================================================
-- Realistic soil fertility and fertilizer management
-- =========================================================
-- Author: TisonK
-- =========================================================
-- COPYRIGHT NOTICE:
-- All rights reserved. Unauthorized redistribution, copying,
-- or claiming this code as your own is strictly prohibited.
-- Original author: TisonK
-- =========================================================
---@class UIHelper
UIHelper = {}

-- Vanilla FS25 always appends its own settings rows before any mod's rows.
-- Restricting template search to the first N elements guarantees we only clone
-- vanilla elements, never touching rows that other mods injected later.
local MAX_SEARCH_INDEX = 50

-- Template cache to avoid repeated searches and ensure consistency
UIHelper.templateCache = {
    sectionHeader = nil,
    binaryOption = nil,
    multiOption = nil,
    initialized = false
}

-- Reset template cache (called on mission unload via SoilFertilityManager:delete())
function UIHelper.resetTemplateCache()
    UIHelper.templateCache = {
        sectionHeader = nil,
        binaryOption = nil,
        multiOption = nil,
        initialized = false
    }
    SoilLogger.info("UI template cache reset")
end

local function getTextSafe(key)
    if not g_i18n then
        return key
    end

    local text = g_i18n:getText(key)
    if text == nil or text == "" then
        SoilLogger.warning("[SoilFertilizer] Missing translation for key: " .. tostring(key))
        return key
    end
    return text
end

-- Validate that an element has the expected structure for section headers
local function validateSectionTemplate(element)
    return element and
           element.name == "sectionHeader" and
           type(element.clone) == "function" and
           type(element.setText) == "function"
end

-- Validate that an element has the expected structure for binary options
local function validateBinaryTemplate(element)
    if not element or not element.elements or #element.elements < 2 then
        return false
    end

    local opt = element.elements[1]
    local lbl = element.elements[2]

    -- Verify structure
    return opt and lbl and
           type(element.clone) == "function" and
           type(opt.setState) == "function" and
           type(lbl.setText) == "function"
end

-- Validate that an element has the expected structure for multi options
local function validateMultiTemplate(element)
    if not element or not element.elements or #element.elements < 2 then
        return false
    end

    local opt = element.elements[1]
    local lbl = element.elements[2]

    -- Verify structure
    return opt and lbl and
           type(element.clone) == "function" and
           type(opt.setTexts) == "function" and
           type(opt.setState) == "function" and
           type(lbl.setText) == "function"
end

-- Find and cache section header template
-- NOTE: Skips elements we created ourselves (__soilFertilizerElement) to prevent
-- feedback loops on retry and to avoid using our own clones as templates.
local function findSectionTemplate(layout)
    if UIHelper.templateCache.sectionHeader then
        return UIHelper.templateCache.sectionHeader
    end

    if not layout or not layout.elements then
        return nil
    end

    for i, el in ipairs(layout.elements) do
        if i > MAX_SEARCH_INDEX then break end
        if not el.__soilFertilizerElement and validateSectionTemplate(el) then
            SoilLogger.info("Found and cached section header template (index %d)", i)
            UIHelper.templateCache.sectionHeader = el
            return el
        end
    end

    SoilLogger.warning("Section header template not found in first %d elements", MAX_SEARCH_INDEX)
    return nil
end

-- NOTE: findDescriptionTemplate() was removed.
-- It cached el.elements[2] — a CHILD element from another mod's settings row.
-- Calling child:clone(layout) can reparent the original child out of its owning
-- row, leaving that row with a missing label → white/blank setting in other mods.
-- The PF viewer-mode notice now uses a section header instead (safe, top-level).

-- Find and cache binary option template
-- Skips our own elements and searches only top-level layout items.
local function findBinaryTemplate(layout)
    if UIHelper.templateCache.binaryOption then
        return UIHelper.templateCache.binaryOption
    end

    if not layout or not layout.elements then
        return nil
    end

    local candidates = {}

    for i, el in ipairs(layout.elements) do
        if i > MAX_SEARCH_INDEX then break end
        -- Skip elements we created (prevents using our own clones as templates)
        if not el.__soilFertilizerElement and el and el.elements and #el.elements >= 2 then
            local firstChild = el.elements[1]
            if firstChild and firstChild.id then
                local id = tostring(firstChild.id)
                if string.find(id, "check") or string.find(id, "Check") then
                    table.insert(candidates, el)
                end
            end
        end
    end

    for _, candidate in ipairs(candidates) do
        if validateBinaryTemplate(candidate) then
            SoilLogger.info("Found and cached binary option template (checked %d candidates in first %d elements)", #candidates, MAX_SEARCH_INDEX)
            UIHelper.templateCache.binaryOption = candidate
            return candidate
        end
    end

    SoilLogger.warning("Binary option template not found (checked %d candidates in first %d elements)", #candidates, MAX_SEARCH_INDEX)
    return nil
end

-- Find and cache multi option template
-- Skips our own elements and searches only top-level layout items.
local function findMultiTemplate(layout)
    if UIHelper.templateCache.multiOption then
        return UIHelper.templateCache.multiOption
    end

    if not layout or not layout.elements then
        return nil
    end

    local candidates = {}

    for i, el in ipairs(layout.elements) do
        if i > MAX_SEARCH_INDEX then break end
        -- Skip elements we created (prevents using our own clones as templates)
        if not el.__soilFertilizerElement and el and el.elements and #el.elements >= 2 then
            local firstChild = el.elements[1]
            if firstChild and firstChild.id then
                local id = tostring(firstChild.id)
                if string.find(id, "multi") then
                    table.insert(candidates, el)
                end
            end
        end
    end

    for _, candidate in ipairs(candidates) do
        if validateMultiTemplate(candidate) then
            SoilLogger.info("Found and cached multi option template (checked %d candidates in first %d elements)", #candidates, MAX_SEARCH_INDEX)
            UIHelper.templateCache.multiOption = candidate
            return candidate
        end
    end

    SoilLogger.warning("Multi option template not found (checked %d candidates in first %d elements)", #candidates, MAX_SEARCH_INDEX)
    return nil
end

function UIHelper.createSection(layout, textId)
    if not layout or not layout.elements then
        SoilLogger.error("[SoilFertilizer] Invalid layout passed to createSection")
        return nil
    end

    local template = findSectionTemplate(layout)
    if not template then
        SoilLogger.error("[SoilFertilizer] No valid section template found")
        return nil
    end

    local success, section = pcall(function() return template:clone(layout) end)
    if not success or not section then
        SoilLogger.error("[SoilFertilizer] Failed to clone section template: %s", tostring(success))
        return nil
    end

    section.id = nil

    if section.setText then
        section:setText(getTextSafe(textId))
    end

    -- Defensive styling: ensure visibility
    if section.setVisible then
        section:setVisible(true)
    end
    section.visible = true

    -- Ensure text color is not white-on-white
    if section.textColor then
        section.textColor = {0.95, 0.95, 0.95, 1.0}
    end

    -- Tag as ours so find functions never use this element as a future template
    section.__soilFertilizerElement = true

    SoilLogger.info("Created section header: %s (visible=%s)", textId, tostring(section.visible))
    return section
end

-- createDescription() was removed.
-- It used findDescriptionTemplate() which cached a CHILD element (el.elements[2])
-- from another mod's row. Cloning that child into the layout could reparent it,
-- tearing it from its owner row and causing that mod's setting to appear blank.
-- The single caller (PF viewer-mode notice) now uses createSection() instead.

function UIHelper.createBinaryOption(layout, id, textId, state, callback)
    if not layout or not layout.elements then
        SoilLogger.error("[SoilFertilizer] Invalid layout passed to createBinaryOption")
        return nil
    end

    local template = findBinaryTemplate(layout)
    if not template then
        SoilLogger.error("[SoilFertilizer] No valid binary option template found")
        return nil
    end

    local success, row = pcall(function() return template:clone(layout) end)
    if not success or not row then
        SoilLogger.error("[SoilFertilizer] Failed to clone binary option template: %s", tostring(success))
        return nil
    end

    -- Validate cloned structure
    if not row.elements or #row.elements < 2 then
        SoilLogger.error("[SoilFertilizer] Cloned binary option has invalid structure")
        return nil
    end

    row.id = nil

    local opt = row.elements[1]
    local lbl = row.elements[2]

    -- Additional validation of cloned elements
    if not opt or not lbl or not opt.setState or not lbl.setText then
        SoilLogger.error("[SoilFertilizer] Cloned binary option elements missing required methods")
        return nil
    end

    if opt then opt.id = nil end
    if opt then opt.target = nil end
    if lbl then lbl.id = nil end

    if opt and opt.toolTipText then opt.toolTipText = "" end
    if lbl and lbl.toolTipText then lbl.toolTipText = "" end

    -- Defensive styling: ensure visibility and proper colors
    if row.setVisible then
        row:setVisible(true)
    end
    row.visible = true

    if opt then
        if opt.setVisible then opt:setVisible(true) end
        opt.visible = true
        if opt.alpha ~= nil then opt.alpha = 1.0 end
    end

    if lbl then
        if lbl.setVisible then lbl:setVisible(true) end
        lbl.visible = true
        if lbl.textColor then
            lbl.textColor = {0.9, 0.9, 0.9, 1.0} -- Light gray, clearly visible
        end
        if lbl.alpha ~= nil then lbl.alpha = 1.0 end
    end

    if opt then
        opt.onClickCallback = function(newState, element)
            local isChecked = (newState == 2)
            if callback then
                callback(isChecked)
            end
        end
    end

    if lbl and lbl.setText then
        lbl:setText(getTextSafe(textId .. "_short"))
    end

    if opt and opt.setState then
        opt:setState(1)
    end

    if state and opt then
        if opt.setIsChecked then
            opt:setIsChecked(true)
        elseif opt.setState then
            opt:setState(2)
        end
    end

    local tooltipText = getTextSafe(textId .. "_long")

    if opt and opt.setToolTipText then
        opt:setToolTipText(tooltipText)
    end
    if lbl and lbl.setToolTipText then
        lbl:setToolTipText(tooltipText)
    end

    if opt then opt.toolTipText = tooltipText end
    if lbl then lbl.toolTipText = tooltipText end

    if row.setToolTipText then
        row:setToolTipText(tooltipText)
    end
    row.toolTipText = tooltipText

    if opt and opt.elements and opt.elements[1] and opt.elements[1].setText then
        opt.elements[1]:setText(tooltipText)
    end

    -- Tag row and option as ours so find functions skip them on retry
    row.__soilFertilizerElement = true
    opt.__soilFertilizerElement = true

    SoilLogger.info("Created binary option: %s (state=%s, visible=%s, lblColor=%s)",
        textId, tostring(state), tostring(row.visible),
        lbl.textColor and string.format("%.1f,%.1f,%.1f", lbl.textColor[1], lbl.textColor[2], lbl.textColor[3]) or "nil")

    return opt
end

function UIHelper.createMultiOption(layout, id, textId, options, state, callback)
    if not layout or not layout.elements then
        SoilLogger.error("[SoilFertilizer] Invalid layout passed to createMultiOption")
        return nil
    end

    local template = findMultiTemplate(layout)
    if not template then
        SoilLogger.error("[SoilFertilizer] No valid multi option template found")
        return nil
    end

    local success, row = pcall(function() return template:clone(layout) end)
    if not success or not row then
        SoilLogger.error("[SoilFertilizer] Failed to clone multi option template: %s", tostring(success))
        return nil
    end

    -- Validate cloned structure
    if not row.elements or #row.elements < 2 then
        SoilLogger.error("[SoilFertilizer] Cloned multi option has invalid structure")
        return nil
    end

    row.id = nil

    local opt = row.elements[1]
    local lbl = row.elements[2]

    -- Additional validation of cloned elements
    if not opt or not lbl or not opt.setTexts or not opt.setState or not lbl.setText then
        SoilLogger.error("[SoilFertilizer] Cloned multi option elements missing required methods")
        return nil
    end

    if opt then opt.id = nil end
    if opt then opt.target = nil end
    if lbl then lbl.id = nil end

    if opt and opt.toolTipText then opt.toolTipText = "" end
    if lbl and lbl.toolTipText then lbl.toolTipText = "" end

    -- Defensive styling: ensure visibility and proper colors
    if row.setVisible then
        row:setVisible(true)
    end
    row.visible = true

    if opt then
        if opt.setVisible then opt:setVisible(true) end
        opt.visible = true
        if opt.alpha ~= nil then opt.alpha = 1.0 end
    end

    if lbl then
        if lbl.setVisible then lbl:setVisible(true) end
        lbl.visible = true
        if lbl.textColor then
            lbl.textColor = {0.9, 0.9, 0.9, 1.0} -- Light gray, clearly visible
        end
        if lbl.alpha ~= nil then lbl.alpha = 1.0 end
    end

    if opt and opt.setTexts then
        opt:setTexts(options)
    end

    if opt and opt.setState then
        opt:setState(state)
    end

    if opt then
        opt.onClickCallback = function(newState, element)
            if callback then
                callback(newState)
            end
        end
    end

    if lbl and lbl.setText then
        lbl:setText(getTextSafe(textId .. "_short"))
    end

    local tooltipText = getTextSafe(textId .. "_long")

    if opt and opt.setToolTipText then
        opt:setToolTipText(tooltipText)
    end
    if lbl and lbl.setToolTipText then
        lbl:setToolTipText(tooltipText)
    end

    if opt then opt.toolTipText = tooltipText end
    if lbl then lbl.toolTipText = tooltipText end

    if row.setToolTipText then
        row:setToolTipText(tooltipText)
    end
    row.toolTipText = tooltipText

    if opt and opt.elements and opt.elements[1] and opt.elements[1].setText then
        opt.elements[1]:setText(tooltipText)
    end

    -- Tag row and option as ours so find functions skip them on retry
    row.__soilFertilizerElement = true
    opt.__soilFertilizerElement = true

    SoilLogger.info("Created multi option: %s (state=%s, visible=%s, lblColor=%s)",
        textId, tostring(state), tostring(row.visible),
        lbl.textColor and string.format("%.1f,%.1f,%.1f", lbl.textColor[1], lbl.textColor[2], lbl.textColor[3]) or "nil")

    return opt
end