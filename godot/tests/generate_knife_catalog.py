"""Generate player-facing catalog entries; technical provenance stays in the source manifest."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def generate_catalog(manifest):
    entries = []
    for source in manifest:
        slug = source['slug']
        inspect = source['inspect']
        entries.append({
            'id': 'cs16forge_' + slug,
            'name': source['name'],
            'model': f'res://models/knives/{slug}.glb',
            'icon': f'res://models/knives/{slug}_thumb.png',
            'desc': 'Осмотр ножа: F.' if inspect else 'Без осмотра.',
            'details': 'Источник: cs16forge.com',
            'category': source['category'],
            'inspect_anim': inspect['name'] if inspect else None,
            'anims': source['role_map'],
            'source_slug': slug,
        })
    return entries


if __name__ == '__main__':
    manifest = json.loads((ROOT / 'models_src/knives/manifest.json').read_text(encoding='utf-8'))
    output = ROOT / 'godot/models/knives/catalog.json'
    output.write_text(json.dumps(generate_catalog(manifest), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Generated {len(manifest)} player-facing catalog entries: {output}')
