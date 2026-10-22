#!/usr/bin/env python3
"""Repair an existing build ZIP; optionally overlay revised project source.

No asset conversion or IMG extraction occurs. Unknown files and converted assets
are retained byte for byte. Every directory is written before its descendants.
"""
import argparse,hashlib,json,tempfile,zipfile
from pathlib import Path,PurePosixPath
from package_project import package

def rebuild(source,output,project=None):
    source=Path(source).resolve();output=Path(output).resolve()
    if source==output:raise ValueError('Use a different output path to preserve the input ZIP')
    with tempfile.TemporaryDirectory() as temp:
        base=Path(temp)
        with zipfile.ZipFile(source) as old:
            entries=[i for i in old.infolist() if not i.is_dir()]
            roots=[PurePosixPath(i.filename).parent for i in entries if PurePosixPath(i.filename).name=='project.godot']
            if len(roots)!=1:raise ValueError('Expected exactly one project.godot')
            prefix=roots[0]
            original={}
            for info in entries:
                name=PurePosixPath(info.filename)
                if name.is_absolute() or '..' in name.parts or '\\' in info.filename:raise ValueError('Unsafe ZIP path')
                try:relative=name.relative_to(prefix)
                except ValueError:raise ValueError('File outside project root')
                if any(part in ('.godot','.git','__pycache__') for part in relative.parts):continue
                target=base/relative
                if target.exists():raise ValueError('Duplicate ZIP member: '+str(relative))
                target.parent.mkdir(parents=True,exist_ok=True)
                data=old.read(info);target.write_bytes(data)
                original[str(relative)]=hashlib.sha256(data).hexdigest()
        overwritten=set()
        if project is not None:
            project=Path(project).resolve()
            if not (project/'project.godot').is_file():raise ValueError('Overlay must be a Godot project')
            for path in sorted(project.rglob('*')):
                rel=path.relative_to(project)
                if not path.is_file() or any(p in ('.godot','.git','__pycache__') for p in rel.parts):continue
                target=base/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(path.read_bytes())
                overwritten.add(rel.as_posix())
            manifest=base/'FILES.sha256'
            files=sorted(p for p in base.rglob('*') if p.is_file() and p!=manifest)
            manifest.write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(base).as_posix()+'\n' for p in files))
            overwritten.add('FILES.sha256')
        report=package(base,output)
        preserved=0
        with zipfile.ZipFile(output) as result:
            for relative,digest in original.items():
                if relative in overwritten:continue
                if hashlib.sha256(result.read('Harbor/'+relative)).hexdigest()!=digest:raise ValueError('Changed preserved file: '+relative)
                preserved+=1
        report.update(preserved_files=preserved,overlaid_files=len(overwritten),asset_conversion_performed=False)
        return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--project',type=Path,help='Optional source overlay; omit to change ZIP layout only')
    args=parser.parse_args()
    print(json.dumps(rebuild(args.input,args.output,args.project),indent=2))
