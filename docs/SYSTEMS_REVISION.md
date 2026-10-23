# Physics, stance and damage revision

This revision adds physical props, vehicle component damage, crouch shooting, airborne weapon restrictions, melee, per-seat transactions and broader regression coverage. It retains the supplied selected assets byte for byte. It does not establish original-game runtime parity.

## Implemented behavior

- Trash cans are independent 18 kg Jolt rigid bodies with CCD, center of mass, contact response and point impulses. Cars can push them; shots translate and rotate them.
- Bullets query separate tire, glass and native body regions. Wheel arches/windows remain query openings. Flat tires lose radius and grip and gain drag; native wheel visuals deflate. Windshields select intact, cracked and shattered states, removing shattered glass and its hit region.
- Vehicle health receives energy-based collision damage once per contact episode, uses damaged native meshes when available, smokes below 500 health, burns below 250 and explodes once after five seconds. Explosion damage is deduplicated, distance weighted and obstruction checked. F6 repairs a nearby stopped lab car for continued testing.
- C toggles crouch, shortens the capsule without moving the feet and checks headroom before standing. Source-style crouch is stationary by default. Crouch aiming and shooting work. Sprint/jump leave crouch only when safe. Launch, airborne and landing phases block firing; airborne reload is cancelled or rejected without spending ammunition.
- Weapon profiles bind exact model scenes and source model IDs. A one-handed pistol leaves the support arm on its base pose. Aim, cover checks, body-turn gating, recoil and reload share action priority. Native inventory contains Colt .45 and unarmed with the currently available files. Missing firearm meshes are not replaced with a pistol or invented rifle.
- Unarmed melee uses imported strike windows and per-swing target deduplication. NPCs start unarmed and use the same motor, health, stance, weapon and reaction components as the player.
- Native Idaho has four marker-defined seats and two physical doors. Alt+E selects a passenger seat, X requests a passenger-to-driver shuffle, and ordinary right-side entry shuffles to a free driver seat. Reservations and control transfer commit atomically. Side-specific clips set transition durations. Seated actors retain a ballistic hit region.
- The yard adds distinctly tuned FWD STINGER and AWD LANDSTAL physics fixtures, including four doors on the latter. Both are visibly labeled mesh-pending fixtures. They are not authentic exported car models.
- V cycles three on-foot distances and vehicle follow/bonnet views. HUD shows stance, melee/ammo, passenger/shuffle state and the active vehicle. Existing aspect-ratio and render/UI scaling controls remain.

## Source-confirmed findings

Reference: reVC commit `a26fff4af555a8a425ac9f17d1dd718d00d1f942`. Reviewed movement/player/ped/fight, weapons, camera, collision/physical, automobile/damage, handling/transmission and animation files. C++ source is not included in this project.

| Finding | Target interpretation |
| --- | --- |
| Timer uses normalized 50 Hz time; gravity .008, pedestrian mass 70 | Native gravity .008×50² = 20 m/s² |
| Player upward jump impulse 8.5, divided by mass | 8.5×50/70 = 6.0714 m/s launch |
| Forward jump minima .1, .17, .22 by move state; faster motion retained | 5, 8.5, 11 m/s minima; preserve faster existing animation motion |
| Crouch is a distinct stationary weapon state | Short collision volume; no generic crouch locomotion by default |
| Object bullet impulse 4 normalized momentum units | 200 N s lab prop shot impulse |
| Player damage factor .33; NPC weakness from stats | Shared damage path with separate configurable modifiers |
| BurstTyre records persistent wheel status | Independent per-wheel damage state and physical handling changes |
| Health 250 fire threshold, 5000 ms burn timer | Configurable five-second terminal vehicle state |
| Camera zoom offsets .25/1.5/2.9 over follow base2 | Three foot follow distances 2.25/3.5/4.9m |
| Handling acceleration multiplier .4, normalized time conversion | Dimensionally mapped force/brake fields; full transmission remains open |

The supplied sprint clip advances roughly 14.67 m/s on average, sometimes faster. Source jump minima are not speed caps. This build preserves faster prelaunch motion rather than silently reducing it; original runtime comparison is required to judge the supplied clip's fidelity.

Godot 4.7.2 Jolt source confirms that direct-body contact positions and normals are in world space despite their API names. Removing a second basis transform fixed rotation-dependent damage. Point-velocity levers subtract body origin and the global-axis COM offset. Vehicle damage snapshots pre-contact velocity, suppresses repeated manifold damage and re-arms after separation. Pedestrian contact reactions re-arm independently, so later impacts can injure or kill a downed actor while resting contact does not.

## Architecture and update rules

Command producers feed shared actor components. CharacterMotor owns physical phase/stance gates; ActorActionState owns pose priority and animation clocks. DamageEvent carries amount, point, normal, direction, source and part. BallisticTrace resolves hit regions, then receiver modules own response. PropProfile, VehicleDamageProfile, StanceProfile, WeaponProfile, SeatDefinition and VehicleVariant keep configuration separate from behavior.

DriveVehicle owns its Jolt body, wheels, damage and seats; VehicleTransition owns transactional actor transfer. A committed driver receives commands; explicit external control ownership is respected. Presentation subscribes to damage state rather than applying damage. Discrete gameplay clocks use fixed physics ticks; rendering does not advance them.

## Validation and limits

All eight suites pass: **260 Godot/Jolt assertions**, including 53 component/system checks and 13 foundation checks. Python parser/converter/packager tests and five render-rate comparisons are reported separately in VALIDATION.md. Systems renders inspect crouched aim/fire, moving prop, tire/glass states, passenger position, fire and labeled fixtures. These are selected checks, not a full manual playthrough or original-runtime comparison.

The extra firearm scenes, weapon-specific IFP blocks, STINGER/LANDSTAL models and complete IMG are absent from the current attachment. `assets/expansion_requests.json` lists exact requested roles. Fire/reload/crouch actions use tuned procedural layers when original clips are absent. No full ragdoll, full transmission, articulated tire contact, cinematic/top-down camera, jacking/locks, crowd/traffic/world streaming, original runtime parity, browser playback or target-GPU performance validation is claimed.

Primary evidence: [pinned reVC](https://github.com/mrxenginner/reVC/tree/a26fff4af555a8a425ac9f17d1dd718d00d1f942), [Godot Jolt direct state](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/objects/jolt_physics_direct_body_state_3d.cpp), and [Jolt contact listener](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/jolt_physics/spaces/jolt_contact_listener_3d.cpp).

Source review and target implementation occurred in one workflow. This is not an independently staffed clean-room certification.
