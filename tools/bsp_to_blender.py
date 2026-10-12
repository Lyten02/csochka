"""Build an optimized, lightmapped Blender scene from a GoldSrc BSP and export GLB files.

Usage (headless):
    blender --background --factory-startup --python tools/bsp_to_blender.py -- <map.bsp> [out_root]

Outputs (out_root defaults to the repository root):
    blender/<map>.blend        editable scene (textures + lightmap packed)
    export/<map>.glb           PNG textures (Godot / generic glTF consumers)
    export/<map>_web.glb       WebP textures (browser build, smaller download)
    export/<map>_stats.json    build statistics
    web/public/maps/<map>_web.glb (+stats), godot/maps/<map>.glb + <map>.bsp   refreshed copies

Optimizations applied:
  * tool faces (sky/clip/trigger/origin/null...) and non-visual brush entities are dropped;
  * all static brushwork is merged into one mesh -> one draw call per material;
  * duplicate vertices are welded (per-loop UVs keep texture seams intact);
  * static lighting is baked into a single padded lightmap atlas on UV1, so runtime needs
    no dynamic lights, no shadows and no normals (the web material is unlit);
  * normals/tangents are not exported.
"""
from __future__ import annotations

import json
import math
import os
import shutil
import sys
import time

import bmesh
import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import goldsrc_bsp as gb  # noqa: E402

UNIT = 0.0254  # 1 GoldSrc unit = 1 inch
LIGHT_GAMMA = 2.5  # engine default `lightgamma`
TEXTURE_GAMMA = 2.0 / 2.5  # engine texgammatable: pow(x, texgamma / gamma) with texgamma 2.0, gamma 2.5
SKY_TEXTURE = "sky"  # faces drawn by the engine as "window to the skybox"
WELD_DISTANCE = 0.0005  # metres
# Brush entities that the engine draws. Everything else (triggers, ladders, clip volumes) is invisible.
RENDERED_CLASSES = {"worldspawn", "func_wall", "func_breakable", "func_illusionary", "func_door",
                    "func_door_rotating", "func_button", "func_rotating", "func_pushable", "func_wall_toggle",
                    "func_train", "func_tracktrain", "func_plat", "func_water", "func_conveyor"}
# kRenderTransColor=1, kRenderTransTexture=2, kRenderGlow=3, kRenderTransAlpha=4, kRenderTransAdd=5
TRANSLUCENT_MODES = {1, 2, 5}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if not argv:
        raise SystemExit("usage: blender -b --factory-startup --python tools/bsp_to_blender.py -- map.bsp [out_root]")
    bsp_path = os.path.abspath(argv[0])
    out_root = os.path.abspath(argv[1]) if len(argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return bsp_path, out_root


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.view_settings.view_transform = "Standard"  # show texture x lightmap colours unaltered
    world = bpy.data.worlds.new("Unlit")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)  # uniform white env -> diffuse = albedo
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    return scene


def make_image(name: str, rgba_top_first: np.ndarray) -> bpy.types.Image:
    h, w = rgba_top_first.shape[:2]
    if rgba_top_first.shape[2] == 3:
        rgba_top_first = np.concatenate([rgba_top_first, np.full((h, w, 1), 255, np.uint8)], axis=2)
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set((np.flipud(rgba_top_first).astype(np.float32) / 255.0).ravel())
    img.file_format = "PNG"
    img.pack()
    return img


def gltf_output_group() -> bpy.types.NodeTree:
    ng = bpy.data.node_groups.get("glTF Material Output")
    if ng is None:
        ng = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        ng.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    return ng


def make_material(name: str, tex_img, lightmap_img, variant: str, alpha: float) -> bpy.types.Material:
    """Base colour = texture(UV0) x lightmap(UV1) for Blender display.

    The glTF exporter follows the first image on the Base Color path (the texture) and exports the
    lightmap through the glTF occlusion slot on TEXCOORD_1; runtimes read its RGB as a light map.
    """
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    bsdf.inputs["Metallic"].default_value = 0.0

    uv0 = nodes.new("ShaderNodeUVMap"); uv0.uv_map = "UVMap"; uv0.location = (-900, 300)
    tex = nodes.new("ShaderNodeTexImage"); tex.image = tex_img; tex.location = (-650, 300)
    tex.interpolation = "Closest" if variant == "cutout" else "Linear"
    uv1 = nodes.new("ShaderNodeUVMap"); uv1.uv_map = "Lightmap"; uv1.location = (-900, -100)
    lm = nodes.new("ShaderNodeTexImage"); lm.image = lightmap_img; lm.location = (-650, -100)
    lm.extension = "EXTEND"
    links.new(uv0.outputs["UV"], tex.inputs["Vector"])
    links.new(uv1.outputs["UV"], lm.inputs["Vector"])

    mix = nodes.new("ShaderNodeMix"); mix.location = (-300, 250)
    mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    links.new(tex.outputs["Color"], mix.inputs[6])
    links.new(lm.outputs["Color"], mix.inputs[7])
    links.new(mix.outputs[2], bsdf.inputs["Base Color"])

    sep = nodes.new("ShaderNodeSeparateColor"); sep.location = (-300, -250)
    links.new(lm.outputs["Color"], sep.inputs["Color"])
    group = nodes.new("ShaderNodeGroup"); group.node_tree = gltf_output_group(); group.location = (0, -350)
    links.new(sep.outputs["Red"], group.inputs["Occlusion"])

    if variant == "cutout":
        rnd = nodes.new("ShaderNodeMath"); rnd.operation = "ROUND"; rnd.location = (-300, 0)
        links.new(tex.outputs["Alpha"], rnd.inputs[0])
        links.new(rnd.outputs[0], bsdf.inputs["Alpha"])
        mat.surface_render_method = "DITHERED"
    elif variant == "translucent":
        bsdf.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
        mat.use_backface_culling = False
    return mat


