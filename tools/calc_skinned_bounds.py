import pygltflib
import numpy as np

glb = pygltflib.GLTF2().load('godot/models/knife.glb')
data = glb.binary_blob()

# Read inverse bind matrices
ibm_acc = glb.accessors[glb.skins[0].inverseBindMatrices]
ibm_bv = glb.bufferViews[ibm_acc.bufferView]
inv_bind = np.frombuffer(data[ibm_bv.byteOffset : ibm_bv.byteOffset + ibm_bv.byteLength], dtype=np.float32).reshape(-1, 4, 4)

# Read animation channels for idle
anim = next(a for a in glb.animations if a.name == 'idle')
time_acc = glb.accessors[anim.samplers[0].input]
time_bv = glb.bufferViews[time_acc.bufferView]
times = np.frombuffer(data[time_bv.byteOffset : time_bv.byteOffset + time_bv.byteLength], dtype=np.float32)

# Get frame 0 translations and rotations for each joint
node_t = {}
node_r = {}
for ch in anim.channels:
    samp = anim.samplers[ch.sampler]
    out_acc = glb.accessors[samp.output]
    out_bv = glb.bufferViews[out_acc.bufferView]
    if ch.target.path == 'translation':
        vals = np.frombuffer(data[out_bv.byteOffset : out_bv.byteOffset + out_bv.byteLength], dtype=np.float32).reshape(-1, 3)
        node_t[ch.target.node] = vals[0]
    elif ch.target.path == 'rotation':
        vals = np.frombuffer(data[out_bv.byteOffset : out_bv.byteOffset + out_bv.byteLength], dtype=np.float32).reshape(-1, 4)
        node_r[ch.target.node] = vals[0]

# Compute world transform for each joint
from scipy.spatial.transform import Rotation

joint_nodes = glb.skins[0].joints
joint_world = {}

def get_node_transform(node_idx):
    node = glb.nodes[node_idx]
    t = node_t.get(node_idx, np.array(node.translation if node.translation else [0, 0, 0], dtype=np.float32))
    r = node_r.get(node_idx, np.array(node.rotation if node.rotation else [0, 0, 0, 1], dtype=np.float32))
    m = np.identity(4, dtype=np.float32)
    m[:3, :3] = Rotation.from_quat(r).as_matrix()
    m[:3, 3] = t
    return m

# Build parent hierarchy
parent_map = {}
for i, n in enumerate(glb.nodes):
    if n.children:
        for c in n.children:
            parent_map[c] = i

world_m = {}
def get_world_m(node_idx):
    if node_idx in world_m:
        return world_m[node_idx]
    local_m = get_node_transform(node_idx)
    if node_idx in parent_map:
        W = get_world_m(parent_map[node_idx]) @ local_m
    else:
        W = local_m
    world_m[node_idx] = W
    return W

for j in joint_nodes:
    get_world_m(j)

# Now skin each primitive
for p_idx, prim in enumerate(glb.meshes[0].primitives):
    mat_name = glb.materials[prim.material].name
    pos_acc = glb.accessors[prim.attributes.POSITION]
    pos_bv = glb.bufferViews[pos_acc.bufferView]
    raw_pos = np.frombuffer(data[pos_bv.byteOffset : pos_bv.byteOffset + pos_bv.byteLength], dtype=np.float32).reshape(-1, 3)

    j_acc = glb.accessors[prim.attributes.JOINTS_0]
    j_bv = glb.bufferViews[j_acc.bufferView]
    raw_j = np.frombuffer(data[j_bv.byteOffset : j_bv.byteOffset + j_bv.byteLength], dtype=np.uint16).reshape(-1, 4)[:, 0]

    skinned_pos = []
    for vi in range(len(raw_pos)):
        v = raw_pos[vi]
        j_idx = raw_j[vi] # joint index into skins[0].joints
        node_idx = joint_nodes[j_idx]
        ibm = inv_bind[j_idx]
        wm = world_m[node_idx]
        skin_mat = wm @ ibm
        v4 = np.array([v[0], v[1], v[2], 1.0], dtype=np.float32)
        skinned_v = (skin_mat @ v4)[:3]
        skinned_pos.append(skinned_v)

    skinned_pos = np.array(skinned_pos, dtype=np.float32)
    print(f'Prim {p_idx} ({mat_name}): min={skinned_pos.min(axis=0)} max={skinned_pos.max(axis=0)} mean={skinned_pos.mean(axis=0)}')
