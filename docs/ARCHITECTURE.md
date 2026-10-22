# Architecture and ownership

This design uses scene composition and small components rather than an engine hierarchy or universal entity manager. `world/arena.gd` is the test application's composition root: scene construction, dependency injection and phase ordering. Gameplay modules do not query global singleton managers. No autoload is required.

| Owner | Responsibility | Explicit boundary |
| --- | --- | --- |
| LocalInputSource | Device input → one-tick GameplayCommand | Replace producer for AI, replay or remote input |
| CharacterMotor | Intent acceleration, support, sweep/slide, steps, jump, collision pushes | MovementProfile; camera yaw; fixed dt |
| WeaponController | Ammo, cooldown, reload, two-stage ray, damage dispatch | WeaponProfile; camera, muzzle, space, exclusions; shot/recoil signals |
| DamageReceiver | Health and prototype target reset | `receive_damage(amount, point, direction)`; damaged/depleted signals |
| DriveVehicle | Rigid body, input latch, steering, seat ownership | HandlingProfile; four independent wheel solver objects |
| WheelForceSolver | Ground query, spring/damper and combined tire forces | Direct body state + space; SI values; no player knowledge |
| VehicleTransition | Seat transaction, validation, timing, collision/control changes | Actor, candidate vehicle, InteractionProfile; state_changed signal |
| FollowCameraRig | Follow/aim/drive framing, lag, swept obstruction and recoil | CameraProfile; target point and exclusion RIDs; no actor lookup |
| LabOverlay | Presentation of state, telemetry, wheel contacts and shot feedback | Read-only composition-root references; no gameplay decisions |
| GameplayTelemetry | Bounded rolling CPU samples | Summarize on demand; no per-tick file I/O |

## Update contract

At 60 physics ticks per second:

1. Sample or inject one command. A jump/interact/reload edge exists for one tick.
2. Validate interaction; advance the transition transaction.
3. Advance the on-foot motor when it owns control.
4. Latch vehicle command only for the committed driver; otherwise park it.
5. Update follow camera and its obstruction query; resolve aim for this tick.
6. Advance weapon cooldown/reload; fire only when on foot.
7. Refresh wheel presentation and record orchestration CPU time.

Jolt invokes vehicle `_integrate_forces` with its direct body state. It consumes the last latched command; no assumption is made that this callback runs after the scene's gameplay callback. Control-to-force latency can be up to one physics tick. Tire forces use `state.step`. Render-time HUD reads snapshots and never mutates simulation. Camera yaw used for movement is the previously resolved yaw; mouse rotation affects camera/aim in the current tick and movement on the next tick. This latency is explicit and requires reference feel validation.

## Vehicle transaction

`on_foot → entering → driving → exiting → on_foot`.

Entry requires grounded actor, reach, line of sight, upright slow vehicle and an unoccupied/unreserved seat. Reserving is synchronous; a competing requester cannot reserve the same seat. Entering suppresses foot/weapon control and parks the car. A timed completion commits the reserved driver exactly once. Loss of vehicle or excessive movement rolls back to the saved approach point.

Driving enables one vehicle input consumer while the foot motor is disabled. Exit requires low linear speed and a supported, clear capsule volume. The prototype tests left, right, then rear candidate positions. Ownership remains committed throughout exiting. On commit it queries again, so a new blocker cancels exit and keeps the driver. A successful commit places the actor, restores control/collision, releases the driver and parks the car.

A collision exception between the actor and the occupied vehicle persists during transfer and for 0.1 s after restoration. This prevents cached Jolt overlap contacts from imparting a spurious impulse as the hidden occupant is moved outside. The acceptance suite checks post-exit vehicle stability. Collision with that one vehicle is suppressed during this short grace interval; it is a documented prototype compromise. The capsule exit test still includes the vehicle before committing.

Entry and exit presently use configured time gates, not skeletal animation markers. `state_changed` is the integration boundary for presentation. Before production animation, drive authoritative completion from validated markers with a timeout and cancellation token; preserve seat reservation until commit. No synchronized door or seated character animations are supplied.

## Extending

- Add a vehicle: duplicate `scenes/vehicle.tscn`, change visuals/shape, inject a HandlingProfile. The four-wheel layout currently lives in DriveVehicle and must be generalized for bikes/boats/aircraft.
- Add a character archetype: reuse CharacterMotor and a MovementProfile with another command producer and presentation scene. No protagonist name is embedded in gameplay modules.
- Add a weapon: reuse WeaponController with another WeaponProfile for hitscan types. A loadout/switching component and projectile strategy are future work, not working features.
- Add a camera mode: supply another presentation strategy through the rig boundary; current follow/aim/driving modes are parameters of one rig.
- Scale the world: replace the arena's direct-child vehicle discovery with a spatial registry and stream content through a world scene owner. No streaming implementation is claimed.
- Multiplayer: commands, explicit seat ownership and signals are useful boundaries, but this is not network-ready. Authentication, authority, serialization, prediction, reconciliation and replication are absent. Jolt is not treated as deterministic rollback simulation.
- Mods: Resources and scenes are content boundaries, not a mod loader or security boundary. Versioned manifests, schema migration and an explicit package loader remain work.

Shared Resources are configuration only. Runtime state lives on component instances. Tests inject the same commands that local input produces and run the production scenes/physics backend.

## Imported-asset extension

CharacterMotor now owns an instance PedHealth and WeaponController, shared by the player and NPC scenes. ImportedAssetSetup selects validated source data fields and creates NPC intent producers. ReferenceMotion samples the immutable native library; ReferencePose is a procedural diagnostic presentation. ImportedAnimationBrowser inspects all clips. Their exact responsibilities and limits are documented in IMPORTED_ASSETS.md. No global player-only movement implementation is used by NPCs.

## Presentation and display boundary

PlaceholderAssets owns semantic model/texture bindings and artwork offsets/colors. ModelPlaceholderSetup installs imported native scenes without moving gameplay ownership into meshes. SkinnedMotionVisual samples shared clip timing on each actor’s independent Skeleton3D/Skin; planar root movement remains motor-owned. ShotPresentation reuses visual effect sprites and never performs damage queries. DisplayController owns window/UI/3D scale settings and optional frame-time adaptation; it cannot change physics timestep or handling data. GameplayHud renders actual state and blocks input through the arena boundary while a modal menu is open. No presentation asset is required to retain the authored primitive fallback.
