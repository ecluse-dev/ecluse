# ecluse_redact

Pseudonymisation **réversible** pour [Écluse](https://github.com/ecluse-dev/ecluse) :
masque les entités personnelles d'un texte avant son envoi à un LLM, et
restaure les vraies valeurs dans la réponse — localement, sans que la
table de correspondance ne quitte jamais le processus.

## Usage

```dart
import 'package:ecluse_redact/ecluse_redact.dart';

void main() {
  final result = Ecluse.redact('M. Jean Dupont, né le 1 janvier 1980.');
  print(result.maskedText); // '[NOM_1], né le [DATE_NAISSANCE_1].'
  print(result.entities);   // entités détectées, type + confiance

  // ... envoi de result.maskedText à un LLM ...

  final finalText = Ecluse.restore(reponseDuLLM, result.mapping);
}
```

## Principe : aucun seuil de confiance ne filtre le masquage

`Ecluse.redact` masque **toute** entité détectée, quelle que soit sa
confiance — il n'y a pas de seuil filtrant dans cette version. En cas de
doute, on protège : un faux positif masqué dégrade un peu le texte envoyé
au LLM, mais un faux négatif non masqué est une fuite de donnée
personnelle. Un routage par seuil de confiance (ex. laisser passer en
clair les indices de faible confiance) est une décision produit qui
relève d'une phase ultérieure de la roadmap (routage on-device/cloud
selon la sensibilité), pas d'un comportement silencieux du moteur de
redaction.

## Détecteurs utilisés

Trois détecteurs à validation structurelle, réutilisés tels quels depuis
`ecluse_core` :

| Entité | Détecteur | Confiance |
|---|---|---|
| NIR | `NirDetector` | 1.0 |
| RPPS | `RppsDetector` | 0.9 |
| IBAN français | `IbanFrDetector` | 1.0 |

Cinq détecteurs **heuristiques de démonstration (v0)**, propres à ce
package :

| Entité | Détecteur | Méthode | Confiance |
|---|---|---|---|
| Nom de personne | `NameDetector` | civilité + mot capitalisé, ou prénom connu + mot capitalisé, ou prénom connu isolé | 0.9 / 0.6 / 0.5 |
| Date de naissance | `DateNaissanceDetector` | contexte (« né(e) le », « date de naissance », « DDN ») + date | 0.7 |
| Adresse postale | `AdresseDetector` | numéro + voie + code postal + commune | 0.7 |
| Téléphone FR | `TelephoneDetector` | motif `0X XX XX XX XX` ou `+33 X …` | 0.8 |
| Email | `EmailDetector` | motif standard `local@domaine.tld` | 0.85 |
| Établissement | `EtablissementDetector` | mot-clé du secteur médico-social (Foyer, Résidence, IME, ITEP, ESAT, EHPAD, MAS, FAM, Centre) + nom propre | 0.7 |

**⚠️ Ces six détecteurs sont une heuristique de démonstration, pas une
solution de production.** Contrairement aux détecteurs d'`ecluse_core`,
ils n'ont aucune clé de contrôle : ce sont des motifs textuels et une
liste de prénoms français courants (non exhaustive, voir
`lib/src/heuristics/french_first_names.dart`), pas une validation
structurelle. Ils seront remplacés en phase 2 par un modèle NER local
embarqué (voir `ROADMAP.md` à la racine du monorepo). Limite connue et
assumée dans cette version : deux mentions différentes de la même
personne (ex. « Mme Sophie Lambert » puis, plus loin, « Sophie ») ne
reçoivent pas le même jeton — seule une valeur textuelle strictement
identique garantit la cohérence du jeton. La résolution de coréférence
inter-mentions est un chantier de phase 2 (« pseudonymes cohérents »).

## Cohérence des jetons

Une même valeur détectée (chaîne strictement identique) reçoit toujours
le même jeton dans tout le texte, afin que le LLM garde le fil des
références. Le jeton est de la forme `[TYPE_N]` (`[NOM_1]`, `[NIR_1]`,
`[DATE_NAISSANCE_1]`, …), `N` étant l'ordre d'apparition dans le
document.

## Restauration tolérante mais jamais approximative

`Ecluse.restore` tolère une déformation raisonnable du jeton par le LLM
(espaces superflus, casse différente) mais ne devine jamais une
correspondance floue : un jeton trop modifié (ex. chiffre différent)
n'est pas restauré, et reste tel quel dans le texte final plutôt que de
risquer une substitution erronée.
