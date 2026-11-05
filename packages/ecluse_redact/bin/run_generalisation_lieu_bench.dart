import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';

/// Mesure de la généralisation du lieu (P2-103). Mesure seulement : rien n'est
/// corrigé.
///
/// Le corpus de P2-93 ne généralisait jamais le lieu (une profession ou un âge
/// l'emportait toujours). On construit donc des documents synthétiques et on
/// applique la suggestion de lieu (retenue ou non : l'appelant choisit), puis
/// on compare, pour chacun :
/// - le F simulé par `ReidLoop` (`fAfter` de la suggestion) ;
/// - le F recalculé après `appliquerGeneralisations`, qui relit le texte
///   généralisé (« département 57 »).
///
/// Les communes sont réelles (géographie publique), tout le reste est inventé.
/// Déterministe : aucune graine, produit cartésien de listes fixes.
///
/// Usage (depuis `packages/ecluse_redact`) :
///   dart run bin/run_generalisation_lieu_bench.dart
const _communes = [
  'Thionville',
  'Vesoul',
  'Besançon',
  'Dole',
  'Nantes',
  'Lille',
  'Brest',
  'Orléans',
  'Rennes',
  'Dijon',
  'Metz',
  'Nancy',
  'Limoges',
  'Poitiers',
  'Angers',
  'Rioz',
  'Champagnole',
  'Beaune',
  'Gray',
  'Luxeuil-les-Bains',
  'Montbéliard',
  'Belfort',
  'Lons-le-Saunier',
  'Le Mans',
  'Saint-Étienne',
  'Aix-en-Provence',
  'Mont-de-Marsan',
];
const _professions = ['pneumologue', 'cardiologue', 'pédiatre', 'psychiatre'];
const _ages = [34, 58, 72, 91, 103];

/// Gabarits : lieu seul, lieu + âge, lieu + profession, les trois.
List<(String, String)> _documents() {
  final docs = <(String, String)>[];
  for (final c in _communes) {
    docs.add(('lieu', 'La personne habite à $c.'));
    for (final a in _ages) {
      docs.add(('lieu+age', 'Elle a $a ans et habite à $c.'));
    }
    for (final p in _professions) {
      docs.add(('lieu+profession', 'Le $p exerce à $c.'));
    }
    for (final p in _professions) {
      for (final a in _ages) {
        docs.add((
          'lieu+age+profession',
          'Ce $p de $a ans exerce à $c.',
        ));
      }
    }
  }
  return docs;
}

