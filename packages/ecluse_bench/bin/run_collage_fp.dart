import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ecluse_core/ecluse_core.dart';

/// Chiffre ce que coûterait une fin de ligne neutralisée **dans le cœur**
/// (P2-162 § 5, points 1 et 3), sans la coder : le texte est recollé ici, hors
/// de `lib/`, avec la règle d'`ecluse_redact` (`_coupuresDeLigne`,
/// `packages/ecluse_redact/lib/src/ecluse.dart`), puis les détecteurs sont
/// appelés directement sur le texte recollé.
///
/// Une détection qui traverse une coupure n'existe que grâce au collage : un
/// détecteur ne franchit jamais un saut de ligne dans le texte d'origine
/// (vérifié en tête de rapport : 0 traversée sur le texte non recollé). Pour
/// chaque entrée on compte donc :
///
/// - les coupures « chiffre, fin de ligne, chiffre » (candidates) ;
/// - les détections qui les traversent (clé valide une fois recollé) ; sur un
///   corpus annoté, celles qui recouvrent un identifiant annoté sont
///   « attendues » (un vrai identifiant coupé), les autres sont « à tort »
///   (budget de faux positifs) ;
/// - les colonnes de nombres à 9, 11 ou 13 chiffres, un par ligne.
///
/// Aucune valeur tirée d'un texte n'est imprimée : seulement des comptes et,
/// pour les détections à tort, l'identifiant du document et les positions.
///
/// Usage : dart run ecluse_bench:run_collage_fp <entrée>... où chaque entrée
/// est un `.jsonl` (champ `text`, champ `entities` facultatif) ou un fichier
/// texte lu en entier. Sans argument : cas ciblés de P2-162 § 5.3 seulement.
///
/// Deux autres mesures (P2-171, points 2 et 4 du plan de P2-162 § 5), toujours
/// sans rien changer dans `lib/` :
///
///   dart run bin/run_collage_fp.dart --equivalence <entrée>...
///     Compare, document par document, les détections des détecteurs isolés
///     sur le texte d'origine et sur le texte recollé (positions reprojetées
///     vers l'origine). Sans entrée : cas de voisinage tirés à graine 42 (un
///     identifiant complet en fin de ligne suivi d'une ligne qui commence par
///     un chiffre, une colonne d'identifiants).
///
///   dart run bin/run_collage_fp.dart --cout [--petit]
///     Temps du recollage et de la détection sur le texte recollé, à trois
///     tailles, sur une page ordinaire et sur des entrées adversariales.
///     `--petit` divise les tailles par 100 (pour le test du banc).
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--equivalence') {
    await _equivalence(args.sublist(1));
    return;
  }
  if (args.isNotEmpty && args.first == '--cout') {
    await _cout(petit: args.contains('--petit'));
    return;
  }
  if (args.isEmpty) {
    await _casCibles();
    return;
  }
  var tTraverseOrigine = 0;
  for (final chemin in args) {
    if (!File(chemin).existsSync()) {
      stderr.writeln('REFUS : $chemin introuvable.');
      exit(66);
    }
    final docs = <_Doc>[];
    if (chemin.endsWith('.jsonl')) {
      for (final l in File(chemin).readAsLinesSync()) {
        if (l.trim().isEmpty) continue;
        final d = jsonDecode(l) as Map<String, dynamic>;
        if (d['text'] is! String) {
          // Règle 4 : refus explicite, jamais « rien à compter » sur un
          // fichier qui n'est pas un corpus (prédictions, par exemple).
          stderr.writeln('REFUS : $chemin n\'a pas de champ "text" '
              '(ce n\'est pas un corpus).');
          exit(65);
        }
        docs.add(_Doc(
          '${d['id']}',
          d['text'] as String,
          [
            for (final e in (d['entities'] as List? ?? const []))
              if (const {'nir', 'rpps', 'iban', 'finess'}
                  .contains('${(e as Map)['type']}'.toLowerCase()))
                (e['start'] as int, e['end'] as int)
          ],
        ));
      }
    } else {
      docs.add(_Doc(chemin, File(chemin).readAsStringSync(), const []));
    }
    var candidates = 0, traversent = 0, attendues = 0, atort = 0, colonnes = 0;
    final parType = <String, int>{};
    final exemples = <String>[];
    for (final d in docs) {
      final r = await _mesure(d);
      candidates += r.candidates;
      traversent += r.traversent;
      attendues += r.attendues;
      atort += r.atort;
      colonnes += r.colonnes;
      tTraverseOrigine += r.traverseOrigine;
      r.parType.forEach((t, n) => parType[t] = (parType[t] ?? 0) + n);
      for (final e in r.exemplesAtort) {
        if (exemples.length < 5) exemples.add('${d.id}:$e');
      }
    }
    final types = (parType.keys.toList()..sort())
        .map((t) => '$t ${parType[t]}')
        .join(', ');
    stdout.writeln('$chemin : ${docs.length} doc., $candidates coupures '
        'chiffre-fin de ligne-chiffre, $traversent détections traversant une '
        'coupure (${types.isEmpty ? 'aucune' : types}) = $attendues attendues '
        '+ $atort à tort, $colonnes colonnes de 9/11/13 chiffres'
        '${exemples.isEmpty ? '' : ' ; à tort (id:début-fin) ${exemples.join(' ')}'}');
  }
  stdout.writeln(
      'Contrôle : $tTraverseOrigine détection(s) traversant une coupure dans '
      'le texte non recollé (attendu 0).');
}

