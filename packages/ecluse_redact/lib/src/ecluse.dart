import 'dart:async';

import 'package:ecluse_audit/ecluse_audit.dart' show AuditChain, JournalAudit;
import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_reference/ecluse_reference.dart'
    show EcluseReference, RareDiseaseCatalog;

import 'heuristics/adresse_detector.dart';
import 'heuristics/date_naissance_detector.dart';
import 'heuristics/email_detector.dart';
import 'heuristics/etablissement_detector.dart';
import 'heuristics/identifiant_cle_invalide_detector.dart';
import 'heuristics/identifiant_detector.dart';
import 'heuristics/identifiant_ocr_detector.dart';
import 'heuristics/initiale_libelle_detector.dart';
import 'heuristics/maladie_rare_detector.dart';
import 'heuristics/prenom_insee_detector.dart';
import 'heuristics/name_detector.dart';
import 'heuristics/casse.dart';
import 'heuristics/minuscules_recapitalise_detector.dart';
import 'heuristics/nom_minuscules_detector.dart';
import 'heuristics/telephone_detector.dart';
import 'coupures_de_nom.dart';
import 'redact_result.dart';
import 'risque.dart';
import 'table_de_correspondance.dart';
import 'tokenizer.dart';

part 'apercu.dart';
part 'dossier.dart';
part 'identites_de_noms.dart';
part 'patronymes_connus.dart';
part 'nombres_dictes.dart';
part 'normalisation_du_texte.dart';
part 'restauration.dart';
part 'session.dart';

/// Façade de pseudonymisation réversible d'Écluse.
///
/// ```dart
/// final result = await Ecluse.redact(texte);
/// // result.maskedText -> texte à envoyer à l'IA
/// // result.mapping    -> table jeton ↔ valeur réelle (reste en mémoire)
/// // result.entities   -> entités détectées (type, confiance)
///
/// final finalText = Ecluse.restore(reponseDuLLM, result.mapping);
/// ```
///
/// `Ecluse.redact` compose, via `EcluseEngine`, les détecteurs à validation
/// structurelle d'`ecluse_core` (NIR, RPPS, IBAN, FINESS, INS) et les
/// détecteurs heuristiques v0 de ce package (voir `lib/src/heuristics/`, remplacés en
/// phase 2 par un NER local — voir ROADMAP.md). `redact` est async parce
/// que `Detector.detect` l'est (contrat uniforme avec le futur NER, qui
/// pourra tourner dans un isolate) — les détecteurs eux-mêmes restent
/// synchrones en interne.
///
/// **Aucun seuil de confiance ne filtre les entités masquées dans cette
/// version** : toute entité détectée, quelle que soit sa confiance, est
/// remplacée par un jeton. Principe : en cas de doute, on protège — un
/// faux positif masqué dégrade un peu le prompt envoyé au LLM, mais un
/// faux négatif non masqué est une fuite. Le routage par seuil de
/// confiance est une décision produit qui viendra plus tard (voir
/// ROADMAP.md, « routage on-device/cloud selon la sensibilité »), pas une
/// décision à prendre silencieusement dans le moteur de redaction.
abstract final class Ecluse {
  /// Détecteurs utilisés par défaut par [redact].
  static const List<Detector> defaultDetectors = [
    LegacyDetectorAdapter(NirDetector(), DetectorTier.structural, name: 'nir'),
    LegacyDetectorAdapter(RppsDetector(), DetectorTier.structural,
        name: 'rpps'),
    // `cleInvalideFr` (P2-252) : un IBAN de forme française à clé invalide est
    // masqué en entier à confiance 0,3, pour qu'une fenêtre FINESS ou
    // téléphone à l'intérieur ne masque jamais qu'une partie du numéro.
    LegacyDetectorAdapter(
        IbanDetector(cleInvalideFr: true), DetectorTier.structural,
        name: 'iban'),
    LegacyDetectorAdapter(InsDetector(), DetectorTier.structural, name: 'ins'),
    FinessDetector(),
    AdeliDetector(),
    LegacyDetectorAdapter(NameDetector(), DetectorTier.reference, name: 'nom'),
    LegacyDetectorAdapter(NomMinusculesDetector(), DetectorTier.reference,
        name: 'nom_minuscules'),
    LegacyDetectorAdapter(InitialeLibelleDetector(), DetectorTier.reference,
        name: 'nom_initiale'),
    LegacyDetectorAdapter(DateNaissanceDetector(), DetectorTier.pattern,
        name: 'date_naissance'),
    LegacyDetectorAdapter(AdresseDetector(), DetectorTier.pattern,
        name: 'adresse'),
    LegacyDetectorAdapter(TelephoneDetector(), DetectorTier.pattern,
        name: 'telephone'),
    LegacyDetectorAdapter(EmailDetector(), DetectorTier.pattern, name: 'email'),
    LegacyDetectorAdapter(EtablissementDetector(), DetectorTier.pattern,
        name: 'etablissement'),
    LegacyDetectorAdapter(
        MinusculesRecapitaliseDetector(AdresseDetector(), communesSeules: true),
        DetectorTier.pattern,
        name: 'adresse_minuscules'),
    LegacyDetectorAdapter(
        MinusculesRecapitaliseDetector(EtablissementDetector()),
        DetectorTier.pattern,
        name: 'etablissement_minuscules'),
    LegacyDetectorAdapter(IdentifiantDetector(), DetectorTier.pattern,
        name: 'identifiant'),
    SecretDetector(),
  ];

