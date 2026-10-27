import 'package:ecluse_core/ecluse_core.dart';

/// Détecteur d'identifiants étiquetés (P2-57), un type par catégorie (P2-59) : numéro de dossier, de patient,
/// d'adhérent, d'allocataire ou de contrat, IPP/IEP, passeport, CNI, permis de
/// conduire, plaque d'immatriculation, adresse IP.
///
/// Ces valeurs n'ont aucune structure vérifiable (pas de clé de contrôle) : la
/// seule garantie est l'**étiquette** qui les annonce, d'où une confiance
/// modérée (0.7) et une valeur qui doit en plus ressembler à un identifiant
/// (au moins 5 chiffres, ou 3 chiffres et une lettre sur 6 caractères). « Dossier
/// n° 12 », « Passeport 2024 » ou « IPP : à renseigner » ne sont jamais masqués.
/// Seule exception à l'étiquette : la plaque au format SIV (`AB-123-CD`, sans les
/// lettres I, O, U), assez spécifique seule.
final class IdentifiantDetector implements EntityDetector {
  const IdentifiantDetector();

  @override
  EntityType get type => EntityType.identifiant;

  static const String _h = '[ \\t\\u00A0\\u202F]';

  /// Mot « numéro » facultatif entre l'étiquette et la valeur.
  static const String _numero = '(?:(?:n[°º]|no\\.?|num\\.?|numéro)$_h*)?';

  /// Étiquettes qui annoncent un identifiant de personne ou de véhicule.
  static const String _etiquettes = '(?:'
      '\\b(?:IPP|IEP)\\b'
      '|\\bdossier(?:$_h+[A-Za-zÀ-ÿ]{2,12})?$_h*(?:n[°º]|no\\.?|numéro)'
      '|(?:n[°º]|no\\.?|num\\.?|numéro)$_h*(?:de$_h+|d[\'’])?'
      '(?:dossier|patient(?:e)?|adhérent(?:e)?|allocataire|contrat|police|'
      'sociétaire|client(?:e)?|passeport|carte)(?:$_h+[A-Za-zÀ-ÿ]{2,8})?'
      '|\\badhérent(?:e)?$_h*(?:n[°º]|no\\.?|numéro)'
      '|\\b(?:passeport|CNI|permis$_h+de$_h+conduire|'
      'carte$_h+(?:nationale$_h+)?d[\'’]identité)'
      '|\\b(?:immatriculation|plaque(?:$_h+d[\'’]immatriculation)?)'
      ')';

  static final RegExp _etiquette = RegExp(
    '$_etiquettes$_h*(?:[:=]$_h*)?$_numero(?:[:=]$_h*)?'
    '([A-Za-z0-9][A-Za-z0-9/._-]{2,24})',
    caseSensitive: false,
  );

  /// Plaque au format SIV, étiquetée ou non.
  static final RegExp _plaque = RegExp(
    r'(?<![A-Za-z0-9-])[A-HJ-NP-TV-Z]{2}-[0-9]{3}-[A-HJ-NP-TV-Z]{2}'
    r'(?![A-Za-z0-9-])',
  );

  /// Adresse IPv4 derrière « IP » / « adresse IP ».
  static final RegExp _ip = RegExp(
    '\\b(?:adresse$_h+)?IP$_h*[:=]?$_h*'
    r'((?:[0-9]{1,3}\.){3}[0-9]{1,3})(?![0-9.]*[0-9])',
    caseSensitive: false,
  );

  /// Catégorie de l'identifiant d'après son étiquette (P2-59).
  static final RegExp _etiquettePiece = RegExp(
    'passeport|CNI|permis|identité',
    caseSensitive: false,
  );
  static final RegExp _etiquetteVehicule =
      RegExp('immatriculation|plaque', caseSensitive: false);

  static EntityType _categorie(String etiquette) {
    if (_etiquettePiece.hasMatch(etiquette)) return EntityType.pieceIdentite;
    if (_etiquetteVehicule.hasMatch(etiquette)) return EntityType.vehicule;
    return EntityType.identifiant;
  }

  static bool _ressembleAUnIdentifiant(String valeur) {
    final chiffres = RegExp('[0-9]').allMatches(valeur).length;
    final lettres = RegExp('[A-Za-z]').allMatches(valeur).length;
    return chiffres >= 5 ||
        (chiffres >= 3 && lettres >= 1 && valeur.length >= 6);
  }

  @override
  List<DetectedEntity> detect(String text) {
    final trouves = <DetectedEntity>[];
    for (final match in _etiquette.allMatches(text)) {
      var valeur = match.group(1)!;
      // Ponctuation de fin de phrase : jamais dans l'identifiant.
      valeur = valeur.replaceFirst(RegExp(r'[./_-]+$'), '');
      if (!_ressembleAUnIdentifiant(valeur)) continue;
      final debut = match.start + match.group(0)!.lastIndexOf(match.group(1)!);
      trouves.add(DetectedEntity(
        type: _categorie(text.substring(match.start, debut)),
        start: debut,
        end: debut + valeur.length,
        value: valeur,
        confidence: 0.7,
      ));
    }
    for (final match in _ip.allMatches(text)) {
      final valeur = match.group(1)!;
      if (valeur.split('.').any((o) => int.parse(o) > 255)) continue;
      final debut = match.start + match.group(0)!.lastIndexOf(valeur);
      trouves.add(DetectedEntity(
        type: EntityType.reseau,
        start: debut,
        end: debut + valeur.length,
        value: valeur,
        confidence: 0.7,
      ));
    }
    for (final match in _plaque.allMatches(text)) {
      trouves.add(DetectedEntity(
        type: EntityType.vehicule,
        start: match.start,
        end: match.end,
        value: match.group(0)!,
        confidence: 0.7,
      ));
    }
    // Une plaque étiquetée est trouvée par les deux motifs : on garde un seul
    // intervalle par position.
    trouves
        .sort((a, b) => a.start != b.start ? a.start - b.start : b.end - a.end);
    final sortie = <DetectedEntity>[];
    for (final e in trouves) {
      if (sortie.isNotEmpty && e.start < sortie.last.end) continue;
      sortie.add(e);
    }
    return sortie;
  }
}
