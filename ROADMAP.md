# Roadmap Écluse

Écluse vise un coin de marché que personne n'occupe : **open source ET
spécialisé français/européen ET mobile/on-device ET audit AIPD**. Les
gateways génériques (Presidio, Grepture, LLM Guard) couvrent la largeur ;
Écluse couvre la profondeur réglementaire locale. Chaque jalon ci-dessous
pousse dans cette direction plutôt que vers la généralité.

Statut : 🟢 fait · 🟡 en cours · ⚪ à venir

---

## Phase 1 — Le sas minimal vendable

Objectif : qu'un premier design partner l'utilise en production.

- 🟢 Détecteurs à validation structurelle : NIR, RPPS, IBAN FR
- 🟢 Résolveur de chevauchements (`resolveOverlaps`)
- 🟢 Harnais de benchmark reproductible vs Presidio
- ⚪ `ecluse_redact` — pseudonymisation réversible, map chiffrée côté client
- ⚪ `ecluse_audit` — journal chaîné horodaté (version minimale)
- ⚪ Détecteurs prioritaires : FINESS, ADELI, téléphone FR, email
- ⚪ Secret scanning (clés API, tokens) — parité avec les gateways génériques
- ⚪ Publication de l'article de benchmark

## Phase 2 — La profondeur qui rend seul

Objectif : occuper le coin vide de la carte.

- ⚪ Export AIPD aux normes CNIL (registre de traitement pré-rempli)
- ⚪ NER local embarqué (GLiNER/ONNX) pour noms et adresses — confiance graduée
- ⚪ Généralisation géographique : remplacer un lieu trop précis par une
  zone large (ville → région → Nord/Sud/Est/Ouest) pour réduire la
  ré-identification par recoupement. Mode irréversible, distinct de la
  pseudonymisation. S'appuie sur le NER + table INSEE commune/région.
- ⚪ Score de ré-identification du texte : indice de risque (élevé/moyen/
  faible) calculé sur l'ensemble du texte, même sans identifiant direct
  (logique k-anonymat rendue visible). Aide à la décision pour le DPO.
- ⚪ Pseudonymes cohérents et cloisonnés : même entité → même jeton au sein
  d'un dossier (le LLM garde le fil), jeton différent d'un dossier à l'autre
  (aucun recoupement possible entre dossiers).
- ⚪ Généralisation multi-dimensions : étendre le principe géographique aux
  autres indices (date de naissance → tranche d'âge, âge exact → palier,
  pathologie rare → catégorie). Bibliothèque de généralisation française.
- ⚪ Routage on-device / cloud selon la sensibilité
- ⚪ SDK Python (là où sont les devs IA)
- ⚪ Chatbot de support « propulsé par Écluse » (dogfooding = démo vivante)

## Phase 3 — Distribution et élargissement européen

Objectif : transformer les concurrents en canaux, étendre la douve.

- ⚪ Adaptateurs : recognizer Presidio-compatible, middleware LiteLLM, plugin Gravitee
- ⚪ Identifiants européens : NISS (BE), AVS (CH), Steuer-ID (DE)
- ⚪ SDK JS/TS
- ⚪ Offre cloud managée (dashboard d'audit, Stripe, SLA)

---

## Principes directeurs

- **Profondeur locale, pas largeur générique.** Ne pas devenir « une
  gateway PII de plus ». Chaque entité FR/EU validée structurellement
  creuse l'écart.
- **Le benchmark public grandit avec le produit.** Actif marketing
  permanent ; à chaque entité ajoutée, réétendre la comparaison.
- **Les design partners guident les priorités.** Un client qui paie
  réordonne cette liste mieux que la liste elle-même.
- **Deux modes, pas un.** *Pseudonymiser* (réversible, pour les
  identifiants : on restaure la valeur dans la réponse) et
  *généraliser* (irréversible, pour les indices contextuels comme un
  lieu : on réduit volontairement le pouvoir d'identification).
  Raisonner sur le faisceau d'indices, pas seulement sur les entités
  isolées — c'est ce que les gateways génériques ne font pas.
- **Ship avant d'annoncer.** Du concret vérifiable avant toute
  communication.

Cette roadmap est indicative et évoluera. Contributions et retours
bienvenus via les issues.
