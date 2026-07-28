/// Contrat d'honnêteté (spec §6) — DOIT apparaître dans chaque sortie
/// publique (`ReidEstimate.notes`, `ReidTrace.notes`/narration/audit).
const String honestyContract =
    'Estimation transparente, ordre de grandeur — calculée sur des données '
    "publiques françaises, sous hypothèse d'indépendance des critères. Aide "
    "à la décision, pas une garantie. Écluse réduit le risque, ne l'annule "
    'pas.';

/// Ajout obligatoire au Cas A (spec §6) — la classe d'équivalence réelle est
/// plus petite mais non quantifiée (rôle, commune précise).
const String honestyUpperBoundAddendum =
    'Borne haute : la précision réelle (commune, rôle) réduit davantage.';

/// Assemble les notes d'une sortie : contrat d'honnêteté toujours en
/// premier, puis l'addendum Cas A si [upperBound], puis les notes
/// spécifiques au calcul ([extra]) — hypothèses, repli, etc.
List<String> honestyNotes({
  required bool upperBound,
  List<String> extra = const [],
}) {
  return [
    honestyContract,
    if (upperBound) honestyUpperBoundAddendum,
    ...extra,
  ];
}
