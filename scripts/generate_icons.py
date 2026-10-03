"""Generate a deterministic code-drawn app icon; no external assets."""
from pathlib import Path
import struct, zlib
def chunk(key, data):
    return struct.pack('>I',len(data))+key+data+struct.pack('>I',zlib.crc32(key+data))
def generate(n):
    rows=[]
    for y in range(n):
        row=bytearray([0])
        for x in range(n):
            u,v=x/n,y/n
            bracket=(.20<u<.25 and .22<v<.78) or (.20<u<.36 and (.22<v<.27 or .73<v<.78)) or (.75<u<.80 and .22<v<.78) or (.64<u<.80 and (.22<v<.27 or .73<v<.78))
            glyph=(.42<u<.48 and .36<v<.64) or (.42<u<.63 and .59<v<.65)
            row.extend((100,245,218) if bracket or glyph else (13,27+int(v*15),46+int(u*15)))
        rows.append(bytes(row))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',n,n,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
if __name__=='__main__':
    for folder in ['controller/Resources','testtarget/Resources']:
        for name,n in [('Icon.png',60),('Icon@2x.png',120),('Icon@3x.png',180)]: Path(folder,name).write_bytes(generate(n))
