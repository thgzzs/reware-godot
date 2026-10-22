# Delivery milestones

## M0 — Version and reference gates: complete

Created: `docs/provenance.json`, `docs/BEHAVIOR_SPEC.md`.
Modified pre-existing files: none; the target is a new project.

Verified the requested 4.7.2 stable archive, release metadata (`prerelease=false`), versioned 4.7 documentation, downloaded release SHA-256 and executable version. Reviewed the APIs used for swept bodies, direct-state forces and space queries; the implementation subsequently executed on that exact release. Pinned reVC commit `a26fff4af555a8a425ac9f17d1dd718d00d1f942` through the GitHub connector. Initial source review covers player/ped, camera, weapon, automobile/tire/transmission/handling, physical forces, entry/exit, animation and world ordering.

Remaining: a canonical reference runtime/configuration, animation and handling/weapon data, broader NPC/AI/navigation audit and captured traces. The source review is bounded and does not establish complete gameplay requirements.

## M1 — Architecture and playable slice: implemented, headless acceptance passed

Created: all project, scene, component, Resource, test and documentation files listed below. Modified pre-existing target files: none. Files were iterated during this milestone; `FILES.sha256` records the delivered state.

Implemented: configurable character motor; follow/aim/driving camera; hitscan weapon/reload/damage; custom four-wheel Jolt vehicle; seat reservation/control transitions; primitive collision yard/targets; live diagnostics; fixed-command integration tests; exact-version validation tool.

Validation: 48 assertions passed with real Jolt on Godot 4.7.2 Stable, including repeated on-foot/vehicle loops and resumed weapon control. Portable validator completed import and execution. Results, timings and command transcript are included. Bugs corrected during acceptance: rounded stair contact starving movement intent; support detection at risers; steep-slope residual motion; incorrectly oriented ramp fixtures; wheel point velocity using an absolute contact with a relative center-of-mass offset; cached occupant contact causing a post-exit impulse. Tests now cover those behaviors.

Remaining: all discrepancies in DISCREPANCIES.md, especially reference calibration, skeletal animation, full AI/open-world systems, desktop visual/input verification, additional vehicle/weapon types and production performance budgets. This milestone does not complete full gameplay parity.

## M2 — Reference calibration: pending

Obtain and pin the runtime build/config and data. Record controlled reference/target input and motion traces. Agree behavior-specific tolerances. Fit movement/jump/camera/weapon/car/transition Resources. Add golden-trace comparisons and retain intentional modernization differences explicitly.

Expected modified files: tuning assets, behavior register, discrepancy report and acceptance thresholds; component changes only where measured behavior requires them. Validation must compare complete trajectories/timing, not only endpoints.

## M3 — Content and open-world expansion: pending

Add animation markers and door/seat presentation, multiple vehicle/weapon strategies, pedestrian command producers, navigation, traffic, spatial discovery, streaming and persistence. Add profiling workloads before optimization. Treat networking and mods as separately scoped systems with real authority/versioning contracts.

## Delivered file inventory

- `.gitignore`
- `LICENSE`
- `README.md`
- `actors/character_motor.gd`
- `actors/character_motor.gd.uid`
- `assets/manifest.json`
- `camera/follow_rig.gd`
- `camera/follow_rig.gd.uid`
- `combat/health.gd`
- `combat/health.gd.uid`
- `combat/weapon.gd`
- `combat/weapon.gd.uid`
- `core/command.gd`
- `core/command.gd.uid`
- `core/input_source.gd`
- `core/input_source.gd.uid`
- `debug/lab_overlay.gd`
- `debug/lab_overlay.gd.uid`
- `debug/telemetry.gd`
- `debug/telemetry.gd.uid`
- `docs/ARCHITECTURE.md`
- `docs/BEHAVIOR_SPEC.md`
- `docs/DISCREPANCIES.md`
- `docs/PHYSICS_MIGRATION.md`
- `docs/VALIDATION.md`
- `docs/provenance.json`
- `driving/vehicle.gd`
- `driving/vehicle.gd.uid`
- `driving/wheel_solver.gd`
- `driving/wheel_solver.gd.uid`
- `interaction/vehicle_transition.gd`
- `interaction/vehicle_transition.gd.uid`
- `project.godot`
- `scenes/arena.tscn`
- `scenes/character.tscn`
- `scenes/target.tscn`
- `scenes/vehicle.tscn`
- `tests/latest_results.json`
- `tests/run_suite.gd`
- `tests/run_suite.gd.uid`
- `tests/validation_transcript.txt`
- `tools/validate.py`
- `tuning/camera.tres`
- `tuning/camera_profile.gd`
- `tuning/camera_profile.gd.uid`
- `tuning/handling.tres`
- `tuning/handling_profile.gd`
- `tuning/handling_profile.gd.uid`
- `tuning/interaction.tres`
- `tuning/interaction_profile.gd`
- `tuning/interaction_profile.gd.uid`
- `tuning/movement.tres`
- `tuning/movement_profile.gd`
- `tuning/movement_profile.gd.uid`
- `tuning/weapon.tres`
- `tuning/weapon_profile.gd`
- `tuning/weapon_profile.gd.uid`
- `world/arena.gd`
- `world/arena.gd.uid`
- `world/primitives.gd`
- `world/primitives.gd.uid`

