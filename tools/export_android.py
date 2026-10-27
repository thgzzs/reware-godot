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
import json


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, default=root.parent/'Harbor-Mobile-Test.apk')
    parser.add_argument('--keystore', type=Path)
    parser.add_argument('--debug', action='store_true',
                        help='Use the existing Android preset and configured debug signing identity.')
    args = parser.parse_args()
    version = subprocess.check_output([args.godot, '--version'], text=True).strip()
    if not re.match(r'^4\.7\.2\.stable(?:\.|$)', version):
        raise SystemExit(f'Requires exactly Godot 4.7.2 Stable; found {version!r}.')
    converted = root/'assets/converted'
    native = (converted/'ped_library.res').is_file()
    texture_sources = list((converted/'models/textures').glob('*.png.import'))
    if native:
        # Runtime remaps recovered from an APK can load in-editor yet disappear
        # from a new export. Require actual authoring resources before building.
        required = [converted/'gameplay_database.tres']
        if (converted/'models/player.scn').exists():
            required.append(converted/'models/player_rig.tres')
        required.extend(path.with_suffix('') for path in texture_sources)
        missing = [str(path.relative_to(root)) for path in required if not path.is_file()]
        if missing:
            raise SystemExit('Native source resources missing; runtime APK remaps alone cannot '
                             'be re-exported: '+', '.join(missing[:5]))
    env = os.environ.copy()
    test_key = root/'android/test-signing/test.keystore'
    key = args.keystore or Path(env.get('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', str(test_key)))
    if not args.debug and not key.is_file():
        raise SystemExit('Signing key missing. Use the complete private test ZIP, or supply --keystore '
                         'and GODOT_ANDROID_KEYSTORE_RELEASE_USER/PASSWORD for your own key.')
    if not args.debug:
        env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(key.resolve())
    if not args.debug and key.resolve() == test_key.resolve():
        env.setdefault('GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'androiddebugkey')
        env.setdefault('GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', 'android')
    elif not args.debug and not all(env.get(k) for k in ('GODOT_ANDROID_KEYSTORE_RELEASE_USER',
                                      'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')):
        raise SystemExit('Set GODOT_ANDROID_KEYSTORE_RELEASE_USER and '
                         'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD for the supplied signing key.')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    clean = subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--', '*.gd', '*.tscn',
                            '*.tres', 'project.godot', 'export_presets.cfg'], cwd=root)
    if clean.returncode:
        raise SystemExit('Commit gameplay/configuration changes before exporting a traceable build.')
    stamp = root/'assets/build_revision.json'
    previous = stamp.read_bytes() if stamp.exists() else None
    try:
        stamp.write_text(json.dumps({'source_commit': commit, 'engine': version,
                                    'build_type': 'debug' if args.debug else 'release'}, indent=2)+'\n')
        for options in (['--editor', '--import', '--quit'],
                        ['--export-debug' if args.debug else '--export-release',
                         'Android', str(args.output.resolve())]):
            result = subprocess.run([args.godot, '--headless', '--path', str(root), *options],
                                    env=env, capture_output=True, text=True, timeout=360)
            print(result.stdout, end='')
            print(result.stderr, end='')
            output = result.stdout+'\n'+result.stderr
            if 'resulting apk is unsigned' in output.lower():
                raise SystemExit('Android signing failed; refusing to deliver an unsigned APK.')
            if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
                raise SystemExit(result.returncode or 1)
    finally:
        if previous is None:
            stamp.unlink(missing_ok=True)
        else:
            stamp.write_bytes(previous)
    if not args.output.is_file():
        raise SystemExit('Godot did not produce the requested APK.')
    with zipfile.ZipFile(args.output) as apk:
        packaged = json.loads(apk.read('assets/assets/build_revision.json'))
        if packaged['source_commit'] != commit:
            raise SystemExit('Packaged source revision differs from the exported commit.')
        names = apk.namelist()
        if native and ('assets/assets/converted/gameplay_database.tres.remap' not in names or
                       sum(name.endswith('.ctex') for name in names)<len(texture_sources)):
            raise SystemExit('Native database or texture imports missing from exported APK.')
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
