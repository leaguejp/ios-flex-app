"""Standalone source + actual deb inspection; Python standard library only."""
import argparse
import gzip
import io
import json
from pathlib import Path
import plistlib
import re
import struct
import tarfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def source_manifest(root):
    def plist(name):
        return plistlib.loads((root / name).read_bytes())
    info = dict(line.split(": ", 1) for line in (root / "control").read_text().splitlines() if ": " in line)
    config = dict(re.findall(r'(ET\w+) = @"([^"]+)"', (root / "shared/TemplateConfig.h").read_text()))
    entry = plist("layout/Library/PreferenceLoader/Preferences/ExamplePrefs.plist")["entry"]
    bundle = plist("prefs/Resources/Info.plist")
    switch = plist("prefs/Resources/Root.plist")["items"][1]
    require(info["Architecture"] == "iphoneos-arm64", "wrong rootless Debian architecture")
    require(plist("ExampleTweak.plist") == {"Filter": {"Bundles": [config["ETTargetBundle"]]}}, "filter and runtime target differ")
    require(switch["defaults"] == config["ETPreferencesDomain"], "preference domain mismatch")
    require(switch["key"] == config["ETEnabledKey"] and switch["default"] is False, "switch/default mismatch")
    require(switch["PostNotification"] == config["ETPreferencesDomain"] + "/ReloadPrefs", "notification mismatch")
    require(entry["bundle"] == bundle["CFBundleExecutable"] == "ExamplePrefs", "preference bundle name mismatch")
    require(entry["detail"] == bundle["NSPrincipalClass"] == "ETRootListController", "controller name mismatch")
    require(entry["isController"] is True and entry["cell"] == "PSLinkCell", "invalid loader entry")
    require(all(x in info["Depends"] for x in ["ellekit", "preferenceloader", "ws.hbang.common"]), "missing runtime dependency")
    for file in root.rglob("*"):
        if file.suffix in [".x", ".m", ".h"]:
            text = file.read_text(encoding="utf-8")
            require("/var/jb" not in text, "hard-coded jailbreak prefix in source")
    return info


def ar_members(data):
    require(data.startswith(b"!<arch>\n"), "invalid ar magic")
    result, pos = {}, 8
    while pos < len(data):
        header = data[pos:pos+60]
        require(len(header) == 60 and header[58:] == b"`\n", "truncated ar header")
        name, length = header[:16].decode().strip().rstrip("/"), int(header[48:58])
        pos += 60
        require(name not in result and 0 <= length <= len(data)-pos, "invalid ar member")
        result[name] = data[pos:pos+length]
        pos += length + length % 2
    require(pos == len(data), "invalid ar alignment")
    return result


def archive(blob):
    raw = gzip.decompress(blob)
    pos = 0
    while pos+512 <= len(raw) and any(raw[pos:pos+512]):
        header = raw[pos:pos+512]
        require(header[257:263] == b"ustar\0" and header[156:157] not in [b"x", b"g", b"L", b"K"], "non-ustar archive header")
        size = int(header[124:136].rstrip(b"\0 ") or b"0", 8)
        pos += 512 + (size+511)//512*512
    require(pos <= len(raw), "truncated tar")
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as tar:
        files = {}
        for item in tar.getmembers():
            name = item.name.removeprefix("./")
            require(not name.startswith("/") and ".." not in name.split("/"), "unsafe tar path")
            if item.isfile():
                require(name not in files, "duplicate file")
                files[name] = tar.extractfile(item).read()
    return files


