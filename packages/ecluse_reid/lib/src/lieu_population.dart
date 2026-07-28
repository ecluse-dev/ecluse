import 'package:ecluse_reference/ecluse_reference.dart';

import 'qi.dart';

/// Résout la population correspondant à un QI `lieu`, selon son niveau
/// (convention : niveau lieu = niveau `GeoHierarchy.generalize` — 0=commune,
/// 1=département, 2=région, 3=grande zone, 4=France).
///
/// **Limitation documentée** : les niveaux 2 (région) et 3 (grande zone) ne
/// sont pas calculables ce jalon — `GeoHierarchy` n'expose aucune
/// agrégation de population par région/grande zone (pas d'itérateur public
/// de communes/départements), et l'ajouter dépasserait les extensions
/// pré-approuvées pour ce jalon (seule `populationOfDep` a été ajoutée).
/// Ces niveaux lèvent [ArgumentError] plutôt que de deviner silencieusement
/// une population.
int populationForLieu(EcluseReference ref, Qi lieu) {
  switch (lieu.level) {
    case 0:
      final pop = ref.geo.population(lieu.value);
      if (pop == null) {
        throw ArgumentError(
          'lieu: commune "${lieu.value}" inconnue ou sans population '
          '(cf. Commune.pmun).',
        );
      }
      return pop;
    case 1:
      return ref.geo.populationOfDep(lieu.value);
    case 2:
    case 3:
      throw ArgumentError(
        'lieu: niveau ${lieu.level} (région/grande zone) non calculable ce '
        "jalon (pas d'agrégation de population disponible dans "
        'ecluse_reference).',
      );
    default:
      return ref.age.totalPopulation; // niveau 4 (France) et au-delà
  }
}

/// Résout le code département à partir d'un QI `lieu`, pour le Cas A
/// (`medecinsCount(dep, ...)`/`professionCount(..., dep)` exigent un
/// département).
///
/// Niveaux supportés : 0 (commune, via `GeoHierarchy.communeByCode`), 1
/// (valeur = code département directement).
String depForLieu(EcluseReference ref, Qi lieu) {
  switch (lieu.level) {
    case 0:
      final commune = ref.geo.communeByCode(lieu.value);
      if (commune == null) {
        throw ArgumentError('lieu: commune "${lieu.value}" inconnue.');
      }
      return commune.dep;
    case 1:
      return lieu.value;
    default:
      throw ArgumentError(
        'lieu: niveau ${lieu.level} ne permet pas de résoudre un '
        'département (Cas A exige un lieu de niveau commune ou '
        'département).',
      );
  }
}
