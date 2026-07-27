import 'dart:convert';

import 'asset_bytes.dart';
import 'gunzip.dart';
import 'normalize.dart';

/// Une commune française (COG INSEE).
class Commune {
  const Commune(
      this.code, this.libelle, this.norm, this.dep, this.reg, this.pmun);

  /// Code INSEE 5 caractères (ex. `"57672"`).
  final String code;

  /// Nom accentué (ex. `"Thionville"`).
  final String libelle;

  /// Nom normalisé pour lookup (ex. `"THIONVILLE"`).
  final String norm;

  /// Code département (ex. `"57"`, `"2A"`, `"971"`).
  final String dep;

  /// Code région (ex. `"44"`).
  final String reg;

  /// Population municipale. `null` pour ~20 communes (Paris/Lyon/Marseille —
  /// population sous leurs arrondissements — et communes de Mayotte au
  /// recensement retardé).
  final int? pmun;
}

/// Regroupement des 18 codes REG en 5 grandes zones géographiques.
///
/// Non fourni par les données sources : table définie dans ce package
/// (cf. spec Jalon 2 §4.1). Découpage par quadrant de la France
/// métropolitaine + Outre-mer.
const Map<String, String> _grandeZone = {
  // Nord : Île-de-France, Hauts-de-France, Normandie
  '11': 'Nord', '32': 'Nord', '28': 'Nord',
  // Est : Grand Est, Bourgogne-Franche-Comté, Auvergne-Rhône-Alpes
  '44': 'Est', '27': 'Est', '84': 'Est',
  // Sud : Provence-Alpes-Côte d'Azur, Occitanie, Corse
  '93': 'Sud', '76': 'Sud', '94': 'Sud',
  // Ouest : Bretagne, Pays de la Loire, Nouvelle-Aquitaine, Centre-Val de Loire
  '53': 'Ouest', '52': 'Ouest', '75': 'Ouest', '24': 'Ouest',
  // Outre-mer : Guadeloupe, Martinique, Guyane, La Réunion, Mayotte
  '01': 'Outre-mer', '02': 'Outre-mer', '03': 'Outre-mer',
  '04': 'Outre-mer', '06': 'Outre-mer',
};

/// Géographie communale : commune → département → région, et population.
///
/// Charge `geo_communes.csv.gz` + `geo_hierarchie.json` au premier usage.
class GeoHierarchy {
  GeoHierarchy(this._assets);

  final AssetBytes _assets;

  Map<String, Commune>? _byCode;
  Map<String, List<String>>? _byNorm;
  Map<String, String>? _depReg;
  Map<String, String>? _regLabel;

  /// Charge les assets si nécessaire. Idempotent.
  Future<void> load() async {
    if (_byCode != null) return;

    final csvBytes = await _assets('geo_communes.csv.gz');
    final lines = gunzipLines(csvBytes);
    final byCode = <String, Commune>{};
    final byNorm = <String, List<String>>{};
    for (final line in lines.skip(1)) {
      if (line.isEmpty) continue;
      final fields = line.split(';');
      final code = fields[0];
      final dep = fields[1];
      final reg = fields[2];
      final pmunRaw = fields[3];
      final norm = fields[4];
      final libelle = fields[5];
      final commune = Commune(
        code,
        libelle,
        norm,
        dep,
        reg,
        pmunRaw.isEmpty ? null : int.parse(pmunRaw),
      );
      byCode[code] = commune;
      byNorm.putIfAbsent(norm, () => []).add(code);
    }
    _byCode = byCode;
    _byNorm = byNorm;

    final hierBytes = await _assets('geo_hierarchie.json');
    final hier = jsonDecode(utf8.decode(hierBytes)) as Map<String, dynamic>;
    _depReg = (hier['dep_reg'] as Map<String, dynamic>)
        .map((dep, reg) => MapEntry(dep, reg as String));
    _regLabel = (hier['reg_label'] as Map<String, dynamic>)
        .map((reg, label) => MapEntry(reg, label as String));
  }

  /// Lève une erreur si [load] n'a pas encore été appelé — distingue
  /// « pas chargé » de « pas trouvé » plutôt que de renvoyer `null` pour
  /// les deux cas.
  void _checkLoaded() {
    if (_byCode == null) {
      throw StateError(
        'GeoHierarchy: appeler load() ou EcluseReference.preload() avant '
        'usage.',
      );
    }
  }

  Commune? communeByCode(String code) {
    _checkLoaded();
    return _byCode![code];
  }

  /// Recherche par nom brut (non normalisé). Candidats homonymes possibles.
  List<Commune> communesByName(String rawName) {
    _checkLoaded();
    final codes = _byNorm![normName(rawName)] ?? const [];
    return codes.map((code) => _byCode![code]!).toList();
  }

  int? population(String communeCode) {
    _checkLoaded();
    return _byCode![communeCode]?.pmun;
  }

  String? regionOfDep(String dep) {
    _checkLoaded();
    return _depReg![dep];
  }

  String? regionLabel(String reg) {
    _checkLoaded();
    return _regLabel![reg];
  }

  /// Échelle de généralisation, le carburant de la boucle ré-id (Jalon 3).
  ///
  /// 0 = commune, 1 = département, 2 = région, 3 = grande zone, 4 = France.
  /// Les niveaux 0-2 rendent ce que les données offrent (pas de libellé de
  /// département dans les assets, donc niveau 1 = code brut) ; le niveau 3
  /// utilise la table [_grandeZone] définie dans ce package.
  String generalize(String communeCode, int level) {
    _checkLoaded();
    final commune = _byCode![communeCode]!;
    switch (level) {
      case 0:
        return commune.libelle;
      case 1:
        return commune.dep;
      case 2:
        return _regLabel![commune.reg] ?? commune.reg;
      case 3:
        return _grandeZone[commune.reg] ?? commune.reg;
      default:
        return 'France';
    }
  }
}
