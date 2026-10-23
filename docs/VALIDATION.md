# Current asset-inclusive validation

Godot **4.7.2 Stable**, official ed1daf0bf, built-in Jolt, physics 60 Hz. The verified official Linux archive has SHA-256 cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4. No engine substitution was used.

The supplied complete ZIP restored the native assets. All **569 Godot/Jolt assertions across 13 suites** and all **23 Python tests without skips** pass in this revision. Earlier milestone counts are historical.

| Suite | Passed | Scope |
| --- | ---: | --- |
| Baseline | 47 | Primitive real-Jolt playable loop |
| Action/door regression | 41 | Synthetic clips, masks, doors and impacts |
| Intent regression | 42 | Independent tap/route/settling fixtures |
| Imported data | 37 | All 1168 native entries and every converted key |
| Presentation | 28 | Rig, models, HUD and replacement bindings |
| Native actions | 66 | Weapon masks, sprint, doors, death and holstering |
| Motion/impacts | 63 | Native motion and physical momentum exchange |
| Systems | 54 | Props, stance, glass, tires and damage |
| Foundation | 13 | State, units, ownership and configuration |
| Native intent | 43 | Native tapping, car/four-bike entry, rear release and directional rests/get-up |
| Stories assets | 10 | Selected models and all source animation blocks |
| Stories gameplay | 77 | Melee, panels, handling, exits and bikes |
| Fall/mobile melee | 48 | Fall damage, recovery and moving strikes |

All 108 other GDScript files load in the script check. Five fixed-physics comparisons pass at 30/60/120/144 and varying render caps. These CPU replay checks do not measure GPU throughput or prove cross-platform determinism.

## Current measurements

Repeated native sprint tapping keeps sprint_civi and the moving phase for all 300 sampled ticks. The gait clock advances on every tick. Instantaneous native root speed is 6.92–13.95 m/s; the supplied clip has a varying root curve. The independent linear fixture measures 6.0–7.2 m/s and verifies the strict 1.20 multiplier cap, decay and release grace. Neither curve is calibrated against a running original executable.

Native walk-ins reach the car and all four bikes through the standing motor before mounting. Sampled maximum tick displacement is under 0.04 m. The right-side Sanchez regression now completes with normal-rate walk-start anticipation. The seat remains reserved until mounting commits; cancellation/death/lost reservation/blockers preserve safe ownership.

Forward quiet falls select prone KO_skid_back; backward falls select supine KO_skid_front. Native skin minima are 0.01010 and 0.01037 m above the flat floor, with terminal heights 0.311 and 0.363 m. Chest orientation is checked independently. Native getup_front/getup restores the diagonal fall heading. All four supplied bike-specific getoffBACK clips retain occupancy during windup and release once into the Jolt torso.

Seven selected poses were rendered at 1280×720 with the Compatibility renderer and Mesa llvmpipe: sprint, prone, supine, and rear-exit windup on PCJ600/Sanchez/Faggio/Freeway. They were visually reviewed. The complete ZIP includes these previews and their repeatable render script. These snapshots are limited visual checks, not exhaustive hand/foot/vehicle-contact or temporal parity.

The native Stories orchestration callback sampled 3600 ticks: mean 271.8 us, p95 423 us. The primitive baseline sampled 3496 ticks: mean 81.8 us, p95 152 us. These shared CPU-environment samples exclude Jolt solving and rendering; the fixtures have different workloads. No comparative speedup or full frame-budget claim is made.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable
Godot_4.7.2_stable --headless --path . --script res://tools/check_project_scripts.gd
python3 tools/check_render_timing.py --godot /absolute/path/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

With a graphical display, run `Godot_4.7.2_stable --path . --resolution 1280x720 --fixed-fps 60 --script res://tests/render_native_intent_preview.gd` to regenerate selected previews.

The validator rejects other engines, imports first and selects private-asset suites only when their inputs exist. Synthetic suites explicitly disable those assets. Native transition tests wait for approach completion before measuring animation-stage duration. Current JSON reports, intent_validation_transcript.txt and intent_python_transcript.txt record the results.

The complete ZIP retains explicit parent directories before files, passes CRC/SHA checks and strict sequential extraction, and imports/starts from a fresh cache. All 315 selected private asset/support payloads are byte-identical to the supplied ZIP; no reconversion occurred. Public git excludes those payloads and native screenshots, while the delivered private test ZIP contains them.

## Remaining validation gaps

Original-executable behavioral/visual/performance traces, actual browser import/export/playback, hardware GPU profiling, the full device matrix, exhaustive clip contacts and articulated ragdolls remain unverified. This is a playable framework, not a claim of full reVC equivalence. See SPRINT_ENTRY_SETTLING.md and DISCREPANCIES.md.
