import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('img', Path(__file__).resolve().parents[1]/'tools/extract_selected_img.py')
img = importlib.util.module_from_spec(spec)
spec.loader.exec_module(img)


def record(offset, size, name):
    return struct.pack('<II24s', offset, size, name.encode('ascii'))


class SelectedImgTests(unittest.TestCase):
    def test_only_requested_payloads_and_padding(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            image = root/'gta3.img'
            directory = root/'gta3.dir'
            image.write_bytes(b'A'*2048+b'B'*2048+b'C'*2048)
            directory.write_bytes(record(0,1,'one.dff')+record(1,1,'unused.dff')+record(2,1,'one.txd'))
            report = img.extract(image, directory, root/'selected', ['ONE.DFF','one.txd','one.dff'])
            self.assertEqual(report['selected_bytes'], 4096)
            self.assertEqual((root/'selected/one.dff').read_bytes(), b'A'*2048)
            self.assertEqual((root/'selected/one.txd').read_bytes(), b'C'*2048)
            self.assertFalse((root/'selected/unused.dff').exists())
            self.assertEqual(len(list((root/'selected').iterdir())), 3)

    def test_invalid_selection_rejected_before_output(self):
        for names in [[], ['../one.dff'], ['*.dff'], ['file.exe']]:
            with self.assertRaises(img.ArchiveError):
                img.select_entries(record(0,1,'one.dff'),2048,names)

    def test_missing_duplicate_truncated_bounds_and_overlap(self):
        cases = [(record(0,1,'other.dff'),2048,['one.dff']),
                 (record(0,1,'one.dff')*2,2048,['one.dff']),
                 (b'bad',2048,['one.dff']),
                 (record(1,1,'one.dff'),2048,['one.dff']),
                 (record(0,0,'one.dff'),2048,['one.dff']),
                 (record(0,2,'one.dff')+record(1,1,'one.txd'),4096,['one.dff','one.txd'])]
        for directory, size, names in cases:
            with self.subTest(directory=directory), self.assertRaises(img.ArchiveError):
                img.select_entries(directory,size,names)

    def test_dry_run_does_not_read_payload_or_create_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            image=root/'gta3.img'; image.write_bytes(b'A'*2048)
            directory=root/'gta3.dir'; directory.write_bytes(record(0,1,'one.dff'))
            report=img.extract(image,directory,root/'out',['one.dff'],True)
            self.assertTrue(report['dry_run'])
            self.assertFalse((root/'out').exists())

    def test_existing_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); output=root/'out'; output.mkdir()
            sentinel=output/'keep'; sentinel.write_text('existing')
            image=root/'gta3.img'; image.write_bytes(b'A'*2048)
            directory=root/'gta3.dir'; directory.write_bytes(record(0,1,'one.dff'))
            with self.assertRaises(FileExistsError):img.extract(image,directory,output,['one.dff'])
            self.assertEqual(sentinel.read_text(),'existing')


if __name__=='__main__':unittest.main()
