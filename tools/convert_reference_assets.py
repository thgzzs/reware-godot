#!/usr/bin/env python3
"""Read bounded VC ANPK chunks and retain every track/key in portable JSON.
No game code or third-party converter implementation is bundled.
Godot build_animation_library.gd emits the native AnimationLibrary.
"""
from pathlib import Path
import argparse,hashlib,json,math,re,struct

class FormatError(ValueError):pass

def parse_ifp(data):
 def chunk(offset,limit,expected=None):
  if offset+8>limit:raise FormatError(f'truncated chunk at {offset}')
  tag=data[offset:offset+4].decode('ascii');size=struct.unpack_from('<I',data,offset+4)[0]
  start=offset+8;end=start+size
  if end>limit:raise FormatError(f'{tag} exceeds parent at {offset}')
  if expected and tag!=expected:raise FormatError(f'expected {expected}; got {tag} at {offset}')
  return tag,start,end,(end+3)&~3
 def name(start,end):return data[start:end].split(b'\0',1)[0].decode('ascii')
 _,start,end,_=chunk(0,len(data),'ANPK')
 _,a,b,cursor=chunk(start,end,'INFO')
 count=struct.unpack_from('<I',data,a)[0];package=name(a+4,b)
 clips=[];warnings=[]
 for clip_index in range(count):
  _,a,b,cursor=chunk(cursor,end,'NAME');clip_name=name(a,b)
  _,dstart,dend,next_clip=chunk(cursor,end,'DGAN')
  _,a,b,part=chunk(dstart,dend,'INFO');bone_count=struct.unpack_from('<I',data,a)[0]
  tracks=[]
  for track_index in range(bone_count):
   _,cstart,cend,next_track=chunk(part,dend,'CPAN')
   _,a,b,key_pos=chunk(cstart,cend,'ANIM')
   if b-a not in [44,48]:raise FormatError(f'unsupported ANIM header {b-a}')
   bone=name(a,a+28);frames=struct.unpack_from('<I',data,a+28)[0]
   bone_id=struct.unpack_from('<i',data,a+40)[0] if b-a==44 else None
   sibling=list(struct.unpack_from('<ii',data,a+40)) if b-a==48 else None
   keys=[];kind='K000'
   if frames:
    kind,ka,kb,kend=chunk(key_pos,cend)
    if kind not in ['KR00','KRT0','KRTS']:raise FormatError(f'unsupported frame kind {kind}')
    stride={'KR00':20,'KRT0':32,'KRTS':44}[kind]
    if kb-ka!=frames*stride:raise FormatError(f'frame byte count mismatch for {clip_name}/{bone}')
    for frame in range(frames):
     values=struct.unpack_from('<'+'f'*(stride//4),data,ka+frame*stride)
     if not all(math.isfinite(v) for v in values):raise FormatError('nonfinite key')
     t=values[-1]
     if t < -1e-6 or (keys and t<keys[-1]['time']):raise FormatError('nonmonotonic time')
     # ANPK stores conjugated quaternions. Convert basis (x,y,z)->(x,z,-y).
     qx,qy,qz,qw=values[:4]
     q=[-qx,-qz,qy,qw]
     norm=math.sqrt(sum(v*v for v in q))
     if norm<1e-8:raise FormatError('zero quaternion')
     if abs(norm-1)>0.002:warnings.append(f'quaternion renormalized: {clip_name}/{bone}/{frame}')
     q=[v/norm for v in q]
     if keys and sum(v*w for v,w in zip(q,keys[-1]['rotation']))<0:q=[-v for v in q]
     key={'time':t,'rotation':q}
     if kind in ['KRT0','KRTS']:
      x,y,z=values[4:7];key['position']=[x,z,-y]
     if kind=='KRTS':
      x,y,z=values[7:10];key['scale']=[x,z,y]
     keys.append(key)
   tracks.append({'bone':bone,'bone_id':bone_id,'sibling_metadata':sibling,'kind':kind,'keys':keys})
   part=next_track
  if part!=dend:raise FormatError(f'unconsumed DGAN bytes {dend-part}')
  duration=max((k['time'] for tr in tracks for k in tr['keys']),default=0)
  clips.append({'name':clip_name,'duration':duration,'tracks':tracks})
  cursor=next_clip
 if cursor!=end:raise FormatError(f'unconsumed package bytes {end-cursor}')
 if any(data[end:]):raise FormatError('unexpected nonzero trailing data')
 if len({c['name'] for c in clips})!=len(clips):raise FormatError('duplicate clip names')
 return {'schema':1,'format':'ANPK','package':package,'source_sha256':hashlib.sha256(data).hexdigest(),'basis':'source XYZ -> Godot X,Z,-Y; quaternion conjugated then basis-converted','clips':clips,'warnings':warnings}

def lines(path):
 for number,line in enumerate(path.read_text(encoding='cp1252').splitlines(),1):
  line=re.split(r'//|#|;',line,1)[0].strip()
  if line and line.lower() not in ['end','the end']:yield number,line

def parse_fight_moves(path):
 """Preserve row order (source move IDs) and frame units; no invented HP mapping."""
 moves=[]
 for n,line in lines(path):
  t=line.split()
  if t[0].upper()=='ENDWEAPONDATA':return moves
  if len(t)!=10:raise FormatError(f'{path.name}:{n}: expected 10 columns')
  try:
   values=list(map(float,t[1:6]));damage=int(t[8]);flags=int(t[9])
  except ValueError as e:raise FormatError(f'{path.name}:{n}: invalid number') from e
  if not all(math.isfinite(x) and x>=0 for x in values) or damage<0 or flags<0 or t[6] not in 'GLMHN' or len(t[6])!=1:
   raise FormatError(f'{path.name}:{n}: invalid move fields')
  moves.append({'index':len(moves),'name':t[0],'start_frame':values[0],'end_frame':values[1],'combo_frame':values[2],
   'start_seconds':values[0]/30.0,'end_seconds':values[1]/30.0,'combo_seconds':values[2]/30.0,
   'strike_radius_source':values[3],'extend_reach_multiplier':values[4],'hit_level':t[6],
   'animation_source':t[7],'damage_source':damage,'flags':flags,
   'has_strike_window':t[6]!='N' and values[1]>values[0]})
 raise FormatError(f'{path.name}: missing ENDWEAPONDATA')

def parse_data(folder):
 stats=[]
 for n,line in lines(folder/'pedstats.dat'):
  t=line.split()
  if len(t)!=10:raise FormatError(f'pedstats.dat:{n}: expected 10 columns')
  stats.append(dict(zip(['name','flee_distance','heading_rate_per_normalized_tick','fear','temper','lawfulness','sexiness','attack_multiplier','defense_multiplier','flags'],[t[0],*map(float,t[1:9]),int(t[9])])) )
 weapons=[]
 for n,line in lines(folder/'weapon.dat'):
  t=line.split()
  if t[0].upper()=='ENDWEAPONDATA':break
  if len(t)!=26:raise FormatError(f'weapon.dat:{n}: expected 26 columns; got {len(t)}')
  nums=[float(v) for v in t[2:14]]
  weapons.append({'name':t[0],'fire_type':t[1],'range':nums[0],'firing_rate_ms':nums[1],'reload_ms':nums[2],'clip_size':int(nums[3]),'damage':nums[4],'projectile_speed':nums[5],'radius':nums[6],'lifespan':nums[7],'spread_source':nums[8],'fire_offset_source':nums[9:12],'animation_group':t[14],'animation_frames':[float(v) for v in t[15:22]],'model_ids':[int(v) for v in t[22:24]],'flags':int(t[24],16),'slot':int(t[25])})
 groups=[]
 for n,line in lines(folder/'pedgrp.dat'):
  names=[x.strip() for x in line.split(',')]
  if len(names)!=16:raise FormatError(f'pedgrp.dat:{n}: expected 16 model slots; got {len(names)}')
  groups.append({'index':len(groups),'models':names})
 types=[];current=None
 for n,line in lines(folder/'ped.dat'):
  t=line.split()
  if t[0].lower() in ['threat','avoid']:
   if current is None:raise FormatError('ped relationship without type')
   current[t[0].lower()]=t[1:]
  else:
   if len(t)!=6:raise FormatError(f'ped.dat:{n}: expected 6 columns')
   current={'name':t[0],'source_values':[float(v) for v in t[1:]],'threat':[],'avoid':[]};types.append(current)
 handling=[];special=[]
 for n,line in lines(folder/'handling.cfg'):
  t=line.split()
  if line.startswith(('%','!','$')):
   special.append({'section':line[0],'name':t[0][1:],'tokens':t[1:]});continue
  if len(t)!=33:raise FormatError(f'handling.cfg:{n}: expected 33 columns; got {len(t)}')
  v=t
  handling.append({'name':v[0],'mass':float(v[1]),'dimensions_source':list(map(float,v[2:5])),'center_of_mass_source':list(map(float,v[5:8])),'percent_submerged':float(v[8]),'traction_multiplier':float(v[9]),'traction_loss':float(v[10]),'traction_bias':float(v[11]),'gears':int(v[12]),'max_speed_kmh':float(v[13]),'acceleration_source':float(v[14]),'drive':v[15],'engine':v[16],'brake_deceleration_source':float(v[17]),'brake_bias':float(v[18]),'abs':bool(int(v[19])),'steering_degrees':float(v[20]),'spring_source':float(v[21]),'damper_source':float(v[22]),'seat_offset':float(v[23]),'collision_damage_multiplier':float(v[24]),'value':int(v[25]),'suspension_upper':float(v[26]),'suspension_lower':float(v[27]),'suspension_bias':float(v[28]),'anti_dive':float(v[29]),'flags':int(v[30],16),'front_light':int(v[31]),'rear_light':int(v[32])})
 return {'schema':1,'ped_stats':stats,'weapons':weapons,'fight_moves':parse_fight_moves(folder/'fistfite.dat') if (folder/'fistfite.dat').is_file() else [],'ped_groups':groups,'ped_types':types,'handling':handling,'special_handling':special,'unmapped_fields':'ped.dat source_values and special handling retained without inventing semantics; weapon animation group needs additional IFP blocks; fight damage is a source input, not final HP'}

def convert(folder,output):
 output.mkdir(parents=True,exist_ok=True)
 anim=parse_ifp((folder/'ped.ifp').read_bytes())
 (output/'ped_animation_source.json').write_text(json.dumps(anim,separators=(',',':')))
 data=parse_data(folder)
 clip_names={c['name'].lower():c['name'] for c in anim['clips']}
 for move in data['fight_moves']:
  move['animation_clip']=clip_names.get(move['animation_source'].lower(),'') if move['animation_source'] not in ['null','default'] else ''
  move['animation_resolution']='resolved' if move['animation_clip'] else ('source_sentinel' if move['animation_source'] in ['null','default'] else 'missing')
 (output/'gameplay_database.json').write_text(json.dumps(data,indent=2))
 catalog=[]
 for c in anim['clips']:
  root=next((t for t in c['tracks'] if t['bone'].lower()=='root' and t['kind'] in ['KRT0','KRTS']),None)
  delta=[root['keys'][-1]['position'][i]-root['keys'][0]['position'][i] for i in range(3)] if root and root['keys'] else [0,0,0]
  catalog.append({'name':c['name'],'duration':c['duration'],'tracks':len(c['tracks']),'keys':sum(len(t['keys']) for t in c['tracks']),'root_delta':delta,'average_horizontal_speed':math.hypot(delta[0],delta[2])/c['duration'] if c['duration'] else 0})
 (output/'animation_catalog.json').write_text(json.dumps({'clips':catalog,'total_clips':len(catalog),'source_sha256':anim['source_sha256']},indent=2))
 report={'clips':len(catalog),'tracks':sum(len(c['tracks']) for c in anim['clips']),'keys':sum(c['keys'] for c in catalog),'source_bytes':(folder/'ped.ifp').stat().st_size,'data_counts':{k:len(v) for k,v in data.items() if isinstance(v,list)},'warnings':anim['warnings'],'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.iterdir() if p.is_file()},'model_status':'This pass covers animation/data only; see models/model_conversion_report.json for separate selected-model conversion status'}
 (output/'conversion_report.json').write_text(json.dumps(report,indent=2))
 print(json.dumps(report,indent=2))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();convert(a.source,a.output)
