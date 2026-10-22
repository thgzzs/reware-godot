# Physics migration contract

## Coordinates and time

Target convention: +Y up, -Z forward, meters, seconds, kilograms, newtons and impulses in N·s. Reference source uses Z up and handling conversions normalize simulation time to 1/50 second. Do not paste reference velocities/accelerations into target Resources. `HandlingMgr::ConvertDataToGameUnits` explicitly converts km/h and acceleration using 50 and 50²; this is a source-confirmed unit clue, not proof that every subsystem shares a uniform scale.

The target runs at 60 Hz. Acceleration integrates with dt; forces are applied once per direct-state callback without multiplying by dt twice. Discrete timings have up to one tick of quantization. No deterministic equivalence across hardware or engine patches is claimed. Exact engine and Jolt selection are enforced at startup.

## Character

CharacterBody3D supplies swept collision queries and `move_and_collide` only. The project does not use `move_and_slide` or assume built-in CharacterBody movement reproduces the reference. Intent acceleration is retained separately from collision-projected velocity so repeated contact with a rounded stair edge does not erase locomotion intent. Actual displacement still obeys swept collisions.

The motor implements ground acceleration/deceleration, sprint and aim speed modifiers, limited air acceleration, gravity, jump buffer, coyote grace, launch windup and landing recovery. Launch speed, delay and gravity are independent tuning values; they have not been matched to reference animations. Ground support uses capsule sweeps plus a center ray to distinguish a floor from a nearby stair riser. Up/forward/down sweeps validate steps; a maximum slope rejects steep support. Projected residual motion is also prevented from climbing steep surfaces. Ceiling collision removes upward velocity. A bounded impulse transfers push momentum to rigid bodies.

The capsule is 1.8 m high with radius 0.32 m and root at its center; foot offset is 0.9 m. Changing those dimensions requires updating support/exit geometry assumptions. Shape dimensions are not yet part of MovementProfile. Ground snapping and edge support are prototype policies, not confirmed reVC ledge behavior. Moving-platform inheritance, crowd collision, sliding surfaces and ragdolls are unimplemented.

## Vehicle

The vehicle is a Jolt RigidBody3D with chassis/cabin collision and a lowered configurable center of mass. Four ray contacts feed independent WheelForceSolver instances; VehicleBody3D is not used.

Per contact, the solver measures spring compression and point velocity relative to a moving rigid support. Target spring force is `clamp(k*x - c*v_normal, 0, max_force)`. Tire force combines drive/brake/rolling resistance and lateral slip opposition; its magnitude is limited by `friction * normal_load`. Forward and side directions lie in the contact plane. Front steer angles reduce with speed and approach the requested angle at a bounded rate. Force is applied at the contact lever arm, allowing natural pitch, roll and load transfer. There is no explicit anti-roll controller or wheel angular inertia model.

Important API detail: PhysicsDirectBodyState3D.center_of_mass is an origin-relative offset expressed in global axes. Therefore relative point velocity uses `(contact - body_origin - center_of_mass)`, not `(contact - center_of_mass)`. A translation-invariance integration test guards this error. Direct-state apply_force receives an origin-relative lever in world axes.

S requests braking when traveling forward, then reverse drive near rest. Space is an independent brake. Gear curves, tire relaxation, surface-specific adhesion, anti-dive, tire damage, physical wheel rotation and wheel sweep contacts remain future calibration/features. Wheel animation is presentation only. Rays can miss curbs that real wheel volumes would strike; chassis collision remains Jolt's responsibility. The engine profile uses axle drive flags and speed caps, not a reference transmission conversion.

## Jolt compatibility

The versioned 4.7 documentation confirms built-in Jolt and the `Jolt Physics` setting. This project uses no unsupported joint soft-limit properties and no extension-only Jolt APIs. It does not use contact impulse estimates for damage, or rely on ray face indices. Convex margins use engine defaults; tune only with measured contact tests. Camera cast_motion cannot detect an initial overlap by itself; embedded pivots need a future overlap/depenetration policy.

## Calibration gates

Capture reference and target traces for identical inputs on flat ground, grades, stairs, curbs, impacts and surface changes. Store raw input timestamp, build/config identity, position, rotation, velocity, support normals, animation phase, wheel contacts and state transitions. Fit tuning against speed-time curves, jump launch/apex/airtime, yaw response, stopping distance, suspension compression/overshoot and entry/exit event times. Agree tolerances per mechanic before calling a match.

Separate gameplay traces from visual capture and performance capture. A numerically close endpoint alone is insufficient: compare trajectories and transition timing. Preserve intentional modernization changes in the discrepancy register instead of tuning them away silently. No reference runtime or original data assets were available in this run, so this calibration gate remains open.

## Imported motion update

The private asset build now has a second, explicitly selected movement policy: body-heading-coupled root displacement and animation commitments. Existing collision/step/gravity machinery is shared. ImportedAssetSetup overrides source-supported data fields; original coefficient/COM mappings remain incomplete. Read IMPORTED_ASSETS.md for the exact policy, heading-rate normalization, unsupported fields and remaining parity gaps.
