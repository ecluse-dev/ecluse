import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:test/test.dart';

/// Option `communes` de `Ecluse.redact` (P2-184, `agent/specs/P2-182.md` § 5
/// pistes A et C) : la table des communes, chargée par l'appelant, retire une
/// adresse prédite à tort sur un nombre à cinq chiffres. Elle ne fait que
/// retirer : sans elle rien ne change, et une commune qu'elle ne connaît pas
/// garde sa détection sauf devant un mot en minuscules.
void main() {
  late CommunesConnues communes;

  setUpAll(() async {
    final geo =
        EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'))
            .geo;
    await geo.load();
    communes = CommunesConnues(geo);
  });

  Future<int> adresses(String texte, {bool option = true}) async {
    final r = await Ecluse.redact(texte, communes: option ? communes : null);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    return r.entities.where((e) => e.type == EntityType.adresse).length;
  }

  // Faux positifs du témoin « nombres à cinq chiffres » : masqués sans
  // l'option (le défaut d'abord), plus avec.
  const nombres = [
    // Casse ordinaire : mot à majuscule puis mot en minuscules.
    '58699 Alpha livrés. Merci de répondre à Marie.',
    '36664 Nord livrés. Merci de répondre à Marie.',
    // « de » seul n'est pas une tournure de quantité (décision du 13 novembre).
    'Inventaire de 22595 Série au dernier relevé. Voir la note de la Direction.',
    // Casse de phrase (texte d'ombre) : nom commun puis mot.
    '71344 boîtes expédiés.',
    '75865 courriers en stock.',
    '99590 repas clôturé.',
  ];
  for (final texte in nombres) {
    test('nombre hors adresse, écarté avec l\'option : $texte', () async {
      expect(await adresses(texte, option: false), 1,
          reason: 'défaut de départ : masqué à tort sans l\'option');
      expect(await adresses(texte), 0);
    });
  }

  // Adresses à ne pas perdre : la commune est dans la table.
  const connues = [
    '25000 Besançon depuis 2019.',
    '70000 Vesoul et environs.',
    '70170 Port-sur-Saône pour le courrier.',
    '70160 Saint Rémy en Comté demain matin.',
    '25250 L\'Isle-sur-le-Doubs comme l\'an dernier.',
    '25000 besançon depuis 2019.',
    '70170 port-sur-saône pour le courrier.',
    'adresse inchangée. 25250 l\'isle-sur-le-doubs à confirmer.',
    // Écritures que `normName` ramène à la même clé.
    '25000 BESANCON depuis 2019, voir Courrier.',
    '70170 Port sur Saone uniquement.',
  ];
  for (final texte in connues) {
    test('commune de la table, gardée : $texte', () async {
      expect(await adresses(texte, option: false), 1);
      expect(await adresses(texte), 1);
    });
  }

  // Commune absente de la table (faute, lieu-dit, ancienne commune) : la
  // détection reste partout où aucun mot en minuscules ne suit.
  const horsTableGardees = [
    'Domicile :\n70000 Vezoul\nFrance',
    '70000 Vezoul',
    'Adresse inchangée. 70000 Vezoul, France.',
    '70190 Les Trois Chênes (domicile).',
    '50130 Cherbourg-Octeville ; ancienne adresse à supprimer.',
    'domicile :\n70000 vezoul\nfrance',
    // Avec une voie devant, la table n'est jamais consultée.
    '12 rue des Lilas, 70000 Vezoul depuis 2019.',
    // « CEDEX » signe une adresse.
    '70000 Vezoul CEDEX 9 depuis 2019.',
    // Un début connu suffit : « Port » est une commune.
    '70170 Port-sur-Sône depuis 2019.',
  ];
  for (final texte in horsTableGardees) {
    test(
        'commune absente de la table, gardée : '
        '${texte.replaceAll('\n', '⏎')}', () async {
      expect(await adresses(texte, option: false), 1);
      expect(await adresses(texte), 1);
    });
  }

  // La perte assumée de l'option, écrite dans `LIMITES.md` : commune absente
  // de la table, sans voie, suivie d'un mot en minuscules.
  const horsTablePerdues = [
    '70000 Vezoul depuis 2019.',
    '70190 Les-Trois-Chênes pour le courrier.',
    '70000 vezoul depuis 2019.',
  ];
  for (final texte in horsTablePerdues) {
    test('perte assumée (hors table + mot en minuscules) : $texte', () async {
      expect(await adresses(texte, option: false), 1);
      expect(await adresses(texte), 0);
    });
  }

  test('une prédiction écartée ne retire pas le nom voisin', () async {
    // Sans la table, l'adresse avale « Marie Dupont » ; avec, le nom détecté
    // à part reste masqué (le retrait se fait avant la résolution des
    // chevauchements, jamais après).
    const texte = '58699 Alpha Mme Marie Dupont livrés.';
    final r = await Ecluse.redact(texte, communes: communes);
    expect(r.maskedText, isNot(contains('Dupont')));
  });

  test('sans effet avec des détecteurs fournis par l\'appelant', () async {
    const texte = '58699 Alpha livrés. Merci de répondre à Marie.';
    final r = await Ecluse.redact(texte,
        detectors: Ecluse.defaultDetectors, communes: communes);
    expect(r.entities.where((e) => e.type == EntityType.adresse), hasLength(1));
  });

  test('Ecluse.detect et Apercu.propose suivent l\'option', () async {
    const texte = '58699 Alpha livrés. Merci de répondre à Marie.';
    final d = await Ecluse.detect(texte, communes: communes);
    expect(d.where((e) => e.type == EntityType.adresse), isEmpty);
    final p = await Apercu.propose(texte, communes: communes);
    expect(p.entites.where((e) => e.type == EntityType.adresse), isEmpty);
  });

  test('table non chargée : refus avant toute détection', () {
    final vide =
        EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'))
            .geo;
    expect(() => Ecluse.redact('70000 Vesoul', communes: CommunesConnues(vide)),
        throwsStateError);
    expect(() => Ecluse.detect('70000 Vesoul', communes: CommunesConnues(vide)),
        throwsStateError);
  });

  test('le message d\'erreur ne cite aucune valeur du texte', () {
    final vide =
        EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'))
            .geo;
    try {
      Ecluse.redact('70000 Vesoul', communes: CommunesConnues(vide));
      fail('StateError attendue');
    } on StateError catch (e) {
      expect(e.toString(), isNot(contains('Vesoul')));
      expect(e.toString(), isNot(contains('70000')));
    }
  });
}
