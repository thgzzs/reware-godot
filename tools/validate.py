#!/usr/bin/env python3
"""Validate with the exact stable editor; never download or select substitutes."""
import argparse
import json
import re
import subprocess
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--godot',required=True,help='Path to Godot 4.7.2 Stable executable')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
version=subprocess.run([args.godot,'--version'],capture_output=True,text=True,check=True).stdout.strip()
if not re.match(r'^4\.7\.2\.stable(?:\.|$)',version):
 raise SystemExit(f'Requires exactly 4.7.2 Stable; found {version!r}. No fallback allowed.')
checks=[ ['--headless','--editor','--import','--quit'], ['--headless','--fixed-fps','60','--script','res://tests/run_suite.gd'], ['--headless','--fixed-fps','60','--script','res://tests/run_revision_suite.gd'] ]
if (root/'assets/converted/ped_library.res').exists():
 checks.append(['--headless','--fixed-fps','60','--script','res://tests/run_imported_suite.gd'])
if (root/'assets/converted/models/player.scn').exists():
 checks.append(['--headless','--fixed-fps','60','--script','res://tests/run_presentation_suite.gd'])
 checks.append(['--headless','--fixed-fps','60','--script','res://tests/run_native_action_suite.gd'])
 checks.append(['--headless','--fixed-fps','60','--script','res://tests/run_motion_suite.gd'])
for options in checks:
 result=subprocess.run([args.godot,'--path',str(root),*options],capture_output=True,text=True)
 print(result.stdout,end='')
 print(result.stderr,end='')
 if result.returncode or 'SCRIPT ERROR:' in result.stderr or '\nERROR:' in result.stderr:
  raise SystemExit(result.returncode or 1)
report=json.loads((root/'tests/latest_results.json').read_text())
if report['failures']:
 raise SystemExit(1)
print(f"Verified {report['assertions']} assertions with {version}")
revision=json.loads((root/'tests/revision_results.json').read_text())
if revision['failures']:raise SystemExit(1)
print(f"Verified {revision['assertions']} action/door/impact assertions")

if (root/'tests/imported_results.json').exists() and (root/'assets/converted/ped_library.res').exists():
 imported=json.loads((root/'tests/imported_results.json').read_text())
 if imported['failures']:raise SystemExit(1)
 print(f"Verified {imported['assertions']} imported-asset assertions")

if (root/'assets/converted/models/player.scn').exists():
 presentation=json.loads((root/'tests/presentation_results.json').read_text())
 if presentation['failures']:raise SystemExit(1)
 print(f"Verified {presentation['assertions']} model/presentation assertions")
 native=json.loads((root/'tests/native_action_results.json').read_text())
 if native['failures']:raise SystemExit(1)
 print(f"Verified {native['assertions']} native action assertions")


if (root/'assets/converted/models/player.scn').exists():
 motion=json.loads((root/'tests/motion_results.json').read_text())
 if motion['failures']:raise SystemExit(1)
 print(f"Verified {len(motion['results'])} temporal motion/seat/impact assertions")
