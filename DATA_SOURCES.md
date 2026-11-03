# Sources des données embarquées

**État : toutes les sources identifiées, licence et dates lues sur les pages.**
Ce fichier recense les jeux de données publics dont des extraits sont versionnés
dans `packages/ecluse_reference/assets/`.

## Comment la vérification a été faite

- **DREES** : la page du jeu a été lue par le mainteneur, qui en a collé le
  contenu le 25 octobre 2026.
- **INSEE** : les pages ont été ouvertes par l'agent le 25 octobre 2026
  (`www.insee.fr`, joignable ; aucun contournement du proxy). Les dates ci-dessous
  sont celles **écrites sur chaque page**. Les fichiers cités ont ensuite été
  retéléchargés depuis ces pages et comparés aux assets versionnés (voir
  « Identification par le contenu »).
- Ce n'est **pas** la date de téléchargement d'origine des assets : celle-ci
  n'a jamais été enregistrée et reste irrécupérable. La seule date certaine
  est celle du commit qui ajoute les fichiers (28 juillet 2026, `248123a`).
  À noter désormais à chaque mise à jour des assets.

## Licence : ce qui est écrit, et où

Les quatre pages de jeu de l'INSEE **ne portent pas de mention de licence**
propre (relevé : aucune occurrence de « licence » dans leur contenu). La licence
vient de la page de l'INSEE « Mentions légales et crédits »
(`https://www.insee.fr/fr/information/2008466`, dernière mise à jour affichée :
13/04/2026), section « Propriété intellectuelle et liens » :

> Sauf mention contraire, les informations publiques diffusées sur ce site
> (données, bases de données, publications, fichiers téléchargeables) sont mises
> à disposition sous la Licence Ouverte / Open Licence version 2.0 (Etalab).
> Cette licence autorise la réutilisation libre, y compris à des fins
> commerciales, sous réserve de mentionner la source sous la forme « Source :
> Insee », de mentionner la date de dernière mise à jour des données lorsque
> celle-ci est connue et de ne pas altérer le sens des informations ou induire
> en erreur quant à leur interprétation.

Deux points à connaître :

1. C'est une déclaration **pour l'ensemble du site**, avec la réserve « Sauf
   mention contraire ». Aucune mention contraire n'a été vue sur les quatre
   pages de jeu, mais la licence n'y est pas répétée.
2. La page « Conditions générales de mise à disposition du public des produits
   d'information statistique » (`https://www.insee.fr/fr/information/2381855`,
   mise à jour affichée : 27/05/2019) dit, art. 2.1, que le droit de
   réutilisation est « concédé sans licence et sans paiement de redevances », sous
   la condition (art. 2.2) que les données « ne soient pas altérées » et que
   « leurs sources et la date de leur dernière mise à jour soient mentionnées ».
   Elle vise « l'acquéreur d'un produit de diffusion ». Elle est plus ancienne
   et sa caducité n'a pas pu être vérifiée ; les deux textes convergent
   sur les obligations (source, date, non-altération).

Corroboration secondaire, non décisive : l'API de data.gouv.fr donne pour la
fiche « Code officiel géographique »
(`https://www.data.gouv.fr/datasets/code-officiel-geographique-1`) l'identifiant
de licence `fr-lo` (Licence Ouverte), fiche modifiée le 9 septembre 2026.

Licence DREES : voir plus bas (lue sur la page du jeu).

## Table de provenance

