import 'dart:convert';

import 'asset_bytes.dart';

/// Rareté par âge (pyramide des âges, France entière).
///
/// Charge `age_pyramide.json` au premier usage.
class AgeRarity {
  AgeRarity(this._assets);

  final AssetBytes _assets;

  Map<int, int>? _byAge;
  int? _total;

  /// Charge l'asset si nécessaire. Idempotent.
  Future<void> load() async {
    if (_byAge != null) return;

    final bytes = await _assets('age_pyramide.json');
    final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final byAge = raw.map((age, n) => MapEntry(int.parse(age), n as int));
    _byAge = byAge;
    _total = byAge.values.fold<int>(0, (sum, n) => sum + n);
  }

  void _checkLoaded() {
    if (_byAge == null) {
      throw StateError(
        'AgeRarity: appeler load() ou EcluseReference.preload() avant '
        'usage.',
      );
    }
  }

  int? countAtAge(int age) {
    _checkLoaded();
    return _byAge![age];
  }

  int get totalPopulation {
    _checkLoaded();
    return _total!;
  }

  double shareAtAge(int age) {
    final count = countAtAge(age);
    return count == null ? 0.0 : count / totalPopulation;
  }
}
