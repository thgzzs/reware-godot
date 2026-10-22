#!/usr/bin/env python3
"""Rebuild private user assets without uploading them to an external service."""
import argparse,shutil,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--source',type=Path,required=True)
p.add_argument('--godot',required=True)
a=p.parse_args()
required=['ped.ifp','weapon.dat','pedgrp.dat','pedstats.dat','handling.cfg','ped.dat']
for name in required:
 if not (a.source/name).is_file():raise SystemExit('Missing source: '+name)
private=root/'assets/local_source';private.mkdir(parents=True,exist_ok=True)
for name in required + [name for name in ['fistfite.dat'] if (a.source/name).is_file()]:
 dest=private/name
 if (a.source/name).resolve()!=dest.resolve():shutil.copy2(a.source/name,dest)
commands=[
 [sys.executable,str(root/'tools/convert_reference_assets.py'),'--source',str(private),'--output',str(root/'assets/converted')],
 [a.godot,'--path',str(root),'--headless','--editor','--import','--quit'],
 [a.godot,'--path',str(root),'--headless','--script','res://tools/build_animation_library.gd']]
for cmd in commands:
 result=subprocess.run(cmd,capture_output=True,text=True)
 print(result.stdout,end='');print(result.stderr,end='')
 if result.returncode or 'SCRIPT ERROR:' in result.stderr or '\nERROR:' in result.stderr:raise SystemExit(result.returncode or 1)
print('Converted all supplied ANPK clips and gameplay data. Model binding remains unverified until DFF rigs are supplied.')
