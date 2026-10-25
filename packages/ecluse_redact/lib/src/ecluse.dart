import 'package:ecluse_core/ecluse_core.dart';

import 'heuristics/adresse_detector.dart';
import 'heuristics/date_naissance_detector.dart';
import 'heuristics/email_detector.dart';
import 'heuristics/etablissement_detector.dart';
import 'heuristics/name_detector.dart';
import 'heuristics/telephone_detector.dart';
import 'redact_result.dart';
import 'tokenizer.dart';

/// Façade de pseudonymisation réversible d'Écluse.
///
/// ```dart
/// final result = await Ecluse.redact(texte);
/// // result.maskedText -> texte à envoyer à l'IA
/// // result.mapping    -> table jeton ↔ valeur réelle (reste en mémoire)
/// // result.entities   -> entités détectées (type, confiance)
///
/// final finalText = Ecluse.restore(reponseDuLLM, result.mapping);
/// ```
///
/// `Ecluse.redact` compose, via `EcluseEngine`, les détecteurs à validation
/// structurelle d'`ecluse_core` (NIR, RPPS, IBAN, FINESS, INS) et les
/// détecteurs heuristiques v0 de ce package (voir `lib/src/heuristics/`, remplacés en
/// phase 2 par un NER local — voir ROADMAP.md). `redact` est async parce
/// que `Detector.detect` l'est (contrat uniforme avec le futur NER, qui
/// pourra tourner dans un isolate) — les détecteurs eux-mêmes restent
/// synchrones en interne.
///
/// **Aucun seuil de confiance ne filtre les entités masquées dans cette
/// version** : toute entité détectée, quelle que soit sa confiance, est
/// remplacée par un jeton. Principe : en cas de doute, on protège — un
/// faux positif masqué dégrade un peu le prompt envoyé au LLM, mais un
/// faux négatif non masqué est une fuite. Le routage par seuil de
/// confiance est une décision produit qui viendra plus tard (voir
/// ROADMAP.md, « routage on-device/cloud selon la sensibilité »), pas une
/// décision à prendre silencieusement dans le moteur de redaction.
abstract final class Ecluse {
  /// Détecteurs utilisés par défaut par [redact].
  static const List<Detector> defaultDetectors = [
    LegacyDetectorAdapter(NirDetector(), DetectorTier.structural, name: 'nir'),
    LegacyDetectorAdapter(RppsDetector(), DetectorTier.structural,
        name: 'rpps'),
    LegacyDetectorAdapter(IbanFrDetector(), DetectorTier.structural,
        name: 'iban'),
    LegacyDetectorAdapter(InsDetector(), DetectorTier.structural, name: 'ins'),
    FinessDetector(),
    LegacyDetectorAdapter(NameDetector(), DetectorTier.reference, name: 'nom'),
    LegacyDetectorAdapter(DateNaissanceDetector(), DetectorTier.pattern,
        name: 'date_naissance'),
    LegacyDetectorAdapter(AdresseDetector(), DetectorTier.pattern,
        name: 'adresse'),
    LegacyDetectorAdapter(TelephoneDetector(), DetectorTier.pattern,
        name: 'telephone'),
    LegacyDetectorAdapter(EmailDetector(), DetectorTier.pattern, name: 'email'),
    LegacyDetectorAdapter(EtablissementDetector(), DetectorTier.pattern,
        name: 'etablissement'),
  ];

