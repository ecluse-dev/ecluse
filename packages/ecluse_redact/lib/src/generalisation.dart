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
      remplacements
          .add(_avecPreposition(texte, p.start, p.end, cible, libelle));
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

/// Un lieu généralisé en département garde la préposition de la commune :
/// « habite à Thionville » devenait « habite à département 57 » (P2-103,
/// P2-116). La préposition qui précède immédiatement est réécrite avec lui
/// (P2-132) : « à » → « dans le », « de » / « d' » → « du ». Rien d'autre
/// n'est touché ; sans préposition reconnue, seul le QI est remplacé.
(int, int, String) _avecPreposition(
    String texte, int debut, int fin, Qi cible, String libelle) {
  if (cible.type != QiType.lieu || !libelle.startsWith('département ')) {
    return (debut, fin, libelle);
  }
  final avant = texte.substring(0, debut);
  for (final (prep, remplacement) in const [
    ('à ', 'dans le '),
    ('À ', 'Dans le '),
    ('de ', 'du '),
    ('De ', 'Du '),
    ("d'", 'du '),
    ('d’', 'du '),
  ]) {
    if (!avant.endsWith(prep)) continue;
    final d = debut - prep.length;
    final mot = d == 0 ||
        !RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(texte[d - 1]);
    if (mot) return (d, fin, '$remplacement$libelle');
  }
  return (debut, fin, libelle);
}

/// Applique au texte masqué de [resultat] les généralisations de pathologie
/// [choisies] par l'appelant (P2-135), sur le modèle de
/// [appliquerGeneralisations] : **irréversible** (la mention d'origine
/// n'entre pas dans la table), jetons et table inchangés, refus en bloc
/// ([GeneralisationException]) d'une suggestion étrangère au résultat,
/// périmée, qui couvre un jeton, ou de deux suggestions sur la même mention.
/// Le rapport de risque est recalculé sur le texte rendu.
RedactResult appliquerGeneralisationsPathologie(
  RedactResult resultat,
  List<SuggestionPathologie> choisies, {
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
    if (!rapport.suggestionsPathologie.any((r) => identical(r, s))) {
      throw const GeneralisationException(
          'suggestion étrangère à ce résultat (périmée ou d\'un autre texte)');
    }
    final m = s.mention;
    if (m.start < 0 || m.end > texte.length || m.start >= m.end) {
      throw const GeneralisationException('position hors du texte masqué');
    }
    if (texte.substring(m.start, m.end) != m.text) {
      throw const GeneralisationException(
          'position périmée : le texte masqué a changé');
    }
    if (m.text.contains('[') || m.text.contains(']')) {
      throw const GeneralisationException(
          'position qui couvre un jeton : refusée');
    }
    remplacements.add((m.start, m.end, s.libelle));
  }
  remplacements.sort((a, b) => a.$1.compareTo(b.$1));
  for (var i = 1; i < remplacements.length; i++) {
    if (remplacements[i].$1 < remplacements[i - 1].$2) {
      throw const GeneralisationException(
          'deux suggestions sur la même mention, ou qui se chevauchent');
    }
  }
  final sortie = StringBuffer();
  var curseur = 0;
  for (final (debut, fin, libelle) in remplacements) {
    sortie
      ..write(texte.substring(curseur, debut))
      ..write(libelle);
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
