#!/usr/bin/env python3
"""Build a project ZIP with explicit parent directories for strict web importers."""
import argparse,hashlib,stat,zipfile
from pathlib import Path,PurePosixPath

def package(project, output, root_name='Harbor'):
    project=project.resolve();output=output.resolve()
    if PurePosixPath(root_name).name!=root_name or root_name in ('','.','..'):
        raise ValueError('root_name must be one simple folder name')
    files=sorted(p for p in project.rglob('*') if p.is_file() and p.resolve()!=output
                 and not any(part in ('.godot','.git','__pycache__') for part in p.relative_to(project).parts))
    directories={PurePosixPath(root_name)}
    for path in files:
        rel=PurePosixPath(root_name)/PurePosixPath(path.relative_to(project).as_posix())
        directories.update(parent for parent in rel.parents if str(parent)!='.')
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for directory in sorted(directories,key=lambda p:(len(p.parts),str(p))):
            info=zipfile.ZipInfo(str(directory)+'/')
            info.create_system=3
            info.external_attr=((stat.S_IFDIR|0o755)<<16)|0x10
            archive.writestr(info,b'')
        for path in files:
            archive.write(path,str(PurePosixPath(root_name)/path.relative_to(project).as_posix()))
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:raise ValueError('Archive CRC verification failed')
        for path in files:
            name=root_name+'/'+path.relative_to(project).as_posix()
            if hashlib.sha256(archive.read(name)).digest()!=hashlib.sha256(path.read_bytes()).digest():
                raise ValueError('Packaged bytes changed: '+name)
    return {'files':len(files),'explicit_directories':len(directories),'bytes':output.stat().st_size}

if __name__=='__main__':
    import json
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();print(json.dumps(package(args.project,args.output)))
