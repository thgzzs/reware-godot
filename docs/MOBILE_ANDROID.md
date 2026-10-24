# Current Android update

Version 0.4-behavior-test (code 4) includes the combat/driving revision and retains the prior test signing identity. See COMBAT_DRIVING_REVISION.md and VALIDATION.md for current checks and limits.

# Mobile controls and Android test build

The complete test ZIP now includes phone controls and an Android export preset. The APK uses the release engine, Compatibility renderer and built-in Jolt from exactly Godot 4.7.2 Stable. It is signed with the included local test identity; it is a private test build rather than a store release.

The APK targets Android API 36, supports Android 7.0/API 24 and later, and includes both ARM64 and ARMv7 native engines. OpenGL ES 3.0 support is required. Intel Android architectures are not included. The requested landscape orientation and expanding viewport support different phone/tablet aspect ratios.

| Control | Behavior |
| --- | --- |
| Left stick | Analog on-foot movement; horizontal vehicle steering |
| Drag the right side | Orbit/aim the camera independently of the stick and buttons |
| AIM | Toggle aiming; tap again to return to hip fire |
| FIRE | Hold to fire or strike with the selected weapon |
| SPRINT | Hold to sprint; repeated taps preserve the existing capped boost |
| JUMP / CROUCH / LOAD | Jump, toggle crouch and reload |
| Left/right weapon arrows | Cycle the complete available loadout |
| ENTER / CANCEL | Walk into mount position, or cancel the approach |
| GAS / REV / BRAKE | Drive, reverse and brake through the shared vehicle controller |
| EXIT | Stationary dismount or moving physical bailout |
| SEAT | Request the existing passenger-to-driver transition |
| CAM | Cycle follow modes |
| MENU / Android Back | Open or close display settings |
| RESPAWN | Restore the player after death |

Touch controls occupy their own canvas and respect the display safe area. HUD/radar/ammunition cards move away from the lower thumb areas. Ordinary display sliders and Resume accept touch through a single-pointer modal bridge. Screen touches do not emulate gameplay mouse buttons, so using the movement stick cannot accidentally fire the weapon.

Each finger keeps its stick/look/button role until release. Held actions are reference-counted, tap edges survive between physics ticks, dragging out releases a button, and menus/focus loss/pause/context changes clear touch ownership. On-foot/driving/dead contexts change the available controls. The existing command producer combines touch with desktop controls; actors, weapons, vehicles and physics remain shared. Use `-- --touch` after Godot's normal launch arguments to preview the touch interface on a desktop.

Edit `tuning/touch.tres` for stick radius/deadzone, camera drag gain, aim toggle and margins. Display settings still offer independent 3D resolution and interface scale; adaptive scaling is optional. Frame-rate and thermal performance on actual phones remain unmeasured.

## Build again

1. Install exactly Godot 4.7.2 Stable and its matching export templates.
2. Install/configure OpenJDK 17, Android platform tools, SDK platform 36 and build tools 36.0.0. Set the Java SDK and Android SDK paths in Godot Editor Settings. The official 4.7 export guide provides the general setup; this release's actual prebuilt manifest targets API 36.
3. Open `project.godot` and complete imports, including the enabled Android texture formats.
4. Export the `Android` preset, or run:

```bash
python3 tools/export_android.py --godot /absolute/path/to/Godot_4.7.2_stable --output /absolute/path/Harbor-Mobile-Test.apk
```

The complete private ZIP contains `android/test-signing/test.keystore` with alias `androiddebugkey` and standard test password `android`. Keep that same test key when rebuilding an update for this test installation. It is excluded from public git and from the APK itself. For your own signing identity, pass `--keystore` and set `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`; the script does not print those values. Public git does not include private game assets or the test key.

The APK bundles runtime models, textures, data Resources and the native animation library. It excludes raw IMG/IFP/model sources, analysis reports, tests, screenshots, tooling and signing material. Exported asset detection uses ResourceLoader so binary/remapped Resources are recognized.

## Validation scope

The touch suite sends ScreenTouch/ScreenDrag through the live viewport/command producer, including simultaneous movement/aim/fire, analog steering/throttle/brake, entry/exit, cancellation boundaries, modal slider/resume, focus loss, cutout layout and respawn. The full native asset regression remains separate. See VALIDATION.md and tests/mobile_results.json for current counts.

APK checks include signature verification, manifest/ABI inspection, archive CRC, 16 KiB native archive alignment and all 32 selected model scenes. The exported payload was also loaded by the exact desktop engine and activated 1168 animation entries, 24 weapons, four pedestrians, seven vehicles and touch controls. That checks packed-resource loading; it does not run Android Java/JNI or prove Android GPU/CPU performance.

Selected desktop software renders cover on-foot, driving, settings and 16:9/wide layouts. No physical Android device or emulator was available. Installation, system insets, suspend/resume, thermals and GPU compatibility still require device testing. Original-runtime/browser parity remains unverified.

Setup references: [Godot 4.7 Android export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html), [official 4.7.2 export templates](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable), [Android command-line tools](https://developer.android.com/studio#command-tools).
