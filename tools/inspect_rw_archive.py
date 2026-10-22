#!/usr/bin/env python3
"""Inspect embedded names without unpacking an IMG's model/texture files.
Fallback for the supplied PC VC ZIP without a DIR index. Original archive
filenames and completeness cannot be recovered by this heuristic. Use the
matching DIR with extract_selected_img.py when one is available.
"""
import argparse,json,struct,zipfile
from pathlib import Path

def chunks(data,start=12,end=None):
 end=len(data) if end is None else end
 while start+12<=end:
  kind,size,version=struct.unpack_from('<III',data,start)
  stop=start+12+size
  if stop>end:raise ValueError('child exceeds parent')
  yield kind,start+12,stop
  start=stop

def names(data,kind):
 result=[]
 if kind==22:
  for tag,a,b in chunks(data):
   if tag==21:
    for child,c,d in chunks(data,a,b):
     if child==1:
      result.append(data[c+8:c+40].split(b'\0')[0].decode('ascii',errors='replace'))
 elif kind==16:
  for tag,a,b in chunks(data):
   if tag==14:
    for child,c,d in chunks(data,a,b):
     if child==3:
      name=''
      for ext,e,f in chunks(data,c,d):
       if ext==0x253F2FE:name=data[e:f].split(b'\0')[0].decode('ascii',errors='replace')
      result.append(name)
 return result

def scan(archive):
 rows=[];unknown=0
 with zipfile.ZipFile(archive) as z:
  info=z.getinfo('gta3.img')
  with z.open(info) as source:
   offset=0
   while offset+12<=info.file_size:
    header=source.read(12)
    kind,size,version=struct.unpack('<III',header)
    if kind in [16,22] and 0<size<32*1024*1024 and offset+size+12<=info.file_size and version in [0x1003ffff,0x1803ffff,0x0c02ffff,0x0800ffff]:
     data=header+source.read(size)
     try: labels=names(data,kind)
     except (ValueError,struct.error): labels=[]
     rows.append({'offset':offset,'bytes':size+12,'kind':'dff' if kind==16 else 'txd','names':labels})
     end=(offset+12+size+2047)//2048*2048
     source.read(end-offset-size-12)
     offset=end
    else:
     source.read(min(2036,info.file_size-offset-12))
     offset+=2048;unknown+=1
 return {'entries':rows,'unknown_sectors':unknown,'original_filenames_available':False,'method':'bounded sector-aligned RenderWare root inspection; not a reconstructed archive directory'}

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--zip',type=Path,required=True)
 p.add_argument('--output',type=Path)
 p.add_argument('--query',default='')
 a=p.parse_args();report=scan(a.zip)
 if a.output:a.output.write_text(json.dumps(report,indent=2)+'\n')
 matches=[r for r in report['entries'] if a.query.lower() in ' '.join(r['names']).lower()]
 print(json.dumps({'recognized_roots':len(report['entries']),'unknown_sectors':report['unknown_sectors'],'matches':matches if a.query else matches[:10]},indent=2))
if __name__=='__main__':main()