def macho_slices(data):
    if data[:4] == b"\xca\xfe\xba\xbe":
        require(len(data) >= 8, "short fat header")
        count = struct.unpack_from(">I", data, 4)[0]
        require(1 <= count <= 8 and 8+20*count <= len(data), "invalid fat count")
        results, ranges = [], []
        for i in range(count):
            cpu, subtype, off, size, alignment = struct.unpack_from(">IIIII", data, 8+i*20)
            require(8+20*count <= off and size <= len(data)-off, "invalid fat slice")
            require(not any(off < end and start < off+size for start, end in ranges), "overlapping slices")
            ranges.append((off, off+size))
            entries = macho_slices(data[off:off+size])
            require(len(entries) == 1 and entries[0]["subtype"] == (subtype & 0xffffff) and cpu == 0x100000c, "fat/thin CPU mismatch")
            results.extend(entries)
        require(len({x["architecture"] for x in results}) == len(results), "duplicate CPU slice")
        return results
    require(data[:4] == b"\xcf\xfa\xed\xfe" and len(data) >= 32, "unsupported Mach-O header")
    cpu, subtype, filetype, commands, command_bytes = struct.unpack_from("<IIIII", data, 4)
    require(cpu == 0x100000c and (subtype & 0xffffff) in [0, 2], "unexpected CPU")
    require(filetype in [6, 8], "expected dylib or bundle")
    end, pos = 32+command_bytes, 32
    require(end <= len(data), "truncated commands")
    links, signed, minimum = [], False, None
    for _ in range(commands):
        require(pos+8 <= end, "truncated command header")
        cmd, size = struct.unpack_from("<II", data, pos)
        require(size >= 8 and size % 8 == 0 and pos+size <= end, "invalid load command")
        if cmd in [0xc, 0x80000018, 0x8000001f, 0x80000023]:
            off = struct.unpack_from("<I", data, pos+8)[0]
            require(24 <= off < size, "invalid dependency string")
            links.append(data[pos+off:pos+size].split(b"\0")[0].decode())
        if cmd == 0x32:
            require(size >= 24, "short build version")
            platform, minimum, sdk = struct.unpack_from("<III", data, pos+8)
            require(platform == 2, "not an iOS device binary")
        if cmd == 0x1d:
            require(size >= 16, "short signature command")
            offset, length = struct.unpack_from("<II", data, pos+8)
            require(length > 0 and offset+length <= len(data), "signature outside binary")
            signed = True
        pos += size
    require(pos == end and signed and minimum == 0x000f0500, "signature or iOS 15.5 deployment missing")
    return [{"architecture": "arm64e" if subtype & 0xffffff == 2 else "arm64", "subtype": subtype & 0xffffff,
             "minimum_ios": "15.5", "dependencies": links, "code_signature_command": signed}]


def inspect_deb(file, root):
    expected = source_manifest(root)
    members = ar_members(file.read_bytes())
    require(list(members) == ["debian-binary", "control.tar.gz", "data.tar.gz"] and members["debian-binary"] == b"2.0\n", "unexpected deb members/compression")
    control, data = archive(members["control.tar.gz"]), archive(members["data.tar.gz"])
    info = dict(line.split(": ", 1) for line in control["control"].decode().splitlines() if ": " in line)
    require(all(info[k] == expected[k] for k in ["Package", "Architecture", "Version"]), "package identity mismatch")
    require(all(name.startswith("var/jb/") for name in data), "payload outside rootless prefix")
    names = {"tweak": "var/jb/Library/MobileSubstrate/DynamicLibraries/ExampleTweak.dylib",
             "preferences": "var/jb/Library/PreferenceBundles/ExamplePrefs.bundle/ExamplePrefs"}
    binaries = {}
    for role, name in names.items():
        require(name in data, "missing " + role)
        slices = macho_slices(data[name])
        require({x["architecture"] for x in slices} == {"arm64", "arm64e"}, "missing CPU slice in " + role)
        for entry in slices:
            require(any("Cephei.framework/" in x for x in entry["dependencies"]), "missing Cephei link")
            require(all(x.startswith(("/System/Library/", "/usr/lib/", "@rpath/")) for x in entry["dependencies"]), "unexpected dependency path")
        binaries[role] = slices
    for relative in ["Library/MobileSubstrate/DynamicLibraries/ExampleTweak.plist", "Library/PreferenceLoader/Preferences/ExamplePrefs.plist"]:
        require(plistlib.loads(data["var/jb/"+relative]) == plistlib.loads((root/("ExampleTweak.plist" if relative.endswith("ExampleTweak.plist") else "layout/"+relative)).read_bytes()), "installed filter/entry differs")
    for resource in ["Root.plist", "Info.plist"]:
        installed = plistlib.loads(data["var/jb/Library/PreferenceBundles/ExamplePrefs.bundle/"+resource])
        wanted = plistlib.loads((root/"prefs/Resources"/resource).read_bytes())
        require(all(installed.get(k) == v for k, v in wanted.items()), "bundle resource mismatch")
    return {"package": info, "members": list(members), "compression": "gzip", "tar": "ustar", "binaries": binaries,
            "physical_settings_and_injection_tested": False}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--deb", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    result = inspect_deb(args.deb, root) if args.deb else {"source": source_manifest(root), "status": "PASS"}
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
