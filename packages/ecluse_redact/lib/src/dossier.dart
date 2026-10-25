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
///
/// [regle] choisit comment une mention de nom d'un document est rapprochée des
/// noms des documents précédents (N3 de `agent/specs/P2-05.md` § 5) ; elle est
/// fixée à la création. Défaut : [RegleNoms.identiteComplete].
final class Dossier {
  Dossier({RegleNoms regle = RegleNoms.identiteComplete})
      : _etat = _Etat(regle);

  _Etat? _etat;
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

/// Règle de rapprochement des noms **entre** les documents d'un dossier. Au sein
/// d'un document, la règle d'inclusion et de civilité s'applique toujours.
enum RegleNoms {
  /// N1 (défaut) : une identité de nom rejoint celle d'un document précédent
  /// seulement si elle est complète et identique (deux segments au moins,
  /// mêmes segments, civilités de sexe compatibles). Une mention partielle
  /// (« Mme Verdier » après « Mme Sophie Verdier ») reçoit un **nouveau** jeton :
  /// aucune fausse fusion par patronyme, mais le LLM voit deux personnes là où
  /// il n'y en a peut-être qu'une.
  identiteComplete,

  /// N2 : la règle d'un document, appliquée entre documents. Une mention
  /// partielle rejoint l'unique identité qu'elle recoupe (inclusion de
  /// segments, civilités de sexe compatibles) ; avec plusieurs identités
  /// possibles, elle reçoit un nouveau jeton. **Risque** : deux personnes
  /// différentes de documents différents peuvent être fusionnées (homonymes,
  /// patronyme répandu), et comme un jeton ne restitue qu'une graphie, la
  /// restauration écrit la forme la plus complète rencontrée, y compris pour
  /// une réponse qui cite un jeton d'un document antérieur.
  inclusion,
}

/// Levée quand on masque ou restaure avec un [Dossier] fermé (règle 4 : refus
/// explicite plutôt que des jetons sans correspondance).
final class DossierFermeException implements Exception {
  const DossierFermeException();

  @override
  String toString() => 'DossierFermeException : le dossier est fermé, son '
      'état a été effacé ; masquer ou restaurer avec lui est refusé.';
}
