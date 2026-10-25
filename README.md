# Harbor / Behavior Lab

An original Godot gameplay framework inspired by reVC behavior, using **Godot 4.7.2 Stable** and built-in **Jolt Physics**. The asset-inclusive test build has a shared player/pedestrian actor, 24 weapon entries, three cars, four bikes, dynamic props and 1168 native animation entries (781 original clips plus retained source variants). It is a playable framework; full reVC equivalence remains unverified.

The [Stories revision](docs/STORIES_REVISION.md) adds spatial melee, pedestrian retaliation, native hip-fire/reload refinement, individual panel damage and physical fragments, full-size flat tires, stronger acceleration, safer cornering, tilted-car crawl exits and moving bailouts. VCS core/weapon animations and LCS bike animations are active; all clips remain accessible in F4. Public git supplies source and import tools; the private ZIP includes selected supplied assets.

The [falling and moving-melee revision](docs/FALL_AND_MOBILE_MELEE.md) adds impact-based fall damage, native descent/glide/landing recovery and walk/run/sprint attacks with blended striking limbs. Tune it through tuning/fall.tres and tuning/melee.tres.

The current [sprint, walk-in entry and settling revision](docs/SPRINT_ENTRY_SETTLING.md) adds capped Shift tapping, collision-driven walking and alignment before mounting, quiet grounded prone/supine settling, and bike-specific rear bailouts. The complete test ZIP includes the supplied assets unchanged; native regression and selected software-rendered poses have been checked.

The [Android/mobile revision](docs/MOBILE_ANDROID.md) adds multi-touch movement, camera and context-sensitive action controls, a phone HUD layout, and a signed Android test APK. The full project ZIP preserves the supplied assets and includes the local test signing identity for repeatable test updates.

The current [combat and driving revision](docs/COMBAT_DRIVING_REVISION.md) adds independent soft landing presentation, directional hit reactions, gradual gait changes, native long-gun grips, legacy crouch, ground attacks, tighter calibrated entry, Idaho two-seat capacity, quiet corpse retirement, physical bike pickup/falls, slow pushing reverse, crash ejection and frontal bonnet damage.

The latest [spatial movement and bike revision](docs/SPATIAL_MOTION_REVISION.md) makes native strides and landings drive collision travel, limits turning on the ground and in the air, clears riding layers on ejection, and separates upright parked bikes from physically fallen bikes. Android Build 6 replaces Build 5 under the same isolated package.

The current [respawn and bike lean revision](docs/RECOVERY_REVISION.md) adds timed pedestrian respawn, safe actor and vehicle void recovery, twenty-percent quicker player turning and corrected tire-force compensation during bike banking. Android Build 7 updates the preceding app using the same package.

The latest [spatial reactions, entry and wreck revision](docs/ACTIONS_DRIVING_REVISION.md) corrects pickup aliases, speeds up player turns and final vehicle alignment, widens steering range, drives grounded hit reactions from native motion and adds scorched vehicles with a safe twenty-second wreck respawn. Android Build 8 updates the same app package.

## Run