  // `IdentifiantCleInvalideDetector` (P2-188) n'est volontairement **pas**
  // dans cette liste : contrairement aux autres détecteurs, il doit lire le
  // texte d'origine, jamais la vue de détection (`_vueDeDetection`). Cette
  // vue neutralise notamment la clé d'un NIR nommée à part (P2-42,
  // « 2550814168025 clé 38 ») pour que le NIR se reconnaisse malgré le mot
  // « clé » entre le numéro et sa clé — mais à la condition stricte que
  // cette clé soit juste (« une clé fausse n'est jamais acceptée »,
  // P2-42). Sur la vue, un NIR à clé séparée **fausse** se présenterait à
  // `IdentifiantCleInvalideDetector` comme un NIR normal à clé fausse, et
  // serait masqué à tort : exactement le compromis que P2-42 a refusé. Voir
  // [_detecter], qui l'appelle à part, sur [text].

  /// Détecte les entités personnelles de [text] et produit un texte masqué
  /// par jetons typés, ainsi que la table de correspondance nécessaire à
  /// [restore].
  ///
  /// Une même valeur détectée reçoit toujours le même jeton dans tout le
  /// texte, pour que le LLM garde le fil des références.
  ///
  /// **Secrets** (clés d'API, jetons, clés privées) : masqués comme le reste,
  /// avec un avertissement dans [RedactResult.warnings]. Ils ne sont **pas**
  /// ajoutés à la table de restauration, sauf si [restoreSecrets] est vrai :
  /// un secret restauré dans la réponse affichée pourrait finir copié dans
  /// un autre outil. Avec [refuseSecrets], la présence d'un secret lève
  /// [SecretsRefusedException] au lieu de masquer (mode strict).
  ///
  /// **Rapport de risque** (P2-04) : avec [riskReference] (référence chargée
  /// par l'appelant), [RedactResult.risque] évalue la ré-identification par
  /// profession de santé, lieu et âge restés dans le texte masqué. Sans elle,
  /// la sortie est exactement celle d'avant : fonction inactive, `risque` nul.
  /// Le rapport ne change jamais le texte envoyé.
  ///
  /// **Dossier** (P2-06) : avec [dossier], les jetons et les identités sont
  /// conservés d'un appel à l'autre, en mémoire seulement. Une même valeur
  /// (e-mail, téléphone…) ou une même identité de nom **complète** (au moins
  /// deux segments, identiques) y garde son jeton ; une mention partielle
  /// d'un autre document reçoit un nouveau jeton, jamais une fusion par
  /// patronyme. Les appels d'un même dossier sont sérialisés. Sans [dossier],
  /// la sortie est exactement celle d'avant.
  ///
  /// **Journal d'audit** (P2-96) : avec [journal], chaque appel laisse une
  /// entrée chaînée (comptes par type, jamais de valeur), écrite **avant** que
  /// le résultat soit rendu et avant tout changement du [dossier] : un texte
  /// rendu a toujours sa trace. Un refus de secrets laisse une entrée
  /// `secrets_refused`. Si l'écriture échoue, l'exception du journal remonte et
  /// rien n'est masqué. Sans [journal], la sortie est exactement celle d'avant.
  ///
  /// **Maladies rares** (P2-143) : avec [maladiesRares] (catalogue Orphanet
  /// **chargé** par l'appelant, sinon [StateError]), une maladie rare
  /// rattachée à une personne et non niée est masquée (`[MALADIE_RARE_1]`)
  /// et restaurable ; les pathologies fréquentes restent en clair. Voir
  /// `MaladieRareDetector`. Sans [maladiesRares], la sortie est exactement
  /// celle d'avant.
  ///
  /// **Prénoms de l'INSEE** (P2-149) : avec [prenomsInsee] (effectifs
  /// **chargés** par l'appelant, sinon [StateError]), un prénom du fichier de
  /// l'INSEE absent de la liste écrite à la main, d'effectif au moins égal au
  /// seuil, suivi d'un patronyme (« Souleymane Aubry »), est masqué comme un
  /// nom. Voir
  /// `PrenomInseeDetector`. Sans [prenomsInsee], la sortie est exactement
  /// celle d'avant.
  ///
  /// **Formes verbales** (P2-251) : avec [formesVerbales] (ensemble de mots en
  /// minuscules, accents conservés, **chargé par l'appelant**, par exemple depuis
  /// le paquet optionnel `ecluse_lexique` sous LGPL-LR), un prénom suivi d'une de
  /// ces formes (« Sophie félicite ») est masqué **seul** : le verbe reste
  /// lisible. Ce paquet n'importe jamais le lexique. Sans [formesVerbales] (ou
  /// vide), la sortie est exactement celle d'avant.
  static Future<RedactResult> redact(
    String text, {
    List<Detector>? detectors,
    bool restoreSecrets = false,
    bool refuseSecrets = false,
    EcluseReference? riskReference,
    Dossier? dossier,
    JournalAudit? journal,
    RareDiseaseCatalog? maladiesRares,
    PrenomsInsee? prenomsInsee,
    Set<String>? formesVerbales,
  }) {
    final options = _Options(
        detectors,
        restoreSecrets,
        refuseSecrets,
        riskReference,
        journal,
        _supplementaires(maladiesRares, prenomsInsee),
        formesVerbales ?? const {});
    if (dossier == null) return _redact(text, _Etat(), options);
    return dossier._serialise(() {
      final etat = dossier._etat;
      if (etat == null) throw const DossierFermeException();
      return _redact(text, etat, options);
    });
  }

