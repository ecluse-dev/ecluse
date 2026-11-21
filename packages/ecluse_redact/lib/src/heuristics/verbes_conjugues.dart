/// Verbes conjugués d'usage courant (P2-240), forme de la 3e personne.
///
/// Pourquoi : sans casse, « Sophie rappelle. » ne se distingue pas de « marc
/// loyer » : un prénom suivi d'un mot est lu comme un nom de deux mots. Le
/// verbe est alors masqué, puis retenu comme patronyme établi et masqué dans
/// toute la suite d'un dossier. Exigence du mainteneur (20 novembre) : **aucun
/// verbe ne doit être masqué**, le LLM en a besoin pour travailler sur le texte.
///
/// Liste fermée, écrite par le projet (verbes d'usage courant en contexte de
/// soin, de courrier et de planning), **pas** tirée d'un corpus : elle ne couvre
/// que ce qu'elle nomme, et un verbe qui n'y figure pas reste masqué avec son
/// prénom (mesure du lot `reserve` de `generate_corpus_prenom_verbe.py`).
///
/// Coût assumé, écrit dans `LIMITES.md` : un **patronyme homographe** d'un de
/// ces verbes (Porte, Marche, Pense…) passe en clair derrière un prénom. Une
/// terminaison seule ne décide pas (Laurent, Vincent, Clément finissent en
/// « -ent »), donc seules les terminaisons d'imparfait et de conditionnel
/// (« -ait », « -aient », « -erait », « -eraient ») et de futur (« -eront »)
/// sont reconnues par la forme : aucun patronyme des corpus ne la porte.
///
/// Les mots outils (« est », « fait », « dit », « vient »…) sont déjà écartés
/// par `NomMinusculesDetector` : ils figurent ici par cohérence, sans effet.
library;

