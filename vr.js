// Le corps galaxie — prototype VR (WebXR + WebGL2).
// Le modèle (model.js) est un arbre de nuages de points. Ici : affichage sur la carte graphique en stéréo,
// suivi des mains (pincer pour attraper, deux mains pour zoomer et tourner), et descente dans les niveaux.
'use strict';
(() => {
const { ALL, CORPS, PAL, ROT } = MODELE;

/* ───────── petites maths (doubles côté processeur, pour garder la précision en zoomant très loin) ───────── */
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]], sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const mulS = (a, s) => [a[0] * s, a[1] * s, a[2] * s], dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const len = a => Math.hypot(a[0], a[1], a[2]), norm = a => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const dist = (a, b) => len(sub(a, b));
const I3 = () => new Float64Array([1, 0, 0, 0, 1, 0, 0, 0, 1]);
const mul3 = (A, B) => { const o = new Float64Array(9); for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) o[3 * i + j] = A[3 * i] * B[j] + A[3 * i + 1] * B[3 + j] + A[3 * i + 2] * B[6 + j]; return o; };
const tr3 = A => new Float64Array([A[0], A[3], A[6], A[1], A[4], A[7], A[2], A[5], A[8]]);
const mv3 = (A, v) => [A[0] * v[0] + A[1] * v[1] + A[2] * v[2], A[3] * v[0] + A[4] * v[1] + A[5] * v[2], A[6] * v[0] + A[7] * v[1] + A[8] * v[2]];
const tmv3 = (A, v) => [A[0] * v[0] + A[3] * v[1] + A[6] * v[2], A[1] * v[0] + A[4] * v[1] + A[7] * v[2], A[2] * v[0] + A[5] * v[1] + A[8] * v[2]];
const qMul = (a, b) => [a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1], a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0], a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3], a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2]];
const qConj = q => [-q[0], -q[1], -q[2], q[3]];
const qMat = q => { const [x, y, z, w] = q; return new Float64Array([1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w), 2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w), 2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]); };
// plus courte rotation qui amène la direction u sur la direction v
function qFromTo(u, v) { const c = cross(u, v), w = 1 + dot(u, v); if (w < 1e-6) return [0, 1, 0, 0]; const l = Math.hypot(c[0], c[1], c[2], w); return [c[0] / l, c[1] / l, c[2] / l, w / l]; }
const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

/* ───────── état : pile de niveaux + placement du niveau courant dans la pièce ───────── */
// Un point local x du niveau courant se trouve dans la pièce à : W.p + W.s * W.A * x   (mètres)
let path = [{ n: CORPS }], DT = 0.016;
const W = { p: [0, 1.15, -0.95], A: I3(), s: 0.55 };
const cur = () => path[path.length - 1].n;
const kids = n => { if (!n.kid) { const a = []; for (let i = 0; i < n.n; i++) if (n.K[i] !== 255) a.push(i); n.kid = Int32Array.from(a); } return n.kid; };
function push(i) { const n = cur(), j = 3 * i, kd = n.kinds[n.K[i]], R = ROT[n.R[i]], pos = [n.P[j], n.P[j + 1], n.P[j + 2]];
  W.p = add(W.p, mulS(mv3(W.A, pos), W.s)); W.A = mul3(W.A, R); W.s *= kd.r; path.push({ n: kd.c, r: kd.r, R, pos, i }); }
