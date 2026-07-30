/// Documents de démonstration — **entièrement fictifs**.
///
/// Toute ressemblance avec des personnes ou établissements réels serait
/// une coïncidence. Les identifiants (NIR, IBAN, RPPS) sont structurellement
/// valides (clé de contrôle correcte — mod 97 pour le NIR, ISO 7064 pour
/// l'IBAN, Luhn pour le RPPS) afin que les détecteurs d'`ecluse_core` se
/// déclenchent réellement, mais ne correspondent à aucune personne
/// existante.
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

/// Contrat de travail fictif — infirmière coordinatrice recrutée par un
/// établissement médico-social. Couvre nom/prénom, adresse, date de
/// naissance, NIR, RPPS (numéro professionnel de santé), IBAN de
/// versement du salaire, établissement employeur, téléphone et email —
/// tous les identifiants structurels (NIR, RPPS, IBAN) à clé valide.
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

Mme Inès Chevalier, née le 12 juin 1990, demeurant 3 impasse des Tilleuls, 12000 Rodez,
numéro de sécurité sociale 2 90 06 12 205 078 92, infirmière diplômée
d'État inscrite sous le numéro RPPS 10200876547,

Il a été convenu ce qui suit :

Article 1 — Engagement
Mme Inès Chevalier est engagée en qualité d'infirmière coordinatrice à
compter du 1er mars 2027, pour une durée indéterminée, à temps plein.

Article 2 — Rémunération
Le salaire mensuel brut est fixé à 2 780 euros, versé le dernier jour
ouvré de chaque mois sur le compte suivant :
FR51 1009 6003 0123 4567 8901 234.

Article 3 — Contact
Pour toute question relative au présent contrat, Mme Inès Chevalier peut
être jointe au 05 65 42 18 76 ou à l'adresse ines.chevalier@example.fr.

Article 4 — Obligations de l'employeur
Le Foyer Les Tilleuls s'engage à fournir les équipements de protection
nécessaires et à assurer la formation continue de la salariée conformément à
la convention collective applicable.

Article 5 — Obligations de la salariée
Mme Inès Chevalier s'engage à respecter le règlement intérieur de
l'établissement et le secret professionnel attaché à ses fonctions
auprès des résidents.

Fait à Nantes, le 20 février 2027, en deux exemplaires.

Pour le Foyer Les Tilleuls,
Mme Claire Bonnard, Directrice
''',
);

/// Compte rendu de réunion de coordination fictif (type RCP/HAD) —
/// plusieurs professionnels de santé nommés avec leur fonction (dont un
/// RPPS), un patient suivi à domicile, une posologie de traitement (à ne
/// pas confondre avec une adresse), et des sigles métier du secteur
/// médico-social qui ne doivent jamais être masqués (SSIAD, CARSAT, RCP).
const compteRenduSample = DemoSample(
  title: 'Compte rendu de réunion de coordination (RCP/HAD)',
  instruction: 'Fais une synthèse et liste les décisions prises.',
  text: '''
COMPTE RENDU DE RÉUNION DE COORDINATION HAD

Type de réunion : RCP (réunion de concertation pluridisciplinaire) — suivi HAD
Date : 14 janvier 2027
Lieu : Antenne HAD Nantes Nord

Patient suivi :
M. Karim Belhadj, né le 3 mars 1985, domicilié 9 rue du Moulin, 44300 Nantes,
numéro de sécurité sociale 1 85 03 44 123 045 28.

Professionnels présents :
- Dr Nadia Costa, médecin coordonnateur, RPPS 10100987659
- Mme Elise Rambert, infirmière coordinatrice IDEC
- M. Thomas Grellier, kinésithérapeute libéral

1. Point sur la prise en charge à domicile
Le SSIAD intervient deux fois par jour pour la toilette et les soins
d'hygiène. La CARSAT a validé la prise en charge financière du matériel
médical.

2. Coordination des soins
Dr Costa ajuste le traitement anticoagulant : innohep 10000 UI en
injection sous-cutanée quotidienne. La RCP recommande un contrôle
biologique à J7.

3. Aspects administratifs
Les frais de déplacement des professionnels libéraux sont remboursés sur
le compte FR56 3000 3020 3692 8471 5621 007. Pour toute question,
contacter le secrétariat au 02 40 55 12 34 ou à
secretariat.had-nantes@example.fr.

4. Prochaine réunion
La prochaine RCP est fixée dans trois semaines.