def make_sky_material(name: str) -> bpy.types.Material:
    """Sky brushes: runtimes draw the skybox through them (GoldSrc behaviour). Flat colour here."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.55, 0.62, 0.72, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.0
    return mat


def build_object(name, faces, face_ids, placements, atlas_size, materials, collection):
    aw, ah = atlas_size
    verts, polys, uv0, uv1, mat_idx = [], [], [], [], []
    mat_slots: dict[str, int] = {}
    for fid in face_ids:
        f = faces[fid]
        pos = f.positions
        order = list(range(len(pos)))
        # BSP windings are clockwise seen from the front; Blender wants counter-clockwise. Use the
        # Newell normal: many faces start with collinear vertices, so a 3-vertex cross product lies.
        newell = np.sum(np.cross(pos, np.roll(pos, -1, axis=0)), axis=0)
        if np.dot(newell, f.normal) < 0:
            order.reverse()
        base = len(verts)
        px, py = placements.get(fid, (0, 0))
        for k in order:
            verts.append(pos[k] * UNIT)
            u, v = f.tex_uv[k]
            uv0.append((u, 1.0 - v))
            if f.light_rgb is not None:
                lx, ly = f.light_st[k]
                uv1.append(((px + lx) / aw, 1.0 - (py + ly) / ah))
            else:
                uv1.append((0.5 / aw, 1.0 - 0.5 / ah))
        polys.append(list(range(base, base + len(order))))
        key = materials[fid]
        mat_idx.append(mat_slots.setdefault(key, len(mat_slots)))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], polys)
    uv_a = mesh.uv_layers.new(name="UVMap")
    uv_b = mesh.uv_layers.new(name="Lightmap")
    uv_a.data.foreach_set("uv", np.asarray(uv0, np.float32).ravel())
    uv_b.data.foreach_set("uv", np.asarray(uv1, np.float32).ravel())
    for key in mat_slots:
        mesh.materials.append(bpy.data.materials[key])
    mesh.polygons.foreach_set("material_index", np.asarray(mat_idx, np.int32))

    bm = bmesh.new()
    bm.from_mesh(mesh)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=WELD_DISTANCE)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=WELD_DISTANCE * 0.1)
    after = len(bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj, before, after


def main():
    t0 = time.time()
    bsp_path, out_root = parse_args()
    map_name = os.path.splitext(os.path.basename(bsp_path))[0]
    bsp = gb.load(bsp_path)
    scene = reset_scene()

    model_ents = bsp.entity_models()
    render_models, translucent_models = {}, {}
    for idx, ent in model_ents.items():
        cls = ent.get("classname", "")
        if cls not in RENDERED_CLASSES:
            continue
        render_models[idx] = ent
        mode = int(ent.get("rendermode", "0") or 0)
        amt = float(ent.get("renderamt", "255") or 255)
        if mode in TRANSLUCENT_MODES and amt < 255:
            translucent_models[idx] = max(amt, 1.0) / 255.0

    rendered = [i for i, f in enumerate(bsp.faces) if f.model in render_models]
    keep = [i for i in rendered if bsp.textures[bsp.faces[i].texture].name.lower() not in gb.NON_RENDER_TEXTURES]
    sky_ids = [i for i in rendered if bsp.textures[bsp.faces[i].texture].name.lower() == SKY_TEXTURE]

    atlas, placements = gb.pack_lightmaps([bsp.faces[i] if i in keep else _unlit(bsp.faces[i]) for i in range(len(bsp.faces))])
    atlas = (np.power(atlas.astype(np.float32) / 255.0, 1.0 / LIGHT_GAMMA) * 255.0 + 0.5).astype(np.uint8)
    lightmap_img = make_image(f"{map_name}_lightmap", atlas)
    lightmap_img.colorspace_settings.name = "sRGB"

    tex_imgs = {}
    for ti in sorted({bsp.faces[i].texture for i in keep}):
        tex = bsp.textures[ti]
        rgba = tex.rgba if tex.rgba is not None else np.full((tex.height, tex.width, 4), (255, 0, 255, 255), np.uint8)
        rgba = rgba.copy()
        rgba[..., :3] = (np.power(rgba[..., :3].astype(np.float32) / 255.0, TEXTURE_GAMMA) * 255.0 + 0.5).astype(np.uint8)
        tex_imgs[ti] = make_image(tex.name, rgba)

    face_mat, opaque_ids, trans_ids = {}, [], []
    for fid in keep:
        f = bsp.faces[fid]
        tex = bsp.textures[f.texture]
        if f.model in translucent_models:
            alpha = translucent_models[f.model]
            key = f"{tex.name}__a{int(round(alpha * 255))}"
            if key not in bpy.data.materials:
                make_material(key, tex_imgs[f.texture], lightmap_img, "translucent", alpha)
            trans_ids.append(fid)
        else:
            key = tex.name
            if key not in bpy.data.materials:
                make_material(key, tex_imgs[f.texture], lightmap_img, "cutout" if tex.alpha_tested else "opaque", 1.0)
            opaque_ids.append(fid)
        face_mat[fid] = key
    if sky_ids:
        make_sky_material(SKY_TEXTURE)
        for fid in sky_ids:
            face_mat[fid] = SKY_TEXTURE

    col = bpy.data.collections.new(map_name)
    scene.collection.children.link(col)
    atlas_size = (atlas.shape[1], atlas.shape[0])
    stats = {"map": map_name, "source_faces": len(bsp.faces), "rendered_faces": len(keep), "sky_faces": len(sky_ids), "objects": {}}
    for obj_name, ids in ((f"{map_name}_static", opaque_ids), (f"{map_name}_translucent", trans_ids), (f"{map_name}_sky", sky_ids)):
        if not ids:
            continue
        obj, vb, va = build_object(obj_name, bsp.faces, ids, placements, atlas_size, face_mat, col)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        stats["objects"][obj_name] = {"faces": len(ids), "triangles": tris, "verts_before_weld": vb,
                                      "verts_after_weld": va, "materials": len(obj.data.materials)}

    # Spawn points as empties (exported as glTF nodes with extras) for viewers.
    spawns = bpy.data.collections.new("spawns")
    scene.collection.children.link(spawns)
    for i, ent in enumerate(e for e in bsp.entities if e.get("classname") in ("info_player_start", "info_player_deathmatch")):
        x, y, z = (float(c) for c in ent["origin"].split())
        empty = bpy.data.objects.new(f"spawn_{ent['classname']}_{i:02d}", None)
        empty.location = (x * UNIT, y * UNIT, z * UNIT)
        yaw = float(ent.get("angles", "0 0 0").split()[1])
        empty.rotation_euler = (0, 0, math.radians(yaw))
        empty["classname"] = ent["classname"]
        spawns.objects.link(empty)

    os.makedirs(os.path.join(out_root, "blender"), exist_ok=True)
    os.makedirs(os.path.join(out_root, "export"), exist_ok=True)
    blend_path = os.path.join(out_root, "blender", f"{map_name}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=True)

    exports = {}
    for suffix, fmt in (("", "AUTO"), ("_web", "WEBP")):
        path = os.path.join(out_root, "export", f"{map_name}{suffix}.glb")
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", export_image_format=fmt, export_image_quality=90,
            export_texcoords=True, export_normals=False, export_tangents=False,
            export_materials="EXPORT", export_cameras=False, export_lights=False,
            export_extras=True, export_yup=True, export_apply=True, use_selection=False,
            export_attributes=False, export_skins=False, export_morph=False, export_animations=False,
        )
        exports[os.path.basename(path)] = os.path.getsize(path)

    stats.update({
        "lightmap_atlas": list(atlas_size), "textures": len(tex_imgs), "materials": len(set(face_mat.values())),
        "exports": exports, "blend": os.path.basename(blend_path), "build_seconds": round(time.time() - t0, 2),
    })
    with open(os.path.join(out_root, "export", f"{map_name}_stats.json"), "w", encoding="utf-8") as fp:
        json.dump(stats, fp, indent=2)

    # Refresh the copies consumed by the web viewer and the Godot project (bsp = collision hulls).
    web_maps = os.path.join(out_root, "web", "public", "maps")
    godot_maps = os.path.join(out_root, "godot", "maps")
    copies = [(f"{map_name}_web.glb", web_maps), (f"{map_name}_stats.json", web_maps), (f"{map_name}.glb", godot_maps)]
    for fname, dest in copies:
        if os.path.isdir(os.path.dirname(dest)):
            os.makedirs(dest, exist_ok=True)
            shutil.copy2(os.path.join(out_root, "export", fname), os.path.join(dest, fname))
    if os.path.isdir(os.path.dirname(godot_maps)):
        shutil.copy2(bsp_path, os.path.join(godot_maps, os.path.basename(bsp_path)))
    print("BSP2BLEND", json.dumps(stats))


def _unlit(face: gb.Face) -> gb.Face:
    """Faces that are not rendered must not take atlas space."""
    return gb.Face(face.model, face.texture, face.positions, face.tex_uv, face.light_st, (0, 0), None, face.normal)


if __name__ == "__main__":
    main()
