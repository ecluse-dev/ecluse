part of 'ecluse.dart';

/// Jeton de forme connue (`[TYPE_N]` ou `TYPE_N`) resté dans le texte après
/// [Ecluse.restoreAvecRapport] : ni retrouvé dans la table de
/// correspondance, ni reconnu comme jeton correctement échappé. Ne porte
/// jamais la valeur réelle attendue à cet endroit — seulement ce qui permet
/// de diagnostiquer sans réexposer de contenu (P2-190).
final class JetonNonRestaure {
  /// Partie avant le dernier `_`, telle que vue dans le texte (`NOM`,
  /// `DATE_NAISSANCE`, ou un libellé que le LLM a traduit comme `NAME`).
  final String type;

  /// Partie après le dernier `_`, telle que vue dans le texte — jamais
  /// interprétée comme un entier : un jeton inventé ou déformé peut porter
  /// n'importe quoi à cet endroit.
  final String numero;

  const JetonNonRestaure(this.type, this.numero);

  @override
  String toString() => '${type}_$numero';

  @override
  bool operator ==(Object other) =>
      other is JetonNonRestaure && other.type == type && other.numero == numero;

  @override
  int get hashCode => Object.hash(type, numero);
}

String _restoreCarte(String text, Map<String, String> mapping) {
  // Un jeton ne peut se trouver que dans un segment `[...]` sans crochet. Si
  // aucune valeur ne contient de crochet ni de barre oblique inversée, les
  // remplacements ne peuvent ni en créer ni en défaire : un seul parcours des
  // segments donne le même résultat que les remplacements successifs, sans
  // le coût « jetons × taille du texte » (P2-64). Sinon, ancien parcours.
  final clesDeJetons = {for (final k in mapping.keys) _cleLache(k)};
  if (mapping.values.any((v) => _peutRecreerUnJeton(v, clesDeJetons))) {
    return _restoreSequentiel(text, mapping);
  }
  final parNom = <String, List<MapEntry<String, RegExp>>>{};
  for (final entry in mapping.entries) {
    parNom
        .putIfAbsent(_cleLache(entry.key), () => [])
        .add(MapEntry(entry.key, tolerantTokenPattern(entry.key)));
  }
  bool exact(RegExp motif, String s) {
    final m = motif.matchAsPrefix(s);
    return m != null && m.end == s.length;
  }

  return text.replaceAllMapped(_segment, (m) {
    final segment = m[0]!;
    for (final candidat in [
      segment,
      if (segment.startsWith('\\')) segment.substring(1),
    ]) {
      for (final c in parNom[_cleLache(candidat)] ??
          const <MapEntry<String, RegExp>>[]) {
        if (exact(c.value, candidat)) {
          return segment.substring(0, segment.length - candidat.length) +
              mapping[c.key]!;
        }
      }
    }
    return segment;
  });
}

/// Segment entre crochets, forme générique `[<libellé>_<numéro>]` —
/// n'importe quel libellé, pas seulement ceux qu'[entityTypeLabel] connaît
/// (un libellé traduit comme `NAME` doit aussi être signalé).
final RegExp _formeJetonCrochets = RegExp(r'\\?\[([^\[\]]*?)_([0-9]+)\]');

/// Occurrence sans crochets d'un libellé *connu* suivi de `_<numéro>`, aux
/// frontières du mot. Restreint aux libellés d'[entityTypeLabel] (et non à
/// toute suite de lettres) : sans crochets, rien ne distingue plus un
/// jeton dépouillé d'un mot ordinaire, donc on ne cherche que les formes
/// qu'Écluse aurait pu réellement émettre.
final RegExp _formeJetonSansCrochets = RegExp(
  '(?<![\\[\\w])(?:${EntityType.values.map((t) => RegExp.escape(entityTypeLabel(t))).join('|')})_[0-9]+(?!\\w)',
);

List<JetonNonRestaure> _jetonsNonRestaures(String texteRestaure) {
  final trouves = <JetonNonRestaure>[];
  for (final m in _formeJetonCrochets.allMatches(texteRestaure)) {
    trouves.add(JetonNonRestaure(m[1]!, m[2]!));
  }
  for (final m in _formeJetonSansCrochets.allMatches(texteRestaure)) {
    final sansCrochets = m[0]!;
    final coupure = sansCrochets.lastIndexOf('_');
    trouves.add(JetonNonRestaure(
      sansCrochets.substring(0, coupure),
      sansCrochets.substring(coupure + 1),
    ));
  }
  return trouves;
}

final RegExp _segment = RegExp(r'\\?\[[^\[\]]*\]');

/// Une valeur ne peut recréer ni défaire un jeton que si elle contient une
/// barre oblique inversée, un crochet isolé (qui se combinerait avec le texte
/// voisin) ou un segment `[...]` que [tolerantTokenPattern] confondrait avec
/// un jeton. Un courriel obfusqué `jean[at]example.fr` n'en est pas un : sans
/// cette précision, il imposait l'ancien parcours (jetons × texte, P2-85).
bool _peutRecreerUnJeton(String valeur, Set<String> clesDeJetons) {
  if (valeur.contains('\\')) return true;
  if (!valeur.contains('[') && !valeur.contains(']')) return false;
  final sansSegments = valeur.replaceAll(_segment, '');
  if (sansSegments.contains('[') || sansSegments.contains(']')) return true;
  return _segment
      .allMatches(valeur)
      .any((m) => clesDeJetons.contains(_cleLache(m[0]!)));
}

/// Clé de rapprochement large : tout ce que [tolerantTokenPattern] tolère en
/// plus du jeton (casse, blancs, soulignements, barres obliques inversées,
/// crochets) est retiré. Deux textes que le motif apparie ont la même clé ;
/// l'inverse est revérifié avec le motif exact.
String _cleLache(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s_\\\[\]]'), '');

String _restoreSequentiel(String text, Map<String, String> mapping) {
  var result = text;
  for (final entry in mapping.entries) {
    result = result.replaceAll(tolerantTokenPattern(entry.key), entry.value);
  }
  return result;
}
