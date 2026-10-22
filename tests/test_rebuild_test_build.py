import importlib.util,sys,tempfile,unittest,zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from rebuild_test_build import rebuild
class RebuildTests(unittest.TestCase):
 def test_repairs_original_217_file_zip_without_changing_asset_bytes(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);source=root/'original.zip';output=root/'fixed.zip'
   with zipfile.ZipFile(source,'w') as z:
    z.writestr('Original/project.godot',b'project')
    for i in range(216):z.writestr('Original/assets/converted/group%d/asset%d.res'%(i%5,i),bytes([i%256])*37)
   result=rebuild(source,output)
   self.assertEqual(result['preserved_files'],217)
   self.assertEqual(result['files'],217)
   with zipfile.ZipFile(output) as z:
    dirs=set()
    for entry in z.infolist():
     path=Path(entry.filename)
     if entry.is_dir():dirs.add(path.as_posix())
     else:self.assertIn(path.parent.as_posix(),dirs)
 def test_overlay_keeps_private_assets(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);project=root/'project';project.mkdir();(project/'project.godot').write_bytes(b'new')
   source=root/'old.zip'
   with zipfile.ZipFile(source,'w') as z:
    z.writestr('Old/project.godot',b'old');z.writestr('Old/assets/converted/ped_library.res',b'private animation bytes')
   result=rebuild(source,root/'new.zip',project)
   self.assertEqual(result['preserved_files'],1)
   with zipfile.ZipFile(root/'new.zip') as z:self.assertEqual(z.read('Harbor/project.godot'),b'new')
 def test_rejects_traversal(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);source=root/'bad.zip'
   with zipfile.ZipFile(source,'w') as z:z.writestr('project.godot','project');z.writestr('../escape','bad')
   with self.assertRaises(ValueError):rebuild(source,root/'out.zip')
