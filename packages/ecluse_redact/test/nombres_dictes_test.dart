import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Nombres dictés en lettres (P2-267, `agent/specs/P2-155.md`, décisions du
/// 23 novembre 2026). Identifiants **synthétiques**, clés calculées ici.
///
/// Ce que ces tests tiennent : un identifiant dicté en toutes lettres est
/// masqué en entier, aux bornes des mots ; le texte n'est jamais réécrit ; un
/// mot-nombre isolé ou une suite courte ne déclenche rien ; une suite longue
/// que rien ne valide est signalée sans valeur ; sans suite de mots-nombres,
/// le résultat est celui d'avant.

const _unites = [
  'zéro',
  'un',
  'deux',
  'trois',
  'quatre',
  'cinq',
  'six',
  'sept',
  'huit',
  'neuf',
  'dix',
  'onze',
  'douze',
  'treize',
  'quatorze',
  'quinze',
  'seize',
];

/// Chiffre par chiffre : « un neuf trois… ».
String chiffreParChiffre(String chiffres) =>
    chiffres.split('').map((c) => _unites[int.parse(c)]).join(' ');

/// Nombre de 0 à 99, orthographe traditionnelle, [regional] pour « septante ».
String moinsDeCent(int n, {bool regional = false, bool traits = true}) {
  final sep = traits ? '-' : ' ';
  if (n <= 16) return _unites[n];
  if (n < 20) return 'dix$sep${_unites[n - 10]}';
  const dizaines = {
    2: 'vingt',
    3: 'trente',
    4: 'quarante',
    5: 'cinquante',
    6: 'soixante'
  };
  final d = n ~/ 10, u = n % 10;
  if (dizaines.containsKey(d)) {
    if (u == 0) return dizaines[d]!;
    if (u == 1) return '${dizaines[d]} et un';
    return '${dizaines[d]}$sep${_unites[u]}';
  }
  if (regional) {
    final tete = {7: 'septante', 8: 'huitante', 9: 'nonante'}[d]!;
    if (u == 0) return tete;
    return u == 1 ? '$tete et un' : '$tete$sep${_unites[u]}';
  }
  if (d == 7) {
    return u == 1
        ? 'soixante et onze'
        : 'soixante$sep${moinsDeCent(10 + u, traits: traits)}';
  }
  if (d == 8) {
    return u == 0 ? 'quatre${sep}vingts' : 'quatre${sep}vingt$sep${_unites[u]}';
  }
  return 'quatre${sep}vingt$sep${moinsDeCent(10 + u, traits: traits)}';
}

/// Par paires, « zéro » dit pour chaque zéro de tête.
String parPaires(String chiffres, {bool regional = false, bool traits = true}) {
  final mots = <String>[];
  for (var i = 0; i < chiffres.length; i += 2) {
    var m = chiffres.substring(i, i + 2 > chiffres.length ? null : i + 2);
    while (m.length > 1 && m.startsWith('0')) {
      mots.add('zéro');
      m = m.substring(1);
    }
    mots.add(moinsDeCent(int.parse(m), regional: regional, traits: traits));
  }
  return mots.join(' ');
}

String cleNir(String treize) {
  final n = BigInt.parse(treize);
  return (97 - (n % BigInt.from(97)).toInt()).toString().padLeft(2, '0');
}

bool luhn(String s) {
  var somme = 0;
  var double = false;
  for (var i = s.length - 1; i >= 0; i--) {
    var d = int.parse(s[i]);
    if (double) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    somme += d;
    double = !double;
  }
  return somme % 10 == 0;
}

String rpps(String dixDebut) {
  for (var c = 0; c < 10; c++) {
    final s = '$dixDebut$c';
    if (luhn(s)) return s;
  }
  throw StateError('aucune clé');
}

String cleIban(String bban) {
  // Clé = 98 - (BBAN suivi de « FR00 » en chiffres, lettres A=10…Z=35) mod 97.
  final b = StringBuffer();
  for (final c in '${bban}FR00'.split('')) {
    final u = c.codeUnitAt(0);
    b.write(u >= 0x41 && u <= 0x5A ? (u - 0x41 + 10).toString() : c);
  }
  final reste = BigInt.parse(b.toString()) % BigInt.from(97);
  return (98 - reste.toInt()).toString().padLeft(2, '0');
}

void main() {
  // NIR synthétique : 1 86 05 75 123 456 + clé.
  final nirCorps = '1860575123456';
  final nir = '$nirCorps${cleNir(nirCorps)}';
  final nirRpps = rpps('1234567890');

  Future<RedactResult> masque(String t) => Ecluse.redact(t);

  group('un identifiant dicté est masqué en entier', () {
    test('NIR chiffre par chiffre derrière « nir »', () async {
      final dit = chiffreParChiffre(nir);
      final t = 'le nir est $dit et le dossier suit';
      final r = await masque(t);
      expect(r.maskedText, 'le nir est [NIR_1] et le dossier suit');
      expect(r.entities.single.type, EntityType.nir);
      // Aux bornes des mots : début du premier, fin du dernier.
      final e = r.entities.single;
      expect(t.substring(e.start, e.end), dit);
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('NIR par groupes de la forme écrite, sans trait d\'union', () async {
      final groupes = [
        nir.substring(0, 1),
        nir.substring(1, 3),
        nir.substring(3, 5),
        nir.substring(5, 7),
        nir.substring(7, 10),
        nir.substring(10, 13),
        nir.substring(13, 15),
      ];
      final dit = groupes
          .map((g) => g.length <= 2
              ? parPaires(g, traits: false)
              : '${chiffreParChiffre(g.substring(0, 1))} ${parPaires(g.substring(1), traits: false)}')
          .join(' ');
      final t = 'numéro de sécu $dit.';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
      expect(r.maskedText.contains('[NIR_1]'), isTrue);
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('variantes régionales « septante », « huitante », « nonante »',
        () async {
      final dit = parPaires(nir, regional: true);
      final r = await masque('nir : $dit');
      expect(r.entities.single.type, EntityType.nir);
      expect(r.maskedText, 'nir : [NIR_1]');
    });

    test('« double » et « triple » répètent le chiffre suivant', () async {
      // 1 22 .. : on construit un NIR dont certains chiffres se répètent.
      final corps = '2111004444555';
      final n = '$corps${cleNir(corps)}';
      final mots = <String>[];
      var i = 0;
      while (i < n.length) {
        var j = i;
        while (j < n.length && n[j] == n[i]) {
          j++;
        }
        var reste = j - i;
        while (reste > 0) {
          if (reste >= 3) {
            mots.addAll(['triple', _unites[int.parse(n[i])]]);
            reste -= 3;
          } else if (reste == 2) {
            mots.addAll(['double', _unites[int.parse(n[i])]]);
            reste -= 2;
          } else {
            mots.add(_unites[int.parse(n[i])]);
            reste -= 1;
          }
        }
        i = j;
      }
      final r = await masque('nir ${mots.join(' ')} vérifié');
      expect(r.entities.single.type, EntityType.nir);
      expect(r.maskedText, 'nir [NIR_1] vérifié');
    });

    test('le zéro dit « o »', () async {
      final dit = chiffreParChiffre(nir).replaceAll('zéro', 'o');
      final r = await masque('nir $dit');
      expect(r.entities.single.type, EntityType.nir);
    });

    test('IBAN : « fr » collé aux chiffres, lettre épelée dans le compte',
        () async {
      const bban = '3000600001' '12345A67890' '55';
      final cle = cleIban(bban);
      final avant = '$cle${bban.substring(0, 15)}';
      final apres = bban.substring(16);
      final dit = 'fr ${parPaires(avant)} a ${parPaires(apres)}';
      final t = 'merci de régler sur l\'iban $dit avant vendredi';
      final r = await masque(t);
      expect(r.entities.where((e) => e.type == EntityType.iban), hasLength(1));
      expect(r.maskedText, contains('[IBAN_1]'));
      expect(r.maskedText, endsWith('avant vendredi'));
      expect(Ecluse.restore(r.maskedText, r.mapping), t);
    });

    test('RPPS derrière « rpps » seulement', () async {
      final dit = chiffreParChiffre(nirRpps);
      final avec = await masque('le dr Martin, rpps $dit');
      expect(avec.entities.any((e) => e.type == EntityType.rpps), isTrue);
      // Sans mot-clé, onze chiffres de Luhn valide ne suffisent pas (un faux
      // accord sur dix) : rien n'est converti.
      final sans = await masque('on compte $dit puis on s\'arrête');
      expect(sans.entities.where((e) => e.type == EntityType.rpps), isEmpty);
    });
  });

  group('jamais sur un mot isolé ni sur une suite courte', () {
    test('« un », « six », « cent » dans une phrase', () async {
      for (final t in [
        'un patient est arrivé à six heures avec cent euros',
        'il a vu deux ou trois médecins, puis un infirmier',
        'cinq six sept huit neuf', // 5 mots : sous le seuil, sans mot-clé
      ]) {
        final r = await masque(t);
        expect(r.entities, isEmpty, reason: t);
        expect(r.maskedText, t);
      }
    });

    test('sans suite de mots-nombres, le résultat est celui d\'avant',
        () async {
      for (final t in [
        'Mme Camille Durand, née le 12/03/1984, habite 4 rue des Lilas.',
        'NIR $nir et RPPS $nirRpps, IBAN FR76 3000 6000 0112 3456 7890 189',
        'Tournez deux fois puis comptez dix.',
        '',
      ]) {
        final r = await masque(t);
        expect(r.warnings.where((w) => w.contains('dicté')), isEmpty,
            reason: t);
        expect(Ecluse.restore(r.maskedText, r.mapping), t);
      }
    });

    test('les montants et dates en lettres ne sont pas des identifiants',
        () async {
      for (final t in [
        'le premier mars deux mille vingt-six, versement de deux cent '
            'cinquante mille euros',
        'comptez à voix haute : cinq, six, sept, huit, neuf, dix, onze, douze',
        'on a recensé huit cent quatre-vingt-dix-neuf mille neuf cents chaises',
      ]) {
        final r = await masque(t);
        expect(r.entities.where((e) => e.type != EntityType.nom), isEmpty,
            reason: t);
      }
    });
  });

  group('signalement d\'une suite dictée non reconnue', () {
    test('neuf mots-nombres ou plus qu\'aucune lecture ne valide', () async {
      const t = 'rappeler au un deux trois quatre cinq six sept huit neuf '
          'dix demain';
      final r = await masque(t);
      final w = r.warnings.where((m) => m.contains('nombre dicté non reconnu'));
      expect(w, hasLength(1));
      // Positions et compte, jamais de valeur du texte.
      expect(w.single, contains('position'));
      for (final mot in ['un', 'deux', 'trois', 'quatre', 'cinq']) {
        expect(w.single.contains(' $mot '), isFalse);
      }
      // Le texte n'est pas masqué ni modifié.
      expect(r.maskedText, t);
    });

    test('une suite reconnue ne déclenche pas le signalement', () async {
      final r = await masque('nir ${chiffreParChiffre(nir)}');
      expect(r.warnings.any((m) => m.contains('nombre dicté')), isFalse);
    });

    test('moins de neuf mots : pas de signalement', () async {
      final r = await masque('un deux trois quatre cinq six sept huit');
      expect(r.warnings.any((m) => m.contains('nombre dicté')), isFalse);
    });
  });

  group('coût', () {
    test('suite de mots-nombres : temps linéaire (400 000 caractères)',
        () async {
      await expectCroissanceLineaire((k) async {
        final t = 'deux trois quatre ' * k;
        await Ecluse.redact(t);
      }, n: 5600);
    });

    test('suite ambiguë (« quatre vingt dix sept ») : temps linéaire',
        () async {
      await expectCroissanceLineaire((k) async {
        final t = 'quatre vingt dix sept soixante quatre ' * k;
        await Ecluse.redact(t);
      }, n: 400);
    });
  });
}
