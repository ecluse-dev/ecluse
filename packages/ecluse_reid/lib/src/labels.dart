import 'package:ecluse_reference/ecluse_reference.dart';

import 'qi.dart';

/// Rendu textuel d'un QI pour la narration DPO (`ReidTrace.explainNarrative`)
/// — jamais utilisé pour le calcul de F (voir `estimator.dart` /
/// `generalizer.dart` pour la logique).
String qiValueLabel(EcluseReference ref, Qi qi) {
  switch (qi.type) {
    case QiType.lieu:
      if (qi.value == lieuFrance) return 'France';
      if (qi.level == 0) {
        final commune = ref.geo.communeByCode(qi.value);
        return commune?.libelle ?? qi.value;
      }
      return 'département ${qi.value}'; // pas de libellé dép. dans les assets
    case QiType.age:
      if (qi.value == qiRetraitValue) return '(âge retiré)';
      if (qi.value.contains('-')) return '${qi.value} ans';
      return '${qi.value} ans';
    case QiType.profession:
      if (qi.value == professionnelDeSante) {
        return 'professionnel de santé (toute profession)';
      }
      if (qi.value == professionToutesSpecialites) {
        return 'médecin (toute spécialité)';
      }
      if (qi.value == qiRetraitValue) return '(profession retirée)';
      return ref.rarity.specialtyLabel(qi.value) ?? qi.value;
  }
}
