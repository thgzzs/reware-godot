# Harbor Android Build 9

Godot 4.7.2 Stable with Jolt; version `0.7.0-gameplay9`, Android package
`org.reware.harbor.revision9`, version code 9. Universal ARM64/ARMv7 test APK.
Base Godot revision: `800976ea156a8b3758b2f68b27fde75a64caaf0e`.

## Changes

- Player and pedestrians share a configurable recovery planner. A fallen torso
  trapped below a slow motorcycle searches supported, unobstructed escape routes
  and applies bounded opposing impulses to the two physical bodies. Collision
  remains active; standing still requires the existing clearance and rest checks.
  No valid route means recovery waits and probes again rather than teleporting.
- Motorcycle reverse acceleration and speed now derive from each model's handling,
  with 2–3.25 m/s caps. Walking-back animation phase tracks actual travel speed.
- Reference movement gains 120 ms jump buffering, 80 ms ledge grace, and bounded
  air steering without airborne yaw rotation. Jumping into a platform riser no
  longer permanently consumes forward momentum: a capsule sweep gates restoring
  horizontal launch speed after clearance. Vertical launch energy stays unchanged.
- Weapon switching lowers the outgoing pose, commits the attachment once, then
  raises the incoming pose. It cancels incompatible firing/reloading/melee and
  clears pending switches on death or respawn. Existing inventory/ammo ownership
  remains intact. Dedicated holster animation assets are not assumed.
- Hip-fire input begins blending the authored upper-body hold pose before the
  firing presentation; the first ballistic event retains immediate response.
  Death clears competing reload/reaction/melee upper-body ownership.
- The APK name, package ID, HUD build label and version now consistently identify
  Build 9. Existing mobile controls, native asset catalog and previous gameplay
  features are retained.

## Validation

`python3 tools/validate.py --godot /absolute/path/to/godot` passed **729 assertions
in 19 suites**, including live Jolt bike-on-player contact, physical separation,
get-up, equipment cancellation, hip-fire blending, and elevated platform landing.
`python3 -m unittest discover -s tests -p 'test_*.py'` passed **23 tests**.

Use `tools/export_android.py` with the exact stable engine and your signing key.
`tools/check_android_payload.gd` checks a clean extraction of the actual APK's
assets, including Build 9 metadata, touch controls, 1,168 clips, 24 inventory
entries, four pedestrians, seven vehicles and the new recovery/equipment systems.

Automated tests run headlessly on Linux. Android device performance, visual pose
quality, every weapon/terrain interruption combination, and full original-game
parity remain unverified. This build does not introduce a full articulated ragdoll,
new authored holster clips, or unsupported climbing animations. No performance
improvement is claimed without profiling evidence.

Private user-supplied placeholder assets and signing keys are excluded from the
public repository. They are required locally to reproduce the private test APK.
