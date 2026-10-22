# Imported animation and gameplay data

The private build includes the seven unchanged source files `ped.ifp`, `weapon.dat`, `pedgrp.dat`, `pedstats.dat`, `handling.cfg`, `ped.dat` and `fistfite.dat`. Their hashes are in `assets/converted/conversion_report.json`. Source and converted folders are ignored by git. The later `models.zip` upload arrived successfully: four selected model roots, real character skin/skeleton and 25 selected textures are now integrated. See [MODEL_AND_DISPLAY_MILESTONE.md](MODEL_AND_DISPLAY_MILESTONE.md) for current model/display status; earlier missing-archive limitations are superseded.

`ped.ifp` contains 234 entries in one ANPK `ped` package. This does not mean it contains every animation used by the whole game. The uploaded weapon data references animation groups such as `colt45`, `uzi` and `rifle`; the corresponding additional IFP blocks are not supplied here. Converting an animation does not implement its gameplay action.

## Conversion results

| Content | Count |
| --- | --- |
| ANPK clips | 234 |
| Source bone tracks | 5,031 |
| Source keyframe records | 87,546 |
| Native Godot channels | 5,422 |
| Native Godot channel keys | 95,427 |
| Pedestrian stat rows | 40 |
| Weapon rows | 37 |
| Pedestrian population groups / model slots per group | 67 / 16 |
| Pedestrian relationship types | 20 |
| Base handling records / special handling records | 106 / 26 |

Source frame records can contain rotation and translation/scale together. Godot separates these channels, which accounts for the higher native counts. Empty source tracks, bone identifiers and sibling metadata are retained as per-clip metadata. All original clip names, timestamps and available translation/rotation/scale channels are retained. No keyframe decimation is performed.

The native `ped_library.res` is an AnimationLibrary using `Skeleton3D:<original bone name>` paths. It opens directly in Godot and can be attached to an AnimationPlayer after the actual skeleton has been imported and its names/rest transforms validated. The native library itself is not neutralized for the procedural proxy. The current selected original character uses absolute local rotations on the imported skeleton; see MODEL_AND_DISPLAY_MILESTONE.md. The proxy computes idle-relative rotations separately at playback time and ignores unmatched extra bones; their original data remains in the library.

ANPK quaternion storage is conjugated on decode. The source basis is mapped with `(x,y,z) → (x,z,-y)`. Unit quaternions are normalized and hemisphere continuity is maintained. Source scale axes are reordered without introducing a negative scale. No character-size scale factor is guessed. The converter rejects out-of-bounds chunks, unsupported key encodings, nonfinite values and decreasing timestamps rather than silently dropping data. It supports this ANPK format, not arbitrary ANP2/ANP3 files.

## Runtime behavior

The same CharacterMotor script, PedHealth component and WeaponController component are instantiated for the player and four NPCs. Local input and PedBrain are separate intent producers. NPC commands use world axes with a zero reference yaw; player commands use camera-relative input converted through the motor's explicit frame argument. The player camera/HUD remain outside pedestrian ownership.

The imported locomotion policy uses WALK_start, WALK_player/run_player, sprint_civi and Run_stop/Run_stopR. Motion comes from sampled root displacement; collision still decides achieved movement. Actual body heading rotates the displacement, rather than rotating only the visible model after changing travel direction. A released sprint completes the selected stop clip and holds heading during that commitment. Ground input intensity increases at 3.5 units/s, derived from the reviewed 0.07 normalized-step source behavior. Normal walk/run blending and discrete states are an initial reimplementation, not an exact copy of the source blend machinery.

Jump launch and landing gates use JUMP_launch/JUMP_land clip durations. Modern coyote/buffer allowances are reduced to a same-tick edge and air steering is disabled in imported mode. Vertical flight still uses the existing ballistic motor rather than trusting the root's vertical translation to solve gravity. Landing root translation is not applied to collision. These are documented remaining differences.

Right-mouse aim currently stands still in imported mode. There is no claim that this reproduces every reference control/weapon mode. The shoulder camera remains a prototype camera. Imported raw sprint displacement is used without an invented scale correction; speed can be surprisingly high and requires matching the actual model scale, reference animation playback/blending and runtime traces before calling it faithful.

The resizable F4 browser previews every clip without moving the colliding actor. Search, select, play/pause or scrub, then close to resume locomotion. Preview playback is diagnostic: it does not implement all 234 actions. Entry/exit now use CAR_getin_LHS/CAR_getout_LHS durations and poses. The actor remains visible during transfer, but safe interpolation is still used because the full door/seat-aligned transition sequence is unfinished. Door opening/closing, passengers, jacking and full animation sequences remain unfinished.

NPCs follow simple authored test routes and react to nearby gunfire when `ped.dat` declares GUN as a threat. Flee range/fear and defense multipliers come from the supplied stats. Population model names and relationships are loaded. This is a small shared-character demonstration, not the full original population/AI/navigation system; group selection by world zone, temper/lawfulness decisions, shopping bags, melee flags and most archetype distinctions are not implemented.

