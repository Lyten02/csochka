"""Extract GoldSrc .spr sprite files to PNG with transparency."""
import os
import struct
import sys
from PIL import Image

def convert_sprites(spr_dir: str, out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    for fname in os.listdir(spr_dir):
        if not fname.lower().endswith(".spr"):
            continue
        path = os.path.join(spr_dir, fname)
        with open(path, "rb") as f:
            data = f.read()

        ident, ver, typ, texFormat = struct.unpack_from("<4siii", data, 0)
        if ident != b"IDSP":
            print(f"Skipping {fname}: not an IDSP sprite")
            continue

        numcolors = struct.unpack_from("<H", data, 40)[0]
        pal_bytes = data[42:42 + numcolors * 3]

        frame_offset = 42 + numcolors * 3
        frame_type = struct.unpack_from("<i", data, frame_offset)[0]
        ox, oy, w, h = struct.unpack_from("<iiii", data, frame_offset + 4)
        pixels_offset = frame_offset + 20
        pixels = data[pixels_offset:pixels_offset + w * h]

        img = Image.new("P", (w, h))
        img.frombytes(pixels)

        palette = list(pal_bytes)
        if len(palette) < 768:
            palette.extend([0] * (768 - len(palette)))
        img.putpalette(palette)

        rgba = img.convert("RGBA")
        datas = rgba.getdata()
        new_data = []
        for item in datas:
            r, g, b, _ = item
            brightness = (r + g + b) / 3.0
            if brightness < 10:
                new_data.append((0, 0, 0, 0))
            else:
                new_data.append((r, g, b, 255))
        rgba.putdata(new_data)

        out_name = os.path.splitext(fname)[0] + ".png"
        out_path = os.path.join(out_dir, out_name)
        rgba.save(out_path)
        print(f"Saved {out_name} ({w}x{h})")

if __name__ == "__main__":
    spr_src = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\zxcursed\.gemini\antigravity\brain\956c65b0-33f6-41d9-8b72-e82454f3f7a8\scratch\hud\cstrike\sprites"
    png_dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "godot", "sprites", "hud")
    convert_sprites(spr_src, png_dst)
