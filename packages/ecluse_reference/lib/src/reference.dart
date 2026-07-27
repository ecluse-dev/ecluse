import 'age_rarity.dart';
import 'asset_bytes.dart';
import 'first_name_gazetteer.dart';
import 'geo_hierarchy.dart';
import 'rarity_source.dart';

/// Façade des données de référence Écluse.
///
/// Fournisseur de données, pas de logique métier : les lookups ambigus
/// (homonymes, prénom = mot courant) renvoient les candidats à l'appelant.
/// Ne masque rien et ne décide rien (cf. garde-fous §8).
class EcluseReference {
  EcluseReference(this._assets);

  final AssetBytes _assets;

  late final GeoHierarchy geo = GeoHierarchy(_assets);
  late final RaritySource rarity = RaritySource(_assets);
  late final AgeRarity age = AgeRarity(_assets);
  late final FirstNameGazetteer firstNames = FirstNameGazetteer(_assets);

  /// Réchauffe tous les assets (à appeler au démarrage sur mobile).
  Future<void> preload() async {
    await Future.wait(
        [geo.load(), rarity.load(), age.load(), firstNames.load()]);
  }
}
