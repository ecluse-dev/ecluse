import 'dart:convert';
import 'dart:io';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';

/// Code postal en tête de texte, de ligne ou de phrase (P2-177).
///
/// Deux mesures, sur le chemin **`Ecluse.redact`** (ce que reçoit le LLM) :
///
/// 1. sur un corpus d'adresses annotées
///    (`bench/generate_corpus_cp_tete.py`), le nombre d'adresses laissées en
///    clair, en tout ou en partie ;
/// 2. avec `--regle-candidate <temoin.jsonl>`, ce que ferait une règle qui
///    écarterait un nombre de cinq chiffres en tête suivi d'un nom **lui-même
///    suivi d'un mot en minuscules** (« 58699 Alpha livrés ») : combien de
///    prédictions à tort elle retire du témoin sans adresse
///    (`bench/generate_corpus_cinq_chiffres.py`), et combien d'adresses du
///    corpus annoté elle ferait partir en clair (« 25000 Besançon depuis
///    2019 »). La règle est **simulée ici, dans le banc** : elle n'existe pas
///    dans `lib/`. Elle sert à dire, chiffres à l'appui, si les deux formes se
///    séparent.
///
/// Aucune valeur du texte n'est imprimée : seulement des comptes par axe.
///
/// Usage :
///   dart run bin/run_cp_tete_bench.dart <adresses.jsonl>
///       [--regle-candidate <temoin.jsonl>]
Future<void> main(List<String> args) async {
  final i = args.indexOf('--regle-candidate');
  final temoin = i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  final reste = [
    for (var k = 0; k < args.length; k++)
      if (i < 0 || (k != i && k != i + 1)) args[k],
  ];
  if (reste.length != 1 || (i >= 0 && temoin == null)) {
    stderr.writeln('Usage : run_cp_tete_bench <adresses.jsonl> '
        '[--regle-candidate <temoin.jsonl>]');
    exit(64);
  }

  // 1. Adresses annotées : laissées en clair par Ecluse.redact.
  var adresses = 0, enClair = 0, perdues = 0, refus = 0;
  final parAxe = <String, List<int>>{}; // axe -> [adresses, en clair, perdues]
  for (final d in _lis(reste[0])) {
    final texte = d['text'] as String;
    final RedactResult r;
    try {
      r = await Ecluse.redact(texte);
    } on TableauAmbiguException {
      // Refus explicite (règle 4) : rien n'est envoyé, donc rien ne part en
      // clair. Compté à part, comme dans `run_redact_bench.dart`.
      refus++;
      continue;
    }
    for (final a in (d['entities'] as List).cast<Map<String, dynamic>>()) {
      if (a['type'] != 'adresse') continue;
      final debut = a['start'] as int, fin = a['end'] as int;
      adresses++;
      final clair = !_couverte(texte, debut, fin, r.entities);
      // L'adresse est perdue par la règle candidate si, une fois retirées les
      // prédictions que la règle écarte, elle n'est plus couverte.
      final perdue = !clair &&
          !_couverte(texte, debut, fin, [
            for (final e in r.entities)
              if (!_regleCandidate(texte, e)) e,
          ]);
      if (clair) enClair++;
      if (perdue) perdues++;
      for (final axe in ['position', 'suite', 'casse']) {
        if (d[axe] == null) continue;
        final c = parAxe.putIfAbsent('$axe=${d[axe]}', () => [0, 0, 0]);
        c[0]++;
        if (clair) c[1]++;
        if (perdue) c[2]++;
      }
    }
  }
  stdout.writeln('code postal en tête : $adresses adresses, $enClair '
      'laissée(s) en clair par Ecluse.redact (chemin du produit)');
  if (refus > 0) {
    stdout.writeln('  documents refusés (rien n\'est envoyé), hors compte : '
        '$refus');
  }
  for (final cle in parAxe.keys.toList()..sort()) {
    final c = parAxe[cle]!;
    stdout.writeln('  $cle : ${c[1]} / ${c[0]} en clair');
  }
  if (temoin == null) return;

  // 2. Règle candidate, simulée : prédictions à tort retirées du témoin,
  // adresses que la même règle ferait partir en clair.
  var predictions = 0, ecartees = 0, enTete = 0, ecarteesEnTete = 0;
  for (final d in _lis(temoin)) {
    final texte = d['text'] as String;
    final RedactResult r;
    try {
      r = await Ecluse.redact(texte);
    } on TableauAmbiguException {
      continue;
    }
    for (final e in r.entities.where((e) => e.type == EntityType.adresse)) {
      predictions++;
      final tete = d['position'] == 'debut';
      if (tete) enTete++;
      if (_regleCandidate(texte, e)) {
        ecartees++;
        if (tete) ecarteesEnTete++;
      }
    }
  }
  stdout.writeln('règle candidate « nom suivi d\'un mot en minuscules » '
      '(simulée dans le banc, absente de lib/) :');
  stdout.writeln('  témoin sans adresse : $ecartees prédiction(s) à tort '
      'écartée(s) sur $predictions (en tête : $ecarteesEnTete sur $enTete)');
  stdout.writeln('  adresses annotées : $perdues perdue(s) sur $adresses '
      '(partiraient en clair)');
  for (final cle in parAxe.keys.toList()..sort()) {
    final c = parAxe[cle]!;
    if (c[2] > 0) stdout.writeln('    $cle : ${c[2]} / ${c[0]} perdue(s)');
  }
}

