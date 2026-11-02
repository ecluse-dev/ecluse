import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

import 'redact_result.dart';
import 'risque.dart';

/// Suggestion périmée, étrangère au résultat ou qui chevauche une autre :
/// refus explicite, jamais d'application partielle (règle 4 de `CLAUDE.md`).
final class GeneralisationException implements Exception {
  const GeneralisationException(this.message);

  final String message;

  @override
  String toString() => 'GeneralisationException: $message';
}

/// Applique au texte masqué de [resultat] les généralisations [choisies] par
/// l'appelant (P2-92, option B de `agent/specs/P2-03.md`).
///
/// Pourquoi une fonction à part : le moteur ne généralise jamais de lui-même
/// (décision P2-03 n° 1). C'est l'application, ou l'utilisateur, qui choisit
/// parmi `resultat.risque.suggestions` ce qu'elle accepte de perdre en
/// précision pour faire baisser le risque.
///
/// **Irréversible** : la valeur d'origine du QI (« Thionville », « 74 ans »)
/// n'entre pas dans [RedactResult.mapping] ; `Ecluse.restore` rendra la forme
/// généralisée (« département 57 », « 70-74 ans »). La table et les jetons
/// sont inchangés, donc la restauration des entités masquées reste exacte.
///
/// Refus ([GeneralisationException]) si une suggestion n'est pas l'une de
/// celles de `resultat.risque` (périmée ou venue d'un autre résultat), si sa
/// position ne retombe plus sur le texte du QI, si elle couvre un jeton, ou
/// si deux positions se chevauchent. Rien n'est appliqué dans ce cas.
///
/// Le rapport de risque du résultat rendu est recalculé sur le texte
/// généralisé : c'est lui qui dit si la généralisation a suffi.
RedactResult appliquerGeneralisations(
  RedactResult resultat,
  List<SuggestionPositionnee> choisies, {
  required EcluseReference reference,
}) {
  final rapport = resultat.risque;
  if (rapport == null) {
    throw const GeneralisationException(
        'aucun rapport de risque : appeler Ecluse.redact avec riskReference');
  }
  if (choisies.isEmpty) return resultat;

  final texte = resultat.maskedText;
  final remplacements = <(int, int, String)>[];
  for (final s in choisies) {
    if (!rapport.suggestions.any((r) => identical(r, s))) {
      throw const GeneralisationException(
          'suggestion étrangère à ce résultat (périmée ou d\'un autre texte)');
    }
    final cible = s.candidat.to;
    if (cible == null) {
      throw const GeneralisationException('suggestion sans palier cible');
    }
    final libelle = qiValueLabel(reference, cible);
    for (final p in s.positions) {
      if (p.start < 0 || p.end > texte.length || p.start >= p.end) {
        throw const GeneralisationException('position hors du texte masqué');
      }
      final extrait = texte.substring(p.start, p.end);
      if (extrait != p.text) {
        throw const GeneralisationException(
            'position périmée : le texte masqué a changé');
      }
      if (extrait.contains('[') || extrait.contains(']')) {
        throw const GeneralisationException(
            'position qui couvre un jeton : refusée');
      }
      remplacements.add((p.start, p.end, libelle));
    }
  }

  remplacements.sort((a, b) => a.$1.compareTo(b.$1));
  for (var i = 1; i < remplacements.length; i++) {
    if (remplacements[i].$1 < remplacements[i - 1].$2) {
      throw const GeneralisationException('positions qui se chevauchent');
    }
  }

  final sortie = StringBuffer();
  var curseur = 0;
  for (final (debut, fin, libelle) in remplacements) {
    sortie.write(texte.substring(curseur, debut));
    sortie.write(libelle);
    curseur = fin;
  }
  sortie.write(texte.substring(curseur));
  final generalise = sortie.toString();

  return RedactResult(
    maskedText: generalise,
    mapping: resultat.mapping,
    entities: resultat.entities,
    warnings: resultat.warnings,
    risque: evaluerRisque(reference, generalise),
    manuelles: resultat.manuelles,
  );
}
