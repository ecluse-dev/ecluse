import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Nom d'un correspondant dans un en-tête de courriel (P2-53). Un prénom
/// absent du gazetteer échappait à toutes les règles : « From: Zorglub Quenelle
/// <z@exemple.fr> » ne masquait que l'adresse. L'indice est la structure : un
/// nom devant `<adresse>` derrière une étiquette d'en-tête en début de ligne,
/// ou devant `<adresse>` suivi de « a écrit ».
void main() {
  const masques = {
    'From: Zorglub Quenelle <z@exemple.fr>': 'Quenelle',
    'De : Zorglub Quenelle <z@exemple.fr>': 'Quenelle',
    'De : Quenelle, Zorglub <z@exemple.fr>': 'Quenelle',
    'De : "Zorglub Quenelle" <z@exemple.fr>': 'Quenelle',
    'À : Zorglub Quenelle <z@exemple.fr>': 'Quenelle',
    'To: Zorglub Quenelle <z@exemple.fr>': 'Quenelle',
    'Cc : Zorglub Quenelle <z@exemple.fr>': 'Quenelle',
    'Objet : x\nDe : QUENELLE Zorglub <z@exemple.fr>\nDate : y': 'QUENELLE',
    '> De : Zorglub Quenelle <z@exemple.fr>': 'Quenelle',
    'Le 12 mars, Zorglub Quenelle <z@exemple.fr> a écrit :': 'Quenelle',
    'On Mon, Zorglub Quenelle <z@exemple.fr> wrote:': 'Quenelle',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('Zorglub')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'Écrire à Service Qualité <qualite@exemple.fr>': 'Service',
    'De : <z@exemple.fr>': 'De',
    'Voir la note <z@exemple.fr>': 'Voir',
    'de la part de Zorglub <z@exemple.fr>': 'part',
    'Texte de : exemple <z@exemple.fr>': 'exemple',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
