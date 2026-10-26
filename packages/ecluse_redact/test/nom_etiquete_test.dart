import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Patronyme seul derrière une étiquette de champ (P2-36). « Nom : Dupont ;
/// Prénom : Jean » masquait le prénom (gazetteer) mais laissait le patronyme,
/// faute d'un indice de nom propre autre que l'étiquette. « Nom » seul est
/// ambigu (« Nom : Aspirine ») : il n'est retenu que si « Prénom » suit sur la
/// même ligne ou la suivante ; les étiquettes précises le sont toujours.
void main() {
  const masques = {
    'Nom : Dupont ; Prénom : Jean': 'Dupont',
    'Nom : Quenelle\nPrénom : Zorglub': 'Quenelle',
    'NOM : QUENELLE  PRÉNOM : Zorglub': 'QUENELLE',
    'Nom de naissance : Quenelle': 'Quenelle',
    "Nom d'usage : Quenelle-Martin": 'Quenelle-Martin',
    'Nom de famille : de La Quenelle': 'Quenelle',
    'Nom patronymique : Quenelle': 'Quenelle',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Nom : Aspirine': 'Aspirine',
    'Nom : Doliprane 500 mg': 'Doliprane',
    'Nom du médicament : Aspirine': 'Aspirine',
    'Le nom : voir ci-dessous': 'voir',
    'Nom de naissance : inconnu': 'inconnu',
    'Nom : inconnu ; Prénom : inconnu': 'inconnu',
    'Nom : Aspirine\n\nPosologie : 2 par jour\nPrénom du chat : voir':
        'Aspirine',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
    });
  }

  test('pas de coût cubique sur une longue ligne de « Nom » répétés', () async {
    // Une première version de l'anticipation (deux `[^\n]*` imbriqués) prenait
    // 126 s pour 2000 répétitions ; la borne est large pour rester stable.
    for (final motif in ['Nom ', 'Nom : ']) {
      final sw = Stopwatch()..start();
      await Ecluse.redact(motif * 4000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)), reason: motif);
    }
  });
}
