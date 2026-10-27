import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom de signature sous une formule de politesse (P2-54). Un prénom absent du
/// gazetteer échappait à toutes les règles : « Cordialement,⏎Zorglub Quenelle ».
/// L'indice est la structure : formule de clôture seule sur sa ligne, nom en
/// majuscule initiale (1 à 3 mots) seul sur la ligne suivante.
void main() {
  const masques = {
    'Merci.\nCordialement,\nZorglub Quenelle\nInfirmier': 'Quenelle',
    'Cordialement\nZorglub Quenelle': 'Quenelle',
    'Bien cordialement,\nQUENELLE Zorglub': 'QUENELLE',
    'Bien à vous,\nZorglub Quenelle': 'Quenelle',
    'Bonne journée,\nZorglub Quenelle': 'Quenelle',
    'Respectueusement,\nZorglub de la Quenelle': 'Quenelle',
    'Best regards,\nZorglub Quenelle': 'Quenelle',
    'Sincerely,\r\nZorglub Quenelle\r\n': 'Quenelle',
    'Cordialement,\n\nZorglub Quenelle': 'Quenelle',
    'Cdt,\nZorglub Quenelle': 'Quenelle',
    'Cordialement,\nZorglub Le Gall': 'Gall',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('Zorglub')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Cordialement, Zorglub Quenelle': 'Cordialement',
    'Cordialement,\nService Qualité': 'Service',
    'Cordialement,\nL\'équipe de soins': 'équipe',
    'Cordialement,\nla direction': 'direction',
    'Cordialement,\nLe 12 mars nous verrons': 'verrons',
    'Cordialement,\nPOUR LE SERVICE': 'SERVICE',
    'Merci,\nZorglub Quenelle': 'Quenelle',
    'Cordialement,\nL\'Équipe': 'Équipe',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
