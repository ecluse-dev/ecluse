import '../detector.dart';
import '../entity.dart';

/// Nature de l'identifiant INS reconnu.
///
/// Correspond à la classification du référentiel INS publié par l'ANS
/// (Agence du Numérique en Santé). Deux familles sont en production
/// courante depuis 2021 ; la troisième reste indispensable pour
/// interpréter les dossiers médicaux antérieurs.
enum InsIdentityKind {
  /// Matricule NIR — personne inscrite au Répertoire National
  /// d'Identification des Personnes Physiques (INSEE).
  nir,

  /// NIA — Numéro Identifiant d'Attente, identifiant provisoire ANS
  /// pour une personne en cours d'attribution de NIR.
  nia,

  /// INS-C — Identifiant Calculé, historique, dérivé de la carte
  /// Vitale. Remplacé depuis 2021 par NIR/NIA en production mais
  /// toujours présent dans les archives médicales antérieures.
  insC,
}

/// Environnement d'attribution d'un OID INS.
///
/// La distinction est capitale : un OID de test ou de démonstration
/// dans un texte de production est **anormal** — soit fuite de jeu de
/// test dans un dossier réel, soit étiquetage erroné d'un vrai
/// identifiant. Un consommateur en aval peut le traiter comme signal
/// d'alerte plutôt que comme un INS ordinaire.
enum InsEnvironment {
  /// Identifiant réel de production.
  production,

  /// Environnement de test — ne devrait jamais apparaître dans un
  /// document patient réel.
  test,

  /// Environnement de démonstration — ne devrait jamais apparaître
  /// dans un document patient réel.
  demonstration,
}

/// Autorité d'affectation d'un OID INS : type d'identifiant +
/// environnement d'attribution.
final class InsOidAuthority {
  const InsOidAuthority(this.kind, this.environment);

  final InsIdentityKind kind;
  final InsEnvironment environment;

  /// `true` si l'OID appartient à l'environnement de production.
  bool get isProduction => environment == InsEnvironment.production;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsOidAuthority &&
          other.kind == kind &&
          other.environment == environment;

  @override
  int get hashCode => Object.hash(kind, environment);

  @override
  String toString() => 'InsOidAuthority(${kind.name}, ${environment.name})';
}

/// Détecteur d'Identité Nationale de Santé (INS).
///
/// L'INS est référencée par un triplet (matricule, OID de référentiel,
/// traits d'identité stricts). Ce détecteur se limite à ce qui est
/// **localement observable dans un texte libre** : les OIDs INS
/// français (préfixe ANS `1.2.250.1.213.1.4.*`) et les marqueurs
/// textuels (`INS-NIR`, `matricule INS`, `identité nationale de
/// santé`, etc.).
///
/// L'association marqueur ↔ NIR proche (reclassification NIR → INS)
/// est du ressort de `EcluseEngine` via `resolveOverlaps` — le
/// détecteur reste local et testable, la fusion multi-couches reste
/// centralisée.
///
/// **Source des OIDs** : « Référentiel Identifiant National de Santé
/// — Liste des OID des autorités d'affectation des INS » publié par
/// l'ANS (esante.gouv.fr). Le préfixe `1.2.250.1.213.1.4.`
/// (ANS-santé) est stable ; les suffixes sont figés au niveau du
/// référentiel.
final class InsDetector implements EntityDetector {
  const InsDetector({
    Map<String, InsOidAuthority>? oidCatalog,
    Set<String>? textualMarkers,
  })  : _oidCatalog = oidCatalog ?? defaultOidCatalog,
        _textualMarkers = textualMarkers ?? defaultTextualMarkers;

  final Map<String, InsOidAuthority> _oidCatalog;
  final Set<String> _textualMarkers;

  /// Catalogue par défaut des OIDs INS reconnus, tel que publié par
  /// l'ANS. Contient les trois familles :
  /// - **INS-NIR** (production, test, démonstration) — matricule INSEE.
  /// - **INS-NIA** (production) — identifiant d'attente.
  /// - **INS-C** historique (production, test, démonstration) —
  ///   identifiant calculé sur la carte Vitale, avant 2021.
  ///
  /// Tout OID commençant par le préfixe ANS mais absent du catalogue
  /// est détecté à confiance modérée (signalé plutôt que raté).
  static const Map<String, InsOidAuthority> defaultOidCatalog = {
    // INS-NIR (matricule INSEE)
    '1.2.250.1.213.1.4.8':
        InsOidAuthority(InsIdentityKind.nir, InsEnvironment.production),
    '1.2.250.1.213.1.4.10':
        InsOidAuthority(InsIdentityKind.nir, InsEnvironment.test),
    '1.2.250.1.213.1.4.11':
        InsOidAuthority(InsIdentityKind.nir, InsEnvironment.demonstration),
    // INS-NIA (identifiant d'attente)
    '1.2.250.1.213.1.4.9':
        InsOidAuthority(InsIdentityKind.nia, InsEnvironment.production),
    // INS-C historique (cartes Vitale, remplacé par NIR/NIA depuis 2021)
    '1.2.250.1.213.1.4.2':
        InsOidAuthority(InsIdentityKind.insC, InsEnvironment.production),
    '1.2.250.1.213.1.4.6':
        InsOidAuthority(InsIdentityKind.insC, InsEnvironment.test),
    '1.2.250.1.213.1.4.7':
        InsOidAuthority(InsIdentityKind.insC, InsEnvironment.demonstration),
  };

  /// Étiquettes textuelles qui identifient un INS dans un document.
  ///
  /// Insensibles à la casse. Séparateurs flexibles (`INS-NIR`,
  /// `INS NIR`, `INS  NIR` tous acceptés).
  static const Set<String> defaultTextualMarkers = {
    'INS-NIR',
    'INS-NIA',
    'INS-C',
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
      final authority = _oidCatalog[oid];
      yield DetectedEntity(
        type: EntityType.ins,
        start: match.start,
        end: match.end,
        value: oid,
        // OID catalogué : confiance haute. OID à préfixe INS mais
        // suffixe inconnu : confiance modérée, signalé plutôt que raté.
        confidence: authority == null ? 0.6 : 0.95,
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

  /// Reconnaît un OID au préfixe ANS-santé même s'il n'est pas dans
  /// le catalogue par défaut. Utile pour signaler « ressemble à un
  /// INS ».
  static bool hasInsOidPrefix(String oid) =>
      oid.startsWith('1.2.250.1.213.1.4.');

  /// Résout l'autorité d'affectation d'un OID (kind + environnement)
  /// s'il appartient au catalogue par défaut. Retourne `null` sinon.
  ///
  /// Un consommateur en aval peut s'appuyer sur `authority.environment`
  /// pour distinguer un identifiant de production d'un identifiant de
  /// test ou de démonstration (potentielle fuite de données de test).
  static InsOidAuthority? resolveAuthority(String oid) =>
      defaultOidCatalog[oid];
}
