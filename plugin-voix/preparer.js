// Met en place ce dont l'extension « GalaxieVoix » a besoin et qui n'est pas dans les sources :
// le moteur sherpa-onnx (bibliothèque Android précompilée) et le modèle français de reconnaissance vocale.
//
//   node plugin-voix/preparer.js          puis          godot\android\build\gradlew.bat -p plugin-voix assembleRelease
//
// Tout vient des publications officielles du projet k2-fsa/sherpa-onnx (https://github.com/k2-fsa/sherpa-onnx/releases),
// téléchargées une fois dans .toolchain/dl/sherpa/ :
//   v2.0.3/sherpa-onnx-static-link-onnxruntime-2.0.3.aar                         moteur (Apache 2.0), ONNX Runtime inclus (MIT)
//   asr-models/sherpa-onnx-streaming-zipformer-fr-kroko-2025-08-06.tar.bz2       modèle français Kroko (CC BY-SA)
//   asr-models/silero_vad.onnx                                                   détection de la parole Silero VAD (MIT)
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');

const ici = __dirname, racine = path.dirname(ici);
const dl = path.join(racine, '.toolchain', 'dl', 'sherpa');
const VERSION = '2.0.3';
const MODELE = 'sherpa-onnx-streaming-zipformer-fr-kroko-2025-08-06';
const BASE = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/';
const fichiers = [
  [`sherpa-onnx-static-link-onnxruntime-${VERSION}.aar`, `v${VERSION}/sherpa-onnx-static-link-onnxruntime-${VERSION}.aar`],
  [`${MODELE}.tar.bz2`, `asr-models/${MODELE}.tar.bz2`],
  ['silero_vad.onnx', 'asr-models/silero_vad.onnx'],
];

fs.mkdirSync(dl, { recursive: true });
for (const [nom, chemin] of fichiers) {
  const cible = path.join(dl, nom);
  if (!fs.existsSync(cible)) {
    console.log('téléchargement de', nom);
    execFileSync('curl', ['-sSL', '--fail', '-A', 'curl', '-o', cible, BASE + chemin], { stdio: 'inherit' });
  }
}

// 1. le moteur : classes Java/Kotlin et bibliothèque native arm64 (le Quest 3 n'a besoin que de celle-là)
const xAar = path.join(dl, 'x-aar');
if (!fs.existsSync(path.join(xAar, 'classes.jar'))) {
  fs.mkdirSync(xAar, { recursive: true });
  execFileSync('tar', ['-xf', path.join(dl, fichiers[0][0]), '-C', xAar], { stdio: 'inherit' });   // un .aar est un zip
}
const copier = (de, vers) => { fs.mkdirSync(path.dirname(vers), { recursive: true }); fs.copyFileSync(de, vers); };
copier(path.join(xAar, 'classes.jar'), path.join(ici, 'libs', `sherpa-onnx-classes-${VERSION}.jar`));
copier(path.join(xAar, 'jni', 'arm64-v8a', 'libsherpa-onnx-jni.so'), path.join(ici, 'src', 'main', 'jniLibs', 'arm64-v8a', 'libsherpa-onnx-jni.so'));

// 2. le modèle
const xModele = path.join(dl, 'x-' + MODELE);
if (!fs.existsSync(path.join(xModele, MODELE, 'tokens.txt'))) {
  fs.mkdirSync(xModele, { recursive: true });
  execFileSync('tar', ['-xjf', path.join(dl, fichiers[1][0]), '-C', xModele], { stdio: 'inherit' });
}
const actifs = path.join(ici, 'src', 'main', 'assets', 'galaxie-voix');
fs.rmSync(path.join(ici, 'src', 'main', 'assets', 'model-fr'), { recursive: true, force: true });   // ancien modèle Vosk
for (const f of ['encoder.onnx', 'decoder.onnx', 'joiner.onnx', 'tokens.txt']) copier(path.join(xModele, MODELE, f), path.join(actifs, f));
copier(path.join(dl, 'silero_vad.onnx'), path.join(actifs, 'silero_vad.onnx'));

// 3. bpe.vocab : la table qui sert à découper nos mots (« mitochondrie ») en morceaux connus du modèle, pour pouvoir
// les favoriser pendant la reconnaissance (« hotwords »). Le modèle est publié sans elle ; on la reconstruit à partir
// de tokens.txt, dont les morceaux sont rangés du plus fréquent au plus rare : le rang tient lieu de probabilité.
const jetons = fs.readFileSync(path.join(xModele, MODELE, 'tokens.txt'), 'utf8').trim().split(/\r?\n/).map(l => l.split(' ')[0]);
const vocab = jetons.filter(j => !/^#\d+$/.test(j))
  .map((j, i) => j + '\t' + (j.startsWith('<') && j.endsWith('>') ? '0' : (-Math.log(i + 20)).toFixed(4)));
fs.writeFileSync(path.join(actifs, 'bpe.vocab'), vocab.join('\n') + '\n');

fs.writeFileSync(path.join(actifs, 'LICENCES.txt'), [
  'Reconnaissance vocale embarquée du corps galaxie — tout fonctionne dans le casque, sans connexion.',
  '',
  `Moteur : sherpa-onnx ${VERSION} (k2-fsa / Next-gen Kaldi), licence Apache 2.0 — https://github.com/k2-fsa/sherpa-onnx`,
  'Calcul : ONNX Runtime (Microsoft), licence MIT — https://github.com/microsoft/onnxruntime',
  `Modèle français : Kroko ASR, modèle communautaire « ${MODELE} » (Banafo), licence CC BY-SA — https://huggingface.co/Banafo/Kroko-ASR`,
  'Détection de la parole : Silero VAD (Silero Team), licence MIT — https://github.com/snakers4/silero-vad',
  '',
].join('\n'));

const mo = f => (fs.statSync(f).size / 1048576).toFixed(1) + ' Mo';
console.log('moteur  :', mo(path.join(ici, 'src', 'main', 'jniLibs', 'arm64-v8a', 'libsherpa-onnx-jni.so')));
for (const f of fs.readdirSync(actifs)) console.log('modèle  :', f, mo(path.join(actifs, f)));
