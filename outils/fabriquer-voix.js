// Fabrique les enregistrements de la voix du guide, sur l'ordinateur, à partir des textes validés par le comité.
// Le casque ne synthétise rien : il rejoue ces fichiers. Ainsi, ce qui est entendu est exactement ce qui a été relu.
//
// Usage :  1) godot --headless --xr-mode off -- --exporter-textes     (écrit godot/voix/textes.json)
//          2) node outils/fabriquer-voix.js                           (écrit godot/voix/clips/*.wav)
// Seuls les textes nouveaux ou modifiés sont refaits (godot/voix/empreintes.json garde la trace de ce qui a été dit).
// Voix : Piper « fr_FR-siwis-medium » (corpus SIWIS, licence CC-BY 4.0, à citer dans les crédits).
'use strict';
const fs = require('fs'), path = require('path'), { spawnSync } = require('child_process'), crypto = require('crypto');
const racine = path.join(__dirname, '..'), voix = path.join(racine, 'godot', 'voix'), clips = path.join(voix, 'clips');
const piper = path.join(racine, '.toolchain', 'piper', 'piper.exe'), modele = path.join(racine, '.toolchain', 'voix', 'fr_FR-siwis-medium.onnx');
fs.mkdirSync(clips, { recursive: true });
const textes = JSON.parse(fs.readFileSync(path.join(voix, 'textes.json'), 'utf8'));
const fichierEmpreintes = path.join(voix, 'empreintes.json');
const empreintes = fs.existsSync(fichierEmpreintes) ? JSON.parse(fs.readFileSync(fichierEmpreintes, 'utf8')) : {};

// Ce qui s'écrit autrement qu'il ne se prononce. L'affichage garde l'écriture d'origine.
const oral = t => t
  .replace(/H₂O/g, 'H deux O').replace(/CO₂/g, 'C O deux').replace(/O₂/g, 'O deux')
  .replace(/\bpH\b/g, 'pé hache').replace(/\btype II\b/g, 'type deux').replace(/\bII\b/g, 'deux')
  .replace(/A–T/g, 'A T').replace(/G–C/g, 'G C').replace(/[«»]/g, '').replace(/\s+\?\./g, ' ?').replace(/\?\./g, '?')
  .replace(/ : /g, ', ').replace(/\s+/g, ' ').trim();

const lignes = [], faits = [];
for (const [cle, texte] of Object.entries(textes)) {
  const dit = oral(texte), h = crypto.createHash('sha1').update(dit).digest('hex'), sortie = path.join(clips, cle + '.wav');
  if (empreintes[cle] === h && fs.existsSync(sortie)) continue;
  lignes.push(JSON.stringify({ text: dit, output_file: sortie }));
  faits.push([cle, h]);
}
// enregistrements devenus inutiles
for (const f of fs.readdirSync(clips)) if (f.endsWith('.wav') && !(f.slice(0, -4) in textes)) { fs.unlinkSync(path.join(clips, f)); fs.rmSync(path.join(clips, f + '.import'), { force: true }); }
console.log(Object.keys(textes).length + ' textes, ' + lignes.length + ' à enregistrer');
if (lignes.length) {
  const r = spawnSync(piper, ['--model', modele, '--json-input', '--sentence_silence', '0.35', '--length_scale', '1.04'], { input: lignes.join('\n') + '\n', encoding: 'utf8', maxBuffer: 1 << 28 });
  if (r.status !== 0) { console.error(r.stderr.slice(-2000)); process.exit(1); }
  for (const [cle, h] of faits) if (fs.existsSync(path.join(clips, cle + '.wav'))) empreintes[cle] = h;
  fs.writeFileSync(fichierEmpreintes, JSON.stringify(empreintes));
}
let octets = 0, manquants = 0;
for (const cle of Object.keys(textes)) { const f = path.join(clips, cle + '.wav'); if (fs.existsSync(f)) octets += fs.statSync(f).size; else manquants++; }
console.log('durée totale : ' + (octets / 44100 / 60).toFixed(1) + ' min, manquants : ' + manquants);
