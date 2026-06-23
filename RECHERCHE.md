# Fondations scientifiques — score de ré-identification

Notes de recherche pour la fonctionnalité phare d'Écluse : mesurer et
réduire le pouvoir d'identification d'un texte, pas seulement masquer des
entités. Ce document pose les concepts, les sources et la chaîne de
traitement visée. À implémenter en phase 2, après le NER local.

---

## L'idée centrale : le risque se mesure

« Cette personne est-elle ré-identifiable ? » a une réponse chiffrée.
On regroupe les individus partageant les mêmes quasi-identifiants
(tranche d'âge, zone, fonction, pathologie) en **classes d'équivalence**.

> Risque de ré-identification d'un enregistrement = 1 / F
> où F = taille de la classe d'équivalence à laquelle il appartient.

- Classe de taille 1 (personne unique) → risque = 1 (certitude).
- Classe de taille 100 → risque = 0,01 (1 %).

C'est le moteur du « score de ré-identification » d'Écluse. Théorie déjà
faite, validée, publiée — à ne pas réinventer, à adapter au texte.

## Vocabulaire à adopter (langage reconnu des DPO et de la CNIL)

Trois modèles de menace, à reprendre dans la doc et l'export AIPD :

- **Risque procureur** : l'attaquant sait déjà que la personne figure
  dans les données ; probabilité qu'elle y soit unique. → Le scénario
  le plus pertinent pour Écluse (quelqu'un lit un compte-rendu et sait
  qu'il parle d'un patient/soignant précis de l'établissement).
- **Risque journaliste** : l'attaquant ne sait pas si la cible est dans
  les données ; probabilité d'unicité dans la population d'origine.
- **Risque marketeur** : adversaire cherchant à ré-identifier le plus de
  personnes possible. Toujours ≤ risque procureur/journaliste.

## Quasi-identifiants (QI)

Ni identifiants directs (nom, NIR → supprimés/pseudonymisés), ni données
neutres. Ce sont les attributs qui, **combinés**, désignent une personne :
âge, sexe, zone géographique, fonction/métier, pathologie, dates clés,
employeur. C'est sur eux que porte la généralisation.

## Techniques de réduction du risque

- **Généralisation** : réduire la précision (ville → région → grande zone ;
  âge exact → tranche ; pathologie rare → catégorie).
- **Suppression** : retirer le QI quand la généralisation ne suffit pas.
- **Boucle** : évaluer le risque → si seuil dépassé, généraliser/supprimer
  davantage → ré-évaluer → jusqu'à passer sous le seuil.

## Outil de référence : ARX (à étudier, pas à embarquer)

ARX — https://arx.deidentifier.org — github.com/arx-deidentifier/arx

- Open source, **licence Apache 2.0** (compatible Écluse), usage
  commercial autorisé.
- Implémente k-anonymity, l-diversity, t-closeness, differential privacy,
  calcul de risque de ré-identification, hiérarchies de généralisation.
- API Java propre ; hiérarchies définies par fichiers (ex. age.csv).

**Limite clé pour nous** : ARX transforme des données **tabulaires (CSV)**.
Il ne lit pas le texte libre. C'est l'outil du monde « base de données ».
→ Réutiliser sa *logique* (hiérarchies, calcul de risque) en la portant
en Dart pour notre usage texte/mobile. Ne pas l'embarquer tel quel.

## Le verrou technique propre à Écluse

ARX et El Emam calculent le risque sur une **population connue** (un jeu de
données entier). Écluse traite **un texte isolé**, sans population de
référence. Il faut donc estimer la rareté autrement :

→ via des **données publiques françaises** (INSEE, annuaires
professionnels : combien de pneumologues à Thionville ? combien de
personnes de cet âge dans ce département ?).

C'est là qu'est notre recherche propre — et là que la connaissance du
terrain français devient un actif que ni ARX ni El Emam n'ont.

## Posture d'humilité (assumée, protectrice)

Même le k-anonymat a des failles connues (ex. « Combinatorial Refinement
Attacks », 2017, contre le recodage local d'ARX). Écluse ne promet pas
l'impossibilité de ré-identifier : il rend la ré-identification
difficile, coûteuse et **mesurable**. Citer ces limites nous crédibilise
face aux experts plutôt que de nous fragiliser.

## Chaîne de traitement visée

1. NER local repère les quasi-identifiants dans le texte.
2. Catégorisation des QI (lieu, âge, fonction, pathologie, dates…).
3. Estimation de rareté via données publiques FR → taille de classe.
4. Calcul du risque procureur (1/F).
5. Si risque > seuil : généraliser (hiérarchies géo/âge/…) puis revenir
   à l'étape 3. Sinon : sortir le texte + le score + le journal AIPD.

## Bibliographie

- Samarati & Sweeney (1998) — introduction du k-anonymity.
- K. El Emam, *Guide to the De-Identification of Personal Health
  Information* (CRC Press) — méthodologie de mesure du risque (procureur/
  journaliste/marketeur, mesures d'unicité, seuils).
- Dankar & El Emam (2010) — scénario marketeur.
- *Practical and ready-to-use methodology to assess the re-identification
  risk in anonymized datasets*, Scientific Reports / arXiv 2501.10841 (2025).
- ARX — Prasser et al., *Flexible Data Anonymization Using ARX* (2020).
- Modèles complémentaires : l-diversity, t-closeness (raffinements du
  k-anonymity contre l'homogénéité des valeurs sensibles).
