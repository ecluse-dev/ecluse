/// Table de correspondance jeton ↔ valeur réelle d'un appel à
/// `Ecluse.redact` (P2-193, décisions du 15 novembre dans `DECISIONS.md`).
///
/// **Pourquoi un type dédié.** La table était un `Map<String, String>` : un
/// `print(result.mapping)`, une interpolation dans un message de log ou une
/// exception, un `jsonEncode` la sortait en clair, valeurs comprises. C'est
/// l'objet le plus sensible du produit : elle ne quitte jamais l'appareil et
/// n'est conservée nulle part (`LIMITES.md` § 5.3). Ce type la rend opaque :
///
/// - [toString] ne dit que le nombre de jetons, jamais un jeton ni une valeur ;
/// - le type n'implémente ni `Map` ni `Iterable` : `jsonEncode` le refuse avec
///   une erreur (refus explicite plutôt qu'échec silencieux) ;
/// - il n'a pas d'`==` : on ne reconstitue pas le contenu en le comparant à
///   des candidats (les tests lisent [entrees]) ;
/// - [vider] efface les valeurs de la mémoire de cette table.
///
/// **Ce que ce type ne fait pas : chiffrer.** Rien n'est conservé hors de la
/// mémoire du processus ; chiffrer une structure en mémoire ne protège pas de
/// quelqu'un qui lit la mémoire (il lit aussi la clé). Le chiffrement sera à
/// rouvrir le jour où une table est persistée (`DECISIONS.md`, P2-189).
/// L'opacité protège de l'affichage accidentel, pas d'un appelant qui lit
/// volontairement [entrees] ou `[]` : celui-là a déjà les valeurs.
final class TableDeCorrespondance {
  /// Table construite à la main depuis [carte] (jeton → valeur), recopiée :
  /// modifier [carte] ensuite ne change pas la table. Le passage d'une carte
  /// en clair reste ainsi un geste visible dans le code appelant.
  TableDeCorrespondance.depuis(Map<String, String> carte)
      : _carte = Map.of(carte);

  final Map<String, String> _carte;

  /// Nombre de jetons de la table.
  int get length => _carte.length;

  bool get isEmpty => _carte.isEmpty;
  bool get isNotEmpty => _carte.isNotEmpty;

  /// Les jetons (`[NOM_1]`…), sans leurs valeurs.
  Iterable<String> get jetons => _carte.keys;

  /// Valeur réelle de [jeton], ou `null` s'il n'est pas dans la table.
  String? operator [](String jeton) => _carte[jeton];

  /// Vrai si [jeton] est dans la table.
  bool contient(String jeton) => _carte.containsKey(jeton);

  /// Les couples (jeton, valeur réelle), pour restaurer ou renuméroter. Un
  /// appelant qui les affiche ou les journalise sort les valeurs en clair.
  Iterable<(String, String)> get entrees =>
      [for (final e in _carte.entries) (e.key, e.value)];

  /// Efface la table : plus aucun jeton ni valeur, et `Ecluse.restore` avec
  /// cette table ne restaurera plus rien. À appeler quand la restauration est
  /// faite (fin de session). Une table partagée par plusieurs résultats
  /// (aperçu, généralisation) est vidée pour tous.
  void vider() => _carte.clear();

  /// Jamais une valeur ni un jeton : seulement le nombre de jetons.
  @override
  String toString() =>
      'TableDeCorrespondance($length jeton${length > 1 ? 's' : ''})';
}
