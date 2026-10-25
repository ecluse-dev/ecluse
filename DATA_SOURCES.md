# Sources des données embarquées

**État : INCOMPLET, volontairement.** Ce fichier recense les jeux de données
publics dont des extraits sont versionnés dans
`packages/ecluse_reference/assets/`. Pour aucun d'eux la **licence n'a été lue
sur la page du jeu de données** : lors de la rédaction (25 octobre 2026), les
hôtes `insee.fr`, `data.gouv.fr` et `drees.solidarites-sante.gouv.fr` n'étaient
pas joignables depuis l'environnement de l'agent (erreur de résolution et refus
du proxy, HTTP 403). Rien n'est donc affirmé ci-dessous comme *lu sur la page* ; les
cases « à compléter » sont à remplir par une personne qui ouvre les pages.

**Indication reçue du mainteneur (25 octobre 2026), non vérifiée.** Le
mainteneur a transmis la réponse d'un assistant IA (captures d'écran) : l'INSEE
et la DREES publieraient leurs données sous **Licence Ouverte / Open Licence
v2.0** (Etalab), réutilisation libre y compris commerciale, sous réserve de
mentionner la source (`Source : Insee`, `Source : DREES`, ou nom du jeu et
millésime). C'est une **source secondaire** : elle n'est pas la lecture de la
page du jeu, que la fiche P1-33 exige. Elle sert d'hypothèse de travail et
d'attribution minimale (voir plus bas) ; elle ne remplace pas la vérification.
Dans cette réponse, le domaine cité pour la DREES (`data.drees.sante.gouv.fr`)
n'est pas celui de la page trouvée par recherche
(`drees.solidarites-sante.gouv.fr`) : à contrôler. De plus, la Licence Ouverte
s'applique **par jeu de données** : un portail ne suffit pas à l'établir pour
chaque fichier.

Règle appliquée : une URL n'est citée que si elle est le nom d'une page
trouvée par une recherche web, et elle est alors marquée « page candidate,
non lue ». Les dates de téléchargement n'ont pas été enregistrées à
l'époque ; la seule date certaine est celle du commit qui ajoute les fichiers
(28 juillet 2026, `248123a`).

## Provenance connue (trace dans le dépôt)

Les fichiers sont produits par `tools/build_reference_assets.py` à partir de
fichiers bruts que le script attend dans un répertoire local
(`/mnt/user-data/uploads`). Le script nomme ces fichiers mais **n'enregistre ni
URL, ni date, ni licence**. Les millésimes déclarés sont dans
`packages/ecluse_reference/assets/reference_meta.json`.

## Table de provenance

| Fichier embarqué | Fichier brut nommé dans le script | Producteur (d'après le nom et le contenu) | Page candidate (non lue) | Date de téléchargement | Licence lue sur la page |
|---|---|---|---|---|---|
| `geo_communes.csv.gz` (colonnes `COM;DEP;REG` et libellé) | `v_commune_2026__1_.csv` | INSEE, Code officiel géographique (COG) 2026, communes | `https://www.insee.fr/fr/information/8740222` ; fiche `https://www.data.gouv.fr/datasets/58c984b088ee386cdb1261f3` | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `geo_communes.csv.gz` (colonne `PMUN`) | `ensemble__1_.zip` → `donnees_communes.csv` | INSEE, populations légales des communes (millésime déclaré « ref2023→2026 ») | aucune page identifiée (la recherche n'a renvoyé que des PDF de la publication « populations légales 2023 ») | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `geo_hierarchie.json` | dérivé du COG ci-dessus et de la colonne `Région` de `donnees_communes.csv` | INSEE | idem | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `age_pyramide.json` | `Population-2025.zip` → `3_Pop1janv_age.xlsx`, feuille `2026` | INSEE, estimations de population par âge (« France entière ») | `https://www.insee.fr/fr/statistiques/8331297` (série jusqu'à 2025 : **ne correspond pas à une feuille « 2026 »**, identification incertaine) | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `rarity_medecins.json` | `Médecins_RPPS_2012-2026.xlsx` (feuille `Effectifs`) | DREES, démographie des professionnels de santé (RPPS) | `https://drees.solidarites-sante.gouv.fr/communique-de-presse-jeux-de-donnees/250513_DATA_professionnels-de-sante-1er-janvier-2024` (édition 2024 : **millésime différent** du fichier 2012-2026) | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `rarity_professions.json` | `Pharmaciens_RPPS_2012-2026.xlsx`, `Chirurgiens-dentistes_RPPS_2012-2026.xlsx`, `Sages-femmes_RPPS_2012-2026.xlsx`, `Pédicures-podologues_RPPS_2018-2026.xlsx` | DREES, idem | idem | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `first_names.txt.gz` | `prenoms-2025-liste_csv.zip` → `prenoms-2025-liste.csv` | INSEE, fichier des prénoms (liste) | `https://www.insee.fr/fr/statistiques/8894961` (édition de juillet 2025, naissances 1900-2024) ou `https://www.insee.fr/fr/statistiques/8595130` (édition 2026) : **édition non déterminée** | non enregistrée | **indiquée « Licence Ouverte v2.0 » (secondaire, non lue sur la page)** |
| `reference_meta.json` | produit par le script | Écluse | sans objet | sans objet | sans objet |

## Mentions de source (si la Licence Ouverte est confirmée)

La licence exige de citer la source et la date de mise à jour, sans suggérer
que le producteur cautionne la réutilisation. Mentions minimales proposées,
à placer dans `NOTICE` ou le README du paquet **après vérification** (je ne
les ai pas ajoutées à des fichiers distribués) :

- `Source : Insee` — Code officiel géographique (millésime 2026), populations
  légales, estimations de population, fichier des prénoms ;
- `Source : DREES` — démographie des professionnels de santé (RPPS).

Ces fichiers sont des **extraits transformés** (`tools/build_reference_assets.py`
filtre, normalise et agrège) : la mention doit le dire.

## Ce qui reste à faire (hors de portée de l'agent)

1. Ouvrir chaque page, noter l'URL exacte, la date de mise en ligne du fichier
   et la **licence telle qu'elle est écrite sur la page** (ne pas la déduire).
2. Confirmer que le fichier brut correspond bien au jeu (nom d'archive, feuille,
   millésime). Trois identifications sont **incertaines** : la population
   communale, la pyramide des âges (feuille `2026`) et l'édition des prénoms.
3. Vérifier que la licence autorise la redistribution d'extraits dans un dépôt
   Apache 2.0, et ajouter la mention de source qu'elle exige, le cas échéant
   (`NOTICE`, README du paquet).
4. Si un fichier brut ne peut pas être retrouvé, le régénérer depuis une
   source identifiée, ou le retirer.

`LIMITES.md` § 7 signale déjà que la provenance et la licence de ces jeux ne
sont pas déclarées ; ce fichier ne lève pas cette réserve.
