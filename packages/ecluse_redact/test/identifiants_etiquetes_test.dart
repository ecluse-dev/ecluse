import 'package:ecluse_core/ecluse_core.dart';
import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

/// Identifiants étiquetés (P2-57) : numéro de dossier, de patient, d'adhérent,
/// IPP, passeport, CNI, plaque d'immatriculation, adresse IP. Ils restaient en
/// clair : ni structure vérifiable, ni type d'entité. Nouveau type
/// `identifiant` (jeton `[IDENTIFIANT_n]`), scindé en quatre catégories (P2-59) :
/// `identifiant` (dossier, patient, adhérent…), `pieceIdentite` (passeport, CNI,
/// permis), `vehicule` (plaque), `reseau` (adresse IP). L'étiquette est obligatoire, sauf
/// pour la plaque au format SIV (`AB-123-CD`), assez spécifique seule.
/// Catégorie attendue du jeton (P2-59) : un type par catégorie d'identifiant.
String categorie(String texte) {
  const pieces = ['Passeport', 'CNI', "Carte d'identité", 'Permis'];
  if (pieces.any(texte.contains)) return 'PIECE_IDENTITE';
  if (RegExp(r'Plaque|Immatriculation|circule').hasMatch(texte)) {
    return 'VEHICULE';
  }
  if (RegExp(r'\bIP\b').hasMatch(texte)) return 'RESEAU';
  return 'IDENTIFIANT';
}

void main() {
  const masques = {
    'IPP : 12345678': '12345678',
    'IPP 12345678': '12345678',
    'IEP: 998877665': '998877665',
    'N° de dossier : 2024-004512': '004512',
    'Numéro de dossier 2024004512': '2024004512',
    'Dossier MDPH n° 2024/12345': '12345',
    'Numéro de patient: 00458712': '00458712',
    'N° patient 00458712': '00458712',
    'Mutuelle : adhérent n° 123456789': '123456789',
    'N° adhérent : 123456789': '123456789',
    'N° allocataire CAF : 1234567': '1234567',
    'N° de contrat : AB123456': 'AB123456',
    'Passeport 12AB34567': '12AB34567',
    'Passeport n° 12AB34567': '12AB34567',
    'CNI n° 123456789012': '123456789012',
    "Carte d'identité n° 123456789012": '123456789012',
    'Permis de conduire n° 123456789012': '123456789012',
    'Plaque AB-123-CD': 'AB-123-CD',
    'Immatriculation : AB-123-CD': 'AB-123-CD',
    'Il circule en CD-456-EF hier': 'CD-456-EF',
    'IP 192.168.1.12': '192.168.1.12',
    'Adresse IP : 203.0.113.45': '203.0.113.45',
  };
  for (final MapEntry(key: texte, value: reste) in masques.entries) {
    test('masqué : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, isNot(contains(reste)), reason: r.maskedText);
      expect(r.maskedText, contains('[${categorie(texte)}_'),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = {
    'N° de dossier : en cours': 'en cours',
    'Dossier n° 12': '12',
    'Dossier 2024': '2024',
    'Passeport vaccinal': 'vaccinal',
    'Passeport 2024': '2024',
    'IPP : à renseigner': 'à renseigner',
    'Plaque 12': '12',
    'Version 192.168.1.12 du logiciel': '192.168.1.12',
    'IP 999.1.1.1': '999.1.1.1',
    'Section AB-123-IO': 'AB-123-IO',
    'Réf. IO-123-AB': 'IO-123-AB',
    'adhérent depuis 2019': '2019',
    'Carte nationale': 'nationale',
    'permis de construire n° 12': '12',
  };
  for (final MapEntry(key: texte, value: reste) in intacts.entries) {
    test('intact : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, contains(reste), reason: r.maskedText);
      expect(
          r.maskedText,
          isNot(matches(
              RegExp(r'\[(IDENTIFIANT|PIECE_IDENTITE|VEHICULE|RESEAU)_'))),
          reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  test('le type est exposé à l\'appelant', () async {
    final r = await Ecluse.redact('IPP : 12345678');
    expect(r.mapping.keys.single, '[IDENTIFIANT_1]');
    expect(
      EntityType.values.map((t) => t.name),
      containsAll(['identifiant', 'pieceIdentite', 'vehicule', 'reseau']),
    );
  });
}
