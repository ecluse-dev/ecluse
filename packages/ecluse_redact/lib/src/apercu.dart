part of 'ecluse.dart';

/// Une entité proposée à la validation de l'utilisateur (P2-18,
/// `agent/specs/P2-08.md`). L'[id] n'a de sens que dans sa [Proposition].
final class EntiteProposee {
  const EntiteProposee({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.valeur,
    required this.confiance,
    required this.tier,
  });

  final int id;
  final EntityType type;
  final int start;
  final int end;
  final String valeur;
  final double confiance;

  /// Origine de la détection : une entité `structural` (clé de contrôle
  /// validée) ne se refuse qu'avec une option explicite.
  final DetectorTier? tier;
}

/// Résultat de [Apercu.propose] : ce qu'Écluse masquerait, sans rien avoir
/// masqué. Liée au texte exact qui l'a produite.
final class Proposition {
  Proposition._(this.texte, this._brutes, this._dossier, this._documents)
      : entites = List.unmodifiable([
          for (var i = 0; i < _brutes.length; i++)
            EntiteProposee(
              id: i,
              type: _brutes[i].type,
              start: _brutes[i].start,
              end: _brutes[i].end,
              valeur: _brutes[i].value,
              confiance: _brutes[i].confidence,
              tier: _brutes[i].tier,
            )
        ]);

  /// Texte analysé : seul texte que [Apercu.applique] accepte.
  final String texte;
  final List<EntiteProposee> entites;
  final List<DetectedEntity> _brutes;

  /// Dossier qui a produit la proposition et nombre de documents qu'il avait
  /// déjà masqués : au-delà, ses patronymes et ses jetons ont pu changer et la
  /// proposition est périmée (P2-19).
  final Dossier? _dossier;
  final int _documents;

  /// Nombre d'entités proposées par type.
  Map<EntityType, int> get resume {
    final m = <EntityType, int>{};
    for (final e in entites) {
      m[e.type] = (m[e.type] ?? 0) + 1;
    }
    return Map.unmodifiable(m);
  }
}

/// Passage ajouté à la main : [start] inclus, [end] exclu, dans le texte
/// analysé.
final class AjoutManuel {
  const AjoutManuel(this.start, this.end, this.type);

  final int start;
  final int end;
  final EntityType type;

  @override
  String toString() => 'AjoutManuel($start, $end, ${type.name})';
}

/// Décision de l'utilisateur sur une [Proposition]. Par défaut : tout accepté.
final class DecisionApercu {
  const DecisionApercu({this.refusees = const {}, this.ajouts = const []});

  /// Identifiants ([EntiteProposee.id]) laissés en clair.
  final Set<int> refusees;
  final List<AjoutManuel> ajouts;
}

/// Décision invalide ou texte modifié : refus explicite, jamais d'application
/// partielle.
final class ApercuException implements Exception {
  const ApercuException(this.message);

  final String message;

  @override
  String toString() => 'ApercuException: $message';
}

/// Aperçu avec validation : [propose] détecte sans rien masquer, l'utilisateur
/// décide, [applique] masque selon sa décision (P2-18).
///
/// Invariants : le texte envoyé est celui de l'aperçu (sinon refus) ; une
/// décision invalide n'applique rien et ne touche pas au dossier ; un passage
/// laissé en clair n'a ni jeton ni entrée de table, donc la restauration reste
/// identique à l'original. Refuser une détection est un acte de l'utilisateur :
/// ce qui reste en clair part chez le tiers (voir `LIMITES.md`).
abstract final class Apercu {
  /// Détecte comme [Ecluse.detect] (aucun effet de bord). Avec
  /// [refuseSecrets], un secret détecté lève [SecretsRefusedException] avant
  /// toute proposition.
  static Future<Proposition> propose(
    String text, {
    List<Detector>? detectors,
    bool refuseSecrets = false,
    Dossier? dossier,
  }) async {
    var documents = 0;
    final List<DetectedEntity> entites;
    if (dossier == null) {
      entites = await Ecluse.detect(text, detectors: detectors);
    } else {
      // Détection et lecture du compteur dans la même section sérialisée.
      (entites, documents) = await dossier._serialise(() async {
        final etat = dossier._etat;
        if (etat == null) throw const DossierFermeException();
        return (
          await Ecluse._detecter(text, etat, detectors),
          etat.documents,
        );
      });
    }
    final secrets = entites.where((e) => e.type == EntityType.secret).length;
    if (refuseSecrets && secrets > 0) throw SecretsRefusedException(secrets);
    return Proposition._(text, entites, dossier, documents);
  }

