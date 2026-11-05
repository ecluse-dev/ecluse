# P2-94 — Table maison des pathologies fréquentes (proposition à valider)

Suite de la décision P2-94 du 5 novembre 2026 (`DECISIONS.md`) : Orphadata
pour les maladies rares, **table écrite par le projet** pour les
pathologies fréquentes. Ce document est la **proposition de table**, à
valider cliniquement par le mainteneur (cadre de santé) avant d'en faire
une donnée de `ecluse_reference`. Aucun code.

## 1. Source des catégories

Les catégories reprennent les **intitulés de la liste des affections de
longue durée** tels que publiés par le portail public sante.fr (29
intitulés ; la page cite le décret n° 2011-77 du 19 janvier 2011, qui a
actualisé la liste). Les intitulés d'un texte réglementaire ne sont pas,
en principe, protégés par le droit d'auteur ; **ce point n'a pas reçu
d'avis juridique**.

Les **systèmes** et les **mentions** (mots du texte libre) sont écrits par
le projet.

## 2. Échelle (rappel de P2-07 § 2.3)

mention précise (« maladie de Parkinson ») → **catégorie** (intitulé ALD) →
**système** → « une maladie chronique » → retrait.

## 3. Table proposée

| Système | Catégorie (intitulé ALD, abrégé) | Mentions à reconnaître (exemples) |
|---|---|---|
| Neurologique | Accident vasculaire cérébral invalidant | AVC, accident vasculaire cérébral, hémiplégie séquellaire |
| Neurologique | Maladie d'Alzheimer et autres démences | maladie d'Alzheimer, démence, démence à corps de Lewy |
| Neurologique | Maladie de Parkinson | maladie de Parkinson, Parkinson |
| Neurologique | Sclérose en plaques | sclérose en plaques, SEP |
| Neurologique | Formes graves des affections neurologiques et musculaires, épilepsie grave | épilepsie, myopathie |
| Neurologique | Paraplégie | paraplégie, tétraplégie |
| Psychiatrique | Affections psychiatriques de longue durée | schizophrénie, trouble bipolaire, dépression récurrente |
| Cardio-vasculaire | Insuffisance cardiaque grave, troubles du rythme, cardiopathies valvulaires ou congénitales graves | insuffisance cardiaque, fibrillation auriculaire, valvulopathie |
| Cardio-vasculaire | Maladie coronaire | infarctus du myocarde, maladie coronaire, angor |
| Cardio-vasculaire | Artériopathies chroniques avec manifestations ischémiques | artériopathie des membres inférieurs, AOMI |
| Respiratoire | Insuffisance respiratoire chronique grave | BPCO, asthme grave, insuffisance respiratoire chronique |
| Digestif et hépatique | Rectocolite hémorragique et maladie de Crohn évolutives | maladie de Crohn, rectocolite hémorragique |
| Digestif et hépatique | Maladies chroniques actives du foie et cirrhoses | cirrhose, hépatite B, hépatite C |
| Métabolique | Diabète de type 1 et de type 2 | diabète, diabète de type 1, diabète de type 2 |
| Métabolique | Maladies métaboliques héréditaires | phénylcétonurie, maladie de Gaucher |
| Rénal | Néphropathie chronique grave et syndrome néphrotique primitif | insuffisance rénale chronique, dialyse, syndrome néphrotique |
| Hématologique | Hémoglobinopathies, hémolyses chroniques sévères | drépanocytose, thalassémie |
| Hématologique | Hémophilies et affections graves de l'hémostase | hémophilie, maladie de Willebrand |
| Hématologique | Insuffisances médullaires et autres cytopénies chroniques | aplasie médullaire |
| Immunitaire et infectieux | Déficit immunitaire primitif grave, infection par le VIH | VIH, séropositivité, déficit immunitaire |
| Immunitaire et infectieux | Tuberculose active, lèpre | tuberculose |
| Immunitaire et infectieux | Bilharziose compliquée | bilharziose |
| Rhumatologique | Polyarthrite rhumatoïde évolutive | polyarthrite rhumatoïde |
| Rhumatologique | Spondylarthrite grave | spondylarthrite ankylosante |
| Rhumatologique | Vascularites, lupus, sclérodermie systémique | lupus, sclérodermie, vascularite |
| Ostéo-articulaire | Scoliose idiopathique structurale évolutive | scoliose |
| Oncologique | Tumeurs malignes, affections malignes lymphatiques ou hématopoïétiques | cancer du sein, cancer du poumon, lymphome, leucémie |
| Génétique | Mucoviscidose | mucoviscidose |
| Transplantation | Suites de transplantation d'organe | greffe de rein, transplanté cardiaque |

La mucoviscidose et certaines maladies métaboliques héréditaires sont
aussi des **maladies rares** : quand Orphadata sera intégré, sa
classification primera pour elles.

## 4. Points à valider par le mainteneur

1. **Regroupement en systèmes** : les douze systèmes ci-dessus sont-ils
   cliniquement justes, et suffisants pour le médico-social ?
2. **Mentions** : abréviations (AVC, SEP, BPCO) à garder malgré le risque de
   faux positifs (« SEP » ailleurs qu'en neurologie) ?
3. **Pathologies hors liste ALD** fréquentes dans les écrits du terrain
   (obésité, hypertension, troubles du spectre de l'autisme, trisomie 21,
   handicap psychique) : à ajouter dans des catégories maison, ou laisser
   hors table ?
4. **Seuil** (P2-07 § 8, question 6) : *Standard* seul, ou *Renforcé* pour la
   pathologie.

## 5. Ce qui manque encore pour du code

- La validation de cette table (§ 4).
- Un **corpus de pathologies** annoté, pour mesurer un extracteur avant de
  l'écrire (règle 5).
- Une façon d'estimer la rareté : la liste ALD ne donne aucun effectif ;
  sans donnée de prévalence, la pathologie ne peut être généralisée qu'en
  **suggestion de dernier recours**, sans F chiffré.
- Pour les maladies rares : la licence d'Orphadata lue sur son site et le
  fichier de nomenclature en français, que la session ne peut pas
  atteindre (site hors de la liste réseau autorisée).

## 6. Source lue

- Liste des ALD, portail public sante.fr : https://www.sante.fr/endometriose/quest-ce-que-le-dispositif-appele-affection-longue-duree-ald
