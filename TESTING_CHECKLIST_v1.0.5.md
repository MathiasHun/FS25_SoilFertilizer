# FS25_SoilFertilizer v1.0.5.0 - Testing Checklist

## Overview
This checklist verifies all 13 robustness and quality fixes from the code audit conducted 2026-02-16.

**Audit Summary**: 1 HIGH, 6 MEDIUM, 6 LOW severity issues fixed
**Reference Patterns**: NPCFavor mod proven patterns adopted
**Files Modified**: 9 core files (~300 lines added/modified)

---

## Pre-Testing Setup

### Clean Install Test
- [ ] Remove existing mod from `%USERPROFILE%\Documents\My Games\FarmingSimulator2025\mods`
- [ ] Delete `FS25_SoilFertilizer.xml` from savegame folder
- [ ] Delete `soilData.xml` from savegame folder
- [ ] Install fresh v1.0.5.0 build
- [ ] Launch game and verify mod loads without errors

### Upgrade Test
- [ ] Keep existing v1.0.4.1 installation
- [ ] Upgrade to v1.0.5.0 (overwrite)
- [ ] Launch game and verify settings/data preserved
- [ ] Check log for migration messages

---

## Phase 1: Critical Crash Prevention (HIGH Severity)

### Issue #1: Assert Crash Protection
**What was fixed**: Replaced 3 assert() calls with graceful error handling + user dialogs

**Test Steps**:
1. **Simulate module load failure**:
   - [ ] Temporarily rename `src/SoilFertilitySystem.lua` to trigger missing module
   - [ ] Launch game
   - **Expected**: Dialog appears: "Soil & Fertilizer Mod failed to load... Critical module 'SoilFertilitySystem' is missing"
   - **Expected**: Game continues without crash
   - **Expected**: Log shows: `[SoilFertilizer ERROR] CRITICAL: SoilFertilitySystem not loaded`
   - [ ] Restore file name

2. **Simulate HUD module failure**:
   - [ ] Temporarily rename `src/ui/SoilHUD.lua`
   - [ ] Launch game
   - **Expected**: Dialog appears: "HUD module failed to load... The mod will run without the HUD display"
   - **Expected**: Mod functions without HUD, no crash
   - [ ] Restore file name

**Pass Criteria**: No game crashes, user notified, graceful degradation

---

### Issue #2: Plowing Hook Nil Check
**What was fixed**: Added validation for workArea parameter before array access

**Test Steps**:
1. [ ] Start new game or load savegame
2. [ ] Attach a plow implement (e.g., Lemken Juwel 8)
3. [ ] Lower plow and till soil for 30 seconds
4. [ ] Check log for errors related to workArea
5. [ ] Verify no crashes during plowing operation

**Pass Criteria**: No nil access errors, plowing bonus applies correctly

---

### Issue #3: Logger String Format Crashes
**What was fixed**: Wrapped all string.format() calls in pcall with tostring() fallback

**Test Steps**:
1. **Enable debug mode**:
   - [ ] Open console (~)
   - [ ] Type: `SoilDebug`
   - [ ] Verify debug mode enabled

2. **Trigger various logging scenarios**:
   - [ ] Harvest crop (triggers onHarvest debug log)
   - [ ] Apply fertilizer (triggers onFertilizerApplied debug log)
   - [ ] Toggle HUD (J key)
   - [ ] Change settings in GUI
   - [ ] Run console command: `SoilFieldInfo 1`

3. **Check log for**:
   - [ ] All debug messages display correctly
   - [ ] No format string errors
   - [ ] Fallback messages if format fails (should show raw tostring)

**Pass Criteria**: No crashes from logging, all messages readable

---

## Phase 2: Robustness Improvements (MEDIUM Severity)

### Issue #4: HUD Nil Access Protection
**What was fixed**: Added defensive nil check before accessing fieldInfo properties

