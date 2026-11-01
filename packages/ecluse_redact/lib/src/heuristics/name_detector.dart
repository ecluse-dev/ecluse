import 'dart:typed_data';

import 'package:ecluse_core/ecluse_core.dart';

import 'etablissement_keywords.dart';
import 'french_first_names.dart';
import 'tableau_csv.dart';

/// Détecteur heuristique de noms de personnes — **v0 de démonstration**.
///
/// Contrairement aux détecteurs d'`ecluse_core`, il n'y a ici aucune clé
/// de contrôle possible : un nom propre n'a pas de structure vérifiable.
/// Ce détecteur combine deux indices :
///
/// 1. Une **civilité** (`M.`, `Mme`, `Mademoiselle`, `Monsieur`, `Madame`,
///    `Dr`, `Docteur`, `Pr`, `Professeur`, `Me`) suivie d'un prénom puis
///    d'un patronyme de 1 à 2 mots (particules `de`, `du`, `des`, `le`,
///    `la`, `van`, `von` admises devant un mot en casse de titre) →
///    confiance haute (0.9) : l'indice
///    est fort et rarement un faux positif.
/// 2. Un **prénom français connu** (voir [frenchFirstNames]) adjacent à un
///    mot capitalisé (nom de famille supposé) → confiance moyenne (0.6).
///    Règle **bidirectionnelle** : le mot capitalisé peut précéder le
///    prénom (ordre « Nom Prénom », ex. « Dubreuil Thomas », ou convention
///    administrative tout-majuscules « DANNER Laurent ») ou le suivre
///    (ordre « Prénom Nom », ex. « Sophie Lambert »), sans condition de
///    casse dans un sens comme dans l'autre. Un prénom **composé** avec
///    tiret (« Jean-Marc », « Anne-Sophie ») est reconnu dès qu'un de ses
///    segments est un prénom connu — le motif capitalisé gourmand avale
///    déjà le tiret comme un seul jeton, donc le comparer tel quel au
///    gazetteer échouerait toujours. Un prénom peut aussi être un nom
///    commun capitalisé par erreur, ou le mot adjacent n'être pas un nom de
///    famille : d'où la confiance moyenne plutôt que haute. Limite connue
///    de cette symétrie : un mot capitalisé par simple position de début
///    de phrase (salutation, connecteur) et adjacent à un prénom connu peut
///    être capturé à tort — voir `LIMITES.md`.
/// 3. Un **prénom français connu** utilisé seul, sans nom de famille qui
///    suit (ex. « Sophie rappelle que… » dans un compte rendu où l'on
///    ne mentionne plus qu'un prénom une fois la personne présentée) →
///    confiance plus faible (0.5), mais détecté quand même : dans cette
///    version, on ne filtre jamais par confiance (voir `Ecluse.redact`),
///    donc un prénom isolé est masqué plutôt que de fuiter.
///
/// Un mot capitalisé isolé, sans civilité ni prénom reconnu (ex. début de
/// phrase), n'est **jamais** masqué : ce serait trop de faux positifs pour
/// une démonstration crédible.
///
/// **Deuxième passe — mentions partielles rattrapées via un patronyme déjà
/// établi.** Une fois les mentions ci-dessus détectées avec certitude, leur
/// patronyme est extrait (voir [_extractSurname]) et recherché ailleurs
/// dans le **même document** — jamais dans une liste externe. Couvre :
/// nom de famille seul après une mention complète (« Dr Costa » après
/// « Dr Nadia Costa »), initiale + nom (« S. Reynaud » — seul le patronyme
/// est masqué, l'initiale reste visible comme une civilité), et patronyme
/// suivi d'un prénom non reconnu par le gazetteer (« Morel Hélène » après
/// « MOREL Antoine » — jeton **différent**, décidé par [Ecluse.redact] sur
/// la base du prénom distinct, pas par ce détecteur). Confiance 0.6, comme
/// l'appariement bidirectionnel dont cette passe réutilise la logique de
/// mot adjacent. Un patronyme qui coïncide avec un sigle exclu (voir
/// [_excludedAcronyms]) n'est jamais retenu pour cette recherche.
///
/// Sera remplacé en phase 2 par un modèle NER local (voir ROADMAP.md).
final class NameDetector implements EntityDetector {
  /// [knownSurnames] : patronymes (minuscules) établis **ailleurs** que dans le
  /// texte analysé, par exemple dans les documents précédents d'un dossier
  /// (P2-14). Ils amorcent la deuxième passe comme un patronyme extrait du
  /// texte : jamais de liste externe ni d'apprentissage, seulement ce que
  /// l'appelant a déjà établi par une mention certaine. Un mot courant égal à
  /// un de ces patronymes (« Petit déjeuner » avec un patient nommé Petit) est
  /// masqué : sur-masquage assumé, voir `LIMITES.md` § 5.4.
  const NameDetector({this.knownSurnames = const {}});

  final Set<String> knownSurnames;

  @override
  EntityType get type => EntityType.nom;

  /// Capture prénom + jusqu'à 2 unités de patronyme supplémentaires
  /// (`PATRONYME{1,2}` de la spec adresse multiligne, borne basse ramenée à
  /// 0 pour préserver le comportement existant « civilité + un seul mot »,
  /// ex. `Dr Martin` -> `Martin`, un patronyme seul sans prénom qui suit).
  /// Chaque unité peut être précédée d'une particule en minuscules (`de`,
  /// `du`, `des`, `le`, `la`, `van`, `von`) à condition d'être suivie d'un
  /// mot en casse de titre — sinon la particule n'est jamais absorbée seule.
  ///
  /// Tous les séparateurs sont `[ \t]+` (espace horizontal), jamais `\s+` :
  /// la spec (§ 3) exige que civilité, prénom et patronyme restent sur la
  /// **même ligne**. `\s` matche aussi `\n`/`\r`, ce qui laissait le
  /// patronyme absorber le premier mot capitalisé de la ligne suivante.
  /// Blanc horizontal : espace, tabulation, espace insécable (U+00A0), espace
  /// fine insécable (U+202F). Jamais un saut de ligne.
  static const String _h = r'[ \t\u00A0\u202F]';

  /// Mot de nom propre : majuscule initiale, apostrophes droite et
  /// typographique (« O’Connor »), tirets. La majuscule initiale couvre le
  /// Latin-1 (À-Ö, Ø-Þ : Á, Ñ, Ø, Æ…) et le Latin étendu A (Œ, Ł, Ş, Ž…) ; les
  /// lettres suivantes couvrent aussi le Latin étendu additionnel (vietnamien,
  /// P2-33).
  static const String _cap =
      r"[A-ZÀ-ÖØ-ÞĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮİĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸŹŻŽ][\wÀ-ſḀ-ỿ'’-]*";

  /// Particules d'un nom (« de la Fontaine », « Van Der Berg », « Le Gall »,
  /// « d'Angelo »), en minuscules **ou** capitalisées, chaînables. Une
  /// particule n'est jamais absorbée seule : elle doit précéder un mot en
  /// casse de titre (voir [_unite]).
  static const String _particules =
      '(?:(?:[Dd]e|[Dd]u|[Dd]es|[Ll]e|[Ll]a|[Ll]es|[Vv]an|[Vv]on|[Dd]er|[Dd]en|'
      '[Ee]l|[Aa]l|[Dd]a|[Dd]as|[Dd]o|[Dd]os|[Dd]i|[Dd]el|[Dd]ella|[Bb]en|[Bb]in|'
      "[Bb]int|[Ii]bn|[Tt]er|[Tt]en|[Zz]u|[Aa]f)$_h+|[DdLl]['’])";