function pop() { const e = path.pop(); W.s /= e.r; W.A = mul3(W.A, tr3(e.R)); W.p = sub(W.p, mulS(mv3(W.A, e.pos), W.s)); }
// On « entre » dans un enfant quand il fait plus d'un mètre de large autour du point qu'on manipule ; on en ressort quand il redevient petit.
function relink(focus) { let changed = false, popped = false;
  for (let it = 0; it < 8; it++) { const n = cur();
    if (path.length > 1 && (W.s < 0.06 || dist(focus, W.p) > 1.5 * W.s + 0.3)) { pop(); changed = popped = true; continue; }
    const f = mulS(tmv3(W.A, sub(focus, W.p)), 1 / W.s), kid = kids(n), P = n.P; let best = -1, bR = 0;
    let near = -1, nE = W.s >= (n.maxR ? 0.5 / n.minR : 5) * 0.98 ? 1e9 : Math.max(0.5 / W.s, 0.3);   // arrivé en butée : on prend le plus proche, où qu'il soit   // dans le vide : l'enfant assez gros le plus proche est attiré vers le point qu'on manipule
    for (let k = 0; k < kid.length; k++) { const i = kid[k], r = n.kinds[n.K[i]].r; if (r * W.s < 0.15) continue;
      const j = 3 * i, dx = P[j] - f[0], dy = P[j + 1] - f[1], dz = P[j + 2] - f[2], d = Math.sqrt(dx * dx + dy * dy + dz * dz);
      if (d < r * 0.9 && r > bR) { best = i; bR = r; } else if (d - r < nE) { near = i; nE = d - r; } }
    if (best < 0 && near >= 0 && !popped) { const j = 3 * near, c = add(W.p, mulS(mv3(W.A, [P[j], P[j + 1], P[j + 2]]), W.s)); W.p = add(W.p, mulS(sub(focus, c), 1 - Math.exp(-DT * 6))); changed = true; break; }
    if (best >= 0) { push(best); changed = true; continue; } break; }
  const n = cur(), max = n.maxR ? 0.5 / n.minR : 5;
  // butées d'échelle : on recale aussi la position, pour que le point manipulé reste en place quand on bute
  const lim = Math.max(path.length === 1 ? 0.05 : 0.01, Math.min(max, W.s)); if (lim !== W.s) { W.p = add(focus, mulS(sub(W.p, focus), lim / W.s)); W.s = lim; changed = true; }
  return changed; }

/* ───────── WebGL ───────── */
const canvas = document.getElementById('vue');
const gl = canvas.getContext('webgl2', { xrCompatible: true, alpha: true, antialias: false, premultipliedAlpha: true });
if (!gl) { document.getElementById('etat').textContent = 'Ce navigateur ne gère pas WebGL2.'; return; }
function prog(vs, fs) { const p = gl.createProgram(); for (const [t, src] of [[gl.VERTEX_SHADER, vs], [gl.FRAGMENT_SHADER, fs]]) { const s = gl.createShader(t); gl.shaderSource(s, src); gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s)); gl.attachShader(p, s); }
  gl.bindAttribLocation(p, 0, 'aPos'); gl.bindAttribLocation(p, 1, 'aCol'); gl.bindAttribLocation(p, 2, 'aSize'); gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(p)); return p; }
// Points : la taille à l'écran suit la distance ; un point-enfant s'efface à mesure que son propre nuage prend le relais.
const PTS = prog(`#version 300 es
in vec3 aPos; in vec3 aCol; in float aSize;
uniform mat4 uPV, uModel; uniform float uS, uF, uGain, uOpen; out vec3 vCol;
void main(){ vec4 w = uModel * vec4(aPos, 1.0); float d = max(length(w.xyz), 0.02); gl_Position = uPV * w; float a = uGain, px;
  if (aSize > 0.0) { float pr = aSize * uS / d * uF; a *= 0.75 * mix(1.0, 0.3, smoothstep(uOpen * 0.5, uOpen, pr)); px = clamp(2.0 * pr, 3.0, 1.6 * uOpen); }
  else { float pr = 0.0035 * uS / d * uF; px = clamp(2.0 * pr, 2.2, 5.0); a *= 0.5; }
  a *= smoothstep(0.03, 0.12, d); gl_PointSize = px; vCol = aCol * a; }`,
`#version 300 es
precision mediump float; in vec3 vCol; out vec4 o;
void main(){ vec2 q = gl_PointCoord * 2.0 - 1.0; float k = 1.0 - dot(q, q); if (k <= 0.0) discard; o = vec4(vCol * smoothstep(0.0, 0.55, k), 0.0); }`);
const U = {}; for (const u of ['uPV', 'uModel', 'uS', 'uF', 'uGain', 'uOpen']) U[u] = gl.getUniformLocation(PTS, u);
const PAN = prog(`#version 300 es
in vec3 aPos; uniform mat4 uPV, uModel; out vec2 vUV;
void main(){ vUV = aPos.xy * vec2(0.5, -0.5) + 0.5; gl_Position = uPV * (uModel * vec4(aPos, 1.0)); }`,
`#version 300 es
precision mediump float; in vec2 vUV; uniform sampler2D uTex; out vec4 o;
void main(){ o = texture(uTex, vUV); }`);
const UP = { uPV: gl.getUniformLocation(PAN, 'uPV'), uModel: gl.getUniformLocation(PAN, 'uModel') };