/// Formes en minuscules, avec accents.
const Set<String> verbesConjuguesCourants = {
  // Communication, contact.
  'rappelle', 'appelle', 'téléphone', 'contacte', 'répond', 'parle', 'écoute',
  'demande', 'explique', 'précise', 'signale', 'confirme', 'informe',
  'prévient', 'écrit', 'dit', 'annonce', 'indique', 'propose', 'refuse',
  'accepte', 'insiste', 'hésite', 'réclame', 'envoie', 'transmet', 'relit',
  'signe', 'valide', 'oublie', 'note', 'remercie', 'répète', 'rappellera',
  'appellera', 'répondra', 'écrira', 'confirmera',
  // Déplacement, présence.
  'arrive', 'vient', 'entre', 'passe', 'sort', 'part', 'revient', 'reste',
  'monte', 'descend', 'rentre', 'retourne', 'rejoint', 'accueille',
  'accompagne', 'quitte', 'suit', 'précède', 'marche', 'court', 'va',
  // Action, état.
  'veut', 'doit', 'peut', 'fait', 'prend', 'donne', 'cherche', 'trouve',
  'attend', 'commence', 'finit', 'termine', 'regarde', 'pense', 'pose',
  'montre', 'change', 'garde', 'joue', 'lit', 'voit', 'sait', 'vit', 'mange',
  'dort', 'travaille', 'aime', 'préfère', 'souhaite', 'espère', 'craint',
  'semble', 'devient', 'reçoit', 'soutient', 'retient', 'tient', 'porte',
  'apporte', 'emporte', 'rapporte', 'ouvre', 'ferme', 'range', 'met',
  'remet', 'laisse', 'perd', 'gagne', 'coupe', 'tire', 'pousse', 'tombe',
  'lève', 'sert', 'sent', 'ressent', 'connaît', 'comprend', 'apprend',
  'reprend', 'surveille', 'soigne', 'aide', 'assiste', 'conduit', 'dirige',
  'gère', 'organise', 'prépare', 'vérifie', 'contrôle', 'examine', 'ausculte',
  'prescrit', 'refait', 'continue', 'arrête', 'essaie', 'essaye',
  'utilise', 'choisit', 'décide', 'oblige', 'permet', 'empêche', 'évite',
  'doute', 'croit', 'ignore', 'visite', 'habite', 'déménage', 'dépose',
  'récupère', 'lave', 'habille', 'couche', 'réveille', 'endort', 'nourrit',
  'boit', 'marque', 'compte', 'calcule', 'paie', 'paye', 'coûte', 'vaut',
  'manque', 'suffit', 'convient', 'existe', 'appartient', 'occupe',
  // Écrit soignant, social et administratif (P2-242) : verbes d'usage des
  // transmissions et comptes rendus, 3e personne du singulier, écrits par
  // champ lexical sans consulter les verbes des sondes `reserve` et
  // `reserve2` (un test contrôle que `reserve2` n'y figure pas).
  'alimente', 'améliore', 'aggrave', 'allonge', 'aménage', 'applique',
  'arrose', 'assure', 'attribue', 'augmente', 'baisse', 'bouge', 'brosse',
  'calme', 'cesse', 'communique', 'compense', 'comprime', 'conserve',
  'consulte', 'décrit', 'diminue', 'dispose', 'distingue', 'documente',
  'douche', 'échange', 'éclaire', 'effectue', 'élimine', 'emploie', 'encadre',
  'enregistre', 'entretient', 'envisage', 'équipe', 'excuse', 'exige',
  'exprime', 'facilite', 'favorise', 'fatigue', 'fournit', 'fréquente',
  'gêne', 'glisse', 'guérit', 'hausse', 'imagine', 'impose', 'inquiète',
  'insère', 'installe', 'intervient', 'invite', 'isole', 'justifie',
  'maintient', 'manifeste', 'mélange', 'mène', 'mérite', 'minimise',
  'mouille', 'neutralise', 'obtient', 'occasionne', 'offre', 'ordonne',
  'participe', 'pleure', 'plie', 'présente', 'prévoit', 'procède', 'produit',
  'progresse', 'promet', 'protège', 'provoque', 'raconte', 'rattrape',
  'réagit', 'réalise', 'rechute', 'recommande', 'recommence', 'réduit',
  'regroupe', 'rejette', 'relaie', 'relance', 'remarque', 'rencontre',
  'renforce', 'renvoie', 'répartit', 'réside', 'respecte', 'respire',
  'ressort', 'rougit', 'rend', 'saigne', 'salue', 'satisfait', 'serre',
  'signifie', 'soulage', 'souffre', 'soumet', 'sourit', 'stabilise',
  'suggère', 'supporte', 'surprend', 'tolère', 'touche', 'traite',
  'transporte', 'transpire', 'tousse', 'tremble', 'vomit', 'veille', 'voyage',
  'accélère', 'accroche', 'adapte', 'adopte', 'affirme', 'agite', 'agit',
  'ajoute', 'ajuste', 'allume', 'amène', 'amuse', 'analyse', 'apprécie',
  'approche', 'argumente', 'arrange', 'aspire', 'associe', 'attire',
  'attrape', 'avance', 'avertit', 'avoue', 'balaie', 'bavarde', 'blesse',
  'bloque', 'bouscule', 'branche', 'brûle', 'cache', 'casse', 'célèbre',
  'chante', 'choque', 'cite', 'cloue', 'compare', 'complique', 'concerne',
  'condamne', 'confie', 'conseille', 'consent', 'constitue', 'consomme',
  'contient', 'contourne', 'convainc', 'crie', 'cuisine', 'danse', 'débute',
  'décroche', 'défend', 'dégage', 'déjeune', 'demeure', 'dépasse', 'dépend',
  'déplace', 'désigne', 'détaille', 'détecte', 'détient', 'détruit',
  'développe', 'devine', 'diffuse', 'dîne', 'discute', 'disparaît',
  'disperse', 'distrait', 'divise', 'dresse', 'échappe', 'échoue', 'écarte',
  'éloigne', 'emmène', 'empile', 'enlève', 'ennuie', 'enseigne', 'entame',
  'entend', 'envahit', 'épuise', 'escalade', 'espace', 'essuie', 'étale',
  'étend', 'étonne', 'étudie', 'évolue', 'exagère', 'exécute', 'exerce',
  'explore', 'expose', 'fabrique', 'fâche', 'fête', 'fléchit', 'fonctionne',
  'forme', 'fouille', 'fuit', 'gratte', 'grandit', 'gronde', 'habitue',
  'hurle', 'impatiente', 'incite', 'inclut', 'intègre', 'interdit',
  'interrompt', 'introduit', 'inverse', 'irrite', 'jette', 'juge', 'jure',
  'lèche', 'limite', 'loge', 'maîtrise', 'manipule', 'masque', 'mord',
  'motive', 'nage', 'nie', 'obéit', 'ôte', 'oppose', 'opère', 'palpe',
  'parcourt', 'parvient', 'penche', 'perçoit', 'persuade', 'peigne', 'plaint',
  'plaît', 'plonge', 'pleut', 'pratique', 'précipite', 'prie', 'profite',
  'prolonge', 'prononce', 'propage', 'prouve', 'pulvérise', 'punit', 'rabat',
  'raccompagne', 'ralentit', 'ramasse', 'ramène', 'rattache', 'ravit',
  'recueille', 'redevient', 'redoute', 'réfléchit', 'refroidit', 'regagne',
  'réjouit', 'remonte', 'rémunère', 'répare', 'repose', 'reproche', 'résiste',
  'résout', 'ressemble', 'restitue', 'retarde', 'retire', 'retrouve',
  'réunit', 'réussit', 'révèle', 'revoit', 'rêve', 'rigole', 'salit', 'sauve',
  'secoue', 'sème', 'sépare', 'situe', 'souligne', 'soupire', 'sous-estime',
  'souvient', 'stresse', 'subit', 'succède', 'suspend', 'tarde', 'tourne',
  'tranche', 'trébuche', 'trompe', 'trouble', 'vend', 'vieillit', 'vole',
  // Pluriel (3e personne), formes d'usage courant.
  'rappellent', 'appellent', 'arrivent', 'viennent', 'veulent', 'doivent',
  'peuvent', 'entrent', 'passent', 'demandent', 'répondent', 'parlent',
  'travaillent', 'font', 'prennent', 'donnent', 'cherchent', 'trouvent',
  'attendent', 'commencent', 'restent', 'sortent', 'partent', 'regardent',
  'écoutent', 'pensent', 'disent', 'voient', 'savent', 'vivent', 'écrivent',
  'confirment', 'refusent', 'acceptent', 'proposent', 'envoient',
  'transmettent', 'reviennent', 'tiennent', 'reçoivent',
};

