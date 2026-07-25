# ecluse_demo

Interface de démonstration d'[Écluse](https://github.com/ecluse-dev/ecluse) :
le trajet complet **redact → LLM → restore**, en direct dans le navigateur.
Serveur Dart local (`shelf`), page HTML unique, sans Flutter ni étape de
build — zéro friction d'installation pour une démo devant un prospect.

## Lancer la démo

```sh
cd packages/ecluse_demo
$env:ANTHROPIC_API_KEY = "sk-ant-..."   # PowerShell ; export sous bash
dart run bin/serve.dart
```

Puis ouvrir <http://localhost:8080>.

Variables d'environnement :

| Variable | Requise | Défaut | Rôle |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | oui | — | Clé API Anthropic, jamais en dur dans le code. |
| `ECLUSE_LLM_MODEL` | non | `claude-sonnet-5` | Modèle Claude utilisé. |
| `PORT` | non | `8080` | Port d'écoute local. |

Si vous préférez un fichier `.env`, il est déjà couvert par le
`.gitignore` racine (`.env*`) — ne jamais le committer.

## Ce que fait la démo

1. Vous collez un texte (ou chargez un des deux documents d'exemple).
2. Un seul bouton, « Envoyer à l'IA » : aucune étape manuelle de
   préparation, conformément au principe « embarqué et transparent » de
   la démo.
3. Le serveur masque le texte localement (`Ecluse.redact`, package
   `ecluse_redact`), envoie **uniquement le texte masqué** à Claude avec
   une consigne système lui demandant explicitement de préserver les
   jetons tels quels, puis restaure les vraies valeurs dans la réponse
   (`Ecluse.restore`) — toujours localement.
4. Quatre panneaux affichent le trajet complet : document d'origine
   (entités surlignées), texte envoyé à l'IA (jetons + compteur), réponse
   brute de l'IA, résultat final restauré.

## Garanties

- La table de correspondance jeton ↔ valeur réelle (`RedactResult.mapping`)
  ne quitte jamais `RedactService.process` : elle n'est ni renvoyée au
  navigateur, ni journalisée, ni écrite sur disque.
- Le prompt envoyé au LLM ne contient que le texte masqué et la consigne
  — jamais le texte original.
- Les logs serveur (stdout) n'affichent que des événements de haut
  niveau (nombre de caractères, nombre d'entités masquées) — jamais de
  contenu.
- Toute erreur réseau ou d'API est interceptée et renvoyée comme message
  clair à l'interface (`{"error": "..."}`), jamais comme plantage du
  serveur.

## Hors périmètre de cette démo

Pas d'OCR, pas de score de ré-identification, pas de journal d'audit
chaîné, pas de chiffrement de la table de correspondance (elle reste en
mémoire process), pas de mode « aperçu + validation » — le mode par
défaut est automatique et transparent de bout en bout. Voir
`BRIEF_DEMO.md` à la racine du monorepo.
