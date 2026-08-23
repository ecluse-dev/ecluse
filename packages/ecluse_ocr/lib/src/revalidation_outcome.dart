import 'package:meta/meta.dart';

import 'ambiguity_resolver.dart';

/// Issue d'une passe de revalidation structurelle sur un token OCR.
///
/// Trois formes exhaustives :
///   - [Corrected] : une variante ambiguë valide un checksum unique →
///     correction sûre appliquée avec traçabilité complète.
///   - [Ambiguous] : plusieurs variantes valident → la couche OCR ne
///     décide pas, main à l'humain (comme la boucle reid).
///   - [Unrecoverable] : aucune variante ne valide malgré la ressemblance
///     structurelle → refus explicite, zone à risque signalée.
sealed class RevalidationOutcome {
  const RevalidationOutcome(
      {required this.original, required this.variantsTried});

  final String original;

  /// Nombre de variantes testées (bornées par `AmbiguityResolver.maxVariants`).
  final int variantsTried;
}

/// Une seule variante ambiguë passe le checksum. Correction sûre.
@immutable
class Corrected extends RevalidationOutcome {
  const Corrected({
    required super.original,
    required super.variantsTried,
    required this.corrected,
    required this.validatorName,
    required this.diff,
  });

  final String corrected;
  final String validatorName;
  final List<CharDiff> diff;

  @override
  String toString() => 'Corrected($original → $corrected via '
      '$validatorName, diff=$diff)';
}

/// Plusieurs variantes passent (au moins un) checksum. On ne tranche pas.
@immutable
class Ambiguous extends RevalidationOutcome {
  const Ambiguous({
    required super.original,
    required super.variantsTried,
    required this.candidates,
  });

  /// Liste des `(variante, validateur qui accepte)`.
  final List<AmbiguousCandidate> candidates;

  @override
  String toString() => 'Ambiguous($original, ${candidates.length} candidats)';
}

@immutable
class AmbiguousCandidate {
  const AmbiguousCandidate({
    required this.candidate,
    required this.validatorName,
    required this.diff,
  });

  final String candidate;
  final String validatorName;
  final List<CharDiff> diff;

  @override
  String toString() => '$candidate via $validatorName';
}

/// Aucune variante ne valide. Le token ressemble à un identifiant mais
/// n'en est pas — ou l'OCR l'a trop dégradé pour être rattrapable.
///
/// Le champ [suspectedKind] indique le type d'identifiant présumé
/// d'après la forme (longueur, alphabet) ; utile pour l'UI de refus
/// ciblé.
@immutable
class Unrecoverable extends RevalidationOutcome {
  const Unrecoverable({
    required super.original,
    required super.variantsTried,
    required this.suspectedKind,
  });

  final String suspectedKind;

  @override
  String toString() =>
      'Unrecoverable($original, suspected=$suspectedKind, tried=$variantsTried)';
}
