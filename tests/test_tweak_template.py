import importlib.util
from pathlib import Path
import plistlib
import shutil
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1] / "templates/dopamine-ios15-rootless"
spec = importlib.util.spec_from_file_location("template_validator", ROOT / "tools/validate.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


def device_slice(subtype=0, minimum=0xf0500):
    commands = struct.pack("<IIIIII", 0x32, 24, 2, minimum, 0x120000, 0)
    commands += struct.pack("<IIII", 0x1d, 16, 72, 4)
    return struct.pack("<IIIIIIII", 0xfeedfacf, 0x100000c, subtype, 6, 2, len(commands), 0, 0) + commands + b"test"


class TemplateTests(unittest.TestCase):
    def test_source_contract(self):
        self.assertEqual(validator.source_manifest(ROOT)["Architecture"], "iphoneos-arm64")

    def test_mismatched_filter_and_notification_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / "template"
            shutil.copytree(ROOT, root, ignore=shutil.ignore_patterns(".theos", ".tools", "packages", "artifacts", "__pycache__"))
            file = root / "ExampleTweak.plist"
            original = file.read_bytes()
            file.write_bytes(plistlib.dumps({"Filter": {"Bundles": ["wrong.bundle"]}}))
            with self.assertRaisesRegex(ValueError, "filter"):
                validator.source_manifest(root)
            file.write_bytes(original)
            file = root / "prefs/Resources/Root.plist"
            values = plistlib.loads(file.read_bytes())
            values["items"][1]["PostNotification"] = "wrong/ReloadPrefs"
            file.write_bytes(plistlib.dumps(values))
            with self.assertRaisesRegex(ValueError, "notification"):
                validator.source_manifest(root)

    def test_device_abi_and_deployment(self):
        self.assertEqual(validator.macho_slices(device_slice())[0]["architecture"], "arm64")
        self.assertEqual(validator.macho_slices(device_slice(0x80000002))[0]["architecture"], "arm64e")
        with self.assertRaisesRegex(ValueError, "deployment"):
            validator.macho_slices(device_slice(minimum=0xe0000))
        with self.assertRaises(ValueError):
            validator.macho_slices(device_slice()[:-1])

    def test_fat_header_cpu_and_overlap_rejected(self):
        a, b = device_slice(), device_slice(0x80000002)
        header = struct.pack(">II", 0xcafebabe, 2)
        header += struct.pack(">IIIII", 0x100000c, 0, 48, len(a), 0)
        header += struct.pack(">IIIII", 0x100000c, 0x80000002, 48+len(a), len(b), 0)
        blob = header+a+b
        self.assertEqual(len(validator.macho_slices(blob)), 2)
        corrupt = bytearray(blob)
        struct.pack_into(">I", corrupt, 8+20+8, 48)
        with self.assertRaisesRegex(ValueError, "overlapping"):
            validator.macho_slices(corrupt)


if __name__ == "__main__":
    unittest.main()