/// Terminaisons qui désignent un verbe conjugué par la forme (P2-240, P2-242) :
/// imparfait, conditionnel et futur d'un verbe en « -er » (« -ait », « -aient »,
/// « -erait », « -eraient », « -eront »), puis des terminaisons de présent
/// choisies **une à la fois** parce qu'aucun nom annoté des corpus du dépôt ni
/// aucun prénom INSEE d'effectif d'au moins 1 000 ne les porte
/// (`bench/mesure_terminaisons_verbes.py`) : « -ifie » (planifie, justifie),
/// « -ionne » (mentionne), « -ifient », « -ionnent », « -isent », « -issent »,
/// « -ivent » (arrivent, suivent) et « -iera » (futur). Écartées malgré un
/// compte nul sur les noms annotés : « -ise » (Louise, Denise), « -era »
/// (Herrera), « -dra » (Sandra), « -ère » (Barrère), « -ite », « -ige »,
/// « -are », « -ule » : des prénoms ou des patronymes réels les portent.
final RegExp _terminaisonVerbale = RegExp(
    r'(?:ait|aient|erait|eraient|eront|ifie|ionne|ifient|ionnent|isent|issent|ivent|iera)$');

/// Vrai si [mot] (en minuscules) est un verbe conjugué d'usage courant.
///
/// Trois voies : la liste fermée, les terminaisons ci-dessus, puis les formes
/// **dérivées** d'un verbe de la liste en « -e » : pluriel (« rappelle » →
/// « rappellent ») et futur du singulier (« rappelle » → « rappellera »). La
/// dérivation ne s'applique qu'à une base de la liste, jamais à un mot
/// quelconque en « -ent » ou en « -ra » (Laurent, Sandra) ; un test vérifie
/// qu'aucune forme dérivée n'est un nom annoté ni un prénom courant.
bool estVerbeConjugue(String mot) {
  if (verbesConjuguesCourants.contains(mot)) return true;
  if (mot.length > 4 && _terminaisonVerbale.hasMatch(mot)) return true;
  if (mot.length > 5) {
    if (mot.endsWith('nt') &&
        verbesConjuguesCourants.contains(mot.substring(0, mot.length - 2)) &&
        mot.endsWith('ent')) {
      return true;
    }
    if (mot.endsWith('ra') &&
        verbesConjuguesCourants.contains(mot.substring(0, mot.length - 2)) &&
        mot.endsWith('era')) {
      return true;
    }
  }
  return false;
}