## Data mapping boundaries

- `pedstats.dat`: ordered records and all fields are preserved. Heading rate is converted from degrees per normalized source step by multiplying by 50 and converting to radians/second. The player row therefore corresponds to 750°/s, not 15°/s. Defense multiplies received damage; attack strength is retained for future melee and is not incorrectly applied to every hitscan shot.
- `weapon.dat`: all 37 records and animation-frame parameters are retained. The demo selects Colt45 and applies range, damage, clip size, firing-rate milliseconds and reload milliseconds. Source animation-dependent attack cadence is not reconstructed by this direct millisecond mapping. Other weapons are data records, not implemented weapon strategies. Missing animation groups stay explicitly missing.
- `handling.cfg`: all 106 base records and 26 special rows are retained. The car selects IDAHO mass, km/h-to-m/s speed limit, steering degrees and driven-axle flags. Original wheel markers now set axle spacing, and the placeholder hull is sized approximately to the imported body. COM origins, spring/damping levels, traction/bias/loss, transmission/anti-dive and vehicle-type extensions remain unmapped until geometry and a calibrated solver are available. No dimensionless legacy suspension coefficient is passed off as an SI spring constant.
- `pedgrp.dat`: all ordered slots, including repeated names, are preserved. test actors currently share one selected player mesh; group names do not imply those individual models were imported.
- `ped.dat`: threat/avoid relationships are parsed. The five numeric fields are preserved as source_values without fabricated semantic names; reviewed source itself labels several of them unknown.

The converted gameplay database is an Inspector-editable ImportedGameplayDatabase Resource. It preserves source values separately from the fields applied to gameplay.

## Online tool research

- [Psycrow101/io_scene_gta_ifp](https://github.com/Psycrow101/io_scene_gta_ifp) provides GTA III/VC/SA IFP import/export for Blender. Its reader at `e54ad39ee2711399ff1c6596f8d572e7f4e8027b` was used only as an independent scratch validation oracle. A minimal mathutils value stub supplied Quaternion/Vector storage and conjugation; its parser was unchanged. No third-party implementation is bundled in Harbor.
- [DragonFF](https://github.com/Parik27/DragonFF), inspected at `54baca8ea2ed95fe5a86917f44399ce677379c59`, provides DFF/skinned-model and TXD tooling. The inspected tree does not contain the standalone IFP parser suggested by some search results, so animation conversion does not depend on that assumption. Its external PC DFF/TXD readers were subsequently used for the selected original model/texture conversion; see MODEL_AND_DISPLAY_MILESTONE.md.
- Godot's [Animation](https://docs.godotengine.org/en/4.7/classes/class_animation.html) resource supplies native position, rotation and scale tracks. This build uses that API directly and does not require a browser upload converter or installed Blender.

The new converter and Godot integration are original project code. The uploaded game assets and converted derivatives retain their original ownership; the framework's MIT license does not relicense those assets. The asset-inclusive build is delivered as a private project archive; source uploads and generated derivatives are excluded from public git by default.

## Validation and reproduction

All 87,546 source keyframes were compared against the independent reader: zero mismatches in names, bone IDs, counts, timestamps and converted channel values. Godot then loaded the native library and compared all 95,427 channel keys and timestamps against decoded source: zero mismatches within the recorded floating-point tolerance. See `tests/independent_decoder_results.json` and `tests/imported_results.json`.

The new integration suite has 36 passing assertions covering library/data counts, full key preservation, playback, heading-coupled motion, walk/start/sprint/stop, jump timing, shared NPC/player components, DAT fields, gun reactions, vehicle transitions, driving and post-exit weapon control. The original 48 regression assertions run with imported behavior disabled so the original prototype's intentional tuning is tested separately. The current Python suite has 18 parser/extractor/model tests; see VALIDATION.md for scope. Neither suite establishes original-mesh or reference-runtime equivalence.

To rebuild from the six initial files plus optional fistfite.dat:

```bash
python3 tools/import_local_assets.py --source /absolute/path/to/files --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
python3 tools/validate.py --godot /absolute/path/to/Godot_v4.7.2-stable_linux.x86_64
python3 -m unittest discover -s tests -p test_asset_conversion.py -v
```

The prebuilt library/database are already included. Rebuilding is optional. Godot 4.7.2 Stable remains mandatory. Without private converted assets, the project falls back to the original primitive playable slice and its baseline movement tuning; it does not fetch assets from anywhere.

## Melee configuration

All 32 ordered fistfite.dat records are stored in the native gameplay Resource. Source frame timings are divided by 30 as confirmed by the pinned LoadFightData implementation. Twenty-eight concrete clip names resolve; four null/default sentinels are preserved separately. F4 shows active strike windows and raw source damage. Raw damage is not final HP damage, and melee hit detection/combos/damage behavior are not implemented.
