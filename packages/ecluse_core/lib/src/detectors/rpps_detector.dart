import '../detector.dart';
import '../digit_compaction.dart';
import '../entity.dart';
import '../luhn.dart';

/// Détecteur de numéros RPPS — Répertoire Partagé des Professionnels de
/// Santé, l'identifiant national unique des professionnels de santé
/// français (médecins, pharmaciens, infirmiers, etc.).
///
/// Structure : 11 chiffres, dont le dernier est une clé de contrôle
/// calculée selon l'algorithme de Luhn sur le numéro complet.
///
/// Contrairement au NIR, le RPPS n'a pas de structure interne vérifiable
/// (pas de mois, pas de département) : la validation repose uniquement sur
/// la longueur et la clé de Luhn. Un nombre aléatoire de 11 chiffres a
/// environ 10 % de chances de passer Luhn, d'où une confiance de 0.9 et
/// non 1.0 — c'est l'illustration du modèle de confiance graduée d'Écluse.
final class RppsDetector implements EntityDetector {
  const RppsDetector();

  @override
  EntityType get type => EntityType.rpps;

  /// 11 chiffres, séparés au plus par un espace, un point ou un tiret, non
  /// enchâssés dans une séquence de chiffres plus longue.
  ///
  /// S'applique au texte *compacté* par [DigitCompaction] : les blancs
  /// exotiques (NBSP, espace fine insécable, tabulation, espaces multiples)
  /// y ont déjà disparu, comme pour `NirDetector`.
  static final RegExp _candidate = RegExp(
    r'(?<![0-9])[0-9](?:[ .\-]?[0-9]){10}(?![0-9])',
  );

  /// Forme syntaxique d'un IBAN FR (mêmes tolérances que
  /// `IbanFrDetector._candidate`), **sans validation de la clé de
  /// contrôle**.
  ///
  /// Un IBAN affiché par blocs de chiffres séparés d'un espace unique a
  /// exactement la forme que tolère [_candidate] (un chiffre puis jusqu'à
  /// dix fois « espace optionnel + chiffre ») : une somme de blocs
  /// consécutifs totalisant 11 chiffres peut passer Luhn par coïncidence.
  /// Quand l'IBAN englobant est lui-même invalide, `IbanFrDetector` ne
  /// produit aucune entité — rien pour départager ce faux positif via
  /// `resolveOverlaps`. Se fier à la seule *forme* (pas à la validité)
  /// écarte le candidat à la source, que l'IBAN soit valide ou non.
  static final RegExp _ibanShapedContext = RegExp(
    r'(?<![A-Za-z0-9])[Ff][Rr][0-9]{2}(?:[ \-./]?[0-9A-Za-z]){23}(?![0-9A-Za-z])',
  );

  /// Ce qui, juste après un candidat, prouve que ses deux derniers chiffres
  /// ouvrent une date ou un âge : la suite d'une date en chiffres
  /// (`/03/2024`, `.03.24`), un nom de mois (`mars`, `janv.`), ou `ans`.
  static final RegExp _suiteDateOuAge = RegExp(
    r'[/.\-][01]?[0-9][/.\-](?:19|20)?[0-9]{2}(?![0-9])'
    r'|[ \u00A0]+(?:janvier|janv\.?|f[ée]vrier|f[ée]vr\.?|mars|avril|avr\.?|mai'
    r'|juin|juillet|juil\.?|ao[uû]t|septembre|sept\.?|octobre|oct\.?'
    r'|novembre|nov\.?|d[ée]cembre|d[ée]c\.?)(?![A-Za-zÀ-ÿ])'
    r'|[ \u00A0]+ans(?![A-Za-zÀ-ÿ])',
    caseSensitive: false,
  );

  static final RegExp _blanc = RegExp(r'[ \t\u00A0\u2000-\u200A\u202F\u3000]');

  /// Un FINESS (ou un SIREN) suivi d'une date ou d'un âge (P2-174).
  ///
  /// Neuf chiffres à clé de Luhn valide, un blanc, puis deux chiffres : onze
  /// chiffres, la longueur d'un RPPS, et la clé de Luhn passe une fois sur
  /// dix. Le candidat avalait alors le jour de la date ou l'âge, sous le
  /// mauvais type (55 cas sur 800 au témoin
  /// `bench/generate_corpus_identifiant_suivi.py`, tous masqués : pas une
  /// fuite, un type faux et une date abîmée).
  ///
  /// Il n'est écarté que si **ce qui suit le prouve** : la suite d'une date
  /// ou « ans ». Suivi d'un mot quelconque (`123456789 12 exerce`), rien ne
  /// dit que « 12 » n'est pas la fin d'un RPPS écrit en deux groupes : le
  /// candidat reste, et les onze chiffres restent masqués. Dans le doute, le
  /// côté qui protège.
  static bool _finessPuisDateOuAge(String text, int start, int end) {
    final brut = text.substring(start, end);
    final coupe = brut.lastIndexOf(_blanc);
    if (coupe < 0) return false;
    final tete = brut.substring(0, coupe).replaceAll(RegExp(r'[^0-9]'), '');
    final queue = brut.substring(coupe + 1);
    if (tete.length != 9 || queue.length != 2 || !isLuhnValid(tete)) {
      return false;
    }
    return _suiteDateOuAge.matchAsPrefix(text, end) != null;
  }

  @override
  List<DetectedEntity> detect(String text) {
    final results = <DetectedEntity>[];
    final compaction = DigitCompaction(text);
    // La forme d'IBAN est cherchée par les mêmes passages que les candidats
    // (P2-174) : sinon un IBAN à blancs irréguliers (insécables, espaces
    // multiples), que le passage régularisé lit maintenant groupe par groupe,
    // n'était plus reconnu comme contexte et l'un de ses blocs de onze
    // chiffres pouvait passer pour un RPPS.
    final ibanShapedRanges = [
      for (final m in compaction.candidates(_ibanShapedContext))
        (m.start, m.end),
    ];
    for (final match in compaction.candidates(_candidate)) {
      // Positions déjà dans le texte d'origine (invariant d'offsets).
      final start = match.start;
      final end = match.end;
      final digits = match.text.replaceAll(RegExp(r'[ .\-]'), '');
      if (!isLuhnValid(digits)) continue;
      final embeddedInIban = ibanShapedRanges.any(
        (r) => start < r.$2 && r.$1 < end,
      );
      if (embeddedInIban) continue;
      if (_finessPuisDateOuAge(text, start, end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.rpps,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.9,
        ),
      );
    }
    return results;
  }
}
