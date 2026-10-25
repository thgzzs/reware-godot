# Build 8 validation

Exactly Godot **4.7.2 Stable** (ed1daf0bf), Jolt Physics, 60 Hz simulation. The complete batch passes **712 assertions across 18 suites**. All **134 scripts** compile and **23 Python tests** pass. The new suite contributes 32 native spatial-hit, wall collision, steering range, entry timing/cancellation, pickup hand-direction and scorched/wreck-lifecycle assertions. See [ACTIONS_DRIVING_REVISION.md](ACTIONS_DRIVING_REVISION.md), actions_validation.json and tests/actions_validation_transcript.txt.

An identical four-case approach/alignment benchmark measures Build 7 at 1.35–1.40 seconds and Build 8 at 0.533–0.550 seconds before the native opening/mounting stage, about 60% less delay. Opening/seating animation durations are retained. Maximum unobstructed spatial-hit displacement error against independently sampled native keys is below 0.000003 m per tick, with a 0.003 m tolerance; walls block travel. This is interaction latency and collision/animation validation, not an FPS or GPU improvement claim.

**Harbor-Rev8.apk**, version **0.6.0-actions8**, code **8**, launcher **Harbor Rev 8**, HUD **BUILD 8**, same package and private signing identity as the preceding app. Export and actual packaged-payload checks are recorded in actions_package.json. Physical Android execution and original-game runtime parity remain untested. Existing corpse settling, fall/jump motion, bicycle balancing, entry/exit, combat, native asset, mobile and UI checks remain in the full batch.

The earlier detailed results below are historical context. Their old timing/render captures were not repeated for this revision.

# Historical Build 7 validation

Exactly Godot **4.7.2 Stable** (ed1daf0bf), Jolt Physics, 60 Hz simulation. The complete batch passes **680 assertions across 17 suites**. All **130 scripts** compile and **23 Python tests** pass. Build 7 adds seventeen respawn, void-recovery and actual left/right bike-bank checks to the preceding suites. See [RECOVERY_REVISION.md](RECOVERY_REVISION.md), recovery_validation.json and tests/recovery_validation_transcript.txt for the changes and repeatable evidence.

Player turning rates are 20% higher while AI tuning and locked airborne heading are unchanged. Left/right bike bank tracking error averages approximately 0.040 radians and residual bank after three seconds without steering is below 0.002 radians in the isolated fixture. Pedestrian delay is eight seconds; test clocks use a shorter duplicate Resource to check pre/post expiry without changing shipped tuning.

**Harbor-Rev7.apk**, version **0.5.1-recovery7**, code **7**, launcher **Harbor Rev 7**, HUD **BUILD 7**, same package and test signing identity as the preceding build. Actual packaged-payload checks are recorded in recovery_package.json. No Android hardware execution, original-runtime equivalence or comparative performance improvement is claimed.

The detailed Build 6 results below are historical context; their checked gameplay remains covered by the current full regression batch. Historical timing and renders were not repeated for this revision.

# Historical Build 6 validation

Exactly Godot **4.7.2 Stable** (ed1daf0bf), Jolt Physics, 60 Hz simulation. The complete batch passes **663 assertions across 16 suites**. All **127 scripts** compile and **23 Python tests** pass.

| Suite | Assertions |
| --- | ---: |
| latest | 47 |
| revision | 41 |
| intent_revision | 42 |
| mobile | 34 |
| imported | 37 |
| presentation | 28 |
| native_action | 66 |
| motion | 63 |
| systems | 54 |
| foundation | 13 |
| native_intent | 43 |
| stories_assets | 10 |
| stories | 77 |
| fall_melee | 48 |
| behavior_revision | 42 |
| spatial_motion | 18 |

The new spatial suite measures actual collision travel against independently sampled native animation keys, lateral motion under turning, bounded ground heading, frozen input-driven air/landing heading, spatial jump launch and landing, upright empty parked bikes, fully side-resting bikes, wheel-support release, physical pickup, removal of riding layers on ejection, changing rider limbs and bounded torso rotation. The other suites retain combat, damage, props, entry/exit, assets and mobile regression coverage. Geometry fixtures reset facing explicitly now that turning is deliberately gradual.

## Final APK

**Harbor Rev 6**, version **0.5.0-spatial6**, code **6**, package **org.reware.harbor.revision5**. It updates Build 5 using the same private test signing key. ARM64 + ARMv7, minimum API 24, target API 36. Signature, CRC, 16 KiB native ZIP alignment, 16 KiB ARM64 ELF load alignment, native Jolt and all 32 model scenes pass.

After a clean extraction of the actual final APK assets, the exact desktop engine verifies BUILD 6 identity, HUD label fit, native asset activation and mobile controls. The extracted compiled gameplay then passes **42 behavior + 18 spatial + 34 touch-input checks**. This exercises the packaged payload, not Android Java/JNI/GPU execution. The loaded content includes 1168 animation entries, 24 weapons, four pedestrians, seven vehicles, legacy crouch and two-seat Idaho.

## Timing and visual checks

Native command playback was repeated at 30/60/120/144 and varying render caps while physics stays at 60 Hz. All five comparisons pass for sampled movement, vehicle position, pose quaternion, shots and state within 0.002 tolerance. This is local fixture consistency, not cross-platform determinism or GPU profiling.

Nine selected native poses were rendered with Compatibility/Mesa llvmpipe and reviewed: walking, turning, airborne jump, landing, upright parked bikes, fallen bike, pickup, crash release and crash follow-through. Repeat with tests/render_spatial_preview.gd. These are desktop software renders, not phone captures or exhaustive animation-contact validation.

## Measurements and performance scope

The new free-ground fixture records approximately 0.000002 m maximum per-tick displacement error against animation keys, with tolerance 0.003 m. The direction-change fixture records about 0.004 m maximum lateral movement, consistent with the supplied root sway. Input-driven air and landing heading changes are zero in the fixture. The side-resting bike has near-zero up-dot and leaves wheel-ray support; parked fixtures retain up-dot above 0.98.

Current Stories orchestration callback: mean **286.8 microseconds**, p95 **439.0 microseconds**, maximum **4257.0 microseconds**, 3600 samples. This excludes Jolt solving/rendering and includes environment noise. Workloads changed, so no comparative FPS improvement is claimed.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable
Godot_4.7.2_stable --headless --path . --script res://tools/check_project_scripts.gd
python3 tools/check_render_timing.py --godot /absolute/path/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Use tools/export_android.py for a signed test rebuild. Run tools/check_android_payload.gd against a clean extracted APK assets directory for the identity/content smoke test. The native suites require the supplied private assets. Current reports are the *_results.json files and spatial_validation_transcript.txt; earlier named transcripts are historical.

## Assets, packaging and remaining gaps

All 315 original selected asset/support payloads are unchanged. The legacy crouch override remains the only added converted clip. The full project ZIP includes explicit parent directories, a complete SHA256 manifest and the private test key; public git excludes supplied assets, native previews and signing material. Fresh ZIP import/startup is checked during packaging.

No physical Android device, Android emulator or running original executable was available. Exact original feel, every slope/weapon/pose contact, aim-strafe variants, grip constraints, full browser execution, articulated ragdolls, hardware performance and full gameplay/visual/performance parity remain unverified. See SPATIAL_MOTION_REVISION.md for source-confirmed findings, target tuning and limits.
