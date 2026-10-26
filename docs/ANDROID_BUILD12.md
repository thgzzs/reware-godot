# Android Build 12 — restored carry, landing control and terrain collapse

Base: Build 11 commit `104342a5ea63547093a138dd4da5303b3c055cc9`.
Godot 4.7.2 Stable + Jolt; `0.8.1-gameplay12`, version code 12,
package `org.reware.harbor.revision12`.

## Carry/holster pose

The configured rifle/shotgun carry Resource again samples the original
`IDLE_armed` association. Its pre-fire ready-pose override and torso lowering are
disabled for this preset. The masked torso/arm layer remains active over walking,
running and sprinting legs. Aiming, firing, reloading, jumping, landing, vehicle
actions and terminal life states retain their own action ownership.

M60 now shares the same preset and explicitly enables both arm chains alongside
M4, Ruger and all three shotguns. Weapon attachments, inventory and ballistics
retain their existing implementation. The native carry suite checks the restored
association, both-hand masks, unchanged locomotion thigh poses and moving legs
during sprinting for all six weapons.

## Landing and counter-input

Landing previously selected a running follow-through from retained air speed,
even when movement input was released. Native contact root travel could also
advance the character without input. Landing now reads camera-relative intent:
forward travel requires a continuing direction; released/opposite input completes
compression in place. Changing that input after contact cancels subsequent root
travel and the running follow-through immediately.

Opposite ground input stops planar movement before a bounded pivot, including
when a native sprint-stop association has locked the heading. A hysteresis angle
keeps the pivot stable until the new direction is aligned. Opposite airborne
input stops planar momentum without changing jump height or rotating the body;
the stop remains held until support returns.

A buffered jump can survive a soft landing's initial contact phase. Hard impacts
retain exclusive recovery ownership. Landing completion uses its action clock,
so changing the follow-through cannot leave a separate timer behind.

## High falls, death and cleanup

The roll is bounded by impact/drop tuning. Higher qualified impacts transfer
directly into a solid Jolt collapse at the current pelvis, with zero seeded
angular velocity. The supplied `KO_skid_back`/prone fallback replaces the earlier
`FALL_collapse` terminal assumption: that imported association ends upright and
is unsuitable as a terminal corpse pose.

Terrain collapse plays through before get-up. Lethal collapse plays its death
association through before final rest/corpse retirement; the terminal pose is
chosen after settling. The shared collision-clearance and bike pin recovery
components remain active for surviving characters.

Entering an impact/death state cancels jump buffering, landing travel, its timer,
sprint/turn state and incompatible weapon actions. Restoring control initializes
ground/air phase and gait state explicitly. A surviving high fall therefore
cannot get up and subsequently replay its old landing association.

## Validation

`tests/run_landing_control_suite.gd` uses the actual native skin and Jolt to check:

- Stationary/released/opposite-input jump landings and contact-time cancellation.
- Immediate ground/air reversal stops and interruption of a locked sprint-stop.
- A buffered second jump through soft contact compression.
- A surviving high fall, one impact, one get-up and no roll/landing replay.
- A lethal high fall with changing bone poses, a grounded terminal corpse,
  no get-up/roll and no pending landing timer.

The full validator includes this suite and the expanded six-weapon carry suite.
**877 assertions passed across 22 suites**, including 86 native carry checks and
19 native landing/fall regressions. All **23 Python tests passed**. Release
validation JSON records package signature, alignment and clean-payload checks. Android device playtesting and performance profiling are
not available; headless native-skin/collision tests are not a runtime-parity claim.
