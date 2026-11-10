import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_reference/ecluse_reference.dart'
    show FirstNameFrequencies, normName;

import 'etablissement_keywords.dart';
import 'french_first_names.dart';
import 'mots_neutres.dart';

/// Option `prenomsInsee` de `Ecluse.redact` (P2-149) : les effectifs de
/// l'INSEE et le seuil au-dessous duquel un mot n'est pas pris pour un prénom.
final class PrenomsInsee {
  /// [effectifs] doit être chargé (sinon [StateError] à l'appel de
  /// `Ecluse.redact`).
  const PrenomsInsee(this.effectifs, {this.seuil = seuilParDefaut});

  final FirstNameFrequencies effectifs;

  /// Effectif cumulé minimal (naissances depuis 1900).
  final int seuil;

  /// Choisi sur mesure (P2-149, `agent/specs/P2-148.md` § 6) : sur la prose
  /// du dépôt, 20 est le plus petit seuil qui écarte les mots courants
  /// observés (« Idem », 10 naissances) ; à 100, de vrais prénoms rares
  /// (« Łukasz », 90) repartaient en clair.
  static const int seuilParDefaut = 20;

  bool _retenu(String nomNormalise) =>
      effectifs.effectif(nomNormalise) >= seuil;
}

/// Prénom du fichier des prénoms de l'INSEE suivi d'un patronyme (P2-149).
///
/// Pourquoi : la liste écrite à la main ([frenchFirstNames]) ne connaît pas
/// « Souleymane » ni « Yaroslav » ; un tel prénom suivi d'un patronyme partait
/// en clair (dernier angle mort des noms du corpus adversarial, spec
/// `agent/specs/P2-148.md`). Le fichier de l'INSEE est une source
/// **indépendante du corpus** : l'ajouter ne revient pas à recopier les
/// valeurs du test.
///
/// Règle volontairement étroite, en casse ordinaire seulement :
/// - un mot en casse de titre (« Oleksandr ») que [estPrenom] reconnaît et que
///   la liste écrite à la main ne connaît pas (celle-ci est déjà traitée par
///   `NameDetector`, ce détecteur ne change rien pour elle) ;
/// - immédiatement suivi d'un patronyme en casse de titre ou en capitales
///   (« Guimard », « GUIMARD »), qui n'est ni un mot outil, ni un mot-clé
///   d'établissement, ni un adjectif ou un participe reconnaissable ;
/// - jamais un prénom seul, jamais l'ordre « Nom Prénom » : la liste de
///   l'INSEE contient des mots courants, une règle plus large les masquerait.
///
/// Confiance 0,6, comme l'appariement prénom + nom de `NameDetector`.
///
/// Pur : [estPrenom] reçoit un mot normalisé par `normName` (capitales, sans
/// accents) et répond sans effet de bord.
final class PrenomInseeDetector implements EntityDetector {
  PrenomInseeDetector(PrenomsInsee prenoms) : estPrenom = prenoms._retenu {
    if (!prenoms.effectifs.isLoaded) {
      throw StateError('PrenomInseeDetector : effectifs des prénoms non '
          'chargés (appeler FirstNameFrequencies.load() avant).');
    }
  }

  /// Vrai si le mot normalisé est un prénom retenu (effectif ≥ seuil).
  final bool Function(String nomNormalise) estPrenom;

  @override
  EntityType get type => EntityType.nom;

  static const String _majuscule =
      'A-ZÀ-ÖØ-ÞĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮİĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸŹŻŽ';
  static const String _minuscule = 'a-zß-öø-ÿā-ž';

  /// Prénom en casse de titre, composé admis (« Mei-Ling »), puis espaces
  /// horizontaux, puis patronyme en casse de titre ou en capitales. Le
  /// patronyme est lu en avance (`(?=…)`) : seul le prénom est consommé, pour
  /// qu'un mot rejeté (« Contacter ») ne masque pas la paire qui le suit
  /// (« Oleksandr Guimard »).
  static final RegExp _motif = RegExp('(?<![\\w$_minuscule$_majuscule\'’-])'
      '([$_majuscule][$_minuscule]+(?:-[$_majuscule][$_minuscule]+)?)'
      '(?=([ \\t\\u00A0]+)'
      '([$_majuscule](?:[$_minuscule]+(?:[\'’-][$_majuscule]?[$_minuscule]+)*'
      '|[$_majuscule]+(?:[\'’-][$_majuscule]+)*))'
      '(?![\\w$_minuscule$_majuscule]))');

  /// Mots du fichier de l'INSEE jamais pris pour un prénom par ce détecteur :
  /// - les prénoms que P2-68 a déjà écartés de la liste écrite à la main parce
  ///   qu'ils sont aussi des mots courants (« Mario Kart », « Manuel
  ///   d'utilisation », « en Jan et en Jun ») : la même raison vaut ici ;
  /// - les particules de nom (« Van Der Berg ») : elles ouvrent un patronyme,
  ///   pas un prénom.
  /// Formes en minuscules sans accents.
  static const Set<String> exclus = {
    'jan', 'jun', 'lou', 'said', 'manuel', 'mario', 'li', 'thi', //
    'van', 'von', 'der', 'den', 'del', 'della', 'ben', 'bin', 'bint', //
    'ibn', 'ter', 'ten', 'das', 'dos', 'des', 'les', //
  };

  static final RegExp _qualificatif = RegExp(r'(?:ée|ées|é|és)$');

  static final Set<String> _motsEtablissement = {
    for (final k in etablissementKeywords) k.toLowerCase(),
  };

  @override
  List<DetectedEntity> detect(String text) {
    final sortie = <DetectedEntity>[];
    for (final m in _motif.allMatches(text)) {
      final prenom = m.group(1)!;
      final patronyme = m.group(3)!;
      final fin = m.end + m.group(2)!.length + patronyme.length;
      if (!_prenomRetenu(prenom)) continue;
      if (!_patronymePlausible(patronyme)) continue;
      sortie.add(DetectedEntity(
        type: EntityType.nom,
        start: m.start,
        end: fin,
        value: text.substring(m.start, fin),
        confidence: 0.6,
      ));
    }
    return sortie;
  }

  bool _prenomRetenu(String mot) {
    final bas = mot.toLowerCase();
    if (exclus.contains(_plie(mot))) return false;
    // Déjà connu de la liste écrite à la main : affaire de `NameDetector`.
    for (final segment in bas.split('-')) {
      if (frenchFirstNames.contains(segment) ||
          frenchFirstNames.contains(_plie(segment))) {
        return false;
      }
    }
    return estPrenom(normName(mot));
  }

  bool _patronymePlausible(String mot) {
    final bas = mot.toLowerCase();
    if (mot.length < 2) return false;
    if (motsNeutres.contains(bas)) return false;
    if (_motsEtablissement.contains(bas)) return false;
    if (_qualificatif.hasMatch(bas)) return false;
    return true;
  }

  static String _plie(String s) => normName(s).toLowerCase();
}