| Fichier embarqué | Fichier brut (script) | Producteur | Page du jeu (URL exacte) | Fichier téléchargeable nommé sur la page | Date écrite sur la page | Licence |
|---|---|---|---|---|---|---|
| `geo_communes.csv.gz` (`COM;DEP;REG`, libellé) | `v_commune_2026__1_.csv` (le suffixe `__1_` vient du navigateur) | INSEE, Code officiel géographique au 1er janvier 2026, liste des communes | `https://www.insee.fr/fr/information/8740222` | `v_commune_2026.csv` (`/fr/statistiques/fichier/8740222/v_commune_2026.csv`) | « Dernière mise à jour le : 24/02/2026 » | Licence Ouverte v2.0 (Etalab), d'après les mentions légales du site (voir plus haut) |
| `geo_communes.csv.gz` (colonne `PMUN`) | `ensemble__1_.zip` → `donnees_communes.csv` | INSEE, populations légales 2023 (fichier d'ensemble) | `https://www.insee.fr/fr/statistiques/8680726` | `ensemble.zip` (`/fr/statistiques/fichier/8680726/ensemble.zip`) | « Paru le 18/12/2025 » (« Décembre 2025 ») | idem |
| `geo_hierarchie.json` | dérivé du COG ci-dessus et de la colonne `Région` de `donnees_communes.csv` | INSEE | les deux pages ci-dessus | idem | idem | idem |
| `age_pyramide.json` | `Population-2025.zip` → `3_Pop1janv_age.xlsx`, feuille `2026` | INSEE, « Données nationales - Population », tableau POP3 (population au 1er janvier par sexe et âge détaillé, France) | `https://www.insee.fr/fr/statistiques/8999013` | `3_Pop1janv_age.xlsx` (`/fr/statistiques/fichier/8999013/3_Pop1janv_age.xlsx`), aussi dans l'archive `irsocsd2025_pop.zip` | « Paru le 15/06/2026 » (« Juin 2026 ») | idem |
| `first_names.txt.gz` | `prenoms-2025-liste_csv.zip` → `prenoms-2025-liste.csv` | INSEE, fichier des prénoms, édition de juillet 2026 (naissances 1900-2025) | `https://www.insee.fr/fr/statistiques/8595130` | `prenoms-2025-liste_csv.zip` (`/fr/statistiques/fichier/8595130/prenoms-2025-liste_csv.zip`) | « Paru le 16/07/2026 » (« Juillet 2026 ») | idem |
| `rarity_medecins.json` | `Médecins_RPPS_2012-2026.xlsx` (feuille `Effectifs`) | DREES/OSAM, « La démographie des professionnels de santé depuis 2012 » (identifiant `la-demographie-des-professionnels-de-sante-depuis-2012`) ; pièce jointe `Médecins RPPS 2012-2026.xlsx` | `https://data.drees.solidarites-sante.gouv.fr/explore/dataset/la-demographie-des-professionnels-de-sante-depuis-2012/information/` | pièce jointe `Médecins RPPS 2012-2026.xlsx` | jeu modifié le 2 juillet 2026 à 11:38 | **Licence Ouverte v2.0 (Etalab)**, lue sur la page du jeu par le mainteneur (25 octobre 2026) ; lien : `https://www.etalab.gouv.fr/wp-content/uploads/2017/04/ETALAB-Licence-Ouverte-v2.0.pdf` |
| `rarity_professions.json` | `Pharmaciens_RPPS_2012-2026.xlsx`, `Chirurgiens-dentistes_RPPS_2012-2026.xlsx`, `Sages-femmes_RPPS_2012-2026.xlsx`, `Pédicures-podologues_RPPS_2018-2026.xlsx` | même jeu DREES/OSAM ; pièces jointes de mêmes noms (`Pharmaciens RPPS 2012-2026.xlsx`, `Chirurgiens-dentistes RPPS 2012-2026.xlsx`, `Sages-femmes RPPS 2012-2026.xlsx`, `Pédicures-podologues RPPS 2018-2026.xlsx`) : présentes dans la liste de la page | idem | idem | idem | idem |
| `reference_meta.json` | produit par le script | Écluse | sans objet | sans objet | sans objet | sans objet |

## Identification par le contenu (trois cas qui étaient incertains)

Les fichiers ont été retéléchargés le 25 octobre 2026 depuis les pages ci-dessus
et passés dans la même logique que `tools/build_reference_assets.py` (script de
comparaison jetable, hors dépôt). Résultats :

- **Populations communales** : `ensemble.zip` de la page 8680726 contient
  `donnees_communes.csv`. Avec le COG `v_commune_2026.csv` : 34 875 communes
  (`TYPECOM=COM`), même ensemble de codes que `geo_communes.csv.gz`, **0 population
  `PMUN` différente, 0 libellé différent**. Identification confirmée.
- **Pyramide des âges** : la page 8331297 (candidate d'origine) est l'édition
  « au 1er janvier 2025 » (fichiers `estim-pop-*-1975-2025.xlsx`, par région et
  département, publiée le 14/01/2025) : **écartée**, elle ne contient pas de
  feuille 2026 ni de série nationale par âge. La bonne page est la 8999013
  (`3_Pop1janv_age.xlsx`, feuille `2026`, présente aussi dans
  `irsocsd2025_pop.zip`) : total 69 079 962, **identique année par année** à
  `age_pyramide.json`. Réserve : le nom `Population-2025.zip` utilisé par le script
  **n'apparaît pas** sur la page (qui propose `irsocsd2025_pop.zip`) ; l'identification
  repose sur le contenu, pas sur le nom. On ne peut pas dire si le fichier
  d'origine datait d'une édition antérieure à celle du 15/06/2026 ; la feuille 2026
  est la même.
- **Prénoms** : la page 8894961 (édition juillet 2025, naissances 1900-2024)
  propose `prenoms-2024-liste_csv.zip` : **écartée**, le script lit `prenoms-2025-…`.
  La page 8595130 (édition juillet 2026, naissances 1900-2025) propose
  `prenoms-2025-liste_csv.zip` : 154 977 prénoms normalisés, **identiques** à
  `first_names.txt.gz`. L'« 2025 » du script est l'année de naissance la plus
  récente, pas l'année d'édition.
- **COG** : 8740222, fichier `v_commune_2026.csv`, confirmé par le contrôle ci-dessus.

Ce contrôle prouve que les assets se **régénèrent à l'identique** depuis ces
fichiers ; il ne prouve pas que ce sont les fichiers téléchargés à l'origine.

## Page DREES : ce qui est établi

Lu par le mainteneur sur la page du jeu : producteur **DREES/OSAM**, licence
**Licence Ouverte v2.0 (Etalab)**, modifié le **2 juillet 2026 à 11:38**, thèmes
« Santé et Système de soins » ; les cinq fichiers que notre script lit figurent
parmi les pièces jointes de la page (les professions du jeu vont bien au-delà :
infirmières, kinésithérapeutes, professions ADELI…, dont nous n'utilisons
aucune). Le jeu est constitué de **tableaux agrégés** (effectifs au 1er janvier
par département et profession), produits par la DREES à partir d'une extraction
du RPPS ; aucune donnée individuelle n'est redistribuée.

## Mentions de source (appliquées)

Les licences exigent de citer la source et la date de mise à jour, sans suggérer
que le producteur cautionne la réutilisation. Les mentions sont dans `NOTICE`
(racine du dépôt) : « Source : Insee » avec les dates des quatre jeux,
« Source : DREES » avec la date de modification, et l'indication que les fichiers
sont des **extraits transformés** (`tools/build_reference_assets.py` filtre,
normalise et agrège), d'autant que les deux textes INSEE posent la condition de
ne pas altérer le sens des données.

## Décision du mainteneur (25 octobre 2026)

Le mainteneur décide de **redistribuer ces extraits transformés dans le dépôt**.
Portée exacte de cette décision :

- le **code** reste sous Apache 2.0 (`LICENSE`) ; les **données** embarquées ne
  sont **pas relicenciées** : elles restent sous la Licence Ouverte v2.0 de leurs
  producteurs, ce que dit `NOTICE` ;
- les obligations de la Licence Ouverte sont tenues par `NOTICE` (source, date de
  mise à jour, extraits transformés) ; le texte intégral de la Licence Ouverte n'a
  pas été relu pour cette PR, seules les formulations citées plus haut l'ont été ;
- l'analyse de la condition de non-altération du sens des données est celle du
  mainteneur ; aucun avis juridique extérieur n'est joint ;
- la page INSEE de 2019 (conditions générales des produits de diffusion) est
  considérée comme ne s'appliquant pas à ces fichiers en libre téléchargement ;
  cette lecture n'a pas pu être vérifiée auprès de l'INSEE.

Reste ouvert : la date de téléchargement d'origine des assets, irrécupérable, à
enregistrer à la prochaine régénération.

`LIMITES.md` § 7 renvoie à ce fichier.
