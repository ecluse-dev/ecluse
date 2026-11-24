import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-286 : l'exemple « note de liaison » de la démo (`noteDeLiaisonSample`),
/// entièrement fictif. Ce qu'il montre : un NIR à clé fausse masqué avec
/// l'avertissement « à vérifier », un IBAN écrit avec des espaces multiples, une
/// espace insécable et une tabulation, et deux phrases sans personne où rien
/// n'est masqué.
void main() {
  final texte = noteDeLiaisonSample.text;
  final debutSansPersonne = texte.indexOf('La réunion se tient');

  test('l\'exemple est proposé par la démo, en dernier', () {
    expect(demoSamples.last, same(noteDeLiaisonSample));
    expect(noteDeLiaisonSample.title, isNotEmpty);
    expect(noteDeLiaisonSample.instruction, isNotEmpty);
  });

  test('il n\'entre pas dans le corpus à clés valides (son NIR est faux)', () {
    expect(validKeysDemoCorpus, isNot(contains(noteDeLiaisonSample)));
  });

  test('cinq entités : deux noms, NIR, IBAN, téléphone', () async {
    final r = await Ecluse.redact(texte);
    final types = r.entities.map((e) => e.type).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    expect(r.entities, hasLength(5));
    expect(types, [
      EntityType.iban,
      EntityType.nir,
      EntityType.nom,
      EntityType.nom,
      EntityType.telephone,
    ]);
    // Les décalages retombent juste : le texte n'est jamais réécrit.
    for (final e in r.entities) {
      expect(texte.substring(e.start, e.end), e.value);
    }
  });

  test('le NIR à clé fausse est masqué en entier, avec un avertissement',
      () async {
    final r = await Ecluse.redact(texte);
    final nir = r.entities.singleWhere((e) => e.type == EntityType.nir);
    expect(nir.value, '2 91 04 75 118 042 90');
    expect(r.maskedText.contains('118 042'), isFalse);
    expect(r.warnings.any((w) => w.contains('clé invalide')), isTrue);
    // L'avertissement ne reprend aucune valeur du texte.
    for (final w in r.warnings) {
      expect(w.contains('118'), isFalse);
      expect(w.contains('2 91 04'), isFalse);
    }
  });

  test('l\'IBAN aux espacements irréguliers est masqué en entier', () async {
    final r = await Ecluse.redact(texte);
    final iban = r.entities.singleWhere((e) => e.type == EntityType.iban);
    expect(iban.value, contains(' '));
    expect(iban.value, contains('\t'));
    expect(iban.value, contains('  '));
    expect(iban.confidence, 1.0);
    expect(r.maskedText.contains('FR77'), isFalse);
    expect(r.maskedText.contains('5924'), isFalse);
  });

  test('rien n\'est masqué dans les deux dernières phrases', () async {
    expect(debutSansPersonne, greaterThan(0));
    final r = await Ecluse.redact(texte);
    expect(r.entities.where((e) => e.end > debutSansPersonne), isEmpty);
    expect(r.maskedText.endsWith(texte.substring(debutSansPersonne)), isTrue);
  });

  test('la restauration rend le texte d\'origine', () async {
    final r = await Ecluse.redact(texte);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });
}
