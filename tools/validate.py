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
for options in [ ['--headless','--editor','--import','--quit'], ['--headless','--fixed-fps','60','--script','res://tests/run_suite.gd'] ]:
 result=subprocess.run([args.godot,'--path',str(root),*options],capture_output=True,text=True)
 print(result.stdout,end='')
 print(result.stderr,end='')
 if result.returncode or 'SCRIPT ERROR:' in result.stderr or '\nERROR:' in result.stderr:
  raise SystemExit(result.returncode or 1)
report=json.loads((root/'tests/latest_results.json').read_text())
if report['failures']:
 raise SystemExit(1)
print(f"Verified {report['assertions']} assertions with {version}")
