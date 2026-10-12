"""GoldSrc (Half-Life / CS 1.6, BSP v30) reader.

Pure Python + numpy so it runs inside Blender's bundled interpreter.
Extracts entities, embedded miptex textures, render faces with texture UVs and
per-face lightmaps (style 0), which is everything needed to rebuild the map as
a lightmapped static mesh.
"""
from __future__ import annotations

import glob
import math
import os
import re
import struct
from dataclasses import dataclass, field

import numpy as np

LUMP_NAMES = (
    "ENTITIES", "PLANES", "TEXTURES", "VERTICES", "VISIBILITY", "NODES", "TEXINFO",
    "FACES", "LIGHTING", "CLIPNODES", "LEAVES", "MARKSURFACES", "EDGES", "SURFEDGES", "MODELS",
)

# Tool textures that never render in the GoldSrc engine.
NON_RENDER_TEXTURES = {"sky", "clip", "aaatrigger", "origin", "null", "skip", "hint", "bevel", "clipbevel", "solidhint"}
TEX_SPECIAL = 1  # texinfo flag: no lightmap (sky / liquids)


@dataclass
class MipTexture:
    name: str
    width: int
    height: int
    rgba: np.ndarray | None  # (h, w, 4) uint8, top row first; None if texture lives in an external WAD

    @property
    def alpha_tested(self) -> bool:
        return self.name.startswith("{")


@dataclass
class Face:
    model: int
    texture: int
    positions: np.ndarray  # (n, 3) float64, GoldSrc units, polygon winding order
    tex_uv: np.ndarray  # (n, 2) texture UV in texture repeats (u = s / width, v = t / height)
    light_st: np.ndarray  # (n, 2) luxel-space coordinates relative to face lightmap origin (+0.5 centre)
    light_size: tuple[int, int]  # (w, h) luxels, (0, 0) when unlit
    light_rgb: np.ndarray | None  # (h, w, 3) uint8 style 0 lightmap
    normal: np.ndarray


@dataclass
class Bsp:
    entities: list[dict[str, str]]
    textures: list[MipTexture]
    faces: list[Face]
    models: list[dict] = field(default_factory=list)

    def entity_models(self) -> dict[int, dict[str, str]]:
        """Map brush model index -> owning entity (worldspawn is model 0)."""
        out: dict[int, dict[str, str]] = {}
        for ent in self.entities:
            if ent.get("classname") == "worldspawn":
                out[0] = ent
            model = ent.get("model", "")
            if model.startswith("*"):
                out[int(model[1:])] = ent
        return out


def _parse_entities(text: str) -> list[dict[str, str]]:
    ents = []
    for block in re.finditer(r"\{([^{}]*)\}", text):
        ents.append(dict(re.findall(r'"([^"]*)"\s+"([^"]*)"', block.group(1))))
    return ents


