import 'package:ecluse_core/ecluse_core.dart';

import 'casse.dart';

/// Initiale et patronyme après un libellé qui annonce une personne (P2-147) :
/// « Présent : T. Lefèvre », « Présents : S. Verdier, K. Perrot et
/// A. Chevrier », « Rédacteur : É. Mérieux ».
///
/// Pourquoi un détecteur à part : `NameDetector` ne reconnaît une initiale
/// suivie d'un patronyme que si ce patronyme a déjà été établi par une mention
/// complète. Dans un compte rendu de réunion, la liste des présents est
/// souvent la seule mention. Mesure P2-89 : 402 caractères de noms en clair
/// sur le corpus adversarial, premier angle mort des heuristiques.
///
/// Prudence : le libellé doit figurer dans [_libelles] (« Annexe : A.
/// Introduction » ou « Article : L. 1110-4 » ne donnent rien), et le mot qui
/// suit l'initiale doit commencer par une majuscule et ne pas être un mot
/// outil (« Présent : A. Le reste… »). Casse ordinaire seulement : en
/// minuscules ou en capitales, `NomMinusculesDetector` couvre déjà ce cas
/// (P2-139).
final class InitialeLibelleDetector implements EntityDetector {
  const InitialeLibelleDetector();

  @override
  EntityType get type => EntityType.nom;

  /// Libellés de personne, sans accent obligatoire sur la première lettre.
  static const String _libelles =
      r'(?:Pr[ée]sente?s?|Excus[ée]e?s?|Absente?s?|R[ée]dacteur|R[ée]dactrice|'
      r'R[ée]dig[ée] par|Sign[ée]|Signataire|Auteur|Autrice|R[ée]f[ée]rente?s?|'
      r'Destinataires?|Interlocut(?:eur|rice)|Valid[ée] par|Vu par|'
      r'Copie [àa]|Participants?|Participantes?)';

  static const String _nom = r'[A-ZÀ-ÖØ-Ý]\.[ \t\u00A0\u202F]?[A-ZÀ-ÖØ-Ý][a-zà-öø-ÿ]+'
      r"(?:[-'’][A-ZÀ-ÖØ-Ý]?[a-zà-öø-ÿ]+)*";

  static final RegExp _ligne = RegExp(
      '(?:^|\\n)[ \\t]*$_libelles[ \\t]*:?[ \\t]*((?:$_nom)'
      '(?:[ \\t]*(?:,|et)[ \\t]*$_nom)*)',
      multiLine: true);

  static final RegExp _unNom = RegExp(_nom);

  static const Set<String> _outils = {
    'Le', 'La', 'Les', 'Un', 'Une', 'De', 'Du', 'Des', 'Et', 'Ou', 'En', //
    'Au', 'Aux', 'Ce', 'Ces', 'Cette', 'Il', 'Elle', 'On', 'Par', 'Pour', //
  };

  @override
  List<DetectedEntity> detect(String text) {
    if (casseDuTexte(text) != CasseTexte.ordinaire) return const [];
    final out = <DetectedEntity>[];
    for (final ligne in _ligne.allMatches(text)) {
      final liste = ligne.group(1)!;
      final base = ligne.end - liste.length;
      for (final m in _unNom.allMatches(liste)) {
        final patronyme =
            m.group(0)!.substring(m.group(0)!.indexOf('.') + 1).trimLeft();
        if (_outils.contains(patronyme)) continue;
        out.add(DetectedEntity(
          type: EntityType.nom,
          start: base + m.start,
          end: base + m.end,
          value: m.group(0)!,
          confidence: 0.6,
        ));
      }
    }
    return out;
  }
}
