import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur heuristique de noms d'établissements — **v0 de
/// démonstration**.
///
/// Motif : un mot-clé caractéristique du secteur médico-social (`Foyer`,
/// `Résidence`, `IME`, `ITEP`, `ESAT`, `EHPAD`, `MAS`, `FAM`, `Centre`)
/// suivi d'un nom propre. Un établissement nommé participe au pouvoir
/// d'identification d'une personne (« le directeur de l'EHPAD Les
/// Tilleuls ») au même titre qu'un nom de personne — voir la philosophie
/// du README racine sur le faisceau d'indices. Confiance modérée (0.7) :
/// le mot-clé est un indice fort, mais le nom propre qui suit n'est pas
/// validé (pas d'annuaire des établissements embarqué).
final class EtablissementDetector implements EntityDetector {
  const EtablissementDetector();

  @override
  EntityType get type => EntityType.etablissement;

  static const _keywords = [
    'Foyer',
    'Résidence',
    'Residence',
    'IME',
    'ITEP',
    'ESAT',
    'EHPAD',
    'MAS',
    'FAM',
    'Centre',
  ];

  static final RegExp _pattern = RegExp(
    '(?:${_keywords.join('|')})'
    r"\s+(?:d['’]accueil\s+|de\s+|des\s+|du\s+|d['’])?"
    r"[A-ZÀ-Ÿ][\wÀ-ÿ'’\-]*(?:\s+[A-ZÀ-Ÿ][\wÀ-ÿ'’\-]*){0,3}",
  );

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    for (final match in _pattern.allMatches(text)) {
      results.add(
        DetectedEntity(
          type: EntityType.etablissement,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.7,
        ),
      );
    }
    return results;
  }
}
