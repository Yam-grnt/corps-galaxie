package io.github.yamgrnt.galaxievoix;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.util.Log;

import com.k2fsa.sherpa.onnx.EndpointConfig;
import com.k2fsa.sherpa.onnx.FeatureConfig;
import com.k2fsa.sherpa.onnx.OnlineModelConfig;
import com.k2fsa.sherpa.onnx.OnlineRecognizer;
import com.k2fsa.sherpa.onnx.OnlineRecognizerConfig;
import com.k2fsa.sherpa.onnx.OnlineStream;
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig;
import com.k2fsa.sherpa.onnx.SileroVadModelConfig;
import com.k2fsa.sherpa.onnx.Vad;
import com.k2fsa.sherpa.onnx.VadModelConfig;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Reconnaissance vocale embarquée pour « Le corps galaxie ».
 * Tout se passe dans le casque : aucun son n'est envoyé où que ce soit.
 *
 * Moteur : sherpa-onnx, modèle français en dictée libre (Kroko, zipformer en flux). Le vocabulaire du projet
 * (noms des objets, synonymes) est favorisé pendant la reconnaissance, sans y être limité : ce qui est dit d'autre
 * est rendu tel quel, et c'est le guide (guide.gd) qui décide quoi en faire.
 *
 * Vu de Godot (singleton « GalaxieVoix ») :
 *   preparer(vocabulaire)  charge le modèle (quelques secondes, hors du fil principal), puis signal « pret »
 *   ecouter(vocabulaire)   ouvre le micro ; vocabulaire = tableau JSON de mots à favoriser ; faux si impossible
 *   pause(oui)             suspend l'écoute sans rendre le micro (pendant que le guide parle)
 *   arreter()              rend le micro
 *   signaux : pret, partiel(texte), entendu(texte), erreur(message)
 */
public class GalaxieVoix extends GodotPlugin {
    private static final String TAG = "GalaxieVoix";
    private static final String DOSSIER = "galaxie-voix/";
    private static final int FREQUENCE = Decoupage.FREQUENCE;

    private volatile OnlineRecognizer reconnaisseur;
    private volatile Vad detecteur;
    private boolean avecMotsCles = false;
    private Set<Character> caracteres = null;
    private volatile boolean enPreparation = false;

    private final Object verrou = new Object();
    private Thread fil = null;
    private volatile boolean actif = false;
    private volatile boolean enPause = false;
    private String vocabulaire = "[]";
    private boolean aReprendre = false;

