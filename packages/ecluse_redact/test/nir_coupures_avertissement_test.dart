import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-305 (principe du 26 novembre, point 0) : la garde `nir_coupures` écarte
/// un NIR à clé fausse écrit en groupes qui ne sont pas ceux d'un NIR (par
/// quatre, par exemple) sans rien dire (mesure P2-303 : 40 / 40 silencieux).
/// `Ecluse.redact` le signale « à vérifier » dans `RedactResult.warnings`
/// (type, compte et positions, **jamais la valeur**). **Aucun masquage ne
/// change.** Textes synthétiques ; les clés sont volontairement fausses.
void main() {
  // « 1 26 07 65 873 965 62 » sans ses espaces : clé 62 fausse (calculée).
  const brut = '126076587396562';
  final parQuatre = '${brut.substring(0, 4)} ${brut.substring(4, 8)} '
      '${brut.substring(8, 12)} ${brut.substring(12)}';
  final motif = RegExp(r'NIR.*groupes.*non masqué.*à vérifier');

  Iterable<String> signaux(RedactResult r) => r.warnings.where(motif.hasMatch);

  test('groupes de quatre, clé fausse : non masqué et signalé, sans la valeur',
      () async {
    final r = await Ecluse.redact('Dossier $parQuatre reçu.');
    expect(r.entities.where((e) => e.type == EntityType.nir), isEmpty);
    final a = signaux(r).toList();
    expect(a, hasLength(1));
    expect(a.single, contains('1 occurrence'));
    expect(a.single, contains('position 8'));
    for (final g in [brut.substring(0, 4), brut.substring(4, 8), '7396']) {
      expect(a.single, isNot(contains(g)));
    }
  });

  test('plusieurs occurrences : un seul avertissement, compte et positions',
      () async {
    final r = await Ecluse.redact('Dossier $parQuatre reçu ; puis $parQuatre.');
    final a = signaux(r).toList();
    expect(a, hasLength(1));
    expect(a.single, contains('2 occurrences'));
  });

  test('NIR en groupes standard à clé fausse : masqué, pas de signal',
      () async {
    final r = await Ecluse.redact('Dossier 1 26 07 65 873 965 62 reçu.');
    expect(r.entities.where((e) => e.type == EntityType.nir), isNotEmpty);
    expect(signaux(r), isEmpty);
  });

  test('cinq groupes de trois (P2-263) : masqué, pas de signal', () async {
    final r = await Ecluse.redact(
        'Attention, saisie erronée hier : 285.057.800.608.446 a été rejeté.');
    expect(r.entities.where((e) => e.type == EntityType.nir), isNotEmpty);
    expect(signaux(r), isEmpty);
  });

  test('clé juste en groupes de quatre : pas de signal de cette garde',
      () async {
    // Clé juste : NirDetector décide seul, la garde de coupures ne s'applique
    // pas à lui ; rien n'est écarté par `nir_coupures`.
    final cle = 97 - (int.parse(brut.substring(0, 13)) % 97);
    final juste = brut.substring(0, 13) + cle.toString().padLeft(2, '0');
    final texte = '${juste.substring(0, 4)} ${juste.substring(4, 8)} '
        '${juste.substring(8, 12)} ${juste.substring(12)}';
    final r = await Ecluse.redact('Dossier $texte reçu.');
    expect(signaux(r), isEmpty);
  });

  test('RPPS suivi d\'un nombre (P2-174) : ce n\'est pas un NIR coupé, silence',
      () async {
    final r = await Ecluse.redact('RPPS 10192209566\n1250 places.');
    expect(signaux(r), isEmpty);
  });

  test('texte sans chiffre : aucun avertissement', () async {
    final r = await Ecluse.redact('Réunion lundi, salle verte.');
    expect(signaux(r), isEmpty);
  });
}
