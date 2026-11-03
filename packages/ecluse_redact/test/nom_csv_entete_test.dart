import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Noms dans un tableau CSV à en-tête (P2-61). La colonne « Nom » ou « Prénom »
/// de l'en-tête désigne des personnes : les cellules de ces colonnes sont
/// masquées, quelle que soit leur casse ou leur prénom. Un tableau dont les
/// lignes n'ont pas le nombre de colonnes de l'en-tête est ambigu : refus
/// explicite (`TableauAmbiguException`), jamais « rien à masquer ».
void main() {
  Future<RedactResult> masque(String texte) => Ecluse.redact(texte);

  const masques = {
    'Nom;Prénom;Date de naissance\nQuenelle;Zorglub;12/03/1950': [
      'Quenelle',
      'Zorglub'
    ],
    'Nom,Prénom,Ville\nQuenelle,Zorglub,Lyon': ['Quenelle', 'Zorglub'],
    'nom\tprenom\tage\nquenelle\tzorglub\t82': ['quenelle', 'zorglub'],
    'Prénom|Nom|Chambre\nZorglub|Quenelle|12': ['Quenelle', 'Zorglub'],
    'Nom;Prénom\n"Quenelle";"Zorglub"': ['Quenelle', 'Zorglub'],
    'Nom de naissance;Nom d\'usage;Prénom\nDupont;Quenelle;Zorglub': [
      'Dupont',
      'Quenelle',
      'Zorglub'
    ],
    'Nom;Prénom;Service\nQuenelle;Zorglub;Cardio\nMartin;Hector;Pneumo': [
      'Quenelle',
      'Zorglub',
      'Martin',
      'Hector'
    ],
    'Id;Nom;Prénom\n1;Quenelle;Zorglub\n2;Dupont;Hector\n3;Durand;Albert': [
      'Quenelle',
      'Dupont',
      'Durand',
      'Albert'
    ],
    'LastName,FirstName,Room\nQuenelle,Zorglub,12': ['Quenelle', 'Zorglub'],
    'Nom;Prénom\r\nQuenelle;Zorglub\r\n': ['Quenelle', 'Zorglub'],
    'Nom;Prénom\nQuenelle;Zorglub\n\nNote : suite\nautre;ligne': [
      'Quenelle',
      'Zorglub',
    ],
  };
  for (final MapEntry(key: texte, value: restes) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎').replaceAll('\t', '→')}',
        () async {
      final r = await masque(texte);
      for (final reste in restes) {
        expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('les colonnes qui ne sont pas des noms restent', () async {
    final r = await masque('Nom;Prénom;Service\nQuenelle;Zorglub;Cardiologie');
    expect(r.maskedText, contains('Cardiologie'));
    expect(r.maskedText, contains('Nom;Prénom;Service'));
  });

  const intacts = [
    'Nom;Service\nCardio;Pneumo',
    'Médicament;Dose\nAspirine;100 mg',
    'Prénom et nom : à compléter',
    'Nom, prénom et adresse seront demandés',
    'Nom;Prénom',
    'Nom ;\nExemple;',
    'Produit,Nom\nPomme,Golden',
  ];
  for (final texte in intacts) {
    test('pas de tableau : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await masque(texte);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const ambigus = {
    'ligne trop courte':
        'Nom;Prénom;Ville\nQuenelle;Zorglub;Lyon\nMartin;Hector',
    'ligne trop longue':
        'Nom;Prénom\nQuenelle;Zorglub\nMartin;Hector;Paris;France',
    'virgule non protégée':
        'Nom,Prénom,Ville\nQuenelle,Zorglub,Lyon\nMartin,Hector,Saint-Paul, Lyon',
    'guillemet non fermé': 'Nom;Prénom\nQuenelle;Zorglub\n"Martin;Hector',
  };
  for (final MapEntry(key: nom, value: texte) in ambigus.entries) {
    test('refus explicite : $nom', () async {
      await expectLater(
        masque(texte),
        throwsA(isA<TableauAmbiguException>()
            .having((e) => e.ligne, 'ligne', greaterThan(1))
            .having((e) => e.toString(), 'message', isNot(contains('Martin')))),
      );
    });
  }
}