    public GalaxieVoix(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "GalaxieVoix";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("pret"));
        s.add(new SignalInfo("partiel", String.class));
        s.add(new SignalInfo("entendu", String.class));
        s.add(new SignalInfo("erreur", String.class));
        return s;
    }

    // ───────── préparation ─────────

    /** Charge le modèle sans bloquer l'affichage. Émet « pret » quand on peut écouter. */
    @UsedByGodot
    public void preparer(String vocabulaire) {
        if (reconnaisseur != null) {
            emitSignal("pret");
            return;
        }
        if (enPreparation) {
            return;
        }
        enPreparation = true;
        Thread t = new Thread(() -> {
            try {
                long debut = System.currentTimeMillis();
                charger();
                Log.i(TAG, "modèle chargé en " + (System.currentTimeMillis() - debut) + " ms"
                        + (avecMotsCles ? ", vocabulaire du projet favorisé" : ", sans vocabulaire favorisé"));
                enPreparation = false;
                emitSignal("pret");
            } catch (Throwable e) {
                enPreparation = false;
                Log.e(TAG, "modèle illisible", e);
                emitSignal("erreur", "modele : " + e.getMessage());
            }
        }, "galaxie-voix-modele");
        t.setPriority(Thread.NORM_PRIORITY - 1);
        t.start();
    }

    private void charger() throws Exception {
        AssetManager actifs = getActivity().getAssets();
        // un fichier manquant doit donner une erreur lisible, pas un arrêt brutal de la bibliothèque native
        for (String f : new String[]{"encoder.onnx", "decoder.onnx", "joiner.onnx", "tokens.txt", "silero_vad.onnx"}) {
            actifs.open(DOSSIER + f).close();
        }
        boolean aVocab = true;
        try {
            actifs.open(DOSSIER + "bpe.vocab").close();
            caracteres = lireCaracteres(actifs);
        } catch (Exception e) {
            aVocab = false;
        }

        SileroVadModelConfig silero = new SileroVadModelConfig();
        silero.setModel(DOSSIER + "silero_vad.onnx");
        silero.setThreshold(0.5f);
        silero.setMinSilenceDuration(0.55f);     // un silence plus long que ça clôt la phrase
        silero.setMinSpeechDuration(0.2f);
        silero.setWindowSize(512);
        silero.setMaxSpeechDuration(20.0f);
        VadModelConfig cv = new VadModelConfig();
        cv.setSileroVadModelConfig(silero);
        cv.setSampleRate(FREQUENCE);
        cv.setNumThreads(1);
        cv.setProvider("cpu");
        detecteur = new Vad(actifs, cv);

        OnlineRecognizer r = null;
        if (aVocab) {
            try {
                r = new OnlineRecognizer(actifs, configuration(true));
                avecMotsCles = true;
            } catch (Throwable e) {
                Log.w(TAG, "vocabulaire favorisé indisponible, reconnaissance simple", e);
            }
        }
        if (r == null) {
            r = new OnlineRecognizer(actifs, configuration(false));
            avecMotsCles = false;
        }
        reconnaisseur = r;
    }

    private static OnlineRecognizerConfig configuration(boolean motsCles) {
        OnlineTransducerModelConfig transducteur = new OnlineTransducerModelConfig();
        transducteur.setEncoder(DOSSIER + "encoder.onnx");
        transducteur.setDecoder(DOSSIER + "decoder.onnx");
        transducteur.setJoiner(DOSSIER + "joiner.onnx");
        OnlineModelConfig modele = new OnlineModelConfig();
        modele.setTransducer(transducteur);
        modele.setTokens(DOSSIER + "tokens.txt");
        modele.setNumThreads(2);
        modele.setProvider("cpu");
        modele.setModelType("zipformer2");
        OnlineRecognizerConfig c = new OnlineRecognizerConfig();
        c.setFeatConfig(new FeatureConfig(FREQUENCE, 80, 0.0f));
        c.setEndpointConfig(new EndpointConfig());
        c.setEnableEndpoint(false);      // la fin de phrase est décidée par la détection de voix (Decoupage)
        if (motsCles) {
            modele.setModelingUnit("bpe");
            modele.setBpeVocab(DOSSIER + "bpe.vocab");
            c.setDecodingMethod("modified_beam_search");
            c.setMaxActivePaths(4);
            c.setHotwordsScore(2.0f);
        } else {
            c.setDecodingMethod("greedy_search");
        }
        c.setModelConfig(modele);
        return c;
    }

    /** Les caractères que le modèle sait écrire : un mot qui en contient d'autres ne peut pas être favorisé. */
    private static Set<Character> lireCaracteres(AssetManager actifs) throws Exception {
        Set<Character> s = new HashSet<>();
        try (InputStream in = actifs.open(DOSSIER + "tokens.txt");
             BufferedReader l = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            String ligne;
            while ((ligne = l.readLine()) != null) {
                int e = ligne.lastIndexOf(' ');
                String jeton = e > 0 ? ligne.substring(0, e) : ligne;
                if (jeton.startsWith("<") || jeton.startsWith("#")) {
                    continue;
                }
                for (int i = 0; i < jeton.length(); i++) {
                    s.add(jeton.charAt(i));
                }
            }
        }
        return s;
    }

    // ───────── écoute ─────────

    /** Ouvre le micro et commence à écouter. Rend faux si le micro est inaccessible ou le modèle pas encore chargé. */
    @UsedByGodot
    public boolean ecouter(String vocabulaire) {
        this.vocabulaire = vocabulaire == null ? "[]" : vocabulaire;
        enPause = false;
        aReprendre = false;
        return demarrer();
    }

    @SuppressLint("MissingPermission")
    private boolean demarrer() {
        if (reconnaisseur == null || detecteur == null) {
            return false;
        }
        arreterFil();
        if (getActivity().checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            emitSignal("erreur", "micro : permission refusée");
            return false;
        }
        AudioRecord micro = ouvrirMicro();
        if (micro == null) {
            emitSignal("erreur", "micro : indisponible");
            return false;
        }
        final String motsCles = avecMotsCles ? MotsCles.pourFlux(lireVocabulaire(vocabulaire), caracteres) : "";
        synchronized (verrou) {
            actif = true;
            fil = new Thread(() -> boucle(micro, motsCles), "galaxie-voix-ecoute");
            fil.start();
        }
        return true;
    }

    @SuppressLint("MissingPermission")
    private static AudioRecord ouvrirMicro() {
        int mini = AudioRecord.getMinBufferSize(FREQUENCE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT);
        int taille = Math.max(mini > 0 ? mini * 2 : 0, FREQUENCE);      // au moins une demi-seconde d'avance
        for (int source : new int[]{MediaRecorder.AudioSource.VOICE_RECOGNITION, MediaRecorder.AudioSource.MIC}) {
            try {
                AudioRecord m = new AudioRecord(source, FREQUENCE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, taille);
                if (m.getState() == AudioRecord.STATE_INITIALIZED) {
                    return m;
                }
                m.release();
            } catch (Exception e) {
                Log.w(TAG, "micro (source " + source + ")", e);
            }
        }
        return null;
    }

    private static List<String> lireVocabulaire(String json) {
        List<String> l = new ArrayList<>();
        try {
            JSONArray a = new JSONArray(json);
            for (int i = 0; i < a.length(); i++) {
                l.add(a.optString(i, ""));
            }
        } catch (Exception e) {
            Log.w(TAG, "vocabulaire illisible", e);
        }
        return l;
    }

    /** Le fil d'écoute : lit le micro, découpe en phrases, reconnaît. */
    private void boucle(AudioRecord micro, String motsCles) {
        final OnlineRecognizer r = reconnaisseur;
        final Vad v = detecteur;
        OnlineStream flux = null;
        try {
            if (!motsCles.isEmpty()) {
                try {
                    flux = r.createStream(motsCles);
                } catch (Throwable e) {
                    Log.w(TAG, "vocabulaire refusé par le moteur", e);
                }
            }
            if (flux == null) {
                flux = r.createStream("");
            }
            final OnlineStream f = flux;
            v.reset();
            Decoupage decoupage = new Decoupage(new Decoupage.Moteur() {
                @Override
                public void detecter(float[] e) {
                    v.acceptWaveform(e);
                    while (!v.empty()) {
                        v.pop();
                    }
                }

                @Override
                public boolean parole() {
                    return v.isSpeechDetected();
                }

                @Override
                public void oublier() {
                    v.reset();
                }

                @Override
                public void ecouter(float[] e) {
                    f.acceptWaveform(e, FREQUENCE);
                    while (r.isReady(f)) {
                        r.decode(f);
                    }
                }

                @Override
                public String texte() {
                    return r.getResult(f).getText();
                }

                @Override
                public void recommencer() {
                    r.reset(f);
                }
            }, new Decoupage.Sortie() {
                @Override
                public void partiel(String t) {
                    emitSignal("partiel", t);
                }

                @Override
                public void entendu(String t) {
                    Log.i(TAG, "entendu : " + t);
                    emitSignal("entendu", t);
                }
            });

            micro.startRecording();
            if (micro.getRecordingState() != AudioRecord.RECORDSTATE_RECORDING) {
                throw new IllegalStateException("le micro est pris par une autre application");
            }
            short[] tampon = new short[FREQUENCE / 10];      // un dixième de seconde
            boolean etaitEnPause = false;
            while (actif) {
                int n = micro.read(tampon, 0, tampon.length);
                if (n < 0) {
                    throw new IllegalStateException("lecture du micro impossible (" + n + ")");
                }
                if (n == 0) {
                    continue;
                }
                if (enPause) {
                    etaitEnPause = true;      // on lit quand même, pour ne pas garder de vieux son en réserve
                    continue;
                }
                if (etaitEnPause) {
                    etaitEnPause = false;
                    decoupage.reprendre();
                }
                float[] bloc = new float[n];
                for (int i = 0; i < n; i++) {
                    bloc[i] = tampon[i] / 32768.0f;
                }
                decoupage.recevoir(bloc);
            }
        } catch (Throwable e) {
            Log.e(TAG, "écoute interrompue", e);
            if (actif) {
                actif = false;
                emitSignal("erreur", "micro : " + e.getMessage());
            }
        } finally {
            try {
                micro.stop();
            } catch (Exception ignore) {
            }
            micro.release();
            if (flux != null) {
                flux.release();
            }
        }
    }

    /** Suspend l'écoute sans rendre le micro (pendant que le guide parle, ou casque retiré). */
    @UsedByGodot
    public void pause(boolean oui) {
        enPause = oui;
    }

    /** Arrête d'écouter et rend le micro. Le modèle reste chargé : réécouter est immédiat. */
    @UsedByGodot
    public void arreter() {
        aReprendre = false;
        arreterFil();
    }

    /** Vrai si le micro est ouvert. */
    @UsedByGodot
    public boolean ecoute() {
        return actif;
    }

    private void arreterFil() {
        Thread t;
        synchronized (verrou) {
            actif = false;
            t = fil;
            fil = null;
        }
        if (t != null && t != Thread.currentThread()) {
            try {
                t.join(2500);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    // ───────── vie de l'application ─────────

    /** L'application passe en arrière-plan : le micro est rendu au système. */
    @Override
    public void onMainPause() {
        boolean ecoutait;
        synchronized (verrou) {
            ecoutait = fil != null && actif;
        }
        if (ecoutait) {
            arreterFil();
            aReprendre = true;
        }
    }

    /** Elle revient : on reprend l'écoute là où elle en était. */
    @Override
    public void onMainResume() {
        if (aReprendre) {
            aReprendre = false;
            if (!demarrer()) {
                Log.w(TAG, "reprise de l'écoute impossible");
            }
        }
    }

    @Override
    public void onMainDestroy() {
        arreter();
        OnlineRecognizer r = reconnaisseur;
        Vad v = detecteur;
        reconnaisseur = null;
        detecteur = null;
        if (r != null) {
            r.release();
        }
        if (v != null) {
            v.release();
        }
    }
}
