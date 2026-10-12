import * as THREE from 'three';

const DEG = Math.PI / 180;
const PITCH_LIMIT = 89 * DEG;
const MOUSE_SENS = 0.0022; // rad per pixel of mouse movement
const TOUCH_LOOK_SENS = 0.005; // rad per CSS pixel of drag
const JOY_RADIUS = 60; // CSS px for full deflection
const ACCEL_RATE = 10; // 1/s, exponential approach to target velocity
const DECEL_RATE = 7; // 1/s, when there is no input
const MIN_SPEED = 0.5;
const MAX_SPEED = 120;
const WHEEL_STEP = 1.2;

const MOVE_KEYS = {
  KeyW: 'fwd', ArrowUp: 'fwd',
  KeyS: 'back', ArrowDown: 'back',
  KeyA: 'left', ArrowLeft: 'left',
  KeyD: 'right', ArrowRight: 'right',
  Space: 'up', KeyE: 'up',
  ControlLeft: 'down', ControlRight: 'down', KeyC: 'down', KeyQ: 'down',
  ShiftLeft: 'fast', ShiftRight: 'fast',
  AltLeft: 'slow', AltRight: 'slow',
};

/**
 * Free-fly camera: pointer-lock mouse look + WASD on desktop,
 * virtual joystick (left half) + drag look (right half) + ▲/▼ on touch.
 * `update(dt)` does not allocate.
 */
export class FlyCamera {
  /**
   * @param {THREE.PerspectiveCamera} camera
   * @param {HTMLElement} surface element receiving mouse/touch input (canvas)
   * @param {{ joystick: HTMLElement, knob: HTMLElement, up: HTMLElement, down: HTMLElement }} touchUi
   */
  constructor(camera, surface, touchUi) {
    this.camera = camera;
    this.surface = surface;
    this.ui = touchUi;
    camera.rotation.order = 'YXZ';

    this.yaw = 0;
    this.pitch = 0;
    this.baseSpeed = 6; // m/s (~236 GoldSrc units/s, close to CS run speed)
    this.velocity = new THREE.Vector3();
    this.currentSpeed = 0;
    this.enabled = true;
    this.onSpeedChange = null;
    this.onAction = null; // (name, arg) => void for 'spawn', 'spawnIndex', 'overlay'

    this.keys = { fwd: false, back: false, left: false, right: false, up: false, down: false, fast: false, slow: false };
    this.touchUp = false;
    this.touchDown = false;

    // Touch state
    this.joyId = -1;
    this.joyX0 = 0;
    this.joyY0 = 0;
    this.joyDX = 0; // -1..1
    this.joyDY = 0; // -1..1 (positive = forward)
    this.lookId = -1;
    this.lookX = 0;
    this.lookY = 0;

    // Mouse drag fallback when pointer lock is unavailable
    this.dragging = false;

    // Scratch objects (no allocation in update)
    this._fwd = new THREE.Vector3();
    this._right = new THREE.Vector3();
    this._target = new THREE.Vector3();

    this._bind();
  }

  get locked() {
    return document.pointerLockElement === this.surface;
  }

  setPose(position, yaw, pitch = 0) {
    this.camera.position.copy(position);
    this.yaw = yaw;
    this.pitch = pitch;
    this.velocity.set(0, 0, 0);
    this.currentSpeed = 0;
    this._applyRotation();
  }

  setBaseSpeed(v) {
    this.baseSpeed = Math.min(MAX_SPEED, Math.max(MIN_SPEED, v));
    if (this.onSpeedChange) this.onSpeedChange(this.baseSpeed);
  }

  _applyRotation() {
    this.camera.rotation.set(this.pitch, this.yaw, 0, 'YXZ');
  }

  _rotate(dx, dy, sens) {
    this.yaw -= dx * sens;
    this.pitch -= dy * sens;
    if (this.pitch > PITCH_LIMIT) this.pitch = PITCH_LIMIT;
    else if (this.pitch < -PITCH_LIMIT) this.pitch = -PITCH_LIMIT;
    this.yaw = THREE.MathUtils.euclideanModulo(this.yaw + Math.PI, Math.PI * 2) - Math.PI;
    this._applyRotation();
  }

