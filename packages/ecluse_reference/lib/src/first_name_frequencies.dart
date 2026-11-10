import 'asset_bytes.dart';
import 'gunzip.dart';
import 'normalize.dart';

/// Effectifs cumulés des prénoms de l'INSEE (naissances depuis 1900, deux
/// sexes), P2-149.
///
/// Pourquoi à côté de [FirstNameGazetteer] : la liste du gazetteer n'a pas
/// d'effectifs et garde tout prénom attribué au moins trois fois, donc des mots
/// courants (« Bilan », « Maison »). Un effectif permet un seuil : un mot
/// attribué une poignée de fois en un siècle n'est pas pris pour un prénom.
///
/// Charge `first_names_effectifs.tsv.gz` (produit par
/// `tools/build_prenoms_effectifs.py`) au premier usage ; hors de
/// `EcluseReference.preload`, comme les maladies rares : seul l'appelant qui
/// active l'option en paie le chargement.
class FirstNameFrequencies {
  FirstNameFrequencies(this._assets);

  static const assetKey = 'first_names_effectifs.tsv.gz';

  final AssetBytes _assets;

  Map<String, int>? _effectifs;

  /// Charge l'asset si nécessaire. Idempotent. Une ligne mal formée est
  /// refusée ([FormatException]) plutôt qu'ignorée.
  Future<void> load() async {
    if (_effectifs != null) return;
    final bytes = await _assets(assetKey);
    final table = <String, int>{};
    for (final ligne in gunzipLines(bytes)) {
      if (ligne.isEmpty || ligne.startsWith('#')) continue;
      final champs = ligne.split('\t');
      final n = champs.length == 2 ? int.tryParse(champs[1]) : null;
      if (n == null) {
        throw FormatException('$assetKey : ligne illisible', ligne);
      }
      table[champs[0]] = n;
    }
    _effectifs = table;
  }

  bool get isLoaded => _effectifs != null;

  /// Effectif cumulé du prénom [token] (normalisé par [normName]), 0 s'il est
  /// absent du fichier.
  int effectif(String token) {
    final table = _effectifs;
    if (table == null) {
      throw StateError('FirstNameFrequencies : appeler load() avant usage.');
    }
    return table[normName(token)] ?? 0;
  }
}
