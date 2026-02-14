-- =========================================================
-- FS25 Realistic Soil & Fertilizer - Constants
-- =========================================================
-- Single source of truth for all tunable values
-- =========================================================
-- Author: TisonK
-- =========================================================

---@class SoilConstants
SoilConstants = {}

-- ========================================
-- TIMING
-- ========================================
SoilConstants.TIMING = {
    UPDATE_INTERVAL = 30000,     -- ms between periodic checks
    FALLOW_THRESHOLD = 7,        -- days before fallow recovery kicks in
}

-- ========================================
-- DIFFICULTY MULTIPLIERS
-- ========================================
SoilConstants.DIFFICULTY = {
    EASY = 1,
    NORMAL = 2,
    HARD = 3,
    MULTIPLIERS = {
        [1] = 0.7,   -- Simple
        [2] = 1.0,   -- Realistic
        [3] = 1.5,   -- Hardcore
    }
}

-- ========================================
-- DEFAULT FIELD VALUES
-- ========================================
SoilConstants.FIELD_DEFAULTS = {
    nitrogen = 50,
    phosphorus = 40,
    potassium = 45,
    organicMatter = 3.5,
    pH = 6.5,
}

-- ========================================
-- NUTRIENT LIMITS
-- ========================================
SoilConstants.NUTRIENT_LIMITS = {
    MIN = 0,
    MAX = 100,
    ORGANIC_MATTER_MAX = 10,
    PH_MIN = 5.0,
    PH_MAX = 7.5,
    PH_NEUTRAL_LOW = 6.5,
    PH_NEUTRAL_HIGH = 7.0,
}

-- ========================================
-- NUTRIENT RECOVERY RATES (per day, fallow fields)
-- ========================================
SoilConstants.FALLOW_RECOVERY = {
    nitrogen = 0.2,
    phosphorus = 0.1,
    potassium = 0.15,
    organicMatter = 0.01,
}

-- ========================================
-- SEASONAL EFFECTS (per day)
-- ========================================
SoilConstants.SEASONAL_EFFECTS = {
    SPRING_NITROGEN_BOOST = 0.1,
    FALL_NITROGEN_LOSS = 0.05,
    SPRING_SEASON = 1,
    FALL_SEASON = 3,
}

-- ========================================
-- pH NORMALIZATION (per day)
-- ========================================
SoilConstants.PH_NORMALIZATION = {
    RATE = 0.01,
}

-- ========================================
-- RAIN EFFECTS
-- ========================================
SoilConstants.RAIN = {
    LEACH_BASE_FACTOR = 0.000001,  -- base leach per dt per rainScale
    NITROGEN_MULTIPLIER = 5,       -- nitrogen leaches most
    POTASSIUM_MULTIPLIER = 2,      -- potassium moderate
    PHOSPHORUS_MULTIPLIER = 0.5,   -- phosphorus binds to soil
    PH_ACIDIFICATION = 0.1,       -- rain acidification multiplier
    MIN_RAIN_THRESHOLD = 0.1,     -- minimum rainScale to trigger effects
}

-- ========================================
-- CROP EXTRACTION RATES (per 1,000 liters harvested)
-- ========================================
SoilConstants.CROP_EXTRACTION = {
    wheat      = { N=2.3, P=1.0, K=1.8 },
    barley     = { N=2.1, P=0.9, K=1.7 },
    maize      = { N=2.8, P=1.2, K=2.4 },
    canola     = { N=3.2, P=1.4, K=2.6 },
    soybean    = { N=3.8, P=1.6, K=2.0 },
    sunflower  = { N=3.0, P=1.3, K=2.8 },
    potato     = { N=4.5, P=2.0, K=6.5 },
    sugarbeet  = { N=4.0, P=1.8, K=7.0 },
    oats       = { N=2.2, P=1.1, K=1.9 },
    rye        = { N=2.4, P=1.0, K=2.1 },
    triticale  = { N=2.5, P=1.2, K=2.3 },
    sorghum    = { N=2.7, P=1.1, K=2.2 },
    peas       = { N=3.5, P=1.3, K=2.4 },
    beans      = { N=3.6, P=1.4, K=2.5 },
}

-- Default extraction for unknown crops
SoilConstants.CROP_EXTRACTION_DEFAULT = { N=2.5, P=1.1, K=2.0 }

-- ========================================
-- FERTILIZER PROFILES (per 1,000 liters applied)
-- ========================================
SoilConstants.FERTILIZER_PROFILES = {
    LIQUIDFERTILIZER = { N=6.0, P=2.5, K=4.0 },
    FERTILIZER       = { N=8.0, P=4.0, K=3.0 },
    MANURE           = { N=3.0, P=2.0, K=3.5, OM=0.05 },
    SLURRY           = { N=4.0, P=2.0, K=5.0, OM=0.03 },
    DIGESTATE        = { N=5.0, P=2.2, K=5.5, OM=0.04 },
    LIME             = { pH=0.4 },
}

-- List of recognized fertilizer fill type names
SoilConstants.FERTILIZER_TYPES = {
    "LIQUIDFERTILIZER",
    "FERTILIZER",
    "MANURE",
    "SLURRY",
    "DIGESTATE",
    "LIME",
}

-- ========================================
-- NUTRIENT STATUS THRESHOLDS
-- ========================================
SoilConstants.STATUS_THRESHOLDS = {
    nitrogen   = { poor = 30, fair = 50 },
    phosphorus = { poor = 25, fair = 45 },
    potassium  = { poor = 20, fair = 40 },
}

-- Threshold for "needs fertilization" warning
SoilConstants.FERTILIZATION_THRESHOLDS = {
    nitrogen = 30,
    phosphorus = 25,
    potassium = 20,
    pH = 5.5,
}

-- ========================================
-- HUD DISPLAY
-- ========================================
SoilConstants.HUD = {
    PANEL_WIDTH = 0.15,
    PANEL_HEIGHT = 0.15,

    -- Position presets (matched to hudPosition setting values 1-5)
    POSITIONS = {
        [1] = { x = 0.850, y = 0.70 },  -- Top Right
        [2] = { x = 0.010, y = 0.70 },  -- Top Left
        [3] = { x = 0.850, y = 0.20 },  -- Bottom Right
        [4] = { x = 0.010, y = 0.20 },  -- Bottom Left
        [5] = { x = 0.850, y = 0.45 },  -- Center Right
    }
}

-- ========================================
-- NETWORK SYNC
-- ========================================
SoilConstants.NETWORK = {
    FULL_SYNC_MAX_ATTEMPTS = 3,
    FULL_SYNC_RETRY_INTERVAL = 5000, -- ms

    -- Network value type encoding
    VALUE_TYPE = {
        BOOLEAN = 0,
        NUMBER = 1,
        STRING = 2,
    }
}

print("[SoilFertilizer] Constants loaded")
