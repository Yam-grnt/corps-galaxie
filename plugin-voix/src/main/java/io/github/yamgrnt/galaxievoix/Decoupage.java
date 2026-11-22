package io.github.yamgrnt.galaxievoix;

/**
 * Découpe le son du micro en phrases.
 *
 * Tant que personne ne parle, rien n'est transmis à la reconnaissance (le casque ne calcule pas pour du silence) :
 * on garde seulement la dernière demi-seconde. Dès qu'une voix est détectée, cette demi-seconde puis la suite sont
 * transmises ; au premier silence un peu long, la phrase est close et rendue.
 *
 * Cette classe ne dépend pas d'Android : le même code est essayé sur ordinateur avec des enregistrements.
 */
final class Decoupage {

    /** Ce que le découpage attend du moteur (détection de voix + reconnaissance). */
    interface Moteur {
        /** Donne du son à la détection de voix. */
        void detecter(float[] echantillons);

        /** Quelqu'un est-il en train de parler ? (redevient faux après un silence assez long) */
        boolean parole();

        /** Oublie ce que la détection de voix a accumulé (après une pause). */
        void oublier();

        /** Donne du son à la reconnaissance, qui avance autant qu'elle peut. */
        void ecouter(float[] echantillons);

        /** Ce qui a été reconnu depuis le début de la phrase. */
        String texte();

        /** Repart d'une phrase vide. */
        void recommencer();
    }

    interface Sortie {
        void partiel(String texte);

        void entendu(String texte);
    }

    static final int FREQUENCE = 16000;
    /** Son gardé d'avance : la détection de voix réagit avec un peu de retard, il ne faut pas perdre le début du mot. */
    private static final int AVANT = (int) (0.6f * FREQUENCE);
    /** Silence ajouté à la fin : le modèle travaille par tranches de 1,3 s, il lui faut de quoi finir la dernière. */
    private static final int QUEUE = (int) (1.6f * FREQUENCE);
    /** Une phrase ne dure pas plus longtemps que ça : au-delà, on rend ce qu'on a. */
    private static final int MAXIMUM = 14 * FREQUENCE;
    /** Après une pause (le guide vient de parler), on laisse passer la fin de sa voix. */
    private static final int REPRISE = (int) (0.25f * FREQUENCE);

    private final Moteur moteur;
    private final Sortie sortie;
    private final float[] anneau = new float[AVANT];
    private int position = 0;
    private int rempli = 0;
    private boolean enPhrase = false;
    private int duree = 0;
    private int aIgnorer = 0;
    private String dernier = "";

    Decoupage(Moteur moteur, Sortie sortie) {
        this.moteur = moteur;
        this.sortie = sortie;
    }

    /** À appeler quand l'écoute reprend après une pause : la phrase en cours est abandonnée. */
    void reprendre() {
        if (enPhrase) {
            moteur.recommencer();
        }
        moteur.oublier();
        enPhrase = false;
        rempli = 0;
        position = 0;
        dernier = "";
        aIgnorer = REPRISE;
    }

    /** Reçoit un bloc de son (16 kHz, mono, entre -1 et 1). */
    void recevoir(float[] bloc) {
        if (aIgnorer > 0) {
            aIgnorer -= bloc.length;
            return;
        }
        moteur.detecter(bloc);
        boolean parole = moteur.parole();
        if (!enPhrase) {
            if (!parole) {
                garder(bloc);
                return;
            }
            enPhrase = true;
            duree = 0;
            dernier = "";
            if (rempli > 0) {
                moteur.ecouter(avant());
            }
        }
        moteur.ecouter(bloc);
        duree += bloc.length;
        String t = moteur.texte().trim();
        if (!t.isEmpty() && !t.equals(dernier)) {
            dernier = t;
            sortie.partiel(t);
        }
        if (!parole || duree > MAXIMUM) {
            finir();
        }
    }

    private void finir() {
        moteur.ecouter(new float[QUEUE]);
        String t = moteur.texte().trim();
        moteur.recommencer();
        enPhrase = false;
        rempli = 0;
        position = 0;
        dernier = "";
        if (!t.isEmpty()) {
            sortie.entendu(t);
        }
    }

    private void garder(float[] bloc) {
        for (float v : bloc) {
            anneau[position] = v;
            position = (position + 1) % AVANT;
        }
        rempli = Math.min(AVANT, rempli + bloc.length);
    }

    /** Le contenu de l'anneau, du plus ancien au plus récent. */
    private float[] avant() {
        float[] s = new float[rempli];
        int debut = (position - rempli + AVANT) % AVANT;
        for (int i = 0; i < rempli; i++) {
            s[i] = anneau[(debut + i) % AVANT];
        }
        return s;
    }
}
