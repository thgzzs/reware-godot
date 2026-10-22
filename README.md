# Harbor / Behavior Lab

An original Godot gameplay framework and executable first-playable prototype informed by source-observable reVC behavior. This is an early milestone, not a completed reVC-equivalent game. It contains no reference source, original game assets, maps, branding, or converted code.

## Run

1. Install **Godot 4.7.2 Stable** from https://godotengine.org/download/archive/4.7.2-stable/ . No other version is accepted by the application.
2. Import `project.godot` with that editor and press F6 on `scenes/arena.tscn`, or F5 to run the project.
3. Confirm **Project Settings > Physics > 3D > Physics Engine = Jolt Physics**. The setting is committed; no extension is required.
4. Approach the orange coupe and press E. Stop with Space before exiting with E. The same character can continue moving and shooting afterward.

The supplied project uses the Compatibility renderer and built-in Jolt. Desktop keyboard/mouse is the implemented input path. No external assets, plugins, engine compilation, network services, or reference-game installation are needed to run this prototype. The editor executable is not bundled.

| Control | On foot | Driving |
| --- | --- | --- |
| W / S | Forward / backward relative to camera | Accelerate / brake then reverse |
| A / D | Strafe relative to camera | Steer |
| Space | Buffered jump with windup | Brake |
| Shift | Sprint | — |
| Right mouse | Aim / slower movement | — |
| Left mouse | Fire | — |
| R | Reload | — |
| E | Enter nearby vehicle | Exit when stopped and a safe exit is clear |
| Mouse | Orbit camera | Orbit camera |
| F3 | Diagnostics | Diagnostics |
| Escape | Release cursor; click to recapture | Same |

## Validate

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
```

On Windows, use the console executable for useful logs. The validator imports the project, rejects mismatched engines, runs the real Jolt integration suite at 60 Hz, and writes `tests/latest_results.json`. It does not download or substitute an engine. Tests run much faster than real time in headless mode.

## Tune

Edit the five `.tres` files under `tuning/` in the Inspector. Serialized movement, handling, weapon, camera, and interaction values are intentionally provisional. They have prototype acceptance tests, not reference-runtime calibration. New actor/vehicle scenes can reuse the same components with different Resources. Use separate Resources or `duplicate()` for per-instance tuning; do not mutate shared tuning during gameplay.

## Read

- `docs/BEHAVIOR_SPEC.md`: source findings, evidence classification, inputs, outputs, ordering, states and dependencies.
- `docs/ARCHITECTURE.md`: ownership, phases, extension boundaries and transition guarantees.
- `docs/PHYSICS_MIGRATION.md`: units, custom solver decisions and calibration requirements.
- `docs/VALIDATION.md`: automated and manual checks, measured prototype results and profiling scope.
- `docs/DISCREPANCIES.md`: unimplemented systems and unverified parity.
- `docs/MILESTONES.md`: delivered files, validation, remaining work and next milestones.
- `docs/provenance.json`: exact engine metadata, checksum, reference commit and reviewed files.
- `assets/manifest.json`: authored primitive assets and dependencies.

Source review and implementation were performed in one workflow. The deliverable follows the requested behavioral-spec separation and uses an unrelated implementation structure; it is not an independently staffed clean-room audit. No source correspondence or gameplay equivalence is asserted.
