-- =========================================================
-- FS25 Realistic Soil & Fertilizer (version 1.0.3.0)
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

-- Template cache
UIHelper.templates = nil
UIHelper.templatesLoaded = false

-- Safe i18n text getter
local function getTextSafe(key)
    if not g_i18n then
        return key
    end

    local text = g_i18n:getText(key)
    if text == nil or text == "" then
        Logging.warning("[SoilFertilizer] Missing translation for key: " .. tostring(key))
        return key
    end
    return text
end

-- Load GUI templates from XML file
function UIHelper.loadTemplates()
    if UIHelper.templatesLoaded then
        return UIHelper.templates ~= nil
    end

    UIHelper.templatesLoaded = true

    local xmlPath = g_currentModDirectory .. "gui/SettingsFrame.xml"

    if not fileExists(xmlPath) then
        Logging.error("[SoilFertilizer] GUI template file not found: " .. xmlPath)
        return false
    end

    local xmlFile = loadXMLFile("SoilFertilizerGUI", xmlPath)
    if not xmlFile or xmlFile == 0 then
        Logging.error("[SoilFertilizer] Failed to load GUI template XML")
        return false
    end

    -- Parse templates manually from XML
    UIHelper.templates = {}

    -- We'll use g_gui to create elements from profiles
    -- For now, store the XML file handle for later use
    UIHelper.xmlFile = xmlFile

    Logging.info("[SoilFertilizer] GUI templates loaded successfully")
    return true
end

-- Create a GuiElement from template name
local function createFromTemplate(templateName, parent)
    if not UIHelper.loadTemplates() then
        Logging.error("[SoilFertilizer] Templates not available")
        return nil
    end

    -- Find the template in XML
    local basePath = "GUI.GuiElement"
    local index = 0

    while true do
        local path = string.format("%s(%d)", basePath, index)
        local name = getXMLString(UIHelper.xmlFile, path .. "#name")

        if name == nil then
            break
        end

        if name == templateName then
            -- Found the template, now create element
            local elementType = getXMLString(UIHelper.xmlFile, path .. "#type")

            if elementType == "text" then
                local element = TextElement.new()

                -- Apply properties
                local textSize = getXMLFloat(UIHelper.xmlFile, path .. ".Properties#textSize")
                local textBold = getXMLBool(UIHelper.xmlFile, path .. ".Properties#textBold")
                local textColor = getXMLString(UIHelper.xmlFile, path .. ".Properties#textColor")
                local textAlignment = getXMLString(UIHelper.xmlFile, path .. ".Properties#textAlignment")

                if textSize then element.textSize = textSize end
                if textBold ~= nil then element.textBold = textBold end

                if textColor then
                    local r, g, b, a = textColor:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
                    if r then
                        element.textColor = {tonumber(r), tonumber(g), tonumber(b), tonumber(a)}
                    end
                end

                if textAlignment == "left" then
                    element.textAlignment = RenderText.ALIGN_LEFT
                elseif textAlignment == "center" then
                    element.textAlignment = RenderText.ALIGN_CENTER
                elseif textAlignment == "right" then
                    element.textAlignment = RenderText.ALIGN_RIGHT
                end

                return element
            end
        end

        index = index + 1
    end

    return nil
end

-- Fallback: Create basic text element
local function createTextElement(text, size, color, bold)
    local element = TextElement.new()
    element.text = text or ""
    element.textSize = size or 0.016
    element.textBold = bold or false
    element.textColor = color or {0.95, 0.95, 0.95, 1}
    element.textAlignment = RenderText.ALIGN_LEFT
    return element
end

-- Fallback: Search existing layout for templates (backward compatibility)
local function findTemplateInLayout(layout, searchFunc)
    if not layout or not layout.elements then
        return nil
    end

    for _, el in ipairs(layout.elements) do
        if searchFunc(el) then
            return el
        end
    end

    return nil
end

function UIHelper.createSection(layout, textId)
    if not layout or not layout.elements then
        Logging.error("[SoilFertilizer] Invalid layout passed to createSection")
        return nil
    end

    -- Try template-based approach first
    local section = createFromTemplate("sf_sectionHeader", layout)

    -- Fallback to searching existing layout
    if not section then
        local template = findTemplateInLayout(layout, function(el)
            return el and el.name == "sectionHeader"
        end)

        if template then
            local success, cloned = pcall(function() return template:clone(layout) end)
            if success and cloned then
                section = cloned
                section.id = nil
            end
        end
    end

    -- Last resort: create manually
    if not section then
        section = createTextElement(getTextSafe(textId), 0.022, {0.95, 0.95, 0.95, 1}, true)
    end

    if section and section.setText then
        section:setText(getTextSafe(textId))
    end

    if section then
        local addSuccess = pcall(function() layout:addElement(section) end)
        if not addSuccess then
            Logging.error("[SoilFertilizer] Failed to add section to layout")
            return nil
        end
    end

    return section
