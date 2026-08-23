import 'ambiguity_resolver.dart';
import 'revalidation_outcome.dart';
import 'structural_validator.dart';

/// Rejoue les checksums structurels sur toutes les variantes ambiguës
/// d'un token OCR bruité.
///
/// C'est le composant qui permet à Ecluse d'ouvrir la porte au PDF-image
/// sans trahir sa ligne éditoriale : au lieu de refuser globalement, on
/// tente une correction sûre, on renvoie à l'humain si ambiguë, on
/// refuse explicitement sinon.
class StructuralRevalidator {
  StructuralRevalidator({
    required this.validators,
    this.resolver = const AmbiguityResolver(),
    Map<String, RegExp>? suspectPatterns,
  }) : suspectPatterns = suspectPatterns ?? defaultSuspectPatterns;

  final List<StructuralValidator> validators;
  final AmbiguityResolver resolver;

  /// Patrons de « ressemble à un identifiant » — utilisés pour décider
  /// si une revalidation doit être tentée, et si l'échec doit remonter
  /// en `Unrecoverable` (au lieu d'un silence).
  ///
  /// Un token qui ne matche aucun patron est ignoré (économise du CPU
  /// sur les mots courants).
  final Map<String, RegExp> suspectPatterns;

  /// Patrons par défaut pour les identifiants santé FR courants.
  ///
  /// Volontairement laxistes — on préfère tenter et échouer
  /// explicitement que rater silencieusement.
  static final Map<String, RegExp> defaultSuspectPatterns = {
    // 15 caractères alphanumériques (accepte 2A/2B Corse).
    'NIR': RegExp(r'^[A-Z0-9OIlSBZGT]{15}$'),
    // RPPS/ADELI : 9 à 11 chiffres.
    'RPPS': RegExp(r'^[0-9OIlSBZGT]{9,11}$'),
    // FINESS : 9 chiffres.
    'FINESS': RegExp(r'^[0-9OIlSBZGT]{9}$'),
    // IBAN FR : 27 caractères commençant par FR.
    'IBAN_FR': RegExp(r'^FR[0-9OIlSBZGT]{25}$', caseSensitive: false),
  };

  /// Tente de revalider un token OCR bruité.
  ///
  /// Retourne `null` si le token ne ressemble à aucun identifiant connu
  /// (économie de CPU — le token traversera le pipeline normal).
  RevalidationOutcome? tryRevalidate(String noisy) {
    final normalized = noisy.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (normalized.isEmpty) return null;

    // Détermine les patrons qui matchent (économise la génération de
    // variantes pour les tokens qui ne ressemblent à rien).
    final matchingKinds = suspectPatterns.entries
        .where((e) => e.value.hasMatch(normalized))
        .map((e) => e.key)
        .toList();

    if (matchingKinds.isEmpty) return null;

    final variants = resolver.variantsOf(normalized);
    final accepted = <AmbiguousCandidate>[];

    for (final variant in variants) {
      for (final validator in validators) {
        // On ne teste un validateur que si le kind présumé peut le
        // concerner (évite RPPS testé sur un IBAN).
        if (!matchingKinds.contains(validator.name)) continue;
        if (validator.validate(variant)) {
          accepted.add(AmbiguousCandidate(
            candidate: variant,
            validatorName: validator.name,
            diff: AmbiguityResolver.diffChars(normalized, variant),
          ));
        }
      }
    }

    if (accepted.isEmpty) {
      return Unrecoverable(
        original: normalized,
        variantsTried: variants.length,
        suspectedKind: matchingKinds.join('|'),
      );
    }

    // Correction sûre = un seul candidat *distinct* accepté par un
    // seul validateur (peu importe la structure du set d'origine).
    final uniqueCandidates = accepted.map((c) => c.candidate).toSet();
    if (uniqueCandidates.length == 1) {
      final only = accepted.first;
      return Corrected(
        original: normalized,
        variantsTried: variants.length,
        corrected: only.candidate,
        validatorName: only.validatorName,
        diff: only.diff,
      );
    }

    return Ambiguous(
      original: normalized,
      variantsTried: variants.length,
      candidates: accepted,
    );
  }
}
