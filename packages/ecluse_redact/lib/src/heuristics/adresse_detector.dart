import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_reference/ecluse_reference.dart' show normName;

import 'communes_nom_exact.dart';
import 'mots_neutres.dart';

/// Détecteur heuristique d'adresses postales simples — **v0 de
/// démonstration**.
///
/// Reconnaît deux motifs :
///
/// 1. `numéro + type de voie + nom de voie + code postal (5 chiffres) +
///    commune`, par exemple `12 rue des Lilas, 75015 Paris` → confiance
///    modérée (0.7) : le numéro et le type de voie sont un indice fort.
/// 2. `code postal (5 chiffres) + commune` **seul**, sans numéro ni type de
///    voie devant (ex. adresse sur sa propre ligne dans un formulaire :
///    `70160 Saint Rémy en Comté`) → confiance plus faible (0.55) : sans le
///    numéro/type de voie, l'indice est moins spécifique. Un code postal
///    isolé, sans nom de commune qui suit, n'est **jamais** masqué à lui
///    seul (5 chiffres seuls n'identifient personne).
///
/// Aucune validation possible dans les deux cas (pas d'annuaire des voies ni
/// des communes embarqué). Ne couvre pas les adresses sans code postal, les
/// boîtes postales, ni les formats étrangers. Sera affiné en phase 2 (NER +
/// table INSEE).
final class AdresseDetector implements EntityDetector {
  const AdresseDetector();

  @override
  EntityType get type => EntityType.adresse;

  static const _voies = [
    'rue',
    'avenue',
    'boulevard',
    'chemin',
    'impasse',
    'allée',
    'allee',
    'place',
    'route',
    'quai',
    'square',
    'passage',
    'cours',
    'lotissement',
    'chaussée',
    'chaussee',
    'faubourg',
    'esplanade',
    'villa',
    'hameau',
    'cité',
    'cite',
    // Abréviations courantes (point facultatif, voir [_voieMotif]).
    'av',
    'ave',
    'bd',
    'bvd',
    'rte',
    'fbg',
    'r',
    'pl',
    'ch',
    'imp',
    'all',
    'sq',
    'crs',
    // Autres types de voie (P2-49).
    'sentier',
    'ruelle',
    'traverse',
    'venelle',
    'parvis',
    'promenade',
    'montée',
    'montee',
    'clos',
  ];

  /// `code postal (5 chiffres) + commune`, réutilisé tel quel comme fin du
  /// motif complet et comme motif autonome pour une adresse sans numéro ni
  /// type de voie. Le premier mot de la « commune » est capturé à part
  /// (groupe nommé `commune`) pour pouvoir l'écarter s'il ressemble à une
  /// unité de mesure plutôt qu'à un nom de lieu — voir [_looksLikeUnit].
  ///
  /// Deux garde-fous généraux, indépendants de tout document précis :
  /// - `(?<!\d)` avant les 5 chiffres : un code postal est le **début**
  ///   d'une séquence de chiffres, jamais une fenêtre choisie au milieu
  ///   d'un numéro plus long (RPPS, NIR non reconnu comme tel, etc.).
  /// - `[ \t]` au lieu de `\s` entre le code postal et la commune : un
  ///   code postal et sa commune sont toujours sur la **même ligne** dans
  ///   un document réel ; `\s` matche aussi le saut de ligne, ce qui
  ///   laissait un span avaler la ligne suivante en entier.
  static const _codePostalCommune = '(?<!\\d)\\d{5}$_h+(?<commune>$_motCommune)'
      '(?:[ \\u00A0\\u202F-]$_connecteurs*(?!$_titres$_finDeTitre)$_motCommune){0,3}'
      '$_suiteDevantCedex'
      '$_suffixeCedex';

