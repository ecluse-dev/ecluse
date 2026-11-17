part of 'ecluse.dart';

/// Clé d'identité pour les types **autres que `nom`** : l'identité est la
/// valeur exacte. Deux adresses ou deux téléphones qui se ressemblent ne
/// doivent jamais être fusionnés sur une simple heuristique. Les noms
/// suivent une résolution différente, plus riche — voir
/// [_resolveNomToken].
String _identityKey(DetectedEntity entity) =>
    '${entity.type.name}:${entity.value}';

/// Ensemble de segments (minuscules) déjà associés à un jeton `nom`.
final class _NomIdentity {
  _NomIdentity(this.segments, this.token, this.gender, this.doc);

  /// Dernier document (numéro d'appel dans le dossier) où l'identité a été
  /// vue : la règle d'inclusion ne s'applique qu'au sein d'un document.
  int doc;

  Set<String> segments;
  final String token;

  /// `'m'`, `'f'` ou `null` : sexe indiqué par la civilité qui précède la
  /// mention (« M. », « Mme »…), quand il y en a une.
  String? gender;
}

/// Sexe indiqué par la civilité qui précède immédiatement [start] dans
/// [text], ou `null`. Sert à ne pas fusionner « M. Jean Dupont » et
/// « Mme Dupont » (un couple) sur leur seul patronyme commun.
String? _genderBefore(String text, int start) {
  final head = text.substring(start < 20 ? 0 : start - 20, start);
  // Sans tenir compte de la casse : en minuscules ou en capitales, la
  // civilité reste hors de la mention (P2-145) et doit encore séparer un
  // couple.
  if (RegExp(r'(?:^|[^\wÀ-ÿ])(?:M\.|Mr\.?|Monsieur)[ \t\u00A0\u202F]*$',
          caseSensitive: false)
      .hasMatch(head)) {
    return 'm';
  }
  if (RegExp(
          r'(?:^|[^\wÀ-ÿ])(?:Mme|Mlle|Mrs\.?|Madame|Mademoiselle)'
          r'[ \t\u00A0\u202F]*$',
          caseSensitive: false)
      .hasMatch(head)) {
    return 'f';
  }
  return null;
}

/// Segments (minuscules, sans doublons) d'une mention de nom — insensible
/// à l'ordre et à la casse : « Dubreuil Thomas » et « Thomas Dubreuil »
/// produisent le même ensemble.
///
/// Une civilité de genre **en tête** (« m. », « mme ») n'est pas un segment :
/// `NomMinusculesDetector` l'inclut dans la mention, `NameDetector` la laisse
/// en clair ; sans ce retrait, « m. antoine lacombe » et « M. Antoine
/// Lacombe » (même personne, casses différentes) recevaient deux jetons
/// (P2-145). Le sexe qu'elle indique est rendu par [_genreEnTete].
Set<String> _nameSegments(String value) {
  final mots = value
      .toLowerCase()
      .replaceAll(',', ' ')
      .split(RegExp(r'\s+'))
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (mots.length > 1 && _civilitesGenre.containsKey(mots.first)) {
    mots.removeAt(0);
  }
  return mots.toSet();
}

/// Civilités de genre (minuscules, point compris) et sexe indiqué.
const Map<String, String> _civilitesGenre = {
  'm.': 'm', 'm': 'm', 'mr': 'm', 'mr.': 'm', 'monsieur': 'm', //
  'mme': 'f', 'mme.': 'f', 'mlle': 'f', 'mlle.': 'f', 'madame': 'f', //
  'mademoiselle': 'f',
};

/// Sexe indiqué par une civilité de genre en tête de [value], ou `null`.
String? _genreEnTete(String value) {
  final premier = value.trimLeft().split(RegExp(r'\s+')).first.toLowerCase();
  return _civilitesGenre[premier];
}

