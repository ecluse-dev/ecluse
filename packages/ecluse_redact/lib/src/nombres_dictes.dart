part of 'ecluse.dart';

// Nombres dictés en lettres (P2-267, spec `agent/specs/P2-155.md`, décisions
// du 23 novembre 2026).
//
// Un identifiant dicté puis transcrit en toutes lettres (« un neuf trois zéro
// huit… ») ne contient aucun chiffre : aucun détecteur ne le voit. Cette
// « seconde vue » lit les suites de mots-nombres, les convertit en chiffres
// *dans une copie de travail*, laisse les détecteurs habituels les valider,
// puis ramène chaque détection aux bornes des mots d'origine. Le texte de
// l'utilisateur n'est jamais réécrit (règle 3) et, sur un texte sans suite de
// mots-nombres, ce code ne renvoie rien : le résultat est celui d'avant.
//
// Pourquoi une copie de travail par suite et par lecture plutôt qu'une vue du
// texte entier : la conversion change la longueur dans les deux sens, et une
// suite se lit de plusieurs façons (« quatre vingt dix » = 90 ou 4 · 20 · 10).
// Seule la clé de contrôle d'un détecteur (mod 97, Luhn, longueur) arbitre ;
// aucune lecture validée, aucune détection (jamais de « rien à masquer » en
// silence : voir [_suitesNonReconnues]).
//
// Aucune valeur tirée du texte n'est jamais mise dans une exception, un
// `toString` ou une sortie console ici.

/// Nombre minimal de mots-nombres consécutifs pour tenter une lecture (point 2
/// des décisions du 23 novembre). Un mot-nombre isolé (« un », « six »,
/// « cent ») est un mot de la langue : jamais converti seul.
const int _kSuite = 6;

/// Même seuil quand la suite suit un mot-clé d'identifiant (« NIR »,
/// « sécu », « RPPS »…).
const int _kSuiteMotCle = 3;

/// Une suite d'au moins ce nombre de mots-nombres qu'aucune lecture ne valide
/// est signalée à l'utilisateur (option B de la spec § 6).
const int _kSuiteNonReconnue = 9;

/// Borne dure du nombre de lectures essayées par suite (spec § 4.3).
const int _kLecturesMax = 64;

/// Au-delà, une suite est découpée en fenêtres qui se recouvrent : le coût
/// reste linéaire (aucun détecteur n'est lancé sur des centaines de milliers
/// de chiffres).
const int _kFenetre = 240;
const int _kRecouvrement = 100;

/// Budget de caractères de chiffres traités par suite et par fenêtre, toutes
/// lectures confondues.
const int _kBudgetChiffres = 8000;

/// Validations sans clé forte (Luhn seul : un faux accord sur dix) : une
/// lecture ne les valide que derrière un mot-clé d'identifiant. NIR et IBAN
/// (clé mod 97) n'en ont pas besoin.
const Set<EntityType> _typesFaibles = {
  EntityType.rpps,
  EntityType.finess,
  EntityType.adeli,
  EntityType.telephone,
  EntityType.siren,
};

const Set<EntityType> _typesValidants = {
  EntityType.nir,
  EntityType.rpps,
  EntityType.iban,
  EntityType.finess,
  EntityType.siren,
  EntityType.adeli,
  EntityType.telephone,
};

/// Minuscules sans accent (usage : comparaison de mots-nombres uniquement).
String _mot(String s) {
  final b = StringBuffer();
  for (final u in s.runes) {
    final c = String.fromCharCode(u).toLowerCase();
    switch (c) {
      case 'é':
      case 'è':
      case 'ê':
      case 'ë':
        b.write('e');
      case 'à':
      case 'â':
        b.write('a');
      case 'ô':
        b.write('o');
      case 'î':
      case 'ï':
        b.write('i');
      case 'û':
      case 'ù':
        b.write('u');
      case 'ç':
        b.write('c');
      case 'œ':
        b.write('oe');
      default:
        b.write(c);
    }
  }
  return b.toString();
}

const Map<String, int> _unitesDictees = {
  'zero': 0,
  'un': 1,
  'une': 1,
  'deux': 2,
  'trois': 3,
  'quatre': 4,
  'cinq': 5,
  'six': 6,
  'sept': 7,
  'huit': 8,
  'neuf': 9,
  'dix': 10,
  'onze': 11,
  'douze': 12,
  'treize': 13,
  'quatorze': 14,
  'quinze': 15,
  'seize': 16,
};

