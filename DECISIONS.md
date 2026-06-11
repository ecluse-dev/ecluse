# Journal des décisions

Trace écrite des choix structurants, pour ne pas re-débattre avec
soi-même et éclairer les contributeurs.

## 2026-06 — Dart d'abord, Rust plus tard
Vélocité solo > pureté d'architecture. Le cœur pourra migrer en Rust
derrière la même API quand le revenu justifiera la complexité.

## 2026-06 — Licence Apache 2.0
Permissive, patent grant rassurant pour les juristes d'entreprise,
compatible open-core. MIT écarté (pas de patent grant), AGPL écartée
(freine l'adoption B2B).

## 2026-06 — Détection stricte (clé validée ou rien)
Les détecteurs ne retournent que des entités structurellement validées.
Faux positifs ≈ 0 est l'argument du futur benchmark vs Presidio.
La confiance graduée existe dans l'API pour les détecteurs futurs
(NER local) qui ne pourront pas valider structurellement.

## 2026-06 — Zéro communication avant preuve
Pas d'annonce publique tant que le benchmark vs Presidio n'est pas
publiable. Premier post = chiffres en main.