/// Résout le jeton d'une entité `nom`, en fusionnant les mentions
/// **partielles** avec une identité déjà établie dans le même document —
/// sans quoi une re-mention par le seul patronyme (« Dr Costa » après
/// « Dr Nadia Costa »), par initiale + patronyme (« S. Reynaud » après
/// « Mme Sandra Reynaud ») ou à ordre nom/prénom inversé (« Thomas
/// Dubreuil » après « Dubreuil Thomas ») recevrait à tort un jeton séparé,
/// laissant croire au LLM qu'il s'agit d'une personne différente.
///
/// Règle : les segments de la nouvelle mention et ceux d'une identité déjà
/// connue sont comparés par **inclusion** (l'un est un sous-ensemble de
/// l'autre), pas par égalité stricte — c'est ce qui permet à un patronyme
/// seul (« Costa », un segment) de rejoindre une identité plus complète
/// (« Nadia Costa », deux segments), tout en refusant de fusionner deux
/// mentions dont les segments se contredisent (« Morel Hélène » ne
/// contient pas « Antoine » : ne fusionne jamais avec « MOREL Antoine »,
/// même patronyme partagé). Quand une mention plus complète rejoint une
/// identité déjà établie sous une forme partielle, l'identité est mise à
/// jour vers la forme la plus riche, pour que les mentions suivantes
/// continuent de s'y rattacher correctement.
///
/// **Ambiguïté assumée** : si la mention correspond à *plusieurs*
/// identités déjà établies et distinctes (deux personnes homonymes déjà
/// identifiées séparément dans le document), aucune fusion n'est risquée —
/// mieux vaut un jeton supplémentaire qu'une mauvaise attribution
/// d'identité.
String _resolveNomToken(
  DetectedEntity entity,
  _Etat etat,
  int docId,
  String text,
) {
  final segments = _nameSegments(entity.value);
  final gender =
      _genderBefore(text, entity.start) ?? _genreEnTete(entity.value);
  // Deux civilités de sexe différent désignent deux personnes, même avec un
  // patronyme commun (un couple).
  bool compatible(_NomIdentity identity) =>
      !(gender != null && identity.gender != null && gender != identity.gender);

  // Seules les identités qui partagent au moins un segment avec la mention
  // peuvent correspondre (les deux sens de l'inclusion l'exigent) : l'index
  // évite de comparer chaque mention à toutes les identités du dossier (P2-64).
  final matches = etat
      .candidats(segments)
      .where(
        (identity) =>
            (etat.regle == RegleNoms.inclusion || identity.doc == docId) &&
            compatible(identity) &&
            (segments.every(identity.segments.contains) ||
                identity.segments.every(segments.contains)),
      )
      .toList();

  if (matches.length == 1) {
    final identity = matches.single;
    identity.doc = docId;
    identity.gender ??= gender;
    if (segments.length > identity.segments.length) {
      // Forme la plus complète rencontrée : la carte de restauration la
      // reprend (« Dr Nadia Costa » plutôt que le « Costa » de la première
      // mention), comme le promet `LIMITES.md` §5.3 — sans cela, les
      // mentions complètes perdaient prénom et titre à la restauration.
      final anciens = identity.segments;
      identity.segments = segments;
      etat.reindexe(identity, anciens);
      etat.mapping[identity.token] = entity.value;
    }
    return identity.token;
  }

  // Entre documents d'un dossier (N1, `agent/specs/P2-05.md` § 5) : seule une
  // identité complète identique (deux segments au moins) rejoint une identité
  // d'un document précédent ; une mention partielle reçoit un nouveau jeton.
  if (matches.isEmpty &&
      etat.regle == RegleNoms.identiteComplete &&
      segments.length >= 2) {
    final anterieures = etat
        .candidats(segments)
        .where((identity) =>
            identity.doc != docId &&
            compatible(identity) &&
            identity.segments.length == segments.length &&
            segments.every(identity.segments.contains))
        .toList();
    if (anterieures.length == 1) {
      final identity = anterieures.single;
      identity.doc = docId;
      identity.gender ??= gender;
      return identity.token;
    }
  }

  final token = _freshToken(EntityType.nom, etat.counterByType, text);
  etat.attribues.add(token);
  etat.mapping[token] = entity.value;
  etat.ajouteIdentite(_NomIdentity(segments, token, gender, docId));
  return token;
}

/// Prochain jeton libre pour [type] : saute tout numéro dont le jeton figure
/// déjà dans le texte d'origine (comparaison tolérante, la même que celle de
/// la restauration). Sans cela, un texte qui contient `[NOM_1]` serait
/// confondu avec un jeton généré et `restore` réinjecterait la valeur d'une
/// personne à la place du texte de l'utilisateur.
String _freshToken(
  EntityType type,
  Map<EntityType, int> counterByType,
  String text,
) {
  var next = counterByType[type] ?? 0;
  String token;
  do {
    next++;
    token = '[${entityTypeLabel(type)}_$next]';
  } while (tolerantTokenPattern(token).hasMatch(_zoneCrochets(text)));
  counterByType[type] = next;
  return token;
}

/// Dernier texte examiné et ses segments `[...]` sans crochet intérieur, joints
/// par un saut de ligne. Un motif de jeton commence par `[` et finit par `]` sans
/// autre crochet : il ne peut se trouver que dans un tel segment. Relever ces
/// segments une fois par texte, au lieu d'appliquer le motif au texte entier pour
/// chaque nouveau jeton, évite un coût quadratique (P2-64).
String? _texteExamine;
String _zoneExaminee = '';

String _zoneCrochets(String text) {
  if (!identical(text, _texteExamine)) {
    _texteExamine = text;
    _zoneExaminee = [
      for (final m in RegExp(r'\[[^\[\]]*\]').allMatches(text)) m[0]!
    ].join('\n');
  }
  return _zoneExaminee;
}
