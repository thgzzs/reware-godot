# Current discrepancies

See [SYSTEMS_REVISION.md](SYSTEMS_REVISION.md) for delivered behavior and [VALIDATION.md](VALIDATION.md) for evidence. Gameplay, visual and performance parity remain unverified against a running original build.

| Area | Remaining gap |
| --- | --- |
| Authentic expansion assets | Current attachment has player, Idaho, Colt45 and trashcan only. Extra firearms, STINGER/LANDSTAL meshes and weapon-specific IFP blocks are required. Native loadout is Colt45 plus unarmed; extra cars are labeled physics fixtures. |
| Weapon behavior | Procedural fire/reload/crouch layers where clips are absent; no complete projectile/explosive arsenal, per-weapon support-grip calibration, audio or original cadence validation. |
| Characters | Single solid torso reaction proxy, not articulated ragdoll; foot/hand IK and full contact calibration remain. Original clip/root-speed fidelity needs runtime traces. |
| Vehicles | Ray suspension/traction model; no exact transmission, wheel angular inertia, tire relaxation or wheel-volume contact. Damage thresholds have source evidence; response coefficients remain tunable approximations. |
| Seats/doors | Passenger/shuffle transactions work; no jacking, lock policy, jump-outs, breakaway door simulation or complete hand-to-door/steering-wheel IK. |
| Camera | Follow distances, aim, obstruction and bonnet view exist; cinematic and top-down modes and embedded-pivot recovery remain. |
| World/AI | Small test yard and shared route/flee actors; no full traffic, navigation/crowd policies, streaming, save/load, missions or population. |
| Validation | No original executable traces, exported web runtime test, physical-device usability review or GPU/frame-budget parity. Fixed-command local timing checks do not prove network or cross-platform determinism. |
| Extensibility | Resource and command boundaries exist; multiplayer replication and mod loading are not implemented. |

All 91 supplied private asset/support files remain byte-identical in the rebuilt ZIP. Earlier milestone counts describe historical builds.
