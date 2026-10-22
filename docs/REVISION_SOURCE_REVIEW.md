# Animation, interaction and impact revision

The current [motion revision](MOTION_REVISION.md) supersedes the initial impact proxy, pose sampling and seat behavior below.

Reference: [mrxenginner/reVC at a26fff4af555a8a425ac9f17d1dd718d00d1f942](https://github.com/mrxenginner/reVC/tree/a26fff4af555a8a425ac9f17d1dd718d00d1f942). This revision reviews the relevant action paths in addition to the earlier system register in BEHAVIOR_SPEC.md. It does not establish complete source coverage or runtime parity.

## Source Confirmed

| Mechanic | Evidence at pinned commit | Requirement extracted |
| --- | --- | --- |
| Locomotion and stop commitment | [PlayerPed.cpp, SetRealMoveAnim](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PlayerPed.cpp#L316), including phase-dependent stop selection near line 450 | Synchronize walk/run phase. Sprint release chooses a foot-specific stop and locks turning through that action. |
| Partial animation channels | [AnimManager.cpp, descriptors and BlendAnimation](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/animation/AnimManager.cpp), [RpAnimBlend.cpp](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/animation/RpAnimBlend.cpp) | Movement and partial weapon associations can coexist; full-body single-clip playback loses observable behavior. |
| Weapon blocks | AnimManager.cpp, aColtAnimations / aRifleAnimations / association definitions | Colt fire/reload use the separate `colt45` block; rifles use `rifle`. `ped.ifp` alone does not supply all gun actions. |
| Death | [Ped.cpp, SetDie / SetDead](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/Ped.cpp#L7027); PlayerPed.cpp death control near line 1742 | Dying and dead are separate states. Repeated damage must not restart death. Completion must retain the terminal pose rather than loop into standing. Source player dead-state timing also has a 4000 ms gate, which this lab does not reproduce. |
| Gun cadence | [WeaponInfo.cpp, LoadWeaponData](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/weapons/WeaponInfo.cpp#L220) | Animation frames use 30 Hz units. Most non-shotgun entries override raw fire rate using the loop span; applying only the raw DAT rate was incomplete. Final cadence also depends on action policy. |
| Door action timing | [Automobile.cpp, ProcessOpenDoor](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/vehicles/Automobile.cpp#L4654) | Opening uses 0.41–0.89 s, inside closing 0.20–0.45 s, get-out opening 0.06–0.43 s, outside closing 0.10–0.23 s. Inside `CAR_closedoor_LHS` and outside `CAR_close_LHS` are different clips. |
| Swinging doors | Automobile.cpp, ProcessSwingingDoor near line 5348 | Door state can respond to physical motion in addition to animation-driven opening. |
| Vehicle impacts | [PedFight.cpp, KillPedWithCar](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PedFight.cpp#L3624) | Relative direction, impact and actor state affect knockdown/death. Falling/dying/dead actors receive special handling; an upright capsule should not continuously block and relaunch the car. |
| Heavy weapon sprint restriction | PlayerPed.cpp near lines 908 and 1554 | The source restricts sprint with some heavy weapons. The requested ability to sprint with every gun is an intentional option, enabled in actions.tres. |

No reference source files are shipped in this project. Findings are requirements; the implementation uses per-actor action state, pose channels, Resources, swept queries and Jolt joints.

## Implementation contracts

| Mechanic | Inputs → outputs | Update order and states | Timing / dependencies |
| --- | --- | --- | --- |
| Movement/action blend | Command, root curves, weapon action → motor displacement and composed pose | Motor owns planar root displacement; phase-synchronized walk/run poses crossfade to start/stop/jump/transition poses. Masked upper actions and aim IK follow; pelvis/legs retain locomotion. | Physics 60 Hz; controlled player pose sampled once per physics tick; actions.tres blend duration 0.16 s. |
| Aim/fire/reload | Aim, pitch, shot events, reload clock → upper-body clip or procedural arm/recoil pose | Locomotion → action crossfade → upper-body crossfade → arm aiming. Reload target blends in/out separately. | Native weapon action used when available; missing blocks use explicit IK/recoil/reload fallbacks. |
| Death/recovery | Damage or vehicle impact → dying/dead or down/getting_up/alive | Reaction preempts normal movement and weapon control. Death is clamped once; get-up requires a clear standing capsule. | Clip duration, knockdown hold and collision clearance; no ragdoll. |
| Weapon selection | Slot/next/previous command → profile, magazine, reserve, presentation | Save outgoing ammo; select incoming slot; cancel reload; retain outstanding shot cooldown. | Three test slots; each slot owns ammo. Source Colt/M4/Shotgun when DAT is available, lab profiles otherwise. |
| Entry | Interaction + clear approach + stopped upright car → reserved/committed seat | On foot → opening → get-in → inside close → driving. Actor collision disabled during transition; only a reservation can commit. | Imported clip durations are added for the total, rather than using get-in alone. Door motor starts at its contact time. |
| Exit | Stopped car + supported clear volume/route → on-foot control | Driving → get-out → outside close → commit. Recheck the selected side at commit. Death releases ownership; invalid vehicle recovers. | Imported get-out plus outside-close duration. Blocked exits preserve driver ownership. |
| Physical door | Desired open/latch + chassis acceleration/contact → door angle | Unlatched RigidBody3D with HingeJoint3D motor/limits; closed latch removes the joint and follows chassis. Reset also resets both doors. | Jolt hinge around vehicle Y; prototype mass, limits and motor values in doors.tres. No unsupported Jolt joint softness tuning. |
| Run-over | Predicted chassis shape sweep + relative speed → bounded impulse, damage, knockdown/death | Probe before next physics solve; standing capsule yields to a solid Jolt torso; no vehicle collision exception is added to the torso. | Speed threshold, quadratic damage, impulse cap and cooldown are target tuning, not converted source units. |
| Presentation | Life, occupancy, equipped profile, health → HUD and mesh selection | HUD shows life state/slot/ammo and respawn prompt; reticle requires active upper action. Model roles are independent Resources. | Original world textures disabled by default; ground, road, steps and targets retain plain colors. Long-gun geometry is an explicit primitive fallback. |

## Runtime Confirmed

Godot/Jolt runtime tests validate the target contracts listed in tests/revision_results.json, latest_results.json, imported_results.json, presentation_results.json and native_action_results.json. Native tests use the uploaded converted skin and clip library. Selected software-OpenGL captures cover the HUD and five action/door states. These are target-runtime observations. No original-game executable was run during this revision. Do not label them reVC runtime confirmation.

## Inferred / still to validate

- Native bone masks preserve leg motion under aim; gun-hand orientation is checked at three pitches. The terminal death skin is measured at 1 cm above the test floor after a cached per-mesh correction. Selected aim/reload/death/door/entry poses were rendered and reviewed. Full foot-contact, hand-to-door and seat/root calibration across every clip remain open. Uploaded assets remain outside public git.
- IK reach, recoil, blend rates, aim movement multiplier, shotgun pellet count/spread and physical door coefficients remain target tuning. They are not measured reVC equivalents.
- Lower-body aim locomotion currently retains the walk/run cycle and changes travel direction; complete directional strafe/backstep clip selection and foot sliding calibration remain open.
- Source turn/root policy is retained from the previous milestone, but full tank-like feel requires original-runtime input/heading/displacement traces. No new air steering was introduced for imported movement.
- Weapon-specific IFP blocks are needed for original firearm firing/reloading animation. Existing converted `ped_library.res` is reused; no assets were regenerated here.
- No passengers, carjacking, locks, damaged/broken doors, door detachment, jumping from moving cars, per-bone damage selection or ragdoll is implemented.
- Car suspension, tire/impact calibration, crowd navigation and reference-runtime performance comparison remain open.

## ZIP repair

`tools/package_project.py` emits every parent directory before its files, including the root. Tests simulate the strict extractor that does not create parent directories for files. CRC and SHA-256 checks verify bytes. `tools/rebuild_test_build.py` can fix the old ZIP without converting or recreating any assets:

```bash
# Layout repair only; every original project file remains byte-identical.
python3 tools/rebuild_test_build.py --input old-build.zip --output repaired-build.zip

# Apply this revised source while retaining all old private asset files.
python3 tools/rebuild_test_build.py --input old-build.zip --project . --output revised-build.zip
```

The supplied 217-file ZIP has been reused for the revised asset-inclusive build, without converting any assets. The packager verifies the preserved bytes. Web-editor ZIP extraction has been simulated; an actual browser import and an exported HTML runtime have not been validated. The ZIP directory fix alone makes no claim about web-export backend support.

## Asset-inclusive follow-up

The original archive contains 217 files and zero directory entries. All 91 private asset/support files are retained byte for byte, including converted models, textures, clips, source inputs and prior images. The revised archive overlays the updated public source and writes explicit parent directories.

Targeted native checks exposed a terminal death skin 13 cm below the floor. SkinnedMotionVisual now computes and caches the terminal skinned minimum once per reaction clip, uses a floor ray and blends a capped visual correction. Actor collision ownership remains in CharacterMotor. Clearance, maximum lift and settle rate are ActionProfile fields; standing/preview poses reset the offset. Reaction support is recalculated per physics tick.

The follow-up also holsters equipped geometry during seat transitions, restores it on foot, removes the false enter prompt while entering/exiting and makes shared light energy configurable to retain readable plain arena colors. Original weapon-specific fire/reload blocks are still absent; procedural fallback actions are explicitly retained.
