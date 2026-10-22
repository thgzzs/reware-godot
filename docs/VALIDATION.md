# Current validation

Godot **4.7.2 Stable**, official `ed1daf0bf`, built-in **Jolt Physics**, fixed 60 Hz. The exact official engine and documentation references are pinned in provenance.json.

| Group | Latest result |
| --- | --- |
| Baseline gameplay assertions, imported mode disabled | 48 passed |
| Imported animation/data and continuous gameplay loop | 36 passed |
| Native models, real skin, display/layout/input/adaptation | 28 passed |
| Python parser, selective extractor and model/texture tests | 18 passed |
| Independent IFP decoder comparison | 87,546 source keys; zero mismatches |
| Native animation round trip | 95,427 channel keys; zero mismatches within tolerance |
| Native Godot software-OpenGL captures | 6 captured and visually reviewed |

The model suite checks 25 native frames/24 skin binds, every weight/palette index, inverse-bind/rest cancellation, upright idle deformation, root-motion ownership, shared player/NPC components, hand attachment, car markers/variants/hull and spawn settling. Window sizes 640×360, 1024×768, 1280×720, 1920×1080, 2560×1080, 3440×1440, 3840×2160 and 1080×1920 verify HUD bounds, nonoverlapping cards and centered camera rays. It also checks independent UI/3D scale changes, menu input blocking, input resumption, adaptive recovery/cooldown and minimum scale.

Reports: tests/latest_results.json, imported_results.json, presentation_results.json and independent_decoder_results.json. The transcripts record exact measurements and assertion labels. Native image/key/vertex data checks do not prove gameplay equivalence.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator rejects other engines, imports before testing, fails on script errors and runs asset-dependent suites only when their inputs exist. It does not fetch an engine. Private conversion tests skip if source inputs are unavailable; Pillow is needed for Python texture tests. For rendered checks on a desktop, run tests/render_model_preview.gd through the same exact editor with a working display.

## Rendered scope

The virtual-window setup was repaired for this milestone. Actual Godot Compatibility rendering used Mesa llvmpipe software OpenGL 4.5. Captures in this private build show the selected skin/texture/car, HUD, display settings, 4:3, wide, portrait and animation browser. Earlier milestone statements that no window rendering was possible are historical and superseded. Audio was explicitly disabled for captures because no sound system is implemented.

Screenshots are controlled automated visual checks, not reference-game comparisons or a complete physical-device usability review. The full gameplay loop was verified with real Jolt headlessly. No original-game runtime trace comparison or full 234-action visual correctness claim is made.

## Profiling

Each gameplay JSON report includes callback CPU summaries. The main arena measurement covers player movement/camera/weapon/transition orchestration and presentation refresh, excluding independent NPC callbacks, Jolt solving, UI drawing and GPU work. Vehicle telemetry covers its four wheel-query/force calculations. presentation_results.json additionally samples one player's SkinnedMotionVisual.sample_pose CPU time over 180 frames, explicitly excluding other actors, physics and rendering. These are narrow shared-environment measurements, not complete frame budgets.

The software-OpenGL captures are not a target-hardware performance benchmark. Adaptive scaling uses sustained frame-time feedback, not a GPU timer; no before/after speedup is claimed. No performance superiority is asserted. Gameplay, visual and performance parity remain separate open validation goals.

## Remaining checks

Reference runtime captures/tolerances, complete blending/IK/action coverage, full vehicle handling calibration, original wheel geometry, doors/passengers, seated driver presentation, camera comfort and real-device input/readability still require work. See DISCREPANCIES.md and MODEL_AND_DISPLAY_MILESTONE.md.
