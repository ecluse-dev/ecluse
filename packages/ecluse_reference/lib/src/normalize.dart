import 'package:diacritic/diacritic.dart';

/// Normalise un nom pour lookup (communes, prénoms).
///
/// **Parité critique avec `build_reference_assets.py`** : toute divergence
/// casse les lookups en silence (cf. garde-fous, §8 de la spec Jalon 2).
/// Règle : retirer les accents, majuscules, remplacer `' ’ - . /` par une
/// espace, réduire les espaces multiples.
String normName(String s) {
  var out = removeDiacritics(s).toUpperCase();
  for (final ch in ["'", '’', '-', '.', '/']) {
    out = out.replaceAll(ch, ' ');
  }
  return out.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}
