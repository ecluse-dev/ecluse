import 'dart:convert';
import 'dart:io' show gzip;

import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Asset synthétique : entités inventées, même format que l'asset réel.
AssetBytes _synthetique(String contenu) =>
    (key) async => gzip.encode(utf8.encode(contenu));

void main() {
  group('RareDiseaseCatalog sur l\'asset réel (Orphanet FR 2026)', () {
    late RareDiseaseCatalog catalogue;

    setUpAll(() async {
      catalogue = RareDiseaseCatalog(fileAssets());
      await catalogue.load();
    });

    test('ORPHAcode → nom et catégorie', () {
      expect(catalogue.nameOf(803), 'Sclérose latérale amyotrophique');
      expect(catalogue.categoryOf(803), 'Maladie neurologique rare');
    });

    test('mention connue, insensible à la casse et aux accents', () {
      expect(catalogue.codesForMention('maladie de Charcot'), {803});
      expect(
          catalogue.codesForMention('SCLEROSE LATERALE AMYOTROPHIQUE'), {803});
    });

    test('liste blanche de sigles : SLA présent, ALD et TS absents', () {
      expect(catalogue.codesForMention('SLA'), {803});
      expect(catalogue.codesForMention('ALD'), isEmpty);
      expect(catalogue.codesForMention('TS'), isEmpty);
    });

    test('mention inconnue : ensemble vide', () {
      expect(catalogue.codesForMention('diabète'), isEmpty);
      expect(catalogue.nameOf(999999999), isNull);
    });

    test('taille et en-tête de version', () {
      expect(catalogue.length, 7834);
      expect(catalogue.version, contains('CC BY 4.0'));
    });
  });

  group('RareDiseaseCatalog sur un asset synthétique', () {
    test('mention partagée : tous les ORPHAcodes rendus', () async {
      final c = RareDiseaseCatalog(_synthetique('# test\n'
          '1\tCatégorie A\tMaladie de Pifou\tMaladie de Pifou\tPifouite\n'
          '2\tCatégorie B\tSyndrome de Zorglub\tZorglubose\tPifouite\n'));
      await c.load();
      expect(c.codesForMention('pifouite'), {1, 2});
      expect(c.version, 'test');
    });

    test('avant load() : StateError', () {
      final c = RareDiseaseCatalog(_synthetique('1\tA\tB\tB\n'));
      expect(() => c.nameOf(1), throwsStateError);
    });

    test('load() idempotent', () async {
      var appels = 0;
      final c = RareDiseaseCatalog((key) async {
        appels++;
        return gzip.encode(utf8.encode('1\tA\tB\tB\n'));
      });
      await c.load();
      await c.load();
      expect(appels, 1);
    });

    for (final (cas, contenu) in [
      ('fichier vide', ''),
      ('en-tête seul', '# rien\n'),
      ('colonne manquante', '1\tCatégorie\tNom\n'),
      ('ORPHAcode non numérique', 'x\tCatégorie\tNom\tNom\n'),
      ('ORPHAcode en double', '1\tA\tB\tB\n1\tA\tC\tC\n'),
    ]) {
      test('refus explicite : $cas', () {
        final c = RareDiseaseCatalog(_synthetique(contenu));
        expect(c.load(), throwsFormatException);
      });
    }
  });
}