  /// Mots qui ouvrent ordinairement une phrase : jamais pris pour un nom quand
  /// ils suivent un saut de ligne (P2-73).
  static const String _debutsDePhrase =
      'Le|La|Les|Un|Une|Des|Du|De|Ce|Cette|Ces|Il|Elle|Ils|Elles|On|Nous|Vous|'
      'Je|Tu|Et|Ou|Mais|Donc|Or|Ni|Car|Si|Que|Qui|Dans|Avec|Pour|Sans|Sur|Sous|'
      'En|Au|Aux|Voir|Merci|Suite|Puis|Ensuite|Aussi|Cependant|Selon';

  /// Séparation entre une civilité (ou une étiquette) et le nom : des blancs, ou
  /// **un seul** saut de ligne (P2-73), jamais une ligne vide, et jamais devant un
  /// mot qui ouvre une phrase. Un texte extrait d'un PDF coupe les lignes
  /// n'importe où.
  static const String _blancOuSaut =
      '(?:$_h+|$_h*\\r?\\n$_h*(?!(?:$_debutsDePhrase)\\b))';

  /// Une unité de nom : particules éventuelles puis mot capitalisé.
  static const String _unite = '(?:$_particules)*$_cap';

  static final RegExp _civility = RegExp(
    r'\b(?:M\.|Mrs\.?|Mr\.?|Ms\.?|Mme\.?|Mlle\.?|Mademoiselle|Monsieur|Madame|Mgr|'
    r'[Aa]bbé|Dre\.?|Dr\.?|Docteure|Docteur|Pr\.?|Professeure|Professeur|Maître|'
    r'Maitre|Me|'
    // P2-69 : formes abrégées et en majuscules, minuscules du dialogue.
    r'Mdme\.?|Melle\.?|MME|MLLE|MR|MONSIEUR|MADAME|MADEMOISELLE|DOCTEUR|PROFESSEUR|'
    r'[mM]onsieur|[mM]adame|[mM]ademoiselle|docteur|docteure|doctoresse|'
    r'professeur|professeure)'
    '$_blancOuSaut'
    '($_unite'
    '(?:$_h+'
    // Un mot-clé d'établissement n'est jamais un patronyme (voir
    // `etablissementKeywords`).
    '(?!(?:${etablissementKeywords.join('|')})\\b)'
    '$_unite){0,2})',
  );

  /// Patronyme derrière une étiquette de champ (P2-36). Les étiquettes précises
  /// (« Nom de naissance », « Nom d'usage », « Nom de famille », « Nom
  /// patronymique », « Nom marital ») désignent toujours une personne. « Nom »
  /// seul est ambigu (« Nom : Aspirine ») : il n'est retenu que si « Prénom »
  /// suit sur la même ligne ou la suivante, signe d'une fiche d'identité.
  /// Qualifications d'une personne derrière « Nom » (P2-41) : « Nom du patient »,
  /// « Nom de l'assurée »… Chaque forme existe en minuscules et en majuscules.
  static final String _nomQualifie = [
    'du$_h+(?:patient|bénéficiaire|demandeur|salarié|résident)',
    'de$_h+la$_h+patiente',
    "de$_h+l['\u2019](?:assuré|assurée|employé|employée)",
  ].map((f) => '(?:$f|${f.toUpperCase()})').join('|');

  /// Séparateur entre une étiquette et sa valeur : `:`, U+001F (cellules d'un
  /// tableau HTML, P2-63) ou une vraie tabulation (cellules d'un tableau Word ou
  /// ODT, P2-65). Des espaces seuls ne suffisent jamais.
  static const String _separateurEtiquette =
      '(?:$_h*[:\u001F](?:$_h*\\r?\\n$_h*(?!(?:$_debutsDePhrase)\\b)|$_h*)|'
      '[ \\t\u00A0\u202F]*\\t$_h*)';

  /// Civilités au pluriel (P2-69) : « Mmes Quenelle et Dupont », « MM. Quenelle et
  /// Dupont », « Mesdames… », « Messieurs… ». Une personne par nom : chaque unité
  /// est une entité séparée, jamais un seul jeton pour deux personnes.
  static final RegExp _civilitePlurielle = RegExp(
    r'(?<![\wÀ-ÿ])(?:Mmes|Mlles|MM\.|Mesdames|Messieurs)'
    '$_h+'
    '($_unite(?:(?:$_h*,$_h*|$_h+(?:et|ou)$_h+)$_unite){0,3})',
  );

  /// Mots de parenté et de religion qui annoncent un nom (P2-69) : « la famille
  /// Quenelle », « les époux Quenelle », « Sœur Marie-Pierre Quenelle », « Père
  /// Quenelle ». Un mot-clé d'établissement n'est jamais un patronyme.
  static final RegExp _cueParente = RegExp(
    r'(?<![\wÀ-ÿ])(?:[Ff]amille|[EeÉé]poux|[Cc]onsorts|[SsŒœ]œur|[Ss]oeur|'
    r'[Ff]rère|Père)'
    '$_h+'
    '(?!(?:${etablissementKeywords.join('|')})\\b)'
    '($_cap(?:$_h+$_unite)?)',
  );

  /// Étiquette et valeur séparées par une tabulation (cellules d'un tableau Word
  /// ou ODT) : seulement si la ligne n'a que ces deux champs. Dans une rangée
  /// d'en-tête (« Nom⇥Prénom⇥Service »), « Prénom⇥Service » n'est pas une
  /// étiquette suivie de sa valeur. Lignes bornées à 300 caractères de part et
  /// d'autre : une ligne plus longue n'est pas un tableau de deux champs.
  static bool _deuxChamps(String text, int debut, int fin) {
    final min = debut > 300 ? debut - 300 : 0;
    final avant = text.substring(min, debut);
    final nl = avant.lastIndexOf('\n');
    if (nl == -1 && min > 0) return false;
    final max = fin + 300 < text.length ? fin + 300 : text.length;
    final apres = text.substring(fin, max);
    var nl2 = apres.indexOf('\n');
    if (nl2 == -1 && max < text.length) return false;
    if (nl2 == -1) nl2 = apres.length;
    // Une seule tabulation sur la ligne, celle du séparateur : la valeur ne
    // chevauche pas une autre cellule.
    return '\t'.allMatches(text.substring(debut, fin)).length == 1 &&
        !avant.substring(nl + 1).contains('\t') &&
        !apres.substring(0, nl2).contains('\t');
  }

  static final RegExp _champNom = RegExp(
    r'\b(?:Nom|NOM)(?:'
    '$_h+(de$_h+naissance|d[\u0027\u2019]usage|de$_h+famille|patronymique|'
    'marital|$_nomQualifie))?'
    '$_separateurEtiquette'
    '(?!(?:Pr[ée]noms?|PR[ÉE]NOMS?|Nom|NOM)\\b)'
    '($_unite(?:$_h+(?!(?:Pr[ée]noms?|PR[ÉE]NOMS?)\\b)$_unite)?)',
  );

