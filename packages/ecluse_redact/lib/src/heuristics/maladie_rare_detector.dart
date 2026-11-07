import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_reference/ecluse_reference.dart' show RareDiseaseCatalog;
import 'package:ecluse_reid/ecluse_reid.dart'
    show PathologieMention, extrairePathologies;

import 'name_detector.dart';
import 'nom_minuscules_detector.dart';

/// Repère les maladies rares rattachées à une personne, pour les masquer
/// (P2-143).
///
/// Pourquoi seulement les maladies rares : décision du mainteneur du 7
/// novembre 2026. Une maladie rare (prévalence inférieure à 1 sur 2 000) avec
/// un département ou un âge suffit souvent à désigner une personne ; une
/// pathologie fréquente (diabète, BPCO) ne le fait pas seule et reste utile
/// au LLM : elle reste en clair, signalée par le rapport de risque.
///
/// Quelles mentions : celles **rattachées** à une personne (« atteinte
/// de », « suivie pour »), et aussi celles **non rattachées** dès que le texte
/// nomme quelqu'un (« Mme Odile Verdier. Diagnostic : maladie de Wilson ») :
/// le rattachement ne repère que des tournures, et une maladie rare qui part
/// en clair à côté d'un nom est la fuite la plus grave. Jamais une mention
/// **niée** (« pas de maladie de Huntington connue »), et rien dans un texte
/// sans nom de personne (« la maladie de Huntington est héréditaire ») : il
/// ne désigne personne. Le repérage est celui de `extrairePathologies`
/// (P2-125, mesuré sur le corpus P2-112).
///
/// Est rare, pour ce détecteur :
/// - une mention trouvée dans le catalogue Orphanet ;
/// - une mention de la table maison **aussi** présente dans Orphanet
///   (mucoviscidose, drépanocytose, phénylcétonurie, maladie de Gaucher) :
///   la table prime pour la catégorie (P2-113), pas pour la rareté ;
///   sauf les infections de [infectionsNonRares] ;
/// - une mention de la table suivie d'un éponyme (« myopathie de
///   Duchenne ») : le nom propre désigne une maladie précise, et le corpus
///   P2-112 l'annote comme rare.
///
/// Pur : le catalogue est chargé par l'appelant avant la construction ; un
/// catalogue non chargé est refusé ([StateError]) plutôt que de laisser
/// croire qu'aucune maladie rare n'a été trouvée.
final class MaladieRareDetector implements EntityDetector {
  MaladieRareDetector(this.catalogue) {
    if (!catalogue.isLoaded) {
      throw StateError('MaladieRareDetector : catalogue Orphanet non chargé '
          '(appeler RareDiseaseCatalog.load() avant).');
    }
  }

  final RareDiseaseCatalog catalogue;

  /// Mentions de la table que le catalogue connaît mais qui ne sont pas des
  /// maladies rares au sens de l'identification : Orphanet y décrit des
  /// formes rares, alors que la tuberculose et la bilharziose (fréquente
  /// chez les personnes venues de zones d'endémie) se voient couramment dans
  /// le médico-social. Choix de l'agent par délégation, à relire (P2-143).
  static const Set<String> infectionsNonRares = {'tuberculose', 'bilharziose'};

  bool _rare(PathologieMention m) {
    if (m.source == 'orphanet') return true;
    if (m.eponyme) return true;
    final t = m.text.toLowerCase();
    return !infectionsNonRares.contains(t) &&
        catalogue.codesForMention(m.text).isNotEmpty;
  }

  @override
  EntityType get type => EntityType.maladieRare;

  static const _noms = NameDetector();
  static const _nomsMinuscules = NomMinusculesDetector();

  /// Le texte nomme-t-il une personne ? Calculé seulement s'il reste une
  /// maladie rare non rattachée : le cas courant n'en paie pas le coût.
  static bool _nommeQuelquun(String text) =>
      _noms.detect(text).isNotEmpty || _nomsMinuscules.detect(text).isNotEmpty;

  @override
  List<DetectedEntity> detect(String text) {
    final rares = [
      for (final m in extrairePathologies(text, catalogue: catalogue))
        if (!m.niee && !m.adjectif && _rare(m)) m,
    ];
    if (rares.isEmpty) return const [];
    final avecPersonne =
        rares.every((m) => m.rattachee) || _nommeQuelquun(text);
    return [
      for (final m in rares)
        if (m.rattachee || avecPersonne)
          DetectedEntity(
            type: EntityType.maladieRare,
            start: m.start,
            end: m.end,
            value: text.substring(m.start, m.end),
            confidence: 0.8,
            tier: DetectorTier.reference,
          ),
    ];
  }
}