  /// Masque [texteAEnvoyer] selon [decision]. Toutes les vérifications ont
  /// lieu avant la première modification d'état.
  ///
  /// Refuser une entité `structural` exige [autoriserRefusStructurel] ;
  /// refuser un secret est toujours interdit. Un ajout qui recouvre
  /// entièrement des détections les remplace ; un recouvrement partiel, une
  /// inclusion dans une détection conservée ou un chevauchement entre ajouts
  /// est une erreur.
  ///
  /// Le rapport de risque ([riskReference]) est calculé ici, sur le texte
  /// réellement masqué, et non dans la proposition.
  static Future<RedactResult> applique(
    Proposition proposition,
    DecisionApercu decision, {
    required String texteAEnvoyer,
    bool autoriserRefusStructurel = false,
    bool restoreSecrets = false,
    EcluseReference? riskReference,
    Dossier? dossier,
  }) {
    RedactResult appliquer(_Etat etat) {
      if (!identical(proposition._dossier, dossier)) {
        throw const ApercuException(
            'la proposition ne s\'applique qu\'au dossier qui l\'a produite');
      }
      if (proposition._documents != etat.documents) {
        throw const ApercuException(
            'le dossier a changé depuis l\'aperçu : refaire l\'aperçu');
      }
      final (finales, manuelles) = _valide(
          proposition, decision, texteAEnvoyer, autoriserRefusStructurel);
      final r = Ecluse._appliquer(
          texteAEnvoyer, finales, etat, restoreSecrets, riskReference);
      return RedactResult(
        maskedText: r.maskedText,
        mapping: r.mapping,
        entities: r.entities,
        warnings: r.warnings,
        risque: r.risque,
        manuelles: List.unmodifiable(manuelles),
      );
    }

    if (dossier == null) {
      return Future.sync(() => appliquer(_Etat()));
    }
    return dossier._serialise(() {
      final etat = dossier._etat;
      if (etat == null) throw const DossierFermeException();
      return Future.value(appliquer(etat));
    });
  }

  static (List<DetectedEntity>, List<DetectedEntity>) _valide(
    Proposition p,
    DecisionApercu d,
    String texte,
    bool autoriserRefusStructurel,
  ) {
    if (texte != p.texte) {
      throw const ApercuException(
          'le texte à envoyer diffère du texte analysé : refaire l\'aperçu');
    }
    final gardees = <DetectedEntity>[];
    for (final id in d.refusees) {
      if (id < 0 || id >= p.entites.length) {
        throw ApercuException('identifiant d\'entité inconnu : $id');
      }
      final e = p.entites[id];
      if (e.type == EntityType.secret) {
        throw ApercuException('un secret ne peut pas être laissé en clair '
            '(entité $id)');
      }
      if (e.tier == DetectorTier.structural && !autoriserRefusStructurel) {
        throw ApercuException('entité $id à validation structurelle : '
            'refus soumis à autoriserRefusStructurel');
      }
    }
    for (var i = 0; i < p._brutes.length; i++) {
      if (!d.refusees.contains(i)) gardees.add(p._brutes[i]);
    }

    final ajouts = <DetectedEntity>[];
    for (final brut in d.ajouts) {
      if (brut.start < 0 || brut.end > texte.length || brut.start >= brut.end) {
        throw ApercuException('ajout hors bornes ou vide : $brut');
      }
      if (_coupeUnePaire(texte, brut.start) ||
          _coupeUnePaire(texte, brut.end)) {
        throw ApercuException(
            'ajout dont une borne coupe un caractère hors plan de base '
            '(paire de substituts UTF-16) : $brut');
      }
      // Les blancs en bordure (sélection à la souris) ne sont pas masqués :
      // deux mentions qui ne diffèrent que par eux partageraient un jeton dont
      // la carte garderait la première forme, et la restauration ajouterait ou
      // retirerait des espaces (P2-20).
      final a = _sansBlancsEnBordure(brut, texte);
      if (a.type == EntityType.secret) {
        throw ApercuException('le type secret ne peut pas être ajouté : $a');
      }
      for (final autre in ajouts) {
        if (a.start < autre.end && autre.start < a.end) {
          throw ApercuException('deux ajouts se chevauchent : $a');
        }
      }
      for (final e in gardees) {
        final recouvert = a.start <= e.start && e.end <= a.end;
        if (!recouvert && a.start < e.end && e.start < a.end) {
          throw ApercuException(
              'ajout $a en chevauchement partiel ou redondant avec une '
              'détection conservée (${e.start}-${e.end})');
        }
      }
      ajouts.add(DetectedEntity(
        type: a.type,
        start: a.start,
        end: a.end,
        value: texte.substring(a.start, a.end),
        confidence: 1.0,
      ));
    }
    final finales = [
      for (final e in gardees)
        if (!ajouts.any((a) => a.start <= e.start && e.end <= a.end)) e,
      ...ajouts,
    ]..sort((x, y) => x.start.compareTo(y.start));
    return (finales, ajouts);
  }
}

final _blanc = RegExp(r'\s');

/// [a] réduit pour que son texte ne commence ni ne finisse par un blanc ;
/// [ApercuException] s'il ne reste rien.
AjoutManuel _sansBlancsEnBordure(AjoutManuel a, String texte) {
  var start = a.start;
  var end = a.end;
  while (start < end && _blanc.hasMatch(texte[start])) {
    start++;
  }
  while (end > start && _blanc.hasMatch(texte[end - 1])) {
    end--;
  }
  if (start == end) {
    throw ApercuException('ajout fait seulement de blancs : $a');
  }
  return AjoutManuel(start, end, a.type);
}

/// Vrai si la position [i] tombe entre les deux moitiés d'une paire de
/// substituts UTF-16 (émoji, etc.) : masquer à cette borne laisserait une
/// moitié isolée dans le texte envoyé, non encodable (P2-21).
bool _coupeUnePaire(String texte, int i) {
  if (i <= 0 || i >= texte.length) return false;
  final avant = texte.codeUnitAt(i - 1);
  final apres = texte.codeUnitAt(i);
  return avant >= 0xD800 &&
      avant <= 0xDBFF &&
      apres >= 0xDC00 &&
      apres <= 0xDFFF;
}
