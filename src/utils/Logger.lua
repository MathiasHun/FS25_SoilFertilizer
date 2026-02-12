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
        print(string.format(PREFIX .. " DEBUG: " .. msg, ...))
    end
end

--- Log an info message (always shown)
function SoilLogger.info(msg, ...)
    print(string.format(PREFIX .. " " .. msg, ...))
end

--- Log a warning message (always shown)
function SoilLogger.warning(msg, ...)
    print(string.format(PREFIX .. " WARNING: " .. msg, ...))
end

--- Log an error message (always shown)
function SoilLogger.error(msg, ...)
    print(string.format(PREFIX .. " ERROR: " .. msg, ...))
end
