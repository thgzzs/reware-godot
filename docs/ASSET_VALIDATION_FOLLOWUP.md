# Original asset validation and Android Build 14

The supplied `Harbor-Godot-4.7.2-Revised-Test-Build(5).zip` closes the original
asset-provenance gaps from the APK-only controller audit. All 728 entries in its
`FILES.sha256` manifest match. Independent checks verify all 71 original PNG
files and their decoded RGBA checksums, plus all 32 original DFF model checksums.

Only `assets/converted`, `assets/local_models` and `assets/local_source` were
copied into the published controller branch at
`2e541039c8bef7a716c4b5fbb531fb5fb12cb8e2`. The older archive's scripts,
scenes, settings and project configuration were not overlaid. Original PNGs and
editable rig/database Resources are used directly; APK pixel reconstruction is
no longer required. Private source assets and derivatives remain excluded from Git.

The current `tools/build_legacy_crouch.gd` rebuilt the compatibility crouch from
the original supplied animation source. Its checksum is exactly
`26cbf4ec23ed7b68c3ec253a890b4e5db4a3a4ec584e62c02928217af2182c9c`,
matching the preceding build. Models and the main animation library were reused
without reconversion.

## Executed validation

| Check | Result |
| --- | --- |
| Archive manifest | 728 verified; zero missing or mismatched files |
| Original textures | 71 PNG byte hashes and decoded pixel hashes match |
| Original models | 32 DFF hashes match |
| Python | All 23 tests pass, zero skips |
| Godot/Jolt | All 905 assertions pass across 23 suites in one full run |
| Final controller suite | All 28 checks pass after making injected joypad release a separate event instance |
| Script scan | 146 scripts parsed/instantiable; zero failures |
| Render-rate replay | 30/60/120/144/variable caps pass at 60 Hz physics; actor/pose/state/shot traces match, vehicle drift below 0.000001 m |
| Native source-payload smoke | 1,168 animation entries, 32 model scenes, seven vehicles, four pedestrians, six long-gun carry/sprint cases, both profile resources and expanded traversal fixtures |

Engine and templates are official Godot 4.7.2 Stable, engine commit `ed1daf0bf`;
both downloaded archives match the official SHA-512 manifest. See
`controller-validation.json` for the current structured results and archive hash.

The test-only input fix avoids submitting the same `InputEventJoypadMotion`
object twice in one frame. Gameplay input and controller behavior are unchanged.

## Android delivery

Build metadata advances to version `0.8.3-assets14`, code 14. The existing
`Android` preset, `org.reware.harbor.revision12` package identifier, application
label, rendering configuration, permissions and ARM32/ARM64 architectures remain.
The exporter embeds the actual published source commit and rejects missing native
authoring resources or incomplete exported texture/database payloads.
It also rejects Godot's explicit unsigned-APK warning: a signing-tool failure can
otherwise return success with an unusable unsigned artifact. Final delivery
requires independent signature verification in addition to a successful export.

This archive contains no Android export preset or signing key. The preset comes
from the existing repository. The available build is debug-signed with a fresh
local debug identity; the original signing identity cannot be recovered from an
APK. An in-place update over a differently signed installation requires its
original private key. Uninstalling an existing app may remove its local data.

Final APK size, checksum, embedded source commit, signature/alignment checks and
compiled-payload smoke results are recorded in the delivered build manifest.
Android installation/device startup, GPU/thermal behavior, physical touch/gamepad
ergonomics and comparison with a running original reVC executable remain untested.
The original controller audit's remaining fidelity gaps still apply; supplying
assets alone does not establish complete behavioral parity.