const Map<String, int> _dizainesDictees = {
  'vingt': 20,
  'vingts': 20,
  'trente': 30,
  'quarante': 40,
  'cinquante': 50,
  'soixante': 60,
  'septante': 70,
  'huitante': 80,
  'nonante': 90,
};

/// Mots d'un identifiant dicté : « o » dit le zéro, « double » et « triple »
/// répètent le chiffre suivant.
bool _estMotNombre(String m) =>
    _unitesDictees.containsKey(m) ||
    _dizainesDictees.containsKey(m) ||
    m == 'cent' ||
    m == 'cents' ||
    m == 'double' ||
    m == 'triple' ||
    m == 'o';

/// Mots-clés qui abaissent le seuil de la suite (comparés sans accent).
final RegExp _motCle = RegExp(
    r'(?:nir|secu|securite sociale|rpps|iban|finess|siren|siret|adeli|'
    r'telephone|portable)\W{0,3}(?:(?:est|numero|n|no|de|du|la|le)\W+){0,2}$');

/// « fr » en fin de contexte, suivi d'espaces : à coller aux chiffres.
final RegExp _collerFr =
    RegExp(r'(?:^|[^A-Za-z])(?:[Ff][Rr])([ \u00A0\t\-]*)$');

bool _estSeparateur(int c) =>
    c == 0x20 ||
    c == 0xA0 ||
    c == 0x09 ||
    c == 0x2D ||
    c == 0x2C ||
    (c >= 0x2010 && c <= 0x2013);

bool _estLettre(int c) =>
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    (c >= 0xC0 && c <= 0x24F && c != 0xD7 && c != 0xF7) ||
    c == 0x153 ||
    c == 0x152;

bool _estChiffre(int c) => c >= 0x30 && c <= 0x39;

/// Un jeton du texte : mot ou nombre en chiffres, avec ses bornes d'origine.
class _Jeton {
  _Jeton(this.debut, this.fin, this.mot, this.chiffres, {this.lettre = false});

  /// Lettre isolée épelée dans un IBAN (« fr … h … ») ou une région corse
  /// (« douze a ») : recopiée telle quelle, en majuscule ([chiffres]).
  final bool lettre;
  final int debut;
  final int fin;

  /// Mot normalisé (minuscules, sans accent), `''` pour un nombre en chiffres.
  final String mot;

  /// Nombre en chiffres tel qu'écrit, `null` pour un mot.
  final String? chiffres;
}

/// Une suite de jetons consécutifs, tous mots-nombres, « et » interne ou
/// nombres en chiffres.
class _Suite {
  _Suite(this.jetons, this.mots);
  final List<_Jeton> jetons;

  /// Nombre de mots-nombres (hors « et » et hors chiffres).
  final int mots;

  int get debut => jetons.first.debut;
  int get fin => jetons.last.fin;
}

