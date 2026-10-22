# Harbor / Behavior Lab

An original Godot gameplay framework inspired by reVC behavior, using **Godot 4.7.2 Stable** and built-in **Jolt Physics**. The earlier asset-inclusive test build has a textured skinned character shared by the player and four pedestrians, an Idaho car, a Colt .45, yard props, 234 converted animations and data-driven tuning. It is a first playable framework; full reVC equivalence is unverified.

The latest [motion and physics revision](docs/MOTION_REVISION.md) fixes shared wheel axle animation, jump pose ownership, camera-center aiming, visible seat alignment and solid Jolt pedestrian impacts. It adds temporal checks of actual bone movement, car contact and recovery.

This source revision adds layered action animation, one-shot death/recovery, weapon switching, all-gun sprinting, physical doors, staged vehicle transitions and swept pedestrian impacts. Arena surfaces default to plain colors. See [revision source review](docs/REVISION_SOURCE_REVIEW.md) for evidence and limitations. The public repository uses primitive fallbacks. The revised private test ZIP retains the supplied converted assets without reconversion.

## Run

1. Install [Godot 4.7.2 Stable](https://godotengine.org/download/archive/4.7.2-stable/). The application rejects other versions.
2. Import `project.godot`, wait for imports, then press F5.
3. Move, jump, aim and shoot the resetting targets. Approach the car, press E, drive/brake/reverse, stop and exit with E, then resume on foot.
4. F2 opens resolution and interface settings. F4 previews all supplied clips.

The Compatibility renderer and Jolt are configured. The engine executable is not bundled. The private download includes the selected converted assets; no conversion tool is needed to run it. The public source repository uses primitive fallbacks until local game data is imported. Original game uploads and derivatives are excluded from public git.

| Control | On foot | Driving |
| --- | --- | --- |
| WASD | Camera-relative movement, heading-coupled travel | Accelerate/brake/reverse and steer |
| Alt / Shift | Walk / sprint | — |
| Space | Jump with animation windup | Brake |
| Right / left mouse | Aim / fire | — |
| R | Reload | — |
| Wheel / Q / Z / 1–3 | Switch weapon | — |
| Backspace | Respawn after death | — |
| E | Enter nearby car | Exit when stopped and clear |
| Mouse | Orbit camera | Orbit camera |
| F1 / F2 | Controls / display settings | Same |
| F3 / F4 | Diagnostics / animation browser | Same; leave the car to preview the actor |
| Escape | Release cursor; click to recapture | Same |

## Resolution and replacement assets

The resizable window supports expanding aspect ratios, a height-preserving camera FOV and responsive HUD/radar/prompts. F2 offers window presets, fullscreen, interface scaling, independent 3D resolution scaling and optional adaptive resolution. Physics remains fixed at 60 Hz. Adaptation is based on sustained frame time and is disabled by default.

Edit **tuning/ped_impact.tres** for impact mass, lift, survival and recovery, **tuning/weapon_pose.tres** for arm/recoil/reload presentation, and **tuning/doors.tres** for seat calibration and door motors. Edit **tuning/arsenal.tres** for loadout profiles/reference weapon names and **tuning/actions.tres** for blend, reaction and all-gun sprint settings. Edit **tuning/placeholder_assets.tres** to replace model/texture roles, attachment offsets, paint and approximate hull sizing. Gameplay controllers do not own the artwork. Replacement character rigs must be compatible with the animation bindings or deliberately retargeted.

Only four selected model roots and 25 PNGs were exported from the uploaded files. The entire IMG is not included. See [the model/display milestone](docs/MODEL_AND_DISPLAY_MILESTONE.md) for selection evidence, native skin validation, setup, limitations and rebuilding.

## Validate

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator checks the exact engine, imports the project and runs appropriate real-Jolt suites. Imported suites run when their private assets are available. Python conversion tests require Pillow; private-file tests skip if their inputs are absent. See [VALIDATION.md](docs/VALIDATION.md) for the latest counts, measured scope and rendered checks.

## Rebuild the existing ZIP

Every ZIP created with the packager includes explicit parent-directory entries for strict web-editor extractors. To repair an old ZIP without changing any file bytes:

```bash
python3 tools/rebuild_test_build.py --input old-build.zip --output repaired-build.zip
```

To apply this source revision and preserve the old converted assets, add `--project .` to that command. No model, texture or animation conversion is required. To package the current directory, run `python3 tools/package_project.py --output Harbor.zip`. An actual browser import and exported web runtime remain unverified.

## Documentation

- [IMPORTED_ASSETS.md](docs/IMPORTED_ASSETS.md): animation conversion, DAT mappings, shared character behavior and limitations.
- [MODEL_AND_DISPLAY_MILESTONE.md](docs/MODEL_AND_DISPLAY_MILESTONE.md): models, materials, skin binding, responsive UI, rebuilding and replacement workflow.
- [SELECTIVE_MODEL_IMPORT.md](docs/SELECTIVE_MODEL_IMPORT.md): archive selection and minimal asset scope.
- [ARCHITECTURE.md](docs/ARCHITECTURE.md): ownership and extension boundaries.
- [BEHAVIOR_SPEC.md](docs/BEHAVIOR_SPEC.md) and [PHYSICS_MIGRATION.md](docs/PHYSICS_MIGRATION.md): source findings and calibration requirements.
- [DISCREPANCIES.md](docs/DISCREPANCIES.md): remaining gaps and parity status.
- [MILESTONES.md](docs/MILESTONES.md): created/modified files and validation by milestone.

Source review and implementation occurred in one workflow; this is not an independently staffed clean-room audit. No source code translation, gameplay equivalence or performance superiority is claimed. Framework licensing does not relicense supplied game assets.

