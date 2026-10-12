/**
 * Async GPU frame timing via EXT_disjoint_timer_query_webgl2.
 * Queries come from a fixed pool; results are polled on later frames,
 * so the CPU never stalls. Disjoint events discard in-flight results.
 */
const POOL_SIZE = 8;

export class GpuTimer {
  constructor(gl) {
    this.gl = gl;
    this.isWebGL2 = typeof WebGL2RenderingContext !== 'undefined' && gl instanceof WebGL2RenderingContext;
    this.ext = this.isWebGL2 ? gl.getExtension('EXT_disjoint_timer_query_webgl2') : null;
    this.supported = !!this.ext;
    this.lastMs = NaN; // most recent resolved GPU time
    this.disjointCount = 0;
    this.resolvedCount = 0;
    this.droppedCount = 0; // frames not measured because the pool was full
    this.free = [];
    this.pending = []; // FIFO, queries finish in submission order
    this.active = null;
    if (this.supported) {
      for (let i = 0; i < POOL_SIZE; i++) this.free.push(gl.createQuery());
    }
  }

  begin() {
    if (!this.supported || this.active) return;
    const q = this.free.pop();
    if (!q) {
      this.droppedCount++;
      return;
    }
    this.gl.beginQuery(this.ext.TIME_ELAPSED_EXT, q);
    this.active = q;
  }

  end() {
    if (!this.active) return;
    this.gl.endQuery(this.ext.TIME_ELAPSED_EXT);
    this.pending.push(this.active);
    this.active = null;
  }

  /** Call once per frame (before begin). Returns the newest GPU ms or NaN. */
  poll() {
    if (!this.supported) return NaN;
    const gl = this.gl;
    const disjoint = gl.getParameter(this.ext.GPU_DISJOINT_EXT);
    if (disjoint) {
      // All in-flight results are unreliable: recycle them.
      this.disjointCount++;
      while (this.pending.length) this.free.push(this.pending.shift());
      return this.lastMs;
    }
    while (this.pending.length) {
      const q = this.pending[0];
      if (!gl.getQueryParameter(q, gl.QUERY_RESULT_AVAILABLE)) break;
      const ns = gl.getQueryParameter(q, gl.QUERY_RESULT);
      this.pending.shift();
      this.free.push(q);
      this.lastMs = ns / 1e6;
      this.resolvedCount++;
    }
    return this.lastMs;
  }
}