class _Doc {
  _Doc(this.id, this.text, this.annotes);
  final String id;
  final String text;
  final List<(int, int)> annotes;
}

class _Mesure {
  int candidates = 0,
      traversent = 0,
      attendues = 0,
      atort = 0,
      colonnes = 0,
      traverseOrigine = 0;
  final parType = <String, int>{};
  final exemplesAtort = <String>[];
}

/// Même règle que `_coupuresDeLigne` d'`ecluse_redact` (à garder identique :
/// une fin de ligne entre un chiffre, un séparateur de groupe ou « chiffre +
/// majuscule » et un chiffre ou « majuscule + chiffre »).
const _blancs = r' \t  -  　';
final RegExp _coupures = RegExp(r'(?<=[0-9/.\-]|[0-9][A-Z])'
    '[$_blancs]*\\r?\\n[$_blancs]*'
    r'(?=[0-9]|[A-Z][0-9])');

/// Colonne : au moins deux lignes consécutives réduites à un nombre de 9, 11
/// ou 13 chiffres (blancs de bord admis).
final RegExp _ligneNombre = RegExp(r'^[ \t]*(\d{9}|\d{11}|\d{13})[ \t]*$');

final Map<String, List<DetectedEntity> Function(String)> _detecteurs = {
  'nir': (t) => const NirDetector().detect(t),
  'rpps': (t) => const RppsDetector().detect(t),
  'iban': (t) => const IbanFrDetector().detect(t),
  // `FinessDetector.detect` est asynchrone ; sa version synchrone est privée.
};

Future<List<(String, int, int)>> _detecte(String t) async {
  final r = <(String, int, int)>[];
  for (final d in _detecteurs.entries) {
    for (final e in d.value(t)) {
      r.add((d.key, e.start, e.end));
    }
  }
  for (final e
      in await const FinessDetector().detect(NormalizedText.identity(t))) {
    r.add(('finess', e.start, e.end));
  }
  return r;
}

/// Recolle comme `ecluse_redact` : la coupure disparaît après un séparateur,
/// devient une espace après un chiffre ou une majuscule de groupe. Rend le
/// texte recollé, la position d'origine de chaque caractère et les débuts de
/// coupure (dans le texte d'origine).
(String, List<int>, List<int>) _recolle(String texte) {
  final ms = _coupures.allMatches(texte).toList();
  final retires = <int>{};
  final unites = texte.codeUnits.toList();
  final debuts = <int>[];
  for (final m in ms) {
    debuts.add(m.start);
    final avant = texte.codeUnitAt(m.start - 1);
    final apresChiffre =
        (avant >= 0x30 && avant <= 0x39) || (avant >= 0x41 && avant <= 0x5A);
    var d = m.start;
    if (apresChiffre) {
      unites[m.start] = 0x20;
      d++;
    }
    for (var i = d; i < m.end; i++) {
      retires.add(i);
    }
  }
  final sb = StringBuffer();
  final carte = <int>[];
  for (var i = 0; i < unites.length; i++) {
    if (retires.contains(i)) continue;
    sb.writeCharCode(unites[i]);
    carte.add(i);
  }
  return (sb.toString(), carte, debuts);
}

