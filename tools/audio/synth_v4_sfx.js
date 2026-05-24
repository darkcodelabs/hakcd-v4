'use strict';

// HAKCD v4 bespoke SFX synth — 14 sounds for the foundation rewrite sprint.
// Pure Node, no external deps. Uses ./sfx_synth.js _internals only.
//
// Outputs mono 22050 Hz 16-bit PCM WAVs into source/sounds/sfx/.
// Reproducer:
//   node tools/audio/synth_v4_sfx.js
//
// Hash-URL parity (sfxr.me): NOT pulled from sfxr.me — we synthesize locally
// the same way v0.0.3 did. See docs/sfx_manifest.md for parameter table.

const path = require('path');
const fs = require('fs');
const sfx = require('./sfx_synth');
const { writeWav, envelope, squareWave, noise } = sfx._internals;
const SR = sfx.SAMPLE_RATE; // 22050

const OUT = path.resolve(__dirname, '../../source/sounds/sfx');

// ---------- Local DSP helpers (small + dependency-free) ----------

function lin(n, from, to) {
  const a = new Float32Array(n);
  const step = (to - from) / (n - 1 || 1);
  for (let i = 0; i < n; i++) a[i] = from + step * i;
  return a;
}

function exp_(n, k) {
  const a = new Float32Array(n);
  for (let i = 0; i < n; i++) a[i] = Math.exp(-(i / (n - 1)) * k);
  return a;
}

function mul(a, b) {
  const o = new Float32Array(a.length);
  for (let i = 0; i < a.length; i++) o[i] = a[i] * b[i];
  return o;
}

function mix(...arrs) {
  const n = Math.max(...arrs.map((a) => a.length));
  const o = new Float32Array(n);
  for (const a of arrs) for (let i = 0; i < a.length; i++) o[i] += a[i];
  for (let i = 0; i < n; i++) o[i] /= arrs.length;
  return o;
}

function scale(a, s) {
  const o = new Float32Array(a.length);
  for (let i = 0; i < a.length; i++) o[i] = a[i] * s;
  return o;
}

function concat(...arrs) {
  const total = arrs.reduce((s, a) => s + a.length, 0);
  const o = new Float32Array(total);
  let off = 0;
  for (const a of arrs) { o.set(a, off); off += a.length; }
  return o;
}

// Sine wave from per-sample frequency
function sine(freqs) {
  const n = freqs.length;
  const o = new Float32Array(n);
  let phase = 0;
  const dt = 1 / SR;
  for (let i = 0; i < n; i++) {
    phase += freqs[i] * dt;
    o[i] = Math.sin(2 * Math.PI * phase);
  }
  return o;
}

// One-pole low-pass for shaping noise character
function lowpass(a, alpha) {
  const o = new Float32Array(a.length);
  let prev = 0;
  for (let i = 0; i < a.length; i++) {
    prev = prev + alpha * (a[i] - prev);
    o[i] = prev;
  }
  return o;
}

// =========================================================================
// LOCKPICK FAMILY
// =========================================================================

// Shared pin-click body. Variant params shift pitch/amp for the 4 variants.
function pinClickVariant({ pitchMul = 1.0, ampMul = 1.0, lpAlpha = 0.35 } = {}) {
  const dur = 0.03;                       // 30 ms
  const n = Math.floor(SR * dur);
  // base = noise burst lightly tinted toward "brass" via mild low-pass
  // (alpha higher = brighter; lpAlpha~0.35 keeps a metallic edge).
  let body = noise(n);
  body = lowpass(body, lpAlpha);
  // Reapply expDecay(14) per spec for the sharp click envelope.
  const env = exp_(n, 14);
  // Pitch shift: resample by stride. pitchMul > 1 = higher pitch (shorter look),
  // pitchMul < 1 = lower pitch. We just stretch/compress the index lookup;
  // the duration stays ~30ms because we keep n constant and read with wrap.
  if (pitchMul !== 1.0) {
    const shifted = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const src = Math.min(n - 1, Math.floor(i * pitchMul));
      shifted[i] = body[src];
    }
    body = shifted;
  }
  return scale(mul(body, env), 0.85 * ampMul);
}

