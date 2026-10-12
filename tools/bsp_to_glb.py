"""Convert a GoldSrc BSP (CS 1.6 / Half-Life) directly to an optimized GLB file.

Pure Python using numpy, Pillow, and pygltflib (no Blender dependency).
Produces a GLB with materials, UV0 (texture) and UV1 (lightmap atlas),
compatible with Godot 4 and map_post_import.gd.

Features:
- Robust ear-clipping & Delaunay quad triangulation (no gaps, folded or missing faces)
- Newell normal verification for CCW winding in glTF coordinate system
- Double-sided material flags + cull_disabled compatibility
- Dedicated samplers (Clamp-to-edge for lightmaps, repeat for textures)
- Elimination of invisible logic brushes (e.g. healingdoor)
"""
from __future__ import annotations

import io
import json
import math
import os
import sys
import numpy as np
from PIL import Image
import pygltflib
from pygltflib import (
    GLTF2, Scene, Node, Mesh, Primitive, Attributes, Accessor, BufferView, Buffer,
    Material, PbrMetallicRoughness, TextureInfo, OcclusionTextureInfo, Texture,
    Image as GLTFImage, Sampler
)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import goldsrc_bsp as gb

UNIT = 0.0254  # 1 GoldSrc unit = 1 inch = 0.0254 m
LIGHT_GAMMA = 2.5
TEXTURE_GAMMA = 2.0 / 2.5
SKY_TEXTURE = "sky"

RENDERED_CLASSES = {
    "worldspawn", "func_wall", "func_breakable", "func_illusionary", "func_door",
    "func_door_rotating", "func_button", "func_rotating", "func_pushable", "func_wall_toggle",
    "func_train", "func_tracktrain", "func_plat", "func_water", "func_conveyor"
}
TRANSLUCENT_MODES = {1, 2, 5}


def _unlit(face: gb.Face) -> gb.Face:
    return gb.Face(face.model, face.texture, face.positions, face.tex_uv, face.light_st, (0, 0), None, face.normal)


def triangulate_polygon_3d(pos: np.ndarray, normal: np.ndarray) -> list[tuple[int, int, int]]:
    """Triangulate a 3D planar polygon into counter-clockwise triangles relative to normal."""
    n = len(pos)
    if n < 3:
        return []
    if n == 3:
        return [(0, 1, 2)]

    if n == 4:
        # Quad (0, 1, 2, 3): test which diagonal (0-2 or 1-3) produces valid CCW triangles
        n0 = np.cross(pos[1] - pos[0], pos[2] - pos[0])
        n1 = np.cross(pos[2] - pos[0], pos[3] - pos[0])
        dot0 = np.dot(n0, normal)
        dot1 = np.dot(n1, normal)

        n2 = np.cross(pos[2] - pos[1], pos[3] - pos[1])
        n3 = np.cross(pos[3] - pos[1], pos[0] - pos[1])
        dot2 = np.dot(n2, normal)
        dot3 = np.dot(n3, normal)

        split0_ok = (dot0 > 1e-4) and (dot1 > 1e-4)
        split1_ok = (dot2 > 1e-4) and (dot3 > 1e-4)

        if split0_ok and not split1_ok:
            return [(0, 1, 2), (0, 2, 3)]
        elif split1_ok and not split0_ok:
            return [(1, 2, 3), (1, 3, 0)]
        else:
            d02 = np.linalg.norm(pos[2] - pos[0])
            d13 = np.linalg.norm(pos[3] - pos[1])
            if d02 <= d13:
                return [(0, 1, 2), (0, 2, 3)]
            else:
                return [(1, 2, 3), (1, 3, 0)]

    # N-gon (n > 4): project to 2D along dominant normal axis and perform ear clipping
    an = np.abs(normal)
    axis = int(np.argmax(an))
    if axis == 0:
        p2d = pos[:, [1, 2]]
    elif axis == 1:
        p2d = pos[:, [0, 2]]
    else:
        p2d = pos[:, [0, 1]]

    # Determine 2D orientation
    area = 0.0
    for i in range(n):
        j = (i + 1) % n
        area += p2d[i][0] * p2d[j][1] - p2d[j][0] * p2d[i][1]

    def is_convex_2d(p_prev, p_curr, p_next):
        v1 = p_curr - p_prev
        v2 = p_next - p_curr
        cross = v1[0] * v2[1] - v1[1] * v2[0]
        return (cross > 1e-6) if area >= 0 else (cross < -1e-6)

    def point_in_tri_2d(pt, a, b, c):
        def sign(p1, p2, p3):
            return (p1[0] - p3[0]) * (p2[1] - p3[1]) - (p2[0] - p3[0]) * (p1[1] - p3[1])
        d1 = sign(pt, a, b)
        d2 = sign(pt, b, c)
        d3 = sign(pt, c, a)
        has_neg = (d1 < -1e-6) or (d2 < -1e-6) or (d3 < -1e-6)
        has_pos = (d1 > 1e-6) or (d2 > 1e-6) or (d3 > 1e-6)
        return not (has_neg and has_pos)

    tris = []
    rem = list(range(n))
    limit = 2 * n * n
    step = 0
    while len(rem) > 3 and step < limit:
        step += 1
        m = len(rem)
        clipped = False
        for i in range(m):
            prev_idx = rem[(i - 1 + m) % m]
            curr_idx = rem[i]
            next_idx = rem[(i + 1) % m]

            p_prev = p2d[prev_idx]
            p_curr = p2d[curr_idx]
            p_next = p2d[next_idx]

            if not is_convex_2d(p_prev, p_curr, p_next):
                continue

            inside = False
            for j in range(m):
                test_idx = rem[j]
                if test_idx in (prev_idx, curr_idx, next_idx):
                    continue
                if point_in_tri_2d(p2d[test_idx], p_prev, p_curr, p_next):
                    inside = True
                    break
            if not inside:
                tris.append((prev_idx, curr_idx, next_idx))
                rem.pop(i)
                clipped = True
                break
        if not clipped:
            tris.append((rem[0], rem[1], rem[2]))
            rem.pop(1)

    if len(rem) == 3:
        tris.append((rem[0], rem[1], rem[2]))
    return tris