  /// Suite du nom de la commune **devant « CEDEX »** (P2-181). Le nom accepté
  /// ci-dessus s'arrête à quatre mots et à la liste courte [_connecteurs] :
  /// une commune de cinq mots en écriture postale (« SAINT LAURENT LES BAINS
  /// LAVAL D AURELLE ») ou liée par « et », « au », « à », « près »… (« Moliets
  /// et Maa ») laissait sa fin en clair, « CEDEX » et son numéro avec elle
  /// (mesure P2-178 : 132 et 604 communes du référentiel). Allonger le nom
  /// sans condition masquerait davantage le texte ordinaire qui suit une
  /// commune (« 70000 Vesoul et Besançon », « 70000 VESOUL SERVICE DES
  /// ADMISSIONS BATIMENT B » : témoin `generate_corpus_commune_suivie.py`).
  ///
  /// La borne retenue ne dépend donc pas d'une longueur : ce qui sépare un
  /// code postal du mot « CEDEX », **sur la même ligne**, est la localité.
  /// Jusqu'à cinq mots de plus (la plus longue commune du référentiel en a
  /// huit) sont pris **seulement si « CEDEX » les suit immédiatement** ; sans
  /// lui, le motif est celui d'avant, au caractère près. Une civilité arrête
  /// toujours le nom, comme plus haut.
  ///
  /// Trois formes de nom que le motif d'avant coupait, toutes **devant
  /// « CEDEX » seulement** (P2-201, classes 2 et 3 de `agent/specs/P2-196.md`) :
  /// un complément entre parenthèses du nom officiel (« CHATEAU CHINON
  /// (VILLE) »), un tiret entouré de blancs (« SARROUX - SAINT JULIEN ») et
  /// deux ou trois blancs de suite, ce que devient ce tiret quand l'écriture
  /// le retire (« SAINT PATERNE   LE CHEVAIN »). Sans « CEDEX » derrière, un
  /// tiret isolé ou une parenthèse sépare deux idées d'un texte ordinaire
  /// (« 70000 VESOUL - SERVICE DES ADMISSIONS », « 70000 VESOUL (VOIR PAGE 3) ») :
  /// le motif reste celui d'avant, au caractère près.
  static const _suiteDevantCedex =
      '(?:(?:$_separateurDevantCedex$_connecteursDevantCedex*'
      '(?!$_titres$_finDeTitre)$_motCommune|$_h*$_parentheseDevantCedex){1,5}'
      '(?=,?$_h*$_cedex))?';

  /// Séparateur de deux mots de la suite devant « CEDEX » : un blanc ou un
  /// tiret (comme avant), un tiret entouré de un à trois blancs, ou deux à trois
  /// blancs de suite. Jamais un saut de ligne ([_h] n'en contient pas).
  static const _separateurDevantCedex =
      '(?:$_h{1,3}-$_h{1,3}|$_h{2,3}|[ \\u00A0\\u202F-])';

  /// Complément du nom de commune entre parenthèses, sur la même ligne : des
  /// mots à majuscule initiale (ou nombre) et des liaisons, 41 caractères au
  /// plus. Pris seulement devant « CEDEX » ([_suiteDevantCedex]).
  static const _parentheseDevantCedex =
      "\\([A-ZÀ-ÖØ-ÞŒ][\\wÀ-ÖØ-Þà-öø-ÿœŒ'’ \\u00A0\\u202F-]{0,40}\\)";

  /// « CEDEX » et son numéro de distribution (P2-164). Le mot « CEDEX » en
  /// capitales ou « Cedex » était déjà pris comme dernier mot de la commune ;
  /// le numéro qui suit (« CEDEX 9 », « Cedex 09 ») restait en clair, comme
  /// « cedex » en minuscules ou après une virgule (mesure P2-157 : 53
  /// adresses sur 155 du corpus flou adversarial). Le numéro n'est lu
  /// qu'**après le mot « CEDEX »** et sur la même ligne, 1 ou 2 chiffres
  /// (1 à 99 ; « CEDEX 2026 dossiers », « CEDEX 9e étage » : le nombre reste
  /// en clair) : un nombre qui suit une commune sans CEDEX n'est jamais
  /// absorbé (« 70000 VESOUL 3 agents »).
  static const _suffixeCedex = '(?:(?:,?$_h*$_cedex)?(?<=$_cedex)'
      '(?:$_h+\\d{1,2}(?![\\dA-Za-zÀ-ÿ]))?)?';

  /// « cedex » dans toutes les casses (le motif d'adresse est sensible à la
  /// casse), jamais collé à une lettre qui suit.
  static const _cedex = '[Cc][Ee][Dd][Ee][Xx](?![A-Za-zÀ-ÿ])';

  /// Blanc horizontal : espace, tabulation, espace insécable (U+00A0), espace
  /// fine insécable (U+202F). Jamais un saut de ligne.
  static const _h = '[ \\t\\u00A0\\u202F]';

