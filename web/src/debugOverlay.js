const WINDOW_MS = 5000; // statistics window
const CAPACITY = 4096; // ring buffer frames (enough for 5 s at >800 fps)
const UPDATE_MS = 250; // DOM refresh period (~4x/s)
const GRAPH_W = 240;
const GRAPH_H = 64;
const GRAPH_MAX_MS = 50;
const INCH = 0.0254;
const COMMON_HZ = [24, 30, 48, 50, 60, 72, 75, 90, 100, 120, 144, 165, 180, 240];
const RAD2DEG = 180 / Math.PI;

const MB = (bytes) => `${(bytes / 1048576).toFixed(2)} МБ`;
const KB = (bytes) => `${(bytes / 1024).toFixed(1)} КБ`;
const ms = (v, d = 2) => (Number.isFinite(v) ? `${v.toFixed(d)} мс` : '—');
const pct = (v) => (Number.isFinite(v) ? `${Math.round(v * 100)}%` : '—');
const num = (v) => (Number.isFinite(v) ? v.toLocaleString('ru-RU') : '—');

function snapRefresh(msValue) {
  const hz = 1000 / msValue;
  for (const h of COMMON_HZ) if (Math.abs(hz - h) / h < 0.06) return 1000 / h;
  return msValue;
}

/**
 * Performance / device / scene debug panel.
 * Hot path (`frame`) only writes into typed-array ring buffers and draws one
 * graph column; statistics and DOM are refreshed every UPDATE_MS.
 */
export class DebugOverlay {
  constructor({ root, renderer, fly, gpuTimer, pixelRatio }) {
    this.root = root;
    this.renderer = renderer;
    this.fly = fly;
    this.gpuTimer = gpuTimer;
    this.pixelRatio = pixelRatio; // { options: [{value,label}], current, onChange }

    this.dt = new Float32Array(CAPACITY);
    this.ts = new Float64Array(CAPACITY);
    this.cpu = new Float32Array(CAPACITY);
    this.gpu = new Float32Array(CAPACITY);
    this.scratch = new Float32Array(CAPACITY);
    this.head = 0;
    this.count = 0;
    this.lastUpdate = 0;
    this.framesSinceUpdate = 0;
    this.refreshMs = Infinity; // best (smallest) snapped refresh estimate
    this.longTasks = { count: 0, total: 0, last: 0, supported: false };

    this._build();
    this._observeLongTasks();
    this.setVisible(true);
    const mobile = matchMedia('(max-width: 700px), (pointer: coarse)').matches;
    this.setCollapsed(mobile);
  }

  // ------------------------------------------------------------------ DOM

