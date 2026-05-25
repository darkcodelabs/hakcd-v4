'use strict';
// Synth 2 footstep SFX variants for HAKCD newb walking.
// Low thump, ~80ms each, 50-80Hz square + noise tail.

const path = require('path');
const sfx = path.resolve('/home/hakcer/projects/hakcd-v4/tools/audio/sfx_synth.js');
const { writeWav, envelope, squareWave, noise } = require(sfx)._internals;
const SR = require(sfx).SAMPLE_RATE;

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
function mix(a, b, wA, wB) {
  const o = new Float32Array(a.length);
  for (let i = 0; i < a.length; i++) o[i] = a[i] * wA + b[i] * wB;
  return o;
}
function scale(a, s) {
  const o = new Float32Array(a.length);
  for (let i = 0; i < a.length; i++) o[i] = a[i] * s;
  return o;
}

function step(thumpHz) {
  const n = Math.floor(SR * 0.07);
  const body = squareWave(lin(n, thumpHz, thumpHz * 0.6));
  const nz = noise(n);
  const mixed = mix(body, nz, 0.7, 0.3);
  const env = exp_(n, 9);
  return scale(mul(mixed, env), 0.55);
}

const OUT = '/home/hakcer/projects/hakcd-v4/source/sounds/sfx';
writeWav(`${OUT}/step_1.wav`, step(75));
writeWav(`${OUT}/step_2.wav`, step(65));
console.log('step_1.wav + step_2.wav written');
