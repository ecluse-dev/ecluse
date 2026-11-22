import 'dart:convert';

import 'package:ecluse_audit/ecluse_audit.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Liste de patronymes fournie par l'application dans le `Dossier` (P2-243,
/// option B de `agent/specs/P2-219.md`, décisions du 21 novembre). Noms
/// synthétiques. Trois choses sont vérifiées : sans liste, rien ne change ;
/// avec, un patronyme seul est masqué dès la première pièce ; et la liste ne
/// sort par aucune des voies d'un appelant distrait (exception, `toString`,
/// JSON, journal).
const _textes = [
  'Mme Sophie Verdier arrive demain. Contact : 01 99 00 12 34.',
  'Le dossier de Verdier est transmis.',
  'Rendez-vous à Vesoul demain avec M. Lenoir.',
  'Le petit déjeuner est servi à 8 h.',
  'le marchand est venu ce matin.',
  'COURRIER POUR VERDIER ET LENOIR.',
  'Aucun nom ici, seulement une réunion à 14 h.',
];

DateTime _horloge() => DateTime.utc(2026, 11, 21, 9, 0);

Future<List<String>> _masque(Dossier d) async =>
    [for (final t in _textes) (await Ecluse.redact(t, dossier: d)).maskedText];

void main() {
  group('équivalence : sans liste, la sortie ne change pas', () {
    test('liste vide = pas de liste, octet pour octet', () async {
      final sans = await _masque(Dossier());
      final vide =
          await _masque(Dossier(patronymesConnus: PatronymesConnus(const [])));
      expect(vide, sans);
    });

    test('liste de noms absents des textes : même sortie', () async {
      final sans = await _masque(Dossier());
      final autres = await _masque(Dossier(
          patronymesConnus: PatronymesConnus(const ['Zorbel', 'Quenard'])));
      expect(autres, sans);
    });

    test('sans dossier : aucune liste, aucun changement', () async {
      final r = await Ecluse.redact('Le dossier de Verdier est transmis.');
      final d = Dossier();
      final r2 = await Ecluse.redact('Le dossier de Verdier est transmis.',
          dossier: d);
      expect(r2.maskedText, r.maskedText);
    });
  });

  group('ce que la liste masque', () {
    final liste = PatronymesConnus(const ['Verdier', 'Lenoir']);

    test('un patronyme seul est masqué dès la première pièce', () async {
      final d = Dossier(patronymesConnus: liste);
      final r = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(r.maskedText, 'Courrier pour [NOM_1].');
      expect(d.restore(r.maskedText), 'Courrier pour Verdier.');
      // Même texte sans liste : en clair (c'est le gain de la liste).
      final sans =
          await Ecluse.redact('Courrier pour Verdier.', dossier: Dossier());
      expect(sans.maskedText, 'Courrier pour Verdier.');
    });

    test('en capitales aussi', () async {
      final d = Dossier(patronymesConnus: liste);
      final r =
          await Ecluse.redact('COURRIER POUR VERDIER ET LENOIR.', dossier: d);
      expect(r.maskedText, isNot(contains('VERDIER')));
      expect(r.maskedText, isNot(contains('LENOIR')));
    });

    test('une commune présente dans la liste est masquée (décision 21/11)',
        () async {
      final d = Dossier(patronymesConnus: PatronymesConnus(const ['Vesoul']));
      final r = await Ecluse.redact('Courrier pour Vesoul.', dossier: d);
      expect(r.maskedText, isNot(contains('Vesoul')));
    });

    test('la casse de la liste et les blancs sont normalisés', () async {
      final d = Dossier(
          patronymesConnus: PatronymesConnus(const ['  VERDIER  ', 'verdier']));
      final r = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(r.maskedText, 'Courrier pour [NOM_1].');
    });

    test('Ecluse.detect (aperçu) en profite, sans effet de bord', () async {
      final d = Dossier(patronymesConnus: liste);
      final e = await Ecluse.detect('Courrier pour Verdier.', dossier: d);
      expect(e.map((x) => x.value), ['Verdier']);
      // Rien n'a été établi : un redact ensuite numérote depuis 1.
      final r = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(r.maskedText, 'Courrier pour [NOM_1].');
    });
  });

  group('ce que la liste n\'amorce pas : les minuscules', () {
    test('« le marchand est venu » reste en clair, liste ou pas', () async {
      final d = Dossier(patronymesConnus: PatronymesConnus(const ['Marchand']));
      final r =
          await Ecluse.redact('le marchand est venu ce matin.', dossier: d);
      expect(r.maskedText, 'le marchand est venu ce matin.');
    });
  });

  group('limites assumées (LIMITES.md § 8), figées ici', () {
    test('un nom à particule de la liste ne correspond à rien', () async {
      final d =
          Dossier(patronymesConnus: PatronymesConnus(const ['de La Fontaine']));
      final r =
          await Ecluse.redact('Courrier pour De La Fontaine.', dossier: d);
      final sans = await Ecluse.redact('Courrier pour De La Fontaine.',
          dossier: Dossier());
      expect(r.maskedText, sans.maskedText);
    });

    test('un mot courant fourni comme nom est masqué (« Petit déjeuner »)',
        () async {
      final d = Dossier(patronymesConnus: PatronymesConnus(const ['Petit']));
      final r = await Ecluse.redact('Petit déjeuner à 8 h.', dossier: d);
      expect(r.maskedText, isNot(contains('Petit')));
    });

    test('deux noms de la liste côte à côte : un seul jeton', () async {
      final d = Dossier(
          patronymesConnus: PatronymesConnus(const ['Verdier', 'Lenoir']));
      final r = await Ecluse.redact('Verdier Lenoir a confirmé.', dossier: d);
      expect(r.maskedText, '[NOM_1] a confirmé.');
    });
  });

  group('refus explicite à la construction, sans la valeur', () {
    PatronymesRefusesException refus(List<String> noms) {
      try {
        PatronymesConnus(noms);
      } on PatronymesRefusesException catch (e) {
        return e;
      }
      fail('aurait dû refuser');
    }

    test(
        'vide, un caractère, sigle en capitales, trop de mots : comptés par motif',
        () {
      final e = refus(['Verdier', '', '   ', 'x', 'EVA', 'Eva', 'a b c d e']);
      expect(e.parMotif, {
        MotifPatronymeRefuse.vide: 2,
        MotifPatronymeRefuse.tropCourt: 1,
        MotifPatronymeRefuse.sigleExclu:
            1, // « EVA » seul ; « Eva » est accepté
        MotifPatronymeRefuse.tropDeMots: 1,
      });
      expect(e.total, 5);
    });

    test('le message ne contient aucune entrée de la liste', () {
      const secrets = ['Verdier', 'Lenoir', 'Zorbelle'];
      final e = refus([...secrets, 'EVA', 'un deux trois quatre cinq Verdier']);
      final message = e.toString();
      for (final s in secrets) {
        expect(message, isNot(contains(s)), reason: 'message');
      }
      expect(message, isNot(contains('EVA')));
      expect(message, contains('2 entrée(s)'));
    });

    test('tout ou rien : une entrée refusée, rien n\'est retenu', () async {
      expect(() => PatronymesConnus(const ['Verdier', '']),
          throwsA(isA<PatronymesRefusesException>()));
      final d = Dossier();
      expect(
          () => d.ajouterPatronymes(PatronymesConnus(const ['Verdier', 'x'])),
          throwsA(isA<PatronymesRefusesException>()));
      final r = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(r.maskedText, 'Courrier pour Verdier.');
    });

    test('un nom à quatre mots est accepté, à cinq refusé', () {
      expect(PatronymesConnus(const ['a de la Fontaine']).length, 1);
      expect(() => PatronymesConnus(const ['un deux trois quatre cinq']),
          throwsA(isA<PatronymesRefusesException>()));
    });
  });

  group('opacité : aucune voie de fuite pour un appelant distrait', () {
    final liste = PatronymesConnus(const ['Verdier', 'Lenoir', 'Zorbelle']);

    void sansNoms(String sortie, String contexte) {
      for (final n in ['Verdier', 'Lenoir', 'Zorbelle', 'verdier']) {
        expect(sortie, isNot(contains(n)), reason: contexte);
      }
    }

    test('toString, interpolation, message d\'exception : le nombre seul', () {
      expect(liste.toString(), 'PatronymesConnus(3 noms)');
      sansNoms('$liste', 'interpolation');
      sansNoms(Exception('liste : $liste').toString(), 'exception');
      sansNoms(Dossier(patronymesConnus: liste).toString(), 'Dossier');
      expect(Dossier(patronymesConnus: liste).toString(), 'Dossier(ouvert)');
    });

    test('jsonEncode refuse la liste', () {
      expect(
          () => jsonEncode(liste), throwsA(isA<JsonUnsupportedObjectError>()));
      expect(() => jsonEncode({'liste': liste}),
          throwsA(isA<JsonUnsupportedObjectError>()));
    });

    test('pas d\'égalité : deux listes identiques ne sont pas égales', () {
      final a = PatronymesConnus(const ['Verdier']);
      final b = PatronymesConnus(const ['Verdier']);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('vider() : la liste de l\'appelant se vide, pas celle d\'un dossier',
        () async {
      final l = PatronymesConnus(const ['Verdier']);
      final d = Dossier(patronymesConnus: l);
      l.vider();
      expect(l.isEmpty, isTrue);
      expect(l.toString(), 'PatronymesConnus(0 nom)');
      final r = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(r.maskedText, 'Courrier pour [NOM_1].');
    });

    test('fermer() : le dossier refuse, la liste de l\'appelant reste',
        () async {
      final l = PatronymesConnus(const ['Verdier']);
      final d = Dossier(patronymesConnus: l);
      d.fermer();
      await expectLater(Ecluse.redact('Courrier pour Verdier.', dossier: d),
          throwsA(isA<DossierFermeException>()));
      expect(
          () => d.ajouterPatronymes(l), throwsA(isA<DossierFermeException>()));
      expect(l.length, 1);
      // Réutilisable pour un autre dossier.
      final r = await Ecluse.redact('Courrier pour Verdier.',
          dossier: Dossier(patronymesConnus: l));
      expect(r.maskedText, 'Courrier pour [NOM_1].');
    });

    test('RedactResult et exceptions du dossier : aucun nom de la liste',
        () async {
      final d = Dossier(patronymesConnus: liste);
      final r = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      // La table contient la valeur du texte (c'est son rôle), pas la liste.
      sansNoms('${r.mapping}', 'table');
      sansNoms('$r', 'RedactResult');
      d.fermer();
      try {
        await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      } on DossierFermeException catch (e) {
        sansNoms(e.toString(), 'DossierFermeException');
      }
    });
  });

  group('journal d\'audit : aucun compte, schéma inchangé', () {
    Future<String> entrees(Dossier d, String texte) async {
      final sink = InMemoryAuditSink();
      await Ecluse.redact(texte,
          dossier: d, journal: JournalAudit(sink: sink, horloge: _horloge));
      return sink.entries.map((e) => e.toCanonicalJson()).join('\n');
    }

    test('aucun nom de la liste dans les entrées', () async {
      final brut = await entrees(
          Dossier(
              patronymesConnus: PatronymesConnus(const ['Verdier', 'Lenoir'])),
          'Courrier pour Verdier.');
      expect(brut, isNot(contains('Verdier')));
      expect(brut, isNot(contains('Lenoir')));
    });

    test(
        'une liste sans effet sur le texte laisse l\'entrée identique, '
        'chaîne comprise : ni nombre d\'entrées ni champ ajouté', () async {
      const texte = 'Mme Sophie Martin arrive demain.';
      final sans = await entrees(Dossier(), texte);
      final avec = await entrees(
          Dossier(
              patronymesConnus: PatronymesConnus(
                  List.generate(37, (i) => 'Zorbel${'x' * i}'))),
          texte);
      expect(avec, sans);
    });

    test('la description du moteur ne change pas avec une liste', () async {
      // Elle ne liste que des noms de détecteurs, qui ne changent pas quand
      // la liste amorce `NameDetector` (LIMITES.md § 8).
      final avant = Ecluse.descriptionMoteur();
      Dossier(patronymesConnus: PatronymesConnus(const ['Verdier']));
      expect(Ecluse.descriptionMoteur(), avant);
      expect(avant, contains('nom'));
    });
  });

  group('liste vivante et cloisonnement', () {
    test('ajouterPatronymes vaut pour les pièces suivantes', () async {
      final d = Dossier();
      final avant = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(avant.maskedText, 'Courrier pour Verdier.');
      d.ajouterPatronymes(PatronymesConnus(const ['Verdier']));
      d.ajouterPatronymes(PatronymesConnus(const ['verdier', 'Lenoir']));
      final apres = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(apres.maskedText, 'Courrier pour [NOM_1].');
    });

    test('la liste d\'un dossier n\'amorce pas un autre dossier', () async {
      final a = Dossier(patronymesConnus: PatronymesConnus(const ['Verdier']));
      final b = Dossier();
      final ra = await Ecluse.redact('Courrier pour Verdier.', dossier: a);
      final rb = await Ecluse.redact('Courrier pour Verdier.', dossier: b);
      expect(ra.maskedText, 'Courrier pour [NOM_1].');
      expect(rb.maskedText, 'Courrier pour Verdier.');
    });

    test('un nom de la liste et la mention établie partagent le dossier',
        () async {
      final d = Dossier(patronymesConnus: PatronymesConnus(const ['Verdier']));
      final r1 = await Ecluse.redact('Mme Sophie Verdier arrive.', dossier: d);
      expect(r1.maskedText, isNot(contains('Verdier')));
      final r2 = await Ecluse.redact('Courrier pour Verdier.', dossier: d);
      expect(r2.maskedText, isNot(contains('Verdier')));
      expect(d.restore(r2.maskedText), 'Courrier pour Verdier.');
    });
  });
}
