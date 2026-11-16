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
        (r"^Ecluse +TOTAL ", 1, "score v3 du moteur seul"),
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
         r"ocr_et_ligne_vide) : \d+ / \d+ en clair", 6, "par variante"),
        (r"^  libellé=.+ : \d+ / \d+ en clair", 6, "par libellé"),
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
# cases OCR et ligne vide au départ, 0 depuis).
PLAFOND_LIBELLE_FORT = {}

# Une ligne qui commence ainsi est un échec en soi.
LIGNES_ECHEC = ("ÉCHEC", "section vide")
