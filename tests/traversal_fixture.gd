class_name TraversalTestFixture
extends RefCounted
## Public synthetic motion; native asset validation remains a separate suite.
static func library() -> AnimationLibrary:
 var lib:=AnimationLibrary.new()
 for name in ["IDLE_stance","WALK_start","WALK_player","run_player","sprint_civi","Run_stop","Run_stopR","JUMP_launch","JUMP_glide","JUMP_land","FALL_fall","FALL_glide","FALL_land","FALL_front","FALL_back","FALL_collapse","GETUP","GETUP_front","IDLE_armed","RIFLE_fire","shotgun_fire","RIFLE_reload","shotgun_reload"]:
  var anim:=Animation.new();anim.length=0.5
  var distance:=0.0
  if name=="WALK_player":distance=0.75
  elif name=="run_player":distance=2.0
  elif name=="sprint_civi":distance=3.0
  elif name=="WALK_start":distance=0.3
  elif name=="JUMP_launch":anim.length=0.2;distance=0.77
  elif name=="JUMP_land":anim.length=0.2;distance=1.17
  elif name=="FALL_land":anim.length=0.566;distance=0.38
  elif name=="FALL_fall":anim.length=0.933;distance=2.7
  elif name=="FALL_glide":anim.length=0.8
  var track:=anim.add_track(Animation.TYPE_POSITION_3D);anim.track_set_path(track,"Skeleton3D:Root")
  anim.position_track_insert_key(track,0,Vector3.ZERO);anim.position_track_insert_key(track,anim.length,Vector3(0,0,-distance))
  lib.add_animation(name,anim)
 return lib
