# File de travail des agents — Écluse

Fichier tenu par le mainteneur. Un agent ne modifie que la colonne
**Statut** de la tâche qu'il traite (règles complètes dans `CLAUDE.md`).

**Statuts** : `à faire` · `PR ouverte` · `fusionnée` · `bloquée` · `humain`
(réservée au mainteneur, un agent ne la prend jamais).

**Types** : `code` (implémentation + tests) · `spec` (conception seule,
dans `agent/specs/<id>.md`, aucun code de production) · `mesure` (exécuter
et rapporter, ne rien corriger).

L'ordre des lignes est l'ordre de priorité. L'agent prend la première
tâche `à faire` dont toutes les dépendances sont `fusionnée`.

## Phase 1 — Le sas minimal vendable

| Id | Type | Tâche | Dépend de | Statut |
|---|---|---|---|---|
| P1-00 | humain | Pousser les tests produits par l'essai d'agent du 10 août (branche locale `test-prime-agent`) | — | humain |
| P1-01 | mesure | Rejouer Presidio sur le corpus v3 et mettre à jour le tableau du benchmark | — | fusionnée |
| P1-02 | code | RPPS : couvrir les variantes de séparateurs (NBSP, espace fine, tabulation, espaces multiples, points, tirets) | — | fusionnée |
| P1-03 | mesure | FINESS : analyser les faux positifs (collision SIREN) et proposer des pistes chiffrées | P1-01 | fusionnée |
| P1-04 | code | Téléphone FR : durcir l'heuristique (formats +33, 0033, séparateurs) | — | fusionnée |
| P1-05 | code | Email : durcir l'heuristique (obfuscations courantes, bornes de span) | — | fusionnée |
| P1-06 | spec | Détecteur ADELI : structure officielle, validation possible, risque de faux positifs | — | fusionnée |
| P1-07 | spec | Secret scanning (clés d'API, jetons) : périmètre, motifs, place dans le pipeline | — | fusionnée |
| P1-08 | spec | `ecluse_audit` v0 : journal chaîné horodaté sans donnée personnelle | — | fusionnée |
| P1-09 | spec | Ingestion PDF texte + garde-fou PDF-image : choix de la bibliothèque, critères de refus | — | fusionnée |
| P1-10 | humain | Valider les specs P1-06 à P1-09 et créer les tâches `code` correspondantes | P1-06, P1-07, P1-08, P1-09 | fusionnée |
| P1-11 | code | Brouillon d'article de benchmark (`bench/ARTICLE.md`) à partir des résultats à jour | P1-01, P1-03 | fusionnée |
| P1-12 | humain | Relire et publier l'article de benchmark | P1-11 | à faire |
| P1-13 | code | Corpus : SIREN sans mot-clé, phrases FINESS + SIREN, ADELI avec/sans mot-clé (nouvelle version du générateur) | P1-03 | fusionnée |
| P1-14 | code | Détecteur ADELI contextuel + `EntityType.adeli` + priorité sur `finess` | P1-13 | fusionnée |
| P1-15 | code | Détecteur de secrets (`EntityType.secret`) | P1-13 | fusionnée |
| P1-16 | code | `ecluse_audit` v0 (entrée, chaîne, vérificateur, sink en mémoire) | P1-08 | fusionnée |
| P1-17 | code | Ingestion PDF : `PdfTextSource`, garde-fou et refus | P1-18 | fusionnée |
| P1-18 | code | Générateur de PDF synthétiques pour calibrer les seuils | P1-09 | fusionnée |
| P1-19 | code | Core : un identifiant suivi d'un nombre (`NIR … 91 12 ans`, `RPPS … 12`) n'est plus détecté (fuite) | — | fusionnée |
| P1-20 | code | Redact : une adresse, un nom ou un établissement en chevauchement partiel écrase l'entité voisine (email cassé, nom en clair) | — | fusionnée |
| P1-21 | code | Redact : collision avec des jetons littéraux du texte (`[NOM_1]`) | — | fusionnée |
| P1-22 | code | Ingest : contenus non lus en silence (préfixe XML autre que `w:`, en-têtes/pieds, UTF-16 sans BOM, exceptions non rattrapées) | — | fusionnée |
| P1-23 | code | Robustesse : ReDoS email et adresse ; démo (taille de corps, JSON non-objet, `Host`/`Origin`, masquage de la consigne) | — | fusionnée |
| P1-24 | code | Redact : noms (prénoms accentués, particules, `Mr`, `Maître`, apostrophe typographique) | — | fusionnée |
| P1-25 | code | Redact : variantes de dates, établissements, adresses et téléphones non détectées | — | fusionnée |
| P1-26 | code | Redact : fusion de deux personnes de même patronyme à la restauration ; carte vs `LIMITES.md` §5.3 | — | fusionnée |
| P1-27 | code | Reid/reference : paliers d'âge, population des départements, normalisation œ, homonymes, validations | — | fusionnée |
| P1-28 | code | Bench : `score.py` (types inconnus, mode souple), `ecluse_sim.py`, README, test d'équivalence | — | fusionnée |
| P1-29 | code | Docs : `LIMITES.md`, `ROADMAP.md`, README du benchmark, `NOTES_SECURITE.md` manquant | — | fusionnée |
| P1-30 | code | Core : NIR à mois fictifs, séparateurs U+2009 et `/`, saut de ligne dans un identifiant groupé | — | fusionnée |
| P1-31 | code | Reid : un nom de commune ambigu (homonymes) est signalé, jamais « faible » | — | fusionnée |
| P1-32 | code | Core : NIR à mois `00` et `21-29` (test d'abord, clé mod 97 exigée) | — | fusionnée |
| P1-33 | code | `DATA_SOURCES.md` : URL, date et licence (lue sur la page) de chaque jeu de données embarqué | — | fusionnée |
| P1-34 | code | README du benchmark : résultats des entités floues dans un tableau séparé | — | fusionnée |
| P1-35 | mesure | Presidio avec reconnaisseurs NIR/RPPS écrits à la main (objection prévisible à l'article) | P1-01 | fusionnée |
| P1-36 | mesure | Rejouer les chiffres Écluse de l'article ([C2], [C5]) avec les détecteurs actuels | — | fusionnée |
| P1-37 | code | `bench/ARTICLE.md` [C5] : écrire `\u00a0` au lieu d'une espace insécable littérale | P1-36 | fusionnée |

## Phase 2 — La profondeur qui rend seul

Découpage proposé dans `agent/specs/P2-decoupage-propose.md` ; seules les
tâches copiées ici sont prises par l'agent.

| Id | Type | Tâche | Dépend de | Statut |
|---|---|---|---|---|
| P2-01 | spec | Critère GO/STOP du NER local (métriques, corpus de décision, plafonds, conditions d'arrêt) | — | fusionnée |
| P2-02 | mesure | Référence chiffrée des heuristiques de noms et d'adresses sur les corpus flous (valeur à battre pour le GO/STOP du NER) | P2-01 | fusionnée |
| P2-03 | spec | Branchement de `ecluse_reid` dans `Ecluse.redact` : contrat public, généralisation irréversible distincte de la pseudonymisation, refus explicites | — | fusionnée |
| P2-03a | code | Profil de corpus de quasi-identifiants annotés (profession, lieu, âge) et son scoreur, dans `bench/` | P2-03 | fusionnée |
| P2-03b | code | `ecluse_reid` : extraction des QI avec positions et estimation totale (résultat typé, sans exception), en ajout et sans changer `estimate` | P2-03a | fusionnée |
| P2-04 | code | Branchement de `ecluse_reid` dans `Ecluse.redact` selon l'option retenue dans la spec P2-03 (test d'équivalence d'abord, mesure avant/après) | P2-03, P2-03a, P2-03b | fusionnée |
| P2-05 | spec | Pseudonymes cohérents entre les documents d'un dossier et cloisonnés entre dossiers : définition du dossier, état en mémoire, menace du recoupement | — | fusionnée |
| P2-05a | code | Profil de corpus multi-documents (dossiers, personnes, identités) et son scoreur, avec la mesure de l'état actuel sans dossier | P2-05 | fusionnée |
| P2-06 | code | État de dossier en mémoire dans `ecluse_redact` : pseudonymes cohérents entre les documents d'un dossier et cloisonnés entre dossiers, selon les décisions de la spec P2-05 (test d'équivalence d'abord, mesure avant/après) | P2-05, P2-05a | fusionnée |
| P2-07 | spec | Généralisation multi-dimensions (date de naissance vers tranche d'âge, âge vers palier, pathologie rare vers catégorie) : dimensions, table de catégories, honnêteté sur ce qui reste ré-identifiable | P2-03 | fusionnée |
| P2-08 | spec | Aperçu avec validation en un clic, option et non défaut (entretien #2) : contrat du composant, sans interface autonome | — | fusionnée |
| P2-09 | spec | Export AIPD : champs du registre pré-rempli, données d'`ecluse_audit` qui y entrent et qui n'y entrent pas | — | fusionnée |
| P2-10 | spec | Transcription vocale locale : choix Vosk ou whisper.cpp, preuve qu'aucun son ne sort de l'appareil, limite sur les chiffres, critère GO/STOP propre | — | fusionnée |
| P2-11 | code | `ecluse_bench` : retirer `pubspec_overrides.yaml` (chemin Windows) du suivi git | — | fusionnée |
| P2-12 | code | Script reproductible du décompte de la fuite des noms hors civilité, versionné dans `bench/` | P2-02 | fusionnée |
| P2-13 | code | `Dossier` : règle de noms entre documents activable (N3) : N1 par défaut, fusion par inclusion (N2) à la demande de l'application | P2-06 | fusionnée |
| P2-14 | code | Patronyme seul : mesurer ce qu'un rattrapage sans liste externe ni NER peut détecter, et ne l'implémenter que si le budget de faux positifs est tenu | P2-05a | fusionnée |
| P2-15 | code | `ecluse_audit` : agrégat d'export pour le registre et l'AIPD (période, comptes par type avec seuil, refus par code, versions, état de la chaîne), en lecture seule | P2-09 | fusionnée |
| P2-16 | code | `ecluse_redact` : scinder détection et application de `Ecluse.redact` (test d'équivalence d'abord), préalable de l'aperçu | P2-08 | fusionnée |
| P2-17 | code | `ecluse_reid` : échelle de dates de naissance et dérivation d'âge avec date de référence injectée, palier 85+, en ajout | P2-07 | fusionnée |
| P2-18 | code | `ecluse_redact` : composant d'aperçu avec validation (proposition, refus, ajouts manuels, application), sans interface | P2-16 | fusionnée |
| P2-19 | code | `ecluse_redact` : une proposition d'aperçu périmée (dossier modifié depuis) ou appliquée à un autre dossier est refusée | P2-18 | fusionnée |
| P2-20 | code | `ecluse_redact` : les blancs en bordure d'un ajout manuel d'aperçu ne sont pas masqués | P2-19 | fusionnée |
| P2-21 | code | `ecluse_redact` : un ajout manuel d'aperçu dont une borne coupe une paire de substituts UTF-16 est refusé | P2-20 | fusionnée |
| P2-22 | code | `ecluse_redact` : marquer la provenance « manuelle » des entités ajoutées dans un aperçu (`RedactResult.manuelles`) | P2-21 | fusionnée |
| P2-23 | code | `ecluse_redact` : rapport de risque de l'aperçu avant application (`Apercu.risque`, `Proposition.risque`), sans effet de bord | P2-22 | fusionnée |
| P2-24 | code | `ecluse_ingest` : test de composition fichier → aperçu sur le texte extrait (décision 10 de P2-08) | P2-23 | fusionnée |
| P2-25 | code | `ecluse_redact` : recherche des jetons littéraux sans compiler un motif par jeton et par appel (coût d'un gros dossier) | P2-24 | fusionnée |
| P2-26 | code | `ecluse_audit` : l'export ne laisse plus retrouver un compte masqué par soustraction ni par le nombre d'entrées de la chaîne | P2-25 | fusionnée |
| P2-27 | code | `ecluse_ingest` : refuser un .docx/.odt dont le contenu ne correspond plus au CRC-32 de l'archive | P2-26 | fusionnée |
| P2-28 | code | `ecluse_ingest` : refuser un PDF qui a plus d'objets page en clair que de pages atteignables (page perdue sans avertissement) | P2-27 | fusionnée |
| P2-29 | code | `ecluse_redact` : détecter les identifiants contenant des caractères invisibles ou des tirets et espaces typographiques, sans réécrire le texte | P2-28 | fusionnée |
| P2-30 | code | `ecluse_redact` : ramener les formes pleine chasse, chiffres arabes orientaux et barres de fraction à l'ASCII dans la vue des détecteurs | P2-29 | fusionnée |
| P2-31 | code | `ecluse_redact` : restaurer un jeton échappé en Markdown (`\\[NOM\\_1\\]`) sans jamais approcher le numéro | P2-30 | fusionnée |
| P2-32 | code | `ecluse_redact` : détecter en entier un nom aux accents décomposés (NFD), sans laisser le reste du nom en clair | P2-31 | fusionnée |
| P2-33 | code | `ecluse_redact` : masquer en entier un nom contenant des majuscules ou lettres hors du jeu français (Á, Ñ, Œ, Ł, Ş, Ž, vietnamien…) | P2-32 | fusionnée |
| P2-34 | code | `ecluse_redact` : détecter une date de naissance aux séparateurs espacés (« 12 / 03 / 1950 », « 12 03 1950 ») | P2-33 | fusionnée |
| P2-35 | code | `ecluse_redact` : reconnaître les civilités abrégées avec point (« Mme. », « Mlle. ») | P2-34 | fusionnée |
| P2-36 | code | `ecluse_redact` : masquer le patronyme derrière une étiquette de champ (« Nom de naissance : », « Nom : … Prénom : … ») | P2-35 | fusionnée |
| P2-37 | code | `ecluse_redact` : masquer en entier une adresse dont le numéro de voie porte une lettre (« 12 B rue des Lilas ») | P2-36 | fusionnée |
| P2-38 | code | `ecluse_redact` : détecter un identifiant à chiffres (NIR, IBAN, téléphone, date) coupé par une fin de ligne entre deux groupes | P2-37 | fusionnée |
| P2-39 | code | `ecluse_redact` : détecter une date de naissance séparée de son étiquette (`\|`, `;`, saut de ligne) | P2-38 | fusionnée |
| P2-40 | code | `ecluse_redact` : masquer le prénom derrière « Prénom : » et reconnaître la fiche « Prénom » avant « Nom » | P2-39 | fusionnée |
| P2-41 | code | `ecluse_redact` : masquer le nom derrière « Nom du patient : », « Nom de l'assuré : »… | P2-40 | fusionnée |
| P2-42 | code | `ecluse_redact` : détecter un NIR dont la clé est nommée à part (« 2550814168025 clé 38 ») | P2-41 | fusionnée |
| P2-43 | code | `ecluse_redact` : reconnaître les variantes de contexte et d'écriture d'une date de naissance (département, abréviations, jour de semaine, mois anglais) | P2-42 | fusionnée |
| P2-44 | code | `ecluse_redact` : détecter « (+33) » et les indicatifs d'outre-mer (+262, +590, +594, +596) ; documenter l'exclusion des numéros étrangers | P2-43 | fusionnée |
| P2-45 | code | `ecluse_redact` : masquer le nom de naissance ou d'épouse derrière « née », « épouse », « veuve », « nom de jeune fille » | P2-44 | fusionnée |
| P2-46 | code | `ecluse_redact` : reconnaître « Professeure », « Docteure », « Dre », « Ms », « Mgr », « Abbé » comme civilités | P2-45 | fusionnée |
| P2-47 | code | `ecluse_redact` : reconnaître les particules da, dos, di, del, ben, bin, bint, ibn, ter, ten, zu, af dans un nom | P2-46 | fusionnée |
| P2-48 | code | `ecluse_redact` : supprimer le coût quadratique de la détection de noms sur un texte à milliers de mentions | P2-47 | fusionnée |
| P2-49 | code | `ecluse_redact` : reconnaître les types de voie « sentier », « ruelle », « clos »… et les abréviations « R. », « pl. », « ch. » | P2-48 | fusionnée |
| P2-50 | code | `ecluse_redact` : borner la recherche de la fiche « Prénom » pour supprimer un coût quadratique sur « Nom : » répété | P2-49 | fusionnée |
| P2-51 | code | `ecluse_redact` : détecter les valeurs derrière des étiquettes décorées en Markdown ou HTML (« **Nom :** », « <b>Né le</b> ») | P2-50 | fusionnée |
| P2-52 | code | `ecluse_redact` : détecter une date de naissance derrière une clé de données (`date_naissance`, `dateNaissance`, `dob`, `ddn`…) | P2-51 | fusionnée |
| P2-53 | code | `ecluse_redact` : détecter le nom d'un correspondant dans un en-tête de courriel (`De :`, `From:`, `… a écrit`) | P2-52 | fusionnée |
| P2-54 | code | `ecluse_redact` : détecter le nom de signature sous une formule de clôture (`Cordialement,`) | P2-53 | fusionnée |
| P2-55 | code | `ecluse_redact` : détecter le nom derrière une étiquette de rôle (`Patient :`, `Résident :`, `Médecin traitant :`…) | P2-54 | fusionnée |
| P2-56 | code | `ecluse_redact` : détecter une adresse sans code postal (`12 rue des Lilas`) | P2-55 | fusionnée |
| P2-57 | code | `ecluse_core`/`ecluse_redact` : type `identifiant` (dossier, IPP, passeport, CNI, plaque, IP) | P2-56 | fusionnée |
| P2-58 | code | `ecluse_redact` : coût cubique d'un mot composé très long (régression de P2-53) | P2-56 | fusionnée |
| P2-59 | code | `ecluse_core`/`ecluse_redact` : scinder le type `identifiant` par catégorie (dossier, document d'identité, véhicule, réseau) | P2-58 | fusionnée |
| P2-60 | code | `ecluse_redact` : téléphones étrangers (pays voisins et Maghreb) | P2-59 | fusionnée |
| P2-61 | code | `ecluse_redact` : noms en clés de données explicites et CSV à en-tête | P2-60 | fusionnée |
| P2-62 | code | `ecluse_core` : IBAN de l'espace SEPA avec clé mod 97 | P2-61 | fusionnée |
| P2-63 | code | `ecluse_redact` : tableaux HTML et titres Markdown dans la vue de détection | P2-62 | fusionnée |
| P2-64 | code | `ecluse_redact` : coût linéaire de la résolution des pseudonymes au-delà de 50 000 mentions | P2-63 | fusionnée |
| P2-65 | code | `ecluse_ingest`/`ecluse_redact` : tableaux Word et ODT (cellules par tabulation, rangées par saut de ligne) | P2-64 | fusionnée |
| P2-66 | code | `ecluse_core` : résolveur de chevauchements linéaire (`resolveOverlaps`) | P2-65 | fusionnée |
| P2-67 | code | `ecluse_ingest` : formats texte structurés `.csv`, `.tsv`, `.json`, `.html`, `.xml` | P2-66 | fusionnée |
| P2-68 | code | `ecluse_redact` : prénoms d'origines variées au gazetteer (Maghreb, Afrique de l'Ouest, Europe, Asie) | P2-67 | fusionnée |
| P2-69 | code | `ecluse_redact` : civilités au pluriel et en majuscules, mots de parenté (`Mmes`, `la famille`, `le docteur`, `Sœur`) | P2-68 | fusionnée |
| P2-70 | code | `ecluse_redact` : prénom entre deux mots capitalisés, couvrir les deux voisins (`Appeler Pierre Dupont`) | P2-69 | fusionnée |
| P2-72 | code | `ecluse_redact` : la restauration ne consomme plus la barre oblique d'un chemin Windows devant un jeton | P2-70 | fusionnée |
| P2-71 | code | `ecluse_redact` : noms dans les noms de fichiers, URL, chemins et identifiants | P2-72 | fusionnée |
| P2-73 | code | `ecluse_redact` : nom coupé par un retour à la ligne (civilité, étiquette puis valeur) | P2-71 | fusionnée |
| P2-74 | code | `ecluse_redact` : forme « Nom, Prénom » (`Marchetti, Odette`) | P2-73 | fusionnée |
| P2-75 | code | `ecluse_redact` : initiales entre une civilité et un patronyme (`Dr A. Faure`) | P2-74 | fusionnée |
| P2-76 | code | `ecluse_redact` : variantes de contexte de naissance (`DN`, `D.N.`, `Date nais.`, `née 12/9/1938`) | P2-74 | fusionnée |
| P2-77 | code | `ecluse_redact` : sur-masquages fréquents (fonctions après civilité, statuts, jours voisins, Saint-…, éponymes, lots) | P2-75 | fusionnée |
| P2-78 | code | `ecluse_redact` : colonne « Date de naissance » d'un tableau à en-tête | P2-79 | fusionnée |
| P2-79 | code | `ecluse_redact`/`ecluse_ingest` : coût d'une chaîne de particules et de balises ouvertes (déni de service) | P2-76 | fusionnée |
| P2-80 | code | `ecluse_redact` : identifiants administratifs sans « n° » (`dossier 4900123456`, `N° résident`, `Plan d'aide n°`) | P2-79 | fusionnée |
| P2-81 | code | `ecluse_redact` : signature avec initiale (`N. Haddad`) et nom de naissance `(ex-Garnier)` | P2-79 | fusionnée |
| P2-82 | code | `Ecluse.restore` : un seul parcours des segments `[...]` au lieu d'un remplacement par jeton (reprise de la partie restauration de #201) | P2-64 | fusionnée |
| P2-84 | code | `ecluse_redact` : valeurs « vides » d'un champ étiqueté (`Prénom : Non renseigné`, `Néant`, `Idem`…) jamais prises pour un nom | P2-82 | fusionnée |
| P2-85 | code | Coûts superlinéaires trouvés par relecture : chiffre + blancs, minuscules + point, `sk-` répété, `restore` avec valeur `[at]` | P2-84 | fusionnée |
| P2-83 | code | `ecluse_redact` : date de naissance — mois abrégés (`janv.`, `déc.`…), libellés `Naiss.` / `Naissance le/du`, date compacte à 8 chiffres | P2-82 | fusionnée |
| P2-86 | spec | Fiche des modèles NER candidats (licence des poids et des données, taille, labels) | — | fusionnée |
| P2-87 | humain | Valider les seuils de P2-01 § 7 et nommer la machine de référence | — | fusionnée |
| P2-88 | code | `bench/ner_predictions.md` : format des prédictions attendu par `score_flou.py`, correspondance des labels, commande de mesure | P2-86 | fusionnée |
| P2-89 | humain | Produire et scorer les prédictions du modèle sur les trois corpus flous, sur le poste du mainteneur | P2-87, P2-88 | fusionnée |
| P2-90 | humain | Décision GO/STOP du NER dans `DECISIONS.md` | P2-89 | fusionnée |
| P2-91 | code | Rapport de risque : suggestions de généralisation positionnées (QI, offsets, niveau, F avant/après), texte inchangé | — | fusionnée |
| P2-92 | code | Application explicite des suggestions choisies par l'appelant (irréversible, refus si périmée) | P2-91 | fusionnée |
| P2-93 | mesure | Généralisation appliquée : avant/après sur le corpus de QI (`score_qi.py`) | P2-92 | fusionnée |
| P2-94 | humain | Source et licence de la table pathologie → catégorie | — | fusionnée |
| P2-95 | spec | Branchement d'`ecluse_audit` dans `Ecluse.redact` | — | fusionnée |
| P2-96 | code | Implémentation de P2-95 selon les décisions du mainteneur | P2-95, P2-96a | fusionnée |
| P2-96a | humain | Trancher les quatre décisions de P2-95 § 7 | P2-95 | fusionnée |
| P2-97 | humain | Lire le gabarit AIPD de la CNIL et solliciter l'avis d'un DPO | — | humain |
| P2-98 | mesure | Rappel des détecteurs sur un texte de style transcrit (sans audio) | — | fusionnée |
| P2-99 | humain | Accepter ou non une dépendance native (whisper.cpp) dans le monorepo | P2-98 | fusionnée |
| P2-100 | code | Tests de coût : rapport de temps entre deux tailles au lieu d'une borne en millisecondes | — | fusionnée |
| P2-101 | code | Migration vers Melos 7 et plus (configuration dans `pubspec.yaml`) | — | fusionnée |
| P2-102 | code | Relire au bon palier les tranches d'âge et les professions généralisées (défauts mesurés par P2-93) | P2-93 | fusionnée |
| P2-103 | mesure | Généralisation du lieu : effet de « département N » non relu sur F et sur l'évaluation | P2-102 | fusionnée |
| P2-104 | spec | Critère GO/STOP du vérificateur LLM local | — | fusionnée |
| P2-104a | humain | Trancher les décisions de P2-104 § 6 (seuils, signaler ou masquer, ordre) et de P2-106 § 4 (licence des données d'un LLM) | P2-104 | fusionnée |
| P2-105 | code | Générateur du corpus de fuites sémantiques (indices annotés, témoin, jeu injection), graine fixe | P2-104a | fusionnée |
| P2-106 | spec | Fiche des petits LLM locaux candidats (licences des poids et des données lues, taille, français, sortie JSON) | P2-104 | fusionnée |
| P2-107 | code | `bench/verificateur_predictions.md` : produire les prédictions du vérificateur (modèle local, prompt de `ecluse_llm`, format de `score_semantique.py`) | P2-105, P2-106 | fusionnée |
| P2-108 | humain | Lancer le vérificateur sur les trois corpus sémantiques sur le poste du mainteneur, scorer, décider GO/STOP | P2-90, P2-107 | humain |
| P2-109 | humain | Branche `feat/llm-scaffold` : statut explicite « non vérifié » dans `VerificationResult` (échec d'analyse, troncature) au lieu d'une liste vide | P2-104 | fusionnée |
| P2-110 | humain | Valider cliniquement la table maison des pathologies (`agent/specs/P2-94-table.md` § 4) | P2-94 | fusionnée |
| P2-111 | humain | Fournir la page de licence d'Orphadata et le fichier de nomenclature en français (site inaccessible à la session) | P2-94 | fusionnée |
| P2-112 | code | Générateur d'un corpus de pathologies annoté (mentions de la table maison, témoin avec faux amis), graine fixe | P2-110 | fusionnée |
| P2-113 | humain | Décider l'intégration d'Orphanet : traitement des sigles, priorité avec la table maison (`agent/specs/P2-113.md` § 6) | P2-94 | fusionnée |
| P2-114 | code | Script d'extraction Orphanet et asset `patho_orphanet.tsv.gz` (`tools/build_orphanet_asset.py`) | P2-113 | fusionnée |
| P2-115 | code | `ecluse_reference` : charger `patho_orphanet.tsv.gz` (ORPHAcode → catégorie, mentions) avec ses tests ; aucun appariement dans le texte | P2-114 | fusionnée |
| P2-116 | code | Relire « département N » après généralisation du lieu (défaut mesuré par P2-103) | P2-103 | fusionnée |
| P2-117 | mesure | Entités floues sur texte sans majuscules ni ponctuation (corpus flou réaliste) | P2-98 | fusionnée |
| P2-118 | code | Avertir dans `warnings` d'un texte sans aucune majuscule (défaut mesuré par P2-117) | P2-117 | fusionnée |
| P2-119 | code | Détecter les noms dans un texte sans aucune majuscule (`NomMinusculesDetector`, mesuré sur les corpus flous en minuscules) | P2-117 | fusionnée |
| P2-120 | code | Adresses et établissements dans un texte sans aucune majuscule (même principe que P2-119) | P2-119 | fusionnée |
| P2-121 | mesure | Entités floues sur texte entièrement en majuscules (corpus flous) | P2-117 | fusionnée |
| P2-122 | code | Adresses et établissements dans un texte sans aucune minuscule ; 0 faux positif sur le témoin en majuscules (`agent/specs/P2-121.md`) | P2-121 | fusionnée |
| P2-123 | code | Noms dans un texte entièrement en capitales (`NomMinusculesDetector` sur le texte mis en minuscules) | P2-121 | fusionnée |
| P2-124 | code | Faux amis prénoms en minuscules (« rose pâle ») : corpus témoin et correction mesurée | P2-119 | fusionnée |
| P2-125 | code | Repérer les pathologies (table maison provisoire + Orphanet, rattachement à une personne), mesuré sur le corpus P2-112, non branché | P2-112 | fusionnée |
| P2-126 | code | Pathologies : négations (« pas de diabète connu ») et formes adjectivales (« diabétique »), corpus `variantes` | P2-125 | fusionnée |
| P2-127 | code | Signaler les pathologies rattachées dans le rapport de risque (information, hors estimation) | P2-126 | fusionnée |
| P2-128 | code | Coût linéaire du repérage des pathologies (fenêtre bornée) et tests de coût des détecteurs de casse | P2-125 | fusionnée |
| P2-131 | code | Texte en minuscules : voie sans code postal après un indice d'adresse (« située », « demeurant ») | P2-120 | fusionnée |
| P2-132 | code | Généralisation en département : réécrire la préposition (« habite dans le département 70 ») | P2-116 | fusionnée |
| P2-133 | code | Message d'un texte sans majuscule ajusté après P2-119/120/131 (« moins sûre », plus « non détectés ») | P2-118 | fusionnée |
| P2-129 | mesure | Pathologies : formes non couvertes (« non diabétique », « DT2 », négation après la mention), corpus `formes_libres` | P2-128 | fusionnée |
| P2-130 | mesure | Tableau de bord des mesures : rejouer tous les corpus du dépôt sur `main` et consigner les chiffres dans `bench/ETAT.md` | P2-128 | fusionnée |
| P2-134 | code | Pathologies : « non » devant un adjectif, sigles DT1/DT2, « ATCD », négation après la mention (défauts mesurés par P2-129) | P2-129 | fusionnée |
| P2-135 | code | Généraliser une pathologie sur demande (catégorie → générique), sans F ; éponyme accolé absorbé | P2-127 | fusionnée |
| P2-136 | code | QI : durées (« pour 9 ans ») et communes-mots courants (« Tours de garde ») écartés ; témoin 412 → 57 | P2-130 | fusionnée |
| P2-137 | code | Démo : texte et consigne masqués séparément dans un `Dossier` (la consigne « Résume. » désactivait les détecteurs de casse), avertissements affichés | P2-133 | fusionnée |
| P2-138 | code | Texte en casse de phrase (majuscule en début de phrase seulement) : détecteurs de casse et avertissement ; fuite 64 % → 0,6 % | P2-120 | fusionnée |
| P2-139 | code | Noms en minuscules : initiale, ordre « nom prénom », particules ; adversarial 27 % → 5,9 % | P2-138 | fusionnée |
| P2-140 | mesure | Dossiers en minuscules et en casse de phrase : cohérence des jetons, collisions, fausses fusions (corpus dossiers × variantes de casse) | P2-139 | fusionnée |
| P2-141 | code | Démo : rapport de risque (bande, indices restés visibles, pathologies) avec la référence publique | P2-137 | fusionnée |
| P2-142 | code | QI : lieu d'un événement (« aura lieu à Brest ») écarté ; témoin 57 → 0 | P2-136 | fusionnée |
| P2-143 | code | Masquer les maladies rares (Orphanet, rattachées ou texte qui nomme une personne), réversible ; pathologies fréquentes en clair | P2-110 | fusionnée |
| P2-144 | code | Patronyme repris seul en minuscules ou capitales (même texte et dossier) ; 116 → 4 non détectés | P2-140 | fusionnée |
| P2-145 | code | Dossiers à casse mixte : corpus `_mixte`, même jeton pour une même personne, civilité de genre en clair en minuscules | P2-140 | fusionnée |
| P2-147 | code | Initiale + patronyme après un libellé de personne (« Présent : T. Lefèvre »), casse ordinaire ; adversarial 9,3 % → 7,2 % | P2-90 | fusionnée |
| P2-148 | spec | Liste de prénoms tirée du fichier des prénoms de l'INSEE (licence à lire), seuil d'effectif, garde-fous faux amis | P2-147 | fusionnée |
| P2-149 | code | Asset de prénoms INSEE (script `tools/`, `NOTICE`), mesure avant/après sur tous les corpus | P2-148 | fusionnée |
| P2-150 | code | Exclure les paires « France Travail » et « Ange Gardien » de l'option `prenomsInsee` (demande du mainteneur) | P2-149 | fusionnée |
| P2-151 | code | Activer l'option `prenomsInsee` dans `ecluse_demo` (choix délégué par le mainteneur) | P2-150 | fusionnée |
| P2-152 | code | Identifiant coupé par une fin de ligne après une lettre de groupe ou bordée d'espaces insécables (extension de P2-38) | P2-38 | fusionnée |
| P2-146 | spec | Lecture du gabarit AIPD de la CNIL (« PIA, les modèles », 2018) et correspondance case par case avec Écluse (`agent/specs/P2-97.md`) | — | fusionnée |
| P2-153 | code | Corpus « mise en page » : générateur qui remet les corpus flous et structurel en lignes d'une page (retours à la ligne seuls), et ligne au tableau de bord ; aucun détecteur modifié | P2-152 | fusionnée |
| P2-154 | mesure | Âge : analyser les 12,7 % d'âges non couverts du corpus QI adversarial (formes manquées, chiffrées) | — | fusionnée |
| P2-155 | spec | Nombres dictés en lettres : normalisation « mots → chiffres » dans la vue de détection (périmètre, ambiguïtés, faux positifs, plan de mesure) | P2-98 | fusionnée |
| P2-156 | mesure | Dépendances `pdf_cos`, `pdf_document`, `pdf_graphics` (10.0.0, dernière 15.0.0) : essayer la montée de version et rapporter ce qui casse | — | fusionnée |
| P2-157 | mesure | Adresses : analyser les 1,9 % de fuite du corpus flou adversarial (formes manquées, chiffrées) | — | fusionnée |
| P2-158 | code | IBAN coupé par une fin de ligne juste avant un groupe qui commence par une lettre (« …0270⏎D932… »), dernier identifiant manqué du corpus « mise en page » | P2-153 | fusionnée |
| P2-159 | code | Âges dans `ecluse_reid` : nombre en lettres suivi de « ans » (les 15 cas de P2-154) et tranche « de 80 à 85 ans » (regroupe P2-163) | P2-154 | fusionnée |
| P2-160 | code | Dictée, les deux corpus de mesure : témoin « mots-nombres » et variantes de dictée manquantes du corpus transcrit, avec mesure de départ ; aucun détecteur modifié (regroupe P2-161) | P2-155 | fusionnée |
| P2-161 | code | Corpus transcrit : variantes de dictée manquantes (« double zéro », « septante », « o six », séparateurs perdus) et mesure de départ ; aucun détecteur modifié | P2-155 | regroupée (P2-160) |
| P2-162 | spec | Fin de ligne dans un identifiant : faut-il descendre la neutralisation de `ecluse_redact` dans `ecluse_core` ? | P2-153 | fusionnée |
| P2-163 | code | Tranche d'âge « de 80 à 85 ans » : lire les deux bornes (aujourd'hui seule la seconde sort) | P2-154 | regroupée (P2-159) |
| P2-164 | code | Adresses : numéro de CEDEX (« CEDEX 9 », « Cedex 09 », virgule avant CEDEX) et boîte postale (« BP 12 ») laissés en clair (suite de P2-157) | P2-157 | fusionnée |
| P2-165 | code | Âges dans `ecluse_reid` : durées lues à tort comme un âge (« deux ans plus tard », « au bout de cinq ans », « un contrat de 3 ans »), en lettres comme en chiffres (suite de P2-159) | P2-159 | fusionnée |
| P2-166 | mesure | Mise en page : ligne « détecteur isolé » au tableau de bord et budget de faux positifs d'une fin de ligne neutralisée dans le cœur (plan de mesure de P2-162 § 5, points 1 et 3) ; aucun code de production | P2-162 | fusionnée |
| P2-167 | code | Adresses : « code postal + mot » hors adresse masqué à tort (« Commande de 70000 unités ») ; mesurer d'abord sur un témoin dédié, puis corriger sans perdre une adresse | P2-164 | fusionnée |
| P2-168 | code | Tableau de bord : `bench/etat.sh` ne doit ni taire une ligne attendue ni masquer un échec (filtres `grep`, `\|\| true`, sorties jetées) ; banc seulement, aucun fichier de `lib/` | P2-165 | fusionnée |
| P2-169 | mesure | Audit des voies de fuite après les changements de novembre (`ecluse_redact`, `ecluse_reid`, `ecluse_ingest`, `ecluse_demo`, `ecluse_audit`) : exceptions, `toString`, journaux, sérialisation ; rapporter, ne rien corriger | P2-165 | fusionnée |
| P2-170 | code | Voies de fuite de `ecluse_reid` et `ecluse_reference` : `toString` sans valeur tirée du texte (`Qi`, `BirthDate`, `Generalization`, `PathologieMention`) et messages d'`ArgumentError` à motif fixe (F1, F3, F4, F5 de P2-169) | P2-169 | fusionnée |
| P2-171 | code | Fin de ligne et moteur seul : documenter la limite (option B de P2-162) et faire les deux mesures qui manquent avant A1 (équivalence octet pour octet, coût en temps) ; aucun fichier de `lib/` | P2-166 | fusionnée |
| P2-172 | code | `ReidTrace.toAuditMap` : aucune valeur de quasi-identifiant dans la trace d'audit (voie F2 de P2-169) | P2-170 | fusionnée |
| P2-173 | code | Établissement et commune coupés par une fin de ligne (« Centre⏎Hospitalier de … », dernier mot de la commune) laissés en clair par `Ecluse.redact` | P2-171 | fusionnée |
| P2-174 | code | Identifiant suivi d'une date ou d'un nombre : FINESS suivi d'une date masqué comme RPPS en avalant le jour (témoin d'abord) | — | fusionnée |
| P2-175 | code | Extraction des QI : ligne « par `Ecluse.redact` » au tableau de bord, lieux à tort (patronyme homonyme d'une commune), professions abrégées (« pneumo », « gynéco », « pediatre ») | — | fusionnée |
| P2-176 | code | Effectif F hors des canaux de texte (`toString`, `toAuditMap`, note de plafonnement) : la tranche de risque à la place de l'effectif exact | P2-172 | fusionnée |
| P2-177 | code | Adresses : nombre de cinq chiffres en tête de phrase suivi d'un mot (« 58699 Alpha livrés ») masqué à tort comme adresse (témoin d'abord) | P2-167 | fusionnée |
| P2-178 | mesure | Adresses : CEDEX après une commune de plus de quatre mots ; mesurer, ne rien corriger | P2-164 | fusionnée |
| P2-179 | code | Tableau de bord : en-tête de `bench/ETAT.md` à jour et type `identifiant` reconnu par `run_redact_bench.dart` (avertissement de fin d'`etat.sh`) ; banc seulement | P2-168 | fusionnée |
| P2-180 | code | Commune masquée en entier : lettre « œ »/« Œ » et mot en « M », « Pr », « Dr »… suivi d'une lettre accentuée pris pour une civilité (« Annœullin », « Le Pré-Saint-Gervais ») ; balayage des communes au tableau de bord | P2-178 | fusionnée |
| P2-181 | code | Commune de cinq mots ou plus et mots de liaison absents (« et », « au », « à », « près ») : témoin de sur-masquage d'abord, puis correction ou arrêt chiffré | P2-180 | fusionnée |
| P2-182 | spec | Table des communes dans la détection d'adresses : gain (« 58699 Alpha » contre « 70000 Vesoul », noms longs), perte (faute d'orthographe, lieu-dit), dépendance `ecluse_reference` → `ecluse_redact` | P2-178 | fusionnée |
| P2-183 | mesure | Communes du balayage de P2-178 en texte tout en capitales et sans majuscule (autres détecteurs) ; mesurer, ne rien corriger | P2-178 | fusionnée |
| P2-184 | code | Nombre à cinq chiffres hors adresse : vérification en table des communes, en option explicite de `Ecluse.redact` (piste A et C de P2-182) | P2-182 | abandonnée (DECISIONS.md, 15 novembre) |
| P2-185 | code | Texte tout en capitales : commune composée qui commence par « LA », « LE », « LES », « L' » (« 01097 LA BOISSE ») écartée à tort comme mot neutre (tâche A de P2-183) ; balayage en capitales au tableau de bord | P2-183 | regroupée (P2-187) |
| P2-186 | code | Restauration fausse : dans un tableau relu sans séparateurs, le nom avale la fonction en capitales qui suit (« LEFÈVRE Olivier AS ») et deux homonymes reçoivent le même jeton ; `Ecluse.restore` réécrit l'autre ligne | — | fusionnée |
| P2-187 | code | Texte tout en capitales : livrer la correction d'essai de P2-185 (commune composée en « LA », « LE », « LES », « L' » masquée en entier), avec d'abord un témoin « cinq chiffres + LE/LA/LES » en capitales et en casse ordinaire | — | fusionnée |
| P2-188 | code | Identifiant à clé fausse annoncé par son libellé (« NIR », « sécurité sociale », « IBAN », « RPPS ») : aujourd'hui en clair ; le masquer quand même et avertir (témoin d'abord) | — | fusionnée |
| P2-189 | spec | Table de correspondance : un type dédié qui ne s'affiche jamais en clair et se vide sur demande, à la place de `Map<String, String>` (changement d'API à décider) | — | fusionnée |
| P2-190 | code | Restauration : signaler les jetons non restaurés (jeton sans crochets, inventé, traduit) et corriger la barre oblique laissée par `\[NOM_1]` | — | fusionnée |
| P2-191 | code | Identifiant annoncé par un libellé fort, lu par OCR : O pour 0, l ou I pour 1, ligne vide au milieu ; suite de P2-188, qui ne couvre que les chiffres | P2-188 | fusionnée |
| P2-192 | code | Démo et sas Claude Code : utiliser `restoreAvecRapport` et remonter les jetons non restaurés (type et numéro seulement) | P2-190 | fusionnée |
| P2-193 | code | Table de correspondance : type dédié `TableDeCorrespondance` à la place de `Map<String, String>`, selon les décisions du 15 novembre (`DECISIONS.md`), rupture nette en 0.2.0 | P2-189 | fusionnée |
| P2-194 | code | Tableau de bord : témoin « libellé fort » (NIR, IBAN, RPPS, ADELI, sécurité sociale derrière leur libellé, clé fausse et variantes OCR de P2-191), voie aujourd'hui couverte par les tests seulement | P2-191 | fusionnée |
| P2-195 | code | Texte tout en capitales : borner la « commune » qui suit un code postal et un déterminant, pour réduire le masquage en trop de P2-187 sans perdre de commune | P2-187 | abandonnée (#409 ; décision du 15 novembre, `DECISIONS.md`) |
| P2-196 | mesure | Balayage des communes en capitales : décrire les 95 adresses encore en partie en clair (causes « autre » 59, « ponctuation » 30, longueur) | P2-187 | fusionnée |
| P2-197 | code | Sas Claude Code (mod TypeScript) : lire le champ `nonRestaures` de `POST /v1/restore` et l'afficher en une ligne | P2-192 | fusionnée |
| P2-198 | spec | Journal d'audit : que faire quand la version du moteur change (0.2.0) entre deux entrées d'un même journal | P2-193 | fusionnée |
| P2-199 | code | ADELI derrière son libellé, lu par OCR (O pour 0, l ou I pour 1) ou coupé par une ligne vide : 200 identifiants sur 300 en clair au témoin P2-194 | P2-194 | fusionnée |
| P2-200 | code | Tableau de bord : balayage des communes en capitales **sans** « CEDEX » et témoin de faux positifs « cinq chiffres + mot neutre + CEDEX », avant toute correction devant CEDEX | P2-196 | fusionnée |
| P2-201 | code | Communes en capitales devant « CEDEX » : lever la règle du mot neutre, admettre parenthèse, tiret isolé et blancs multiples, numéro de CEDEX après un nom (classes 1 à 5 de `agent/specs/P2-196.md`) | P2-200 | fusionnée |
| P2-202 | code | Export AIPD : moteurs dans l'ordre de première apparition, nombre de changements de moteur et mention d'honnêteté (recommandations de `agent/specs/P2-198.md`) | P2-198 | fusionnée |
| P2-203 | mesure | Mesurer la confiance des masquages et l'avertissement « à vérifier » au tableau de bord (le banc ne lit pas la confiance aujourd'hui) | P2-194 | fusionnée |
| P2-204 | code | ADELI à clé fausse derrière son libellé : masqué à confiance 0,6 sans avertissement « à vérifier », alors que NIR, IBAN et RPPS à clé fausse en portent un | P2-199 | fusionnée |
| P2-205 | spec | Communes en capitales sans « CEDEX » : 338 adresses sur 139 500 en partie en clair, dont 216 par la longueur (commune de plus de quatre mots) ; options et risque de faux positifs avant toute correction | P2-200 | fusionnée |
| P2-206 | mesure | Communes en capitales sans « CEDEX » : rendre la ventilation en cinq formes reproductible et chiffrer le coût des options « nom exact du référentiel » et « fin de ligne » (aucun `lib/` modifié) | P2-205 | fusionnée |
| P2-207 | code | `EtablissementDetector` : frontière de mot pour les mots-clés (« CH » dans « BUËCH ») et masquage limité au nom (ne pas déborder sur la ligne suivante) ; 29 des 338 adresses en défaut | P2-205 | fusionnée |
| P2-208 | code | « SAINT M HERVE » : le « M » isolé après SAINT n'est pas une civilité ; seule adresse en défaut qui reste au balayage en capitales avec CEDEX | P2-201 | fusionnée |
| P2-209 | code | Une seule implémentation de la clé Luhn : exporter celle de `ecluse_core` et retirer la copie de `ecluse.dart` (P2-204), sans changer de comportement | P2-204 | fusionnée |
| P2-210 | mesure | Fréquence réaliste de « cinq chiffres + mot neutre + CEDEX » en capitales sur des courriers synthétiques, pour trancher le coût de P2-201 (113 / 200 au témoin pire cas) | P2-201 | fusionnée |
| P2-211 | mesure | Mots neutres de `mots_neutres.dart`, avec et sans accent, capitales et casse ordinaire : nombre de phrases où la liste ne protège pas le nombre (témoin de 400 phrases par mot) | P2-210 | fusionnée |
| P2-212 | code | Mots neutres sans accent en capitales (« 39314 NUMEROS EN ATTENTE » masqué en adresse) : 35 lignes sur 3 185 au témoin des courriers | P2-211 | fusionnée |
| P2-213 | code | Commune dont le nom contient un mot de voie (« 52417 GRAFFIGNY CHEMIN CEDEX 7 ») : code postal et nom restent en clair quand une ligne « code postal + mot » suit | P2-210 | fusionnée |
| P2-214 | code | Communes en capitales sans « CEDEX » : règle « nom exact du référentiel » pour les formes A, C et D de P2-206 (309 adresses en partie en clair) | P2-206, P2-207 | fusionnée |
| P2-215 | spec | Écritures de communes hors référentiel (« ST », « STE », fautes, apostrophe perdue) : ce que la règle « nom exact » ne couvre pas, options et recommandation | P2-206 | fusionnée |
| P2-216 | code | Découper `ecluse.dart` (1 378 lignes, cohésion la plus faible du graphe du 15 novembre) en fichiers par responsabilité, sans changer le comportement ni l'API publique | P2-214 | fusionnée |
| P2-217 | code | `LIMITES.md` : résumé de deux pages en tête, détail dessous (2 065 lignes dont plus de 1 000 pour les entités coupées), aucun contenu perdu | P2-212, P2-214 | fusionnée |
| P2-218 | mesure | Patronyme seul sans civilité hors session de dossier (« le dossier de Maillard ») : corpus et témoin versionnés, chiffre de départ (16 noms manqués sur 83 à la sonde du 17 novembre) | — | fusionnée |
| P2-219 | spec | Liste de personnes fournie par l'appelant (patients, salariés, planning) : ouvrir à l'API ce que la session de dossier fait déjà ; options, risques, recommandation | P2-218 | fusionnée |
| P2-220 | code | Patronyme seul derrière un contexte de personne (« le dossier de X », « l'entretien avec X », « X a confirmé ») : masquer, témoin sans nom tenu | P2-218 | fusionnée |
| P2-221 | spec | Référentiel de patronymes en option (sur le modèle de `prenomsInsee`) : source, licence, faux positifs sur les noms qui sont aussi des mots (« Marchand », « Petit ») | P2-218 | fusionnée |
| P2-222 | spec | Session de dossier dans `ecluse_demo` et dans le sas Claude Code : état des lieux, et proposition pour qu'elle serve dès que des textes se suivent | — | fusionnée |
| P2-223 | mesure | SIREN masqué comme FINESS : fréquence sur le corpus v3 entier et sur un témoin de SIREN, options chiffrées (3 sur 50 documents à la sonde du 17 novembre) | — | fusionnée |
| P2-224 | mesure | Comparatif versionné avec d'autres outils (Presidio en français, spaCy français, règles d'EDS-Pseudo) sur une centaine de documents, plus une moitié adresses et dates de naissance | P2-218 | fusionnée |
| P2-225 | humain | Mesurer GLiNER et le modèle complet d'EDS-Pseudo sur le poste du mainteneur (modèles inaccessibles en session cloud), avec le script de P2-224 | P2-224 | humain |
| P2-226 | mesure | Témoin élargi des tournures de personne (P2-220) : mots de rôle et de parenté, organismes, noms communs à majuscule, patronymes qui sont aussi des communes ou des noms communs | P2-220 | fusionnée |
| P2-227 | code | Tournures de personne : liste fermée des mots de rôle et de parenté (« Madame a confirmé », « entretien avec Famille ») jamais pris pour un patronyme | P2-226 | fusionnée |
| P2-228 | code | Tournures de personne : n'écarter les communes qu'après « à la demande de » (fuite « Gaillard a confirmé ») | P2-227 | fusionnée |
| P2-229 | code | Tournures de personne : liste fermée d'organismes nationaux (« le dossier de France Travail », « à la demande de Emmaüs ») | P2-228 | fusionnée |
| P2-230 | spec | Aperçu : signaler « à vérifier » les noms établis par une seule tournure de personne, sans changer ce qui est masqué | P2-229 | fusionnée |
| P2-231 | humain | Lire les licences : noms de famille de l'INSEE (P2-221), lexiques de formes fléchies du français (Lefff, LGPL-LR ; Morphalou, ATILF) et leur compatibilité avec Apache 2.0 ; puis décider du référentiel de patronymes et du lexique de verbes | P2-221 | fusionnée |
| P2-232 | code | Aperçu : signal « à vérifier » sur les noms dont la seule preuve est une tournure de personne (option A de P2-230), sans changer ce qui est masqué | P2-230 | fusionnée |
| P2-233 | mesure | Patronymes qui sont aussi une commune derrière « à la demande de » : 24 sur 96 en clair (P2-228) ; options pour les départager des lieux, chiffrées hors `lib/` | P2-228 | fusionnée |
| P2-234 | code | Tournures de personne : organismes encore masqués à tort (43 sur 96 au témoin de P2-226, après P2-229) | P2-229 | fusionnée |
| P2-235 | mesure | Bornes d'un nom « prénom + verbe » (« Sophie rappelle. » proposé en entier, confiance 0,5) : fréquence et cause | P2-230 | fusionnée |
| P2-236 | code | Test de coût linéaire de `adresse_cedex_test.dart` : remplacer le plafond fixe de 15 s par un rapport de croissance | — | fusionnée |
| P2-237 | mesure | Expliquer l'écart de 3 caractères du témoin « commune suivie » (5 379 → 5 376, depuis P2-212) | P2-212 | fusionnée |
| P2-238 | mesure | Témoin `lieu` élargi : communes de 10 000 à 100 000 habitants derrière les tournures de personne, avant le seuil de 100 000 (décision du 20 novembre) | P2-233 | fusionnée |
| P2-239 | code | Tournures de personne : n'écarter après « à la demande de » que les communes de 100 000 habitants et plus (option D de P2-233) | P2-238 | fusionnée |
| P2-240 | code | « Prénom + verbe » : ne plus étendre un nom sur un verbe conjugué (« Sophie rappelle. »), ni retenir ce verbe comme patronyme | P2-235 | fusionnée |
| P2-241 | code | « Prénom + mot » : dans un texte à casse normale, ne jamais étendre un prénom sur un mot en minuscule (aucun verbe masqué, hors liste comprise), coût mesuré d'abord | P2-240 | fusionnée |
| P2-242 | code | « Prénom + verbe » : étendre la liste fermée de P2-240 (formes et terminaisons sûres) sans aucune fuite ajoutée | P2-241 | fusionnée |
| P2-243 | code | Liste de personnes fournie par l'application, dans le `Dossier` (option B de la spec P2-219, décisions du 21 novembre) | P2-219 | fusionnée |
| P2-244 | code | Communes hors référentiel : « ST »/« STE » et séparateurs collés (option 1 de la spec P2-215, table réduite) | P2-215 | fusionnée |
| P2-245 | spec | Paquet optionnel `ecluse_lexique` sous sa propre licence (formes verbales du Lefff, LGPL-LR), hors du cœur Apache 2.0 | P2-242 | fusionnée |
| P2-246 | mesure | Témoin de documents réalistes sans aucune donnée personnelle (au moins 400) : masquages à tort des six configurations du comparatif | P2-224 | fusionnée |
| P2-247 | mesure | Comparatif : annoter les données personnelles non annotées de l'échantillon v3 (noms, téléphones, numéros de dossier) avant de compter les masquages à tort | P2-224 | fusionnée |
| P2-248 | code | SIREN et SIRET nommés : après « SIREN » ou « SIRET », étiquette `siren` au lieu de `finess`, toujours masqué | — | fusionnée |
| P2-249 | humain | Télécharger le fichier national des noms de l'INSEE (txt, fait le 21 novembre : `patronymes_effectifs.tsv.gz`) et Morphalou 3.1 (CSV « tout en un ») et les déposer pour génération des fichiers dérivés (le réseau des sessions ne joint ni insee.fr ni ortolang.fr) | P2-231 | fusionnée |
| P2-250 | code | Référentiel de patronymes de l'INSEE (Licence Ouverte 2.0) : confirmer un nom derrière une tournure, et règle de forme de P2-241 limitée aux mots absents du référentiel | P2-231 | abandonnée |
| P2-251 | code | Paquet optionnel `ecluse_lexique` (LGPL-LR) : formes verbales de Morphalou 3.1, chargées comme fichier remplaçable (spec P2-245) ; aucun verbe masqué derrière un prénom | P2-249 | fusionnée |
| P2-252 | code | IBAN à clé invalide masqué en entier : ne plus masquer 9 de ses chiffres comme FINESS en laissant le reste en clair (10 cas sur 200 000) | — | fusionnée |
| P2-253 | code | Liste de patronymes fournie (P2-243) : un nom écrit avec une majuscule initiale (« Eva ») n'est pas refusé parce que sa forme en capitales est un sigle exclu | P2-243 | fusionnée |
| P2-254 | code | IBAN FR à clé fausse sans libellé dont la clé porte une lettre « o » d'OCR (« FR8o52… ») : 4 sur 50 en clair au corpus libellé fort | — | fusionnée |
| P2-255 | mesure | Recensement des pièges de tous les générateurs de corpus : lesquels sont des données personnelles d'après DECISIONS.md, comment chacun est annoté et traité aujourd'hui | — | fusionnée |
| P2-256 | mesure | `bench/README.md` rejoué de bout en bout : chiffres périmés depuis P2-248 (SIREN typé) et l'annotation des IBAN à clé fausse (826 entités) | — | fusionnée |
| P2-257 | code | `bench/ETAT.md` : 18 sections en double (17 identiques, 1 divergente) fusionnées, sans changer aucun chiffre | — | fusionnée |
| P2-258 | code | NIR à clé fausse sans libellé : donnée personnelle (décision du 23 novembre) ; annoter les pièges des corpus et les masquer en entier à 0,3 « à vérifier », coût mesuré d'abord | — | fusionnée |
| P2-259 | code | SIRET nommé (14 chiffres après « SIRET ») masqué en entier, type `siren` : 30 / 30 en clair aujourd'hui | — | fusionnée |
| P2-260 | code | Numéro de TVA intracommunautaire masqué en entier (« FR » + clé + SIREN), type `siren` : 29 / 35 en clair aujourd'hui | — | fusionnée |
| P2-261 | code | SIREN, SIRET et TVA annotés `siren` au banc (texte inchangé) ; comparaison principale sur les types communs, ligne à part pour les identifiants d'entreprise | — | fusionnée |
| P2-262 | code | Reproduire le banc sur une machine neuve : séquence exacte (modèles, ordre, durées) validée et écrite dans `bench/README.md` ; aucun changement de code | — | fusionnée |
| P2-267 | code | Nombres dictés en lettres : seconde vue « lettres → chiffres » (décisions P2-155 du 23 novembre) ; GO si fuite ≤ 5 % par type et 0 masquage à tort sur les témoins | P2-155 | fusionnée |
| P2-263 | code | NIR à clé fausse coupé par une fin de ligne, en chiffres pleine chasse ou groupé 3 × 5 : masqué à 0,3 par la vue de détection | P2-258 | fusionnée |
| P2-264 | mesure | Fuite par OCR (« O » pour 0, « l » ou « I » pour 1) sans libellé, par type, avec le coût en masquages à tort ; rien corrigé | — | fusionnée |
| P2-265 | code | `bench/ETAT.md` contrôlé : un script compare chaque tableau courant à la sortie d'`etat.sh` et échoue au premier écart ; historique à part | — | fusionnée |
| P2-266 | code | Machine neuve : le test d'équivalence dit quelle commande génère `bench/corpus.jsonl` au lieu d'échouer seulement sur « introuvable » | — | fusionnée |
| P2-268 | code | Identifiants lus par OCR (« O » pour 0, « l »/« I » pour 1) : relus dans une suite candidate, gardés si la clé valide ; clé faible seulement derrière un libellé (décision du 23 novembre, nuit) | P2-264 | fusionnée |
| P2-269 | mesure | Presidio rejoué sur les 200 000 documents (au lieu d'être rescoré sur ses prédictions du 21 novembre) ; écarts rapportés, rien corrigé | — | fusionnée |
| P2-270 | mesure | Nombres dictés : témoin durci de phrases ordinaires denses en nombres (montants, horaires, adresses, consignes avec « code ») ; masquages et signalements à tort comptés, rien corrigé | P2-267 | fusionnée |
| P2-271 | code | Nombres dictés : FINESS non couvert en entier quand un nom d'établissement chevauche la lecture (6 à 9 sur 129) | P2-267 | fusionnée |
| P2-272 | mesure | Masquages à tort hérités sur suites denses (14 / 450 au témoin durci de P2-268, dont 10 IBAN « FR » à clé fausse) : coût par détecteur et perte de rappel de chaque garde possible ; rien corrigé | P2-268 | fusionnée |
| P2-273 | code | Nombres dictés : retirer « code » des mots-clés de validation faible (3 → 0 masquage à tort sur le témoin durci de P2-270, aucun effet mesuré sur les variantes dictées) | P2-270 | fusionnée |
| P2-274 | mesure | Nombres dictés : seuil du signalement « non reconnu » (9, 11, 13 mots) : signalements à tort sur le témoin durci contre identifiants dictés non validés signalés ; rien corrigé | P2-270 | fusionnée |
| P2-275 | code | OCR : trous restants de P2-268 (NIR corse « 2A »/« 2B » relu sans libellé, libellé + clé fausse + séparateurs multiples) et témoin durci des mots-nombres dans `etat.sh` | P2-268 | fusionnée |
| P2-276 | code | Gardes à coût nul de P2-272 : `nir_suitelettre`, `finess_suitelettre`, `adr_confusables` (pas `iban_g45`, qui attend le mainteneur) | P2-272 | fusionnée |
| P2-277 | code | IBAN à clé fausse écrit en paires (0 / 40 à la sonde) et adresse « code postal + commune avec arrondissement » (0 / 140) | P2-272 | fusionnée |
| P2-278 | code | Tableau de bord : sonde de P2-272 et identifiants dictés abîmés de P2-274 suivis par `etat.sh` | P2-272, P2-274 | fusionnée |
| P2-279 | mesure | Faux accords par détecteur sur un témoin durci élargi (≥ 5 000 documents) et sur 200 000 documents sans identifiant, avec intervalle ; rien corrigé | P2-272 | fusionnée |
| P2-280 | mesure | Signalement « nombre dicté non reconnu » : critères autres que le nombre de mots (mot voisin « code », « digicode »…) ; rien corrigé | P2-274 | fusionnée |
| P2-281 | code | Régression de P2-275 : 5 IBAN dictés abîmés, recouverts en partie par une entité, ne sont plus signalés « nombre dicté non reconnu » | P2-275 | fusionnée |
| P2-282 | code | Signalement de la dictée coupé par un mot voisin (« code », « digicode », « mot de passe ») à 100 caractères, levé par un libellé d'identifiant (mesure P2-280 : 49 → 0 à tort) | P2-281 | fusionnée |
| P2-283 | code | IBAN de clé juste écrit en paires après « FR » (`FR 24 30 00 …`) : mesure à la sonde puis correction d'`IbanFrDetector` | P2-277 | fusionnée |
| P2-284 | code | Tableau de bord : faux accords par détecteur de P2-279 (5 000 + 5 600 documents) suivis par `etat.sh` | P2-279 | fusionnée |
| P2-285 | mesure | Établissement masqué dans des phrases sans personne (3,98 % sur 200 000 : « SSIAD à Angers ») : décompte par forme, rien corrigé | P2-279 | fusionnée |
| P2-286 | code | Démo `ecluse_demo` : encart « ce que disent les mesures » (chiffres de l'article v2, avec leurs réserves) et troisième exemple « note de liaison » (NIR à clé fausse, IBAN aux espacements irréguliers, sigles sans personne) | — | fusionnée |
| P2-287 | mesure | Rapport de risque : un mot courant en tête de phrase lu comme commune (« Son numéro… » → lieu « Son », F = 89) ; décompte sur les corpus, rien corrigé | — | fusionnée |
| P2-288 | mesure | Faux accords IBAN à clé fausse 89 → 102 sur le témoin élargi de P2-279 : rejouer avant et après P2-277 et P2-283, cause par gabarit ; rien corrigé | P2-284 | fusionnée |
| P2-289 | code | Établissements : la classe `[A-ZÀ-Ÿ]` contient les minuscules accentuées, « à » est absorbé (« CHU à Lille ») ; majuscules seulement (mesure P2-285 : 5 902 → 0) | P2-285 | fusionnée |
| P2-290 | mesure | Détecteur d'établissements corrigé (P2-289) sur les variantes de casse et de mise en page du corpus flou ; rien corrigé | P2-289 | fusionnée |
| P2-291 | code | Tableau de bord : signalements « nombre dicté non reconnu » à tort suivis par `etat.sh` (durci 630, neuf graine 43, origine 300) | P2-282 | fusionnée |
| P2-292 | mesure | Coût réel de la garde du mot voisin (P2-282) : identifiants dictés abîmés précédés de « code » sans libellé ; rien corrigé | P2-282 | fusionnée |
| P2-293 | mesure | IBAN en paires : sonde élargie aux séparateurs point, tiret, barre et aux confusions d'OCR ; coût des gardes de P2-288 ; rien corrigé | P2-288 | fusionnée |
| P2-294 | code | Établissements en 60 colonnes : « IME La Source », « CH de Vesoul », « SSIAD de Gray » non couverts en entier sur le flou réaliste | P2-289 | bloquée |
| P2-295 | spec | « Type + mot générique » (« Résidence Autonomie », 2 063 / 200 000) : options chiffrées pour la décision du mainteneur | P2-289 | fusionnée |
| P2-296 | mesure | Faux tableau à 60 colonnes : 3 documents sur 400 du flou réaliste refusés (« ligne 7 : 3 colonnes au lieu de 2 ») ; cause, et coût d'une règle plus stricte sur les tableaux de noms ; rien corrigé | — | fusionnée |
| P2-297 | mesure | Établissements en majuscules : 69 / 400 (réaliste) et 98 / 114 (adversarial) couverts sans aucune entité `etablissement` ; par quoi ils sont couverts, et ce qui partirait si ce type-là manquait ; rien corrigé | P2-290 | fusionnée |
| P2-298 | code | Témoin de 480 documents : `bench/COMPARATIF.md` et `bench/ARTICLE.md` disent encore 16 / 480 pour Écluse ; remesurer et mettre à jour (9 / 480 attendu après P2-289) | P2-290 | fusionnée |
| P2-299 | code | Garde du mot voisin (P2-282) : la coupure du signalement devient un avertissement distinct (décision du 26 novembre, point 3) | P2-292 | à faire |
| P2-300 | code | Gardes de P2-272 : `nir_suitelettre`, `finess_suitelettre`, `adr_confusables`, et `iban_g45` avec avertissement (décision du 26 novembre, points 0 et 1) | P2-272 | à faire |
| P2-301 | code | Établissements : liste fermée « type + mot générique » non masqués (décision du 26 novembre, point 5) | P2-295 | à faire |
| P2-302 | code | Rapport de risque : liste d'exclusion des mots courants en tête de phrase lus comme commune (décision du 26 novembre, point 6) | P2-287 | à faire |
| P2-303 | mesure | Inventaire des gardes existantes qui retirent un masquage sans avertissement (principe du 26 novembre, point 0) ; rien corrigé | — | à faire |

La phase 3 sera découpée ici quand la phase 2 sera fusionnée.

---

## Fiches détaillées

Les fiches des tâches fusionnées sont dans `agent/QUEUE-archive.md` (historique, à ne lire que si une fiche ouverte y renvoie).

### P2-86 à P2-101 — Fin de la phase 2

Découpage : `agent/specs/P2-decoupage-fin.md` (fusionné le 2 novembre 2026).
Chaque tâche y a sa ligne, son bloc et ses bloquants ; les fiches ci-dessous
ne reprennent que ce qui manque pour la prendre.

- **P2-161** : regroupée dans P2-160 le 12 novembre (une seule PR pour les
  deux corpus de dictée).
- **P2-163** : regroupée dans P2-159 le 12 novembre (une seule PR pour les
  âges).

- **P2-184** : adresses, chemin `Ecluse.redact`. Spec `agent/specs/P2-182.md`
  § 1.1, § 5 pistes A et C : 71 des 74 faux positifs du témoin cinq chiffres
  (P2-167, P2-177) seraient écartés si le mot qui suit le nombre n'est pas une
  commune de `geo_communes.csv.gz`. La table est **chargée par l'appelant** et
  passée en option de `Ecluse.redact`, comme `prenomsInsee` ; jamais chargée
  par défaut ni à l'intérieur d'un détecteur. Sans l'option, aucun
  comportement ne change. La vérification **s'ajoute** aux règles existantes
  et ne fait que retirer un faux positif : une commune absente de la table
  (faute d'orthographe, lieu-dit, ancienne commune) garde sa détection
  actuelle. Test d'abord : ligne du témoin avec l'option au tableau de bord,
  chiffre de départ 74. **Fini quand** : témoin avec l'option 74 → 3 ou
  moins ; témoin sans l'option inchangé ; jeu de 432 adresses de P2-177 et
  corpus flous : 0 adresse perdue avec l'option ; coût de chargement et de
  recherche écrits dans la PR ; `LIMITES.md` et README d'`ecluse_redact`
  (l'option et ce qu'elle ne couvre pas) à jour. La démo n'active pas l'option
  dans cette tâche.
- **P2-185** : adresses, branche « tout en capitales » d'`AdresseDetector`.
  Rapport `agent/specs/P2-183.md` § 3.1 et § 4 tâche A : 2 222 communes
  (6,4 % du référentiel) sont écartées en entier en capitales parce que leur
  premier mot est un déterminant. Distinguer « 70000 LA » seul (rejet,
  comportement actuel correct) de « 01097 LA BOISSE » (un second mot de
  commune suit : accepter). Test d'abord : mettre le balayage « tout
  capitales » de P2-183 au tableau de bord, chiffre de départ. **Fini
  quand** : cause « déterminant initial » du balayage en capitales proche de
  0 (chiffre exact dans la PR) ; témoin en capitales de P2-122 toujours à 0 ;
  témoin cinq chiffres et reste du tableau de bord inchangés ; `LIMITES.md`
  à jour. Si « LE SERVICE DES ADMISSIONS », « LES 3 PREMIERS » ou une forme
  proche revient comme adresse, s'arrêter et rapporter les deux mesures.
- **P2-195** : `AdresseDetector`, branche « tout en capitales ». Constat de
  #403 : en capitales, après « 12345 LE SERVICE », la « commune » avale tous
  les mots qui suivent ; témoin P2-187 en capitales : 107 phrases sur 200
  masquées en trop. Règle commune de `DECISIONS.md` : dans le doute, le côté
  qui protège ; on ne retire un masquage que s'il ne coûte aucune commune.
  Test d'abord : cas de phrase longue en capitales où la commune s'arrête
  (fin de ligne, ponctuation, mot neutre, nombre). **Fini quand** : sur le
  balayage des communes en capitales, adresses en partie en clair ≤ 95 et
  cause « déterminant initial » ≤ 10 (aucune régression) ; témoin P2-187 en
  capitales sous 107 / 200, chiffré avant/après ; longueur moyenne du span
  masqué en trop chiffrée avant/après ; `LIMITES.md` à jour ; reste du
  tableau de bord inchangé.
- **P2-195** (décision du 15 novembre) : abandonnée. Le critère « témoin sous
  107 / 200 » n'est pas atteignable par une borne (#409) ; le masquage en trop
  des phrases « cinq chiffres + déterminant + mot » en capitales est le prix
  assumé de P2-187. La liste de deuxièmes mots n'est pas retenue : une commune
  mal lue repasserait en clair.
- **P2-212** : `mots_neutres.dart` (`ecluse_redact`). Constat de #427 : la
  liste n'a que les formes accentuées (« numéros », « salariés »,
  « résidents ») ; en capitales sans accent, « 39314 NUMEROS EN ATTENTE » est
  masqué en adresse (35 / 469 lignes de la famille « quantité »). Test
  d'abord, rouge sur `main`. Une forme sans accent n'est ajoutée que si elle
  n'est pas aussi un nom de commune du référentiel versionné ; sinon la
  laisser et le dire. **Fini quand** : témoin des courriers (P2-210) à 0
  ligne masquée en trop ; témoin de P2-211 chiffré avant/après ; balayages de
  communes (avec et sans CEDEX) et témoins P2-167, P2-187, P2-200 inchangés
  ou meilleurs : aucune commune perdue ; reste du tableau de bord inchangé.
- **P2-216** : refactor sans changement de comportement, `ecluse_redact`,
  `lib/src/ecluse.dart` (1 378 lignes : liste des détecteurs, `redact`,
  `detect`, appliquer les remplacements, `restore`, normalisation Unicode et
  coupures de ligne, identités de noms et genre, état d'une session). Le
  graphe du 15 novembre le donne comme le fichier le moins cohérent du
  paquet. Étape 0 : écrire dans la PR la liste des symboles publics exportés
  par `ecluse_redact.dart` avant le découpage. Découper par responsabilité
  (par exemple : normalisation du texte ; identités de noms ; restauration ;
  état de session ; le reste dans `ecluse.dart`), dans des fichiers de
  `lib/src/`. Les noms privés (`_x`) ne passent pas d'un fichier à l'autre :
  utiliser `part` / `part of`, ou rendre publics dans `src/` (non exportés) les
  seuls noms nécessaires ; dans les deux cas rien de nouveau dans
  `ecluse_redact.dart`. Un fichier à la fois, `test` entre chaque. Ne
  renommer ni reformater rien d'autre, ne changer aucune expression régulière
  ni aucun seuil. Dépend de P2-214 (dernier changement de ce paquet en cours).
  **Fini quand** : plus aucun fichier de `lib/src/` de ce découpage au-dessus
  de 600 lignes ; liste des symboles publics identique avant/après ; `format`,
  `analyze`, `test` verts ; `etat.sh` strictement inchangé par rapport à
  `main` ; aucun test modifié (sauf imports) ; `DECISIONS.md` ni `LIMITES.md`
  touchés.
- **P2-217** : documentation seulement, aucun `lib/` modifié. `LIMITES.md`
  fait 2 065 lignes, dont plus de 1 000 pour la seule section des entités
  coupées (§ 5.2) : un lecteur (DPO, client, agent) ne peut pas y trouver ce
  qu'Écluse ne fait pas. Mettre en tête un **résumé de deux pages au plus** :
  ce qu'Écluse ne fait pas, par grandes familles (formats hors périmètre,
  limites de détection, fuites résiduelles, restauration), chaque ligne
  renvoyant à son paragraphe détaillé, phrases courtes, sans jargon, même
  honnêteté que le détail (« réduit le risque, ne l'annule pas »). Le détail
  reste dessous, **sans suppression ni reformulation** ; seuls les titres et
  les ancres peuvent changer, et chaque lien interne du dépôt vers
  `LIMITES.md` (README, `DECISIONS.md`, specs) doit rester valide. Si la
  section 5.2 gagne à être découpée en sous-sections, le faire par titres
  seulement. Dépend de P2-212 et de P2-214 (elles modifient `LIMITES.md`).
  **Fini quand** : le résumé tient en deux pages ; tout paragraphe du détail
  a un renvoi depuis le résumé ou une raison écrite de ne pas en avoir ; un
  contrôle (script ou relecture, décrit dans la PR) montre que le texte du
  détail est identique à celui de `main` hors titres ; liens internes
  vérifiés ; `format`, `analyze`, `test` verts et tableau de bord inchangé.
- **P2-218** : mesure seulement, rien dans `lib/`. Sonde non versionnée du
  17 novembre : sur 54 documents du corpus de dossiers réaliste (11 dossiers
  entiers, graine 42), `Ecluse.redact` appelé **document par document** laisse
  en clair 16 noms sur 83, tous des patronymes seuls, sans civilité ni prénom,
  dans une pièce où la personne n'a pas encore été nommée (« le dossier de
  Maillard est transmis », « à la demande de Sabatier », « Rambaud a
  confirmé ») ; avec la session de dossier, 83 sur 83 ; l'option
  `prenomsInsee` n'y change rien. **Fini quand** : `etat.sh` donne, sur le
  corpus de dossiers réaliste entier, le nombre de noms manqués hors civilité
  en appel document par document et en session, ventilé par tournure qui
  précède ou suit le nom ; un témoin versionné, graine 42, d'au moins 400
  phrases sans nom de personne construites sur les mêmes tournures (« le
  dossier de presse », « à la demande de Paris », « l'entretien avec
  succès ») ; chiffres de départ dans `bench/ETAT.md` ; aucune correction.
- **P2-219** : spec seulement (`agent/specs/P2-219.md`), aucun code de
  production. Dans un dossier, les patronymes établis par les pièces
  précédentes amorcent le détecteur de noms (`_detecteursAvecPatronymes`,
  P2-14). Une application connaît souvent ces noms d'avance (liste de
  patients, de salariés, planning). Décrire : la forme d'une option publique
  qui reçoit cette liste ; ce qu'elle masque et ne masque pas (casse, noms
  composés, noms qui sont aussi des mots courants, homonymes de communes) ;
  ce que la liste devient (jamais journalisée, jamais dans un message
  d'erreur ni un `toString`, même règle que la table de correspondance) ;
  l'effet sur l'API publique et sur `descriptionMoteur` ; le coût en temps
  pour 10 000 noms. **Fini quand** : au moins deux options comparées, une
  recommandation, les décisions à prendre par le mainteneur listées, et le
  protocole de mesure (corpus et témoin de P2-218) écrit.
- **P2-220** : détecteur de noms (`ecluse_redact`), chemin `Ecluse.redact`.
  Test d'abord : un cas rouge par tournure retenue de P2-218. Ne retenir une
  tournure que si le témoin de P2-218 le permet ; le mot candidat doit
  commencer par une majuscule hors début de phrase et ne pas être une commune
  ni un mot de `mots_neutres.dart`. Dans le doute, masquer, mais dire le coût.
  **Fini quand** : noms manqués de P2-218 (document par document) divisés par
  quatre au moins ; témoin de P2-218 : au plus 1 % de phrases masquées à
  tort, chaque cas restant expliqué ; témoins de noms existants et reste du
  tableau de bord inchangés ou meilleurs ; `LIMITES.md` à jour. Si les deux
  seuils ne tiennent pas ensemble, s'arrêter et donner les chiffres dans la
  PR.
- **P2-221** : spec seulement (`agent/specs/P2-221.md`). Sur le modèle de
  l'option `prenomsInsee` (P2-149 à P2-151). Lire la licence de la source
  envisagée (fichier des noms de famille de l'INSEE) ; si la page n'est pas
  joignable, le dire et ne rien affirmer. Chiffrer sur le témoin de P2-218 et
  sur les témoins existants ce que coûterait une table seule (noms qui sont
  aussi des mots : « Marchand », « Petit », « Boulanger »), puis adossée à un
  contexte de personne (P2-220). Aucune donnée ajoutée au dépôt à ce stade.
  **Fini quand** : source, licence et taille écrites dans la spec (et le
  projet de ligne pour `DATA_SOURCES.md`) ; coût simulé hors `lib/` ;
  recommandation (faire, ne pas faire, à quelles conditions).
- **P2-222** : spec seulement (`agent/specs/P2-222.md`). Dire, code lu, si
  `ecluse_demo` (serveur du sas) et `integrations/claude-code/ecluse-sas`
  utilisent une session de dossier quand plusieurs textes se suivent, et
  sinon ce qu'il faudrait changer. Traiter : quand ouvrir et fermer un
  dossier, ce qui reste en mémoire et combien de temps, le risque de mêler
  deux personnes ou deux dossiers (collisions, fausses fusions de
  `score_dossiers.py`), l'effet sur `restore`. **Fini quand** : état des lieux
  avec fichiers et lignes ; une proposition et son plan de mesure ; les
  décisions à prendre par le mainteneur listées.
- **P2-223** : mesure seulement, rien dans `lib/`. P1-03 avait analysé la
  collision FINESS / SIREN ; la sonde du 17 novembre trouve encore 3 SIREN
  masqués comme FINESS sur 50 documents du corpus v3 (« Le SIREN de la société
  est … »). **Fini quand** : `etat.sh` donne le nombre de SIREN masqués en
  FINESS sur le corpus v3 entier et sur un témoin versionné de 400 phrases à
  SIREN (avec et sans le mot « SIREN » à proximité) ; les options sont
  chiffrées hors `lib/` (libellé « SIREN » ou « SIRET » avant le nombre, clé
  de Luhn du SIREN) avec, pour chacune, le nombre de vrais FINESS perdus ;
  chiffres de départ dans `bench/ETAT.md` ; aucune correction.
- **P2-224** : mesure seulement. Rendre reproductible la sonde du
  17 novembre : un script dans `bench/` tire, graine 42, 50 documents du
  corpus v3, des dossiers entiers du corpus réaliste jusqu'à 50 documents, et
  une moitié à adresses et dates de naissance annotées (corpus existants du
  banc), puis note chaque outil sur le texte qu'il laisse passer : `Ecluse.redact`
  document par document, en session de dossier, Presidio par défaut, Presidio
  configuré en français, spaCy `fr_core_news_lg` seul, règles d'EDS-Pseudo
  (`simple_rules`, `addresses`, `dates`). Dépendances autorisées pour cette
  tâche, dans un fichier séparé `bench/requirements-comparatif.txt` (jamais
  dans `requirements.txt`) : `edsnlp`, `eds-pseudo`, les modèles spaCy
  `fr_core_news_lg` et `en_core_web_lg`. Règle de score : entité entièrement
  couverte, quel que soit le type prédit ; civilité retirée des noms ;
  masquages à tort comptés sur les documents sans entité. Le script ne tourne
  pas dans `etat.sh`. **Fini quand** : tableau par outil et par type dans
  `bench/COMPARATIF.md`, avec la commande exacte, les versions, et un
  paragraphe « ce que ce comparatif ne dit pas » (corpus produits par le
  projet, petit échantillon, outils non mesurés) ; aucun chiffre repris dans
  le README ni dans l'article.
- **P2-225** : `humain`. Les modèles GLiNER et le modèle entraîné
  d'EDS-Pseudo ne sont pas téléchargeables en session cloud. À lancer sur le
  poste du mainteneur avec le script de P2-224, puis compléter
  `bench/COMPARATIF.md`.

### P2-226 à P2-231 — Faux masquages des tournures de personne (après P2-220)

Contexte : sonde à la main du 17 novembre (200 phrases, 50 mots, non
versionnée), `Ecluse.redact` document par document, après P2-220 : mots de
rôle et de parenté masqués comme nom dans 32 cas sur 40 (« Madame »,
« Monsieur », « Médecin », « Famille », « Fils », « Tuteur », « Maman »,
« Kiné » ; « Patient » et « Résident », statuts, épargnés) ; organismes 32 sur
40 (« France Travail », « Emmaüs », « Doctolib », « Croix-Rouge ») ; patronymes
qui sont aussi une commune de 10 000 habitants et plus encore en clair dans 16
cas sur 20 (« Gaillard », « Laval », « Fontaine »). Avant P2-220 : 0 sur 40
dans les deux premières familles. Le témoin de P2-218 (12 noms communs) ne
voit rien de cela. Pistes écartées par la même analyse : repérer les
intitulés (tous les faux masquages sont en pleine phrase) ; exiger un second
indice dans le document (ces noms n'en ont pas, sinon ils étaient déjà
rattrapés avant P2-220).

- **P2-226** : mesure seulement. Générateur versionné dans `bench/`, graine
  42, mêmes quatre tournures que P2-220 et mêmes gabarits que P2-218, cinq
  familles d'au moins 20 mots chacune, choisis par l'agent, **sans reprendre
  les 12 noms communs du témoin de P2-218** : mots de rôle et de parenté
  (civilités seules, parenté, fonctions soignantes et sociales, style
  télégraphique sans article) ; organismes et marques, d'un ou deux mots ;
  noms communs à majuscule ; patronymes qui sont aussi une commune de 10 000
  habitants et plus ; patronymes qui sont aussi un nom commun (« Berger »,
  « Boulanger »). Les deux dernières familles sont des noms de personne
  annotés (fuite si non masqués) ; les trois premières n'en contiennent pas.
  Valeurs synthétiques uniquement (règle 1). Scoreur, test Python, ligne dans
  `etat.sh`. **Fini quand** : `etat.sh` donne, par famille et par tournure, le
  nombre de mots masqués (`Ecluse.redact`, document par document) ; chiffres
  de départ dans `bench/ETAT.md` ; aucune correction.
- **P2-227** : détecteur de noms (`ecluse_redact`), même règle que les
  statuts déjà exclus. Liste fermée, écrite par le projet, justifiée par la
  langue (civilités, parenté, fonctions), **pas** calée mot à mot sur le
  témoin de P2-226 : le dire dans le commentaire de doc et vérifier qu'au
  moins un mot de rôle du témoin est hors de la liste pour mesurer la
  généralisation. Test d'abord. **Fini quand** : famille « rôles » de P2-226
  divisée par quatre au moins ; patronymes seuls manqués de P2-218 toujours au
  plus 4 sur 116 ; familles de patronymes de P2-226 et reste du tableau de bord
  inchangés ou meilleurs ; `LIMITES.md` à jour.
- **P2-228** : détecteur de noms. Derrière « l'entretien avec », « le
  dossier de » et devant « a confirmé », ne plus écarter un mot parce qu'il est
  une commune de 10 000 habitants et plus ; garder l'exclusion après « à la
  demande de ». Test d'abord. Dire le coût (« Paris a confirmé » masqué).
  **Fini quand** : famille « patronymes-communes » de P2-226 masquée en
  entier derrière ces trois tournures ; famille « lieu » du témoin de P2-218 :
  coût chiffré, chaque cas expliqué ; reste du tableau de bord inchangé ou
  meilleur ; `LIMITES.md` à jour.
- **P2-229** : détecteur de noms. Liste fermée d'organismes nationaux et de
  services publics ou associatifs courants dans le soin et le social, écrite
  par le projet (aucune donnée externe ajoutée). Même règle de
  généralisation que P2-227. **Fini quand** : famille « organismes » de P2-226
  divisée par quatre au moins ; patronymes de P2-218 et de P2-226 inchangés ;
  reste du tableau de bord inchangé ou meilleur ; `LIMITES.md` à jour.
- **P2-230** : spec seulement (`agent/specs/P2-230.md`), code lu
  (`apercu.dart`, confiance des entités de `NameDetector`). Décrire comment
  l'aperçu signalerait « à vérifier » un nom établi par une seule tournure,
  sans rien démasquer par défaut ; effet sur l'API publique et sur
  `descriptionMoteur` ; ce qui n'apparaît jamais (valeur du texte dans un
  message ou un `toString`). **Fini quand** : au moins deux options comparées,
  une recommandation, les décisions du mainteneur listées.
- **P2-231** : `humain`. Lecture des licences, mise à jour le 21 novembre
  après P2-242 (une liste de verbes écrite à la main généralise mal : 344
  verbes ajoutés, 180 sur 200 et 630 sur 680 verbes de réserve encore
  masqués). Trois ressources : (1) fichier des noms de famille de l'INSEE
  (P2-221) ; (2) Lefff, lexique des formes fléchies du français (Inria),
  distribué sous LGPL-LR ; (3) Morphalou (ATILF, CNRS), en accès libre « sous
  acceptation de la licence », licence non lue. Question à trancher pour (2)
  et (3) : un fichier dérivé (liste des formes verbales) peut-il vivre dans un
  dépôt Apache 2.0, dans un fichier séparé sous sa propre licence, déclaré dans
  `DATA_SOURCES.md` ? Un lexique seul de noms communs est écarté (9 patronymes
  sur 10 de la sonde du 17 novembre sont aussi des noms communs). Si les
  licences le permettent, une tâche de code : lexique de verbes (aucun verbe
  masqué derrière un prénom, quelle que soit la forme) et règle de forme de
  P2-241 limitée aux mots absents du référentiel de patronymes.

### P2-232 — Signal « à vérifier » dans l'aperçu (décisions du 19 novembre)

- **P2-232** : `ecluse_core` (champ de provenance) et `ecluse_redact`
  (`NameDetector`, `apercu.dart`), selon `agent/specs/P2-230.md` et les
  décisions de `DECISIONS.md` du 19 novembre : option A, sens strict (§ 4 de la
  spec), libellé « à vérifier », aucun compte dans le journal, version du
  moteur inchangée. Le champ est une énumération fermée, jamais une chaîne
  libre ; il est propagé par les copies d'entité du moteur et de `ecluse.dart`
  (spec § 5), avec un test qui échoue s'il est perdu. Test d'abord : une entité
  de tournure seule (`aVerifier` vrai), puis le même mot avec une civilité
  ailleurs dans le texte (faux), puis établi dans un document précédent du
  `Dossier` (faux). **Fini quand** : `aVerifier` exact sur les 4 cas de § 4 de
  la spec ; `maskedText` et `mapping` de `Ecluse.redact` identiques octet pour
  octet sur tous les corpus du tableau de bord ; `descriptionMoteur` et
  `versionMoteur` identiques ; aucun `toString`, message ou sortie console avec
  une valeur du texte (un test par voie, spec § 7) ; `LIMITES.md` § 6 à jour
  (« l'aperçu est un confort, pas une garantie ») ; décompte rejoué, chemin
  `Apercu.propose` : corpus de P2-226 (307 signalés au plus, vrais patronymes et
  autres mots rapportés séparément) et corpus v3 (nombre signalé sur les noms
  proposés).

### P2-233 à P2-237 — Suites des tournures de personne et dette (19 novembre)

- **P2-233** : mesure seulement. Après P2-228, derrière « à la demande de », les
  grandes communes sont encore écartées : 24 patronymes-communes sur 96 du
  témoin de P2-226 restent en clair (fuites), alors que l'exclusion protège les
  phrases `lieu` du témoin de P2-218 (« à la demande de Paris »). Chiffrer hors
  `lib/`, sur ces deux témoins et le corpus de dossiers, au moins trois options
  (par exemple : seuil d'habitants plus haut ; communes chefs-lieux seulement ;
  indice voisin de lieu ou de personne dans la phrase ; ne plus rien écarter),
  avec pour chacune les fuites restantes et les lieux masqués à tort.
  **Fini quand** : tableau des options dans `bench/ETAT.md`, une recommandation,
  aucune correction ; chemin `Ecluse.redact` document par document.
- **P2-234** : détecteur de noms. Les 43 organismes masqués à tort du témoin de
  P2-226 (11 / 10 / 11 / 11 par tournure) : classer d'abord les causes (mot
  absent de la liste de P2-229, organisme de deux mots dont un seul mot est
  reconnu, marque) dans la PR, puis corriger celles qui relèvent d'une règle,
  **sans** ajouter mot à mot les organismes du témoin (même règle de
  généralisation que P2-227 et P2-229 : au moins un organisme du témoin reste
  hors liste). Test d'abord. **Fini quand** : famille `organismes` divisée par
  deux au moins, chaque cas restant expliqué ; familles de patronymes, témoin de
  P2-218 et corpus de dossiers (1 manqué sur 116) inchangés ou meilleurs ; reste
  du tableau de bord inchangé ; `LIMITES.md` à jour.
- **P2-235** : mesure seulement. La spec P2-230 (§ 11) a vu « Sophie
  rappelle. » proposé comme un seul nom de 0 à 15 (confiance 0,5). Trouver la
  règle qui le produit, compter sur les corpus existants combien d'entités `nom`
  débordent sur un verbe ou un mot courant (chemin `Ecluse.redact`), et dire si
  c'est voulu (commentaire de doc, décision) ou un défaut. **Fini quand** :
  règle citée, compte dans `bench/ETAT.md`, verdict argumenté ; aucune
  correction.
- **P2-236** : test seulement (`packages/ecluse_redact/test/adresse_cedex_test.dart`,
  test « coût linéaire »). Le plafond fixe `lessThan(15000)` dépend de la
  machine. Le remplacer par un rapport : temps pour 2 N lignes au plus k fois le
  temps pour N lignes (k justifié dans le commentaire, médiane de plusieurs
  répétitions), sur le modèle d'un test de croissance déjà présent s'il en
  existe un ; chercher les autres plafonds fixes du même genre et les lister
  dans la PR. **Fini quand** : le test échoue sur une version quadratique
  simulée (à montrer dans la PR, sans la committer) et passe sur `main` ; aucun
  fichier de `lib/` modifié ; durée du test au plus égale à l'actuelle.
- **P2-237** : mesure seulement. Depuis P2-212 (#436), le témoin « commune
  suivie » (P2-181) donne 5 376 caractères masqués au lieu de 5 379, sans
  adresse en partie en clair. Trouver le ou les documents concernés et la règle
  responsable, dire si l'écart est une fuite, un masquage plus juste ou neutre.
  **Fini quand** : documents et règle cités dans `bench/ETAT.md`, verdict ;
  aucune correction.

### P2-238 à P2-240 — Suites de P2-233 et P2-235 (décisions du 20 novembre)

- **P2-238** : mesure seulement. Ajouter au témoin des tournures (même
  générateur que P2-218 ou P2-226, graine 42) une famille de lieux tirés du
  référentiel versionné, communes de 10 000 à 100 000 habitants, au moins 40
  noms répartis par tranche (10–30 000, 30–50 000, 50–100 000), derrière « à la
  demande de » et les trois autres tournures. Chiffrer hors `lib/` les seuils
  10 000 (`main`) et 100 000. **Fini quand** : par tranche et par seuil, lieux
  masqués à tort dans `bench/ETAT.md`, chemin `Ecluse.redact` document par
  document ; aucune correction.
- **P2-239** : détecteur de noms. Après « à la demande de », n'écarter que les
  communes de 100 000 habitants et plus (table dérivée du référentiel versionné,
  par le même script que `communes_grandes.dart`, test de parité). Test
  d'abord. **Fini quand** : famille `patronymes_communes` de P2-226 sans fuite
  derrière « à la demande de » ; lieux masqués à tort sur le témoin élargi de
  P2-238 rapportés par tranche et égaux à la simulation de P2-238 ; corpus de
  dossiers et reste du tableau de bord inchangés ou meilleurs ; `LIMITES.md` à
  jour. Le garde-fou de 50 % est **levé** (décision du 20 novembre, après
  P2-238 : 60 sur 60 villes de 10 000 à 100 000 habitants masquées à tort
  derrière « à la demande de » au seuil de 100 000) : ce coût est assumé et
  écrit dans `LIMITES.md`.
- **P2-240** : `NomMinusculesDetector`, branche « prénom connu suivi d'un mot »
  (P2-119, P2-124), et `patronymeEtabli`. Test d'abord, avec la sonde de P2-235
  rendue reproductible dans `bench/` (400 phrases « Prénom verbe. », graine
  42) et l'effet en chaîne (« Sophie rappelle. Elle rappelle demain. », et en
  dossier). Écarter un mot suivant qui est un verbe conjugué, par une règle de
  forme justifiée (terminaisons, liste fermée de verbes courants écrite par le
  projet), sans rendre en clair un patronyme qui ressemble à un verbe : le
  mesurer sur les témoins de noms existants. Exigence du mainteneur (20 novembre) : **aucun verbe ne
  doit être masqué**, le LLM en a besoin pour travailler sur le texte. Un
  patronyme qui a la forme d'un verbe conjugué (homographe) passe donc en clair
  derrière un prénom : en dresser la liste mesurée dans la PR et l'écrire dans
  `LIMITES.md` comme fuite connue. **Fini quand** : sonde 340 → **0** ; le verbe n'est plus masqué ailleurs ni dans le document suivant d'un
  dossier ; témoins de noms, familles de patronymes de P2-226 et corpus de
  dossiers inchangés ou meilleurs (aucune fuite ajoutée) ; `LIMITES.md` à jour.

### P2-241 — Aucun verbe masqué, règle de forme (décision du 20 novembre)

- **P2-241** : `NomMinusculesDetector`, branche « prénom connu suivi d'un mot »,
  et `patronymeEtabli`. P2-240 n'écarte que les 177 formes de sa liste
  (réserve hors liste : 200 sur 200 verbes encore masqués). Règle décidée :
  quand le texte est à casse normale (casse de phrase, `casse.dart`), un
  prénom n'est **jamais** étendu sur le mot suivant s'il est en minuscule ; la
  branche reste inchangée pour les textes entièrement en minuscules. **Mesure
  d'abord** (dans la PR, avant le code) : sur tous les corpus du tableau de
  bord, combien de noms annotés « Prénom nom-en-minuscule » dans un texte à
  casse normale passeraient en clair (coût : fuite d'un patronyme écrit en
  minuscule). Test d'abord. **Fini quand** : famille `reserve` de la sonde de
  P2-240 à 0 sur 200, famille `courants` toujours à 0 ; fuites ajoutées
  comptées et listées par corpus, écrites dans `LIMITES.md` ; textes tout en
  minuscules inchangés ; reste du tableau de bord inchangé ou expliqué ligne
  à ligne. Si la mesure préalable montre plus de 1 % des noms d'un corpus
  existant rendus en clair, s'arrêter et rendre les chiffres.

### P2-242 — Étendre la liste des verbes (décision du 21 novembre)

- **P2-242** : `verbes_conjugues.dart` et `NomMinusculesDetector`. Suite de
  P2-241 (règle de forme bloquée : +154 noms en partie en clair, 25,9 %, sur
  le corpus adversarial en casse de phrase). Décision : étendre la liste fermée
  de P2-240, **sans aucune fuite ajoutée** ; la règle de forme reviendra avec un
  référentiel de patronymes (après P2-231). Étendre aux verbes courants de
  l'écrit soignant et social (transmissions, comptes rendus) et à leurs formes
  conjuguées usuelles (présent, passé composé avec participe, imparfait,
  futur, 3e personne du singulier et du pluriel), plus les terminaisons qui ne
  rendent en clair **aucun** nom annoté d'aucun corpus (le mesurer, une
  terminaison à la fois). Généralisation : ne pas reprendre mot à mot les 20
  verbes de la réserve de P2-240 ; ajouter à la sonde une seconde réserve d'au
  moins 60 verbes, écrite avant la liste et contrôlée absente par un test.
  Test d'abord. **Fini quand** : famille `courants` à 0 ; réserve de P2-240
  au plus 100 sur 200 et seconde réserve mesurée, chiffres dans
  `bench/ETAT.md` ; noms en clair (entier ou en partie) inchangés sur tous les
  corpus flous et de dossiers, prénoms de la sonde à 0 ; reste du tableau de
  bord inchangé ou expliqué ligne à ligne ; `LIMITES.md` à jour (la liste ne
  couvre pas tout).

### P2-243 à P2-245 — Décisions du 21 novembre

- **P2-243** : `ecluse_redact`, selon `agent/specs/P2-219.md` et les
  décisions de `DECISIONS.md` du 21 novembre : option **B**
  (`Dossier(patronymesConnus: …)`), type opaque de la § 4.1 (`toString` qui ne
  donne que le nombre, pas d'`==`, `jsonEncode` refusé, `vider()` appelé par
  `fermer()`) ; une commune présente dans la liste est masquée ; aucun compte
  dans le journal d'audit, schéma inchangé, limite écrite dans `LIMITES.md`
  § 8 ; entrée invalide (vide, un seul mot de moins de deux lettres, sigle
  exclu, plus de N mots) **refusée à la construction avec un motif, sans la
  valeur** ; la liste n'amorce pas `NomMinusculesDetector` (casse de titre et
  capitales seulement) ; `ajouterPatronymes` sur le dossier pour une liste qui
  grandit ; noms à particule (« de La Fontaine ») et deux noms contigus écrits
  comme limites dans `LIMITES.md`. Test d'abord : sortie octet pour octet
  identique sans liste (corpus v3 et dossiers). **Fini quand** : protocole de
  la § 7 de la spec appliqué (liste exacte, large, sans la bonne personne ;
  noms manqués et masqués à tort au témoin), chiffres dans `bench/ETAT.md` ;
  un test par voie de fuite (exception, `toString`, journal) ; reste du
  tableau de bord inchangé.
- **P2-244** : `AdresseDetector`, table réduite seulement (spec P2-215,
  option 1) : « ST »/« STE » lus « SAINT »/« SAINTE », puis comparaison des
  noms collés (sans espaces) pour absorber apostrophe et tiret perdus. Pas de
  distance d'édition (option 2 reportée, après un témoin de noms longs). Test
  d'abord. **Fini quand** : sur le corpus de la spec, 388 → 280 au plus et les
  trois écritures « ST », apostrophe collée, tiret collé à 0 ; témoins cinq
  chiffres, déterminant, mot neutre devant CEDEX, courriers, noms de forme
  neutre inchangés ; reste du tableau de bord inchangé ; `LIMITES.md` à jour.
- **P2-245** : spec seulement (`agent/specs/P2-245.md`). Un paquet optionnel
  `ecluse_lexique`, sous sa propre licence, fournirait à
  `NomMinusculesDetector` les formes verbales du Lefff (LGPL-LR) ; le cœur et
  `ecluse_redact` restent Apache 2.0 et fonctionnent sans lui. Décrire :
  forme de l'injection (le détecteur reçoit un ensemble de formes, jamais
  d'import du paquet), génération du fichier de formes (script dans `tools/`,
  source et version citées, aucun téléchargement dans la CI), taille estimée,
  fichiers de licence et `DATA_SOURCES.md`, ce que la règle de forme de P2-241
  deviendrait avec ce lexique et avec le référentiel de patronymes (P2-231),
  et ce qu'il faut que le mainteneur vérifie sur la licence. **Aucune donnée
  ajoutée au dépôt.** **Fini quand** : au moins deux options d'architecture
  comparées, une recommandation, les décisions du mainteneur listées.

### P2-246 à P2-248 — Masquages à tort mesurés honnêtement (décisions du 21 novembre)

Contexte : le comparatif du 21 novembre (`f7a94bb`) compte 11 documents sur
24 « masqués à tort » par Écluse contre 2 pour les règles d'EDS-Pseudo. Relus un
par un, ces 11 cas sont : 3 noms de personnes non annotés (« Rappel : Nadia Roux
est attendu… », laissés en clair par EDS-Pseudo), 1 numéro de dossier, 1
téléphone, 3 IBAN à clé invalide, 3 SIREN lus comme FINESS. Le corpus v3
n'annote que les identifiants : la ligne compare donc mal.

- **P2-246** : mesure seulement. Générateur versionné (`bench/`, graine 42) d'au
  moins 400 documents réalistes du soin et du social **sans aucune donnée
  personnelle** : consignes de service, comptes rendus de réunion sans nom,
  protocoles, plannings de salles, notes logistiques, courriers types, avec la
  casse ordinaire, des majuscules de titre, des sigles, des numéros non
  personnels (salles, pages, articles de loi, codes de protocole), des marques,
  des villes et des verbes en tête de phrase. Ajouté à `bench/comparatif.py`
  (option ou second échantillon) sans changer l'échantillon existant.
  **Fini quand** : pour les six configurations, documents et caractères masqués
  à tort, par type prédit, dans `bench/COMPARATIF.md` ; pour Écluse, chaque
  famille de masquage à tort décrite (exemple synthétique) ; aucune correction.
- **P2-247** : mesure seulement. Dans l'échantillon du comparatif, annoter
  (annotation propre au comparatif, sans toucher `generate_corpus.py`) les
  données personnelles présentes mais non annotées par le corpus v3 : noms de
  personnes, téléphones, numéros de dossier. **Fini quand** : la ligne « masqués à
  tort » et la couverture recalculées pour les six configurations ; l'ancienne et
  la nouvelle ligne côte à côte dans `bench/COMPARATIF.md`, avec la règle
  d'annotation écrite ; aucune correction.
- **P2-248** : détecteur FINESS. Quand le nombre suit « SIREN » ou « SIRET »
  (mêmes fenêtres que le contexte FINESS existant), l'entité est de type
  `siren` et non `finess`, **toujours masquée** (le SIREN d'un entrepreneur
  individuel désigne une personne). Jeton, restauration et `LIMITES.md` à jour.
  Test d'abord. **Fini quand** : les 42 SIREN du corpus v3 typés `siren` ;
  précision FINESS du benchmark d'identifiants 75,4 % → 100 % sans perte de
  rappel ; aucune entité de moins masquée sur aucun corpus (même couverture au
  caractère) ; reste du tableau de bord inchangé ou expliqué.

### P2-249 à P2-251 — Référentiel de patronymes et lexique de verbes (licences lues le 21 novembre)

Licences (lues le 21 novembre, voir `DECISIONS.md`) : fichier des noms de
l'INSEE sous Licence Ouverte 2.0 (réutilisation libre, y compris commerciale,
mention « Source : Insee » et date de mise à jour) ; Morphalou 3.1 (ATILF, 2023,
159 271 lemmes, 976 570 formes fléchies) sous LGPL-LR.

- **P2-249** : `humain`. Le réseau des sessions refuse insee.fr et ortolang.fr.
  Le mainteneur télécharge (1) le fichier national des noms (page « Fichier des
  noms État civil » de l'INSEE, format txt) et (2) Morphalou 3.1 au format CSV
  « tout en un » (Ortolang), et les dépose dans la conversation de pilotage ;
  les fichiers dérivés, leurs empreintes SHA-256 et les scripts de génération
  (`tools/`) sont ajoutés par une PR distincte, avant P2-250 et P2-251.
- **P2-250** : **abandonnée le 22 novembre** (décision du mainteneur, voir
  `DECISIONS.md`) : le référentiel ne sert qu'à filtrer le lexique de verbes
  (P2-251) ; l'usage (a), sans effet défini, est abandonné. Mesure préalable dans
  `bench/mesure_patronymes_referentiel.py` (#487). Fiche d'origine : `ecluse_redact`. Table de patronymes dérivée de
  `packages/ecluse_reference/assets/patronymes_effectifs.tsv.gz` (versionné le 21
  novembre ; 218 111 noms normalisés avec effectif 1891-2000 ; attention : des
  mots courants y figurent, par exemple « PRESSE », 1 795 naissances : un seuil
  d'effectif est à mesurer, comme pour les prénoms en P2-149), du fichier de
  l'INSEE (noms seuls, sans effectifs, par le script de `tools/`, test de
  parité), mention dans `DATA_SOURCES.md`. Deux usages seulement (décision du
  21 novembre) : (a) confirmer un mot derrière une tournure de personne
  (P2-220) ; (b) règle de forme de P2-241 (« prénom + mot en minuscule » non
  étendu) appliquée seulement aux mots **absents** du référentiel. Jamais pour
  masquer un mot seul. Test d'abord. **Fini quand** : noms communs à majuscule et
  verbes de réserve des témoins de P2-226 et P2-240/P2-242 mesurés avant/après ;
  corpus adversarial en casse de phrase : noms en clair (entier ou en partie)
  inchangés ou en baisse ; patronymes seuls et dossiers inchangés ; reste du
  tableau de bord inchangé ou expliqué ; `LIMITES.md` à jour (noms nés après
  2000 ou attribués moins de 30 fois absents).
- **P2-251** : nouveau paquet `packages/ecluse_lexique`, sous LGPL-LR (fichier
  `LICENSE` complet, mention de modification datée, crédit ATILF), selon la
  recommandation de la spec P2-245 : un fichier de formes verbales dérivé de
  Morphalou 3.1 (script de `tools/`), chargé par l'application et
  **remplaçable** par l'utilisateur ; `ecluse_redact` reçoit un ensemble de
  formes et n'importe jamais le paquet ; le cœur reste Apache 2.0. Test d'abord.
  **Fini quand** : avec le lexique, verbes de réserve de P2-240 et P2-242 à 0
  masqué ; prénoms et noms des corpus : aucune fuite ajoutée ; sans le lexique,
  sortie octet pour octet identique ; taille du fichier et coût de chargement
  rapportés ; `DATA_SOURCES.md`, `LIMITES.md` et README du paquet à jour.

### P2-252 et P2-253 — Corrections (décisions du 22 novembre)

- **P2-252** : `ecluse_core` (IBAN, FINESS) ou résolution des chevauchements.
  Sur 200 000 documents du corpus d'identifiants (graine 42), 10 IBAN « pièges » à
  clé invalide (« L'IBAN … a été refusé par la banque (clé invalide). ») voient 9
  de leurs chiffres masqués comme FINESS et le reste laissé en clair : un numéro de
  compte partiellement exposé. Décision : un IBAN de forme française complète mais
  à clé invalide est masqué **en entier** (un IBAN mal recopié reste celui de
  quelqu'un), sous un type à choisir et à justifier (iban à confiance réduite, par
  exemple) ; le FINESS ne doit plus être cherché à l'intérieur. Test d'abord, à
  partir d'un cas synthétique qui reproduit le défaut. **Fini quand** : sur le corpus
  de 200 000 documents (`generate_corpus.py --n 200000 --seed 42`), 0 IBAN piège
  masqué en partie (chemin `Ecluse.redact` et moteur seul, chacun nommé) ; vrais
  IBAN et FINESS : rappel inchangé (100 %) ; aucune entité de moins masquée sur
  aucun corpus du tableau de bord ; `LIMITES.md` à jour.
- **P2-253** : `patronymes_connus.dart`. Aujourd'hui une entrée d'un seul mot
  dont la forme en capitales est un sigle exclu du détecteur de noms (« EVA »,
  échelle visuelle analogique) est refusée, et le refus porte sur toute la liste :
  une application qui a une patiente prénommée Eva ne peut pas fournir sa liste.
  Décision : une entrée écrite avec une majuscule initiale suivie de minuscules
  (« Eva ») est acceptée et masquée ; seule la forme tout en capitales reste
  refusée (ou acceptée seulement en casse de titre dans le texte : à justifier).
  Le sigle « EVA » en capitales dans le texte n'est jamais masqué à cause de la
  liste. Test d'abord. **Fini quand** : « Eva » accepté, masqué dans « Eva Martin
  est venue », « EVA 6/10 » non masqué ; refus de « EVA » ou comportement choisi
  documenté ; protocole de P2-243 rejoué sans régression ; `LIMITES.md` à jour.

### P2-254 — IBAN FR à clé fausse, lettre « o » dans la clé, sans libellé

Depuis le 22 novembre (décision du mainteneur, `DECISIONS.md`), le corpus
« libellé fort » (`bench/generate_corpus_libelle_fort.py`) annote comme donnée
personnelle les IBAN à clé fausse **sans libellé** (variante
`cle_fausse_sans_libelle`). Par `Ecluse.redact`, 46 sur 50 sont masqués en
entier ; **les 4 qui partent en clair ont tous une lettre `o` ou `O` à la place
d'un chiffre de la clé** (« FR8o52… », « FRo6… »). `IbanCleInvalideDetector`
(P2-252) exige deux chiffres après `FR` ; le libellé fort (P2-191) tolère cette
lettre, mais il n'y a pas de libellé ici. Le défaut est toléré au tableau de bord
par un plafond de 4 (`PLAFOND_LIBELLE_FORT` dans `bench/etat_attendu.py`).

Travail : admettre `O`/`o` à la place d'un chiffre **dans les deux caractères de
clé** d'un IBAN de forme française complète (`FR` + 2 + 23 caractères), sans
libellé, au même type `iban`, confiance 0,3, avertissement « à vérifier ». Test
d'abord, à partir d'un cas synthétique qui reproduit le défaut. Mesurer le coût :
une suite « FRo… » qui n'est pas un IBAN (référence, code) serait masquée ;
compter les nouveaux masquages sur tous les témoins du tableau de bord et sur le
témoin de 480 documents sans donnée personnelle (`comparatif.py --temoin`).
**Fini quand** : `sans libellé x cle_fausse_sans_libelle` à 0 / 50 en clair et le
plafond retiré ; aucun témoin négatif du tableau de bord ne gagne de masquage (ou
chaque nouveau masquage est listé et justifié dans la PR) ; vrais IBAN : rappel
inchangé ; `LIMITES.md` à jour.

### P2-255 — Recensement des pièges des corpus (mesure)

Le 22 novembre, deux corpus ont changé d'annotation : un IBAN à clé fausse est
désormais une donnée personnelle (`DECISIONS.md`, 22 novembre, points 7 et 8).
D'autres pièges restent « non annotés » sans qu'on ait vérifié s'ils relèvent de
la même logique (NIR à clé fausse, RPPS à Luhn cassé, ADELI à clé fausse,
numéros voisins, SIRET, téléphones, numéros de dossier…).

Travail : pour **chaque** générateur `bench/generate_corpus*.py`, lister chaque
forme de piège ou de témoin négatif qui ressemble à une donnée personnelle ; pour
chacune : exemple synthétique, annotée ou non, traitement actuel par
`Ecluse.redact` (masquée en entier, en partie, en clair, comptée sur le corpus
de graine 42) et la règle de `DECISIONS.md` ou `LIMITES.md` qui s'y applique.
Signaler les cas où l'annotation et la règle se contredisent, ou où une partie
seulement du numéro est masquée. **Ne rien corriger, ne changer aucune
annotation** : les choix reviennent au mainteneur. Rapport dans
`agent/specs/P2-255.md`, terminé par la liste des questions à trancher, chacune
avec ses conséquences mesurées (combien de masquages ou de fuites changeraient).
**Fini quand** : tous les générateurs sont couverts (le rapport liste ceux qui
n'ont aucun piège) ; chaque chiffre vient d'une commande citée.

### P2-256 — `bench/README.md` rejoué (mesure)

`bench/README.md` mêle des chiffres de dates différentes : le tableau principal
et la section « reconnaisseurs NIR et RPPS » ont été remis à jour le 22 novembre
(826 entités), mais d'autres sections citent encore l'état d'avant P2-248 (42
faux positifs FINESS, précision FINESS 75,4 %) ou d'avant l'annotation des IBAN
à clé fausse (778 entités, 214 IBAN, « 67 IBAN »), et le corpus étendu (P1-13)
n'a pas été rejoué depuis. Travail : rejouer chaque mesure citée par le fichier
avec la commande qu'il donne (Écluse ; Presidio seulement si l'environnement le
permet, sinon rescorer les prédictions existantes et le dire), corriger chaque
chiffre, dater chaque section, et garder les anciennes valeurs en note quand
elles ont été publiées. Aucun code ni corpus modifié. **Fini quand** : chaque
chiffre du fichier est relié à une commande rejouée au même commit (cité) ; la
PR liste chaque chiffre changé, avant/après.

### P2-257 — `bench/ETAT.md` dédoublonné (code, documentation seule)

`bench/ETAT.md` (≈ 3 050 lignes) contient 18 titres de section en double : 17
blocs strictement identiques, 1 divergent (des mises à jour successives ont
recopié une série de sections). Travail : ne garder qu'un exemplaire de chaque
section, à sa première place ; pour la section divergente, fusionner les deux
versions sans perdre une ligne d'information (signaler dans la PR ce qui
différait). Mettre à jour l'en-tête du fichier (date, commit). **Aucun chiffre ne
change** : un script dans la PR doit montrer que l'ensemble des lignes du
fichier après est inclus dans l'ensemble des lignes d'avant, plus les seules
lignes de fusion listées. **Fini quand** : aucun titre `## ` en double ;
`bash bench/etat.sh` inchangé (le fichier n'est pas lu par le script, à
vérifier) ; diff relu ligne à ligne pour la section divergente.

### P2-258 — NIR à clé fausse sans libellé (code)

Décision du 23 novembre (`DECISIONS.md`, point 1) : comme l'IBAN (P2-252), un NIR
mal recopié reste celui d'un patient. Aujourd'hui, par `Ecluse.redact`, les NIR
pièges de `bench/generate_corpus.py` (« saisie erronée hier : … a été rejeté »)
partent en clair : 45 / 45 en v3, 29 / 29 en extended (`agent/specs/P2-255.md`,
§ 3, script `bench/recensement_pieges.py`).

Travail, dans cet ordre :
1. **Mesurer le coût avant tout masquage.** Prototype de détection (même place et
   même schéma que `IbanCleInvalideDetector`, P2-252 : détecteur pur dans
   `ecluse_core`) : quinze chiffres (mêmes séparateurs que `NirDetector`), sexe
   1 ou 2, mois 01-12 ou plages admises par `NirDetector`, département plausible,
   **clé fausse**. Compter les nouveaux masquages sur tous les témoins négatifs
   du tableau de bord (`bash bench/etat.sh`) et sur `comparatif.py --temoin`.
   Si un témoin gagne plus de 5 masquages, s'arrêter et ouvrir une PR « bloqué »
   avec la liste.
2. Test d'abord (cas synthétique qui reproduit la fuite), puis le détecteur :
   type `nir`, masqué en entier, confiance 0,3, avertissement « identifiant à clé
   invalide masqué : à vérifier » sans la valeur. Activé dans
   `Ecluse.defaultDetectors` ; `NirDetector` strict inchangé.
3. Annoter `nir` les NIR pièges de `generate_corpus.py` (v3 et extended) et les
   NIR `nombre_sans_libelle` de `generate_corpus_libelle_fort.py` (tous les
   types qui sont un NIR, numéro de sécurité sociale compris ; une fois sur deux
   ils portent une lettre « O »/« o » d'OCR : la détection doit l'admettre à la
   place d'un zéro, comme P2-254 pour l'IBAN), **texte
   inchangé octet pour octet** (comme P2-252 et #493/#494 : test d'empreinte
   SHA-256 des textes, totaux d'entités mis à jour dans les tests).
4. Rejouer : tableau de bord, `bench/comparatif.py` (Presidio : rescorer les
   prédictions existantes si Presidio ne tourne pas, et le dire), mettre à jour
   `bench/COMPARATIF.md`, `bench/README.md`, `bench/etat_attendu.py`,
   `LIMITES.md` (§ 2, retirer le NIR de la ligne « corrections inscrites »).

**Fini quand** : NIR pièges 0 en clair (v3 et extended) ; libellé fort
`sans libellé` NIR 0 en clair ; rappel NIR des vrais NIR inchangé ; chaque
nouveau masquage d'un témoin listé et justifié dans la PR ; la PR donne les
chiffres avant / après du comparatif (entités v3 826 → 871 attendu, à vérifier),
car l'article de benchmark les cite.

### P2-259 — SIRET nommé (code)

Décision du 23 novembre (point 3). « Le SIRET de l'établissement est … » :
quatorze chiffres après le mot « SIRET », en clair 30 / 30 (v3) et 19 / 19
(extended) par `Ecluse.redact` (P2-255). `FinessDetector` type déjà `siren` un
nombre de **neuf** chiffres proche de « SIREN » ou « SIRET » (P2-248) ; le SIRET
de quatorze chiffres n'est pas vu.

Travail : test d'abord ; puis masquer en entier quatorze chiffres (groupés
3 3 3 5 ou collés) **dans la même fenêtre de 40 caractères** après ou avant le
mot « SIRET » (casse indifférente), type `siren`, confiance haute ; clé de Luhn
sur 14 chiffres vérifiée : clé fausse → confiance 0,3 avec avertissement « à
vérifier » (même règle que le libellé fort, P2-188). Sans le mot « SIRET »,
rien ne change. **Aucune annotation nouvelle au banc** (le SIRET n'est pas l'un
des quatre types, décision du 23 novembre point 5) : la mesure se fait par
`bench/recensement_pieges.py`. Coût : nouveaux masquages sur les témoins du
tableau de bord et `comparatif.py --temoin`, listés.
**Fini quand** : SIRET pièges 0 en clair (v3 et extended) ; aucun chiffre du
tableau principal ne change (sinon, expliquer) ; `LIMITES.md` à jour (§ 1 SIREN
et § 2).

### P2-260 — Numéro de TVA intracommunautaire (code)

Décision du 23 novembre (point 4). « N° de TVA intracommunautaire : FR… » :
29 / 35 en clair, 6 / 35 masqués en partie comme RPPS (onze chiffres valides
par hasard, « FR » en clair) par `Ecluse.redact`, corpus extended (P2-255).

Travail : test d'abord ; puis masquer en entier « FR » + deux caractères de clé
+ neuf chiffres (blancs admis comme dans le générateur et dans les formes
usuelles), type `siren`. Clé vérifiée par calcul (`(12 + 3 × (SIREN mod 97))
mod 97`) : clé juste → confiance haute ; clé fausse → seulement derrière un
libellé (« TVA », « n° TVA », « intracommunautaire » dans la fenêtre), confiance
0,3 et avertissement. Le résolveur doit préférer cette entité au RPPS partiel.
Pas de nouvelle annotation au banc ; mesure par `bench/recensement_pieges.py`.
Coût : nouveaux masquages des témoins, listés (« FR » + onze chiffres peut être
une référence).
**Fini quand** : TVA 0 en clair et 0 masqué en partie (extended) ; aucun RPPS du
corpus ne change de type ; `LIMITES.md` à jour.

### P2-261 — SIREN, SIRET et TVA annotés au banc (code)

Décision du 23 novembre, point 8 (`DECISIONS.md`). Depuis P2-259 et P2-260, Écluse
masque à dessein SIREN nommé, SIRET nommé et TVA, mais le banc ne les annote pas :
ils comptent comme faux positifs (v3, moteur seul : 92,4 % / 100 %, 72 FP `siren`,
871 entités ; extended : 185 FP `siren`, TOTAL 70,6 % / 91,7 %).

Travail :
1. **Annoter `siren`**, texte inchangé octet pour octet (test d'empreinte SHA-256
   comme #493/#494), chaque SIREN, SIRET et numéro de TVA que les générateurs
   écrivent **comme tels** : `trap_siret`, `trap_siren`, `tva` et `siren_plain`
   de `bench/generate_corpus.py` (v3 et extended), et toute autre occurrence que
   trouve `bench/recensement_pieges.py`. Le span couvre le numéro entier (« FR » et
   la clé compris pour la TVA). Les nombres de neuf chiffres que le texte ne
   présente pas comme un SIREN ne sont pas annotés. Les noms `trap_*` concernés
   sont renommés ou commentés : ce ne sont plus des pièges.
2. **Témoin flou** (`bench/generate_corpus_flou.py`, variante « identifiants
   d'entreprise ») : la ligne « SIRET … TVA … » n'est plus « rien à masquer ».
   L'annoter `siren` (positifs), ou la remplacer par une ligne sans donnée
   personnelle **sans changer les autres variantes** ; choisir et le justifier
   dans la PR. Après la tâche, le témoin « rien à masquer » doit redonner 0.
3. **Scoreur** : `score.py` et `comparatif.py` gardent un TOTAL tous types, et
   ajoutent la comparaison principale **sur les types communs** (NIR, RPPS, IBAN,
   FINESS, ADELI) : gold et prédictions `siren` retirés **pour tous les outils**,
   même règle. Ligne à part `siren` pour chaque outil (Presidio n'a pas de
   reconnaisseur français : le dire, ne pas l'interpréter).
4. Rejouer tout : `bash bench/etat.sh` (0 ÉCHEC), `comparatif.py` (Presidio :
   rescorer les prédictions existantes si Presidio ne tourne pas, et le dire),
   puis mettre à jour `bench/COMPARATIF.md`, `bench/README.md`, `bench/ETAT.md`,
   `bench/etat_attendu.py`, totaux des tests, `LIMITES.md` (§ 2 : les phrases
   « non annotés au banc » de P2-259 et P2-260). **Ne pas toucher
   `bench/ARTICLE.md`** : l'article est repris par le pilote.

**Fini quand** : textes des corpus identiques (empreintes) ; v3 et extended,
`siren` annoté ; le chemin de chaque chiffre est écrit ; la PR donne un tableau
avant / après pour Écluse et Presidio, tous types **et** types communs, plus la
ligne `siren` ; toute fuite `siren` révélée par l'annotation (SIREN non masqué par
`Ecluse.redact`) est listée par gabarit, **sans être corrigée** dans cette tâche ;
témoin « rien à masquer » à 0.

### P2-262 — Reproduire le banc sur une machine neuve (code, documentation seule)

L'article de benchmark invite à « rejouer ces mesures ». Personne n'a vérifié la
séquence sur une machine vierge : modèles spaCy (`en_core_web_lg`,
`fr_core_news_lg`), EDS-Pseudo installé depuis GitHub, `bench/corpus.jsonl`
préalable au test d'équivalence, durée de Presidio. Travail : partir d'une VM sans
rien d'installé hors Dart et Python, suivre `bench/README.md` à la lettre, noter
chaque écart (commande manquante, ordre faux, version différente, durée), puis
réécrire la section « Reproduire » de `bench/README.md` avec la séquence qui
marche. Rejouer : identifiants sur 1 000 documents (Écluse moteur seul,
`Ecluse.redact`, Presidio par défaut), `bench/comparatif.py --temoin` ; 200 000
documents seulement pour Écluse (Presidio : donner la durée mesurée sur 1 000 et
l'extrapolation, sans le lancer). **Aucun changement de code ni de chiffre** :
un chiffre rejoué qui diffère de `bench/COMPARATIF.md` ou de `bench/README.md`
est rapporté dans la PR, pas corrigé. `bench/ARTICLE.md` n'est pas touché.
**Fini quand** : la PR liste les écarts trouvés et les commandes exactes, avec
les versions installées et les durées ; `bench/README.md` § « Reproduire » à jour ;
les chiffres rejoués concordent ou chaque écart est expliqué.

### P2-267 — Nombres dictés en lettres (code)

Décisions du 23 novembre au soir (`DECISIONS.md`, six points) sur la spec
`agent/specs/P2-155.md`, à lire en entier (§ 3 à § 7). Défaut mesuré
(`Ecluse.redact`, graine 42) : fuite au caractère 97,4 à 98,0 % sur les cinq
variantes de `bench/generate_corpus_transcrit.py`.

Travail, dans l'ordre de la spec § 7 :
1. Test d'équivalence d'abord : tous les corpus existants donnent des prédictions
   identiques octet pour octet avant et après (seconde vue inactive sans
   mot-nombre, garde `identical` comme P2-29).
2. Compléter le générateur de transcrits (graine 42, offsets exacts) avec les
   variantes absentes : « double / triple », « septante / huitante / nonante »,
   « o » pour zéro, séparateurs perdus ; mesurer le défaut avant toute correction.
3. Seconde vue avec table début / fin par caractère ; span ramené aux bornes des
   mots ; lectures ambiguës bornées (64 au plus) et arbitrées par la clé du
   détecteur ; K et K après mot-clé fixés par la mesure (tableau dans la PR).
4. Signalement non bloquant « nombre dicté non reconnu, relire avant envoi »
   pour une suite d'au moins 9 mots-nombres qu'aucune lecture ne valide :
   positions et compte seulement, aucune valeur.
5. Test de coût : 400 000 caractères de mots-nombres, temps linéaire.
6. `LIMITES.md` mis à jour (ce qui est couvert, ce qui reste hors périmètre).

Hors lot : âge en lettres, lettres d'IBAN épelées, corrections du locuteur.
**Fini quand** (conditions de GO, décision point 6) : par type et par variante
dictée, fuite au caractère ≤ 5 % par `Ecluse.redact` (un type dont l'écriture
dépend d'un hors-lot, comme les lettres d'IBAN, est signalé et exclu, avec la
raison) ; 0 masquage à tort sur **tous** les témoins (v3, flou, QI, dossiers,
mots neutres, faux amis, mots-nombres 0 / 300) ; texte restauré identique ;
`bash bench/etat.sh` sans écart hors des lignes prévues. Une condition manquée :
PR « bloqué » avec la mesure complète, sans contournement.

### P2-263 — NIR à clé fausse : fin de ligne, pleine chasse, groupes de 3 (code)

Limites notées à la fusion de P2-258 (#502) : un NIR à clé fausse sans libellé
n'est pas masqué quand il est coupé par une fin de ligne, écrit en chiffres
pleine chasse, ou groupé 3 × 5. Travail : sonde synthétique qui montre la fuite
par `Ecluse.redact`, puis lecture sur la vue de détection (P2-29), sans toucher
au texte ni à `NirDetector` strict ; le NIR à clé nommée à part (P2-42) reste
identique. **Fini quand** : les trois formes masquées en entier à 0,3 avec
l'avertissement « à vérifier » ; 0 masquage nouveau sur les témoins (liste
fournie sinon) ; `etat.sh` inchangé hors lignes prévues.

### P2-264 — Fuite par OCR sans libellé (mesure)

Rien n'est corrigé. P2-191 couvre « O » pour 0 et « l » ou « I » pour 1 derrière
un libellé fort ; P2-254 l'IBAN à clé fausse avec « O ». Sans libellé, un NIR à
clé juste écrit avec un « O » part en clair (compte rendu du 23 novembre matin).
Travail : générateur synthétique (graine 42) qui substitue ces confusions dans
NIR, RPPS, IBAN, FINESS et `siren`, avec et sans libellé, plus un témoin négatif
(mots et références ordinaires contenant ces lettres) ; mesurer par
`Ecluse.redact` la fuite au caractère par type et le nombre de masquages à tort.
Rapport dans `agent/specs/P2-264.md`. **Fini quand** : tableau fuite / masquage à
tort par type et par confusion, avec le chemin mesuré ; proposition chiffrée de
correction (ce qu'elle coûterait sur le témoin), sans code de production.

### P2-265 — `bench/ETAT.md` contrôlé (code)

La session du 23 novembre après-midi a trouvé 3 lignes en retard sur 8 vérifiées
(tableau « Dictée », « v3 sans ponctuation », titre de section). Travail : un
script `bench/` (en s'appuyant sur `bench/verifie_etat.py` s'il convient) compare
chaque valeur courante d'`ETAT.md` à la sortie d'`etat.sh` et sort en erreur au
premier écart, avec la ligne fautive ; l'historique passe dans une section datée
que le script ignore ; tests Python. **Fini quand** : le script passe sur `main`
après mise à jour d'`ETAT.md`, échoue sur une valeur modifiée à la main (test),
et `bench/README.md` dit quand le lancer.

### P2-266 — Test d'équivalence sur machine neuve (code)

Sur une VM neuve, `melos run test` échoue tant que `bench/corpus.jsonl` (ignoré par
git) n'est pas généré (`packages/ecluse_bench/test/golden_equivalence_test.dart`).
Travail : le message d'échec donne la commande exacte
(`python3 bench/generate_corpus.py --n 1000 --seed 42 --out bench/corpus.jsonl`) ;
même phrase dans `bench/README.md`. Pas d'appel à Python depuis le test, pas de
saut silencieux (règle 4). **Fini quand** : sur une VM sans corpus, l'échec affiche
la commande ; avec le corpus, le test passe comme avant.

### P2-268 — Identifiants lus par OCR (code)

Décision du 23 novembre, nuit (`DECISIONS.md`, six points), sur le rapport
`agent/specs/P2-264.md` (à lire en entier) et son prototype
`bench/ocr_proposition.py`. Défaut mesuré par `Ecluse.redact` sur
`bench/flou/corpus_ocr.jsonl` : sans libellé, fuite au caractère NIR 97,6 %,
RPPS 98,8 %, IBAN 22,2 %, FINESS 100 %, SIREN 99,1 % ; avec libellé, FINESS
99,5 % et SIREN 96,3 % (non relus).

Travail :
1. **Durcir le témoin d'abord** : ajouter à `bench/generate_corpus_ocr.py`
   (graine 42) un témoin négatif de suites ordinaires denses en O/o/l/I et
   chiffres (références de commande, lots, codes produits, numéros de pièce,
   identifiants informatiques), au moins 400 documents ; mesurer le prototype
   dessus et donner le nombre de faux accords par type **avant** tout code.
   Plus de 0 faux accord pour une clé forte sans libellé : s'arrêter, PR
   « bloqué » avec la liste.
2. Test d'abord (cas synthétiques qui montrent la fuite), puis la règle dans
   `ecluse_redact` (ou un détecteur pur de `ecluse_core`, comme
   `IbanCleInvalideDetector`) : suite de l'alphabet `[0-9OolI]`, séparateurs de
   groupe tolérés, au moins une lettre d'OCR, identifiant valide une fois les
   lettres relues. NIR et IBAN avec ou sans libellé ; RPPS, FINESS, SIREN, ADELI
   seulement derrière un libellé ou un mot-clé (même liste que P2-267 si elle
   convient, sinon la justifier). Masqué en entier, type de l'identifiant,
   confiance 0,3, avertissement « à vérifier » sans la valeur.
3. Aucun changement sans lettre d'OCR : prédictions identiques octet pour octet
   sur tous les autres corpus (`bench/equivalence_predictions.sh`).
4. Rejouer `bash bench/etat.sh`, `python3 bench/controle_etat.py` (bloc régénéré
   avec `--propose` si les lignes OCR changent, et seulement elles), mettre à
   jour `LIMITES.md` et `agent/specs/P2-264.md` (§ résultat après correction).

**Fini quand** : par `Ecluse.redact`, sans libellé, fuite NIR et IBAN ≤ 5 % ;
avec libellé, fuite ≤ 5 % pour les cinq types ; sans libellé, RPPS, FINESS et
SIREN inchangés (et le dire) ; **0 masquage à tort** sur le témoin d'origine
(400), le témoin durci, `corpus_flou_realiste`, `corpus_courriers`, le corpus
principal et tous les témoins d'`etat.sh` ; tableau avant / après dans la PR.

### P2-269 — Presidio rejoué sur 200 000 documents (mesure)

L'article de benchmark cite Presidio sur 200 000 documents à partir de ses
prédictions du 21 novembre (commit `c3de6a8`), **rescorées** sur l'annotation du
23 novembre, pas rejouées. P2-262 a mesuré ≈ 30 minutes extrapolées. Travail :
générer le corpus de 200 000 documents (graine 42), lancer `bench/run_presidio.py`
tel que livré (seuil 0,35, `en_core_web_lg`), scorer avec `bench/score.py`
(tous types, types communs, ligne `siren`, fuite au caractère). Comparer au
rescorage : P 100 %, rappel types communs 16,7 %, tous types 15,2 %, IBAN
27 820 vrais positifs. Rapport dans `agent/specs/P2-269.md`, avec versions et
durée. **Rien n'est corrigé** ; `bench/ARTICLE.md` non touché. **Fini quand** :
chiffres rejoués donnés avec leur chemin, et chaque écart au rescorage expliqué
(ou « aucun écart »).

### P2-270 — Nombres dictés : témoin durci (mesure)

Le témoin « mots-nombres » (300 phrases) donne 0 prédiction après P2-267, mais
la PR #511 signale trois incertitudes : mots-clés de validation faible tirés des
corpus synthétiques (« code » est large), signalement « nombre dicté non
reconnu » possible sur une phrase ordinaire dense en nombres, K = 6 que le témoin
ne départage pas de 4. Travail : générateur synthétique (graine 42) d'au moins
600 phrases ordinaires dictées, sans identifiant : montants et prix, horaires et
durées, dates, adresses en lettres, posologies et quantités, consignes et
digicodes avec le mot « code », numéros de chambre ou de poste. Mesurer par
`Ecluse.redact` : masquages à tort par type, signalements à tort, et le même
tableau pour K = 4, 6 et 8. Rapport dans `agent/specs/P2-270.md`. **Rien n'est
corrigé.** **Fini quand** : tableau par famille de phrases et par type prédit,
exemples synthétiques des cas à tort, et proposition chiffrée (mot-clé à retirer,
K à changer) avec son effet sur les variantes dictées de P2-267.

### P2-271 — Nombres dictés : FINESS chevauché par un établissement (code)

Après P2-267, par `Ecluse.redact`, 6 à 9 FINESS dictés sur 129 ne sont pas
couverts en entier (1 à 17 caractères en clair) : un nom d'établissement détecté
avant (« ch de metz finess … ») l'emporte au tri des chevauchements (PR #511,
« ce qui reste incertain »). Travail : d'abord la mesure des cas exacts sur les
cinq variantes dictées (liste par gabarit) ; puis test qui montre la fuite ; puis
correction de la résolution des chevauchements pour qu'un identifiant validé
venu de la seconde vue soit couvert en entier (étendre l'établissement ou garder
les deux étendues), sans rien changer hors des passages dictés. **Fini quand** :
FINESS dicté 129 / 129 couverts en entier sur chaque variante ; prédictions
identiques octet pour octet sur tous les autres corpus
(`bench/equivalence_predictions.sh`) ; `python3 bench/controle_etat.py` conforme
(bloc régénéré pour les seules lignes dictées) ; témoins à 0.

### P2-272 — Masquages à tort hérités sur suites denses (mesure)

Le témoin durci de P2-268 (`bench/generate_corpus_ocr.py`, 450 documents de
références, lots et codes ordinaires) donne 14 masquages à tort **déjà présents
avant P2-268** (compte rendu du 24 novembre, nuit) : IBAN de forme française à clé
fausse sans libellé (P2-252) 10, NIR à clé fausse avec « o » (P2-258) 1, adresse
« cinq chiffres + mot » 2, FINESS neuf chiffres 1. Travail : par `Ecluse.redact`,
lister ces cas par détecteur et par gabarit ; pour chaque détecteur, simuler deux
ou trois gardes (par exemple : séparateurs de groupe de quatre exigés pour l'IBAN
à clé fausse sans libellé, deux chiffres de clé réels, mot-clé voisin) et mesurer
pour chacune les masquages à tort évités et le **rappel perdu** sur les corpus à
clé fausse (v3 : 48 IBAN et 45 NIR ; libellé fort ; 200 000 documents si le temps
le permet). Rapport dans `agent/specs/P2-272.md`. **Rien n'est corrigé.**
**Fini quand** : tableau détecteur × garde (masquages à tort évités, identifiants
perdus), chemin mesuré écrit, recommandation chiffrée pour le mainteneur.

### P2-273 — Nombres dictés : retirer « code » des mots-clés faibles (code)

P2-270 (`agent/specs/P2-270.md`) : avec « code » dans `_motCleFaible`, le témoin
durci donne 3 masquages à tort (FINESS 1, RPPS 2, famille « codes ») ; sans lui,
0, et aucun changement sur les six variantes dictées. Travail : test qui montre
un des 3 cas, retrait du mot, rejeu. **Fini quand** : témoin durci à 0 masquage à
tort ; six variantes dictées à 943 / 943 couverts comme après P2-271 ;
prédictions identiques octet pour octet ailleurs
(`bench/equivalence_predictions.sh`) ; `python3 bench/controle_etat.py`
conforme.

### P2-274 — Nombres dictés : seuil du signalement (mesure)

P2-270 : 46 signalements « nombre dicté non reconnu » à tort sur 630 phrases,
tous des codes dits de 9 chiffres ou plus ; le seuil est 9 mots-nombres. Travail :
mesurer, par `Ecluse.redact` (paramètre de seuil exposé à un script de banc
seulement, sans changer le produit), les seuils 9, 11 et 13 : signalements à tort
sur le témoin durci, et identifiants dictés **non validés** encore signalés sur
les corpus dictés (NIR à 15, IBAN à 27, avec clé fausse ou mot perdu).
Rapport dans `agent/specs/P2-274.md`. **Rien n'est corrigé.** **Fini quand** :
tableau seuil × (signalements à tort, identifiants non validés signalés), et
recommandation chiffrée.

### P2-275 — OCR : trous restants (code)

Après P2-268 (#518), par `Ecluse.redact` : 4 NIR corses (« 2A »/« 2B ») sur 120
lus avec une lettre d'OCR sans libellé restent en clair ; un identifiant derrière
un libellé, à clé fausse une fois relu et écrit avec des séparateurs multiples,
n'est pas couvert. Le témoin durci des mots-nombres (P2-270) n'est pas dans
`etat.sh`. Travail : sonde synthétique qui montre chaque trou, puis correction,
puis ajout du témoin durci au tableau de bord (`etat.sh`, `etat_attendu.py`,
bloc de `ETAT.md` régénéré par `controle_etat.py --propose`). Garder la règle
« sexe 1 ou 2 » pour un NIR relu sans libellé. **Fini quand** : les 4 NIR corses
masqués à 0,3 avec l'avertissement OCR ; le cas libellé + clé fausse + séparateurs
multiples masqué ; 0 masquage à tort nouveau sur tous les témoins (dont le témoin
durci de P2-268) ; prédictions identiques ailleurs ; `controle_etat.py` conforme.

### P2-276 — Gardes à coût nul contre les masquages à tort hérités (code)

Mesure de P2-272 (`agent/specs/P2-272.md`, chemin `Ecluse.redact`) : les gardes
`nir_suitelettre`, `finess_suitelettre` et `adr_confusables` (prototype
`bench/gardes_faux_accords_patch.py`) retirent des masquages à tort du témoin
durci sans perdre un seul identifiant sur v3, libellé fort, OCR, la sonde et les
200 000 documents. `iban_g45` est **hors de cette tâche** : il perd 40 / 520 IBAN
en groupes de trois à la sonde, le mainteneur doit trancher. Travail : test qui
montre chaque masquage à tort, puis les trois gardes dans le produit, puis rejeu.
**Fini quand** : masquages à tort du témoin durci réduits du nombre que la mesure
de P2-272 prévoit pour ces trois gardes seules (le donner) ; 0 identifiant perdu
sur v3, libellé fort, OCR, sonde et 200 000 documents ; prédictions identiques
ailleurs (`bench/equivalence_predictions.sh`) ; `python3 bench/controle_etat.py`
conforme (bloc régénéré pour les seules lignes prévues).

### P2-277 — IBAN à clé fausse en paires, adresse avec arrondissement (code)

Trous vus par la sonde de P2-272 (`bench/generate_sonde_gardes.py`), par
`Ecluse.redact` : IBAN de forme française à clé fausse écrit en paires de
chiffres, 0 / 40 couverts ; adresse « code postal + commune avec arrondissement »
(« … Lyon 3e »), 0 / 140 couverts en entier. Travail : test d'abord, puis
correction, sans toucher les autres formes. **Fini quand** : 40 / 40 et
140 / 140 couverts en entier ; 0 masquage à tort nouveau sur tous les témoins
(dont le témoin durci de P2-268) ; prédictions identiques ailleurs ;
`controle_etat.py` conforme.

### P2-278 — Sonde et dictée abîmée suivies par le tableau de bord (code)

La sonde de P2-272 et les corpus d'identifiants dictés abîmés de P2-274
(`bench/generate_corpus_dicte_non_valide.py`) ne sont pas dans `bench/etat.sh` :
leurs trous ne sont pas suivis. Travail : les ajouter à `etat.sh`,
`etat_attendu.py`, `etat_exemple.txt`, et régénérer le bloc d'`ETAT.md` par
`controle_etat.py --propose`. **Fini quand** : lignes ajoutées ; aucun chiffre
existant ne change ; `controle_etat.py` conforme ; tests Python verts.

### P2-279 — Faux accords par détecteur, avec intervalle (mesure)

14 / 450 au témoin durci de P2-268 est trop petit pour une barre d'erreur.
Travail : témoin durci élargi (au moins 5 000 documents, mêmes familles que
P2-268, graine 42) et 200 000 documents sans identifiant (gabarits de
`bench/generate_corpus_temoin.py` ou équivalent) ; par `Ecluse.redact`, taux de
masquages à tort par détecteur (IBAN à clé fausse P2-252, NIR à clé fausse P2-258,
OCR P2-268, adresse, FINESS, nombres dictés) avec un intervalle de confiance à
95 %. Rapport dans `agent/specs/P2-279.md`. **Rien n'est corrigé.** **Fini
quand** : tableau détecteur × (taux, intervalle, exemples synthétiques), chemin
mesuré écrit.

### P2-280 — Signalement de la dictée : autres critères (mesure)

P2-274 : en jouant seulement sur le nombre de mots, 46 / 24 / 0 signalements à
tort (seuils 9 / 11 / 13) contre 11 / 18 / 41 identifiants abîmés passés sans
avertissement. Travail : mesurer d'autres critères, seuls ou combinés au seuil
9 (mot voisin « code », « digicode », « mot de passe » qui coupe le signalement ;
forme d'un identifiant connu, comme 15 ou 27 positions ; présence d'un libellé
d'identifiant). Mêmes corpus que P2-274. Rapport dans `agent/specs/P2-280.md`.
**Rien n'est corrigé.** **Fini quand** : tableau critère × (signalements à tort,
identifiants abîmés sans avertissement) et recommandation chiffrée.

### P2-281 — Signalement perdu sur les IBAN dictés recouverts (code)

Régression trouvée par la session du 24 novembre (matin, 2), bissectée sur le
commit de P2-275 (`34f4ca8`) : par `Ecluse.redact`, sur les corpus d'identifiants
dictés abîmés de P2-274, 5 IBAN signalés « nombre dicté non reconnu » ne le sont
plus, parce qu'une entité `iban` les recouvre en partie. « Rien » (identifiant
abîmé passé sans masquage ni avertissement) : 8 / 3 au rapport de P2-274, 9 / 7
sur `main`. Travail : test d'abord sur ces 5 documents ; puis le signalement
porte aussi une suite dictée **recouverte en partie** par une entité. **Fini
quand** : « rien » ≤ 8 / 3 sur les deux corpus abîmés ; 0 masquage à tort de plus
sur les témoins mots-nombres (300) et durci (630) ; prédictions identiques
ailleurs ; `python3 bench/controle_etat.py` conforme (bloc régénéré pour les
seules lignes de dictée abîmée).

### P2-282 — Signalement coupé par un mot voisin (code)

Mesure de P2-280 (`agent/specs/P2-280.md`) : un mot voisin (« code »,
« digicode », « mot de passe ») à 100 caractères au plus, sauf libellé
d'identifiant dans la même fenêtre, ramène les signalements à tort de 49 à 0 sur
le témoin durci (630), sans silence de plus. Réserve de la mesure : critère choisi
après lecture du témoin. Travail : test d'abord, dont un « code IBAN … » qui doit
rester signalé ; puis la règle ; puis un **témoin neuf** (graine 43, mêmes
familles que P2-270, jamais lu avant) pour vérifier que le gain tient. **Fini
quand** : 0 signalement à tort sur le témoin durci ; sur le témoin neuf, résultat
donné avant / après ; silences ≤ base de P2-281 ; `controle_etat.py` conforme.

### P2-283 — IBAN de clé juste écrit en paires (code)

Après P2-277 (#529), un IBAN de clé **juste** écrit en paires avec séparateur après
« FR » n'est pas pris par `IbanFrDetector` : sonde manuelle, seul un morceau est
masqué comme téléphone. Travail : ajouter à la sonde de P2-272 40 cas par
écriture (paires, clé juste), mesurer par `Ecluse.redact`, puis corriger. Ne pas
couvrir les clés à lettre en paires (9 faux accords de plus au témoin, #529).
**Fini quand** : 40 / 40 couverts en entier ; 0 masquage à tort nouveau sur tous
les témoins (dont le témoin durci de P2-268) ; prédictions identiques ailleurs ;
`controle_etat.py` conforme.

### P2-284 — Faux accords suivis par le tableau de bord (code)

P2-279 (`agent/specs/P2-279.md`) mesure les faux accords par détecteur sur un
témoin durci de 5 000 documents et 5 600 phrases ordinaires (162 / 5 000 avant
P2-276, 129 après). Travail : ces deux jeux (pas les 200 000, trop longs) dans
`etat.sh`, `etat_attendu.py`, `etat_exemple.txt`, bloc d'`ETAT.md` régénéré.
**Fini quand** : lignes par détecteur ajoutées ; aucun chiffre existant ne
change ; `controle_etat.py` conforme ; tests Python verts.

### P2-285 — Établissement masqué sans personne (mesure)

P2-279 : sur 200 000 documents du soin sans donnée personnelle, 7 965 (3,98 %)
voient un établissement générique masqué (« SSIAD à Angers », « Résidence
Autonomie »). `DECISIONS.md` et `LIMITES.md` assument déjà « CHU à Lille ».
Travail : décompte par forme (sigle seul, sigle + ville, nom générique en
majuscules de titre, autre), avec exemples synthétiques, et comparaison avec ce
que les décisions assument. Rapport dans `agent/specs/P2-285.md`. **Rien n'est
corrigé.** **Fini quand** : tableau forme × taux ; pour chaque forme, garder,
restreindre ou signaler, avec ce que chaque choix coûterait en établissements
nommés manqués sur les corpus annotés.

### P2-286 — Démo : chiffres des mesures et exemple « pièges » (code)

La démo locale (`packages/ecluse_demo`) montre le trajet en quatre panneaux mais
aucun chiffre de mesure. Travail : (1) un encart statique sous les panneaux,
trois barres : identifiants entièrement masqués sur 200 000 documents (Écluse
100 %, Presidio 16,7 %), données personnelles couvertes sur 397 entités
(Écluse 100 %, Presidio fr 70 %, Presidio par défaut 53 %, EDS-Pseudo 52 %,
spaCy 47 %), documents sans donnée personnelle masqués à tort sur 480 (Écluse
3 %, EDS-Pseudo 54 %, Presidio par défaut 93 %, Presidio fr 95 %, spaCy
100 %), chacune avec sa réserve (corpus du projet, petits échantillons) et la
date de mesure ; les chiffres viennent de `bench/COMPARATIF.md` et de l'article,
pas d'une saisie libre. (2) Un exemple de plus dans
`ecluse_redact/lib/src/samples.dart`, entièrement fictif : note de liaison
avec un NIR à clé fausse (avertissement « à vérifier » attendu), un IBAN écrit
avec espaces multiples, insécable et tabulation, et des phrases sans personne
(salle, page, article de loi, sigles CHU, CPAM, HAD) ; bouton de chargement
dans `web/index.html`. (3) Les réponses de démonstration ne s'affichent pas en
markdown brut : `**gras**` du LLM rendu ou retiré à l'affichage.
**Fini quand** : encart et exemple visibles ; test du nouvel exemple (5 entités,
avertissement de clé, 0 masquage dans les deux dernières phrases) ; tests de la
démo verts ; aucun nom de structure réelle.

### P2-287 — Mot courant lu comme commune dans le rapport de risque (mesure)

Constaté le 24 novembre sur un texte fictif passé par la démo : « Son numéro de
sécurité sociale… » en tête de phrase donne un quasi-identifiant `lieu` « Son »
(commune homonyme), F = 89, et le rapport l'affiche. Travail : vérifier si
`LIMITES.md` ou P1-31 couvrent déjà ce cas ; compter, sur les corpus du dépôt et
le témoin sans donnée personnelle, les QI `lieu` qui sont des mots outils ou
courants en tête de phrase (« Son », « Sept », « Bourg »…), avec exemples
synthétiques. Rapport dans `agent/specs/P2-287.md`. **Rien n'est corrigé.**
**Fini quand** : tableau mot × occurrences × effet sur la bande de risque ;
recommandation chiffrée (liste d'exclusion, exigence d'une préposition « à »,
« de », ou statu quo).

### P2-288 — Faux accords IBAN : 89 → 102 (mesure)

Le témoin élargi de P2-279 (5 000 documents) donnait 89 documents à tort pour
l'IBAN à clé fausse (P2-252) à la mesure de P2-279 ; le tableau de bord de P2-284
en donne 102. Cause probable : P2-277 (IBAN en paires), peut-être P2-283 (paires à
clé juste) ; non rejoué. Travail : par `Ecluse.redact`, rejouer le témoin élargi
aux commits avant P2-277, après P2-277 et après P2-283 (`git worktree`, sans rien
changer sur `main`) ; lister par gabarit et par forme les documents qui changent,
avec exemples synthétiques. Rapport dans `agent/specs/P2-288.md`. **Rien n'est
corrigé.** **Fini quand** : la hausse est attribuée commit par commit et forme par
forme ; pour chaque forme, ce qu'une garde coûterait en IBAN perdus sur la sonde et
les corpus à clé fausse.

### P2-289 — Établissements : « à » absorbé dans le nom (code)

Mesure de P2-285 (`agent/specs/P2-285.md`, « Constat qui change la question ») :
dans `etablissement_detector.dart`, `_word = "[A-ZÀ-Ÿ]…"` ; l'intervalle `À-Ÿ`
(U+00C0–U+0178) contient les minuscules accentuées U+00E0–U+00FF, dont « à », qui
passe pour un mot en casse de titre : « CHU à Lille » est absorbé. Variante
mesurée `[A-ZÀ-ÖØ-ÞŒ]` : documents sans personne masqués à tort 7 965 → 2 063
(sigle + « à » + ville 5 902 → 0) ; réaliste, bornes exactes 317 → 400 / 400 ;
aucun établissement annoté manqué. Travail : test d'abord ; correction ; vérifier
et corriger de même les trois classes `[A-ZÀ-Ÿ]` de `coupures_de_nom.dart` (avec
la mesure de chacune) ; **ne pas toucher** « type + mot générique » (« Résidence
Autonomie », décision du mainteneur en attente). **Fini quand** : chiffres de la
variante retrouvés par `Ecluse.redact` ; 0 établissement ni nom annoté manqué sur
tous les corpus ; `controle_etat.py` conforme (bloc régénéré pour les seules
lignes prévues, chaque écart expliqué dans la PR) ; prédictions identiques sur les
corpus sans établissement.

### P2-290 — Établissements corrigés : casse et mise en page (mesure)

P2-285 n'a pas rejoué les variantes de casse et de mise en page. Après P2-289,
mesurer par `Ecluse.redact` les établissements annotés (couverts en entier, bornes
exactes) et les masquages à tort sur les variantes de `generate_corpus_flou.py`
(tout en majuscules, tout en minuscules, 60 et 90 colonnes, titres) et sur le
témoin de 480 documents de l'article (`comparatif.py --temoin`, ligne Écluse :
16 / 480 avant). Rapport dans `agent/specs/P2-290.md`. **Rien n'est corrigé.**
**Fini quand** : tableau variante × (couverts, bornes exactes, à tort) avant /
après P2-289, et le nouveau chiffre Écluse du témoin de 480 documents, pour
l'article.

### P2-291 — Signalements à tort suivis par le tableau de bord (code)

P2-282 (#543) a ramené les signalements « nombre dicté non reconnu » à tort de 49
à 0 (témoin durci, graine 42) et de 41 à 0 (témoin neuf, graine 43), mais
`bench/etat.sh` n'a pas bougé : ces signalements ne sont pas suivis. Travail :
lignes « signalements à tort » pour le témoin durci (630), le témoin neuf (630,
graine 43, générateur versionné) et le témoin d'origine (300), par
`Ecluse.redact`, dans `etat.sh`, `etat_attendu.py`, `etat_exemple.txt`, bloc
d'`ETAT.md` régénéré par `controle_etat.py --propose`. **Fini quand** : lignes
ajoutées, aucun chiffre existant ne change, `controle_etat.py` conforme, tests
Python verts.

### P2-292 — Coût réel de la garde du mot voisin (mesure)

Réserve de P2-282 : son coût n'est pas mesurable, parce qu'aucun corpus ne place
« code », « digicode », « mot de passe », « mdp » ou « pin » devant un
identifiant. Travail : corpus synthétique (graine 42) d'identifiants dictés
abîmés (mot perdu, clé fausse : mêmes familles que P2-274), précédés à 0 à 100
caractères d'un mot voisin, avec et sans libellé d'identifiant dans la fenêtre ;
mesurer par `Ecluse.redact` les identifiants passés sans masquage ni
avertissement. Rapport dans `agent/specs/P2-292.md`. **Rien n'est corrigé.**
**Fini quand** : tableau mot voisin × distance × (avec / sans libellé) des
identifiants passés sans avertissement, et recommandation chiffrée (garder,
raccourcir la fenêtre, retirer un mot).

### P2-293 — IBAN en paires : sonde élargie (mesure)

P2-288 (`agent/specs/P2-288.md`) a chiffré cinq gardes contre les 13 faux accords
« FR + séparateur + 11 paires + 1 », mais sur une sonde à espaces seuls. Travail :
élargir `bench/generate_sonde_gardes.py` (ou une sonde dédiée, graine 42) aux
séparateurs point, tiret et barre, et aux corps avec confusions d'OCR (O/o, l/I),
clé juste et clé fausse ; mesurer par `Ecluse.redact` le coût de chaque garde de
P2-288 (IBAN perdus) et son gain (faux accords évités au témoin élargi de
P2-279). Rapport dans `agent/specs/P2-293.md`. **Rien n'est corrigé.** **Fini
quand** : tableau garde × écriture (perdus, évités) et recommandation chiffrée.

### P2-294 — Établissements en 60 colonnes (code)

**Bloquée (PR #551, fermée sans fusion)** : la fiche est fausse. Les trois
documents ne sont pas couverts en partie : `Ecluse.redact` les refuse en entier
(tableau ambigu, aucune fuite). Remplacée par P2-296.

Après P2-289, trois établissements du corpus flou réaliste coupé à 60 colonnes
restent couverts en partie par `Ecluse.redact` (« IME La Source », « CH de
Vesoul », « SSIAD de Gray », identiques avant et après P2-289). Travail : test
qui montre chaque cas, puis correction (recollage de fin de ligne ou portée du
nom d'établissement), sans changer les prédictions ailleurs. **Fini quand** :
400 / 400 couverts en entier sur le réaliste à 60 colonnes ; prédictions
identiques sur les autres corpus (`bench/equivalence_predictions.sh`) ;
`controle_etat.py` conforme (bloc régénéré pour les seules lignes prévues).

### P2-295 — « Type + mot générique » (spec)

P2-285 et P2-289 : sur 200 000 documents sans personne, 2 063 voient masqué un
établissement générique (« Résidence Autonomie », « Foyer d'accueil »…). La
décision est au mainteneur. Travail : spec dans `agent/specs/P2-295.md`, avec au
moins trois options chiffrées par mesure (laisser ; liste fermée de mots
génériques ; exiger un nom propre après le type), chacune avec ses masquages à
tort évités et ses établissements annotés perdus sur les corpus flou réaliste,
adversarial et principal, et une recommandation. **Aucune ligne de code de
production.** **Fini quand** : tableau option × (évités, perdus) et questions
fermées pour le mainteneur.

### P2-296 — Faux tableau à 60 colonnes (mesure)

P2-294 (PR #551) : sur le flou réaliste coupé à 60 colonnes
(`generate_corpus_flou.py --n 400 --seed 42`, puis
`generate_corpus_mise_en_page.py --largeur 60`), les documents 27, 292 et 395
sont refusés par `Ecluse.redact` (`TableauAmbiguException`, « ligne 7 : 3
colonnes au lieu de 2 »). Le refus fait ce qu'il doit : rien ne part. Mais trois
documents sur 400 (0,75 %) ne sont pas traités du tout. Travail : trouver pourquoi
la coupure à 60 colonnes fabrique un tableau de noms (`tableau_csv.dart`) ;
simuler au plus trois règles plus strictes (le temps de la mesure, jamais
commitées) et mesurer pour chacune, par `Ecluse.redact` : documents refusés à tort
évités sur les largeurs 60 et 90, et vrais tableaux de noms **acceptés à tort**
(donc envoyés) sur les corpus de tableaux du dépôt. Rapport dans
`agent/specs/P2-296.md`. **Rien n'est corrigé.** **Fini quand** : cause écrite,
tableau règle × (refus évités, vrais tableaux acceptés à tort), recommandation
chiffrée. Si une règle accepte un seul vrai tableau à tort, elle est déconseillée
(règle 4 de `CLAUDE.md`).

### P2-297 — Établissements en majuscules sans type `etablissement` (mesure)

P2-290 et P2-295 : en majuscules, 69 établissements sur 400 du flou réaliste et
98 sur 114 de l'adversarial sont couverts en entier, mais par aucune entité de
type `etablissement`. Travail : par `Ecluse.redact`, dire par quel type chacun est
couvert (personne, lieu, autre), document par document, et ce que cela change
pour la restauration et pour le rapport de risque (type affiché, F). Vérifier si
`LIMITES.md` le dit déjà (mots-clés lus dans leur casse d'origine). Rapport dans
`agent/specs/P2-297.md`. **Rien n'est corrigé.** **Fini quand** : tableau type
couvrant × corpus, effet sur la restauration et sur le rapport, et
recommandation chiffrée (correction ou ligne de `LIMITES.md`).

### P2-298 — Témoin de 480 documents : mettre à jour le comparatif (code)

P2-290 : après P2-289, Écluse masque à tort 9 documents sur 480 du témoin sans
donnée personnelle (contre 16), tous « Résidence Autonomie » ou « Foyer D'accueil
Médicalisé ». `bench/COMPARATIF.md` (ligne « Documents masqués à tort ») et
`bench/ARTICLE.md` disent encore 16 / 480. Travail : rejouer
`python3 bench/comparatif.py --temoin` sur `main`, reporter les chiffres Écluse
(documents et caractères), dire en une phrase d'où viennent les 9 restants et
renvoyer à P2-295 ; ne toucher aucun chiffre des autres outils sans l'avoir
rejoué. **Fini quand** : les deux fichiers disent la valeur rejouée, la commande
pour la reproduire y figure, `controle_etat.py` conforme.

### P2-299 — Garde du mot voisin : avertissement au lieu du silence (code)

Décision du 26 novembre, point 3. Mesure P2-292 : quand « code », « digicode »,
« mot de passe », « mdp » ou « pin » précède à moins de 100 caractères un
identifiant dicté non reconnu sans libellé, la garde de P2-282 coupe le
signalement et 94 % de ces identifiants partent sans avertissement. Travail : test
d'abord (le corpus de `bench/generate_corpus_mot_voisin.py` montre le silence),
puis, dans ce cas seulement, émettre un avertissement distinct et moins pressant
(« suite de nombres dictés précédée d'un mot comme “code” : non masquée,
à vérifier »), jamais la valeur. Le signalement ordinaire reste coupé.
**Fini quand** : par `Ecluse.redact`, 0 identifiant du corpus mot voisin
(≤ 100 caractères, sans libellé) sans aucun avertissement (contre 6 214) ; les
témoins de P2-291 donnent toujours 0 signalement « nombre dicté non reconnu » à
tort, et le nombre d'avertissements distincts y est écrit dans `bench/ETAT.md`
(attendu : de l'ordre de 49 sur le témoin durci) ; aucun masquage changé ailleurs
(`bench/equivalence_predictions.sh`) ; `LIMITES.md` dit le nouvel avertissement.

### P2-300 — Gardes de P2-272 (code)

Décision du 26 novembre, points 0 et 1. Travail : brancher, dans le code produit,
les quatre gardes mesurées par `agent/specs/P2-272.md`
(`bench/gardes_faux_accords_patch.py`) : `nir_suitelettre`, `finess_suitelettre`,
`adr_confusables`, `iban_g45`. Pour `iban_g45`, un IBAN à clé fausse en groupes de
trois que la garde ne masque plus produit un avertissement « à vérifier » dans
`RedactResult.warnings` (sans la valeur). Test d'abord pour chaque garde.
**Fini quand** : témoin durci de P2-268 14 → 2 documents masqués à tort ; 0
identifiant perdu sur v3, libellé fort, OCR et 200 000 documents ; sonde de
`bench/generate_sonde_gardes.py` : les 40 IBAN en groupes de trois sont tous
signalés ; `controle_etat.py` conforme, bloc régénéré pour les seules lignes
prévues ; `LIMITES.md` à jour.

### P2-301 — « Type + mot générique » : liste fermée (code)

Décision du 26 novembre, point 5 (option 2 de `agent/specs/P2-295.md`). Travail :
un type d'établissement en toutes lettres suivi seulement de mots d'une liste
fermée de mots génériques (au départ : Autonomie, D'accueil, Médicalisé,
Médicalisée, Services, Social, Agricole) n'est pas masqué. La liste est une
constante documentée, extensible. Test d'abord. **Fini quand** : 200 000 documents
sans personne 2 063 → 0 pour les mots de la liste ; témoin de 480 documents
9 → 0 ; 0 établissement annoté perdu sur le flou réaliste et adversarial (7
présentations) ; `LIMITES.md` dit que la liste ne connaît que ce qu'elle contient
et qu'un établissement réellement nommé « Résidence Autonomie » ne serait pas
masqué ; si P2-298 est fusionnée, `bench/COMPARATIF.md` et `bench/ARTICLE.md`
mis à jour avec la valeur rejouée.

### P2-302 — Mots courants lus comme commune (code)

Décision du 26 novembre, point 6 (recommandation de `agent/specs/P2-287.md`).
Travail : liste d'exclusion des mots courants qui, en tête de phrase, ne sont pas
lus comme un lieu (« Son », « Aucun », « Mont », « Cours », « Salles », « Vers »,
« Contre »…, les 27 mots du rapport), extensible, avec
`bench/generate_sonde_mots_courants.py` comme jeu de test. Test d'abord. **Fini
quand** : 0 lieu légitime perdu sur les corpus de quasi-identifiants ; les 18 653
lieux de mots courants du rapport écartés ; la sonde combinée de P2-287 (§ 5)
rend un rapport évalué avec ou sans la phrase ; `LIMITES.md` dit que la liste ne
couvre que ce qu'elle contient.

### P2-303 — Gardes silencieuses : inventaire (mesure)

Principe du 26 novembre, point 0 : une garde ne rend jamais une donnée
silencieuse. Travail : lister, dans `packages/ecluse_core` et
`packages/ecluse_redact`, chaque test qui empêche d'émettre une entité ou un
signalement pour éviter un masquage à tort (gardes de contexte, listes
d'exclusion, seuils) ; pour chacun, dire s'il laisse un avertissement et mesurer
par `Ecluse.redact`, sur une sonde synthétique, combien de vrais identifiants il
laisse partir sans avertissement. Les listes d'exclusion de lieux et
d'établissements (mots qui ne sont pas des identifiants) sont à classer à part.
Rapport dans `agent/specs/P2-303.md`. **Rien n'est corrigé.** **Fini quand** :
tableau garde × (avertissement oui/non, identifiants silencieux sur la sonde),
et une proposition de tâche `code` par garde silencieuse coûteuse.
