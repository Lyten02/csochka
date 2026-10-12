import * as THREE from 'three';

const MAX_ANISOTROPY = 4;

/**
 * Replaces every glTF material with unlit MeshBasicMaterial.
 *
 * The Blender pipeline stores the baked RGB lightmap in `occlusionTexture`
 * (texCoord 1), which GLTFLoader exposes as `material.aoMap`. We move it to
 * `lightMap` (sRGB, uv channel 1). MeshBasicMaterial computes
 * `lightMapTexel.rgb * lightMapIntensity * RECIPROCAL_PI` (see three's
 * meshbasic.glsl.js), so intensity = PI gives `texture * lightmap`.
 *
 * Each mesh gets two materials sharing the same textures: `lit` (with
 * lightmap) and `flat` (texture only); toggling swaps `mesh.material`
 * instead of recompiling shaders every time.
 *
 * Faces textured `sky` behave like GoldSrc sky brushes: they write depth only
 * and are drawn first, so the skybox background shows through them and hides
 * whatever geometry lies behind (exactly what the engine does).
 */
export const SKY_MATERIAL = 'sky';

export function convertMaterials(root, renderer) {
  const anisotropy = Math.min(MAX_ANISOTROPY, renderer.capabilities.getMaxAnisotropy());
  const lightmaps = new Map(); // aoMap source -> sRGB lightmap texture
  const pairs = new Map(); // original material -> { lit, flat }
  const meshes = [];

  const lightmapFor = (aoMap) => {
    let lm = lightmaps.get(aoMap.source);
    if (!lm) {
      lm = aoMap.clone();
      lm.colorSpace = THREE.SRGBColorSpace;
      lm.channel = 1;
      lm.anisotropy = Math.min(anisotropy, lm.anisotropy || 1);
      lm.generateMipmaps = true;
      lm.needsUpdate = true;
      lightmaps.set(aoMap.source, lm);
    }
    return lm;
  };

  const makePair = (src) => {
    if (src.name === SKY_MATERIAL) {
      const sky = new THREE.MeshBasicMaterial({ name: src.name, colorWrite: false, side: src.side });
      return { lit: sky, flat: sky, sky: true };
    }
    const map = src.map || null;
    if (map) {
      map.anisotropy = anisotropy;
      map.generateMipmaps = true;
    }
    const common = {
      name: src.name,
      map,
      color: src.color ? src.color.clone() : new THREE.Color(1, 1, 1),
      transparent: src.transparent,
      opacity: src.opacity,
      alphaTest: src.alphaTest,
      side: src.side,
      depthWrite: src.depthWrite,
    };
    const lit = new THREE.MeshBasicMaterial({
      ...common,
      lightMap: src.aoMap ? lightmapFor(src.aoMap) : null,
      lightMapIntensity: Math.PI,
    });
    const flat = new THREE.MeshBasicMaterial(common);
    return { lit, flat };
  };

  root.traverse((obj) => {
    if (!obj.isMesh) return;
    const src = obj.material;
    let pair = pairs.get(src);
    if (!pair) {
      pair = makePair(src);
      pairs.set(src, pair);
    }
    obj.material = pair.lit;
    if (pair.sky) obj.renderOrder = -1; // before any opaque geometry, right after the background
    obj.userData.materialPair = pair;
    meshes.push(obj);
  });

  // Original PBR materials were never rendered; their aoMap textures were
  // never uploaded (the lightmap clones share only the image source).
  for (const src of pairs.keys()) src.dispose();

  const pairList = [...pairs.values()];
  return {
    meshes,
    pairs: pairList,
    lightmaps: [...lightmaps.values()],
    setLightmap(on) {
      for (const mesh of meshes) {
        const pair = mesh.userData.materialPair;
        mesh.material = on ? pair.lit : pair.flat;
      }
    },
    setWireframe(on) {
      for (const pair of pairList) {
        pair.lit.wireframe = on;
        pair.flat.wireframe = on;
      }
    },
  };
}
