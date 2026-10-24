# Spatial movement and bike reaction revision / Build 6

Target remains exactly Godot 4.7.2 Stable (ed1daf0bf), Jolt, physics 60 Hz. The Android package remains org.reware.harbor.revision5 so this update can replace Build 5 using the same private test signing identity. Its version is 0.5.0-spatial6, code 6, launcher name Harbor Rev 6, HUD BUILD 6.

## Confirmed defects and changes

- Riding layers had unconditional priority over every full-body pose. A crash left the layers populated, so a correctly selected fall clip could still render a seated rider. Riding layers now apply only to seated animation state. Seat release and physical reaction entry explicitly relinquish them. The reaction pose takes ownership immediately. Intentional bike dismount keeps its bike-specific rear windup, then hands off to the airborne bike fall clip after release.
- Native animation root displacement was followed by a second velocity interpolation. The collision body could lag behind the feet and keep moving sideways after its facing changed. Ground movement now sweeps the exact sampled planar animation displacement. Gait blending supplies acceleration and deceleration; a separate velocity lerp no longer changes the native stride. Idle/walk/run/sprint blending shares the root-motion weights.
- Launch poses did not consume planar root travel; landing poses were visual overlays over unrelated gait motion. Launch and landing now consume their own authored planar displacement. Landing owns one pose/travel clock, captures its heading, and resumes the gait without repeating walk-start. Vertical flight remains a gravity/collision trajectory; authored vertical bone motion is not applied as a second gravity path.
- Facing input ran while airborne, with a high inherited heading limit. The shared steering component now caps ground turning by speed, brakes on large reversals and ignores facing input during launch, flight and landing contact. Camera look remains independent. Physical torso reactions also have bounded angular speed and presentation tilt, preventing continuous wheel-like spinning.
- Empty bikes had no explicit parked state, a low center of mass and suspension rays that supported heavily tilted bodies. Parked-standing, ridden, mounting, lifting and fallen support now have explicit rules. Parked bikes hold upright; a sufficiently disturbed bike loses standing support and rests on its physical side collider. Heavily tilted wheel rays are disabled. Lift assistance applies real torque and partial weight support, then replans the mount only after the chassis is upright and sufficiently quiet. Normal stationary dismount can restore standing support; crash/bailout release cannot.

## Source Confirmed

Reference commit: [a26fff4af555a8a425ac9f17d1dd718d00d1f942](https://github.com/mrxenginner/reVC/tree/a26fff4af555a8a425ac9f17d1dd718d00d1f942). SHA256 records for the inspected files are in spatial_source_files.json.

| Source | Behavior used as specification |
| --- | --- |
| Ped.cpp, CalculateNewVelocity | Bounded heading updates; transform animation movement delta through the current heading to form planar movement. |
| PlayerPed.cpp, PlayerControlZelda | Camera-relative intent, movement-speed acceleration, separate jump/air/landing handling. |
| Ped.cpp, SetLanding; PlayerPed.cpp, RunningLand | Distinct landing associations and a moving landing choice. |
| Bike.cpp, KnockOffRider | Mark driving associations for removal before changing the pedestrian state and selecting directional knock-off reactions. |
| Bike.cpp, balance section | Rider-balanced, being-picked-up and standing states explicitly gate balance assistance. An empty bike does not imply one unconditional balance policy. |
| PedAI.cpp, entering/pickup | Choose pickup/pullup by side/tilt and begin physical pickup after the animation timing gate. |

No original architecture or class hierarchy was copied. The new steering, action clocks and support rules belong to the composed Godot components.

## Runtime Confirmed (this Godot implementation)

The spatial-motion suite uses the supplied skin, animations and actual Jolt contacts. It compares collision travel with independently sampled native animation keys, checks lateral drift during turning, heading changes under opposing and airborne input, spatial launch/landing, parked support, fully side-resting bikes, physical pickup, visible limb changes after ejection, and bounded torso rotation.

Free-ground walk/run displacement error in the native fixture is below 0.003 m per tick; measured runs are approximately 0.000002 m. The turning fixture's lateral movement remains within the small authored root sway. Airborne and landing heading changes under rotating input are zero in the fixture. Knocked-over bikes rest near 90 degrees rather than a suspension-supported 45-degree lean.

These are target-runtime checks. They do not establish original-game feel, Android hardware behavior or full gameplay parity.

## Inferred / target tuning

The modern heavier steering limits, reversal threshold, landing playback bounds, torso angular limits, bike collider/center of mass and lift assistance are explicit target tuning choices. Tune MovementProfile, LandingProfile, GaitProfile, PedImpactProfile and BikeProfile. The wheel-load roll compensation is a measured support-force feedforward term while balance assistance is authorized; a fallen bike bypasses it.

Physics owns trajectories and collision travel. Animation owns the sampled root displacement and pose phase. Neither a rendered bone nor a parked visual orientation owns seat occupancy or input.

## Remaining gaps

No running reVC executable or physical Android device was available. Exact stride contact on every slope, weapon/aim-strafe variants, asset-specific grip constraints and articulated ragdolls still need validation. The current fall body remains a bounded solid torso proxy. No FPS improvement or full behavioral equivalence is claimed.
