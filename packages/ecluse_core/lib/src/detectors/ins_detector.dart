import '../detector.dart';
import '../entity.dart';

/// Détecteur d'Identité Nationale de Santé (INS).
///
/// L'INS est référencée par un triplet (matricule, OID de référentiel,
/// traits d'identité stricts). Ce détecteur se limite à ce qui est
/// **localement observable dans un texte libre** : les OIDs INS français
/// (préfixe ANS `1.2.250.1.213.1.4.*`) et les marqueurs textuels
/// (`INS-NIR`, `matricule INS`, `identité nationale de santé`, etc.).
///
/// L'association marqueur ↔ NIR proche (reclassification NIR → INS) est
/// du ressort de `EcluseEngine` via `resolveOverlaps` — le détecteur reste
/// local et testable, la fusion multi-couches reste centralisée.
///
/// **À faire vérifier avec l'ANS** : la table [defaultOidToKind] repose
/// sur les OIDs observés dans les DUI Ségur vague 2. Le préfixe
/// `1.2.250.1.213.1.4.` (ANS-santé) est stable ; seuls les suffixes
/// précis peuvent bouger entre versions du CI-SIS.
final class InsDetector implements EntityDetector {
  const InsDetector({
    Map<String, InsIdentityKind>? oidCatalog,
    Set<String>? textualMarkers,
  })  : _oidCatalog = oidCatalog ?? defaultOidToKind,
        _textualMarkers = textualMarkers ?? defaultTextualMarkers;

  final Map<String, InsIdentityKind> _oidCatalog;
  final Set<String> _textualMarkers;

  /// OIDs INS courants observés dans le CI-SIS Ségur vague 2.
  ///
  /// Le préfixe `1.2.250.1.213.1.4.` est le segment ANS-santé stable ;
  /// seuls les suffixes précis peuvent évoluer entre versions.
  static const Map<String, InsIdentityKind> defaultOidToKind = {
    '1.2.250.1.213.1.4.8': InsIdentityKind.nir,
    '1.2.250.1.213.1.4.9': InsIdentityKind.nir,
    '1.2.250.1.213.1.4.10': InsIdentityKind.nia,
    '1.2.250.1.213.1.4.11': InsIdentityKind.nis,
  };

  /// Étiquettes textuelles qui identifient un INS dans un document.
  ///
  /// Insensibles à la casse. Séparateurs flexibles (`INS-NIR`,
  /// `INS NIR`, `INS  NIR` tous acceptés).
  static const Set<String> defaultTextualMarkers = {
    'INS-NIR',
    'INS-NIA',
    'INS-NIS',
    'INS-C',
    'INS-A',
    'INSi',
    'matricule INS',
    'identifiant national de santé',
    'identite nationale de sante',
    'identité nationale de santé',
  };

  @override
  EntityType get type => EntityType.ins;

  /// Regex sur les OIDs commençant par le préfixe ANS-santé.
  static final RegExp _oidPattern = RegExp(
    r'\b1\.2\.250\.1\.213\.1\.4(?:\.\d+)+\b',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[
      ..._detectOids(text),
      ..._detectTextualMarkers(text),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return results;
  }

  Iterable<DetectedEntity> _detectOids(String text) sync* {
    for (final match in _oidPattern.allMatches(text)) {
      final oid = match.group(0)!;
      final kind = _oidCatalog[oid];
      yield DetectedEntity(
        type: EntityType.ins,
        start: match.start,
        end: match.end,
        value: oid,
        // OID catalogué : confiance haute. OID à préfixe INS mais
        // suffixe inconnu : confiance modérée, signalé plutôt que raté.
        confidence: kind == null ? 0.6 : 0.95,
      );
    }
  }

  Iterable<DetectedEntity> _detectTextualMarkers(String text) sync* {
    for (final marker in _textualMarkers) {
      final normalized = marker.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = normalized.split(RegExp(r'[\s-]+')).map(RegExp.escape);
      final pattern = RegExp(
        r'(?<![A-Za-zÀ-ÿ0-9])' + parts.join(r'[\s-]+') + r'(?![A-Za-zÀ-ÿ0-9])',
        caseSensitive: false,
      );
      for (final match in pattern.allMatches(text)) {
        yield DetectedEntity(
          type: EntityType.ins,
          start: match.start,
          end: match.end,
          value: text.substring(match.start, match.end),
          confidence: 0.9,
        );
      }
    }
  }

  /// Reconnaît un OID au préfixe ANS-santé même s'il n'est pas dans le
  /// catalogue par défaut. Utile pour signaler « ressemble à un INS ».
  static bool hasInsOidPrefix(String oid) =>
      oid.startsWith('1.2.250.1.213.1.4.');
}

/// Nature de l'identifiant INS reconnu.
enum InsIdentityKind {
  /// Matricule NIR (personne née en France, INSEE).
  nir,

  /// Identifiant d'attente (personne en cours d'attribution).
  nia,

  /// Identifiant provisoire (situation particulière).
  nis,
}
