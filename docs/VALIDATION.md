# Current validation

Godot **4.7.2 Stable**, official `ed1daf0bf`, built-in **Jolt Physics**, fixed 60 Hz. The official engine archive digest is pinned in provenance.json.

| Suite | Current result | Scope |
| --- | --- | --- |
| Editor import / script parsing | Passed | Exact 4.7.2 editor |
| Baseline gameplay | 48 passed | Real Jolt, primitive fallback |
| Action/door/impact contracts | 41 passed | Real Jolt and synthetic animation fixtures |
| Imported animation/data | 36 passed | Retained source clips/data, 234 clips, complete native key round trip |
| Native model/display | 28 passed | Real skin, model markers, responsive HUD, display/input/adaptive controls |
| Native actions | 24 passed | Aim mask/pitch, all-gun sprint, model selection, death floor/hold, physical doors, staged entry/exit and weapon holstering |
| Temporal native motion | 21 passed | Actual moving thigh poses, run-jump phases, world aim convergence, reload motion, cabin/seat fit, wheel reversal, physical contact/lift and recovery |
| Python | 23 passed, none skipped | Parser, conversion, selected archive and packaging fixtures |
| Rendered review | Temporal motion + prior 11 captures | Sprint frames, jump, aim/reload, occupied/corrected seat and bonnet-impact sequence; software OpenGL |
| Strict ZIP extraction | Passed | Parent entries before files; CRC and byte checks; fresh editor import/startup |
| Original-game runtime / browser playback | Not tested | No gameplay equivalence or HTML runtime claim |

Total: **198 Godot/Jolt assertions**, plus **23 Python tests**. All 91 original private asset/support files are retained byte for byte; no assets were reconverted or re-extracted from IMG. The input ZIP contained 217 files and zero directory entries.

The native death check originally measured a minimum 13 cm below the floor. The visual now caches a terminal skin minimum and blends a capped correction to 1 cm above the test floor. Collision ownership stays with the actor. Native aim checks preserve leg rotation and verify hand orientation at three pitch values. Door tests confirm attachment, opposite opening directions and latching. The final exit restores both standing collision/control and the equipped visual.

Reports are tests/latest_results.json, revision_results.json, imported_results.json, presentation_results.json, native_action_results.json and motion_results.json. Current full transcripts are motion_validation_transcript.txt and motion_python_transcript.txt. Older revision-only transcripts record the earlier source-only run and are historical. Prior screenshots in the supplied ZIP are retained unchanged; current captures were inspected separately.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator rejects other engines, imports before testing and fails on script errors. Asset-dependent suites run only when private assets are available. On a desktop with a working display, use tests/render_model_preview.gd for layout captures and tests/render_action_preview.gd for selected native action captures. Run tests/run_motion_suite.gd with a graphical display to capture the temporal regression sequence; it also runs headlessly without image output.

## Profiling

| Callback | Samples | Mean, us | p95, us |
| --- | ---: | ---: | ---: |
| Native motion orchestration, including player pose | 1794 | 239.5 | 359.0 |
| Four-wheel query/force calculation | 2489 | 41.8 | 75.0 |
| Native player pose sampler | 180 | 140.0 | 225.0 |

These shared-environment samples cover only the named callbacks. The current orchestration includes the fixed player pose; it is not directly comparable to the previous orchestration samples that excluded pose evaluation. Orchestration excludes independent NPC/probe/door callbacks, Jolt solving, HUD drawing and rendering. The pose sample excludes other actors and GPU skinning. The terminal skin minimum is computed once per settled reaction clip and cached; a cold computation is not represented by steady pose timing. No speedup, complete frame budget or performance superiority is claimed.

Software-OpenGL captures use Mesa llvmpipe rather than a physical GPU. Full foot/door contacts across every action, target-device usability, original-game traces, browser import/playback, gameplay parity, visual parity and performance parity remain separate validation goals.

Current motion renders show different sprint frames, airborne jump, aim/reload, occupied seating and three stages of a bonnet impact. A later cabin correction render verifies closing/latching. The apparent object protruding at the front of the driver door is the original car mirror; an empty-car control capture confirms it. Bone positions also remain inside the cabin. These are selected target checks, not exhaustive mesh penetration or reference-runtime parity tests.
