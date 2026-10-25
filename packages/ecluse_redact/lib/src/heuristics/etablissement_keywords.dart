/// Mots-clés qui ouvrent un nom d'établissement. Partagés avec
/// `NameDetector` : un nom de personne ne doit jamais absorber l'un de ces
/// mots comme patronyme, sinon son span chevauche l'établissement voisin et
/// la résolution des chevauchements supprime l'un des deux (fuite).
///
/// Interne au paquet : non exporté par `ecluse_redact.dart`.
const List<String> etablissementKeywords = [
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
];
