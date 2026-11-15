import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// P2-188 : un NIR, un IBAN FR ou un RPPS annoncé par un libellé fort («
/// NIR », « N° de sécurité sociale », « numéro SS », « IBAN », « RPPS »)
/// mais dont la clé de contrôle est fausse partait en clair — la règle «
/// clé validée ou rien » (`DECISIONS.md`) vaut pour la détection sans
/// contexte, pas pour un champ que son libellé désigne sans ambiguïté.
///
/// Fixtures reprises des fixtures synthétiques déjà établies dans
/// `ecluse_core` (NIR `185057800608491`, IBAN `FR7630006000011234567890189`,
/// RPPS `10001234565`, toutes à clé valide), avec le dernier chiffre de la
/// clé changé pour obtenir une clé fausse — jamais une valeur réelle.
void main() {
  group('témoin positif : libellé fort + clé fausse, masqué', () {
    const cas = {
      'NIR, libellé "NIR"': (
        'NIR 1 85 05 78 006 084 90',
        EntityType.nir,
      ),
      'NIR, "numéro de sécurité sociale"': (
        'Numéro de sécurité sociale : 1 85 05 78 006 084 90.',
        EntityType.nir,
      ),
      'NIR, "N° de sécurité sociale"': (
        'N° de sécurité sociale : 185057800608490',
        EntityType.nir,
      ),
      'NIR, "numéro SS"': (
        'numéro SS 185057800608490',
        EntityType.nir,
      ),
      'IBAN, libellé "IBAN"': (
        'IBAN : FR77 3000 6000 0112 3456 7890 189',
        EntityType.iban,
      ),
      'RPPS, libellé "RPPS"': (
        'RPPS 10001234566',
        EntityType.rpps,
      ),
    };

    for (final entry in cas.entries) {
      test(entry.key, () async {
        final (texte, type) = entry.value;
        final r = await Ecluse.redact(texte);
        expect(r.entities.any((e) => e.type == type), isTrue,
            reason: 'identifiant à clé fausse non masqué : $texte');
        expect(r.mapping.values, isNot(contains(texte)));
        expect(
          r.warnings.any((w) => w.contains('identifiant à clé invalide')),
          isTrue,
        );
        // Jamais la valeur réelle dans l'avertissement.
        for (final w in r.warnings) {
          expect(w, isNot(contains('185057800608490')));
          expect(w, isNot(contains('10001234566')));
        }
      });
    }
  });

  group('témoin négatif : libellé seul ou suivi d\'autre chose, intact', () {
    const phrases = [
      'NIR : non communiqué',
      'IBAN : voir pièce jointe',
      'RPPS : non renseigné',
      'NIR : 450 euros',
      'IBAN : le 12/03/2026',
    ];

    for (final texte in phrases) {
      test(texte, () async {
        final r = await Ecluse.redact(texte);
        expect(r.maskedText, texte);
        expect(r.mapping, isEmpty);
      });
    }
  });

  test('clé valide : détecteur strict seul, pas de double masquage', () async {
    final r = await Ecluse.redact(
      'NIR : 1 85 05 78 006 084 91. RPPS 10001234565. '
      'IBAN : FR76 3000 6000 0112 3456 7890 189',
    );
    expect(r.entities.where((e) => e.type == EntityType.nir), hasLength(1));
    expect(r.entities.where((e) => e.type == EntityType.rpps), hasLength(1));
    expect(r.entities.where((e) => e.type == EntityType.iban), hasLength(1));
    expect(
      r.entities.singleWhere((e) => e.type == EntityType.nir).confidence,
      1.0,
    );
    expect(
      r.warnings.any((w) => w.contains('identifiant à clé invalide')),
      isFalse,
    );
  });
}
