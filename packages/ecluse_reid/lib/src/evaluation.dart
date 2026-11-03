import 'package:ecluse_reference/ecluse_reference.dart';

import 'estimator.dart';
import 'honesty.dart';
import 'labels.dart';
import 'qi.dart';
import 'qi_extraction.dart';

/// Issue d'une évaluation (P2-03b). Trois états explicites, jamais confondus :
/// l'absence d'évaluation n'est pas un risque faible (règle 4 de CLAUDE.md).
enum EvaluationStatut {
  /// F a pu être estimé : voir [Evaluation.estimate].
  evalue,

  /// Aucun quasi-identifiant détecté. **Ce n'est pas un risque faible** : rien
  /// n'a été évalué.
  aucunQi,

  /// Des QI sont présents mais F ne peut pas être estimé : voir
  /// [Evaluation.motifs] (motifs lisibles).
  nonEvaluable,
}

/// Résultat **total** d'une évaluation : produit pour toute entrée, sans
/// exception.
///
/// Se distingue de [estimate] et de `ReidLoop`, qui lèvent `ArgumentError`
/// pour les entrées qu'ils ne savent pas traiter et dont le comportement n'a
/// pas changé.
class Evaluation {
  const Evaluation({
    required this.statut,
    required this.notes,
    this.qis = const [],
    this.spans = const [],
    this.estimate,
    this.motifs = const [],
    this.avertissements = const [],
  });

  final EvaluationStatut statut;

  /// QI retenus pour l'estimation (dédoublonnés : une même commune citée deux
  /// fois compte une fois).
  final List<Qi> qis;

  /// QI repérés dans le texte, avec position. Vide pour [evaluateQis].
  final List<QiSpan> spans;

  /// L'estimation, seulement si [statut] est [EvaluationStatut.evalue].
  final ReidEstimate? estimate;

  /// Pourquoi l'évaluation est impossible, seulement si [statut] est
  /// [EvaluationStatut.nonEvaluable].
  final List<String> motifs;

  /// Avertissements sur une évaluation faite (lieux ambigus).
  final List<String> avertissements;

  /// Contrat d'honnêteté (spec §6), **toujours en premier**, quel que soit le
  /// statut.
  final List<String> notes;
}

const String _noteAucunQi =
    'Aucun quasi-identifiant (profession de santé, lieu, âge) détecté : ce '
    "n'est pas un risque faible, c'est une absence d'évaluation. Un texte peut "
    'rester ré-identifiant par des indices que cette estimation ne couvre pas.';

String _libelles(EcluseReference ref, Iterable<Qi> qis) =>
    qis.map((q) => qiValueLabel(ref, q)).join(', ');

/// Évalue le risque de ré-identification d'un texte : extrait les QI avec
/// leur position ([extractQiSpans]) puis les estime ([evaluateQis]).
///
/// Ne lève jamais pour une entrée de l'utilisateur (texte quelconque).
Evaluation evaluateText(EcluseReference ref, String text) {
  final extraction = extractQiSpans(ref, text);
  final inutilisables = extraction.spans.where((s) => s.qi == null).toList();
  return _evaluer(
    ref,
    extraction.spans,
    [
      for (final s in extraction.spans)
        if (s.qi != null) s.qi!
    ],
    extraction.avertissements,
    [
      for (final s in inutilisables)
        'lieu « ${s.text} » ambigu (${s.candidats.length} communes de ce nom) '
            "et aucune n'a de population connue : le cas prudent est "
            'indéterminable',
    ],
  );
}

/// Évalue une combinaison de QI **structurés** (sans texte). Mêmes règles et
/// mêmes statuts que [evaluateText].
Evaluation evaluateQis(
  EcluseReference ref,
  List<Qi> qis, {
  List<String> avertissements = const [],
}) =>
    _evaluer(ref, const [], qis, avertissements, const []);

