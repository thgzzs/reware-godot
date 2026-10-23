#!/usr/bin/env python3
"""Run the project suites with exactly Godot 4.7.2 Stable; no fallback engine."""
import argparse
import json
import re
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    version = subprocess.run([args.godot, '--version'], capture_output=True, text=True,
                             check=True, timeout=30).stdout.strip()
    if not re.match(r'^4\.7\.2\.stable(?:\.|$)', version):
        raise SystemExit(f'Requires exactly 4.7.2 Stable; found {version!r}. No fallback allowed.')

    def run(options):
        result = subprocess.run([args.godot, '--path', str(root), *options],
                                capture_output=True, text=True, timeout=240)
        print(result.stdout, end='')
        print(result.stderr, end='')
        output = result.stdout + '\n' + result.stderr
        if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
            raise SystemExit(result.returncode or 1)

    run(['--headless', '--editor', '--import', '--quit'])
    suites = [('suite', 'latest'), ('revision_suite', 'revision')]
    if (root/'assets/converted/ped_library.res').exists():
        suites.append(('imported_suite', 'imported'))
    if (root/'assets/converted/models/player.scn').exists():
        suites.extend((name+'_suite', name) for name in
                      ('presentation', 'native_action', 'motion', 'systems', 'foundation'))
    if (root/'assets/converted/stories_animation_source.json').exists():
        suites.extend([('stories_assets', 'stories_assets'), ('stories_suite', 'stories')])
    total = 0
    for script, report_name in suites:
        report_path = root/'tests'/(report_name+'_results.json')
        report_path.unlink(missing_ok=True)  # A stale report cannot satisfy this run.
        run(['--headless', '--fixed-fps', '60', '--script', f'res://tests/run_{script}.gd'])
        report = json.loads(report_path.read_text())
        if report['failures'] or not all(item['passed'] for item in report['results']):
            raise SystemExit(f'{script}: failed assertions')
        count = report.get('assertions', len(report['results']))
        total += count
        print(f'Verified {count} assertions: {script}')
    print(f'Verified {total} assertions across {len(suites)} suites with {version}')


if __name__ == '__main__':
    main()
