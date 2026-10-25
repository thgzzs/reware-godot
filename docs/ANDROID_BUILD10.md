# Android Build 10 — standing rifle and shotgun presentation

Version `0.7.1-gameplay10`, package `org.reware.harbor.revision10`, code 10.
Built from Android Build 9 (`14556be510616160e2b55fb8292a01260f71f562`).

## Cause and change

Standing locomotion previously sampled `IDLE_stance` with no upper-body weight
unless aiming, firing or reloading. Long guns therefore inherited unarmed arms.
The supplied Stories library contains `IDLE_armed`; the pinned reVC reference
(`a26fff4af555a8a425ac9f17d1dd718d00d1f942`) also maps the standard big-gun partial
and two-armed player idle to `idle_armed` in `src/animation/AnimManager.cpp`.

M4, Ruger, pump shotgun, stubby shotgun and SPAS-12 now use a separate configurable
standing-hold Resource. The authored loop blends over 220 ms onto torso/arm bones;
it never turns on aim IK, changes root movement, or replaces head/leg animation.
Aiming, firing and reloading override the carry layer, then fade back into it.
Sprinting, crouching, reactions, vehicle actions and death retain their ownership.
Other weapon families keep their existing profiles.

A missing native reload clip previously fell through to sampling a firing clip.
It now uses the existing procedural reload fallback instead.

## Checks

`tests/run_standing_weapon_suite.gd` exercises all five imported weapons on the
actual native skeleton: authored arm rotations, both-hand grip transforms, base
leg poses, no idle firing/root drift, aim/release blending, reload priority,
sprint release, pistol isolation and death cleanup. It adds 57 assertions.
The suite is included in `tools/validate.py`; exported APK checks also exercise
the five standing holds using only the packaged resources.

Pose geometry was inspected from two viewpoints using CPU skinning of the loaded
character mesh plus each active weapon model. This is not Android device visual
or performance testing; final device presentation remains unverified.