  /// Mot de commune : majuscule initiale (le motif est sensible à la casse,
  /// voir [_pattern]). `\w` ne couvre que l'ASCII sans le drapeau `unicode`
  /// (Dart) : les classes `À-ÖØ-Þ`/`à-öø-ÿ` ajoutent les lettres accentuées
  /// latin-1, mais s'arrêtent à `ÿ` (U+00FF) et laissent dehors la ligature
  /// « œ »/« Œ » (U+0153/U+0152, hors Latin-1) — 109 communes du référentiel
  /// (« Annœullin », « Œuilly ») perdaient leur nom à partir de cette lettre
  /// ou, en initiale, n'étaient pas reconnues comme commune du tout
  /// (P2-180, § 1).
  static const _motCommune = "[A-ZÀ-ÖØ-ÞŒ][\\wÀ-ÖØ-Þà-öø-ÿœŒ'’-]*";

  /// Petits mots **en minuscules** qui lient les parties d'un nom de commune
  /// (« Saint-Rémy en Comté », « Neuilly sur Seine », « Villeneuve d'Ascq »).
  /// Tout autre mot en minuscules arrête la commune : sinon le span avale le
  /// texte qui suit (un email, un nom) et la résolution des chevauchements
  /// supprime l'entité voisine au lieu de la masquer (fuite).
  static const _connecteurs =
      "(?:(?:de|du|des|la|le|les|en|sur|sous|lès|lez|aux)[ -]|[dl]['’])";

  /// Mots de liaison en minuscules admis **seulement devant « CEDEX »**
  /// ([_suiteDevantCedex]) : ceux de [_connecteurs], plus ceux que le balayage
  /// des communes a trouvés absents (`agent/specs/P2-178.md` § 4 : « et »,
  /// « au », « près », « di », « devant », « à », « ès », « ez », « del »,
  /// « dels », « deux », « derrière », « dit », « entre », « las »). Hors de ce
  /// contexte ils restent refusés : « 70000 Vesoul et Besançon », « 70000
  /// Vesoul à 9 h » ne sont pas un nom de commune.
  static const _connecteursDevantCedex =
      '(?:(?:de|du|des|la|le|les|en|sur|sous|lès|lez|aux|et|au|près|di|'
      "devant|à|ès|ez|del|dels|deux|derrière|dit|entre|las)[ -]|[dl]['’])";

  /// Civilités et titres qui ne sont jamais le dernier mot d'une commune :
  /// ils annoncent un nom de personne, détecté à part.
  ///
  /// Le « M » isolé derrière SAINT n'est pas une civilité : c'est la commune
  /// « Saint-M'Hervé », dont l'apostrophe est perdue à la normalisation
  /// (« 35184 SAINT M HERVE CEDEX 3 », P2-208). Un « M » après un autre mot
  /// reste un titre.
  static const _titres =
      '(?:Mme|Mlle|Mr|Madame|Monsieur|Mademoiselle|Dr|Docteur|Pr|Professeur|Me|Maître|'
      'M(?<!(?:Saint|SAINT|Sainte|SAINTE|St|ST|Ste|STE)[ \\u00A0\\u202F-]+M))';

  /// Fin de mot après un titre (« M », « Pr »…), équivalent de `\b` mais qui
  /// tient compte des lettres accentuées : `\b` de Dart se fonde sur `\w`
  /// ASCII (sans drapeau `unicode`), qui ne voit pas « é » comme une lettre.
  /// « Pr\b » matchait donc déjà entre le « r » et le « é » de « Pré » : un
  /// nom de commune en un seul mot qui commence comme un titre abrégé
  /// (« Le Pré-Saint-Gervais », « Les Mées », « Le Mée-sur-Seine ») était pris
  /// pour une civilité annonçant un nom et n'était jamais inclus dans la
  /// commune (P2-180, § 1). Une vraie civilité est toujours suivie d'un
  /// espace ou d'un point avant le nom (« Mme Durand », « M. Durand ») : la
  /// différence ne change donc rien aux civilités réelles.
  static const _finDeTitre = "(?![\\wÀ-ÖØ-Þà-öø-ÿœŒ'’-])";

