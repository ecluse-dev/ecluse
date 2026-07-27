import 'dart:io';

import 'asset_bytes.dart';

/// Implémentation d'[AssetBytes] qui lit les assets sur le disque.
///
/// Pour tests, CLI et serveur — pas d'app Flutter. [assetsDir] est résolu
/// relativement au répertoire courant, qui doit être la racine du package
/// (c'est le cas par défaut avec `dart test` et `melos exec`).
AssetBytes fileAssets({String assetsDir = 'assets'}) {
  return (String key) => File('$assetsDir/$key').readAsBytes();
}