  _build() {
    const r = this.root;
    r.innerHTML = '';

    const header = document.createElement('div');
    header.className = 'ov-header';
    const title = document.createElement('span');
    title.className = 'ov-title';
    title.textContent = 'Отладка';
    this.summary = document.createElement('span');
    this.summary.className = 'ov-summary';
    this.collapseBtn = document.createElement('button');
    this.collapseBtn.className = 'ov-collapse';
    this.collapseBtn.type = 'button';
    this.collapseBtn.addEventListener('click', () => this.setCollapsed(!this.collapsed));
    header.append(title, this.summary, this.collapseBtn);
    r.append(header);

    this.canvas = document.createElement('canvas');
    this.canvas.className = 'ov-graph';
    this.canvas.width = GRAPH_W;
    this.canvas.height = GRAPH_H;
    this.ctx = this.canvas.getContext('2d', { alpha: false });
    this.ctx.fillStyle = '#111';
    this.ctx.fillRect(0, 0, GRAPH_W, GRAPH_H);
    this.y16 = Math.round(GRAPH_H - (16.7 / GRAPH_MAX_MS) * GRAPH_H);
    this.y33 = Math.round(GRAPH_H - (33.3 / GRAPH_MAX_MS) * GRAPH_H);
    const legend = document.createElement('div');
    legend.className = 'ov-legend';
    legend.innerHTML =
      'Время кадра, 0–50 мс; линии: 16.7 / 33.3 мс. ' +
      '<i class="c-cpu">■</i> CPU <i class="c-gpu">■</i> GPU';
    this.verdictEl = document.createElement('div');
    this.verdictEl.className = 'ov-verdict';
    this.verdictReason = document.createElement('div');
    this.verdictReason.className = 'ov-reason';
    r.append(this.canvas, legend, this.verdictEl, this.verdictReason);

    this.body = document.createElement('div');
    this.body.className = 'ov-body';
    r.append(this.body);

    const s = (title) => this._section(title);
    let sec = s('Кадры (окно 5 с)');
    this.el = {};
    const row = (key, label) => { this.el[key] = this._row(sec, label); };
    row('fps', 'FPS сейчас / сред.');
    row('fpsMinMax', 'FPS мин / макс');
    row('low1', '1% low FPS');
    row('ftAvg', 'Кадр сред./p99/худш., мс');
    row('refresh', 'Частота экрана (оценка)');
    row('frames', 'Кадров в окне');

    sec = s('Нагрузка');
    row('cpu', 'CPU: update + render()');
    row('cpuMax', 'CPU макс');
    row('gpu', 'GPU кадра');
    row('cpuLoad', 'Загрузка CPU от бюджета');
    row('gpuLoad', 'Загрузка GPU от бюджета');
    row('gpuInfo', 'GPU-таймер');

    sec = s('renderer.info');
    row('calls', 'Draw calls');
    row('tris', 'Треугольники');
    row('pointsLines', 'Точки / линии');
    row('memGeo', 'Геометрии / текстуры');
    row('programs', 'Шейдерные программы');

    this.sceneSec = s('Сцена');
    this.buildSec = s('Сборка карты (stats.json)');

    sec = s('Память');
    row('heap', 'JS heap исп. / всего');
    row('heapLimit', 'JS heap лимит');
    row('longTasks', 'Long tasks (>50 мс)');

    this.deviceSec = s('Устройство / GPU');
    sec = this.deviceSec;
    row('pr', 'Pixel ratio (применён / DPR)');
    row('buffer', 'Буфер кадра');
    row('css', 'Размер CSS');
    row('mpix', 'Мпикс за кадр');

    this.loadSec = s('Загрузка');

    sec = s('Камера');
    row('posM', 'Позиция, м');
    row('posU', 'Позиция, GoldSrc');
    row('angles', 'Рыскание / тангаж');
    row('speed', 'Скорость');
    row('baseSpeed', 'Базовая скорость (колесо)');

    sec = s('Качество');
    const label = document.createElement('label');
    label.className = 'row';
    const k = document.createElement('span');
    k.className = 'k';
    k.textContent = 'Масштаб рендера (pixel ratio)';
    const select = document.createElement('select');
    for (const opt of this.pixelRatio.options) {
      const o = document.createElement('option');
      o.value = opt.value;
      o.textContent = opt.label;
      select.append(o);
    }
    select.value = this.pixelRatio.current;
    select.addEventListener('change', () => this.pixelRatio.onChange(select.value));
    label.append(k, select);
    sec.append(label);
  }

  _section(title) {
    const d = document.createElement('details');
    d.className = 'ov-sec';
    d.open = true;
    const sum = document.createElement('summary');
    sum.textContent = title;
    d.append(sum);
    this.body.append(d);
    return d;
  }

  _row(section, label) {
    const row = document.createElement('div');
    row.className = 'row';
    const k = document.createElement('span');
    k.className = 'k';
    k.textContent = label;
    const v = document.createElement('span');
    v.className = 'v';
    row.append(k, v);
    section.append(row);
    return v;
  }

  _staticRows(section, pairs) {
    for (const [label, value] of pairs) this._row(section, label).textContent = value;
  }

  _set(key, text) {
    const el = this.el[key];
    if (el._t !== text) {
      el._t = text;
      el.textContent = text;
    }
  }

  setVisible(v) {
    this.visible = v;
    this.root.hidden = !v;
  }

