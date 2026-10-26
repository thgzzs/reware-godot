# Gameplay revision 11 — traversal, supported weapon carry, bike recovery

Source base: `8c6546fb80cb1f928e65cfacb466409cdb1bd540` (Build 10).
Target: Godot **4.7.2 Stable**, Jolt; version `0.8.0-gameplay11`.

## Reference investigation

**Source confirmed:** reVC commit
`a26fff4af555a8a425ac9f17d1dd718d00d1f942`, `src/peds/Ped.cpp`:

- `SetJump` / `FinishLaunchCB` (9168 / 9182): launch association, clearance checks,
  then airborne motion; heading is held through launch.
- `SetInTheAir` (5297): uses `ANIM_STD_FALL_GLIDE`, independent of gun actions.
- `InTheAir` (5315): probes downward; landing selection depends on approaching
  support. A distant descent is distinct from landing.
- `SetLanding` (5338): fades incompatible partial associations, selects a landing
  reaction, and attaches `PedLandCB`.
- `PedLandCB` (3960): completes landing ownership and restores the previous state.

**Source confirmed:** [Classic Axis](https://github.com/gennariarmando/classic-axis),
commit `74156ccc3c4f4f610fef5908d75c38f7f535c3c3`, `source/Main.cpp`:
`RotatePlayer` (547) separates camera-relative rotation policy from movement;
aim handling excludes conflicting jump/sprint inputs. The VC jump-failure fix
(117) is an executable byte patch, not a portable platforming implementation.
Its behavioral intent informs action exclusivity; no addresses or engine hooks
are copied into Godot, and no Classic Axis runtime-parity claim is made.

**Asset inspection before workspace maintenance:** the supplied Stories
`FALL_fall` is a forward ground roll; `FALL_glide` is the falling pose.
`JUMP_land` lasts approximately 0.20 s, `FALL_land` 0.567 s. Geometry at multiple
clip phases was inspected using CPU skinning. These observations do not replace
new validation with the private assets after restoration.

## Root causes and implementation

1. Ordinary long falls previously changed into the rotating Jolt torso **before
   contact**, while sampling `FALL_fall`. Free fall now retains the character
   sweep and looping `FALL_glide`. Only a measured support impact can start a
   survivable roll or severe Jolt tumble. Bike/combat ejections keep their existing
   physical airborne paths. Environmental damage is still calculated once from
   relative closing speed at support contact.
2. The short moving landing could look like jumping directly into running.
   `ActorLandingState` now samples contact compression (`FALL_land`), then blends
   into the spatial `JUMP_land` stride. One monotonic clock drives both pose and
   swept root travel. Confirmed jumps retain a landing even when a higher surface
   leaves little downward travel. Hard moving impacts select the roll on contact.
3. Rifle/shotgun hold formerly applied only while idle, and the generic carry
   pose did not guarantee a support-hand grip for every imported model. The five
   supported long guns now sample their own authored pre-fire **two-handed** pose
   while idle, starting, walking, running and stopping. A configurable shared
   torso rotation lowers the carry; both hands retain their authored relationship,
   and the neck compensates to preserve head direction. Aim/reload/fire override
   carrying. Sprint, crouch, reactions, landing, bike seating and death keep their
   exclusive poses. Missing native ready poses retain the configured fallback.
4. A bike can enter the standing volume after initial get-up clearance succeeds.
   Recovery now revalidates vehicles during get-up. An obstruction returns control
   to the solid torso at the current pelvis; the shared separation planner then
   resolves the obstruction physically. It does not disable bike collision,
   teleport horizontally, duplicate seat ownership, or force an obstructed actor
   upright. Clear space permits the normal get-up sequence to resume.

## Test-map additions

`TraversalCourse` is a static builder with a replaceable configuration Resource:

- Six ramps: **10°, 20°, 30°, 40°, 50°, 60°**, with top decks and height labels.
- Seven ascending/gapped garden platforms, **0.25–2.60 m** tall.
- Step-height gauges: **0.12, 0.24, 0.32, 0.42 m**.
- Physical stairs to **1, 2, 4, 7 m** drop decks and marked landing areas.
- Thirteen jumping platforms beyond the ground boundary; gaps have real void
  underneath. Existing spawn recovery returns failed jumps to the safe spawn.
- An opening in the east perimeter connects the driving area to the drop tower.

Fixtures share materials and need no per-frame map logic. No performance gain is
claimed; device frame-time and draw-call profiling remain outstanding.

## Completed validation with restored private assets

All **839 assertions passed across 21 Godot/Jolt suites** using exact Godot
4.7.2 Stable. The native standing-weapon suite now passes 67 checks, including
walking/running with the authored supported grip for all five rifles/shotguns.
The movement suite verifies contact and stride pose ownership on the actual skin
in all 24 inventory slots; sprint measurement uses a flat lane outside the new
platform garden. Carry geometry for M4 and shotgun was inspected from two views
while standing, walking and running. Python validation: **23 passed, zero skipped**.

Tests that previously required one JUMP_* landing clip were updated to verify
both contact/stride layers, normalized weights, exclusive action ownership and
the actual rendered layer signature. Collision stopping in the new platform
course is kept separate from continuous sprint timing measurements.

The compiled APK was checked for package/version/HUD Build 11 identity, signature,
ZIP CRC, ARM64 16 KiB alignment, ARM64/ARMv7 binaries with Jolt, all 32 model scenes,
and exclusion of source asset archives and signing keys. A clean extraction of
its own assets passed the native catalog, touch UI, five weapon holds, expanded
map and real void-gap checks. **17 gameplay assertions** also passed from that
extracted APK, including actual Jolt pin recovery, equipment cancellation and
jumping onto a raised platform.

## Compiled Android artifact

`Harbor-Rev11.apk`, version `0.8.0-gameplay11`, version code **11**, package
`org.reware.harbor.revision11`. Universal ARM64/ARMv7; target SDK 36. A ZIP fallback
contains the identical APK. The supplied archive restored the private assets;
the original crouch compatibility resource was regenerated from its source data.
A fresh private test signing key was generated because the archive contained no
keystore. Assets and keys remain excluded from public git.

The earlier source-only status is superseded by these completed build checks.
Android device playtesting and device frame-time profiling remain unavailable;
headless skin/collision validation is not full original-game runtime parity.
