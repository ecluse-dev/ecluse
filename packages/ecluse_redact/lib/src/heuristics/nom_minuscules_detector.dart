import 'package:ecluse_core/ecluse_core.dart';

import 'casse.dart';
import 'french_first_names.dart';

/// Noms de personnes dans un texte **sans aucune majuscule** (P2-119), ou
/// **sans aucune minuscule** (texte en capitales, P2-123).
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

  /// Particules d'un nom (« de la fontaine »), sous-ensemble des mots outils.
  static const Set<String> _particules = {'de', 'du', 'des', 'la', 'le'};

  /// Mots qui introduisent une personne juste avant son nom (P2-139).
  static const Set<String> _indicesPersonne = {
    'par', 'avec', 'chez', 'pour', 'contacter', 'appeler', 'rappeler', //
    'voir', 'prévenir', 'informer', 'référent', 'référente', //
  };

  /// Prénoms du gazetteer qui sont aussi des mots courants (P2-124, corpus
  /// témoin `generate_corpus_faux_amis_prenoms.py`). Seuls, suivis d'un
  /// adjectif ou d'un participe, ils ne sont pas masqués. Formes sans
  /// accents, comme le gazetteer.
  static const Set<String> _fauxAmis = {
    'aimee', 'ambre', 'aurore', 'blanche', 'capucine', 'celeste', 'claire', //
    'constance', 'fleur', 'hortense', 'iris', 'marguerite', 'marine', //
    'noel', 'pierre', 'rose', 'victoire', 'violette', //
  };

  /// Terminaisons d'adjectif ou de participe qui ne finissent presque jamais
  /// un patronyme. « -al » n'y est pas (Duval, Laval), « -ale » si ; « -eux »
  /// non plus (Mérieux : mesure P2-124 sur le corpus adversarial).
  static final RegExp _suffixeQualificatif =
      RegExp(r'(?:ée|ées|é|és|ante?s?|ive|ives|ifs?|inte|intes|ale|ales|aux)$');

  /// Adjectifs courts de couleur ou d'état, sans terminaison reconnaissable.
  static const Set<String> _adjectifs = {
    'pâle', 'vif', 'vive', 'clair', 'claire', 'foncé', 'sombre', 'net', //
    'nette', 'sèche', 'sec', 'blanc', 'noir', 'rouge', 'vert', 'bleu', //
    'jaune', 'gris', 'grise', 'beige', 'fine', 'fin', 'pur', 'pure', //
  };

  static bool _qualificatif(String mot) =>
      _adjectifs.contains(mot) || _suffixeQualificatif.hasMatch(mot);

  static String _plie(String mot) =>
      mot.split('').map((c) => _accents[c] ?? c).join();

  /// Texte analysé, en minuscules, s'il est sans majuscule ou en casse de
  /// phrase (P2-138, voir `casse.dart`) ou sans minuscule (P2-123 :
  /// « M. JULIEN CHEVRIER » fuyait à 35,6 %, mesure P2-121) ; `null` en casse
  /// ordinaire, laissée à `NameDetector`. Même longueur exigée : les
  /// positions valent pour l'original.
  static String? _base(String text) => switch (casseDuTexte(text)) {
        CasseTexte.ordinaire => null,
        CasseTexte.minuscules || CasseTexte.capitales => enMinuscules(text),
      };

  @override
  List<DetectedEntity> detect(String original) {
    final text = _base(original);
    if (text == null) return const [];
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

    /// Le mot [i] suit-il un champ (« : », « , ») ou un mot qui introduit
    /// une personne (« par », « avec »…), sur la même ligne ?
    bool apresIndice(int i) {
      if (i == 0) return false;
      final entre = text.substring(mots[i - 1].end, mots[i].start);
      if (entre.contains('\n')) return false;
      if (entre.contains(':') || entre.contains(',')) return true;
      return _blancs.hasMatch(entre) &&
          _indicesPersonne.contains(mots[i - 1].group(0)!);
    }

    void ajoute(int debut, int fin, double confiance) {
      trouves.add(DetectedEntity(
        type: EntityType.nom,
        start: mots[debut].start,
        end: mots[fin].end,
        value: original.substring(mots[debut].start, mots[fin].end),
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
            if (!contigu(fin, fin + 1)) break;
            final suivant = mots[fin + 1].group(0)!;
            if (!_outil(suivant)) {
              fin++;
              continue;
            }
            // Particule (« jean de la fontaine », P2-139) : gardée si un mot
            // non outil la suit, deux particules au plus.
            var j = fin + 1;
            var particules = 0;
            while (j < mots.length &&
                particules < 2 &&
                _particules.contains(mots[j].group(0)!) &&
                contigu(j - 1, j)) {
              j++;
              particules++;
            }
            if (particules == 0 ||
                j >= mots.length ||
                !contigu(j - 1, j) ||
                _outil(mots[j].group(0)!) ||
                // « de la part du service » n'est pas une particule.
                mots[j].group(0)! == 'part') {
              break;
            }
            fin = j;
            break; // un seul groupe de particules
          }
        }
        ajoute(i, fin, 0.7);
        i = fin + 1;
        continue;
      }
      // Initiale et patronyme après un champ ou un indice (« présent : t.
      // lefèvre », « suivi par j. martin ») (P2-139). Pas en tête de ligne :
      // « a. vérifier » est une énumération.
      if (mot.length == 1 &&
          i + 1 < mots.length &&
          contigu(i, i + 1, pointAdmis: true) &&
          text.substring(mots[i].end, mots[i + 1].start).startsWith('.') &&
          !_outil(mots[i + 1].group(0)!) &&
          apresIndice(i)) {
        ajoute(i, i + 1, 0.5);
        i += 2;
        continue;
      }
      // Ordre « nom prénom » après un indice (« dossier suivi par perrot
      // olivier ») (P2-139). Pas avec un faux ami : « humeur claire » après
      // « transmission : » (123 faux positifs au premier essai).
      if (!_prenom(mot) &&
          !_outil(mot) &&
          mot.length > 1 &&
          i + 1 < mots.length &&
          contigu(i, i + 1) &&
          _prenom(mots[i + 1].group(0)!) &&
          !_fauxAmis.contains(_plie(mots[i + 1].group(0)!)) &&
          apresIndice(i)) {
        ajoute(i, i + 1, 0.5);
        i += 2;
        continue;
      }
      if (_prenom(mot) &&
          contigu(i, i + 1) &&
          !_outil(mots[i + 1].group(0)!) &&
          !_civilites.contains(mots[i + 1].group(0)!)) {
        final suivant = mots[i + 1].group(0)!;
        if (!_qualificatif(suivant)) {
          ajoute(i, i + 1, 0.5);
          i += 2;
          continue;
        }
        // Prénom suivi d'un adjectif ou d'un participe (« rose pâle »,
        // « blanche agitée ») : pas un patronyme. Un faux ami (« rose ») est
        // alors un mot courant ; un autre prénom (« julien agité ») reste
        // masqué, seul.
        if (!_fauxAmis.contains(_plie(mot))) ajoute(i, i, 0.5);
        i += 2;
        continue;
      }
      i++;
    }
    return trouves;
  }
}
