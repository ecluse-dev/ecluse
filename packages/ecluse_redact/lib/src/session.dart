part of 'ecluse.dart';

/// Options d'un appel à [Ecluse.redact], regroupées pour ne pas les passer
/// une à une entre les étapes.
final class _Options {
  const _Options(this.detectors, this.restoreSecrets, this.refuseSecrets,
      this.riskReference, this.journal, this.supplementaires,
      [this.formesVerbales = const {}]);

  final List<Detector>? detectors;
  final bool restoreSecrets;
  final bool refuseSecrets;
  final EcluseReference? riskReference;
  final JournalAudit? journal;
  final List<Detector> supplementaires;
  final Set<String> formesVerbales;
}

/// État de masquage : jetons attribués, identités de noms, compteurs et carte.
/// Un appel sans [Dossier] en crée un neuf (comportement historique) ; un
/// [Dossier] conserve le sien entre les appels.
final class _Etat {
  _Etat([this.regle = RegleNoms.identiteComplete]);

  /// Règle de rapprochement des noms entre les documents du dossier.
  final RegleNoms regle;

  final Map<String, String> mapping = {};
  final Map<String, String> tokenByIdentity = {};
  final List<_NomIdentity> nomIdentities = [];

  /// Index des identités (P2-64). Une mention correspond à une identité si ses
  /// segments sont **inclus dans** ceux de l'identité, ou l'inverse : le premier
  /// cas se cherche par le segment le plus rare de la mention (`_parSegment`), le
  /// second par les sous-ensembles de la mention (`_parEnsemble`, clé = segments
  /// triés). `_parSegment` garde une identité sous tous les segments qu'elle a eus
  /// (ils ne font que croître) ; `_sansSegment` garde celles qui n'en ont aucun,
  /// qui correspondent à toute mention.
  final Map<String, Set<_NomIdentity>> _parSegment = {};
  final Map<String, Set<_NomIdentity>> _parEnsemble = {};
  final Set<_NomIdentity> _sansSegment = {};

  static String _cle(Set<String> segments) =>
      (segments.toList()..sort()).join('\u0000');

  final Map<EntityType, int> counterByType = {};

  void ajouteIdentite(_NomIdentity identite) {
    nomIdentities.add(identite);
    indexe(identite);
  }

  void indexe(_NomIdentity identite) {
    if (identite.segments.isEmpty) {
      _sansSegment.add(identite);
      return;
    }
    for (final segment in identite.segments) {
      (_parSegment[segment] ??= {}).add(identite);
    }
    (_parEnsemble[_cle(identite.segments)] ??= {}).add(identite);
  }

  /// L'identité vient de changer de segments (forme plus complète rencontrée).
  void reindexe(_NomIdentity identite, Set<String> anciens) {
    _parEnsemble[_cle(anciens)]?.remove(identite);
    indexe(identite);
  }

  /// Identités susceptibles de correspondre à une mention de [segments] : un
  /// sur-ensemble de celles qui correspondent réellement (le prédicat exact est
  /// ensuite appliqué par l'appelant).
  Iterable<_NomIdentity> candidats(Set<String> segments) {
    if (segments.isEmpty) return nomIdentities;
    final vues = <_NomIdentity>{..._sansSegment};
    // Identités qui contiennent tous les segments de la mention : la plus petite
    // des listes de segment suffit.
    Set<_NomIdentity>? plusPetite;
    for (final segment in segments) {
      final liste = _parSegment[segment];
      if (liste == null) {
        plusPetite = const {};
        break;
      }
      if (plusPetite == null || liste.length < plusPetite.length) {
        plusPetite = liste;
      }
    }
    vues.addAll(plusPetite ?? const {});
    // Identités dont les segments sont inclus dans ceux de la mention.
    final liste = segments.toList();
    if (liste.length > 8) {
      for (final segment in liste) {
        vues.addAll(_parSegment[segment] ?? const {});
      }
    } else {
      for (var masque = 1; masque < (1 << liste.length); masque++) {
        final sous = {
          for (var k = 0; k < liste.length; k++)
            if (masque & (1 << k) != 0) liste[k]
        };
        vues.addAll(_parEnsemble[_cle(sous)] ?? const {});
      }
    }
    return vues;
  }

  /// Patronymes (minuscules) établis par une mention certaine d'un document
  /// du dossier : amorcent la détection des documents suivants.
  final Set<String> patronymes = {};

  /// Liste de patronymes fournie par l'application (P2-243) : amorce
  /// `NameDetector` seulement, jamais `NomMinusculesDetector`. Copie propre à
  /// l'état, effacée avec lui ; jamais mêlée à [patronymes] (établis).
  PatronymesConnus fournis = PatronymesConnus._vide();

  /// Tous les jetons attribués, y compris ceux qui ne sont pas dans la carte
  /// (secrets non restaurables).
  final Set<String> attribues = {};

  /// Nombre de documents déjà masqués avec cet état.
  int documents = 0;

  /// Motifs de [tolerantTokenPattern] déjà compilés, par jeton : compiler un
  /// motif par jeton et par appel dominait le coût d'un gros dossier (P2-25).
  final Map<String, RegExp> _motifs = {};

  static final RegExp _crochets = RegExp(r'\[[^\[\]]*\]');

  /// Jetons déjà attribués qui figurent en clair dans [text] (même résultat
  /// que `tolerantTokenPattern(jeton).hasMatch(text)` pour chacun, dans l'ordre
  /// d'attribution). Un motif commence par `[` et finit par `]` sans autre
  /// crochet à l'intérieur : il ne peut se trouver que dans un segment
  /// `[...]` sans crochet, donc un texte sans tel segment (le cas courant) ne
  /// coûte plus rien, et les autres ne sont testés que sur ces segments.
  List<String> jetonsLitteraux(String text) {
    if (attribues.isEmpty) return const [];
    final segments = [for (final m in _crochets.allMatches(text)) m[0]!];
    if (segments.isEmpty) return const [];
    final zone = segments.join('\n');
    return [
      for (final jeton in attribues)
        if ((_motifs[jeton] ??= tolerantTokenPattern(jeton)).hasMatch(zone))
          jeton
    ];
  }

  /// Copie profonde, pour simuler un masquage (rapport de risque de l'aperçu)
  /// sans toucher à l'état réel du dossier.
  _Etat copie() {
    final c = _Etat(regle)..documents = documents;
    c.mapping.addAll(mapping);
    c.tokenByIdentity.addAll(tokenByIdentity);
    for (final n in nomIdentities) {
      c.ajouteIdentite(
          _NomIdentity(Set.of(n.segments), n.token, n.gender, n.doc));
    }
    c.counterByType.addAll(counterByType);
    c.patronymes.addAll(patronymes);
    c.fournis._noms.addAll(fournis._noms);
    c.attribues.addAll(attribues);
    return c;
  }

  void efface() {
    mapping.clear();
    tokenByIdentity.clear();
    nomIdentities.clear();
    _parSegment.clear();
    _parEnsemble.clear();
    _sansSegment.clear();
    counterByType.clear();
    patronymes.clear();
    fournis.vider();
    attribues.clear();
  }
}
