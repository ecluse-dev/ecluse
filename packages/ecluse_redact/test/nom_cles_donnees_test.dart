import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Noms derrière une clé de données explicite (P2-61) : `nom_patient`,
/// `nom_famille`, `nom_naissance`, `lastname`, `firstname`, `prenom`… en JSON,
/// XML, YAML ou paramètres d'URL. La clé nue « nom » reste exclue (« nom »
/// désigne aussi un fichier, un projet, un médicament). La valeur peut être en
/// minuscules : la clé explicite est l'indice.
void main() {
  const masques = {
    '{"nom_patient": "Quenelle"}': 'Quenelle',
    '{"nom_famille": "Quenelle", "prenom": "Zorglub"}': 'Quenelle',
    '{"lastname": "Quenelle"}': 'Quenelle',
    '{"lastName": "Quenelle"}': 'Quenelle',
    '{"firstname": "zorglub"}': 'zorglub',
    '{"first_name": "Zorglub", "last_name": "Quenelle"}': 'Quenelle',
    '{"family_name": "de la Quenelle"}': 'Quenelle',
    '{"prenom": "Zorglub"}': 'Zorglub',
    '{"prenoms": "Zorglub Hector"}': 'Hector',
    '{"nom_naissance": "Dupont"}': 'Dupont',
    '{"nom_de_naissance": "Dupont"}': 'Dupont',
    '{"nom_usage": "Quenelle"}': 'Quenelle',
    "{'nom_patient': 'Quenelle'}": 'Quenelle',
    '<nom_patient>Quenelle</nom_patient>': 'Quenelle',
    '<lastName>Quenelle</lastName>': 'Quenelle',
    '<prenom>Zorglub</prenom>': 'Zorglub',
    'nom_patient=Quenelle&prenom=Zorglub': 'Quenelle',
    'https://exemple.fr/?firstname=Zorglub&x=1': 'Zorglub',
    'nom_patient: Quenelle': 'Quenelle',
    'patient:\n  prenom: Zorglub\n  nom_famille: Quenelle': 'Quenelle',
    '{"surname": "QUENELLE"}': 'QUENELLE',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : ${texte.replaceAll('\n', '⏎')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[NOM_'), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    '{"nom": "Aspirine"}': 'Aspirine',
    '{"nom": "Quenelle"}': 'Quenelle',
    '{"nom_fichier": "rapport"}': 'rapport',
    '{"nom_projet": "Alpha"}': 'Alpha',
    '{"nom_patient": null}': 'null',
    '{"nom_patient": ""}': '""',
    '{"nom_patient": "inconnu"}': 'inconnu',
    '{"nom_patient": "12345"}': '12345',
    '{"prenom": "N/A"}': 'N/A',
    'nom_patient: Inconnu': 'Inconnu',
    'prenom: Non': 'Non',
    '{"lastname": "NULL"}': 'NULL',
    '{"filename": "a.txt"}': 'a.txt',
    '{"username": "zq42"}': 'zq42',
    'Le prenom_champ est vide': 'prenom_champ',
    '{"lastname_count": 3}': '3',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(r.maskedText, isNot(contains('[NOM_')), reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }
}