/// Découpe [text] en suites de mots-nombres (au moins [kMin] mots, ou
/// [kMotCle] derrière un mot-clé d'identifiant). Linéaire.
List<_Suite> _suitesDeMotsNombres(String text,
    {int kMin = _kSuite, int kMotCle = _kSuiteMotCle}) {
  final suites = <_Suite>[];
  var courante = <_Jeton>[];
  var mots = 0;
  var finPrecedent = -1;
  // Dernier mot rencontré (hors suite) : « fr » devant une suite ouvre le
  // contexte IBAN, où les lettres du numéro de compte sont épelées.
  var motAvant = '';
  var finMotAvant = -1;
  var contexteIban = false;

  void clore() {
    if (courante.isNotEmpty) {
      // Un « et » en tête ou en queue n'appartient pas à la suite.
      while (courante.isNotEmpty &&
          (courante.last.mot == 'et' || courante.last.lettre)) {
        courante.removeLast();
      }
      if (courante.isNotEmpty && mots >= kMotCle) {
        final seuil =
            _precedeParMotCle(text, courante.first.debut) ? kMotCle : kMin;
        if (mots >= seuil) suites.add(_Suite(courante, mots));
      }
    }
    courante = <_Jeton>[];
    mots = 0;
  }

  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (_estLettre(c)) {
      var j = i + 1;
      while (j < n && _estLettre(text.codeUnitAt(j))) {
        j++;
      }
      final longueur = j - i;
      final m = longueur <= 12 ? _mot(text.substring(i, j)) : '';
      final nombre = m.isNotEmpty && _estMotNombre(m);
      final et = m == 'et';
      final lettreIban = !nombre &&
          !et &&
          longueur == 1 &&
          courante.isNotEmpty &&
          (contexteIban ||
              ((m == 'a' || m == 'b') && _estMotNombre(courante.last.mot))) &&
          _gapSeparateur(text, finPrecedent, i);
      if (lettreIban) {
        courante.add(_Jeton(i, j, '', m.toUpperCase(), lettre: true));
        finPrecedent = j;
      } else if (nombre || et) {
        if (courante.isNotEmpty && !_gapSeparateur(text, finPrecedent, i)) {
          clore();
        }
        if (courante.isEmpty) {
          contexteIban =
              motAvant == 'fr' && _gapSeparateur(text, finMotAvant, i);
        }
        if (et && courante.isEmpty) {
          // « et » ne commence jamais une suite.
        } else {
          courante.add(_Jeton(i, j, m, null));
          if (nombre) mots++;
          finPrecedent = j;
        }
      } else {
        clore();
        contexteIban = false;
        motAvant = m;
        finMotAvant = j;
      }
      i = j;
    } else if (_estChiffre(c)) {
      var j = i + 1;
      while (j < n && _estChiffre(text.codeUnitAt(j))) {
        j++;
      }
      if (courante.isNotEmpty && _gapSeparateur(text, finPrecedent, i)) {
        courante.add(_Jeton(i, j, '', text.substring(i, j)));
        finPrecedent = j;
      } else {
        clore();
      }
      i = j;
    } else {
      i++;
    }
  }
  clore();
  return suites;
}

bool _gapSeparateur(String text, int de, int a) {
  if (de < 0 || a <= de) return false;
  for (var k = de; k < a; k++) {
    if (!_estSeparateur(text.codeUnitAt(k))) return false;
  }
  return true;
}

/// Mots qui annoncent un identifiant à validation faible (Luhn seul), dans les
/// 60 caractères qui précèdent la suite, comparés sans accent. Pas de « numéro »
/// ni de « nombre » seuls : ils précèdent aussi bien un montant. Pas de « code »
/// non plus (P2-273) : « le code du coffre est… » annonce un code d'accès, et un
/// faux accord de Luhn sur dix suffisait à le masquer comme FINESS ou RPPS
/// (3 cas sur 630 phrases du témoin durci de P2-270, aucun effet sur les
/// variantes dictées).
final RegExp _motCleFaible = RegExp(
    r'\b(?:rpps|praticien|medecin|finess|structure|etablissement|siren|siret|'
    r'societe|entreprise|adeli|telephone|portable)\b');

bool _precedeParMotCleFaible(String text, int debut) {
  final from = debut > 60 ? debut - 60 : 0;
  return _motCleFaible.hasMatch(_mot(text.substring(from, debut)));
}

bool _precedeParMotCle(String text, int debut) {
  final from = debut > 48 ? debut - 48 : 0;
  final avant = _mot(text.substring(from, debut));
  return _motCle.hasMatch(avant);
}

/// Alternative de lecture à partir d'un jeton : longueur en jetons, chiffres.
typedef _Alt = (int, String);