def _read_miptex(data: bytes, base: int) -> MipTexture:
    name = data[base:base + 16].split(b"\0")[0].decode("latin1")
    width, height = struct.unpack_from("<II", data, base + 16)
    offsets = struct.unpack_from("<4I", data, base + 24)
    if offsets[0] == 0:
        return MipTexture(name, width, height, None)
    pixels = np.frombuffer(data, np.uint8, width * height, base + offsets[0]).reshape(height, width)
    pal_ofs = base + offsets[3] + (width // 8) * (height // 8) + 2  # skip u16 palette size
    palette = np.frombuffer(data, np.uint8, 256 * 3, pal_ofs).reshape(256, 3)
    rgba = np.empty((height, width, 4), np.uint8)
    rgba[..., :3] = palette[pixels]
    rgba[..., 3] = 255
    if name.startswith("{"):
        # '{' textures: palette index 255 is fully transparent. Bleed neighbour colour
        # into the holes so bilinear filtering does not produce blue fringes.
        mask = pixels == 255
        rgba[mask, 3] = 0
        if mask.any() and (~mask).any():
            opaque = rgba[~mask, :3].astype(np.float32).mean(axis=0)
            rgba[mask, :3] = opaque.astype(np.uint8)
    return MipTexture(name, width, height, rgba)


_WAD_CACHE: dict[str, tuple[str, int, int]] | None = None


def _get_wad_cache() -> dict[str, tuple[str, int, int]]:
    global _WAD_CACHE
    if _WAD_CACHE is not None:
        return _WAD_CACHE

    cache: dict[str, tuple[str, int, int]] = {}
    search_dirs = [
        "C:/Games/Counter-Strike 1.6/valve",
        "C:/Games/Counter-Strike 1.6/cstrike",
        "C:/Games/Counter-Strike 1.6/cstrike_downloads",
        "D:/csochka/CS 1.6",
        "D:/csochka/CS 1.6/godot/maps",
        os.path.expanduser("~/Downloads"),
    ]
    wad_files: list[str] = []
    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for root, _, files in os.walk(d):
            for f in files:
                if f.lower().endswith(".wad"):
                    wad_files.append(os.path.join(root, f))

    for wf in wad_files:
        try:
            with open(wf, "rb") as f:
                hdr = f.read(12)
                if len(hdr) < 12:
                    continue
                magic, numlumps, infotableofs = struct.unpack("<4sII", hdr)
                if magic not in (b"WAD3", b"WAD2"):
                    continue
                f.seek(infotableofs)
                for _ in range(numlumps):
                    entry = f.read(32)
                    if len(entry) < 32:
                        break
                    ofs, dsize, size, ltype, cmprs, dummy = struct.unpack("<IIIBBH", entry[:16])
                    tname = entry[16:].split(b"\0")[0].decode("latin1", "ignore").lower()
                    if tname and tname not in cache:
                        cache[tname] = (wf, ofs, dsize)
        except Exception:
            pass

    _WAD_CACHE = cache
    return _WAD_CACHE


def load(path: str) -> Bsp:
    data = open(path, "rb").read()
    version = struct.unpack_from("<i", data, 0)[0]
    if version != 30:
        raise ValueError(f"{path}: unsupported BSP version {version} (expected 30 / GoldSrc)")
    lumps = {name: struct.unpack_from("<ii", data, 4 + i * 8) for i, name in enumerate(LUMP_NAMES)}

    def lump(name: str) -> tuple[int, int]:
        return lumps[name]

    ent_ofs, ent_len = lump("ENTITIES")
    entities = _parse_entities(data[ent_ofs:ent_ofs + ent_len].decode("latin1", "replace"))

    tex_ofs, _ = lump("TEXTURES")
    tex_count = struct.unpack_from("<i", data, tex_ofs)[0]
    textures = []
    wad_cache = None
    for mip_ofs in struct.unpack_from(f"<{tex_count}i", data, tex_ofs + 4):
        if mip_ofs < 0:
            textures.append(MipTexture("missing", 16, 16, None))
        else:
            tex = _read_miptex(data, tex_ofs + mip_ofs)
            if tex.rgba is None and tex.name.lower() not in NON_RENDER_TEXTURES:
                if wad_cache is None:
                    wad_cache = _get_wad_cache()
                tkey = tex.name.lower()
                if tkey in wad_cache:
                    wf, ofs, dsize = wad_cache[tkey]
                    try:
                        with open(wf, "rb") as f:
                            f.seek(ofs)
                            tex_data = f.read(dsize)
                            mt = _read_miptex(tex_data, 0)
                            tex.rgba = mt.rgba
                            tex.width = mt.width
                            tex.height = mt.height
                    except Exception:
                        pass
            textures.append(tex)

    v_ofs, v_len = lump("VERTICES")
    vertices = np.frombuffer(data, np.float32, v_len // 4, v_ofs).reshape(-1, 3).astype(np.float64)
    e_ofs, e_len = lump("EDGES")
    edges = np.frombuffer(data, np.uint16, e_len // 2, e_ofs).reshape(-1, 2)
    se_ofs, se_len = lump("SURFEDGES")
    surfedges = np.frombuffer(data, np.int32, se_len // 4, se_ofs)
    p_ofs, p_len = lump("PLANES")
    planes = [struct.unpack_from("<4fi", data, p_ofs + i * 20) for i in range(p_len // 20)]
    ti_ofs, ti_len = lump("TEXINFO")
    texinfos = []
    for i in range(ti_len // 40):
        vals = struct.unpack_from("<8f2i", data, ti_ofs + i * 40)
        texinfos.append((np.array(vals[0:4], np.float32), np.array(vals[4:8], np.float32), vals[8], vals[9]))
    light_ofs_lump, light_len = lump("LIGHTING")
    lighting = data[light_ofs_lump:light_ofs_lump + light_len]

    m_ofs, m_len = lump("MODELS")
    models = []
    face_model = {}
    for i in range(m_len // 64):
        vals = struct.unpack_from("<9f4i3i", data, m_ofs + i * 64)
        model = {
            "mins": vals[0:3], "maxs": vals[3:6], "origin": vals[6:9],
            "headnodes": vals[9:13], "visleafs": vals[13], "firstface": vals[14], "numfaces": vals[15],
        }
        models.append(model)
        for f in range(model["firstface"], model["firstface"] + model["numfaces"]):
            face_model[f] = i

    f_ofs, f_len = lump("FACES")
    # Byte budget of each face's lightmap = distance to the next lightmap block. Compilers and the
    # engine disagree on float precision for extents, so the budget disambiguates the luxel grid.
    light_offsets = sorted({struct.unpack_from("<i", data, f_ofs + fi * 20 + 16)[0] for fi in range(f_len // 20)} - {-1})
    light_budget = {a: b - a for a, b in zip(light_offsets, light_offsets[1:] + [len(lighting)])}
    faces = []
    for fi in range(f_len // 20):
        planenum, side, firstedge, numedges, texinfo_i = struct.unpack_from("<HHiHH", data, f_ofs + fi * 20)
        styles = data[f_ofs + fi * 20 + 12:f_ofs + fi * 20 + 16]
        lightofs = struct.unpack_from("<i", data, f_ofs + fi * 20 + 16)[0]
        vec_s, vec_t, miptex, flags = texinfos[texinfo_i]
        tex = textures[miptex]

        idx = []
        for k in range(firstedge, firstedge + numedges):
            se = surfedges[k]
            idx.append(edges[se][0] if se >= 0 else edges[-se][1])
        pos = vertices[idx]

        # Engine math is float32; the compiler (hlrad) may have used doubles. Try both.
        pos32 = pos.astype(np.float32)
        s = pos32 @ vec_s[:3] + vec_s[3]
        t = pos32 @ vec_t[:3] + vec_t[3]
        tex_uv = np.stack([s / tex.width, t / tex.height], axis=1).astype(np.float64)

        light_rgb = None
        light_size = (0, 0)
        light_st = np.zeros((len(idx), 2))
        if not (flags & TEX_SPECIAL) and lightofs >= 0 and styles[0] != 255:
            num_styles = sum(1 for st in styles if st != 255)
            s64 = pos @ vec_s[:3].astype(np.float64) + float(vec_s[3])
            t64 = pos @ vec_t[:3].astype(np.float64) + float(vec_t[3])
            candidates = []
            for ss, tt in ((s, t), (s64, t64)):
                bmin_s, bmax_s = math.floor(float(ss.min()) / 16), math.ceil(float(ss.max()) / 16)
                bmin_t, bmax_t = math.floor(float(tt.min()) / 16), math.ceil(float(tt.max()) / 16)
                candidates.append((bmin_s, bmin_t, bmax_s - bmin_s + 1, bmax_t - bmin_t + 1))
            budget = light_budget.get(lightofs, 0)
            match = next((c for c in candidates if c[2] * c[3] * 3 * num_styles == budget), None)
            if match is None:
                # Off-by-one at an exact 16-unit boundary: keep the column count, trust the lump for rows.
                bmin_s, bmin_t, lw, lh = candidates[1]
                if budget and budget % (lw * 3 * num_styles) == 0:
                    lh = min(lh, budget // (lw * 3 * num_styles))
                match = (bmin_s, bmin_t, lw, lh)
            bmin_s, bmin_t, lw, lh = match
            count = lw * lh * 3
            if lightofs + count <= len(lighting):
                light_rgb = np.frombuffer(lighting, np.uint8, count, lightofs).reshape(lh, lw, 3)
                light_size = (lw, lh)
                light_st = np.stack([s64 / 16 - bmin_s + 0.5, t64 / 16 - bmin_t + 0.5], axis=1)

        nx, ny, nz, _dist, _type = planes[planenum]
        normal = np.array([nx, ny, nz]) * (-1 if side else 1)
        faces.append(Face(face_model.get(fi, 0), miptex, pos, tex_uv, light_st, light_size, light_rgb, normal))

    return Bsp(entities, textures, faces, models)


def pack_lightmaps(faces: list[Face], pad: int = 1, max_width: int = 2048):
    """Shelf-pack face lightmaps into one RGB atlas.

    Returns (atlas uint8 (H, W, 3) top-row-first, {face_index: (x, y)} luxel origin of the face block).
    Each block gets `pad` luxels of edge-replicated border so bilinear filtering never bleeds.
    """
    items = [(i, f) for i, f in enumerate(faces) if f.light_rgb is not None]
    area = sum((f.light_size[0] + 2 * pad) * (f.light_size[1] + 2 * pad) for _, f in items)
    width = 64
    while width * width < area * 1.15 and width < max_width:
        width *= 2
    items.sort(key=lambda it: (-(it[1].light_size[1]), -(it[1].light_size[0])))

    placements = {}
    x = y = shelf_h = 0
    for i, f in items:
        w, h = f.light_size[0] + 2 * pad, f.light_size[1] + 2 * pad
        if x + w > width:
            x, y, shelf_h = 0, y + shelf_h, 0
        placements[i] = (x + pad, y + pad)
        x += w
        shelf_h = max(shelf_h, h)
    height = 1
    while height < y + shelf_h:
        height *= 2

    atlas = np.zeros((height, width, 3), np.uint8)
    for i, f in items:
        px, py = placements[i]
        block = np.pad(f.light_rgb, ((pad, pad), (pad, pad), (0, 0)), mode="edge")
        atlas[py - pad:py - pad + block.shape[0], px - pad:px - pad + block.shape[1]] = block
    return atlas, placements
