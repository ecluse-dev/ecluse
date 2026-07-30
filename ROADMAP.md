# Roadmap Écluse

Écluse vise un coin de marché que personne n'occupe : **open source ET
spécialisé français/européen ET mobile/on-device ET audit AIPD**. Les
gateways génériques (Presidio, Grepture, LLM Guard) couvrent la largeur ;
Écluse couvre la profondeur réglementaire locale. Chaque jalon ci-dessous
pousse dans cette direction plutôt que vers la généralité.

Statut : 🟢 fait · 🟡 en cours · ⚪ à venir

---

## Périmètre d'entrée — arbitrage de juillet 2026

Décision structurante, posée avant les phases : **quels formats Écluse
accepte-t-il en entrée ?** Elle conditionne ce qui est développable et ce
qui ne le sera pas.

### HORS PÉRIMÈTRE : image et manuscrit

Photos, scans, PDF-image, écriture manuscrite : **non traités**.

- **Raison technique.** OCR et HTR (reconnaissance de manuscrit) injectent
  des erreurs de lecture. Un NIR mal lu échoue à sa clé mod 97 → il est
  rejeté comme invalide → **il fuit en clair**. La validation structurelle,
  meilleur atout d'Écluse, se retourne en mécanisme de fuite silencieuse
  dès qu'elle s'applique à du texte deviné. Un modèle de vision lit mieux
  le manuscrit qu'un OCR classique, mais il hallucine des chiffres
  plausibles : même fuite, moins détectable.
- **Raison produit.** Une image contient des éléments identifiants **non
  textuels** — signature, tampon, en-tête, logo d'établissement, visage —
  qu'aucun pipeline OCR ne « lit ». Couvrir l'image sans les traiter
  produit un faux sentiment de sécurité, la faille n°1 de
  `NOTES_SECURITE.md`.