/// Lectures possibles d'un nombre commençant au jeton [i] (jetons de [j]).
List<_Alt> _alternatives(List<_Jeton> j, int i) {
  final t = j[i];
  if (t.chiffres != null) return [(1, t.chiffres!)];
  final m = t.mot;
  final alts = <_Alt>[];

  String? mot(int k) => k < j.length && j[k].chiffres == null ? j[k].mot : null;

  int? unite(int k) => mot(k) == null ? null : _unitesDictees[mot(k)];

  // < 20 : un mot, ou « dix » + sept/huit/neuf. Rend (longueur, valeur).
  List<(int, int)> petit(int k) {
    final u = unite(k);
    if (u == null) return const [];
    final r = <(int, int)>[(1, u)];
    if (u == 10) {
      final s = unite(k + 1);
      if (s != null && s >= 7 && s <= 9) r.add((2, 10 + s));
    }
    return r;
  }

  void plus(int longueur, int valeur) => alts.add((longueur, '$valeur'));

  // Nombres de 1 à 99 à partir de i (sans zéro), pour les centaines.
  List<(int, int)> moinsDeCent(int k) {
    final r = <(int, int)>[];
    for (final (l, v) in petit(k)) {
      if (v >= 1) r.add((l, v));
    }
    final mk = mot(k);
    if (mk == null) return r;
    int? base;
    var l0 = 1;
    if (_dizainesDictees.containsKey(mk)) {
      base = _dizainesDictees[mk];
    }
    if (mk == 'quatre') {
      final s = mot(k + 1);
      if (s == 'vingt' || s == 'vingts') {
        base = 80;
        l0 = 2;
      }
    }
    if (base == null) return r;
    r.add((l0, base));
    final quatreVingt = l0 == 2;
    if (base <= 60 && mot(k + l0) == 'et') {
      final s = unite(k + l0 + 1);
      if (s == 1) r.add((l0 + 2, base + 1));
      if (base == 60 && s == 11) r.add((l0 + 2, 71));
    }
    if (base >= 70 &&
        !quatreVingt &&
        mot(k + l0) == 'et' &&
        unite(k + l0 + 1) == 1) {
      r.add((l0 + 2, base + 1));
    }
    for (final (l, v) in petit(k + l0)) {
      final etendu = base == 60 || quatreVingt;
      if (v >= 1 && v <= 9) r.add((l0 + l, base + v));
      if (etendu && v >= 10 && v <= 19) r.add((l0 + l, base + v));
    }
    return r;
  }

  // Centaines : « cent », « deux cent », puis éventuellement < 100.
  void centaine(int k, int multiplicateur, int l0) {
    plus(l0, multiplicateur * 100);
    for (final (l, v) in moinsDeCent(k + l0)) {
      plus(l0 + l, multiplicateur * 100 + v);
    }
  }

  if (m == 'cent' || m == 'cents') {
    centaine(i, 1, 1);
  }
  final u = _unitesDictees[m];
  if (u != null && u >= 2 && u <= 9) {
    final s = mot(i + 1);
    if (s == 'cent' || s == 'cents') centaine(i, u, 2);
  }
  if (m == 'double' || m == 'triple') {
    final d = unite(i + 1);
    if (d != null && d <= 9) {
      // « double zéro » garde ses zéros : du texte, pas un entier.
      alts.add((2, '$d' * (m == 'double' ? 2 : 3)));
    }
  }
  if (m == 'o') alts.add((1, '0'));
  for (final (l, v) in petit(i)) {
    plus(l, v);
  }
  for (final (l, v) in moinsDeCent(i)) {
    plus(l, v);
  }
  // Plus longue lecture d'abord, sans doublon.
  final vues = <String>{};
  final out = <_Alt>[];
  alts.sort((a, b) => b.$1 != a.$1 ? b.$1 - a.$1 : a.$2.compareTo(b.$2));
  for (final a in alts) {
    if (vues.add('${a.$1}:${a.$2}')) out.add(a);
  }
  return out;
}

/// Une lecture : les chiffres et, pour chaque chiffre, les bornes (dans le
/// texte d'origine) des mots dont il vient.
class _Lecture {
  _Lecture(this.chiffres, this.debuts, this.fins);
  final String chiffres;
  final List<int> debuts;
  final List<int> fins;
}

/// Nœud de la recherche des lectures : position, nombre de nombres lus
/// jusque-là, pièce lue (chaîne de parents).
class _NoeudLecture {
  _NoeudLecture(this.i, this.g, this.parent, this.depart, this.longueur,
      this.chiffres, this.ordre);
  final int i;
  final int g;
  final _NoeudLecture? parent;
  final int depart;
  final int longueur;
  final String chiffres;
  final int ordre;
}

