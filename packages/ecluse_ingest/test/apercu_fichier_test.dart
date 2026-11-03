import 'dart:convert';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

/// L'aperçu avec validation porte sur le **texte extrait** d'un fichier
/// (décision 10 de P2-08, P2-24) : ce test fixe la composition
/// `ingestFile` → `Apercu` sans code d'intégration, et le refus explicite des
/// fichiers non lus (aucun aperçu possible sans texte).
const _lignes = [
  'M. Julien Vasseur, né le 12 mai 1988, demeurant 14 rue des Acacias, '
      '44000 Nantes, numéro de sécurité sociale 1 88 05 44 056 003 25.',
  'Contact : 02 40 12 34 56 ou julien.vasseur@example.fr.',
];

List<int> _docx(List<String> paragraphes) => buildStoredZip({
      'word/document.xml': paragraphes
          .map(
              (p) => '<w:p><w:r><w:t xml:space="preserve">$p</w:t></w:r></w:p>')
          .join(),
    });

void main() {
  final fichiers = <String, List<int>>{
    'note.txt': utf8.encode(_lignes.join('\n')),
    'note.md': utf8.encode(_lignes.join('\n\n')),
    'note.docx': _docx(_lignes),
  };

  for (final MapEntry(key: nom, value: octets) in fichiers.entries) {
    group(nom, () {
      late String texte;
      setUp(() {
        final r = ingestFile(octets, filename: nom);
        expect(r, isA<IngestedText>());
        texte = (r as IngestedText).text;
      });

      test('les entités proposées retombent sur le texte extrait', () async {
        final p = await Apercu.propose(texte);
        expect(p.texte, texte);
        expect(p.entites, isNotEmpty);
        for (final e in p.entites) {
          expect(texte.substring(e.start, e.end), e.valeur);
        }
      });

      test('tout accepté = Ecluse.redact sur le texte extrait', () async {
        final p = await Apercu.propose(texte);
        final r = await Apercu.applique(p, const DecisionApercu(),
            texteAEnvoyer: texte);
        final attendu = await Ecluse.redact(texte);
        expect(r.maskedText, attendu.maskedText);
        expect(r.mapping, attendu.mapping);
      });

      test('un refus laisse en clair et se restaure à l\'identique', () async {
        final p = await Apercu.propose(texte);
        final email = p.entites.firstWhere((e) => e.type == EntityType.email);
        final r = await Apercu.applique(p, DecisionApercu(refusees: {email.id}),
            texteAEnvoyer: texte);
        expect(r.maskedText, contains(email.valeur));
        expect(Ecluse.restore(r.maskedText, r.mapping), texte);
      });
    });
  }

  test('un fichier non lu ne donne aucun texte, donc aucun aperçu', () {
    final r = ingestFile(utf8.encode('x'), filename: 'photo.png');
    expect(r, isA<IngestRefused>());
    expect(r, isNot(isA<IngestedText>()));
  });
}
