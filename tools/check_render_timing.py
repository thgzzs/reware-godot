#!/usr/bin/env python3
"""Compare native fixed-command playback across render rates; physics stays at 60 Hz."""
import argparse
import json
import math
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
version = subprocess.run([args.godot, '--version'], capture_output=True, text=True, check=True).stdout.strip()
if not re.match(r'^4\.7\.2\.stable(?:\.|$)', version):
    raise SystemExit(f'Requires exactly 4.7.2 Stable, found {version}')
if not (root / 'assets/converted/models/player.scn').exists():
    raise SystemExit('Native timing comparison requires the selected private models and animation library.')
reports = {}
for case in ['30', '60', '120', '144', 'variable']:
    command = [args.godot, '--path', str(root), '--headless']
    if case != 'variable':
        command += ['--fixed-fps', case]
    command += ['--script', 'res://tests/run_timing_scenario.gd', '--', '--case=' + case]
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr
    (root / 'tests' / ('timing_' + case + '.log')).write_text(log)
    if result.returncode or 'SCRIPT ERROR:' in log or '\nERROR:' in log:
        raise SystemExit(log)
    reports[case] = json.loads((root / 'tests' / ('timing_' + case + '.json')).read_text())
baseline = reports['60']['snapshots']
results = []
for case, report in reports.items():
    rows = report['snapshots']
    position = max(math.dist(a['position'], b['position']) for a, b in zip(baseline, rows))
    velocity = max(math.dist(a['velocity'], b['velocity']) for a, b in zip(baseline, rows))
    car = max(math.dist(a['car'], b['car']) for a, b in zip(baseline, rows))
    pose = max(min(math.dist(a['pose'], b['pose']), math.dist(a['pose'], [-x for x in b['pose']])) for a, b in zip(baseline, rows))
    states = all(all(a[key] == b[key] for key in ('shots', 'phase', 'clip')) for a, b in zip(baseline, rows))
    passed = len(rows) == len(baseline) and max(position, velocity, car, pose) < 0.002 and states
    row = dict(case=case, passed=passed, max_position_m=position, max_velocity_mps=velocity,
               max_car_position_m=car, max_pose_quaternion_delta=pose, state_shots_equal=states,
               render_steps=report['render_steps'], render_dt_range=report['render_dt_range'])
    results.append(row)
    print(row, flush=True)
output = dict(physics_hz=60, scope='One local CPU fixed-command native fixture; fixed render deltas and real-clock varying render cap. Not cross-platform determinism or GPU timing.', results=results, failures=sum(not row['passed'] for row in results))
(root / 'tests/render_timing_results.json').write_text(json.dumps(output, indent=2) + '\n')
raise SystemExit(bool(output['failures']))