  toggle() {
    this.setVisible(!this.visible);
  }

  setCollapsed(c) {
    this.collapsed = c;
    this.root.classList.toggle('collapsed', c);
    this.collapseBtn.textContent = c ? 'Подробнее ▸' : 'Свернуть ▾';
  }

  _observeLongTasks() {
    try {
      if (!PerformanceObserver.supportedEntryTypes?.includes('longtask')) return;
      const obs = new PerformanceObserver((list) => {
        for (const e of list.getEntries()) {
          this.longTasks.count++;
          this.longTasks.total += e.duration;
          this.longTasks.last = e.duration;
        }
      });
      obs.observe({ type: 'longtask', buffered: true });
      this.longTasks.supported = true;
    } catch {
      this.longTasks.supported = false;
    }
  }

  // ------------------------------------------------------ static sections

  /** Called once after load. */
  setStatic({ device, scene, build, load }) {
    this._staticRows(this.deviceSec, [
      ['GPU (renderer)', device.gpuRenderer],
      ['GPU (vendor)', device.gpuVendor],
      ['WebGL', device.webgl],
      ['MAX_TEXTURE_SIZE', String(device.maxTextureSize)],
      ['Антиалиасинг', device.antialias ? 'вкл' : 'выкл'],
      ['Ядер CPU', device.cores ?? 'недоступно'],
      ['Память устройства', device.deviceMemory != null ? `${device.deviceMemory} ГБ` : 'недоступно'],
      ['Платформа', device.platform],
      ['Сенсорный ввод', device.touch],
      ['Сеть', device.connection ?? 'недоступно'],
    ]);

    this._staticRows(this.sceneSec, [
      ['Меши (примитивы)', num(scene.primitives)],
      ['Материалы', num(scene.materials)],
      ['Вершины', num(scene.vertices)],
      ['Треугольники', num(scene.triangles)],
      ['Геометрия в GPU (оценка)', MB(scene.geometryBytes)],
      ['Текстуры в GPU (оценка)', `${MB(scene.textureBytes)} (${scene.textureCount} шт.)`],
      ['из них карта освещения', MB(scene.lightmapBytes)],
      ['Итого GPU (оценка)', MB(scene.geometryBytes + scene.textureBytes)],
      ['Крупнейшие текстуры', scene.textureList.slice(0, 3).map((t) => `${t.name} ${t.w}×${t.h}`).join(', ')],
    ]);

    if (build) {
      const objs = Object.entries(build.objects || {});
      const rows = [
        ['Карта', build.map],
        ['Граней в BSP / отрисовано', `${num(build.source_faces)} / ${num(build.rendered_faces)}`],
      ];
      for (const [name, o] of objs) {
        rows.push([name, `${num(o.triangles)} тр., ${num(o.verts_after_weld)} верш. (до сварки ${num(o.verts_before_weld)}), ${o.materials} мат.`]);
      }
      if (build.lightmap_atlas) rows.push(['Атлас освещения', build.lightmap_atlas.join('×')]);
      rows.push(['Текстур / материалов', `${build.textures} / ${build.materials}`]);
      for (const [file, size] of Object.entries(build.exports || {})) rows.push([file, KB(size)]);
      if (build.build_seconds != null) rows.push(['Время сборки', `${build.build_seconds} с`]);
      this._staticRows(this.buildSec, rows);
    } else {
      this._staticRows(this.buildSec, [['stats.json', 'недоступно']]);
    }

    this.loadRows = {};
    this.loadRows.size = this._row(this.loadSec, 'Размер GLB');
    this.loadRows.download = this._row(this.loadSec, 'Скачивание');
    this.loadRows.parse = this._row(this.loadSec, 'Разбор (parse)');
    this.loadRows.first = this._row(this.loadSec, 'Первый кадр (от старта)');
    this.setLoad(load);
  }

