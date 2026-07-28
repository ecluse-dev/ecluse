import 'package:ecluse_reference/ecluse_reference.dart';

/// Somme `RaritySource.medecinsCount(dep, code)` sur les 14 codes de
/// spécialité (`specialtyCodes()`) — palier 1 de l'échelle profession
/// (« médecin, toute spécialité »). Vérifié sur données réelles : dep "57"
/// -> 2894.
int medecinTouteSpecialite(RaritySource rarity, String dep) {
  var total = 0;
  for (final code in rarity.specialtyCodes()) {
    total += rarity.medecinsCount(dep, code) ?? 0;
  }
  return total;
}

/// [medecinTouteSpecialite] + somme `RaritySource.professionCount(profession,
/// dep)` sur les 4 professions (`professions()`) — palier 2, au-delà du
/// palier 1 (« professionnel de santé »). Vérifié sur données réelles : dep
/// "57" -> 5107 (2894 + 976+671+415+151 = 2213).
int professionnelDeSanteCount(RaritySource rarity, String dep) {
  var total = medecinTouteSpecialite(rarity, dep);
  for (final profession in rarity.professions()) {
    total += rarity.professionCount(profession, dep) ?? 0;
  }
  return total;
}
