# Stories assets, combat and vehicle revision

This revision replaces the active animation set with VCS core and PS2-converted weapon clips and LCS bike clips from the supplied pack. All 781 original clips across 44 IFP blocks are retained under unique namespaces. Another 387 aliases select the active set; F4 therefore displays 1,168 entries. Miscellaneous, facial and cutscene clips are available for inspection, not all connected to gameplay. Missing facial bones remain explicitly unmapped.

The private build contains 32 native model scenes and 71 textures: the original four scenes/25 textures plus 28 scenes/46 textures selected from models.zip. The additions include the supported weapon models, PCJ600, Sanchez, Faggio, Freeway, Stinger and Landstal. No full IMG extraction or ASI execution occurred. The new selection reads 1,384,856 bytes of DFF/TXD payloads; exact ranges/hashes are in assets/stories_model_selection.json. Previously selected source models and PNGs remain unchanged.

## Delivered behavior

- Shared player/pedestrian components now support retaliation or fleeing based on aggression/fear. The same melee controller applies to both.
- Melee consumes planar animation root motion through the collision motor, sweeps the animated hand/weapon tip, checks occlusion and deduplicates victims. Clips without useful root translation permit controlled attack shuffling. Punch strength is reduced; player attack statistics are not multiplied into source base damage. The balancing scale is an intentional departure.
- Twelve firearm and twelve melee entries, including unarmed, use exact models and configurable clip lists. Chainsaw presentation currently uses discrete strikes rather than continuous cutting simulation. Projectile/area weapons remain unsupported.
- Hip fire raises the weapon arm without steering the moving body toward the camera. Targets outside the configured arm cone are rejected. Native reload and shotgun pump recovery own upper-body articulation; aim/fire layers cannot overwrite them. Support-grip poses and muzzle offsets are separate Resources.
- Cars have localized panel health, damaged mesh variants, detachable physical panel fragments and separate engine health. Jolt contact points, bullets and melee select the struck region. Repair restores parts; expired debris cannot create duplicate fragments.
- Flat tires retain full-size wheel meshes. Reduced support radius, grip and additional drag make them sink and slide. This uses contact rays rather than deforming tire-volume collision.
- Car launch response is stronger. Speed-dependent steering curvature and ground-contact anti-roll reduce routine cornering flips while leaving airborne and severe impacts physical.
- Four bike types use two suspension/contact solvers, independent wheel spin/fork steering, inertia-aware balance, configurable lean and LCS mount/ride/lean/dismount clips.
- Sideways/upside-down exits find supported upright capsule destinations and use crawl animation. The supplied right crawl is mirrored for left exits. A pelvis anchor prevents animated root translation from shifting the actor twice; crawl presentation returns to the world-upright frame instead of applying the car roll throughout the source animation. Moving exits revalidate a path, release the seat once and launch the physical reaction body with vehicle momentum; the released car coasts. Passenger bailout preserves another driver's control.

## Evidence categories

### Source confirmed

