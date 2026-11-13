import 'dart:convert';
import 'dart:io';

import 'package:ecluse_reference/ecluse_reference.dart';
import 'package:ecluse_reid/ecluse_reid.dart';
import 'package:test/test.dart';

/// L'effectif F hors des canaux de texte (P2-176).
///
/// Pour un lieu seul, F est la population légale de la commune. Or cette
/// population est unique en France pour 8,5 % des communes de
/// `geo_communes.csv.gz`, et unique dans son département pour 70 % : écrire
/// l'effectif exact dans une trace d'audit ou un `toString`, c'est y écrire
/// la commune. Ces canaux donnent donc la tranche de risque ; les champs
/// numériques (`f`, `fBefore`, `fAfter`) gardent l'effectif pour
/// l'application.
///
/// Les communes sont des entrées du référentiel public (populations légales
/// de l'INSEE), pas des données tirées d'un document.
void main() {
  // Commune dont la population légale n'est portée par aucune autre commune
  // du référentiel (vérifié plus bas sur l'asset lui-même).
  const communeUnique = '70026';
  // Commune de 320 habitants : l'effectif départemental d'une profession y
  // est plafonné à la population du lieu (note de plafonnement).
  const petiteCommune = '57001';

  late EcluseReference ref;
  late int popUnique;
  late int popPetite;

  setUpAll(() async {
    ref = EcluseReference(fileAssets(assetsDir: '../ecluse_reference/assets'));
    await ref.preload();
    popUnique = ref.geo.population(communeUnique)!;
    popPetite = ref.geo.population(petiteCommune)!;
  });

  /// Vrai si [texte] porte l'effectif [f] : comme nombre entier isolé
  /// (« 2393 », « 2393.0 », « 2393.00 ») ou, pour un effectif non entier,
  /// sous une de ses deux écritures.
  bool porte(String texte, double f) {
    if (f == f.roundToDouble()) {
      return RegExp('(?<![0-9])${f.round()}(?![0-9])').hasMatch(texte);
    }
    return texte.contains(f.toString()) || texte.contains(f.toStringAsFixed(2));
  }

  /// Tous les effectifs que la trace connaît.
  List<double> effectifs(ReidTrace trace) => [
        trace.estimateInitial.f,
        for (final c in trace.candidats) ...[
          c.fBefore,
          if (c.fAfter != null) c.fAfter!,
        ],
        if (trace.suggestion != null) ...[
          trace.suggestion!.fBefore,
          trace.suggestion!.fAfter,
        ],
      ];

  /// Clés numériques permises dans la carte d'audit : niveaux de
  /// généralisation et seuil, fixés par Écluse et l'application.
  const clesPermises = {'niveau', 'niveauAvant', 'niveauApres', 'seuilVise'};

  /// La carte d'audit de [trace] ne porte aucun effectif : aucun nombre hors
  /// des clés permises, aucune chaîne qui en cite un.
  void attendSansEffectif(ReidTrace trace) {
    final relue =
        jsonDecode(jsonEncode(trace.toAuditMap())) as Map<String, Object?>;
    final chaines = <String>[];
    final nombres = <String, num>{};
    void parcourir(Object? noeud, {String? cle}) {
      if (noeud is Map) {
        noeud.forEach((k, v) => parcourir(v, cle: k as String));
      } else if (noeud is List) {
        for (final v in noeud) {
          parcourir(v, cle: cle);
        }
      } else if (noeud is String) {
        chaines.add(noeud);
      } else if (noeud is num && !clesPermises.contains(cle)) {
        nombres[cle ?? '?'] = noeud;
      }
    }

    parcourir(relue);
    expect(nombres.keys, isEmpty,
        reason: 'clés numériques hors niveaux et seuil');
    for (final f in effectifs(trace)) {
      for (final chaine in chaines) {
        expect(porte(chaine, f), isFalse,
            reason: 'un effectif est cité dans une chaîne de la carte');
      }
    }
  }

  test('prémisse : la population de la commune choisie est unique en France',
      () {
    final lignes = utf8
        .decode(gzip.decode(
            File('../ecluse_reference/assets/geo_communes.csv.gz')
                .readAsBytesSync()))
        .split('\n')
        .skip(1)
        .where((l) => l.isNotEmpty);
    final memePopulation =
        lignes.where((l) => l.split(';')[3] == '$popUnique').length;
    expect(memePopulation, 1);
  });

  group('les champs numériques de l\'API ne changent pas', () {
    test('lieu seul : f est la population de la commune', () {
      final e = estimate(ref, const [Qi(QiType.lieu, communeUnique)]);
      expect(e.f, popUnique.toDouble());
      expect(e.band, RiskBand.faible);
    });

    test('candidat et suggestion gardent fBefore et fAfter', () {
      final trace = ReidLoop(ref).explain(
          const [Qi(QiType.age, '89'), Qi(QiType.lieu, petiteCommune)]);
      expect(trace.suggestion!.fAfter, closeTo(3519.56, 1));
      expect(trace.candidats.where((c) => c.retenu).single.fAfter,
          trace.suggestion!.fAfter);
    });
  });

  group('toAuditMap : la tranche de risque, jamais l\'effectif', () {
    test('lieu seul, succès immédiat', () {
      final trace =
          ReidLoop(ref).explain(const [Qi(QiType.lieu, communeUnique)]);
      expect(trace.outcome, TraceOutcome.succes);
      attendSansEffectif(trace);
      expect(trace.toAuditMap()['bandeInitiale'], 'faible');
      expect(trace.toAuditMap().containsKey('fInitial'), isFalse);
    });

    test('lieu seul, candidats simulés (fBefore = population)', () {
      final trace = ReidLoop(ref, threshold: 1000000)
          .explain(const [Qi(QiType.lieu, communeUnique)]);
      expect(trace.candidats, isNotEmpty);
      expect(trace.candidats.first.fBefore, popUnique.toDouble());
      attendSansEffectif(trace);
    });

    test(
        'lieu et âge au dernier palier : le retrait de l\'âge rend fAfter = '
        'population', () {
      final trace = ReidLoop(ref, threshold: 1000000).explain(const [
        Qi(QiType.age, '65-130', level: 3),
        Qi(QiType.lieu, communeUnique),
      ]);
      final retrait = trace.candidats.where((c) => c.type == QiType.age).single;
      expect(retrait.fAfter, popUnique.toDouble());
      attendSansEffectif(trace);
    });

    test('chaque candidat donne sa tranche avant et après', () {
      final trace = ReidLoop(ref).explain(
          const [Qi(QiType.age, '89'), Qi(QiType.lieu, petiteCommune)]);
      attendSansEffectif(trace);
      final candidats = trace.toAuditMap()['candidats'] as List;
      final retenu = candidats
          .cast<Map<String, Object?>>()
          .firstWhere((c) => c['retenu'] == true);
      expect(retenu['bandeAvant'], 'eleve');
      expect(retenu['bandeApres'], 'faible');
      expect(retenu.containsKey('fAvant'), isFalse);
      expect(retenu.containsKey('fApres'), isFalse);
      expect(retenu['raisonDuChoix'], contains('eleve'));
      expect(retenu['raisonDuChoix'], contains('faible'));
    });

    test('un candidat sans palier n\'a pas de tranche après', () {
      final trace = ReidLoop(ref, threshold: 1000000000)
          .explain(const [Qi(QiType.lieu, lieuFrance, level: 4)]);
      attendSansEffectif(trace);
      final candidat = (trace.toAuditMap()['candidats'] as List).single
          as Map<String, Object?>;
      expect(candidat['bandeAvant'], 'faible');
      expect(candidat['bandeApres'], isNull);
    });

    test(
        'profession plafonnée à la population du lieu : la note ne cite pas '
        'la population', () {
      const qis = [
        Qi(QiType.profession, 'pharmacien'),
        Qi(QiType.lieu, petiteCommune),
      ];
      final e = estimate(ref, qis);
      expect(e.f, popPetite.toDouble(), reason: 'le plafond s\'applique');
      final note = e.notes.singleWhere((n) => n.contains('plafonnée'));
      expect(porte(note, popPetite.toDouble()), isFalse);
      attendSansEffectif(ReidLoop(ref).explain(qis));
    });
  });

  group('toString : la tranche de risque, jamais l\'effectif', () {
    test('ReidEstimate', () {
      final e = estimate(ref, const [Qi(QiType.lieu, communeUnique)]);
      expect(porte(e.toString(), e.f), isFalse);
      expect(e.toString(), contains('faible'));
      expect(e.toString(), contains('lieu'));
    });

    test('ReidEstimate, effectif non entier', () {
      final e = estimate(
          ref, const [Qi(QiType.age, '89'), Qi(QiType.lieu, communeUnique)]);
      expect(e.f, isNot(e.f.roundToDouble()));
      expect(porte(e.toString(), e.f), isFalse);
    });

    test('ReidTrace', () {
      final trace =
          ReidLoop(ref).explain(const [Qi(QiType.lieu, communeUnique)]);
      expect(porte(trace.toString(), trace.estimateInitial.f), isFalse);
      expect(trace.toString(), contains('succes'));
      expect(trace.toString(), contains('faible'));
    });

    test('Generalization', () {
      final g = ReidLoop(ref, threshold: 1000000).explain(const [
        Qi(QiType.age, '65-130', level: 3),
        Qi(QiType.lieu, communeUnique),
      ]).suggestion!;
      expect(porte(g.toString(), g.fBefore), isFalse);
      expect(porte(g.toString(), g.fAfter), isFalse);
      expect(g.toString(), contains(g.bandBefore.name));
      expect(g.toString(), contains(g.bandAfter.name));
    });
  });
}
