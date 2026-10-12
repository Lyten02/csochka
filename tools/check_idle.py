import struct
import numpy as np

with open(r'C:\Users\zxcursed\Downloads\cstrike\models\v_knife.mdl', 'rb') as f:
    data = f.read()

numseq = struct.unpack_from('<i', data, 164)[0]
seqindex = struct.unpack_from('<i', data, 168)[0]
numbones = struct.unpack_from('<i', data, 140)[0]
boneindex = struct.unpack_from('<i', data, 144)[0]

bones = []
for i in range(numbones):
    off = boneindex + i * 112
    name = data[off:off+32].split(b'\x00')[0].decode('ascii', errors='ignore')
    parent = struct.unpack_from('<i', data, off + 32)[0]
    vals = struct.unpack_from('<6f', data, off + 64)
    scales = struct.unpack_from('<6f', data, off + 88)
    bones.append({'name': name, 'parent': parent, 'vals': vals, 'scales': scales})

def angle_matrix(angles):
    p, y, r = angles[0], angles[1], angles[2]
    sp, cp = np.sin(p), np.cos(p)
    sy, cy = np.sin(y), np.cos(y)
    sr, cr = np.sin(r), np.cos(r)
    m = np.identity(3, dtype=np.float32)
    m[0, 0] = cp * cy
    m[0, 1] = sr * sp * cy + cr * -sy
    m[0, 2] = cr * sp * cy + -sr * -sy
    m[1, 0] = cp * sy
    m[1, 1] = sr * sp * sy + cr * cy
    m[1, 2] = cr * sp * sy + -sr * cy
    m[2, 0] = -sp
    m[2, 1] = sr * cp
    m[2, 2] = cr * cp
    return m

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
        val = struct.unpack_from('<h', data, pos + 2 + k * 2)[0]
    else:
        val = struct.unpack_from('<h', data, pos + 2 + (valid - 1) * 2)[0]
    return bone_val + val * bone_scale

for s in range(numseq):
    off = seqindex + s * 176
    label = data[off:off+32].split(b'\x00')[0].decode('ascii', errors='ignore')
    if label == 'idle':
        fps = struct.unpack_from('<f', data, off + 32)[0]
        numframes = struct.unpack_from('<i', data, off + 56)[0]
        animindex = struct.unpack_from('<i', data, off + 124)[0]
        print(f'Sequence idle: {numframes} frames, {fps} fps')

        world_m = []
        for b in range(numbones):
            b_anim_ptr = animindex + b * 12
            offsets = struct.unpack_from('<6h', data, b_anim_ptr)
            channels = [extract_channel(b_anim_ptr, offsets[j], bones[b]['vals'][j], bones[b]['scales'][j], 0) for j in range(6)]
            pos = np.array(channels[:3], dtype=np.float32)
            rot = np.array(channels[3:], dtype=np.float32)
            R = angle_matrix(rot)
            M = np.identity(4, dtype=np.float32)
            M[:3, :3] = R
            M[:3, 3] = pos
            p = bones[b]['parent']
            if p == -1:
                W = M
            else:
                W = world_m[p] @ M
            world_m.append(W)
            bname = bones[b]['name']
            if 'hand' in bname.lower() or 'bone25' in bname.lower() or b == 0:
                print(f'{b:2d} ({bname:15s}): pos_gs={W[:3, 3]}')