  /// Version du moteur écrite dans le journal d'audit. Tenue égale à la
  /// version de `pubspec.yaml` par un test.
  static const String versionMoteur = 'ecluse_redact 0.2.0';

  /// Description du moteur pour le journal (décision P2-96a n° 4) : version et
  /// noms des détecteurs actifs, construite ici plutôt que fournie par
  /// l'application, pour qu'elle soit toujours exacte. Un nom hors de la forme
  /// admise par le journal devient `autre` ; au-delà de 200 caractères, seul
  /// le nombre de détecteurs est donné.
  static String descriptionMoteur([List<Detector>? detectors]) {
    final noms = [
      for (final d in detectors ?? defaultDetectors)
        _nomDetecteurSur.hasMatch(d.name) ? d.name : 'autre',
    ];
    final complete = '$versionMoteur [${noms.join(',')}]';
    if (complete.length <= 200) return complete;
    return '$versionMoteur [${noms.length} detecteurs]';
  }

  static final RegExp _nomDetecteurSur = RegExp(r'^[A-Za-z0-9_.+\-]{1,40}$');

  /// Détecte les entités de [text] **sans rien masquer** (P2-16, préalable de
  /// l'aperçu de `agent/specs/P2-08.md`). Renvoie exactement les entités que
  /// [redact] masquerait : triées par position, sans chevauchement.
  ///
  /// **Aucun effet de bord** : pas de jeton attribué, pas de numéro consommé,
  /// pas de patronyme établi, [dossier] inchangé. Avec un [dossier], la
  /// détection est sérialisée après ses appels précédents et profite des
  /// patronymes qu'ils ont établis (P2-14) ; un dossier fermé lève
  /// [DossierFermeException]. [detectors] remplace les détecteurs par défaut,
  /// sans être modifié.
  static Future<List<DetectedEntity>> detect(
    String text, {
    List<Detector>? detectors,
    Dossier? dossier,
    RareDiseaseCatalog? maladiesRares,
    PrenomsInsee? prenomsInsee,
    Set<String>? formesVerbales,
  }) {
    final extra = _supplementaires(maladiesRares, prenomsInsee);
    final formes = formesVerbales ?? const <String>{};
    if (dossier == null) {
      return _detecter(text, _Etat(), detectors, extra, formes);
    }
    return dossier._serialise(() {
      final etat = dossier._etat;
      if (etat == null) throw const DossierFermeException();
      return _detecter(text, etat, detectors, extra, formes);
    });
  }

  /// Détecteurs ajoutés par les options (P2-143, P2-149). Construits à
  /// l'appel, pour qu'un catalogue ou des effectifs non chargés soient
  /// refusés avant toute détection.
  static List<Detector> _supplementaires(RareDiseaseCatalog? maladiesRares,
      [PrenomsInsee? prenomsInsee]) {
    return [
      if (maladiesRares != null)
        LegacyDetectorAdapter(
            MaladieRareDetector(maladiesRares), DetectorTier.reference,
            name: 'maladie_rare'),
      if (prenomsInsee != null)
        LegacyDetectorAdapter(
            PrenomInseeDetector(prenomsInsee), DetectorTier.reference,
            name: 'prenom_insee'),
    ];
  }

