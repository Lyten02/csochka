"""Validate committed GLBs against every default-body MDL mesh, not just conversion exit codes.
Run: python godot/tests/test_knife_converter.py
"""
import json
from pathlib import Path
import struct
import unittest

from pygltflib import GLTF2

ROOT = Path(__file__).resolve().parents[2]


class KnifeConverterTest(unittest.TestCase):
    def test_all_default_bodyparts_and_skin_materials(self):
        manifest = json.loads((ROOT / 'models_src/knives/manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(len(manifest), 20)
        for entry in manifest:
            with self.subTest(knife=entry['slug']):
                data = (ROOT / 'models_src/knives' / entry['slug'] / 'v_knife.mdl').read_bytes()
                parts, body_offset = struct.unpack_from('<ii', data, 204)
                refs, families, skin_offset = struct.unpack_from('<iii', data, 192)
                skin = struct.unpack_from(f'<{refs}H', data, skin_offset) if families else None
                expected = []
                for part in range(parts):
                    model = struct.unpack_from('<i', data, body_offset + part * 76 + 72)[0]
                    meshes, mesh_offset = struct.unpack_from('<ii', data, model + 72)
                    for mesh in range(meshes):
                        triangles, _, material = struct.unpack_from('<iii', data, mesh_offset + mesh * 20)
                        if triangles:
                            expected.append((triangles * 3, skin[material] if skin else material))
                gltf = GLTF2().load(str(ROOT / 'godot/models/knives' / (entry['slug'] + '.glb')))
                actual = [(gltf.accessors[p.indices].count, p.material) for p in gltf.meshes[0].primitives]
                self.assertEqual(actual, expected, 'Every bodypart mesh must survive conversion')
                texture_count, texture_offset = struct.unpack_from('<ii', data, 180)
                for texture in range(texture_count):
                    flags = struct.unpack_from('<i', data, texture_offset + texture * 80 + 64)[0]
                    additive = gltf.materials[texture].name.endswith('__goldsrc_additive')
                    self.assertEqual(additive, bool(flags & 32), 'Preserve additive overlays instead of opaque black')
                if entry['inspect']:
                    source = entry['inspect']
                    animation = next(a for a in gltf.animations if a.name == source['name'])
                    duration = max(gltf.accessors[s.input].max[0] for s in animation.samplers)
                    self.assertAlmostEqual(duration, (source['frames'] - 1) / source['fps'], places=5)
                print(f"[PASS] {entry['slug']}: {parts} bodyparts, {len(actual)} meshes, {sum(n for n, _ in actual)//3} triangles")


if __name__ == '__main__':
    unittest.main()