  update(dt) {
    if (dt > 0.1) dt = 0.1; // avoid huge jumps after tab switches

    const k = this.keys;
    let inF = (k.fwd ? 1 : 0) - (k.back ? 1 : 0) + this.joyDY;
    let inR = (k.right ? 1 : 0) - (k.left ? 1 : 0) + this.joyDX;
    let inU = (k.up || this.touchUp ? 1 : 0) - (k.down || this.touchDown ? 1 : 0);
    const len = Math.hypot(inF, inR, inU);
    if (len > 1) {
      inF /= len;
      inR /= len;
      inU /= len;
    }

    let speed = this.baseSpeed;
    if (k.fast) speed *= 4;
    if (k.slow) speed *= 0.25;

    // Forward follows the full view direction (fly), right stays horizontal.
    const cp = Math.cos(this.pitch);
    this._fwd.set(-Math.sin(this.yaw) * cp, Math.sin(this.pitch), -Math.cos(this.yaw) * cp);
    this._right.set(Math.cos(this.yaw), 0, -Math.sin(this.yaw));

    const target = this._target
      .copy(this._fwd).multiplyScalar(inF)
      .addScaledVector(this._right, inR);
    target.y += inU;
    target.multiplyScalar(speed);

    const rate = len > 0 ? ACCEL_RATE : DECEL_RATE;
    const a = 1 - Math.exp(-rate * dt); // frame-rate independent damping
    this.velocity.lerp(target, a);
    if (len === 0 && this.velocity.lengthSq() < 1e-6) this.velocity.set(0, 0, 0);

    this.camera.position.addScaledVector(this.velocity, dt);
    this.currentSpeed = this.velocity.length();
  }

  // ---------------------------------------------------------------- input

