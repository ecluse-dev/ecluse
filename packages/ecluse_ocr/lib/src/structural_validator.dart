import 'package:meta/meta.dart';

/// Validateur structurel : reçoit un candidat, renvoie s'il est valide
/// pour un format identifiant (NIR, RPPS, IBAN, FINESS...).
///
/// Sera implémenté par des adapters vers `ecluse_core` : chaque
/// `Detector` structurel de `ecluse_core` (avec sa clé de Luhn ou ses
/// règles) fournit son `StructuralValidator` correspondant.
abstract interface class StructuralValidator {
  /// Nom court du validateur, propagé dans les traces (`NIR`, `RPPS`,
  /// `IBAN_FR`, `FINESS`).
  String get name;

  /// Normalise puis valide. Retourne `true` si le candidat satisfait
  /// toutes les contraintes structurelles (longueur, alphabet, checksum).
  bool validate(String candidate);
}

/// Fake NIR pour les tests — implémente la vraie clé de Luhn du NIR
/// français : `97 - (nir mod 97)` sur les 13 premiers chiffres doit
/// donner les 2 derniers. Le caractère de sexe `2A`/`2B` (Corse) est
/// normalisé en `19`/`18` avant calcul.
@visibleForTesting
class FakeNirValidator implements StructuralValidator {
  const FakeNirValidator();

  @override
  String get name => 'NIR';

  @override
  bool validate(String candidate) {
    final normalized =
        candidate.replaceAll(RegExp(r'[\s.\-]'), '').toUpperCase();
    if (normalized.length != 15) return false;
    // Département Corse : 2A/2B → 19/18.
    final digitsOnly =
        normalized.replaceFirst('2A', '19').replaceFirst('2B', '18');
    if (!RegExp(r'^\d{15}$').hasMatch(digitsOnly)) return false;
    final body = int.tryParse(digitsOnly.substring(0, 13));
    final key = int.tryParse(digitsOnly.substring(13));
    if (body == null || key == null) return false;
    return (97 - (body % 97)) == key;
  }
}

/// Fake validateur générique par regex, utile pour les tests.
@visibleForTesting
class RegexValidator implements StructuralValidator {
  const RegexValidator({required this.name, required this.pattern});

  @override
  final String name;
  final RegExp pattern;

  @override
  bool validate(String candidate) => pattern.hasMatch(candidate);
}