  /// Sépare le nom de voie du `CP_COMMUNE` qui suit : soit sur la **même
  /// ligne** (virgule optionnelle, comportement historique), soit via **un
  /// unique** saut de ligne (`SEP_LIGNE_UNIQUE` de la spec adresse
  /// multiligne). Un second saut de ligne consécutif (ligne vide) fait
  /// naturellement échouer les deux alternatives : `\d{5}` ne suit alors
  /// plus immédiatement (aux espaces horizontaux près), donc le span
  /// s'interrompt — pas de logique de garde séparée à écrire.
  static const _voieVersCpCommune =
      '(?:,?[ \\t\\u00A0\\u202F]*|[ \\t]*\\r?\\n[ \\t]*)';

  /// Rend une chaîne insensible à la casse lettre par lettre (`rue` devient
  /// `[Rr][Uu][Ee]`). Dart ne propose pas de drapeau local : le motif entier
  /// ne peut pas être `caseSensitive: false` sans rendre la commune
  /// insensible à la casse aussi.
  static String _ci(String word) => word.split('').map((c) {
        final up = c.toUpperCase();
        final low = c.toLowerCase();
        return up == low ? c : '[$up$low]';
      }).join();

  /// Type de voie, avec point facultatif pour les abréviations (`av.`, `bd.`).
  static final String _voieMotif = '(?:${_voies.map(_ci).join('|')})\\.?';

