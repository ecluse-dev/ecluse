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

  group('négations et formes adjectivales (P2-126)', () {
    test('négation : repérée, niée, jamais rattachée', () {
      for (final texte in [
        'Aucun antécédent de BPCO.',
        'Pas de diabète connu.',
        'Absence de tuberculose.',
        "Sans antécédent d'épilepsie dans la famille.",
      ]) {
        final m = extrait(texte).single;
        expect(m.niee, isTrue, reason: texte);
        expect(m.rattachee, isFalse, reason: texte);
      }
    });

    test('la négation ne porte pas au-delà de sa phrase', () {
      final ms = extrait('Pas de fièvre. Antécédents : BPCO.');
      expect(ms.single.rattachee, isTrue);
    });

    test('forme adjectivale : rattachée, catégorie de la table', () {
      final m = extrait('Mme Odile Benali, diabétique, est arrivée.').single;
      expect(m.text, 'diabétique');
      expect(m.categorie, 'diabète de type 1 et de type 2');
      expect(m.rattachee, isTrue);
    });

    test('« dialysé » (adjectif) et « dialyse » (nom) distingués', () {
      expect(
          extrait('M. Rémi Faure, dialysé, sollicite un rendez-vous.')
              .single
              .rattachee,
          isTrue);
      expect(
          extrait('La salle de dialyse est fermée.').single.rattachee, isFalse);
    });
  });

  group('formes libres (P2-134, mesure P2-129)', () {
    test('« non » juste avant une forme adjectivale : niée', () {
      final m = extrait('M. Rémi Faure, non diabétique.').single;
      expect(m.niee, isTrue);
      expect(m.rattachee, isFalse);
    });

    test('« non » plus loin ne nie pas : « non fumeur, atteint de »', () {
      final m = extrait('Patient non fumeur, atteint de diabète.').single;
      expect(m.rattachee, isTrue);
    });

    test('« DT2 » et « ATCD : »', () {
      expect(extrait('Atteinte de DT2.').single.rattachee, isTrue);
      expect(extrait('ATCD : diabète de type 2.').single.rattachee, isTrue);
    });

    test('négation après la mention, même après « ATCD : »', () {
      for (final texte in [
        'ATCD : diabète : non.',
        'Antécédents : tuberculose exclue au dernier bilan.',
        'ATCD : BPCO ? à éliminer.',
      ]) {
        final m = extrait(texte).single;
        expect(m.niee, isTrue, reason: texte);
        expect(m.rattachee, isFalse, reason: texte);
      }
    });

    test('« diabète non insulinodépendant » reste une pathologie', () {
      final m = extrait('Atteint de diabète non insulinodépendant.').single;
      expect(m.niee, isFalse);
      expect(m.rattachee, isTrue);
    });
  });

  group('éponyme accolé (P2-135)', () {
    test('« myopathie de Duchenne » : mention entière', () {
      final m = extrait('Antécédents : myopathie de Duchenne.').single;
      expect(m.text, 'myopathie de Duchenne');
    });

    test('civilité après « de » : pas un éponyme', () {
      final m = extrait('Antécédents : diabète de Mme Verdier.').single;
      expect(m.text, 'diabète');
    });
  });
}