  /// Détection pure : lit [etat] (patronymes établis) sans jamais le modifier.
  static Future<List<DetectedEntity>> _detecter(
    String text,
    _Etat etat,
    List<Detector>? detectors, [
    List<Detector> supplementaires = const [],
    Set<String> formesVerbales = const {},
  ]) async {
    // Dans un dossier, les patronymes établis par les documents précédents
    // amorcent la détection de noms (P2-14) ; des détecteurs fournis par
    // l'appelant ne sont jamais modifiés.
    final base = detectors ??
        (etat.patronymes.isEmpty &&
                etat.fournis.isEmpty &&
                formesVerbales.isEmpty
            ? defaultDetectors
            : _detecteursAvecPatronymes(
                etat.patronymes, etat.fournis._noms, formesVerbales));
    final engine = EcluseEngine(
        supplementaires.isEmpty ? base : [...base, ...supplementaires]);
    final (vue, positions) = _vueDeDetection(text);
    final entites = (await engine.run(vue)).entities;
    // Les positions et la valeur sont ramenées au texte d'origine : le texte
    // n'est jamais réécrit, la table garde la valeur exacte (invariant 3).
    // Ramène une entité de la vue au texte d'origine.
    DetectedEntity ramener(DetectedEntity e) {
      final debut = positions == null ? e.start : positions[e.start];
      var fin = positions == null ? e.end : positions[e.end - 1] + 1;
      // Les diacritiques qui suivent la dernière lettre en font partie.
      while (fin < text.length && _estCombinant(text.codeUnitAt(fin))) {
        fin++;
      }
      return DetectedEntity(
        type: e.type,
        start: debut,
        end: fin,
        value: text.substring(debut, fin),
        confidence: e.confidence,
        tier: e.tier,
        provenance: e.provenance,
      );
    }

    final surLeTexte =
        identical(vue, text) ? entites : [for (final e in entites) ramener(e)];
    // P2-267 : identifiants dictés en toutes lettres, lus dans une seconde
    // vue (jamais à la place de la première) ; rien à faire, et rien de
    // changé, sans suite de mots-nombres.
    final dictees = await _detecterNombresDictes(text, (vue) async {
      final ents = (await engine.run(vue)).entities;
      final cle = const IdentifiantCleInvalideDetector().detect(vue);
      final fausse = const NirCleInvalideDetector().detect(vue);
      if (cle.isEmpty && fausse.isEmpty) return ents;
      return _avecCleInvalide(resolveOverlaps([...ents, ...fausse]), cle);
    });
    final surLeTexteEtDictees = dictees.isEmpty
        ? surLeTexte
        : resolveOverlaps([
            ..._etablissementsRognesParDictees(surLeTexte, dictees, text),
            ...dictees
          ]);
    // P2-188 : identifiant à clé invalide annoncé par un libellé fort, sur
    // [text] directement — jamais sur [vue] (voir le commentaire de
    // `defaultDetectors`).
    // P2-268 : identifiants lus avec des lettres d'OCR (« O » pour 0, « l » pour
    // 1), relus pour être validés ; texte d'origine, jamais la vue.
    final cleInvalide = [
      ...const IdentifiantCleInvalideDetector().detect(text),
      ...const IdentifiantOcrDetector().detect(text),
    ];
    // P2-258 : NIR à clé fausse sans libellé, lui aussi sur [text] (la vue
    // neutralise la « clé » nommée à part de P2-42, qui doit rester intacte).
    final nirCleFausseTexte = const NirCleInvalideDetector().detect(text);
    // P2-263 : le même NIR à clé fausse coupé par une fin de ligne ou écrit en
    // chiffres pleine chasse, lu sur la vue de détection (P2-29). Ne sont gardées
    // que les détections dont l'étendue d'origine contient cette fin de ligne ou
    // ces chiffres : une coupure ordinaire reste jugée par la règle stricte sur le
    // texte (RPPS suivi d'un nombre : jamais un NIR, P2-174), et la clé nommée à
    // part (P2-42, « … clé 39 ») reste intacte, la vue effaçant le mot « clé ».
    final nirCleFausse = identical(vue, text)
        ? nirCleFausseTexte
        : [
            ...nirCleFausseTexte,
            for (final e in const NirCleInvalideDetector(coupuresLibres: true)
                .detect(vue))
              if (_coupureOuPleineChasse(ramener(e).value) &&
                  !_cleNommeeDansLaValeur.hasMatch(ramener(e).value))
                ramener(e),
          ];
    if (nirCleFausse.isNotEmpty) {
      return _avecCleInvalide(
          resolveOverlaps([...surLeTexteEtDictees, ...nirCleFausse]),
          cleInvalide);
    }
    return _avecCleInvalide(surLeTexteEtDictees, cleInvalide);
  }

  /// P2-271 : un nom d'établissement qui chevauche un identifiant **dicté**
  /// validé (seconde vue de P2-267) est rogné autour de lui. Sans cela, le nom
  /// d'établissement, plus long (« établissement ch de metz finess » avale les
  /// premiers mots-nombres du numéro), l'emportait au tri des chevauchements et
  /// laissait la fin du FINESS dicté en clair (6 à 9 sur 129 selon la variante).
  /// Les deux étendues sont gardées : l'établissement avant (et après) le
  /// numéro, le numéro en entier. Sans identifiant dicté, cette fonction n'est
  /// jamais appelée : le texte sans mot-nombre garde exactement son résultat.
  static List<DetectedEntity> _etablissementsRognesParDictees(
    List<DetectedEntity> base,
    List<DetectedEntity> dictees,
    String text,
  ) {
    final sortie = <DetectedEntity>[];
    for (final e in base) {
      if (e.type != EntityType.etablissement) {
        sortie.add(e);
        continue;
      }
      var segments = <(int, int)>[(e.start, e.end)];
      var touche = false;
      for (final d in dictees) {
        if (d.start >= e.end || d.end <= e.start) continue;
        touche = true;
        segments = [
          for (final (a, b) in segments) ...[
            if (a < d.start) (a, b < d.start ? b : d.start),
            if (b > d.end) (a > d.end ? a : d.end, b),
          ],
        ];
      }
      if (!touche) {
        sortie.add(e);
        continue;
      }
      for (var (a, b) in segments) {
        while (a < b && text[a].trim().isEmpty) {
          a++;
        }
        while (b > a && text[b - 1].trim().isEmpty) {
          b--;
        }
        if (a >= b) continue;
        sortie.add(DetectedEntity(
          type: e.type,
          start: a,
          end: b,
          value: text.substring(a, b),
          confidence: e.confidence,
          tier: e.tier,
          provenance: e.provenance,
        ));
      }
    }
    return sortie;
  }