function gpu(n) { if (n.vao) return n.vao; const N = n.n, d = new Float32Array(N * 7);
  for (let i = 0; i < N; i++) { const o = i * 7, k = n.K[i]; d[o] = n.P[3 * i]; d[o + 1] = n.P[3 * i + 1]; d[o + 2] = n.P[3 * i + 2];
    let c = n.col, m = 1, sz = 0; if (k === 255) { if (n.C[i]) { c = PAL[n.C[i]]; m = 1.8; } } else { c = n.kinds[k].c.col; sz = n.kinds[k].r; }
    d[o + 3] = c[0] * m; d[o + 4] = c[1] * m; d[o + 5] = c[2] * m; d[o + 6] = sz; }
  return n.vao = makeVao(d, gl.STATIC_DRAW).vao; }
function makeVao(data, usage) { const vao = gl.createVertexArray(), buf = gl.createBuffer(); gl.bindVertexArray(vao); gl.bindBuffer(gl.ARRAY_BUFFER, buf); gl.bufferData(gl.ARRAY_BUFFER, data, usage);
  gl.enableVertexAttribArray(0); gl.vertexAttribPointer(0, 3, gl.FLOAT, false, 28, 0); gl.enableVertexAttribArray(1); gl.vertexAttribPointer(1, 3, gl.FLOAT, false, 28, 12);
  gl.enableVertexAttribArray(2); gl.vertexAttribPointer(2, 1, gl.FLOAT, false, 28, 24); gl.bindVertexArray(null); return { vao, buf }; }
const handData = new Float32Array(120 * 7), handGpu = makeVao(handData, gl.DYNAMIC_DRAW); let handCount = 0;
const quad = makeVao(new Float32Array([-1, -1, 0, 0, 0, 0, 0, 1, -1, 0, 0, 0, 0, 0, -1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0]), gl.STATIC_DRAW);

/* ───────── choix de ce qu'on dessine cette image ───────── */
const OPEN = 12, DENS = 0.14, MAX_ITEMS = 600, MAX_POINTS = 340000;
let items = [], total = 0, head = [0, 1.5, 0], fwd = [0, 0, -1], F = 900;
function collect(n, t, A, s, depth, gain) { const d = Math.max(0.03, dist(t, head)), px = s / d * F;
  let cnt = n.n; const want = n.ns + px * px * DENS; if (want < n.n) cnt = Math.max(1, want | 0);
  items.push({ n, t, A, s, cnt, gain: gain * Math.min(1, Math.sqrt(0.012 * (3.14 * px * px + 1) / cnt)) }); total += cnt;
  if (!n.maxR || depth >= 7 || n.maxR * s / Math.max(0.05, d - s) * F < OPEN * 0.5) return;
  const kid = kids(n), P = n.P, cand = [];
  for (let k = 0; k < kid.length; k++) { const i = kid[k], j = 3 * i, r = n.kinds[n.K[i]].r * s, x = P[j], y = P[j + 1], z = P[j + 2];
    const cx = t[0] + s * (A[0] * x + A[1] * y + A[2] * z), cy = t[1] + s * (A[3] * x + A[4] * y + A[5] * z), cz = t[2] + s * (A[6] * x + A[7] * y + A[8] * z);
    const dx = cx - head[0], dy = cy - head[1], dz = cz - head[2], dd = Math.max(0.03, Math.hypot(dx, dy, dz)), pr = r / dd * F; if (pr < OPEN * 0.5) continue;
    const ahead = dx * fwd[0] + dy * fwd[1] + dz * fwd[2]; if (dd > r && ahead < 0.25 * dd - r) continue;      // hors du champ de vision
    cand.push([pr, i, cx, cy, cz]); }
  cand.sort((a, b) => b[0] - a[0]);
  for (const c of cand) { if (items.length >= MAX_ITEMS || total > MAX_POINTS) break; const i = c[1], kd = n.kinds[n.K[i]];
    collect(kd.c, [c[2], c[3], c[4]], mul3(A, ROT[n.R[i]]), s * kd.r, depth + 1, gain * smooth(OPEN * 0.5, OPEN, c[0])); } }
