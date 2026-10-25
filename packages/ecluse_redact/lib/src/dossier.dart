part of 'ecluse.dart';

/// Dossier : suite de documents masqués avec un état commun, conservé **en
/// mémoire seulement** (P2-06, `agent/specs/P2-05.md`).
///
/// L'application cliente décide ce qu'est un dossier (conversation, lot de
/// fichiers, affaire) : elle le crée, le passe à `Ecluse.redact(dossier: …)` et
/// le ferme avec [fermer]. L'état (jetons, identités, carte) n'est jamais
/// sérialisé, journalisé ni écrit ; [toString] n'en expose rien ; il ne survit
/// pas au processus. Après un redémarrage, un nouveau [Dossier] repart de zéro :
/// ses jetons ne correspondent plus à ceux déjà envoyés, c'est à l'application
/// de ne pas mélanger les deux.
final class Dossier {
  Dossier();

  _Etat? _etat = _Etat();
  Future<void> _file = Future<void>.value();

  /// Vrai après [fermer] : le dossier refuse alors de masquer et de restaurer.
  bool get estFerme => _etat == null;

  /// Efface l'état. Idempotent. Les appels déjà en attente échouent avec
  /// [DossierFermeException] plutôt que de renvoyer des jetons sans
  /// correspondance.
  void fermer() {
    _etat?.efface();
    _etat = null;
  }

  /// Remplace dans [text] chaque jeton attribué dans ce dossier, quel que soit
  /// le message où il est apparu. Un jeton inconnu du dossier est laissé tel
  /// quel. Lève [DossierFermeException] si le dossier est fermé.
  String restore(String text) {
    final etat = _etat;
    if (etat == null) throw const DossierFermeException();
    return Ecluse.restore(text, etat.mapping);
  }

  /// Exécute [action] après les appels précédents du dossier : la numérotation
  /// et la fusion des noms ne se courent jamais après.
  Future<T> _serialise<T>(Future<T> Function() action) {
    final fin = Completer<void>();
    final precedent = _file;
    _file = fin.future;
    return precedent.then((_) => action()).whenComplete(fin.complete);
  }

  /// Ne montre ni jeton ni valeur.
  @override
  String toString() => 'Dossier(${estFerme ? 'fermé' : 'ouvert'})';
}

/// Levée quand on masque ou restaure avec un [Dossier] fermé (règle 4 : refus
/// explicite plutôt que des jetons sans correspondance).
final class DossierFermeException implements Exception {
  const DossierFermeException();

  @override
  String toString() => 'DossierFermeException : le dossier est fermé, son '
      'état a été effacé ; masquer ou restaurer avec lui est refusé.';
}
