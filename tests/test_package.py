import gzip, io, struct, tarfile, unittest
from scripts.inspect_deb import ar_members, archive, macho
class PackageTests(unittest.TestCase):
    def test_reject_truncated_ar(self):
        for blob in [b'',b'!<arch>\nfoo',b'!<arch>\n'+b' '*60]:
            with self.assertRaises(ValueError): ar_members(blob)
    def test_actual_tar_format(self):
        out=io.BytesIO()
        with tarfile.open(fileobj=out,mode='w',format=tarfile.USTAR_FORMAT) as t:
            entry=tarfile.TarInfo('control');entry.size=3;t.addfile(entry,io.BytesIO(b'abc'))
        t,names=archive(gzip.compress(out.getvalue()));self.assertEqual(names,['control']);self.assertEqual(t.extractfile('control').read(),b'abc')
    def test_reject_gnu(self):
        out=io.BytesIO()
        with tarfile.open(fileobj=out,mode='w',format=tarfile.GNU_FORMAT) as t: t.addfile(tarfile.TarInfo('x'))
        with self.assertRaises(ValueError): archive(gzip.compress(out.getvalue()))
    def test_reject_wrong_cpu_or_unsigned(self):
        data=struct.pack('<IIIIIIII',0xfeedfacf,0x100000c,0,2,0,0,0,0)
        with self.assertRaises(ValueError): macho(data)
if __name__=='__main__': unittest.main()