function buildList() { items = []; total = 0; let t = W.p, A = W.A, s = W.s, top = path.length - 1;
  for (let up = 0; up < 2 && top > 0; up++) { const e = path[top], sp = s / e.r; if (sp > 2500) break; const Ap = mul3(A, tr3(e.R)); t = sub(t, mulS(mv3(Ap, e.pos), sp)); A = Ap; s = sp; top--; }
  collect(path[top].n, t, A, s, 0, 1);
  for (const it of items) { const m = it.m = new Float32Array(16), A2 = it.A, s2 = it.s;
    m[0] = s2 * A2[0]; m[1] = s2 * A2[3]; m[2] = s2 * A2[6]; m[4] = s2 * A2[1]; m[5] = s2 * A2[4]; m[6] = s2 * A2[7]; m[8] = s2 * A2[2]; m[9] = s2 * A2[5]; m[10] = s2 * A2[8];
    m[12] = it.t[0] - head[0]; m[13] = it.t[1] - head[1]; m[14] = it.t[2] - head[2]; m[15] = 1; } }

/* ───────── panneau d'explication (texte dessiné dans une image, affichée sur un rectangle flottant) ───────── */
// Deux panneaux distincts : l'explication au-dessus du poignet gauche, le menu (revenir, quitter) au-dessus du poignet droit.
let fps = 0, pressed = '', wantExit = false, wantHome = false;
const mkPanel = (w, h, pw, ph) => { const cv = document.createElement('canvas'); cv.width = w; cv.height = h; return { cv, c: cv.getContext('2d'), tex: gl.createTexture(), key: '', pw, ph, geo: null, m: null }; };
const INFO = mkPanel(1024, 448, 0.21, 0.092), MENU = mkPanel(1024, 260, 0.17, 0.043);
const BTN = [{ id: 'home', label: 'Revenir au corps', x: 24, w: 476 }, { id: 'exit', label: 'Quitter la VR', x: 524, w: 476 }], BY = 24, BH = 212;
function upload(p) { gl.bindTexture(gl.TEXTURE_2D, p.tex); gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true); gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, p.cv); gl.generateMipmap(gl.TEXTURE_2D);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE); gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE); }
function wrap(c, txt, maxW) { const out = []; let line = ''; for (const w of txt.split(' ')) { const t = line ? line + ' ' + w : w; if (c.measureText(t).width > maxW && line) { out.push(line); line = w; } else line = t; } if (line) out.push(line); return out; }
function drawInfo(n) { const key = n.name + '|' + path.length + '|' + Math.round(fps / 3); if (key === INFO.key) return; INFO.key = key; const c = INFO.c; c.clearRect(0, 0, 1024, 448);
  c.fillStyle = 'rgba(6,6,8,.86)'; c.fillRect(0, 0, 1024, 448); c.fillStyle = n.hex; c.fillRect(0, 0, 8, 448);
  c.fillStyle = '#8f8f94'; c.font = '500 24px system-ui,sans-serif'; c.fillText(path.map(e => e.n.name).join('  ›  ').slice(-70), 36, 46);
  c.fillStyle = '#f1f1ec'; c.font = '600 56px system-ui,sans-serif'; c.fillText(n.name, 36, 114);
  c.fillStyle = n.hex; c.font = '500 24px system-ui,sans-serif'; c.fillText(n.cat.toUpperCase(), 36, 152);
  c.fillStyle = '#f1f1ec'; c.font = '400 29px system-ui,sans-serif'; wrap(c, n.desc, 950).slice(0, 6).forEach((l, i) => c.fillText(l, 36, 200 + i * 38));
  c.fillStyle = '#8f8f94'; c.font = '400 19px ui-monospace,monospace'; c.textAlign = 'right'; c.fillText(Math.round(fps) + ' images/s · ' + total + ' points', 1000, 434); c.textAlign = 'left'; upload(INFO); }
function drawMenu() { if (MENU.key === 'm' + pressed) return; MENU.key = 'm' + pressed; const c = MENU.c; c.clearRect(0, 0, 1024, 260); c.textAlign = 'center'; c.font = '600 44px system-ui,sans-serif';
  for (const b of BTN) { const on = pressed === b.id; c.fillStyle = on ? '#f1f1ec' : 'rgba(20,20,24,.92)'; c.fillRect(b.x, BY, b.w, BH); c.strokeStyle = '#f1f1ec'; c.lineWidth = 4; c.strokeRect(b.x, BY, b.w, BH); c.fillStyle = on ? '#000' : '#f1f1ec'; c.fillText(b.label, b.x + b.w / 2, BY + BH / 2 + 15); }
  upload(MENU); }
