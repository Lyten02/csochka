"""Render a seamless 360° desert skybox (equirectangular) for the map's `skyname desert`.

The BSP does not ship the CS skybox images, so this builds a procedural stand-in in Blender:
physical sky (sun where the map's light_environment puts it), red sandstone mesas/buttes with
strata, a sand plain, thin clouds and distance haze, rendered with a Cycles panoramic camera.

Usage:
    blender --background --factory-startup --python tools/make_skybox.py -- [out_root] [--preview]

Outputs (out_root defaults to the repository root):
    export/sky/desert_sky.png        4096x2048 PNG   (lossless master)
    export/sky/desert_sky.webp       4096x2048 WebP  (Godot)
    export/sky/desert_sky_web.webp   2048x1024 WebP  (browser)
and refreshes web/public/sky/ and godot/sky/ copies.

Image convention (same as three.js `equirectUv`): u = atan2(dir.z, dir.x) / 2π + 0.5,
v = asin(dir.y) / π + 0.5 with glTF/Godot axes (Y up, GoldSrc +X = +X, GoldSrc +Y = -Z).
"""
from __future__ import annotations

import math
import os
import random
import shutil
import sys

import bmesh
import bpy
import numpy as np

SUN_ELEVATION = 30.0  # light_spot "_sky 1": pitch -30
SUN_AZIMUTH = 0.0  # angles "0 270 0": light travels towards -Y, so the sun sits at +Y (Blender sky rotation 0 = +Y)
HAZE_DISTANCE = 28000.0  # metres, e-folding distance of aerial perspective
SEED = 35


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = "--preview" in argv
    argv = [a for a in argv if a != "--preview"]
    out_root = os.path.abspath(argv[0]) if argv else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return out_root, preview


def setup_render(scene, width, height, samples):
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for backend in ("OPTIX", "CUDA", "HIP", "ONEAPI", "METAL"):
        try:
            prefs.compute_device_type = backend
            prefs.get_devices()
            gpus = [d for d in prefs.devices if d.type == backend]
            if gpus:
                for d in prefs.devices:
                    d.use = d.type == backend
                scene.cycles.device = "GPU"
                break
        except TypeError:
            continue
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "None"


def make_world(scene):
    world = bpy.data.worlds.new("DesertSky")
    world.use_nodes = True
    nt = world.node_tree
    sky = nt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "MULTIPLE_SCATTERING"
    sky.sun_elevation = math.radians(SUN_ELEVATION)
    sky.sun_rotation = math.radians(SUN_AZIMUTH)
    sky.sun_size = math.radians(1.2)
    sky.altitude = 900.0
    sky.air_density = 1.0
    sky.aerosol_density = 3.0  # dusty desert air -> pale, warm horizon
    sky.ozone_density = 1.0
    nt.links.new(sky.outputs["Color"], nt.nodes["Background"].inputs["Color"])
    scene.world = world


def haze(nt, surface_socket, haze_rgb):
    """Aerial perspective: blend the surface towards the measured horizon radiance with view distance."""
    nodes, links = nt.nodes, nt.links
    cam = nodes.new("ShaderNodeCameraData")
    k = nodes.new("ShaderNodeMath"); k.operation = "MULTIPLY"; k.inputs[1].default_value = -1.0 / HAZE_DISTANCE
    e = nodes.new("ShaderNodeMath"); e.operation = "EXPONENT"
    inv = nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
    links.new(cam.outputs["View Distance"], k.inputs[0])
    links.new(k.outputs[0], e.inputs[0])
    links.new(e.outputs[0], inv.inputs[1])
    emit = nodes.new("ShaderNodeEmission"); emit.inputs["Color"].default_value = (*haze_rgb, 1.0)
    mix = nodes.new("ShaderNodeMixShader")
    links.new(inv.outputs[0], mix.inputs[0])
    links.new(surface_socket, mix.inputs[1])
    links.new(emit.outputs[0], mix.inputs[2])
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(mix.outputs[0], out.inputs["Surface"])


def ramp(nodes, stops):
    cr = nodes.new("ShaderNodeValToRGB")
    els = cr.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, col) in zip(els, stops):
        el.position = pos
        el.color = (*col, 1.0)
    return cr


