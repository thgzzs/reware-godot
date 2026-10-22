# Discrepancies and remaining scope

No gameplay, visual or performance equivalence to reVC is claimed. This is an original first-playable framework, not a complete open-world game.

| Area | Delivered | Gap / evidence needed | Priority |
| --- | --- | --- | --- |
| Reference baseline | Immutable commit and bounded source register | Reference executable/config, game data, runtime traces and agreed acceptance tolerances | P0 |
| Locomotion | Custom acceleration, turning, aim/sprint modifiers, buffered windup jump, landing, sweeps, low steps and slope rejection | Match animation/root motion, ledge policy, friction, sprint stamina, air steering and exact timings | P0 |
| Animation | Visible primitive avatar; gameplay phases and transition signal | Skeleton, locomotion blends, aim IK, jump launch markers, doors, seated body and entry/exit clips | P0 |
| Camera | Follow/aim/driving presets, orbit, lag, FOV, sphere obstruction | Reference mode coverage, embedded-pivot recovery, vehicle auto-centering and artistic validation | P1 |
| Weapons | One hitscan type, ammo, reload, spread, recoil, damage and resettable targets | Switching/loadout, melee/projectiles, per-type logic, recoil calibration, penetration, audio and IK | P1 |
| Vehicle physics | Four contacts, spring/damper, combined traction limit, steering, braking/reverse, body collision and COM | Reference transmission, wheel inertia, tire relaxation, wheel-volume casts, surface handling, anti-roll/anti-dive and calibrated impact response | P0 |
| Vehicle transitions | Reserved driver seat, timers, control/collision transfer, supported exit alternatives, commit-time revalidation | Only one driver seat; no passengers, jacking, doors/locks, jump-outs, model-specific animations or ragdolls; 0.1 s vehicle collision grace | P0 |
| AI/pedestrians | Reusable character command boundary and initial ped source findings | Actual NPC archetypes, behavior trees/state policies, crowd avoidance, navigation and traffic | P1 |
| Open world | Self-contained collision test yard and vehicle discovery boundary | Streaming, persistence/save-load, missions, districts, traffic, population, spatial indexing and floating origin | P1 |
| Mod/multiplayer | Resource configs, instance state and command boundaries | No loader, protocol, authority, replication, prediction or sandboxing | P2 |
| Debugging | State, motion, timings, loads/contact markers; Godot collision visibility | Persistent trace recorder, replay UI, force-vector overlays and automated capture comparison | P1 |
| Visual parity | Authored primitives only | Original art pipeline, desktop visual QA, accessibility/readability checks and animation; no visual parity testing performed | P1 |
| Performance parity | Headless per-module CPU samples with scope labels | Target hardware/GPU runs, reference measurements, crowds/streaming loads, memory and hitch budgets | P1 |

All five tuning Resources are prototype defaults. None is a measured reference handling/weapon/character preset. Target acceptance bounds validate functioning systems and regression fixes; they are not parity tolerances.

The test environment here supplied no window server, so validation used headless Godot with real Jolt. Rendering, input-device ergonomics, camera comfort and subjective feel still need the manual desktop checks in VALIDATION.md. A successful headless test does not prove those properties.
