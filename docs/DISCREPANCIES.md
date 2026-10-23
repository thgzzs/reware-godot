# Current discrepancies

Falling and moving melee are documented in [FALL_AND_MOBILE_MELEE.md](FALL_AND_MOBILE_MELEE.md). The asset/vehicle delivery is documented in [STORIES_REVISION.md](STORIES_REVISION.md); older milestones are historical. Gameplay, visual and performance parity remain unverified against a running original build.

| Area | Remaining gap |
| --- | --- |
| Animation coverage | All 781 clips converted, but not every miscellaneous/cutscene clip has a gameplay state. Facial bones absent from the supplied player rig remain unmapped. Some mirrored/crossfaded contact poses need broader inspection. |
| Weapons | 24 supported entries use exact assets. Projectile, area-effect and continuous chainsaw semantics, original audio, exhaustive recoil/support-grip tuning and reference cadence traces remain. |
| Characters | Shared physical motor and retaliation work; impact uses a solid torso rather than articulated ragdoll. Full foot/hand contact calibration and original root-speed traces remain. |
| Vehicles | Three native cars and four native bikes. Ray suspension/contact model; no exact transmission, wheel angular inertia, tire relaxation or deformable tire volume. Bike balance and cornering limits are intentionally tuned approximations. |
| Damage | Localized panels/fragments, engine, tires and glass work. No general fracture simulation, exhaustive panel/hinge interaction or all original light-damage visuals. |
| Transitions | Crawl and moving bailouts work; source right crawl mirrors for left exits. No jacking/lock policy, exhaustive animation contact markers or steering-wheel/door-handle IK. |
| World/AI/camera | Small yard and shared fight/flee peds. No full traffic, population, navigation/crowds, streaming, missions, save/load or full cinematic camera set. |
| Validation | No original executable traces, browser playback, hardware GPU frame budget or full device/usability matrix. Local replay agreement does not prove cross-platform/network determinism. |
| Extensions | Data/command boundaries exist; multiplayer replication and mod loading are unimplemented. |

The four original model scenes and 25 PNGs remain byte-identical. Active animation resources and weapon/fight data are deliberately replaced by the supplied Stories set; legacy source tables remain for provenance.
