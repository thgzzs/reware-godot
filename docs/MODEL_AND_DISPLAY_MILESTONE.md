# Selective model and display milestone

## Delivered

The supplied `models.zip` was read directly. Four model roots and four small texture dictionaries were selected from `gta3.img`: **369,300 bytes** of IMG payload. The complete IMG was not written to disk or unpacked into model files. Loose `hud.txd`, `MISC.TXD`, `particle.txd` and `generic.txd` supplied the additional HUD, wheel, effect and yard textures. Only **25 selected texture images** were exported as PNGs.

| Placeholder role | Identifying evidence | Runtime use |
| --- | --- | --- |
| Shared character | Material `player`, 25 source frames, 24 skin binds, 1,153 vertices | Player and four NPCs use the same motor, health, weapon and skinned presentation components |
| Idaho | Root frame `idaho`, wheel/door/seat dummies, matching Idaho material textures | Drivable car with source body hierarchy and inactive damaged/low-detail variants |
| Colt .45 | Root frame `colt45`, `colt_all` material | Right-hand attachment on the imported character skeleton |
| Street bin | Root frame `trashcan`, `binend/binhandle/binside/trash` textures | Two static yard props with authored box collisions |

There was no matching `.dir` in the ZIP. The original archive filenames are therefore unavailable. An original bounded inspector scanned sector-aligned RenderWare root headers and embedded frame/texture metadata, recognizing 5,985 roots and leaving 4,130 unrecognized sectors. Those counts do not establish an exhaustive archive inventory. The descriptive exported filenames are labels, not recovered directory entries. Exact selected offsets, root lengths and model hashes are pinned in `assets/model_selection.json`. All uploaded files remain unchanged.

## Conversion

