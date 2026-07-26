/// Texte prêt pour la détection : version normalisée + projection des
/// positions vers le texte brut d'origine.
///
/// Pour ce jalon, `normalized` vaut `raw` tel quel et `toRawOffset` est
/// l'identité : la normalisation par blocs de chiffres (`DigitCompaction`)
/// reste interne à `NirDetector`/`IbanFrDetector`, qui reprojettent déjà
/// leurs propres positions avant de renvoyer une `DetectedEntity`. Chaque
/// `Detector` reçoit donc `raw` en pratique (voir les adaptateurs dans
/// `detector.dart`) ; ce type existe pour donner au moteur un point
/// d'extension unique le jour où une normalisation partagée (et sa
/// reprojection) sera nécessaire pour un nouveau détecteur.
class NormalizedText {
  const NormalizedText({
    required this.raw,
    required this.normalized,
    required this.toRawOffset,
  });

  /// Texte original, non modifié.
  final String raw;

  /// Texte après normalisation. Identique à [raw] pour ce jalon.
  final String normalized;

  /// Projette une position du texte normalisé vers le texte brut.
  /// Identité pour ce jalon (voir la note de classe).
  final int Function(int normalizedIndex) toRawOffset;

  factory NormalizedText.identity(String raw) => NormalizedText(
        raw: raw,
        normalized: raw,
        toRawOffset: (i) => i,
      );
}
