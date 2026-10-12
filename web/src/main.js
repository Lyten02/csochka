import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { convertMaterials } from './materials.js';
import { computeSceneStats } from './sceneStats.js';
import { GpuTimer } from './gpuTimer.js';
import { FlyCamera } from './flyCamera.js';
import { DebugOverlay } from './debugOverlay.js';

const DEFAULT_MAP = './maps/35hp_3_web.glb';
const DEFAULT_SKY = './sky/desert_sky_web.webp'; // equirect, rendered by tools/make_skybox.py
const SKY_COLOR = 0x9cc3e0; // shown until the skybox image has loaded
const INCH = 0.0254; // metres per GoldSrc unit
const EYE_HEIGHT = 17 * INCH; // eye above hull centre
const PIXEL_RATIO_KEY = 'cs16viewer.pixelRatio';
const BASE_VFOV = 75; // degrees, landscape
const MAX_VFOV = 100; // degrees, portrait cap
const MIN_HFOV = THREE.MathUtils.degToRad(60);
const RAD2DEG = 180 / Math.PI;

const $ = (id) => document.getElementById(id);
const canvas = $('view');
const toolbar = $('toolbar');
const overlayRoot = $('overlay');

const params = new URLSearchParams(location.search);
const mapUrl = params.get('map') || DEFAULT_MAP;
const skyUrl = params.get('sky') || DEFAULT_SKY;
const statsUrl = mapUrl.replace(/(_web)?\.glb(\?.*)?$/i, '_stats.json');

const isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
document.body.classList.toggle('touch', isTouch);

// ------------------------------------------------------------- renderer

const dpr = window.devicePixelRatio || 1;
const antialias = dpr <= 1.5;
const renderer = new THREE.WebGLRenderer({ canvas, antialias });
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.NoToneMapping;

const scene = new THREE.Scene();
scene.background = new THREE.Color(SKY_COLOR);
const camera = new THREE.PerspectiveCamera(BASE_VFOV, 1, 0.05, 400);

// Pixel ratio (render scale) with persistence.
const autoRatio = Math.min(dpr, 1.5);
const pixelRatioOptions = [
  { value: 'auto', label: `авто (${autoRatio.toFixed(2)})` },
  { value: '0.5', label: '0.5' },
  { value: '0.75', label: '0.75' },
  { value: '1', label: '1' },
  { value: 'native', label: `родной (${dpr.toFixed(2)})` },
];
let pixelRatioChoice = localStorage.getItem(PIXEL_RATIO_KEY) || 'auto';
if (!pixelRatioOptions.some((o) => o.value === pixelRatioChoice)) pixelRatioChoice = 'auto';
const resolvePixelRatio = (v) => (v === 'auto' ? autoRatio : v === 'native' ? dpr : Number(v));

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setPixelRatio(resolvePixelRatio(pixelRatioChoice));
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  // Landscape: 75° vertical FOV. Portrait: keep at least 60° horizontally.
  const vFovForMinH = 2 * Math.atan(Math.tan(MIN_HFOV / 2) / camera.aspect) * RAD2DEG;
  camera.fov = Math.min(MAX_VFOV, Math.max(BASE_VFOV, vFovForMinH));
  camera.updateProjectionMatrix();
  // On narrow screens the toolbar wraps; keep the overlay below it.
  overlayRoot.style.top = w <= 700 ? `${Math.ceil(toolbar.getBoundingClientRect().bottom + 6)}px` : '';
}
window.addEventListener('resize', resize);
window.addEventListener('orientationchange', resize);
resize();

// ------------------------------------------------------------- controls

const fly = new FlyCamera(camera, canvas, {
  joystick: $('joystick'),
  knob: $('joy-knob'),
  up: $('btn-up'),
  down: $('btn-down'),
});
const speedHint = $('speed-hint');
fly.onSpeedChange = (v) => {
  speedHint.textContent = `Скорость: ${v.toFixed(1)} м/с`;
};
fly.onSpeedChange(fly.baseSpeed);
document.addEventListener('pointerlockchange', () => {
  document.body.classList.toggle('locked', fly.locked);
});

const gpuTimer = new GpuTimer(renderer.getContext());

// ------------------------------------------------------------- loading

const loadFill = $('load-fill');
const loadText = $('load-text');
const kb = (b) => `${(b / 1024).toFixed(0)} КБ`;

