/// Documents de démonstration — **entièrement fictifs**.
///
/// Toute ressemblance avec des personnes ou établissements réels serait
/// une coïncidence. Les identifiants (NIR, IBAN) sont structurellement
/// valides (clé de contrôle correcte) afin que les détecteurs d'
/// `ecluse_core` se déclenchent réellement, mais ne correspondent à
/// aucune personne existante.
library;

/// Un document d'exemple pour la démo, avec la consigne par défaut à
/// envoyer au LLM.
final class DemoSample {
  const DemoSample({
    required this.title,
    required this.text,
    required this.instruction,
  });

  final String title;
  final String text;
  final String instruction;
}

/// Contrat de travail fictif — nom/prénom du salarié, adresse, date de
/// naissance, NIR, IBAN de versement du salaire, établissement employeur,
/// nom du responsable signataire, téléphone et email.
const contratTravailSample = DemoSample(
  title: 'Contrat de travail',
  instruction: 'Résume les obligations de chaque partie et vérifie que les '
      'mentions obligatoires sont présentes.',
  text: '''
CONTRAT DE TRAVAIL À DURÉE INDÉTERMINÉE

Entre les soussignés :

Le Foyer Les Tilleuls, établissement d'accueil pour adultes handicapés
situé 8 rue de la Mairie, 44000 Nantes, représenté par Mme Claire Bonnard,
Directrice,

Et

M. Julien Vasseur, né le 12 mai 1988, demeurant 14 rue des Acacias, 44000
Nantes, numéro de sécurité sociale 1 88 05 44 056 003 25,

Il a été convenu ce qui suit :

Article 1 — Engagement
M. Julien Vasseur est engagé en qualité d'éducateur spécialisé à compter
du 1er septembre 2026, pour une durée indéterminée, à temps plein.

Article 2 — Rémunération
Le salaire mensuel brut est fixé à 2 450 euros, versé le dernier jour
ouvré de chaque mois sur le compte suivant : FR40 3000 3015 7000 0370 8452 432.

Article 3 — Contact
Pour toute question relative au présent contrat, M. Julien Vasseur peut
être joint au 02 40 12 34 56 ou à l'adresse julien.vasseur@example.fr.

Article 4 — Obligations de l'employeur
Le Foyer Les Tilleuls s'engage à fournir les équipements de protection
nécessaires et à assurer la formation continue du salarié conformément à
la convention collective applicable.

Article 5 — Obligations du salarié
M. Julien Vasseur s'engage à respecter le règlement intérieur de
l'établissement et le secret professionnel attaché à ses fonctions
auprès des résidents.

Fait à Nantes, le 15 août 2026, en deux exemplaires.

Pour le Foyer Les Tilleuls,
Mme Claire Bonnard, Directrice
''',
);

/// Compte rendu de conseil d'administration fictif — plusieurs
/// participants nommés avec leur fonction, un établissement nommé,
/// une mention d'un prénom seul (cas d'usage réel : une fois la personne
/// présentée, on ne la re-mentionne plus que par son prénom).
const compteRenduSample = DemoSample(
  title: 'Compte rendu de conseil d\'administration',
  instruction: 'Fais une synthèse et liste les décisions prises.',
  text: '''
COMPTE RENDU DE CONSEIL D'ADMINISTRATION

Établissement : IME Beauséjour
Date : 3 juillet 2026

Présents :
- Mme Sophie Lambert, directrice
- M. Marc Herbin, trésorier
- Dr Nadia Ferrand, médecin coordonnateur
- Mme Claire Bonnard, administratrice, représentant le Foyer Les Tilleuls

1. Ouverture de séance
Mme Sophie Lambert ouvre la séance à 14h30 et rappelle l'ordre du jour.

2. Point budgétaire
M. Marc Herbin présente le budget prévisionnel 2027. Le conseil valide
une augmentation de 3 % de la dotation dédiée à la formation du
personnel éducatif.

3. Point médical
Dr Nadia Ferrand fait un point sur l'organisation des soins et signale
une tension sur le recrutement d'infirmiers de nuit. Sophie rappelle que
le recrutement est déjà lancé depuis le mois de mai.

4. Décisions prises
- Le conseil approuve le budget prévisionnel 2027 à l'unanimité.
- Le conseil autorise le recrutement de deux infirmiers supplémentaires.
- Le conseil mandate Mme Sophie Lambert pour signer la convention de
  partenariat avec le Foyer Les Tilleuls.

Pour toute question, contacter le secrétariat à
contact@ime-beausejour.example.fr.

La séance est levée à 16h00.
''',
);

/// Les deux documents d'exemple, dans l'ordre d'affichage de la démo.
const demoSamples = [contratTravailSample, compteRenduSample];
