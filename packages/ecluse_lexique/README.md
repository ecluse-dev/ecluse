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

Le code Dart du paquet (chargement, injection dans le détecteur de noms) est la
tâche P2-251 ; voir `agent/specs/P2-245.md` et `DECISIONS.md` (21 novembre).