  static List<DetectedEntity> _avecCleInvalide(
      List<DetectedEntity> surLeTexte, List<DetectedEntity> cleInvalide) {
    if (cleInvalide.isEmpty) return surLeTexte;
    // P2-199 : le libellé fort est une preuve plus forte que l'heuristique
    // d'adresse « cinq chiffres + mot ». Sur « ADELI 209l73939 noté », elle
    // lisait « 73939 noté » comme une adresse, de confiance plus haute que
    // 0,3, et `resolveOverlaps` gardait l'adresse en laissant « 209l » en
    // clair. Une adresse qui chevauche un identifiant annoncé est écartée.
    // Coût en n log m (jamais n x m) : début des candidats triés + plus
    // grande fin vue jusque-là, dichotomie sur le début.
    final candidats = [...cleInvalide]..sort((a, b) => a.start - b.start);
    final finMax = <int>[];
    var plusGrande = 0;
    for (final c in candidats) {
      if (c.end > plusGrande) plusGrande = c.end;
      finMax.add(plusGrande);
    }
    bool chevauche(DetectedEntity e) {
      var bas = 0;
      var haut = candidats.length;
      while (bas < haut) {
        final milieu = (bas + haut) >> 1;
        if (candidats[milieu].start < e.end) {
          bas = milieu + 1;
        } else {
          haut = milieu;
        }
      }
      return bas > 0 && finMax[bas - 1] > e.start;
    }

    return resolveOverlaps([
      for (final e in surLeTexte)
        if (e.type != EntityType.adresse || !chevauche(e)) e,
      for (final e in cleInvalide)
        DetectedEntity(
          type: e.type,
          start: e.start,
          end: e.end,
          value: e.value,
          confidence: e.confidence,
          tier: DetectorTier.pattern,
          provenance: e.provenance,
        ),
    ]);
  }

  static Future<RedactResult> _redact(
    String text,
    _Etat etat,
    _Options options,
  ) async {
    final resolved = await _detecter(text, etat, options.detectors,
        options.supplementaires, options.formesVerbales);

    final secretCount =
        resolved.where((e) => e.type == EntityType.secret).length;
    final journal = options.journal;
    final moteur = journal == null
        ? ''
        : descriptionMoteur(options.supplementaires.isEmpty
            ? options.detectors
            : [
                ...options.detectors ?? defaultDetectors,
                ...options.supplementaires
              ]);
    if (options.refuseSecrets && secretCount > 0) {
      await journal?.enregistrerRefusSecrets(
          moteur: moteur, nombre: secretCount);
      throw SecretsRefusedException(secretCount);
    }
    // Le journal est écrit avant l'application, qui seule modifie l'état du
    // dossier : si l'écriture échoue, rien n'est masqué ni attribué. Les
    // comptes sont ceux des entités détectées, secrets compris.
    await journal?.enregistrerMasquage(
        moteur: moteur, comptes: AuditChain.countsOf(resolved));
    return _appliquer(
        text, resolved, etat, options.restoreSecrets, options.riskReference);
  }