**Test Steps**:
1. [ ] Enable HUD (J key)
2. [ ] Stand in field with initialized data
3. [ ] Stand in uninitialized field
4. [ ] Stand outside any field
5. [ ] Rapidly toggle HUD on/off while moving between fields
6. [ ] Check for "Initializing..." vs actual field data display

**Pass Criteria**: No crashes, graceful "Initializing..." message for uninitialized fields

---

### Issue #5: Network Corruption Detection
**What was fixed**: Added validation + sanitization for MP field data with user notification

**Test Steps** (MULTIPLAYER REQUIRED):
1. **Normal MP sync**:
   - [ ] Host dedicated server
   - [ ] Client joins
   - [ ] Verify field data syncs correctly
   - [ ] Check log for: `[SoilFertilizer] Client: Synced X fields from server`

2. **Simulate corrupt data** (requires code modification):
   - [ ] Temporarily modify SoilFullSyncEvent:writeStream to send invalid values:
     - nitrogen = 999 (out of range)
     - pH = 12.0 (out of range)
     - organicMatter = -5 (negative)
   - [ ] Client joins
   - **Expected**: Log warnings: "Corrupt MP data: Field X nitrogen out of range... clamping to 0-100"
   - **Expected**: Notification shown: "Soil Mod: Data sync issue detected. Please report if this persists."
   - **Expected**: Values clamped to safe ranges (nitrogen → 100, pH → 7.5, organicMatter → 0)
   - [ ] Restore original code

**Pass Criteria**: Corruption detected, logged, clamped, user notified, game continues

---

### Issue #6: Field Scan Retry Protection
**What was fixed**: 3-tier retry (time → frame → fail gracefully) with notifications

**Test Steps**:

**Normal case (time-based success)**:
1. [ ] Start new game
2. [ ] Check log for: "Scanning fields via FieldManager..."
3. [ ] Verify: "Scanned X farmlands and initialized Y fields"
4. [ ] No retry attempts needed

**Delayed case (frame-based fallback)**:
1. **Simulate delayed field availability** (requires code modification):
   - [ ] Modify `scanFields()` to return `false` for first 10 calls
   - [ ] Launch game
   - **Expected**: Log shows: "Time-based retry failed after 10 attempts - switching to frame-based fallback"
   - **Expected**: Notification: "Soil Mod: Field initialization delayed. Trying alternative method..."
   - **Expected**: Log shows: "Frame-based field scan successful after X frames!"
   - **Expected**: Notification: "Soil Mod: Field initialization successful!"
   - [ ] Restore original code

**Failure case (total timeout)**:
1. **Simulate permanent field unavailability** (requires code modification):
   - [ ] Modify `scanFields()` to always return `false`
   - [ ] Launch game
   - **Expected**: Both time and frame retries fail
   - **Expected**: Dialog appears: "Could not initialize fields... The mod has been disabled for this session only... Please restart the game to try again"
   - **Expected**: Mod disabled (no crashes, graceful degradation)
   - [ ] Restart game (mod re-enables automatically)
   - [ ] Restore original code

**Pass Criteria**: All 3 tiers work, user notified at each stage, graceful failure

---

### Issue #7: Settings Validation Rejection
**What was fixed**: SettingsSchema.validate() now rejects unknown settings instead of passing through

**Test Steps**:
1. **Normal settings validation**:
   - [ ] Change settings via GUI (all known settings)
   - [ ] Save and reload
   - [ ] Verify all settings preserved

2. **Unknown setting injection** (requires manual XML edit):
   - [ ] Open `FS25_SoilFertilizer.xml` in savegame folder
   - [ ] Add fake setting: `<unknownSetting>true</unknownSetting>`
   - [ ] Launch game
   - **Expected**: Log shows: `[SoilFertilizer WARNING] Validation rejected unknown setting: unknownSetting`
   - **Expected**: Unknown setting ignored, not loaded into Settings object
   - [ ] Verify mod functions normally

