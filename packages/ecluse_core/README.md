# ecluse_core

Détection d'entités personnelles françaises et européennes (PII) — le cœur
d'[Écluse](https://github.com/ecluse-dev/ecluse), le sas RGPD entre vos
prompts et les LLM.

**Garanties :** zéro dépendance réseau, zéro effet de bord, 100 % on-device.
Vos textes ne quittent jamais le processus.

## Usage

```dart
import 'package:ecluse_core/ecluse_core.dart';

void main() {
  const detector = NirDetector();
  final entities = detector.detect('Patient 1 85 05 78 006 084 91 admis.');
  for (final e in entities) {
    print('${e.type.name} trouvé en [${e.start}, ${e.end})');
  }
}
```

## Détecteurs disponibles

| Entité | Détecteur | Validation |
|---|---|---|
| NIR (n° de sécurité sociale) | `NirDetector` | Structure + clé de contrôle |

À venir : RPPS, FINESS, IBAN, téléphones FR, plaques d'immatriculation,
adresses.

## Philosophie de détection

Un détecteur Écluse ne se contente pas d'un motif : il **valide la
structure** (clé de contrôle, plages légales). Un faux positif anonymisé,
c'est un prompt dégradé pour rien ; un faux négatif, c'est une fuite. La
validation structurelle minimise les deux.
