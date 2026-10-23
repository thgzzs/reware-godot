# Current validation

Godot **4.7.2 Stable**, official `ed1daf0bf`, built-in **Jolt Physics**, fixed 60 Hz. The official engine archive digest is pinned in provenance.json.

| Suite | Current result | Scope |
| --- | --- | --- |
| Editor import / script parsing | Passed | Exact 4.7.2 editor |
| Baseline gameplay | 48 passed | Real Jolt, primitive fallback |
| Action/door/impact contracts | 41 passed | Real Jolt and synthetic animation fixtures |
| Imported animation/data | 36 passed | Retained source clips/data, 234 clips, complete native key round trip |
| Native model/display | 28 passed | Real skin, model markers, responsive HUD, display/input/adaptive controls |
| Native actions | 22 passed | Aim masks, supported model inventory, death, doors, transition and holstering |
| Temporal native motion | 19 passed | Moving poses, aiming, reload, seat, wheels, physical impact and recovery |
| Systems | 53 passed | Props, tire/glass rays, stance/fire restrictions, cameras, seats, melee, rotated collision damage, fire/explosion/repair |
| Foundations | 13 passed | State-specific jump speed, slopes, heavy-car pushes, fresh/resting/severe subsequent ped impacts |
| Python | 23 passed, none skipped | Parser, conversion, selected archive and packaging fixtures |
| Render timing | Five comparisons | Fixed render deltas 30/60/120/144 plus real-clock varying render cap; fixed physics60 |
| Rendered review | Eight systems states plus previous motion sequence | Software OpenGL; selected appearance checks |
| Strict ZIP extraction | Passed | Explicit parent entries, CRC/SHA verification, preserved private bytes and fresh import/startup |
| Original-game runtime / browser playback | Not tested | No gameplay equivalence or exported HTML runtime claim |

Total: **260 Godot/Jolt assertions**, **23 Python tests** and **five local render-rate comparisons**. Native assertion counts changed because absent rifle/shotgun meshes are now correctly excluded rather than represented by another model. All 91 original private asset/support files are retained byte for byte. The original input had 217 files and zero directory entries.

The native death check originally measured a minimum 13 cm below the floor. The visual now caches a terminal skin minimum and blends a capped correction to 1 cm above the test floor. Collision ownership stays with the actor. Native aim checks preserve leg rotation and verify hand orientation at three pitch values. Door tests confirm attachment, opposite opening directions and latching. The final exit restores both standing collision/control and the equipped visual.

Reports are tests/latest_results.json, revision_results.json, imported_results.json, presentation_results.json, native_action_results.json and motion_results.json. Current full transcripts are systems_validation_transcript.txt and systems_python_transcript.txt. Additional reports: systems_results.json, foundation_results.json and render_timing_results.json. Older revision-only transcripts record the earlier source-only run and are historical. Prior screenshots in the supplied ZIP are retained unchanged; current captures were inspected separately.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 tools/check_render_timing.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator rejects other engines, imports before testing and fails on script errors. Asset-dependent suites run only when private assets are available. On a desktop with a working display, use tests/render_model_preview.gd for layout captures and tests/render_action_preview.gd for selected native action captures. Run tests/run_motion_suite.gd with a graphical display to capture the temporal regression sequence; it also runs headlessly without image output.

## Profiling

| Callback | Samples | Mean, us | p95, us |
| --- | ---: | ---: | ---: |
| Native orchestration including player pose | 1558 | 916.4 | 2237.0 |
| Four-wheel query/force calculation | 2253 | 142.5 | 469.0 |
| Native player pose sampler | 180 | 498.6 | 1104.0 |

These shared-environment samples cover only the named callbacks. The current orchestration includes the fixed player pose; it is not directly comparable to the previous orchestration samples that excluded pose evaluation. Orchestration excludes independent NPC/probe/door callbacks, Jolt solving, HUD drawing and rendering. The pose sample excludes other actors and GPU skinning. The terminal skin minimum is computed once per settled reaction clip and cached; a cold computation is not represented by steady pose timing. No speedup, complete frame budget or performance superiority is claimed.

Software-OpenGL captures use Mesa llvmpipe rather than a physical GPU. Full foot/door contacts across every action, target-device usability, original-game traces, browser import/playback, gameplay parity, visual parity and performance parity remain separate validation goals.

Current motion renders show different sprint frames, airborne jump, aim/reload, occupied seating and three stages of a bonnet impact. A later cabin correction render verifies closing/latching. The apparent object protruding at the front of the driver door is the original car mirror; an empty-car control capture confirms it. Bone positions also remain inside the cabin. These are selected target checks, not exhaustive mesh penetration or reference-runtime parity tests.

The final five-case replay produced identical player positions/velocities, pose quaternions, shot counts and state names at sampled fixed ticks. Maximum car position difference was 4.24e-7 m. The variable render run observed delta times from 0.001824 to 0.143006 seconds. These measurements cover one controlled local scenario, with 60 Hz physics throughout; they do not validate alternative physics frequencies.

The combined systems render was stopped at its three-minute software-rendering limit after six state captures; remaining fire review uses the isolated render_fire_preview.gd fixture. Earlier variant appearance captures remain valid because fixture geometry was unchanged. The timeout was a render-review harness limit, separate from the eight completed gameplay suites.
