import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Identifiants administratifs sans « n° » de dossier (P2-80), relevés par la
/// relecture indépendante : « dossier 4900123456 », « dossier APA 2026/0412 »,
/// « N° résident : 000123 », « Plan d'aide n° PA-2026-0042 » restaient en clair. La
/// valeur doit toujours ressembler à un identifiant (au moins cinq chiffres, ou trois
/// chiffres et une lettre) et jamais à une date ni à une année.
void main() {
  const masques = {
    'Caisse: CPAM 49, dossier 4900123456': '4900123456',
    'Bénéficiaire (n° 4900123456) - dossier APA 2026/0412': '2026/0412',
    "Plan d'aide n° PA-2026-0042": 'PA-2026-0042',
    'N° résident : 000123': '000123',
    'N° de résident 884412': '884412',
    'Dossier 4900123456': '4900123456',
    'Référence dossier : AB-2026-00412': 'AB-2026-00412',
    'Usager n° de dossier 2024-0412': '2024-0412',
    'dossier APA 2026/0412 validé': '2026/0412',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[IDENTIFIANT_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Dossier 2024': '2024',
    'dossier 12': '12',
    'dossier du 12/03/2026': '12/03/2026',
    'Dossier daté du 12.03.2026': '12.03.2026',
    "Plan d'aide validé le 12/03/2026": '12/03/2026',
    'N° résident : en attente': 'en attente',
    'Résident n° 12': 'n° 12',
    'dossier en cours': 'en cours',
    'Dossier médical complet': 'médical',
    'dossier 2024-04': '2024-04',
    'Numéro de sécurité : 12345': '12345',
    'Réf. : 884412': '884412',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('[IDENTIFIANT_')),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
