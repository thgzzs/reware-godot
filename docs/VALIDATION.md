# Current source validation

Godot **4.7.2 Stable**, official ed1daf0bf, built-in Jolt, physics 60 Hz. The official release was rechecked as stable and its downloaded Linux archive matched SHA-256 cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4. No engine substitution was used.

| Current suite | Passed | Scope |
| --- | ---: | --- |
| Baseline | 47 | Real Jolt with authored primitive geometry; move/jump/fire/drive/brake/exit and repeated cycles |
| Synthetic action/door/impact | 41 | Authored animation channels and real Jolt; masks, reactions, doors and mounting stages |
| Sprint/approach/settling | 42 | Tap cap/continuity, collision-driven walk-in/chassis routes, cancellation, settled orientation/get-up, physical fall damage and bike rear-release selection |
| GDScript parsing | 106 | All other project scripts loaded by check_project_scripts.gd, including asset-dependent test scripts |
| Python | 14 passed, 9 skipped | 23 discovered; private-file conversion fixtures skip because supplied assets are absent |

**130 current Godot/Jolt assertions passed.** See tests/intent_revision_results.json, latest_results.json, revision_results.json, intent_validation_transcript.txt and intent_python_transcript.txt. Earlier native reports/transcripts are historical; they do not describe a rerun of this revision.

## Current measurements

The linear synthetic sprint clip travels at 6.0 m/s. Repeated tapping retains the same sprint clip, never enters stop/start and reaches 7.2 m/s at the 1.20 cap. Holding produces no tap bonus. The walk-in fixture travels approximately 0.89 m through the motor with maximum tick displacement 0.025 m, then opens/mounts. Front-of-car requests route around a chassis corner. New obstacles and lost/dead/destroyed participants cancel without stale occupancy.

The primitive baseline orchestration callback sampled 3496 ticks: mean 85.2 us, p95 155.0 us. These shared-environment CPU samples exclude Jolt solving and rendering. They are not a full frame budget, native-animation benchmark or demonstrated speedup. Planning work is bounded and happens at request time; no comparative performance claim is made.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable
Godot_4.7.2_stable --headless --path . --script res://tools/check_project_scripts.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator rejects other engines, imports first and only selects asset-dependent suites when their inputs exist. Transition tests explicitly wait for approach completion before measuring animation-stage duration. Zip packaging uses explicit parent directories, CRC and SHA manifests; the source package is checked again through a fresh import/startup.

## Historical native evidence and pending checks

The previous asset-inclusive release passed 483 Godot/Jolt assertions, 23 Python tests and five local render-rate comparisons. Its converted artwork and animation library were removed from the local workspace by maintenance and are absent from public git. Current access does not provide a way to recover those file bytes.

Consequently the native asset suites, native sprint gait review, prone/supine terminal skin alignment, all four bike rear-dismount visuals and native render-rate replay remain **pending for this revision**. They require overlaying this source onto the previous asset-inclusive build. No new asset conversion was performed. This source ZIP does not replace the earlier asset-inclusive ZIP. Native gameplay parity, original executable comparison, browser playback and hardware GPU performance remain unverified.

See SPRINT_ENTRY_SETTLING.md for implementation, tuning, confirmed reference behavior and current limits.