  /// Masque [resolved] (entités triées, sans chevauchement) dans [text] et
  /// met à jour [etat]. Seule étape qui modifie l'état : [_redact] et
  /// l'aperçu (`Apercu.applique`) passent par ici, pour que « tout accepté »
  /// reste identique à [redact].
  static RedactResult _appliquer(
    String text,
    List<DetectedEntity> resolved,
    _Etat etat,
    bool restoreSecrets,
    EcluseReference? riskReference,
  ) {
    final secretCount =
        resolved.where((e) => e.type == EntityType.secret).length;
    // Identifiant à clé invalide masqué quand même, grâce au libellé fort
    // qui l'annonce (P2-188) : confiance 0.3, unique à
    // `IdentifiantCleInvalideDetector` et, pour l'IBAN de forme française à
    // clé invalide sans libellé, à `IbanCleInvalideDetector` (P2-252).
    final cleInvalideCount = resolved
            .where((e) =>
                (e.type == EntityType.nir ||
                    e.type == EntityType.iban ||
                    e.type == EntityType.rpps ||
                    e.type == EntityType.adeli ||
                    // SIRET nommé à clé de Luhn fausse (P2-259), TVA
                    // intracommunautaire à clé fausse derrière son libellé
                    // (P2-260).
                    e.type == EntityType.siren) &&
                e.confidence == 0.3 &&
                e.provenance != Provenance.lectureOcr)
            .length +
        // ADELI à clé fausse derrière son libellé (P2-204) : masqué par
        // `AdeliDetector` à confiance 0,6 (inchangée, `LIMITES.md` § 2), donc
        // hors du compte ci-dessus. Le message ne porte jamais la valeur.
        resolved.where(_adeliCleFausse).length;

    // Identifiants relus après des lettres d'OCR (P2-268) : masqués à confiance
    // 0,3, avertissement distinct, jamais la valeur dans le message.
    final ocrCount =
        resolved.where((e) => e.provenance == Provenance.lectureOcr).length;

    // Jetons déjà attribués dans le dossier qui figurent en clair dans ce
    // texte : ils seront remplacés à la restauration (relevé avant tout
    // changement d'état).
    final litteraux = etat.jetonsLitteraux(text);
    final docId = etat.documents++;
    // Sans casse ordinaire, les noms viennent de `NomMinusculesDetector`, qui
    // a ses propres confiances (P2-144).
    final sansCasse = casseDuTexte(text) != CasseTexte.ordinaire;
    for (final entity in resolved) {
      if (entity.type != EntityType.nom) continue;
      // En capitales, `NameDetector` peut aussi avoir rendu la mention.
      final patronyme = (sansCasse
              ? NomMinusculesDetector.patronymeEtabli(
                  entity.value, entity.confidence)
              : null) ??
          NameDetector.patronymeEtabli(entity.value, entity.confidence);
      if (patronyme != null) etat.patronymes.add(patronyme.toLowerCase());
    }
    final utilises = <String>{};
    final buffer = StringBuffer();
    var cursor = 0;

    for (final entity in resolved) {
      buffer.write(text.substring(cursor, entity.start));
      final String token;
      if (entity.type == EntityType.nom) {
        token = _resolveNomToken(entity, etat, docId, text);
      } else {
        final key = _identityKey(entity);
        var existant = etat.tokenByIdentity[key];
        if (existant == null) {
          existant = _freshToken(entity.type, etat.counterByType, text);
          etat.tokenByIdentity[key] = existant;
          etat.attribues.add(existant);
        }
        token = existant;
        if (entity.type != EntityType.secret || restoreSecrets) {
          etat.mapping[token] = entity.value;
        }
      }
      utilises.add(token);
      buffer.write(token);
      cursor = entity.end;
    }
    buffer.write(text.substring(cursor));

    final maskedText = buffer.toString();
    return RedactResult(
      maskedText: maskedText,
      mapping: TableDeCorrespondance.depuis({
        for (final token in utilises)
          if (etat.mapping.containsKey(token)) token: etat.mapping[token]!
      }),
      entities: resolved,
      warnings: [
        if (secretCount > 0)
          'Un secret a été masqué ($secretCount occurrence'
              '${secretCount > 1 ? 's' : ''}) : pensez à le révoquer s\'il a '
              'déjà été partagé ailleurs.',
        if (cleInvalideCount > 0)
          'identifiant à clé invalide masqué : à vérifier'
              '${cleInvalideCount > 1 ? " ($cleInvalideCount occurrences)" : ""}.',
        if (ocrCount > 0)
          "identifiant lu avec des lettres d'OCR masqué : à vérifier"
              '${ocrCount > 1 ? " ($ocrCount occurrences)" : ""}.',
        ..._avertissementNombreDicte(text, resolved),
        ..._avertissementIbanEcarte(text, resolved),
        ..._avertissementsSuiteAbimee(text, resolved),
        if (_sansMajuscule(text))
          _avertissementSansMajuscule
        else if (_casseDePhrase(text, resolved))
          _avertissementCasseDePhrase,
        for (final token in litteraux)
          'Le texte contient en clair $token (littéral), jeton déjà attribué '
              'dans ce dossier : il sera remplacé à la restauration, qui ne '
              'sera pas identique à ce passage du texte.',
      ],
      risque: riskReference == null
          ? null
          : evaluerRisque(riskReference, maskedText),
    );
  }

  /// Signalement non bloquant d'une suite dictée non reconnue (P2-267, option
  /// B de la spec P2-155) : positions et compte seulement, jamais de valeur.
  ///
  /// P2-299 : une suite que la garde du mot voisin dispense du signalement
  /// ordinaire (« code », « digicode »… dans les 100 caractères avant, sans
  /// libellé d'identifiant) reçoit un avertissement distinct, moins pressant :
  /// elle n'est pas masquée, et une garde ne rend jamais une donnée silencieuse.
  static List<String> _avertissementNombreDicte(
      String text, List<DetectedEntity> resolved) {
    final suites = _suitesNonReconnues(text, resolved);
    String passages(List<int> positions) {
      final n = positions.length;
      final liste = positions.take(5).join(', ');
      return '($n passage${n > 1 ? "s" : ""}, position${n > 1 ? "s" : ""} '
          '$liste${n > 5 ? ", …" : ""})';
    }

    return [
      if (suites.signalees.isNotEmpty)
        'nombre dicté non reconnu, relire avant envoi '
            '${passages(suites.signalees)}.',
      if (suites.coupees.isNotEmpty)
        "suite de nombres dictés précédée d'un mot comme « code » : non "
            'masquée, à vérifier ${passages(suites.coupees)}.',
    ];
  }

  /// Avertissement d'un IBAN à clé fausse que la garde `iban_g45` n'a pas
  /// masqué (P2-300, décision du 26 novembre, points 0 et 1) : « FR » + 25
  /// caractères en groupes inhabituels (de trois par exemple) est le plus
  /// souvent un code de pièce, parfois un IBAN recopié autrement. Une garde ne
  /// rend jamais une donnée silencieuse : le passage est signalé « à vérifier »
  /// (compte et positions, jamais la valeur), sauf si une autre entité le
  /// couvre déjà en entier (libellé fort, OCR…).
  static List<String> _avertissementIbanEcarte(
      String text, List<DetectedEntity> resolved) {
    // Rien à chercher sans « FR » : évite de refaire la compaction du texte.
    if (!_contientFr.hasMatch(text)) return const [];
    final positions = [
      for (final e in const IbanCleInvalideDetector().ecartes(text))
        if (!_couvertEnEntier(resolved, e.start, e.end)) e.start
    ];
    if (positions.isEmpty) return const [];
    final n = positions.length;
    return [
      'IBAN à clé fausse écrit en groupes inhabituels, non masqué : à vérifier '
          '($n occurrence${n > 1 ? "s" : ""}, position${n > 1 ? "s" : ""} '
          '${positions.take(5).join(", ")}${n > 5 ? ", …" : ""}).'
    ];
  }

