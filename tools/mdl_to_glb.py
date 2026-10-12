"""Convert GoldSrc .mdl models (MDL v10) to glTF/GLB with skeleton, materials, and animations."""
import io
import os
import struct
import sys
import numpy as np
from PIL import Image
from scipy.spatial.transform import Rotation
import pygltflib

UNIT = 0.0254

# Change of basis: GoldSrc (x forward, y left, z up) -> Godot/glTF (x right, y up, -z forward)
C = np.array([
    [ 0.0, -1.0,  0.0],
    [ 0.0,  0.0,  1.0],
    [-1.0,  0.0,  0.0]
], dtype=np.float32)
C_inv = C.T

def bone_rotation_matrix(angles):
    """Bone angles are (x, y, z) radians; HL SDK AngleQuaternion composes them as Rz(z) @ Ry(y) @ Rx(x)."""
    return Rotation.from_euler("xyz", angles).as_matrix().astype(np.float32)

def convert_mdl_to_glb(mdl_path: str, out_glb_path: str, skin_prefix: str | None = None):
    os.makedirs(os.path.dirname(out_glb_path), exist_ok=True)
    with open(mdl_path, "rb") as f:
        data = f.read()

    # 1. Textures & Materials
    numtextures = struct.unpack_from("<i", data, 180)[0]
    textureindex = struct.unpack_from("<i", data, 184)[0]
    textures = []
    tex_png_bytes = []
    for i in range(numtextures):
        off = textureindex + i * 80
        name = data[off:off+64].split(b"\x00")[0].decode("ascii", errors="ignore")
        flags, w, h, index = struct.unpack_from("<iiii", data, off + 64)
        pix = data[index : index + w * h]
        pal = data[index + w * h : index + w * h + 768]
        img = Image.new("P", (w, h))
        img.frombytes(pix)
        img.putpalette(list(pal))
        rgb = img.convert("RGBA")
        # Reskins share the MDL geometry/animations and only swap textures: <prefix><name>.png
        if skin_prefix:
            skin_path = skin_prefix + os.path.splitext(name)[0].lower() + ".png"
            skin = Image.open(skin_path).convert("RGBA")
            if skin.size != (w, h):
                raise ValueError(f"{skin_path} is {skin.size}, MDL texture {name} is {(w, h)}")
            rgb = skin
        bio = io.BytesIO()
        rgb.save(bio, format="PNG")
        tex_png_bytes.append(bio.getvalue())
        textures.append((name, w, h))

    # 2. Bones
    numbones = struct.unpack_from("<i", data, 140)[0]
    boneindex = struct.unpack_from("<i", data, 144)[0]
    bones = []
    for i in range(numbones):
        off = boneindex + i * 112
        name = data[off:off+32].split(b"\x00")[0].decode("ascii", errors="ignore")
        parent = struct.unpack_from("<i", data, off + 32)[0]
        vals = struct.unpack_from("<6f", data, off + 64)
        scales = struct.unpack_from("<6f", data, off + 88)
        pos_gs = np.array(vals[:3], dtype=np.float32)
        rot_gs = np.array(vals[3:], dtype=np.float32)
        R_gs = bone_rotation_matrix(rot_gs)

        R_gltf = C @ R_gs @ C_inv
        pos_gltf = (C @ pos_gs) * UNIT
        rot_quat = Rotation.from_matrix(R_gltf).as_quat()

        bones.append({
            "name": name,
            "parent": parent,
            "pos_gs": pos_gs,
            "rot_gs": rot_gs,
            "scales": scales,
            "vals": vals,
            "R_gs": R_gs,
            "pos_gltf": pos_gltf,
            "rot_gltf": rot_quat,
            "R_gltf": R_gltf
        })

    world_m4 = []
    for i in range(numbones):
        m4 = np.identity(4, dtype=np.float32)
        m4[:3, :3] = bones[i]["R_gltf"]
        m4[:3, 3] = bones[i]["pos_gltf"]
        p = bones[i]["parent"]
        if p == -1:
            world_m4.append(m4)
        else:
            world_m4.append(world_m4[p] @ m4)

    inv_bind_matrices = []
    for i in range(numbones):
        inv_m = np.linalg.inv(world_m4[i])
        inv_bind_matrices.append(inv_m.T) # column major
    inv_bind_array = np.array(inv_bind_matrices, dtype=np.float32)

    # 3. Meshes
    bodypartindex = struct.unpack_from("<i", data, 208)[0]
    modelindex = struct.unpack_from("<i", data, bodypartindex + 72)[0]
    mOff = modelindex
    nummesh = struct.unpack_from("<i", data, mOff + 72)[0]
    meshindex = struct.unpack_from("<i", data, mOff + 76)[0]
    numverts = struct.unpack_from("<i", data, mOff + 80)[0]
    vertinfoindex = struct.unpack_from("<i", data, mOff + 84)[0]
    vertindex = struct.unpack_from("<i", data, mOff + 88)[0]
    numnorms = struct.unpack_from("<i", data, mOff + 92)[0]
    norminfoindex = struct.unpack_from("<i", data, mOff + 96)[0]
    normindex = struct.unpack_from("<i", data, mOff + 100)[0]

    raw_verts = []
    for v in range(numverts):
        pos_gs = np.array(struct.unpack_from("<3f", data, vertindex + v * 12), dtype=np.float32)
        b = data[vertinfoindex + v]
        pos_gltf = (C @ pos_gs) * UNIT
        raw_verts.append((pos_gltf, b))

    raw_norms = []
    for n in range(numnorms):
        norm_gs = np.array(struct.unpack_from("<3f", data, normindex + n * 12), dtype=np.float32)
        norm_gltf = C @ norm_gs
        raw_norms.append(norm_gltf)

    primitives_data = []
    for m in range(nummesh):
        off = meshindex + m * 20
        triindex = struct.unpack_from("<i", data, off + 4)[0]
        skinref = struct.unpack_from("<i", data, off + 8)[0]
        tex_w, tex_h = textures[skinref][1], textures[skinref][2]

        pos = triindex
        vert_map = {}
        unique_verts = []
        indices = []

        while True:
            count = struct.unpack_from("<h", data, pos)[0]
            pos += 2
            if count == 0:
                break
            is_fan = count < 0
            vcount = abs(count)
            strip_pts = []
            for _ in range(vcount):
                vi, ni, s, t = struct.unpack_from("<hhhh", data, pos)
                pos += 8
                u = s / tex_w
                v = t / tex_h
                strip_pts.append((vi, ni, u, v))

            tris = []
            if is_fan:
                for j in range(1, vcount - 1):
                    tris.append((strip_pts[0], strip_pts[j], strip_pts[j + 1]))
            else:
                for j in range(vcount - 2):
                    if j % 2 == 0:
                        tris.append((strip_pts[j], strip_pts[j + 1], strip_pts[j + 2]))
                    else:
                        tris.append((strip_pts[j + 1], strip_pts[j], strip_pts[j + 2]))

            # GoldSrc strips/fans are clockwise-front (Quake GL_FRONT culling); glTF front faces are CCW.
            for tri in tris:
                for p in (tri[0], tri[2], tri[1]):
                    key = (p[0], p[1], round(p[2], 5), round(p[3], 5))
                    if key not in vert_map:
                        vert_map[key] = len(unique_verts)
                        pos_loc, b = raw_verts[p[0]]
                        norm_loc = raw_norms[p[1]]
                        p4 = np.array([pos_loc[0], pos_loc[1], pos_loc[2], 1.0], dtype=np.float32)
                        bind_pos = (world_m4[b] @ p4)[:3]
                        bind_norm = (world_m4[b][:3, :3] @ norm_loc)
                        bind_norm = bind_norm / (np.linalg.norm(bind_norm) + 1e-8)
                        unique_verts.append((bind_pos, bind_norm, (p[2], p[3]), b))
                    indices.append(vert_map[key])

        primitives_data.append({
            "skinref": skinref,
            "verts": unique_verts,
            "indices": indices
        })

    # 4. Animations
    numseq = struct.unpack_from("<i", data, 164)[0]
    seqindex = struct.unpack_from("<i", data, 168)[0]

    def extract_channel(anim_ptr, offset, bone_val, bone_scale, frame):
        if offset == 0:
            return bone_val
        pos = anim_ptr + offset
        k = frame
        while True:
            total = data[pos + 1]
            valid = data[pos]
            if total == 0:
                return bone_val
            if total <= k:
                k -= total
                pos += 2 + valid * 2
            else:
                break
        if valid > k:
            val = struct.unpack_from("<h", data, pos + 2 + k * 2)[0]
        else:
            val = struct.unpack_from("<h", data, pos + 2 + (valid - 1) * 2)[0]
        return bone_val + val * bone_scale

    animations_data = []
    for s in range(numseq):
        off = seqindex + s * 176
        label = data[off:off+32].split(b"\x00")[0].decode("ascii", errors="ignore")
        fps = struct.unpack_from("<f", data, off + 32)[0]
        numframes = struct.unpack_from("<i", data, off + 56)[0]
        animindex = struct.unpack_from("<i", data, off + 124)[0]

        times = np.array([f / fps for f in range(numframes)], dtype=np.float32)
        bone_tracks = []

        for b in range(numbones):
            b_anim_ptr = animindex + b * 12
            offsets = struct.unpack_from("<6H", data, b_anim_ptr)  # mstudioanim_t offsets are unsigned
            pos_keys = []
            rot_keys = []

            for f in range(numframes):
                channels = [extract_channel(b_anim_ptr, offsets[j], bones[b]["vals"][j], bones[b]["scales"][j], f) for j in range(6)]
                pos_gs = np.array(channels[:3], dtype=np.float32)
                rot_gs = np.array(channels[3:], dtype=np.float32)
                R_gs = bone_rotation_matrix(rot_gs)

                R_gltf = C @ R_gs @ C_inv
                pos_gltf = (C @ pos_gs) * UNIT
                rot_quat = Rotation.from_matrix(R_gltf).as_quat()

                pos_keys.append(pos_gltf)
                rot_keys.append(rot_quat)

            bone_tracks.append({
                "bone": b,
                "positions": np.array(pos_keys, dtype=np.float32),
                "rotations": np.array(rot_keys, dtype=np.float32)
            })

        animations_data.append({
            "name": label,
            "fps": fps,
            "numframes": numframes,
            "times": times,
            "tracks": bone_tracks
        })

    # 5. Build glTF
    bin_data = bytearray()
    def add_buffer_data(raw_bytes, align=4):
        nonlocal bin_data
        pad = (align - (len(bin_data) % align)) % align
        if pad > 0:
            bin_data.extend(b"\x00" * pad)
        offset = len(bin_data)
        bin_data.extend(raw_bytes)
        return offset, len(raw_bytes)

    gltf = pygltflib.GLTF2()
    gltf.asset = pygltflib.Asset(generator="GoldSrc MDL to glTF Converter", version="2.0")

    gltf.samplers.append(pygltflib.Sampler(magFilter=pygltflib.LINEAR, minFilter=pygltflib.LINEAR_MIPMAP_LINEAR))
    for i, png in enumerate(tex_png_bytes):
        off, length = add_buffer_data(png)
        bv_idx = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off, byteLength=length))
        img_idx = len(gltf.images)
        gltf.images.append(pygltflib.Image(bufferView=bv_idx, mimeType="image/png", name=textures[i][0]))
        tex_idx = len(gltf.textures)
        gltf.textures.append(pygltflib.Texture(sampler=0, source=img_idx))
        gltf.materials.append(pygltflib.Material(
            name=textures[i][0],
            pbrMetallicRoughness=pygltflib.PbrMetallicRoughness(
                baseColorTexture=pygltflib.TextureInfo(index=tex_idx),
                metallicFactor=0.0,
                roughnessFactor=0.8
            ),
            extensions={"KHR_materials_unlit": {}},
            doubleSided=False  # GoldSrc culls studio model back faces; winding is converted to CCW above
        ))
    gltf.extensionsUsed.append("KHR_materials_unlit")

    off, length = add_buffer_data(inv_bind_array.tobytes())
    bv_inv_bind = len(gltf.bufferViews)
    gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off, byteLength=length))
    acc_inv_bind = len(gltf.accessors)
    gltf.accessors.append(pygltflib.Accessor(
        bufferView=bv_inv_bind,
        componentType=pygltflib.FLOAT,
        count=numbones,
        type=pygltflib.MAT4
    ))

    gltf_primitives = []
    for p_idx, prim in enumerate(primitives_data):
        v_arr = prim["verts"]
        i_arr = np.array(prim["indices"], dtype=np.uint16)

        positions = np.array([v[0] for v in v_arr], dtype=np.float32)
        normals = np.array([v[1] for v in v_arr], dtype=np.float32)
        uvs = np.array([[v[2][0], v[2][1]] for v in v_arr], dtype=np.float32)
        joints = np.array([[v[3], 0, 0, 0] for v in v_arr], dtype=np.uint16)
        weights = np.array([[1.0, 0.0, 0.0, 0.0] for v in v_arr], dtype=np.float32)

        off_i, len_i = add_buffer_data(i_arr.tobytes())
        bv_i = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_i, byteLength=len_i, target=pygltflib.ELEMENT_ARRAY_BUFFER))
        acc_i = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(bufferView=bv_i, componentType=pygltflib.UNSIGNED_SHORT, count=len(i_arr), type=pygltflib.SCALAR, max=[int(i_arr.max())], min=[int(i_arr.min())]))

        off_p, len_p = add_buffer_data(positions.tobytes())
        bv_p = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_p, byteLength=len_p, target=pygltflib.ARRAY_BUFFER))
        acc_p = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(bufferView=bv_p, componentType=pygltflib.FLOAT, count=len(positions), type=pygltflib.VEC3, max=positions.max(axis=0).tolist(), min=positions.min(axis=0).tolist()))

        off_n, len_n = add_buffer_data(normals.tobytes())
        bv_n = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_n, byteLength=len_n, target=pygltflib.ARRAY_BUFFER))
        acc_n = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(bufferView=bv_n, componentType=pygltflib.FLOAT, count=len(normals), type=pygltflib.VEC3))

        off_u, len_u = add_buffer_data(uvs.tobytes())
        bv_u = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_u, byteLength=len_u, target=pygltflib.ARRAY_BUFFER))
        acc_u = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(bufferView=bv_u, componentType=pygltflib.FLOAT, count=len(uvs), type=pygltflib.VEC2))

        off_j, len_j = add_buffer_data(joints.tobytes())
        bv_j = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_j, byteLength=len_j, target=pygltflib.ARRAY_BUFFER))
        acc_j = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(bufferView=bv_j, componentType=pygltflib.UNSIGNED_SHORT, count=len(joints), type=pygltflib.VEC4))

        off_w, len_w = add_buffer_data(weights.tobytes())
        bv_w = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_w, byteLength=len_w, target=pygltflib.ARRAY_BUFFER))
        acc_w = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(bufferView=bv_w, componentType=pygltflib.FLOAT, count=len(weights), type=pygltflib.VEC4))

        gltf_primitives.append(pygltflib.Primitive(
            attributes=pygltflib.Attributes(POSITION=acc_p, NORMAL=acc_n, TEXCOORD_0=acc_u, JOINTS_0=acc_j, WEIGHTS_0=acc_w),
            indices=acc_i,
            material=prim["skinref"]
        ))

    gltf.meshes.append(pygltflib.Mesh(name="v_knife", primitives=gltf_primitives))

    root_bone_indices = []
    for b in range(numbones):
        node_idx = 1 + b
        p = bones[b]["parent"]
        if p == -1:
            root_bone_indices.append(node_idx)

    mesh_node = pygltflib.Node(name="v_knife_mesh", mesh=0, skin=0)
    gltf.nodes.append(mesh_node)

    for b in range(numbones):
        children = [1 + c for c in range(numbones) if bones[c]["parent"] == b]
        b_node = pygltflib.Node(
            name=bones[b]["name"],
            translation=bones[b]["pos_gltf"].tolist(),
            rotation=bones[b]["rot_gltf"].tolist(),
            children=children if children else None
        )
        gltf.nodes.append(b_node)

    joint_node_indices = list(range(1, 1 + numbones))
    gltf.skins.append(pygltflib.Skin(
        inverseBindMatrices=acc_inv_bind,
        joints=joint_node_indices,
        name="Armature"
    ))

    scene_root_children = [0] + root_bone_indices
    scene_root_node = pygltflib.Node(name="RootNode", children=scene_root_children)
    root_node_idx = len(gltf.nodes)
    gltf.nodes.append(scene_root_node)
    gltf.scenes.append(pygltflib.Scene(nodes=[root_node_idx]))
    gltf.scene = 0

    for anim in animations_data:
        samplers = []
        channels = []

        off_t, len_t = add_buffer_data(anim["times"].tobytes())
        bv_t = len(gltf.bufferViews)
        gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_t, byteLength=len_t))
        acc_t = len(gltf.accessors)
        gltf.accessors.append(pygltflib.Accessor(
            bufferView=bv_t,
            componentType=pygltflib.FLOAT,
            count=len(anim["times"]),
            type=pygltflib.SCALAR,
            max=[float(anim["times"].max())],
            min=[float(anim["times"].min())]
        ))

        for tr in anim["tracks"]:
            b = tr["bone"]
            target_node = 1 + b

            off_pos, len_pos = add_buffer_data(tr["positions"].tobytes())
            bv_pos = len(gltf.bufferViews)
            gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_pos, byteLength=len_pos))
            acc_pos = len(gltf.accessors)
            gltf.accessors.append(pygltflib.Accessor(
                bufferView=bv_pos,
                componentType=pygltflib.FLOAT,
                count=len(tr["positions"]),
                type=pygltflib.VEC3
            ))
            s_pos_idx = len(samplers)
            samplers.append(pygltflib.AnimationSampler(input=acc_t, output=acc_pos, interpolation=pygltflib.LINEAR))
            channels.append(pygltflib.AnimationChannel(
                sampler=s_pos_idx,
                target=pygltflib.AnimationChannelTarget(node=target_node, path="translation")
            ))

            off_rot, len_rot = add_buffer_data(tr["rotations"].tobytes())
            bv_rot = len(gltf.bufferViews)
            gltf.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=off_rot, byteLength=len_rot))
            acc_rot = len(gltf.accessors)
            gltf.accessors.append(pygltflib.Accessor(
                bufferView=bv_rot,
                componentType=pygltflib.FLOAT,
                count=len(tr["rotations"]),
                type=pygltflib.VEC4
            ))
            s_rot_idx = len(samplers)
            samplers.append(pygltflib.AnimationSampler(input=acc_t, output=acc_rot, interpolation=pygltflib.LINEAR))
            channels.append(pygltflib.AnimationChannel(
                sampler=s_rot_idx,
                target=pygltflib.AnimationChannelTarget(node=target_node, path="rotation")
            ))

        gltf.animations.append(pygltflib.Animation(
            name=anim["name"],
            channels=channels,
            samplers=samplers
        ))

    gltf.buffers.append(pygltflib.Buffer(byteLength=len(bin_data)))
    gltf.set_binary_blob(bytes(bin_data))
    gltf.save(out_glb_path)
    print(f"Generated {out_glb_path} ({os.path.getsize(out_glb_path)} bytes)")

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("mdl", help="source GoldSrc .mdl")
    ap.add_argument("glb", help="output .glb")
    ap.add_argument("--skin", metavar="PREFIX", help="replace MDL textures with PNGs named <PREFIX><texture>.png")
    a = ap.parse_args()
    convert_mdl_to_glb(a.mdl, a.glb, a.skin)
