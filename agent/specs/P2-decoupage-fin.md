# Phase 2 : découpage de ce qui reste

Proposition du 2 novembre 2026. La file (`agent/QUEUE.md`) est épuisée : sa
dernière tâche, P2-85, est fusionnée, et aucune ligne `à faire` ne reste. Or
`ROADMAP.md` garde des items de phase 2 qui ne sont jamais entrés dans la file.
La règle de `QUEUE.md` (« la phase 3 sera découpée quand la phase 2 sera
fusionnée ») ne se déclenchera donc jamais seule.

Ce document propose des tâches. **Il ne modifie pas la file** : seules les
lignes que le mainteneur y copie sont prises par l'agent (règle de
`CLAUDE.md`). Les identifiants `P2-86` et suivants sont provisoires.

Priorité retenue par le mainteneur le 2 novembre 2026 : **trancher le NER
d'abord**.

## 1. État de départ (lu dans le dépôt)

| Item de `ROADMAP.md` | Ce qui existe sur `main` | Ce qui manque |
|---|---|---|
| NER local | Spec du critère GO/STOP (P2-01) ; référence des heuristiques (P2-02, P2-12) ; paquet `ecluse_ner` à l'état de stub | Modèle choisi, mesure sur les trois corpus flous, décision GO/STOP |
| Score de ré-identification | Rapport de risque branché dans `Ecluse.redact`, désactivé par défaut (P2-04, option A de P2-03) | Suggestions positionnées, puis application explicite par l'appelant (option B, décision P2-03 n° 1) |
| Généralisation multi-dimensions | Échelle de dates et âge dérivé dans `ecluse_reid` (P2-17) | Application (même option B) ; pathologie : aucune source de table (P2-07 § 3) |
| Généralisation géographique | Hiérarchie commune → département → France dans `ecluse_reid` | Régions non calculées ; application (option B) |
| Export AIPD | Agrégat du journal (`AuditExporter.agrege`, P2-15) | Gabarit CNIL non lu, avis d'un DPO non sollicité (P2-09) |
| Journal d'audit | Bibliothèque `ecluse_audit` v0 | Non branché dans `Ecluse.redact` (`LIMITES.md` § 8) |
| Transcription vocale | Spec P2-10, moteur retenu whisper.cpp | Mesure sur texte transcrit, décision sur la dépendance native, critère GO/STOP |
| Routage on-device / cloud | Rien sur `main` ; scaffold LLM en brouillon (PR #10) | Critère GO/STOP du vérificateur LLM (règle 7) |
| SDK Python | Rien | Décision du mainteneur avant toute spec |
| Chatbot de support | Rien | Dépend d'un LLM tiers ; aucune valeur avant les autres briques |

## 2. Tâches proposées

« Bloquant » = ce que le mainteneur ou une source externe doit fournir avant
que l'agent puisse finir.

### Bloc A — NER : trancher (priorité 1)

| Id | Type | Tâche | Dépend de | Bloquant |
|---|---|---|---|---|
| P2-86 | spec | Fiche des modèles candidats (au plus deux) : licence des poids lue sur la page de distribution, taille quantifiée, labels français, correspondance avec les types d'`ecluse_redact` | — | Si la page du modèle n'est pas joignable depuis l'environnement cloud, la fiche le dit et le mainteneur lit la licence |
| P2-87 | humain | Valider les seuils de P2-01 § 7 (gain de fuite, faux positifs du témoin, 300 Mo, 2 s) et nommer la machine de référence | — | — |
| P2-88 | code | `bench/ner_predictions.md` : format d'entrée attendu par `score_flou.py` (déjà existant), table de correspondance des labels du modèle vers les types du corpus, commande exacte de la mesure | P2-86 | — |
| P2-89 | humain | Produire les prédictions du modèle sur les trois corpus flous (graine 42, 400 documents) sur le poste du mainteneur, puis les scorer avec `score_flou.py` | P2-87, P2-88 | Le modèle tourne en local ; aucune donnée réelle |
| P2-90 | humain | Décision GO/STOP du NER, écrite dans `DECISIONS.md` | P2-89 | — |

Pourquoi ce découpage : `score_flou.py` accepte déjà des prédictions externes
(`--pred "NER=preds.jsonl"`). L'agent n'a donc besoin ni du modèle, ni d'une
dépendance ONNX, ni d'un accès réseau au dépôt de modèles pour préparer la
mesure. La règle 7 (aucun NER ONNX fusionné sans GO) est tenue.

### Bloc B — Généralisation appliquée (option B de P2-03)

| Id | Type | Tâche | Dépend de | Bloquant |
|---|---|---|---|---|
| P2-91 | code | Rapport de risque : suggestions de généralisation **positionnées** (QI, offsets, niveau proposé, F avant/après), sans changer le texte | — | — |
| P2-92 | code | Fonction explicite d'application des suggestions choisies par l'appelant : irréversible, hors table de correspondance, refus si la proposition est périmée (même règle que l'aperçu, P2-19) | P2-91 | — |
| P2-93 | mesure | Avant/après sur le corpus de QI (`score_qi.py`) : part de documents sous le seuil *Standard*, caractères modifiés, QI généralisés | P2-92 | — |
| P2-94 | humain | Choisir la source de la table pathologie → catégorie et lire sa licence | — | Aucune source dans le dépôt (P2-07 § 3) |

Invariants rappelés : le moteur ne généralise jamais de lui-même ; sans option,
la sortie d'`Ecluse.redact` est inchangée octet pour octet (décision P2-03 n° 2).

### Bloc C — Journal d'audit branché

| Id | Type | Tâche | Dépend de | Bloquant |
|---|---|---|---|---|
| P2-95 | spec | Point de branchement d'`ecluse_audit` dans `Ecluse.redact` : `AuditSink` optionnel fourni par l'appelant, aucun journal par défaut, ce qu'une entrée contient pour un aperçu et pour un refus | — | — |
| P2-96 | code | Implémentation de P2-95, test d'équivalence d'abord (sans sink, sortie inchangée) | P2-95 | — |
| P2-97 | humain | Lire le gabarit AIPD de la CNIL et solliciter l'avis d'un DPO (préalable de l'export AIPD) | — | Source externe |

### Bloc D — Vocal, sans dépendance native

| Id | Type | Tâche | Dépend de | Bloquant |
|---|---|---|---|---|
| P2-98 | mesure | Rappel des détecteurs sur un texte « de style transcrit » généré (minuscules, ponctuation absente, nombres dictés en lettres), sans audio ni moteur vocal (P2-10 § 9.1) | — | — |
| P2-99 | humain | Décider si une dépendance native (whisper.cpp) peut entrer dans le monorepo, et dans quel paquet | P2-98 | — |

P2-98 est utile même en cas de STOP du vocal : il mesure ce qu'un texte dicté
par ailleurs (outil tiers) laisserait fuir.

### Bloc E — Maintenance découverte le 2 novembre 2026

| Id | Type | Tâche | Dépend de | Bloquant |
|---|---|---|---|---|
| P2-100 | code | Tests de coût : remplacer les bornes en millisecondes par un rapport de temps entre deux tailles (même méthode que la PR #242), paquet par paquet | PR #242 fusionnée | — |
| P2-101 | code | Migration vers Melos 7 et plus : la configuration passe dans `pubspec.yaml` (la PR Dependabot #18 échoue avec `NoScriptException`) | — | Touche peut-être `.github/` : à faire par le mainteneur ou avec son accord explicite |

## 3. Ce que ce document propose de ne pas découper maintenant

- **Routage on-device / cloud** : suppose le vérificateur LLM, soumis à la
  règle 7. Proposition : écrire d'abord une spec du critère GO/STOP du
  vérificateur (même forme que P2-01) une fois le NER tranché, car un GO du
  NER change ce que le vérificateur doit rattraper.
- **SDK Python** : proposition de le **reporter en phase 3**, à côté du SDK
  JS/TS et des adaptateurs Presidio et LiteLLM. Les trois relèvent de la
  distribution, pas de la profondeur de détection.
- **Chatbot de support** : proposition de le **reporter en phase 3**, après
  l'offre cloud. Il dépend d'un LLM tiers et n'apporte rien avant.

Si le mainteneur accepte ces deux reports, la phase 2 se termine avec les
blocs A à D.

## 4. Ordre conseillé

1. P2-87 (décision, une heure) et P2-86 en parallèle : ils débloquent le NER.
2. P2-91 puis P2-92 : l'agent avance pendant que le mainteneur mesure le NER.
3. P2-95 puis P2-96, P2-98, P2-100 : sans source externe.
4. P2-89 et P2-90 dès que la fiche et la commande sont prêtes.

## 5. Questions pour le mainteneur

1. Accepter les reports du SDK Python et du chatbot en phase 3 ?
2. Pour P2-101, qui fait la modification si `.github/` doit changer ?
3. Les tâches `humain` (P2-87, P2-89, P2-90, P2-94, P2-97, P2-99) : faut-il les
   copier dans la file pour qu'elles apparaissent dans le bilan hebdomadaire ?

## 6. Ce que ce document ne sait pas

- Si un modèle candidat a une licence de poids permissive et lisible.
- Si la généralisation d'un cran suffit à passer sous le seuil *Standard* sur
  le corpus de QI : c'est ce que P2-93 mesure.
- Le contenu du gabarit AIPD de la CNIL.
