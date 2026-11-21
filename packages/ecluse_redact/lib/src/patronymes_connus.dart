part of 'ecluse.dart';

/// Pourquoi une entrée de [PatronymesConnus] est refusée (P2-243). Le motif ne
/// porte jamais la valeur refusée : une liste de patients est une donnée de
/// l'application, elle ne doit finir ni dans un message d'exception ni dans un
/// journal.
enum MotifPatronymeRefuse {
  /// Entrée vide ou faite d'espaces.
  vide,

  /// Un seul mot de moins de deux lettres.
  tropCourt,

  /// Un seul mot qui est un sigle exclu du détecteur de noms (« EVA », « HTA »…) :
  /// il serait ignoré sans message, ce que la règle 4 de `CLAUDE.md` interdit.
  sigleExclu,

  /// Plus de [PatronymesConnus.motsMax] mots : ce n'est plus un nom.
  tropDeMots,
}

/// Levée par [PatronymesConnus.new] et [Dossier.ajouterPatronymes] quand au
/// moins une entrée est refusée. **Rien n'est retenu** (tout ou rien) : une
/// liste à moitié acceptée serait un masquage que l'application ne voit pas.
///
/// Le message donne, par motif, **le nombre** d'entrées refusées : jamais une
/// entrée, jamais son rang dans la liste.
final class PatronymesRefusesException implements Exception {
  PatronymesRefusesException(Map<MotifPatronymeRefuse, int> parMotif)
      : parMotif = Map.unmodifiable(parMotif);

  /// Nombre d'entrées refusées, par motif (les motifs à zéro sont absents).
  final Map<MotifPatronymeRefuse, int> parMotif;

  /// Nombre total d'entrées refusées.
  int get total => parMotif.values.fold(0, (a, b) => a + b);

  @override
  String toString() => 'PatronymesRefusesException : $total entrée(s) '
      'refusée(s), liste non retenue (${[
        for (final e in parMotif.entries) '${e.key.name} : ${e.value}'
      ].join(', ')}).';
}

/// Liste de patronymes fournie par l'application **avant** la première pièce
/// d'un [Dossier] (patients, salariés, planning) : option B de
/// `agent/specs/P2-219.md`, décisions du 21 novembre dans `DECISIONS.md`.
///
/// **Ce que la liste fait.** Elle amorce la deuxième passe de `NameDetector`
/// comme un patronyme établi par une pièce précédente : un patronyme seul
/// (« Le dossier de Verdier », « VERDIER ») est masqué dès la première pièce.
/// Elle **n'amorce pas** `NomMinusculesDetector` : en minuscules, un mot de la
/// liste n'est pas masqué sur sa seule présence (« le marchand est venu »).
///
/// **Ce qu'elle ne fait pas** (`LIMITES.md` § 8) : une liste est une liste de
/// *mots*, pas de personnes. Un nom qui est aussi un mot courant (« Petit »,
/// « Marchand ») ou une commune (« Vesoul ») est masqué partout où il s'écrit
/// avec une majuscule, y compris dans « Petit déjeuner » : l'application le
/// déclenche en le fournissant. La comparaison se fait mot à mot : un nom à
/// particule (« de La Fontaine ») ou à plusieurs mots ne correspond à rien, et
/// un pluriel ou une faute ne sont pas rattrapés. Deux noms de la liste côte à
/// côte (« Verdier Lenoir ») donnent un seul jeton.
///
/// **Opacité**, même règle que `TableDeCorrespondance` : [toString] ne dit que
/// le nombre d'entrées ; pas d'`==` ; le type n'est ni une `Iterable` ni une
/// `Map`, donc `jsonEncode` le refuse ; [vider] efface la copie de la
/// bibliothèque. Aucune valeur dans un message d'exception, aucun compte dans
/// le journal d'audit, aucune écriture sur disque. L'application garde ses
/// propres copies de sa liste : l'opacité protège de l'affichage accidentel,
/// pas de la mémoire du processus.
final class PatronymesConnus {
  /// Nombre de mots au-delà duquel une entrée n'est plus un nom.
  static const int motsMax = 4;

  /// Construit la liste depuis [noms], en une passe : toute entrée refusée lève
  /// [PatronymesRefusesException] (comptes par motif, sans valeur) et la liste
  /// n'est pas construite. Les doublons (casse et blancs ignorés) comptent pour
  /// une entrée.
  factory PatronymesConnus(Iterable<String> noms) {
    final retenus = <String>{};
    final refus = <MotifPatronymeRefuse, int>{};
    void refuse(MotifPatronymeRefuse m) => refus[m] = (refus[m] ?? 0) + 1;
    for (final brut in noms) {
      final mots = brut.trim().split(RegExp(r'\s+'))
        ..removeWhere((m) => m.isEmpty);
      if (mots.isEmpty) {
        refuse(MotifPatronymeRefuse.vide);
      } else if (mots.length > motsMax) {
        refuse(MotifPatronymeRefuse.tropDeMots);
      } else if (mots.length == 1 && mots.first.runes.length < 2) {
        refuse(MotifPatronymeRefuse.tropCourt);
      } else if (mots.length == 1 && NameDetector.estSigleExclu(mots.first)) {
        refuse(MotifPatronymeRefuse.sigleExclu);
      } else {
        retenus.add(mots.join(' ').toLowerCase());
      }
    }
    if (refus.isNotEmpty) throw PatronymesRefusesException(refus);
    return PatronymesConnus._(retenus);
  }

  PatronymesConnus._(this._noms);

  /// Liste vide (pour l'état d'un dossier sans liste).
  PatronymesConnus._vide() : _noms = <String>{};

  // Minuscules, blancs normalisés. Privé : visible seulement de la bibliothèque
  // `ecluse.dart` (détection), jamais d'un appelant.
  final Set<String> _noms;

  /// Nombre d'entrées distinctes.
  int get length => _noms.length;

  bool get isEmpty => _noms.isEmpty;
  bool get isNotEmpty => _noms.isNotEmpty;

  /// Efface la copie en mémoire. Ne touche pas aux copies de l'application.
  void vider() => _noms.clear();

  /// Jamais un nom : seulement le nombre d'entrées.
  @override
  String toString() => 'PatronymesConnus($length nom${length > 1 ? 's' : ''})';
}
