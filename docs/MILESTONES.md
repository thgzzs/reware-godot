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