/// Énumère au plus [max] lectures de [j], **la plus composée d'abord** : on
/// préfère le moins de nombres (« soixante quatre vingt quatorze » se lit
/// 60 · 94 avant 64 · 20 · 14 ; « quatre vingt dix » se lit 90 avant 4 · 20 ·
/// 10). Recherche meilleur-d'abord avec le minimum exact du reste de la suite
/// comme borne : la première lecture est la plus composée, et la borne de
/// [max] lectures ne coupe jamais la bonne au profit d'une série de variantes
/// de queue (un parcours en profondeur le ferait sur un IBAN de quarante mots).
List<_Lecture> _lectures(List<_Jeton> j, {int max = _kLecturesMax}) {
  final n = j.length;
  final alts = List<List<_Alt>?>.filled(n, null);
  List<_Alt> de(int i) =>
      alts[i] ??= j[i].mot == 'et' ? const <_Alt>[] : _alternatives(j, i);

  // Plus petit nombre de nombres pour lire j[i..] jusqu'au bout.
  final minReste = List<int>.filled(n + 1, 0);
  for (var i = n - 1; i >= 0; i--) {
    final ai = de(i);
    if (ai.isEmpty) {
      minReste[i] = minReste[i + 1];
      continue;
    }
    var meilleur = 1 << 30;
    for (final (l, _) in ai) {
      final c = 1 + minReste[i + l];
      if (c < meilleur) meilleur = c;
    }
    minReste[i] = meilleur;
  }

  // Tas binaire : plus petite borne d'abord, puis position la plus avancée.
  final tas = <_NoeudLecture>[];
  bool avant(_NoeudLecture a, _NoeudLecture b) {
    final fa = a.g + minReste[a.i], fb = b.g + minReste[b.i];
    if (fa != fb) return fa < fb;
    if (a.i != b.i) return a.i > b.i;
    return a.ordre < b.ordre;
  }

  void pousser(_NoeudLecture e) {
    tas.add(e);
    var k = tas.length - 1;
    while (k > 0) {
      final p = (k - 1) >> 1;
      if (!avant(tas[k], tas[p])) break;
      final t = tas[k];
      tas[k] = tas[p];
      tas[p] = t;
      k = p;
    }
  }

  _NoeudLecture retirer() {
    final haut = tas.first;
    final dernier = tas.removeLast();
    if (tas.isNotEmpty) {
      tas[0] = dernier;
      var k = 0;
      for (;;) {
        final g = 2 * k + 1, d = g + 1;
        var m = k;
        if (g < tas.length && avant(tas[g], tas[m])) m = g;
        if (d < tas.length && avant(tas[d], tas[m])) m = d;
        if (m == k) break;
        final t = tas[k];
        tas[k] = tas[m];
        tas[m] = t;
        k = m;
      }
    }
    return haut;
  }

  _Lecture rendre(_NoeudLecture fin) {
    final pieces = <_NoeudLecture>[];
    for (_NoeudLecture? e = fin; e != null; e = e.parent) {
      if (e.longueur > 0) pieces.add(e);
    }
    final b = StringBuffer();
    final d = <int>[];
    final f = <int>[];
    for (final e in pieces.reversed) {
      final debut = j[e.depart].debut;
      final finMot = j[e.depart + e.longueur - 1].fin;
      for (var k = 0; k < e.chiffres.length; k++) {
        b.write(e.chiffres[k]);
        d.add(debut);
        f.add(finMot);
      }
    }
    return _Lecture(b.toString(), d, f);
  }

  final out = <_Lecture>[];
  var ordre = 0;
  var pas = 0;
  final limite = max * (n + 8) * 8 + 1000;
  pousser(_NoeudLecture(0, 0, null, 0, 0, '', ordre++));
  while (tas.isNotEmpty && out.length < max && pas++ < limite) {
    final e = retirer();
    if (e.i >= n) {
      out.add(rendre(e));
      continue;
    }
    final ai = de(e.i);
    if (ai.isEmpty) {
      pousser(_NoeudLecture(e.i + 1, e.g, e, e.i, 0, '', ordre++));
      continue;
    }
    for (final (l, s) in ai) {
      pousser(_NoeudLecture(e.i + l, e.g + 1, e, e.i, l, s, ordre++));
    }
  }
  return out;
}

/// Détections de nombres dictés dans [text], aux bornes des mots d'origine.
///
/// [analyse] lance les détecteurs habituels sur un texte de travail et rend
/// leurs entités (positions de ce texte de travail). Rend une liste vide, sans
/// rien allouer d'autre qu'un parcours, quand le texte n'a aucune suite de
/// mots-nombres : le résultat est alors celui d'avant (P2-267, point 1 des
/// décisions).
Future<List<DetectedEntity>> _detecterNombresDictes(
  String text,
  Future<List<DetectedEntity>> Function(String vue) analyse,
) async {
  final suites = _suitesDeMotsNombres(text);
  if (suites.isEmpty) return const [];
  final trouvees = <DetectedEntity>[];
  for (final suite in suites) {
    final jetons = suite.jetons;
    if (jetons.length <= _kFenetre) {
      trouvees.addAll(await _lireFenetre(text, jetons, analyse));
    } else {
      var a = 0;
      while (a < jetons.length) {
        final b = a + _kFenetre < jetons.length ? a + _kFenetre : jetons.length;
        trouvees
            .addAll(await _lireFenetre(text, jetons.sublist(a, b), analyse));
        if (b >= jetons.length) break;
        a = b - _kRecouvrement;
      }
    }
  }
  return trouvees;
}