Future<_Mesure> _mesure(_Doc d) async {
  final r = _Mesure();
  final (recolle, carte, debuts) = _recolle(d.text);
  r.candidates = debuts.length;
  for (final (_, s, e) in await _detecte(d.text)) {
    if (debuts.any((c) => s <= c && c < e)) r.traverseOrigine++;
  }
  if (debuts.isNotEmpty) {
    for (final (type, s, e) in await _detecte(recolle)) {
      final os = carte[s], oe = carte[e - 1] + 1;
      if (!debuts.any((c) => os <= c && c < oe)) continue;
      r.traversent++;
      r.parType[type] = (r.parType[type] ?? 0) + 1;
      if (d.annotes.any((a) => a.$1 < oe && os < a.$2)) {
        r.attendues++;
      } else {
        r.atort++;
        r.exemplesAtort.add('$os-$oe');
      }
    }
  }
  final lignes = d.text.split('\n');
  var serie = 0;
  for (final l in lignes) {
    if (_ligneNombre.hasMatch(l.replaceAll('\r', ''))) {
      serie++;
      if (serie == 2) r.colonnes++;
    } else {
      serie = 0;
    }
  }
  return r;
}

/// Cas ciblés de P2-162 § 5.3 : contre-exemples écrits à la main, puis des
/// colonnes de nombres tirés au hasard (graine 42) à 9, 11 et 13 chiffres.
Future<void> _casCibles() async {
  final cas = <String, String>{
    'Salle 4⏎A2': 'La réunion a lieu en salle 4\nA2 fermée le soir.',
    'Vol 12⏎B7': 'Vol 12\nB7 porte ouverte.',
    'le 3⏎C4 du plan': 'Voir le 3\nC4 du plan.',
    'chambres 101⏎102': 'Chambres 101\n102\n103\n104',
    'tableau de chambres': 'Chambre\n12\n13\n14\n15\n16\n17\n18\n19',
  };
  for (final c in cas.entries) {
    final (recolle, carte, debuts) = _recolle(c.value);
    var n = 0;
    for (final (_, s, e) in await _detecte(recolle)) {
      final os = carte[s], oe = carte[e - 1] + 1;
      if (debuts.any((x) => os <= x && x < oe)) n++;
    }
    stdout.writeln('cas « ${c.key} » : ${debuts.length} coupure(s), '
        '$n détection(s) traversant une coupure');
  }
  final alea = Random(42);
  for (final chiffres in [9, 11, 13]) {
    for (final lignes in [2, 10]) {
      var tirages = 0, detections = 0;
      for (var essai = 0; essai < 2000; essai++) {
        final nombres = [
          for (var i = 0; i < lignes; i++)
            [for (var k = 0; k < chiffres; k++) alea.nextInt(10)].join()
        ];
        final (recolle, carte, debuts) = _recolle('${nombres.join('\n')}\n');
        tirages++;
        for (final (_, s, e) in await _detecte(recolle)) {
          final os = carte[s], oe = carte[e - 1] + 1;
          if (debuts.any((x) => os <= x && x < oe)) detections++;
        }
      }
      stdout.writeln('colonne de $lignes nombres de $chiffres chiffres '
          '(tirage uniforme) : $detections détection(s) traversant une '
          'coupure sur $tirages colonnes');
    }
  }
}

// ---------------------------------------------------------------------------
// P2-171, point 2 du plan de P2-162 § 5 : équivalence octet pour octet.
// ---------------------------------------------------------------------------

