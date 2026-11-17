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
part 'normalisation_du_texte.dart';
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
    LegacyDetectorAdapter(IbanDetector(), DetectorTier.structural,
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
  }) {
    final options = _Options(detectors, restoreSecrets, refuseSecrets,
        riskReference, journal, _supplementaires(maladiesRares, prenomsInsee));
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
  }) {
    final extra = _supplementaires(maladiesRares, prenomsInsee);
    if (dossier == null) return _detecter(text, _Etat(), detectors, extra);
    return dossier._serialise(() {
      final etat = dossier._etat;
      if (etat == null) throw const DossierFermeException();
      return _detecter(text, etat, detectors, extra);
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
  ]) async {
    // Dans un dossier, les patronymes établis par les documents précédents
    // amorcent la détection de noms (P2-14) ; des détecteurs fournis par
    // l'appelant ne sont jamais modifiés.
    final base = detectors ??
        (etat.patronymes.isEmpty
            ? defaultDetectors
            : _detecteursAvecPatronymes(etat.patronymes));
    final engine = EcluseEngine(
        supplementaires.isEmpty ? base : [...base, ...supplementaires]);
    final (vue, positions) = _vueDeDetection(text);
    final entites = (await engine.run(vue)).entities;
    // Les positions et la valeur sont ramenées au texte d'origine : le texte
    // n'est jamais réécrit, la table garde la valeur exacte (invariant 3).
    final surLeTexte = identical(vue, text)
        ? entites
        : [
            for (final e in entites)
              () {
                final debut = positions == null ? e.start : positions[e.start];
                var fin = positions == null ? e.end : positions[e.end - 1] + 1;
                // Les diacritiques qui suivent la dernière lettre en font
                // partie.
                while (
                    fin < text.length && _estCombinant(text.codeUnitAt(fin))) {
                  fin++;
                }
                return DetectedEntity(
                  type: e.type,
                  start: debut,
                  end: fin,
                  value: text.substring(debut, fin),
                  confidence: e.confidence,
                  tier: e.tier,
                );
              }()
          ];
    // P2-188 : identifiant à clé invalide annoncé par un libellé fort, sur
    // [text] directement — jamais sur [vue] (voir le commentaire de
    // `defaultDetectors`).
    final cleInvalide = const IdentifiantCleInvalideDetector().detect(text);
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
        ),
    ]);
  }

  static Future<RedactResult> _redact(
    String text,
    _Etat etat,
    _Options options,
  ) async {
    final resolved =
        await _detecter(text, etat, options.detectors, options.supplementaires);

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
    // `IdentifiantCleInvalideDetector` parmi les types nir/iban/rpps.
    final cleInvalideCount = resolved
            .where((e) =>
                (e.type == EntityType.nir ||
                    e.type == EntityType.iban ||
                    e.type == EntityType.rpps ||
                    e.type == EntityType.adeli) &&
                e.confidence == 0.3)
            .length +
        // ADELI à clé fausse derrière son libellé (P2-204) : masqué par
        // `AdeliDetector` à confiance 0,6 (inchangée, `LIMITES.md` § 2), donc
        // hors du compte ci-dessus. Le message ne porte jamais la valeur.
        resolved.where(_adeliCleFausse).length;

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

  static String _restoreCarte(String text, Map<String, String> mapping) {
    // Un jeton ne peut se trouver que dans un segment `[...]` sans crochet. Si
    // aucune valeur ne contient de crochet ni de barre oblique inversée, les
    // remplacements ne peuvent ni en créer ni en défaire : un seul parcours des
    // segments donne le même résultat que les remplacements successifs, sans
    // le coût « jetons × taille du texte » (P2-64). Sinon, ancien parcours.
    final clesDeJetons = {for (final k in mapping.keys) _cleLache(k)};
    if (mapping.values.any((v) => _peutRecreerUnJeton(v, clesDeJetons))) {
      return _restoreSequentiel(text, mapping);
    }
    final parNom = <String, List<MapEntry<String, RegExp>>>{};
    for (final entry in mapping.entries) {
      parNom
          .putIfAbsent(_cleLache(entry.key), () => [])
          .add(MapEntry(entry.key, tolerantTokenPattern(entry.key)));
    }
    bool exact(RegExp motif, String s) {
      final m = motif.matchAsPrefix(s);
      return m != null && m.end == s.length;
    }

    return text.replaceAllMapped(_segment, (m) {
      final segment = m[0]!;
      for (final candidat in [
        segment,
        if (segment.startsWith('\\')) segment.substring(1),
      ]) {
        for (final c in parNom[_cleLache(candidat)] ??
            const <MapEntry<String, RegExp>>[]) {
          if (exact(c.value, candidat)) {
            return segment.substring(0, segment.length - candidat.length) +
                mapping[c.key]!;
          }
        }
      }
      return segment;
    });
  }

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

  /// Segment entre crochets, forme générique `[<libellé>_<numéro>]` —
  /// n'importe quel libellé, pas seulement ceux qu'[entityTypeLabel] connaît
  /// (un libellé traduit comme `NAME` doit aussi être signalé).
  static final RegExp _formeJetonCrochets =
      RegExp(r'\\?\[([^\[\]]*?)_([0-9]+)\]');

  /// Occurrence sans crochets d'un libellé *connu* suivi de `_<numéro>`, aux
  /// frontières du mot. Restreint aux libellés d'[entityTypeLabel] (et non à
  /// toute suite de lettres) : sans crochets, rien ne distingue plus un
  /// jeton dépouillé d'un mot ordinaire, donc on ne cherche que les formes
  /// qu'Écluse aurait pu réellement émettre.
  static final RegExp _formeJetonSansCrochets = RegExp(
    '(?<![\\[\\w])(?:${EntityType.values.map((t) => RegExp.escape(entityTypeLabel(t))).join('|')})_[0-9]+(?!\\w)',
  );

  static List<JetonNonRestaure> _jetonsNonRestaures(String texteRestaure) {
    final trouves = <JetonNonRestaure>[];
    for (final m in _formeJetonCrochets.allMatches(texteRestaure)) {
      trouves.add(JetonNonRestaure(m[1]!, m[2]!));
    }
    for (final m in _formeJetonSansCrochets.allMatches(texteRestaure)) {
      final sansCrochets = m[0]!;
      final coupure = sansCrochets.lastIndexOf('_');
      trouves.add(JetonNonRestaure(
        sansCrochets.substring(0, coupure),
        sansCrochets.substring(coupure + 1),
      ));
    }
    return trouves;
  }

  static final RegExp _segment = RegExp(r'\\?\[[^\[\]]*\]');

  /// Une valeur ne peut recréer ni défaire un jeton que si elle contient une
  /// barre oblique inversée, un crochet isolé (qui se combinerait avec le texte
  /// voisin) ou un segment `[...]` que [tolerantTokenPattern] confondrait avec
  /// un jeton. Un courriel obfusqué `jean[at]example.fr` n'en est pas un : sans
  /// cette précision, il imposait l'ancien parcours (jetons × texte, P2-85).
  static bool _peutRecreerUnJeton(String valeur, Set<String> clesDeJetons) {
    if (valeur.contains('\\')) return true;
    if (!valeur.contains('[') && !valeur.contains(']')) return false;
    final sansSegments = valeur.replaceAll(_segment, '');
    if (sansSegments.contains('[') || sansSegments.contains(']')) return true;
    return _segment
        .allMatches(valeur)
        .any((m) => clesDeJetons.contains(_cleLache(m[0]!)));
  }

  /// Clé de rapprochement large : tout ce que [tolerantTokenPattern] tolère en
  /// plus du jeton (casse, blancs, soulignements, barres obliques inversées,
  /// crochets) est retiré. Deux textes que le motif apparie ont la même clé ;
  /// l'inverse est revérifié avec le motif exact.
  static String _cleLache(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_\\\[\]]'), '');

  static String _restoreSequentiel(String text, Map<String, String> mapping) {
    var result = text;
    for (final entry in mapping.entries) {
      result = result.replaceAll(tolerantTokenPattern(entry.key), entry.value);
    }
    return result;
  }
}

