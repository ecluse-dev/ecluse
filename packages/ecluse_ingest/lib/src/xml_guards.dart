/// Garde-fous communs aux extracteurs XML (`.docx`, `.odt`) : tout contenu
/// que le micro-extracteur ne sait pas lire fidèlement est **refusé avec un
/// motif**, jamais rendu comme un texte vide ou partiel (règle n°4 de
/// `CLAUDE.md`).
library;

/// Refuse un document dont l'espace de noms principal est déclaré avec un
/// autre préfixe que celui que lit l'extracteur (`ns0:` de python-docx,
/// espace de noms par défaut…). Sans cela l'extracteur ne reconnaît aucune
/// balise et renvoie un texte vide sans erreur.
///
/// Renvoie le motif de refus, ou `null` si le document est lisible.
String? namespacePrefixRefusal(
  String xml, {
  required String namespace,
  required String expectedPrefix,
  required String format,
}) {
  final ns = RegExp.escape(namespace);
  final declarations =
      RegExp('xmlns(?::([A-Za-z_][\\w.-]*))?\\s*=\\s*["\']$ns["\']')
          .allMatches(xml);
  for (final d in declarations) {
    final prefix = d.group(1);
    if (prefix != expectedPrefix) {
      final found =
          prefix == null ? 'un espace de noms par défaut' : '« $prefix: »';
      return 'Document $format refusé : espace de noms XML déclaré avec '
          '$found au lieu du préfixe « $expectedPrefix: » attendu '
          '(préfixe non géré, le texte ne serait pas lu).';
    }
  }
  return null;
}

/// Refuse les constructions XML que l'extracteur ne sait pas lire.
String? unsupportedXmlRefusal(String xml, {required String format}) {
  if (xml.contains('<![CDATA[')) {
    return 'Document $format refusé : section CDATA non gérée (le texte ne '
        'serait pas lu).';
  }
  return null;
}
