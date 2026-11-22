package io.github.yamgrnt.galaxievoix;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Prépare la liste des mots à favoriser pendant la reconnaissance (« hotwords » de sherpa-onnx) à partir du
 * vocabulaire du projet : noms des objets du modèle et synonymes, tels que le guide les fournit.
 *
 * Le modèle écrit « l’axone » en un seul mot, avec une apostrophe courbe : on ajoute donc les formes élidées.
 * Cette classe ne dépend pas d'Android : le même code est essayé sur ordinateur.
 */
final class MotsCles {
    private static final String VOYELLES = "aeiouyhéèêëàâîïôöûüœæ";

    private MotsCles() {
    }

    /**
     * @param termes     mots ou groupes de mots, écrits normalement (« mitochondrie », « globule rouge », « ADN »)
     * @param caracteres caractères que le modèle sait écrire (null : pas de vérification)
     * @return les formes à favoriser, une par élément
     */
    static Set<String> formes(List<String> termes, Set<Character> caracteres) {
        Set<String> s = new LinkedHashSet<>();
        for (String brut : termes) {
            if (brut == null) {
                continue;
            }
            String t = brut.replace('\'', '’').replace('-', ' ').replaceAll("\\s+", " ").trim();
            if (t.length() < 2 || t.startsWith("[") || t.contains("/") || t.contains(":") || !connu(t, caracteres)) {
                continue;
            }
            s.add(t);
            if (VOYELLES.indexOf(Character.toLowerCase(t.charAt(0))) >= 0) {
                s.add("l’" + t);
            }
        }
        return s;
    }

    /** La liste sous la forme attendue par sherpa-onnx pour un flux : formes séparées par « / ». */
    static String pourFlux(List<String> termes, Set<Character> caracteres) {
        return String.join("/", formes(termes, caracteres));
    }

    private static boolean connu(String t, Set<Character> caracteres) {
        if (caracteres == null) {
            return true;
        }
        for (int i = 0; i < t.length(); i++) {
            char c = t.charAt(i);
            if (c != ' ' && !caracteres.contains(c)) {
                return false;
            }
        }
        return true;
    }
}
