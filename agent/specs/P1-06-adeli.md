# P1-06 — Détecteur ADELI : structure, validation, risque de faux positifs

Type : `spec`. Aucun code de production. Aucune donnée réelle.

## 0. Niveau de vérification

La structure ci-dessous vient d'une **recherche web** (résumés de sources
secondaires). Je n'ai **pas pu ouvrir** la fiche officielle de l'ASIP/ANS
(`esante.gouv.fr`, hôte inaccessible depuis l'environnement de l'agent). Tout
ce qui est marqué **[non vérifié]** doit être confirmé par le mainteneur sur
la source officielle avant d'écrire du code.

Sources à consulter (liens relevés, non lus en entier) :

- Fiche ASIP « Comprendre la différence entre les identifiants RPPS, ADELI et
  AM » :
  <https://esante.gouv.fr/sites/default/files/media_entity/documents/asip_pusc_comprendre_difference_identifiants_rpps_adeli_am.pdf>
- Annuaire Santé, profil FHIR du praticien (pour les types d'identifiants) :
  <https://interop.esante.gouv.fr/ig/fhir/annuaire/1.0.0-ballot-4/StructureDefinition-as-dp-practitioner.html>
- Glossaire grand public (source secondaire) :
  <https://appines.fr/guide/glossaire/numero-adeli>

## 1. Structure du numéro (d'après les sources secondaires)

- **9 caractères** [à confirmer sur la fiche officielle].
- Découpage rapporté : 2 caractères de **département** d'enregistrement,
  2 chiffres de **code profession**, 4 chiffres de **numéro
  d'enregistrement**, 1 **clé de contrôle** [non vérifié : la répartition
  exacte varie selon les sources].
