import 'asset_bytes.dart';
import 'gunzip.dart';
import 'normalize.dart';

/// Gazetteer de prénoms connus (INSEE).
///
/// **Signal de confiance, jamais masque autonome** : sert à relever la
/// confiance d'une détection déjà contextuelle (civilité + mot, prénom +
/// NOM…) dans `NameDetector`, ne déclenche pas seul (cf. garde-fous §8).
///
/// Charge `first_names.txt.gz` au premier usage.
class FirstNameGazetteer {
  FirstNameGazetteer(this._assets);

  final AssetBytes _assets;

  Set<String>? _names;

  /// Charge l'asset si nécessaire. Idempotent.
  Future<void> load() async {
    if (_names != null) return;

    final bytes = await _assets('first_names.txt.gz');
    _names = gunzipLines(bytes).where((line) => line.isNotEmpty).toSet();
  }

  bool isKnownFirstName(String token) {
    if (_names == null) {
      throw StateError(
        'FirstNameGazetteer: appeler load() ou EcluseReference.preload() '
        'avant usage.',
      );
    }
    return _names!.contains(normName(token));
  }
}
