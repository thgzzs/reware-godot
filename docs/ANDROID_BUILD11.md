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

## Fresh validation after restoration

`python3 tools/validate.py --godot /absolute/path/to/godot`:
**207 assertions passed in five public suites** using exact Godot 4.7.2 + Jolt.
The 42 traversal contracts cover collision angles, climbing 10°/30° and rejecting
50°, actual run/sprint jump-contact-stride sequences, falling into the void and
respawning, carry/action priority, two-hand transform preservation, head/root
isolation, landing root travel at 30/60/120 Hz, and interrupted bike get-up.

Python: **14 passed, 9 skipped** (23 discovered). The skipped tests require the
private converted asset set. The native standing-weapon suite has been extended
to walking/running and the new ready-pose selection; it cannot be re-run without
those files. Synthetic clips and primitive colliders validate state/geometry
contracts, not final native skin quality or original-game runtime parity.

## Build status

This revision is source-ready. **No Build 11 APK has been compiled or signed.**
Workspace maintenance removed the private assets and signing key. They are
intentionally excluded from git and unavailable through the current file-reader
capabilities. Restore the complete private project ZIP (including
`assets/converted` and `android/test-signing/test.keystore`) before running the
native suites, native pose inspection and Android export. A previous APK can
recover shipped resources, but not its private signing key.

After restoration, run the full validator, Python tests, export with
`tools/export_android.py`, verify APK signature/alignment/version, and run
`tools/check_android_payload.gd` against its clean extracted assets. Android device
visual/performance validation remains required; earlier Build 10 results are not
reported as Build 11 verification.
