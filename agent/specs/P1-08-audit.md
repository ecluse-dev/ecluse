# P1-08 — `ecluse_audit` v0 : journal chaîné horodaté sans donnée personnelle

Type : `spec`. Aucun code de production, aucune dépendance ajoutée.

## 0. Contrainte structurante

L'exemption HDS repose sur le fait qu'Écluse **ne stocke rien**. Le journal
ne doit donc contenir **aucune donnée personnelle, aucune valeur détectée**,
et la bibliothèque **n'écrit elle-même nulle part** : elle fabrique des
entrées et sait les vérifier ; le stockage appartient à l'application cliente.

Rien ci-dessous n'est un avis juridique. L'affirmation « ce journal n'est pas
une donnée personnelle » est à faire valider par le mainteneur / un DPO
(voir §6, ré-identification par recoupement).

## 1. Format d'une entrée

JSON canonique (clés triées, sans espaces, UTF-8), un objet par entrée :

| Champ | Type | Contenu |
|---|---|---|
| `v` | entier | version du schéma de l'entrée (1) |
| `seq` | entier | numéro d'ordre, commence à 0, +1 à chaque entrée |
| `ts` | chaîne | horodatage UTC RFC 3339, à la seconde, **horloge de l'appareil** |
| `engine` | chaîne | version du moteur (ex. `ecluse_core 0.1.0`) et des détecteurs actifs (noms) |
| `op` | chaîne | `redact`, `ingest_refused`, ou autre opération fermée à l'énumération |
| `counts` | objet | nombre d'entités par type (`{"nir":2,"iban":1}`) — types de l'enum `EntityType`, comptes entiers |
| `reason` | chaîne | pour `ingest_refused` : **code** de motif (liste fermée : `pdf_image`, `encrypted`, `unsupported_format`…), pas le message libre |
| `digest` | chaîne | empreinte du texte d'entrée (voir §2) — **optionnel** |
| `prev` | chaîne | hash (hex) de l'entrée précédente ; chaîne de zéros pour `seq` 0 |
| `hash` | chaîne | SHA-256 (hex) de l'entrée canonique **sans** ce champ, concaténée à `prev` |

`hash = SHA-256( canonique(entrée sans hash) )`, où `prev` fait partie de
l'entrée canonique : modifier, supprimer ou réordonner une entrée casse la
chaîne à partir de ce point.

## 2. Le point délicat : l'empreinte du texte

Un hash simple (SHA-256) d'un texte court est **réversible par force
brute** quand le texte est devinable : un NIR seul compte 13 chiffres, un
« Dr Martin RPPS 1000… » reste largement contraint. Une empreinte non
protégée serait donc une donnée personnelle déguisée.

Options :

1. **Pas d'empreinte** (recommandé pour la v0) : le journal ne prouve que le
   *nombre* et la *nature* des opérations, pas leur contenu. Zéro risque.
2. **HMAC-SHA-256 avec une clé secrète détenue par l'application cliente**
   (jamais dans le journal) : l'application peut prouver « ce texte a bien
   été traité à cette date » sans que le journal permette de deviner le texte.
   Si la clé fuit, l'empreinte redevient forçable. Optionnel, à activer
   explicitement.
3. SHA-256 simple : **à écarter**.

## 3. Ce que le journal ne contient jamais

- le texte d'entrée, un extrait, un nom de fichier, un titre de document ;
- toute valeur détectée, tout jeton de substitution, toute correspondance
  valeur ↔ jeton (la carte de restauration reste en mémoire) ;
- les positions (`start`/`end`) et longueurs des entités : elles révèlent la
  structure du texte (ordre, taille d'un nom) ;
- un hash simple ou un hash par entité (forçable) ;
- l'identité de l'utilisateur, un identifiant de patient, une adresse IP, un
  identifiant d'appareil ;
- le message libre d'un refus (il peut citer du contenu) — seulement un code.

## 4. Stockage et API (esquisse, pas de code)

- `AuditEntry` : objet immuable sérialisable ; `AuditChain.next(...)` produit
  l'entrée suivante à partir de la dernière (`seq`, `prev`) que l'application
  lui fournit. La bibliothèque **ne garde pas d'état persistant**.
- `AuditSink` : interface à implémenter par l'application (fichier append-only,
  base, etc.). Écluse peut fournir une implémentation **en mémoire** pour les
  tests ; aucune implémentation fichier par défaut (ce serait du stockage).