Reviewed reVC commit [a26fff4](https://github.com/mrxenginner/reVC/tree/a26fff4af555a8a425ac9f17d1dd718d00d1f942), including PedFight.cpp, PedAI.cpp, Bike.cpp, Automobile.cpp, DamageManager.cpp, Ped.cpp, PlayerPed.cpp, CivilianPed.cpp and CarCtrl.cpp.

FightHitPed applies the player's unarmed base damage without the NPC attack-stat multiplier. Its damage calculation includes a random 2-or-3 factor, an added unit and unarmed scaling. PedAI distinguishes crawl, normal get-out and moving jump-out paths. DamageManager stores separate wheel, panel, light and door states. Bike code uses rider lean and two-wheel support/balance. These are behavioral findings, not imported implementation.

### Target runtime confirmed

The production scenes run on exact Godot 4.7.2 Stable with built-in Jolt. Ten suites exercise 435 assertions, including actual pedestrian retaliation, melee contact with car geometry, localized collision damage, detach/repair, flat-tire settling, cornering, tilted exits and all four bike mount/drive/exit loops. Five local render-rate replays agree at sampled physics ticks. Nine selected software-rendered states were reviewed. See VALIDATION.md and tests/*results.json.

This label describes the new Godot runtime. No original executable was run, so none of these results establishes original-runtime equivalence.

### Inferred or intentionally tuned

Melee balancing, grip IK, bike balance gains, launch multiplier, cornering limit, crawl path and impact lift are calibrated approximations. Detailed original vehicle trajectories, attack contacts and animation/root timing still require paired runtime recordings. Gameplay, visual and performance parity remain separate targets. There is no independently staffed clean-room audit.

## Ownership and extension

| Module / Resource | Owns |
| --- | --- |
| RigProfile / RigBinding | Source bone IDs, canonical names and cached per-clip channel-index bindings |
| ReferenceMotion / SkinnedMotionVisual | Fixed-tick phase/root sampling and independent per-actor skeleton presentation |
| MeleeController / MeleeProfile | Strike windows, collision-swept displacement, animated tip sweep and balance |
| WeaponActionCatalog | Clip combinations, native muzzle/tip points and pose Resource selection |
| PedBrain | Intent, fight/flee decisions and cooldowns; no duplicate movement/combat implementation |
| VehicleParts / VehiclePartProfile | Local part state, visual variants, fragmentation and repair |
| VehicleStability | Speed-dependent steer cap and supported anti-roll |
| BikeDynamics / BikeProfile | Two-contact balance, lean and native fork/wheel presentation |
| VehicleExitSolver / VehicleTransition | Clearance and transactional occupancy/control transfer |

To add a melee weapon, import its exact model, add a loadout/DAT entry and add clip candidates/tip calibration in tuning/weapon_actions.tres. No actor-class branch is required. Configure damage/recovery/root limits in tuning/melee.tres. Add a bike variant Resource with handling, model, seat and clip prefix; the actor and input pipeline remain shared. For larger worlds replace the arena's direct-child lookup with an owned spatial registry.

## Rebuild supplied assets

The private ZIP already contains native resources. Conversion is only needed when replacing assets. Public git contains the importer and selection manifests but excludes supplied source/derived artwork.

1. Import the original base gameplay tables and original player/Idaho/Colt45/trashcan assets using the existing import tools documented in IMPORTED_ASSETS.md and MODEL_AND_DISPLAY_MILESTONE.md. The Stories importer requires pedstats.dat, handling.cfg, pedgrp.dat and ped.dat already in assets/local_source.
2. Obtain external [DragonFF at 54baca8](https://github.com/Parik27/DragonFF/tree/54baca8ea2ed95fe5a86917f44399ce677379c59) and Pillow. Its implementation is not bundled.
3. Run:

```bash
python3 tools/import_stories_assets.py --models-zip /path/models.zip --animations-zip /path/stories-pack.zip --dragonff /path/DragonFF
Godot_4.7.2_stable --headless --path . --editor --import --quit
Godot_4.7.2_stable --headless --path . --script res://tools/build_stories_library.gd
Godot_4.7.2_stable --headless --path . --script res://tools/build_model_scenes.gd -- --source=stories_models.json
python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable
```

The public import CLI was reproduced in isolation: five portable outputs and all 46 new PNGs exactly matched the build. Source IFP contains 294,083 keys over 17,666 channels. Twenty-one keys have duplicate timestamps in VCS buddy_fire; native curve construction deterministically keeps the last value at each timestamp, yielding 294,062 keys. Raw source keys and IFPs remain retained. Native round-trip tests compare every resulting channel key. Two Lowblow channels share a display name but distinct IDs; bindings use channel indices/IDs to avoid silently selecting the first duplicate.

## Remaining gaps

No full world, missions, traffic, save system, multiplayer or mod loader. Physical pedestrian reactions use one solid torso rather than an articulated ragdoll. Tire contacts are rays; no wheel angular inertia or relaxation model. Bike tuning is a prototype rather than original parity. Glass/panel breakage uses state changes and bounded fragments, not fracture simulation. Some source facial/cutscene bones are absent. Browser import/playback and hardware GPU performance remain unverified. All miscellaneous clips are preserved, but bespoke gameplay states for each clip are not implemented.
