import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom de commune masqué en entier : lettre « œ »/« Œ » et faux titre
/// (P2-180, `agent/specs/P2-178.md` § 4 et § 7 tâche A).
///
/// Deux causes indépendantes de la longueur, trouvées par le balayage des
/// 34 875 communes du référentiel (`bench/generate_corpus_cedex.py
/// --balayage`) :
///
/// 1. `\w` ne couvre que l'ASCII sans le drapeau `unicode` (Dart) : la
///    ligature « œ »/« Œ » (U+0153/U+0152) est hors des classes
///    `À-ÖØ-Þ`/`à-öø-ÿ` (Latin-1, qui s'arrêtent à U+00FF). Un nom de commune
///    qui contient cette lettre perdait tout ce qui suit (« Annœullin » →
///    `[ADRESSE_1]œullin`) ; un nom qui **commence** par « Œ » n'était pas
///    reconnu comme commune du tout (rien n'était masqué).
/// 2. `\b` de Dart se fonde sur `\w` ASCII : il voit une frontière de mot
///    entre un « r »/« m » et une lettre accentuée qui suit directement. Un
///    nom de commune en un seul mot qui commence comme un titre abrégé
///    (« Pr », « M », « Me »…) était donc pris pour une civilité annonçant un
///    nom (« Le **Pr**é-Saint-Gervais », « Les **M**ées ») et jamais inclus
///    dans la commune : seul « Le »/« Les » restait masqué.
void main() {
  const casRouges = [
    '59112 Annœullin',
    '02000 Œuilly',
    '93310 Le Pré-Saint-Gervais',
    '04190 Les Mées',
    '77350 Le Mée-sur-Seine',
  ];
  for (final texte in casRouges) {
    test('commune masquée en entier : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, '[ADRESSE_1]', reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Contre-exemples : une vraie civilité devant un nom, séparée par un
  // espace ou un point, reste détectée à part de la commune — la commune
  // (« Vesoul ») s'arrête avant la civilité, qui annonce un nom masqué par
  // ailleurs.
  const civilitesIntactes = {
    '70000 Vesoul Mme Durand': '[ADRESSE_1] Mme [NOM_1]',
    '70000 Vesoul M. Durand': '[ADRESSE_1] M. [NOM_1]',
    '70000 Vesoul Dr Faure': '[ADRESSE_1] [NOM_1]',
    '70000 Vesoul Me Blanc': '[ADRESSE_1] [NOM_1]',
  };
  for (final MapEntry(key: texte, value: attendu)
      in civilitesIntactes.entries) {
    test('civilité + nom restent séparés de la commune : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, attendu, reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
