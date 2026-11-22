// Essai du moteur de reconnaissance vocale sur ordinateur, sans casque :
//   1. les phrases de phrases.json sont dites par une voix de synthèse (Piper, .toolchain/piper) ;
//   2. elles sont jouées bout à bout, comme par le micro, dans la chaîne du casque (Simulation.java : même découpage,
//      mêmes réglages, même modèle que l'extension) ;
//   3. ce qui est entendu est donné au guide (outils/essai-guide.gd), qui dit combien de demandes sont comprises.
//
//   node plugin-voix/essai/essai-moteur.js            (après  node plugin-voix/preparer.js)
//
// Une voix de synthèse n'est pas une vraie voix dans un vrai casque : ces chiffres servent à comparer deux réglages
// ou deux moteurs entre eux, pas à promettre un taux de réussite.
const fs = require('fs'), path = require('path'), { spawnSync, execFileSync } = require('child_process');

const racine = path.resolve(__dirname, '..', '..'), outils = path.join(racine, '.toolchain');
const dl = path.join(outils, 'dl', 'sherpa'), travail = path.join(racine, 'plugin-voix', 'build', 'essai');
const VERSION = '2.0.3', BASE = `https://github.com/k2-fsa/sherpa-onnx/releases/download/v${VERSION}/`;
const voix = { s: 'fr_FR-siwis-medium', g: 'fr_FR-gilles-low' };
const jdk = path.join(outils, 'jdk', fs.readdirSync(path.join(outils, 'jdk'))[0], 'bin');
const lancer = (exe, args, opt = {}) => {
  const r = spawnSync(exe, args, { encoding: 'utf8', maxBuffer: 1 << 26, ...opt });
  if (r.status !== 0 && !opt.tolerer) { console.error(r.stdout, r.stderr); process.exit(1); }
  return (r.stdout || '') + (r.stderr || '');
};

// bibliothèques sherpa-onnx pour ordinateur (mêmes sources officielles que celles du casque)
const jar = path.join(dl, `sherpa-onnx-jvm-${VERSION}.jar`), natif = path.join(dl, `sherpa-onnx-native-lib-win-x64-${VERSION}.jar`);
for (const f of [jar, natif]) if (!fs.existsSync(f)) execFileSync('curl', ['-sSL', '--fail', '-A', 'curl', '-o', f, BASE + path.basename(f)], { stdio: 'inherit' });
const dll = path.join(dl, 'x-jni-win');
if (!fs.existsSync(path.join(dll, 'sherpa-onnx-jni.dll'))) {
  fs.mkdirSync(dll, { recursive: true });
  lancer('tar', ['-xf', natif, '-C', dll, '--strip-components=3', 'sherpa-onnx/native/win-x64']);
}