/// Une détection sérialisée : type, positions **dans le texte d'origine**,
/// confiance et valeur. La valeur sert à la comparaison ; elle n'est jamais
/// imprimée.
Future<List<String>> _detecteComplet(String t, [List<int>? carte]) async {
  int debut(int s) => carte == null ? s : carte[s];
  int fin(int e) => carte == null ? e : carte[e - 1] + 1;
  String ligne(String type, DetectedEntity e) => jsonEncode([
        type,
        debut(e.start),
        fin(e.end),
        e.confidence,
        e.value,
      ]);
  final r = <String>[];
  for (final d in _detecteurs.entries) {
    for (final e in d.value(t)) {
      r.add(ligne(d.key, e));
    }
  }
  for (final e
      in await const FinessDetector().detect(NormalizedText.identity(t))) {
    r.add(ligne('finess', e));
  }
  return r;
}

class _Equivalence {
  int docs = 0,
      sansCoupure = 0,
      identiques = 0,
      differents = 0,
      avecCoupure = 0,
      origine = 0,
      conservees = 0,
      remplacees = 0,
      perdues = 0,
      traversantes = 0,
      nouvellesHors = 0;
  final aVoir = <String>[];

  /// Type des détections nouvelles qui traversent une coupure.
  final traversantesParType = <String, int>{};

  String get types => traversantesParType.isEmpty
      ? ''
      : ' (${(traversantesParType.keys.toList()..sort()).map((t) => '$t ${traversantesParType[t]}').join(', ')})';

  void ajoute(_Equivalence o) {
    o.traversantesParType.forEach(
        (t, n) => traversantesParType[t] = (traversantesParType[t] ?? 0) + n);
    docs += o.docs;
    sansCoupure += o.sansCoupure;
    identiques += o.identiques;
    differents += o.differents;
    avecCoupure += o.avecCoupure;
    origine += o.origine;
    conservees += o.conservees;
    remplacees += o.remplacees;
    perdues += o.perdues;
    traversantes += o.traversantes;
    nouvellesHors += o.nouvellesHors;
  }

  /// Vrai si rien n'a changé hors des détections qui traversent une coupure.
  bool get equivalent => differents == 0 && perdues == 0 && nouvellesHors == 0;

  String get resume => '$docs doc. ; sans coupure $sansCoupure doc., '
      'détections identiques $identiques, différentes $differents ; '
      'avec coupure $avecCoupure doc. : détections d\'origine $origine, '
      'conservées $conservees, remplacées $remplacees, perdues $perdues ; '
      'nouvelles : '
      '$traversantes traversant une coupure$types, $nouvellesHors hors '
      'coupure'
      '${aVoir.isEmpty ? '' : ' ; à voir (id:début-fin) ${aVoir.join(' ')}'}';
}

/// Compare un document. Sans coupure, les deux listes doivent être égales
/// octet pour octet. Avec coupure, chaque détection d'origine doit se
/// retrouver à l'identique (« conservée »). Sinon elle est « remplacée » si
/// une détection nouvelle qui traverse une coupure la recouvre en entier
/// (le morceau d'un identifiant coupé, pris pour un autre identifiant, cède
/// la place à l'identifiant entier), et « perdue » dans les autres cas. Toute
/// détection nouvelle doit traverser une coupure (sinon « hors coupure » :
/// le collage aurait changé une détection qui ne le concerne pas).
Future<void> _compare(_Equivalence r, String id, String texte) async {
  final (recolle, carte, debuts) = _recolle(texte);
  final avant = await _detecteComplet(texte);
  final apres = await _detecteComplet(recolle, carte);
  r.docs++;
  if (debuts.isEmpty) {
    r.sansCoupure++;
    if (avant.join('\n') == apres.join('\n')) {
      r.identiques++;
    } else {
      r.differents++;
      if (r.aVoir.length < 5) r.aVoir.add('$id:différent');
    }
    return;
  }
  r.avecCoupure++;
  final ensembleApres = apres.toSet();
  final ensembleAvant = avant.toSet();
  // Détections nouvelles : (début, fin) de celles qui traversent une coupure.
  final traversantes = <(int, int)>[];
  for (final a in apres) {
    if (ensembleAvant.contains(a)) continue;
    final d = jsonDecode(a) as List;
    final os = d[1] as int, oe = d[2] as int;
    if (debuts.any((c) => os <= c && c < oe)) {
      r.traversantes++;
      traversantes.add((os, oe));
      final t = d[0] as String;
      r.traversantesParType[t] = (r.traversantesParType[t] ?? 0) + 1;
    } else {
      r.nouvellesHors++;
      if (r.aVoir.length < 5) r.aVoir.add('$id:$os-$oe');
    }
  }
  for (final a in avant) {
    r.origine++;
    if (ensembleApres.contains(a)) {
      r.conservees++;
      continue;
    }
    final d = jsonDecode(a) as List;
    final os = d[1] as int, oe = d[2] as int;
    if (traversantes.any((t) => t.$1 <= os && oe <= t.$2)) {
      r.remplacees++;
    } else {
      r.perdues++;
      if (r.aVoir.length < 5) r.aVoir.add('$id:$os-$oe');
    }
  }
}

