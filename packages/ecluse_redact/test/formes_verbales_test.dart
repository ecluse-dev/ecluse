import 'package:ecluse_core/ecluse_core.dart' show EntityType;
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Formes verbales fournies par l'application (P2-251). `ecluse_redact`
/// reçoit un ensemble de mots et n'importe jamais le paquet `ecluse_lexique`.
/// Mots synthétiques : « avise » et « félicite » sont des verbes absents de la
/// liste fermée de `verbes_conjugues.dart`.
void main() {
  const formes = {'avise', 'félicite'};

  test('sans formes : le verbe hors liste est masqué avec son prénom',
      () async {
    final r = await Ecluse.redact('Rdv. Sophie avise le service.');
    expect(r.maskedText, isNot(contains('avise')));
  });

  test('avec formes : le prénom seul est masqué, le verbe reste lisible',
      () async {
    const texte = 'Rdv. Sophie avise le service.';
    final r = await Ecluse.redact(texte, formesVerbales: formes);
    expect(r.maskedText, 'Rdv. [NOM_1] avise le service.');
    expect(r.entities.single.type, EntityType.nom);
    expect(Ecluse.restore(r.maskedText, r.mapping), texte);
  });

  test('ensemble vide ou absent : sortie identique à celle d\'avant', () async {
    const texte = 'Rdv. Sophie avise le service. Marc félicite Julien Roche.';
    final a = await Ecluse.redact(texte);
    final b = await Ecluse.redact(texte, formesVerbales: const {});
    expect(b.maskedText, a.maskedText);
    expect([for (final e in b.entities) (e.start, e.end, e.confidence)],
        [for (final e in a.entities) (e.start, e.end, e.confidence)]);
    expect(Ecluse.restore(b.maskedText, b.mapping), texte);
  });

  test('un patronyme qui n\'est pas dans l\'ensemble reste masqué', () async {
    final r = await Ecluse.redact('Rdv. Sophie Roche arrive.',
        formesVerbales: formes);
    expect(r.maskedText, isNot(contains('Roche')));
  });

  test('detect et un Dossier reçoivent aussi l\'option', () async {
    final e = await Ecluse.detect('Rdv. Sophie avise le service.',
        formesVerbales: formes);
    expect(e.single.value, 'Sophie');
    final dossier = Dossier();
    final r = await Ecluse.redact('Rdv. Sophie avise le service.',
        dossier: dossier, formesVerbales: formes);
    expect(r.maskedText, 'Rdv. [NOM_1] avise le service.');
  });

  test('texte entièrement en minuscules : la même règle s\'applique', () async {
    final r = await Ecluse.redact('rdv. sophie félicite le service.',
        formesVerbales: formes);
    expect(r.maskedText, contains('félicite'));
    expect(r.maskedText, isNot(contains('sophie')));
  });
}
