# Architecture and ownership

This design uses scene composition and small components rather than an engine hierarchy or universal entity manager. `world/arena.gd` is the test application's composition root: scene construction, dependency injection and phase ordering. Gameplay modules do not query global singleton managers. No autoload is required.

| Owner | Responsibility | Explicit boundary |
| --- | --- | --- |
| LocalInputSource | Device input → one-tick GameplayCommand | Replace producer for AI, replay or remote input |
| CharacterMotor | Intent acceleration, support, sweep/slide, steps, jump, collision pushes | MovementProfile; camera yaw; fixed dt |
| WeaponController | Ammo, cooldown, reload, two-stage ray, damage dispatch | WeaponProfile; camera, muzzle, space, exclusions; shot/recoil signals |
| DamageReceiver | Health and prototype target reset | `receive_damage(amount, point, direction)`; damaged/depleted signals |
| DriveVehicle | Rigid body, input latch, steering, seat ownership | HandlingProfile; four car or two bike contact solvers |
| WheelForceSolver | Ground query, spring/damper and combined tire forces | Direct body state + space; SI values; no player knowledge |
| VehicleTransition | Seat transaction, validation, timing, collision/control changes | Actor, candidate vehicle, InteractionProfile; state_changed signal |
| FollowCameraRig | Follow/aim/drive framing, lag, swept obstruction and recoil | CameraProfile; target point and exclusion RIDs; no actor lookup |
| LabOverlay | Presentation of state, telemetry, wheel contacts and shot feedback | Read-only composition-root references; no gameplay decisions |
| GameplayTelemetry | Bounded rolling CPU samples | Summarize on demand; no per-tick file I/O |

## Added composition boundaries

DamageEvent and BallisticTrace connect weapons to actor, prop and vehicle receivers. PhysicalProp owns its Jolt body and PropProfile. VehicleDamage owns health, tire/glass state and terminal fire/explosion; presentation modules observe state. ActorStance owns capsule/headroom changes; MeleeController owns strike windows. VehicleSeatMap owns unique reservations/occupants; VehicleTransition commits transfers. HandlingDataMapper and VehicleVariant create distinct physics fixtures without putting mesh-specific branches in controllers. See SYSTEMS_REVISION.md.

## Update contract

At 60 physics ticks per second:

1. Sample or inject one command. A jump/interact/reload edge exists for one tick.
2. Read camera look, validate interaction and advance the transition transaction.
3. Advance weapon selection, cooldown and reload once, then actor action clocks and motor.
4. Latch the committed driver's command; otherwise respect parked/coasting/external ownership.
5. Update follow camera/obstruction and solve the camera-center aim target.
6. Sample the controlled actor pose once, update bone attachments, then resolve muzzle-occluded firing.
7. Record orchestration CPU time. Each vehicle owns its own wheel presentation callback.

Jolt invokes vehicle `_integrate_forces` independently with the last latched command. Force input can have one physics tick of latency. Movement uses the current look yaw; the camera-center target and the muzzle query belong to the same gameplay tick. The player pose is sampled at the fixed tick so render frame rate cannot advance action clocks or crossfades twice. NPC normal presentation samples during rendering; reaction bodies own their pose synchronization while active. Render-time HUD reads simulation state.

## Vehicle transaction

`on_foot → entering → driving → exiting → on_foot`.

Entry requires grounded actor, reach, line of sight, upright slow vehicle and an unoccupied/unreserved seat. Reserving is synchronous; a competing requester cannot reserve the same seat. Entering suppresses foot/weapon control and parks the car. A timed completion commits the reserved driver exactly once. Loss of vehicle or excessive movement rolls back to the saved approach point.

Driving enables one vehicle input consumer while the foot motor is disabled. Normal exit requires a supported, clear capsule volume. A moving exit validates a bailout route and hands collision ownership to the physical reaction body. Tilted cars use an upright-world destination and animated crawl path. The prototype tests left, right, then rear candidate positions. Ownership remains committed throughout exiting. On commit it queries again, so a new blocker cancels exit and keeps the driver. A successful commit places the actor, restores control/collision, releases the driver and parks the car.

A collision exception between the actor and the occupied vehicle persists during transfer and for 0.1 s after restoration. This prevents cached Jolt overlap contacts from imparting a spurious impulse as the collision-disabled occupant is moved outside. The acceptance suite checks post-exit vehicle stability. Collision with that one vehicle is suppressed during this short grace interval; it is a documented prototype compromise. The capsule exit test still includes the vehicle before committing.

Entry and exit presently use configured time gates, not skeletal animation markers. `state_changed` is the integration boundary for presentation. Before production animation, drive authoritative completion from validated markers with a timeout and cancellation token; preserve seat reservation until commit. Imported clip times drive door motor contact gates. The visible driver is pelvis-anchored to the model seat; get-in/get-out use one pelvis path so capsule translation and animated vertical root motion cannot both shift the seat. Independent animation event markers and cancellation tokens remain future work.

## Extending