Future<void> _equivalence(List<String> chemins) async {
  if (chemins.isEmpty) {
    await _voisinage();
    return;
  }
  final total = _Equivalence();
  for (final chemin in chemins) {
    if (!File(chemin).existsSync()) {
      stderr.writeln('REFUS : $chemin introuvable.');
      exit(66);
    }
    final r = _Equivalence();
    if (chemin.endsWith('.jsonl')) {
      for (final l in File(chemin).readAsLinesSync()) {
        if (l.trim().isEmpty) continue;
        final d = jsonDecode(l) as Map<String, dynamic>;
        if (d['text'] is! String) {
          stderr.writeln('REFUS : $chemin n\'a pas de champ "text" '
              '(ce n\'est pas un corpus).');
          exit(65);
        }
        await _compare(r, '${d['id']}', d['text'] as String);
      }
    } else {
      await _compare(r, chemin, File(chemin).readAsStringSync());
    }
    stdout.writeln('$chemin : ${r.resume}');
    total.ajoute(r);
  }
  stdout.writeln('TOTAL (${chemins.length} entrée(s)) : ${total.resume}');
  stdout.writeln(total.equivalent
      ? 'Équivalence : aucune détection changée hors des coupures.'
      : 'Équivalence ROMPUE : ${total.differents} document(s) sans coupure '
          'différent(s), ${total.perdues} détection(s) perdue(s), '
          '${total.nouvellesHors} nouvelle(s) hors coupure.');
}

/// Identifiants synthétiques à clé calculée (jamais copiés d'une source
/// réelle), mêmes règles que `bench/generate_corpus.py`.
String _luhn(String corps) {
  var somme = 0;
  for (var i = 0; i < corps.length; i++) {
    var c = corps.codeUnitAt(corps.length - 1 - i) - 0x30;
    if (i.isEven) {
      c *= 2;
      if (c > 9) c -= 9;
    }
    somme += c;
  }
  return '$corps${(10 - somme % 10) % 10}';
}

String _chiffres(Random r, int n) =>
    [for (var i = 0; i < n; i++) r.nextInt(10)].join();

String _deux(int n) => n.toString().padLeft(2, '0');
String _trois(int n) => n.toString().padLeft(3, '0');

final Map<String, String Function(Random)> _fabriques = {
  'nir': (r) {
    final corps = '${1 + r.nextInt(2)}${_deux(r.nextInt(100))}'
        '${_deux(1 + r.nextInt(12))}${_deux(21 + r.nextInt(75))}'
        '${_trois(1 + r.nextInt(989))}${_trois(1 + r.nextInt(999))}';
    return '$corps${_deux(97 - int.parse(corps) % 97)}';
  },
  'rpps': (r) => _luhn('1${_chiffres(r, 9)}'),
  'iban': (r) {
    final bban = _chiffres(r, 23);
    // « FR00 » déplacé en fin et converti : F = 15, R = 27.
    final cle =
        BigInt.from(98) - BigInt.parse('${bban}152700') % BigInt.from(97);
    return 'FR${_deux(cle.toInt())}$bban';
  },
  'finess': (r) => _luhn('${_deux(1 + r.nextInt(95))}${_chiffres(r, 6)}'),
};

