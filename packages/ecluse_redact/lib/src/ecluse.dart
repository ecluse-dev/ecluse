import 'dart:async';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_reference/ecluse_reference.dart' show EcluseReference;

import 'heuristics/adresse_detector.dart';
import 'heuristics/date_naissance_detector.dart';
import 'heuristics/email_detector.dart';
import 'heuristics/etablissement_detector.dart';
import 'heuristics/name_detector.dart';
import 'heuristics/telephone_detector.dart';
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
    LegacyDetectorAdapter(IbanFrDetector(), DetectorTier.structural,
        name: 'iban'),
    LegacyDetectorAdapter(InsDetector(), DetectorTier.structural, name: 'ins'),
    FinessDetector(),
    AdeliDetector(),
    LegacyDetectorAdapter(NameDetector(), DetectorTier.reference, name: 'nom'),
    LegacyDetectorAdapter(DateNaissanceDetector(), DetectorTier.pattern,
        name: 'date_naissance'),
    LegacyDetectorAdapter(AdresseDetector(), DetectorTier.pattern,
        name: 'adresse'),
    LegacyDetectorAdapter(TelephoneDetector(), DetectorTier.pattern,
        name: 'telephone'),
    LegacyDetectorAdapter(EmailDetector(), DetectorTier.pattern, name: 'email'),
    LegacyDetectorAdapter(EtablissementDetector(), DetectorTier.pattern,
        name: 'etablissement'),
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
  static Future<RedactResult> redact(
    String text, {
    List<Detector>? detectors,
    bool restoreSecrets = false,
    bool refuseSecrets = false,
    EcluseReference? riskReference,
    Dossier? dossier,
  }) {
    if (dossier == null) {
      return _redact(text, _Etat(), detectors, restoreSecrets, refuseSecrets,
          riskReference);
    }
    return dossier._serialise(() {
      final etat = dossier._etat;
      if (etat == null) throw const DossierFermeException();
      return _redact(
          text, etat, detectors, restoreSecrets, refuseSecrets, riskReference);
    });
  }

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
  }) {
    if (dossier == null) return _detecter(text, _Etat(), detectors);
    return dossier._serialise(() {
      final etat = dossier._etat;
      if (etat == null) throw const DossierFermeException();
      return _detecter(text, etat, detectors);
    });
  }

  /// Détection pure : lit [etat] (patronymes établis) sans jamais le modifier.
  static Future<List<DetectedEntity>> _detecter(
    String text,
    _Etat etat,
    List<Detector>? detectors,
  ) async {
    // Dans un dossier, les patronymes établis par les documents précédents
    // amorcent la détection de noms (P2-14) ; des détecteurs fournis par
    // l'appelant ne sont jamais modifiés.
    final engine = EcluseEngine(detectors ??
        (etat.patronymes.isEmpty
            ? defaultDetectors
            : _detecteursAvecPatronymes(etat.patronymes)));
    return (await engine.run(text)).entities;
  }

  static Future<RedactResult> _redact(
    String text,
    _Etat etat,
    List<Detector>? detectors,
    bool restoreSecrets,
    bool refuseSecrets,
    EcluseReference? riskReference,
  ) async {
    final resolved = await _detecter(text, etat, detectors);

    final secretCount =
        resolved.where((e) => e.type == EntityType.secret).length;
    if (refuseSecrets && secretCount > 0) {
      throw SecretsRefusedException(secretCount);
    }
    return _appliquer(text, resolved, etat, restoreSecrets, riskReference);
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
    final litteraux = [
      for (final token in etat.attribues)
        if (tolerantTokenPattern(token).hasMatch(text)) token
    ];
    final docId = etat.documents++;
    for (final entity in resolved) {
      if (entity.type != EntityType.nom) continue;
      final patronyme =
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

  /// Remplace chaque jeton présent dans [text] par sa valeur réelle depuis
  /// [mapping]. Tolère une déformation raisonnable du jeton par le LLM
  /// (espaces superflus, casse) mais ne devine jamais une correspondance
  /// approximative — voir [tolerantTokenPattern].
  static String restore(String text, Map<String, String> mapping) {
    var result = text;
    for (final entry in mapping.entries) {
      result = result.replaceAll(tolerantTokenPattern(entry.key), entry.value);
    }
    return result;
  }
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
  if (RegExp(r'(?:^|[^\wÀ-ÿ])(?:M\.|Mr\.?|Monsieur)[ \t\u00A0\u202F]*$')
      .hasMatch(head)) {
    return 'm';
  }
  if (RegExp(r'(?:^|[^\wÀ-ÿ])(?:Mme|Mlle|Mrs\.?|Madame|Mademoiselle)'
          r'[ \t\u00A0\u202F]*$')
      .hasMatch(head)) {
    return 'f';
  }
  return null;
}

/// Segments (minuscules, sans doublons) d'une mention de nom — insensible
/// à l'ordre et à la casse : « Dubreuil Thomas » et « Thomas Dubreuil »
/// produisent le même ensemble.
Set<String> _nameSegments(String value) => value
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((segment) => segment.isNotEmpty)
    .toSet();

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
  final gender = _genderBefore(text, entity.start);
  // Deux civilités de sexe différent désignent deux personnes, même avec un
  // patronyme commun (un couple).
  bool compatible(_NomIdentity identity) =>
      !(gender != null && identity.gender != null && gender != identity.gender);

  final matches = etat.nomIdentities
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
      identity.segments = segments;
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
    final anterieures = etat.nomIdentities
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
  etat.nomIdentities.add(_NomIdentity(segments, token, gender, docId));
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
  } while (tolerantTokenPattern(token).hasMatch(text));
  counterByType[type] = next;
  return token;
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
  final Map<EntityType, int> counterByType = {};

  /// Patronymes (minuscules) établis par une mention certaine d'un document
  /// du dossier : amorcent la détection des documents suivants.
  final Set<String> patronymes = {};

  /// Tous les jetons attribués, y compris ceux qui ne sont pas dans la carte
  /// (secrets non restaurables).
  final Set<String> attribues = {};

  /// Nombre de documents déjà masqués avec cet état.
  int documents = 0;

  /// Copie profonde, pour simuler un masquage (rapport de risque de l'aperçu)
  /// sans toucher à l'état réel du dossier.
  _Etat copie() {
    final c = _Etat(regle)..documents = documents;
    c.mapping.addAll(mapping);
    c.tokenByIdentity.addAll(tokenByIdentity);
    c.nomIdentities.addAll([
      for (final n in nomIdentities)
        _NomIdentity(Set.of(n.segments), n.token, n.gender, n.doc)
    ]);
    c.counterByType.addAll(counterByType);
    c.patronymes.addAll(patronymes);
    c.attribues.addAll(attribues);
    return c;
  }

  void efface() {
    mapping.clear();
    tokenByIdentity.clear();
    nomIdentities.clear();
    counterByType.clear();
    patronymes.clear();
    attribues.clear();
  }
}
