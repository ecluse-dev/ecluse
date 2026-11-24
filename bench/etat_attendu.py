"""Lignes attendues dans la sortie de `bench/etat.sh` (P2-168).

Pour chaque section (« ## … »), des motifs de ligne et le nombre minimal de
lignes qui doivent les satisfaire. Un motif absent ou trop rare est un trou :
une section qui se vide en silence (un filtre `grep` qui ne trouve plus rien,
une commande dont la sortie est jetée) ne passe plus inaperçue.

Les nombres sont les comptes de lignes, jamais des valeurs mesurées : un
chiffre qui change n'est pas l'affaire de ce fichier (c'est `bench/ETAT.md`).
Les corpus témoins (sans entité annotée) n'ont pas de ligne de score ; leur
ligne « entites predites » est attendue à la place.

Ajouter une ligne au tableau de bord, c'est ajouter ici son motif.
"""

# (préfixe du titre de section, [(motif de ligne, minimum, explication)])
ATTENDU = [
    ("## commit", [
        (r"^## commit [0-9a-f]+$", 1, "numéro de commit"),
    ]),
    ("## v3 (identifiants structurels)", [
        (r"^Ecluse +TOTAL ", 1, "score v3 du moteur seul, tous types (siren compris)"),
        (r"^Ecluse \(c\) +COMMUNS ", 2,
         "score v3 du moteur seul, types communs (strict, souple ; P2-261)"),
        (r"^Ecluse \(e\) +(strict|souple) ", 2,
         "ligne siren à part (strict, souple ; P2-261)"),
    ]),
    ("## v3 transcrit", [
        (r"^# (sans_ponctuation|en_lettres)$", 2, "deux variantes"),
        (r"^Ecluse +TOTAL ", 2, "score de chaque variante"),
    ]),
    ("## v3 dictée", [
        (r"^# \w+ : moteur seul \(ecluse_core\)$", 4, "4 variantes, moteur seul"),
        (r"^Ecluse +TOTAL ", 4, "score moteur seul de chaque variante"),
        (r"^# \w+ : Ecluse\.redact \(chemin du produit\)$", 6,
         "6 variantes, Ecluse.redact"),
        (r"^finess .* TOTAL \d+/\d+ \(", 6, "rappel Ecluse.redact"),
        (r"^  fuite au caractère : .* TOTAL ", 6, "fuite au caractère"),
    ]),
    ("## témoin mots-nombres", [
        (r"^témoin mots-nombres : \d+ prédictions sur \d+ phrases$", 1,
         "témoin mots-nombres"),
    ]),
    ("## mots-nombres durci", [
        (r"^mots-nombres durci : \d+ prédictions sur \d+ phrases$", 1,
         "témoin mots-nombres durci (P2-270, P2-275)"),
    ]),
    ("## fuite par OCR", [
        (r"^TOTAL (nir|rpps|iban|finess|siren) +(libelle|sans_libelle) ", 10,
         "5 types, avec et sans libellé (P2-264, P2-268)"),
        (r"^témoin négatif (temoin|temoin_dur) : \d+ / \d+ documents", 2,
         "témoin d'origine et témoin durci"),
    ]),
    ("## OCR derrière un libellé", [
        (r"^TOTAL (nir|rpps|iban) +libelle_cle_fausse ", 3,
         "NIR, RPPS, IBAN à clé fausse derrière un libellé (P2-275)"),
    ]),
    ("## sonde des gardes", [
        (r"^sonde (adresse|finess|iban|nir) \S+ .+ : couverts \d+/\d+$", 27,
         "identifiants de la sonde, par type, clé et écriture (P2-278, P2-283)"),
        (r"^sonde TOTAL : couverts \d+/\d+$", 1, "total de la sonde"),
    ]),
    ("## faux accords par détecteur", [
        (r"^faux accords : .+ : \d+ documents, \d+ avec au moins une entité$", 2,
         "deux corpus sans donnée personnelle (P2-279, P2-284)"),
        (r"^(.+ : \d+ / \d+ documents \(\d+\.\d+ %, IC 95 % \[\d+\.\d+ ; \d+\.\d+\] %\), "
         r"\d+ entité\(s\)|aucun détecteur : 0 / \d+ documents \(IC 95 % "
         r"\[0\.000 ; \d+\.\d+\] %\))$", 2,
         "taux de documents à tort par détecteur, avec intervalle de Wilson"),
    ]),
    ("## identifiants dictés abîmés", [
        (r"^# (mot_perdu|cle_fausse)$", 2, "deux abîmements (P2-274, P2-278)"),
        (r"^(nir|iban|TOTAL) +n= *\d+ +masqués= *\d+ \(dont signalés +\d+\) +"
         r"signalés seulement= *\d+ +rien= *\d+$", 6,
         "NIR, IBAN et total, pour chaque abîmement"),
    ]),
    ("## flou", [
        (r"^# \w+$", 13, "13 corpus flous"),
        (r"^  restaurations non identiques .* : \d+$", 13,
         "restaurations non identiques"),
        (r"^  entites predites \d+$", 13, "entités prédites (témoins compris)"),
        (r"^GLOBAL +\d+", 8, "ligne GLOBAL des 8 corpus annotés"),
        (r"^nom +\d+", 8, "ligne nom"),
        (r"^adresse +\d+", 8, "ligne adresse"),
        (r"^etablissement +\d+", 8, "ligne établissement"),
    ]),
    ("## quasi-identifiants", [
        (r"^# \w+$", 4, "4 corpus QI"),
        (r"^age +\d+", 2, "âge, réaliste et adversarial"),
        (r"^lieu +\d+", 2, "lieu"),
        (r"^profession +\d+", 2, "profession"),
        (r"^  Extractions totales +: \d+$", 2, "témoin et témoin durées"),
    ]),
    ("## quasi-identifiants par Ecluse.redact", [
        (r"^# (realiste|adversarial)$", 2, "2 corpus (réaliste et adversarial)"),
        (r"^  documents +: \d+$", 2, "nombre de documents"),
        (r"^  patronyme en clair +: \d+ document", 2,
         "patronymes en clair, mesure du produit"),
    ]),
    ("## généralisation appliquée", [
        (r"^# \w+$", 4, "3 corpus et le lieu"),
        (r"^  documents avec suggestion :", 3, "documents avec suggestion"),
        (r"^  refus ou exception à l'application :", 3, "refus"),
        (r"^  F médian :", 3, "F médian"),
        (r"^  bande recalculée :", 1, "bande recalculée (lieu)"),
        (r"^  QI lieu dans l'évaluation", 1, "QI lieu relu"),
        (r"^  F recalculé vs F simulé :", 1, "F recalculé vs simulé"),
    ]),
    ("## dossiers", [
        (r"^# \w+$", 9, "9 corpus de dossiers"),
        (r"^  Cohérence ", 9, "titre de cohérence"),
        (r"^    nom +\d+ / +\d+", 9, "cohérence des noms (annoncée par ETAT.md)"),
        (r"^  Collisions ", 9, "collisions"),
        (r"^  Fausses fusions ", 9, "fausses fusions"),
        (r"^  Restaurations non identiques ", 9, "restaurations non identiques"),
        (r"^  Mentions annotées non détectées ", 9, "mentions non détectées"),
    ]),
    ("## pathologies", [
        (r"^# ", 4, "indices, variantes, formes_libres, maladies rares"),
        (r"^  indices : TP", 2, "indices rattachés"),
        (r"^  témoin : ", 2, "témoin"),
        (r"^  TOTAL TP", 2, "formes libres (brut, rattachées)"),
        (r"^corpus indices :", 1, "maladies rares, corpus indices"),
        (r"^corpus temoin :", 1, "maladies rares, témoin"),
        (r"^échantillon Orphanet", 1, "échantillon Orphanet"),
    ]),
    ("## témoin nombres à cinq chiffres", [
        (r"^témoin cinq chiffres : \d+ phrases, \d+ prédiction", 1,
         "compte des adresses prédites à tort (P2-167)"),
        (r"^  position=(debut|milieu) : \d+ / \d+", 2, "par position"),
    ]),
    ("## témoin déterminant après cinq chiffres", [
        (r"^témoin cinq chiffres : \d+ phrases, \d+ prédiction", 1,
         "compte des adresses prédites à tort (P2-187)"),
        (r"^  casse=(capitales|ordinaire) : \d+ / \d+", 2, "par casse"),
    ]),
    ("## code postal en tête", [
        (r"^code postal en tête : \d+ adresses, \d+ laissée\(s\) en clair", 1,
         "adresses en tête laissées en clair (P2-177)"),
        (r"^  suite=(ligne|minuscule|ponctuation|rien) : \d+ / \d+ en clair",
         4, "par suite"),
        (r"^  témoin sans adresse : \d+ prédiction\(s\) à tort écartée", 1,
         "règle candidate simulée, gain sur le témoin"),
        (r"^  adresses annotées : \d+ perdue\(s\) sur \d+", 1,
         "règle candidate simulée, adresses perdues"),
    ]),
    ("## communes : nom en partie en clair après CEDEX", [
        (r"^cedex commune longue : \d+ adresses, \d+ avec au moins un "
         r"caractère en clair", 1, "balayage des communes (P2-178)"),
        (r"^  ecriture=(libelle|postale|libelle_espaces|capitales_tirets) : "
         r"\d+ / \d+ en défaut", 4, "par écriture"),
    ]),
    ("## communes en capitales : nom en partie en clair après CEDEX", [
        (r"^cedex commune longue : \d+ adresses, \d+ avec au moins un "
         r"caractère en clair", 1, "balayage en capitales avec CEDEX (P2-185)"),
        (r"^  cedex=CEDEX n : \d+ / \d+ en défaut", 1, "axe cedex=CEDEX n"),
    ]),
    ("## communes en capitales sans CEDEX", [
        (r"^cedex commune longue : \d+ adresses, \d+ avec au moins un "
         r"caractère en clair", 1, "balayage en capitales sans CEDEX (P2-200)"),
        (r"^  cedex=sans : \d+ / \d+ en défaut", 1, "axe cedex=sans"),
    ]),
    ("## communes en capitales sans CEDEX : formes et règles candidates", [
        (r"^sans CEDEX : \d+ adresses en partie en clair sur \d+, par forme",
         1, "ventilation par forme (P2-206)"),
        (r"^  forme [ABCDE] : \d+ adresse\(s\), \d+ commune\(s\)", 5,
         "formes A à E"),
        (r"^  forme autre : \d+ adresse\(s\)", 1, "forme « autre » (reste)"),
        (r"^balayage sans CEDEX : \d+ adresses en partie en clair", 1,
         "balayage, règles candidates simulées"),
        (r"^  règle=(exact_prefixe|exact_ligne|fin_de_ligne) : \d+ → \d+ en "
         r"partie en clair", 3, "balayage : trois règles"),
        (r"^  forme E : \d+ adresses, non simulable", 1, "forme E non simulée"),
        (r"^commune suivie, règles candidates \(", 2,
         "témoin commune suivie, deux régimes de casse"),
        (r"^  règle=(exact_prefixe|exact_ligne|fin_de_ligne) : \d+ / \d+ "
         r"caractères de suite masqués", 6, "témoin suivie : trois règles x 2"),
        (r"^témoin sans adresse annotée, règles candidates : \d+ phrases", 3,
         "témoins sans adresse : commune neutre, cinq chiffres, déterminant"),
        (r"^  casse=\w+ : \d+ / \d+ phrases à adresse prédite", 5,
         "par casse, trois témoins"),
    ]),
    ("## commune à mot de voie", [
        (r"^commune à mot de voie : \d+ documents, \d+ communes, \d+ "
         r"document\(s\) à adresse en partie en clair", 1,
         "balayage des communes à mot de voie (P2-213)"),
        (r"^  casse=(ordinaire|capitales) : \d+ / \d+ en défaut", 2,
         "par casse"),
        (r"^  cedex=(avec|sans) : \d+ / \d+ en défaut", 2, "par CEDEX"),
        (r"^  suite=(sans|mot|adresse) : \d+ / \d+ en défaut", 3,
         "par ligne suivante"),
        (r"^  voie=(sans|avec) : \d+ / \d+ en défaut", 2,
         "derrière ou non une vraie voie"),
        (r"^  mot de voie=\S+ : \d+ / \d+ en défaut", 5, "par mot de voie"),
        (r"^  en clair : vraie voie \d+, code postal \d+, commune \d+, "
         r"seconde adresse \d+", 1, "ce qui reste en clair"),
        (r"^  début en clair .* : \d+ document\(s\) ; fin du nom seule en "
         r"clair : \d+", 1, "signature du défaut"),
        (r"^  ligne « code postal \+ mot » masquée", 1, "masquage en trop"),
    ]),
    ("## communes en capitales hors référentiel", [
        (r"^écritures hors référentiel : \d+ adresses, \d+ communes des formes "
         r"A, C et D", 1, "population et écritures (P2-244)"),
        (r"^# table (complete|reduite) \(\d+ noms\)$", 2, "deux tables"),
        (r"^  variante=(reference|accents|st|apostrophe_collee|tiret_colle|"
         r"lettre_fautive|lettre_omise) : \d+ adresses, Ecluse\.redact seul "
         r"\d+ ; exact \d+ ; normalise \d+ ; distance1 \d+$", 14,
         "sept écritures, deux tables"),
        (r"^  écritures hors référentiel \(cinq variantes\) : \d+ adresses, "
         r"Ecluse\.redact seul \d+ ; exact \d+ ; normalise \d+ ; distance1 "
         r"\d+$", 2, "total des cinq écritures, deux tables"),
    ]),
    ("## courriers en capitales", [
        (r"^courriers : \d+ courriers, \d+ lignes, \d+ adresses annotées, "
         r"\d+ courrier\(s\) à adresse en partie en clair", 1,
         "courriers synthétiques (P2-210)"),
        (r"^  masquage en trop : \d+ courriers / \d+, \d+ lignes / \d+", 1,
         "masquage en trop"),
        (r"^  famille=(reference|montant|quantite|texte|adresse|"
         r"montant_adresse) : \d+ / \d+ lignes masquées en trop", 6,
         "six familles de lignes"),
        (r"^  types en trop : ", 1, "types de détection en trop"),
    ]),
    ("## SIREN masqués comme FINESS", [
        (r"^SIREN masqués comme FINESS : corpus v3 entier \d+ / \d+ nombres à "
         r"clé valide non annotés, témoin SIREN \d+ / \d+, SIREN voisins du "
         r"pendant FINESS \d+ / \d+$", 1, "SIREN masqués, trois jeux (P2-223)"),
        (r"^vrais FINESS en clair sans option : corpus v3 \d+ / \d+, pendant "
         r"FINESS \d+ / \d+$", 1, "vrais FINESS en clair sans option"),
        (r"^  témoin (libelle|ecriture)=\S+ : \d+ / \d+ masqués comme FINESS$", 6,
         "témoin par libellé et par écriture"),
        (r"^  option=(libelle_immediat|libelle_40|libelle_40_sans_mot_finess|"
         r"contexte_exige|prefixe) : SIREN masqués v3 \d+ / \d+, témoin "
         r"\d+ / \d+, voisins \d+ / \d+ ; vrais FINESS perdus en plus "
         r"\(en clair\) v3 \d+ / \d+, pendant \d+ / \d+$", 5, "cinq options"),
        (r"^  témoin : SIREN sous une détection de n'importe quel type \d+ / "
         r"\d+", 1, "SIREN sous n'importe quel type"),
        (r"^  option=luhn : SIREN du témoin valides à la clé du FINESS \d+ / "
         r"\d+ : aucune distinction possible$", 1, "contrôle de la clé de Luhn"),
    ]),
    ("## patronyme seul hors civilité", [
        (r"^noms hors civilité, patronyme seul : \d+ mentions, manquées "
         r"document par document \d+, en session \d+$", 1,
         "patronyme seul, document par document et en session (P2-218)"),
        (r"^noms hors civilité, plusieurs mots \(civilité ou prénom\) : \d+ "
         r"mentions, manquées document par document \d+, en session \d+$", 1,
         "noms à plusieurs mots, pour référence"),
        (r"^  tournure=.+ : \d+ / \d+ manqués document par document, "
         r"\d+ / \d+ en session$", 3, "ventilation par tournure"),
        (r"^tournures sans nom : \d+ documents, \d+ entité\(s\) annotée\(s\), "
         r"\d+ masqués à tort$", 1, "témoin sans nom de personne (P2-218)"),
        (r"^  tournure=.+ : \d+ / \d+ masqués à tort$", 5,
         "témoin, par tournure"),
        (r"^  genre=.+ : \d+ / \d+ masqués à tort$", 4, "témoin, par genre"),
        (r"^  types sur les masquages à tort : ", 1, "types détectés à tort"),
    ]),
    ("## liste de patronymes de l'application", [
        (r"^# b, liste (sans_liste|exacte|large|sans)$", 4, "quatre listes"),
        (r"^  b_(debut|milieu) +\d+ / +\d+ +[\d.]+ %$", 8,
         "première mention, deux cas pour chacune des quatre listes (P2-243)"),
        (r"^leurres, liste (sans_liste|exacte|large|sans) : \d+ / \d+ "
         r"documents sans personne avec un nom masqué$", 4,
         "leurres, quatre listes"),
        (r"^  liste (exacte|large|sans) : noms hors civilité, patronyme seul "
         r": \d+ mentions, manquées document par document \d+, en session \d+$",
         3, "corpus de dossiers réaliste, trois listes"),
        (r"^témoin, (sans liste|liste large) : \d+ / \d+ documents sans "
         r"personne avec un nom masqué$", 2, "témoin sans nom, avec et sans liste"),
    ]),
    ("## tournures de personne, témoin élargi", [
        (r"^tournures de personne : \d+ documents, 5 familles, \d+ noms "
         r"annotés, \d+ détection\(s\) hors du mot$", 1,
         "témoin élargi des tournures de personne (P2-226)"),
        (r"^  famille=(roles|organismes|communs) : \d+ / \d+ masqués à tort$",
         3, "familles sans personne"),
        (r"^  famille=patronymes_(communes|noms_communs) : \d+ / \d+ masqués, "
         r"\d+ en clair \(fuite\)$", 2, "familles de patronymes"),
        (r"^    tournure=.+ : \d+ / \d+$", 20, "par famille et par tournure"),
        (r"^  types sur les (masquages à tort|patronymes masqués) : ", 2,
         "types détectés"),
    ]),
    ("## communes moyennes derrière les tournures de personne", [
        (r"^communes moyennes : \d+ documents, 0 entité\(s\) annotée\(s\), "
         r"\d+ lieux masqués à tort$", 1,
         "témoin des communes de 10 000 à 100 000 habitants (P2-238)"),
        (r"^  tranche=(10-30k|30-50k|50-100k) : \d+ / \d+ lieux masqués à "
         r"tort$", 3, "par tranche de population"),
        (r"^  tournure=.+ : \d+ / \d+ lieux masqués à tort$", 4,
         "par tournure"),
        (r"^  tranche_tournure=.+ : \d+ / \d+ lieux masqués à tort$", 12,
         "par tranche et par tournure"),
    ]),
    ("## prénom + verbe conjugué", [
        (r"^prénom \+ verbe : \d+ phrases, \d+ verbes masqués, \d+ prénoms en "
         r"clair \(fuite\)$", 1, "sonde prénom + verbe (P2-240)"),
        (r"^  famille=(courants|reserve|reserve2) : \d+ / \d+ verbes masqués, \d+ "
         r"prénoms en clair$", 2, "par famille"),
    ]),
    ("## mots neutres, un mot à la fois", [
        (r"^mots neutres : \d+ mots, \d+ phrases, \d+ nombre\(s\) "
         r"masqué\(s\) en adresse, \d+ sous un autre type, \d+ mot\(s\) "
         r"touché\(s\)", 1, "témoin des mots neutres (P2-211)"),
        (r"^  casse=(capitales|ordinaire) : \d+ / \d+", 2, "par casse"),
        (r"^  forme=(accentuee|sans_accent) : \d+ / \d+", 2, "par forme"),
        (r"^  suite=(rien|neutre|nom) : \d+ / \d+", 3, "par suite"),
        (r"^  mot=\S+ : capitales \d+ / \d+, ordinaire \d+ / \d+", 70,
         "une ligne par mot de mots_neutres.dart (78 au 16 novembre)"),
        (r"^  mot=\S+ : .* ; sans accent : capitales \d+ / \d+, "
         r"ordinaire \d+ / \d+", 1, "au moins un mot accentué, forme sans accent"),
        (r"^  types sur le nombre : ", 1, "types de détection sur le nombre"),
    ]),
    ("## témoin mot neutre devant CEDEX", [
        (r"^témoin cinq chiffres : \d+ phrases, \d+ prédiction", 1,
         "adresses prédites à tort devant CEDEX (P2-200)"),
        (r"^  casse=(capitales|ordinaire) : \d+ / \d+", 2, "par casse"),
        (r"^  suffixe=(mot|parenthese|tiret) : \d+ / \d+", 3,
         "par forme de suite"),
    ]),
    ("## commune suivie de mots ordinaires", [
        (r"^commune suivie : \d+ documents, \d+ à la suite masquée en "
         r"partie, \d+ / \d+ caractères de suite masqués", 1,
         "témoin de sur-masquage (P2-181)"),
        (r"^  famille=(capitales|liaison|majuscule) : \d+ / \d+ documents",
         3, "par famille de suite"),
        (r"^  ecriture=(libelle|postale) : \d+ / \d+ documents", 2,
         "par écriture"),
    ]),
    ("## identifiant suivi d'un nombre", [
        (r"^identifiant suivi : \d+ documents, \d+ identifiant\(s\) non "
         r"couvert\(s\)", 1, "témoin identifiant suivi (P2-174)"),
        (r"^  type_id=(finess|iban|nir|rpps) : \d+ / \d+ en défaut", 4,
         "par type d'identifiant"),
        (r"^  separateur=(espace|ligne|virgule) : \d+ / \d+ en défaut", 3,
         "par séparateur"),
    ]),
    ("## identifiant derrière un libellé fort", [
        (r"^libellé fort : \d+ identifiants positifs, \d+ en clair, \d+ au "
         r"type faux ; \d+ documents témoins, \d+ masqués à tort", 1,
         "synthèse du témoin libellé fort (P2-194)"),
        (r"^  variante=(cle_juste|cle_fausse|ocr_zero|ocr_un|ligne_vide|"
         r"ocr_et_ligne_vide|cle_fausse_sans_libelle) : \d+ / \d+ en clair",
         7, "par variante"),
        (r"^  libellé=.+ : \d+ / \d+ en clair", 7, "par libellé"),
        (r"^  .+ x (cle_juste|cle_fausse|ocr_zero|ocr_un|ligne_vide|"
         r"ocr_et_ligne_vide) : \d+ / \d+ en clair", 36,
         "6 libellés x 6 variantes"),
        (r"^  témoin négatif=(libelle_seul|non_communique|mot_ordinaire|"
         r"nombre_sans_libelle) : \d+ / \d+ masqués à tort", 4,
         "4 formes de témoin négatif"),
        (r"^confiance des masquages", 1, "en-tête de la mesure P2-203"),
        (r"^  confiance positifs : ", 1, "confiances des positifs"),
        (r"^  confiance variante=(cle_juste|cle_fausse|ocr_zero|ocr_un|"
         r"ligne_vide|ocr_et_ligne_vide) : ", 6, "confiances par variante"),
        (r"^  confiance détections des négatifs : ", 1,
         "confiances des négatifs masqués"),
        (r"^  avertissement à vérifier : positifs \d+ / \d+, négatifs \d+ / "
         r"\d+", 1, "documents avec l'avertissement"),
        (r"^  à vérifier variante=(cle_juste|cle_fausse|ocr_zero|ocr_un|"
         r"ligne_vide|ocr_et_ligne_vide) : \d+ / \d+", 6,
         "avertissement par variante"),
        (r"^  incohérence confiance 0.3 / avertissement : positifs \d+, "
         r"négatifs \d+", 1, "cohérence confiance 0,3 et avertissement"),
        (r"^  exception P2-204 \(ADELI clé fausse, confiance 0.6, avec "
         r"avertissement\) : positifs \d+", 1, "exception ADELI clé fausse"),
    ]),
    ("## mise en page", [
        (r"^# \w+ largeur \d+ : \d+ refus$", 6, "3 corpus x 2 largeurs"),
        (r"^GLOBAL +\d+", 4, "GLOBAL du réaliste et de l'adversarial"),
        (r"^  entites predites \d+$", 2,
         "prédictions du témoin (annoncées par ETAT.md)"),
        (r"^  entités coupées par une fin de ligne : adresse \d+ coupées", 4,
         "entités coupées, réaliste et adversarial (P2-173)"),
        (r"^# structurel largeur \d+, moteur seul", 2, "moteur seul"),
        (r"^Ecluse +TOTAL ", 2, "score moteur seul"),
        (r"^# structurel largeur \d+, détecteur isolé", 2,
         "détecteur isolé (P2-166)"),
        (r"^# structurel largeur \d+, Ecluse\.redact", 2, "Ecluse.redact"),
        (r"^finess .* TOTAL \d+/\d+ \(", 4,
         "rappel du détecteur isolé et d'Ecluse.redact"),
    ]),
    ("## collage de fin de ligne hors du cœur", [
        (r"structurel_l\d+\.jsonl : \d+ doc\., \d+ coupures", 2,
         "corpus structurel recoupé à 60 et 90 colonnes"),
        (r"^Contrôle : \d+ détection", 1, "contrôle sur le texte non recollé"),
        (r"^cas « ", 5, "cas ciblés de P2-162 § 5.3"),
        (r"^colonne de \d+ nombres de \d+ chiffres", 6,
         "colonnes de 9, 11 et 13 chiffres"),
    ]),
]

# Identifiant derrière un libellé fort (P2-194) : plafond de documents
# positifs laissés en clair, par (libellé, variante). Absent = 0 : un
# identifiant positif qui repasse en clair fait échouer `etat.sh`
# (`verifie_etat.py`). Une case ne figure ici qu'avec le constat d'un défaut
# déjà connu ; le plafond ne peut que baisser et se retire quand la
# correction est livrée. Vide depuis P2-199 (ADELI : 50 sur chacune des quatre
# cases OCR et ligne vide au départ, 0 depuis). Il a porté un seul plafond, du
# 22/11/2026 à P2-254 : 4 IBAN à clé fausse sans libellé (lettre « o » d'OCR
# dans la clé) sur 50 partaient en clair par `Ecluse.redact` ; ils sont
# masqués depuis P2-254 et le plafond est retiré.
PLAFOND_LIBELLE_FORT = {}

# Une ligne qui commence ainsi est un échec en soi.
LIGNES_ECHEC = ("ÉCHEC", "section vide")