def rock_material(haze_rgb):
    mat = bpy.data.materials.new("Sandstone")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], sep.inputs[0])

    # Strata: 1D noise along height, warped by a broad horizontal noise.
    warp = nodes.new("ShaderNodeTexNoise"); warp.inputs["Scale"].default_value = 0.0015
    links.new(geo.outputs["Position"], warp.inputs["Vector"])
    warp_amt = nodes.new("ShaderNodeMath"); warp_amt.operation = "MULTIPLY"; warp_amt.inputs[1].default_value = 40.0
    links.new(warp.outputs["Fac"], warp_amt.inputs[0])
    zw = nodes.new("ShaderNodeMath"); zw.operation = "ADD"
    links.new(sep.outputs["Z"], zw.inputs[0]); links.new(warp_amt.outputs[0], zw.inputs[1])
    strata_vec = nodes.new("ShaderNodeCombineXYZ")
    links.new(zw.outputs[0], strata_vec.inputs["Z"])
    strata = nodes.new("ShaderNodeTexNoise"); strata.noise_dimensions = "1D"
    strata.inputs["Scale"].default_value = 0.035
    strata.inputs["Detail"].default_value = 6.0
    links.new(zw.outputs[0], strata.inputs["W"])
    band = ramp(nodes, [(0.30, (0.28, 0.075, 0.03)), (0.45, (0.42, 0.14, 0.06)), (0.55, (0.55, 0.26, 0.13)),
                        (0.62, (0.36, 0.11, 0.05)), (0.75, (0.62, 0.38, 0.22))])
    links.new(strata.outputs["Fac"], band.inputs["Fac"])

    # Vertical erosion streaks darken the cliffs.
    smap = nodes.new("ShaderNodeMapping"); smap.inputs["Scale"].default_value = (1.0, 1.0, 0.08)
    links.new(geo.outputs["Position"], smap.inputs["Vector"])
    streak = nodes.new("ShaderNodeTexNoise"); streak.inputs["Scale"].default_value = 0.06
    streak.inputs["Detail"].default_value = 4.0
    links.new(smap.outputs[0], streak.inputs["Vector"])
    streak_ramp = ramp(nodes, [(0.35, (0.55, 0.55, 0.55)), (0.65, (1.0, 1.0, 1.0))])
    links.new(streak.outputs["Fac"], streak_ramp.inputs["Fac"])
    cliff = nodes.new("ShaderNodeMix"); cliff.data_type = "RGBA"; cliff.blend_type = "MULTIPLY"
    cliff.inputs[0].default_value = 1.0
    links.new(band.outputs["Color"], cliff.inputs[6]); links.new(streak_ramp.outputs["Color"], cliff.inputs[7])

    # Talus skirt and flat tops pick up wind-blown sand.
    attr = nodes.new("ShaderNodeAttribute"); attr.attribute_name = "hfrac"
    skirt_fac = ramp(nodes, [(0.12, (1, 1, 1)), (0.22, (0, 0, 0))])
    links.new(attr.outputs["Fac"], skirt_fac.inputs["Fac"])
    sepn = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Normal"], sepn.inputs[0])
    top_fac = ramp(nodes, [(0.75, (0, 0, 0)), (0.9, (1, 1, 1))])
    links.new(sepn.outputs["Z"], top_fac.inputs["Fac"])
    dust = nodes.new("ShaderNodeMath"); dust.operation = "MAXIMUM"
    links.new(skirt_fac.outputs["Color"], dust.inputs[0]); links.new(top_fac.outputs["Color"], dust.inputs[1])
    sand = nodes.new("ShaderNodeMix"); sand.data_type = "RGBA"
    links.new(dust.outputs[0], sand.inputs[0])
    links.new(cliff.outputs[2], sand.inputs[6])
    sand.inputs[7].default_value = (0.50, 0.25, 0.13, 1.0)

    bump_noise = nodes.new("ShaderNodeTexNoise"); bump_noise.inputs["Scale"].default_value = 0.02
    bump_noise.inputs["Detail"].default_value = 10.0
    links.new(geo.outputs["Position"], bump_noise.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6
    links.new(bump_noise.outputs["Fac"], bump.inputs["Height"])
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.1
    links.new(sand.outputs[2], bsdf.inputs["Base Color"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    haze(nt, bsdf.outputs[0], haze_rgb)
    return mat


def ground_material(haze_rgb):
    mat = bpy.data.materials.new("DesertFloor")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    geo = nodes.new("ShaderNodeNewGeometry")
    big = nodes.new("ShaderNodeTexNoise"); big.inputs["Scale"].default_value = 0.0006; big.inputs["Detail"].default_value = 8
    links.new(geo.outputs["Position"], big.inputs["Vector"])
    col = ramp(nodes, [(0.3, (0.16, 0.08, 0.04)), (0.5, (0.26, 0.13, 0.065)), (0.72, (0.34, 0.2, 0.11))])
    links.new(big.outputs["Fac"], col.inputs["Fac"])
    fine = nodes.new("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 0.05; fine.inputs["Detail"].default_value = 6
    links.new(geo.outputs["Position"], fine.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.3
    links.new(fine.outputs["Fac"], bump.inputs["Height"])
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Specular IOR Level"].default_value = 0.1
    links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    haze(nt, bsdf.outputs[0], haze_rgb)
    return mat


def cloud_material(haze_rgb):
    mat = bpy.data.materials.new("Clouds")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    geo = nodes.new("ShaderNodeNewGeometry")
    cmap = nodes.new("ShaderNodeMapping"); cmap.inputs["Scale"].default_value = (1.0, 2.5, 1.0)
    links.new(geo.outputs["Position"], cmap.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 0.00012
    noise.inputs["Detail"].default_value = 10.0; noise.inputs["Roughness"].default_value = 0.62
    links.new(cmap.outputs[0], noise.inputs["Vector"])
    cover = ramp(nodes, [(0.52, (0, 0, 0)), (0.75, (0.85, 0.85, 0.85))])
    links.new(noise.outputs["Fac"], cover.inputs["Fac"])
    transp = nodes.new("ShaderNodeBsdfTransparent")
    white = nodes.new("ShaderNodeBsdfTranslucent"); white.inputs["Color"].default_value = (0.95, 0.93, 0.9, 1)
    diff = nodes.new("ShaderNodeBsdfDiffuse"); diff.inputs["Color"].default_value = (0.9, 0.88, 0.86, 1)
    lit = nodes.new("ShaderNodeAddShader")
    links.new(white.outputs[0], lit.inputs[0]); links.new(diff.outputs[0], lit.inputs[1])
    mix = nodes.new("ShaderNodeMixShader")
    links.new(cover.outputs["Color"], mix.inputs[0])
    links.new(transp.outputs[0], mix.inputs[1]); links.new(lit.outputs[0], mix.inputs[2])
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(mix.outputs[0], out.inputs["Surface"])
    return mat


def mesa(name, center, radius, height, elong, rot, rng, mat, collection):
    """Butte: wide talus skirt, steep layered cliff, flat cap; hfrac attribute = height fraction."""
    n = 96
    phases = [rng.uniform(0, math.tau) for _ in range(5)]
    amps = [rng.uniform(0.04, 0.12) for _ in range(5)]
    levels = [(-0.02, 1.85), (0.10, 1.35), (0.20, 1.05), (0.24, 1.0), (0.52, 0.97), (0.56, 0.9),
              (0.60, 0.88), (0.9, 0.86), (0.94, 0.8), (1.0, 0.78)]
    bm = bmesh.new()
    rings = []
    ca, sa = math.cos(rot), math.sin(rot)
    for zf, rs in levels:
        ring = []
        for i in range(n):
            a = math.tau * i / n
            wobble = 1.0 + sum(amp * math.sin((k + 2) * a + ph) for k, (amp, ph) in enumerate(zip(amps, phases)))
            r = radius * rs * wobble * (1.0 + rng.uniform(-0.025, 0.025))
            x, y = math.cos(a) * r * elong, math.sin(a) * r
            z = zf * height + (rng.uniform(-0.02, 0.02) * height if 0.0 < zf < 1.0 else 0.0)
            ring.append(bm.verts.new((center[0] + x * ca - y * sa, center[1] + x * sa + y * ca, z)))
        rings.append(ring)
    for lo, hi in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(rings[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    attr = mesh.attributes.new("hfrac", "FLOAT", "POINT")
    attr.data.foreach_set("value", [max(v.co.z, 0.0) / height for v in mesh.vertices])
    for p in mesh.polygons:
        p.use_smooth = False
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    # Subdivide + displace for broken, eroded silhouettes.
    sub = obj.modifiers.new("sub", "SUBSURF"); sub.levels = sub.render_levels = 2; sub.subdivision_type = "SIMPLE"
    tex = bpy.data.textures.new(name + "_erosion", "CLOUDS"); tex.noise_scale = radius * 0.35; tex.noise_depth = 4
    disp = obj.modifiers.new("disp", "DISPLACE"); disp.texture = tex; disp.strength = radius * 0.08
    disp.mid_level = 0.5; disp.texture_coords = "GLOBAL"
    return obj


def build_landscape(scene, haze_rgb):
    col = bpy.data.collections.new("Desert")
    scene.collection.children.link(col)
    rng = random.Random(SEED)
    rock = rock_material(haze_rgb)

    ground = bpy.data.meshes.new("Ground")
    ground.from_pydata([(-80000, -80000, 0), (80000, -80000, 0), (80000, 80000, 0), (-80000, 80000, 0)], [], [(0, 1, 2, 3)])
    ground.materials.append(ground_material(haze_rgb))
    col.objects.link(bpy.data.objects.new("Ground", ground))

    clouds = bpy.data.meshes.new("Clouds")
    clouds.from_pydata([(-90000, -90000, 3200), (90000, -90000, 3200), (90000, 90000, 3200), (-90000, 90000, 3200)], [], [(0, 1, 2, 3)])
    clouds.materials.append(cloud_material(haze_rgb))
    col.objects.link(bpy.data.objects.new("Clouds", clouds))

    # Clusters of buttes all around, a big mesa wall behind the sun side, lone spires in between.
    clusters = [(15, 2600, 4), (65, 3800, 4), (120, 2200, 3), (170, 4500, 5), (215, 3000, 4),
                (262, 5200, 5), (305, 2400, 3), (345, 3500, 4)]
    idx = 0
    for az_deg, dist, count in clusters:
        for k in range(count):
            az = math.radians(az_deg + rng.uniform(-14, 14))
            d = dist * rng.uniform(0.8, 1.35)
            cx, cy = math.sin(az) * d, math.cos(az) * d
            spire = rng.random() < 0.35
            radius = rng.uniform(90, 200) if spire else rng.uniform(260, 800)
            height = rng.uniform(380, 700) if spire else rng.uniform(260, 560)
            elong = 1.0 if spire else rng.uniform(1.0, 2.4)
            mesa(f"Butte_{idx:02d}", (cx, cy), radius, height, elong, rng.uniform(0, math.pi), rng, rock, col)
            idx += 1
    return col


def camera(scene):
    cd = bpy.data.cameras.new("Pano")
    cd.type = "PANO"
    cd.panorama_type = "EQUIRECTANGULAR"
    cd.clip_end = 200000
    cam = bpy.data.objects.new("Pano", cd)
    cam.location = (0, 0, 30)
    # Face +X at the image centre (u = 0.5), +Y at u = 0.25: three.js/Godot equirect convention.
    cam.rotation_euler = (math.pi / 2, 0, -math.pi / 2)
    scene.collection.objects.link(cam)
    scene.camera = cam


def measure(scene, path):
    """Linear radiance stats of a small sky-only render: exposure + haze colour."""
    scene.render.image_settings.file_format = "OPEN_EXR"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]
    bpy.data.images.remove(img)
    os.remove(path)
    horizon = px[int(h * 0.47):int(h * 0.5)].reshape(-1, 3)
    sky = px[:int(h * 0.45)].reshape(-1, 3)
    lum = sky @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lum = lum[lum < np.percentile(lum, 99.5)]  # ignore the sun disc
    return horizon.mean(axis=0), float(np.median(lum))


def main():
    out_root, preview = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    make_world(scene)
    camera(scene)

    setup_render(scene, 256, 128, 16)
    haze_rgb, sky_lum = measure(scene, os.path.join(out_root, "export", "sky", "_measure.exr"))
    exposure = math.log2(0.30 / max(sky_lum, 1e-6))
    scene.view_settings.exposure = exposure
    print(f"SKYBOX haze {haze_rgb} sky median {sky_lum:.4f} exposure {exposure:.2f}")

    build_landscape(scene, tuple(float(c) for c in haze_rgb))
    width, height = (1024, 512) if preview else (4096, 2048)
    setup_render(scene, width, height, 32 if preview else 128)
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    out_dir = os.path.join(out_root, "export", "sky")
    png = os.path.join(out_dir, "desert_sky_preview.png" if preview else "desert_sky.png")
    scene.render.filepath = png
    bpy.ops.render.render(write_still=True)
    if preview:
        print("SKYBOX preview", png)
        return
    encode_outputs(scene, png, out_dir, out_root)


def encode_outputs(scene, png, out_dir, out_root):
    # The PNG is already display-referred: re-encode with an identity view transform.
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.0
    scene.render.image_settings.file_format = "WEBP"
    scene.render.image_settings.color_mode = "RGB"
    webps = {}
    for suffix, size, quality in (("", 4096, 90), ("_web", 2048, 85)):
        img = bpy.data.images.load(png, check_existing=False)
        if img.size[0] != size:
            img.scale(size, size // 2)
        scene.render.image_settings.quality = quality
        path = os.path.join(out_dir, f"desert_sky{suffix}.webp")
        img.save_render(path, scene=scene)
        bpy.data.images.remove(img)
        webps[suffix] = path
    for src, dest_dir in ((webps["_web"], os.path.join(out_root, "web", "public", "sky")),
                          (webps[""], os.path.join(out_root, "godot", "sky"))):
        if os.path.isdir(os.path.dirname(dest_dir)):
            os.makedirs(dest_dir, exist_ok=True)
            shutil.copy2(src, os.path.join(dest_dir, os.path.basename(src)))
    print("SKYBOX done", {os.path.basename(p): os.path.getsize(p) for p in [png, *webps.values()]})


if __name__ == "__main__":
    os.makedirs(os.path.join(parse_args()[0], "export", "sky"), exist_ok=True)
    main()
