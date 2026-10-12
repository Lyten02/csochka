import pygltflib
import numpy as np
from scipy.spatial.transform import Rotation

glb = pygltflib.GLTF2().load('godot/models/knife_black.glb')
data = glb.binary_blob()
ibm_acc = glb.accessors[glb.skins[0].inverseBindMatrices]
ibm_bv = glb.bufferViews[ibm_acc.bufferView]
inv_bind = np.frombuffer(data[ibm_bv.byteOffset : ibm_bv.byteOffset + ibm_bv.byteLength], dtype=np.float32).reshape(-1, 4, 4)

anim = next(a for a in glb.animations if a.name == 'idle')
node_t, node_r = {}, {}
for ch in anim.channels:
    samp = anim.samplers[ch.sampler]
    out_bv = glb.bufferViews[glb.accessors[samp.output].bufferView]
    if ch.target.path == 'translation':
        node_t[ch.target.node] = np.frombuffer(data[out_bv.byteOffset : out_bv.byteOffset + out_bv.byteLength], dtype=np.float32).reshape(-1, 3)[0]
    elif ch.target.path == 'rotation':
        node_r[ch.target.node] = np.frombuffer(data[out_bv.byteOffset : out_bv.byteOffset + out_bv.byteLength], dtype=np.float32).reshape(-1, 4)[0]

joint_nodes = glb.skins[0].joints
parent_map = {}
for i, n in enumerate(glb.nodes):
    if n.children:
        for c in n.children: parent_map[c] = i

world_m = {}
def get_world_m(node_idx):
    if node_idx in world_m: return world_m[node_idx]
    node = glb.nodes[node_idx]
    t = node_t.get(node_idx, np.array(node.translation or [0,0,0], dtype=np.float32))
    r = node_r.get(node_idx, np.array(node.rotation or [0,0,0,1], dtype=np.float32))
    m = np.identity(4, dtype=np.float32)
    m[:3, :3] = Rotation.from_quat(r).as_matrix()
    m[:3, 3] = t
    W = (get_world_m(parent_map[node_idx]) @ m) if node_idx in parent_map else m
    world_m[node_idx] = W
    return W

for j in joint_nodes: get_world_m(j)

prim = glb.meshes[0].primitives[0]
pos_bv = glb.bufferViews[glb.accessors[prim.attributes.POSITION].bufferView]
raw_pos = np.frombuffer(data[pos_bv.byteOffset : pos_bv.byteOffset + pos_bv.byteLength], dtype=np.float32).reshape(-1, 3)

j_bv = glb.bufferViews[glb.accessors[prim.attributes.JOINTS_0].bufferView]
raw_j = np.frombuffer(data[j_bv.byteOffset : j_bv.byteOffset + j_bv.byteLength], dtype=np.uint16).reshape(-1, 4)[:, 0]

skin_m_knife = world_m[joint_nodes[raw_j[0]]] @ inv_bind[raw_j[0]]

tip = (skin_m_knife @ np.append(raw_pos[np.argmin(raw_pos[:, 2])], 1.0))[:3]
base = (skin_m_knife @ np.append(raw_pos[np.argmax(raw_pos[:, 2])], 1.0))[:3]
spine = (skin_m_knife @ np.append(raw_pos[267], 1.0))[:3]
edge = (skin_m_knife @ np.append(raw_pos[224], 1.0))[:3]

u_y = (tip - base) / np.linalg.norm(tip - base)
w = edge - spine
u_x = w - np.dot(w, u_y) * u_y
u_x /= np.linalg.norm(u_x)
u_z = np.cross(u_x, u_y)
M_blade = np.column_stack([u_x, u_y, u_z])

print('Blade direction in model space:', u_y)
print('Width direction (spine to edge) in model space:', u_x)

for theta_deg in [-10, -5, 0, 5, 10, 15, 20]:
    for tilt_x_deg in [-5, 0, 5]: # slight tilt left/right
        theta = np.radians(theta_deg)
        tilt_x = np.radians(tilt_x_deg)
        t_y = np.array([np.sin(tilt_x), np.cos(theta), -np.sin(theta)], dtype=np.float32)
        t_y /= np.linalg.norm(t_y)
        t_x = np.array([-1, 0, 0], dtype=np.float32)
        t_x = t_x - np.dot(t_x, t_y) * t_y
        t_x /= np.linalg.norm(t_x)
        t_z = np.cross(t_x, t_y)
        M_target = np.column_stack([t_x, t_y, t_z])
        R = M_target @ M_blade.T
        rot = Rotation.from_matrix(R)
        yaw, pitch, roll = rot.as_euler('YXZ', degrees=True)
        print(f'tilt_z={theta_deg:3d}, tilt_x={tilt_x_deg:2d} -> Godot Vector3({pitch:6.1f}, {yaw:6.1f}, {roll:6.1f})')
