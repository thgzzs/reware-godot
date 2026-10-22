# Discrepancies and remaining scope

The current test build includes selected original placeholders, real skin/bind data, shared pedestrians, 234 animations, responsive HUD/UI and independent render/interface scaling. Model and basic layout checks pass; full reference gameplay, visual and performance parity remain unverified. See MODEL_AND_DISPLAY_MILESTONE.md for the completed import/display scope.

| Area | Delivered | Gap / evidence needed | Priority |
| --- | --- | --- | --- |
| Reference baseline | Immutable commit and bounded source register | Reference executable/config, game data, runtime traces and agreed acceptance tolerances | P0 |
| Locomotion | Custom acceleration, turning, aim/sprint modifiers, buffered windup jump, landing, sweeps, low steps and slope rejection | Match animation/root motion, ledge policy, friction, sprint stamina, air steering and exact timings | P0 |
| Animation | 234 native clips, original selected character skin/rig, absolute bone playback | Full locomotion/action blends, aim IK, root policy calibration, doors and seated driver presentation | P0 |
| Camera | Follow/aim/driving presets, orbit, lag, FOV, sphere obstruction | Reference mode coverage, embedded-pivot recovery, vehicle auto-centering and artistic validation | P1 |
| Weapons | One hitscan type, ammo, reload, spread, recoil, damage and resettable targets | Switching/loadout, melee/projectiles, per-type logic, recoil calibration, penetration, audio and IK | P1 |
| Vehicle physics | Four contacts, spring/damper, combined traction limit, steering, braking/reverse, body collision and COM | Reference transmission, wheel inertia, tire relaxation, wheel-volume casts, surface handling, anti-roll/anti-dive and calibrated impact response | P0 |
| Vehicle transitions | Reserved driver seat, timers, control/collision transfer, supported exit alternatives, commit-time revalidation | Only one driver seat; no passengers, jacking, doors/locks, jump-outs, model-specific animations or ragdolls; 0.1 s vehicle collision grace | P0 |
| AI/pedestrians | Four route/flee NPCs sharing motor/health/weapon/presentation with the player | Full archetype decisions, state policies, crowd avoidance, navigation and traffic | P1 |
| Open world | Self-contained collision test yard and vehicle discovery boundary | Streaming, persistence/save-load, missions, districts, traffic, population, spatial indexing and floating origin | P1 |
| Mod/multiplayer | Resource configs, instance state and command boundaries | No loader, protocol, authority, replication, prediction or sandboxing | P2 |
| Debugging | State, motion, timings, loads/contact markers; Godot collision visibility | Persistent trace recorder, replay UI, force-vector overlays and automated capture comparison | P1 |
| Visual parity | Four original model roots, 25 textures, real skin binding and six rendered software-OpenGL captures | Reference visual comparisons, physical-device usability/accessibility and full blend/vehicle art behavior | P1 |
| Performance parity | Headless per-module CPU samples with scope labels | Target hardware/GPU runs, reference measurements, crowds/streaming loads, memory and hitch budgets | P1 |


The custom physics coefficients and behavior acceptance bounds remain prototype values. Actual meshes do not establish physical equivalence. The selected car uses original axle markers, an approximate body hull and procedural textured wheels; full wheel geometry, door action and seated driver presentation remain open. The rendered checks use software OpenGL in a virtual window server, not a full physical-device usability review.
