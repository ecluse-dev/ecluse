import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Sur-masquages fréquents relevés par une relecture adverse indépendante
/// (P2-77) : fonctions après une civilité, mots de statut, jours et adverbes
/// avalés avec un prénom, toponymes « Saint-… », éponymes médicaux, numéros de
/// lot. Chaque cas dégradait un prompt (la fonction, la date ou le statut
/// disparaissait) sans protéger personne. Les témoins prouvent que les vrais
/// noms restent masqués.
void main() {
  const intacts = {
    // Fonction après civilité.
    'Madame la Directrice a signé la convention.': 'la Directrice',
    'Monsieur le Directeur de l\'EHPAD a répondu.': 'le Directeur',
    'Madame le Maire a été informée.': 'le Maire',
    'Monsieur le Président de la République.': 'le Président',
    'Mme la Préfète est attendue.': 'la Préfète',
    // Mot de statut après civilité ou parenté.
    'Mme Décédée.': 'Décédée',
    'Madame Âgée de 82 ans.': 'Âgée',
    'Mme Aidante principale.': 'Aidante',
    'Mme Retraitée depuis 2010.': 'Retraitée',
    'Mme Hospitalisée le 3 mars.': 'Hospitalisée',
    'M. Bénéficiaire du RSA.': 'Bénéficiaire',
    'Famille Monoparentale en situation de précarité.': 'Monoparentale',
    'Famille Recomposée avec trois enfants.': 'Recomposée',
    'Famille Nombreuse, quatre enfants à charge.': 'Nombreuse',
    'Père Divorcé, mère absente.': 'Divorcé',
    'Époux Décédé en 2020.': 'Décédé',
    // Champ d'état civil.
    'Situation familiale : Marié, deux enfants': 'Marié',
    'État civil : Mariée': 'Mariée',
    'Statut familial : Marié': 'Marié',
    // Toponymes.
    'Le patient vient de Saint-Denis.': 'Saint-Denis',
    'Département de la Seine-Saint-Denis (93).': 'Seine-Saint-Denis',
    'Centre hospitalier de Saint-Malo.': 'Saint-Malo',
    'Fête de la Saint-Jean.': 'Saint-Jean',
    // Éponymes médicaux.
    'Maladie de Charcot-Marie-Tooth.': 'Charcot-Marie-Tooth',
    'Syndrome de Gilles de la Tourette': 'Gilles de la Tourette',
    // Numéro de lot.
    'Numéro de lot : AB-123-CD': 'AB-123-CD',
    'Série : AB-123-CD': 'AB-123-CD',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Le prénom reste masqué, le jour ou l'adverbe reste lisible.
  const temporels = {
    'Lundi Marie viendra pour le ménage.': 'Lundi',
    'Hier Sophie est venue.': 'Hier',
    'Demain Thomas sera absent.': 'Demain',
    'Ensuite Julien prendra le relais.': 'Ensuite',
    'Merci Pierre pour le retour.': 'Merci',
    'Jeudi Lucas a rendez-vous chez l\'orthophoniste.': 'Jeudi',
  };
  for (final MapEntry(key: texte, value: mot) in temporels.entries) {
    test('jour ou adverbe conservé, prénom masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(mot), reason: r.maskedText);
      expect(r.maskedText, contains('[NOM_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Témoins : les vrais noms restent masqués.
  const masques = {
    'Madame Dupont a signé.': 'Dupont',
    'Mme Quenelle est venue.': 'Quenelle',
    'Famille Quenelle présente': 'Quenelle',
    'Les époux Quenelle': 'Quenelle',
    'Marie Dupont, mariée': 'Dupont',
    'Mme Saint-Pierre est venue.': 'Saint-Pierre',
    'Dr Alzheimer a décrit la maladie.': 'Alzheimer',
    'Appeler Pierre Dupont demain.': 'Dupont',
    'Merci Pierre Dupont': 'Dupont',
    'Mardi Pierre Dupont viendra.': 'Dupont',
    'Plaque AB-123-CD': 'AB-123-CD',
    'Il circule en CD-456-EF hier': 'CD-456-EF',
    'Madame La Fontaine est venue.': 'Fontaine',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('témoin, toujours masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