async function download(url) {
  const t0 = performance.now();
  const res = await fetch(url);
  if (!res.ok) throw new Error(`HTTP ${res.status} ${res.statusText} — ${url}`);
  const total = Number(res.headers.get('content-length')) || 0;
  const chunks = [];
  let loaded = 0;
  const reader = res.body.getReader();
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    loaded += value.byteLength;
    if (total) {
      const p = Math.min(100, (loaded / total) * 100);
      loadFill.style.width = `${p.toFixed(1)}%`;
      loadText.textContent = `Скачано ${kb(loaded)} из ${kb(total)} (${p.toFixed(0)}%)`;
    } else {
      loadText.textContent = `Скачано ${kb(loaded)}`;
    }
  }
  const buffer = new Uint8Array(loaded);
  let offset = 0;
  for (const c of chunks) {
    buffer.set(c, offset);
    offset += c.byteLength;
  }
  // Dev/preview servers answer missing files with index.html (HTTP 200).
  const isGlb = loaded >= 4 && buffer[0] === 0x67 && buffer[1] === 0x6c && buffer[2] === 0x54 && buffer[3] === 0x46; // "glTF"
  const isJson = loaded > 0 && buffer[0] === 0x7b; // "{"
  if (!isGlb && !isJson) {
    throw new Error(`Ответ сервера не является glTF/GLB (Content-Type: ${res.headers.get('content-type') || '?'}) — ${url}`);
  }
  return { buffer: buffer.buffer, bytes: loaded, ms: performance.now() - t0 };
}

async function loadStats(url) {
  try {
    const res = await fetch(url);
    return res.ok ? await res.json() : null;
  } catch {
    return null;
  }
}

function collectSpawns(root) {
  const spawns = [];
  const pos = new THREE.Vector3();
  const quat = new THREE.Quaternion();
  const euler = new THREE.Euler();
  root.traverse((obj) => {
    if (!obj.name.startsWith('spawn_')) return;
    obj.getWorldPosition(pos);
    obj.getWorldQuaternion(quat);
    euler.setFromQuaternion(quat, 'YXZ');
    const cls = obj.userData.classname || (obj.name.includes('deathmatch') ? 'info_player_deathmatch' : 'info_player_start');
    spawns.push({
      name: obj.name,
      team: cls === 'info_player_deathmatch' ? 'Т' : 'КТ',
      eye: pos.clone().setY(pos.y + EYE_HEIGHT),
      // Node yaw is GoldSrc yaw (0 = +X). Three's camera looks down -Z,
      // so rotate by -90° to face the node's +X axis.
      yaw: euler.y - Math.PI / 2,
    });
  });
  // Keep glTF node order: the first spawn node is the start position.
  const perTeam = { КТ: 0, Т: 0 };
  for (const s of spawns) s.label = `${s.team} ${++perTeam[s.team]}`;
  return spawns;
}

function deviceInfo() {
  const gl = renderer.getContext();
  let vendor = gl.getParameter(gl.VENDOR);
  let rendererName = gl.getParameter(gl.RENDERER);
  const dbg = gl.getSupportedExtensions()?.includes('WEBGL_debug_renderer_info')
    ? gl.getExtension('WEBGL_debug_renderer_info')
    : null;
  if (dbg) {
    vendor = gl.getParameter(dbg.UNMASKED_VENDOR_WEBGL) || vendor;
    rendererName = gl.getParameter(dbg.UNMASKED_RENDERER_WEBGL) || rendererName;
  } else {
    vendor += ' (маскировано)';
  }
  const conn = navigator.connection;
  const uaPlatform = navigator.userAgentData?.platform || navigator.platform || '?';
  const mobile = navigator.userAgentData?.mobile;
  return {
    gpuVendor: vendor,
    gpuRenderer: rendererName,
    webgl: `${renderer.capabilities.isWebGL2 ? 'WebGL 2' : 'WebGL 1'} (${gl.getParameter(gl.SHADING_LANGUAGE_VERSION)})`,
    maxTextureSize: renderer.capabilities.maxTextureSize,
    antialias,
    cores: navigator.hardwareConcurrency,
    deviceMemory: navigator.deviceMemory,
    platform: mobile == null ? uaPlatform : `${uaPlatform}${mobile ? ', мобильное' : ''}`,
    touch: navigator.maxTouchPoints > 0 ? `да (${navigator.maxTouchPoints} кас.)` : 'нет',
    connection: conn?.effectiveType
      ? `${conn.effectiveType}${conn.downlink ? `, ~${conn.downlink} Мбит/с` : ''}`
      : null,
  };
}

// ------------------------------------------------------------- state / UI

const state = {
  ready: false,
  spawns: [],
  spawnIndex: 0,
  lightmap: true,
  wireframe: false,
  materials: null,
  overlay: null,
  load: null,
  firstFrame: false,
};
window.viewer = { renderer, scene, camera, fly, state };

const spawnSelect = $('spawn-select');
const btnLightmap = $('btn-lightmap');
const btnWire = $('btn-wire');
const btnOverlay = $('btn-overlay');

function goToSpawn(i) {
  const s = state.spawns[i];
  if (!s) return;
  state.spawnIndex = i;
  spawnSelect.value = String(i);
  fly.setPose(s.eye, s.yaw, 0);
}
window.viewer.goToSpawn = goToSpawn;

function toggleOverlay() {
  if (!state.overlay) return;
  state.overlay.toggle();
  btnOverlay.classList.toggle('on', state.overlay.visible);
}

fly.onAction = (name, arg) => {
  if (name === 'spawn') goToSpawn(state.spawnIndex);
  else if (name === 'spawnIndex') goToSpawn(arg);
  else if (name === 'overlay') toggleOverlay();
};

