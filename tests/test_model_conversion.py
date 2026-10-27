import hashlib,importlib.util,json,struct,tempfile,unittest,zipfile
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
def module(name):
 spec=importlib.util.spec_from_file_location(name,ROOT/'tools'/(name+'.py'))
 value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
converter=module('convert_model_placeholders')
inspector=module('inspect_rw_archive')
def chunk(kind,payload):return struct.pack('<III',kind,len(payload),0x1003ffff)+payload
def texture_inputs_available():
 folder=ROOT/'assets/converted/models'
 report=folder/'model_conversion_report.json'
 return not (folder/'textures/.apk_recovered').exists() and report.is_file() and all((folder/entry['path']).is_file()
                                 for entry in json.loads(report.read_text())['texture_exports'])
def original_models_available():
 selection=json.loads((ROOT/'assets/model_selection.json').read_text())
 return all((ROOT/'assets/local_models'/(entry['role']+'.dff')).is_file()
            for entry in selection['models'])

class ModelConversionTests(unittest.TestCase):
 def test_matrix_basis_conjugation(self):
  result=converter.matrix([[1,0,0],[0,1,0],[0,0,1]],[1,2,3])
  self.assertEqual(result,[[1,0,0],[0,1,0],[0,0,1],[1,3,-2]])
  self.assertEqual(converter.skin_matrix([[1,0,0,0],[0,1,0,0],[0,0,1,0],[1,2,3,1]]),result)
 def test_inspection_skips_unrecognized_sectors_without_export(self):
  native=chunk(1,struct.pack('<II',8,0)+b'example\0'.ljust(32,b'\0'))
  dictionary=chunk(22,chunk(21,native))
  data=b'?'*2048+dictionary
  with tempfile.TemporaryDirectory() as temp:
   path=Path(temp)/'models.zip'
   with zipfile.ZipFile(path,'w') as z:z.writestr('gta3.img',data)
   result=inspector.scan(path)
   self.assertEqual(len(result['entries']),1)
   self.assertEqual(result['entries'][0]['offset'],2048)
   self.assertEqual(result['entries'][0]['names'],['example'])
   self.assertFalse(result['original_filenames_available'])
   self.assertEqual(len(list(Path(temp).iterdir())),1)
 @unittest.skipUnless(texture_inputs_available(),'Supply original PNGs; APK texture imports are insufficient for byte provenance')
 def test_every_png_preserves_decoded_rgba(self):
  folder=ROOT/'assets/converted/models'
  report=json.loads((folder/'model_conversion_report.json').read_text())
  self.assertEqual(len(report['original_models']),4)
  self.assertEqual(len(report['texture_exports']),25)
  self.assertEqual(report['selected_img_payload_bytes'],369300)
  self.assertFalse(report['unpacked_entire_archive'])
  for texture in report['texture_exports']:
   path=folder/texture['path']
   image=Image.open(path).convert('RGBA')
   self.assertEqual(image.size,(texture['width'],texture['height']))
   self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(),texture['rgba_sha256'])
   self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),texture['png_sha256'])
 @unittest.skipUnless(original_models_available(),'Supply original DFF inputs; converted model metadata alone is insufficient')
 def test_selected_original_model_hashes(self):
  selection=json.loads((ROOT/'assets/model_selection.json').read_text())
  for model in selection['models']:
   data=(ROOT/'assets/local_models'/(model['role']+'.dff')).read_bytes()
   self.assertEqual(len(data),model['bytes'])
   self.assertEqual(hashlib.sha256(data).hexdigest(),model['sha256'])

if __name__=='__main__':unittest.main()
