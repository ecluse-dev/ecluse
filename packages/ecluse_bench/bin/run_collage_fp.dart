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
Future<void> main(List<String> args) async {
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