function lockpick_pin_click_1() {
  return pinClickVariant({ pitchMul: 1.00, ampMul: 1.00 });
}
function lockpick_pin_click_2() {
  // slight pitch shift DOWN (pitchMul < 1 reads slower => lower pitch)
  return pinClickVariant({ pitchMul: 0.85, ampMul: 1.00 });
}
function lockpick_pin_click_3() {
  // slight pitch shift UP
  return pinClickVariant({ pitchMul: 1.18, ampMul: 1.00 });
}
function lockpick_pin_click_4() {
  // louder + brighter (less low-pass = more high freq energy)
  return pinClickVariant({ pitchMul: 1.05, ampMul: 1.18, lpAlpha: 0.6 });
}

// lockpick_pin_set — 100ms confirmation chime, single tone falling 800->500 Hz
function lockpick_pin_set() {
  const dur = 0.1;
  const n = Math.floor(SR * dur);
  const freqs = lin(n, 800, 500);
  const sq = squareWave(freqs);
  const env = envelope(n, 0.03, 0.4);
  return scale(mul(sq, env), 0.75);
}

// lockpick_snap — 250ms harsh buzz, 200Hz square + heavy noise
function lockpick_snap() {
  const dur = 0.25;
  const n = Math.floor(SR * dur);
  const sq = squareWave(lin(n, 200, 160));
  const nz = noise(n);
  const m = mix(scale(sq, 0.6), scale(nz, 0.4));
  const env = envelope(n, 0.02, 0.3);
  return scale(mul(m, env), 0.9);
}

// lockpick_tension_warn — 400ms rising whine, square sweep 250 -> 1100 Hz
function lockpick_tension_warn() {
  const dur = 0.4;
  const n = Math.floor(SR * dur);
  const freqs = lin(n, 250, 1100);
  const sq = squareWave(freqs);
  const env = envelope(n, 0.05, 0.15);
  return scale(mul(sq, env), 0.7);
}

// lockpick_open — 500ms — 80ms low thud + 420ms 4-tone brass arpeggio.
function lockpick_open() {
  const thud_n = Math.floor(SR * 0.08);
  const thud = scale(mul(squareWave(lin(thud_n, 110, 60)), exp_(thud_n, 5)), 0.85);
  const tumble_n = Math.floor(SR * 0.42);
  const arp_freqs = [440, 554, 659, 880];
  const seg_n = Math.floor(tumble_n / arp_freqs.length);
  let tumble = new Float32Array(0);
  for (const f of arp_freqs) {
    const s = scale(
      mul(squareWave(lin(seg_n, f, f * 1.02)), exp_(seg_n, 6)),
      0.7
    );
    tumble = concat(tumble, s);
  }
  return concat(thud, tumble);
}

// =========================================================================
// TYSON FAMILY
// =========================================================================

// tyson_digit_select — 25ms soft tick, low-passed noise burst.
function tyson_digit_select() {
  const dur = 0.025;
  const n = Math.floor(SR * dur);
  const nz = lowpass(noise(n), 0.22);
  const env = exp_(n, 16);
  return scale(mul(nz, env), 0.55);
}

// tyson_digit_commit — 80ms confirm beep, square 850Hz
function tyson_digit_commit() {
  const dur = 0.08;
  const n = Math.floor(SR * dur);
  const sq = squareWave(lin(n, 850, 850));
  const env = envelope(n, 0.02, 0.5);
  return scale(mul(sq, env), 0.65);
}

// tyson_winner — 680ms Punch-Out WINNER homage.
//   C5(523)->E5(659)->G5(784)->C6(1047) ascending arpeggio
//   + sustained C5+E5+G5 triad tail
function tyson_winner() {
  const note_n = Math.floor(SR * 0.12);   // 120 ms per arp note
  const seq = [523, 659, 784, 1047];
  let out = new Float32Array(0);
  for (const f of seq) {
    const s = scale(
      mul(squareWave(lin(note_n, f, f)), envelope(note_n, 0.03, 0.25)),
      0.6
    );
    out = concat(out, s);
  }
  // Sustained C-E-G triad ~200ms — matches spec "sustained C-E-G triad"
  const sus_n = Math.floor(SR * 0.2);
  const c = squareWave(lin(sus_n, 523, 523));
  const e = squareWave(lin(sus_n, 659, 659));
  const g = squareWave(lin(sus_n, 784, 784));
  const chord = mix(c, e, g);
  out = concat(out, scale(mul(chord, envelope(sus_n, 0.02, 0.6)), 0.7));
  return out;
}

