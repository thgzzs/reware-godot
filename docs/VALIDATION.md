# Current validation

Godot **4.7.2 Stable**, official `ed1daf0bf`, built-in **Jolt**, fixed 60 Hz. See provenance.json for the exact engine archive digest. Historical reports and milestone counts describe earlier revisions.

| Suite | Passed | Scope |
| --- | ---: | --- |
| Baseline gameplay | 47 | Movement, jump, targeting, suspension and first playable loop |
| Action contracts | 41 | Synthetic fixtures: masks, reactions, doors and transitions |
| Imported animation/data | 36 | Native 294,062-key round trip and data integration |
| Native presentation | 28 | Skin, model markers, layout/display and pose sampling |
| Native actions | 66 | 24-entry loadout, masked actions, death and doors |
| Temporal motion | 63 | 24-entry action timing, movement, seats, wheel spin and physical impacts |
| Systems | 54 | Props, tires/glass, stance, firing, melee, seats and damage |
| Foundations | 13 | Jump/slope response, heavy pushes and impact lifecycle |
| Stories assets | 10 | 44 blocks, all originals/aliases, rig-ID mapping and exact assets |
| Stories gameplay | 77 | Retaliation, spatial strikes, localized collisions, fragments, bikes and bailouts |
| Falling / mobile melee | 48 | Real drops/ledge/recovery, shared actors, all melee weapons, stride/pose/tip/collision and cancellation |

Total: **483 Godot/Jolt assertions**, **23 Python tests with none skipped**, and **five local render-rate comparisons**. The prior nine selected software-OpenGL states were reviewed: pistol hip fire, M4 aim, katana strike, PCJ600 rider, Faggio rider, bike collection, panel damage, detached bonnet and overturned crawl. This is selected visual review, not exhaustive contact verification.

Reports are tests/*_results.json. The current structured transcript is tests/fall_validation_transcript.txt; fall_python_transcript.txt records the 23 Python tests. Four new software-OpenGL captures review descent, hard landing and running bat/katana attacks. Earlier transcripts are historical. The independent legacy decoder report applies to the original ped.ifp only; current Stories validation compares native curves against the portable source representation after deterministic duplicate-time coalescing. The Stories import CLI was reproduced in isolation: five portable outputs and all 46 new PNGs exactly matched.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable
python3 tools/check_render_timing.py --godot /absolute/path/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator checks the exact version, imports first, removes stale result files, enforces process timeouts and fails on script errors or failed assertions. Asset-dependent suites only run when their private inputs exist. Python private-input tests skip if those inputs are absent. Rendering fixtures in tests/render_stories_preview.gd require a graphical display.

## Target measurements

The native Idaho acceptance fixture reaches 10 m/s in 1.267 s. Its 2.5 s high-speed corner test begins at 22 m/s, ends near 28.51 m/s and retains a minimum upright dot of 0.99980. Source-derived behavior and intentional balance changes are distinguished in STORIES_REVISION.md. These targets have not been compared to original-runtime traces.

| Callback | Samples | Mean, us | p95, us |
| --- | ---: | ---: | ---: |
| Stories native orchestration | 3600 | 277.5 | 442.0 |
| Four-wheel force/query | 3600 | 34.5 | 61.0 |
| Native player pose sample | 180 | 160.5 | 260.0 |

These shared-environment CPU samples cover only the named callbacks. Orchestration includes the controlled player pose but excludes independent NPC/door/probe callbacks, Jolt solving, HUD drawing and rendering. Pose timing excludes other actors and GPU skinning. The Stories orchestration maximum was 5.5 ms; shared-environment scheduling pauses are included. Complete statistics remain in the JSON report. No complete frame budget, speedup or performance superiority is claimed. Caches avoid repeated rig resolution and contact-list allocations; no comparative benchmark isolates their savings.

Five replays use render rates 30/60/120/144 and a variable-cap real-clock run, with physics fixed at 60 Hz. Sampled player position, velocity, pose, state and shot count agree; the maximum car-position difference is 4.173e-07 m. The variable case observes render deltas from 0.000863 to 0.1474147 s. This controlled local fixture does not establish all-bike, cross-platform, alternate-physics-rate or network determinism.

## Packaging and limits

The ZIP uses explicit parent-directory entries, CRC checks, SHA-256 manifests and strict extraction. The four original model scenes and 25 PNGs are preserved; the active animation library and weapon/fight tables are intentionally replaced. The original source ZIP had 217 files and zero directory entries. A fresh extracted-project import/startup is required by the delivery packager.

Software-rendered captures use Mesa llvmpipe, not a physical GPU. Original executable behavior, browser import/playback, full visual parity, hardware GPU performance and target-device usability remain unverified. Gameplay parity, visual parity and performance parity are separate goals.

## Falling and mobile-melee measurements

In the current native fixture a 2 m drop causes no damage, a 4 m drop causes approximately 10 health damage, a 7 m drop approximately 64 and an 18 m drop reaches the 200-damage cap. Walk/run/sprint attacks retain at least 85% of unarmed stride distance and remain below 115%, without adding stationary attack-root velocity. These are target acceptance bands, not original-game parity. See tests/fall_melee_results.json and FALL_AND_MOBILE_MELEE.md. All previously selected private asset bytes are retained; this revision performs no asset reconversion.