// Les panneaux ne suivent plus les mains : ils sont posés dans la pièce, de part et d'autre du corps, tournés vers l'endroit
// où tu te tenais en entrant. « Revenir au corps » les replace devant toi.
function anchor(p, h0, f, ang, dy, d) { const c0 = Math.cos(ang), s0 = Math.sin(ang), dir = [f[0] * c0 - f[2] * s0, 0, f[0] * s0 + f[2] * c0], c = [h0[0] + dir[0] * d, h0[1] + dy, h0[2] + dir[2] * d];
  const nrm = norm(sub(h0, c)), r = norm(cross([0, 1, 0], nrm)), u = cross(nrm, r); p.geo = { c, r, u, nrm }; }
function place(p) { const g = p.geo; if (!g) { p.m = null; return; } const m = p.m = new Float32Array(16);
  m[0] = g.r[0] * p.pw; m[1] = g.r[1] * p.pw; m[2] = g.r[2] * p.pw; m[4] = g.u[0] * p.ph; m[5] = g.u[1] * p.ph; m[6] = g.u[2] * p.ph; m[8] = g.nrm[0]; m[9] = g.nrm[1]; m[10] = g.nrm[2];
  m[12] = g.c[0] - head[0]; m[13] = g.c[1] - head[1]; m[14] = g.c[2] - head[2]; m[15] = 1; }
let POKE = null;   // doigt simulé, pour les tests automatiques
function menuTouch() { let hit = ''; const g = MENU.geo; if (g) for (const h of POKE ? [{ tip: POKE }] : hands) { if (!h.tip) continue; const d = sub(h.tip, g.c), z = dot(d, g.nrm); if (Math.abs(z) > 0.03) continue;
      const x = (dot(d, g.r) / MENU.pw + 1) * 512, y = (1 - dot(d, g.u) / MENU.ph) * 130; for (const b of BTN) if (x > b.x && x < b.x + b.w && y > BY && y < BY + BH) hit = b.id; }
  if (hit && hit !== pressed) { if (hit === 'exit') wantExit = true; else wantHome = true; } pressed = hit; }

/* ───────── gestes ───────── */
let hands = [], grabKey = null, pinchState = {};
// Chaque image applique le petit mouvement des mains depuis l'image précédente, directement sur le monde.
// (L'ancienne version repartait d'une position mémorisée au début du geste, et la remémorisait dès qu'on entrait
// dans quelque chose ou qu'une chose était attirée : le zoom se figeait à chaque fois.)
let prev = null;
function gestures() { const g = hands.filter(h => h.pinch), key = g.map(h => h.id).join('+');
  if (prev && prev.key === key && g.length === 1) { // une main : l'objet suit la main et tourne avec le poignet
    const D = qMat(qMul(g[0].quat, qConj(prev.q))); W.A = mul3(D, W.A); W.p = add(g[0].pos, mv3(D, sub(W.p, prev.a))); relink(g[0].pos); }
  else if (prev && prev.key === key && g.length === 2) { // deux mains : écarter pour grossir, tourner pour faire pivoter, autour du point entre les mains
    const a = g[0].pos, b = g[1].pos, m = mulS(add(a, b), 0.5), m0 = mulS(add(prev.a, prev.b), 0.5), k = Math.pow(Math.max(0.03, dist(a, b)) / Math.max(0.03, dist(prev.a, prev.b)), 1.6);   // écarter du double agrandit d'environ 3 fois
    const D = qMat(qFromTo(norm(sub(prev.b, prev.a)), norm(sub(b, a)))); W.A = mul3(D, W.A); W.s *= k; W.p = add(m, mulS(mv3(D, sub(W.p, m0)), k)); relink(m); }
  prev = g.length ? { key, a: g[0].pos.slice(), q: g[0].quat.slice(), b: g[1] && g[1].pos.slice() } : null; }
