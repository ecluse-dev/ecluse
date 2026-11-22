import 'dart:convert';
import 'dart:io';

import 'package:ecluse_lexique/ecluse_lexique.dart';
import 'package:test/test.dart';

void main() {
  test('lecture : formes, lignes # et vides ignorées, blancs retirés', () {
    final f =
        FormesVerbales.depuisTexte('# source\n\navise\n  félicite \navise\n');
    expect(f.formes, {'avise', 'félicite'});
    expect(f.nombre, 2);
  });

  test('refus explicite d\'un lexique vide, sans citer de contenu', () {
    expect(
      () => FormesVerbales.depuisTexte('# rien\n\n'),
      throwsA(isA<FormatException>().having((e) => e.message, 'message',
          'lexique de formes verbales vide ou illisible')),
    );
  });

  test('fichier remplaçable : texte simple et gzip', () async {
    final d = Directory.systemTemp.createTempSync('lexique_test');
    addTearDown(() => d.deleteSync(recursive: true));
    File('${d.path}/a.txt').writeAsStringSync('# x\navise\n');
    File('${d.path}/b.txt.gz')
        .writeAsBytesSync(gzip.encode(utf8.encode('# x\nfélicite\nrince\n')));
    expect((await FormesVerbales.charger('${d.path}/a.txt')).formes, {'avise'});
    expect((await FormesVerbales.charger('${d.path}/b.txt.gz')).formes,
        {'félicite', 'rince'});
  });

  test('fichier absent : FileSystemException', () {
    expect(FormesVerbales.charger('/chemin/inexistant.txt'),
        throwsA(isA<FileSystemException>()));
  });

  test('le fichier livré se charge (taille et cohérence)', () async {
    final f = await FormesVerbales.charger('assets/formes_verbales.txt.gz');
    expect(f.nombre, greaterThan(400000));
    expect(f.formes, containsAll(['avise', 'félicite', 'rappelle']));
    expect(f.formes.any((m) => m != m.toLowerCase()), isFalse);
  });
}