1. Install [Godot 4.7.2 Stable](https://godotengine.org/download/archive/4.7.2-stable/). The application rejects other versions.
2. Import `project.godot`, wait for imports, then press F5.
3. Move, jump, aim and shoot the resetting targets. Approach a car or bike, press E, drive/brake/reverse, and exit with E (bail out while moving), then resume on foot.
4. F2 opens resolution and interface settings. F4 previews all supplied clips.

The Compatibility renderer and Jolt are configured. The engine executable is not bundled. The private download includes the selected converted assets; no conversion tool is needed to run it. The public source repository uses primitive fallbacks until local game data is imported. Original game uploads and derivatives are excluded from public git.

| Control | On foot | Driving |
| --- | --- | --- |
| WASD | Camera-relative movement, heading-coupled travel | Accelerate/brake/reverse and steer |
| Alt / Shift | Walk / hold sprint; tap for capped boost | — |
| Space | Jump with animation windup; firing disabled in air | Brake |
| C | Toggle crouch; crouched aim/fire | — |
| V | Cycle follow distances | Follow/bonnet camera |
| Alt+E / X | Passenger entry / — | Passenger-to-driver shuffle |
| F6 | Repair nearby stopped lab car | Repair stopped lab car |
| Right / left mouse | Aim / fire or melee strike | — |
| R | Reload | — |
| Wheel / Q / Z / 1–9 | Switch weapon | — |
| Backspace | Respawn after death | — |
| E | Walk to the selected door/mount, enter; press again to cancel approach | Exit, crawl out when tilted, or bail while moving |
| Mouse | Orbit camera | Orbit camera |
| F1 / F2 | Controls / display settings | Same |
| F3 / F4 | Diagnostics / animation browser | Same; leave the car to preview the actor |
| Escape | Release cursor; click to recapture | Same |

## Resolution and replacement assets

The resizable window supports expanding aspect ratios, a height-preserving camera FOV and responsive HUD/radar/prompts. F2 offers window presets, fullscreen, interface scaling, independent 3D resolution scaling and optional adaptive resolution. Physics remains fixed at 60 Hz. Adaptation is based on sustained frame time and is disabled by default.

Edit **tuning/ped_impact.tres** for impact mass, lift, survival and recovery, **tuning/weapon_pose.tres** for arm/recoil/reload presentation, and **tuning/doors.tres** for seat calibration and door motors. Edit **tuning/arsenal.tres** for loadout profiles/reference weapon names and **tuning/actions.tres** for blend, reaction and all-gun sprint settings. Edit **tuning/placeholder_assets.tres** to replace model/texture roles, attachment offsets, paint and approximate hull sizing. Gameplay controllers do not own the artwork. Replacement character rigs must be compatible with the animation bindings or deliberately retargeted.

The build contains 32 selected model scenes and 71 PNGs; the entire IMG is not included. The Stories revision documents the 28 additional models and 46 additional textures. Bone-ID bindings, exact model roles and data-driven melee/weapon action definitions support replacement assets. See [the model/display milestone](docs/MODEL_AND_DISPLAY_MILESTONE.md) for selection evidence, native skin validation, setup, limitations and rebuilding.

## Validate

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 tools/check_render_timing.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator checks the exact engine, imports the project and runs appropriate real-Jolt suites. Imported suites run when their private assets are available. Python conversion tests require Pillow; private-file tests skip if their inputs are absent. See [VALIDATION.md](docs/VALIDATION.md) for the latest counts, measured scope and rendered checks.

## Rebuild the existing ZIP

Every ZIP created with the packager includes explicit parent-directory entries for strict web-editor extractors. To repair an old ZIP without changing any file bytes:

```bash
python3 tools/rebuild_test_build.py --input old-build.zip --output repaired-build.zip
```

To overlay a project directory, add `--project .` to that command. This revision reuses the supplied Stories assets without reconversion. The complete revised ZIP already contains them. To package the current directory, run `python3 tools/package_project.py --output Harbor.zip`. An actual browser import and exported web runtime remain unverified.

## Documentation

- [STORIES_REVISION.md](docs/STORIES_REVISION.md): current combat, bike, vehicle, conversion and extension details.
- [IMPORTED_ASSETS.md](docs/IMPORTED_ASSETS.md): animation conversion, DAT mappings, shared character behavior and limitations.
- [MODEL_AND_DISPLAY_MILESTONE.md](docs/MODEL_AND_DISPLAY_MILESTONE.md): models, materials, skin binding, responsive UI, rebuilding and replacement workflow.
- [SELECTIVE_MODEL_IMPORT.md](docs/SELECTIVE_MODEL_IMPORT.md): archive selection and minimal asset scope.
- [ARCHITECTURE.md](docs/ARCHITECTURE.md): ownership and extension boundaries.
- [BEHAVIOR_SPEC.md](docs/BEHAVIOR_SPEC.md) and [PHYSICS_MIGRATION.md](docs/PHYSICS_MIGRATION.md): source findings and calibration requirements.
- [DISCREPANCIES.md](docs/DISCREPANCIES.md): remaining gaps and parity status.
- [MILESTONES.md](docs/MILESTONES.md): created/modified files and validation by milestone.

Source review and implementation occurred in one workflow; this is not an independently staffed clean-room audit. No source code translation, gameplay equivalence or performance superiority is claimed. Framework licensing does not relicense supplied game assets.

