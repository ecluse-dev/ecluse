# Sources des données embarquées

**État : DREES vérifiée, INSEE encore incomplet.** Ce fichier recense les
jeux de données publics dont des extraits sont versionnés dans
`packages/ecluse_reference/assets/`.

**Comment la vérification a été faite.** Les hôtes `insee.fr`, `data.gouv.fr` et
`data.drees.solidarites-sante.gouv.fr` ne sont pas joignables depuis
l'environnement de l'agent (erreur de résolution, refus du proxy HTTP 403).
La page du jeu DREES a donc été **lue par le mainteneur**, qui en a collé le
contenu le 25 octobre 2026 ; l'agent n'a pas ouvert la page lui-même. Pour
l'INSEE, seule une indication **secondaire** existe : la réponse d'un assistant
IA (captures d'écran) dit « Licence Ouverte v2.0 (Etalab), citer la source » ;
ce n'est pas la lecture de la page du jeu, que la fiche P1-33 exige. Elle est
conservée comme hypothèse de travail, jamais comme preuve. La Licence Ouverte
s'applique **par jeu de données** : un portail ne suffit pas à l'établir pour
chaque fichier.

Dates de téléchargement : **non enregistrées** à l'époque ; la seule date
certaine est celle du commit qui ajoute les fichiers (28 juillet 2026,
`248123a`). Pour la DREES, le jeu a été modifié le 2 juillet 2026 : les
fichiers ont donc été téléchargés après cette date si leur millésime est bien
celui de la page (inférence, pas une trace).

## Provenance connue (trace dans le dépôt)

Les fichiers sont produits par `tools/build_reference_assets.py` à partir de
fichiers bruts que le script attend dans un répertoire local
(`/mnt/user-data/uploads`). Le script nomme ces fichiers mais **n'enregistre ni
URL, ni date, ni licence**. Les millésimes déclarés sont dans
`packages/ecluse_reference/assets/reference_meta.json`.

## Table de provenance

| Fichier embarqué | Fichier brut nommé dans le script | Producteur (d'après le nom et le contenu) | Page du jeu | Date de téléchargement | Licence |
|---|---|---|---|---|---|
| `geo_communes.csv.gz` (colonnes `COM;DEP;REG` et libellé) | `v_commune_2026__1_.csv` | INSEE, Code officiel géographique (COG) 2026, communes | `https://www.insee.fr/fr/information/8740222` ; fiche `https://www.data.gouv.fr/datasets/58c984b088ee386cdb1261f3` | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `geo_communes.csv.gz` (colonne `PMUN`) | `ensemble__1_.zip` → `donnees_communes.csv` | INSEE, populations légales des communes (millésime déclaré « ref2023→2026 ») | aucune page identifiée (la recherche n'a renvoyé que des PDF de la publication « populations légales 2023 ») | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `geo_hierarchie.json` | dérivé du COG ci-dessus et de la colonne `Région` de `donnees_communes.csv` | INSEE | idem | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `age_pyramide.json` | `Population-2025.zip` → `3_Pop1janv_age.xlsx`, feuille `2026` | INSEE, estimations de population par âge (« France entière ») | `https://www.insee.fr/fr/statistiques/8331297` (série jusqu'à 2025 : **ne correspond pas à une feuille « 2026 »**, identification incertaine) | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `rarity_medecins.json` | `Médecins_RPPS_2012-2026.xlsx` (feuille `Effectifs`) | DREES/OSAM, « La démographie des professionnels de santé depuis 2012 » (identifiant `la-demographie-des-professionnels-de-sante-depuis-2012`) ; pièce jointe `Médecins RPPS 2012-2026.xlsx` | `https://data.drees.solidarites-sante.gouv.fr/explore/dataset/la-demographie-des-professionnels-de-sante-depuis-2012/information/` ; jeu modifié le 2 juillet 2026 à 11:38 | non enregistrée | **Licence Ouverte v2.0 (Etalab)**, lue sur la page du jeu par le mainteneur (25 octobre 2026) ; lien : `https://www.etalab.gouv.fr/wp-content/uploads/2017/04/ETALAB-Licence-Ouverte-v2.0.pdf` |
| `rarity_professions.json` | `Pharmaciens_RPPS_2012-2026.xlsx`, `Chirurgiens-dentistes_RPPS_2012-2026.xlsx`, `Sages-femmes_RPPS_2012-2026.xlsx`, `Pédicures-podologues_RPPS_2018-2026.xlsx` | même jeu DREES/OSAM ; pièces jointes de mêmes noms (`Pharmaciens RPPS 2012-2026.xlsx`, `Chirurgiens-dentistes RPPS 2012-2026.xlsx`, `Sages-femmes RPPS 2012-2026.xlsx`, `Pédicures-podologues RPPS 2018-2026.xlsx`) : **présentes dans la liste de la page** | idem | non enregistrée | **Licence Ouverte v2.0 (Etalab)**, lue sur la page du jeu par le mainteneur (25 octobre 2026) ; lien : `https://www.etalab.gouv.fr/wp-content/uploads/2017/04/ETALAB-Licence-Ouverte-v2.0.pdf` |
| `first_names.txt.gz` | `prenoms-2025-liste_csv.zip` → `prenoms-2025-liste.csv` | INSEE, fichier des prénoms (liste) | `https://www.insee.fr/fr/statistiques/8894961` (édition de juillet 2025, naissances 1900-2024) ou `https://www.insee.fr/fr/statistiques/8595130` (édition 2026) : **édition non déterminée** | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `reference_meta.json` | produit par le script | Écluse | sans objet | sans objet | sans objet |

## Page DREES : ce qui est établi

Lu par le mainteneur sur la page du jeu : producteur **DREES/OSAM**, licence
**Licence Ouverte v2.0 (Etalab)**, modifié le **2 juillet 2026 à 11:38**, thèmes
« Santé et Système de soins » ; les cinq fichiers que notre script lit figurent
parmi les pièces jointes de la page (les professions du jeu vont bien au-delà :
infirmières, kinésithérapeutes, professions ADELI…, dont nous n'utilisons
aucune). Le jeu est constitué de **tableaux agrégés** (effectifs au 1er janvier
par département et profession), produits par la DREES à partir d'une extraction
du RPPS ; aucune donnée individuelle n'est redistribuée.

## Mentions de source

La licence exige de citer la source et la date de mise à jour, sans suggérer
que le producteur cautionne la réutilisation. Mentions minimales proposées,
à placer dans `NOTICE` ou le README du paquet (je ne les ai pas ajoutées à des
fichiers distribués : décision du mainteneur). La DREES est confirmée ; l'INSEE
reste conditionnel à la lecture de ses pages :

- `Source : Insee` — Code officiel géographique (millésime 2026), populations
  légales, estimations de population, fichier des prénoms ;
- `Source : DREES` — démographie des professionnels de santé (RPPS), jeu modifié le 2 juillet 2026 (confirmé).

Ces fichiers sont des **extraits transformés** (`tools/build_reference_assets.py`
filtre, normalise et agrège) : la mention doit le dire.

## Ce qui reste à faire

**DREES : fait** pour la source, la licence et la date de modification du jeu.
Reste la date de téléchargement des fichiers, non enregistrée (irrécupérable ;
à noter désormais à chaque mise à jour des assets).

**INSEE : à faire par quelqu'un qui peut ouvrir les pages** (quatre jeux : COG
2026, populations légales des communes, estimations de population par âge,
fichier des prénoms). Pour chacun : URL exacte, date de mise en ligne et
**licence telle qu'écrite sur la page** (ne pas la déduire de l'indication
secondaire). Trois identifications restent **incertaines** : la population
communale (`ensemble.zip`, aucune page trouvée), la pyramide des âges
(feuille `2026`, alors que la page trouvée porte sur la série jusqu'en 2025)
et l'édition du fichier des prénoms (2025 ou 2026).

**Ensuite** : confirmer que la licence autorise la redistribution d'extraits
transformés dans un dépôt Apache 2.0 (la Licence Ouverte v2.0 l'autorise, avec
citation de la source : à valider par le mainteneur) et ajouter les mentions de
source dans `NOTICE` ou le README du paquet. Si un fichier brut ne peut pas
être retrouvé, le régénérer depuis une source identifiée, ou le retirer.

`LIMITES.md` § 7 signale que la provenance et la licence des jeux embarqués
ne sont pas déclarées ; ce fichier lève cette réserve pour la DREES seulement.
