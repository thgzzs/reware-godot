#!/usr/bin/env python3
"""Decode only the reviewed IMG ranges to portable model data + used PNGs.

Requires an external pinned DragonFF checkout (--dragonff). It is an offline
build dependency, not bundled in the game. No archive-wide unpack is performed.
"""
import argparse, hashlib, json, math, re, sys, zipfile
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]

def digest(data):return hashlib.sha256(data).hexdigest()
def file_digest(path):
 h=hashlib.sha256()
 with path.open('rb') as source:
  for block in iter(lambda:source.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def vector(v):return [v[0],v[2],-v[1]]
def matrix(rotation,position):
 # C * R * C^-1, columns stored as right/up/at in RenderWare.
 columns=[vector(rotation[0]),vector(rotation[2]),[-x for x in vector(rotation[1])]]
 return [*columns,vector(position)]
def skin_matrix(rows):return matrix(rows[:3],rows[3][:3])
def clean(name):return re.sub(r'[^a-z0-9_.-]','_',name.lower().strip())

def model_data(clump,role):
 frames=[]
 for i,f in enumerate(clump.frame_list):
  frames.append({'name':'ModelRoot' if role=='player' and i==0 else f.name,'source_name':f.name,'parent':f.parent,
   'transform':matrix(f.rotation_matrix,f.position),'bone_id':f.bone_data.header.id if f.bone_data else -1})
 geometries=[]
 for g in clump.geometry_list:
  mats=[]
  for mat in g.materials:
   mats.append({'color':list(mat.color),'textures':[t.name.lower().strip() for t in mat.textures]})
  geo={'vertices':[vector(v) for v in g.vertices],'normals':[vector(v) for v in g.normals],
   'uv':[[v.u,v.v] for v in g.uv_layers[0]] if g.uv_layers else [],
   'colors':[list(v) for v in g.prelit_colors],
   'triangles':[[t.a,t.b,t.c,t.material] for t in g.triangles],'materials':mats}
  if 'skin' in g.extensions:
   skin=g.extensions['skin']
   hierarchy=next(f.bone_data for f in clump.frame_list if f.bone_data and f.bone_data.header.bone_count>0)
   frame_by_id={f.bone_data.header.id:i for i,f in enumerate(clump.frame_list) if f.bone_data}
   bones=[-1]*skin.num_bones
   for b in hierarchy.bones:bones[b.index]=frame_by_id[b.id]
   if -1 in bones:raise ValueError('Incomplete skin binding')
   geo['skin']={'frame_indices':bones,'inverse_binds':[skin_matrix(m) for m in skin.bone_matrices],
    'indices':[list(v) for v in skin.vertex_bone_indices],'weights':[list(v) for v in skin.vertex_bone_weights]}
  geometries.append(geo)
 return {'role':role,'frames':frames,'geometries':geometries,
  'atomics':[{'frame':a.frame,'geometry':a.geometry,'flags':a.flags} for a in clump.atomic_list]}

def convert(archive,selection,dragonff,output):
 sys.path.insert(0,str(dragonff.resolve()))
 from gtaLib import dff,txd
 output.mkdir(parents=True,exist_ok=True)
 textures=output/'textures';textures.mkdir(exist_ok=True)
 private=ROOT/'assets/local_models';private.mkdir(parents=True,exist_ok=True)
 records=json.loads(selection.read_text())
 models=[];report={'schema':1,'archive_zip_sha256':file_digest(archive),'directory_supplied':False,
  'range_identification':'sector-aligned bounded RenderWare roots; labels from embedded frame/material/texture metadata, not original archive filenames',
  'decoder':'Parik27/DragonFF@54baca8ea2ed95fe5a86917f44399ce677379c59','original_models':[],'texture_exports':[],
  'unpacked_entire_archive':False,'selected_img_payload_bytes':0}
 with zipfile.ZipFile(archive) as z:
  with z.open('gta3.img') as image:
   for row in sorted(records['models'],key=lambda r:r['offset']):
    image.seek(row['offset']);data=image.read(row['bytes'])
    if len(data)!=row['bytes'] or digest(data)!=row['sha256']:raise ValueError('Model source hash mismatch: '+row['role'])
    (private/(row['role']+'.dff')).write_bytes(data)
    decoded=dff.dff();decoded.load_memory(data)
    if len(decoded.clumps)!=1:raise ValueError('Expected one reviewed clump')
    models.append(model_data(decoded.clumps[0],row['role']))
    report['original_models'].append(row)
    report['selected_img_payload_bytes']+=len(data)
  with z.open('gta3.img') as image:
   for row in sorted(records['dictionaries'],key=lambda r:r['offset']):
    image.seek(row['offset']);data=image.read(row['bytes'])
    (private/(row['label']+'.txd')).write_bytes(data)
    report['selected_img_payload_bytes']+=len(data)
    export_textures(txd,data,row['wanted'],row['label'],textures,report)
  for row in records['loose_dictionaries']:
   data=z.read(row['file'])
   export_textures(txd,data,row['wanted'],row['file'],textures,report)
 (output/'models.json').write_text(json.dumps({'schema':1,'basis':'XYZ -> X,Z,-Y; transforms conjugated by basis','models':models},separators=(',',':')))
 (output/'model_conversion_report.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'models':len(models),'textures':len(report['texture_exports']),'img_payload_bytes':report['selected_img_payload_bytes']}))

def export_textures(txd,data,wanted,label,output,report):
 decoded=txd.txd();decoded.load_memory(data)
 by_name={t.name.lower().strip():t for t in decoded.native_textures}
 for name in wanted:
  texture=by_name[name.lower().strip()]
  rgba=texture.to_rgba()
  if rgba is None or len(rgba)!=texture.width*texture.height*4:raise ValueError('Invalid RGBA pixels: '+name)
  image=Image.frombytes('RGBA',(texture.width,texture.height),rgba)
  path=output/(clean(name)+'.png');image.save(path)
  report['texture_exports'].append({'name':name,'dictionary_label':label,'source_dictionary_sha256':digest(data),
   'path':'textures/'+path.name,'width':texture.width,'height':texture.height,'rgba_sha256':digest(rgba),'png_sha256':digest(path.read_bytes())})

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--zip',type=Path,required=True);p.add_argument('--selection',type=Path,default=ROOT/'assets/model_selection.json')
 p.add_argument('--dragonff',type=Path,required=True);p.add_argument('--output',type=Path,default=ROOT/'assets/converted/models')
 a=p.parse_args();convert(a.zip,a.selection,a.dragonff,a.output)
