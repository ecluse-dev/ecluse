import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Particules de noms d'origine portugaise, italienne, arabe ou néerlandaise
/// (P2-47) : « dos », « da », « do », « das », « di », « del », « della », « ben »,
/// « bin », « bint », « ibn », « ter », « ten », « zu », « af ». Sans elles, un nom
/// comme « Pedro dos Santos » était masqué à moitié (« [NOM_1] dos Santos »).
void main() {
  const masques = [
    'M. Pedro dos Santos',
    'M. Luis da Silva',
    'Mme Ana das Neves',
    'M. Paulo do Nascimento',
    'M. Marco di Stefano',
    'Mme Lucia del Rio',
    'Mme Lucia della Rovere',
    'M. Ahmed ben Ali',
    'M. Omar bin Laden',
    'Mme Fatima bint Ali',
    'M. Youssef ibn Zayed',
    'M. Hans ter Horst',
    'M. Jan ten Brink',
    'M. Karl zu Guttenberg',
    'M. Olof af Ugglas',
  ];
  for (final texte in masques) {
    test('masqué en entier : $texte', () async {
      final r = await Ecluse.redact(texte);
      final civilite = texte.split(' ').first;
      expect(r.maskedText, '$civilite [NOM_1]', reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Le dossier dos Santos est clos',
    'Une salade da Vinci',
    'le ben oui du jour',
    'Tout est ter et ten',
  ];
  for (final texte in intacts) {
    test('aucun nom : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.mapping, isEmpty, reason: r.maskedText);
    });
  }
}
