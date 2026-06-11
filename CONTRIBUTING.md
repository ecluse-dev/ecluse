# Contribuer à Écluse

Merci de votre intérêt ! Écluse est en construction publique et les
contributions sont bienvenues.

## Démarrage

```bash
git clone https://github.com/ecluse-dev/ecluse.git
cd ecluse
dart pub global activate melos
melos bootstrap
melos run test
```

## Règles

- Tout détecteur livré avec ses tests (cas valides, rejets, positions).
- `melos run format`, `melos run analyze` et `melos run test` doivent
  passer avant toute PR.
- Les détecteurs sont purs : pas de réseau, pas d'effet de bord.
- Jamais de données personnelles réelles dans les tests ou les fixtures —
  uniquement des valeurs synthétiques.

## Proposer un détecteur

Ouvrez d'abord une issue décrivant l'entité visée, sa structure officielle
(source réglementaire si possible) et sa règle de validation. On discute,
puis vous codez.
