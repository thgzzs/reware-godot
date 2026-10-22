# Current validation

Godot **4.7.2 Stable**, official `ed1daf0bf`, built-in **Jolt Physics**, fixed 60 Hz. The downloaded official archive SHA-256 was verified against its release digest. Engine/API sources remain pinned in provenance.json.

| Current revision | Result | Scope |
| --- | --- | --- |
| Editor import / script parsing | Passed | Exact 4.7.2 editor |
| Existing gameplay suite | 48 passed | Real Jolt, primitive fallback |
| Action/door/impact revision suite | 41 passed | Real Jolt plus synthetic animation library and seven-bone skeleton |
| Python tests | 14 passed, 9 skipped | ZIP, parser, converter fixtures; private input tests skipped |
| Strict ZIP extraction regression | Passed | 217-file fixture with missing original directory entries, byte-preserving repair, parent directories written before files |
| Original converted model/animation suites | Not rerun | Private asset-inclusive build ZIP unavailable in this workspace |
| Browser import / exported HTML | Not run | ZIP layout fix validated through a strict extraction simulation |
| New rendered visual checks | Not run | No display server or private source assets available |

New checks cover phase-matched walk/run blending, preserved leg motion under aiming, action crossfades, simultaneous aim/walk/fire, reload blending, every equipped gun sprinting, one-shot death/respawn, per-slot ammunition and reload/cooldown policy, opening/closing both physical door hinges, source clip stages and contact delay, continuous entry/exit, ownership cancellation on death, swept pedestrian impacts, bounded reactions, fatal/nonfatal outcomes and clearance-gated get-up.

Reports: tests/latest_results.json and tests/revision_results.json. The revision transcript is tests/revision_validation_transcript.txt. Source findings and remaining visual/calibration gaps are in REVISION_SOURCE_REVIEW.md.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The validator rejects other engines, imports before testing and fails on script errors. Imported suites run only if their private assets are present. Historical imported_results.json, presentation_results.json, independent_decoder_results.json and older transcripts are retained as prior-milestone evidence; they do not validate the new pose layering or door/model attachment.

## Profiling

Current per-callback samples are recorded in the two JSON reports. Gameplay orchestration excludes independent NPC/probe/door callbacks, Jolt solving, UI drawing and rendering. Vehicle force samples cover the four wheel queries and force calculations. The synthetic pose sample covers seven bones in a death pose, excludes the actual 25-frame native skin, rendering and Jolt, and must not be treated as the cost of the real asset build.

Latest diagnostic samples (microseconds):

| Callback | Samples | Mean | p95 |
| --- | ---: | ---: | ---: |
| Arena orchestration | 3488 | 51.6 | 117.0 |
| Four-wheel query/force calculation | 3488 | 34.9 | 48.0 |
| Seven-bone synthetic death pose | 180 | 23.1 | 48.0 |

No before/after speedup or complete frame budget is claimed. Measurements from the shared headless environment are diagnostic baselines. Target GPU/browser/device measurements, original-game runtime traces, gameplay parity, visual parity and performance parity remain separate open validation goals.

## Prior milestone evidence

Before this revision, the private build recorded 36 imported-animation assertions, 28 model/display assertions, 87,546 independently decoded source keys with no mismatch, 95,427 native channel keys within tolerance and six software-OpenGL captures. These are historical conversion and layout checks. Those assets and images have not been regenerated. Once the existing ZIP is supplied, overlay the revised source with rebuild_test_build.py and rerun the imported and model suites plus visual checks.
