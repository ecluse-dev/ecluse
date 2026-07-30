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
/// structurelle d'`ecluse_core` (NIR, RPPS, IBAN, FINESS) et les détecteurs
/// heuristiques v0 de ce package (voir `lib/src/heuristics/`, remplacés en
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
    final counterByType = <EntityType, int>{};
    final buffer = StringBuffer();
    var cursor = 0;

    for (final entity in resolved) {
      buffer.write(text.substring(cursor, entity.start));
      final token = tokenByIdentity.putIfAbsent(_identityKey(entity), () {
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

/// Clé d'identité utilisée pour regrouper sous un même jeton plusieurs
/// mentions d'une même personne — sans quoi le LLM peut croire qu'il s'agit
/// de deux personnes distinctes et produire une analyse fausse (pas une
/// fuite, mais une dégradation de la réponse).
///
/// Pour les noms : l'ordre nom/prénom et la casse ne changent pas
/// l'identité (« Dubreuil Thomas » = « Thomas Dubreuil » = « DUBREUIL
/// Thomas »), donc l'identité est l'ensemble trié des segments en
/// minuscules. Volontairement étroit : seuls des segments identiques
/// suffisent à fusionner deux mentions — pas de rapprochement partiel
/// (« Martin » seul ne fusionne pas avec « Jean Martin »), qui risquerait
/// de confondre deux personnes différentes.
///
/// Conséquence assumée : [Ecluse.restore] ne peut restituer qu'une seule
/// graphie par jeton (remplacement global dans la réponse du LLM, sans
/// notion de position). Une re-mention à ordre nom/prénom inversé de la
/// même personne voit donc son ordre harmonisé sur la première mention
/// lors de la restauration — voir `LIMITES.md`.
///
/// Pour tous les autres types, l'identité reste la valeur exacte : deux
/// adresses ou deux téléphones qui se ressemblent ne doivent jamais être
/// fusionnés sur une simple heuristique.
String _identityKey(DetectedEntity entity) {
  if (entity.type != EntityType.nom) {
    return '${entity.type.name}:${entity.value}';
  }
  final segments = entity.value
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((segment) => segment.isNotEmpty)
      .toList()
    ..sort();
  return 'nom:${segments.join(' ')}';
}