**Pass Criteria**: Unknown settings rejected and logged, no crashes

---

## Phase 3: Code Quality (LOW Severity)

### Issue #8: HUD Color Theme Bounds
**What was fixed**: Clamp hudColorTheme to range 1-4 with logging

**Test Steps**:
1. **Normal theme selection**:
   - [ ] Open settings GUI
   - [ ] Cycle through all 4 color themes
   - [ ] Verify each renders correctly (Green, Blue, Amber, Mono)

2. **Invalid theme value** (requires XML edit):
   - [ ] Open `FS25_SoilFertilizer.xml`
   - [ ] Change `<hudColorTheme>10</hudColorTheme>`
   - [ ] Launch game
   - [ ] Enable HUD (J key)
   - **Expected**: Log warning: "HUD color theme out of range (10) - clamping to 1-4"
   - **Expected**: HUD displays with theme 4 (clamped max)
   - [ ] No crash

**Pass Criteria**: Out-of-range themes clamped, logged, HUD renders correctly

---

### Issue #9: Hook Debug Logging
**What was fixed**: Added hook-level debug logging for harvest and fertilizer events

**Test Steps**:
1. [ ] Enable debug mode: `SoilDebug`
2. [ ] Harvest any crop
   - **Expected log**: `[SoilFertilizer DEBUG] Harvest hook triggered: Field X, Crop Y, ZL`
   - **Expected log**: `[SoilFertilizer DEBUG] Harvest: Field X, Crop Y, ZL` (system-level)
3. [ ] Apply fertilizer
   - **Expected log**: `[SoilFertilizer DEBUG] Fertilizer hook triggered: Field X, Fill type FERTILIZER`
   - **Expected log**: `[SoilFertilizer DEBUG] Fertilizer: Field X, FERTILIZER, ZL` (system-level)

**Pass Criteria**: Both hook-level and system-level debug logs appear for each operation

---

### Issue #10: Console Command SoilListFields
**What was fixed**: Exposed unused listAllFields() function via new console command

**Test Steps**:
1. [ ] Open console (~)
2. [ ] Type: `soilfertility`
   - **Expected**: Command list includes: "SoilListFields - List all fields with soil data"
3. [ ] Type: `SoilListFields`
   - **Expected output**:
     ```
     [SoilFertilizer] === Listing all fields ===
     Our tracked fields:
       Field 1: N=50.0, P=40.0, K=45.0, pH=6.5, OM=3.50%
       Field 2: ...

     Fields in FieldManager:
       Field 1: Name=Field 1
       Field 2: Name=Field 2
     === End field list ===
     ```
4. [ ] Verify output matches actual field count and data

**Pass Criteria**: Command works, outputs all field data, no crashes

---

### Issue #11: Plowing Magic Number
**What was fixed**: Moved hardcoded 0.15 to SoilConstants.PLOWING.MIN_DEPTH_FOR_PLOWING

**Test Steps**:
1. [ ] Open `src/config/Constants.lua`
2. [ ] Verify section exists:
   ```lua
   SoilConstants.PLOWING = {
       MIN_DEPTH_FOR_PLOWING = 0.15,
   }
   ```
3. [ ] Open `src/hooks/HookManager.lua` line ~300
4. [ ] Verify code uses: `cultivatorSpec.workingDepth > SoilConstants.PLOWING.MIN_DEPTH_FOR_PLOWING`
5. [ ] Test plowing operation (should work identically to before)

**Pass Criteria**: Constant defined, used correctly, no behavioral change

---

### Issue #12: Network Value Clamping
**What was fixed**: Added math.max/min clamping to both SoilFullSyncEvent and SoilFieldUpdateEvent

**Test Steps** (MULTIPLAYER REQUIRED):
1. [ ] Host dedicated server
2. [ ] Client joins
3. [ ] Verify fields sync correctly
4. [ ] Harvest crop on server
   - **Expected**: SoilFieldUpdateEvent sent to clients
   - **Expected**: Client field data updates (check HUD)
