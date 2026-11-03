# Phase 2 : découpage proposé en tâches

`agent/QUEUE.md` est une zone interdite à l'agent : ces lignes sont
**à copier par le mainteneur** dans la file, dans l'ordre qu'il choisit. Ce
document ne contient aucune ligne de code et ne décide rien : il propose.
Sources lues pour l'écrire : `ROADMAP.md` (phases 2 et 3, périmètre d'entrée,
principes), `CLAUDE.md` (règles 3 à 7), `DECISIONS.md`, `LIMITES.md` §§ 5 à 8 et
l'état des paquets `ecluse_ner`, `ecluse_reid`, `ecluse_audit`.

## Constats qui contraignent le découpage

1. **Deux bibliothèques existent mais ne sont pas branchées** : `ecluse_reid`
   (estimation de ré-identification, généralisation géographique ; `LIMITES.md`
   §§ 6 et 7) et `ecluse_audit` (journal chaîné ; `LIMITES.md` § 8). Brancher
   l'existant ne demande ni dépendance ni source externe : c'est le travail le
   moins risqué de la phase.
2. **Le NER local est verrouillé par `CLAUDE.md` règle 7** : le NER ONNX n'est
   pas fusionné sans le critère GO/STOP validé par le mainteneur. Ce critère
   n'est écrit nulle part dans le dépôt. `ecluse_ner` est aujourd'hui un stub
   sans dépendance native. Premier pas utile : écrire le critère, pas le code.
3. **Toute dépendance (pub ou pip) exige que la tâche la prévoie** (`CLAUDE.md`).
   Le NER (runtime ONNX et modèle), la transcription vocale (Vosk ou
   whisper.cpp) et le SDK Python en demandent toutes : chacune passe donc par
   une spec qui nomme la dépendance et sa licence.
4. **Mesurer avant de corriger** (règle 5) : toute amélioration de détection
   démarre par un cas de corpus qui montre le défaut.
5. **La phase 1 n'est pas entièrement fermée** : P1-00, P1-10 et P1-12 restent
   à `humain`. `QUEUE.md` dit que la phase 2 sera découpée « quand la phase 1
   sera fusionnée » ; ce document est donc anticipé.

## Tâches proposées

Les identifiants `P2-xx` sont provisoires. « Bloquants » = ce que le mainteneur
ou une source externe doit fournir avant que l'agent puisse finir.

| Id proposé | Type | Tâche | Dépend de | Bloquants à lever d'abord |
|---|---|---|---|---|
| P2-01 | spec | Critère GO/STOP du NER local : métriques (rappel, précision, budget de faux positifs sur noms et adresses), corpus de décision, plafonds de taille de modèle et de latence, ce qui arrête le chantier | — | Le mainteneur valide le critère (règle 7) |
| P2-02 | mesure | Référence chiffrée des détecteurs heuristiques de noms et adresses (`ecluse_redact`) sur le corpus flou, modes strict et souple : c'est la valeur à battre pour le GO/STOP. Ne rien corriger | P2-01 | — |
| P2-03 | spec | Branchement de `ecluse_reid` dans `Ecluse.redact` : où le score apparaît, mode de généralisation irréversible distinct de la pseudonymisation, comportement sur commune ambiguë (jamais « faible », voir `DECISIONS.md`) | — | Arbitrage sur le contrat public (le score change-t-il la sortie, ou seulement un rapport ?) |
| P2-04 | code | Implémentation de P2-03, test d'abord, mesure avant/après de ce que la généralisation masque ou casse | P2-03 | — |
| P2-05 | spec | Pseudonymes cohérents et cloisonnés par dossier : identité d'un dossier, durée de vie de la carte (jamais sérialisée), traitement du cas P1-26 (deux personnes de même patronyme), ce qui empêche le recoupement entre dossiers | — | Définition d'un « dossier » côté application cliente |
| P2-06 | code | Implémentation de P2-05 | P2-05 | — |
| P2-07 | spec | Généralisation multi-dimensions (date de naissance vers tranche d'âge, âge vers palier, pathologie rare vers catégorie) : liste des dimensions, table de catégories, honnêteté sur ce qui reste ré-identifiable | P2-03 | Source de la table de catégories de pathologies (aucune dans le dépôt) |
| P2-08 | spec | Aperçu avec validation en un clic, **option** et non défaut (entretien #2) : contrat du composant (ce qu'il reçoit de `redact`, ce qu'il renvoie), sans interface autonome (phase 3) | — | — |
| P2-09 | spec | Export AIPD : champs du registre pré-rempli, quelles données d'`ecluse_audit` y entrent, ce qui n'y entre pas | — | **Le gabarit CNIL n'a pas été lu** ; avis du DPO avant d'affirmer publiquement que le journal n'est pas une donnée personnelle (`DECISIONS.md`) |
| P2-10 | spec | Transcription vocale locale : choix Vosk ou whisper.cpp, preuve qu'aucun son ne sort de l'appareil (aucun repli cloud), limite honnête sur les chiffres, critère GO/STOP propre | — | Licences et tailles des modèles non vérifiées ; mesure des erreurs sur les identifiants numériques |

Non découpé volontairement : routage on-device / cloud, SDK Python et chatbot de
support. Le routage suppose le scaffold LLM, lui aussi soumis au GO/STOP
(règle 7). Le SDK Python ouvre une chaîne d'outils entière (dépendances,
distribution) qui mérite une décision du mainteneur avant toute spec. Le chatbot
dépend d'un LLM tiers et n'a pas de valeur avant les autres briques.

## Ordre conseillé et raisons

1. **P2-01 d'abord** : il ne coûte aucune dépendance, il demande une seule
   décision du mainteneur, et il débloque tout le chantier NER.
2. **P2-03 puis P2-04** : brancher `ecluse_reid` est ce qui rapproche le plus
   l'objectif de la phase (« occuper le coin vide ») et n'a besoin d'aucune
   source externe.
3. **P2-02** en parallèle, une fois P2-01 écrit.
4. **P2-05 puis P2-06** : touche l'invariant « la carte n'est jamais
   sérialisée » ; une spec avant le code limite le risque.
5. **P2-07, P2-08, P2-09, P2-10** selon les signaux des design partners
   (`ROADMAP.md` : un client qui paie réordonne la liste).

## Ce que ce document ne sait pas

- Le contenu du gabarit AIPD de la CNIL, les licences et poids de GLiNER, Vosk
  et whisper.cpp : non lus, donc aucune affirmation dessus ici.
- Si le NER améliorera réellement le rappel sur noms et adresses : c'est
  précisément ce que P2-02 et le GO/STOP doivent mesurer.
- L'effort réel de chaque tâche : aucune estimation n'a été faite.

## Questions pour le mainteneur

1. Voulez-vous que le branchement de `ecluse_reid` (P2-03) change le texte
   envoyé au LLM, ou seulement produise un rapport de risque ?
2. Qu'est-ce qui doit déclencher un STOP du NER (taille du modèle, latence,
   licence, gain de rappel insuffisant) ?
3. Y a-t-il un design partner dont le besoin doit réordonner ces tâches ?
