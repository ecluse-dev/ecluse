/// Mots-clés qui ouvrent un nom d'établissement. Partagés avec
/// `NameDetector` : un nom de personne ne doit jamais absorber l'un de ces
/// mots comme patronyme, sinon son span chevauche l'établissement voisin et
/// la résolution des chevauchements supprime l'un des deux (fuite).
///
/// Interne au paquet : non exporté par `ecluse_redact.dart`.
const List<String> etablissementKeywords = [
  "Foyer d'accueil médicalisé",
  'Foyer d’accueil médicalisé',
  'Foyer',
  'Résidence',
  'Residence',
  'IME',
  'ITEP',
  'ESAT',
  'EHPAD',
  'MAS',
  'FAM',
  'Centre',
  'CH',
  'SSIAD',
  'Clinique',
  'Hôpital',
  'Hopital',
  'Lycée',
  'Lycee',
  'CHU',
  'CHR',
  'CHRU',
  'CHS',
  'SESSAD',
  'IMPro',
  'IMP',
  'Maison de retraite',
  'Institut Médico-Éducatif',
  'Institut Médico-Educatif',
];

/// Mots-clés reconnus aussi en minuscules : suffisamment spécifiques pour ne
/// pas être des mots courants (« centre » seul ne l'est pas, d'où son
/// absence). Non utilisés par `NameDetector`.
const List<String> etablissementKeywordsMinuscules = [
  'centre hospitalier',
  'maison de retraite',
];