  setLoad(load) {
    if (!this.loadRows) return;
    this.loadRows.size.textContent = `${KB(load.bytes)} (${load.url})`;
    this.loadRows.download.textContent = ms(load.downloadMs, 0);
    this.loadRows.parse.textContent = ms(load.parseMs, 0);
    this.loadRows.first.textContent = ms(load.firstFrameMs, 0);
  }

  // ------------------------------------------------------------ per frame

  /**
   * @param {number} now performance.now()
   * @param {number} dtMs time since previous frame
   * @param {number} cpuMs CPU time of update + render()
   * @param {number} gpuMs newly resolved GPU time, NaN if none this frame
   */
  frame(now, dtMs, cpuMs, gpuMs) {
    const i = this.head;
    this.dt[i] = dtMs;
    this.ts[i] = now;
    this.cpu[i] = cpuMs;
    this.gpu[i] = gpuMs;
    this.head = (i + 1) % CAPACITY;
    if (this.count < CAPACITY) this.count++;
    this.framesSinceUpdate++;

    if (!this.visible) {
      if (now - this.lastUpdate >= UPDATE_MS) this._resetTick(now);
      return;
    }
    this._drawGraph(dtMs, cpuMs, gpuMs);
    if (now - this.lastUpdate >= UPDATE_MS) this._update(now);
  }

  _resetTick(now) {
    this.lastUpdate = now;
    this.framesSinceUpdate = 0;
  }

  _drawGraph(dtMs, cpuMs, gpuMs) {
    const ctx = this.ctx;
    const x = GRAPH_W - 1;
    ctx.drawImage(this.canvas, -1, 0);
    ctx.fillStyle = '#111';
    ctx.fillRect(x, 0, 1, GRAPH_H);
    const scale = GRAPH_H / GRAPH_MAX_MS;
    const h = Math.min(GRAPH_H, dtMs * scale);
    ctx.fillStyle = dtMs <= 17.5 ? '#3c3' : dtMs <= 34 ? '#dc3' : '#e33';
    ctx.fillRect(x, GRAPH_H - h, 1, h);
    const hc = Math.min(GRAPH_H, cpuMs * scale);
    ctx.fillStyle = '#39f';
    ctx.fillRect(x, GRAPH_H - hc, 1, hc);
    if (gpuMs === gpuMs) {
      const hg = Math.min(GRAPH_H - 1, gpuMs * scale);
      ctx.fillStyle = '#f5d';
      ctx.fillRect(x, GRAPH_H - 1 - hg, 1, 2);
    }
    ctx.fillStyle = '#888';
    ctx.fillRect(x, this.y16, 1, 1);
    ctx.fillRect(x, this.y33, 1, 1);
  }

