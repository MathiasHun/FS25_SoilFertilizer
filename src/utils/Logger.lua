-- =========================================================
-- FS25 Realistic Soil & Fertilizer - Logger
-- =========================================================
-- Centralized logging with consistent [SoilFertilizer] prefix
-- and debug-mode gating
-- =========================================================
-- Author: TisonK
-- =========================================================

---@class SoilLogger
SoilLogger = {}

local PREFIX = "[SoilFertilizer]"

--- Log a debug message (only shown when debugMode is enabled)
function SoilLogger.debug(msg, ...)
    if g_SoilFertilityManager and g_SoilFertilityManager.settings and g_SoilFertilityManager.settings.debugMode then
        local success, formatted = pcall(string.format, PREFIX .. " DEBUG: " .. msg, ...)
        if success then
            print(formatted)
        else
            print(PREFIX .. " DEBUG: " .. tostring(msg))
        end
    end
end

--- Log an info message (always shown)
function SoilLogger.info(msg, ...)
    local success, formatted = pcall(string.format, PREFIX .. " " .. msg, ...)
    if success then
        print(formatted)
    else
        print(PREFIX .. " " .. tostring(msg))
    end
end

--- Log a warning message (always shown)
function SoilLogger.warning(msg, ...)
    local success, formatted = pcall(string.format, PREFIX .. " WARNING: " .. msg, ...)
    if success then
        print(formatted)
    else
        print(PREFIX .. " WARNING: " .. tostring(msg))
    end
end

--- Log an error message (always shown)
function SoilLogger.error(msg, ...)
    local success, formatted = pcall(string.format, PREFIX .. " ERROR: " .. msg, ...)
    if success then
        print(formatted)
    else
        print(PREFIX .. " ERROR: " .. tostring(msg))
    end
end
