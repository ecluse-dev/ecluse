import 'package:ecluse_core/ecluse_core.dart';
import 'package:test/test.dart';

/// Identifiant suivi ou précédé d'un nombre qui n'en fait pas partie
/// (P2-174) : la date d'un contrôle, un âge, une quantité.
///
/// Deux défauts, mesurés par le témoin `bench/generate_corpus_identifiant_
/// suivi.py` (4 800 documents, chemin `Ecluse.redact`) :
///
/// 1. **fuite** : un identifiant à espacement irrégulier (espaces multiples,
///    insécable, tabulation), ou un FINESS écrit « 12 345 678 9 », collé à un
///    nombre voisin n'était plus détecté. La compaction des blancs soudait le
///    voisin, et le passage sur le texte d'origine ne tolère qu'un séparateur
///    simple (limite laissée par P1-19) ;
/// 2. **type faux** : un FINESS (9 chiffres) et le jour d'une date (2
///    chiffres) font la longueur d'un RPPS ; une fois sur dix la clé de Luhn
///    passe, et le RPPS avalait le jour.
///
/// Tous les identifiants sont fabriqués ici, clés calculées.
void main() {
  // --- Fabrication -------------------------------------------------------
  bool luhn(String d) {
    var s = 0;
    var dbl = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var v = d.codeUnitAt(i) - 0x30;
      if (dbl) {
        v *= 2;
        if (v > 9) v -= 9;
      }
      s += v;
      dbl = !dbl;
    }
    return s % 10 == 0;
  }

  String avecCleLuhn(String base) {
    for (var k = 0; k < 10; k++) {
      if (luhn('$base$k')) return '$base$k';
    }
    throw StateError('clé de Luhn introuvable');
  }

  String nirAvecCle(String corps13) {
    final cle = 97 - (int.parse(corps13) % 97);
    return '$corps13${cle.toString().padLeft(2, '0')}';
  }

  /// Un FINESS et deux chiffres `dd` tels que FINESS + `dd` passe aussi Luhn
  /// (donc lisible comme un RPPS de 11 chiffres), `dd` entre [min] et [max].
  (String, String) finessEtSuite(int min, int max) {
    for (var n = 700000; n < 700400; n++) {
      final f = avecCleLuhn('70$n');
      for (var dd = min; dd <= max; dd++) {
        final s = dd.toString().padLeft(2, '0');
        if (luhn('$f$s')) return (f, s);
      }
    }
    throw StateError('aucun couple trouvé');
  }

  const nirDetector = NirDetector();
  const ibanDetector = IbanFrDetector();
  const rppsDetector = RppsDetector();
  Future<List<DetectedEntity>> finess(String t) =>
      const FinessDetector().detect(NormalizedText.identity(t));

  final nir = nirAvecCle('1850578006084');
  String groupes(String n, String sep) => [
        n.substring(0, 1),
        n.substring(1, 3),
        n.substring(3, 5),
        n.substring(5, 7),
        n.substring(7, 10),
        n.substring(10, 13),
        n.substring(13, 15),
      ].join(sep);

  group('fuite : espacement irrégulier et nombre voisin', () {
    for (final (nom, sep) in const [
      ('espaces doubles', '  '),
      ('espace insécable', ' '),
      ('tabulation', '\t'),
      ('espace puis insécable', '  '),
    ]) {
      final ecrit = groupes(nir, sep);
      for (final (cas, texte) in [
        ('nombre après', 'NIR $ecrit 12 ans'),
        ('date après', 'NIR $ecrit 12/03/2024'),
        ('nombre avant', 'Dossier 12 $ecrit'),
        ('des deux côtés', 'Page 3 $ecrit 12 ans'),
        ('nombre après des blancs irréguliers', 'NIR $ecrit$sep${'12'} ans'),
      ]) {
        test('NIR, $nom, $cas', () {
          final e = nirDetector.detect(texte);
          expect(e, hasLength(1), reason: texte);
          expect(texte.substring(e.single.start, e.single.end), ecrit);
        });
      }
    }

    test('IBAN à blancs irréguliers suivi d\'un nombre', () {
      // Clé calculée : IBAN FR synthétique.
      const bban = '30006000011234567890189';
      final num = '${bban}152700';
      var reste = 0;
      for (final c in num.codeUnits) {
        reste = (reste * 10 + (c - 0x30)) % 97;
      }
      final iban = 'FR${(98 - reste).toString().padLeft(2, '0')}$bban';
      final ecrit = [
        for (var i = 0; i < iban.length; i += 4)
          iban.substring(i, i + 4 > iban.length ? iban.length : i + 4),
      ].join('  ');
      for (final texte in [
        'IBAN $ecrit 12 ans',
        'IBAN $ecrit 3 lits',
        'Page 12 $ecrit',
      ]) {
        final e = ibanDetector.detect(texte);
        expect(e, hasLength(1), reason: texte);
        expect(texte.substring(e.single.start, e.single.end), ecrit);
      }
    });

    final f = avecCleLuhn('70123456');
    final fEspace =
        '${f.substring(0, 2)} ${f.substring(2, 5)} ${f.substring(5, 8)} ${f.substring(8)}';
    for (final (cas, texte) in [
      ('date en chiffres après', 'FINESS $fEspace 12/03/2024'),
      ('âge après', 'FINESS $fEspace 72 ans'),
      ('quantité après', 'FINESS $fEspace 3 lits'),
      ('nombre avant', 'Page 12 $fEspace FINESS'),
      (
        'sur la ligne suivante, recollée par une espace',
        'FINESS $fEspace 14 mars 2025'
      ),
    ]) {
      test('FINESS écrit « 12 345 678 9 », $cas', () async {
        final e = await finess(texte);
        expect(e, hasLength(1), reason: texte);
        expect(texte.substring(e.single.start, e.single.end), fEspace);
      });
    }

    test('un FINESS collé à un chiffre reste rejeté', () async {
      expect(await finess('FINESS ${f}1'), isEmpty);
      expect(await finess('FINESS $fEspace${'1'}'), isEmpty);
    });
  });

  group('type faux : un RPPS n\'avale pas le début d\'une date ou d\'un âge',
      () {
    final (fd, jour) = finessEtSuite(1, 28);
    final (fa, age) = finessEtSuite(30, 99);

    for (final (cas, texte, f) in [
      ('date en chiffres', 'FINESS $fd $jour/03/2024 noté', fd),
      ('date à points', 'FINESS $fd $jour.03.2024 noté', fd),
      ('date en lettres', 'FINESS $fd $jour mars 2024 noté', fd),
      ('date en lettres abrégée', 'FINESS $fd $jour janv. 2024 noté', fd),
      ('âge', 'FINESS $fa $age ans noté', fa),
    ]) {
      test(cas, () async {
        // La prémisse du cas : les 11 chiffres passent Luhn.
        final i = texte.indexOf(f);
        expect(luhn('$f${texte.substring(i + 10, i + 12)}'), isTrue);
        expect(rppsDetector.detect(texte), isEmpty, reason: texte);
        final e = await finess(texte);
        expect(e, hasLength(1));
        expect(texte.substring(e.single.start, e.single.end), f);
      });
    }

    test('sans preuve que les deux chiffres sont autre chose, le RPPS reste',
        () {
      // « 123456789 12 exerce » : rien ne dit que « 12 » n'est pas la fin du
      // numéro. Dans le doute, le côté qui protège : tout reste masqué.
      final texte = 'Prescripteur $fd $jour exerce à mi-temps';
      expect(rppsDetector.detect(texte), hasLength(1));
      final texteNombre = 'Prescripteur $fd $jour lits';
      expect(rppsDetector.detect(texteNombre), hasLength(1));
    });

    test('un vrai RPPS suivi d\'une date reste un RPPS', () {
      final r = avecCleLuhn('1000345678');
      for (final texte in [
        'RPPS $r 12/03/2024',
        'RPPS ${r.substring(0, 5)} ${r.substring(5, 10)} ${r.substring(10)} 12 mars 2024',
        'RPPS $r 72 ans',
      ]) {
        final e = rppsDetector.detect(texte);
        expect(e, hasLength(1), reason: texte);
        expect(
            texte.substring(e.single.start, e.single.end).replaceAll(' ', ''),
            r);
      }
    });
  });

  group('IBAN à clé fausse et à blancs irréguliers : aucun bloc lu comme RPPS',
      () {
    // Le passage régularisé lit un IBAN à blancs irréguliers groupe par
    // groupe : ses trois derniers groupes (4 + 4 + 3 chiffres) font onze
    // chiffres et peuvent passer Luhn. La forme d'IBAN (même à clé fausse)
    // doit les écarter, comme avec des espaces simples.
    for (final (nom, sep) in const [
      ('espaces simples', ' '),
      ('insécables', '\u00A0'),
      ('espaces triples', '   '),
    ]) {
      test(nom, () {
        var trouves = 0;
        for (var n = 0; n < 300; n++) {
          final compte = (10000000000 + n * 7919).toString();
          // Clé volontairement fausse : « 00 » n'est jamais une clé d'IBAN.
          final iban = 'FR003000600001$compte${'89'}';
          final ecrit = [
            for (var i = 0; i < iban.length; i += 4)
              iban.substring(i, i + 4 > iban.length ? iban.length : i + 4),
          ].join(sep);
          trouves += rppsDetector.detect('L\'IBAN $ecrit a été refusé').length;
        }
        expect(trouves, 0);
      });
    }
  });

  group('un identifiant ne finit pas au milieu d\'une date en chiffres', () {
    test('RPPS suivi d\'une date : jamais lu comme un NIR', () {
      // On cherche un RPPS et une date « jj/mm/aaaa » tels que RPPS + jj +
      // mm forme un NIR à clé valide (15 chiffres).
      String? texte;
      String? rpps;
      recherche:
      for (var n = 0; n < 200000; n++) {
        final r = avecCleLuhn('18505${n.toString().padLeft(5, '0')}');
        for (var jj = 1; jj <= 28; jj++) {
          for (var mm = 1; mm <= 12; mm++) {
            final j = jj.toString().padLeft(2, '0');
            final m = mm.toString().padLeft(2, '0');
            final quinze = '$r$j$m';
            if (nirAvecCle(quinze.substring(0, 13)) == quinze) {
              rpps = r;
              texte = 'RPPS $r $j/$m/2024 noté';
              break recherche;
            }
          }
        }
      }
      expect(texte, isNotNull, reason: 'aucun cas trouvé');
      expect(nirDetector.detect(texte!), isEmpty, reason: texte);
      final e = rppsDetector.detect(texte);
      expect(e, hasLength(1));
      expect(texte.substring(e.single.start, e.single.end), rpps);
    });

    test('un NIR pointé suivi d\'un autre nombre n\'est pas touché', () {
      final ecrit = groupes(nir, '.');
      final texte = 'NIR $ecrit du 12/03/2024';
      expect(nirDetector.detect(texte), hasLength(1));
    });
  });
}
