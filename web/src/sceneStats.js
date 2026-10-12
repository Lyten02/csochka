/**
 * One-shot scene statistics and GPU memory estimates.
 * Geometry bytes = sum of unique attribute arrays + index arrays.
 * Texture bytes = w * h * 4 (RGBA8 upload) * 4/3 for a full mip chain.
 */
export function computeSceneStats(root, materialSets, extraTextures = []) {
  const geometries = new Set();
  const materials = new Set();
  const textures = new Set();
  let meshes = 0;
  let vertices = 0;
  let triangles = 0;

  root.traverse((obj) => {
    if (!obj.isMesh) return;
    meshes++;
    const geo = obj.geometry;
    geometries.add(geo);
    const pos = geo.attributes.position;
    vertices += pos ? pos.count : 0;
    triangles += (geo.index ? geo.index.count : pos ? pos.count : 0) / 3;
  });

  for (const set of materialSets) {
    for (const mat of set) {
      materials.add(mat);
      if (mat.map) textures.add(mat.map);
      if (mat.lightMap) textures.add(mat.lightMap);
    }
  }

  let geometryBytes = 0;
  const arrays = new Set();
  for (const geo of geometries) {
    for (const name in geo.attributes) {
      const attr = geo.attributes[name];
      const array = attr.isInterleavedBufferAttribute ? attr.data.array : attr.array;
      if (!arrays.has(array)) {
        arrays.add(array);
        geometryBytes += array.byteLength;
      }
    }
    if (geo.index && !arrays.has(geo.index.array)) {
      arrays.add(geo.index.array);
      geometryBytes += geo.index.array.byteLength;
    }
  }

  let textureBytes = 0;
  let lightmapBytes = 0;
  const textureList = [];
  for (const tex of textures) {
    const img = tex.image;
    const w = img?.width || 0;
    const h = img?.height || 0;
    const mip = tex.generateMipmaps ? 4 / 3 : 1;
    const bytes = w * h * 4 * mip;
    textureBytes += bytes;
    const isLightmap = tex.channel === 1;
    if (isLightmap) lightmapBytes += bytes;
    textureList.push({ name: tex.name || (isLightmap ? 'lightmap' : '?'), w, h, bytes, isLightmap });
  }
  for (const extra of extraTextures) {
    textureBytes += extra.bytes;
    textureList.push(extra);
  }
  textureList.sort((a, b) => b.bytes - a.bytes);

  return {
    meshes,
    primitives: meshes, // GLTFLoader creates one THREE.Mesh per glTF primitive
    geometries: geometries.size,
    materials: materials.size,
    vertices,
    triangles: Math.round(triangles),
    geometryBytes,
    textureCount: textures.size,
    textureBytes,
    lightmapBytes,
    textureList,
  };
}
