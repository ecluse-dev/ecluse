#!/usr/bin/env python3
"""Génère des PDF **synthétiques** pour calibrer l'ingestion PDF (P1-17).

Bibliothèque standard uniquement (aucune dépendance ajoutée) : le PDF est
écrit à la main (objets, xref, flux). Sortie **reproductible octet pour
octet** : graine fixe, pas d'horodatage, `/ID` dérivé du nom, images en
ASCIIHex (pas de dépendance à la version de zlib).

Aucune donnée réelle : les identifiants (NIR, RPPS, IBAN) sont fabriqués par
les générateurs de `generate_corpus.py` (clés valides calculées).

Les attendus (`expected.json`) sont ceux de la **cible** fixée par
`agent/specs/P1-09-pdf.md` §3 : ils décrivent ce que l'ingestion DOIT faire,
pas ce que fait aujourd'hui une bibliothèque donnée. Les seuils (20
caractères par page, plafonds de pages et de taille) sont des valeurs de
départ à calibrer sur ce jeu.

Usage :
    python3 bench/generate_pdfs.py --out bench/pdf
    python3 bench/generate_pdfs.py --out /tmp/pdf --with-oversize   # + 51 Mo
"""

import argparse
import hashlib
import json
import os
import random

import generate_corpus as gc

SEED = 42
PAGE_W, PAGE_H = 595, 842

# Motifs de refus (codes stables, repris par P1-17).
MOTIF_SANS_TEXTE = "sans_texte"
MOTIF_PARTIEL = "partiellement_numerise"
MOTIF_ILLISIBLE = "texte_illisible"
MOTIF_CHIFFRE = "chiffre"
MOTIF_MALFORME = "malforme"
MOTIF_PLAFOND_PAGES = "plafond_pages"
MOTIF_PLAFOND_TAILLE = "plafond_taille"

PAD = bytes.fromhex(
    "28BF4E5E4E758A4164004E56FFFA01082E2E00B6D0683E802F0CA9FE6453697A"
)


def rc4(key: bytes, data: bytes) -> bytes:
    s = list(range(256))
    j = 0
    for i in range(256):
        j = (j + s[i] + key[i % len(key)]) % 256
        s[i], s[j] = s[j], s[i]
    out = bytearray()
    i = j = 0
    for byte in data:
        i = (i + 1) % 256
        j = (j + s[i]) % 256
        s[i], s[j] = s[j], s[i]
        out.append(byte ^ s[(s[i] + s[j]) % 256])
    return bytes(out)


def pdf_escape(text: str) -> bytes:
    raw = text.encode("cp1252")
    return raw.replace(b"\\", b"\\\\").replace(b"(", b"\\(").replace(b")", b"\\)")


