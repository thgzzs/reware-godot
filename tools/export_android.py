#!/usr/bin/env python3
"""Export the Android test APK with exactly Godot 4.7.2 Stable.

Configure the Android/Java SDK paths in Godot first. Private test builds include a
local test keystore; public git users must supply their own signing identity.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import zipfile


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, default=root.parent/'Harbor-Mobile-Test.apk')
    parser.add_argument('--keystore', type=Path)
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    if not re.match(r'^4\.7\.2\.stable(?:\.|$)', version):
        raise SystemExit(f'Requires exactly Godot 4.7.2 Stable; found {version!r}.')
    env = os.environ.copy()
    test_key = root/'android/test-signing/test.keystore'
    key = args.keystore or Path(env.get('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', str(test_key)))
    if not key.is_file():
        raise SystemExit('Signing key missing. Use the complete private test ZIP, or supply --keystore '
                         'and GODOT_ANDROID_KEYSTORE_RELEASE_USER/PASSWORD for your own key.')
    env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(key.resolve())
    if key.resolve() == test_key.resolve():
        env.setdefault('GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'androiddebugkey')
        env.setdefault('GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', 'android')
    elif not all(env.get(k) for k in ('GODOT_ANDROID_KEYSTORE_RELEASE_USER',
                                      'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')):
        raise SystemExit('Set GODOT_ANDROID_KEYSTORE_RELEASE_USER and '
                         'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD for the supplied signing key.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    for options in (['--editor', '--import', '--quit'],
                    ['--export-release', 'Android', str(args.output.resolve())]):
        result = subprocess.run([args.godot, '--headless', '--path', str(root), *options],
                                env=env, capture_output=True, text=True, timeout=360)
        print(result.stdout, end='')
        print(result.stderr, end='')
        if result.returncode or 'SCRIPT ERROR:' in result.stdout+result.stderr or '\nERROR:' in result.stdout+result.stderr:
            raise SystemExit(result.returncode or 1)
    if not args.output.is_file():
        raise SystemExit('Godot did not produce the requested APK.')
    with zipfile.ZipFile(args.output) as apk:
        forbidden = [name for name in apk.namelist() if
                     name.startswith(('assets/tests/', 'assets/docs/', 'assets/tools/',
                                      'assets/assets/local_source/', 'assets/assets/local_models/',
                                      'assets/android/test-signing/')) or
                     name.endswith(('.keystore', '.jks')) or '/tmp' in name]
        if forbidden:
            raise SystemExit('Development-only files found in APK: '+', '.join(forbidden[:3]))
    print(f'Created {args.output.resolve()} ({args.output.stat().st_size} bytes)')


if __name__ == '__main__':
    main()
