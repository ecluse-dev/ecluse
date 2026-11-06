import 'package:ecluse_core/ecluse_core.dart';

import 'french_first_names.dart';

/// Noms de personnes dans un texte **sans aucune majuscule** (P2-119).
///
/// Pourquoi un détecteur à part : [NameDetector] repère un nom à sa majuscule
/// initiale. Sur un texte tout en minuscules (dictée transcrite, message tapé
/// vite), la mesure P2-117 trouve 100 % de fuite des noms. Ce détecteur ne
/// s'active **que** si le texte n'a aucune lettre majuscule : sur un texte
/// ordinaire il ne rend rien, et le comportement d'Écluse y est inchangé par
/// construction.
///
/// Deux indices, plus prudents que ceux de [NameDetector] faute de casse :
///
/// 1. Une **civilité** (`m.`, `mme`, `mlle`, `monsieur`, `madame`,
///    `mademoiselle`, `dr`, `docteur`, `pr`, `professeur`) suivie d'un
///    prénom connu et d'un ou deux mots, ou d'un seul mot (le patronyme) →
///    confiance 0.7. « me » (maître) est exclu : en minuscules, c'est le
///    pronom (« il me dit »).
/// 2. Un **prénom connu** suivi d'un mot → confiance 0.5.
///
/// Dans les deux cas, un mot outil (« le », « est », « de »…) arrête le nom :
/// « madame la directrice » ou « monsieur est arrivé » ne donnent rien. Les
/// faux positifs restent possibles (« claire » adjectif suivi d'un nom) ;
/// en cas de doute on protège (voir `Ecluse.redact`), et `warnings` signale
/// de toute façon un texte sans majuscule (P2-118).
final class NomMinusculesDetector implements EntityDetector {
  const NomMinusculesDetector();

  @override
  EntityType get type => EntityType.nom;

  static final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _mot =
      RegExp(r"\p{Ll}[\p{Ll}'’-]*\p{Ll}|\p{Ll}", unicode: true);
  static final RegExp _blancs = RegExp(r'^[ \t  ]+$');

  static const Set<String> _civilites = {
    'm', 'mme', 'mlle', 'monsieur', 'madame', 'mademoiselle', //
    'dr', 'docteur', 'pr', 'professeur',
  };

  /// Civilités abrégées qu'un point peut suivre (« m. », « dr. »).
  static const Set<String> _abregees = {'m', 'mme', 'mlle', 'dr', 'pr'};

  /// Mots outils et verbes très courants : jamais un patronyme ici.
  static const Set<String> _motsOutils = {
    'le',
    'la',
    'les',
    'l',
    'un',
    'une',
    'des',
    'de',
    'du',
    'd',
    'au',
    'aux',
    'et',
    'ou',
    'ni',
    'mais',
    'donc',
    'car',
    'or',
    'que',
    'qui',
    'quoi',
    'dont',
    'où',
    'si',
    'ne',
    'pas',
    'plus',
    'très',
    'bien',
    'aussi',
    'à',
    'a',
    'en',
    'dans',
    'sur',
    'sous',
    'par',
    'pour',
    'avec',
    'sans',
    'chez',
    'vers',
    'entre',
    'depuis',
    'pendant',
    'avant',
    'après',
    'contre',
    'est',
    'sont',
    'était',
    'sera',
    'été',
    'être',
    'avoir',
    'ont',
    'avait',
    'va',
    'vont',
    'vient',
    'viendra',
    'fait',
    'dit',
    'peut',
    'doit',
    'veut',
    'il',
    'elle',
    'ils',
    'elles',
    'on',
    'nous',
    'vous',
    'je',
    'tu',
    'se',
    'sa',
    'son',
    'ses',
    'leur',
    'leurs',
    'ce',
    'cet',
    'cette',
    'ces',
    'notre',
    'votre',
    'mon',
    'ma',
    'mes',
    'lui',
    'y',
    'tout',
    'tous',
    'toute',
    'toutes',
    'même',
    'autre',
    'directeur',
    'directrice',
    'demain',
    'hier',
    'aujourd',
    'matin',
    'soir',
    'midi',
  };

  static const Map<String, String> _accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ÿ': 'y', 'ç': 'c', 'œ': 'oe', 'æ': 'ae', 'ñ': 'n', //
  };

  /// Prénoms du gazetteer qui, en minuscules, sont d'abord un sigle de soin :
  /// « eva » est l'échelle visuelle analogique (« score eva inchangé »). Seuls
  /// ceux qu'une mesure a montrés figurent ici (P2-119, corpus témoin).
  static const Set<String> _prenomsSigles = {'eva'};

  static bool _prenom(String mot) {
    if (_prenomsSigles.contains(mot)) return false;
    final plie = mot.split('').map((c) => _accents[c] ?? c).join();
    return frenchFirstNames.contains(mot) ||
        frenchFirstNames.contains(plie) ||
        (mot.contains('-') && mot.split('-').any(_prenom));
  }

  static bool _outil(String mot) => _motsOutils.contains(mot);

  @override
  List<DetectedEntity> detect(String text) {
    if (_majuscule.hasMatch(text)) return const [];
    final mots = _mot.allMatches(text).toList();
    final trouves = <DetectedEntity>[];

    /// Le mot d'indice [j] suit-il le mot [i] séparé seulement par des blancs
    /// (après un éventuel point d'abréviation si [pointAdmis]) ?
    bool contigu(int i, int j, {bool pointAdmis = false}) {
      if (j >= mots.length) return false;
      var entre = text.substring(mots[i].end, mots[j].start);
      if (pointAdmis && entre.startsWith('.')) entre = entre.substring(1);
      return _blancs.hasMatch(entre);
    }

    void ajoute(int debut, int fin, double confiance) {
      trouves.add(DetectedEntity(
        type: EntityType.nom,
        start: mots[debut].start,
        end: mots[fin].end,
        value: text.substring(mots[debut].start, mots[fin].end),
        confidence: confiance,
      ));
    }

    var i = 0;
    while (i < mots.length) {
      final mot = mots[i].group(0)!;
      if (_civilites.contains(mot) &&
          contigu(i, i + 1, pointAdmis: _abregees.contains(mot)) &&
          !_outil(mots[i + 1].group(0)!)) {
        var fin = i + 1;
        if (_prenom(mots[fin].group(0)!)) {
          for (var k = 0; k < 2; k++) {
            if (!contigu(fin, fin + 1) || _outil(mots[fin + 1].group(0)!)) {
              break;
            }
            fin++;
          }
        }
        ajoute(i, fin, 0.7);
        i = fin + 1;
        continue;
      }
      if (_prenom(mot) &&
          contigu(i, i + 1) &&
          !_outil(mots[i + 1].group(0)!) &&
          !_civilites.contains(mots[i + 1].group(0)!)) {
        ajoute(i, i + 1, 0.5);
        i += 2;
        continue;
      }
      i++;
    }
    return trouves;
  }
}
