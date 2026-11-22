/// Lexique optionnel de formes verbales pour Écluse (P2-251).
///
/// **Ce paquet est sous LGPL-LR** (voir `LICENSE` du paquet), comme le fichier
/// `assets/formes_verbales.txt.gz` qu'il sait lire, dérivé de Morphalou 3.1
/// (ATILF, CNRS - Université de Lorraine). Le cœur d'Écluse et `ecluse_redact`
/// restent sous Apache 2.0 : ils n'importent **jamais** ce paquet et ne
/// reçoivent qu'un ensemble de mots (`Ecluse.redact(formesVerbales: …)`).
///
/// Le fichier est **remplaçable** par l'utilisateur (LGPL-LR § 4b) : [charger]
/// lit n'importe quel fichier au même format (une forme par ligne, minuscules,
/// lignes `#` ignorées, gzip si le nom finit par `.gz`).
library;

import 'dart:convert';
import 'dart:io';

/// Ensemble de formes verbales chargé par l'application.
final class FormesVerbales {
  FormesVerbales._(this.formes);

  /// Formes verbales, en minuscules, accents conservés.
  final Set<String> formes;

  /// Nombre de formes.
  int get nombre => formes.length;

  /// Lit un lexique depuis son [texte] : une forme par ligne, blancs de bord
  /// retirés, lignes vides et lignes commençant par `#` ignorées.
  ///
  /// Refus explicite plutôt qu'un lexique vide silencieux : un texte sans
  /// aucune forme lève [FormatException] (le message ne cite aucune ligne).
  factory FormesVerbales.depuisTexte(String texte) {
    final formes = <String>{};
    for (final ligne in const LineSplitter().convert(texte)) {
      final forme = ligne.trim();
      if (forme.isEmpty || forme.startsWith('#')) continue;
      formes.add(forme);
    }
    if (formes.isEmpty) {
      throw const FormatException(
          'lexique de formes verbales vide ou illisible');
    }
    return FormesVerbales._(formes);
  }

  /// Charge le fichier [chemin] (gzip si le nom finit par `.gz`).
  ///
  /// Lève [FileSystemException] si le fichier manque, [FormatException] s'il
  /// n'est pas du texte UTF-8 valide ou ne contient aucune forme.
  static Future<FormesVerbales> charger(String chemin) async {
    final brut = await File(chemin).readAsBytes();
    final octets = chemin.endsWith('.gz') ? gzip.decode(brut) : brut;
    return FormesVerbales.depuisTexte(utf8.decode(octets));
  }
}