  /// Détecte les entités personnelles de [text] et produit un texte masqué
  /// par jetons typés, ainsi que la table de correspondance nécessaire à
  /// [restore].
  ///
  /// Une même valeur détectée reçoit toujours le même jeton dans tout le
  /// texte, pour que le LLM garde le fil des références.
  static Future<RedactResult> redact(
    String text, {
    List<Detector>? detectors,
  }) async {
    final engine = EcluseEngine(detectors ?? defaultDetectors);
    final detection = await engine.run(text);
    final resolved = detection.entities;

    final mapping = <String, String>{};
    final tokenByIdentity = <String, String>{};
    final nomIdentities = <_NomIdentity>[];
    final counterByType = <EntityType, int>{};
    final buffer = StringBuffer();
    var cursor = 0;

    for (final entity in resolved) {
      buffer.write(text.substring(cursor, entity.start));
      final token = entity.type == EntityType.nom
          ? _resolveNomToken(
              entity,
              nomIdentities,
              counterByType,
              mapping,
              text,
            )
          : tokenByIdentity.putIfAbsent(_identityKey(entity), () {
              final generated = _freshToken(entity.type, counterByType, text);
              mapping[generated] = entity.value;
              return generated;
            });
      buffer.write(token);
      cursor = entity.end;
    }
    buffer.write(text.substring(cursor));

    return RedactResult(
      maskedText: buffer.toString(),
      mapping: Map.unmodifiable(mapping),
      entities: resolved,
    );
  }

  /// Remplace chaque jeton présent dans [text] par sa valeur réelle depuis
  /// [mapping]. Tolère une déformation raisonnable du jeton par le LLM
  /// (espaces superflus, casse) mais ne devine jamais une correspondance
  /// approximative — voir [tolerantTokenPattern].
  static String restore(String text, Map<String, String> mapping) {
    var result = text;
    for (final entry in mapping.entries) {
      result = result.replaceAll(tolerantTokenPattern(entry.key), entry.value);
    }
    return result;
  }
}

/// Clé d'identité pour les types **autres que `nom`** : l'identité est la
/// valeur exacte. Deux adresses ou deux téléphones qui se ressemblent ne
/// doivent jamais être fusionnés sur une simple heuristique. Les noms
/// suivent une résolution différente, plus riche — voir
/// [_resolveNomToken].
String _identityKey(DetectedEntity entity) =>
    '${entity.type.name}:${entity.value}';

/// Ensemble de segments (minuscules) déjà associés à un jeton `nom`.
final class _NomIdentity {
  _NomIdentity(this.segments, this.token, this.gender);

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
  if (RegExp(r'(?:^|[^\wÀ-ÿ])(?:M\.|Mr\.?|Monsieur)[ \t\u00A0\u202F]*$')
      .hasMatch(head)) {
    return 'm';
  }
  if (RegExp(r'(?:^|[^\wÀ-ÿ])(?:Mme|Mlle|Mrs\.?|Madame|Mademoiselle)'
          r'[ \t\u00A0\u202F]*$')
      .hasMatch(head)) {
    return 'f';
  }
  return null;
}

/// Segments (minuscules, sans doublons) d'une mention de nom — insensible
/// à l'ordre et à la casse : « Dubreuil Thomas » et « Thomas Dubreuil »
/// produisent le même ensemble.
Set<String> _nameSegments(String value) => value
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((segment) => segment.isNotEmpty)
    .toSet();

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
  List<_NomIdentity> identities,
  Map<EntityType, int> counterByType,
  Map<String, String> mapping,
  String text,
) {
  final segments = _nameSegments(entity.value);
  final gender = _genderBefore(text, entity.start);
  final matches = identities
      .where(
        (identity) =>
            // Deux civilités de sexe différent désignent deux personnes,
            // même avec un patronyme commun (un couple).
            !(gender != null &&
                identity.gender != null &&
                gender != identity.gender) &&
            (segments.every(identity.segments.contains) ||
                identity.segments.every(segments.contains)),
      )
      .toList();

  if (matches.length == 1) {
    final identity = matches.single;
    identity.gender ??= gender;
    if (segments.length > identity.segments.length) {
      // Forme la plus complète rencontrée : la carte de restauration la
      // reprend (« Dr Nadia Costa » plutôt que le « Costa » de la première
      // mention), comme le promet `LIMITES.md` §5.3 — sans cela, les
      // mentions complètes perdaient prénom et titre à la restauration.
      identity.segments = segments;
      mapping[identity.token] = entity.value;
    }
    return identity.token;
  }

  final token = _freshToken(EntityType.nom, counterByType, text);
  mapping[token] = entity.value;
  identities.add(_NomIdentity(segments, token, gender));
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
  } while (tolerantTokenPattern(token).hasMatch(text));
  counterByType[type] = next;
  return token;
}
