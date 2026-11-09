import 'dart:convert';
import 'dart:io';

import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Prénom absent de la liste écrite à la main, suivi d'un patronyme (P2-149,
/// spec `agent/specs/P2-148.md`) : dernier angle mort des noms mesuré sur le
/// corpus adversarial.
///
/// Les effectifs sont **inventés** (asset synthétique en mémoire) : ces tests
/// vérifient la règle et le seuil, pas les données de l'INSEE. Les prénoms
/// (« Oleksandr », « Bintou », « Wassim », « Faustine ») ne sont ni dans
/// `french_first_names.dart` ni dans les listes du générateur de corpus.
void main() {
  const tsv = '# Source : essai synthétique\n'
      'BINTOU\t900\n'
      'FAUSTINE\t5000\n'
      'FRANCE\t40\n'
      'MAISON\t5\n'
      'OLEKSANDR\t300\n'
      'RUE\t3\n'
      'WASSIM\t2500\n';

  Future<FirstNameFrequencies> charge(String contenu) async {
    final octets = gzip.encode(utf8.encode(contenu));
    final f = FirstNameFrequencies((_) async => octets);
    await f.load();
    return f;
  }

  late PrenomsInsee prenoms;

  setUpAll(() async {
    prenoms = PrenomsInsee(await charge(tsv), seuil: 100);
  });

  test('sans l\'option : le prénom hors liste part en clair (défaut mesuré)',
      () async {
    final r = await Ecluse.redact('Contacter Oleksandr Guimard demain.');
    expect(r.maskedText, contains('Oleksandr'));
  });

  test('avec l\'option : prénom + patronyme masqués et restaurés', () async {
    const texte = 'Contacter Oleksandr Guimard demain. Le dossier de Bintou '
        'Lacombe est incomplet ; Wassim FERRAND et Faustine Morvan rappellent.';
    final r = await Ecluse.redact(texte, prenomsInsee: prenoms);
    for (final mot in [
      'Oleksandr',
      'Guimard',
      'Bintou',
      'Lacombe',
      'Wassim',
      'FERRAND',
      'Faustine',
      'Morvan'
    ]) {
      expect(r.maskedText, isNot(contains(mot)), reason: mot);
    }
    expect(r.mapping.values, contains('Oleksandr Guimard'));
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('sous le seuil : mot courant intact', () async {
    const texte = 'Maison Bleue. Rue Pasteur. France Travail a confirmé.';
    final r = await Ecluse.redact(texte, prenomsInsee: prenoms);
    expect(r.maskedText, texte);
  });

  test('le seuil se règle', () async {
    final bas = PrenomsInsee(prenoms.effectifs, seuil: 1);
    final r = await Ecluse.redact('Rue Pasteur.', prenomsInsee: bas);
    expect(r.maskedText, isNot(contains('Pasteur')));
  });

  test('prénom seul, ordre « Nom Prénom », patronyme en minuscules : intacts',
      () async {
    const texte = 'Oleksandr arrive. Bintou est là. Wassim a appelé. '
        'Guimard Oleksandr.';
    final r = await Ecluse.redact(texte, prenomsInsee: prenoms);
    expect(r.maskedText, texte);
  });

  test('patronyme qui est un mot outil, un établissement ou un participe',
      () async {
    const texte = 'Wassim Dans la salle. Bintou Centre. Faustine Arrivée.';
    final r = await Ecluse.redact(texte, prenomsInsee: prenoms);
    expect(r.maskedText, texte);
  });

  test('effectifs non chargés : refus explicite', () {
    final vide = FirstNameFrequencies((_) async => const []);
    expect(
        () => Ecluse.redact('Oleksandr Guimard',
            prenomsInsee: PrenomsInsee(vide)),
        throwsStateError);
  });

  test('asset mal formé : refus explicite', () {
    expect(() => charge('BINTOU\tbeaucoup\n'), throwsFormatException);
  });
}
