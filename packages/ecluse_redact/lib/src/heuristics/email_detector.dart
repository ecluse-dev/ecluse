import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique d'adresses email — **v0 de démonstration**.
///
/// Motif standard `local@domaine.tld`. Une adresse email bien formée est un
/// indice très spécifique (peu de faux positifs) mais reste un motif, pas
/// une validation structurelle (pas de vérification DNS/MX) : confiance
/// haute (0.85).
///
/// Le span exclut la ponctuation collée (point final, virgule, chevrons,
/// parenthèses, `mailto:`) : l'espace de remplacement ne doit pas manger
/// un caractère du texte de l'utilisateur.
///
/// Obfuscations reconnues, car sans risque de faux positif : `[at]`,
/// `(at)`, `[arobase]`, `(arobase)` (casse indifférente, espaces
/// facultatifs) **suivis d'un domaine avec TLD**. Confiance abaissée
/// (0.7) : c'est une adresse volontairement déguisée, donc plus
/// probablement réelle, mais le motif est moins canonique. Un « at » ou
/// « arobase » écrit en clair (`jean at example.fr`) n'est volontairement
/// **pas** détecté : trop de texte courant ressemble à ce motif (voir
/// `LIMITES.md`).
final class EmailDetector implements EntityDetector {
  const EmailDetector();

  @override
  EntityType get type => EntityType.email;

  /// Label de domaine : alphanumérique aux extrémités, tirets au milieu
  /// (pas de label vide, donc pas de points consécutifs).
  static const String _label = r'[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?';

  /// Séparateur local/domaine : `@`, ou une obfuscation entre crochets ou
  /// parenthèses. `[ \t]` et non `\s` : ne jamais traverser une fin de
  /// ligne.
  static const String _at = r'(?:@|[ \t]*[\[(][ \t]*(?:[Aa][Tt]|'
      r'[Aa][Rr][Oo][Bb][Aa][Ss][Ee])[ \t]*[\])][ \t]*)';

  static final RegExp _pattern = RegExp(
    '[A-Za-z0-9_%+-][A-Za-z0-9._%+-]*$_at(?:$_label\\.)+[A-Za-z]{2,}',
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      final raw = match.group(0)!;
      results.add(
        DetectedEntity(
          type: EntityType.email,
          start: match.start,
          end: match.end,
          value: raw,
          confidence: raw.contains('@') ? 0.85 : 0.7,
        ),
      );
    }
    return results;
  }
}
