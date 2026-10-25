# Respawn, steering and bike lean / Build 7

Targets exactly Godot 4.7.2 Stable and Jolt Physics. Version 0.5.1-recovery7, Android code 7, launcher Harbor Rev 7, visible HUD BUILD 7. The package and private test signing key are retained so this update installs over the preceding revision.

## Implemented

Pedestrians reuse their CharacterMotor after an eight-second death delay. ActorSpawnRecovery owns the countdown and spawn policy separately from the decision-making brain, health, animation and motor. Respawn clears dead/reaction/corpse state, weapon recovery timers, vehicle collision exceptions and combat pursuit. Each pedestrian returns to its captured spawn mark with its initial heading and resumes wandering through the same PedBrain. The player still uses manual respawn after ordinary death.

Actors below -15 meters return immediately, including dead or physically falling actors. Player recovery cancels entry, seating, bailout or bike lifting and releases reservations, balancing and control ownership before restoring the shared character. Cars and bikes also return to their own captured spawn position when below the same threshold. Vehicle damage is retained. Spawn placement checks standing clearance and a walkable floor, trying nearby rings when the mark is blocked. If all candidates are blocked it retries after half a second instead of overlapping geometry. It rejects surfaces more than 0.6 meters above or below the spawn floor.

Player ground turning is twenty percent quicker. AI profiles remain unchanged. Speed-dependent steering, reversal braking, native spatial locomotion and locked airborne/landing heading remain in force. The multiplier is a Resource property, not a hardcoded input or character identity check in the motor.

The bike's roll controller previously cancelled only suspension contact torque. Actual Jolt tests showed outward banking under cornering because the remaining tire force acted below the center of mass. WheelForceSolver now reports the total force it actually applies, and authorized rider/standing/lifting balance compensates its roll moment. Steering still owns the desired lean and the physical PD controller approaches it; steering release returns that target to zero. Fallen bikes bypass the controller and retain physical side-rest and pickup behavior. No transforms are snapped to impose a lean.

## Validation and scope

Run `python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable` for all suites, including tests/run_recovery_suite.gd. Its seventeen assertions cover respawn timing, actor reuse, health/life/collision restoration, threat reset, both living/dead void recovery, blocked spawns, player and mounted void recovery, vehicle spawn recovery, unchanged AI steering and actual left/right Jolt banking and return to upright.

In isolated nine-meter-per-second cornering, average lean tracking error is about 0.040 radians; both directions retain their rider. After three seconds without steering, residual bank is below 0.002 radians. These are repeatable target-engine checks, not original-game runtime parity or Android hardware measurements. The eight-second policy and twenty-percent response increase are target tuning choices. No optimization or original-runtime equivalence is claimed.

## Files

Created: actors/spawn_profile.gd, actors/spawn_recovery.gd, tuning/spawn.tres, tests/run_recovery_suite.gd and this document (plus generated Godot UID files and test report).

Modified: actors/character_motor.gd, actors/ped_brain.gd, world/arena.gd, interaction/vehicle_transition.gd, driving/vehicle.gd, driving/wheel_solver.gd, driving/bike_dynamics.gd, tuning/movement_profile.gd, tools/validate.py, tools/check_android_payload.gd, project.godot, export_presets.cfg, README.md and validation documentation.

All supplied private model, texture and animation payloads are retained. No new assets or reference source code are included. Future work includes Android device validation, articulated ragdolls and original-runtime comparison captures.
