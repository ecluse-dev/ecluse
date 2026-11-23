import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-263 : un NIR à clé fausse, sans libellé, est masqué en entier à 0,3
/// (« à vérifier ») même coupé par une fin de ligne, écrit en chiffres pleine
/// chasse ou groupé 3 × 5. Limites notées à la fusion de P2-258. Cas
/// synthétiques : corps 2 85 05 78 006 084, clé juste 41, on met 46.
void main() {
  const compact = '285057800608446';
  const intro = 'Attention, saisie erronée hier : ';
  const fin = ' a été rejeté par le contrôle.';

  String pleineChasse(String s) => String.fromCharCodes(
      s.codeUnits.map((c) => c >= 0x30 && c <= 0x39 ? c + 0xFEE0 : c));

  final formes = <String, String>{
    'fin de ligne dans un groupe (compact)': '28505780\n0608446',
    'fin de ligne entre deux groupes': '2 85 05 78\n006 084 46',
    'fin de ligne avec retour chariot': '2 85 05 78\r\n006 084 46',
    'fin de ligne et blancs en tête de ligne': '2 85 05 78\n   006 084 46',
    'pleine chasse compacte': pleineChasse(compact),
    'pleine chasse groupée': pleineChasse('2 85 05 78 006 084 46'),
    '3 × 5 avec des espaces': '285 057 800 608 446',
    '3 × 5 avec des points': '285.057.800.608.446',
    '3 × 5 avec des tirets': '285-057-800-608-446',
    '3 × 5 avec des barres': '285/057/800/608/446',
    'pleine chasse et fin de ligne':
        '${pleineChasse('285057')}\n${pleineChasse('800608446')}',
  };

  for (final MapEntry(key: nom, value: nir) in formes.entries) {
    test('$nom : masqué en entier, type nir, confiance 0,3', () async {
      final t = '$intro$nir$fin';
      final r = await Ecluse.redact(t);
      expect(r.entities, hasLength(1), reason: nom);
      expect(r.entities.single.type, EntityType.nir);
      expect(r.entities.single.value, nir);
      expect(r.entities.single.confidence, 0.3);
      expect(r.maskedText, '$intro[NIR_1]$fin');
      expect(r.warnings.join(' '), contains('clé invalide'));
      // L'avertissement ne porte jamais la valeur.
      expect(r.warnings.join(' '), isNot(contains('006')));
      // Le texte n'est jamais réécrit.
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });
  }

  group('ce qui ne change pas', () {
    test('NIR à clé juste coupé : inchangé (confiance 1,0)', () async {
      final r = await Ecluse.redact('NIR 2 85 05 78\n006 084 41.');
      expect(r.entities.single.type, EntityType.nir);
      expect(r.entities.single.confidence, 1.0);
    });

    test('clé nommée à part, fausse, reste intacte (P2-42)', () async {
      for (final t in [
        'NIR : 2550814168025 clé 39',
        'NIR : 2550814168025\nclé 39',
        'NIR : ${pleineChasse('2550814168025')} clé 39',
        'Page 1850397100123 clé 99',
      ]) {
        final r = await Ecluse.redact(t);
        expect(r.mapping.jetons, isNot(contains('[NIR_1]')), reason: t);
      }
    });

    test('RPPS suivi d\'un nombre, même sur deux lignes : jamais un NIR',
        () async {
      // RPPS valide (Luhn) de onze chiffres puis un nombre de quatre chiffres.
      for (final t in [
        'RPPS 10192209566 1250 places noté.',
        'RPPS 10192209566\n1250 places noté.',
      ]) {
        final r = await Ecluse.redact(t);
        expect(r.entities.where((e) => e.type == EntityType.nir), isEmpty,
            reason: t);
      }
    });

    test('3 × 5 sans lien avec un NIR (premier chiffre, mois) : rien',
        () async {
      for (final t in [
        'Référence 385.057.800.608.446 du lot',
        'Référence 285.130.800.608.446 du lot',
        'Lot 285 057 800 608 44 livré', // 14 chiffres seulement
        'Tel 285.057.800.608.4465 noté', // 16 chiffres
      ]) {
        final r = await Ecluse.redact(t);
        expect(r.entities.where((e) => e.type == EntityType.nir), isEmpty,
            reason: t);
      }
    });

    test('deux nombres sur deux lignes qui ne forment pas un NIR : rien',
        () async {
      for (final t in [
        'Chambre 12\nCode 4567 repas',
        'Total 1234567\n89012 euros',
      ]) {
        final r = await Ecluse.redact(t);
        expect(r.entities, isEmpty, reason: t);
      }
    });
  });
}
