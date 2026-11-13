import 'dart:async';

import 'package:ecluse_audit/ecluse_audit.dart' show AuditChain, JournalAudit;
import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_reference/ecluse_reference.dart'
    show EcluseReference, RareDiseaseCatalog;

import 'heuristics/adresse_detector.dart';
import 'heuristics/date_naissance_detector.dart';
import 'heuristics/email_detector.dart';
import 'heuristics/etablissement_detector.dart';
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
import 'tokenizer.dart';

part 'apercu.dart';
part 'dossier.dart';

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
  static const String versionMoteur = 'ecluse_redact 0.1.0';

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
    if (identical(vue, text)) return entites;
    // Les positions et la valeur sont ramenées au texte d'origine : le texte
    // n'est jamais réécrit, la table garde la valeur exacte (invariant 3).
    return [
      for (final e in entites)
        () {
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
          );
        }()
    ];
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
      mapping: Map.unmodifiable({
        for (final token in utilises)
          if (etat.mapping.containsKey(token)) token: etat.mapping[token]!
      }),
      entities: resolved,
      warnings: [
        if (secretCount > 0)
          'Un secret a été masqué ($secretCount occurrence'
              '${secretCount > 1 ? 's' : ''}) : pensez à le révoquer s\'il a '
              'déjà été partagé ailleurs.',
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
  static String restore(String text, Map<String, String> mapping) {
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

/// Caractères sans largeur ou de contrôle bidirectionnel qu'un copier-coller
/// glisse dans un identifiant (U+200B espace sans chasse, U+200C/D, U+2060,
/// U+FEFF, trait d'union conditionnel, marques de direction).
final RegExp _invisibles = RegExp(
    '[\u00AD\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF'
    '\u0300-\u036F\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]');

bool _estInvisible(int c) =>
    c == 0x00AD ||
    c == 0x180E ||
    (c >= 0x200B && c <= 0x200F) ||
    (c >= 0x202A && c <= 0x202E) ||
    (c >= 0x2060 && c <= 0x2064) ||
    (c >= 0x2066 && c <= 0x2069) ||
    c == 0xFEFF ||
    _estCombinant(c);

/// Diacritique combinant (accent d'un nom écrit en forme décomposée, NFD) : retiré
/// de la vue des détecteurs, mais rattaché à la lettre qui le porte quand une
/// entité est ramenée au texte d'origine (P2-32).
bool _estCombinant(int c) =>
    (c >= 0x0300 && c <= 0x036F) ||
    (c >= 0x1DC0 && c <= 0x1DFF) ||
    (c >= 0x20D0 && c <= 0x20FF) ||
    (c >= 0xFE20 && c <= 0xFE2F);

/// Espaces Unicode autres que U+0020 et U+00A0 (déjà acceptés par les
/// détecteurs).
final RegExp _espacesUnicode =
    RegExp('[\u1680\u2000-\u200A\u202F\u205F\u3000]');

/// Tirets typographiques que le traitement de texte substitue au trait d'union.
final RegExp _tiretsUnicode = RegExp('[\u2010-\u2013\u2212\uFE63\uFF0D]');

/// Formes pleine chasse (U+FF01 à U+FF5E), chiffres arabes orientaux, barres de
/// fraction et de division : équivalents ASCII d'un chiffre, d'une lettre ou d'un
/// signe d'identifiant.
final RegExp _autresFormes =
    RegExp('[\\uFF01-\\uFF5E\\u0660-\\u0669\\u06F0-\\u06F9\\u2044\\u2215]');

/// Équivalent ASCII de [c] (même longueur : une unité UTF-16 pour une unité).
int _versAscii(int c) {
  if (c >= 0xFF01 && c <= 0xFF5E) return c - 0xFEE0;
  if (c >= 0x0660 && c <= 0x0669) return 0x30 + (c - 0x0660);
  if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + (c - 0x06F0);
  if (c == 0x2044 || c == 0x2215) return 0x2F; // '/'
  return c;
}

/// Texte sur lequel tournent les détecteurs (P2-29) : espaces Unicode ramenés à
/// U+0020 et tirets typographiques à `-` (même longueur), caractères invisibles
/// retirés. Renvoie aussi, si des caractères ont été retirés, la position
/// d'origine de chaque caractère conservé. Sans caractère concerné, le texte
/// d'origine lui-même (`identical`) : la détection est alors celle d'avant.
(String, List<int>?) _vueDeDetection(String text) {
  var vue = text;
  if (_espacesUnicode.hasMatch(vue)) {
    vue = vue.replaceAll(_espacesUnicode, ' ');
  }
  if (_tiretsUnicode.hasMatch(vue)) {
    vue = vue.replaceAll(_tiretsUnicode, '-');
  }
  if (_autresFormes.hasMatch(vue)) {
    vue = String.fromCharCodes([for (final c in vue.codeUnits) _versAscii(c)]);
  }
  final coupures = _coupuresDeLigne.allMatches(vue).toList();
  // Fins de ligne à l'intérieur d'un nom d'établissement ou de commune
  // (P2-173) : une espace à la place, dans la vue seulement.
  final nomsCoupes = coupuresDeNom(vue);
  final cles = _cleNommee.allMatches(vue).toList();
  final decorations = _decorations.allMatches(vue).toList();
  final balises = vue.contains('<') || vue.contains('&nbsp;')
      ? _balisesStructure.allMatches(vue).toList()
      : <RegExpMatch>[];
  if (coupures.isEmpty &&
      nomsCoupes.isEmpty &&
      cles.isEmpty &&
      decorations.isEmpty &&
      balises.isEmpty &&
      !_invisibles.hasMatch(vue)) {
    return (vue, null);
  }
  // Les caractères d'une coupure sont retirés comme les invisibles, sauf un
  // espace conservé quand la coupure suit un chiffre.
  final retires = <int>{};
  final unites = vue.codeUnits.toList();
  for (final m in coupures) {
    // Après un séparateur (`12-` / `34`), la coupure disparaît ; après un
    // chiffre, elle devient une espace.
    // Une majuscule de groupe (P2-152) compte comme un chiffre.
    final avant = vue.codeUnitAt(m.start - 1);
    final apresChiffre =
        (avant >= 0x30 && avant <= 0x39) || (avant >= 0x41 && avant <= 0x5A);
    var debut = m.start;
    if (apresChiffre) {
      unites[m.start] = 0x20;
      debut++;
    }
    for (var i = debut; i < m.end; i++) {
      retires.add(i);
    }
  }
  // Nom coupé (P2-173) : la fin de ligne et ses blancs deviennent une seule
  // espace. Une coupure d'identifiant au même endroit prime (les deux listes
  // sont dans l'ordre du texte : un seul parcours).
  var k = 0;
  for (final (debut, fin) in nomsCoupes) {
    while (k < coupures.length && coupures[k].end <= debut) {
      k++;
    }
    if (k < coupures.length && coupures[k].start < fin) continue;
    unites[debut] = 0x20;
    for (var i = debut + 1; i < fin; i++) {
      retires.add(i);
    }
  }
  // « 2550814168025 clé 38 » (P2-42) : le mot et ses marques disparaissent,
  // une espace subsiste entre le numéro et la clé.
  for (final m in cles) {
    unites[m.start] = 0x20;
    for (var i = m.start + 1; i < m.end; i++) {
      retires.add(i);
    }
  }
  // Marques de gras, d'italique et de code (P2-51) : retirées de la vue.
  for (final m in decorations) {
    for (var i = m.start; i < m.end; i++) {
      retires.add(i);
    }
  }
  // Balises de tableau et de bloc HTML (P2-63) : retirées, un séparateur subsiste.
  // Entre deux cellules : U+001F (séparateur d'unités), lu comme `:` par les
  // étiquettes et comme séparateur de colonnes par le CSV ; U+001E entre deux
  // cellules d'en-tête (`<th>`), séparateur de colonnes seulement, pour qu'un
  // en-tête « Nom, Prénom, Service » ne se lise jamais « Prénom : Service ».
  // Saut de ligne entre deux blocs, espace pour `&nbsp;`. Des balises de bloc
  // consécutives ne donnent qu'un saut de ligne.
  var finPrecedente = -1;
  var precedenteLigne = false;
  for (final m in balises) {
    final balise = m.group(0)!.toLowerCase();
    int separateur;
    if (balise == '&nbsp;') {
      separateur = 0x20;
    } else if (m.group(1) != null) {
      separateur = _finitParDeuxPoints(vue, m.start)
          ? 0x20
          : (balise == '</th>' && m.group(1) == 'th' ? 0x1E : 0x1F);
    } else if (balise.startsWith('</t') && balise.length == 5) {
      separateur = 0x20; // dernière cellule d'une ligne
    } else if (RegExp(r'^<t[dh][\s>]').hasMatch(balise)) {
      for (var i = m.start; i < m.end; i++) {
        retires.add(i);
      }
      continue; // ouverture de cellule : disparaît
    } else {
      separateur = 0x0A; // bloc, ligne de tableau, saut de ligne
    }
    final contigu = finPrecedente == m.start;
    if (separateur == 0x0A &&
        ((precedenteLigne && contigu) ||
            _saut(vue, m.start - 1, -1) ||
            _saut(vue, m.end, 1))) {
      for (var i = m.start; i < m.end; i++) {
        retires.add(i);
      }
    } else {
      unites[m.start] = separateur;
      for (var i = m.start + 1; i < m.end; i++) {
        retires.add(i);
      }
    }
    finPrecedente = m.end;
    precedenteLigne = separateur == 0x0A;
  }
  final sb = StringBuffer();
  final positions = <int>[];
  for (var i = 0; i < unites.length; i++) {
    final c = unites[i];
    if (retires.contains(i) || _estInvisible(c)) continue;
    sb.writeCharCode(c);
    positions.add(i);
  }
  return (sb.toString(), positions);
}

/// Balises HTML de structure (P2-63) : cellules et lignes de tableau, blocs,
/// listes, titres, sauts de ligne, et `&nbsp;`. Seules les balises sans attribut,
/// ou dont les attributs sont de pure mise en forme (`class`, `style`, `colspan`,
/// `width`…), sont concernées : un attribut libre (`title`, `href`, `alt`) peut
/// porter une donnée personnelle et rester visible aux détecteurs. Le premier
/// groupe capture la cellule qui suit une fin de cellule (`</td>` puis `<td>`).
final RegExp _balisesStructure = RegExp(
  r'</t[dh]>(?=[ \t\r\n]*<(t[dh])[\s>])'
  r'|</?(?:t[dh]|tr|table|thead|tbody|tfoot|p|div|li|ul|ol|h[1-6])'
  r'(?:\s+(?:class|style|colspan|rowspan|width|height|align|valign|bgcolor|id|'
  r'border)\s*=\s*(?:"[^"<>]*"|\u0027[^\u0027<>]*\u0027|[^\s<>"\u0027]*))*\s*/?>'
  r'|<br\s*/?>'
  r'|&nbsp;',
  caseSensitive: false,
);

/// Vrai si, en partant de [i] et en allant dans le sens [pas], le premier
/// caractère qui n'est ni une espace ni une tabulation est un saut de ligne réel :
/// une balise de bloc voisine d'un vrai saut de ligne n'en ajoute pas un second
/// (une ligne vide mettrait fin à un tableau).
bool _saut(String vue, int i, int pas) {
  while (i >= 0 && i < vue.length && (vue[i] == ' ' || vue[i] == '\t')) {
    i += pas;
  }
  return i >= 0 && i < vue.length && (vue[i] == '\n' || vue[i] == '\r');
}

bool _finitParDeuxPoints(String vue, int fin) {
  var i = fin - 1;
  while (i >= 0 && (vue[i] == ' ' || vue[i] == '\t')) {
    i--;
  }
  return i >= 0 && vue[i] == ':';
}

/// Fin de ligne entre deux groupes d'un identifiant (P2-38) : après un chiffre
/// ou l'un de `/ . -`, avant un chiffre, avec les blancs de part et d'autre.
/// Volontairement étroite : un saut de ligne ordinaire (texte, nom, adresse)
/// n'est pas touché, donc aucun span de texte ne traverse une ligne.
///
/// P2-152 : la coupure est aussi admise après **une** majuscule précédée d'un
/// chiffre (lettre de compte d'un IBAN « 461K⏎4056 », « 2A⏎073 » d'un NIR
/// corse), même tolérance que `DigitCompaction`, et les blancs autour de la
/// fin de ligne comprennent les espaces insécables et typographiques (un
/// export bureautique coupe « 7460⏎\u00A08432 »). Ce qui suit doit être un
/// chiffre, ou (P2-158) **une** majuscule suivie d'un chiffre : un groupe de
/// compte d'IBAN peut commencer par une lettre (« …0270⏎D932… »). Les
/// contre-exemples (« Salle 4⏎A2 fermée », « Vol 12⏎B7 porte ») ne sont pas
/// détectés après neutralisation : la validation de l'identifiant (clé,
/// forme) reste le garde-fou contre la fusion de deux lignes sans rapport.
final RegExp _coupuresDeLigne = RegExp(r'(?<=[0-9/.\-]|[0-9][A-Z])'
    '[$_blancsDeLigne]*\\r?\\n[$_blancsDeLigne]*'
    r'(?=[0-9]|[A-Z][0-9])');

/// Blancs horizontaux admis autour d'une fin de ligne d'identifiant : ceux de
/// `DigitCompaction` (jamais le saut de ligne lui-même).
const String _blancsDeLigne = r' \t\u00A0\u2000-\u200A\u202F\u3000';

/// Marques de mise en forme Markdown ou HTML autour d'une étiquette (P2-51) :
/// `**Nom :** Quenelle`, `*Nom* : Quenelle`, `` `Nom` : …``, `<b>Nom :</b>`.
/// Une suite de marques (`*`, `_`, `` ` ``, p. ex. `**` ou `__`) d'ouverture n'est
/// retirée que devant un mot et hors d'un mot ; une suite de fermeture seulement
/// après un mot ou une ponctuation et hors d'un mot. Un soulignement ou une étoile
/// **à l'intérieur** d'un mot (`jean_dupont`, `[NOM_1]`) et une opération
/// (`3 * 4`) ne sont jamais touchés. Classe de caractères plutôt que des
/// alternatives `\*\*|\*` répétées : ces dernières se recouvrent et donnaient un
/// retour arrière exponentiel (50 000 étoiles : 51 s).
final RegExp _decorations = RegExp(r'(?<![\wÀ-ÿ*_`])[*_`]+(?=[\wÀ-ÿ])'
    r'|(?<=[\wÀ-ÿ.,;:!?)\]])[*_`]+(?![\wÀ-ÿ*_`])'
    r'|</?(?:b|i|u|em|strong)>');

/// Clé de contrôle nommée à part (P2-42) : après un chiffre, « clé », « cle » ou
/// « clef » (avec `(` et `:` facultatifs) puis deux chiffres. Neutralisée dans la
/// vue de détection seulement : le NIR n'est reconnu que si la clé est juste.
final RegExp _cleNommee = RegExp(
    r'(?<=[0-9])[ \t]*(?:\([ \t]*)?(?:[Cc]l[ée]f?|CL[ÉE]F?)[ \t]*(?::[ \t]*)?'
    r'(?=[0-9]{2}(?![0-9]))');

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

/// Clé d'identité pour les types **autres que `nom`** : l'identité est la
/// valeur exacte. Deux adresses ou deux téléphones qui se ressemblent ne
/// doivent jamais être fusionnés sur une simple heuristique. Les noms
/// suivent une résolution différente, plus riche — voir
/// [_resolveNomToken].
String _identityKey(DetectedEntity entity) =>
    '${entity.type.name}:${entity.value}';

/// Ensemble de segments (minuscules) déjà associés à un jeton `nom`.
final class _NomIdentity {
  _NomIdentity(this.segments, this.token, this.gender, this.doc);

  /// Dernier document (numéro d'appel dans le dossier) où l'identité a été
  /// vue : la règle d'inclusion ne s'applique qu'au sein d'un document.
  int doc;

  Set<String> segments;
  final String token;

  /// `'m'`, `'f'` ou `null` : sexe indiqué par la civilité qui précède la
  /// mention (« M. », « Mme »…), quand il y en a une.
  String? gender;
}

/// Sexe indiqué par la civilité qui précède immédiatement [start] dans
/// [text], ou `null`. Sert à ne pas fusionner « M. Jean Dupont » et
/// « Mme Dupont » (un couple) sur leur seul patronyme commun.
String? _genderBefore(String text, int start) {
  final head = text.substring(start < 20 ? 0 : start - 20, start);
  // Sans tenir compte de la casse : en minuscules ou en capitales, la
  // civilité reste hors de la mention (P2-145) et doit encore séparer un
  // couple.
  if (RegExp(r'(?:^|[^\wÀ-ÿ])(?:M\.|Mr\.?|Monsieur)[ \t\u00A0\u202F]*$',
          caseSensitive: false)
      .hasMatch(head)) {
    return 'm';
  }
  if (RegExp(
          r'(?:^|[^\wÀ-ÿ])(?:Mme|Mlle|Mrs\.?|Madame|Mademoiselle)'
          r'[ \t\u00A0\u202F]*$',
          caseSensitive: false)
      .hasMatch(head)) {
    return 'f';
  }
  return null;
}

/// Segments (minuscules, sans doublons) d'une mention de nom — insensible
/// à l'ordre et à la casse : « Dubreuil Thomas » et « Thomas Dubreuil »
/// produisent le même ensemble.
///
/// Une civilité de genre **en tête** (« m. », « mme ») n'est pas un segment :
/// `NomMinusculesDetector` l'inclut dans la mention, `NameDetector` la laisse
/// en clair ; sans ce retrait, « m. antoine lacombe » et « M. Antoine
/// Lacombe » (même personne, casses différentes) recevaient deux jetons
/// (P2-145). Le sexe qu'elle indique est rendu par [_genreEnTete].
Set<String> _nameSegments(String value) {
  final mots = value
      .toLowerCase()
      .replaceAll(',', ' ')
      .split(RegExp(r'\s+'))
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (mots.length > 1 && _civilitesGenre.containsKey(mots.first)) {
    mots.removeAt(0);
  }
  return mots.toSet();
}

/// Civilités de genre (minuscules, point compris) et sexe indiqué.
const Map<String, String> _civilitesGenre = {
  'm.': 'm', 'm': 'm', 'mr': 'm', 'mr.': 'm', 'monsieur': 'm', //
  'mme': 'f', 'mme.': 'f', 'mlle': 'f', 'mlle.': 'f', 'madame': 'f', //
  'mademoiselle': 'f',
};

/// Sexe indiqué par une civilité de genre en tête de [value], ou `null`.
String? _genreEnTete(String value) {
  final premier = value.trimLeft().split(RegExp(r'\s+')).first.toLowerCase();
  return _civilitesGenre[premier];
}

/// Résout le jeton d'une entité `nom`, en fusionnant les mentions
/// **partielles** avec une identité déjà établie dans le même document —
/// sans quoi une re-mention par le seul patronyme (« Dr Costa » après
/// « Dr Nadia Costa »), par initiale + patronyme (« S. Reynaud » après
/// « Mme Sandra Reynaud ») ou à ordre nom/prénom inversé (« Thomas
/// Dubreuil » après « Dubreuil Thomas ») recevrait à tort un jeton séparé,
/// laissant croire au LLM qu'il s'agit d'une personne différente.
///
/// Règle : les segments de la nouvelle mention et ceux d'une identité déjà
/// connue sont comparés par **inclusion** (l'un est un sous-ensemble de
/// l'autre), pas par égalité stricte — c'est ce qui permet à un patronyme
/// seul (« Costa », un segment) de rejoindre une identité plus complète
/// (« Nadia Costa », deux segments), tout en refusant de fusionner deux
/// mentions dont les segments se contredisent (« Morel Hélène » ne
/// contient pas « Antoine » : ne fusionne jamais avec « MOREL Antoine »,
/// même patronyme partagé). Quand une mention plus complète rejoint une
/// identité déjà établie sous une forme partielle, l'identité est mise à
/// jour vers la forme la plus riche, pour que les mentions suivantes
/// continuent de s'y rattacher correctement.
///
/// **Ambiguïté assumée** : si la mention correspond à *plusieurs*
/// identités déjà établies et distinctes (deux personnes homonymes déjà
/// identifiées séparément dans le document), aucune fusion n'est risquée —
/// mieux vaut un jeton supplémentaire qu'une mauvaise attribution
/// d'identité.
String _resolveNomToken(
  DetectedEntity entity,
  _Etat etat,
  int docId,
  String text,
) {
  final segments = _nameSegments(entity.value);
  final gender =
      _genderBefore(text, entity.start) ?? _genreEnTete(entity.value);
  // Deux civilités de sexe différent désignent deux personnes, même avec un
  // patronyme commun (un couple).
  bool compatible(_NomIdentity identity) =>
      !(gender != null && identity.gender != null && gender != identity.gender);

  // Seules les identités qui partagent au moins un segment avec la mention
  // peuvent correspondre (les deux sens de l'inclusion l'exigent) : l'index
  // évite de comparer chaque mention à toutes les identités du dossier (P2-64).
  final matches = etat
      .candidats(segments)
      .where(
        (identity) =>
            (etat.regle == RegleNoms.inclusion || identity.doc == docId) &&
            compatible(identity) &&
            (segments.every(identity.segments.contains) ||
                identity.segments.every(segments.contains)),
      )
      .toList();

  if (matches.length == 1) {
    final identity = matches.single;
    identity.doc = docId;
    identity.gender ??= gender;
    if (segments.length > identity.segments.length) {
      // Forme la plus complète rencontrée : la carte de restauration la
      // reprend (« Dr Nadia Costa » plutôt que le « Costa » de la première
      // mention), comme le promet `LIMITES.md` §5.3 — sans cela, les
      // mentions complètes perdaient prénom et titre à la restauration.
      final anciens = identity.segments;
      identity.segments = segments;
      etat.reindexe(identity, anciens);
      etat.mapping[identity.token] = entity.value;
    }
    return identity.token;
  }

  // Entre documents d'un dossier (N1, `agent/specs/P2-05.md` § 5) : seule une
  // identité complète identique (deux segments au moins) rejoint une identité
  // d'un document précédent ; une mention partielle reçoit un nouveau jeton.
  if (matches.isEmpty &&
      etat.regle == RegleNoms.identiteComplete &&
      segments.length >= 2) {
    final anterieures = etat
        .candidats(segments)
        .where((identity) =>
            identity.doc != docId &&
            compatible(identity) &&
            identity.segments.length == segments.length &&
            segments.every(identity.segments.contains))
        .toList();
    if (anterieures.length == 1) {
      final identity = anterieures.single;
      identity.doc = docId;
      identity.gender ??= gender;
      return identity.token;
    }
  }

  final token = _freshToken(EntityType.nom, etat.counterByType, text);
  etat.attribues.add(token);
  etat.mapping[token] = entity.value;
  etat.ajouteIdentite(_NomIdentity(segments, token, gender, docId));
  return token;
}

/// Prochain jeton libre pour [type] : saute tout numéro dont le jeton figure
/// déjà dans le texte d'origine (comparaison tolérante, la même que celle de
/// la restauration). Sans cela, un texte qui contient `[NOM_1]` serait
/// confondu avec un jeton généré et `restore` réinjecterait la valeur d'une
/// personne à la place du texte de l'utilisateur.
String _freshToken(
  EntityType type,
  Map<EntityType, int> counterByType,
  String text,
) {
  var next = counterByType[type] ?? 0;
  String token;
  do {
    next++;
    token = '[${entityTypeLabel(type)}_$next]';
  } while (tolerantTokenPattern(token).hasMatch(_zoneCrochets(text)));
  counterByType[type] = next;
  return token;
}

/// Dernier texte examiné et ses segments `[...]` sans crochet intérieur, joints
/// par un saut de ligne. Un motif de jeton commence par `[` et finit par `]` sans
/// autre crochet : il ne peut se trouver que dans un tel segment. Relever ces
/// segments une fois par texte, au lieu d'appliquer le motif au texte entier pour
/// chaque nouveau jeton, évite un coût quadratique (P2-64).
String? _texteExamine;
String _zoneExaminee = '';

String _zoneCrochets(String text) {
  if (!identical(text, _texteExamine)) {
    _texteExamine = text;
    _zoneExaminee = [
      for (final m in RegExp(r'\[[^\[\]]*\]').allMatches(text)) m[0]!
    ].join('\n');
  }
  return _zoneExaminee;
}

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

/// Options d'un appel à [Ecluse.redact], regroupées pour ne pas les passer
/// une à une entre les étapes.
final class _Options {
  const _Options(this.detectors, this.restoreSecrets, this.refuseSecrets,
      this.riskReference, this.journal, this.supplementaires);

  final List<Detector>? detectors;
  final bool restoreSecrets;
  final bool refuseSecrets;
  final EcluseReference? riskReference;
  final JournalAudit? journal;
  final List<Detector> supplementaires;
}

/// État de masquage : jetons attribués, identités de noms, compteurs et carte.
/// Un appel sans [Dossier] en crée un neuf (comportement historique) ; un
/// [Dossier] conserve le sien entre les appels.
final class _Etat {
  _Etat([this.regle = RegleNoms.identiteComplete]);

  /// Règle de rapprochement des noms entre les documents du dossier.
  final RegleNoms regle;

  final Map<String, String> mapping = {};
  final Map<String, String> tokenByIdentity = {};
  final List<_NomIdentity> nomIdentities = [];

  /// Index des identités (P2-64). Une mention correspond à une identité si ses
  /// segments sont **inclus dans** ceux de l'identité, ou l'inverse : le premier
  /// cas se cherche par le segment le plus rare de la mention (`_parSegment`), le
  /// second par les sous-ensembles de la mention (`_parEnsemble`, clé = segments
  /// triés). `_parSegment` garde une identité sous tous les segments qu'elle a eus
  /// (ils ne font que croître) ; `_sansSegment` garde celles qui n'en ont aucun,
  /// qui correspondent à toute mention.
  final Map<String, Set<_NomIdentity>> _parSegment = {};
  final Map<String, Set<_NomIdentity>> _parEnsemble = {};
  final Set<_NomIdentity> _sansSegment = {};

  static String _cle(Set<String> segments) =>
      (segments.toList()..sort()).join('\u0000');

  final Map<EntityType, int> counterByType = {};

  void ajouteIdentite(_NomIdentity identite) {
    nomIdentities.add(identite);
    indexe(identite);
  }

  void indexe(_NomIdentity identite) {
    if (identite.segments.isEmpty) {
      _sansSegment.add(identite);
      return;
    }
    for (final segment in identite.segments) {
      (_parSegment[segment] ??= {}).add(identite);
    }
    (_parEnsemble[_cle(identite.segments)] ??= {}).add(identite);
  }

  /// L'identité vient de changer de segments (forme plus complète rencontrée).
  void reindexe(_NomIdentity identite, Set<String> anciens) {
    _parEnsemble[_cle(anciens)]?.remove(identite);
    indexe(identite);
  }

  /// Identités susceptibles de correspondre à une mention de [segments] : un
  /// sur-ensemble de celles qui correspondent réellement (le prédicat exact est
  /// ensuite appliqué par l'appelant).
  Iterable<_NomIdentity> candidats(Set<String> segments) {
    if (segments.isEmpty) return nomIdentities;
    final vues = <_NomIdentity>{..._sansSegment};
    // Identités qui contiennent tous les segments de la mention : la plus petite
    // des listes de segment suffit.
    Set<_NomIdentity>? plusPetite;
    for (final segment in segments) {
      final liste = _parSegment[segment];
      if (liste == null) {
        plusPetite = const {};
        break;
      }
      if (plusPetite == null || liste.length < plusPetite.length) {
        plusPetite = liste;
      }
    }
    vues.addAll(plusPetite ?? const {});
    // Identités dont les segments sont inclus dans ceux de la mention.
    final liste = segments.toList();
    if (liste.length > 8) {
      for (final segment in liste) {
        vues.addAll(_parSegment[segment] ?? const {});
      }
    } else {
      for (var masque = 1; masque < (1 << liste.length); masque++) {
        final sous = {
          for (var k = 0; k < liste.length; k++)
            if (masque & (1 << k) != 0) liste[k]
        };
        vues.addAll(_parEnsemble[_cle(sous)] ?? const {});
      }
    }
    return vues;
  }

  /// Patronymes (minuscules) établis par une mention certaine d'un document
  /// du dossier : amorcent la détection des documents suivants.
  final Set<String> patronymes = {};

  /// Tous les jetons attribués, y compris ceux qui ne sont pas dans la carte
  /// (secrets non restaurables).
  final Set<String> attribues = {};

  /// Nombre de documents déjà masqués avec cet état.
  int documents = 0;

  /// Motifs de [tolerantTokenPattern] déjà compilés, par jeton : compiler un
  /// motif par jeton et par appel dominait le coût d'un gros dossier (P2-25).
  final Map<String, RegExp> _motifs = {};

  static final RegExp _crochets = RegExp(r'\[[^\[\]]*\]');

  /// Jetons déjà attribués qui figurent en clair dans [text] (même résultat
  /// que `tolerantTokenPattern(jeton).hasMatch(text)` pour chacun, dans l'ordre
  /// d'attribution). Un motif commence par `[` et finit par `]` sans autre
  /// crochet à l'intérieur : il ne peut se trouver que dans un segment
  /// `[...]` sans crochet, donc un texte sans tel segment (le cas courant) ne
  /// coûte plus rien, et les autres ne sont testés que sur ces segments.
  List<String> jetonsLitteraux(String text) {
    if (attribues.isEmpty) return const [];
    final segments = [for (final m in _crochets.allMatches(text)) m[0]!];
    if (segments.isEmpty) return const [];
    final zone = segments.join('\n');
    return [
      for (final jeton in attribues)
        if ((_motifs[jeton] ??= tolerantTokenPattern(jeton)).hasMatch(zone))
          jeton
    ];
  }

  /// Copie profonde, pour simuler un masquage (rapport de risque de l'aperçu)
  /// sans toucher à l'état réel du dossier.
  _Etat copie() {
    final c = _Etat(regle)..documents = documents;
    c.mapping.addAll(mapping);
    c.tokenByIdentity.addAll(tokenByIdentity);
    for (final n in nomIdentities) {
      c.ajouteIdentite(
          _NomIdentity(Set.of(n.segments), n.token, n.gender, n.doc));
    }
    c.counterByType.addAll(counterByType);
    c.patronymes.addAll(patronymes);
    c.attribues.addAll(attribues);
    return c;
  }

  void efface() {
    mapping.clear();
    tokenByIdentity.clear();
    nomIdentities.clear();
    _parSegment.clear();
    _parEnsemble.clear();
    _sansSegment.clear();
    counterByType.clear();
    patronymes.clear();
    attribues.clear();
  }
}