end

function UIHelper.createDescription(layout, textId)
    if not layout or not layout.elements then
        Logging.error("[SoilFertilizer] Invalid layout passed to createDescription")
        return nil
    end

    -- Try template-based approach
    local desc = createFromTemplate("sf_description", layout)

    -- Fallback to searching existing layout
    if not desc then
        local template = findTemplateInLayout(layout, function(el)
            return el and el.elements and #el.elements >= 2 and
                   el.elements[2] and el.elements[2].setText
        end)

        if template then
            local success, cloned = pcall(function() return template.elements[2]:clone(layout) end)
            if success and cloned then
                desc = cloned
                desc.id = nil
            end
        end
    end

    -- Last resort: create manually
    if not desc then
        desc = createTextElement(getTextSafe(textId), 0.014, {0.7, 0.7, 0.7, 1}, false)
    end

    if desc and desc.setText then
        desc:setText(getTextSafe(textId))
    end

    if desc then
        if desc.textSize then
            desc.textSize = 0.014
        end

        if desc.textColor then
            desc.textColor = {0.7, 0.7, 0.7, 1}
        end

        local addSuccess = pcall(function() layout:addElement(desc) end)
        if not addSuccess then
            Logging.error("[SoilFertilizer] Failed to add description to layout")
            return nil
        end
    end

    return desc
end

function UIHelper.createBinaryOption(layout, id, textId, state, callback)
    if not layout or not layout.elements then
        Logging.error("[SoilFertilizer] Invalid layout passed to createBinaryOption")
        return nil
    end

    -- Search for existing checkbox template in layout
    local template = findTemplateInLayout(layout, function(el)
        return el and el.elements and #el.elements >= 2 and
               el.elements[1] and el.elements[1].id and (
                   string.find(el.elements[1].id, "^check") or
                   string.find(el.elements[1].id, "Check")
               )
    end)

    if not template then
        Logging.warning("[SoilFertilizer] BinaryOption template not found!")
        return nil
    end

    local success, row = pcall(function() return template:clone(layout) end)
    if not success or not row then
        Logging.error("[SoilFertilizer] Failed to clone binary option template")
        return nil
    end

    row.id = nil

    if not row.elements or #row.elements < 2 then
        Logging.error("[SoilFertilizer] Cloned row has invalid elements")
        return nil
    end

    local opt = row.elements[1]
    local lbl = row.elements[2]

    if opt then opt.id = nil end
    if opt then opt.target = nil end
    if lbl then lbl.id = nil end

    if opt and opt.toolTipText then opt.toolTipText = "" end
    if lbl and lbl.toolTipText then lbl.toolTipText = "" end

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

    local addSuccess = pcall(function() layout:addElement(row) end)
    if not addSuccess then
        Logging.error("[SoilFertilizer] Failed to add binary option to layout")
        return nil
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

    return opt
end

function UIHelper.createMultiOption(layout, id, textId, options, state, callback)
    if not layout or not layout.elements then
        Logging.error("[SoilFertilizer] Invalid layout passed to createMultiOption")
        return nil
    end

    -- Search for existing multi-option template in layout
    local template = findTemplateInLayout(layout, function(el)
        return el and el.elements and #el.elements >= 2 and
               el.elements[1] and el.elements[1].id and
               string.find(el.elements[1].id, "^multi")
    end)

    if not template then
        Logging.warning("[SoilFertilizer] MultiOption template not found!")
        return nil
    end

    local success, row = pcall(function() return template:clone(layout) end)
    if not success or not row then
        Logging.error("[SoilFertilizer] Failed to clone multi option template")
        return nil
    end

    row.id = nil

    if not row.elements or #row.elements < 2 then
        Logging.error("[SoilFertilizer] Cloned row has invalid elements")
        return nil
    end

    local opt = row.elements[1]
    local lbl = row.elements[2]

    if opt then opt.id = nil end
    if opt then opt.target = nil end
    if lbl then lbl.id = nil end

    if opt and opt.toolTipText then opt.toolTipText = "" end
    if lbl and lbl.toolTipText then lbl.toolTipText = "" end

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

    local addSuccess = pcall(function() layout:addElement(row) end)
    if not addSuccess then
        Logging.error("[SoilFertilizer] Failed to add multi option to layout")
        return nil
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

    return opt
end
