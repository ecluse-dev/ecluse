import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// Repérage des pathologies (P2-125) : mesure seulement, non branché sur le
/// risque.
void main() {
  late RareDiseaseCatalog catalogue;
  setUpAll(() async {
    catalogue =
        RareDiseaseCatalog(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await catalogue.load();
  });

  List<PathologieMention> extrait(String t) =>
      extrairePathologies(t, catalogue: catalogue);

  test('table maison : mention, catégorie, système, positions', () {
    const texte = 'Mme Odile Verdier, atteinte de la maladie de Parkinson.';
    final m = extrait(texte).single;
    expect(texte.substring(m.start, m.end), 'maladie de Parkinson');
    expect(m.categorie, 'maladie de Parkinson');
    expect(m.systeme, 'neurologique');
    expect(m.source, 'table');
    expect(m.rattachee, isTrue);
  });

  test('la plus longue mention l\'emporte', () {
    final m = extrait('Suivi pour diabète de type 2.').single;
    expect(m.text, 'diabète de type 2');
  });

  test('maladie rare : catégorie Orphanet', () {
    final m = extrait('M. Rémi Faure, atteint de sclérose latérale '
            'amyotrophique, est hospitalisé.')
        .single;
    expect(m.source, 'orphanet');
    expect(m.categorie, 'Maladie neurologique rare');
    expect(m.systeme, 'maladie rare');
  });

  test('la table maison prime sur Orphanet (mucoviscidose)', () {
    final m = extrait('Antécédents : mucoviscidose.').single;
    expect(m.source, 'table');
  });

  test('plusieurs mentions après « antécédents »', () {
    final ms = extrait('Antécédents : BPCO et insuffisance cardiaque.');
    expect([for (final m in ms) m.text], ['BPCO', 'insuffisance cardiaque']);
    expect(ms.every((m) => m.rattachee), isTrue);
  });

  test('service, réseau, sens figuré : repéré mais non rattaché', () {
    for (final texte in [
      'Réunion du réseau diabète jeudi à 14 h.',
      "L'unité Alzheimer accueille deux soignants.",
      'Affiche de prévention de l\'AVC en salle d\'attente.',
    ]) {
      final ms = extrait(texte);
      expect(ms.every((m) => !m.rattachee), isTrue, reason: texte);
    }
  });

  test('le rattachement ne franchit pas une fin de phrase', () {
    final m =
        extrait('Il est atteint. Formation sur l\'épilepsie demain.').single;
    expect(m.rattachee, isFalse);
  });

  test('sans catalogue : seulement la table', () {
    expect(extrairePathologies('atteinte de sclérose latérale amyotrophique'),
        isEmpty);
  });

  test('texte sans pathologie : rien', () {
    expect(extrait('Rendez-vous avec la direction demain matin.'), isEmpty);
  });
}
