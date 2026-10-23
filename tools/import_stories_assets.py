from pathlib import Path
import sys,json,zipfile,hashlib
import argparse
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description="Convert every Stories IFP and only reviewed model/texture dependencies; no runtime ASI.")
parser.add_argument('--models-zip',type=Path,required=True)
parser.add_argument('--animations-zip',type=Path,required=True)
parser.add_argument('--dragonff',type=Path,required=True,help='External DragonFF checkout at the documented pinned commit')
parser.add_argument('--model-roles',type=Path,default=root/'assets/stories_asset_roles.json')
args=parser.parse_args()
sys.path.insert(0,str(root/'tools'));sys.path.insert(0,str(args.dragonff.resolve()))
for name in ['pedstats.dat','handling.cfg','pedgrp.dat','ped.dat']:
 if not(root/'assets/local_source'/name).is_file():raise SystemExit('Import base gameplay data first; missing '+name)
for folder in ['assets/converted/models/textures','assets/local_models','assets/local_source/legacy']:(root/folder).mkdir(parents=True,exist_ok=True)
for name in ['weapon.dat','fistfite.dat']:
 original=root/'assets/local_source'/name;legacy=root/'assets/local_source/legacy'/name
 if original.is_file()and not legacy.exists():legacy.write_bytes(original.read_bytes())
from convert_reference_assets import parse_ifp,parse_data
from convert_model_placeholders import model_data,export_textures
from gtaLib import dff,txd
# Retain every block under a collision-free namespace; active aliases prefer VCS and LCS bikes.
z=zipfile.ZipFile(args.animations_zip)
clips=[];aliases={};catalog=[]
for name in z.namelist():
 if not name.lower().endswith('.ifp'):continue
 package=parse_ifp(z.read(name));game='vcs'if'/VCS Animations/'in name else'lcs';block=Path(name).stem.lower();ns=f'{game}__{block}'
 private=root/'assets/local_source/stories'/game/(block+'.ifp');private.parent.mkdir(parents=True,exist_ok=True);private.write_bytes(z.read(name))
 active=game=='vcs' and ('/anim/'in name or '/VCS IFP' in name or '/LCS Bike' in name)
 for c in package['clips']:
  original=c['name'];key=ns+'__'+original;entry={**c,'name':key,'source_sha256':package['source_sha256'],'source_clip':original,'namespace':ns};clips.append(entry)
  if active:aliases[original]=key
 catalog.append({'path':name,'namespace':ns,'source_sha256':package['source_sha256'],'clips':len(package['clips']),'active':active,'bindings':sorted({t['bone']for c in package['clips']for t in c['tracks']})})
for fname in ['weapon.dat','fistfite.dat']:
 content=z.read('Stories Animation Pack Complete Set/VCS Animations/data/'+fname)
 (root/'assets/local_source'/fname).write_bytes(content)
 for game in ['VCS','LCS']:
  dst=root/'assets/local_source/stories'/game.lower()/fname;dst.write_bytes(z.read(f'Stories Animation Pack Complete Set/{game} Animations/data/{fname}'))
for game in ['VCS','LCS']:
 (root/'assets/local_source/stories'/game.lower()/'VC.CustomAnimsData.dat').write_bytes(z.read(f'Stories Animation Pack Complete Set/{game} Animations/scripts/VC.CustomAnimsData.dat'))
for name in ['readme.txt','credits.txt']:(root/'assets/local_source/stories'/name).write_bytes(z.read('Stories Animation Pack Complete Set/'+name))
source={'schema':2,'format':'ANPK','package':'Stories complete catalog','source_sha256':hashlib.sha256((args.animations_zip).read_bytes()).hexdigest(),'clips':clips,'aliases':aliases,'warnings':[]}
(root/'assets/converted/stories_animation_source.json').write_text(json.dumps(source,separators=(',',':')))
(root/'assets/converted/stories_catalog.json').write_text(json.dumps({'blocks':catalog,'original_clips':len(clips),'active_aliases':len(aliases),'policy':'VCS core and PS2 converted weapon blocks; LCS converted bike blocks. Remaining LCS clips retained namespaced; no ASI execution.'},indent=2))
db=parse_data(root/'assets/local_source')
lookup={name.lower():name for name in aliases}
for move in db['fight_moves']:
 move['animation_clip']=lookup.get(move['animation_source'].lower(),'') if move['animation_source']not in ['null','default']else''
 move['animation_resolution']='resolved'if move['animation_clip']else('source_sentinel'if move['animation_source']in ['null','default']else'missing')
