import 'asset_bytes.dart';
import 'gunzip.dart';
import 'normalize.dart';

/// Catalogue des maladies rares Orphanet (P2-115).
///
/// Lit `patho_orphanet.tsv.gz`, produit par `tools/build_orphanet_asset.py`
/// à partir du pack de nomenclature Orphanet en français (CC BY 4.0, voir
/// `NOTICE`). Une ligne par entité : ORPHAcode, catégorie (parent
/// préférentiel Orphanet), nom, puis les mentions retenues.
///
/// **Fournisseur de données, pas détecteur** : il ne cherche rien dans un
/// texte. Une mention partagée par plusieurs entités rend tous les
/// ORPHAcodes ; c'est à l'appelant de trancher (cf. [EcluseReference]).
/// L'appariement dans le texte libre attend un corpus pour être mesuré
/// (P2-112), d'où cette séparation.
///
/// **Refus explicite** : un asset vide ou mal formé lève une
/// [FormatException] au chargement, plutôt qu'un catalogue vide qui
/// laisserait croire qu'aucune maladie rare n'est connue.
class RareDiseaseCatalog {
  RareDiseaseCatalog(this._assets);

  static const assetKey = 'patho_orphanet.tsv.gz';

  final AssetBytes _assets;

  Map<int, ({String category, String name})>? _entities;
  Map<String, Set<int>>? _mentions;
  String? _version;

  /// Charge l'asset si nécessaire. Idempotent.
  Future<void> load() async {
    if (_entities != null) return;

    final lines = gunzipLines(await _assets(assetKey));
    final entities = <int, ({String category, String name})>{};
    final mentions = <String, Set<int>>{};
    String? version;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        version ??= line.substring(1).trim();
        continue;
      }
      final fields = line.split('\t');
      final code = int.tryParse(fields.first);
      if (fields.length < 4 || code == null) {
        throw FormatException(
            '$assetKey : ligne ${i + 1} mal formée (ORPHAcode, catégorie, '
            'nom et au moins une mention attendus)');
      }
      if (entities.containsKey(code)) {
        throw FormatException('$assetKey : ORPHAcode $code en double');
      }
      entities[code] = (category: fields[1], name: fields[2]);
      for (final mention in fields.skip(3)) {
        final key = normName(mention);
        if (key.isEmpty) continue;
        (mentions[key] ??= <int>{}).add(code);
      }
    }
    if (entities.isEmpty) {
      throw const FormatException('$assetKey : aucune entité');
    }
    _entities = entities;
    _mentions = mentions;
    _version = version;
  }

  Map<int, ({String category, String name})> get _e {
    final e = _entities;
    if (e == null) {
      throw StateError('RareDiseaseCatalog: appeler load() avant usage.');
    }
    return e;
  }

  /// En-tête de l'asset (source, date d'extraction, licence), ou `null`.
  String? get version {
    _e;
    return _version;
  }

  /// Vrai une fois [load] terminé. Permet à un appelant synchrone (rapport
  /// de risque) de n'utiliser le catalogue que s'il a été chargé.
  bool get isLoaded => _entities != null;

  /// Nombre d'entités chargées.
  int get length => _e.length;

  /// Catégorie Orphanet d'un ORPHAcode (« Maladie neurologique rare »…),
  /// ou `null` s'il n'est pas dans le catalogue.
  String? categoryOf(int orphaCode) => _e[orphaCode]?.category;

  /// Nom Orphanet d'un ORPHAcode, ou `null`.
  String? nameOf(int orphaCode) => _e[orphaCode]?.name;

  /// ORPHAcodes associés à une mention, comparée après [normName].
  /// Vide si la mention est inconnue ; plusieurs codes si elle est ambiguë.
  Set<int> codesForMention(String mention) {
    _e;
    return Set.unmodifiable(_mentions![normName(mention)] ?? const <int>{});
  }

  /// Toutes les mentions normalisées, pour un appariement futur.
  Iterable<String> get mentions {
    _e;
    return _mentions!.keys;
  }
}
