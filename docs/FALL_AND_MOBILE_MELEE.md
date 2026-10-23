# Falling and moving melee

The shared actor now distinguishes a sustained descent from an ordinary jump. After sufficient drop and downward travel it enters `falling`, plays the supplied FALL_fall clip, then loops FALL_glide. Landing measures relative velocity along the support normal, selects a hard-landing recovery when appropriate, and applies damage once. Fatal impacts select FALL_collapse. The HUD shows falling/recovery; F3 includes drop, impact speed and damage.

ActorFallState is per-actor trajectory evidence and emits a landing signal. CharacterMotor owns support/collision, and PedHealth owns health. FallProfile in tuning/fall.tres contains thresholds, damage and animation candidates. The same components serve player and pedestrians. Combat defense multipliers do not reduce environmental landing damage. Vehicle seating, teleport/reset and respawn discard previous trajectory evidence. Existing vehicle reaction bodies retain their own collision ownership; this change applies to the on-foot motor.

The default curve is `min(200, 1.25 * max(0, impact_speed - 9.5)^2)`, with speeds in m/s. Damage requires at least 0.24 seconds airborne and 1.4 m of descent. A hard landing begins at 10.5 m/s. Normal jump height is below the damage threshold. These are explicit target tuning choices, not claims of original-game parity. Relative normal speed handles moving rigid/static supports and avoids treating tangential slope travel as a landing impact.

Moving melee uses walk/run/sprint locomotion as the base. Native attack articulation overlays the configured upper body; kicks additionally mask the configured striking leg. Walk/run legs continue at their existing speed, without adding attack-root velocity. Stationary attacks retain their collision-swept source root displacement. Strikes can move between stationary and mobile presentation during the same attack. Steering is bounded by MeleeProfile; weapon switching, losing support and death cancel the attack and fade the layer.

Mobile strikes sweep the displayed weapon/limb tip between fixed-tick poses, including actor travel. Player and pedestrian gameplay poses sample on the physics tick before resolving the strike. Contact windows, deduplication and obstruction checks remain in MeleeController. Physics owns motion; animation does not teleport the actor or bypass wall collision.

## Tuning and extension

- tuning/fall.tres: safe impact speed, curve coefficient/cap, minimum air/drop evidence, descent detection, hard recovery and clip candidates. `damage_enabled` disables damage while preserving falling presentation/recovery.
- tuning/melee.tres: mobile attacks, steering rate, strike/recovery balance and stationary root scale. Existing weapon clip/tip definitions remain in tuning/weapon_actions.tres.
- ActionProfile: mobile kick bone mask. Imported rig-ID bindings still resolve the clip channels.

Use the existing move controls with left mouse held to strike while walking, running or sprinting. Ordinary airborne weapon restrictions remain. Fall damage and moving attacks use the existing character components; no player-only controller or separate NPC combat implementation was introduced.

## Validation and limits

Run `python3 tools/validate.py --godot /absolute/path/Godot_4.7.2_stable`. The new tests/run_fall_melee_suite.gd exercises normal jumps, short/moderate/severe drops, actual ledge traversal, recovery/death, long glides, disabled damage, reset, shared pedestrian behavior, relative support speed, all imported melee weapons, stride speed, steering, moving tip damage, world collision, pose transitions, cancellation and respawn. Current results and measurements are in tests/fall_melee_results.json and VALIDATION.md.

Software-rendered checks cover descent, hard landing and running bat/katana attacks. This is a selected visual review. Full animated contact calibration, articulated fall ragdolls, water landings, ladders, network authority and original-runtime parity remain outside this revision. No asset reconversion or engine-version change is required.
