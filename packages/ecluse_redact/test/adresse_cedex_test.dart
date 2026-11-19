import 'package:ecluse_redact/ecluse_redact.dart';
import 'package:test/test.dart';

import 'support/cout.dart';

/// Numéro de CEDEX (P2-164). Mesure P2-157 : « 70000 VESOUL CEDEX 9 » était
/// masqué jusqu'au mot « CEDEX » compris, et le numéro de distribution qui
/// suit restait en clair (« [ADRESSE_1] 9 ») : 53 adresses sur 155 du corpus
/// flou adversarial, 1,9 % des caractères d'adresse.
void main() {
  const masques = [
    'Adresse : 8 chemin des Vignes, 70000 VESOUL CEDEX 9',
    'Adresse : 8 chemin des Vignes\n70000 VESOUL CEDEX 9',
    'Adresse : 8 chemin des Vignes, 70000 VESOUL CEDEX 09',
    'Adresse : 8 chemin des Vignes, 70000 Vesoul Cedex 9',
    'Adresse : 8 chemin des Vignes, 70000 Vesoul cedex 9',
    'Adresse : 8 chemin des Vignes, 70000 VESOUL, CEDEX 9',
    'Adresse : 8 chemin des Vignes, 70000 VESOUL CEDEX 9',
    'Adresse : 70000 VESOUL CEDEX 9',
    'Adresse : 8 chemin des Vignes, 70000 VESOUL CEDEX',
    'Adresse : 8 chemin des Vignes, 70000 Vesoul cedex',
  ];
  for (final texte in masques) {
    test('adresse en entier : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, 'Adresse : [ADRESSE_1]', reason: r.maskedText);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  // Ce qui suit l'adresse reste en clair : le numéro de CEDEX a 1 ou 2
  // chiffres et n'est lu qu'après le mot « CEDEX ».
  const suites = {
    'Adresse : 70000 VESOUL CEDEX 9.': 'Adresse : [ADRESSE_1].',
    'Adresse : 70000 VESOUL CEDEX 9, tél. à suivre':
        'Adresse : [ADRESSE_1], tél. à suivre',
    'Adresse : 70000 VESOUL 3 agents présents':
        'Adresse : [ADRESSE_1] 3 agents présents',
    'Adresse : 70000 VESOUL CEDEX 2026 dossiers':
        'Adresse : [ADRESSE_1] 2026 dossiers',
    'Adresse : 70000 VESOUL CEDEX 9e étage': 'Adresse : [ADRESSE_1] 9e étage',
    'Adresse : 70000 VESOUL CEDEX\n9 agents présents':
        'Adresse : [ADRESSE_1]\n9 agents présents',
  };
  for (final MapEntry(key: texte, value: attendu) in suites.entries) {
    test('suite intacte : ${texte.replaceAll('\n', '\\n')}', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, attendu);
      expect(Ecluse.restore(r.maskedText, r.mapping), texte);
    });
  }

  const intacts = [
    'Le service CEDEX 9 est fermé.',
    'Envoyer au cedex 12 avant lundi.',
    'Commande 70000, cedex 9 non concerné.',
  ];
  for (final texte in intacts) {
    test('inchangé : $texte', () async {
      final r = await Ecluse.redact(texte);
      expect(r.maskedText, texte);
    });
  }

  test('coût linéaire : « 70000 VESOUL CEDEX » répété', () async {
    // Rapport de tailles (méthode de P2-100, `support/cout.dart`) au lieu d'un
    // plafond fixe de 15 s, qui dépendait de la machine : 1 250 lignes puis
    // 5 000, meilleur de trois essais, seuil 8 (≈ 4 si linéaire, ≈ 16 si
    // quadratique). Le défaut visé est une croissance quadratique du
    // rattachement du numéro de CEDEX.
    await expectCroissanceLineaire((k) async {
      await Ecluse.redact(List.filled(k, '70000 VESOUL CEDEX 9').join('\n'));
    }, n: 1250, raison: 'CEDEX répété');
  });
}
