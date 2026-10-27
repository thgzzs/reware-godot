# Player controller audit and Build 13

Reviewed on 2026-10-27. Implementation base: `gameplay/carry-landing-fall12`,
`c422aea249b9c01e4c431f9496d6725bc255643c`. The repository default `main`
was Build 8. Using Rev12 preserves the intervening movement, carry, recovery,
touch and vehicle changes.

The supplied `Harbor-Rev12.apk` is 75,504,241 bytes, SHA-256
`d88e33291f3eaf345e581be2e7b8d9c17011edf523516e652ba1969a7850b068`.
This matches the repository's Build 12 validation record. Its exported native
models, texture imports, animations and gameplay Resources were recovered for
local validation without model or animation reconversion. These private derivatives remain excluded
from Git. Original DFF/PNG conversion inputs and the signing key are absent.
For re-export, the two runtime-only database/rig remaps were saved as authoring
Resources. All 71 texture source images were reconstructed from the supplied
runtime imports; their decoded RGBA is unchanged. Sixty match original PNG
checksums exactly. Eleven contain the original importer's alpha-border processing,
so original source-byte provenance cannot be reconstructed for those images.
The source PNG provenance check remains explicitly skipped.

## Scope and execution flow

The static inventory covers all 147 project GDScripts (103 runtime scripts,
10,954 total script lines at inventory time), functions, explicit resource paths
and physics-query call sites. See `controller-audit-inventory.json`. Execution
tracing and runtime tests cover the shared actor, input, presentation, weapons,
damage/recovery, camera, vehicle transaction and mobile paths. This is a source
and regression audit; exhaustive original-game state equivalence is unverified.

| Owner | Actual source of truth and execution boundary |
| --- | --- |
| `core/input_source.gd` | Samples keyboard/mouse and mapped gamepad actions once per physics tick into `GameplayCommand`; `TouchIntent.apply` merges touch axes, held counts and one-shot edges. |
| `world/arena.gd` | Composition root. Blocks modal input; resolves interactions; applies current camera look; ticks vehicle transaction; advances weapon clocks; ticks actor; latches vehicle command; updates camera; solves reticle target; samples player pose; resolves melee and gunfire. |
| `actors/character_motor.gd` | Sole standing/on-foot collision owner. Converts camera-relative intent, gates launch/landing, chooses root travel, owns `drive_velocity` and `velocity`, executes bounded sweeps/steps/support recovery. Mesh motion never applies another locomotion displacement. |
| `actors/character_steering.gd` | Owns movement/aim heading intent and bounded turn; native action/air/landing restrictions precede turns. Actor `facing` is authoritative; `Visual.rotation` presents it. |
| `animation/reference_motion.gd` | Native gait phase, blend intensity, cycle and sampled root displacement. No separate AnimationTree exists in the project. `SkinnedMotionVisual` samples existing animation Resources and applies upper-body layers/IK. |
| `ActorActionState` | Action clocks, life state, hit/reload/fire/melee presentation permissions. Weapon controller owns ammo, cadence, reload transaction and inventory. Switching now explicitly clears the old upper action. |
| `ActorFallState` / `ActorLandingState` | Per-instance trajectory evidence and one-shot damage calculation; a single landing clock controls compression/follow-through. Motor supplies collision impact evidence and commits health loss. |
| `PedHealth` / `PedReactionBody` | Health owns depletion. On knockdown, the standing capsule yields collision ownership to the existing Jolt torso; recovery validates standing volume. No articulated ragdoll or armor implementation exists. |
| `VehicleTransition` / seat map | Reservation, approach/alignment, entry, occupancy, exit/bailout and cancellation. Seated player motor is disabled. Seat ownership commits before driver input; exit is revalidated before on-foot restoration. |
| `FollowCameraRig` | Orbit yaw/pitch, anchor lag, follow/aim/bonnet distance and sphere obstruction. Current yaw reaches motor in the same physics tick. |
| `MobileControls` / `TouchIntent` | Finger-role ownership, context/layout, focus/menu clearing and intent. Existing touch UI and command integration are retained. |

