import '../detector.dart';
import '../entity.dart';

/// Détecteur de NIR — Numéro d'Inscription au Répertoire, plus connu
/// comme « numéro de sécurité sociale » français.
///
/// Structure d'un NIR complet (15 chiffres) :
///
/// ```
/// S AA MM DD CCC OOO KK
/// │ │  │  │  │   │   └─ clé de contrôle (2 chiffres)
/// │ │  │  │  │   └───── numéro d'ordre (3 chiffres)
/// │ │  │  │  └───────── commune ou pays de naissance (3 chiffres)
/// │ │  │  └──────────── département (01-99, 2A, 2B)
/// │ │  └─────────────── mois de naissance (01-12)
/// │ └────────────────── année de naissance (2 chiffres)
/// └──────────────────── sexe / catégorie (1-8)
/// ```
///
/// La clé vaut `97 - (N mod 97)` où N est le NIR sans la clé, lu comme un
/// entier de 13 chiffres. Pour la Corse, `2A` est remplacé par `19` et
/// `2B` par `18` avant le calcul.
///
/// Ce détecteur ne retourne que des NIR dont la clé de contrôle est
/// **structurellement valide** (confiance 1.0). Un faux NIR syntaxiquement
/// plausible mais à clé invalide est ignoré : c'est ce qui distingue une
/// validation structurelle d'un simple motif regex, et ce qui maintient un
/// taux de faux positifs proche de zéro.
final class NirDetector implements EntityDetector {
  const NirDetector();

  @override
  EntityType get type => EntityType.nir;

  /// Candidats : 15 caractères utiles, séparateurs optionnels (espace,
  /// point, tiret), `2A`/`2B` accepté en position de département. Les
  /// lookarounds interdisent qu'un candidat soit enchâssé dans une
  /// séquence de chiffres plus longue.
  static final RegExp _candidate = RegExp(
    r'(?<![0-9])'
    r'[1-8][ .\-]?'
    r'[0-9]{2}[ .\-]?'
    r'[0-9]{2}[ .\-]?'
    r'(?:[0-9]{2}|2[ABab])[ .\-]?'
    r'[0-9]{3}[ .\-]?'
    r'[0-9]{3}[ .\-]?'
    r'[0-9]{2}'
    r'(?![0-9])',
  );

  static final RegExp _separators = RegExp(r'[ .\-]');

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _candidate.allMatches(text)) {
      final raw = match.group(0)!;
      final normalized = raw.replaceAll(_separators, '').toUpperCase();
      if (_isValidNir(normalized)) {
        results.add(
          DetectedEntity(
            type: EntityType.nir,
            start: match.start,
            end: match.end,
            value: raw,
            confidence: 1.0,
          ),
        );
      }
    }
    return results;
  }

  /// Valide un NIR normalisé (15 caractères, sans séparateurs, majuscules).
  static bool _isValidNir(String nir) {
    if (nir.length != 15) return false;

    // Mois de naissance : 01 à 12.
    // NOTE v0 : les mois fictifs attribués par l'INSEE en cas de date
    // inconnue (20, 30-42, 50-99) ne sont pas encore acceptés.
    final month = int.tryParse(nir.substring(3, 5));
    if (month == null || month < 1 || month > 12) return false;

    // Département : 01-99 ou 2A/2B (Corse).
    final dept = nir.substring(5, 7);
    final isCorsica = dept == '2A' || dept == '2B';
    if (!isCorsica) {
      final deptNum = int.tryParse(dept);
      if (deptNum == null || deptNum < 1) return false;
    }

    // Numéro d'ordre : 001 à 999.
    final order = int.tryParse(nir.substring(10, 13));
    if (order == null || order < 1) return false;

    // Clé de contrôle.
    final body = nir
        .substring(0, 13)
        .replaceFirst('2A', '19', 5)
        .replaceFirst('2B', '18', 5);
    final number = int.tryParse(body);
    if (number == null) return false;

    final expectedKey = 97 - (number % 97);
    final actualKey = int.tryParse(nir.substring(13, 15));
    return actualKey == expectedKey;
  }
}
