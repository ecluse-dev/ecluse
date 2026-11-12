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
| P2-103 | mesure | Généralisation du lieu : effet de « département N » non relu sur F et sur l'évaluation | P2-102 | PR ouverte |
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
| P2-140 | mesure | Dossiers en minuscules et en casse de phrase : cohérence des jetons, collisions, fausses fusions (corpus dossiers × variantes de casse) | P2-139 | PR ouverte |
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
| P2-158 | code | IBAN coupé par une fin de ligne juste avant un groupe qui commence par une lettre (« …0270⏎D932… »), dernier identifiant manqué du corpus « mise en page » | P2-153 | PR ouverte |
| P2-159 | code | Âges dans `ecluse_reid` : nombre en lettres suivi de « ans » (les 15 cas de P2-154) et tranche « de 80 à 85 ans » (regroupe P2-163) | P2-154 | à faire |
| P2-160 | code | Dictée, les deux corpus de mesure : témoin « mots-nombres » et variantes de dictée manquantes du corpus transcrit, avec mesure de départ ; aucun détecteur modifié (regroupe P2-161) | P2-155 | à faire |
| P2-161 | code | Corpus transcrit : variantes de dictée manquantes (« double zéro », « septante », « o six », séparateurs perdus) et mesure de départ ; aucun détecteur modifié | P2-155 | regroupée (P2-160) |
| P2-162 | spec | Fin de ligne dans un identifiant : faut-il descendre la neutralisation de `ecluse_redact` dans `ecluse_core` ? | P2-153 | à faire |
| P2-163 | code | Tranche d'âge « de 80 à 85 ans » : lire les deux bornes (aujourd'hui seule la seconde sort) | P2-154 | regroupée (P2-159) |

La phase 3 sera découpée ici quand la phase 2 sera fusionnée.

---

## Fiches détaillées

Les fiches des tâches fusionnées sont dans `agent/QUEUE-archive.md` (historique, à ne lire que si une fiche ouverte y renvoie).

### P2-86 à P2-101 — Fin de la phase 2

Découpage : `agent/specs/P2-decoupage-fin.md` (fusionné le 2 novembre 2026).
Chaque tâche y a sa ligne, son bloc et ses bloquants ; les fiches ci-dessous
ne reprennent que ce qui manque pour la prendre.

- **P2-88** : document seulement, aucune dépendance. Repartir de
  `agent/specs/P2-86.md` § 2.1 pour la correspondance des labels du candidat 1
  vers les types des corpus flous. La commande finale réutilise
  `score_flou.py --pred "NER=…"`. **Fini quand** : un tiers peut lancer la
  mesure sans autre information.
- **P2-91** : ajout au `RiskReport` existant, sans changer `maskedText`. Test
  d'équivalence d'abord : sans `riskReference`, sortie inchangée octet pour
  octet (décision P2-03 n° 2). **Fini quand** : chaque suggestion porte ses
  offsets dans le texte masqué (celui que l'appelant généraliserait, le
  rapport porte sur lui) et le F estimé après généralisation.
- **P2-92** : jamais déclenchée par le moteur ; une proposition périmée est
  refusée comme dans l'aperçu (P2-19). La généralisation n'entre pas dans la
  table de correspondance (irréversible).
- **P2-93** : mesurer, ne rien corriger.
- **P2-96** : attend P2-96a.
- **P2-98** : générer le texte transcrit à partir du corpus v3 (minuscules,
  ponctuation retirée, nombres en lettres), graine 42. Mesurer le rappel par
  type ; ne rien corriger.
- **P2-100** : méthode de la PR #242 (meilleur de trois essais, deux tailles
  dans un rapport 4, seuil 8). Un paquet par commit. **Fini quand** : plus
  aucun test ne compare un temps à une borne absolue.
- **P2-101** : `humain` tant que l'accord pour toucher `.github/` n'est pas
  donné (zone interdite aux agents).