No autoload, native module or GDExtension supplies a competing player controller.
Godot's built-in Jolt backend remains selected. No save/load system was found.
No player hierarchy, mesh, animation library, vehicle physics or touch layout was
replaced. No files were removed.

## Exact reVC reference and comparison

`mrxenginner/reVC` was cloned and pinned to
`a26fff4af555a8a425ac9f17d1dd718d00d1f942`. Its API branch enumeration returned
one branch, `miami`, at that commit. No other fork was substituted. Build flags
including `FREE_CAM` and `FIX_BUGS` select different source paths; no original
runtime/configuration was available for trajectory or timing captures.

| Behavior / source | Rev12 finding and classification | Result |
| --- | --- | --- |
| [PlayerControlZelda, PlayerPed.cpp:1491](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PlayerPed.cpp#L1491) | Camera-relative heading and movement intensity exist. Source scalar rises by `0.07 * timestep` and resets on release; target smooth release is intentionally modernized. | Classic uses the verified rise and immediate scalar release; shipped modern release remains selectable. |
| [SetRealMoveAnim, PlayerPed.cpp:317](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PlayerPed.cpp#L317) | Native walk/run/sprint and alternating sprint-stop clips already work. Source below-run intensity chooses full walk association; target blends idle at small analog deflections. | Classic selects full walk below the run blend and retains sprint-stop heading commitment. Modern analog presentation stays gradual. |
| [CalculateNewVelocity, Ped.cpp:1415](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/Ped.cpp#L1415) | Root displacement drives motion correctly. Target speed-dependent turn caps/reversal braking intentionally differ from source heading-rate clamp. | Classic turns at normalized source heading rate. Modern bounded pivot/hysteresis remains available. |
| [Timer.cpp:150](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/core/Timer.cpp#L150), [Physical.h:12](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/entities/Physical.h#L12) | Existing 50-normalized-ticks/second conversion is correct. | Retained: gravity `0.008 * 50² = 20 m/s²`; velocity values multiply by 50. |
| [SetJump / FinishLaunchCB, Ped.cpp:9168](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/Ped.cpp#L9168) | Animation windup and two clearance spheres already match the source design. Player impulse `8.5 / 70 * 50 = 6.0714286 m/s` is correct. Binary sprint launch selection loses partial blend contribution. | Classic horizontal launch floor uses actual sprint blend (`0.17 + 0.05 * weight`) or run blend (`0.10 + 0.07 * weight`), retaining greater existing planar speed. |
| [PlayerControlZelda, PlayerPed.cpp:1534–1578](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PlayerPed.cpp#L1534) | Buffer, ledge grace, air-steering and opposite-input momentum cancellation are deliberate Rev9–12 additions. Heavy weapon restrictions were absent. | Classic requires a grounded input edge, disables buffer/grace/air steering/air braking, and enforces the source heavy bit for jumping and sprinting. Source obstruction nudge is still unsupported. |
| [WeaponInfo.h:19](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/weapons/WeaponInfo.h#L19) | Target `heavy` is weapon-name tuning; it is not the original `1 << 9` flag. | Imported flags now persist in `WeaponProfile.source_flags`. Classic consumes the actual bit; authored profiles with no source bits retain a documented fallback. |
| [UseSprintEnergy, PlayerPed.cpp:204](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PlayerPed.cpp#L204) | Tap-speed bonus and release grace differ from the inspected held-button sprint source. Stamina/training is incomplete. | Classic disables tap multiplier/release grace. Stamina, tired idle and training remain open. |
| [SetLanding, Ped.cpp:5338](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/Ped.cpp#L5338), [ProcessEntityCollision, Ped.cpp:2918](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/Ped.cpp#L2918) | Target impact/drop qualification, compression/stride, collapse and quadratic damage are intentional adaptations. Source uses additional planar/vertical and surface-specific rules. | Existing collision and one-shot damage retained and regression-tested. Full fall/landing parity remains open in both profiles. |
| [AnimBlendAssociation.cpp:169](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/animation/AnimBlendAssociation.cpp#L169) | Target root integrator mishandles a tick crossing multiple loops: residual sample is clamped and complete loops are lost. Buggy. | Root integration now counts complete cycles and a partial segment; additive displacement is tested. This is a stability correction, not a claim to reproduce source frame bugs. |
| [Cam.cpp:1347](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/core/Cam.cpp#L1347), [Camera.cpp:251](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/core/Camera.cpp#L251) | Target shoulder aiming/orbit and sphere obstruction are modernized. Mouse/touch deltas work; no gamepad bindings/rate channel existed. | Added a right-stick angular-rate channel integrated by physics delta; existing look deltas keep their semantics. Original automatic recenter/mode set remains incomplete. |
| [Pad.cpp:2318](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/core/Pad.cpp#L2318), [GetSprint:3097](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/core/Pad.cpp#L3097) | Shared command routing and touch ownership are structurally sound. Native aiming multiplied analog magnitude a second time after root selection. Buggy. | Heading normalization removes duplicate scaling; analog aim, action-map idempotence and injected joypad motion are tested. No touch redesign. |
| [Weapon.cpp:162](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/weapons/Weapon.cpp#L162), [PedFight.cpp:256](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PedFight.cpp#L256) | Existing cadence, two-stage cover-aware fire and melee window systems work. One target query result was unused. Switching could retain the previous gun's upper action. | Removed one unused ray query per eligible fire attempt and clear old fire/reload presentation on equip; cooldown and inventory ownership retained. |
| [PedFight.cpp:2651](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PedFight.cpp#L2651) | Player combat damage scaling `0.33` is already faithful. Armor/immunities/source damage categories are unsupported. | Existing health/death and recovery systems retained and regression-tested. |
| [PedAI.cpp:4147](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/peds/PedAI.cpp#L4147), [Vehicle.cpp:1724](https://github.com/mrxenginner/reVC/blob/a26fff4af555a8a425ac9f17d1dd718d00d1f942/src/vehicles/Vehicle.cpp#L1724) | Target reservation/commit, door alignment, revalidated exit and bike bailout are integrated; exact source jacking/lock/contact marker rules are incomplete. | Transaction and vehicle dynamics retained; regression coverage includes entry, driving, exit, ejection and recovery. |

Additional source inspection included `PedType.cpp` (`CPedStats` lives there,
not in a `PedStats.cpp` file), `PedIK`, `CPhysical`, entity/world ordering,
animation manager/associations, vehicle, automobile and bike interfaces. Existing
`BEHAVIOR_SPEC.md` records the earlier source evidence; this report records the
current implementation and does not turn prior runtime reports into new tests.

## Selecting behavior and controls

The shipped player profile remains `tuning/movement.tres` (Rev12 modern policy).
Set the arena's existing-script exported `player_movement_profile` to
`tuning/movement_classic.tres` **before scene initialization** to select classic
rules. Both profiles use the same motor, sweeps, presentation and weapon paths;
there is no parallel controller or settings UI. The classic profile defines the
source reference for the rules implemented above. It does not establish complete
Vice City parity for unsupported camera, stamina, fall, asset or combat behavior.

Gamepad defaults: left stick moves/drives, right stick looks, triggers aim/fire,
A jumps/brakes, Y enters/exits, X reloads, B crouches, left-stick press sprints,
right-stick press cycles the camera, shoulders select weapons. New movement
actions use a 0.2 deadzone; existing configured actions retain their deadzones.
Keyboard, mouse and touch keep their controls. Hardware gamepad ergonomics are
unverified; injected joypad events exercise the production input path.

## Changes and validation

Important changed files: `actors/character_motor.gd`, `character_steering.gd`,
`sprint_state.gd`, `animation/reference_motion.gd`, `imported_asset_setup.gd`,
`combat/weapon.gd`, `core/input_source.gd`, `command.gd`, `camera/follow_rig.gd`,
`world/arena.gd`, and existing movement/weapon/camera profile scripts.
Added `tuning/movement_classic.tres` and focused controller/profile runners.
No scene hierarchy, model/animation payload or decoded runtime texture pixels
changed. Android preset package,
application label, ARM32/ARM64 configuration and permissions are preserved;
version code advances to 13, version `0.8.2-controller13`.

`tools/export_android.py` now supports debug export using the same preset,
requires committed gameplay/configuration, embeds the actual Git commit into
`assets/build_revision.json`, verifies it in the APK, and restores/removes the
temporary stamp afterwards. Native authoring-resource preflight and packaged
database/texture checks prevent a partial APK from being accepted when only
runtime remaps were restored. The payload smoke check now fails immediately
for missing native Resources. Existing release signing remains supported. Missing
original PNG/DFF fixtures are now explicitly skipped by the two provenance tests
whose previous metadata-only guards incorrectly allowed them to run.

Executed with official Godot **4.7.2.stable.official.ed1daf0bf** and built-in
Jolt. Engine archive and export templates match official SHA-512 sums.

| Check | Actual result |
| --- | --- |
| Project import | Passed; no script/resource errors. |
| Script scan | 146 scripts loaded/instantiable, excluding the scan runner itself. |
| Full production validator | 903 assertions passed across 23 suites. |
| Final expanded controller suite | 28 passed; replaces the 26-check controller run in the full validator, for **905 distinct passing assertions** across the same 23 suites. |
| Final touch suite | 34 passed after the input changes. |
| Python | 23 discovered: 14 passed, 9 explicitly skipped for absent original source fixtures. The two provenance errors observed before correcting fixture guards are not counted as passes. |
| Render-rate replay | All five cases passed: 30/60/120/144/variable caps, 60 Hz physics; player position, velocity, action/shot and pose traces match. Maximum vehicle drift 0.00000042 m. |
| Diff / Python syntax | `git diff --check` and Python compile checks passed. |
| Android installation / hardware input / GPU / thermals | Not executed; no Android device or emulator supplied. ADB daemon startup is unavailable in this host. |
| Original executable comparison | Not executed; no reference runtime/input traces supplied. |

Coverage includes idle, walk/run/sprint, reversals, launch/apex/land/falls,
graded slopes, stairs, wall/ceiling contacts, skin/layer changes, aim/fire/melee,
weapon switch/reload, damage/death/respawn, car/bike seat transactions, bailout,
recovery and simulated multi-touch. These are bounded acceptance scenarios,
not an exhaustive arbitrary-world or hardware matrix.

Three alternating before/after CPU samples used the same native scene, 240 ticks
per scenario after warmup, compared to the untouched Rev12 worktree:

| Scenario | Before median mean / p95 | After median mean / p95 |
| --- | --- | --- |
| Idle | 328.25 / 524 µs | 304.27 / 450 µs |
| Run | 409.23 / 647 µs | 380.87 / 501 µs |
| Aim/fire | 369.00 / 590 µs | 357.88 / 530 µs |

See `controller-performance.json` for all samples. This small local CPU sample
showed no regression; variability prevents assigning these reductions to one
change or predicting Android FPS. Telemetry excludes the Jolt solver, renderer
and GPU. The directly verified reduction is one unused aim ray per eligible
fire attempt. No speculative physics-query expansion or visual quality reduction
was made.

## Remaining issues

- Original runtime fidelity remains unverified. Current supplied Stories clips
  and gameplay data can differ from original VC assets and flags. Absolute native
  walk/run/sprint speeds are asset-derived; no guessed global m/s replacements
  were introduced.
- Classic sprint stamina/training, tired idle, exact blend rates, source jump
  obstruction nudge, moving-support velocity inheritance, full surface-aware
  fall damage, landing callbacks and original camera recenter/modes remain open.
- The existing camera sweep can miss initial pivot overlap. A dedicated embedded
  pivot/depenetration policy still needs validation; it was not replaced here.
- Armor, full targeting/lock behavior, projectile/continuous weapon semantics,
  jacking/locks, exact door/hand markers, original audio, save/load and full-world
  navigation/population are absent or incomplete in the existing framework.
- Broad Android lifecycle, GPU, thermal, real touch/gamepad and installation
  validation require hardware. Native headless tests and APK payload tests do
  not substitute for them.
- The new debug signing identity differs from the supplied APK certificate.
  Android cannot install it over the differently signed existing application.
  A release upgrade requires the original private key; uninstalling the existing
  app may remove its local data. No package-ID change is used to hide this.

Git delivery and final APK metadata/checksum are recorded separately in the
delivery manifest after the source commit is published and the build verified.