(root/'assets/converted/gameplay_database.json').write_text(json.dumps(db,indent=2))
# Exact model roles from source model IDs/embedded RenderWare roots.
roles=json.loads(args.model_roles.read_text())
from inspect_rw_archive import scan
index=scan(args.models_zip)['entries'];models=[];selection=[];wanted=set();out=root/'assets/converted/models';textures=out/'textures';private=root/'assets/local_models';report={'decoder':'Parik27/DragonFF@54baca8ea2ed95fe5a86917f44399ce677379c59','texture_exports':[],'models':[],'selected_payload_bytes':0,'full_img_extracted':False};archive=zipfile.ZipFile(args.models_zip)
with archive.open('gta3.img')as img:
 for role,frame in sorted(roles.items(),key=lambda pair:next(x['offset']for x in index if x['kind']=='dff'and x['names']and x['names'][0].lower()==pair[1].lower())):
  row=next(x for x in index if x['kind']=='dff'and x['names']and x['names'][0].lower()==frame.lower());img.seek(row['offset']);data=img.read(row['bytes']);obj=dff.dff();obj.load_memory(data);model=model_data(obj.clumps[0],role);models.append(model);(private/(role+'.dff')).write_bytes(data)
  uses={t for g in model['geometries']for m in g['materials']for t in m['textures']};wanted|=uses
  record={'role':role,'frame':frame,'offset':row['offset'],'bytes':row['bytes'],'sha256':hashlib.sha256(data).hexdigest(),'textures':sorted(uses)};selection.append(record);report['selected_payload_bytes']+=len(data)
# Skip textures already delivered; look up exact names without extracting the archive.
needed={t for t in wanted if not(textures/(t.replace(' ','_')+'.png')).exists()};assigned={};txds={}
for t in needed:
 candidates=[x for x in index if x['kind']=='txd'and t in [n.lower().strip()for n in x['names']]]
 if candidates:
  row=min(candidates,key=lambda x:x['bytes']);key=row['offset'];txds[key]=row;assigned.setdefault(key,[]).append(t)
loose_needed=needed-set(t for ts in assigned.values()for t in ts)
for fname in ['generic.txd','MISC.TXD','particle.txd','hud.txd']:
 if not loose_needed:break
 data=archive.read(fname);obj=txd.txd();obj.load_memory(data);available={x.name.lower().strip()for x in obj.native_textures};use=sorted(loose_needed&available)
 if use:export_textures(txd,data,use,fname,textures,report);loose_needed-=set(use)
if loose_needed:raise ValueError('Unresolved texture dependencies '+str(loose_needed))
with archive.open('gta3.img')as img:
 for offset in sorted(txds):
  row=txds[offset];img.seek(offset);data=img.read(row['bytes']);label='stories_'+str(offset);(private/(label+'.txd')).write_bytes(data);export_textures(txd,data,sorted(assigned[offset]),label,textures,report);report['selected_payload_bytes']+=len(data)
# New native scenes only; keep existing player/Idaho/Colt/trashcan scenes untouched.
(out/'stories_models.json').write_text(json.dumps({'models':models},separators=(',',':')))
report['models']=selection;(out/'stories_model_report.json').write_text(json.dumps(report,indent=2));(root/'assets/stories_model_selection.json').write_text(json.dumps({'models':selection,'archive_full_sha256':hashlib.sha256((args.models_zip).read_bytes()).hexdigest(),'full_archive_unpacked':False},indent=2))
print('Converted blocks',len(catalog),'clips',len(clips),'active aliases',len(aliases),'models',len(models),'new textures',len(report['texture_exports']),'payload bytes',report['selected_payload_bytes'],flush=True)

# Preserve actual model IDs as the rig binding contract; do not guess by bone name.
model_source=root/'assets/converted/models/models.json'
if model_source.is_file():
 player=next((m for m in json.loads(model_source.read_text())['models']if m['role']=='player'),None)
 if player is not None:
  ids={f['name']:f['bone_id']for f in player['frames']if f['bone_id']>=0}
  (out/'player_rig.tres').write_text('[gd_resource type="Resource" script_class="AnimationRigProfile" load_steps=2 format=3]\n[ext_resource type="Script" path="res://animation/rig_profile.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nbone_ids = Dictionary[String,int]('+json.dumps(ids)+')\n')
print('Next: import with exact Godot 4.7.2 Stable, then run build_stories_library.gd and build_model_scenes.gd -- --source=stories_models.json. Originals remain outside public git.')
