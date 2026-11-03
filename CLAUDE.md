# CLAUDE.md — règles pour les agents qui travaillent sur Écluse

Ce fichier s'applique à toute session Claude Code sur ce dépôt : session
interactive, tâche planifiée cloud ou exécution déclenchée par une PR.
Il est écrit et modifié **uniquement par le mainteneur**. Un agent ne le
modifie jamais, même pour le « corriger ».

## Le projet en bref

Écluse est un sas de pseudonymisation entre un utilisateur et un LLM tiers :
détecter et retenir localement ce qui identifie une personne, envoyer le
reste, restaurer la réponse. Monorepo Dart pur (SDK ≥ 3.3), géré par Melos,
licence Apache 2.0.

Avant toute tâche, lire au minimum : `ROADMAP.md` (phases et périmètre),
`DECISIONS.md` (choix déjà tranchés), `LIMITES.md` (ce qu'Écluse ne
prétend pas faire) et `agent/QUEUE.md` (la file de travail).

## Commandes

```bash
dart pub global activate melos
melos bootstrap
melos run format    # dart format --set-exit-if-changed
melos run analyze   # dart analyze --fatal-infos
melos run test
# Benchmark (Python) :
pip install -r bench/requirements.txt
python bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl
```

Une PR n'est ouverte que si les trois commandes `format`, `analyze` et
`test` passent localement.

## Règles non négociables

1. **Données synthétiques uniquement.** Aucun document réel, aucun extrait
   de vrai planning, aucun identifiant réel dans le code, les tests, les
   fixtures, les prompts ou les messages. Les identifiants de test sont
   générés (clés valides calculées), jamais copiés d'une source réelle.
2. **Aucun nom de prospect, d'établissement client ou de personne
   rencontrée** dans les commits, titres et descriptions de PR, commentaires
   ou fichiers versionnés. Le dépôt est public. Les entretiens se citent
   au plus par numéro anonyme (« entretien #2 »).
3. **Le LLM annote, il ne réécrit jamais le texte utilisateur.** Les offsets
   et la traçabilité sont des invariants.
4. **Refus explicite plutôt qu'échec silencieux.** Tout format illisible,
   ambigu ou hors périmètre est refusé avec un motif. Jamais de « rien à
   masquer » sur un contenu non lu.
5. **Mesurer avant de corriger.** Toute correction de détection commence
   par un test ou un cas de corpus qui montre le défaut, puis la correction,
   puis la mesure avant/après (précision, rappel, budget de faux positifs).
6. **Détecteurs purs.** Pas de réseau, pas d'effet de bord, pas de
   dépendance native dans `ecluse_core`.
7. **Périmètre tenu.** Image, scan, PDF-image et manuscrit restent hors
   périmètre sur `main`. Les branches `feat/ocr-scaffold`, `feat/llm-scaffold`
   et le NER ONNX ne sont pas fusionnés sans le critère GO/STOP validé par le
   mainteneur.

## Zones interdites à un agent autonome

Un agent ne modifie **pas** :

- `CLAUDE.md` ;
- `agent/QUEUE.md`, sauf la ligne de statut de **sa** tâche (voir plus bas) ;
- `agent/PROMPTS.md` et `agent/setup-cloud-env.sh` ;
- `GEMINI.md` (consignes du relecteur Gemini) ;
- `.github/` (workflows, dependabot, modèles) ;
- `LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md` ;
- la branche `main`, directement ou par force-push.

Un agent n'ajoute pas de dépendance (pub ou pip) sans que la tâche le
prévoie explicitement. S'il en faut une, il s'arrête et le signale.

## Déroulé d'une exécution autonome

1. **Vérifier la condition d'arrêt.** Compter les PR ouvertes dont la branche
   commence par `claude/`. En session cloud, `gh pr` est indisponible ;
   utiliser l'API REST :
   `gh api 'repos/ecluse-dev/ecluse/pulls?state=open&per_page=100' --jq '[.[] | select(.head.ref | startswith("claude/"))] | length'`.
   S'il y en a **3 ou plus**, ne rien faire d'autre : terminer la session
   en une phrase (« 3 PR en attente de revue, arrêt »). S'il est impossible
   de compter les PR ouvertes, s'arrêter aussi.
2. **Choisir une seule tâche** dans `agent/QUEUE.md` : la première ligne au
   statut `à faire` dont toutes les dépendances sont `fusionnée`, et qui
   n'est pas marquée `humain`. Aucune tâche éligible → s'arrêter.
3. **Lire la fiche de la tâche** (section détaillée sous le tableau) et les
   fichiers qu'elle cite.
4. **Travailler sur une branche** `claude/<id-tâche>-<slug>` partie de `main`.
5. **Respecter le type de tâche** :
   - `code` : implémentation + tests, dans le périmètre de la fiche ;
   - `spec` : un document de conception seulement, aucune ligne de code de
     production. Les specs vont dans `agent/specs/<id>.md` ;
   - `mesure` : exécuter, mesurer, rapporter ; ne rien corriger.
6. **Mettre à jour la ligne de statut** de la tâche dans `agent/QUEUE.md`
   à `PR ouverte`, dans le même commit que le travail.
7. **Ouvrir une PR** vers `main` avec : ce qui a été fait, les mesures
   avant/après le cas échéant, ce qui reste incertain, et ce que le
   mainteneur doit vérifier. Ne jamais la fusionner.
8. **S'arrêter.** Une tâche par exécution, même s'il reste du temps.

## Relecture par Gemini

Le mainteneur peut faire relire une PR par Gemini CLI depuis son poste
(consignes dans `GEMINI.md`). C'est un relecteur d'une autre famille de
modèle : ses remarques servent au mainteneur. Un agent autonome n'y répond
pas et ne relance pas d'exécution pour les traiter ; le mainteneur décide
s'il crée une tâche de correction.

## Quand s'arrêter et rendre la main

Arrêter la tâche et l'expliquer dans la PR (ou, sans PR possible, dans le
compte rendu de session) quand :

- la fiche est ambiguë ou contradictoire avec `DECISIONS.md` ;
- la tâche exigerait de toucher une zone interdite ;
- la tâche exigerait des données réelles ou un accès à la machine du
  mainteneur ;
- un test existant échoue sur `main` avant tout changement ;
- deux tentatives de correction n'ont pas rendu la CI verte.

Mieux vaut une PR « bloqué, voici pourquoi » qu'un contournement.

## Style

- Code, commentaires, documentation et messages de commit en français,
  comme le reste du dépôt.
- Les commentaires de doc expliquent le *pourquoi* (cf. détecteurs
  existants), pas seulement le *quoi*.
- Tout détecteur livré avec ses tests : cas valides, rejets, positions.
- Tests reproductibles : seeds explicites, aucune dépendance à l'heure ou
  au réseau.