def convert_bsp_to_glb(bsp_path: str, out_glb_path: str) -> dict:
    bsp = gb.load(bsp_path)
    map_name = os.path.splitext(os.path.basename(bsp_path))[0]

    model_ents = bsp.entity_models()
    render_models, translucent_models = {}, {}
    for idx, ent in model_ents.items():
        cls = ent.get("classname", "")
        if cls not in RENDERED_CLASSES:
            continue

        # Filter out invisible healing logic entities (healingdoor)
        targetname = ent.get("targetname", "").lower()
        if "healing" in targetname:
            continue

        mode = int(ent.get("rendermode", "0") or 0)
        amt_str = ent.get("renderamt")
        amt = float(amt_str) if amt_str is not None else (0.0 if mode in TRANSLUCENT_MODES else 255.0)

        # Translucent entity with 0 renderamt is invisible in GoldSrc
        if mode in TRANSLUCENT_MODES and amt <= 0.0:
            continue

        render_models[idx] = ent
        if mode in TRANSLUCENT_MODES and amt < 255.0:
            translucent_models[idx] = max(amt, 1.0) / 255.0

    rendered = [i for i, f in enumerate(bsp.faces) if f.model in render_models]
    keep = [i for i in rendered if bsp.textures[bsp.faces[i].texture].name.lower() not in gb.NON_RENDER_TEXTURES]
    sky_ids = [i for i in rendered if bsp.textures[bsp.faces[i].texture].name.lower() == SKY_TEXTURE]

    # Lightmaps atlas
    atlas, placements = gb.pack_lightmaps([bsp.faces[i] if i in keep else _unlit(bsp.faces[i]) for i in range(len(bsp.faces))])
    # Ensure (0, 0) is pure white so unlit faces receive 100% albedo brightness
    atlas[0, 0] = (255, 255, 255)
    atlas_gamma = (np.power(atlas.astype(np.float32) / 255.0, 1.0 / LIGHT_GAMMA) * 255.0 + 0.5).astype(np.uint8)
    atlas_gamma[0, 0] = (255, 255, 255)

    # Encode lightmap atlas to PNG bytes
    lm_pil = Image.fromarray(atlas_gamma, mode="RGB")
    lm_buf = io.BytesIO()
    lm_pil.save(lm_buf, format="PNG", compress_level=6)
    lm_bytes = lm_buf.getvalue()

    # Encode texture images to PNG bytes
    tex_bytes_map = {}
    for ti in sorted({bsp.faces[i].texture for i in keep}):
        tex = bsp.textures[ti]
        rgba = tex.rgba if tex.rgba is not None else np.full((tex.height, tex.width, 4), (255, 0, 255, 255), np.uint8)
        rgba = rgba.copy()
        rgba[..., :3] = (np.power(rgba[..., :3].astype(np.float32) / 255.0, TEXTURE_GAMMA) * 255.0 + 0.5).astype(np.uint8)
        t_pil = Image.fromarray(rgba, mode="RGBA")
        t_buf = io.BytesIO()
        t_pil.save(t_buf, format="PNG", compress_level=6)
        tex_bytes_map[ti] = t_buf.getvalue()

    # GLB Assembly
    buffer_data = bytearray()
    buffer_views: list[BufferView] = []
    accessors: list[Accessor] = []
    images: list[GLTFImage] = []
    textures: list[Texture] = []
    materials: list[Material] = []

    def add_buffer_view(data_bytes: bytes, target: int | None = None) -> int:
        pad = (4 - (len(buffer_data) % 4)) % 4
        if pad:
            buffer_data.extend(b"\x00" * pad)
        offset = len(buffer_data)
        buffer_data.extend(data_bytes)
        bv = BufferView(buffer=0, byteOffset=offset, byteLength=len(data_bytes), target=target)
        buffer_views.append(bv)
        return len(buffer_views) - 1

    def add_accessor(bv_idx: int, count: int, comp_type: int, type_str: str, min_v=None, max_v=None) -> int:
        acc = Accessor(
            bufferView=bv_idx,
            byteOffset=0,
            componentType=comp_type,
            count=count,
            type=type_str,
            min=min_v,
            max=max_v
        )
        accessors.append(acc)
        return len(accessors) - 1

    # Samplers:
    # 0: Lightmap clamp to edge (mag linear, min linear)
    sampler_lm = Sampler(magFilter=9729, minFilter=9729, wrapS=33071, wrapT=33071)
    # 1: Texture repeat (mag linear, min linear mipmap linear)
    sampler_tex = Sampler(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)
    samplers = [sampler_lm, sampler_tex]

    # Image & Texture 0: Lightmap
    lm_img_bv = add_buffer_view(lm_bytes)
    images.append(GLTFImage(bufferView=lm_img_bv, mimeType="image/png", name=f"{map_name}_lightmap"))
    textures.append(Texture(source=0, sampler=0, name=f"{map_name}_lightmap"))
    lightmap_tex_idx = 0

    # Images & Textures for map textures
    tex_gltf_idx: dict[int, int] = {}
    for ti, tb in tex_bytes_map.items():
        tex = bsp.textures[ti]
        img_bv = add_buffer_view(tb)
        img_idx = len(images)
        images.append(GLTFImage(bufferView=img_bv, mimeType="image/png", name=tex.name))
        t_idx = len(textures)
        textures.append(Texture(source=img_idx, sampler=1, name=tex.name))
        tex_gltf_idx[ti] = t_idx

    # Materials
    mat_key_to_idx: dict[str, int] = {}

    def get_or_create_material(key: str, ti: int | None, variant: str, alpha: float) -> int:
        if key in mat_key_to_idx:
            return mat_key_to_idx[key]
        idx = len(materials)
        mat_key_to_idx[key] = idx

        if key == SKY_TEXTURE:
            mat = Material(
                name=SKY_TEXTURE,
                pbrMetallicRoughness=PbrMetallicRoughness(
                    baseColorFactor=[0.55, 0.62, 0.72, 1.0],
                    metallicFactor=0.0,
                    roughnessFactor=1.0
                ),
                doubleSided=True
            )
        else:
            t_idx = tex_gltf_idx[ti]
            pbr = PbrMetallicRoughness(
                baseColorTexture=TextureInfo(index=t_idx, texCoord=0),
                baseColorFactor=[1.0, 1.0, 1.0, alpha],
                metallicFactor=0.0,
                roughnessFactor=1.0
            )
            occlusion = OcclusionTextureInfo(index=lightmap_tex_idx, texCoord=1, strength=1.0)
            alpha_mode = "OPAQUE"
            alpha_cutoff = None
            if variant == "cutout":
                alpha_mode = "MASK"
                alpha_cutoff = 0.5
            elif variant == "translucent":
                alpha_mode = "BLEND"

            mat = Material(
                name=key,
                pbrMetallicRoughness=pbr,
                occlusionTexture=occlusion,
                alphaMode=alpha_mode,
                alphaCutoff=alpha_cutoff,
                doubleSided=True
            )
        materials.append(mat)
        return idx

    # Categorize faces
    opaque_fids = []
    trans_fids = []
    for fid in keep:
        f = bsp.faces[fid]
        if f.model in translucent_models:
            trans_fids.append(fid)
        else:
            opaque_fids.append(fid)

    aw, ah = atlas.shape[1], atlas.shape[0]

    def build_mesh(fids: list[int], mesh_name: str) -> Mesh | None:
        if not fids:
            return None
        # Group by material
        mat_faces: dict[int, list[int]] = {}
        for fid in fids:
            f = bsp.faces[fid]
            tex = bsp.textures[f.texture]
            if f.model in translucent_models:
                alpha = translucent_models[f.model]
                key = f"{tex.name}__a{int(round(alpha * 255))}"
                mid = get_or_create_material(key, f.texture, "translucent", alpha)
            elif tex.name.lower() == SKY_TEXTURE:
                mid = get_or_create_material(SKY_TEXTURE, None, "sky", 1.0)
            else:
                key = tex.name
                variant = "cutout" if tex.alpha_tested else "opaque"
                mid = get_or_create_material(key, f.texture, variant, 1.0)
            mat_faces.setdefault(mid, []).append(fid)

        primitives: list[Primitive] = []
        for mid, group_fids in mat_faces.items():
            pos_list = []
            uv0_list = []
            uv1_list = []
            ind_list = []

            for fid in group_fids:
                f = bsp.faces[fid]
                pos = f.positions
                order = list(range(len(pos)))

                # Check polygon winding via Newell normal in GoldSrc coords
                newell = np.sum(np.cross(pos, np.roll(pos, -1, axis=0)), axis=0)
                if np.dot(newell, f.normal) < 0:
                    order.reverse()

                px, py = placements.get(fid, (0, 0))
                base_idx = len(pos_list)

                # Collect vertices for this face in glTF coordinates
                face_gltf_pos = []
                for k in order:
                    p = pos[k]
                    # GoldSrc (x, y, z) -> glTF / Godot Y-up (x * UNIT, z * UNIT, -y * UNIT)
                    gp = [float(p[0] * UNIT), float(p[2] * UNIT), float(-p[1] * UNIT)]
                    face_gltf_pos.append(gp)
                    pos_list.append(gp)
                    u, v = f.tex_uv[k]
                    uv0_list.append([float(u), float(v)])
                    if f.light_rgb is not None:
                        lx, ly = f.light_st[k]
                        uv1_list.append([float((px + lx) / aw), float((py + ly) / ah)])
                    else:
                        uv1_list.append([float(0.5 / aw), float(0.5 / ah)])

                # Face normal in glTF coordinates
                fn_gltf = np.array([f.normal[0], f.normal[2], -f.normal[1]], dtype=np.float64)
                face_pos_arr = np.array(face_gltf_pos, dtype=np.float64)

                # Triangulate polygon cleanly with ear-clipping & optimal quad diagonals
                tris = triangulate_polygon_3d(face_pos_arr, fn_gltf)
                for t in tris:
                    ind_list.extend([base_idx + t[0], base_idx + t[1], base_idx + t[2]])

            if not ind_list:
                continue

            pos_arr = np.array(pos_list, dtype=np.float32)
            uv0_arr = np.array(uv0_list, dtype=np.float32)
            uv1_arr = np.array(uv1_list, dtype=np.float32)
            ind_arr = np.array(ind_list, dtype=np.uint32)

            pos_bv = add_buffer_view(pos_arr.tobytes(), target=34962)  # ARRAY_BUFFER
            uv0_bv = add_buffer_view(uv0_arr.tobytes(), target=34962)
            uv1_bv = add_buffer_view(uv1_arr.tobytes(), target=34962)
            ind_bv = add_buffer_view(ind_arr.tobytes(), target=34963)  # ELEMENT_ARRAY_BUFFER

            pos_min = pos_arr.min(axis=0).tolist()
            pos_max = pos_arr.max(axis=0).tolist()

            pos_acc = add_accessor(pos_bv, len(pos_arr), 5126, "VEC3", min_v=pos_min, max_v=pos_max)
            uv0_acc = add_accessor(uv0_bv, len(uv0_arr), 5126, "VEC2")
            uv1_acc = add_accessor(uv1_bv, len(uv1_arr), 5126, "VEC2")
            ind_acc = add_accessor(ind_bv, len(ind_arr), 5125, "SCALAR", min_v=[int(ind_arr.min())], max_v=[int(ind_arr.max())])

            primitives.append(Primitive(
                attributes=Attributes(POSITION=pos_acc, TEXCOORD_0=uv0_acc, TEXCOORD_1=uv1_acc),
                indices=ind_acc,
                material=mid
            ))

        return Mesh(name=mesh_name, primitives=primitives)

    meshes: list[Mesh] = []
    nodes: list[Node] = []
    scene_nodes: list[int] = []

    static_mesh = build_mesh(opaque_fids, f"{map_name}_static")
    if static_mesh and static_mesh.primitives:
        m_idx = len(meshes)
        meshes.append(static_mesh)
        n_idx = len(nodes)
        nodes.append(Node(name=f"{map_name}_static", mesh=m_idx))
        scene_nodes.append(n_idx)

    trans_mesh = build_mesh(trans_fids, f"{map_name}_translucent")
    if trans_mesh and trans_mesh.primitives:
        m_idx = len(meshes)
        meshes.append(trans_mesh)
        n_idx = len(nodes)
        nodes.append(Node(name=f"{map_name}_translucent", mesh=m_idx))
        scene_nodes.append(n_idx)

    sky_mesh = build_mesh(sky_ids, f"{map_name}_sky")
    if sky_mesh and sky_mesh.primitives:
        m_idx = len(meshes)
        meshes.append(sky_mesh)
        n_idx = len(nodes)
        nodes.append(Node(name=f"{map_name}_sky", mesh=m_idx))
        scene_nodes.append(n_idx)

    # Spawn nodes
    for i, ent in enumerate(e for e in bsp.entities if e.get("classname") in ("info_player_start", "info_player_deathmatch")):
        x, y, z = (float(c) for c in ent["origin"].split())
        n_idx = len(nodes)
        nodes.append(Node(
            name=f"spawn_{ent['classname']}_{i:02d}",
            translation=[float(x * UNIT), float(z * UNIT), float(-y * UNIT)]
        ))
        scene_nodes.append(n_idx)

    gltf = GLTF2(
        scene=0,
        scenes=[Scene(nodes=scene_nodes)],
        nodes=nodes,
        meshes=meshes,
        materials=materials,
        textures=textures,
        images=images,
        samplers=samplers,
        accessors=accessors,
        bufferViews=buffer_views,
        buffers=[Buffer(byteLength=len(buffer_data))]
    )
    gltf.set_binary_blob(bytes(buffer_data))
    gltf.save_binary(out_glb_path)

    stats = {
        "map": map_name,
        "source_faces": len(bsp.faces),
        "rendered_faces": len(keep),
        "sky_faces": len(sky_ids),
        "materials": len(materials),
        "meshes": len(meshes),
        "glb_size_bytes": os.path.getsize(out_glb_path),
    }
    return stats


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python bsp_to_glb.py <input.bsp> [output.glb]")
        sys.exit(1)
    in_bsp = sys.argv[1]
    out_glb = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(in_bsp)[0] + ".glb"
    res = convert_bsp_to_glb(in_bsp, out_glb)
    print("Successfully converted:", json.dumps(res, indent=2))