Iterable<Map<String, dynamic>> _lis(String chemin) sync* {
  for (final ligne in File(chemin).readAsLinesSync()) {
    if (ligne.trim().isEmpty) continue;
    yield jsonDecode(ligne) as Map<String, dynamic>;
  }
}

final RegExp _blanc = RegExp(r'\s');

/// Vrai si chaque caractère hors blancs de `[debut, fin)` est sous une
/// détection, quel qu'en soit le type : c'est ce qui ne part pas en clair.
bool _couverte(
    String texte, int debut, int fin, Iterable<DetectedEntity> entites) {
  for (var p = debut; p < fin; p++) {
    if (_blanc.hasMatch(texte[p])) continue;
    if (!entites.any((e) => e.start <= p && p < e.end)) return false;
  }
  return true;
}

final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);

/// Le nombre ouvre le texte, une ligne ou une phrase.
final RegExp _enTete = RegExp(r'(?:^|\n|[.!?…])[ \t  ]*$');

const String _connecteur =
    "(?:(?:de|du|des|la|le|les|en|sur|sous|lès|lez|aux)[ -]|[dl]['’])";

/// Texte en casse ordinaire : le nom est un mot à majuscule, prolongé par
/// d'autres mots à majuscule (connecteurs en minuscules tolérés), puis vient
/// un mot en minuscules sur la même ligne.
final RegExp _suiteOrdinaire = RegExp(
    r'^\d{5}[ \t  ]+\p{Lu}[\p{L}’'
    "'"
    r'-]*'
    '(?:[ -]$_connecteur?\\p{Lu}[\\p{L}’\'-]*)*'
    r'[ \t  ]+\p{Ll}',
    unicode: true);

/// Texte sans aucune majuscule : le nom est le premier mot (prolongé par
/// connecteur, « port sur saone »), puis vient un autre mot.
final RegExp _suiteMinuscules = RegExp(
    r'^\d{5}[ \t  ]+[\p{L}’'
    "'"
    r'-]+'
    '(?:[ -]$_connecteur[\\p{L}’\'-]+)*'
    r'[ \t  ]+\p{Ll}',
    unicode: true);

/// La règle candidate : une adresse prédite qui commence par un code postal
/// en tête (texte, ligne ou phrase) et dont le nom est suivi, sur la même
/// ligne, d'un mot en minuscules.
bool _regleCandidate(String texte, DetectedEntity e) {
  if (e.type != EntityType.adresse) return false;
  if (!_enTete.hasMatch(texte.substring(0, e.start))) return false;
  final finDeLigne = texte.indexOf('\n', e.start);
  final ligne = texte.substring(e.start, finDeLigne < 0 ? null : finDeLigne);
  return (_majuscule.hasMatch(texte) ? _suiteOrdinaire : _suiteMinuscules)
      .hasMatch(ligne);
}
