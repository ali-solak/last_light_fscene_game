"""Embeds a palette PNG into a .glb whose "palette" material lost its
texture on export:
  python tool/models/glb_add_palette.py in.glb palette.png out.glb"""
import json, struct, sys
src, png_path, out = sys.argv[1:4]
b = open(src, 'rb').read()
clen = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + clen])
bin_start = 20 + clen + 8
blen = struct.unpack('<I', b[20 + clen:24 + clen])[0]
binary = bytearray(b[bin_start:bin_start + blen])
png = open(png_path, 'rb').read()
while len(binary) % 4: binary.append(0)
off = len(binary)
binary += png
while len(binary) % 4: binary.append(0)
j['buffers'][0]['byteLength'] = len(binary)
j.setdefault('bufferViews', []).append({'buffer': 0, 'byteOffset': off, 'byteLength': len(png)})
j.setdefault('images', []).append({'name': 'palette', 'mimeType': 'image/png', 'bufferView': len(j['bufferViews']) - 1})
j.setdefault('samplers', []).append({'magFilter': 9728, 'minFilter': 9728})
j.setdefault('textures', []).append({'sampler': len(j['samplers']) - 1, 'source': len(j['images']) - 1})
for m in j['materials']:
    if m.get('name') == 'palette':
        m.setdefault('pbrMetallicRoughness', {})['baseColorTexture'] = {'index': len(j['textures']) - 1}
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
total = 12 + 8 + len(js) + 8 + len(binary)
o = struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(binary), 0x004E4942) + bytes(binary)
open(out, 'wb').write(o)
print('wrote', out, total)
