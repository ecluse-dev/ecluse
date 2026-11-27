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

  group('prénom aussi nom commun, en minuscules : pas de signal', () {
    // « iris sans particularité » est de la prose (le prénom est une fleur) ;
    // 38 documents sur 400 du témoin « faux amis » étaient avertis à tort.
    for (final texte in [
      'iris sans particularité notable à l\'examen, tout est normal.',
      'rose pour la suite des soins, rien à signaler ce matin.',
      'olive sur le plateau du repas, sans autre remarque.',
    ]) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.warnings.where(motif.hasMatch), isEmpty, reason: texte);
      });
    }
    test('un prénom qui n\'est pas un nom commun garde son signal',
        () => signale('sophie sans a rappelé le service ce matin.', 'sans'));
  });

  group('déterminant derrière « demande de » ou « entretien avec »', () {
    // « à la demande de la Préfecture » : « la » est un article, pas un nom.
    // Mesure P2-316 : 59 documents sur 400 du témoin `tournures_sans_nom`
    // (casse ordinaire) étaient avertis à tort, au-dessus du seuil de 5 %.
    for (final texte in [
      'Rendez-vous reporté à la demande de la Préfecture ce mardi.',
      'Le dossier de le Service est transmis hier matin.',
      'Entretien avec la direction prévu jeudi prochain.',
      'Entretien avec le service qualité prévu jeudi.',
    ]) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.warnings.where(motif.hasMatch), isEmpty, reason: texte);
      });
    }
  });

  group('déterminant derrière un prénom en minuscules : pas de signal', () {
    for (final texte in [
      'Le courrier arrive: eva le transmet au service demain matin.',
      'Dossier clos, gauthier ce matin au bureau pour la réunion.',
      'Réunion: eva du service qualité sera présente jeudi.',
    ]) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.warnings.where(motif.hasMatch), isEmpty, reason: texte);
      });
    }
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
