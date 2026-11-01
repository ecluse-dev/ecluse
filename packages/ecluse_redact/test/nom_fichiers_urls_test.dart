import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Noms dans les noms de fichiers, URL, chemins et identifiants (P2-71).
/// Le séparateur `_`, `-` ou `.` ou une casse minuscule faisait un seul mot ou un
/// mot sans majuscule : « Bilan_Pierre_Dupont_2024.pdf », « /patient/pierre-dupont »,
/// « pierre.dupont », « @pierre_dupont » restaient en clair.
void main() {
  const masques = {
    'Voir Bilan_Pierre_Dupont_2024.pdf': ['Dupont', 'Pierre'],
    'Pièce jointe : Dupont_Pierre_bilan.docx': ['Dupont', 'Pierre'],
    'Fichier Pierre.Dupont.pdf': ['Dupont', 'Pierre'],
    'Bilan-Pierre-Dupont.pdf': ['Dupont', 'Pierre'],
    'https://exemple.fr/patient/pierre-dupont': ['dupont', 'pierre'],
    'https://exemple.fr/patient/pierre_dupont/dossier': ['dupont', 'pierre'],
    '/home/pierre.dupont/dossiers': ['dupont', 'pierre'],
    r'C:\Users\pierre.dupont\Documents': ['dupont', 'pierre'],
    'Compte @pierre_dupont': ['dupont', 'pierre'],
    'ordonnance_pierre_dupont.pdf': ['dupont', 'pierre'],
    'pierre-dupont-bilan.docx': ['dupont', 'pierre'],
    'Identifiant : pierre.dupont': ['dupont', 'pierre'],
    'login=pierre_dupont': ['dupont', 'pierre'],
    'https://www.linkedin.com/in/marie-martin-12345': ['marie', 'martin'],
  };
  for (final MapEntry(key: texte, value: restes) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      for (final v in restes) {
        expect(r.maskedText.toLowerCase(), isNot(contains(v.toLowerCase())),
            reason: r.maskedText);
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('le mot du nom de fichier qui n\'est pas un nom reste lisible',
      () async {
    final r = await Ecluse.redact('Voir Bilan_Pierre_Dupont_2024.pdf');
    expect(r.maskedText, endsWith('.pdf'));
    expect(r.maskedText, contains('2024'));
  });

  const intacts = {
    'https://exemple.fr/sous-marin': 'sous-marin',
    'https://exemple.fr/pierre-et-vacances': 'pierre-et-vacances',
    'https://exemple.fr/rose-des-vents': 'rose-des-vents',
    'https://exemple.fr/louis-de-funes-fan': 'louis-de-funes',
    'https://exemple.fr/grand-pere/pierre-papier': 'pierre-papier',
    'https://exemple.fr/rendez-vous': 'rendez-vous',
    'le fichier bilan_annuel_2024.pdf': 'bilan_annuel_2024.pdf',
    'compte_rendu_final.docx': 'compte_rendu_final.docx',
    'chef-lieu et peut-être': 'chef-lieu',
    'Date_Naissance et Nom_Patient': 'Date_Naissance',
    'user_id=12345': 'user_id',
    'https://exemple.fr/a/b/c': 'https://exemple.fr/a/b/c',
    'version 1.2.3 de pierre.js': 'pierre.js',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