An external [DragonFF](https://github.com/Parik27/DragonFF) checkout at `54baca8ea2ed95fe5a86917f44399ce677379c59` decoded the selected PC DFF/TXD payloads. Its GPL tool code is a build dependency and is not bundled in this project. Native game execution does not require Blender, DragonFF, Pillow or RenderWare readers. The original framework's MIT license does not relicense the provided game data or derived assets.

`tools/convert_model_placeholders.py` writes portable model data and only requested PNGs. `tools/build_model_scenes.gd` creates four native packed `.scn` scenes with ArrayMesh surfaces, materials, a real Skeleton3D and Skin. It preserves frame hierarchy, vertex weights, source bind matrices, UVs and material assignments. All 24 inverse binds cancel the corresponding native global rest transforms within 0.000001. The source basis `(x,y,z) → (x,z,-y)` is applied consistently to vertices, normals, frame transforms and inverse binds. Triangle order is reversed for Godot's clockwise front faces. Missing source normals are generated. Legacy paint marker colors are semantic channels with Inspector-editable placeholder colors.

The actual 25-frame character hierarchy replaces the procedural diagnostic skeleton when the selected native model is available. Converted IFP quaternions set absolute local rotations; missing tracks reset to rest values. Planar root translation remains in the collision motor and is not applied a second time to the skin. Vertical root pose remains animated. A configurable 0.115 m visual offset aligns the idle skin with the prototype capsule. This is an alignment adjustment, not a model-size rescale. CPU evaluation of the loaded idle mesh produces approximately 1.835 m body height. Rendered checks show the textured model and its pose in the test yard. These checks do not prove full animation blend or gameplay parity.

The car retains genuine marker transforms; axle spacing uses the original wheel markers. Its body has an approximate 5.5 m box hull, with a separate existing cabin box. Wheels are procedural cylinders and hub quads using the supplied MISC textures; no original wheel mesh was found or claimed. The suspension's mount height and force coefficients remain provisional. Driver visibility, door movement and seat-aligned transition sequences remain unfinished.

## Replace assets

Edit `tuning/placeholder_assets.tres` in the Inspector. `PlaceholderAssets` provides semantic scene paths for character, vehicle, weapon and prop; character and weapon offsets; the weapon attachment bone; paint colors; hull dimensions; and texture-role paths. Compatible `.scn`, `.tscn` or `.glb` replacements can be assigned without editing gameplay code. A character with different bone names/rest conventions requires a deliberate animation binding/retarget pass; this is not automatic universal retargeting. Vehicle frame names are the current imported adapter convention; another model convention needs its own adapter or matching markers.

The public repository contains the code, configuration and reproducible tools. The asset-inclusive project download contains the selected native scenes, textures, data and original selected payloads. The complete IMG and ZIP are not bundled in the project. With no local imported assets, the source project retains its authored primitive fallback.

## Display and HUD

The window uses `canvas_items`, an expanding aspect policy and a square 720-unit design minimum. The initial desktop window is 1440×900 and remains resizable. Camera `KEEP_HEIGHT` preserves vertical FOV while horizontal coverage follows aspect ratio. The HUD computes its health, ammo, radar and context rectangles from logical viewport dimensions. The reticle, projected shot tracers and diagnostic contact markers use the same viewport coordinate system as the camera.

F1 toggles help, F2 opens display settings, F3 toggles diagnostics and F4 opens the resizable animation browser. Display settings expose window-size presets, fullscreen, 75–150% interface scaling and 50–100% bilinear 3D render scaling. The 3D buffer scales independently of UI sharpness. Settings persist in `user://display.cfg`. Test mode does not load or save a player's settings.

Optional adaptive mode targets 60 FPS using sustained frame-time samples, hysteresis and a cooldown. It is disabled by default and is not a GPU-time measurement. It may reduce resolution for a CPU bottleneck without improving performance; no automatic performance improvement is asserted. Headless runs and unfocused windows do not drive adaptation. Sliders and menus block actor/fire commands while open. No physics timestep or handling coefficient is changed by resolution settings.

The HUD shows actual health/ammunition/reload state, vehicle speed, interaction messages and a **local yard radar**, not a map of the original world. No unimplemented money/wanted/mission state is fabricated. Muzzle-flash and impact sprites reuse two allocated presentation nodes; they do not own hit detection. There is no audio implementation.

## Rebuild and test

Run with **Godot 4.7.2 Stable**, built-in **Jolt Physics**. The native assets are already included in the private build. For rebuilding, install Python 3.10+ and Pillow, supply an external pinned DragonFF checkout, then run from the project root:

```bash
python3 tools/inspect_rw_archive.py --zip /path/to/models.zip --query idaho --output /path/to/catalog.json
python3 tools/convert_model_placeholders.py --zip /path/to/models.zip --dragonff /path/to/DragonFF
godot --path . --headless --editor --import --quit
godot --path . --headless --script res://tools/build_model_scenes.gd
python3 tools/validate.py --godot /absolute/path/to/Godot_4.7.2_stable
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The committed selection is specific to the supplied archive and verifies selected DFF hashes. Use the matching `.dir` with `extract_selected_img.py` when available instead of assuming these offsets fit another edition. For new artwork, import the new scene and update semantic bindings; the source archive pipeline is unnecessary.

## Validation and remaining gaps

112 Godot assertions (48 baseline, 36 imported animation/data, 28 model/display) and 18 Python tests pass. Eight window sizes cover 4:3, 16:9, ultrawide, 4K and portrait. Tests verify real skin binds/weights, upright idle deformation, independent UI/3D scales, camera center rays, menu input blocking, adaptive bounds/cooldown/recovery and gameplay transitions. Six native Godot software-OpenGL captures support a rendered visual review of the model/HUD, settings, 4:3, wide, portrait and animation browser. These are automated captures, not physical-device usability or reference-runtime comparisons.

The original movement/vehicle solvers still need runtime reference traces and calibration. Complete combat/melee, full blend policies, weapon animation blocks, IK, pedestrians' full AI/population/navigation, original wheel geometry, doors/passengers, driver presentation, audio, streaming and full gameplay/visual/performance parity remain open.

## File changes

Created: presentation/display_profile.gd, display_controller.gd, placeholder_assets.gd, skinned_motion_visual.gd, model_placeholder_setup.gd, gameplay_hud.gd, shot_presentation.gd; tuning/display.tres and placeholder_assets.tres; tools/inspect_rw_archive.py, convert_model_placeholders.py and build_model_scenes.gd; tests/run_presentation_suite.gd, render_model_preview.gd and test_model_conversion.py; assets/model_selection.json; selected local model payloads, native scenes, PNGs, conversion reports and visual captures; this document.

Modified: shared character presentation type, arena wiring and input gating, camera aspect setting, imported setup labels, animation browser layout/style, debug HUD compatibility script, project display settings, validation entry point, tests and status/provenance/manifest documentation. The repository owner's arena tab-formatting and nearest-vehicle refactor were retained.

Primary tool research: [GTA Scout README](https://github.com/Dryxio/gta-scout) explicitly describes its initial adapter as classic PC San Andreas and leaves full VC/III adapters for future work. It was reviewed, not installed or presented as a VC exporter. [Godot 4.7 multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html) and Viewport/Window/Skeleton3D/Skin documentation informed the native API integration.

## Spawn regression resolved

Rendered and physical checks exposed a spawn-only impulse after hull resizing: actor bodies were added to the tree at the origin and moved afterward, allowing stale initial contacts with the car. Initial actor, NPC and vehicle transforms are now assigned before tree insertion. A repeatable unreset spawn-settling assertion guards this case. Force coefficients were not tuned to hide the fault.
