# Conception — boucle d'anonymisation (risque → généralise → re-mesure)

Le cœur intelligent d'Écluse : au lieu de masquer en une passe, on mesure
le risque de ré-identification, on généralise juste ce qu'il faut, et on
re-mesure jusqu'à passer sous un seuil. À implémenter en phase 2, après le
NER. Ce document fige les décisions de conception. Voir RECHERCHE.md pour
les fondations théoriques (risque = 1/F, El Emam, ARX).

---

## 1. Contrat d'entrée/sortie

La boucle travaille sur une **structure de quasi-identifiants (QI)**, pas
sur du texte brut. Le texte n'est régénéré qu'à la sortie.

- **Entrée** : texte déjà pseudonymisé (identifiants directs traités) +
  liste de QI repérés par le NER :
  `[{type, valeur, position, niveau: 0}, …]`
- **Sortie** : liste de QI avec niveaux relevés, texte reconstruit, score
  de risque final, journal des décisions.

Avantage : pas de re-détection à chaque tour (plus rapide, plus sûr).

## 2. Seuil d'acceptation (configurable, jamais codé en dur)

Trois niveaux nommés, le risque étant 1/F (F = taille de classe
d'équivalence estimée) :

| Niveau     | F minimum | Risque max | Usage                              |
|------------|-----------|------------|-------------------------------------|
| Standard   | ≥ 10      | 0,10       | cas courant (défaut)               |
| Renforcé   | ≥ 20      | 0,05       | santé sensible (pathologie, psy)   |
| Strict     | ≥ 50      | 0,02       | cas les plus exposés               |

F ≥ 5 (classique k-anonymat historique) jugé trop faible aujourd'hui.
Défaut prudent à F ≥ 10. **Valeurs à confirmer avec les design partners DPO.**

## 3. Mesure du risque (approximation transparente)

On ne connaîtra jamais le F exact d'un texte isolé (pas de population de
référence) → on vise un ordre de grandeur fiable, et on est transparent
sur l'approximation.

Méthode : pour chaque QI, estimer la part de la population française qui
partage cette caractéristique via **données publiques** (INSEE pour
géo/âge, RPPS/ADELI agrégés pour les professions de santé). Combiner
(première approximation, indépendance supposée) → estimer F.

> Exemple : « pneumologue » (rare) × « ce département » (filtre fort) ×
> « 94 ans » (très rare) → poignée de personnes → F petit → risque élevé.

L'hypothèse d'indépendance est fausse en rigueur (âge et fonction
corrélés) → l'assumer comme **approximation prudente** dans la doc. Un
estimateur simple et transparent vaut mieux qu'un modèle opaque, surtout
pour un produit dont la valeur est la confiance.

## 4. Action de réduction (gloutonne et explicable)

Quand risque > seuil, choisir le QI à généraliser : celui au **meilleur
rapport risque-gagné / sens-perdu**.

À chaque tour, pour chaque QI encore généralisable, simuler « +1 cran →
le risque tombe de combien ? » et prendre le plus efficace. Stratégie
gloutonne (greedy) : pas optimale mathématiquement, mais simple, rapide,
**explicable pour l'audit**. Raffinement possible : pondérer par
l'importance du QI pour le sens (généraliser un lieu coûte souvent moins
de sens que généraliser une pathologie centrale au propos).

## 5. Trois sorties (l'épuisement rend la main à l'humain)

- **Succès** : risque < seuil → sortir le texte.
- **Garde-fou** : nombre max d'itérations atteint → arrêt de sécurité
  (borne dure, indépendante de la logique métier).
- **Épuisement** : tout généralisé au max, risque toujours > seuil.
  → Écluse **ne décide pas seul** : il s'arrête et alerte. « Ce texte ne
  peut pas être anonymisé sous votre seuil sans perdre l'essentiel. Voici
  les éléments bloquants. » Puis rend la main avec trois options :
  envoyer en assumant le risque (journalisé), supprimer le QI bloquant,
  ou renoncer. C'est aussi le déclencheur naturel du **routage
  on-device** : un texte irréductiblement sensible va au modèle local,
  pas au cloud.