// 1. synthèse, puis mise à 16 kHz avec un peu de silence autour (0,4 s avant, 1 s après)
const phrases = JSON.parse(fs.readFileSync(path.join(__dirname, 'phrases.json'), 'utf8'));
const wavs = path.join(travail, 'wav');
fs.mkdirSync(wavs, { recursive: true });
function mettre_a_16k(b) {
  let p = 12, sr = 0, data = null;
  while (p < b.length - 8) {
    const id = b.toString('ascii', p, p + 4), len = b.readUInt32LE(p + 4);
    if (id === 'fmt ') sr = b.readUInt32LE(p + 12);
    if (id === 'data') { data = b.subarray(p + 8, Math.min(b.length, p + 8 + len)); break; }
    p += 8 + len + (len & 1);
  }
  const n = data.length >> 1, r = sr / 16000, m = Math.floor(n / r), H = 16, fc = Math.min(1, 1 / r) * 0.95;
  const pre = 6400, post = 16000, tot = pre + m + post, o = Buffer.alloc(44 + tot * 2);
  o.write('RIFF', 0); o.writeUInt32LE(36 + tot * 2, 4); o.write('WAVEfmt ', 8); o.writeUInt32LE(16, 16); o.writeUInt16LE(1, 20);
  o.writeUInt16LE(1, 22); o.writeUInt32LE(16000, 24); o.writeUInt32LE(32000, 28); o.writeUInt16LE(2, 32); o.writeUInt16LE(16, 34);
  o.write('data', 36); o.writeUInt32LE(tot * 2, 40);
  for (let j = 0; j < m; j++) {
    const t = j * r, c = Math.floor(t); let s = 0;
    for (let k = c - H + 1; k <= c + H; k++) {
      if (k < 0 || k >= n) continue;
      const d = t - k, a = Math.PI * d * fc;
      s += data.readInt16LE(k * 2) / 32768 * (d === 0 ? 1 : Math.sin(a) / a) * (0.5 + 0.5 * Math.cos(Math.PI * d / H)) * fc;
    }
    o.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(s * 32767))), 44 + (pre + j) * 2);
  }
  return o;
}
for (const [lettre, nom] of Object.entries(voix)) {
  phrases.forEach((ph, i) => {
    const cible = path.join(wavs, lettre + String(i + 1).padStart(2, '0') + '.wav');
    if (fs.existsSync(cible)) return;
    const brut = path.join(travail, 'brut.wav');
    lancer(path.join(outils, 'piper', 'piper.exe'), ['-m', path.join(outils, 'voix', nom + '.onnx'), '-f', brut], { input: ph[0] + '\n' });
    fs.writeFileSync(cible, mettre_a_16k(fs.readFileSync(brut)));
  });
}

// 2. le vocabulaire du projet, puis la chaîne du casque
const godot = path.join(outils, 'godot', 'Godot_v4.4.1-stable_win64_console.exe');
const guide = extra => lancer(godot, ['--headless', '--xr-mode', 'off', '--quit-after', '5000', '--path', path.join(racine, 'godot'),
  '-s', '../outils/essai-guide.gd', '--', ...extra], { tolerer: true });
const vocab = path.join(travail, 'vocabulaire.txt'), entendu = path.join(travail, 'entendu.json');
guide(['--vocabulaire=' + vocab.replace(/\\/g, '/')]);
const classes = path.join(travail, 'classes'), src = path.join(racine, 'plugin-voix', 'src', 'main', 'java', 'io', 'github', 'yamgrnt', 'galaxievoix');
fs.mkdirSync(classes, { recursive: true });
lancer(path.join(jdk, 'javac.exe'), ['-encoding', 'UTF-8', '-cp', jar, '-d', classes, path.join(src, 'Decoupage.java'), path.join(src, 'MotsCles.java'),
  path.join(__dirname, 'Simulation.java')]);
const sortie = lancer(path.join(jdk, 'java.exe'), ['-Dfile.encoding=UTF-8', '-Djava.library.path=' + dll, '-cp', classes + ';' + jar,
  'io.github.yamgrnt.galaxievoix.Simulation', path.join(racine, 'plugin-voix', 'src', 'main', 'assets', 'galaxie-voix'), wavs,
  process.argv.includes('--sans-vocabulaire') ? '-' : vocab, entendu]);
console.log(sortie.split(/\r?\n/).filter(l => /modèle chargé|mots favorisés|phrases rendues|fin de phrase|calcul/.test(l)).join('\n'));

// 3. ce que le guide en comprend
const res = guide(['--transcriptions=' + entendu.replace(/\\/g, '/'), '--attendus=' + path.join(__dirname, 'phrases.json').replace(/\\/g, '/'), '--detail']);
console.log(res.split(/\r?\n/).filter(l => /RATÉ|MOTEUR|GUIDE|ARRÊT/.test(l)).join('\n'));
console.log('(voix s : ' + voix.s + ', nette ; voix g : ' + voix.g + ', de mauvaise qualité, pour voir comment la chaîne se dégrade)');
