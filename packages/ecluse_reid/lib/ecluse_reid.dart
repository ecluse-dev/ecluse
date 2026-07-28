/// Boucle de ré-identification (Jalon 3) — estime la taille de la classe
/// d'équivalence d'une combinaison de quasi-identifiants (profession de
/// santé, lieu, âge) et suggère une généralisation, sur données publiques
/// françaises (`ecluse_reference`).
///
/// Dart pur, zéro dépendance native. Estime et informe ; ne masque rien et
/// ne décide rien seul (l'épuisement rend la main à l'humain, spec
/// §5/§10).
library;

export 'src/age_bands.dart';
export 'src/estimator.dart';
export 'src/generalizer.dart';
export 'src/honesty.dart';
export 'src/labels.dart';
export 'src/lieu_population.dart';
export 'src/profession_rarity.dart';
export 'src/qi.dart';
export 'src/qi_extraction.dart';
export 'src/reid_loop.dart';
export 'src/reid_trace.dart';
export 'src/risk_band.dart';
