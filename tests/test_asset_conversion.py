import importlib.util
from pathlib import Path
import struct
import unittest
import tempfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('converter',ROOT/'tools/convert_reference_assets.py')
converter=importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)
SOURCE=ROOT/'assets/local_source'

@unittest.skipUnless((SOURCE/'ped.ifp').exists(),'Supply the private source files to run asset parser tests')
class SuppliedAssetTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.data=(SOURCE/'ped.ifp').read_bytes()
 def test_package_counts(self):
  a=converter.parse_ifp(self.data)
  self.assertEqual(a['package'],'ped')
  self.assertEqual(len(a['clips']),234)
  self.assertEqual(sum(len(t['keys']) for c in a['clips'] for t in c['tracks']),87546)
 def test_truncation_rejected(self):
  with self.assertRaises(converter.FormatError):converter.parse_ifp(self.data[:-1])
 def test_unknown_key_encoding_rejected(self):
  altered=self.data.replace(b'KR00',b'KX00',1)
  with self.assertRaises(converter.FormatError):converter.parse_ifp(altered)
 def test_oversized_chunk_rejected(self):
  altered=bytearray(self.data)
  struct.pack_into('<I',altered,4,len(altered)+1000)
  with self.assertRaises(converter.FormatError):converter.parse_ifp(bytes(altered))
 def test_declared_animation_count_enforced(self):
  altered=bytearray(self.data)
  struct.pack_into('<I',altered,16,235)
  with self.assertRaises(converter.FormatError):converter.parse_ifp(bytes(altered))
 def test_all_data_tables(self):
  d=converter.parse_data(SOURCE)
  self.assertEqual({k:len(d[k]) for k in ['ped_stats','weapons','ped_groups','ped_types','handling','special_handling']},{'ped_stats':40,'weapons':37,'ped_groups':67,'ped_types':20,'handling':106,'special_handling':26})
 def test_units_and_relationships_preserved(self):
  d=converter.parse_data(SOURCE)
  player=next(r for r in d['ped_stats'] if r['name']=='STAT_PLAYER')
  self.assertEqual(player['heading_rate_per_normalized_tick'],15)
  self.assertEqual(player['defense_multiplier'],0.4)
  civilian=next(r for r in d['ped_types'] if r['name']=='CIVMALE')
  self.assertIn('GUN',civilian['threat'])
  self.assertIn('PLAYER1',civilian['avoid'])
class FightDataTests(unittest.TestCase):
 def test_frame_units_sentinels_and_inactive_reactions(self):
  with tempfile.TemporaryDirectory() as temp:
   path=Path(temp)/'fistfite.dat'
   path.write_text('Jab 6 10 0 .32 1.2 H FIGHTjab 2 1\nHit 4 0 0 0 1 N HIT_front 0 0\nAttack 0 0 0 0 .8 H default 0 0\nENDWEAPONDATA\n')
   rows=converter.parse_fight_moves(path)
   self.assertEqual(rows[0]['start_seconds'],.2)
   self.assertEqual(rows[0]['damage_source'],2)
   self.assertTrue(rows[0]['has_strike_window'])
   self.assertFalse(rows[1]['has_strike_window'])
   self.assertFalse(rows[2]['has_strike_window'])
   self.assertEqual(rows[2]['animation_source'],'default')
 def test_bad_data_is_rejected(self):
  for text in ['Jab 6 10\nENDWEAPONDATA','Jab nan 10 0 .32 1.2 H FIGHTjab 2 1\nENDWEAPONDATA','Jab 6 10 0 .32 1.2 X FIGHTjab 2 1\nENDWEAPONDATA','Jab 6 10 0 .32 1.2 H FIGHTjab 2 1']:
   with tempfile.TemporaryDirectory() as temp:
    path=Path(temp)/'fistfite.dat';path.write_text(text)
    with self.assertRaises(converter.FormatError):converter.parse_fight_moves(path)

if __name__=='__main__':unittest.main()