class Builder:
    """Assemble des objets PDF numérotés, la table xref et la queue."""

    def __init__(self, name: str, encrypt: bool = False):
        self.name = name
        self.objs = []  # (dict_text, stream | None)
        self.encrypt = encrypt
        self.doc_id = hashlib.md5(name.encode()).digest()
        self._key = None
        if encrypt:
            owner = b"proprietaire-synthetique"
            owner_padded = (owner + PAD)[:32]
            okey = hashlib.md5(owner_padded).digest()[:5]
            self._o = rc4(okey, PAD)  # mot de passe utilisateur vide
            p = -4
            self._p = p
            self._key = hashlib.md5(
                PAD + self._o + p.to_bytes(4, "little", signed=True) + self.doc_id
            ).digest()[:5]
            self._u = rc4(self._key, PAD)

    def reserve(self) -> int:
        self.objs.append(None)
        return len(self.objs)

    def set(self, num: int, dict_text: str, stream: bytes = None) -> int:
        self.objs[num - 1] = (dict_text, stream)
        return num

    def add(self, dict_text: str, stream: bytes = None) -> int:
        return self.set(self.reserve(), dict_text, stream)

    def _object_key(self, num: int) -> bytes:
        return hashlib.md5(
            self._key + num.to_bytes(3, "little") + (0).to_bytes(2, "little")
        ).digest()[: min(len(self._key) + 5, 16)]

    def build(self, root: int, info: int = None, bad_startxref: bool = False) -> bytes:
        out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        encrypt_num = None
        if self.encrypt:
            encrypt_num = self.add(
                "<< /Filter /Standard /V 1 /R 2 /P %d /O <%s> /U <%s> >>"
                % (self._p, self._o.hex(), self._u.hex())
            )
        offsets = []
        for i, (dict_text, stream) in enumerate(self.objs, start=1):
            offsets.append(len(out))
            out += b"%d 0 obj\n" % i
            if stream is None:
                out += dict_text.encode("cp1252") + b"\n"
            else:
                if self.encrypt:
                    stream = rc4(self._object_key(i), stream)
                out += (
                    "<< %s /Length %d >>\nstream\n" % (dict_text, len(stream))
                ).encode("cp1252")
                out += stream + b"\nendstream\n"
            out += b"endobj\n"
        xref_at = len(out)
        out += b"xref\n0 %d\n" % (len(self.objs) + 1)
        out += b"0000000000 65535 f \n"
        for off in offsets:
            out += b"%010d 00000 n \n" % off
        idhex = self.doc_id.hex()
        trailer = "<< /Size %d /Root %d 0 R" % (len(self.objs) + 1, root)
        if info:
            trailer += " /Info %d 0 R" % info
        if encrypt_num:
            trailer += " /Encrypt %d 0 R" % encrypt_num
        trailer += " /ID [<%s> <%s>] >>" % (idhex, idhex)
        out += b"trailer\n" + trailer.encode() + b"\n"
        out += b"startxref\n%d\n%%%%EOF\n" % (xref_at + 7 if bad_startxref else xref_at)
        return bytes(out)


def text_stream(lines, font="F1", size=11) -> bytes:
    """Flux de contenu : une ligne = un `Tj` positionné (x, y, texte)."""
    parts = []
    for x, y, text in lines:
        if font in ("CID", "CIDLATIN"):
            # Codes de glyphes sans table ToUnicode : un extracteur qui lit
            # l'identité les rend tels quels. Zone privée (U+E000…) pour
            # « CID », lettres latines étendues (U+0100…) pour « CIDLATIN ».
            base = 0xE000 if font == "CID" else 0x0100
            hexcodes = "".join("%04X" % (base + (ord(c) % 0x80)) for c in text)
            parts.append(b"BT /F2 %d Tf %d %d Td <%s> Tj ET\n" % (size, x, y, hexcodes.encode()))
        else:
            parts.append(
                b"BT /F1 %d Tf %d %d Td (" % (size, x, y) + pdf_escape(text) + b") Tj ET\n"
            )
    return b"".join(parts)


