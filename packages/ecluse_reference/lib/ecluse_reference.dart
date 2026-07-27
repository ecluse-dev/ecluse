/// Données de référence publiques (géographie INSEE, rareté des professions
/// de santé, pyramide des âges, gazetteer de prénoms) pour Écluse.
///
/// Dart pur, chargement paresseux, zéro dépendance Flutter — l'accès aux
/// octets d'un asset est injecté par l'appelant via [AssetBytes].
library;

export 'src/age_rarity.dart';
export 'src/asset_bytes.dart';
export 'src/file_assets.dart';
export 'src/first_name_gazetteer.dart';
export 'src/geo_hierarchy.dart';
export 'src/normalize.dart';
export 'src/rarity_source.dart';
export 'src/reference.dart';