- **P2-102** : défauts mesurés par P2-93 (#262) : « 104 ans » relu dans
  « 100-104 ans », profession généralisée non relue. **Fini quand** : chaque
  palier d'âge et de profession produit par `nextRung` se relit tel quel
  (`qiValueLabel` puis `extractQiSpans`).
- **P2-103** : mesurer, ne rien corriger. Le corpus réaliste de P2-93 ne
  généralisait jamais le lieu ; construire au besoin des cas où la
  suggestion retenue porte sur le lieu, puis comparer F simulé (`fAfter`) et
  F recalculé après `appliquerGeneralisations`.
- **P2-140** : **mesure seulement.** Les détecteurs de casse (P2-119 à
  P2-139) n'ont été mesurés que document par document. Appliquer
  `bench/variantes_casse.py` aux trois corpus de dossiers
  (`generate_corpus_dossiers.py --n 400 --seed 42`), puis
  `run_dossiers_bench.dart --dossier` et `score_dossiers.py` sur chaque
  variante (`_minuscules`, `_phrase`, `_majuscules`). Rapporter dans
  `agent/specs/P2-140.md`, à côté des chiffres en casse ordinaire
  (`bench/ETAT.md`) : cohérence, collisions, fausses fusions, restaurations
  non identiques, mentions non détectées. Signaler en particulier si une
  même personne reçoit deux jetons selon la casse de ses mentions. Aucun
  code de production.
- **P2-129** : **mesure seulement, ne rien corriger.** Ajouter à
  `bench/generate_corpus_pathologies.py` un corpus `formes_libres` (graine
  fixe, préfixe stable, corpus existants inchangés : le vérifier par
  comparaison des sorties) avec des formes que P2-125/126 ne couvrent pas :
  « non diabétique », « DT2 », « diabète : non », « BPCO ? à éliminer »,
  « suspicion de », « ATCD : », fautes courantes (« diabete »,
  « épilépsie »). Annoter ce qui est une pathologie de la personne, ne pas
  annoter les négations. Mesurer avec `bin/run_pathologies_bench.dart`
  (brut et rattachées) et rapporter dans `agent/specs/P2-129.md`, par forme,
  ce qui est trouvé, manqué, ou rattaché à tort. Tests Python du nouveau
  corpus.
- **P2-130** : **mesure seulement.** Rejouer sur `main` tous les corpus
  documentés dans `bench/README.md` et les rapports `agent/specs/P1-36.md`,
  `P2-98.md`, `P2-117.md`, `P2-121.md`, `P2-124.md`, `P2-125.md` (mêmes
  commandes, mêmes graines), et consigner dans un nouveau `bench/ETAT.md` un
  tableau unique : corpus, commit, précision, rappel, fuite au caractère,
  faux positifs du témoin. Signaler tout écart avec les chiffres des
  rapports. Aucun code de production.
- **P2-122** : sur le modèle de `MinusculesRecapitaliseDetector` (P2-120,
  à lire d'abord) : un texte **sans aucune minuscule** reçoit un texte
  d'ombre de même longueur en casse de titre (mots outils, unités et noms de
  comptage en minuscules, sigles d'établissement gardés en capitales),
  passé à `AdresseDetector` et `EtablissementDetector`. Actif seulement sans
  aucune minuscule. Mesure avant/après obligatoire (commandes et chiffres de
  départ : `agent/specs/P2-121.md`) : fuite par type sur les corpus flous
  réaliste et adversarial en majuscules ; **budget : 0 faux positif** sur
  le témoin en majuscules (194 aujourd'hui) ; sorties **identiques** sur les
  corpus d'origine, en minuscules et v3. Les noms ne sont pas dans le
  périmètre. Ne pas modifier les détecteurs existants.
- **P2-120** : sur le modèle de `NomMinusculesDetector` (P2-119) : un
  détecteur actif **seulement** si le texte n'a aucune majuscule, qui
  rattrape les adresses (numéro + type de voie : « 7 impasse des
  charmilles », code postal + commune) et les établissements (mot-clé de
  `etablissement_keywords.dart` suivi de son nom, arrêté par un mot outil).
  Mesure avant/après obligatoire sur `corpus_flou_{realiste,adversarial}`
  mis en minuscules (`text.lower()`, offsets inchangés) : fuite au caractère
  par type (`score_flou.py`) ; **budget : 0 faux positif** sur
  `corpus_flou_temoin` en minuscules, et sorties **identiques** sur les
  corpus d'origine. Commandes et chiffres de départ : `agent/specs/P2-117.md`
  (adresse et établissement : 100 % de fuite). Ne pas toucher aux
  détecteurs existants.
- **P2-115** : lecture seule de l'asset, sur le modèle de
  `first_name_gazetteer.dart` (gzip, chargement paresseux). Ignorer la
  ligne d'en-tête « # ». API minimale : catégorie d'un ORPHAcode, et
  ensemble des mentions normalisées avec leur ORPHAcode. Tests : l'asset
  réel (« Sclérose latérale amyotrophique » → « Maladie neurologique
  rare », « SLA » présent, « ALD » absent), plus un asset synthétique pour
  les cas de refus (fichier vide, colonne manquante). **Pas** d'appariement
  dans du texte ni de branchement dans `ecluse_reid` : ce sera une tâche
  suivante, après P2-110 et P2-112 (corpus pour mesurer). Ne pas modifier
  l'asset ni le script.
- **P1-36** : mesurer, ne rien corriger. Rejouer les commandes [C1], [C2],
  [C4] et [C5] de `bench/ARTICLE.md` sur `main` et rapporter le tableau
  Écluse (précision, rappel, F1 par type, faux positifs par type) et le
  résultat de [C5], à côté des chiffres de l'article. Contexte :
  `agent/specs/P1-12-relecture.md`. Ne pas modifier `bench/ARTICLE.md` ni
  `bench/requirements.txt` : signaler les écarts dans la PR.
- **P2-105** : Python, dans `bench/`, comme les autres générateurs ; aucun
  LLM appelé. Partir de textes passés dans `Ecluse.redact` et annoter dans
  le générateur les indices restants (rôle unique, événement daté, rareté
  locale, coréférence). Voir `agent/specs/P2-104.md` § 3. **Fini quand** :
  trois jeux (indices, témoin, injection) reproductibles à graine égale.
- **P2-106** : comme `agent/specs/P2-86.md`. Si une page n'est pas joignable,
  le dire ; ne jamais supposer une licence.
- **P2-107** : document seulement, aucune dépendance, sur le modèle de
  `bench/ner_predictions.md`. Candidat de départ : SmolLM3-3B
  (`agent/specs/P2-106.md`). Partir du prompt versionné et du parseur de la
  branche `feat/llm-scaffold`, sans fusionner la branche. Dire comment
  obtenir le statut « non vérifié » sur un échec.
- **P2-109** : `humain` parce que le travail se fait sur la branche
  `feat/llm-scaffold`, pas sur une branche partie de `main` (règle 7). Constat
  (P2-107) : sur un échec d'analyse, `LlmRedactVerifier` rend une liste vide
  et `isClean` vaut `true`, contraire à la condition D de P2-104. Le
  prompt `v1` tronque aussi le texte à 4 000 caractères sans changer le
  statut. Le mainteneur décide quand et comment corriger la branche.
- **P2-112** : Python, dans `bench/`, comme `generate_corpus_semantique.py`.
  Mentions tirées de `agent/specs/P2-94-table.md` § 3 avec leur catégorie et
  leur système ; témoin avec des faux amis (« SEP » en dehors de la
  neurologie, « cancer » au sens figuré, « dialyse » d'un appareil).
  **Fini quand** : corpus reproductible à graine égale, offsets exacts,
  tests passés.
- **P2-153** : Python, dans `bench/`, comme les autres générateurs
  (`generate_corpus_mise_en_page.py`), plus ses tests. Entrée : un corpus
  `.jsonl` existant ; sortie : le même, où chaque texte est recoupé aux
  espaces à une largeur donnée (60 puis 90 caractères), sans rien changer
  d'autre, avec les offsets des entités recalculés exactement. Graine 42.
  Ajouter à `bench/etat.sh` et à `bench/ETAT.md` une section « mise en
  page » : fuite par type sur le réaliste, l'adversarial et le témoin flous,
  rappel sur le corpus structurel. **Ne modifier aucun détecteur** : la
  règle « un span ne traverse jamais un saut de ligne » (`LIMITES.md` § 5.2)
  est assumée ; la tâche la chiffre. **Fini quand** : corpus reproductible à
  graine égale, offsets vérifiés par un test, chiffres dans `ETAT.md`.
- **P2-154** : mesurer, ne rien corriger. Partir de `bench/qi/` (corpus
  adversarial, 400 documents, `score_qi.py`). Classer les âges non couverts
  par forme (« bientôt 80 ans », « la soixantaine », âge en lettres…), avec
  le nombre de cas et un exemple synthétique par forme. Rapport dans
  `agent/specs/P2-154.md`, avec pour chaque forme le risque de faux positif
  attendu si on la couvrait.
- **P2-155** : document seulement (`agent/specs/P2-155.md`), aucune ligne de
  code de production. Contexte : `agent/specs/P2-98.md` (rappel 0 % sur le
  corpus transcrit, `bench/generate_corpus_transcrit.py`). Traiter : les
  façons de dicter un NIR, un téléphone, un IBAN, un RPPS (chiffre à
  chiffre, par paires, « quatre-vingt-dix », « soixante et onze », « double
  zéro ») ; où faire la conversion (vue de détection seulement, le texte
  n'est jamais réécrit, offsets conservés) ; les ambiguïtés (« un » article
  ou chiffre, « neuf » adjectif) ; le budget de faux positifs sur les
  témoins ; le plan de mesure avant/après. Finir par les décisions qui
  reviennent au mainteneur.
- **P2-156** : mesurer, ne rien corriger sur `main`. Sur la branche de la
  tâche, monter les trois paquets, lancer `melos run analyze` et `melos run
  test`, rejouer les PDF synthétiques (`bench/generate_pdfs.py`). Rapport
  dans `agent/specs/P2-156.md` : ce qui casse, l'effort estimé, les notes de
  version lues. **Ne pas inclure** le changement de `pubspec` dans la PR :
  seul le rapport est fusionnable ; le mainteneur décide de la montée.
- **P2-157** : mesurer, ne rien corriger. `bench/flou/`, corpus adversarial,
  type adresse. Même forme de rapport que P2-154, dans
  `agent/specs/P2-157.md`.
- **P2-158** : extension étroite de P2-152 (`_coupuresDeLigne`,
  `ecluse_redact/lib/src/ecluse.dart`). Aujourd'hui la fin de ligne n'est
  neutralisée que si ce qui suit est un chiffre ; l'admettre aussi devant
  **une** majuscule suivie d'un chiffre. Test d'abord dans
  `identifiant_coupe_test.dart` (le cas rouge, plus des contre-exemples qui
  doivent rester intacts : « Salle 4⏎A2 fermée », « Vol 12⏎B7 porte », « le
  3⏎C4 du plan »). **Fini quand** : section « mise en page » de
  `bench/ETAT.md` à 778/778 par `Ecluse.redact` à 60 colonnes, tous les
  autres chiffres du tableau de bord inchangés, `LIMITES.md` § 5.2 mis à
  jour (y citer aussi les chiffres de P2-153).
- **P2-159** : `ecluse_reid`, `qi_extraction.dart`. Périmètre décidé par le
  mainteneur le 12 novembre : seulement un nombre en lettres **suivi de
  « ans »** (unités, dizaines, « et un », « soixante-dix », « quatre-vingt »,
  avec trait d'union ou espace). **Hors périmètre** : « la soixantaine »,
  « octogénaire », « dans sa quatre-vingtième année » (choix de produit, ne
  pas y toucher). Réutiliser l'exclusion des durées (`_dureeAvant`, P2-136).
  Test d'abord sur les 15 cas de `agent/specs/P2-154.md` § 2. **Fini
  quand** : âges non couverts du corpus QI adversarial 12,7 % → 0 %, corpus
  témoin QI toujours à 0 extraction à tort, reste du tableau de bord
  inchangé.
  **Second volet (ancienne P2-163)**, dans la même PR : « de 80 à 85 ans »
  ne sort aujourd'hui que la borne 85 (`agent/specs/P2-154.md` § 3). Test
  d'abord (« de 80 à 85 ans », « entre 60 et 65 ans », « 80-85 ans ») et
  contre-exemples (« de 2 à 3 ans de suivi », durée). Décider dans la PR, en
  le justifiant, si l'extraction est une tranche ou deux âges, sans changer
  le format du rapport de risque. **Fini quand**, pour les deux volets : cas
  rouges verts, âges non couverts du QI adversarial à 0 %, corpus QI réaliste
  et témoins inchangés, reste du tableau de bord inchangé.
- **P2-160** : Python, dans `bench/`, avec ses tests, sur le modèle des
  autres générateurs. Au moins 300 phrases synthétiques, graine 42, dont une
  moitié avec au moins 6 mots-nombres consécutifs : montants (« deux cent
  cinquante mille euros »), dates en lettres, quantités, consignes
  (« comptez dix, répétez six fois »). Aucune entité annotée : c'est un
  témoin. Ajouter au tableau de bord une ligne « témoin mots-nombres :
  N prédictions » par `Ecluse.redact`. **Ne modifier aucun détecteur.**
  Voir `agent/specs/P2-155.md` § 5.
  **Second volet (ancienne P2-161)**, dans la même PR :
  `bench/generate_corpus_transcrit.py` et ses tests. Ajouter les variantes de
  `agent/specs/P2-155.md` § 2 absentes du corpus : « double / triple »,
  « septante / huitante / nonante », zéro dit « o », traits d'union et
  virgules perdus. Offsets exacts, graine 42. Mesurer le rappel et la fuite
  de départ par variante et par type, et les écrire dans `bench/ETAT.md`.
  C'est le « défaut d'abord » de la future tâche de code. **Fini quand** :
  les deux corpus sont reproductibles à graine égale, leurs chiffres sont
  dans `bench/ETAT.md`, le reste du tableau de bord est inchangé.
- **P2-162** : document seulement (`agent/specs/P2-162.md`). Constat de
  P2-153 : par `Ecluse.redact`, 777 identifiants sur 778 sont détectés à
  60 colonnes ; par le moteur seul (`EcluseEngine`), 87,7 %. Une
  application qui appelle `ecluse_core` directement manque donc les
  identifiants coupés. Décrire : qui appelle le moteur seul aujourd'hui
  (`ecluse_bench`, `ecluse_demo`, autres ?), les options (descendre la
  neutralisation dans `ecluse_core`, la documenter comme limite du moteur,
  refuser l'appel direct), leurs risques (faux positifs, offsets, coût,
  détecteurs purs), le plan de mesure. Finir par la décision qui revient au
  mainteneur.
- **P2-161** : regroupée dans P2-160 le 12 novembre (une seule PR pour les
  deux corpus de dictée).
- **P2-163** : regroupée dans P2-159 le 12 novembre (une seule PR pour les
  âges).