## M1.1 — Supplied animation/data integration: complete within available-file scope

Created: animation/imported_database.gd, imported_asset_setup.gd, reference_motion.gd, reference_pose.gd; actors/ped_health.gd and ped_brain.gd; debug/animation_browser.gd; tools/convert_reference_assets.py, build_animation_library.gd and import_local_assets.py; tests/run_imported_suite.gd and test_asset_conversion.py; docs/IMPORTED_ASSETS.md; source/converted asset folders and reports.

Modified: shared character motor, input command/source, arena composition, vehicle transition presentation/timing, HUD, validation entry point, gitignore, README, asset manifest and architecture/status documentation. No uploaded source file was changed.

Implemented: conversion of all 234 supplied clips to native Godot animation; full source table preservation; explicit subset of DAT fields applied; shared player/NPC components; original-clip locomotion timing/root curves; committed sprint stopping; animation browser and four route/flee NPCs.

Validation: independent decoding comparison, exhaustive native key comparison, 33 imported-mode assertions, 48 baseline regression assertions and 7 parser tests passed. Original skeleton/skin retargeting is unverified.

Remaining: gta3.img did not arrive; original character/vehicle/texture/rig conversion is blocked. Other IFP blocks, actual model binding, complete action/AI systems, reference captures, vehicle coefficient calibration and full parity remain open. This milestone does not claim otherwise.

## M1.2 — Selective model preparation and fistfight data

Created: tools/extract_selected_img.py, tests/test_selected_img.py, docs/SELECTIVE_MODEL_IMPORT.md.

Modified: animation/imported_database.gd, tools/convert_reference_assets.py, tools/build_animation_library.gd, tools/import_local_assets.py, debug/animation_browser.gd, world/arena.gd, tests/test_asset_conversion.py, tests/run_imported_suite.gd, README and asset/status documentation. Added unmodified assets/local_source/fistfite.dat and rebuilt converted Resources/reports.

Implemented: optional 32-row melee configuration import, explicit 30-fps timing conversion and sentinel handling; clip-inspector timings; original selective PC VC IMG v1 + DIR extractor with dry-run selection and per-output hashes.

Validation: see docs/VALIDATION.md for the current run. Synthetic archive tests cover selection and invalid inputs; no real IMG conversion test was possible.

Remaining: gta3.img upload failed again; matching gta3.dir and model/texture bytes are unavailable. Actual selective extraction, DFF/TXD conversion, skin/rig binding, shared material dependency resolution, melee combat and desktop visual validation remain unfinished.

## M1.3 — Selected models, native skin and responsive display

See MODEL_AND_DISPLAY_MILESTONE.md for the created/modified file register, implemented systems, selection evidence, validation and remaining gaps. The archive arrived this milestone, superseding the M1.1/M1.2 upload blockers. Four model roots and 25 textures are included in the private build; no full IMG extraction occurred.

## Action, interaction and packaging revision

Implemented explicit ZIP parent directories and a byte-preserving old-build repair/overlay tool; normalized arena indentation; layered locomotion/action/upper-body animation with aim/reload IK and recoil fallback; one-shot death and clearance-gated knockdown recovery; per-slot weapon state and Resource-driven arsenal; sprint with all guns; physical front doors and staged entry/exit; predicted pedestrian impacts; HUD life/weapon/reticle fixes and plain arena surfaces.

Created modules: animation/action_profile.gd, animation/actor_action_state.gd, driving/door_profile.gd, driving/vehicle_door.gd, driving/pedestrian_impact.gd, presentation/equipped_weapon_visual.gd, tuning/weapon_loadout.gd, tuning/actions.tres, tuning/doors.tres and tuning/arsenal.tres. Created tools: package_project.py and rebuild_test_build.py. New tests: run_revision_suite.gd, test_project_package.py and test_rebuild_test_build.py. New source review, test reports/transcripts and file register accompany them.

Modified actor health/motor, motion sampling, weapon/command/input, imported data wiring, vehicle/transition, HUD/model bindings, tuning, arena, validation helpers and existing asset-dependent tests. Exact created/modified paths, including Godot UIDs, are in revision_files.json. No project files were removed; no original asset files were generated.

Validation: exact Godot 4.7.2 Stable editor import; 48 baseline plus 41 new Jolt/synthetic-animation assertions passed; 14 Python tests passed, 9 private-input checks skipped. The ZIP regressions use 217-file fixtures and strict extraction with byte verification. Callback timings are reported in the current JSON reports; no speedup is claimed.

Remaining gaps: private asset-inclusive ZIP unavailable, so new original-model animation/door contacts and visual alignment are unverified; separate weapon IFP blocks required for original gun actions; browser import/export and target-GPU tests not run; source-calibrated impact/door/handling parity, visible driver, passengers/jacking/locks/ragdoll remain open. See REVISION_SOURCE_REVIEW.md and VALIDATION.md.
