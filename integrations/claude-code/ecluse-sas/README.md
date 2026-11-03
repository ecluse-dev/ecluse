# ecluse-sas — prototype de mod Claude Code

Sas Écluse branché dans Claude Code (v2.1.287+), en deux portes :

- **Ce que Claude reçoit** (prompts tapés, résultats des outils : fichiers lus,
  sorties de commandes…) passe d'abord par le moteur Écluse local et arrive
  pseudonymisé (`[NOM_1]`, `[NIR_1]`…).
- **Ce que Claude produit** est restauré localement : à l'écran pour ses
  réponses, sur le disque pour les fichiers qu'il écrit ou modifie.

Si le moteur ne répond pas, rien ne part : prompt bloqué, outil bloqué, ou
résultat retenu.

## Lancer

Fenêtre 1, le moteur (à la racine du monorepo) :

```powershell
cd packages\ecluse_demo
dart run bin/sas.dart        # écoute sur 127.0.0.1:8787, aucune clé API
```

Fenêtre 2, Claude Code avec le mod :

```powershell
claude --plugin-dir $HOME\Documents\ecluse-sas
```

`faux-moteur.mjs` (Node) imite le moteur pour tester le mod seul.

Adresse du moteur : option `endpoint` (défaut `http://127.0.0.1:8787`).
Toute adresse non locale est refusée et bloque tout.

## Contrat du moteur

| Route | Corps | Réponse |
|---|---|---|
| `POST /v1/redact` | `{ "session", "text" }` | `{ "text", "entities" }` |
| `POST /v1/restore` | `{ "session", "text" }` | `{ "text" }` |

La table de correspondance reste dans le moteur, en mémoire, par session,
avec des jetons stables sur toute la conversation. Le mod ne la voit jamais.

## Règles par outil

| Outil | Entrée (ce que Claude demande) | Résultat (ce que Claude lit) |
|---|---|---|
| Read, Glob, Grep | jetons restaurés (chemins réels) | pseudonymisé |
| Write, Edit, MultiEdit, NotebookEdit | jetons restaurés : le disque garde les vraies valeurs | pseudonymisé |
| Bash, WebFetch, WebSearch, MCP, autres | **jetons laissés tels quels**, aucune vraie valeur ne sort | pseudonymisé |
| Image ou PDF (contenu binaire) | — | retenu (non vérifiable) |

## Comportement en cas d'échec (testé)

| Situation | Résultat |
|---|---|
| Moteur injoignable, lent (30 s), HTTP ≠ 2xx, réponse illisible | prompt bloqué / outil bloqué / résultat retenu |
| Hook qui plante ou dépasse son budget | idem (`.catch`) |
| Image ou pièce jointe dans le prompt | prompt bloqué |
| Adresse du moteur non locale | tout bloqué |
| Restauration impossible à l'affichage | la réponse s'affiche avec ses jetons |

`claude plugin test .` : 14 tests, 14 réussis.

## Ce que le prototype NE couvre PAS

- **Commandes slash** (`/xxx args`) : partent en clair (signalé dans le fil).
- **Contexte automatique** : prompt système, CLAUDE.md, état git, rappels.
- **Commandes Bash qui citent un jeton** : `grep "[NOM_1]"` ne trouvera rien,
  le jeton n'étant pas restauré pour Bash (choix de sécurité).
- **Noms dans les chemins de fichiers** : pseudonymisés si le moteur les
  détecte, sinon visibles.
- **À vérifier en vrai** : qu'Edit accepte toujours un fichier dont la lecture
  a été réécrite par le mod (contrôle « fichier déjà lu » de Claude Code).