Evaluation _evaluer(
  EcluseReference ref,
  List<QiSpan> spans,
  List<Qi> qisBruts,
  List<String> avertissements,
  List<String> motifsPrealables,
) {
  // Une même valeur citée deux fois n'est pas un doublon.
  final qis = <Qi>[];
  for (final q in qisBruts) {
    if (!qis.contains(q)) qis.add(q);
  }

  if (qis.isEmpty && motifsPrealables.isEmpty) {
    return Evaluation(
      statut: EvaluationStatut.aucunQi,
      spans: spans,
      avertissements: avertissements,
      notes: honestyNotes(upperBound: false, extra: const [_noteAucunQi]),
    );
  }

  final motifs = <String>[...motifsPrealables];

  // L'estimation suppose UNE personne (une profession, un lieu, un âge).
  const pluriel = {
    QiType.profession: 'professions',
    QiType.lieu: 'lieux',
    QiType.age: 'âges',
  };
  for (final type in QiType.values) {
    final dumeme = qis.where((q) => q.type == type).toList();
    if (dumeme.length > 1) {
      motifs.add('plusieurs ${pluriel[type]} détectés '
          '(${_libelles(ref, dumeme)}) : l\'estimation suppose une seule '
          'personne');
    }
  }

  final lieux = qis.where((q) => q.type == QiType.lieu).toList();
  final aProfession = qis.any((q) => q.type == QiType.profession);
  final lieuUtile = lieux.any((q) => q.level == 0 || q.level == 1);
  if (aProfession && !lieuUtile) {
    motifs.add('profession sans lieu : une commune ou un département est '
        'requis pour retrouver les effectifs de la profession');
  }

  if (motifs.isNotEmpty) {
    return Evaluation(
      statut: EvaluationStatut.nonEvaluable,
      qis: qis,
      spans: spans,
      motifs: motifs,
      avertissements: avertissements,
      notes: honestyNotes(upperBound: false),
    );
  }

  final ReidEstimate e;
  try {
    e = estimate(ref, qis);
  } on ArgumentError catch (err) {
    // Filet : tout refus de l'estimateur devient un motif, jamais une
    // exception (population absente, niveau de lieu non calculable, code de
    // profession inconnu…).
    return Evaluation(
      statut: EvaluationStatut.nonEvaluable,
      qis: qis,
      spans: spans,
      motifs: [_motifRefus(ref, qis, err)],
      avertissements: avertissements,
      notes: honestyNotes(upperBound: false),
    );
  }
  if (e.f <= 0) {
    final nulle = _lieuxSansPopulation(ref, qis).where((c) => c.pmun == 0);
    return Evaluation(
      statut: EvaluationStatut.nonEvaluable,
      qis: qis,
      spans: spans,
      motifs: [
        if (nulle.isNotEmpty)
          'lieu « ${nulle.first.libelle} » : population légale nulle, F '
              "n'est pas défini"
        else
          "l'effectif estimé est nul (${_libelles(ref, qis)}) : âge, lieu ou "
              "profession hors des données de référence, F n'est pas défini",
      ],
      avertissements: avertissements,
      notes: honestyNotes(upperBound: false),
    );
  }
  // Le plafond « population du lieu » est ignoré quand elle est indisponible
  // (profession + commune agrégée ou Mayotte) : le dire.
  final sansPlafond =
      _lieuxSansPopulation(ref, qis).where((c) => c.pmun == null);
  return Evaluation(
    statut: EvaluationStatut.evalue,
    qis: qis,
    spans: spans,
    estimate: e,
    avertissements: [
      ...avertissements,
      for (final c in sansPlafond)
        'Lieu « ${c.libelle} » : population absente des données de référence ; '
            "l'effectif du département n'est pas plafonné à la population du "
            'lieu.',
    ],
    notes: e.notes,
  );
}

/// Communes (niveau 0) des QI dont la population est absente (`null`) ou
/// nulle (`0`).
Iterable<Commune> _lieuxSansPopulation(
    EcluseReference ref, List<Qi> qis) sync* {
  for (final q in qis.where((q) => q.type == QiType.lieu && q.level == 0)) {
    final c = ref.geo.communeByCode(q.value);
    if (c != null && (c.pmun == null || c.pmun == 0)) yield c;
  }
}

/// Motif lisible d'un refus de l'estimateur. Le message d'un `ArgumentError`
/// est écrit pour le développeur : on le remplace quand la cause est connue.
String _motifRefus(EcluseReference ref, List<Qi> qis, ArgumentError err) {
  final absentes = _lieuxSansPopulation(ref, qis).where((c) => c.pmun == null);
  if (absentes.isNotEmpty) {
    final c = absentes.first;
    final agregee = {'75', '69', '13'}.contains(c.dep);
    return 'lieu « ${c.libelle} » : population absente des données de '
        'référence '
        '${agregee ? "(commune agrégée, arrondissements non modélisés)" : "(Mayotte : recensement non intégré)"}'
        ' ; F ne peut pas être estimé sans profession';
  }
  return 'estimation impossible : ${err.message}';
}