5. [ ] Apply fertilizer on server
   - **Expected**: SoilFieldUpdateEvent sent to clients
   - **Expected**: Client field data updates (check HUD)
6. [ ] Check logs for no out-of-range errors

**Pass Criteria**: All network reads clamped to valid ranges, no corruption

---

## Regression Testing

### Core Functionality Checklist
- [ ] **Mod loads**: No errors in log on startup
- [ ] **Settings GUI**: Opens, all controls work, saves correctly
- [ ] **HUD display**: Shows field data, position presets work, themes work
- [ ] **Harvest depletion**: Nutrients decrease after harvest
- [ ] **Fertilizer restoration**: Nutrients increase after fertilizing
- [ ] **Plowing bonus**: Organic matter improves after deep plowing
- [ ] **Seasonal effects**: Spring nitrogen boost, fall nitrogen loss
- [ ] **Rain effects**: Nutrient leaching during rain
- [ ] **Console commands**: All 15 commands work (type `soilfertility` to list)
- [ ] **Save/Load**: Data persists across game restarts
- [ ] **Multiplayer sync**: Settings + field data sync server → clients
- [ ] **Admin enforcement**: Non-admin clients can't change settings
- [ ] **Precision Farming compatibility**: Mod enters read-only mode when PF detected
- [ ] **FPS performance**: No noticeable frame drops

### Edge Cases
- [ ] **Empty savegame**: Fresh start initializes all fields
- [ ] **Field ownership change**: Field data cleans up when sold
- [ ] **Rapid HUD toggle**: No crashes from J key spam
- [ ] **Multiple MP clients**: All clients sync correctly
- [ ] **Client disconnect/reconnect**: Sync resumes correctly
- [ ] **Difficulty changes**: Multipliers apply correctly
- [ ] **Disable/Re-enable mod**: State persists correctly

---

## Performance Validation

### Frame Rate Check
1. [ ] Enable F3 debug overlay (if available)
2. [ ] Measure FPS baseline (no soil mod)
3. [ ] Measure FPS with soil mod active
4. [ ] Verify < 5% FPS impact

### Memory Check
1. [ ] Monitor game memory usage over 30 minutes
2. [ ] Harvest crops, apply fertilizer, toggle HUD
3. [ ] Verify no memory leaks (stable memory usage)

---

## Final Verification

### Success Criteria Summary
- ✅ All 13 fixes verified individually
- ✅ No new crashes introduced
- ✅ All regression tests pass
- ✅ Multiplayer functionality intact
- ✅ Performance acceptable (<5% FPS impact)
- ✅ No memory leaks

### Version Bump
- [ ] Update `modDesc.xml` version to `1.0.5.0`
- [ ] Update CHANGELOG.md with all fixes
- [ ] Commit to development branch
- [ ] Create PR to main branch

---

## Notes

**Testing Time Estimate**: 3-4 hours comprehensive testing
**Minimum Viable Test**: Issues #1, #2, #3, #5, #6 (critical path) = 1 hour

**Test Environment Requirements**:
- FS25 v1.4+ (latest patch)
- Clean savegame OR existing v1.0.4.1 savegame
- Multiplayer test requires 2+ players (dedicated server preferred)

**Known Limitations**:
- Some tests require code modification (marked clearly)
- Performance testing accuracy depends on system specs
- Multiplayer tests require coordination

---

## Bug Reporting Template

If issues found during testing, use this template:

```
**Issue**: [Short description]
**Severity**: Critical / High / Medium / Low
**Related Fix**: Issue #X from audit
**Steps to Reproduce**:
1. ...
2. ...
3. ...
**Expected**: [What should happen]
**Actual**: [What actually happened]
**Log Output**: [Paste relevant log lines]
**Savegame**: [Attach if relevant]
```

---

*Testing checklist generated 2026-02-16 for v1.0.5.0 release*