  _bind() {
    const s = this.surface;
    const opts = { passive: false };

    // Keyboard (event.code: layout-independent, works with Russian layout)
    window.addEventListener('keydown', (e) => this._onKey(e, true));
    window.addEventListener('keyup', (e) => this._onKey(e, false));
    window.addEventListener('blur', () => this._releaseAll());
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) this._releaseAll();
    });

    // Mouse
    s.addEventListener('pointerdown', (e) => this._onPointerDown(e), opts);
    window.addEventListener('pointermove', (e) => this._onPointerMove(e), opts);
    window.addEventListener('pointerup', (e) => this._onPointerUp(e));
    window.addEventListener('pointercancel', (e) => this._onPointerUp(e));
    document.addEventListener('mousemove', (e) => {
      if (this.locked) this._rotate(e.movementX, e.movementY, MOUSE_SENS);
    });
    s.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.setBaseSpeed(this.baseSpeed * (e.deltaY < 0 ? WHEEL_STEP : 1 / WHEEL_STEP));
    }, opts);
    s.addEventListener('contextmenu', (e) => e.preventDefault());

    // Block page scroll / pinch-zoom / double-tap zoom on touch devices.
    const block = (e) => e.preventDefault();
    s.addEventListener('touchstart', block, opts);
    s.addEventListener('touchmove', block, opts);
    document.addEventListener('gesturestart', block, opts);
    document.addEventListener('dblclick', block, opts);

    // Vertical buttons
    this._holdButton(this.ui.up, (v) => { this.touchUp = v; });
    this._holdButton(this.ui.down, (v) => { this.touchDown = v; });
  }

  _holdButton(el, set) {
    const on = (e) => {
      e.preventDefault();
      el.setPointerCapture?.(e.pointerId);
      el.classList.add('active');
      set(true);
    };
    const off = () => {
      el.classList.remove('active');
      set(false);
    };
    el.addEventListener('pointerdown', on, { passive: false });
    el.addEventListener('pointerup', off);
    el.addEventListener('pointercancel', off);
    el.addEventListener('lostpointercapture', off);
    el.addEventListener('touchstart', (e) => e.preventDefault(), { passive: false });
  }

  _releaseAll() {
    for (const key in this.keys) this.keys[key] = false;
    this.touchUp = this.touchDown = false;
    this._endJoystick();
    this.lookId = -1;
    this.dragging = false;
  }

  _onKey(e, down) {
    const t = e.target;
    if (t && (t.tagName === 'INPUT' || t.tagName === 'SELECT' || t.tagName === 'TEXTAREA')) return;
    const action = MOVE_KEYS[e.code];
    if (action) {
      this.keys[action] = down;
      // Space scrolls, Alt opens browser menus, arrows scroll.
      e.preventDefault();
      return;
    }
    if (!down || e.repeat) return;
    if (e.code === 'KeyR') this.onAction?.('spawn');
    else if (e.code === 'F3') {
      e.preventDefault();
      this.onAction?.('overlay');
    } else if (e.code.startsWith('Digit')) {
      const n = e.code.charCodeAt(5) - 48;
      if (n >= 1 && n <= 9) this.onAction?.('spawnIndex', n - 1);
    }
  }

  _onPointerDown(e) {
    if (e.pointerType === 'mouse') {
      if (e.button !== 0) return;
      if (!this.locked && this.surface.requestPointerLock) {
        try {
          const p = this.surface.requestPointerLock();
          if (p && p.catch) p.catch(() => {}); // fall back to drag-look
        } catch {
          /* drag-look fallback */
        }
      }
      this.dragging = true;
      this.lookX = e.clientX;
      this.lookY = e.clientY;
      return;
    }
    // touch / pen
    e.preventDefault();
    const rect = this.surface.getBoundingClientRect();
    const leftHalf = e.clientX - rect.left < rect.width / 2;
    if (leftHalf && this.joyId === -1) {
      this.joyId = e.pointerId;
      this.joyX0 = e.clientX;
      this.joyY0 = e.clientY;
      this.joyDX = this.joyDY = 0;
      const j = this.ui.joystick;
      j.style.transform = `translate(${e.clientX}px, ${e.clientY}px)`;
      this.ui.knob.style.transform = 'translate(0px, 0px)';
      j.classList.add('visible');
    } else if (!leftHalf && this.lookId === -1) {
      this.lookId = e.pointerId;
      this.lookX = e.clientX;
      this.lookY = e.clientY;
    } else {
      return;
    }
    this.surface.setPointerCapture?.(e.pointerId);
  }

  _onPointerMove(e) {
    if (e.pointerType === 'mouse') {
      if (this.dragging && !this.locked && (e.buttons & 1)) {
        this._rotate(e.clientX - this.lookX, e.clientY - this.lookY, MOUSE_SENS);
      }
      this.lookX = e.clientX;
      this.lookY = e.clientY;
      return;
    }
    if (e.pointerId === this.joyId) {
      e.preventDefault();
      let dx = e.clientX - this.joyX0;
      let dy = e.clientY - this.joyY0;
      const d = Math.hypot(dx, dy);
      if (d > JOY_RADIUS) {
        dx *= JOY_RADIUS / d;
        dy *= JOY_RADIUS / d;
      }
      this.ui.knob.style.transform = `translate(${dx}px, ${dy}px)`;
      // Small dead zone, then linear response.
      const dead = 0.12;
      const nx = dx / JOY_RADIUS;
      const ny = -dy / JOY_RADIUS;
      this.joyDX = Math.abs(nx) < dead ? 0 : nx;
      this.joyDY = Math.abs(ny) < dead ? 0 : ny;
    } else if (e.pointerId === this.lookId) {
      e.preventDefault();
      this._rotate(e.clientX - this.lookX, e.clientY - this.lookY, TOUCH_LOOK_SENS);
      this.lookX = e.clientX;
      this.lookY = e.clientY;
    }
  }

  _onPointerUp(e) {
    if (e.pointerType === 'mouse') {
      this.dragging = false;
      return;
    }
    if (e.pointerId === this.joyId) this._endJoystick();
    else if (e.pointerId === this.lookId) this.lookId = -1;
  }

  _endJoystick() {
    this.joyId = -1;
    this.joyDX = this.joyDY = 0;
    this.ui.joystick.classList.remove('visible');
  }
}
