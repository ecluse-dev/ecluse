import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-316 (principe du 26 novembre, point 0) : neuf listes d'exclusion des noms
/// (`non_noms`, `mots_structure`, `sigles_organismes`, `mots_contexte_non_noms`,
/// `articles_capitalises`, `sigles_exclus`, `prenoms_insee_exclus`,
/// `mots_neutres`, `outils_initiale`) laissaient en clair, sans un mot, un
/// patronyme homonyme d'un de leurs mots (inventaire P2-308). Elles sont
/// signalées comme les quatre de P2-310 : « à vérifier », compte et positions,
/// **jamais la valeur**. **Aucun masquage ne change.**
void main() {
  final motif = RegExp(r'mot pris pour un nom commun.*non masqué : à vérifier');

  Future<void> signale(String texte, String mot) async {
    final r = await Ecluse.redact(texte);
    final a = r.warnings.where(motif.hasMatch).toList();
    expect(a, hasLength(1), reason: texte);
    final debut = texte.indexOf(mot);
    expect(a.single, contains('position $debut)'), reason: texte);
    // Seule la partie « compte et positions » est variable : le libellé fixe
    // contient des mots courants (« pour »).
    expect(a.single.split('(').last.toLowerCase(),
        isNot(contains(mot.toLowerCase())),
        reason: 'la valeur ne figure pas dans l\'avertissement');
    expect(
        r.entities.where((e) => e.start < debut + mot.length && e.end > debut),
        isEmpty,
        reason: texte);
  }

  group('derrière « le dossier de »', () {
    for (final (mot, liste) in [
      ('Sans', 'non_noms et mots_neutres'),
      ('Pour', 'mots_structure'),
      ('Personne', 'mots_contexte_non_noms'),
      ('Chacun', 'mots_contexte_non_noms'),
      ('Cette', 'articles_capitalises et outils_initiale'),
      ('Ces', 'articles_capitalises et outils_initiale'),
      ('Sur', 'mots_neutres'),
      ('PRADO', 'sigles_exclus'),
      ('ARS', 'sigles_organismes'),
      ('Des', 'prenoms_insee_exclus'),
    ]) {
      test('$mot ($liste)',
          () => signale('Le dossier de $mot a été transmis hier.', mot));
    }
  });

  group('prénom connu en minuscules', () {
    test('mot neutre',
        () => signale('sophie sans a rappelé le service ce matin.', 'sans'));
    test('pronom',
        () => signale('sophie elles a rappelé le service ce matin.', 'elles'));
  });

  group('mot masqué ou mot ordinaire : pas de signal', () {
    for (final texte in [
      'Le dossier de presse est prêt.',
      'Le dossier de Zorglub Quenelle a été transmis.',
      'Madame Dupont est venue ce matin.',
      'Réunion sans pause à 14 h, salle 3.',
      'Sophie Martin a rappelé le service.',
      'Il faut le dossier sans tarder.',
    ]) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.warnings.where(motif.hasMatch), isEmpty);
      });
    }
  });
}
