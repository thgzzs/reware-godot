# Combat, landing and vehicle revision

Target: Godot **4.7.2 Stable**, official ed1daf0bf, Jolt Physics. Public baseline: 41fc84fd17b058305f9d42e62bc43b8141ab555e.

Reference: [reVC a26fff4](https://github.com/mrxenginner/reVC/tree/a26fff4af555a8a425ac9f17d1dd718d00d1f942). The original executable was unavailable. Source-confirmed rules informed new target components; runtime checks below mean this Godot implementation, not original-game parity.

## Source Confirmed

| Mechanic | Source confirmed | Target behavior / dependencies |
| --- | --- | --- |
| Landing | Ped.cpp SetLanding chooses FALL_land / FALL_collapse; PlayerPed.cpp RunningLand changes moving landings to JUMP_land | LandingState samples native landing poses independently of motor recovery. Soft drops keep movement; damaging falls retain recovery and damage. Physics support precedes visual selection. |
| Hit reaction | AnimManager.cpp defines directional partial hit associations | Damage direction selects HIT_front/back/L/R. Explicit reaction clock temporarily suppresses weapon actions; swept stagger and arm/spine pose recover together. |
| Ground combat | PedFight.cpp checks low/prone/dead targets, distance and angle; selects weapon ground moves or groundkick | MeleeTargeting queries shared actor state, floor support, distance, direction and occlusion once per attack. Unarmed uses KICK_floor; weapon catalog selects downward attacks. |
| Moving punch | PedFight.cpp separates mobile attacks from stationary fight moves | Moving unarmed strikes use PUNCHR and hand sweeps; starting movement cancels an existing standing kick. Native walk/run legs remain active. |
| Door capacity | VehicleModelInfo.cpp capacity derives from door count, not rear dummy existence | Idaho exposes two front seats and two door bodies. Four-door variants retain rear seats. |
| Entry placement | PedAI.cpp door targets depend on seat markers and final animation displacement | VehicleEntryGeometry computes per-model approach points and physical mount side from native root travel. Short, collision-checked approach runs before final alignment. Door distance/height/path limits prevent remote entry. Reservations precede animation; occupancy commits once. |
| Bike reverse | PedFight.cpp DriveVehicle uses BIKE_WALKBACK; AnimManager maps it to pushes | Rider intent selects bike-specific pushes; feet apply a capped slow reverse force instead of reverse engine torque. |
| Bike lift | PedAI.cpp selects pickup/pullup by side/tilt; torque begins after 0.4667 s | Lift stage keeps standing collision and reservation, plays the supplied clip, then applies inertia-aware Jolt torque. Clear approach is replanned after upright recovery. Cancellation, obstruction timeout, death and seat loss release ownership. |
| Rider collision | Bike.cpp knock-off policy depends on relative contact severity/direction and angular/tilt state | Contact evidence queues one rider ejection; a clearance solver finds a torso destination. Momentum transfers into the shared physical fall body. Balance assistance ceases without rider/mount/lift. |
| Front panel damage | Automobile.cpp front bumper collision damage can propagate to bonnet | Contact-localized damage affects the nearest panel and propagates severe frontal impact to bonnet. Different contact normals rearm independently, including walls sharing a body with the road. Engine damage is applied once. |

## Animation ownership

Locomotion blends walk/run/sprint at a shared cycle. Resource-defined acceleration, deceleration and sprint blend durations drive both root travel and pose weights. Ground velocity follows a bounded acceleration rather than switching instantly to the next root speed.

Soft landing is a timed visual layer; hard landing is an exclusive recovery. Melee has full-body and moving upper-body forms. Native two-handed weapon poses retain authored arm/grip articulation: torso correction centers the aim rather than replacing both arms with the pistol solver. Reload and authored firearm recovery keep their native ownership. Directional hits temporarily own reaction bones and suppress firing. Preview mode bypasses gameplay layers.

The old ANPK WEAPON_crouch was rebuilt alone from the existing decoded source into `assets/converted/legacy_crouch.res` using `tools/build_legacy_crouch.gd`. A per-session shallow library copy replaces that one active clip; the supplied 1168-entry library and all 315 original asset/support payloads remain unchanged. No full archive extraction or bulk reconversion occurred.

## Corpse lifecycle

Player and pedestrians retain the same CharacterMotor, combat and fall components. A run-over launches a solid Jolt torso with impulse, lift and angular motion. Once a dead actor reaches supported quiet rest, its solid body freezes with collision layers/masks cleared. A query-only Area retains melee targeting and floor-hit reactions. It does not push cars or receive forces. Respawn clears the proxy and resets the physical body. Living downed actors still wait for a clear standing volume before directional get-up.

## Runtime Confirmed (Godot)

The native revision suite checks the shared player/ped actor with supplied clips and actual Jolt contacts. It verifies visible soft landing without a movement lock, directional hit timing/translation, gradual gait weights, centered rifle/shotgun aim, one moving punch, floor attacks against a retired corpse hitbox, nearby-door entry, two-seat Idaho, actual bonnet collision damage, dynamic bike pickup, slow walking reverse and crash release. These observations apply to this Godot build.

## Inferred / requires validation

Exact original movement feel, blend curves, contact timing, original handling parity and all asset-specific hand/foot contacts still require executable traces and playtesting. The new acceleration, blend, door-range and reverse-speed values are explicit target tuning choices. Pickup has no physical hand constraint; contact placement during the authored animation remains approximate. No source-confirmed rule alone establishes runtime equivalence.

## Tuning and debug

Resources: `gait.tres`, `landing.tres`, `actions.tres`, `interaction.tres`, `bike.tres`, `melee.tres`, `weapon_actions.tres`, `long_gun_pose.tres`, `vehicle_parts.tres`. Profiles expose transition times, movement response, door range, route length, reverse speed, pickup tilt/torque/timing, crash threshold, ground reach and bonnet propagation.

Existing HUD/state inspector, animation browser, force telemetry, collision visualization and touch controls remain available. Approach/lift are cancellable with E or touch CANCEL. Physics state owns trajectories; rendered skeletons never own health, occupancy or input.

## Validation and limits

Run `python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable` and the Python suite described in VALIDATION.md. The dedicated `run_behavior_revision_suite.gd` exercises native landings, hit clocks, gait blending, rifle/shotgun aiming, legacy crouch, moving punches, corpse targeting, entry distance/ownership/pelvis alignment, actual wall-to-bonnet contact, fallen-bike pickup, slow reverse and rider ejection. `render_behavior_preview.gd` provides repeatable selected-pose previews.

This milestone does not prove complete fighting, shooting or driving equivalence. Asset contacts still need human playtesting, particularly all weapon grips at extreme pitch, moving lift obstacles, uneven terrain and every model/clip combination. Torso bodies remain a practical fall proxy, not articulated ragdolls. Bike pickup uses authored animation and dynamic torque, not a hand-to-handlebar physical constraint. No original executable comparison, Android device run, GPU performance parity or full open-world content claim is made. Performance telemetry records current workloads; no unmeasured optimization speedup is claimed.
