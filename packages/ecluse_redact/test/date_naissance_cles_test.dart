import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Date de naissance derrière une clé de données structurées (P2-52) : JSON, YAML,
/// XML, paramètres d'URL. La clé (`date_naissance`, `dateNaissance`, `birth_date`,
/// `dob`, `ddn`, `naissance`) est un contexte sans ambiguïté, comme « né le » en
/// prose : seul le contexte, jamais la date seule, déclenche la détection.
void main() {
  const masques = [
    '{"date_naissance": "12/03/1950"}',
    '{"dateNaissance":"12/03/1950"}',
    '{"date-naissance": "12/03/1950"}',
    '{"birth_date": "1950-03-12"}',
    '{"birthDate": "1950-03-12"}',
    '{"birthdate": "1950-03-12"}',
    '{"date_of_birth": "1950-03-12"}',
    '{"dob": "12/03/1950"}',
    '{"ddn": "12/03/1950"}',
    '{"naissance": "12/03/1950"}',
    '{"patient": {"nom": "X", "ddn": "12/03/1950"}}',
    'date_naissance: 12/03/1950',
    'dateNaissance = 12/03/1950',
    "date_naissance: '12/03/1950'",
    '<dateNaissance>12/03/1950</dateNaissance>',
    '<naissance>12/03/1950</naissance>',
    'ddn=12/03/1950&nom=X',
    'date_de_naissance: 12 mars 1950',
  ];
  for (final texte in masques) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, contains('[DATE_NAISSANCE_1]'),
          reason: r.maskedText);
      expect(r.maskedText, isNot(contains('1950')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    '{"date_creation": "12/03/1950"}',
    '{"date_naissance_projet": "12/03/1950"}',
    '{"naissance_projet": "12/03/1950"}',
    '{"dobby": "12/03/1950"}',
    '{"update": "12/03/1950"}',
    '{"date": "12/03/1950"}',
    '{"ddns": "12/03/1950"}',
    'la naissance du projet: 12/03/1950',
    '{"date_naissance": "inconnue"}',
  ];
  for (final texte in intacts) {
    test('aucune date de naissance : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping.keys, isNot(contains('[DATE_NAISSANCE_1]')),
          reason: r.maskedText);
    });
  }
}