Future<List<DetectedEntity>> _lireFenetre(
  String text,
  List<_Jeton> jetons,
  Future<List<DetectedEntity>> Function(String vue) analyse,
) async {
  const contexte = 80;
  final debutSuite = jetons.first.debut;
  final finSuite = jetons.last.fin;
  final ctxD = debutSuite > contexte ? debutSuite - contexte : 0;
  final ctxF =
      finSuite + contexte < text.length ? finSuite + contexte : text.length;
  // « FR » dicté puis les chiffres de l'IBAN : le détecteur attend « FR » collé
  // aux chiffres ; l'espace est retirée de la vue de travail seulement.
  var avant = text.substring(ctxD, debutSuite);
  final collee = _collerFr.firstMatch(avant);
  if (collee != null) {
    avant = avant.substring(0, collee.end - collee.group(1)!.length);
  }
  final apres = text.substring(finSuite, ctxF);
  final motCle = _precedeParMotCleFaible(text, debutSuite);

  // Budget de chiffres : moins de lectures quand la suite est longue.
  final budget = _kBudgetChiffres ~/ (jetons.length * 2 + 1);
  final maxLectures = budget < 1
      ? 1
      : budget > _kLecturesMax
          ? _kLecturesMax
          : budget;

  for (final lecture in _lectures(jetons, max: maxLectures)) {
    if (lecture.chiffres.isEmpty) continue;
    // Une validation faible (Luhn seul) ne compte que derrière un mot-clé :
    // sans lui, un accord au hasard (un sur dix) serait quasi certain sur 64
    // lectures.
    final faibleAutorise = motCle;
    final vue = '$avant${lecture.chiffres}$apres';
    final entites = await analyse(vue);
    final dedans = avant.length;
    final fin = dedans + lecture.chiffres.length;
    final retenues = <DetectedEntity>[];
    var valide = false;
    for (final e in entites) {
      if (e.end <= dedans || e.start >= fin) continue;
      if (_typesValidants.contains(e.type) &&
          (faibleAutorise || !_typesFaibles.contains(e.type))) {
        valide = true;
      }
      retenues.add(e);
    }
    if (!valide) continue;
    // Ramène les positions de la vue de travail au texte d'origine : un
    // chiffre porte l'étendue entière des mots dont il vient.
    int debutOrigine(int p) {
      if (p < dedans) return ctxD + p;
      if (p >= fin) return finSuite + (p - fin);
      return lecture.debuts[p - dedans];
    }

    int finOrigine(int p) {
      // [p] : dernier caractère inclus.
      if (p < dedans) return ctxD + p + 1;
      if (p >= fin) return finSuite + (p - fin) + 1;
      return lecture.fins[p - dedans];
    }

    return [
      for (final e in retenues)
        if (_typesValidants.contains(e.type) &&
            (faibleAutorise || !_typesFaibles.contains(e.type)))
          () {
            final d = debutOrigine(e.start);
            final f = finOrigine(e.end - 1);
            return DetectedEntity(
              type: e.type,
              start: d,
              end: f,
              value: text.substring(d, f),
              confidence: e.confidence,
              tier: e.tier,
              provenance: e.provenance,
            );
          }()
    ];
  }
  return const [];
}

/// Positions de départ des suites d'au moins [_kSuiteNonReconnue]
/// mots-nombres qu'aucune entité de [entites] ne recouvre : « nombre dicté non
/// reconnu ». Ne renvoie que des positions, jamais de texte (point 4 des
/// décisions du 23 novembre).
List<int> _suitesNonReconnues(String text, List<DetectedEntity> entites) {
  final suites = _suitesDeMotsNombres(text,
      kMin: _kSuiteNonReconnue, kMotCle: _kSuiteNonReconnue);
  if (suites.isEmpty) return const [];
  final r = <int>[];
  var k = 0;
  for (final s in suites) {
    while (k < entites.length && entites[k].end <= s.debut) {
      k++;
    }
    final recouvert = k < entites.length && entites[k].start < s.fin;
    if (!recouvert) r.add(s.debut);
  }
  return r;
}