- Add a vehicle: duplicate `scenes/vehicle.tscn`, change visuals/shape, inject a HandlingProfile. Configure active contacts and, for bikes, BikeProfile and clip prefix. Boats/aircraft require new dynamics modules.
- Add a character archetype: reuse CharacterMotor and a MovementProfile with another command producer and presentation scene. No protagonist name is embedded in gameplay modules.
- Add a weapon: reuse WeaponController with another WeaponProfile for hitscan types. WeaponLoadout provides switching and per-slot ammo; a projectile strategy remains future work.
- Add a camera mode: supply another presentation strategy through the rig boundary; current follow/aim/driving modes are parameters of one rig.
- Scale the world: replace the arena's direct-child vehicle discovery with a spatial registry and stream content through a world scene owner. No streaming implementation is claimed.
- Multiplayer: commands, explicit seat ownership and signals are useful boundaries, but this is not network-ready. Authentication, authority, serialization, prediction, reconciliation and replication are absent. Jolt is not treated as deterministic rollback simulation.
- Mods: Resources and scenes are content boundaries, not a mod loader or security boundary. Versioned manifests, schema migration and an explicit package loader remain work.

Shared Resources are configuration only. Runtime state lives on component instances. Tests inject the same commands that local input produces and run the production scenes/physics backend.

## Imported-asset extension

CharacterMotor now owns an instance PedHealth and WeaponController, shared by the player and NPC scenes. ImportedAssetSetup selects validated source data fields and creates NPC intent producers. ReferenceMotion samples the immutable native library; ReferencePose is a procedural diagnostic presentation. ImportedAnimationBrowser inspects all clips. Their exact responsibilities and limits are documented in IMPORTED_ASSETS.md. No global player-only movement implementation is used by NPCs.

## Presentation and display boundary

PlaceholderAssets owns semantic model/texture bindings and artwork offsets/colors. ModelPlaceholderSetup installs imported native scenes without moving gameplay ownership into meshes. SkinnedMotionVisual samples shared clip timing on each actor’s independent Skeleton3D/Skin; planar root movement remains motor-owned. ShotPresentation reuses visual effect sprites and never performs damage queries. DisplayController owns window/UI/3D scale settings and optional frame-time adaptation; it cannot change physics timestep or handling data. GameplayHud renders actual state and blocks input through the arena boundary while a modal menu is open. No presentation asset is required to retain the authored primitive fallback.


## Action and impact revision

Each CharacterMotor owns ActorActionState, PedHealth and WeaponController. Player and pedestrian command sources remain interchangeable. ReferenceMotion owns movement phase and root integration; SkinnedMotionVisual composes phase-matched locomotion, full-body action crossfades, masked gun actions and arm IK. Presentation never moves the collision body. ActionProfile stores blend/reaction policy separately from movement and weapon Resources. WeaponLoadout in tuning/arsenal.tres defines the test arsenal and reference DAT selections.

DriveVehicle composes a PedestrianImpactProbe and two VehicleDoor bodies. VehicleDoorProfile owns hinge, mass, panel, seat and approach tuning; each vehicle duplicates its profile before model markers adjust it. A latched door has no active joint so freezing it cannot pin the chassis to the world. VehicleTransition reserves and commits occupancy around separate opening/get-in/inside-close and get-out/outside-close stages. Exit volume and route are checked again on the same selected exit index.

EquippedWeaponVisual binds exact scene roles. The active imported arsenal has 24 entries and native VCS weapon actions. WeaponActionCatalog stores clip lists, muzzle/tip calibration and grip Resources; unavailable assets are not silently aliased to another weapon.

## Motion ownership revision

Full-body actions explicitly replace locomotion layers. Jump launch has a short 40 ms crossfade because its supplied clip lasts only 133 ms. Upper actions are suppressed during jumping, seating, life reactions and sprinting; aim/fire/reload take precedence over a sprint request. Base pose and upper pose snapshots are cached before IK, preventing a solved arm pose from feeding back into the next locomotion crossfade.

AimSolution provides the camera-center target to the actor's world-space hand solver. WeaponController advances state before pose evaluation and resolves firing after pose evaluation. The muzzle-to-target ray still blocks cover between gun and reticle. WeaponPoseProfile contains reach, recoil, magazine-hand trajectory and solver tuning independently from ballistics.

Each actor composes one dormant top-level PedReactionBody. On impact, the standing collider yields collision/motion ownership to this 75 kg Jolt torso. The body uses CCD, world/vehicle/door/actor contacts, bounded lift and opposite car impulse. The skeleton follows the physical pelvis; it does not also drive the body transform. Recovery requires slow motion, a supported clear standing volume and a get-up action. Death retains the physical body; respawn deactivates and reuses it. It is a single rigid torso approximation, not a per-bone ragdoll.

Each wheel has a steer/suspension parent and an axle spin pivot carrying both tire and visible hub. Rates use the wheel solver's relative longitudinal contact velocity; airborne wheels use chassis speed as a presentation fallback. Physical wheel inertia is still unimplemented.

## Current Stories modules

RigBinding resolves original source bone IDs and caches channel-index mappings for each rig/clip, including duplicate display names. MeleeController passes planar clip displacement through the motor and sweeps animated attack tips. PedBrain only supplies intent; damage and strikes use the shared actor components. VehicleParts owns localized health/variants/fragment lifetime; VehicleStability owns contact-limited steering/anti-roll; BikeDynamics owns two-contact balance and lean. VehicleExitSolver owns clearance, while VehicleTransition retains occupancy until an exit or bailout commit. See STORIES_REVISION.md for configuration and extension paths.

## Falling and mobile strikes

ActorFallState tracks per-instance trajectory evidence; FallProfile owns thresholds/clip choices; CharacterMotor supplies relative support-normal landing speed and commits damage through PedHealth once. Mobile melee retains the locomotion base, overlays configured striking bones and sweeps the displayed tip after fixed-tick pose evaluation. Player and pedestrian roots use that same order. See FALL_AND_MOBILE_MELEE.md.