  /// Avertissements des trois gardes de P2-276 (`nir_suitelettre`,
  /// `finess_suitelettre`, `adr_confusables`, P2-304 ; principe du 26 novembre,
  /// point 0) : un candidat suivi d'une suite à lettre de confusion d'OCR est
  /// pris pour un numéro de pièce plus long et n'est pas masqué ; il est
  /// signalé « à vérifier » (type, compte et positions, **jamais la valeur**),
  /// sauf si une autre entité le couvre déjà en entier. Aucun masquage ne
  /// change. Chaque détecteur n'est interrogé que si le texte contient de quoi
  /// le déclencher (un chiffre, ou un code postal suivi d'un mot à chiffres).
  static List<String> _avertissementsSuiteAbimee(
      String text, List<DetectedEntity> resolved) {
    if (!_contientChiffre.hasMatch(text)) return const [];
    String ligne(String quoi, List<int> positions, {bool feminin = false}) {
      final n = positions.length;
      return '$quoi, non masqué${feminin ? "e" : ""} : à vérifier '
          '($n occurrence${n > 1 ? "s" : ""}, position${n > 1 ? "s" : ""} '
          '${positions.take(5).join(", ")}${n > 5 ? ", …" : ""}).';
    }

    List<int> positions(Iterable<({int start, int end})> ecartes) => [
          for (final e in ecartes)
            if (!_couvertEnEntier(resolved, e.start, e.end)) e.start
        ];

    final nir = positions(const NirCleInvalideDetector().ecartes(text));
    final finess = positions(FinessDetector.ecartes(text));
    final adresse = _codePostalPuisMotAChiffres.hasMatch(text)
        ? positions(const AdresseDetector().ecartes(text))
        : const <int>[];
    return [
      if (nir.isNotEmpty)
        ligne("NIR à clé fausse suivi d'une suite à lettres d'OCR", nir),
      if (finess.isNotEmpty)
        ligne("FINESS suivi d'une suite à lettres d'OCR", finess),
      if (adresse.isNotEmpty)
        ligne(
            "adresse dont la commune est faite de chiffres et de lettres d'OCR",
            adresse,
            feminin: true),
    ];
  }

  static final RegExp _contientChiffre = RegExp(r'[0-9]');
  static final RegExp _codePostalPuisMotAChiffres =
      RegExp(r'[0-9]{5}[ \t]+[0-9oOlI]');

  static final RegExp _contientFr = RegExp(r'[Ff][Rr]');

  /// Vrai si l'union des entités de [resolved] (triées, disjointes) couvre
  /// `[debut, fin)` sans trou.
  static bool _couvertEnEntier(
      List<DetectedEntity> resolved, int debut, int fin) {
    var pos = debut;
    for (final e in resolved) {
      if (e.end <= pos) continue;
      if (e.start > pos) return false;
      pos = e.end;
      if (pos >= fin) return true;
    }
    return pos >= fin;
  }

  /// Vrai pour un ADELI de neuf chiffres dont la clé Luhn est fausse, masqué à
  /// confiance 0,6 (P2-204). Un numéro corse (lettre dans la valeur) n'a pas de
  /// règle de clé établie : il n'est pas jugé faux et ne déclenche rien.
  static bool _adeliCleFausse(DetectedEntity e) {
    if (e.type != EntityType.adeli || e.confidence != 0.6) return false;
    final chiffres = e.value.replaceAll(RegExp(r'[\s\u00A0\u202F.\-]'), '');
    if (!RegExp(r'^[0-9]{9}$').hasMatch(chiffres)) return false;
    return !isLuhnValid(chiffres);
  }

  /// Avertissement d'un texte sans aucune majuscule (P2-118). Mesure P2-117 :
  /// les détecteurs de noms, d'adresses et d'établissements reposent sur la
  /// majuscule initiale ; sur un texte en minuscules, leur fuite passe à
  /// 100 %. Sans ce message, le résultat ressemblait à un texte sans donnée
  /// nominative (règle 4 : pas d'échec silencieux).
  ///
  /// Depuis P2-119, P2-120 et P2-131, des détecteurs dédiés rattrapent une
  /// partie de ces entités (fuite globale du corpus réaliste en minuscules :
  /// 0,6 %, adversarial : 13,4 %) : le message ne dit plus « ne sont pas
  /// détectés », ce qui serait faux, mais que la détection y est moins sûre
  /// (P2-133). Il reste nécessaire : patronyme seul, voie sans indice, faux
  /// amis hors liste.
  static const String _avertissementSansMajuscule =
      'Le texte ne contient aucune majuscule : la détection des noms, '
      'adresses et établissements y est moins sûre (un nom de famille seul, '
      'par exemple, peut passer). Relisez le texte avant de l\'envoyer.';

