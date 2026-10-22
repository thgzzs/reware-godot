import importlib.util,tempfile,unittest,zipfile
from pathlib import Path

spec=importlib.util.spec_from_file_location('package',Path(__file__).resolve().parents[1]/'tools/package_project.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class ProjectPackageTests(unittest.TestCase):
 def test_strict_extractor_can_write_every_nested_file(self):
  with tempfile.TemporaryDirectory() as temp:
   base=Path(temp);project=base/'project';project.mkdir()
   expected={}
   for i in range(217):
    name=('root%d.txt'%i) if i<6 else ('scenes/actors/group%d/file%d.gd'%(i%8,i))
    expected['Harbor/'+name]=('original bytes %d'%i).encode()
    target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(expected['Harbor/'+name])
   output=base/'test.zip';report=module.package(project,output)
   self.assertEqual(report['files'],217)
   extracted=base/'strict';extracted.mkdir()
   with zipfile.ZipFile(output) as archive:
    for info in archive.infolist():
     target=extracted/info.filename
     if info.is_dir():target.mkdir()  # Intentionally does not create parents.
     else:
      with target.open('xb') as destination:destination.write(archive.read(info))
    self.assertGreater(sum(x.is_dir() for x in archive.infolist()),0)
   for name,data in expected.items():self.assertEqual((extracted/name).read_bytes(),data)
 def test_engine_caches_and_output_archive_are_excluded(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);(root/'.godot').mkdir();(root/'.godot/cache').write_text('cache');(root/'project.godot').write_text('project')
   output=root/'build.zip'
   module.package(root,output);module.package(root,output)
   with zipfile.ZipFile(output) as archive:self.assertEqual(archive.namelist(),['Harbor/','Harbor/project.godot'])

if __name__=='__main__':unittest.main()