function pointed() { let best = null; for (const h of hands) { if (!h.tip) continue; for (const it of items) if (it.s < 0.6 && it.s > 0.012 && dist(h.tip, it.t) < it.s && (!best || it.s < best.s)) best = it; } return best ? best.n : cur(); }
function readXR(frame, ref, session, dt) { hands = []; handCount = 0; const put = (p, r, c) => { if (handCount >= 120) return; const o = handCount++ * 7; handData[o] = p.x - head[0]; handData[o + 1] = p.y - head[1]; handData[o + 2] = p.z - head[2]; handData[o + 3] = c[0]; handData[o + 4] = c[1]; handData[o + 5] = c[2]; handData[o + 6] = r; };
  for (const src of session.inputSources) { const id = src.handedness; let pos = null, quat = [0, 0, 0, 1], pinch = false, tip = null, wrist = null;
    if (src.hand) { const tp = frame.getJointPose(src.hand.get('thumb-tip'), ref), ip = frame.getJointPose(src.hand.get('index-finger-tip'), ref), wp = frame.getJointPose(src.hand.get('wrist'), ref);
      if (tp && ip) { const a = tp.transform.position, b = ip.transform.position, d = Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z);
        pinch = pinchState[id] = pinchState[id] ? d < 0.055 : d < 0.028; pos = [(a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2]; tip = [b.x, b.y, b.z];
        if (wp) { const o = wp.transform.orientation, q = wp.transform.position; quat = [o.x, o.y, o.z, o.w]; wrist = [q.x, q.y, q.z]; } }
      for (const j of src.hand.values()) { const jp = frame.getJointPose(j, ref); if (jp) put(jp.transform.position, 0.0045, pinch ? [1, 0.85, 0.3] : [0.45, 0.85, 1]); } }
    else if (src.gripSpace) { const gp = frame.getPose(src.gripSpace, ref); if (gp) { const a = gp.transform.position, o = gp.transform.orientation; pos = tip = wrist = [a.x, a.y, a.z]; quat = [o.x, o.y, o.z, o.w];
        const ax = src.gamepad ? src.gamepad.axes : [], sy = ax.length >= 4 ? ax[3] : 0;   // joystick : pousser agrandit, tirer réduit, autour de la manette
        if (Math.abs(sy) > 0.2) { const f = Math.exp(-sy * dt * 2.2); W.s *= f; W.p = add(pos, mulS(sub(W.p, pos), f)); relink(pos); }
        if (src.gamepad && src.gamepad.buttons[5] && src.gamepad.buttons[5].pressed) wantExit = true;   // bouton B ou Y : sortir
        const bt = src.gamepad ? src.gamepad.buttons : []; pinch = !!((bt[0] && bt[0].pressed) || (bt[1] && bt[1].pressed)); put(a, 0.012, pinch ? [1, 0.85, 0.3] : [0.45, 0.85, 1]); } }
    if (pos) hands.push({ id, pos, quat, pinch, tip, wrist }); }
  const g = hands.filter(h => h.pinch); if (g.length === 2) for (let i = 1; i < 24; i++) { const t = i / 24; put({ x: g[0].pos[0] + (g[1].pos[0] - g[0].pos[0]) * t, y: g[0].pos[1] + (g[1].pos[1] - g[0].pos[1]) * t, z: g[0].pos[2] + (g[1].pos[2] - g[0].pos[2]) * t }, 0.003, [1, 0.85, 0.3]); } }

/* ───────── rendu d'un œil ───────── */
function mat4mul(a, b) { const o = new Float32Array(16); for (let c = 0; c < 4; c++) for (let r = 0; r < 4; r++) o[4 * c + r] = a[r] * b[4 * c] + a[4 + r] * b[4 * c + 1] + a[8 + r] * b[4 * c + 2] + a[12 + r] * b[4 * c + 3]; return o; }
function drawEye(proj, view, vpH, panelM) { // on dessine par rapport à la tête : la vue ne garde que sa rotation et le décalage de l'œil
  const v = Float32Array.from(view); const tx = v[12] + v[0] * head[0] + v[4] * head[1] + v[8] * head[2], ty = v[13] + v[1] * head[0] + v[5] * head[1] + v[9] * head[2], tz = v[14] + v[2] * head[0] + v[6] * head[1] + v[10] * head[2];
  v[12] = tx; v[13] = ty; v[14] = tz; const pv = mat4mul(proj, v);
  gl.useProgram(PTS); gl.uniformMatrix4fv(U.uPV, false, pv); gl.uniform1f(U.uF, proj[5] * vpH / 2); gl.uniform1f(U.uOpen, OPEN);
  gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE); gl.disable(gl.DEPTH_TEST);
  for (const it of items) { gl.bindVertexArray(gpu(it.n)); gl.uniformMatrix4fv(U.uModel, false, it.m); gl.uniform1f(U.uS, it.s); gl.uniform1f(U.uGain, it.gain * Math.min(1.5, Math.sqrt(it.n.n / it.cnt))); gl.drawArrays(gl.POINTS, 0, it.cnt); }
  if (handCount) { gl.bindVertexArray(handGpu.vao); gl.uniformMatrix4fv(U.uModel, false, IDENT); gl.uniform1f(U.uS, 1); gl.uniform1f(U.uGain, 1); gl.uniform1f(U.uOpen, 1e5); gl.drawArrays(gl.POINTS, 0, handCount); }
  if (panelM) for (const p of [INFO, MENU]) { if (!p.m) continue; gl.useProgram(PAN); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA); gl.uniformMatrix4fv(UP.uPV, false, pv); gl.uniformMatrix4fv(UP.uModel, false, p.m);
    gl.bindTexture(gl.TEXTURE_2D, p.tex); gl.bindVertexArray(quad.vao); gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); }
  gl.bindVertexArray(null); }