/// Tire un identifiant que son détecteur trouve en entier quand il est seul
/// sur sa ligne : le banc ne mesure ensuite que l'effet du voisinage.
Future<String> _tire(String type, Random r) async {
  for (;;) {
    final id = _fabriques[type]!(r);
    final texte = '${type.toUpperCase()} $id';
    final debut = texte.length - id.length;
    for (final v in await _detecteComplet(texte)) {
      final d = jsonDecode(v) as List;
      if (d[0] == type && d[1] == debut && d[2] == texte.length) return id;
    }
  }
}

/// Cas de voisinage : c'est là qu'un collage peut **retirer** une détection
/// (l'identifiant complet reçoit des chiffres voisins). Aucun corpus du dépôt
/// ne contient ces formes ; elles sont tirées ici, graine 42, 500 par forme
/// et par type.
Future<void> _voisinage() async {
  const tirages = 500;
  final formes = <String, Future<String> Function(String, Random)>{
    'identifiant puis ligne « N comprimés »': (t, r) async =>
        '${t.toUpperCase()} ${await _tire(t, r)}\n'
        '${1 + r.nextInt(9999)} comprimés le matin.\n',
    'identifiant puis ligne qui commence par une date': (t, r) async =>
        '${t.toUpperCase()} ${await _tire(t, r)}\n'
        '${_deux(1 + r.nextInt(28))}/${_deux(1 + r.nextInt(12))}/2026 : '
        'visite prévue.\n',
    'ligne finie par un nombre puis identifiant': (t, r) async =>
        'Chambre ${1 + r.nextInt(999)}\n'
        '${await _tire(t, r)} (${t.toUpperCase()})\n',
    'colonne de 2 identifiants': (t, r) async => '${t.toUpperCase()} :\n'
        '${await _tire(t, r)}\n${await _tire(t, r)}\n',
    'colonne de 10 identifiants': (t, r) async => '${t.toUpperCase()} :\n'
        '${[for (var i = 0; i < 10; i++) await _tire(t, r)].join('\n')}\n',
  };
  final total = _Equivalence();
  for (final forme in formes.entries) {
    for (final type in _fabriques.keys) {
      final alea = Random(42);
      final r = _Equivalence();
      for (var i = 0; i < tirages; i++) {
        await _compare(r, '$type-$i', await forme.value(type, alea));
      }
      // Les positions « à voir » d'un tirage ne servent à personne.
      r.aVoir.clear();
      stdout.writeln('voisinage, ${forme.key}, $type : $tirages tirages ; '
          'sans coupure ${r.sansCoupure} (identiques ${r.identiques}) ; avec '
          'coupure ${r.avecCoupure} : détections d\'origine ${r.origine}, '
          'conservées ${r.conservees}, remplacées ${r.remplacees}, perdues '
          '${r.perdues} ; nouvelles : '
          '${r.traversantes} traversant une coupure${r.types}, '
          '${r.nouvellesHors} hors coupure');
      total.ajoute(r);
    }
  }
  stdout.writeln('TOTAL voisinage : ${total.docs} tirages ; sans coupure '
      '${total.sansCoupure} (identiques ${total.identiques}) ; avec coupure '
      '${total.avecCoupure} : détections d\'origine ${total.origine}, '
      'conservées ${total.conservees}, remplacées ${total.remplacees}, '
      'perdues ${total.perdues} ; nouvelles : '
      '${total.traversantes} traversant une coupure${total.types}, '
      '${total.nouvellesHors} hors coupure');
}

// ---------------------------------------------------------------------------
// P2-171, point 4 du plan de P2-162 § 5 : coût en temps.
// ---------------------------------------------------------------------------

/// Meilleur de trois essais, en microsecondes (méthode de P2-100).
Future<int> _chrono(Future<void> Function() f) async {
  var meilleur = 1 << 62;
  for (var i = 0; i < 3; i++) {
    final s = Stopwatch()..start();
    await f();
    s.stop();
    meilleur = min(meilleur, s.elapsedMicroseconds);
  }
  return meilleur;
}

