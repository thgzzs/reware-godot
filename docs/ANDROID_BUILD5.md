# Android build 5

The Android app is named **Harbor Rev 5** and uses package **org.reware.harbor.revision5**, version **0.4.1-revision5**, code **5**. It installs alongside the older org.reware.harbor app, avoiding confusion between installations and signing identities. The HUD displays **GAMEPLAY REVISION / BUILD 5**.

Gameplay comes from the combat/driving revision merged in PR #3 (4377cd3). This packaging revision adds build identification and installation isolation; it does not claim additional gameplay parity. It uses the existing supplied models/animation resources and the legacy crouch override.

The previous delivered APK was checked directly through its extracted assets: all 42 native revision assertions passed. Its unchanged app name/HUD made it difficult to identify. This is evidence about the packaged code, not a diagnosis of what was installed or running on a user's phone.

Rebuild with tools/export_android.py and exact Godot 4.7.2 Stable. The private test signing identity remains outside public git. Verify the exported manifest and signature, then run tools/check_android_payload.gd against a clean extraction of APK assets to check build identity, native asset activation, mobile controls and label fit. Native behavior and mobile input suites remain separate. No physical Android device or emulator is available in this environment.