  /// Au moins trois mots de deux lettres ou plus, et aucune lettre
  /// majuscule. En deçà (« ok merci », un numéro seul), le message serait du
  /// bruit ; un texte entièrement en MAJUSCULES n'est pas concerné ici.
  /// Casse de phrase (P2-138) : des majuscules, mais seulement en début de
  /// phrase, de ligne ou dans un sigle ; mêmes détecteurs dédiés qu'un texte
  /// sans majuscule, même réserve.
  static const String _avertissementCasseDePhrase =
      'Les noms propres du texte ne portent pas de majuscule : la détection '
      'des noms, adresses et établissements y est moins sûre (un nom de '
      'famille seul, par exemple, peut passer). Relisez le texte avant de '
      'l\'envoyer.';

  ///
  /// Émis seulement si un nom, une adresse ou un établissement y a été
  /// trouvé : une phrase ordinaire sans nom propre (« Le patient va bien. »)
  /// est aussi en casse de phrase, et l'avertir serait du bruit. Un patronyme
  /// seul, sans civilité ni prénom, peut donc passer sans avertissement ici
  /// (`LIMITES.md` § 5).
  static bool _casseDePhrase(String text, List<DetectedEntity> trouvees) =>
      casseDuTexte(text) == CasseTexte.minuscules &&
      trouvees.any((e) =>
          e.type == EntityType.nom ||
          e.type == EntityType.adresse ||
          e.type == EntityType.etablissement);

  static bool _sansMajuscule(String text) {
    if (text.contains(RegExp(r'\p{Lu}', unicode: true))) return false;
    return RegExp(r'\p{Ll}{2,}', unicode: true).allMatches(text).length >= 3;
  }

  /// Remplace chaque jeton présent dans [text] par sa valeur réelle depuis
  /// [mapping]. Tolère une déformation raisonnable du jeton par le LLM
  /// (espaces superflus, casse) mais ne devine jamais une correspondance
  /// approximative — voir [tolerantTokenPattern].
  static String restore(String text, TableDeCorrespondance table) =>
      _restoreCarte(
          text, {for (final (jeton, valeur) in table.entrees) jeton: valeur});

  /// Comme [restore], mais rend en plus la liste des jetons de forme connue
  /// restés dans le texte après restauration : un jeton sans crochets (le
  /// LLM les a retirés), un numéro que [redact] n'a jamais émis (inventé),
  /// ou un libellé qui n'est pas celui attendu (traduit, mal recopié) — voir
  /// [JetonNonRestaure]. Sondé le 15 novembre (P2-190) : aucun appelant ne
  /// pouvait jusqu'ici s'apercevoir qu'un jeton attendu n'avait pas été
  /// restauré, donc qu'une information pseudonymisée restait affichée telle
  /// quelle — risque de fuite résiduelle silencieuse.
  ///
  /// Ne change rien au texte rendu par [restore] ni à sa signature : cette
  /// fonction l'appelle et analyse seulement son résultat. Un jeton
  /// correctement restauré (y compris `\[NOM_1]`, où la barre oblique est un
  /// séparateur de chemin conservé à dessein, P2-72) n'apparaît jamais dans
  /// la liste rendue.
  ///
  /// La liste ne contient jamais la valeur réelle : seulement le type et le
  /// numéro tels que vus dans le texte (jamais interprétés comme un entier,
  /// un jeton inventé peut porter n'importe quoi). Une détection par forme
  /// reste approximative par nature : un texte contenant par coïncidence un
  /// segment `[QUELQUE_CHOSE_3]` sans lien avec Écluse serait aussi signalé
  /// (voir `packages/ecluse_redact/README.md`).
  static (String, List<JetonNonRestaure>) restoreAvecRapport(
    String text,
    TableDeCorrespondance table,
  ) {
    final texteRestaure = restore(text, table);
    return (texteRestaure, _jetonsNonRestaures(texteRestaure));
  }
}

/// Les détecteurs par défaut, avec un [NameDetector] amorcé par [patronymes]
/// (établis par les pièces du dossier) et [fournis] (liste de l'application,
/// P2-243). Seuls les patronymes établis amorcent `NomMinusculesDetector` : la
/// liste fournie n'y entre pas (casse de titre et capitales seulement).
List<Detector> _detecteursAvecPatronymes(Set<String> patronymes,
        [Set<String> fournis = const {},
        Set<String> formesVerbales = const {}]) =>
    [
      for (final detecteur in Ecluse.defaultDetectors)
        if (detecteur is LegacyDetectorAdapter && detecteur.name == 'nom')
          LegacyDetectorAdapter(
            NameDetector(knownSurnames: {...patronymes, ...fournis}),
            DetectorTier.reference,
            name: 'nom',
          )
        else if (detecteur is LegacyDetectorAdapter &&
            detecteur.name == 'nom_minuscules')
          LegacyDetectorAdapter(
            NomMinusculesDetector(
              knownSurnames: Set.of(patronymes),
              formesVerbales: formesVerbales,
            ),
            DetectorTier.reference,
            name: 'nom_minuscules',
          )
        else
          detecteur,
    ];

/// Levée par `Ecluse.redact(refuseSecrets: true)` quand le texte contient au
/// moins un secret. Le message ne reproduit jamais le secret.
final class SecretsRefusedException implements Exception {
  const SecretsRefusedException(this.count);

  /// Nombre d'occurrences de secrets détectées.
  final int count;

  @override
  String toString() => 'SecretsRefusedException: $count secret(s) détecté(s) ; '
      'envoi refusé (mode strict).';
}