def gray_image(width: int, height: int) -> bytes:
    """Dégradé déterministe, 8 bits, encodé en hexadécimal ASCII."""
    raw = bytes((x * 255 // (width - 1) + y * 3) % 256 for y in range(height) for x in range(width))
    return raw.hex().encode() + b">"


def make_pdf(
    name,
    pages,
    *,
    encrypt=False,
    info=None,
    open_action_js=None,
    bad_startxref=False,
):
    """`pages` : liste de dict {lines, font, image ('full'|'small'|None), annot}."""
    b = Builder(name, encrypt=encrypt)
    catalog = b.reserve()
    pages_obj = b.reserve()
    font1 = b.add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    font2 = None
    if any(p.get("font", "F1") != "F1" for p in pages):
        # Police sans ToUnicode ni programme intégré. Jamais dans le PDF
        # chiffré : ses chaînes seraient à chiffrer aussi.
        assert not encrypt
        desc = b.add(
            "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /PoliceSynthetique "
            "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> /DW 600 >>"
        )
        font2 = b.add(
            "<< /Type /Font /Subtype /Type0 /BaseFont /PoliceSynthetique "
            "/Encoding /Identity-H /DescendantFonts [%d 0 R] >>" % desc
        )
    image_obj = b.add(
        "/Type /XObject /Subtype /Image /Width 40 /Height 40 /ColorSpace /DeviceGray "
        "/BitsPerComponent 8 /Filter /ASCIIHexDecode",
        gray_image(40, 40),
    )
    # Pour un objet à flux, `dict_text` est le contenu du dictionnaire sans
    # « << >> » : `build` les ajoute avec `/Length`.
    kids = []
    for page in pages:
        content = b""
        if page.get("lines"):
            content += text_stream(page["lines"], page.get("font", "F1"))
        if page.get("image") == "full":
            content += b"q %d 0 0 %d 0 0 cm /Im1 Do Q\n" % (PAGE_W, PAGE_H)
        elif page.get("image") == "small":
            content += b"q 120 0 0 40 400 80 cm /Im1 Do Q\n"
        fonts = "/F1 %d 0 R" % font1 + (" /F2 %d 0 R" % font2 if font2 else "")
        res = "/Resources << /Font << %s >> /XObject << /Im1 %d 0 R >> >>" % (fonts, image_obj)
        d = "<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %d %d] %s" % (pages_obj, PAGE_W, PAGE_H, res)
        if content:
            d += " /Contents %d 0 R" % b.add("", content)
        if page.get("annot"):
            annot = b.add(
                "<< /Type /Annot /Subtype /Text /Rect [50 50 70 70] /Contents (%s) >>"
                % pdf_escape(page["annot"]).decode("cp1252")
            )
            d += " /Annots [%d 0 R]" % annot
        d += " >>"
        kids.append(b.add(d))
    b.set(pages_obj, "<< /Type /Pages /Count %d /Kids [%s] >>"
          % (len(kids), " ".join("%d 0 R" % k for k in kids)))
    cat = "<< /Type /Catalog /Pages %d 0 R" % pages_obj
    if open_action_js:
        cat += " /OpenAction << /S /JavaScript /JS (%s) >>" % open_action_js
    b.set(catalog, cat + " >>")
    info_obj = b.add(info) if info else None
    return b.build(catalog, info_obj, bad_startxref=bad_startxref)


# ---------------------------------------------------------------------------


def identifiers():
    rng = random.Random(SEED)
    nir = gc.make_nir(rng)
    rpps = gc.make_rpps(rng)
    iban = gc.make_iban(rng)
    nir_txt = " ".join([nir[0], nir[1:3], nir[3:5], nir[5:7], nir[7:10], nir[10:13], nir[13:15]])
    iban_txt = " ".join(iban[i:i + 4] for i in range(0, len(iban), 4))
    return {
        "nir": (nir, nir_txt),
        "rpps": (rpps, rpps),
        "iban": (iban, iban_txt),
    }


def build_all(with_oversize=False):
    ids = identifiers()
    nir, nir_txt = ids["nir"]
    rpps, rpps_txt = ids["rpps"]
    iban, iban_txt = ids["iban"]

    def lines(*texts, x=60, y0=780, dy=22):
        return [(x, y0 - i * dy, t) for i, t in enumerate(texts)]

    corps = lines(
        "Compte rendu de consultation (document synthetique).",
        "Le patient est suivi depuis 2019 pour une hypertension stable.",
        "Numero de securite sociale : " + nir_txt,
        "Medecin referent, RPPS : " + rpps_txt,
        "Remboursement sur le compte " + iban_txt + ".",
    )
    entites = [
        {"type": "nir", "valeur": nir, "affiche": nir_txt},
        {"type": "rpps", "valeur": rpps, "affiche": rpps_txt},
        {"type": "iban", "valeur": iban, "affiche": iban_txt},
    ]
    files = {}
    meta = {}

    def register(name, data, kind, attendu, motif=None, entites_=None, avertissements=None, note=None):
        files[name] = data
        entry = {"nature": kind, "attendu": attendu}
        if motif:
            entry["motif"] = motif
        if entites_:
            entry["entites"] = entites_
        if avertissements:
            entry["avertissements_attendus"] = avertissements
        if note:
            entry["note"] = note
        meta[name] = entry

    # --- acceptés -------------------------------------------------------
    register("texte_simple.pdf", make_pdf("texte_simple", [{"lines": corps}]),
             "texte, 1 page", "accepte", entites_=entites)

    pages3 = [
        {"lines": lines("Page 1 : en-tete de dossier synthetique.", "Numero : " + nir_txt)},
        {"lines": lines("Page 2 : suite du dossier, observations de routine pour le test.")},
        {"lines": lines("Page 3 : RPPS " + rpps_txt + " et IBAN " + iban_txt + ".")},
    ]
    register("texte_multipage.pdf", make_pdf("texte_multipage", pages3),
             "texte, 3 pages", "accepte",
             entites_=[entites[0], entites[1], entites[2]],
             note="les offsets valent par rapport au texte extrait, pas au PDF")

    cut_a = iban_txt[: len(iban_txt) // 2].rstrip()
    cut_b = iban_txt[len(cut_a):].lstrip()
    register("texte_iban_coupe.pdf", make_pdf("texte_iban_coupe", [{"lines": lines(
        "Virement vers l'IBAN " + cut_a, cut_b + " merci.", "Fin du document de test.")}]),
        "texte, IBAN coupé par un retour à la ligne", "accepte",
        entites_=[{"type": "iban", "valeur": iban, "affiche": cut_a + "\\n" + cut_b}],
        note="limite connue (LIMITES.md) : un identifiant coupé par une fin de ligne peut échapper à la détection ; ne pas compter comme défaut de l'extraction seule")

    colonnes = [(60, 780 - i * 22, t) for i, t in enumerate([
        "Colonne gauche : texte de remplissage",
        "pour simuler une mise en page",
        "sur deux colonnes dans un document.",
        "Fin de la colonne de gauche.",
    ])] + [(320, 780 - i * 22, t) for i, t in enumerate([
        "Colonne droite : RPPS " + rpps_txt,
        "et compte " + iban_txt,
        "Fin de la colonne de droite.",
    ])]
    register("texte_colonnes.pdf", make_pdf("texte_colonnes", [{"lines": colonnes}]),
             "texte, deux colonnes", "accepte",
             entites_=[entites[1], entites[2]],
             note="l'ordre de lecture peut mélanger les colonnes ; les identifiants doivent rester intacts")

    register("texte_et_image.pdf", make_pdf("texte_et_image", [{"lines": corps, "image": "small"}]),
             "texte + image de tampon", "accepte_avertissement", entites_=entites,
             avertissements=["image présente non traitée (tampon, signature, en-tête)"])

    register("page_blanche.pdf", make_pdf("page_blanche", [{"lines": corps}, {}]),
             "texte + page blanche (ni texte ni image)", "accepte", entites_=entites,
             note="accepté si l'extracteur sait distinguer page vide et page image ; sinon refus conservateur (spec §3)")

    info = "<< /Title (Dossier synthetique) /Author (Auteur Synthetique) /Subject (Test) >>"
    register("metadonnees_annotation.pdf", make_pdf(
        "metadonnees_annotation",
        [{"lines": corps, "annot": "Note de relecture synthetique, RPPS " + rpps_txt}],
        info=info),
        "texte + /Info + annotation contenant un identifiant", "accepte_avertissement",
        entites_=entites,
        avertissements=["métadonnées et annotations présentes et non extraites"],
        note="l'identifiant de l'annotation n'est PAS dans le texte de page : il ne doit pas être considéré comme lu")

    register("javascript.pdf", make_pdf(
        "javascript", [{"lines": corps}],
        open_action_js="app.alert\\(\\\"synthetique\\\"\\);"),
        "texte + action JavaScript à l'ouverture", "accepte", entites_=entites,
        note="le JavaScript ne doit jamais être exécuté ; un avertissement est souhaitable (à décider)")

    # --- refusés --------------------------------------------------------
    register("scan_pur.pdf", make_pdf("scan_pur", [{"image": "full"}]),
             "une page, image pleine page, aucun texte", "refuse", MOTIF_SANS_TEXTE)

    register("mixte.pdf", make_pdf("mixte", [{"lines": corps}, {"image": "full"}, {"image": "full"}]),
             "page 1 texte, pages 2 et 3 images", "refuse", MOTIF_PARTIEL,
             note="pages sans texte à lister : 2, 3 ; le document est refusé en entier")

    register("texte_quasi_vide.pdf", make_pdf("texte_quasi_vide", [{"lines": [(60, 780, "p. 1")], "image": "full"}]),
             "image pleine page + 3 caractères de texte", "refuse", MOTIF_SANS_TEXTE,
             note="sous le seuil de 20 caractères alphanumériques par page")

    illisible = [(60, 780 - i * 22, t) for i, t in enumerate([
        "Numero de securite sociale " + nir_txt,
        "Compte " + iban_txt,
        "Texte long pour depasser le seuil de caracteres.",
    ])]
    register("texte_illisible.pdf", make_pdf("texte_illisible", [{"lines": illisible, "font": "CID"}]),
        "police Type0 Identity-H sans ToUnicode ni police intégrée (zone privée)", "refuse", MOTIF_ILLISIBLE,
        note="texte non vide ≠ texte lu ; attrapé par le critère « zone privée > 5 % » du spec §3")

    register("texte_illisible_latin.pdf", make_pdf("texte_illisible_latin", [{"lines": illisible, "font": "CIDLATIN"}]),
        "même police sans ToUnicode, codes rendus en lettres latines étendues", "refuse", MOTIF_ILLISIBLE,
        note="LACUNE des critères du spec §3 : aucun U+FFFD ni zone privée, 100 % de lettres ; le garde-fou doit "
             "aussi examiner la part de caractères hors du jeu attendu (ASCII/Latin-1) ; à calibrer en P1-17")

    register("chiffre.pdf", make_pdf("chiffre", [{"lines": corps}], encrypt=True),
             "RC4 40 bits, mot de passe utilisateur vide", "refuse", MOTIF_CHIFFRE,
             note="s'ouvre sans mot de passe mais reste chiffré : refus quand même (règle n°4)")

    base = files["texte_simple.pdf"]
    register("tronque.pdf", base[: int(len(base) * 0.6)],
             "texte_simple coupé à 60 % (ni xref ni trailer)", "refuse", MOTIF_MALFORME)

    register("xref_casse.pdf", make_pdf("xref_casse", [{"lines": corps}], bad_startxref=True),
             "startxref pointant au mauvais endroit", "refuse", MOTIF_MALFORME,
             note="des lecteurs reconstruisent la table ; la politique de P1-17 tranche (refus de la cible spec §3)")

    register("sans_page.pdf", make_pdf("sans_page", []),
             "catalogue valide, zéro page", "refuse", MOTIF_SANS_TEXTE)

    long_pages = [{"lines": lines("Page de remplissage synthetique numero %03d." % (i + 1))} for i in range(250)]
    register("tres_long_250_pages.pdf", make_pdf("tres_long", long_pages),
             "250 pages de texte (plafond de départ : 200)", "refuse", MOTIF_PLAFOND_PAGES)

    if with_oversize:
        filler = b"% " + b"x" * 62 + b"\n"
        pad = filler * ((51 * 1024 * 1024) // len(filler))
        register("tres_gros.pdf", base.replace(b"%%EOF", pad + b"%%EOF"),
                 "plus de 50 Mo (non versionné)", "refuse", MOTIF_PLAFOND_TAILLE)

    return files, meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="bench/pdf")
    ap.add_argument("--with-oversize", action="store_true")
    args = ap.parse_args()
    files, meta = build_all(args.with_oversize)
    os.makedirs(args.out, exist_ok=True)
    for name, data in files.items():
        with open(os.path.join(args.out, name), "wb") as f:
            f.write(data)
    expected = {
        "graine": SEED,
        "seuils_depart": {"alnum_par_page": 20, "pages_max": 200, "taille_max_octets": 50 * 1024 * 1024},
        "fichiers": dict(sorted(meta.items())),
    }
    with open(os.path.join(args.out, "expected.json"), "w", encoding="utf-8") as f:
        json.dump(expected, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"{len(files)} PDF écrits dans {args.out}")


if __name__ == "__main__":
    main()
