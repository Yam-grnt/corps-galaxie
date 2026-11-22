// Convertit le modèle (model.js) en un fichier binaire que l'application Godot charge directement.
// Usage : node outils/exporter-modele.js   → écrit godot/modele.bin et godot/modele.json
// Par nœud : pos (xyz), att (rvb + rayon de l'enfant), sp ([système, phase] par point, même ordre que pos), puis les enfants triés par taille :
// kp (centres), kr (rayons), kk (nœud), ko (rotation), ki (indice du point), ks (système). « sys » est le système du nœud lui-même (−1 : aucun).
'use strict';
const fs = require('fs'), path = require('path');
const racine = path.join(__dirname, '..');
const MODELE = new Function(fs.readFileSync(path.join(racine, 'model.js'), 'utf8') + ';return MODELE;')();
const { ALL, PAL, ROT } = MODELE, morceaux = []; let off = 0;
const ecrire = ta => { const b = Buffer.from(ta.buffer, ta.byteOffset, ta.byteLength); const o = off; morceaux.push(b); off += b.length; const pad = (4 - off % 4) % 4; if (pad) { morceaux.push(Buffer.alloc(pad)); off += pad; } return o; };
const idx = new Map(ALL.map((n, i) => [n, i]));
const rot = new Float32Array(ROT.length * 9); ROT.forEach((r, i) => rot.set(r, i * 9));
const meta = { rot_n: ROT.length, rot_off: ecrire(rot), noeuds: [] };
for (const n of ALL) { const N = n.n, pos = new Float32Array(N * 3), att = new Float32Array(N * 4), kids = [];
  for (let i = 0; i < N; i++) { pos[3 * i] = n.P[3 * i]; pos[3 * i + 1] = n.P[3 * i + 1]; pos[3 * i + 2] = n.P[3 * i + 2];
    const k = n.K[i]; let c = n.col, m = 1, sz = 0;
    if (k === 255) { if (n.C[i]) { c = PAL[n.C[i]]; m = 1.8; } }
    else { c = n.C[i] ? PAL[n.C[i]] : n.kinds[k].c.col; sz = n.kinds[k].r; kids.push(i); }   // teinte imposée au point-enfant (veine bleue, nerf jaune…), sans le facteur 1.8
    att[4 * i] = c[0] * m; att[4 * i + 1] = c[1] * m; att[4 * i + 2] = c[2] * m; att[4 * i + 3] = sz; }
  // enfants triés du plus gros au plus petit : les parcours s'arrêtent dès qu'ils deviennent trop petits pour compter
  kids.sort((a, b) => n.kinds[n.K[b]].r - n.kinds[n.K[a]].r);
  const kp = new Float32Array(kids.length * 3), kr = new Float32Array(kids.length), kk = new Int32Array(kids.length), ko = new Int32Array(kids.length), ki = new Int32Array(kids.length), ks = new Int32Array(kids.length);
  kids.forEach((i, j) => { kp[3 * j] = n.P[3 * i]; kp[3 * j + 1] = n.P[3 * i + 1]; kp[3 * j + 2] = n.P[3 * i + 2]; kr[j] = n.kinds[n.K[i]].r; kk[j] = idx.get(n.kinds[n.K[i]].c); ko[j] = n.R[i]; ki[j] = i; ks[j] = Math.round(n.S[2 * i]); });
  meta.noeuds.push({ nom: n.name, desc: n.desc, cat: n.cat, hex: n.hex, taille: n.size, sys: n.sys, n: N, ns: n.ns, max_r: n.maxR, min_r: n.maxR ? n.minR : 0,
    pos: ecrire(pos), att: ecrire(att), sp: ecrire(n.S), nk: kids.length, kp: ecrire(kp), kr: ecrire(kr), kk: ecrire(kk), ko: ecrire(ko), ki: ecrire(ki), ks: ecrire(ks) }); }
meta.racine = idx.get(MODELE.CORPS);
meta.racines = { homme: idx.get(MODELE.CORPS), femme: idx.get(MODELE.CORPS_F) };
fs.writeFileSync(path.join(racine, 'godot', 'modele.bin'), Buffer.concat(morceaux));
fs.writeFileSync(path.join(racine, 'godot', 'modele.json'), JSON.stringify(meta));
console.log(ALL.length + ' nœuds, ' + (off / 1e6).toFixed(1) + ' Mo');
