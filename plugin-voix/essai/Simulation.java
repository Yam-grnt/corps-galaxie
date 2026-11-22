package io.github.yamgrnt.galaxievoix;

import com.k2fsa.sherpa.onnx.FeatureConfig;
import com.k2fsa.sherpa.onnx.OnlineModelConfig;
import com.k2fsa.sherpa.onnx.OnlineRecognizer;
import com.k2fsa.sherpa.onnx.OnlineRecognizerConfig;
import com.k2fsa.sherpa.onnx.OnlineStream;
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig;
import com.k2fsa.sherpa.onnx.SileroVadModelConfig;
import com.k2fsa.sherpa.onnx.Vad;
import com.k2fsa.sherpa.onnx.VadModelConfig;

import java.io.File;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Essai sur ordinateur de la chaîne du casque : les enregistrements sont joués bout à bout, par blocs d'un dixième de
 * seconde comme le ferait le micro, dans le même découpage (Decoupage) et avec les mêmes réglages que GalaxieVoix.
 * Lancé par essai-moteur.js. args : dossier du modèle, dossier des wav 16 kHz, vocabulaire (un mot par ligne, ou « - »), sortie json, [poids des mots favorisés]
 */
public class Simulation {
    public static void main(String[] a) throws Exception {
        // Windows fournit sa propre onnxruntime.dll, plus ancienne : on charge d'abord celle de sherpa-onnx
        System.load(new File(System.getProperty("java.library.path").split(";")[0], "onnxruntime.dll").getAbsolutePath());
        String m = a[0];
        boolean motsCles = !a[2].equals("-");
        float score = a.length > 4 ? Float.parseFloat(a[4]) : 2.0f;

        Vad vad = new Vad(VadModelConfig.builder().setSileroVadModelConfig(SileroVadModelConfig.builder()
                .setModel(m + "/silero_vad.onnx").setThreshold(Float.parseFloat(System.getProperty("seuil", "0.5"))).setMinSilenceDuration(Float.parseFloat(System.getProperty("silence", "0.55"))).setMinSpeechDuration(0.2f)
                .setWindowSize(512).setMaxSpeechDuration(20f).build()).setTenVadModelConfig(com.k2fsa.sherpa.onnx.TenVadModelConfig.builder().build()).setSampleRate(16000).setNumThreads(1).setProvider("cpu").build());

        OnlineModelConfig.Builder mc = OnlineModelConfig.builder()
                .setTransducer(OnlineTransducerModelConfig.builder().setEncoder(m + "/encoder.onnx").setDecoder(m + "/decoder.onnx")
                        .setJoiner(m + "/joiner.onnx").build())
                .setTokens(m + "/tokens.txt").setNumThreads(2).setProvider("cpu").setModelType("zipformer2");
        OnlineRecognizerConfig.Builder rc = OnlineRecognizerConfig.builder()
                .setFeatureConfig(FeatureConfig.builder().setSampleRate(16000).setFeatureDim(80).build()).setEnableEndpoint(false);
        if (motsCles) {
            mc.setModelingUnit("bpe").setBpeVocab(m + "/bpe.vocab");
            rc.setDecodingMethod("modified_beam_search").setMaxActivePaths(4).setHotwordsScore(score);
        } else {
            rc.setDecodingMethod("greedy_search");
        }
        long t0 = System.currentTimeMillis();
        OnlineRecognizer r = new OnlineRecognizer(rc.setOnlineModelConfig(mc.build()).build());
        System.out.println("modèle chargé en " + (System.currentTimeMillis() - t0) + " ms");

        OnlineStream flux;
        if (motsCles) {
            Set<Character> car = new HashSet<>();
            for (String l : Files.readAllLines(Paths.get(m + "/tokens.txt"), StandardCharsets.UTF_8)) {
                int e = l.lastIndexOf(' ');
                String j = e > 0 ? l.substring(0, e) : l;
                if (j.startsWith("<") || j.startsWith("#")) continue;
                for (char c : j.toCharArray()) car.add(c);
            }
            List<String> termes = Files.readAllLines(Paths.get(a[2]), StandardCharsets.UTF_8);
            String liste = MotsCles.pourFlux(termes, car);
            System.out.println("mots favorisés : " + liste.split("/").length + " formes pour " + termes.size() + " termes");
            // le casque appelle createStream(hotwords) ; l'API pour ordinateur ne l'expose pas, on passe par la même fonction native
            Field p = OnlineRecognizer.class.getDeclaredField("ptr");
            p.setAccessible(true);
            Method cs = OnlineRecognizer.class.getDeclaredMethod("createStream", long.class, String.class);
            cs.setAccessible(true);
            flux = new OnlineStream((Long) cs.invoke(r, p.getLong(r), liste));
        } else {
            flux = r.createStream();
        }
        final OnlineStream f = flux;

        final long[] horloge = {0};          // échantillons joués
        final long[] calcul = {0};           // nanosecondes passées à reconnaître
        final List<long[]> sorties = new ArrayList<>();
        final List<String> textes = new ArrayList<>();
        final int[] partiels = {0};
        Decoupage d = new Decoupage(new Decoupage.Moteur() {
            public void detecter(float[] e) {
                long t = System.nanoTime();
                vad.acceptWaveform(e);
                while (!vad.empty()) vad.pop();
                calcul[0] += System.nanoTime() - t;
            }

            public boolean parole() {
                return vad.isSpeechDetected();
            }

            public void oublier() {
                vad.reset();
            }

            public void ecouter(float[] e) {
                long t = System.nanoTime();
                f.acceptWaveform(e, 16000);
                while (r.isReady(f)) r.decode(f);
                calcul[0] += System.nanoTime() - t;
            }

            public String texte() {
                return r.getResult(f).getText();
            }

            public void recommencer() {
                r.reset(f);
            }
        }, new Decoupage.Sortie() {
            public void partiel(String t) {
                partiels[0]++;
            }

            public void entendu(String t) {
                sorties.add(new long[]{horloge[0]});
                if (System.getProperty("bavard") != null) System.out.println("  [" + horloge[0] / 1600 / 10.0 + " s] " + t);
                textes.add(t);
            }
        });

        File[] fs = new File(a[1]).listFiles((dd, n) -> n.endsWith(".wav"));
        Arrays.sort(fs);
        StringBuilder sb = new StringBuilder("{\n");
        double retard = 0, pire = 0;
        int nRetards = 0;
        long audio = 0;
        boolean premier = true;
        for (File fichier : fs) {
            byte[] b = Files.readAllBytes(fichier.toPath());
            int n = (b.length - 44) / 2;
            float[] s = new float[n + 8000];           // une demi-seconde de silence en plus entre deux phrases
            for (int i = 0; i < n; i++) s[i] = (short) ((b[44 + 2 * i] & 0xff) | (b[45 + 2 * i] << 8)) / 32768f;
            long debut = horloge[0];
            int finParole = n - 16000;                 // les fichiers finissent par une seconde de silence
            int avant = textes.size();
            for (int p = 0; p < s.length; p += 1600) {
                float[] bloc = Arrays.copyOfRange(s, p, Math.min(s.length, p + 1600));
                horloge[0] += bloc.length;
                d.recevoir(bloc);
            }
            audio += s.length;
            StringBuilder t = new StringBuilder();
            for (int k = avant; k < textes.size(); k++) {
                t.append(t.length() > 0 ? " " : "").append(textes.get(k));
                double r1 = (sorties.get(k)[0] - debut - finParole) / 16000.0;
                if (k == textes.size() - 1) {
                    retard += r1;
                    pire = Math.max(pire, r1);
                    nRetards++;
                }
            }
            sb.append(premier ? "" : ",\n").append(" \"").append(fichier.getName()).append("\": \"")
                    .append(t.toString().replace("\\", "\\\\").replace("\"", "\\\"")).append("\"");
            premier = false;
        }
        sb.append("\n}\n");
        Files.write(Paths.get(a[3]), sb.toString().getBytes(StandardCharsets.UTF_8));
        System.out.printf("%d fichiers, %d phrases rendues, %d résultats partiels%n", fs.length, textes.size(), partiels[0]);
        System.out.printf("fin de phrase rendue %.2f s après la fin de la parole en moyenne (pire %.2f s), hors temps de calcul%n", retard / Math.max(1, nRetards), pire);
        System.out.printf("calcul : %.1f s pour %.0f s de son (%.3f fois le temps réel sur ce PC)%n", calcul[0] / 1e9, audio / 16000.0, calcul[0] / 1e9 / (audio / 16000.0));
        f.release();
        r.release();
        vad.release();
    }
}