La séance est levée à 16h30.
''',
);

/// Compte rendu de réunion de synthèse ESAT fictif — bénéficiaire suivi en
/// atelier protégé, médecin du travail (RPPS), sigles métier du secteur
/// (ESAT, MDPH, IDE) qui ne doivent jamais être masqués.
const compteRenduEsatSample = DemoSample(
  title: 'Compte rendu de réunion de synthèse (ESAT)',
  instruction: 'Fais une synthèse et liste les décisions prises.',
  text: '''
COMPTE RENDU DE RÉUNION DE SYNTHÈSE — ESAT

Établissement : ESAT Les Ateliers du Sillon
Date : 5 février 2027
Objet : point d'étape du projet personnalisé d'accompagnement

Bénéficiaire suivi :
Mme Nadia Ferreira, née le 9 avril 1987, domiciliée 5 rue des Tilleuls, 44300 Nantes,
numéro de sécurité sociale 1 87 09 44 201 033 26.

Professionnels présents :
- Dr Paul Ricard, médecin du travail, RPPS 10300765418
- Mme Elise Rambert, éducatrice spécialisée
- M. Antoine Roussel, moniteur d'atelier

1. Bilan de la période d'essai
L'ESAT confirme la poursuite de l'accompagnement en atelier
conditionnement. La MDPH a validé le renouvellement de l'orientation.

2. Aspects médicaux
Le Dr Ricard signale une tolérance correcte au poste, sans restriction
particulière. L'IDE assure le suivi hebdomadaire.

3. Aspects administratifs
La rémunération garantie est versée sur le compte
FR98 2004 1010 0558 0001 2345 615. Pour toute question, contacter le
secrétariat au 02 40 33 44 55 ou à secretariat.esat-sillon@example.fr.

4. Prochaine réunion
Prochain point dans six mois.

La séance est levée à 11h00.
''',
);

/// Compte rendu de conseil de la vie sociale (CVS) EHPAD fictif — résident
/// représenté, médecin coordonnateur (RPPS), sigles métier du secteur
/// (CCAS, CPTS, IDEC) qui ne doivent jamais être masqués.
const compteRenduEhpadSample = DemoSample(
  title: 'Compte rendu de conseil de la vie sociale (EHPAD)',
  instruction: 'Fais une synthèse et liste les décisions prises.',
  text: '''
COMPTE RENDU DE CONSEIL DE LA VIE SOCIALE — EHPAD

Établissement : EHPAD Les Jardins de Brède
Date : 18 mars 2027

Résident représenté :
M. Henri Castagne, né le 7 juillet 1933, domicilié 12 avenue de la Libération, 33300 Bordeaux,
numéro de sécurité sociale 2 65 07 33 305 067 08.

Professionnels et représentants présents :
- Dr Camille Vidal, médecin coordonnateur, RPPS 10400654322
- Mme Odile Ferrand, présidente du CVS
- M. Julien Sartre, représentant des familles

1. Vie quotidienne
Le CCAS a été sollicité pour l'organisation de la sortie de printemps. La
CPTS locale participera à une session d'information sur la vaccination.

2. Suivi médical
Le Dr Vidal présente le bilan du dernier trimestre. Aucun événement
indésirable signalé. L'IDEC assure la coordination des soins.

3. Aspects financiers
La participation aux frais de sortie est prélevée sur le compte
FR40 3005 6008 1189 0123 4567 842. Contact : 05 56 44 22 11 ou
cvs.jardins-brede@example.fr.

4. Prochaine réunion
Le prochain CVS se tiendra dans trois mois.

La séance est levée à 15h30.
''',
);

/// Les deux documents d'exemple chargeables depuis la démo (boutons de
/// `ecluse_demo`), dans leur ordre d'affichage.
const demoSamples = [contratTravailSample, compteRenduSample];

/// Corpus de démonstration où NIR, IBAN et RPPS sont **tous** à clé
/// structurellement valide, générés puis revérifiés par les détecteurs
/// d'`ecluse_core` — le seul corpus sur lequel un taux de masquage à 100 %
/// des identifiants structurels a un sens (voir les tests d'invariant dans
/// `ecluse_redact_test.dart`). Au moins trois comptes rendus de réunion
/// distincts, plus le contrat de travail (qui contient lui aussi les trois
/// types à clé valide).
const validKeysDemoCorpus = [
  contratTravailSample,
  compteRenduSample,
  compteRenduEsatSample,
  compteRenduEhpadSample,
];