Future<void> main() async {
  final ref =
      EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
  await ref.preload();

  final docs = _documents();
  var avecSuggestion = 0;
  var suggestionLieu = 0;
  var retenueLieu = 0;
  var refus = 0;
  final parGabarit = <String, int>{};
  final statutApres = <String, int>{};
  final lieuRelu = <String, int>{};
  final qiLieu = <String, int>{};
  final comparaison = <String, int>{};
  final exemples = <String>[];
  final ecarts = <double>[];
  final bandesSimulees = <String, int>{};
  final bandesRecalculees = <String, int>{};
  final niveauApres = <String, int>{};

  for (final (gabarit, texte) in docs) {
    final base = await Ecluse.redact(texte, riskReference: ref);
    final sugg = base.risque!.suggestions;
    if (sugg.isEmpty) continue;
    avecSuggestion++;
    if (sugg.first.candidat.type == QiType.lieu) retenueLieu++;
    // L'application accepte n'importe quelle suggestion de la liste : on prend
    // celle du lieu, retenue ou non.
    final lieux = sugg.where((x) => x.candidat.type == QiType.lieu);
    if (lieux.isEmpty) continue;
    final s = lieux.first;
    suggestionLieu++;
    parGabarit[gabarit] = (parGabarit[gabarit] ?? 0) + 1;

    final simule = s.candidat.fAfter;
    final bandeSimulee = s.candidat.bandAfter?.name ?? '?';
    bandesSimulees[bandeSimulee] = (bandesSimulees[bandeSimulee] ?? 0) + 1;
    niveauApres['niveau ${s.candidat.to?.level}'] =
        (niveauApres['niveau ${s.candidat.to?.level}'] ?? 0) + 1;

    final RedactResult apres;
    try {
      apres = appliquerGeneralisations(base, [s], reference: ref);
    } on GeneralisationException {
      refus++;
      continue;
    }
    final ev = apres.risque!.evaluation;
    final st = ev.statut.name;
    statutApres[st] = (statutApres[st] ?? 0) + 1;
    final qis = ev.estimate;
    final recalcule = qis?.f;
    final bandeRec = qis?.band.name ?? st;
    bandesRecalculees[bandeRec] = (bandesRecalculees[bandeRec] ?? 0) + 1;

    // Le lieu généralisé (« département 57 ») est-il relu ? On regarde si le
    // texte généralisé contient encore un libellé de département et si un QI
    // de type lieu figure dans l'évaluation.
    final contientDep = RegExp(r'département \d').hasMatch(apres.maskedText);
    final garde = ev.qis.any((q) => q.type == QiType.lieu)
        ? 'un QI lieu relu'
        : 'aucun QI lieu relu';
    qiLieu[garde] = (qiLieu[garde] ?? 0) + 1;
    final cle = contientDep ? 'texte contient « département N »' : 'autre';
    lieuRelu[cle] = (lieuRelu[cle] ?? 0) + 1;

    String cat;
    if (recalcule == null) {
      cat = 'F recalculé absent ($st)';
    } else if (simule == null) {
      cat = 'F simulé absent';
    } else if ((recalcule - simule).abs() < 1e-9) {
      cat = 'F recalculé = F simulé';
    } else if (recalcule < simule) {
      cat = 'F recalculé < F simulé';
    } else {
      cat = 'F recalculé > F simulé';
    }
    comparaison[cat] = (comparaison[cat] ?? 0) + 1;
    if (recalcule != null && simule != null) {
      ecarts.add(recalcule / (simule == 0 ? 1 : simule));
    }
    if (exemples.length < 6 && cat != 'F recalculé = F simulé') {
      exemples.add('  « $texte » → « ${apres.maskedText} » : '
          'F avant ${s.candidat.fBefore}, simulé $simule, '
          'recalculé $recalcule ($st)');
    }
  }

  String med(List<double> v) {
    if (v.isEmpty) return 'n/a';
    final s = [...v]..sort();
    return s[s.length ~/ 2].toStringAsFixed(3);
  }

  stdout.writeln('${docs.length} documents synthétiques');
  stdout.writeln('  avec au moins une suggestion : $avecSuggestion');
  stdout.writeln('  suggestion de lieu présente (appliquée ici) : '
      '$suggestionLieu');
  stdout.writeln('  dont suggestion retenue (la première) sur le lieu : '
      '$retenueLieu');
  stdout.writeln('  par gabarit : ${_fmt(parGabarit)}');
  stdout.writeln('  refus à l\'application : $refus');
  stdout.writeln('  niveau cible simulé : ${_fmt(niveauApres)}');
  stdout.writeln('  bande simulée (fAfter) : ${_fmt(bandesSimulees)}');
  stdout.writeln('  statut après application : ${_fmt(statutApres)}');
  stdout.writeln('  bande recalculée : ${_fmt(bandesRecalculees)}');
  stdout.writeln('  texte généralisé : ${_fmt(lieuRelu)}');
  stdout.writeln(
      '  QI lieu dans l\'évaluation après application : ${_fmt(qiLieu)}');
  stdout.writeln('  F recalculé vs F simulé : ${_fmt(comparaison)}');
  stdout.writeln('  rapport recalculé / simulé (médian) : ${med(ecarts)}');
  for (final e in exemples) {
    stdout.writeln(e);
  }
}

String _fmt(Map<String, int> m) =>
    (m.keys.toList()..sort()).map((k) => '$k=${m[k]}').join(', ');
