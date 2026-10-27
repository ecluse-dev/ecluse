/// Tableau CSV à en-tête (P2-61) : les colonnes « Nom », « Prénom »… de
/// l'en-tête désignent des personnes, quelle que soit la valeur des cellules.
///
/// Fonction pure sur le texte : elle ne réécrit rien, elle renvoie des
/// intervalles du texte d'origine. Un tableau reconnu mais incohérent (ligne qui
/// n'a pas le nombre de colonnes de l'en-tête, guillemet non fermé) est refusé
/// par [TableauAmbiguException] : lire de travers un tableau de noms et rendre
/// « rien à masquer » serait un échec silencieux.
library;

/// Levée quand un tableau à en-tête de noms est ambigu. Le message donne la
/// ligne et le motif, jamais le contenu d'une cellule.
final class TableauAmbiguException implements Exception {
  const TableauAmbiguException(this.ligne, this.motif);

  /// Numéro de la ligne fautive (à partir de 1).
  final int ligne;

  /// Motif du refus.
  final String motif;

  @override
  String toString() => 'TableauAmbiguException : ligne $ligne : $motif ; '
      'envoi refusé (tableau de noms ambigu).';
}

/// Intervalle `[start, end)` d'une cellule de nom dans le texte d'origine.
typedef CelluleNom = ({int start, int end});

const _separateurs = [';', '\t', '|', ','];

const _colonnesDeNoms = {
  'nom', 'prenom', 'prenoms', 'nomdenaissance', 'nomdusage', 'nomdefamille',
  'nompatient', 'nomdupatient', 'nomnaissance', 'nomusage', 'nomepouse',
  'lastname', 'firstname', 'surname', 'familyname', 'givenname', 'nomprenom', //
};

const _sansValeur = {
  'null', 'none', 'nan', 'inconnu', 'inconnue', 'vide', 'na', 'nc', 'nr', //
};

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', //
};

String _normalise(String s) {
  final sb = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final m = _accents[c] ?? c;
    if (RegExp(r'^[a-z]$').hasMatch(m)) sb.write(m);
  }
  return sb.toString();
}

/// Découpe une ligne `[debut, fin)` en cellules, en respectant les guillemets
/// doublés. Renvoie `null` si un guillemet reste ouvert.
List<CelluleNom>? _cellules(String text, int debut, int fin, String sep) {
  final cellules = <CelluleNom>[];
  var depart = debut;
  var entre = false;
  for (var i = debut; i < fin; i++) {
    final c = text[i];
    if (c == '"') {
      entre = !entre;
    } else if (!entre && c == sep) {
      cellules.add((start: depart, end: i));
      depart = i + 1;
    }
  }
  if (entre) return null;
  cellules.add((start: depart, end: fin));
  return cellules;
}

/// Rogne les blancs et les guillemets d'une cellule.
CelluleNom _interieur(String text, CelluleNom c) {
  var s = c.start;
  var e = c.end;
  while (s < e && (text[s] == ' ' || text[s] == '\t')) {
    s++;
  }
  while (e > s && (text[e - 1] == ' ' || text[e - 1] == '\t')) {
    e--;
  }
  if (e - s >= 2 && text[s] == '"' && text[e - 1] == '"') {
    s++;
    e--;
  }
  return (start: s, end: e);
}

/// Cellules de noms de tous les tableaux à en-tête de [text].
List<CelluleNom> cellulesDeNoms(String text) {
  // Découpe en lignes sans copier le texte.
  final lignes = <CelluleNom>[];
  var debut = 0;
  while (debut <= text.length) {
    var fin = text.indexOf('\n', debut);
    if (fin == -1) fin = text.length;
    var e = fin;
    if (e > debut && text[e - 1] == '\r') e--;
    lignes.add((start: debut, end: e));
    debut = fin + 1;
  }

  final sortie = <CelluleNom>[];
  var i = 0;
  while (i < lignes.length) {
    final entete = _entete(text, lignes[i]);
    if (entete == null || i + 1 >= lignes.length) {
      i++;
      continue;
    }
    final (sep, colonnes, nbColonnes) = entete;
    // Première ligne de données : elle doit avoir la forme de l'en-tête, sinon
    // ce n'est pas un tableau (phrase qui commence par « Nom, prénom… »).
    final premiere =
        _cellules(text, lignes[i + 1].start, lignes[i + 1].end, sep);
    if (premiere == null || premiere.length != nbColonnes) {
      i++;
      continue;
    }
    var j = i + 1;
    for (; j < lignes.length; j++) {
      final l = lignes[j];
      if (l.start == l.end) break; // ligne vide : fin du tableau
      final cells = _cellules(text, l.start, l.end, sep);
      if (cells == null) {
        throw TableauAmbiguException(j + 1, 'guillemet non fermé');
      }
      if (cells.length != nbColonnes) {
        // Une ligne sans séparateur est du texte qui suit le tableau.
        if (cells.length == 1) break;
        throw TableauAmbiguException(
          j + 1,
          '${cells.length} colonnes au lieu de $nbColonnes',
        );
      }
      for (final k in colonnes) {
        final c = _interieur(text, cells[k]);
        if (c.end <= c.start) continue;
        final valeur = text.substring(c.start, c.end);
        final n = _normalise(valeur);
        if (n.isEmpty ||
            _sansValeur.contains(n) ||
            _colonnesDeNoms.contains(n)) {
          continue;
        }
        if (valeur.length > 60) continue;
        sortie.add(c);
      }
    }
    i = j;
  }
  return sortie;
}

/// Reconnaît un en-tête : au moins 2 champs courts dont un nom de colonne de
/// personne. Renvoie le séparateur, les index des colonnes de noms et le
/// nombre de colonnes.
(String, List<int>, int)? _entete(String text, CelluleNom ligne) {
  if (ligne.end - ligne.start > 400) return null;
  for (final sep in _separateurs) {
    if (!text.substring(ligne.start, ligne.end).contains(sep)) continue;
    final cells = _cellules(text, ligne.start, ligne.end, sep);
    if (cells == null || cells.length < 2) continue;
    final colonnes = <int>[];
    var courts = true;
    for (var k = 0; k < cells.length; k++) {
      final c = _interieur(text, cells[k]);
      if (c.end - c.start > 40) courts = false;
      if (_colonnesDeNoms
          .contains(_normalise(text.substring(c.start, c.end)))) {
        colonnes.add(k);
      }
    }
    if (courts && colonnes.isNotEmpty) return (sep, colonnes, cells.length);
  }
  return null;
}
