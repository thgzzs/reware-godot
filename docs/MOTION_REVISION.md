# Motion, seating, aiming and Jolt contact revision

The reported freezes and pass-through contacts had implementation causes. This revision corrects ownership and adds temporal observations of the actual imported skin. It retains Godot 4.7.2 Stable, Jolt, the supplied asset bytes, the shared player/NPC motor and plain arena surfaces.

## Findings and changes

| Report | Cause found in the target project | Result |
| --- | --- | --- |
| Wheels appear static | Only the rubber mesh rotated; the visible hub was its sibling, and the local spin axis was incorrect | Each independent wheel now has a suspension/steering parent and one X-axis spin pivot carrying rubber and hub. Relative tire contact velocity drives the spin; reverse reverses it. Every vehicle owns its update. |
| Run-to-jump freezes | force_action changed the selected clip while phase remained `move`; pose_layers continued sampling frozen walk/run cycle values | Exclusive full-body actions claim their pose channel. Launch/glide/land replace locomotion. The 133 ms launch gets a 40 ms crossfade. |
| Sprint/action conflicts | Upper weapon actions could still claim the arms during sprint/jump; crossfade snapshots could include previous IK | Explicit upper-channel eligibility, separate base/upper snapshots before IK and one fixed player pose sample. All equipped guns permit sprinting; aim/fire/reload requests take priority over sprint. Pure sprint already moved in the simple reproduction; action combinations and actual bone motion now have tests. |
| Off-center gun | Actor used previous camera look/pitch, camera ray advanced later, IK used only local pitch | Read look before movement. Solve the current camera-center ray in world space and converge the hand/gun axis on its target, including shoulder parallax and actor heading. Preserve the muzzle-to-target occlusion ray. |
| Reload/fire overrides | Weapon selection/reload advanced after actor actions; hardcoded arm targets and repeated pose sampling | Weapon state advances once before actor actions, then pose, then firing. WeaponPoseProfile separates reach, recoil, reload-hand trajectory and support grip from ballistics. Original gun blocks remain optional. |
| Incorrect/invisible seated driver | Occupant was hidden and capsule origin was placed at a pelvis marker | Visible CAR_sit pose, pelvis-to-seat anchoring, per-car marker adjustment and car-relative orientation. One pelvis path during get-in/out avoids applying animated vertical root displacement twice. |
| Door closure lags transition | Motor speed/strength could not close through the source contact window | Resource-controlled motor speed, impulse and gain adjusted; closure/latching and both door directions tested. Physical obstruction can still prevent closure. |
| Immediate pedestrian death and car pass-through | A high quadratic damage coefficient, low kinematic sphere, world-only collision and vehicle exception | Reusable 75 kg Jolt torso takes sole collision/motion ownership. CCD and solid car/bonnet contact provide support and push. Reduced-mass transfer, bounded lift and opposite car impulse replace the kinematic slide. Moderate hits can knock down and recover; high-speed hits can kill. |

## Source Confirmed

Pinned reference: [reVC a26fff4af555a8a425ac9f17d1dd718d00d1f942](https://github.com/mrxenginner/reVC/tree/a26fff4af555a8a425ac9f17d1dd718d00d1f942).

`CPed::KillPedWithCar` in [PedFight.cpp](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PedFight.cpp#L3624) distinguishes falling/dead/upright actors, impact direction and severity. Some branches inherit car motion; the bonnet branch uses vehicle height and estimated time across its length to produce upward movement. The vehicle receives an opposing response. These observations motivate state-dependent reaction, momentum exchange, lift and continuing contact. Legacy impulse/timestep units are not directly converted into SI thresholds here.

The earlier source review documents phase-dependent locomotion/stops, partial weapon channels, separate gun blocks and door contact timing. The source intentionally restricts some heavy-weapon sprinting; the user's all-gun sprint request remains an explicit target option. No reference C++ is copied or shipped.

The target uses documented [Godot 4.7 RigidBody3D](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html) and [built-in Jolt](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html) APIs. A top-level torso body is positioned only at ownership transfer; normal motion comes from Jolt forces and contacts. No unsupported joint soft limits or contact impulse damage estimates are used.

## Runtime Confirmed

These observations concern the target runtime, not the original executable:

- Actual thigh orientation changes by about 1.13 radians over ten sprint ticks in each weapon slot. Ordinary run-to-jump exposes launch/glide/landing poses and approximately 1.12 m capsule rise; movement layers do not mask them.
- Gun-hand world axes converge on the camera-center target at three pitches while moving. Reload changes hand position without stopping the legs. Native gun-specific IFP blocks are absent, so these are procedural presentation checks.
- Driver pelvis error is below 1 mm in the fixture. Calf/foot/head bones remain within tested cabin bounds, and the door latches after entry. The mirror was verified separately with the driver hidden; it is original car geometry.
- Visible hub rotation changes during forward travel and reverses during reverse. This is visual rolling, not a simulation of wheel inertia or tire deformation.
- A nominal 10 m/s approach leaves the pedestrian at approximately 79 health, produces about 1.01 m torso lift and over 200 reported vehicle contact points across the sequence. The torso travels with/contacting the car, then safely returns to standing after braking. Contact counts are observations of this fixture, not deterministic guarantees across platforms.
- All 198 Godot/Jolt assertions and 23 Python tests pass. Rendered motion frames cover sprint, jump, aim/reload, occupied seat and three bonnet-impact stages. Previous native death and door regressions also pass.

Run `python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable`. It automatically includes tests/run_motion_suite.gd when private native assets are present. Run that same scene-tree script with a graphical display to generate diagnostic motion captures. Reports and callback-only profiling are in tests/motion_results.json and docs/VALIDATION.md.

## Inferred and remaining

Impact damage, lift, mass, cabin offsets, motor strength and arm trajectories are target tuning. They require original-runtime traces and more vehicle/rig fixtures for calibration. A rigid torso with animated articulation can rotate and ride the bonnet; limbs do not have individual physical collision. This is not a full ragdoll. A second vehicle can physically push an active torso, but additional damage from those later contacts is not yet modeled. Gun deaths retain the existing grounded terminal-animation path.

Original Colt/rifle/shotgun IFP blocks are still required for authentic fire/reload poses. Current fallbacks do not animate removable magazines or moving weapon parts. Steering-wheel/door hand IK, complete directional aim locomotion, foot planting, all-body mesh clearance, alternate seats, passengers, damaged doors, traffic/crowd behavior, full world systems and parity remain open. Browser playback and GPU/full-frame performance are unverified.

No performance speedup is claimed. The controlled player pose moved into the orchestration callback, so its new timing includes work previously measured separately. The impact body is created once per actor and reused; full memory/crowd profiling remains future work.

## Delivery

See MILESTONES.md for created/modified files. The public repository contains framework source and tests. The private ZIP overlays those files on the user's original archive and preserves all 91 private asset/support files byte for byte. It includes explicit parent directory entries, a full file hash manifest and the exact-version setup/testing instructions. No asset conversion or full IMG extraction occurs.
