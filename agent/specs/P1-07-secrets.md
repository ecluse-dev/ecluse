# P1-07 — Secret scanning (clés d'API, jetons, clés privées)

Type : `spec`. Aucun code de production. Aucun secret réel, même en exemple.

## 0. Niveau de vérification

- Les **formes** de secrets viennent de deux sources : la configuration de
  règles du projet *gitleaks* (lue le 25 oct. 2026 sur
  <https://raw.githubusercontent.com/gitleaks/gitleaks/master/config/gitleaks.toml>,
  via un résumé automatique ; **licence non confirmée sur cette page**) et la
  connaissance générale de l'auteur de la spec (marquée **[à confirmer]**).
- La documentation de GitHub (`docs.github.com`) était **inaccessible** depuis
  l'environnement : les préfixes de jetons GitHub sont donc confirmés
  uniquement par les règles gitleaks, pas par la source officielle.
- Rien n'a été exécuté. Les motifs ci-dessous sont des **descriptions de
  structure**, pas du code ; en écrire nos propres expressions régulières
  (ne pas recopier celles de gitleaks avant d'avoir vérifié leur licence).

## 1. Pourquoi c'est dans le périmètre d'Écluse

Écluse retient localement « ce qui identifie une personne ». Un secret n'est
pas une donnée personnelle, mais le cas d'usage est le même : un texte
collé dans un LLM tiers (code, journal, fichier de configuration) contient
parfois une clé qui donne accès à un système. L'envoyer est une fuite
irréversible (la clé est à révoquer). Les utilisateurs d'un sas de
pseudonymisation s'attendent à ce que ça le couvre ; sinon, c'est un
faux sentiment de sécurité de plus. **Décision à valider** : accepter cette
extension de périmètre (voir `ROADMAP.md`, phase 2).

## 2. Formats à couvrir en priorité

| Format | Structure (d'après gitleaks sauf mention) | Faux positifs |
|---|---|---|
| Clé privée PEM | `-----BEGIN … PRIVATE KEY-----` jusqu'à `-----END … PRIVATE KEY-----`, bloc multi-ligne (≥ 64 caractères entre les deux) | Très faibles. Cas : bloc coupé, ou `\n` littéraux dans du JSON |
| Jeton GitHub classique | préfixe `ghp_` + 36 alphanumériques ; autres préfixes `gho_`, `ghu_`, `ghs_`, `ghr_` **[à confirmer, docs GitHub inaccessibles]** | Très faibles (préfixe + longueur fixe) |
| Jeton GitHub à granularité fine | `github_pat_` + 82 caractères `\w` | Très faibles |
| Clé d'accès AWS (identifiant) | préfixes `AKIA`, `ASIA`, `ABIA`, `ACCA`, `A3T?` + 16 caractères `[A-Z2-7]` | Faibles. **La clé secrète AWS (40 caractères base64) n'a aucun préfixe : exclue de la v1** (risque de FP élevé), sauf avec mot-clé de contexte (`aws_secret_access_key`) |
| Clé d'API Google | `AIza` + 35 caractères `[\w-]` | Faibles |
| Clé Stripe | `sk_`/`rk_` + `test`/`live`/`prod` + `_` + 10 à 99 alphanumériques | Faibles |
| Jeton Slack (bot) | `xoxb-` + deux nombres + suffixe alphanumérique | Faibles |
| Clé Anthropic | `sk-ant-api03-` + 93 caractères `[A-Za-z0-9_-]` + `AA` | Faibles |
| Clé OpenAI | `sk-` (+ `proj`/`svcacct`/`admin`) + segments longs encadrant le marqueur fixe `T3BlbkFJ` | Faibles. **Le format évolue ; à re-vérifier avant chaque version** |
| JWT | trois segments base64url séparés par des points, les deux premiers commençant par `ey` | Moyens : un JWT expiré ou de test n'est pas un secret actif, mais on masque quand même |
| Chaîne de connexion avec identifiants | `scheme://utilisateur:motdepasse@hôte` (`postgres`, `postgresql`, `mysql`, `mongodb`, `mongodb+srv`, `redis`, `amqp`, `https`) **[à confirmer]** | Moyens : `https://user@host` sans mot de passe ne doit pas être masqué ; exiger `:` et un mot de passe non vide |
| En-tête `Authorization: Bearer …` | mot-clé + jeton ≥ 20 caractères | Moyens ; v2 |

Les noms de fournisseurs sont des exemples tirés de gitleaks ; la liste
exacte « principaux fournisseurs de LLM et de cloud » est une décision du
mainteneur.

**Hors v1 volontairement** : détection par entropie (« toute chaîne
aléatoire longue ») — taux de faux positifs trop élevé (identifiants de
commit, hachages, UUID) et pas de justification possible à l'utilisateur.

## 3. Proposition d'intégration

### Type d'entité

Ajouter `EntityType.secret` (un seul type en v1). Le sous-type (GitHub, AWS…)
n'est pas utile à l'utilisateur et alourdirait `DetectedEntity` ; il peut
vivre dans le nom du détecteur pour l'audit. Alternative envisagée : un type
par fournisseur — écartée (explosion de l'enum pour aucun gain de masquage).

### Place dans `EcluseEngine`

Un nouveau `Detector` (par exemple `SecretDetector`) dans la liste
`defaultDetectors`, tier **`pattern`** (format fixe, mais **aucune clé de
contrôle vérifiée** par nous ; ne pas le classer `structural`).
Confiance proposée : 0,95 pour préfixe + longueur exacts ; 1,0 pour un bloc
PEM complet ; 0,7 pour JWT et chaîne de connexion.

Pas de conflit attendu avec NIR/RPPS/IBAN. Un secret ne contient pas d'espaces
à neutraliser : **ne pas** le faire passer par `DigitCompaction`.

### Comportement attendu

| Option | Avantage | Risque |
|---|---|---|
| **Masquer** (par défaut proposé) | Cohérent avec le reste d'Écluse ; le texte reste utilisable | Un secret mal reconnu (§5) passe quand même |
| **Refuser l'envoi** si un secret est détecté | Évite toute fuite d'un secret reconnu | Bloque l'usage ; frustrant si le secret n'est qu'un exemple de documentation |
| Les deux (mode strict, activable) | Choix à l'application cliente | Complexité d'API |

Recommandation : **masquer par défaut**, avec un **avertissement visible**
(« un secret a été masqué : pensez à le révoquer »), et un **mode strict
optionnel** qui refuse. Le remplacement est un jeton de substitution
`[SECRET_n]` ; **ne jamais restaurer un secret dans la réponse affichée sans
décision explicite** (il pourrait finir copié dans un autre outil) :
restauration désactivée par défaut pour ce type. À valider.

### Spans

- PEM : tout le bloc, `BEGIN` à `END`, y compris sauts de ligne.
- Chaîne de connexion : à décider entre masquer le seul mot de passe (le
  reste, nom d'hôte, aide à comprendre la question) ou l'URL entière
  (plus sûr : le nom d'utilisateur et l'hôte sont aussi sensibles). Proposé :
  **userinfo complet** (`utilisateur:motdepasse`).
- Jetons : la valeur seule, sans guillemets ni point-virgule.

## 4. Tests (futur ticket `code`)

**Règle essentielle :** les valeurs de test sont des **chaînes fabriquées à
l'exécution** (préfixe + caractères tirés d'une graine fixe), jamais un
secret réel, et **jamais écrites sous une forme qui déclencherait la
détection de secrets de GitHub ou d'un hook de pré-commit** : construire la
chaîne par concaténation (`'ghp_' + 'x' * 36` n'est pas assez réaliste pour
tromper un scanner mais suffit au motif ; vérifier que la poussée n'est pas
bloquée). Pour chaque format : détection avec offsets exacts, rejet d'une
valeur trop courte ou à mauvais préfixe, absence de faux positif sur le
corpus du benchmark (`bench/corpus.jsonl`, objectif : 0 détection `secret`),
et sur du texte courant (hachages Git de 40 caractères, UUID, base64 de
données).

## 5. Limites à écrire dans `LIMITES.md`

- Un secret **sans forme reconnaissable** (mot de passe choisi par un
  humain, clé AWS secrète seule, jeton propriétaire) n'est **pas** détecté.
- Un PEM coupé ou dont les sauts de ligne sont remplacés par `\n` littéraux
  peut échapper au motif (à traiter explicitement).
- Les formats évoluent (OpenAI, GitHub) : la liste exige un entretien.
- Masquer ne rend pas un secret déjà envoyé ailleurs inoffensif.

## 6. Mesure avant de coder

Règle n°5 : étendre le générateur de corpus avec des secrets fabriqués et des
pièges (hachages, UUID, `https://user@host`, PEM tronqué), puis mesurer
précision/rappel par format **avant** le détecteur, et non-régression des
scores NIR/RPPS/IBAN/FINESS (aucune baisse).

## 7. Décisions demandées au mainteneur

1. Accepter l'extension de périmètre aux secrets.
2. Valider `EntityType.secret` et le tier `pattern`.
3. Choisir : masquer seul, refuser, ou masquer + mode strict (recommandé).
4. Restauration des secrets désactivée par défaut ?
5. Liste finale des fournisseurs de la v1 et licence de la source de motifs
   (gitleaks) avant toute réutilisation.