  _update(now) {
    const elapsed = now - this.lastUpdate;
    const fpsNow = (this.framesSinceUpdate * 1000) / elapsed;
    this._resetTick(now);

    // Gather window samples (newest backwards).
    const from = now - WINDOW_MS;
    let n = 0;
    let sumDt = 0;
    let sumCpu = 0;
    let maxCpu = 0;
    let sumGpu = 0;
    let nGpu = 0;
    for (let k = 0, idx = this.head; k < this.count; k++) {
      idx = idx === 0 ? CAPACITY - 1 : idx - 1;
      if (this.ts[idx] < from) break;
      const d = this.dt[idx];
      this.scratch[n++] = d;
      sumDt += d;
      const c = this.cpu[idx];
      sumCpu += c;
      if (c > maxCpu) maxCpu = c;
      const g = this.gpu[idx];
      if (g === g) {
        sumGpu += g;
        nGpu++;
      }
    }
    if (n === 0) return;
    const sorted = this.scratch.subarray(0, n).sort();
    const minDt = sorted[0];
    const maxDt = sorted[n - 1];
    const p99 = sorted[Math.floor(0.99 * (n - 1))];
    const p10 = sorted[Math.floor(0.1 * (n - 1))];
    const worstCount = Math.max(1, Math.ceil(n * 0.01));
    let worstSum = 0;
    for (let k = n - worstCount; k < n; k++) worstSum += sorted[k];
    const low1 = 1000 / (worstSum / worstCount);
    const avgDt = sumDt / n;
    const avgFps = 1000 / avgDt;
    const cpuAvg = sumCpu / n;
    const gpuAvg = nGpu ? sumGpu / nGpu : NaN;

    if (n >= 30) this.refreshMs = Math.min(this.refreshMs, snapRefresh(p10));
    const budget = Number.isFinite(this.refreshMs) ? this.refreshMs : 1000 / 60;
    const refreshHz = 1000 / budget;
    const cpuLoad = cpuAvg / budget;
    const gpuLoad = gpuAvg / budget;

    this._set('fps', `${fpsNow.toFixed(0)} / ${avgFps.toFixed(1)}`);
    this._set('fpsMinMax', `${(1000 / maxDt).toFixed(1)} / ${(1000 / minDt).toFixed(1)}`);
    this._set('low1', low1.toFixed(1));
    this._set('ftAvg', `${avgDt.toFixed(2)} / ${p99.toFixed(2)} / ${maxDt.toFixed(2)}`);
    this._set('refresh', `${refreshHz.toFixed(0)} Гц → бюджет ${budget.toFixed(2)} мс`);
    this._set('frames', String(n));

    this._set('cpu', ms(cpuAvg));
    this._set('cpuMax', ms(maxCpu));
    const gt = this.gpuTimer;
    if (!gt.supported) {
      this._set('gpu', 'недоступно');
      this._set('gpuLoad', 'недоступно');
      this._set('gpuInfo', gt.isWebGL2 ? 'нет EXT_disjoint_timer_query_webgl2' : 'нет WebGL2');
    } else {
      this._set('gpu', Number.isFinite(gpuAvg) ? ms(gpuAvg) : '…');
      this._set('gpuLoad', pct(gpuLoad));
      this._set('gpuInfo', `запросов ${gt.resolvedCount}, disjoint ${gt.disjointCount}, пропущено ${gt.droppedCount}`);
    }
    this._set('cpuLoad', pct(cpuLoad));

    // renderer.info reflects the last render() call (autoReset).
    const info = this.renderer.info;
    this._set('calls', num(info.render.calls));
    this._set('tris', num(info.render.triangles));
    this._set('pointsLines', `${info.render.points} / ${info.render.lines}`);
    this._set('memGeo', `${info.memory.geometries} / ${info.memory.textures}`);
    this._set('programs', String(info.programs ? info.programs.length : 0));

    const mem = performance.memory;
    if (mem) {
      this._set('heap', `${MB(mem.usedJSHeapSize)} / ${MB(mem.totalJSHeapSize)}`);
      this._set('heapLimit', MB(mem.jsHeapSizeLimit));
    } else {
      this._set('heap', 'недоступно');
      this._set('heapLimit', 'недоступно');
    }
    const lt = this.longTasks;
    this._set('longTasks', lt.supported
      ? `${lt.count} шт., всего ${lt.total.toFixed(0)} мс, посл. ${lt.last.toFixed(0)} мс`
      : 'недоступно');

    const canvas = this.renderer.domElement;
    const pr = this.renderer.getPixelRatio();
    const mpix = (canvas.width * canvas.height) / 1e6;
    this._set('pr', `${pr.toFixed(2)} / ${devicePixelRatio.toFixed(2)}`);
    this._set('buffer', `${canvas.width}×${canvas.height}`);
    this._set('css', `${canvas.clientWidth}×${canvas.clientHeight}`);
    this._set('mpix', `${mpix.toFixed(2)} (${(mpix * avgFps).toFixed(0)} Мпикс/с)`);

    const p = this.fly.camera.position;
    this._set('posM', `${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}`);
    this._set('posU', `${(p.x / INCH).toFixed(0)}, ${(-p.z / INCH).toFixed(0)}, ${(p.y / INCH).toFixed(0)}`);
    this._set('angles', `${(this.fly.yaw * RAD2DEG).toFixed(1)}° / ${(this.fly.pitch * RAD2DEG).toFixed(1)}°`);
    const sp = this.fly.currentSpeed;
    this._set('speed', `${sp.toFixed(2)} м/с (${(sp / INCH).toFixed(0)} ед/с)`);
    const bs = this.fly.baseSpeed;
    this._set('baseSpeed', `${bs.toFixed(2)} м/с (${(bs / INCH).toFixed(0)} ед/с)`);

    this._verdict({ avgFps, refreshHz, low1, p99, maxDt, budget, cpuAvg, avgDt, cpuLoad, gpuLoad, mpix, pr, calls: info.render.calls, tris: info.render.triangles });

    const summary = `${fpsNow.toFixed(0)} FPS · ${avgDt.toFixed(1)} мс · ${this.verdictLevel}`;
    if (this.summary._t !== summary) {
      this.summary._t = summary;
      this.summary.textContent = summary;
    }
  }