const IDENT = new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
let lastT = 0; const tick = t => { const dt = Math.min(0.1, (t - lastT) / 1000 || 0.016); lastT = t; fps += (1 / dt - fps) * 0.05; return dt; };

/* ───────── session VR ───────── */
let xr = null;
async function enter(mode) { const etat = document.getElementById('etat');
  try { const session = await navigator.xr.requestSession(mode, { requiredFeatures: ['local-floor'], optionalFeatures: ['hand-tracking'] });
    await gl.makeXRCompatible(); const nat = XRWebGLLayer.getNativeFramebufferScaleFactor ? XRWebGLLayer.getNativeFramebufferScaleFactor(session) : 1.2;
    const layer = new XRWebGLLayer(session, gl, { antialias: false, alpha: true, depth: false, framebufferScaleFactor: Math.min(1.5, Math.max(1, nat)) });   // pleine définition du casque, au lieu de la définition réduite par défaut
    session.updateRenderState({ baseLayer: layer }); const ref = await session.requestReferenceSpace('local-floor'); xr = session; grabKey = null; wantExit = wantHome = false; let placed = false; if (session.updateTargetFrameRate && session.supportedFrameRates) { const fr = Array.from(session.supportedFrameRates); if (fr.includes(90)) session.updateTargetFrameRate(90).catch(() => {}); }
    session.addEventListener('end', () => { xr = null; etat.textContent = 'Session terminée.'; requestAnimationFrame(flat); });
    const loop = (t, frame) => { session.requestAnimationFrame(loop); const pose = frame.getViewerPose(ref); if (!pose) return; const dt = tick(t);
      const hp = pose.transform.position, hm = pose.transform.matrix; head = [hp.x, hp.y, hp.z]; fwd = norm([-hm[8], -hm[9], -hm[10]]);
      if (!placed || wantHome) { placed = true; wantHome = false; grabKey = null; const f = norm([fwd[0], 0, fwd[2]]); path = [{ n: CORPS }]; W.s = 0.5; W.A = qMat([0, Math.sin(Math.atan2(-f[0], -f[2]) / 2), 0, Math.cos(Math.atan2(-f[0], -f[2]) / 2)]); W.p = [head[0] + f[0] * 0.9, Math.max(0.9, head[1] - 0.35), head[2] + f[2] * 0.9];
        anchor(INFO, head, f, 0.75, -0.12, 0.75); anchor(MENU, head, f, -0.75, -0.3, 0.6); prev = null; }
      DT = dt; readXR(frame, ref, session, dt); gestures(); place(INFO); place(MENU); menuTouch(); if (wantExit) { wantExit = false; session.end(); return; }
      const v0 = layer.getViewport(pose.views[0]); F = pose.views[0].projectionMatrix[5] * v0.height / 2; buildList(); drawInfo(pointed()); drawMenu(); const pm = true;
      gl.bindFramebuffer(gl.FRAMEBUFFER, layer.framebuffer); gl.clearColor(0, 0, 0, mode === 'immersive-ar' ? 0 : 1); gl.clear(gl.COLOR_BUFFER_BIT);
      for (const view of pose.views) { const vp = layer.getViewport(view); gl.viewport(vp.x, vp.y, vp.width, vp.height); drawEye(view.projectionMatrix, view.transform.inverse.matrix, vp.height, pm); } };
    session.requestAnimationFrame(loop); etat.textContent = 'En immersion.';
  } catch (e) { etat.textContent = 'Impossible de démarrer : ' + (e && e.message || e); } }

