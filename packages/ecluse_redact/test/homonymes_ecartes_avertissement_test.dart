import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-310 (principe du 26 novembre, point 0) : quatre listes d'exclusion des noms
/// (`verbes_conjugues`, `statuts`, `mots_voisins_neutres`, `mots_de_role`) laissent
/// en clair un patronyme homonyme d'un de leurs mots (inventaire P2-308 : 0
/// signalé sur la sonde). `Ecluse.redact` le signale « à vérifier » (compte et
/// positions, **jamais la valeur**). **Aucun masquage ne change.**
void main() {
  final motif = RegExp(r'mot pris pour un nom commun.*non masqué : à vérifier');

  Iterable<String> signaux(RedactResult r) => r.warnings.where(motif.hasMatch);

  Future<void> signale(String texte, String mot, {int occurrences = 1}) async {
    final r = await Ecluse.redact(texte);
    final a = signaux(r).toList();
    expect(a, hasLength(1), reason: texte);
    expect(a.single, contains('$occurrences occurrence'), reason: texte);
    expect(a.single.toLowerCase(), isNot(contains(mot.toLowerCase())),
        reason: 'la valeur ne figure pas dans l\'avertissement');
    // Le mot reste en clair (aucun masquage ne change) : aucune entité ne le couvre.
    final debut = texte.indexOf(mot);
    expect(
        r.entities.where((e) => e.start < debut + mot.length && e.end > debut),
        isEmpty,
        reason: texte);
  }

  group('statuts derrière une civilité', () {
    test('Madame Marié',
        () => signale('Madame Marié est venue ce matin.', 'Marié'));
    test('Madame Cadet',
        () => signale('Madame Cadet est venue ce matin.', 'Cadet'));
    test('famille Cadet',
        () => signale('La famille Cadet a rappelé le service.', 'Cadet'));
  });

  group('derrière « le dossier de »', () {
    test('mois',
        () => signale('Le dossier de Avril a été transmis hier.', 'Avril'));
    test('jour',
        () => signale('Le dossier de Lundi a été transmis hier.', 'Lundi'));
    test('mot de rôle',
        () => signale('Le dossier de Gendre a été transmis hier.', 'Gendre'));
    test('statut',
        () => signale('Le dossier de Marié a été transmis hier.', 'Marié'));
  });

  group('prénom connu en minuscules suivi d\'un mot écarté', () {
    test('verbe conjugué',
        () => signale('sophie porte a rappelé le service ce matin.', 'porte'));
  });

  test('plusieurs occurrences : un seul avertissement, compte et positions',
      () async {
    final r = await Ecluse.redact(
        'Madame Marié est venue. Madame Cadet a rappelé. Le dossier de Avril '
        'a été transmis.');
    final a = signaux(r).toList();
    expect(a, hasLength(1));
    expect(a.single, contains('3 occurrences'));
  });

  group('pas de signal', () {
    for (final texte in [
      'Réunion lundi à 14 h, salle 3.',
      'Madame Dupont est venue ce matin.',
      'Le dossier de Zorglub Quenelle a été transmis.',
      'Sophie rappelle le service demain.',
      'Elle est mariée depuis longtemps.',
      'Le dossier de presse est prêt.',
    ]) {
      test(texte, () async {
        expect(signaux(await Ecluse.redact(texte)), isEmpty);
      });
    }

    test('un nom masqué n\'est pas signalé', () async {
      final r = await Ecluse.redact('Madame Dupont est venue ce matin.');
      expect(r.entities.where((e) => e.type == EntityType.nom), isNotEmpty);
      expect(signaux(r), isEmpty);
    });
  });
}
