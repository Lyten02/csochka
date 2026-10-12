import pygltflib, numpy as np
from scipy.spatial.transform import Rotation
from scipy.optimize import minimize

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
raw_pos = np.frombuffer(data[glb.bufferViews[glb.accessors[prim.attributes.POSITION].bufferView].byteOffset : glb.bufferViews[glb.accessors[prim.attributes.POSITION].bufferView].byteOffset + glb.bufferViews[glb.accessors[prim.attributes.POSITION].bufferView].byteLength], dtype=np.float32).reshape(-1, 3)
raw_j = np.frombuffer(data[glb.bufferViews[glb.accessors[prim.attributes.JOINTS_0].bufferView].byteOffset : glb.bufferViews[glb.accessors[prim.attributes.JOINTS_0].bufferView].byteOffset + glb.bufferViews[glb.accessors[prim.attributes.JOINTS_0].bufferView].byteLength], dtype=np.uint16).reshape(-1, 4)[:, 0]
skin_m_knife = world_m[joint_nodes[raw_j[0]]] @ inv_bind[raw_j[0]]

tip = (skin_m_knife @ np.append(raw_pos[np.argmin(raw_pos[:, 2])], 1.0))[:3]
base = (skin_m_knife @ np.append(raw_pos[np.argmax(raw_pos[:, 2])], 1.0))[:3]
spine = (skin_m_knife @ np.append(raw_pos[224], 1.0))[:3] # UV 0.05 = spine
edge = (skin_m_knife @ np.append(raw_pos[267], 1.0))[:3]  # UV 0.21 = edge

lh = world_m[joint_nodes[3]][:3, 3]
rh = world_m[joint_nodes[21]][:3, 3]

print('Model points:')
print('  Tip:  ', tip)
print('  Base: ', base)
print('  Spine:', spine)
print('  Edge: ', edge)
print('  LH:   ', lh)
print('  RH:   ', rh)

# Camera parameters:
# FOV = 73.74 vertical, aspect = 16:9 = 1.7778
# In normalized device coords (NDC) [-1, 1]:
# x_ndc = (x / -z) / (tan(fov_y/2) * aspect)
# y_ndc = (y / -z) / tan(fov_y/2)
fov_y = np.radians(73.74)
tan_half_y = np.tan(fov_y / 2.0)
aspect = 16.0 / 9.0
tan_half_x = tan_half_y * aspect

def project(p_cam):
    x, y, z = p_cam[0], p_cam[1], p_cam[2]
    # z is negative
    d = -z
    if d <= 0.01:
        return np.array([999.0, 999.0])
    return np.array([x / (d * tan_half_x), y / (d * tan_half_y)])

# Target screen positions in NDC [-1, 1] based on Screenshot 2:
# In Screenshot 2:
# LH is at bottom-left: x ≈ -0.5 to -0.7, y ≈ -0.6 to -0.8
# RH is at bottom-right: x ≈ +0.4 to +0.6, y ≈ -0.6 to -0.8
# Blade Base: x ≈ +0.4 to +0.5, y ≈ -0.4 to -0.5
# Blade Tip: x ≈ +0.45 to +0.55, y ≈ +0.7 to +0.9 (pointing straight up!)
# Edge.x < Spine.x (Edge is to the left of spine on screen)

print('\nSearching for best orientation...')
best_loss = 1e9
best_params = None

# Grid search over pitch, yaw, roll
for pitch in np.linspace(-40, 80, 25):
    for yaw in np.linspace(-180, 180, 37):
        for roll in np.linspace(-180, 180, 37):
            rot = Rotation.from_euler('YXZ', [yaw, pitch, roll], degrees=True)
            R = rot.as_matrix()

            # Blade vector in cam space:
            b_dir = R @ (tip - base)
            b_dir_n = b_dir / np.linalg.norm(b_dir)

            # We want blade pointing UP: b_dir_n[1] > 0.9, and |b_dir_n[0]| < 0.15
            if b_dir_n[1] < 0.85 or abs(b_dir_n[0]) > 0.2:
                continue

            # Edge to spine vector: we want edge on LEFT of spine (edge.x < spine.x)
            e_cam = R @ edge
            s_cam = R @ spine
            if (e_cam[0] - s_cam[0]) > -0.01: # edge must be to the left
                continue

            # Normal vector: should face camera (pointing towards +Z)
            # Normal in model space:
            n_blade = np.cross(edge - spine, tip - base)
            n_blade /= np.linalg.norm(n_blade)
            n_cam = R @ n_blade
            if n_cam[2] < 0.1: # must face player (+Z)
                continue

            # Check LH and RH relative positions:
            # We want RH on the right side of the screen (RH.x > 0)
            # And LH on the left of RH (LH.x < RH.x)
            lh_cam = R @ lh
            rh_cam = R @ rh
            if rh_cam[0] < 0.0:
                continue

            loss = (1.0 - b_dir_n[1]) * 10.0 + abs(b_dir_n[0]) * 5.0 - n_cam[2] * 2.0
            if loss < best_loss:
                best_loss = loss
                best_params = (pitch, yaw, roll, b_dir_n, e_cam[0] - s_cam[0], n_cam[2], lh_cam, rh_cam)
                print(f'Candidate: pitch={pitch:5.1f}, yaw={yaw:5.1f}, roll={roll:5.1f} | b_dir={b_dir_n} | dx_edge_spine={e_cam[0]-s_cam[0]:.3f} | n_z={n_cam[2]:.3f}')
                print(f'   LH={lh_cam}, RH={rh_cam}')
