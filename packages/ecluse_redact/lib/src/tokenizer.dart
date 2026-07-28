import 'package:ecluse_core/ecluse_core.dart';

/// Préfixe de jeton lisible associé à chaque [EntityType].
///
/// Un LLM comprend mieux un jeton typé (`[NOM_1]`) qu'un hash opaque, et
/// c'est plus parlant en démonstration — voir `BRIEF_DEMO.md`.
String entityTypeLabel(EntityType type) => switch (type) {
      EntityType.nir => 'NIR',
      EntityType.rpps => 'RPPS',
      EntityType.iban => 'IBAN',
      EntityType.finess => 'FINESS',
      EntityType.nom => 'NOM',
      EntityType.dateNaissance => 'DATE_NAISSANCE',
      EntityType.adresse => 'ADRESSE',
      EntityType.telephone => 'TELEPHONE',
      EntityType.email => 'EMAIL',
      EntityType.etablissement => 'ETABLISSEMENT',
    };

/// Construit une regex tolérante pour retrouver un jeton comme `[NOM_1]`
/// même si le LLM en a légèrement déformé la présentation (espaces
/// superflus autour des crochets ou du tiret bas, casse différente).
///
/// Volontairement strict au-delà de cette tolérance : pas de correspondance
/// approximative sur les chiffres (`[NOM_1]` ne doit jamais matcher
/// `[NOM_10]`) — mieux vaut ne pas restaurer un jeton déformé que restaurer
/// la mauvaise valeur.
RegExp tolerantTokenPattern(String token) {
  final inner = token.substring(1, token.length - 1);
  final escaped = RegExp.escape(inner).replaceAll('_', '[ _]*');
  return RegExp('\\[\\s*$escaped\\s*\\]', caseSensitive: false);
}
