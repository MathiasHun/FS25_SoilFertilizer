-- rotation_foresight_test.lua - the pre-plant rotation projection that the field-detail
-- dialog's Rotation Foresight section reads. Guards _rotationStatusFor (the shared pure
-- status helper) and projectRotation (the read-only "what happens if I plant X next"),
-- so the preview can never disagree with the status the player actually gets on harvest.
--!load: src/utils/Logger.lua, src/config/Constants.lua, src/SoilFertilitySystem.lua

local cr = SoilConstants.CROP_ROTATION

local function newSys()
  return setmetatable({}, { __index = SoilFertilitySystem })
end

-- A system whose getFieldInfo is stubbed to a fixed crop history, so projectRotation
-- can be exercised without the live-field / FieldState machinery.
local function sysWithHistory(lastCrop, lastCrop2)
  local sys = newSys()
  sys.getFieldInfo = function(_self, _fieldId)
    return { lastCrop = lastCrop, lastCrop2 = lastCrop2 }
  end
  return sys
end

-- ── _rotationStatusFor: the pure status rule ───────────────
do
  local sys = newSys()
  T.eq("rf: same crop repeated → Fatigue",            sys:_rotationStatusFor("wheat", "wheat"),   "Fatigue")
  T.eq("rf: legume after non-legume → Bonus",         sys:_rotationStatusFor("soybean", "wheat"),  "Bonus")
  T.eq("rf: two different cereals → OK",               sys:_rotationStatusFor("wheat", "barley"),   "OK")
  T.eq("rf: legume after legume → OK (not Bonus)",     sys:_rotationStatusFor("peas", "soybean"),   "OK")
  T.eq("rf: perennial forage repeated → OK (not Fatigue)", sys:_rotationStatusFor("grass", "grass"), "OK")
  T.eq("rf: incomplete history → nil",                 sys:_rotationStatusFor("wheat", nil),        nil)
  T.eq("rf: nil candidate → nil",                      sys:_rotationStatusFor(nil, "wheat"),        nil)
end

-- ── projectRotation: read-only projection, disease module ABSENT ──
-- With no SoilDiseaseSystem loaded, the disease direction guard must degrade to "neutral".
do
  local sys = sysWithHistory("wheat", "barley")

  local fatigue = sys:projectRotation(1, "wheat")   -- wheat after wheat
  T.eq("rf: project same crop → Fatigue status",  fatigue.status, "Fatigue")
  T.ok("rf: project same crop → fatigue flag",    fatigue.fatigue == true)
  T.near("rf: project fatigue multiplier = 1.15", fatigue.fatigueMultiplier, cr.FATIGUE_MULTIPLIER)
  T.eq("rf: project same crop → nitrogen neutral", fatigue.nitrogen, "neutral")
  T.eq("rf: project same crop → follows current",  fatigue.follows, "wheat")
  T.eq("rf: disease neutral when module absent",   fatigue.disease, "neutral")

  local bonus = sys:projectRotation(1, "soybean")   -- legume after wheat
  T.eq("rf: project legume → Bonus status",  bonus.status,   "Bonus")
  T.eq("rf: project legume → nitrogen up",   bonus.nitrogen, "up")
  T.ok("rf: project legume → no fatigue",    bonus.fatigue == false)

  local ok = sys:projectRotation(1, "barley")       -- neutral cereal after wheat
  T.eq("rf: project neutral cereal → OK status", ok.status,   "OK")
  T.eq("rf: project neutral cereal → nitrogen neutral", ok.nitrogen, "neutral")
end

-- ── projectRotation: undefined + invalid inputs ───────────
do
  local blank = sysWithHistory(nil, nil)
  local proj = blank:projectRotation(1, "wheat")
  T.eq("rf: no crop history → status nil",  proj.status,  nil)
  T.eq("rf: no crop history → follows nil", proj.follows, nil)

  local sys = sysWithHistory("wheat", "barley")
  T.ok("rf: fieldId nil → nil",         sys:projectRotation(nil, "wheat") == nil)
  T.ok("rf: fieldId <= 0 → nil",        sys:projectRotation(0, "wheat")   == nil)
  T.ok("rf: empty candidate → nil",     sys:projectRotation(1, "")        == nil)
  T.ok("rf: nil candidate → nil",       sys:projectRotation(1, nil)       == nil)
end

-- ── projectRotation: disease direction, module PRESENT ─────
-- Stub the disease-rotation multiplier: >1 raises pressure, <1 lowers it, 1 neutral.
-- projectRotation keys the multiplier on the hypothetical post-plant history, whose
-- lastCrop is the candidate, so we branch on that.
do
  SoilDiseaseSystem = {
    rotationMult = function(h)
      if h.lastCrop == "wheat" then return 1.2      -- monoculture: more disease
      elseif h.lastCrop == "soybean" then return 0.8 -- legume break: less disease
      else return 1.0 end                            -- neutral
    end,
  }

  local sys = sysWithHistory("wheat", "barley")
  T.eq("rf: disease up when rotationMult > 1",   sys:projectRotation(1, "wheat").disease,   "up")
  T.eq("rf: disease down when rotationMult < 1", sys:projectRotation(1, "soybean").disease, "down")
  T.eq("rf: disease neutral when rotationMult = 1", sys:projectRotation(1, "barley").disease, "neutral")

  SoilDiseaseSystem = nil  -- leave the global env as we found it
end