- **Raison prospection.** Besoin non validé : 1 confirmation (#1), 1 « je
  ne sais pas » (#2). Et aucun des deux chantiers concrets nommés par #2
  — retranscription de réunions, contrats RH — n'est manuscrit.
- **Posture assumée**, à écrire dans la doc publique : « Écluse ne traite
  ni le manuscrit ni l'image. » Annoncer une couverture qui rate un
  identifiant sur cinq est pire que ne rien annoncer.

### DANS LE PÉRIMÈTRE

**1. Fichiers texte natifs** — PDF texte, docx, odt, txt, markdown.

Extraction avec offsets fiables, aucune erreur d'entrée, pipeline existant
applicable tel quel. C'est du travail d'intégration, pas de recherche.

> ⚠️ **Garde-fou obligatoire** : détecter le PDF-image (couche texte vide
> ou quasi vide) et **refuser explicitement le document**. Ne jamais rendre
> un « rien à masquer » sur un fichier non lu — c'est la forme la plus
> vicieuse de la faille n°1.

**2. Vocal**, sous condition non négociable : **transcription 100 % locale**.

- Aucun son ne part vers un serveur externe. Sinon, pas de vocal du tout.
- La dictée « système » (bouton micro du clavier) est **exclue** : aucune
  maîtrise du comportement, le son peut partir chez Google/Apple. Écluse
  doit embarquer son propre moteur.
- Candidats techniques, à évaluer le moment venu : **Vosk** (léger, pensé
  mobile/embarqué, bons modèles FR — a priori le plus proche de l'ADN
  on-device) ou **whisper.cpp** (meilleure qualité, modèle plus lourd).
  Ne pas se fier à une app grand public en « on-device optionnel » : il
  faut une brique sans fallback cloud caché.
- **Limite honnête à documenter** : la transcription introduit des erreurs
  sur les chiffres, comme l'OCR. Les noms et le contexte survivent mieux
  que les identifiants numériques. À signaler à l'utilisateur, pas à
  masquer sous une promesse lisse.
- Argument de vente que les concurrents génériques (texte only) ne font
  pas : « même votre voix ne quitte jamais l'appareil ».
- Coût assumé : modèle plus lourd, qualité parfois moindre = prix de la
  confidentialité, justifié ici.

**Principe gravé** : « si dictée il y a un jour, elle sera locale, ou elle
ne sera pas. »

---

## Phase 1 — Le sas minimal vendable

Objectif : qu'un premier design partner l'utilise en production.

- 🟢 Détecteurs à validation structurelle : NIR, RPPS, IBAN FR
- 🟢 Résolveur de chevauchements (`resolveOverlaps`)
- 🟢 Normalisation avant détection (`digit_compaction`) — espacements
  irréguliers, NBSP, tabulations
- 🟢 Harnais de benchmark reproductible vs Presidio
- 🟢 `ecluse_redact` — pseudonymisation réversible, map jamais sérialisée
- 🟢 `ecluse_demo` — trajet complet en 4 panneaux, réversibilité prouvée
- ⚪ `ecluse_audit` — journal chaîné horodaté (version minimale)
- ⚪ Détecteurs prioritaires : FINESS, ADELI, téléphone FR, email
  (heuristiques v0 en place, à durcir)
- ⚪ Secret scanning (clés API, tokens) — parité avec les gateways génériques
- ⚪ Publication de l'article de benchmark
- ⚪ **Import de fichiers texte natifs** (PDF texte, docx) + garde-fou
  PDF-image. Seule exception discutable à la règle « rien avant un signal
  de paiement » : quelques jours de travail, aucune recherche, et rend la
  démo de rentrée nettement plus concrète — « déposez votre compte rendu,
  regardez ce qui ressort ».

## Phase 2 — La profondeur qui rend seul

Objectif : occuper le coin vide de la carte.

- ⚪ Export AIPD aux normes CNIL (registre de traitement pré-rempli)
- ⚪ NER local embarqué (GLiNER/ONNX) pour noms et adresses — confiance
  graduée. Remplace les détecteurs heuristiques v0 de `ecluse_redact`.
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
- ⚪ **Transcription vocale locale** (Vosk ou whisper.cpp embarqué) — voir
  les conditions non négociables du périmètre d'entrée ci-dessus. Débloque
  le cas d'usage n°1 identifié en entretien : la retranscription de
  réunions, y compris CA et CSE.
- ⚪ Mode « aperçu + validation en un clic » : avant l'envoi à l'IA,
  l'utilisateur voit ce qui a été détecté et sera masqué (« 2 noms,
  1 NIR repérés »), et valide d'un clic.
  **⚠️ C'est une OPTION de confort, PAS le mode par défaut** (arbitrage
  issu de l'entretien #2 : « il faut que ce soit embarqué, que ce soit
  transparent… on ne se pose pas de questions, et go »). Le défaut est
  invisible et automatique. À fournir comme composant que les apps
  clientes intègrent ; une interface Écluse autonome relève de la phase 3.
- ⚪ Chatbot de support « propulsé par Écluse » (dogfooding = démo vivante)

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
- **Un périmètre refusé est un périmètre tenu.** Mieux vaut annoncer que
  l'image et le manuscrit ne sont pas traités que de les couvrir mal.
  L'honnêteté sur les limites est une mesure de sécurité, pas une posture.
- **Le mode par défaut est invisible et automatique.** Embarqué,
  transparent, zéro frottement. Toute étape de validation humaine est une
  option, jamais le chemin nominal.
- **Réversibilité en première phrase.** Écluse *pseudonymise* et restaure
  localement ; il ne détruit pas. Le malentendu « anonymisation
  destructive » est le premier à lever dans tout pitch.
- **Le benchmark public grandit avec le produit.** Actif marketing
  permanent ; à chaque entité ajoutée, réétendre la comparaison. Chaque
  format dégradé rencontré rejoint le corpus.
- **Les design partners guident les priorités.** Un client qui paie
  réordonne cette liste mieux que la liste elle-même. Rien d'avancé ne se
  code avant un signal de paiement.
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