// =========================================================================
// COIN VAULT FAMILY
// =========================================================================

// coin_navigate_tick — 22ms soft click wheel tick
function coin_navigate_tick() {
  const n = Math.floor(SR * 0.022);
  const nz = lowpass(noise(n), 0.5);
  const env = exp_(n, 18);
  return scale(mul(nz, env), 0.55);
}

// coin_zoom_whoosh — 220ms short whoosh, band-passed noise sweep
function coin_zoom_whoosh() {
  const dur = 0.22;
  const n = Math.floor(SR * dur);
  const nz = noise(n);
  const lp = lowpass(nz, 0.18);
  const lp2 = lowpass(lp, 0.03);
  const band = new Float32Array(n);
  for (let i = 0; i < n; i++) band[i] = lp[i] - lp2[i];
  const env = envelope(n, 0.5, 0.4);
  return scale(mul(band, env), 0.8);
}

// coin_mint — 350ms sparkle chime: 200->2200Hz square sweep w/ envelope decay,
// brighter than tyson_winner.
function coin_mint() {
  const dur = 0.35;
  const n = Math.floor(SR * dur);
  const freqs = lin(n, 200, 2200);
  const sq = squareWave(freqs);
  // Sparkle: layer a higher-octave shimmer on top
  const shimmer = squareWave(lin(n, 400, 4400));
  const m = mix(scale(sq, 0.6), scale(shimmer, 0.4));
  const env = exp_(n, 4);
  return scale(mul(m, env), 0.8);
}

// =========================================================================
// PWNGLOVE BOOT
// =========================================================================

// pwnglove_boot — 500ms C major triad with slight rise 261->280 / 329->352 / 392->420
function pwnglove_boot() {
  const dur = 0.5;
  const n = Math.floor(SR * dur);
  const c = squareWave(lin(n, 261, 280));
  const e = squareWave(lin(n, 329, 352));
  const g = squareWave(lin(n, 392, 420));
  const chord = mix(c, e, g);
  const env = envelope(n, 0.05, 0.4);
  return scale(mul(chord, env), 0.75);
}

// =========================================================================
// Manifest + dispatch
// =========================================================================

const sounds = {
  'lockpick_pin_click_1.wav':   lockpick_pin_click_1(),
  'lockpick_pin_click_2.wav':   lockpick_pin_click_2(),
  'lockpick_pin_click_3.wav':   lockpick_pin_click_3(),
  'lockpick_pin_click_4.wav':   lockpick_pin_click_4(),
  'lockpick_pin_set.wav':       lockpick_pin_set(),
  'lockpick_snap.wav':          lockpick_snap(),
  'lockpick_tension_warn.wav':  lockpick_tension_warn(),
  'lockpick_open.wav':          lockpick_open(),
  'tyson_digit_select.wav':     tyson_digit_select(),
  'tyson_digit_commit.wav':     tyson_digit_commit(),
  'tyson_winner.wav':           tyson_winner(),
  'coin_navigate_tick.wav':     coin_navigate_tick(),
  'coin_zoom_whoosh.wav':       coin_zoom_whoosh(),
  'coin_mint.wav':              coin_mint(),
  'pwnglove_boot.wav':          pwnglove_boot(),
};

fs.mkdirSync(OUT, { recursive: true });

for (const [name, samples] of Object.entries(sounds)) {
  const dest = path.join(OUT, name);
  writeWav(dest, samples);
  const dur_ms = Math.round((samples.length / SR) * 1000);
  console.log(`${name.padEnd(32)} ${dur_ms.toString().padStart(4)}ms`);
}

console.log(`\nGenerated ${Object.keys(sounds).length} bespoke SFX into ${OUT}`);