- **Clé de contrôle : algorithme de Luhn** [non vérifié sur la fiche
  officielle ; indiqué par le résumé d'une fiche ASIP]. Si c'est exact, c'est
  la même clé que le FINESS, le SIREN et le RPPS : `luhn.dart` est réutilisable.
- **Format alphanumérique en Corse** : exemple rapporté `2B6021939` (lettre
  `A`/`B` à la place d'un chiffre du département) [non vérifié]. **Question
  ouverte** : comment la lettre entre dans le calcul de Luhn (valeur ? 0 ?
  conversion ?). Tant que ce n'est pas établi, ne pas valider la clé des ADELI
  corses ; les traiter comme « forme plausible sans clé vérifiée ».
- L'ADELI est progressivement remplacé par le RPPS (11 chiffres) pour les
  professions intégrées ; il reste présent dans les documents anciens et pour
  les professions non encore migrées. [source secondaire]
- La liste des codes profession valides n'a pas été récupérée : **ne pas
  l'inventer**. Sans cette liste, le code profession n'est pas un signal
  utilisable.

## 2. Collision avec FINESS et SIREN

Un ADELI numérique (hors Corse) a 9 chiffres et, si l'hypothèse Luhn est
exacte, la même clé que FINESS et SIREN. **La validation structurelle ne peut
pas distinguer les trois** : c'est la collision déjà mesurée sur le FINESS
(`agent/specs/P1-03-finess.md`, 42 faux positifs sur 42 SIREN pièges).

Ordre de grandeur, à titre indicatif (calcul, pas mesure) : un nombre
aléatoire de 9 chiffres passe Luhn une fois sur dix. Le préfixe département
(~97 valeurs valides sur 100) n'élimine presque rien, et le code profession
est inexploitable sans liste officielle.

**Observation importante.** `FinessDetector` capte déjà tout nombre de
9 chiffres à clé Luhn valide (confiance 0,5 sans contexte). Un ADELI Luhn-valide
est donc **déjà masqué aujourd'hui**, sous le type `finess`. Le risque de fuite
n'est pas là ; il est dans :

1. l'**ADELI à clé invalide** (faute de frappe) ou **corse** (non capté par
   un motif purement numérique) ;
2. l'**étiquette** : le texte restauré / l'audit affiche « finess » pour un
   ADELI ;
3. l'**ADELI écrit avec séparateurs** inhabituels (voir `DigitCompaction`).

## 3. Proposition de détection

Principe : **contexte lexical obligatoire pour émettre un type `adeli`**, pas
de détection nue.

1. Mots déclencheurs (insensibles à la casse, fenêtre de 40 caractères comme
   `FinessDetector`) : `ADELI`, `n° ADELI`, `numéro ADELI`, `N°ADELI`.
2. Avec déclencheur :
   - 9 chiffres, Luhn valide → `adeli`, confiance **0,9** ;
   - 9 chiffres, Luhn **invalide** → `adeli`, confiance **0,6** (un champ
     explicitement étiqueté ADELI mal saisi doit quand même être masqué :
     refus explicite plutôt que fuite) ;
   - forme corse `^(2[AB])[0-9]{7}$` → `adeli`, confiance 0,6 (clé non vérifiée).
3. Sans déclencheur : **ne rien émettre** côté ADELI. Les nombres Luhn-valides
   restent captés par `FinessDetector` (aucune régression de protection).
4. Résolution de chevauchement : sur un même span, `adeli` avec déclencheur
   « ADELI » l'emporte sur `finess` sans contexte « FINESS ». À traiter dans
   `resolveOverlaps` ou par une règle de tier explicite ; **décision de
   conception pour le mainteneur** car elle touche l'API de `ecluse_core`.
5. Nouveau `EntityType.adeli` : il n'existe pas aujourd'hui dans
   `entity.dart` (seuls `rpps`, `finess`… y figurent). Ajout public,
   donc à valider.

## 4. Risques de faux positifs

| Source | Effet | Mitigation |
|---|---|---|
| SIREN / FINESS sans déclencheur | Aucun nouveau FP ADELI (pas d'émission sans mot-clé) | Principe §3.3 |
| « ADELI » mentionné près d'un autre nombre de 9 chiffres (ex. SIREN du cabinet) | Mauvais rattachement du type | Ne retenir que le nombre le plus proche du mot-clé ; mesurer sur corpus |
| Numéro invalide étiqueté ADELI → masqué à 0,6 | Sur-masquage assumé | Documenté dans `LIMITES.md` |
| Mot « adeli » dans un nom propre ou une marque | Fenêtre de 40 caractères sans nombre : aucune émission | Aucune (pas de nombre) |

Estimation de volume réelle : **impossible** sans corpus ; ne pas annoncer de
chiffre de précision avant mesure (règle n°5 de `CLAUDE.md`).

## 5. Plan de mesure avant de coder (pour la tâche `code` à créer)

1. Étendre `bench/generate_corpus.py` (nouvelle version du corpus) : ADELI
   avec déclencheur (valide, invalide, espacé), ADELI sans déclencheur
   (annoté ? **décision** : en or, car c'est bien un ADELI, mais capté sous
   `finess`), phrases mixtes ADELI + SIREN, ADELI corse. Données **générées**
   par `luhn_digit`, jamais copiées.
2. Mesurer avant/après : précision/rappel `adeli`, et non-régression des
   scores `finess` (75,4 % / 100 %).
3. Tests unitaires : offsets exacts, séparateurs (via `DigitCompaction`),
   rejets (8 chiffres, 10 chiffres, mot-clé sans nombre).

## 6. Questions pour le mainteneur

1. Confirmer la structure et l'algorithme de clé sur la fiche officielle
   (§1) ; obtenir la règle de la lettre corse dans le calcul.
2. Valider l'ajout de `EntityType.adeli` et la règle de priorité face à
   `finess` (§3.4–3.5).
3. Accepter le sur-masquage des numéros à clé invalide étiquetés ADELI (§3.2).
4. L'ADELI en or sans déclencheur doit-il compter comme TP `adeli` (rappel
   `adeli` bas par construction) ou comme TP `finess` (alias de masquage) ?

## 7. Ce qui reste incertain

Tout le §1 est de seconde main ; la liste des codes profession et la règle
corse sont inconnues ; aucun chiffre de faux positifs réel n'est disponible.