  /// Numéro de voie : 1 à 4 chiffres, suffixe facultatif `bis`, `ter`… ou une
  /// lettre majuscule A-F (« 12 bis rue », « 12bis rue », « 12 B rue »). La
  /// lettre doit être majuscule et isolée : le type de voie qui suit reste
  /// obligatoire, ce qui écarte « Annexe 12 B : voir page 3 ».
  static final String _numero = '\\d{1,4}(?:$_h*(?:${[
    'bis',
    'ter',
    'quater',
    'quinquies'
  ].map(_ci).join('|')}|[A-F](?![A-Za-zÀ-ÿ])))?';

  /// Nom de voie borné à 80 caractères : le quantificateur paresseux non
  /// borné rendait le motif quadratique quand « N rue » se répète sans code
  /// postal (16 Ko = plus de 5 s). Un nom de voie plus long n'est plus
  /// reconnu en entier : seul « code postal + commune » est alors masqué.
  static const String _nomVoie = "[A-ZÀ-ÖØ-Þa-zà-öø-ÿ0-9'’\\- ]{1,80}?";

  static final RegExp _pattern = RegExp(
    '$_numero$_h*(?:,$_h*)?$_voieMotif'
    '$_h+$_nomVoie'
    '$_voieVersCpCommune'
    '$_codePostalCommune',
  );

  /// Variante sans numéro (« rue des Lilas, 75015 Paris ») : exige que le
  /// type de voie ne soit pas collé à un mot qui précède, et un code postal
  /// + commune derrière. Confiance plus faible (0.6) que la forme numérotée.
  static final RegExp _patternSansNumero = RegExp(
    '(?<![\\wÀ-ÿ])$_voieMotif'
    '$_h+$_nomVoie'
    '$_voieVersCpCommune'
    '$_codePostalCommune',
  );

  static final RegExp _codePostalCommuneOnly = RegExp(_codePostalCommune);

  /// Types de voie reconnus **sans code postal** (P2-56) : en toutes lettres
  /// ou abréviations d'au moins deux lettres sans autre sens courant. « r »,
  /// « pl », « ch », « all », « sq », « crs », « imp » en sont exclus : après un
  /// nombre, ils désignent des chambres, des places ou des chapitres.
  static const _voiesSansCodePostal = [
    'rue', 'avenue', 'boulevard', 'chemin', 'impasse', 'allée', 'allee',
    'place', 'route', 'quai', 'square', 'passage', 'cours', 'lotissement',
    'chaussée', 'chaussee', 'faubourg', 'esplanade', 'villa', 'hameau', //
    'cité', 'cite', 'av', 'bd', 'bvd', 'rte', 'fbg', 'sentier', 'ruelle',
    'traverse', 'venelle', 'parvis', 'promenade', 'montée', 'montee', 'clos',
  ];

  /// Mot d'un nom de voie : majuscule initiale ou nombre (« rue du 8 Mai »).
  static const String _motVoie = "(?:[A-ZÀ-ÖØ-Þ][\\wÀ-ÿ'’-]*|\\d{1,4})";

  static const String _particuleVoie =
      "(?:(?:de|du|des|la|le|les|aux|sur|en|von|van)[ \\t]+|[dl]['’])";

  /// Adresse sans code postal : numéro + type de voie + nom de voie de 1 à 5
  /// mots en majuscule initiale (particules en minuscules tolérées). Le nom en
  /// minuscules (« 12 place disponible », « 3 chemin de fer ») n'est jamais une
  /// adresse. Confiance 0.55 : aucune validation possible.
  static final RegExp _patternSansCodePostal = RegExp(
    '(?<![\\wÀ-ÿ])$_numero$_h*(?:,$_h*)?'
    '(?:${_voiesSansCodePostal.map(_ci).join('|')})\\.?$_h+'
    '(?:$_particuleVoie)*$_motVoie'
    '(?:[ \\t-]+(?:$_particuleVoie)*$_motVoie){0,4}',
  );

  /// Unités de mesure courantes (SI et posologie clinique) — un nombre à 5
  /// chiffres suivi d'une unité (« 10000 UI », « 20000 ML ») a exactement
  /// la même forme syntaxique qu'un code postal suivi d'une commune, mais
  /// n'a rien d'une adresse : effacer une posologie serait une fuite de
  /// donnée clinique plus grave que le faux négatif évité. Liste générale,
  /// indépendante de tout document précis.
  static const _measurementUnits = {
    'ui', 'iu', 'mg', 'mcg', 'ng', 'pg', //
    'ml', 'cl', 'dl', 'kg', 'mol', 'mmol', 'meq', //
    'cm', 'mm', 'km', 'kcal', //
  };

  static final RegExp _minuscule = RegExp(r'\p{Ll}', unicode: true);
  static final RegExp _majuscule = RegExp(r'\p{Lu}', unicode: true);

  static bool _sansMinuscule(String text) =>
      !_minuscule.hasMatch(text) && _majuscule.hasMatch(text);

  /// Le texte reconnu **finit** par « CEDEX » (et son numéro) : le mot est sur
  /// la même ligne, juste derrière la commune ([_suffixeCedex] est la dernière
  /// pièce du motif).
  static final RegExp _finitParCedex = RegExp(
    '(?<![A-Za-zÀ-ÿ0-9])$_cedex'
    '(?:$_h+\\d{1,2})?\$',
    caseSensitive: false,
  );

  /// Vrai quand le premier mot de la commune est un mot neutre (P2-122) : en
  /// texte tout en capitales, « 70000 EUROS HORS TAXES » ne doit pas être une
  /// adresse. **Sauf devant « CEDEX »** (P2-201, décision du 15 novembre) :
  /// « 46090 VERS CEDEX 2 », « 09230 SOUS PARSAT CEDEX 1 » sont des communes
  /// (15 sur 34 875 du référentiel ont un mot neutre en tête, 61 adresses du
  /// balayage). Le coût est un nombre à cinq chiffres, un mot neutre et
  /// « CEDEX » à la suite (« VIREMENT DE 70000 EUROS CEDEX 3 »), masqué en trop :
  /// `LIMITES.md`. Sans « CEDEX », la règle reste entière.
  static bool _communeNeutre(RegExpMatch match) {
    final commune = match.namedGroup('commune');
    if (commune == null) return false;
    if (_finitParCedex.hasMatch(match.group(0)!)) return false;
    final premier = RegExp(r"^[^ \t\u00A0\u202F'’-]+").stringMatch(commune);
    if (premier == null || !motsNeutres.contains(premier.toLowerCase())) {
      return false;
    }
    return !_determinantDeCommune(match, premier);
  }

  /// Déterminants qui ouvrent un nom de commune (« La Boisse », « Le Plan »,
  /// « Les Mées », « L'Isle… ») : 2 222 communes, 6,4 % du référentiel
  /// (P2-183). En texte tout en capitales ils étaient écartés avec les mots
  /// neutres, et la commune n'était masquée ni avec son code postal ni avec
  /// son CEDEX (P2-185).
  static const Set<String> _determinants = {'le', 'la', 'les', 'l'};

  /// Mots qui, juste après un déterminant, ne confirment pas une commune.
  static final RegExp _separateursDeMot = RegExp(r"[ \t\u00A0\u202F'’-]+");

  /// Vrai si le premier mot (un déterminant) est suivi, dans le texte déjà
  /// reconnu comme « code postal + commune », d'**un second mot de commune**
  /// qui n'est ni un mot neutre ni « CEDEX » : « 01097 LA BOISSE » est une
  /// adresse, « 70000 LA » seul ou « 70000 LE DEVIS DES… » (second mot
  /// neutre) ne l'est pas. Le motif n'avale que des mots à initiale
  /// majuscule : « 70000 LES 3 PREMIERS » s'arrête après « LES ».
  static bool _determinantDeCommune(RegExpMatch match, String premier) {
    if (!_determinants.contains(premier.toLowerCase())) return false;
    final commune = match.namedGroup('commune')!;
    final brut = match.group(0)!;
    final depuis = brut.indexOf(commune, 5) + premier.length;
    if (depuis < premier.length) return false;
    final reste = brut.substring(depuis).split(_separateursDeMot);
    for (final mot in reste) {
      if (mot.isEmpty) continue;
      final bas = mot.toLowerCase();
      return !motsNeutres.contains(bas) && !RegExp(r'^cedex$').hasMatch(bas);
    }
    return false;
  }

  static bool _looksLikeUnit(RegExpMatch match) {
    final commune = match.namedGroup('commune');
    return commune != null && _measurementUnits.contains(commune.toLowerCase());
  }

  /// Règle CP_COMMUNE de la spec : « un token de commune commence par une
  /// majuscule ». Ne peut pas être imposé par la classe de caractères de
  /// `commune` elle-même : `_pattern` et `_codePostalCommuneOnly` sont
  /// `caseSensitive: false` (nécessaire pour matcher les types de voie en
  /// minuscules), ce qui rend `[A-ZÀ-ÖØ-Þ]` insensible à la casse par la
  /// même occasion et laissait passer des faux positifs comme
  /// « 70000 euros ». Vérification a posteriori, sur la sous-chaîne
  /// réellement matchée, indépendante du flag de casse du motif.
  static final RegExp _uppercaseFirstLetter = RegExp(r'^[A-ZÀ-ÖØ-ÞŒ]');

  static bool _communeStartsWithUppercase(RegExpMatch match) {
    final commune = match.namedGroup('commune');
    return commune != null && _uppercaseFirstLetter.hasMatch(commune);
  }

  /// Tournure de **quantité ou de référence** juste avant un nombre à cinq
  /// chiffres (P2-167) : « commande **de** 70000 unités », « **environ** 12345
  /// exemplaires », « **lot** 70000 », « **réf.** 54321 », « **n°** 17514 »,
  /// « **total :** 70000 ». Un code postal n'est pas introduit ainsi : il suit
  /// une voie, une virgule, un retour à la ligne, « à » ou une étiquette
  /// d'adresse. Mesure de départ (`bench/generate_corpus_cinq_chiffres.py`,
  /// 400 phrases sans adresse) : 132 adresses prédites à tort par
  /// `Ecluse.redact`.
  ///
  /// Les mots de la tournure sont des mots de grammaire (préposition de
  /// quantité, étiquettes de pièce ou de commande), pas des valeurs tirées d'un
  /// corpus. Les mots qui **suivent** le nombre ne sont pas jugés : « 70000
  /// Vesoul » et « 70000 Alpha » ont la même forme.
  ///
  /// « de » seul n'est **pas** une tournure de quantité (décision du
  /// 13 novembre) : « la mairie de 70000 Vesoul », « originaire de 25000
  /// Besançon » restent masqués. « de » ne compte qu'après un nom de pièce ou
  /// de quantité (« commande de 70000 unités », « un lot de 12345 pièces »).
  /// Mieux vaut un nombre masqué à tort qu'un code postal laissé en clair.
  static final RegExp _introduitParQuantite = RegExp(
    r'(?<![\p{L}])(?:(?:commande|lot|total|quantité|quantite|montant|facture|'
    r'dossier|stock|livraison|tirage)s?'
    r"(?:[ \t\u00A0\u202F]+(?:de|d['’]))?|"
    r'environ|n°|réf\.?|ref\.?|référence|reference)'
    r'[ \t\u00A0\u202F]*:?[ \t\u00A0\u202F]*$',
    caseSensitive: false,
    unicode: true,
  );

  /// Borne la partie du texte relue avant le nombre : le coût reste linéaire
  /// quand les nombres à cinq chiffres se répètent.
  static const int _fenetreQuantite = 40;

  static bool _estIntroduitParQuantite(String text, int debut) {
    final depart = debut > _fenetreQuantite ? debut - _fenetreQuantite : 0;
    return _introduitParQuantite.hasMatch(text.substring(depart, debut));
  }

  /// Mot d'un nom de commune pour la règle « nom exact » : une suite de
  /// lettres ou de chiffres, accents compris.
  static final RegExp _motDeNom = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  /// Ce qui peut séparer deux mots d'un nom de commune du référentiel, sur la
  /// même ligne : blancs, tiret, apostrophe, parenthèses (« CHATEAU CHINON
  /// (VILLE) », « SARROUX - SAINT JULIEN »). Ni virgule, ni point, ni saut de
  /// ligne : ils ferment le nom.
  static final RegExp _entreMotsDeNom = RegExp("^[ \\t\\u00A0\\u202F'’()-]+\$");

  /// Portion de ligne relue derrière un code postal : le plus long nom de
  /// [communesNomExact] a huit mots et moins de 60 caractères.
  static const int _fenetreNomExact = 120;

  /// Règle « nom exact du référentiel » (P2-214, décision du 16 novembre) :
  /// fin du **plus long** nom de [communesNomExact] qui commence juste après
  /// le code postal placé en [codePostal], ou `null`.
  ///
  /// Pourquoi : le motif s'arrête au quatrième mot et à la première
  /// parenthèse ; en capitales sans « CEDEX », 252 adresses du balayage du
  /// référentiel gardaient la fin de leur nom en clair (« 02213 DHUYS ET MORIN
  /// EN [BRIE] », « 58120 CHATEAU CHINON [(VILLE)] », P2-206). Allonger le
  /// motif masquerait le texte ordinaire qui suit une commune ; le nom exact
  /// ne masque que ce qui **est** une commune connue, écrite en entier. Le
  /// texte est comparé sans accent ni ponctuation, comme la table.
  ///
  /// Le nom doit finir à une limite de mot ; une parenthèse fermante qui le
  /// suit immédiatement en fait partie. Une écriture hors du référentiel
  /// (« ST » pour « SAINT », une faute) n'est pas reconnue : `LIMITES.md`.
  static int? _finNomExact(String text, int codePostal) {
    final i = codePostal + 5;
    if (i >= text.length) return null;
    var limite = text.indexOf('\n', i);
    if (limite < 0) limite = text.length;
    if (limite - i > _fenetreNomExact) limite = i + _fenetreNomExact;
    final ligne = text.substring(i, limite);
    final cle = StringBuffer();
    var mots = 0;
    var precedent = 0;
    int? fin;
    for (final mot in _motDeNom.allMatches(ligne)) {
      final entre = ligne.substring(precedent, mot.start);
      // Avant le premier mot : des blancs seulement (le motif l'exige déjà).
      if (entre.isEmpty || !_entreMotsDeNom.hasMatch(entre)) break;
      if (++mots > communesNomExactMotsMax) break;
      if (mots > 1) cle.write(' ');
      cle.write(normName(mot.group(0)!));
      precedent = mot.end;
      if (communesNomExact.contains(cle.toString())) {
        var f = mot.end;
        if (f < ligne.length && ligne[f] == ')') f++;
        fin = i + f;
      }
    }
    return fin;
  }

  /// Fin de l'adresse quand la règle « nom exact » a parlé ([exact]). Cas
  /// ordinaire : la plus lointaine des deux fins (le nom exact prolonge un
  /// motif arrêté au quatrième mot ; « CEDEX n » prolonge le nom). Si la
  /// commune commence par un mot neutre ([neutre], « 70000 LES PLACES
  /// RESTANTES »), seul le nom exact justifie l'adresse : elle s'arrête à sa
  /// fin, le reste de la ligne n'est pas masqué.
  static int _finRetenue(RegExpMatch match, int? exact, bool neutre) {
    if (exact == null) return match.end;
    if (neutre) return exact;
    return exact > match.end ? exact : match.end;
  }

  /// Position du code postal dans une adresse reconnue par un motif de voie :
  /// le dernier nombre de cinq chiffres suivi d'un blanc (le nom de commune
  /// et « CEDEX n » n'en contiennent pas).
  static final RegExp _codePostalDansVoie = RegExp('(?<!\\d)\\d{5}$_h');

  /// Fin du nom exact pour [match] en texte tout en capitales, sinon `null`.
  /// [seul] : le motif est « code postal + commune » (le code postal ouvre le
  /// texte reconnu) ; sinon il est cherché derrière la voie.
  static int? _nomExact(String text, RegExpMatch match, bool capitales,
      {required bool seul}) {
    if (!capitales) return null;
    if (seul) return _finNomExact(text, match.start);
    final dans = match.group(0)!.lastIndexOf(_codePostalDansVoie);
    return dans < 0 ? null : _finNomExact(text, match.start + dans);
  }

  static bool _chevauche(List<_Range> tries, int start, int end) {
    var lo = 0;
    var hi = tries.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (tries[mid].start < end) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    // `lo` : premier intervalle commençant à `end` ou après ; les précédents
    // sont disjoints et triés, seul le dernier peut déborder sur `start`.
    return lo > 0 && tries[lo - 1].end > start;
  }

  @override
  List<DetectedEntity> detect(String text) {
    // Texte sans aucune minuscule : la règle « la commune commence par une
    // majuscule » ne filtre plus rien (« 70000 EUROS HORS TAXES » devenait
    // une adresse : 194 faux positifs sur le témoin, mesure P2-121). On y
    // écarte une commune qui commence par un mot neutre (P2-122).
    final capitales = _sansMinuscule(text);
    final results = <DetectedEntity>[];
    final claimed = <_Range>[];

    for (final match in _pattern.allMatches(text)) {
      if (_looksLikeUnit(match)) continue;
      if (!_communeStartsWithUppercase(match)) continue;
      final exact = _nomExact(text, match, capitales, seul: false);
      final neutre = capitales && _communeNeutre(match);
      if (neutre && exact == null) continue;
      final start = match.start;
      final end = _finRetenue(match, exact, neutre);
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.7,
        ),
      );
      claimed.add(_Range(start, end));
    }

    // Voie sans numéro : après la forme numérotée (qui la contient), pour
    // ne pas produire deux entités sur la même adresse.
    for (final match in _patternSansNumero.allMatches(text)) {
      if (_looksLikeUnit(match)) continue;
      if (!_communeStartsWithUppercase(match)) continue;
      final exact = _nomExact(text, match, capitales, seul: false);
      final neutre = capitales && _communeNeutre(match);
      if (neutre && exact == null) continue;
      final start = match.start;
      final end = _finRetenue(match, exact, neutre);
      if (claimed.any((r) => r.overlaps(start, end))) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.6,
        ),
      );
      claimed.add(_Range(start, end));
    }

    // Adresse sans code postal (P2-56), en dernier : une adresse complète déjà
    // reconnue la contient. Intervalles déjà retenus triés (disjoints par
    // construction), recherche dichotomique plutôt que balayage.
    final retenus = [...claimed]..sort((a, b) => a.start - b.start);
    for (final match in _patternSansCodePostal.allMatches(text)) {
      if (_chevauche(retenus, match.start, match.end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: match.start,
          end: match.end,
          value: match.group(0)!,
          confidence: 0.55,
        ),
      );
      claimed.add(_Range(match.start, match.end));
    }

    for (final match in _codePostalCommuneOnly.allMatches(text)) {
      if (_looksLikeUnit(match)) continue;
      if (!_communeStartsWithUppercase(match)) continue;
      // Nom exact du référentiel (P2-214) : il lève la règle du mot neutre
      // (« 12345 LES PLACES ») et porte la fin de l'adresse à la fin du nom.
      final exact = _nomExact(text, match, capitales, seul: true);
      final neutre = capitales && _communeNeutre(match);
      if (neutre && exact == null) continue;
      final start = match.start;
      final end = _finRetenue(match, exact, neutre);
      if (_estIntroduitParQuantite(text, start)) continue;
      // Déjà couvert par une adresse complète (numéro + voie) ci-dessus :
      // ne pas ajouter un doublon pour le seul suffixe "code postal +
      // commune" de cette même adresse.
      if (claimed.any((r) => r.overlaps(start, end))) continue;
      results.add(
        DetectedEntity(
          type: EntityType.adresse,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.55,
        ),
      );
      claimed.add(_Range(start, end));
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }
}

final class _Range {
  const _Range(this.start, this.end);
  final int start;
  final int end;

  bool overlaps(int otherStart, int otherEnd) =>
      otherStart < end && start < otherEnd;
}