String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

/// Page ordinaire : phrases synthétiques, un identifiant valide toutes les
/// dix lignes, coupé en deux lignes une fois sur deux.
Future<String> _page(int lignes) async {
  final alea = Random(42);
  const phrases = [
    'Le résident a bien dormi et pris son petit déjeuner.',
    'Transmission du matin : rien à signaler.',
    'Rendez-vous de suivi prévu dans la semaine.',
    'Chambre 12',
    '3 comprimés le soir pendant 5 jours.',
    'Poids stable, tension 12/8.',
  ];
  final types = _fabriques.keys.toList();
  final sb = StringBuffer();
  for (var i = 0; i < lignes; i++) {
    if (i % 10 == 9) {
      final type = types[(i ~/ 10) % types.length];
      final id = await _tire(type, alea);
      final coupe = (i ~/ 10).isOdd ? id.length ~/ 2 : -1;
      sb.writeln(coupe < 0
          ? '${type.toUpperCase()} $id'
          : '${type.toUpperCase()} ${id.substring(0, coupe)}\n'
              '${id.substring(coupe)}');
    } else {
      sb.writeln(phrases[i % phrases.length]);
    }
  }
  return sb.toString();
}

Future<void> _cout({required bool petit}) async {
  final echelle = petit ? 100 : 1;
  final entrees = <String, Future<String> Function(int)>{
    'page ordinaire (lignes)': _page,
    'adversarial « chiffre, fin de ligne » (caractères)': (n) async =>
        '7\n' * (n ~/ 2),
    'adversarial « chiffre, blancs, fin de ligne, blancs » (caractères)':
        (n) async => '7 \n ' * (n ~/ 4),
    'adversarial lignes de 60 chiffres (caractères)': (n) async =>
        '${'1234567890' * 6}\n' * (n ~/ 61),
    'adversarial « 9 chiffres, fin de ligne » (caractères)': (n) async =>
        '123456789\n' * (n ~/ 10),
  };
  // Au-delà, la taille suivante n'est pas lancée : le banc dit « abandonné »
  // au lieu de tourner sans fin sur un coût superlinéaire.
  const plafondMicros = 60 * 1000 * 1000;
  for (final e in entrees.entries) {
    final tailles = e.key.startsWith('page')
        ? [1000, 10000, 100000]
        : [100000, 200000, 400000];
    int? precedentRecollage, precedentDetection, precedenteTaille;
    for (final brute in tailles) {
      final taille = brute ~/ echelle;
      if (precedentDetection != null &&
          precedentDetection * (taille / precedenteTaille!) * 4 >
              plafondMicros) {
        stdout.writeln('coût, ${e.key} $taille : abandonné (la taille '
            'précédente laisse prévoir plus de 60 s)');
        break;
      }
      final texte = await e.value(taille);
      late String recolle;
      late int coupures;
      final tRecollage = await _chrono(() async {
        final (r, _, d) = _recolle(texte);
        recolle = r;
        coupures = d.length;
      });
      final tOrigine = await _chrono(() async => _detecte(texte));
      final tRecolle = await _chrono(() async => _detecte(recolle));
      final rapportTaille =
          precedenteTaille == null ? null : taille / precedenteTaille;
      String rapport(int? avant, int maintenant) => avant == null
          ? ''
          : ' (×${(maintenant / max(avant, 1)).toStringAsFixed(1)} pour '
              '×${rapportTaille!.toStringAsFixed(0)} en taille)';
      stdout.writeln('coût, ${e.key} $taille : ${texte.length} car., '
          '$coupures coupures ; recollage ${_ms(tRecollage)} ms'
          '${rapport(precedentRecollage, tRecollage)} ; détection sur '
          'l\'origine ${_ms(tOrigine)} ms ; détection sur le texte recollé '
          '${_ms(tRecolle)} ms${rapport(precedentDetection, tRecolle)}');
      precedentRecollage = tRecollage;
      precedentDetection = tRecolle;
      precedenteTaille = taille;
    }
  }
}
