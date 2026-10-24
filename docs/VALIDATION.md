# Validation / combat and driving revision

Exactly Godot **4.7.2 Stable**, official ed1daf0bf, built-in **Jolt Physics**, fixed simulation 60 Hz. Current reports pass **645 assertions across 15 suites**. The complete 644-check batch passed; a final stationary-hit root-translation correction then passed the expanded 42-check native revision suite. All **123** other GDScript files compile/instantiate in the script check. All **23 Python tests** pass.

| Suite | Assertions |
| --- | ---: |
| Core gameplay | 47 |
| Earlier regressions | 41 |
| Sprint / transitions / settling | 42 |
| Touch input | 34 |
| Imported data / movement | 37 |
| Presentation | 28 |
| Native action ownership | 66 |
| Motion and impacts | 63 |
| Props / stance / glass / tires / damage | 54 |
| Units and ownership | 13 |
| Native entry / resting / recovery | 43 |
| Stories assets | 10 |
| Combat / panels / handling / bikes | 77 |
| Falling / moving melee | 48 |
| Combat / landing / bike revision | 42 |

The new 42-check native suite includes actual low-drop movement, directional hits and stagger, one presentation update per simulation tick, gradual sprint blending, five rifle/shotgun aim variants, legacy crouch, seven moving punch requests, query-only corpse retirement, an actual floor-kick sweep, downward bat selection, door range/run-in/occupancy/pelvis alignment, bonnet damage in a real wall contact, bike falling/pickup/cancellation, walking reverse and crash ejection with inherited motion.

## Measured behavior

- Soft-drop fixture: visible landing motion continues; no hard-landing movement lock. Hard/unsafe impacts retain recovery and environmental damage.
- Native pose sampler: **30 calls over 30 simulation ticks** in the idle fixture. Presentation fallback skips a pose already sampled by the simulation, so blend clocks do not advance twice. This is an update-ownership check, not an FPS claim.
- Idle corpse fixtures retire solid physics only after supported quiet rest and visual floor alignment. Prone/supine skins clear the flat floor; floor-hit queries remain active.
- Final car acceleration fixture reaches 10 m/s in **1.267 s**. The high-speed steering fixture records minimum chassis-up dot **0.9998**. These are target measurements, not original-runtime parity.
- Bike reverse approaches **0.91 m/s** with the native pushes clip. The crash fixture records peak transferred rider speed above 8 m/s and the bike fall clip before quiet terminal settling.
- Native repeated sprint tapping keeps its gait across all 300 sampled ticks. Current measurements are in native_intent_results.json; raw animation root curves vary within each stride and are not constant-speed caps.

## Timing and profiling

The native fixed-command playback was rerun at 30/60/120/144 and a varying render cap while physics stays at 60 Hz. All five comparisons pass for sampled positions, velocity, vehicle position, pose quaternion, shots and state, with tolerance 0.002. See render_timing_results.json. This local CPU fixture does not establish cross-platform determinism or GPU throughput.

Current Stories orchestration callback: mean **854.6 microseconds**, p95 **2276.0 microseconds**, maximum **54487.0 microseconds**, 3600 samples. It excludes Jolt solving and rendering and includes environment noise. Different milestone workloads cannot support a comparative speedup claim. No speculative FPS improvement is asserted.

## Visual review

Nine selected poses were rendered with the Compatibility renderer and Mesa llvmpipe: M4 aim, shotgun aim, legacy crouch, directional hit, soft landing, unarmed ground kick, downward bat attack, bike pickup and walking reverse. Repeatable script: tests/render_behavior_preview.gd. These are desktop software renders, not Android screenshots or complete temporal/contact validation.

## Android and project package

Version **0.4-behavior-test**, code **4**, package **org.reware.harbor**, minimum API **24**, target API **36**, ARM64 + ARMv7. The release-engine APK retains the prior test signing identity. Signature, archive CRC, 16 KiB ZIP alignment, 16 KiB ARM64 ELF load alignment, native Jolt and all 32 selected model scenes pass. A clean extraction of the final APK payload loads 1168 animation entries, 24 weapons, four pedestrians, seven vehicles, the legacy crouch override, two-seat Idaho and mobile controls in the exact desktop engine.

The complete ZIP retains explicit parent directories, a full SHA256 manifest, selected assets and the test signing key. The 315 original selected asset/support payloads remain byte-identical; one legacy crouch Resource was added from the existing decoded source. The public source repository excludes private assets, native previews and signing material. Fresh ZIP extraction/import/startup is checked separately during packaging.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable
Godot_4.7.2_stable --headless --path . --script res://tools/check_project_scripts.gd
python3 tools/check_render_timing.py --godot /absolute/path/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Run tests/render_behavior_preview.gd with a graphical display to recreate the selected poses. The validator refuses other engine versions and enables native suites only when their private inputs are present. Reports and behavior_validation_transcript.txt describe this milestone; earlier named transcripts are historical.

## Remaining gaps

No original executable traces or Android device/emulator were available. Android Java/JNI/GPU execution, installation, lifecycle/insets/thermals, uneven-ground edge cases, every asset/pose/contact combination, articulated ragdolls, full browser runtime, full open-world simulation and behavioral/visual/performance equivalence remain unverified. See COMBAT_DRIVING_REVISION.md and DISCREPANCIES.md. The tests establish a playable target implementation, not full reVC parity.
