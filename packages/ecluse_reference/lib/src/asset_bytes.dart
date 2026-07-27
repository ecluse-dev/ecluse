/// Rend les octets bruts d'un asset par sa clé (nom de fichier).
///
/// Injecté par l'appelant : une app Flutter le fournit via `rootBundle`,
/// un test/CLI/serveur via [fileAssets] (lecture disque).
typedef AssetBytes = Future<List<int>> Function(String key);
