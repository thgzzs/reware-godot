# Sprint tapping, walk-in entry and physical reaction settling

This revision adds a capped sprint-tapping boost, a collision-driven approach stage before mounting vehicles, and direction-aware settling for physical reactions. It also selects each bike family's rear get-off animation for an intentional moving bailout.

## Sprint

Holding Shift starts ordinary sprint. Releasing it briefly between taps no longer toggles out of the sprint gait: a 0.28 s intent grace bridges separate presses. Subsequent distinct presses add a small bonus, which decays over time and caps at 1.20 times ordinary sprint. A minimum tap interval prevents arbitrarily rapid input from increasing the cap. Holding the button does not create repeated boost events. Walk, aim, reload, loss of support and incompatible actions reset the bonus.

ActorSprintState owns the per-actor input history; tuning/sprint.tres owns the gain, decay, grace and cap. The native gait clock and its root displacement share the multiplier, so boosted movement does not simply slide a normal-speed skeleton. The fallback motor applies the same capped multiplier. Resuming directional movement interrupts a pending Run_stop instead of forcing the actor to finish stopping and restart walking.

The 20% cap and tap curve are explicit new tuning choices. They are not a measured original-game coefficient. The synthetic root-motion fixture measures continuous 6.0–7.2 m/s movement while tapping. The restored native sprint clip remains active through all 300 tapping ticks: measured instantaneous root speed spans 6.92–13.95 m/s because the supplied stride has a nonuniform root curve. That range is not a constant speed target or an original-runtime measurement.

## Walk-in entry

The transaction is now `on_foot → approaching → entering → driving/passenger`. A request reserves the seat while the actor retains standing collision and the motor. VehicleApproach plans a clear route to the door/mount marker, including chassis-corner routes when the direct segment crosses the vehicle. Forced walk commands slow near the marker, then turn and stop the actor before the opening/mounting animation begins. The approach does not interpolate or teleport the actor through the chassis.

The approach planner uses bounded capsule casts at request time, not a new global navigation system. A stalled path, lost reservation, invalid vehicle, excessive vehicle motion, death or cancellation releases the transaction at the actor's current position. E cancels an approach. Dynamic blockers are handled by the normal motor and a stall timeout; arbitrary world pathfinding remains outside this local planner. Timing tests distinguish approach time from opening/get-in/closing time.

Native walk-start anticipation plays at its normal rate before near-marker slowdown, preventing a planted start from expiring the stall timeout. Weapons are holstered for the transaction; cancellation restores their availability. Tune arrival radius, slowdown/start rate, clearance, timeout and heading policy in InteractionProfile. GameplayCommand.locomotion_scale limits forced approach gait speed without bypassing the shared motor. Player and pedestrian command boundaries remain explicit.

## Physical falls and settling

High on-foot descents can hand collision ownership to the existing Jolt torso proxy. They preserve velocity and spin; environmental landing damage is dispatched once from the first supported impact, using relative normal closing speed. Modest drops keep their existing motor-driven landing. FallProfile exposes the physical-tumble threshold separately from damage thresholds.

ReactionRestState observes actual support, linear speed and angular speed. It cannot settle a body while airborne or sliding quickly. After continuous quiet contact it blends presentation into a floor-aligned prone or supine pose according to fall direction. The torso rigid body remains physical; no orientation or velocity is overwritten by this visual correction. Another substantial impact unlocks the settled pose. Recovery waits for settling, selects the matching get-up animation and retains the fall heading.

The same component serves car impacts, car/bike bailouts and physical on-foot falls. It is a single rigid torso approximation, not an articulated ragdoll. ReactionRestProfile in tuning/reaction_rest.tres exposes contact time, speed thresholds, blend policy and clip/get-up candidates. Native inspection found FALL_front/back leave bent limbs penetrating the floor. The flat supplied terminal poses are KO_skid_back for prone and KO_skid_front for supine. A cached skin minimum and supported floor probe blend the presentation to 1 cm clearance after the pose settles; physical torso transforms/velocities are unchanged.

## Bike bailout selection

At pinned reVC commit a26fff4af555a8a425ac9f17d1dd718d00d1f942, PedAI.cpp chooses ANIM_BIKE_GETOFF_BACK for an intentional moving bike exit. AnimManager.cpp maps that action to BIKEs/BIKEd/BIKEv/BIKEh_getoffBACK. The former generic BIKE_fall_off selection describes a different reaction.

VehicleVariant now stores the bailout suffix, release timing and explicit fallbacks. Moving bike bailouts validate rear-sector destinations, play the corresponding rear get-off windup, then transfer inherited velocity to the physical reaction body. Car rollout selection and its release timing remain separate. If a converted library lacks the required rear clip, the configured fallback is used; the native suite verifies all four supplied rear clips and their windup/release ownership gates.

## Evidence and limits

The asset-inclusive follow-up runs the supplied native rig, all 1168 library entries, VCS core/weapons and LCS bike clips on exact Godot 4.7.2 Stable with Jolt. The native intent suite adds 43 checks for uninterrupted gait playback, car/four-bike walk-in, unique seating, rear bailout windup/release, airborne spin, flat directional terminal skin, chest orientation, get-up selection and retained heading. The separate 42-check synthetic suite remains deliberately independent of private assets.

The native follow-up corrected two issues found by those checks: holstering during approach, and walk-start slowdown starving a small corrective Sanchez step. It also replaced the unsuitable bent terminal clips and corrected skin floor clearance. Seven selected native poses were rendered with Mesa llvmpipe and visually reviewed; these are snapshots, not exhaustive animation-contact or temporal visual parity.

See VALIDATION.md and native_intent_results.json for current counts and measurements. All selected private asset bytes are preserved from the supplied ZIP. Full original-game parity, browser playback, articulated ragdolls, arbitrary world pathfinding and target-hardware performance remain unverified. The tapping curve, rest thresholds and bike release timing are explicit target tuning choices.
