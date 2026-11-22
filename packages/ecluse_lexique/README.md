# ecluse_lexique — lexique optionnel, sous LGPL-LR

**Ce dossier n'est pas sous Apache 2.0.** Il contient une ressource
linguistique dérivée de **Morphalou 3.1** (ATILF, CNRS - Université de Lorraine,
ORTOLANG, <https://hdl.handle.net/11403/morphalou/v3.1>), distribuée sous la
**LGPL-LR** (Lesser General Public License For Linguistic Resources), dont le
texte complet est dans [`LICENSE`](LICENSE).

| Fichier | Contenu | Modification |
|---|---|---|
| `assets/formes_verbales.txt.gz` | 511 245 formes fléchies des 14 760 verbes de Morphalou 3.1, une par ligne | extraction le 21 novembre 2026 par `tools/build_formes_verbales.py` (lemmes de catégorie « Verbe », locutions exclues) |

Pourquoi un dossier à part : la LGPL-LR s'applique à toute ressource dérivée
(section 2c), mais un programme qui lit la ressource sans en contenir de
partie reste hors de son champ (section 3). Le cœur d'Écluse et
`ecluse_redact` restent sous Apache 2.0 et fonctionnent sans ce lexique ;
l'application qui le charge doit le garder **remplaçable** par l'utilisateur
(section 4b), mentionner son usage et joindre la licence.

## Utilisation (P2-251)

```dart
import 'package:ecluse_lexique/ecluse_lexique.dart';
import 'package:ecluse_redact/ecluse_redact.dart';

final lexique = await FormesVerbales.charger('chemin/vers/formes_verbales.txt.gz');
final r = await Ecluse.redact(texte, formesVerbales: lexique.formes);
```

`ecluse_redact` ne dépend pas de ce paquet : il reçoit un `Set<String>` et
fonctionne sans (sortie octet pour octet identique). Un prénom suivi d'une forme
du lexique (« Sophie sollicite ») est masqué **seul** ; le verbe reste lisible.
Le fichier se remplace par un autre au même format (une forme par ligne,
minuscules, lignes `#` ignorées, gzip si le nom finit par `.gz`).

**Limite à lire avant d'activer** (`LIMITES.md`) : le lexique contient des formes
qui sont aussi des patronymes (« laurent », « roche », « martinez », « boucher »…).
Derrière un prénom, dans un texte sans majuscule ou en casse de phrase, ce nom
passe **en clair** (« rdv avec marc laurent »). Les corpus du dépôt n'en perdent
aucun, mais 5 583 patronymes du fichier de l'INSEE (4,5 % des naissances) sont
dans ce cas. L'option est désactivée par défaut.

Voir `agent/specs/P2-245.md` et `DECISIONS.md` (21 novembre).
