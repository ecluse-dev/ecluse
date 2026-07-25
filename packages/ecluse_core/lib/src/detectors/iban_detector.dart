import '../detector.dart';
import '../digit_compaction.dart';
import '../entity.dart';

/// Détecteur d'IBAN français (International Bank Account Number).
///
/// Structure d'un IBAN FR (27 caractères) :
///
/// ```
/// FR KK BBBBB GGGGG CCCCCCCCCCC RR
/// │  │  │     │     │           └─ clé RIB (2 chiffres)
/// │  │  │     │     └───────────── numéro de compte (11 alphanumériques)
/// │  │  │     └─────────────────── code guichet (5 chiffres)
/// │  │  └───────────────────────── code banque (5 chiffres)
/// │  └──────────────────────────── clé de contrôle IBAN (2 chiffres)
/// └─────────────────────────────── code pays
/// ```
///
/// Validation par la clé de contrôle ISO 7064 : les 4 premiers caractères
/// sont déplacés à la fin, les lettres converties en nombres (A=10 …
/// Z=35), et le tout doit être congru à 1 modulo 97. Cette clé est
/// fortement discriminante, d'où une confiance de 1.0.
final class IbanFrDetector implements EntityDetector {
  const IbanFrDetector();

  @override
  EntityType get type => EntityType.iban;

  /// `FR` + 2 chiffres + 23 alphanumériques, séparateurs espace ou tiret
  /// tolérés, non enchâssé dans une séquence alphanumérique plus longue.
  static final RegExp _candidate = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9]{2}(?:[ \-]?[0-9A-Za-z]){23}(?![0-9A-Za-z])',
  );

  static final RegExp _separators = RegExp(r'[ \-]');

  @override
  List<DetectedEntity> detect(String text) {
    // Neutralise d'abord les espaces (multiples, insécables, tabulations)
    // internes à une séquence de chiffres — un RIB affiché en tableau
    // n'utilise pas toujours un séparateur simple entre les groupes.
    // `_candidate` tolère déjà un séparateur unique par caractère, donc ce
    // repli sur le format « collé » suffit à couvrir les deux cas.
    final compaction = DigitCompaction(text);

    final results = <DetectedEntity>[];
    for (final match in _candidate.allMatches(compaction.compact)) {
      final start = compaction.originalStart(match.start);
      final end = compaction.originalEnd(match.end);
      final raw = text.substring(start, end);
      // Normalise depuis le match *compact* (déjà nettoyé des espaces
      // internes, quels qu'ils soient) plutôt que depuis `raw` : `raw`
      // vient du texte d'origine et peut encore contenir des séparateurs
      // que `_separators` ne connaît pas (tabulation, espace insécable).
      final normalized =
          match.group(0)!.replaceAll(_separators, '').toUpperCase();
      if (_isValidIban(normalized)) {
        results.add(
          DetectedEntity(
            type: EntityType.iban,
            start: start,
            end: end,
            value: raw,
            confidence: 1.0,
          ),
        );
      }
    }
    return results;
  }

  /// Valide un IBAN normalisé (27 caractères, majuscules, sans séparateurs)
  /// selon ISO 7064 (mod 97-10).
  static bool _isValidIban(String iban) {
    if (iban.length != 27) return false;

    // Réarrangement : BBAN + code pays + clé.
    final rearranged = iban.substring(4) + iban.substring(0, 4);

    // Calcul du modulo 97 en flux, chiffre par chiffre, pour éviter tout
    // dépassement d'entier (l'équivalent numérique fait ~30 chiffres).
    var remainder = 0;
    for (final unit in rearranged.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        // Chiffre.
        remainder = (remainder * 10 + (unit - 0x30)) % 97;
      } else if (unit >= 0x41 && unit <= 0x5A) {
        // Lettre A-Z → 10-35, soit deux chiffres.
        final value = unit - 0x41 + 10;
        remainder = (remainder * 100 + value) % 97;
      } else {
        return false;
      }
    }
    return remainder == 1;
  }
}