Cohérent avec la vision : Écluse **mesure et informe**, il ne masque pas
aveuglément ni ne décide à la place de l'humain responsable.

## 6. Trace (un journal, deux usages)

À chaque itération : QI concerné, niveau avant→après, risque avant,
risque après, raison du choix. Ligne de conclusion : seuil visé, atteint
ou non, score final, type de sortie. Sert l'**audit AIPD** (preuve
technique) ET le **mode explication** (récit lisible DPO).

---

## Pseudo-code

```
qis = ner_extraire_quasi_identifiants(texte_pseudonymisé)
itérations = 0
tant que risque(qis) > seuil ET itérations < MAX :
    candidat = qi_au_meilleur_gain(qis)        # greedy
    si candidat généralisable :
        généraliser(candidat)                  # +1 cran
        journaliser(candidat, risque_avant, risque_après)
    sinon :
        retour ÉPUISEMENT(qis, risque, bloquants)
    itérations += 1
si itérations == MAX : retour GARDE_FOU(...)
retour SUCCÈS(reconstruire(texte, qis), risque(qis), journal)
```

---

## Hiérarchies de généralisation françaises (le carburant de l'étape 4)

Chaque QI a une échelle de « crans », du plus précis (niveau 0) au plus
général. La boucle monte d'un cran à la fois.

### Géographie
0. Commune (Thionville)
1. Département (Moselle / 57)
2. Région (Grand Est)
3. Grande zone (Nord-Est de la France)
4. Pays (France) → puis suppression
Source : codes officiels géographiques INSEE (COG).

### Âge
0. Âge exact (94 ans)
1. Tranche de 5 ans (90-94)
2. Tranche de 10 ans (90-99)
3. Catégorie large (« plus de 75 ans », « mineur/adulte/senior »)
4. Suppression
Note : les grands âges (85+) sont fortement ré-identifiants (peu
d'individus) → souvent traités directement en catégorie « 85+ ».
Source : pyramide des âges INSEE.

### Date (naissance, événement)
0. Date exacte (12/03/1931)
1. Mois/année (03/1931)
2. Année (1931)
3. Décennie / tranche → suppression

### Profession de santé
0. Spécialité précise + lieu (chef de pneumologie, CH de X)
1. Spécialité (pneumologue)
2. Famille (médecin spécialiste)
3. Catégorie (professionnel de santé)
4. Suppression
Source : nomenclatures RPPS/ADELI (effectifs par spécialité/département
pour l'estimation de rareté).

### Pathologie
0. Diagnostic précis (maladie rare nommée)
1. Catégorie (maladie génétique rare)
2. Système concerné (maladie neurologique)
3. Mention vague (« pathologie chronique ») → suppression
Attention : la pathologie est souvent le cœur du sens médical →
généraliser en dernier recours, signaler le coût en sens.

### Employeur / établissement
0. Établissement nommé (CHR de Metz)
1. Type + ville (CHR de Metz → « un hôpital de Metz »)
2. Type + zone (« un hôpital du Grand Est »)
3. Type seul (« un établissement hospitalier ») → suppression

---

## Principes de conception à retenir

- La boucle manipule une **structure de QI**, pas du texte.
- Seuil **configurable** (défaut F ≥ 10), jamais codé en dur.
- Risque = **approximation transparente** via données publiques FR ;
  la transparence sur l'imprécision est une force.
- Réduction **gloutonne et explicable** (greedy).
- L'épuisement **rend la main à l'humain** + déclenche le routage local.
- Un **seul journal** sert l'audit AIPD et le mode explication.

Tout ceci est de la **phase 2** (après le NER). Le poser sur le papier
clarifie la vision ; ne pas le coder avant qu'un client paie pour la base.
