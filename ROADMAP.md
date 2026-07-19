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
- ⚪ Mode « aperçu + validation en un clic » : avant l'envoi à l'IA,
  l'utilisateur voit ce qui a été détecté et sera masqué (« 2 noms,
  1 NIR repérés »), et valide d'un clic. Traduit la vision « mesurer
  et informer, pas décider seul ». Rassure le soignant (contrôle
  humain, pas de boîte noire). À fournir comme composant que les
  apps clientes intègrent ; une interface Écluse autonome (ex.
  extension navigateur devant ChatGPT) relève de la phase 3.
- ⚪ Chatbot de support « propulsé par Écluse » (dogfooding = démo vivante)

- ⚪ Traitement d'images / OCR : détecter et protéger les données dans des
  photos et scans de documents (ordonnances, courriers, résultats de labo
  — le format réel du terrain soignant). FORTE utilité métier.
  MISES EN GARDE du Conseil :
  • L'OCR injecte des erreurs (O lu pour 0…) qui CASSENT la validation
    structurelle : un NIR mal lu échoue à sa clé de contrôle → rejeté
    comme invalide → fuite en clair. Notre meilleur atout se retourne
    contre nous sur le texte deviné.
  • Une image contient des données NON textuelles (signatures, tampons,
    logos identifiants, photos) qu'un pipeline OCR ne « lit » pas → fausse
    assurance. À traiter séparément.
  • Exige une vigilance redoublée sur la fuite résiduelle + un
    avertissement honnête (« le traitement d'image est moins fiable que
    le texte, vérifiez vous-même »).
  • NE PAS coder avant qu'un client le demande. Valider d'abord via les
    conversations de découverte (« texte tapé ou photos/scans ? »).

- ⚪ Dictée vocale 100 % locale : si Écluse intègre une saisie vocale, la
  transcription DOIT se faire sur l'appareil, AUCUN son ne part vers un
  serveur externe. Sinon, ne pas l'intégrer.
  • Ne PAS s'appuyer sur la dictée « système » (micro du clavier) : aucun
    contrôle, peut envoyer le son à Google/Apple. Écluse doit embarquer son
    PROPRE moteur de transcription local (ex. Whisper allégé on-device).
  • Argument de vente : « même votre voix ne quitte jamais l'appareil » —
    promesse que les concurrents génériques (texte only) ne font pas.
  • Coût assumé : modèle plus lourd, qualité parfois moindre = prix de la
    confidentialité, justifié ici. Phase 2/3, après validation client.
  • Principe gravé : « si dictée il y a un jour, elle sera locale, ou elle
    ne sera pas. »
  • Candidats techniques (à évaluer le moment venu) : whisper.cpp (Whisper
    en local, embarquable, bonne qualité, modèle plus lourd) ou Vosk
    (plus léger, pensé mobile/embarqué, bons modèles FR — a priori le
    plus adapté à l'ADN on-device mobile). NE PAS se fier à une app
    grand public en « on-device optionnel » : il faut une brique dont
    on maîtrise totalement le comportement (pas de fallback cloud caché).

## Phase 3 — Distribution et élargissement européen

Objectif : transformer les concurrents en canaux, étendre la douve.

- ⚪ Adaptateurs : recognizer Presidio-compatible, middleware LiteLLM, plugin Gravitee
- ⚪ Identifiants européens : NISS (BE), AVS (CH), Steuer-ID (DE)
- ⚪ SDK JS/TS
- ⚪ Offre cloud managée (dashboard d'audit, Stripe, SLA)
- ⚪ Vitrine grand public (extension navigateur gratuite devant ChatGPT) :
  alerte l'internaute qui s'apprête à envoyer des données sensibles
  (ex. résultats d'analyses médicales). Répond au problème réel de la
  pénurie de médecins — les gens exposent leurs données de santé aux
  IA. PRINCIPE : la protection de base est gratuite pour tous, jamais
  derrière un paywall (faire payer la sécurité = contresens éthique et
  commercial pour un produit de vie privée). Rôle = vitrine, preuve,
  communauté — PAS source de revenu (le B2C confidentialité ne paie
  quasi jamais). Le revenu vient des pros/éditeurs. Un éventuel palier
  payant particulier porterait sur le confort (historique, sync,
  modèle local), jamais sur la protection elle-même.

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
