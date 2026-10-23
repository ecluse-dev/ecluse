# Tâches planifiées des agents — configuration et prompts

Ce fichier décrit les trois tâches planifiées à créer sur
claude.ai/code (section « Scheduled » / routines). Il est tenu par le
mainteneur ; un agent ne le modifie pas.

Réglages communs aux trois tâches :

- **Dépôt** : `ecluse-dev/ecluse` uniquement.
- **Environnement cloud** : un environnement dédié « ecluse », réseau
  *Trusted* (par défaut), avec `agent/setup-cloud-env.sh` collé dans le
  champ *Setup script*. Aucune variable d'environnement, et surtout aucune
  clé d'API.
- **Connecteurs** : aucun. Retirer tous ceux proposés par défaut.

---

## 1. Agent dev

- **Déclencheur** : planification personnalisée, deux exécutions par nuit
  espacées de cinq heures : `7 4,23 * * *`, fuseau Europe/Paris.
- **Modèle** : un modèle de la gamme Sonnet (coût maîtrisé).

Prompt :

```text
Tu es l'agent de développement d'Écluse. Lis CLAUDE.md à la racine du dépôt
et applique strictement son « Déroulé d'une exécution autonome » :
condition d'arrêt (3 PR claude/* ouvertes ou plus), une seule tâche prise
dans agent/QUEUE.md, branche claude/<id>-<slug>, statut mis à jour à
« PR ouverte », PR vers main, puis arrêt.

Avant de coder : export PATH="$PATH:/opt/dart-sdk/bin:$HOME/.pub-cache/bin"
puis melos bootstrap, et vérifie que melos run test passe sur main. Si ce
n'est pas le cas, n'entreprends aucune tâche : ouvre une PR « bloqué »
décrivant l'échec.

Ne fusionne jamais rien. Ne modifie aucune zone interdite listée dans
CLAUDE.md. En cas de doute, arrête-toi et explique pourquoi dans la PR.
```

## 2. Agent red-team

- **Déclencheur** : événement GitHub *Pull request*, action `labeled`,
  filtres : branche de tête commence par `claude/`, labels contiennent
  `detection`. Le mainteneur pose le label sur les PR qui touchent la
  détection.
- **Modèle** : le plus capable disponible (s'exécute rarement).

Prompt :

```text
Tu es l'agent red-team d'Écluse. Une PR qui modifie la détection vient
d'être étiquetée « detection ». Lis CLAUDE.md, puis le diff de la PR.

Ton seul objectif : trouver des cas où le code de la PR laisse fuir une
donnée identifiante ou produit un faux positif. Utilise uniquement des
données synthétiques (clés de contrôle calculées, jamais copiées).

1. Écris des cas d'attaque (séparateurs exotiques, Unicode, chevauchements,
   contextes ambigus, valeurs valides par coïncidence) et exécute-les
   localement contre la branche de la PR.
2. Publie UN commentaire sur la PR via
   gh api repos/ecluse-dev/ecluse/issues/<numéro>/comments -f body=...
   listant les cas qui cassent, avec l'entrée exacte, le résultat obtenu et
   le résultat attendu. Si rien ne casse, dis-le et liste ce que tu as
   essayé.

Tu ne pousses aucun commit, tu ne corriges rien, tu n'ouvres aucune PR.
```

## 3. Bilan hebdomadaire

- **Déclencheur** : planification hebdomadaire, dimanche 9h07, Europe/Paris.
- **Modèle** : un modèle de la gamme Sonnet.
- **Notifications** : push activé, pour recevoir le bilan sur téléphone.

Prompt :

```text
Tu es l'agent de bilan d'Écluse. Lis CLAUDE.md et agent/QUEUE.md.
Ne modifie aucun fichier, ne pousse rien, n'ouvre aucune PR.

Rédige en français un bilan de la semaine écoulée, en moins de 25 lignes :
1. PR claude/* ouvertes, fusionnées et fermées depuis 7 jours
   (gh api 'repos/ecluse-dev/ecluse/pulls?state=all&per_page=50').
2. Tâches de agent/QUEUE.md bloquées, et pourquoi d'après leurs PR.
3. État de la CI sur main.
4. Prochaines tâches éligibles, et une proposition de réordonnancement
   seulement si une dépendance ou un blocage le justifie.
5. Rappel : vérifier la consommation dans Paramètres > Utilisation sur
   claude.ai (l'agent n'y a pas accès).

Termine par la liste des décisions attendues du mainteneur.
```
