"""Inspect actual ar/deb, compression, every tar header, metadata, Mach-O and links."""
import argparse, gzip, io, json, struct, tarfile, plistlib
from pathlib import Path

def ar_members(data):
    if not data.startswith(b'!<arch>\n'):
        raise ValueError('invalid ar magic')
    p, result = 8, {}
    while p < len(data):
        header = data[p:p+60]
        if len(header) != 60 or header[58:] != b'`\n':
            raise ValueError('invalid ar header')
        name = header[:16].decode().strip().rstrip('/')
        size = int(header[48:58]); p += 60
        if name in result or size < 0 or size > len(data)-p:
            raise ValueError('duplicate/truncated ar member')
        result[name] = data[p:p+size]; p += size + size % 2
    if p != len(data):
        raise ValueError('ar alignment')
    return result

def archive(blob):
    raw = gzip.decompress(blob)
    headers, p = [], 0
    while p+512 <= len(raw) and raw[p:p+512] != bytes(512):
        h = raw[p:p+512]
        if h[257:263] != b'ustar\0' or h[263:265] != b'00':
            raise ValueError('tar header is not POSIX ustar')
        size = int(h[124:136].rstrip(b'\0 ').lstrip(b' ') or b'0', 8)
        if h[156:157] in (b'x', b'g', b'L', b'K'):
            raise ValueError('extended tar headers unsupported by policy')
        headers.append(h[:100].split(b'\0')[0].decode())
        p += 512 + ((size+511)//512)*512
    if len(raw)-p < 1024 or any(raw[p:]):
        raise ValueError('missing tar end blocks')
    return tarfile.open(fileobj=io.BytesIO(raw), mode='r:'), headers

def macho(data):
    if len(data) < 32 or struct.unpack_from('<I',data)[0] != 0xfeedfacf:
        raise ValueError('expected thin arm64 Mach-O')
    cpu, subtype = struct.unpack_from('<II',data,4)
    if cpu != 0x100000c or subtype & 0xffffff != 0:
        raise ValueError('expected arm64 (not arm64e) code')
    n, count = struct.unpack_from('<II',data,16)
    p, links, rpaths, signed, entitlements = 32, [], [], False, {}
    end = p+count
    if end > len(data): raise ValueError('truncated Mach-O commands')
    for _ in range(n):
        cmd,size = struct.unpack_from('<II',data,p)
        if size < 8 or size % 8 or p+size > end: raise ValueError('invalid Mach-O command')
        if cmd in (0xc,0x80000018,0x8000001f,0x80000023,0x8000001c):
            off=struct.unpack_from('<I',data,p+8)[0]
            if off>=size: raise ValueError('invalid load string')
            value=data[p+off:p+size].split(b'\0')[0].decode()
            (rpaths if cmd==0x8000001c else links).append(value)
        if cmd == 0x1d:
            signed = True
            if size < 16: raise ValueError('invalid signature command')
            off,length=struct.unpack_from('<II',data,p+8)
            if length < 12 or off+length>len(data): raise ValueError('signature outside binary')
            blob=data[off:off+length];magic,total,items=struct.unpack_from('>III',blob)
            if magic != 0xfade0cc0 or total>length or 12+items*8>total: raise ValueError('invalid signature superblob')
            for j in range(items):
                kind,index=struct.unpack_from('>II',blob,12+j*8)
                if index+8>total: raise ValueError('invalid signature slot')
                slotmagic,slotlen=struct.unpack_from('>II',blob,index)
                if slotlen<8 or index+slotlen>total: raise ValueError('invalid signature blob bounds')
                if slotmagic==0xfade7171:
                    if entitlements: raise ValueError('duplicate entitlements')
                    entitlements=plistlib.loads(blob[index+8:index+slotlen])
                    if not isinstance(entitlements,dict): raise ValueError('invalid entitlements dictionary')
        p += size
    if p != end or not signed: raise ValueError('unsigned or malformed Mach-O')
    for link in links:
        if 'flex' in link.lower(): raise ValueError('unexpected FLEX dependency')
        if not link.startswith(('/System/Library/', '/usr/lib/', '@rpath/')):
            raise ValueError('unexpected library path: '+link)
    return dict(cpu='arm64',dependencies=links,rpaths=rpaths,code_signature=True,entitlements=entitlements)

def inspect(path, architecture, scheme):
    members=ar_members(Path(path).read_bytes())
    if list(members) != ['debian-binary','control.tar.gz','data.tar.gz'] or members['debian-binary'] != b'2.0\n':
        raise ValueError('unexpected deb members/version/compression')
    control,ch=archive(members['control.tar.gz']); data,dh=archive(members['data.tar.gz'])
    info={}; controls=[m for m in control.getmembers() if m.name.lstrip('./')=='control']
    if len(controls)!=1: raise ValueError('control missing')
    for script in ('postinst','postrm'):
        entries=[m for m in control.getmembers() if m.name.lstrip('./')==script]
        if len(entries)!=1 or not entries[0].mode & 0o111: raise ValueError('missing/nonexecutable maintainer script: '+script)
        text=control.extractfile(entries[0]).read()
        if not text.startswith(b'#!/bin/sh\n') or b'\r' in text: raise ValueError('invalid shell script format')
    for line in control.extractfile(controls[0]).read().decode().splitlines():
        if ': ' in line:
            key,value=line.split(': ',1);info[key]=value
    if info.get('Architecture')!=architecture or info.get('Package')!='jp.league.runtimeatlas':
        raise ValueError('wrong package identity/architecture')
    binaries={}
    for entry in data.getmembers():
        name=entry.name.removeprefix('./')
        if name.startswith('/') or '..' in name.split('/'): raise ValueError('unsafe package path')
        if name in ('','.'):
            if not entry.isdir(): raise ValueError('tar root must be a directory')
            continue
        if scheme=='rootless' and name and name not in ('var','var/jb') and not name.startswith('var/jb/'):
            raise ValueError('rootless file outside install prefix: '+name)
        if scheme=='roothide' and name.split('/')[0] not in ('Applications','Library'):
            raise ValueError('unexpected RootHide install layout: '+name)
        if entry.isfile():
            blob=data.extractfile(entry).read()
            if blob[:4]==b'\xcf\xfa\xed\xfe': binaries[name]=macho(blob)
    expected={'RuntimeAtlas','AtlasTestTarget','RuntimeAtlasAgent.dylib'}
    if {Path(n).name for n in binaries} != expected: raise ValueError('missing/unexpected binaries')
    controller=next(v for n,v in binaries.items() if Path(n).name=='RuntimeAtlas')
    expected_entitlements={'com.apple.private.security.no-container':True,'com.apple.private.security.no-sandbox':True,'com.apple.private.security.container-required':False}
    if controller['entitlements']!=expected_entitlements: raise ValueError('Controller deployment entitlements missing/unexpected')
    for name,entry in binaries.items():
        if Path(name).name!='RuntimeAtlas' and entry['entitlements']: raise ValueError('unexpected privileges in Agent/TestTarget')
    return dict(package=info,scheme=scheme,members=list(members),compression='gzip',tar='ustar (every header checked)',control_headers=ch,data_headers=dh,binaries=binaries)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('deb');parser.add_argument('--architecture',required=True);parser.add_argument('--scheme',choices=['rootless','roothide'],required=True);parser.add_argument('--output',required=True)
    args=parser.parse_args();report=inspect(args.deb,args.architecture,args.scheme)
    Path(args.output).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report['package'],indent=2))
