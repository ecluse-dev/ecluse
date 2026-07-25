import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique d'adresses postales simples — **v0 de
/// démonstration**.
///
/// Reconnaît deux motifs :
///
/// 1. `numéro + type de voie + nom de voie + code postal (5 chiffres) +
///    commune`, par exemple `12 rue des Lilas, 75015 Paris` → confiance
///    modérée (0.7) : le numéro et le type de voie sont un indice fort.
/// 2. `code postal (5 chiffres) + commune` **seul**, sans numéro ni type de
///    voie devant (ex. adresse sur sa propre ligne dans un formulaire :
///    `70160 Saint Rémy en Comté`) → confiance plus faible (0.55) : sans le
///    numéro/type de voie, l'indice est moins spécifique. Un code postal
///    isolé, sans nom de commune qui suit, n'est **jamais** masqué à lui
///    seul (5 chiffres seuls n'identifient personne).
///
/// Aucune validation possible dans les deux cas (pas d'annuaire des voies ni
/// des communes embarqué). Ne couvre pas les adresses sans code postal, les
/// boîtes postales, ni les formats étrangers. Sera affiné en phase 2 (NER +
/// table INSEE).
final class AdresseDetector implements EntityDetector {
  const AdresseDetector();

  @override
  EntityType get type => EntityType.adresse;

  static const _voies = [
    'rue',
    'avenue',
    'boulevard',
    'chemin',
    'impasse',
    'allée',
    'allee',
    'place',
    'route',
    'quai',
    'square',
    'passage',
    'cours',
    'lotissement',
  ];

  /// `code postal (5 chiffres) + commune`, réutilisé tel quel comme fin du
  /// motif complet et comme motif autonome pour une adresse sans numéro ni
  /// type de voie.
  static const _codePostalCommune = "\\d{5}\\s+[A-ZÀ-ÖØ-Þ][\\wÀ-ÖØ-Þà-öø-ÿ'’-]*"
      "(?:[ -][A-ZÀ-ÖØ-Þ][\\wÀ-ÖØ-Þà-öø-ÿ'’-]*){0,3}";

  static final RegExp _pattern = RegExp(
    "\\d{1,4}\\s*,?\\s*(?:${_voies.join('|')})"
    "\\s+[A-ZÀ-ÖØ-Þa-zà-öø-ÿ0-9'’\\- ]+?,?\\s*"
    "$_codePostalCommune",
    caseSensitive: false,
  );

  static final RegExp _codePostalCommuneOnly = RegExp(
    _codePostalCommune,
    caseSensitive: false,
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    final claimed = <_Range>[];

    for (final match in _pattern.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: match.group(0)!,
          confidence: 0.7,
        ),
      );
      claimed.add(_Range(start, end));
    }

    for (final match in _codePostalCommuneOnly.allMatches(text)) {
      final start = match.start;
      final end = match.end;
      // Déjà couvert par une adresse complète (numéro + voie) ci-dessus :
      // ne pas ajouter un doublon pour le seul suffixe "code postal +
      // commune" de cette même adresse.
      if (claimed.any((r) => r.overlaps(start, end))) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: match.group(0)!,
          confidence: 0.55,
        ),
      );
      claimed.add(_Range(start, end));
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }
}

final class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && start < otherEnd;
}
