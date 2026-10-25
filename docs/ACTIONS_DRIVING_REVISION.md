# Spatial reactions, entry and wreck lifecycle / Build 8

Exactly Godot 4.7.2 Stable (ed1daf0bf), Jolt Physics and a 60 Hz simulation. Version 0.6.0-actions8, Android code 8, launcher Harbor Rev 8 and HUD BUILD 8. This updates the preceding app under the same package and private test signing identity.

## Source Confirmed

Reference commit: a26fff4af555a8a425ac9f17d1dd718d00d1f942 in mrxenginner/reVC. Eight inspected source files and hashes are recorded in actions_source_files.json. This revision reviews movement/action ownership, combat reactions, entry alignment, bike pickup, steering lock, vehicle destruction and wreck cleanup; it does not claim a complete audit or parity of the entire original game.

- AnimManager.cpp explicitly maps semantic left-side bike pickup and pull-up actions to the literal clips BIKE_pickupR and BIKE_pullupR, and right-side actions to L-suffixed names. The earlier target code assumed suffixes denoted the actor's side. Inspection of the supplied skin confirms R clips reach rightward from a left-side actor and L clips reach leftward from a right-side actor.
- PedAI.cpp, PedAnimAlignCB and EnterCar, selects pickup versus pull-up from the bike right-vector height and the entry side. The physical pickup gate is 0.4667 seconds. SetEnterCar_AllClear and EnterCar distinguish final car alignment from bike mounting and fit the actor to the selected opening before committing the seat.
- Ped.cpp, CalculateNewVelocity, turns authored animation displacement into actor movement through the current heading. PedFight.cpp distinguishes directional hit actions, falls and floor hits. The target uses this behavioral division rather than duplicating those state machines or class structures.
- Automobile.cpp and Bike.cpp, ProcessControlInputs, scale steering through per-vehicle lock. Automobile.cpp, BlowUpCar, marks the vehicle wrecked and scorched and timestamps death. CarCtrl.cpp removes eligible wrecks after sixty seconds, subject to visibility/distance constraints. The new twenty-second repaired fixture respawn is a target test-environment policy, not a claim that the original uses this policy.

## Implemented systems

Player steering multiplier rises from 1.2 to 1.6 relative to the underlying motor profile: one-third quicker than Build 7. AI tuning is unchanged. Ground-speed limits, reversal braking and locked airborne/landing heading remain. Both cars and bikes have 25% more low-speed wheel lock through HandlingProfile; speed-sensitive steering limits remain. The tuned lateral acceleration bounds rise modestly to 8.5 m/s² for mapped cars and 8.0 m/s² for bikes, retaining car anti-roll and measured bike roll support.

Standing grounded hit reactions now own a full-body clip, a captured heading and one normalized action clock. CharacterMotor consumes that clip's sampled planar displacement through its existing collision/step/support solver. Movement, aim, jumping, melee and shooting cannot override the stagger. There is no second planar kick or independent visual root translation. The last clock segment is consumed exactly once. Crouched and airborne hits retain their constrained upper reaction and physical response rather than adding a standing clip's planar path or a second vertical trajectory. Player and NPC use the same components; AI fight facing respects the reaction lock.

Entry retains normal collision-driven approach and full seat reservation checks. Inside a 0.38-meter marker radius, a bounded alignment stage moves with collision sweeps at at most 1.6 m/s, turns at at most 7 rad/s and uses the native car alignment clip. It must reach both position and heading tolerances before opening/mounting. Timeout and cancellation release control and reservations. Transit runs closer to the marker and avoids extremely slow animation playback. Bike pickup/pull-up now uses the explicit semantic aliases in BikeProfile; its physical lifting gate, side-rest and subsequent mount are retained.

VehicleScorch creates per-instance material overrides only on destruction, darkening textured and primitive model surfaces, roughening them and disabling emission. It includes attached and tracked detached panels; shared material resources and neighboring vehicles are not modified. Repair restores the exact original material assignments. This supports the supplied Standard/BaseMaterial3D assets; future custom shaders should provide their own scorch implementation.

VehicleRecovery retains destroyed cars/bikes for twenty seconds by default, then repairs and resets the same entity near its captured spawn. It checks floor and compound hull/cabin clearance, tries nearby marks and retries when blocked. It waits for occupants/reservations to release and removes invalid references. Repair resets damaged panels, debris, tires, glass, colors and damage state; reset restores chassis/door physics and parked control. This is a separate Resource-configured policy from collision damage and presentation. Void recovery and pedestrian respawn remain active.

## Runtime Confirmed in this target

The full batch passes 712 assertions across 18 suites. The new 32 assertions independently sample all four directional hit clips, verify actual travel, heading/jump locks and wall blocking, measure actual wheel angle, exercise fast left/right car/bike alignment and cancellation, verify all four side/tilt aliases and hand reach, and test scorched material isolation/restoration plus delayed, blocked and resumed wreck recycling. All 134 scripts compile and 23 Python tests pass. APK evidence is stored separately in actions_package.json after export; Android hardware execution is untested.

An identical four-case entry benchmark was run against the private Build 7 project and this project. With the actor 0.65 m outside a side marker and deliberately facing away, time to the native entry stage falls from 1.35–1.40 s to 0.533–0.550 s (about 60% less alignment delay). Opening, seating and closing animation durations are retained. See actions_entry_comparison.json. This measures interaction latency, not rendering/FPS performance.

Maximum per-tick spatial-hit displacement error against independently sampled animation keys is below 0.000003 m on an unobstructed floor (tolerance 0.003 m). Walls clip the path safely. The material test measures a primitive body color changing from (0.95, 0.46, 0.28) to (0.152, 0.0644, 0.0364), then restoring the exact original assignment.

## Maintainability and performance scope

Wreck presentation changes only on damage-state events; material discovery/duplication is not performed per frame. Spawn clearance queries run after the configured delay and retry interval, while normal driving only advances small recovery clocks. Existing reusable collision, native animation, seats and damage components retain ownership. No comparative GPU, FPS or memory improvement is claimed, and no original executable/runtime comparison is available. Render appearance and touch feel still need physical Android validation.

## Files and reproduction

Created: driving/respawn_profile.gd, driving/vehicle_recovery.gd, presentation/vehicle_scorch.gd, tuning/vehicle_respawn.tres, tests/run_actions_revision_suite.gd, this document and evidence JSON/transcript files, plus generated Godot UID files.

Modified: animation/actor_action_state.gd; actors/character_motor.gd, character_steering.gd, ped_brain.gd; presentation/skinned_motion_visual.gd, vehicle_damage_visual.gd; interaction/vehicle_approach.gd, vehicle_transition.gd; driving/vehicle.gd, handling_mapper.gd, bike_profile.gd; tuning/movement_profile.gd, handling_profile.gd, interaction_profile.gd; project.godot, export_presets.cfg, tools/check_android_payload.gd, tools/validate.py, tests/run_recovery_suite.gd, tests/run_spatial_motion_suite.gd and validation/setup documentation.

Run `python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable`, then export with `python3 tools/export_android.py --godot /absolute/path/to/Godot_4.7.2_stable --output /absolute/path/Harbor-Rev8.apk`. Keep the private test key for updates. All 315 supplied private asset payloads are preserved unchanged; public git excludes assets and signing material.
