# Validation and profiling

Verified 2026-10-22 with **Godot 4.7.2 Stable**, official engine hash `ed1daf0bf001b61586d9930840f2f1394092c079`, built-in **Jolt Physics**, 60 Hz fixed simulation and headless display. The portable Python validator completed editor import and the integration suite: **48 assertions, 0 failures**. Raw measurements and individual outcomes are in `tests/latest_results.json`.

## Automated coverage

The suite instantiates production scenes and runs real Jolt simulation. Command injection exercises movement acceleration/distance/deceleration, camera-relative movement, aim speed/FOV, jump windup/apex/landing/buffering, wall and ceiling collision, stair traversal, walkable/steep slopes, camera sweep retraction, hitscan damage, cadence, ammo conservation/reload, suspension equilibrium, reserved-seat exclusivity, entry/exit timings, moving-exit rejection, driving acceleration/steering/braking/reverse, blocked exits, late blockers, repeated enter/exit cycles, resumed foot/weapon control, post-exit body stability, world-translation invariance and vehicle collision with a wall.

These checks establish prototype acceptance and protect fixes. They do not compare against a reference runtime. The suite is a sequential integration scenario with checks at each stage, not isolated unit tests. Read the earliest failure first. It uses a fixed seed and zero spread/recoil for cadence/damage isolation; shipped defaults remain nonzero. Its runtime changes affect only the test instance.

## Selected measurements

| Prototype metric | Measured |
| --- | --- |
| Movement after acceleration | 5.0 m/s |
| Aim movement speed | 2.5 m/s |
| Jump launch from request sample | 0.150 s |
| Jump apex above starting position | 1.121 m |
| Sampled airborne duration | 0.667 s |
| Weapon inter-shot spacing | 12 physics ticks / 0.20 s |
| Vehicle speed after 2.5 s throttle | 12.566 m/s |
| Vehicle distance in that acceleration run | 16.398 m |
| Braking initial speed | 13.157 m/s |
| Braking path endpoint distance | 8.858 m |
| Braking time to test stop threshold | 1.300 s |
| Total settled wheel normal load | 11772.0 N |
| Vehicle static weight | 11772 N |

Jump/transition times include fixed-tick scheduling and sample boundaries. Braking measurement follows the steering scenario, so it includes a nonstraight trajectory and reports endpoint displacement, not arc length. It must not be presented as a reference straight-line braking-distance measurement.

## CPU baseline

| Scope | Samples | Mean | p95 | Maximum |
| --- | --- | --- | --- | --- |
| Gameplay orchestration, motor, camera, weapon and presentation update | 3488 | 44.71 μs | 110 μs | 417 μs |
| Main vehicle four-wheel query/force callback | 3488 | 35.47 μs | 64 μs | 277 μs |

These are wall-clock CPU samples from one shared execution environment, not controlled hardware benchmarks. The ring contains at most 3600 samples per scope. The vehicle row covers the main car, not the extra crash-test car. Jolt contact solving, renderer, GPU time, input latency, streaming and crowded-world load are excluded. Instrumentation overhead is included. The instantaneous engine physics monitor is retained only as raw context; it is not a p95 physics budget.

No performance improvement over reVC is claimed. No optimization A/B experiment was conducted. Fixing an incorrect point-velocity coordinate transform was a correctness change, not a measured optimization. Measure actual target hardware first; then choose one bottleneck, compare the same recorded workload and verify behavioral parity before accepting an optimization.

## Reproduce

```bash
python3 tools/validate.py --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
```

The tool refuses a different engine and fails on script errors, nonzero engine exits or failed assertions. It regenerates the report. No editor cache is included in the archive; import creates it. A passing report from a different engine is not acceptable. Sandbox execution emitted `/proc/self/exe` path-resolution warnings; the final import and suite still exited successfully with no script errors. The engine was freshly extracted for each launch in this environment because the executable did not remain intact between launches; this is an execution-environment limitation, not part of the project or its setup requirements.

## Required desktop/manual checks

These are outstanding, not passed:

1. Run the exact editor, move/aim/sprint/jump on the fixtures and inspect animation-free movement/camera comfort at 30, 60 and 144 render FPS.
2. Shoot every target, empty a magazine, reload, verify target reset and try shooting close to walls and over cover.
3. Drive, brake/reverse, collide at low/high speed, enter/exit repeatedly; block one exit, all exits and an exit during the transition.
4. Press F3 to inspect state, velocity, step/impact readings, wheel loads/contact markers and callback timings. Enable **Debug > Visible Collision Shapes** and use the Godot debugger/profiler for collision/physics diagnostics.
5. Collect CPU/GPU frame time, physics solve time, memory, hitch and instance counts on target hardware. Stress with additional vehicle/character instances before setting budgets.
6. Obtain reference runtime traces, record build flags/data and apply the calibration gates in PHYSICS_MIGRATION.md.

Gameplay parity, visual parity and performance parity remain separate open evaluations. The headless suite confirms only the implemented target behavior above.
