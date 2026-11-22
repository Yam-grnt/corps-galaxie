// Fabrique par programme tous les sons de l'application (aucune banque de sons) : cinq nappes en boucle, une par
// échelle, et les sons d'interaction. Usage : node outils/fabriquer-sons.js   → écrit godot/sons/*.wav
'use strict';
const fs = require('fs'), path = require('path');
const SR = 22050, TAU = Math.PI * 2;
const dossier = path.join(__dirname, '..', 'godot', 'sons');
fs.mkdirSync(dossier, { recursive: true });

// hasard reproductible : les sons sont identiques d'une fabrication à l'autre
let graine = 20261122;
const rnd = () => { graine = (Math.imul(graine, 1664525) + 1013904223) >>> 0; return graine / 4294967296; };

function ecrire(nom, s, gain = 1) {
  let max = 1e-9; for (const v of s) max = Math.max(max, Math.abs(v));
  const k = gain * 0.89 / max, b = Buffer.alloc(44 + s.length * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + s.length * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16);
  b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * 2, 28);
  b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(s.length * 2, 40);
  for (let i = 0; i < s.length; i++) b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s[i] * k)) * 32767), 44 + i * 2);
  fs.writeFileSync(path.join(dossier, nom + '.wav'), b);
  console.log(nom + '.wav', (s.length / SR).toFixed(2) + ' s');
}
// bruit filtré passe-bas, rendu bouclable par fondu de la fin dans le début
function bruit(n, coupure) {
  const a = 1 - Math.exp(-TAU * coupure / SR), fondu = Math.floor(SR * 0.6), brut = new Float64Array(n + fondu);
  let y1 = 0, y2 = 0;
  for (let i = 0; i < brut.length; i++) { y1 += a * (rnd() * 2 - 1 - y1); y2 += a * (y1 - y2); brut[i] = y2; }
  const s = new Float64Array(n);
  for (let i = 0; i < n; i++) s[i] = brut[i];
  for (let i = 0; i < fondu; i++) { const t = i / fondu; s[i] = brut[i] * t + brut[n + i] * (1 - t); }
  return s;
}
// ajoute une note dont la queue, si elle dépasse la fin, se replie au début : la boucle ne s'entend pas
function note(s, debut, duree, f) { const n = Math.floor(duree * SR), d = Math.floor(debut * SR); for (let i = 0; i < n; i++) s[(d + i) % s.length] += f(i / SR, i / n); }

// 0 — le corps : un bourdon grave, le souffle, et le cœur à 66 battements par minute (12 battements par boucle)
{ const L = 12 / 1.1, n = Math.round(L * SR), s = new Float64Array(n), souffle = bruit(n, 420);
  for (let i = 0; i < n; i++) { const t = i / SR;
    s[i] = 0.5 * Math.sin(TAU * 55 * t) + 0.3 * Math.sin(TAU * 82.5 * t) + 0.12 * Math.sin(TAU * 165 * t) * (0.6 + 0.4 * Math.sin(TAU * 3 * t / L));
    s[i] += 2.2 * souffle[i] * (0.5 - 0.5 * Math.cos(TAU * 3 * t / L)); }
  for (let b = 0; b < 12; b++) for (const [dt, g] of [[0, 1], [0.3, 0.7]])
    note(s, b / 1.1 + dt, 0.16, (t, u) => g * 0.9 * Math.sin(TAU * (45 * t + 35 * 0.06 * (1 - Math.exp(-t / 0.06)))) * Math.exp(-t / 0.045) * Math.min(1, t / 0.004));
  ecrire('nappe_0', s); }

// 1 — tissus et cellules : un milieu liquide, sourd, traversé de petites bulles
{ const L = 12, n = L * SR, s = bruit(n, 700);
  for (let i = 0; i < n; i++) s[i] *= 3 * (0.75 + 0.25 * Math.sin(TAU * 2 * i / n));
  for (let b = 0; b < 40; b++) { const f0 = 500 + rnd() * 500, g = 0.05 + rnd() * 0.08;
    note(s, rnd() * L, 0.05, (t, u) => g * Math.sin(TAU * (f0 * t + f0 * t * t / 0.1)) * Math.sin(Math.PI * u)); }
  ecrire('nappe_1', s, 0.8); }

// 2 — organites et protéines : de rares cloches, comme des mécanismes qui s'enclenchent
{ const L = 12, n = L * SR, s = new Float64Array(n), gamme = [196, 220, 261.6, 293.7, 329.6, 392, 440];
  for (let i = 0; i < n; i++) s[i] = 0.05 * Math.sin(TAU * 98 * i / SR);
  for (let b = 0; b < 9; b++) { const f = gamme[Math.floor(rnd() * gamme.length)] * (rnd() < 0.3 ? 2 : 1), g = 0.25 + rnd() * 0.2;
    note(s, b * L / 9 + rnd() * 0.5, 2.4, t => g * Math.sin(TAU * f * t + 2.2 * Math.exp(-t / 0.5) * Math.sin(TAU * f * 1.4 * t)) * Math.exp(-t / 0.7) * Math.min(1, t / 0.003)); }
  ecrire('nappe_2', s, 0.7); }

// 3 — molécules et atomes : des sons purs en rapports simples (2 : 3 : 4), qui battent lentement
{ const L = 12, n = L * SR, s = new Float64Array(n);
  for (let i = 0; i < n; i++) { const t = i / SR;
    s[i] = 0.35 * (Math.sin(TAU * 220 * t) + Math.sin(TAU * 220.5 * t)) + 0.22 * (Math.sin(TAU * 330 * t) + Math.sin(TAU * 330.25 * t))
      + 0.14 * (Math.sin(TAU * 440 * t) + Math.sin(TAU * 440.5 * t)) + 0.2 * Math.sin(TAU * 110 * t); }
  ecrire('nappe_3', s, 0.55); }

// 4 — noyaux et quarks : presque le silence, un grondement très grave et trois sons qui se cherchent
{ const L = 12, n = L * SR, s = new Float64Array(n);
  for (let i = 0; i < n; i++) { const t = i / SR;
    s[i] = 0.6 * Math.sin(TAU * 40 * t) + 0.1 * (Math.sin(TAU * 117 * t) + Math.sin(TAU * 120 * t) + Math.sin(TAU * 123 * t)); }
  ecrire('nappe_4', s, 0.6); }

// sons d'interaction
const effet = (nom, duree, f, gain) => { const n = Math.floor(duree * SR), s = new Float64Array(n); for (let i = 0; i < n; i++) s[i] = f(i / SR, i / n); ecrire(nom, s, gain); };
const glisse = (f0, f1, d) => (t, u) => Math.sin(TAU * (f0 * t + (f1 - f0) * t * t / (2 * d))) * Math.sin(Math.PI * u) ** 0.7;
effet('saisie', 0.09, glisse(220, 330, 0.09), 0.6);
effet('entree', 0.55, (t, u) => glisse(660, 330, 0.55)(t, u) + 0.5 * glisse(990, 495, 0.55)(t, u), 0.5);
effet('sortie', 0.45, (t, u) => glisse(330, 660, 0.45)(t, u) + 0.5 * glisse(495, 990, 0.45)(t, u), 0.5);
effet('clic', 0.03, (t, u) => Math.sin(TAU * 1500 * t) * Math.exp(-t / 0.006), 0.5);
effet('compris', 0.2, (t, u) => (t < 0.09 ? Math.sin(TAU * 660 * t) * Math.sin(Math.PI * t / 0.09) : Math.sin(TAU * 880 * t) * Math.sin(Math.PI * (t - 0.09) / 0.11)), 0.5);