$('btn-spawn').addEventListener('click', () => goToSpawn(state.spawnIndex));
spawnSelect.addEventListener('change', () => {
  goToSpawn(Number(spawnSelect.value));
  spawnSelect.blur();
});
btnLightmap.addEventListener('click', () => {
  state.lightmap = !state.lightmap;
  state.materials?.setLightmap(state.lightmap);
  btnLightmap.classList.toggle('on', state.lightmap);
});
btnWire.addEventListener('click', () => {
  state.wireframe = !state.wireframe;
  state.materials?.setWireframe(state.wireframe);
  btnWire.classList.toggle('on', state.wireframe);
});
btnOverlay.addEventListener('click', toggleOverlay);

// ------------------------------------------------------------- skybox

async function loadSky(url) {
  try {
    const tex = await new THREE.TextureLoader().loadAsync(url);
    tex.mapping = THREE.EquirectangularReflectionMapping;
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.generateMipmaps = false;
    tex.minFilter = THREE.LinearFilter;
    tex.name = 'skybox';
    scene.background = tex;
    return tex;
  } catch (err) {
    console.error('Skybox failed to load:', url, err);
    return null;
  }
}

// three converts an equirect background into a cube render target of size height / 2.
function skyStats(tex) {
  const { width: w, height: h } = tex.image;
  const face = h / 2;
  return { name: 'skybox (equirect + cube)', w, h, bytes: w * h * 4 + 6 * face * face * 4 * (4 / 3), isLightmap: false };
}

// ------------------------------------------------------------- main

async function init() {
  const statsPromise = loadStats(statsUrl);
  const skyPromise = loadSky(skyUrl);
  const dl = await download(mapUrl);

  loadFill.style.width = '100%';
  loadText.textContent = 'Разбор карты и декодирование текстур…';
  const tParse = performance.now();
  const loader = new GLTFLoader();
  const gltf = await loader.parseAsync(dl.buffer, THREE.LoaderUtils.extractUrlBase(mapUrl));
  const parseMs = performance.now() - tParse;

  const root = gltf.scene;
  const materials = convertMaterials(root, renderer);
  state.materials = materials;

  // Static map: bake matrices once, skip per-frame recomputation.
  root.updateMatrixWorld(true);
  root.traverse((obj) => {
    obj.matrixAutoUpdate = false;
  });
  scene.add(root);

  state.spawns = collectSpawns(root);
  spawnSelect.replaceChildren(
    ...state.spawns.map((s, i) => {
      const o = document.createElement('option');
      o.value = String(i);
      o.textContent = i < 9 ? `${i + 1}: ${s.label}` : s.label;
      return o;
    }),
  );
  if (state.spawns.length) goToSpawn(0);
  else fly.setPose(new THREE.Vector3(0, 2, 0), 0, 0);

  const sky = await skyPromise;
  const sceneStats = computeSceneStats(root, [materials.pairs.map((p) => p.lit)], sky ? [skyStats(sky)] : []);
  state.load = { url: mapUrl, bytes: dl.bytes, downloadMs: dl.ms, parseMs, firstFrameMs: NaN };

  state.overlay = new DebugOverlay({
    root: overlayRoot,
    renderer,
    fly,
    gpuTimer,
    pixelRatio: {
      options: pixelRatioOptions,
      current: pixelRatioChoice,
      onChange(v) {
        pixelRatioChoice = v;
        localStorage.setItem(PIXEL_RATIO_KEY, v);
        resize();
      },
    },
  });
  window.viewer.overlay = state.overlay;
  state.overlay.setStatic({ device: deviceInfo(), scene: sceneStats, build: await statsPromise, load: state.load });

  renderer.compile(scene, camera);
  resize();
  $('loading').classList.add('done');
  state.ready = true;
  lastTime = performance.now();
}

let lastTime = performance.now();
let gpuResolved = 0;

function frame(time) {
  if (!state.ready) return;
  // `time` is the rAF frame timestamp (vsync-aligned, less jitter than now()).
  const now = time;
  const dtMs = now - lastTime;
  lastTime = now;

  const gpuMs = gpuTimer.poll();
  const newGpu = gpuTimer.resolvedCount !== gpuResolved;
  gpuResolved = gpuTimer.resolvedCount;

  const t0 = performance.now();
  fly.update(dtMs / 1000);
  gpuTimer.begin();
  renderer.render(scene, camera);
  gpuTimer.end();
  const cpuMs = performance.now() - t0;

  if (!state.firstFrame) {
    // First frame: its dt contains loading time, keep it out of the stats.
    state.firstFrame = true;
    state.load.firstFrameMs = performance.now();
    state.overlay.setLoad(state.load);
    return;
  }
  state.overlay.frame(now, dtMs, cpuMs, newGpu ? gpuMs : NaN);
}

renderer.setAnimationLoop(frame);

init().catch((err) => {
  console.error(err);
  $('loading').classList.add('done');
  const box = $('error');
  box.hidden = false;
  box.textContent = `Не удалось загрузить карту «${mapUrl}».\n${err?.message || err}`;
});
