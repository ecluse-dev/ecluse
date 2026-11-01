import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Étiquette et valeur séparées par une tabulation (P2-65) : les cellules d'un
/// tableau Word ou ODT. Seule une rangée de deux champs compte : dans un en-tête
/// « Nom⇥Prénom⇥Service », « Prénom⇥Service » n'est pas une étiquette et sa valeur.
void main() {
  const masques = {
    'Nom\tQuenelle\nPrénom\tZorglub': ['Quenelle', 'Zorglub'],
    'Prénom\tZorglub\nNom\tQuenelle': ['Quenelle', 'Zorglub'],
    'Nom de naissance\tDupont': ['Dupont'],
    'Patient\tZorglub Quenelle': ['Quenelle'],
    'Nom\t Quenelle\nPrénom \t Zorglub': ['Quenelle', 'Zorglub'],
  };
  for (final MapEntry(key: texte, value: restes) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎').replaceAll('\t', '→')}',
        () async {
      final r = await Ecluse.redact(texte);
      for (final v in restes) {
        expect(r.maskedText, isNot(contains(v)), reason: r.maskedText);
      }
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Nom\tPrénom\tService': 'Service',
    'Prénom\tService\tChambre': 'Service',
    'Nom\tAspirine': 'Aspirine',
    'Nom Quenelle': 'Quenelle',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\t', '→')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
