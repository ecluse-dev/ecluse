import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-309 (principe du 26 novembre, point 0) : `DigitCompaction` écarte un
/// identifiant dont les derniers chiffres ouvrent une date complète en chiffres
/// (« … 12/03/2024 »). Sans avertissement, il partait en clair en silence.
/// `Ecluse.redact` le signale « à vérifier » (type, compte et positions,
/// **jamais la valeur**). **Aucun masquage ne change.**
///
/// Sonde : identifiants fabriqués (clés calculées), au moins 40 cas écartés par
/// type, chemin `Ecluse.redact`. Les cas sont énumérés, sans hasard.
void main() {
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
    throw StateError('pas de clé');
  }

  String nir(int n) {
    final base = '1850578006${n.toString().padLeft(3, '0')}';
    final k = 97 - int.parse(base) % 97;
    return '$base${k.toString().padLeft(2, '0')}';
  }

  final motif =
      RegExp(r'de clé juste suivi d.une date, non masqué : à vérifier');

  /// Textes de la sonde, par type : (type, texte).
  final sonde = <(EntityType, String)>[];
  for (var n = 0; n < 400; n++) {
    final id = nir(n);
    final g = '${id[0]} ${id.substring(1, 3)} ${id.substring(3, 5)} '
        '${id.substring(5, 7)} ${id.substring(7, 10)} '
        '${id.substring(10, 13)} ${id.substring(13)}';
    sonde.add((EntityType.nir, 'NIR $g/03/2024 noté'));
  }
  for (var n = 0; n < 400; n++) {
    final id = avecCleLuhn('10003${(30000 + n).toString().padLeft(5, '0')}');
    sonde.add((
      EntityType.rpps,
      'Prescripteur ${id.substring(0, 9)} ${id.substring(9)}/03/2024 noté'
    ));
  }
  for (var n = 0; n < 400; n++) {
    final id = avecCleLuhn('25000${(100 + n).toString().padLeft(3, '0')}');
    sonde.add((
      EntityType.finess,
      'FINESS ${id.substring(0, 8)} ${id.substring(8)}/03/2024 noté'
    ));
  }

  test('la sonde écarte au moins 40 cas par type (prémisse)', () {
    final parType = <EntityType, int>{};
    for (final (type, texte) in sonde) {
      if (candidatsEcartesDevantDate(texte).any((c) => c.type == type)) {
        parType[type] = (parType[type] ?? 0) + 1;
      }
    }
    for (final t in [EntityType.nir, EntityType.rpps, EntityType.finess]) {
      expect(parType[t] ?? 0, greaterThanOrEqualTo(40), reason: '$t');
    }
  });

  test('chaque candidat écarté est signalé, sans la valeur', () async {
    var ecartes = 0;
    var signales = 0;
    for (final (type, texte) in sonde) {
      final c = candidatsEcartesDevantDate(texte);
      if (c.isEmpty) continue;
      final r = await Ecluse.redact(texte);
      // Un candidat qu'une autre entité couvre en entier est masqué : pas de
      // signal. Les autres doivent être signalés.
      final nonCouverts = c.where(
          (x) => !r.entities.any((e) => e.start <= x.start && e.end >= x.end));
      ecartes += nonCouverts.length;
      final a = r.warnings.where(motif.hasMatch).toList();
      if (nonCouverts.isNotEmpty) {
        signales += nonCouverts.length;
        expect(a, isNotEmpty, reason: '$type');
      }
      for (final w in r.warnings) {
        for (final x in c) {
          final valeur = texte.substring(x.start, x.end);
          expect(w, isNot(contains(valeur)));
          for (final g in valeur.split(' ').where((g) => g.length >= 3)) {
            expect(w, isNot(contains(g)));
          }
        }
      }
    }
    expect(ecartes, greaterThan(100));
    expect(signales, ecartes);
  });

  test('aucun masquage ne change : le candidat écarté reste non couvert',
      () async {
    final texte = 'NIR ${(() {
      final id = nir(5);
      return '${id[0]} ${id.substring(1, 3)} ${id.substring(3, 5)} '
          '${id.substring(5, 7)} ${id.substring(7, 10)} '
          '${id.substring(10, 13)} ${id.substring(13)}';
    })()}/03/2024 noté';
    final c = candidatsEcartesDevantDate(texte);
    if (c.isEmpty) return; // clé > 39 : pas de date possible, cas sans objet
    final r = await Ecluse.redact(texte);
    expect(r.entities.where((e) => e.type == EntityType.nir), isEmpty);
  });

  test('sans date complète ou sans identifiant : aucun avertissement',
      () async {
    for (final texte in [
      'Réunion lundi à 14 h, salle 3 le 12/03/2024.',
      'NIR ${nir(3)} noté sans date',
      'Valeur ${avecCleLuhn('10003300001')} notée.',
    ]) {
      final r = await Ecluse.redact(texte);
      expect(r.warnings.where(motif.hasMatch), isEmpty, reason: texte);
    }
  });

  test('identifiant à clé fausse devant une date : pas de signal', () async {
    final id = nir(7);
    final faux =
        '${id.substring(0, 13)}${(int.parse(id.substring(13)) + 1) % 100 == 0 ? '01' : ((int.parse(id.substring(13)) + 1) % 100).toString().padLeft(2, '0')}';
    final r = await Ecluse.redact(
        'NIR ${faux.substring(0, 13)} ${faux.substring(13)}/03/2024');
    expect(r.warnings.where(motif.hasMatch), isEmpty);
  });

  test('IBAN : groupements usuels, aucun candidat écarté devant une date', () {
    // Dernier groupe de trois caractères (4-4-4-4-4-4-3) ou paire : ne peut pas
    // ouvrir une date. Mesure honnête : 0 cas constructible.
    for (var n = 0; n < 50; n++) {
      final bban = '30006000011${n.toString().padLeft(11, '0')}';
      final reste = BigInt.parse('${bban}89' '152700') % BigInt.from(97);
      final cle = (98 - reste.toInt()).toString().padLeft(2, '0');
      final iban = 'FR$cle${bban}89';
      final g = [
        for (var i = 0; i < iban.length; i += 4)
          iban.substring(i, i + 4 > iban.length ? iban.length : i + 4)
      ].join(' ');
      final c = candidatsEcartesDevantDate('IBAN $g/03/2024');
      expect(c.where((x) => x.type == EntityType.iban), isEmpty);
    }
  });

  // P2-312 : l'identifiant réel (RPPS ou FINESS) est déjà masqué en entier ;
  // le candidat signalé n'est qu'une lecture voisine du même nombre, élargie
  // aux deux premiers chiffres de la date. Ces dix textes sont ceux du témoin
  // « identifiant suivi » (graine 42) qui portaient l'avertissement en trop.
  // Identifiants fabriqués (clés calculées), jamais copiés d'une source réelle.
  test('identifiant réel masqué en entier : pas d\'avertissement en trop',
      () async {
    const textes = [
      'RPPS 11121 25902 9 07-11-2024 noté au dossier.',
      'RPPS 19628936544 23/09/2023 noté au dossier.',
      'Prescripteur 17399704695 21-03-2024 noté au dossier.',
      'FINESS 192925386 18-08-2024 noté au dossier.',
      'N° FINESS : 765653001 26.03.2026 noté au dossier.',
      'FINESS 79 360 470 3 18/01/2022 noté au dossier.',
      'N° FINESS : 147689228 18.03.2023 noté au dossier.',
      'FINESS 879545895 18/06/2022 noté au dossier.',
    ];
    for (final texte in textes) {
      final r = await Ecluse.redact(texte);
      // L'identifiant réel est masqué (aucun masquage ne change)...
      expect(
          r.entities.where(
              (e) => e.type == EntityType.rpps || e.type == EntityType.finess),
          isNotEmpty,
          reason: texte);
      // ...et rien n'est signalé en plus.
      expect(r.warnings.where(motif.hasMatch), isEmpty, reason: texte);
    }
  });

  // Limite assumée de P2-312 : un FINESS à confiance 0,5 (pas de libellé) a la
  // même forme que les neuf premiers chiffres d'un RPPS dont les deux derniers
  // touchent la date (« Prescripteur 100033000 18/03/2024 » : RPPS 10003300018).
  // L'avertissement reste, au prix de deux doublons du témoin « identifiant
  // suivi » : mieux vaut un avertissement en trop que deux chiffres d'un RPPS
  // laissés en clair sans un mot (principe du 26 novembre, point 0).
  test('FINESS sans libellé (confiance 0,5) : l\'avertissement est conservé',
      () async {
    for (final texte in [
      'Établissement 09 608 624 4 26/06/2020 noté au dossier.',
      'Établissement 890284573 18/07/2020 noté au dossier.',
      'Prescripteur 100033000 18/03/2024 noté',
    ]) {
      final r = await Ecluse.redact(texte);
      expect(r.warnings.where(motif.hasMatch), isNotEmpty, reason: texte);
    }
  });
}
