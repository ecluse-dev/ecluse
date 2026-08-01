import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

void main() {
  const detector = NameDetector();

  group('NameDetector', () {
    test('civilité + prénom + nom -> confiance haute, civilité préservée', () {
      final entities = detector.detect('M. Jean Dupont est arrivé.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Jean Dupont');
      expect(entities.single.start, 'M. '.length);
      expect(entities.single.confidence, 0.9);
    });

    test('civilité + un seul mot capitalisé -> détecté, civilité préservée',
        () {
      // Civilité de genre : reste en clair, contrairement au titre
      // professionnel (voir le groupe dédié plus bas).
      final entities = detector.detect('M. Martin recevra le patient.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Martin');
    });

    test('prénom connu + mot capitalisé -> confiance moyenne', () {
      final entities = detector.detect('Sophie Lambert dirige le foyer.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Sophie Lambert');
      expect(entities.single.confidence, 0.6);
    });

    test('prénom connu isolé, sans nom qui suit -> confiance plus faible', () {
      final entities = detector.detect('Sophie rappelle que le dossier '
          'avance.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Sophie');
      expect(entities.single.confidence, 0.5);
    });

    test('mot capitalisé en début de phrase sans indice -> non détecté', () {
      final entities = detector.detect('Le contrat est signé aujourd\'hui.');
      expect(entities, isEmpty);
    });

    test('mot capitalisé quelconque sans prénom connu -> non détecté', () {
      final entities = detector.detect('Nantes accueille de nombreux '
          'établissements.');
      expect(entities, isEmpty);
    });

    test('NOM en majuscules avant un prénom connu -> bloc complet', () {
      final entities = detector.detect('DANNER Laurent a signé le contrat.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'DANNER Laurent');
      expect(entities.single.confidence, 0.6);
    });

    // Reproduction exacte du bug signalé : "DANNER Laurent" strictement en
    // début de texte, sans rien avant. Le mot en majuscules doit être
    // rattaché au prénom qui le suit, pas laissé en clair à côté du jeton.
    test('"DANNER Laurent" seul, en tout début de texte -> bloc complet',
        () async {
      final entities = detector.detect('DANNER Laurent');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'DANNER Laurent');
      expect(entities.single.start, 0);
      expect(entities.single.end, 'DANNER Laurent'.length);
      expect(entities.single.confidence, 0.6);

      final masked = (await Ecluse.redact('DANNER Laurent')).maskedText;
      expect(masked, isNot(contains('DANNER')));
      expect(masked, contains('[NOM_1]'));
    });

    test('prénom connu suivi d\'un NOM en majuscules -> bloc complet', () {
      final entities = detector.detect('Laurent DANNER a signé le contrat.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Laurent DANNER');
      expect(entities.single.confidence, 0.6);
    });

    // Ordre inverse de la reproduction ci-dessus, même exigence.
    test('"Laurent DANNER" seul, en tout début de texte -> bloc complet',
        () async {
      final entities = detector.detect('Laurent DANNER');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Laurent DANNER');
      expect(entities.single.confidence, 0.6);

      final masked = (await Ecluse.redact('Laurent DANNER')).maskedText;
      expect(masked, isNot(contains('DANNER')));
      expect(masked, contains('[NOM_1]'));
    });

    test(
        'civilité + NOM en majuscules + prénom -> bloc complet, civilité '
        'préservée', () {
      final entities = detector.detect('Mme HOUSER Lorette est présente.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'HOUSER Lorette');
      expect(entities.single.confidence, 0.9);
    });

    test('sigle en majuscules isolé, sans prénom ni civilité -> non détecté',
        () {
      final entities = detector.detect('Hier, le CSE a voté à l\'unanimité.');
      expect(entities, isEmpty);
    });

    group('ordre NOM Prénom (sans majuscules) — bug corrigé', () {
      // Avant correction : seul le prénom connu était capté, le nom de
      // famille qui le précède (non tout-majuscules) fuitait en clair.
      test('"Dubreuil Thomas" -> bloc complet, pas seulement le prénom', () {
        final entities = detector.detect('Dubreuil Thomas a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Dubreuil Thomas');
        expect(entities.single.confidence, 0.6);
      });

      test('"Valette Sophie" -> bloc complet (le nom ne doit pas fuiter)', () {
        final entities = detector.detect('Valette Sophie a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Valette Sophie');
      });

      test('"Roche Chantal" -> bloc complet (le nom ne doit pas fuiter)', () {
        final entities = detector.detect('Roche Chantal a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Roche Chantal');
      });

      test('"Vasseur Marc" -> bloc complet (le nom ne doit pas fuiter)', () {
        final entities = detector.detect('Vasseur Marc a signé le contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Vasseur Marc');
      });
    });

    group('prénom composé (tiret) — bug corrigé', () {
      // Avant correction : le motif capitalisé gourmand avalait le tiret
      // ("Jean-Marc" comme un seul jeton), qui ne correspondait à aucune
      // entrée du gazetteer -> aucune détection, fuite totale.
      test('"VALETTE Jean-Marc" -> bloc complet, prénom composé reconnu', () {
        final entities = detector.detect('VALETTE Jean-Marc a signé le '
            'contrat.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'VALETTE Jean-Marc');
        expect(entities.single.confidence, 0.6);
      });

      test('prénom composé après civilité reste géré normalement', () {
        final entities = detector.detect('Mme Anne-Sophie Perrin est '
            'arrivée.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Anne-Sophie Perrin');
      });

      test('un mot composé qui n\'est pas un prénom connu reste ignoré', () {
        final entities = detector.detect('Peut-être qu\'il viendra '
            'demain.');
        expect(entities, isEmpty);
      });
    });

    test('acronymes métier en majuscules -> jamais masqués (non-régression)',
        () {
      const acronymSentences = [
        'Hier, le SSIAD a coordonné la visite.',
        'La CARSAT a validé le dossier.',
        'Le HAD intervient à domicile.',
        'La RCP se tient jeudi.',
        'Le MSP accueille de nouveaux patients.',
        'La PCH a été accordée.',
        'L\'APA couvre une partie des frais.',
        'L\'IDE est passée ce matin.',
        'L\'IDEC a validé le protocole.',
        'L\'ESAT emploie 40 personnes.',
        'Le CSE a voté à l\'unanimité.',
      ];
      for (final sentence in acronymSentences) {
        expect(
          detector.detect(sentence),
          isEmpty,
          reason: 'faux positif sur : $sentence',
        );
      }
    });

    group('sigles cliniques et d\'échelles — bug corrigé', () {
      // "EVA" (Échelle Visuelle Analogique) est AUSSI un prénom français
      // connu du gazetteer : contrairement aux sigles administratifs
      // (jamais un prénom), il fallait une exclusion explicite, pas
      // seulement l'absence du gazetteer.
      test('"EVA" dans son contexte clinique réel -> jamais un nom', () {
        final entities = detector.detect('Douleur évaluée : bolus 1mg si '
            'EVA > 4.');
        expect(entities, isEmpty);
      });

      test('sigles cliniques/échelles courants -> jamais masqués', () {
        const clinicalSentences = [
          'Le score MMS est stable.',
          'Le GIR a été réévalué ce mois-ci.',
          'L\'ECG ne montre pas d\'anomalie.',
          'La TSH est dans les normes.',
          'L\'IMC du patient est de 24.',
        ];
        for (final sentence in clinicalSentences) {
          expect(
            detector.detect(sentence),
            isEmpty,
            reason: 'faux positif sur : $sentence',
          );
        }
      });

      test(
          '"EVA" ne fusionne pas non plus comme faux nom de famille '
          'adjacent à un prénom connu', () {
        final entities = detector.detect('Julien EVA a complété la '
            'grille.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Julien');
        expect(entities.single.confidence, 0.5);
      });

      test(
          '"Eva" en casse normale reste un vrai prénom détecté (non-'
          'régression : seule la forme MAJUSCULE du sigle est exclue)', () {
        final entities = detector.detect('Eva rappelle que le dossier '
            'avance.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Eva');
      });
    });

    test('civilité + nom seul reste inchangée par la règle bidirectionnelle',
        () {
      // Civilité de genre : reste en clair, contrairement au titre
      // professionnel (voir le groupe dédié plus bas).
      final entities = detector.detect('Monsieur Vasseur recevra le patient.');
      expect(entities, hasLength(1));
      expect(entities.single.value, 'Vasseur');
      expect(entities.single.confidence, 0.9);
    });

    group('civilité "Pr"/"Professeur" (bug à corriger)', () {
      // "Pr Dupont" (patronyme seul, sans prénom reconnu) fuit aujourd'hui :
      // "Pr" est absent de la liste de civilités, contrairement à
      // Dr/Docteur. Trou réel en contexte hospitalier (professeur de
      // médecine en compte rendu).
      //
      // Valeurs mises à jour : "Pr"/"Professeur" sont des titres
      // professionnels, absorbés dans le span (voir le groupe dédié plus
      // bas) — la civilité n'est donc plus préservée ici, contrairement à
      // "M."/"Monsieur" ci-dessus.
      test('"Pr" + nom seul -> détecté, titre absorbé', () {
        final entities = detector.detect('Pr Dupont recevra le patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Pr Dupont');
        expect(entities.single.confidence, 0.9);
      });

      test('"Professeur" + nom seul -> détecté, titre absorbé', () {
        final entities =
            detector.detect('Professeur Dupont recevra le patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Professeur Dupont');
        expect(entities.single.confidence, 0.9);
      });

      test('"Pr" + prénom + patronyme -> bloc complet, titre inclus', () {
        final entities = detector.detect('Pr Nadia Costa examine le patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Pr Nadia Costa');
        expect(entities.single.confidence, 0.9);
      });
    });

    group(
        'mentions partielles rattrapées via un patronyme déjà connu — '
        'bug corrigé', () {
      // Cas 1 : nom de famille seul, après une mention complète. Le titre
      // "Dr" est désormais inclus dans l'entité complète, mais
      // _extractSurname doit continuer à isoler "Costa" pour que le
      // rattrapage fonctionne (voir le groupe dédié plus bas).
      test('"Costa" seul, après "Dr Nadia Costa", est rattrapé', () {
        final entities = detector.detect(
          'Dr Nadia Costa examine le patient. Costa confirme le '
          'diagnostic la semaine suivante.',
        );
        expect(entities, hasLength(2));
        expect(entities[0].value, 'Dr Nadia Costa');
        expect(entities[1].value, 'Costa');
      });

      // Cas 2 : initiale + nom. L'initiale seule n'est pas un identifiant
      // fort (comme une civilité) : seul le patronyme est masqué, à
      // l'image de "M."/"Mme" qui restent visibles à côté du jeton.
      test(
          '"S. Reynaud" est rattrapé via le patronyme "Reynaud" connu de '
          '"Mme Sandra Reynaud" ; l\'initiale reste visible', () {
        final entities = detector.detect(
          'Mme Sandra Reynaud dirige le service. S. Reynaud a signé le '
          'rapport.',
        );
        expect(entities, hasLength(2));
        expect(entities[0].value, 'Sandra Reynaud');
        expect(entities[1].value, 'Reynaud');
      });

      // Cas 3 : membre de famille partageant le patronyme, mais avec un
      // prénom DIFFÉRENT -> doit être détecté comme un patronyme connu,
      // mais rester une personne distincte (vérifié côté identité dans
      // ecluse_redact_test.dart).
      test(
          '"Morel Hélène" est rattrapé via le patronyme "Morel" connu de '
          '"MOREL Antoine"', () {
        final entities = detector.detect(
          'Patient : M. MOREL Antoine. Épouse : Morel Hélène, personne de '
          'confiance.',
        );
        expect(entities, hasLength(2));
        expect(entities[0].value, 'MOREL Antoine');
        expect(entities[1].value, 'Morel Hélène');
      });

      test(
          'sans mention complète préalable, un patronyme isolé ne '
          'déclenche toujours rien (non-régression)', () {
        final entities = detector.detect('Costa confirme le diagnostic.');
        expect(entities, isEmpty);
      });

      test(
          'un sigle qui apparaîtrait comme composant d\'une mention '
          'civile n\'est jamais retenu comme patronyme de rattrapage', () {
        // Risque explicite du chantier : si un patronyme collecté (même
        // via la civilité, qui ne filtre pas les sigles) coïncide avec un
        // sigle métier, il ne doit jamais servir de patronyme pour la
        // passe de rattrapage.
        final entities = detector.detect(
          'Dr HAD Martin examine le dossier. Plus loin, le SSIAD et le '
          'HAD interviennent à domicile.',
        );
        expect(entities.map((e) => e.value), isNot(contains('HAD')));
      });

      test(
          'non-régression : médicaments, dispositifs et sigles métier '
          'ne sont jamais pris pour un patronyme de rattrapage', () {
        final entities = detector.detect(
          'Dr Nadia Costa prescrit le traitement. Costa ajuste la '
          'posologie : innohep 10000 UI, Lovenox 4000 UI, Lasilix 40 mg, '
          'Bétadine en application locale, Spiriva 1 inhalation par jour, '
          'Symbicort 2 bouffées, dispositif Snoezelen, pansement URGO '
          'Start. Le programme Asalée et le protocole PRADO sont '
          'poursuivis, ainsi que la PCA et le dossier Anah. Sigles '
          'présents : SSIAD, CARSAT, EHPAD, SAMSAH, MSP, RCP, HAD, IDEC, '
          'CPTS, MDPH, CCAS, ALD, BPCO, EVA, IPS, MMSE, PTH, IDE, IDEL, '
          'UDAF, CVS, ESAT.',
        );
        expect(entities.map((e) => e.value), ['Dr Nadia Costa', 'Costa']);
      });
    });

    test('type exposé est EntityType.nom', () {
      expect(detector.type, EntityType.nom);
    });

    // -------------------------------------------------------------------------
    // Titre professionnel absorbé dans le span (bug à corriger).
    //
    // Périmètre strict : Dr, Docteur, Pr, Professeur, Me. Les civilités de
    // genre (M., Mme, Mademoiselle, Monsieur, Madame) restent en clair —
    // arbitrage volontairement non tranché, voir LIMITES.md. Un seul jeton,
    // type NOM existant — pas de nouveau type TITRE.
    // -------------------------------------------------------------------------
    group('titre professionnel absorbé dans le span (bug à corriger)', () {
      test('"Dr Martin" -> un seul jeton couvrant le titre et le nom',
          () async {
        final entities = detector.detect('Dr Martin recevra le patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Dr Martin');
        expect(entities.single.start, 0);
        expect(entities.single.type, EntityType.nom);

        final r = await Ecluse.redact('Dr Martin recevra le patient.');
        expect(r.maskedText, '[NOM_1] recevra le patient.');
        expect(
          Ecluse.restore(r.maskedText, r.mapping),
          'Dr Martin recevra le patient.',
        );
      });

      test('"Pr Nadia Costa" -> nom composé absorbé avec le titre', () async {
        final entities = detector.detect('Pr Nadia Costa examine le dossier.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Pr Nadia Costa');

        final r = await Ecluse.redact('Pr Nadia Costa examine le dossier.');
        expect(r.maskedText, '[NOM_1] examine le dossier.');
        expect(
          Ecluse.restore(r.maskedText, r.mapping),
          'Pr Nadia Costa examine le dossier.',
        );
      });

      test('"Me Dubois" -> titre absorbé', () async {
        final entities = detector.detect('Me Dubois a signé l\'acte.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Me Dubois');

        final r = await Ecluse.redact('Me Dubois a signé l\'acte.');
        expect(r.maskedText, '[NOM_1] a signé l\'acte.');
        expect(
          Ecluse.restore(r.maskedText, r.mapping),
          'Me Dubois a signé l\'acte.',
        );
      });

      test(
          '"Monsieur Martin" -> INCHANGÉ, la civilité de genre reste en '
          'clair', () async {
        final entities = detector.detect('Monsieur Martin recevra le '
            'patient.');
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Martin');

        final r = await Ecluse.redact('Monsieur Martin recevra le patient.');
        expect(r.maskedText, 'Monsieur [NOM_1] recevra le patient.');
        expect(
          Ecluse.restore(r.maskedText, r.mapping),
          'Monsieur Martin recevra le patient.',
        );
      });

      test(
          '"Dr Martin\\nSecretaire de séance." -> le span ne traverse pas '
          'le saut de ligne', () async {
        const texte = 'Dr Martin\nSecretaire de séance.';
        final entities = detector.detect(texte);
        expect(entities, hasLength(1));
        expect(entities.single.value, 'Dr Martin');

        final r = await Ecluse.redact(texte);
        expect(r.maskedText, '[NOM_1]\nSecretaire de séance.');
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      });

      // _extractSurname doit ignorer le titre en tête avant de splitter :
      // sinon "Pr Nadia Costa" (3 mots) ne produit plus aucun patronyme
      // extrait, et le rattrapage d'une mention partielle plus loin dans
      // le document ("Costa" seul, sans titre ni prénom) ne fonctionne
      // plus. L'entité complète, elle, doit rester "Pr Nadia Costa" pour
      // le masquage.
      test(
          'rattrapage : "Costa" seul est toujours rattrapé quand la '
          'mention complète porte un titre professionnel', () async {
        const texte = 'Pr Nadia Costa examine le patient. Costa confirme le '
            'diagnostic la semaine suivante.';
        final entities = detector.detect(texte);
        expect(entities, hasLength(2));
        expect(entities[0].value, 'Pr Nadia Costa');
        expect(entities[1].value, 'Costa');

        final r = await Ecluse.redact(texte);
        expect(r.mapping.length, 1, reason: 'même identité, même jeton');

        final restored = Ecluse.restore(r.maskedText, r.mapping);
        expect(restored, isNot(equals(texte)));
        expect(
          restored,
          'Pr Nadia Costa examine le patient. Pr Nadia Costa confirme le '
          'diagnostic la semaine suivante.',
        );
      });
    });
  });
}