- `AuditVerifier.verify(Iterable<AuditEntry>)` : recalcule la chaîne et
  renvoie soit « intègre jusqu'à `seq` N », soit la **première rupture**
  (`seq`, nature : hash invalide, `prev` incohérent, `seq` non consécutif).

## 5. Garanties — et leurs limites

Détecté par la vérification : modification d'une entrée, suppression ou
insertion au milieu, réordonnancement.

**Non détecté** :

- la **troncature en fin de journal** (suppression des dernières entrées) :
  la chaîne reste valide. Parade : l'application **ancre** régulièrement le
  dernier `hash` hors du journal (ticket, e-mail, autre système) ;
- la **réécriture complète** par quelqu'un qui contrôle tout le fichier et
  recalcule la chaîne : un hash chaîné n'est pas une signature. Parade
  future : signature (clé détenue par l'application) ou ancrage externe ;
- la **justesse de l'horloge** : `ts` vient de l'appareil. « Horodaté » ne
  signifie pas ici « horodatage qualifié » (RFC 3161 / eIDAS). À écrire
  explicitement dans `LIMITES.md` pour ne pas survendre.

## 6. Risques

1. **Ré-identification par recoupement** : un `ts` à la seconde + des
   `counts` rapprochés des journaux d'une application (qui a ouvert quel
   dossier à cette seconde) peuvent relier une entrée à une personne. Parade
   : horodatage à la minute (option), pas d'identifiant utilisateur dans le
   journal, avis du DPO.
2. **Les comptes révèlent la nature du document** (un document avec 2 NIR et
   1 IBAN est un dossier paie) : jugé acceptable, à valider.
3. **Dépendance cryptographique** : SHA-256 / HMAC demandent un paquet (par
   exemple `package:crypto`, paquet officiel de l'équipe Dart, licence BSD-3
   **[à confirmer]**) car `ecluse_core` n'en a pas. **Ajout interdit sans
   accord explicite** ; ce document ne l'ajoute pas. Alternative : écrire un
   SHA-256 maison — déconseillé (risque d'erreur).
4. **Canonicalisation** : un JSON canonique mal défini casse la
   vérification entre versions ; figer la règle (clés triées, entiers sans
   zéros inutiles, pas de flottants) et tester avec des vecteurs.
5. **Faux sentiment de preuve** : le journal prouve la cohérence interne, pas
   la vérité des événements.

## 7. Plan de tests (futur ticket `code`)

- Vecteurs fixes : entrées d'exemple → `hash` attendus (reproductible, sans
  horloge : `ts` injecté).
- Chaîne intègre de N entrées vérifiée ; modification d'un champ, suppression,
  insertion, réordonnancement → rupture détectée à la bonne `seq`.
- Troncature de fin **non** détectée : test qui l'affirme (pour ne pas laisser
  croire le contraire).
- Test de non-fuite : générer des entrées pour des textes contenant des
  NIR/RPPS/IBAN **fabriqués** ; sérialiser le journal ; vérifier qu'aucune
  valeur, aucun fragment, aucune position n'y figure.
- Aucune dépendance au réseau ni à l'heure réelle.

## 8. Décisions demandées au mainteneur

1. Empreinte du texte : aucune (recommandé), HMAC optionnel, ou abandon.
2. Autoriser une dépendance de hachage (`package:crypto` ?) pour un nouveau
   paquet `ecluse_audit`.
3. Granularité de l'horodatage (seconde ou minute).
4. Politique d'ancrage de la tête de chaîne et de signature (v1 ?).
5. Valider avec un DPO que le journal n'est pas une donnée personnelle.
