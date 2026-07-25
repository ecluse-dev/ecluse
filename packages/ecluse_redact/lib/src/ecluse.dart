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
/// final result = Ecluse.redact(texte);
/// // result.maskedText -> texte à envoyer à l'IA
/// // result.mapping    -> table jeton ↔ valeur réelle (reste en mémoire)
/// // result.entities   -> entités détectées (type, confiance)
///
/// final finalText = Ecluse.restore(reponseDuLLM, result.mapping);
/// ```
///
/// `Ecluse.redact` combine les détecteurs à validation structurelle
/// d'`ecluse_core` (NIR, RPPS, IBAN) et les détecteurs heuristiques v0 de
/// ce package (voir `lib/src/heuristics/`, remplacés en phase 2 par un
/// NER local — voir ROADMAP.md).
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
  static const List<EntityDetector> defaultDetectors = [
    NirDetector(),
    RppsDetector(),
    IbanFrDetector(),
    NameDetector(),
    DateNaissanceDetector(),
    AdresseDetector(),
    TelephoneDetector(),
    EmailDetector(),
    EtablissementDetector(),
  ];

  /// Détecte les entités personnelles de [text] et produit un texte masqué
  /// par jetons typés, ainsi que la table de correspondance nécessaire à
  /// [restore].
  ///
  /// Une même valeur détectée reçoit toujours le même jeton dans tout le
  /// texte, pour que le LLM garde le fil des références.
  static RedactResult redact(
    String text, {
    List<EntityDetector> detectors = defaultDetectors,
  }) {
    final raw = <DetectedEntity>[
      for (final detector in detectors) ...detector.detect(text),
    ];
    final resolved = resolveOverlaps(raw);

    final mapping = <String, String>{};
    final tokenByValue = <String, String>{};
    final counterByType = <EntityType, int>{};
    final buffer = StringBuffer();
    var cursor = 0;

    for (final entity in resolved) {
      buffer.write(text.substring(cursor, entity.start));
      final token = tokenByValue.putIfAbsent(entity.value, () {
        final next = (counterByType[entity.type] ?? 0) + 1;
        counterByType[entity.type] = next;
        final generated = '[${entityTypeLabel(entity.type)}_$next]';
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