  _verdict(m) {
    const gpuKnown = Number.isFinite(m.gpuLoad);
    const dominant = Math.max(m.cpuLoad, gpuKnown ? m.gpuLoad : 0);
    const missesVsync = m.avgFps < 0.95 * m.refreshHz;

    let level;
    let cls;
    // Level reflects sustained load; isolated hitches only lower it to "medium".
    if (m.avgFps < 0.8 * m.refreshHz || dominant > 0.85) {
      level = 'Тяжёлая нагрузка';
      cls = 'heavy';
    } else if (dominant > 0.5 || missesVsync || m.low1 < 0.5 * m.refreshHz || m.p99 > 2 * m.budget) {
      level = 'Средняя нагрузка';
      cls = 'medium';
    } else {
      level = 'Лёгкая нагрузка';
      cls = 'light';
    }

    let reason;
    const fill = `${m.mpix.toFixed(2)} Мпикс/кадр при pixel ratio ${m.pr.toFixed(2)}`;
    const lightGeometry = m.tris < 300000;
    if (gpuKnown && m.gpuLoad >= m.cpuLoad && m.gpuLoad > 0.5) {
      reason = lightGeometry
        ? `Узкое место — GPU, заполнение пикселей (fill-rate): ${fill}, геометрия лёгкая (${num(m.tris)} тр.). Уменьшите масштаб рендера.`
        : `Узкое место — GPU: много геометрии (${num(m.tris)} тр.) и ${fill}.`;
    } else if (m.cpuLoad > 0.5 && (!gpuKnown || m.cpuLoad > m.gpuLoad)) {
      reason = `Узкое место — CPU: обновление и render() занимают ${m.cpuAvg.toFixed(2)} мс (${m.calls} draw calls).`;
    } else if (missesVsync && !gpuKnown && m.cpuAvg < 0.6 * m.avgDt) {
      reason = `Кадр ${m.avgDt.toFixed(1)} мс при CPU ${m.cpuAvg.toFixed(2)} мс: вероятно, упор в GPU / fill-rate (${fill}). GPU-таймер недоступен. Попробуйте уменьшить масштаб рендера.`;
    } else if (missesVsync) {
      reason = 'CPU и GPU загружены слабо, но кадры пропускаются: сборка мусора, длинные задачи, фоновая вкладка или троттлинг браузера.';
    } else {
      reason = `Запас есть: частота упирается в vsync (${m.refreshHz.toFixed(0)} Гц), загрузка CPU ${Math.round(m.cpuLoad * 100)}%` +
        (gpuKnown ? `, GPU ${Math.round(m.gpuLoad * 100)}%.` : ', GPU — нет данных.');
    }
    if (m.maxDt > 3 * m.budget) reason += ` Есть фризы: худший кадр ${m.maxDt.toFixed(0)} мс.`;

    this.verdictLevel = level;
    if (this.verdictEl._t !== level) {
      this.verdictEl._t = level;
      this.verdictEl.textContent = level;
      this.verdictEl.className = `ov-verdict ${cls}`;
    }
    if (this.verdictReason._t !== reason) {
      this.verdictReason._t = reason;
      this.verdictReason.textContent = reason;
    }
  }
}