/* ───────── aperçu à plat (ordinateur, ou avant d'entrer en VR) : glisser pour tourner, molette pour zoomer ───────── */
const FOCUS = [0, 1.15, -0.95];
let flatUntil = 0;
function flat(t) { if (xr) return; requestAnimationFrame(flat); DT = tick(t); if (t < flatUntil) relink(FOCUS);
  const w = canvas.clientWidth, h = canvas.clientHeight, d = Math.min(devicePixelRatio || 1, 2); if (canvas.width !== Math.round(w * d) || canvas.height !== Math.round(h * d)) { canvas.width = Math.round(w * d); canvas.height = Math.round(h * d); }
  head = [0, 1.25, 0.25]; fwd = [0, 0, -1]; const f = 1 / Math.tan(0.5), a = canvas.width / canvas.height, n = 0.02, fa = 500;
  const proj = new Float32Array([f / a, 0, 0, 0, 0, f, 0, 0, 0, 0, (fa + n) / (n - fa), -1, 0, 0, 2 * fa * n / (n - fa), 0]), view = new Float32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -head[0], -head[1], -head[2], 1]);
  F = proj[5] * canvas.height / 2; buildList(); document.getElementById('lieu').textContent = path.map(e => e.n.name).join(' › ');
  gl.bindFramebuffer(gl.FRAMEBUFFER, null); gl.viewport(0, 0, canvas.width, canvas.height); gl.clearColor(0, 0, 0, 1); gl.clear(gl.COLOR_BUFFER_BIT); drawEye(proj, view, canvas.height, null); }
let dragging = null;
canvas.addEventListener('pointerdown', e => { dragging = [e.clientX, e.clientY]; canvas.setPointerCapture(e.pointerId); });
canvas.addEventListener('pointermove', e => { if (!dragging || xr) return; const dx = (e.clientX - dragging[0]) * 0.006, dy = (e.clientY - dragging[1]) * 0.006; dragging = [e.clientX, e.clientY];
  const D = mul3(qMat([0, Math.sin(dx / 2), 0, Math.cos(dx / 2)]), qMat([Math.sin(dy / 2), 0, 0, Math.cos(dy / 2)])); W.A = mul3(D, W.A); W.p = add(FOCUS, mv3(D, sub(W.p, FOCUS))); });
canvas.addEventListener('pointerup', () => { dragging = null; });
canvas.addEventListener('wheel', e => { e.preventDefault(); if (xr) return; const k = Math.exp(-e.deltaY * 0.0015); W.s *= k; W.p = add(FOCUS, mulS(sub(W.p, FOCUS), k)); relink(FOCUS); flatUntil = performance.now() + 1200; }, { passive: false });

/* ───────── boutons ───────── */
(async () => { const etat = document.getElementById('etat'), bv = document.getElementById('vr'), ba = document.getElementById('ar');
  bv.onclick = () => enter('immersive-vr'); ba.onclick = () => enter('immersive-ar');
  if (!navigator.xr) { etat.textContent = 'Ce navigateur ne propose pas la VR. Ouvre cette page dans le navigateur du Quest. Ici, tu vois un aperçu : glisse pour tourner, molette pour zoomer.'; return; }
  const [v, a] = await Promise.all([navigator.xr.isSessionSupported('immersive-vr').catch(() => false), navigator.xr.isSessionSupported('immersive-ar').catch(() => false)]);
  bv.disabled = !v; ba.disabled = !a; etat.textContent = v || a ? 'Casque détecté. Choisis un mode pour entrer.' : 'Aucun casque détecté par ce navigateur. Aperçu : glisse pour tourner, molette pour zoomer.'; })();
requestAnimationFrame(flat);
window.__vr = { menu: () => MENU.geo, poke: t => { POKE = t; }, state: () => ({ path: path.map(e => e.n.name), s: W.s, items: items.length, total, fps }), W, relink, push, pop, gestureTest: (hs) => { hands = hs; gestures(); return { p: W.p, s: W.s }; } };
})();
