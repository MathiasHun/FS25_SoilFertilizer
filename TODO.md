# TODO: FS25_SoilFertilizer

> Ecosystem role: **Soil and Crops** · Part of the Realistic Farming connected suite
> Status: FILLED from the ecosystem audit/baseline, kept current.
> Convention: `[ ]` open · `[~]` in progress · `[x]` done · `[!]` blocked. Newest at the top of each section.

## From the ecosystem audit (Arissani)
- [x] Resolve Point 8 (ProStaff silent bridge): decided no bridge now; baseline v3 "already consumed" claim to be corrected by Claude(A) to planned-not-built.
- [ ] Confirm getFieldInfo should stay the sole companion read path; verify CropDisease and DairyCore call it (not `soilSystem.fields`) during their audits.
- [ ] Decide whether getFieldInfo exposes FieldSentry state or companions keep reading `g_currentMission.fieldSentry`.

## Bugs
- [ ] None open from the audit. Track new ones from GitHub issues here.

## Features / enhancements
- [ ] NetworkSync v2 delta path: `onWriteDelta`/`onReadDelta` on SoilNetworkSyncBridge (send only changed fields).
- [ ] ProStaff fertilizer discount silent bridge (when scheduled): pcall-guarded `proStaffManager:getFertilizerDiscount(farmId)` as a cost multiplier at the fertilizer cost site.

## Cross-mod integration
- [x] StateLedger bridge (`SoilFertilizer_Soil`, delegate-when-present).
- [x] NetworkSync bridge (`SoilFertilizer_Sync`, whole-field-map).
- [x] MasterHUD bridge (soil HUD draw stack via subscribe).
- [x] SettingsHub bridge (settings mirrored for FarmTablet System Settings app).
- [ ] Lock module ids `SoilFertilizer_Soil` and `SoilFertilizer_Sync` with Claude(A) before release (persistence + wire keys, never rename after ship).
- [!] Two-machine MP sync test of the bridges (waits on: a live host+client session with a partner).

## Docs / localization
- [ ] Keep all 26 languages in step for any new setting or fill type.
- [ ] Update SoilVersionDialog CHANGELOG + README version on every release.

## Blocked / waiting on
- [!] getFieldInfo FieldSentry-state decision (waits on: audit answer).
- [!] ProStaff discount bridge (waits on: ProStaffCoOp handle confirmed + SF cost hook site scheduled).
