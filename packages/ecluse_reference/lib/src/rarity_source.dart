import 'dart:convert';

import 'asset_bytes.dart';

/// Rareté par profession de santé × département.
///
/// Charge `rarity_medecins.json` + `rarity_professions.json` au premier
/// usage.
class RaritySource {
  RaritySource(this._assets);

  final AssetBytes _assets;

  Map<String, String>? _specialtyLabels;
  Map<String, Map<String, int>>? _medecinsByDep;
  Map<String, Map<String, int>>? _professions;

  /// Charge les assets si nécessaire. Idempotent.
  Future<void> load() async {
    if (_medecinsByDep != null) return;

    final medecinsBytes = await _assets('rarity_medecins.json');
    final medecins =
        jsonDecode(utf8.decode(medecinsBytes)) as Map<String, dynamic>;
    _specialtyLabels = (medecins['labels'] as Map<String, dynamic>)
        .map((code, label) => MapEntry(code, label as String));
    _medecinsByDep = (medecins['by_dep'] as Map<String, dynamic>).map(
      (dep, specs) => MapEntry(
        dep,
        (specs as Map<String, dynamic>)
            .map((code, n) => MapEntry(code, n as int)),
      ),
    );

    final professionsBytes = await _assets('rarity_professions.json');
    final professions =
        jsonDecode(utf8.decode(professionsBytes)) as Map<String, dynamic>;
    _professions = professions.map(
      (profession, byDep) => MapEntry(
        profession,
        (byDep as Map<String, dynamic>)
            .map((dep, n) => MapEntry(dep, n as int)),
      ),
    );
  }

  void _checkLoaded() {
    if (_medecinsByDep == null) {
      throw StateError(
        'RaritySource: appeler load() ou EcluseReference.preload() avant '
        'usage.',
      );
    }
  }

  int? medecinsCount(String dep, String specialtyCode) {
    _checkLoaded();
    return _medecinsByDep![dep]?[specialtyCode];
  }

  String? specialtyLabel(String code) {
    _checkLoaded();
    return _specialtyLabels![code];
  }

  Iterable<String> specialtyCodes() {
    _checkLoaded();
    return _specialtyLabels!.keys;
  }

  int? professionCount(String profession, String dep) {
    _checkLoaded();
    return _professions![profession]?[dep];
  }

  Iterable<String> professions() {
    _checkLoaded();
    return _professions!.keys;
  }
}
