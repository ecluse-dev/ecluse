import 'package:ecluse_core/ecluse_core.dart';

import 'french_first_names.dart';

/// Détecteur heuristique de noms de personnes — **v0 de démonstration**.
///
/// Contrairement aux détecteurs d'`ecluse_core`, il n'y a ici aucune clé
/// de contrôle possible : un nom propre n'a pas de structure vérifiable.
/// Ce détecteur combine deux indices :
///
/// 1. Une **civilité** (`M.`, `Mme`, `Monsieur`, `Madame`, `Dr`, `Docteur`,
///    `Me`) suivie d'un ou deux mots capitalisés → confiance haute (0.9) :
///    l'indice est fort et rarement un faux positif.
/// 2. Un **prénom français connu** (voir [frenchFirstNames]) suivi d'un mot
///    capitalisé (nom de famille supposé) → confiance moyenne (0.6) :
///    un prénom peut aussi être un nom commun capitalisé par erreur, ou le
///    mot suivant n'être pas un nom de famille.
/// 3. Un **prénom français connu** utilisé seul, sans nom de famille qui
///    suit (ex. « Sophie rappelle que… » dans un compte rendu où l'on
///    ne mentionne plus qu'un prénom une fois la personne présentée) →
///    confiance plus faible (0.5), mais détecté quand même : dans cette
///    version, on ne filtre jamais par confiance (voir `Ecluse.redact`),
///    donc un prénom isolé est masqué plutôt que de fuiter.
///
/// Un mot capitalisé isolé, sans civilité ni prénom reconnu (ex. début de
/// phrase), n'est **jamais** masqué : ce serait trop de faux positifs pour
/// une démonstration crédible.
///
/// Sera remplacé en phase 2 par un modèle NER local (voir ROADMAP.md).
final class NameDetector implements EntityDetector {
  const NameDetector();

  @override
  EntityType get type => EntityType.nom;

  static final RegExp _civility = RegExp(
    r'\b(?:M\.|Mme|Monsieur|Madame|Dr\.?|Docteur|Me)\s+'
    r"([A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*"
    r"(?:\s+[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*)?)",
  );

  static final RegExp _capitalizedWord = RegExp(
    r"[A-ZÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ][\wÀ-ſ'-]*",
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    final claimed = <_Range>[];

    for (final match in _civility.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.9,
        ),
      );
      claimed.add(_Range(start, end));
    }

    for (final match in _capitalizedWord.allMatches(text)) {
      final word = match.group(0)!;
      final normalized = word.toLowerCase();
      if (!frenchFirstNames.contains(normalized)) continue;
      if (claimed.any((r) => r.overlaps(match.start, match.end))) continue;

      final afterFirstName = _matchNextCapitalizedWord(text, match.end);
      final hasFreeLastName = afterFirstName != null &&
          !claimed.any(
            (r) => r.overlaps(afterFirstName.start, afterFirstName.end),
          );

      final start = match.start;
      final end = hasFreeLastName ? afterFirstName.end : match.end;
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: hasFreeLastName ? 0.6 : 0.5,
        ),
      );
      claimed.add(_Range(start, end));
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }

  /// Cherche le mot capitalisé suivant immédiatement (séparé uniquement par
  /// des espaces) la position [from]. Retourne `null` s'il n'y en a pas.
  ///
  /// `matchAsPrefix` ancre déjà la recherche à [from] : il ne faut pas de
  /// `^` dans le motif, qui référence le tout début de la chaîne et non la
  /// position de départ passée en argument.
  static Match? _matchNextCapitalizedWord(String text, int from) {
    final gapMatch = RegExp(r' +').matchAsPrefix(text, from);
    if (gapMatch == null) return null;
    return _capitalizedWord.matchAsPrefix(text, gapMatch.end);
  }
}

final class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && start < otherEnd;
}
