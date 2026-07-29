import 'dart:convert';

import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_ingest/ecluse_ingest.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'zip_test_utils.dart';

/// Phrase synthétique reprenant un identifiant de chaque type détecté par
/// défaut (NIR et IBAN structurellement valides, comme dans
/// `ecluse_redact`'s `contratTravailSample`), pour prouver que le pipeline
/// existant fonctionne sans changement sur un texte extrait par
/// `ecluse_ingest`.
const _sampleLines = [
  'M. Julien Vasseur, né le 12 mai 1988, demeurant 14 rue des Acacias, '
      '44000 Nantes, numéro de sécurité sociale 1 88 05 44 056 003 25.',
  'Salaire versé sur FR40 3000 3015 7000 0370 8452 432.',
  'Contact : 02 40 12 34 56 ou julien.vasseur@example.fr.',
  'Employeur : Foyer Les Tilleuls.',
];

List<int> _buildDocxBytes(List<String> paragraphs) {
  final xml = paragraphs
      .map((p) => '<w:p><w:r><w:t xml:space="preserve">$p</w:t></w:r></w:p>')
      .join();
  return buildStoredZip({'word/document.xml': xml});
}

/// Vérifie, sur [extractedText] tel qu'issu de `ecluse_ingest`, que le
/// pipeline `Ecluse.redact` / `Ecluse.restore` existant fonctionne sans
/// modification : les offsets de chaque entité retombent juste sur le
/// texte réellement extrait, et le texte revient identique après un
/// masquage/restauration complet.
Future<void> _expectRoundTripSurvives(String extractedText) async {
  final redacted = await Ecluse.redact(extractedText);

  expect(redacted.entities, isNotEmpty);
  final detectedTypes = redacted.entities.map((e) => e.type).toSet();
  expect(
    detectedTypes,
    containsAll(<EntityType>{
      EntityType.nir,
      EntityType.iban,
      EntityType.nom,
      EntityType.dateNaissance,
      EntityType.adresse,
      EntityType.telephone,
      EntityType.email,
      EntityType.etablissement,
    }),
  );

  // La preuve concrète que les offsets sont fiables : chaque entité
  // détectée retombe exactement sur la sous-chaîne annoncée du texte
  // réellement extrait par ecluse_ingest.
  for (final entity in redacted.entities) {
    expect(
      extractedText.substring(entity.start, entity.end),
      entity.value,
      reason: 'offset invalide pour ${entity.type} '
          '(${entity.start}, ${entity.end})',
    );
  }

  // Le LLM (ici simulé) reçoit le texte masqué et le renvoie tel quel :
  // la restauration doit reconstituer exactement le texte extrait.
  final restoredText = Ecluse.restore(redacted.maskedText, redacted.mapping);
  expect(restoredText, extractedText);
}

void main() {
  group('round-trip redact -> restore sur texte ingéré', () {
    test('.txt', () async {
      final result = ingestFile(
        utf8.encode(_sampleLines.join('\n')),
        filename: 'contrat.txt',
      );
      final text = (result as IngestedText).text;
      await _expectRoundTripSurvives(text);
    });

    test('.md', () async {
      final result = ingestFile(
        utf8.encode(_sampleLines.join('\n')),
        filename: 'contrat.md',
      );
      final text = (result as IngestedText).text;
      await _expectRoundTripSurvives(text);
    });

    test('.docx', () async {
      final result = ingestFile(
        _buildDocxBytes(_sampleLines),
        filename: 'contrat.docx',
      );
      final text = (result as IngestedText).text;
      await _expectRoundTripSurvives(text);
    });
  });

  group(
      'refus explicite — jamais de "rien à masquer" sur un fichier non '
      'lu', () {
    test(
        '.pdf est toujours refusé en v1, y compris avec une couche de '
        'texte lisible', () {
      // Le PDF (texte ou image) est intégralement hors périmètre v1 : ce
      // test couvre a fortiori le cas du PDF-image (couche texte vide),
      // puisque même un PDF parfaitement lisible est refusé.
      final result = ingestFile(
        utf8.encode('%PDF-1.4\n% contenu texte plausible mais ignoré'),
        filename: 'compte_rendu_scanne.pdf',
      );
      expect(result, isA<IngestRefused>());
      expect(result, isNot(isA<IngestedText>()));
    });
  });
}