/// Jeton de forme connue (`[TYPE_N]` ou `TYPE_N`) resté dans le texte après
/// [Ecluse.restoreAvecRapport] : ni retrouvé dans la table de
/// correspondance, ni reconnu comme jeton correctement échappé. Ne porte
/// jamais la valeur réelle attendue à cet endroit — seulement ce qui permet
/// de diagnostiquer sans réexposer de contenu (P2-190).
final class JetonNonRestaure {
  /// Partie avant le dernier `_`, telle que vue dans le texte (`NOM`,
  /// `DATE_NAISSANCE`, ou un libellé que le LLM a traduit comme `NAME`).
  final String type;

  /// Partie après le dernier `_`, telle que vue dans le texte — jamais
  /// interprétée comme un entier : un jeton inventé ou déformé peut porter
  /// n'importe quoi à cet endroit.
  final String numero;

  const JetonNonRestaure(this.type, this.numero);

  @override
  String toString() => '${type}_$numero';

  @override
  bool operator ==(Object other) =>
      other is JetonNonRestaure && other.type == type && other.numero == numero;

  @override
  int get hashCode => Object.hash(type, numero);
}

/// Les détecteurs par défaut, avec un [NameDetector] amorcé par [patronymes].
List<Detector> _detecteursAvecPatronymes(Set<String> patronymes) => [
      for (final detecteur in Ecluse.defaultDetectors)
        if (detecteur is LegacyDetectorAdapter && detecteur.name == 'nom')
          LegacyDetectorAdapter(
            NameDetector(knownSurnames: Set.of(patronymes)),
            DetectorTier.reference,
            name: 'nom',
          )
        else if (detecteur is LegacyDetectorAdapter &&
            detecteur.name == 'nom_minuscules')
          LegacyDetectorAdapter(
            NomMinusculesDetector(knownSurnames: Set.of(patronymes)),
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