  /// Mois et jours : jamais un nom de naissance (« née Lundi »), sous leurs trois
  /// écritures (minuscules, initiale, majuscules).
  static final String _moisEtJours = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août',
    'septembre', 'octobre', 'novembre', 'décembre', 'lundi', 'mardi',
    'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche', //
  ]
      .map(
          (w) => '$w|${w[0].toUpperCase()}${w.substring(1)}|${w.toUpperCase()}')
      .join('|');

  /// Nom de naissance ou d'épouse (P2-45) : « née Dupont », « épouse Dupont »,
  /// « ép. », « veuve », « divorcée », « nom de jeune fille (:) Dupont ». Le
  /// marqueur peut ouvrir une phrase et le nom doit commencer par une majuscule : « née le », « née à Lyon » ne sont pas touchés.
  static final RegExp _nomDeNaissance = RegExp(
    r'(?<![\wÀ-ÿ])(?:[Nn]ée|[ÉéEe]pouse|[ÉéEe]p\.|[Vv]euve|[Dd]ivorcée|'
    '[Nn]om$_h+de$_h+jeune$_h+fille)'
    '(?:$_h*:)?$_blancOuSaut'
    '(?!(?:$_moisEtJours)\\b)'
    '($_unite(?:$_h+$_unite)?)',
  );

  /// Prénom(s) derrière l'étiquette « Prénom » (P2-40) : toujours une personne
  /// (« Prénom usuel », « Prénom de naissance »…), de 1 à 3 mots, sans jamais
  /// absorber l'étiquette suivante (« Nom », « Prénom »). « Prénom du chat : »
  /// n'est pas reconnu : seules les qualifications d'état civil le sont.
  static final RegExp _champPrenom = RegExp(
    r'\b(?:Pr[ée]noms?|PR[ÉE]NOMS?)(?:'
    '$_h+(?:usuels?|de$_h+naissance|d[\u0027\u2019]usage|[àa]$_h+l[\u0027\u2019]'
    r'[ée]tat$_h+civil))?'
    '$_separateurEtiquette'
    '(?!(?:Nom|NOM|Pr[ée]noms?|PR[ÉE]NOMS?)\\b)'
    '($_unite(?:$_h+(?!(?:Nom|NOM|Pr[ée]noms?|PR[ÉE]NOMS?)\\b)$_unite){0,2})',
  );

  /// Nom d'un correspondant dans un en-tête de courriel (P2-53), prénom connu
  /// ou non du gazetteer. Deux structures : une étiquette d'en-tête en début de
  /// ligne (« De : », « From: », « À : », « Cc : »…, éventuellement citée par
  /// `>`) suivie du nom puis de `<adresse`, avec « Nom, Prénom » et guillemets
  /// tolérés ; ou un nom devant `<adresse>` suivi de « a écrit » / « wrote ».
  /// Un mot-clé d'établissement n'est jamais un patronyme.
  static final String _nomMail = '(?!(?:${etablissementKeywords.join('|')})\\b)'
      '($_unite(?:,?$_h+$_unite){0,2})';

  static final RegExp _enteteMail = RegExp(
    '^[ \\t>]*(?:De|DE|From|FROM|[ÀA]|To|TO|Cc|CC|Cci|Bcc|BCC|Exp[ée]diteur|'
    'Destinataire|Reply-To)$_h*:$_h*["\u0027\u201C]?$_nomMail["\u0027\u201D]?$_h*<',
    multiLine: true,
  );

  static final RegExp _aEcrit = RegExp(
    // Début de mot strict (tiret et apostrophe compris) : sinon le motif
    // repart de chaque segment d'un mot composé très long, en temps cubique.
    "(?<![\\wÀ-ÿ'’-])($_unite(?:$_h+$_unite){0,2})$_h*<[^<>\\s]+@[^<>\\s]+>:?$_h*"
    r'(?:a[ \t]+[ée]crit|wrote|ha[ \t]+scritto|schrieb)',
  );

  /// Formules de clôture d'un courrier (P2-54). Le nom de signature est la
  /// ligne qui suit : la structure, non le prénom, désigne la personne.
  static const List<String> _formulesCloture = [
    'cordialement', 'bien cordialement', 'très cordialement',
    'cordialement vôtre', 'bien à vous', 'bien à toi', 'bonne journée',
    'bonne soirée', 'bonne continuation', 'respectueusement',
    'respectueuses salutations', 'salutations distinguées',
    'sincères salutations', 'amicalement', 'bien amicalement', 'cdt',
    'best regards', 'kind regards', 'regards', 'sincerely', //
  ];

  /// Début de ligne de signature qui désigne une structure, non une personne.
  static const List<String> _motsStructure = [
    'Service', 'SERVICE', 'Pôle', 'Direction', 'DIRECTION', 'Équipe',
    'Équipes', 'Secrétariat', 'Cabinet', 'Unité', 'Département', 'Association',
    'Société', 'Mairie', 'Pour', 'POUR', 'Mon', 'Ma', //
  ];

  /// Nom seul sur la ligne qui suit une formule de clôture (1 à 3 mots en
  /// majuscule initiale, jamais un article élidé ni un mot-clé
  /// d'établissement), une ligne vide tolérée entre les deux.
  static final RegExp _signature = RegExp(
    '^[ \\t>]*(?:${_formulesCloture.map((f) => '[${f[0].toUpperCase()}${f[0]}]${f.substring(1)}').join('|')})'
    '$_h*[,.!]?$_h*\\r?\\n(?:$_h*\\r?\\n)?$_h*'
    "(?![Ll]['\u2019])"
    '(?!(?:${[...etablissementKeywords, ..._motsStructure].join('|')})\\b)'
    '($_unite(?:$_h+$_unite){0,2})$_h*\\r?\$',
    multiLine: true,
  );

  /// Étiquettes de rôle qui désignent sans ambiguïté une personne (P2-55). Les
  /// étiquettes qui précèdent aussi des organismes (« Contact », « Tuteur »,
  /// « Représentant légal », « Destinataire ») en sont volontairement absentes.
  static const String _etiquettesRole =
      r'(?:[Pp]atient(?:e|\(e\))?|PATIENT(?:E)?|[Rr]ésident(?:e|\(e\))?|RÉSIDENT(?:E)?|'
      r'[Bb]énéficiaire|BÉNÉFICIAIRE|[Uu]sager|[Uu]sagère|USAGER|'
      r'[Pp]ersonne[ \t]+accompagnée|[Pp]ersonne[ \t]+de[ \t]+confiance|'
      r'[Pp]ersonne[ \t]+à[ \t]+prévenir|[Mm]édecin[ \t]+traitant)';

  /// Valeurs qui ne sont pas un nom (états, structures) en tête de valeur.
  static const List<String> _nonNoms = [
    'Non', 'NON', 'Oui', 'OUI', 'Aucun', 'Aucune', 'AUCUN', 'AUCUNE', 'Sans',
    'SANS', 'Pas', 'PAS', 'Inconnu', 'Inconnue', 'INCONNU', 'INCONNUE', 'Voir',
    'VOIR', 'Cabinet', 'Association', 'Service', 'Pôle', 'Direction', 'Unité',
    'Département', 'Société', 'Mairie', 'Équipe', //
  ];

  static final RegExp _etiquetteRole = RegExp(
    '(?<![\\wÀ-ÿ])$_etiquettesRole$_separateurEtiquette'
    "(?![DdLl]['\u2019])"
    '(?!(?:${[...etablissementKeywords, ..._nonNoms].join('|')})\\b)'
    '($_unite$_h+$_unite(?:$_h+$_unite)?)',
  );

  /// Clés de données explicites qui désignent une personne (P2-61), en
  /// snake_case, kebab-case ou camelCase : `nom_patient`, `nom_famille`,
  /// `nom_naissance`, `nom_usage`, `lastname`, `family_name`, `surname`,
  /// `firstname`, `given_name`, `prenom(s)`. La clé nue « nom » est exclue : elle
  /// désigne aussi un fichier, un projet, un médicament (arbitrage du 27 octobre).
  static const String _cleNom = '(?:nom[_-]?(?:de[_-]?|d[_-]?)?'
      '(?:patient|patiente|famille|naissance|usage|jeune[_-]?fille)'
      '|(?:last|family|sur)[_-]?name|first[_-]?name|given[_-]?name'
      '|pr[ée]noms?)';

  /// Valeurs qui ne sont pas un nom : absence de valeur ou booléen.
  static final String _valeurVide = '(?!(?:${[
    'null', 'none', 'nan', 'undefined', 'unknown', 'inconnue?', 'vide', //
    'true', 'false', 'oui', 'non', 'n/?a', 'nc', 'nr', //
  ].map((m) => '[${m[0].toUpperCase()}${m[0]}]${m.substring(1)}|${m.toUpperCase()}').join('|')})(?![A-Za-zÀ-ÿ0-9_]))';

  static const String _motLax = "[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ'’.-]*";

  /// Valeur d'une clé en JSON, XML ou paramètre (`"cle": "v"`, `<cle>v</cle>`,
  /// `cle=v`) : 1 à 4 mots, casse libre, la clé étant l'indice.
  static final RegExp _cleDonneeLax = RegExp(
    '(?:["\u0027]$_cleNom["\u0027]$_h*:$_h*["\u0027]?'
    '|<$_cleNom(?:$_h[^>]*)?>$_h*'
    '|(?<![\\w"\u0027.-])$_cleNom$_h*=$_h*["\u0027]?)'
    '$_valeurVide($_motLax(?:$_h+$_motLax){0,3})(?![A-Za-zÀ-ÿ0-9_])',
    caseSensitive: false,
  );

  /// Même clé, sensible à la casse du mot de valeur : seule la première lettre de
  /// chaque mot de la clé varie (`nom_patient`, `Nom_patient`, `lastName`).
  static const String _cleNomCs = '(?:[Nn]om[_-]?(?:[Dd]e[_-]?|[Dd][_-]?)?'
      '(?:[Pp]atiente?|[Ff]amille|[Nn]aissance|[Uu]sage|[Jj]eune[_-]?[Ff]ille)'
      '|(?:[Ll]ast|[Ff]amily|[Ss]ur)[_-]?[Nn]ame|[Ff]irst[_-]?[Nn]ame'
      '|[Gg]iven[_-]?[Nn]ame|[Pp]r[ée]noms?)';

  /// Forme `cle: Valeur` (YAML, texte brut) : valeur en majuscule initiale,
  /// 1 à 3 unités, pour ne pas absorber la fin d'une phrase.
  static final RegExp _cleDonneePlain = RegExp(
    '(?<![\\w"\u0027.-])$_cleNomCs$_h*:$_h*$_valeurVide'
    '($_unite(?:$_h+$_unite){0,2})',
  );

  static final RegExp _prenomChamp = RegExp(r'\b(?:Pr[ée]nom|PR[ÉE]NOM)\b');

  /// Fenêtre de recherche de « Prénom » après un « Nom : » seul : fin de la
  /// ligne suivante, bornée. Un contrôle en code sur une fenêtre bornée plutôt
  /// qu'une anticipation dans l'expression : deux `[^\n]*` imbriqués y étaient
  /// cubiques sur une longue ligne de « Nom » répétés (1000 répétitions : 40 s).
  static const int _fenetrePrenom = 300;

  static bool _fichePrenomSuit(String text, int from) {
    // Fenêtre bornée d'abord (P2-50) : chercher le saut de ligne dans tout le
    // reste du texte parcourait un texte sans saut de ligne en entier à chaque
    // occurrence (1 Mo de « Nom : » : 43 s).
    final fin = from + _fenetrePrenom < text.length
        ? from + _fenetrePrenom
        : text.length;
    final fenetre = text.substring(from, fin);
    // Trois lignes : « Nom : » puis sa valeur sur la ligne suivante, puis
    // « Prénom : » (P2-73).
    var coupe = fenetre.indexOf('\n');
    for (var i = 0; i < 2 && coupe != -1; i++) {
      coupe = fenetre.indexOf('\n', coupe + 1);
    }
    return _prenomChamp
        .hasMatch(coupe == -1 ? fenetre : fenetre.substring(0, coupe));
  }

  /// « Prénom » dans la ligne courante ou la précédente, avant [to], dans la
  /// même fenêtre bornée (fiche dont le prénom précède le nom).
  static bool _fichePrenomPrecede(String text, int to) {
    if (to <= 0) return false;
    // Fenêtre bornée d'abord : remonter jusqu'au début de ligne serait
    // quadratique sur une longue ligne de « Nom » répétés.
    final fenetre =
        text.substring(to < _fenetrePrenom ? 0 : to - _fenetrePrenom, to);
    var debut = fenetre.lastIndexOf('\n');
    for (var i = 0; i < 2 && debut > 0; i++) {
      debut = fenetre.lastIndexOf('\n', debut - 1);
    }
    return _prenomChamp.hasMatch(fenetre.substring(debut < 0 ? 0 : debut));
  }

  static final RegExp _capitalizedWord = RegExp(_cap);

  /// Unité de nom suivie uniquement d'espaces jusqu'à la fin de la chaîne
  /// passée : sert à trouver le mot juste avant une position [before] dans
  /// le texte complet, en appelant ce motif sur `text.substring(0, before)`
  /// — les indices du groupe capturé restent alors valides dans `text`.
  static final RegExp _wordBeforeEnd = RegExp('($_cap)$_h+\$');

  /// Unité de nom (avec particules) à une position donnée : sert à étendre
  /// le patronyme qui suit un prénom reconnu (« Pierre de la Fontaine »).
  static final RegExp _uniteAt = RegExp(_unite);

  /// Sigles métier — administratifs et cliniques — qui ne doivent jamais
  /// être traités comme un nom, **même écrits tout en majuscules et même
  /// s'ils coïncident avec un prénom du gazetteer** (ex. « EVA », Échelle
  /// Visuelle Analogique, qui est aussi un prénom français courant).
  ///
  /// La plupart des sigles métier sont déjà à l'abri par simple absence du
  /// gazetteer (voir le test de non-régression sur SSIAD, CARSAT, etc.) :
  /// cette liste protège spécifiquement les cas **ambigus**, où le sigle
  /// coïncide avec une entrée du gazetteer, plus une couverture générale
  /// des sigles cliniques/échelles courants du secteur médico-social —
  /// domaine cœur d'Écluse — pour éviter d'effacer une donnée clinique.
  /// Comparaison volontairement **sensible à la casse** : un prénom réel
  /// écrit normalement (« Eva ») reste détecté, seule la forme MAJUSCULE
  /// conventionnelle du sigle est exclue.
  static const _excludedAcronyms = {
    // Sigles administratifs et structures (secteur médico-social).
    'SSIAD', 'CARSAT', 'SAMSAH', 'EHPAD', 'MSP', 'PCH', 'PRADO', 'ALD',
    'CPTS', 'IDEL', 'UDAF', 'MDPH', 'CCAS', 'HAD', 'RCP', 'IPS', 'APA',
    'IDE', 'IDEC', 'ESAT', 'CSE', //
    // Échelles et sigles cliniques courants.
    'EVA', 'EVS', 'EN', 'ADL', 'IADL', 'MMS', 'MMSE', 'GIR', 'AGGIR',
    'ECPA', 'GCS', 'ECG', 'EEG', 'IRM', 'TDM', 'VNI', 'AVC', 'IDM', 'HTA',
    'BPCO', 'IRC', 'IRA', 'AVK', 'INR', 'TSH', 'NFS', 'CRP', 'IMC', 'ETP',
    'ASH', 'AMP', 'PTH', //
  };

  static bool _isExcludedAcronym(String word) =>
      _excludedAcronyms.contains(word);

  /// Titres professionnels : révèlent une profession, un quasi-identifiant
  /// de premier ordre en contexte hospitalier — le span masqué les inclut
  /// désormais (voir `LIMITES.md`). Périmètre strict et volontairement
  /// distinct des civilités de genre (`M.`, `Mme`, `Mademoiselle`,
  /// `Monsieur`, `Madame`), qui restent en clair : ce choix-là n'est pas
  /// tranché, celui-ci l'est. Comparaison sur le texte de civilité déjà
  /// matché (trim, sans l'espace de séparation), pas sur une nouvelle
  /// regex — la liste doit rester synchronisée avec l'alternation de
  /// [_civility].
  static const _professionalTitles = {
    'Dr', 'Dr.', 'Dre', 'Dre.', 'Docteur', 'Docteure', 'Pr', 'Pr.',
    'Professeur',
    'Professeure', 'Me', 'Maître', 'Maitre', //
    // P2-69
    'DOCTEUR', 'PROFESSEUR', 'docteur', 'docteure', 'doctoresse', 'professeur',
    'professeure', //
  };

  static bool _motDeLiaison(String s) => s == 'et' || s == 'ou';

  static bool _isProfessionalTitle(String civility) =>
      _professionalTitles.contains(civility.trim());

  /// Séparateurs de mots d'un nom de fichier ou d'un identifiant (P2-71) :
  /// `_` entre deux caractères alphanumériques, et `.` entre deux mots à initiale
  /// majuscule (`Bilan_Pierre_Dupont_2024.pdf`, `Pierre.Dupont.pdf`). Remplacés
  /// par une espace sur une copie de travail de **même longueur** : les
  /// positions restent celles du texte d'origine, dont les valeurs sont relues.
  static final RegExp _soulignes =
      RegExp(r'(?<=[A-Za-zÀ-ÿ0-9])_(?=[A-Za-zÀ-ÿ0-9])');
  static final RegExp _pointsEntreMajuscules =
      RegExp(r'(?<=[A-ZÀ-Þ][a-zà-ÿ]+)\.(?=[A-ZÀ-Þ][a-zà-ÿ])');

  static String _separateursDeMots(String text) {
    if (!text.contains('_') && !text.contains('.')) return text;
    var travail = text;
    if (text.contains('_')) travail = travail.replaceAll(_soulignes, ' ');
    if (text.contains('.')) {
      travail = travail.replaceAll(_pointsEntreMajuscules, ' ');
    }
    return travail;
  }

  /// Extensions de fichier courantes : la dernière partie d'un nom de fichier
  /// n'est pas un nom.
  static const _extensions = {
    'pdf', 'doc', 'docx', 'odt', 'txt', 'md', 'xls', 'xlsx', 'csv', 'ods',
    'ppt', 'pptx', 'png', 'jpg', 'jpeg', 'gif', 'html', 'htm', 'json', 'xml',
    'zip', 'rtf', 'tif', 'tiff', //
  };

  /// Mots qui ne sont pas des noms et qui côtoient un prénom dans un nom de
  /// fichier ou une adresse (documents, articles, prépositions, mots courants).
  static const _motsCourants = {
    'bilan', 'dossier', 'fiche', 'rapport', 'compte', 'rendu', 'courrier',
    'ordonnance', 'certificat', 'scan', 'copie', 'final', 'version', 'projet',
    'note', 'notes', 'liste', 'plan', 'planning', 'cr', 'pour', 'avec', 'sans',
    'sous', 'sur', 'dans', 'chez', 'les', 'des', 'une', 'the', 'and', 'papier',
    'ciseaux', 'pere', 'mere', 'grand', 'grande', 'petit', 'petite', 'chef',
    'lieu', 'rue', 'avenue', 'index', 'home', 'user', 'users', 'admin',
    'profil',
    'patient', 'patiente', 'resident', 'residente', 'suivi', 'visite', 'test',
    'www', 'com', 'org', 'net', 'fr', 'html', 'php', 'asp', //
    'et', 'ou', 'de', 'du', 'la', 'le', 'en', 'au', 'aux', 'un', 'sa', 'son', //
  };

  static final RegExp _slug =
      RegExp(r'(?<![\w.\-])([a-zà-ÿ]{2,}(?:[._-][a-zà-ÿ]{2,}){1,3})(?![\w@])');

  static final RegExp _etiquetteIdentifiant = RegExp(
    r'(?:identifiant|login|utilisateur|username|pseudo|compte|user)[ \t]*[:=][ \t]*$',
    caseSensitive: false,
  );

  /// Nom en minuscules dans un nom de fichier, une adresse web, un chemin ou un
  /// identifiant (P2-71) : `pierre-dupont`, `pierre.dupont`, `@pierre_dupont`,
  /// `ordonnance_pierre_dupont.pdf`. Le contexte est exigé (après `/`, `\`, `@`
  /// ou `=`, devant une extension de fichier, ou derrière « identifiant : »), et
  /// l'une des parties doit être un prénom du gazetteer ; le prénom et ses deux
  /// voisines alphabétiques, hors mots courants, sont couverts.
  List<DetectedEntity> _slugs(String text, List<DetectedEntity> deja) {
    final reserve = _Reserve(text.length);
    for (final e in deja) {
      reserve.add(e.start, e.end);
    }
    final ajouts = <DetectedEntity>[];
    for (final m in _slug.allMatches(text)) {
      var parties = [
        for (final p in RegExp(r'[a-zà-ÿ]+').allMatches(m.group(1)!)) p
      ];
      final base = m.start;
      var extension = false;
      final jeton = m.group(1)!;
      final dernierPoint = jeton.lastIndexOf('.');
      if (dernierPoint > 0 &&
          _extensions.contains(jeton.substring(dernierPoint + 1))) {
        parties = parties.sublist(0, parties.length - 1);
        extension = true;
      }
      if (parties.length < 2) continue;
      final avant = m.start > 0 ? text[m.start - 1] : '';
      final debutLigne =
          text.substring(m.start > 40 ? m.start - 40 : 0, m.start);
      final contexte = extension ||
          '/\\@='.contains(avant) && avant.isNotEmpty ||
          _etiquetteIdentifiant.hasMatch(debutLigne);
      if (!contexte) continue;
      var premier = -1;
      var dernier = -1;
      for (var i = 0; i < parties.length; i++) {
        if (!_isKnownFirstName(parties[i].group(0)!)) continue;
        final voisines = [
          for (final j in [i - 1, i, i + 1])
            if (j >= 0 &&
                j < parties.length &&
                (j == i || !_motsCourants.contains(parties[j].group(0)!)))
              j
        ];
        for (final j in voisines) {
          if (premier == -1 || j < premier) premier = j;
          if (j > dernier) dernier = j;
        }
      }
      if (premier == -1 || dernier - premier < 1) continue;
      final start = base + parties[premier].start;
      final end = base + parties[dernier].end;
      if (reserve.overlaps(start, end)) continue;
      ajouts.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: 0.55,
        ),
      );
      reserve.add(start, end);
    }
    return ajouts;
  }

  @override
  List<DetectedEntity> detect(String text) {
    final base = _detecter(text);
    var resultats = base;
    // Deuxième lecture sur la copie où `_` et `.` séparent des mots (P2-71) : ses
    // entités ne comptent que si elles ne chevauchent pas celles de la première
    // lecture, qui garde seule les clés de données (`nom_patient`) intactes.
    final travail = _separateursDeMots(text);
    if (!identical(travail, text)) {
      // `proprietaire[p]` : index de l'entité de la première lecture qui couvre la
      // position p (-1 sinon) ; coût linéaire en la taille du texte.
      final proprietaire = Int32List(text.length)
        ..fillRange(0, text.length, -1);
      for (var i = 0; i < base.length; i++) {
        proprietaire.fillRange(base[i].start, base[i].end, i);
      }
      final retirees = <int>{};
      final supplements = <DetectedEntity>[];
      for (final e in _detecter(travail)) {
        final touchees = <int>{};
        var deborde = false;
        for (var p = e.start; p < e.end; p++) {
          final o = proprietaire[p];
          if (o != -1) touchees.add(o);
        }
        // Une entité de la seconde lecture qui en recouvre entièrement d'autres
        // les remplace (« Pierre Dupont » pour « Pierre » seul) ; qui les déborde
        // seulement, ou qui chevauche une entité déjà remplacée, elle est écartée.
        for (final o in touchees) {
          if (base[o].start < e.start ||
              base[o].end > e.end ||
              retirees.contains(o)) {
            deborde = true;
          }
        }
        if (deborde) continue;
        retirees.addAll(touchees);
        supplements.add(
          DetectedEntity(
            type: e.type,
            start: e.start,
            end: e.end,
            value: text.substring(e.start, e.end),
            confidence: e.confidence,
            tier: e.tier,
          ),
        );
      }
      if (supplements.isNotEmpty) {
        resultats = [
          for (var i = 0; i < base.length; i++)
            if (!retirees.contains(i)) base[i],
          ...supplements,
        ]..sort((a, b) => a.start - b.start);
      }
    }
    if (!text.contains(RegExp(r'[._-]'))) return resultats;
    final slugs = _slugs(text, resultats);
    if (slugs.isEmpty) return resultats;
    return [...resultats, ...slugs]..sort((a, b) => a.start - b.start);
  }

  List<DetectedEntity> _detecter(String text) {
    final results = <DetectedEntity>[];
    // Parallèle à `results` (même index) : le nom seul, sans le titre
    // professionnel éventuel, pour la deuxième passe (voir
    // [_extractSurname]). Nécessaire parce que `results[i].value` inclut
    // désormais le titre pour une entité issue d'un titre professionnel,
    // ce qui casserait l'extraction du patronyme si on la lisait dessus.
    final surnameSources = <String>[];
    final claimed = _Reserve(text.length);

    for (final match in _civility.allMatches(text)) {
      final name = match.group(1)!;
      final nameStart =
          match.end - name.length; // groupe 1 ancré en fin de match
      final civility = text.substring(match.start, nameStart);
      final includeTitle = _isProfessionalTitle(civility);
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: includeTitle ? match.start : nameStart,
          end: match.end,
          value: includeTitle ? text.substring(match.start, match.end) : name,
          confidence: 0.9,
        ),
      );
      surnameSources.add(name);
      claimed.add(match.start, match.end); // réserve civilité + nom
    }

    for (final match in _champNom.allMatches(text)) {
      if (match.group(0)!.contains('\t') &&
          !_deuxChamps(text, match.start, match.end)) {
        continue;
      }
      final name = match.group(2)!;
      final start = match.end - name.length;
      // Groupe 1 : étiquette précise ; absent pour « Nom » seul.
      if (match.group(1) == null &&
          !_fichePrenomSuit(text, match.start) &&
          !_fichePrenomPrecede(text, match.start)) {
        continue;
      }
      if (claimed.overlaps(start, match.end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: match.end,
          value: name,
          confidence: 0.6,
        ),
      );
      surnameSources.add(name);
      claimed.add(start, match.end);
    }

    // Civilités au pluriel : une entité par nom (P2-69).
    for (final match in _civilitePlurielle.allMatches(text)) {
      final groupe = match.group(1)!;
      final debutGroupe = match.end - groupe.length;
      for (final u in _uniteAt.allMatches(groupe)) {
        final start = debutGroupe + u.start;
        final end = debutGroupe + u.end;
        final name = text.substring(start, end);
        if (_motDeLiaison(name) || claimed.overlaps(start, end)) continue;
        results.add(
          DetectedEntity(
            type: EntityType.nom,
            start: start,
            end: end,
            value: name,
            confidence: 0.9,
          ),
        );
        surnameSources.add(name);
        claimed.add(start, end);
      }
    }

    // Mots de parenté : « la famille Quenelle » (P2-69).
    for (final match in _cueParente.allMatches(text)) {
      final name = match.group(1)!;
      final start = match.end - name.length;
      if (claimed.overlaps(start, match.end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: match.end,
          value: name,
          confidence: 0.7,
        ),
      );
      surnameSources.add(name);
      claimed.add(start, match.end);
    }

    // Nom de naissance ou d'épouse (P2-45).
    for (final match in _nomDeNaissance.allMatches(text)) {
      final name = match.group(1)!;
      final start = match.end - name.length;
      if (claimed.overlaps(start, match.end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: match.end,
          value: name,
          confidence: 0.7,
        ),
      );
      surnameSources.add(name);
      claimed.add(start, match.end);
    }

    // Nom d'un correspondant dans un en-tête de courriel (P2-53).
    for (final (re, enTete) in [
      (_enteteMail, true),
      (_aEcrit, false),
      (_signature, true),
      (_etiquetteRole, true),
      (_cleDonneeLax, true),
      (_cleDonneePlain, true)
    ]) {
      for (final match in re.allMatches(text)) {
        if (identical(re, _etiquetteRole) &&
            match.group(0)!.contains('\t') &&
            !_deuxChamps(text, match.start, match.end)) {
          continue;
        }
        final name = match.group(1)!;
        // Signature : trois mots tout en majuscules (« POUR LE SERVICE »)
        // sont une mention, non un nom.
        if (identical(re, _signature) &&
            name == name.toUpperCase() &&
            name.split(RegExp(r'\s+')).length > 2) {
          continue;
        }
        // L'étiquette précède le nom (dernière occurrence : « De : D ») ; la
        // forme « a écrit » commence par le nom.
        final start = enTete
            ? match.start + match.group(0)!.lastIndexOf(name)
            : match.start;
        final end = start + name.length;
        if (claimed.overlaps(start, end)) continue;
        results.add(
          DetectedEntity(
            type: EntityType.nom,
            start: start,
            end: end,
            value: name,
            confidence: 0.6,
          ),
        );
        surnameSources.add(name);
        claimed.add(start, end);
      }
    }

    // Cellules de noms d'un tableau CSV à en-tête (P2-61).
    for (final c in cellulesDeNoms(text)) {
      if (claimed.overlaps(c.start, c.end)) continue;
      final name = text.substring(c.start, c.end);
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: c.start,
          end: c.end,
          value: name,
          confidence: 0.7,
        ),
      );
      surnameSources.add(name);
      claimed.add(c.start, c.end);
    }

    // Prénom(s) derrière l'étiquette « Prénom » (P2-40), connus ou non du
    // gazetteer.
    for (final match in _champPrenom.allMatches(text)) {
      if (match.group(0)!.contains('\t') &&
          !_deuxChamps(text, match.start, match.end)) {
        continue;
      }
      final name = match.group(1)!;
      final start = match.end - name.length;
      if (claimed.overlaps(start, match.end)) continue;
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: match.end,
          value: name,
          confidence: 0.6,
        ),
      );
      surnameSources.add(name);
      claimed.add(start, match.end);
    }

    for (final match in _capitalizedWord.allMatches(text)) {
      final word = match.group(0)!;
      if (_isExcludedAcronym(word)) continue;
      if (!_looksLikeKnownFirstName(word)) continue;
      if (claimed.overlaps(match.start, match.end)) continue;

      // Règle bidirectionnelle : un nom de famille supposé peut précéder
      // ou suivre le prénom reconnu, sans condition de casse dans un sens
      // comme dans l'autre (voir le commentaire de classe).
      final before = _matchPrevCapitalizedWord(text, match.start) ??
          _matchPrevVirgule(text, match.start, match.end);
      final hasFreeLastNameBefore =
          before != null && !claimed.overlaps(before.start, before.end);

      final after = _matchNextCapitalizedWord(text, match.end);
      final hasFreeLastNameAfter =
          after != null && !claimed.overlaps(after.start, after.end);

      final int start;
      final int end;
      final double confidence;
      if (hasFreeLastNameBefore && hasFreeLastNameAfter) {
        // Un mot capitalisé de chaque côté (« Appeler Pierre Dupont », « Patient
        // Pierre Dupont ») : on ne sait pas lequel est le patronyme. Les deux sont
        // couverts (P2-70) ; en prendre un seul laissait l'autre en clair.
        start = before.start;
        end = after.end;
        confidence = 0.6;
      } else if (hasFreeLastNameBefore) {
        start = before.start;
        end = match.end;
        confidence = 0.6;
      } else if (hasFreeLastNameAfter) {
        start = match.start;
        end = after.end;
        confidence = 0.6;
      } else {
        start = match.start;
        end = match.end;
        confidence = 0.5;
      }
      results.add(
        DetectedEntity(
          type: EntityType.nom,
          start: start,
          end: end,
          value: text.substring(start, end),
          confidence: confidence,
        ),
      );
      surnameSources.add(text.substring(start, end));
      claimed.add(start, end);
    }

    // --- Deuxième passe : rattrapage des mentions partielles via un
    // patronyme déjà établi par la première passe (voir le commentaire de
    // classe). Ne s'exécute que si au moins un patronyme fiable a été
    // extrait — sur un document sans mention complète, rien ne change.
    //
    // Lit `surnameSources`, pas `results[i].value` : pour une entité issue
    // d'un titre professionnel, `value` inclut le titre (« Pr Nadia
    // Costa »), ce qui ferait échouer `_extractSurname` (borné à 1 ou 2
    // mots). `surnameSources[i]` reste le nom seul dans tous les cas.
    final knownSurnames = <String>{...this.knownSurnames};
    for (var i = 0; i < results.length; i++) {
      final surname = _extractSurname(results[i].confidence, surnameSources[i]);
      if (surname == null || _isExcludedAcronym(surname)) continue;
      knownSurnames.add(surname.toLowerCase());
    }

    if (knownSurnames.isNotEmpty) {
      for (final match in _capitalizedWord.allMatches(text)) {
        final word = match.group(0)!;
        if (_isExcludedAcronym(word)) continue;
        if (!knownSurnames.contains(word.toLowerCase())) continue;
        if (claimed.overlaps(match.start, match.end)) continue;

        // Uniquement la direction « après » (pas « avant ») : sans
        // vérification gazetteer sur le mot adjacent — le principe même de
        // cette passe est de couvrir des prénoms absents du gazetteer —
        // apparier vers l'avant est nettement moins exposé aux faux
        // positifs qu'apparier vers l'arrière, où un mot capitalisé de
        // début de phrase précède très souvent un patronyme sans aucun
        // rapport (voir la limite déjà documentée sur la règle
        // bidirectionnelle).
        final after = _matchNextCapitalizedWord(text, match.end);
        final hasFreeWordAfter =
            after != null && !claimed.overlaps(after.start, after.end);

        final int start;
        final int end;
        if (hasFreeWordAfter) {
          start = match.start;
          end = after.end;
        } else {
          start = match.start;
          end = match.end;
        }
        results.add(
          DetectedEntity(
            type: EntityType.nom,
            start: start,
            end: end,
            value: text.substring(start, end),
            confidence: 0.6,
          ),
        );
        claimed.add(start, end);
      }
    }

    results.sort((a, b) => a.start - b.start);
    return results;
  }

  /// Patronyme (casse d'origine) qu'une entité `nom` déjà détectée établit
  /// sans ambiguïté, ou `null` (P2-14). Sert à amorcer les documents suivants
  /// d'un dossier. [value] peut commencer par un titre professionnel
  /// (« Dr Nadia Costa »), qui est écarté. Retient : un mot après une civilité
  /// (confiance 0.9) et un couple de deux mots dont **un seul** est un prénom
  /// connu (confiance 0.6). Un prénom seul, un mot isolé ou un couple dont
  /// aucun ou les deux mots sont des prénoms n'établissent rien.
  static String? patronymeEtabli(String value, double confidence) {
    var words = value.trim().split(RegExp(r'\s+'));
    if (words.length > 1 && _professionalTitles.contains(words.first)) {
      words = words.sublist(1);
    }
    final name = words.join(' ');
    if (confidence == 0.9) return _extractSurname(confidence, name);
    if (confidence == 0.6 && words.length == 2) {
      final firstIsFirstName = _looksLikeKnownFirstName(words[0]);
      final secondIsFirstName = _looksLikeKnownFirstName(words[1]);
      if (firstIsFirstName == secondIsFirstName) return null;
      return firstIsFirstName ? words[1] : words[0];
    }
    return null;
  }

  /// Patronyme extrait d'une mention **certaine** (civilité, ou couple
  /// prénom+nom bidirectionnel), utilisé pour amorcer la deuxième passe.
  /// Retourne `null` quand aucun patronyme fiable ne peut être isolé — un
  /// prénom isolé (confiance 0.5, sans nom de famille adjacent) n'établit
  /// aucun patronyme.
  ///
  /// [value] est le **nom seul**, jamais le titre professionnel éventuel
  /// (voir `surnameSources` dans [detect]) : un titre inclus ferait
  /// gonfler le nombre de mots et empêcherait toute extraction.
  static String? _extractSurname(double confidence, String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      // Un seul mot : fiable uniquement depuis la civilité (confiance
      // 0.9), où le mot qui suit « Dr »/« Mme »/etc. est conventionnellement
      // un nom de famille en usage professionnel français.
      return confidence == 0.9 ? words.first : null;
    }
    if (words.length == 2) {
      final first = words[0];
      final second = words[1];
      final firstIsFirstName = _looksLikeKnownFirstName(first);
      final secondIsFirstName = _looksLikeKnownFirstName(second);
      if (firstIsFirstName && !secondIsFirstName) return second;
      if (secondIsFirstName && !firstIsFirstName) return first;
      // Ambigu (aucun des deux mots reconnu comme prénom, ou les deux) :
      // convention la plus fréquente en français courant, « Prénom Nom »
      // -> le second mot est retenu comme patronyme.
      return second;
    }
    return null;
  }

  /// [word] est-il un prénom français connu, tel quel ou via l'un de ses
  /// segments s'il s'agit d'un prénom composé (« Jean-Marc », « Anne-
  /// Sophie ») ? Le motif capitalisé englobe déjà le tiret dans un seul
  /// jeton (voir [_capitalizedWord]), donc un prénom composé n'apparaît
  /// jamais tel quel dans [frenchFirstNames] : il faut regarder ses
  /// segments plutôt que le jeton entier.
  static bool _looksLikeKnownFirstName(String word) {
    if (_isKnownFirstName(word)) return true;
    if (!word.contains('-')) return false;
    return word.split('-').any(_isKnownFirstName);
  }

  /// Le gazetteer est en minuscules **sans accents** (sauf rares entrées) :
  /// on compare la forme brute et la forme dépouillée de ses accents, sinon
  /// « Stéphane » ou « Hélène » ne seraient jamais reconnus.
  static bool _isKnownFirstName(String word) {
    final lower = word.toLowerCase();
    return frenchFirstNames.contains(lower) ||
        frenchFirstNames.contains(_foldAccents(lower));
  }

  static const Map<String, String> _accentMap = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', //
    'ÿ': 'y', 'ç': 'c', 'œ': 'oe', 'æ': 'ae', 'ñ': 'n', //
  };

  static String _foldAccents(String lower) =>
      lower.split('').map((c) => _accentMap[c] ?? c).join();

  /// Cherche le mot capitalisé suivant immédiatement (séparé uniquement par
  /// des espaces) la position [from]. Retourne `null` s'il n'y en a pas.
  ///
  /// `matchAsPrefix` ancre déjà la recherche à [from] : il ne faut pas de
  /// `^` dans le motif, qui référence le tout début de la chaîne et non la
  /// position de départ passée en argument.
  static Match? _matchNextCapitalizedWord(String text, int from) {
    final gapMatch = _ecart.matchAsPrefix(text, from);
    if (gapMatch == null) return null;
    final wordMatch = _uniteAt.matchAsPrefix(text, gapMatch.end);
    if (wordMatch == null || _isExcludedAcronym(wordMatch.group(0)!)) {
      return null;
    }
    return wordMatch;
  }

  /// Cherche un mot capitalisé (majuscules ou casse normale) séparé
  /// uniquement par des espaces de la position [before]. Retourne `null`
  /// s'il n'y en a pas, ou si ce mot est un sigle exclu (voir
  /// [_excludedAcronyms]) — un sigle ne doit jamais être avalé comme s'il
  /// s'agissait d'un nom de famille adjacent à un prénom reconnu.
  static _WordSpan? _matchPrevCapitalizedWord(String text, int before) {
    // Fenêtre bornée (P2-48) : copier et parcourir tout le texte qui précède
    // rendait la détection quadratique (4 000 mentions : 11 s). Un mot de plus de
    // [_fenetreMotPrecedent] caractères n'est plus reconnu en entier.
    final debut =
        before > _fenetreMotPrecedent ? before - _fenetreMotPrecedent : 0;
    final head = text.substring(debut, before);
    final match = _wordBeforeEnd.firstMatch(head);
    if (match == null) return null;
    final word = match.group(1)!;
    if (_isExcludedAcronym(word)) return null;
    // Le groupe capturé est en tête du motif : son début coïncide avec
    // celui du match entier.
    return _WordSpan(debut + match.start, debut + match.start + word.length);
  }

  /// Mots d'adresse ou de liaison qui précèdent une virgule puis un prénom
  /// sans être un patronyme (« Bonjour, Odette »).
  static const String _avantVirgule =
      'Bonjour|Bonsoir|Salut|Merci|Cordialement|Bien|Cher|Chère|Chers|Alors|Donc|'
      'Oui|Non|Voilà|Voila|Allô|Allo|Hello|Hi|Dear|Madame|Monsieur|Docteur|Dr|'
      'Mme|Mlle|Ensuite|Puis|Enfin|Aussi|Ainsi|Pourtant|Pardon|Désolé|Bravo|Ok|OK';

  static final RegExp _nomVirgule = RegExp(
    '($_cap),$_h+\$',
  );

  static final RegExp _apresPrenomVirgule = RegExp(
    r'^[ \t\u00A0\u202F]*(?:[(,;:\n\r\-\u2013\u2014.]|\d|$)',
  );

  /// Forme « Nom, Prénom » (P2-74) : le mot capitalisé avant « , » qui précède le
  /// prénom commençant en [prenomDebut] et finissant en [prenomFin]. Seulement si
  /// le prénom est suivi d'une ponctuation, d'une parenthèse, d'un chiffre ou de
  /// la fin de ligne (jamais d'une phrase qui continue en minuscules), et si ce
  /// mot n'est pas une formule d'adresse.
  static _WordSpan? _matchPrevVirgule(
      String text, int prenomDebut, int prenomFin) {
    final fin = prenomFin + 40 < text.length ? prenomFin + 40 : text.length;
    if (!_apresPrenomVirgule.hasMatch(text.substring(prenomFin, fin))) {
      return null;
    }
    final debut = prenomDebut > _fenetreMotPrecedent
        ? prenomDebut - _fenetreMotPrecedent
        : 0;
    final head = text.substring(debut, prenomDebut);
    final match = _nomVirgule.firstMatch(head);
    if (match == null) return null;
    final word = match.group(1)!;
    if (_isExcludedAcronym(word) ||
        RegExp('^(?:$_avantVirgule)\$').hasMatch(word)) {
      return null;
    }
    return _WordSpan(debut + match.start, debut + match.start + word.length);
  }

  static const int _fenetreMotPrecedent = 400;

  static final RegExp _ecart = RegExp('$_h+');
}

final class _WordSpan {
  const _WordSpan(this.start, this.end);
  final int start;
  final int end;
}

/// Plages du texte déjà réservées par une entité (P2-48). Un masque par caractère
/// plutôt qu'une liste de plages parcourue à chaque mot candidat, qui rendait la
/// détection quadratique avec des milliers de mentions. Même sémantique : deux
/// plages se recouvrent si elles partagent au moins un caractère.
final class _Reserve {
  _Reserve(int length) : _pris = Uint8List(length);

  final Uint8List _pris;

  void add(int start, int end) {
    for (var i = start; i < end; i++) {
      _pris[i] = 1;
    }
  }

  bool overlaps(int start, int end) {
    for (var i = start; i < end; i++) {
      if (_pris[i] != 0) return true;
    }
    return false;
  }
}
