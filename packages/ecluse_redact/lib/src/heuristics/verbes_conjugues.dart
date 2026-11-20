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
  // Pluriel (3e personne), formes d'usage courant.
  'rappellent', 'appellent', 'arrivent', 'viennent', 'veulent', 'doivent',
  'peuvent', 'entrent', 'passent', 'demandent', 'répondent', 'parlent',
  'travaillent', 'font', 'prennent', 'donnent', 'cherchent', 'trouvent',
  'attendent', 'commencent', 'restent', 'sortent', 'partent', 'regardent',
  'écoutent', 'pensent', 'disent', 'voient', 'savent', 'vivent', 'écrivent',
  'confirment', 'refusent', 'acceptent', 'proposent', 'envoient',
  'transmettent', 'reviennent', 'tiennent', 'reçoivent',
};

/// Terminaisons d'imparfait, de conditionnel et de futur d'un verbe en « -er ».
final RegExp _terminaisonVerbale =
    RegExp(r'(?:ait|aient|erait|eraient|eront)$');

/// Vrai si [mot] (en minuscules) est un verbe conjugué d'usage courant.
bool estVerbeConjugue(String mot) =>
    verbesConjuguesCourants.contains(mot) ||
    (mot.length > 4 && _terminaisonVerbale.hasMatch(mot));
